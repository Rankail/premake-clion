
local p = premake
local project = p.project
local workspace = p.workspace
local tree = p.tree
local config = p.config
local clion = p.modules.clion

clion.project = {}
local m = clion.project

function m.quote(s) -- handle single quote: required for "old" version of cmake
	return premake.quote(s):gsub("'", " ") 
end

function m.getcompiler(cfg)
	local default = iif(cfg.system == p.WINDOWS, "msc", "clang")
	local toolset = p.tools[_OPTIONS.cc or cfg.toolset or default]
	if not toolset then
		error("Invalid toolset '" + (_OPTIONS.cc or cfg.toolset) + "'")
	end
	return toolset
end

function m.files(prj)
	local tr = project.getsourcetree(prj)

	tree.traverse(tr, {
		onleaf = function(node, depth)
			if node.flags.ExcludeFromBuild or node.generated then
				return
			end
			_p(1, '"%s"', path.getrelative(prj.workspace.location, node.abspath))
		end
	})
end

function m.generate(prj)
    p.utf8()

	if prj.kind == 'Utility' then
		return
	end

	if prj.hasGeneratedFiles then
		m.generated_files(prj)
	end

	if prj.kind == 'StaticLib' then
		_p('add_library("%s" STATIC', prj.name)
	elseif prj.kind == 'SharedLib' then
		_p('add_library("%s" SHARED', prj.name)
	else
		if prj.executable_suffix then
			_p('set(CMAKE_EXECUTABLE_SUFFIX "%s")', prj.executable_suffix)
		end
		_p('add_executable("%s"', prj.name)
	end

	m.files(prj)
	if prj.hasGeneratedFiles then
		_p(1, '${GENERATED_FILES}')
	end
	_p(')')

	for cfg in project.eachconfig(prj) do
		_p('if(PREMAKE_CONFIG_TYPE STREQUAL %s)', clion.cfgname(cfg))
		
		m.generateDependencies(prj)
		m.generateOutputDir(prj, cfg)
		m.generateIncludeDirs(prj, cfg)
		m.generateDefines(prj, cfg)
		m.generateUndefines(prj, cfg)
		m.generateLibDirs(prj, cfg)
		m.generateLibs(prj, cfg)
		m.generateBuildOptions(prj, cfg)
		m.generateLinkOptions(prj, cfg)
		m.generateCppStandard(prj, cfg)
		m.generatePrecompiledHeaders(prj, cfg)
		m.generateBuildCommands(prj, cfg)
		m.generateCustomCommands(prj, cfg)

		_p('endif()')
		_p('')
	end
end

function m.generateDependencies(prj)
	-- dependencies
	local dependencies = project.getdependencies(prj)
	if #dependencies > 0 then
		_p(1, 'add_dependencies("%s"', prj.name)
		for _, dependency in ipairs(dependencies) do
			_p(2, '"%s"', dependency.name)
		end
		_p(1,')')
	end
end

function m.generateOutputDir(prj, cfg)
	-- output dir
	outputdir = path.getrelative(prj.workspace.location.."/.clion-cmake/"..clion.cfgname(cfg), cfg.buildtarget.directory)

	_p(1,'set_target_properties("%s" PROPERTIES', prj.name)
	_p(2, 'OUTPUT_NAME "%s"', cfg.buildtarget.basename)
	_p(2, 'ARCHIVE_OUTPUT_DIRECTORY "%s"', outputdir)
	_p(2, 'LIBRARY_OUTPUT_DIRECTORY "%s"', outputdir)
	_p(2, 'RUNTIME_OUTPUT_DIRECTORY "%s"', outputdir)
	_p(1,')')
end

function m.generateIncludeDirs(prj, cfg)
	-- include dirs
	m.generateIncludeDirsExternal(prj, cfg)
	m.generateIncludeDirsNormal(prj, cfg)
	m.generateIncludeDirsAfter(prj, cfg)
	m.generateIncludeDirsForce(prj, cfg)
end

function m.generateIncludeDirsExternal(prj, cfg)
	if #cfg.externalincludedirs > 0 then
		_p(1, 'target_include_directories("%s" SYSTEM PRIVATE', prj.name)
		for _, includedir in ipairs(cfg.externalincludedirs) do
			_x(2, '"%s"', includedir)
		end
		_p(1, ')')
	end
end

function m.generateIncludeDirsNormal(prj, cfg)
	if #cfg.includedirs > 0 then
		_p(1, 'target_include_directories("%s" PRIVATE', prj.name)
		for _, includedir in ipairs(cfg.includedirs) do
			_x(2, '"%s"', includedir)
		end
		_p(1, ')')
	end
end

function m.generateIncludeDirsAfter(prj, cfg)
	if #cfg.frameworkdirs > 0 or (cfg.includedirsafter and #cfg.includedirsafter > 0) then
		_p(1, 'if (MSVC)')
		_p(2, 'target_compile_options("%s" PRIVATE %s)', prj.name, table.implode(p.tools.msc.getincludedirs(cfg, {}, {}, cfg.frameworkdirs, cfg.includedirsafter), "", "", " "))
		_p(1, 'else()')
		_p(2, 'target_compile_options("%s" PRIVATE %s)', prj.name, table.implode(p.tools.gcc.getincludedirs(cfg, {}, {}, cfg.frameworkdirs, cfg.includedirsafter), "", "", " "))
		_p(1, 'endif()')
	end
end

function m.generateIncludeDirsForce(prj, cfg)
	if #cfg.forceincludes > 0 then
		_p(1, 'if (MSVC)')
		_p(2, 'target_compile_options("%s" PRIVATE %s)', prj.name, table.implode(p.tools.msc.getforceincludes(cfg), "", "", " "))
		_p(1, 'else()')
		_p(2, 'target_compile_options("%s" PRIVATE %s)', prj.name, table.implode(p.tools.gcc.getforceincludes(cfg), "", "", " "))
		_p(1, 'endif()')
	end
end

function m.generateDefines(prj, cfg)
	-- defines
	if #cfg.defines > 0 then
		_p(1, 'target_compile_definitions("%s" PRIVATE', prj.name)
		for _, define in ipairs(cfg.defines) do
			_p(2, '"%s"', p.esc(define):gsub(' ', '\\ '))
		end
		_p(1, ')')
	end
end

function m.generateUndefines(prj, cfg)
	if #cfg.undefines > 0 then
		_p(1, 'if (MSVC)')
		_p(2, 'target_compile_options("%s" PRIVATE %s)', prj.name, table.implode(p.tools.msc.getundefines(cfg.undefines), "", "", " "))
		_p(1, 'else()')
		_p(2, 'target_compile_options("%s" PRIVATE %s)', prj.name, table.implode(p.tools.gcc.getundefines(cfg.undefines), "", "", " "))
		_p(1, 'endif()')
	end
end

function m.generateLibDirs(prj, cfg)
	-- lib dirs
	if #cfg.libdirs > 0 then
		_p(1, 'target_link_directories("%s" PRIVATE', prj.name)
		for _, libdir in ipairs(cfg.libdirs) do
			_p(2, '"%s"', libdir)
		end
		_p(1, ')')
	end
end

function m.generateLibs(prj, cfg)
	-- libs
	local toolset = m.getcompiler(cfg)
	local isclangorgcc = toolset == p.tools.clang or toolset == p.tools.gcc
	
	local uselinkgroups = isclangorgcc and cfg.linkgroups == p.ON
	if uselinkgroups or # config.getlinks(cfg, "dependencies", "object") > 0 or #config.getlinks(cfg, "system", "fullpath") > 0 then
		_p(1, 'target_link_libraries("%s"', prj.name)
		-- Do not use toolset here as cmake needs to resolve dependency chains
		if uselinkgroups then
			_p(2, '-Wl,--start-group')
		end
		for a, link in ipairs(config.getlinks(cfg, "dependencies", "object")) do
			_p(2, '"%s"', link.project.name)
		end
		if uselinkgroups then
			-- System libraries don't depend on the project
			_p(2, '-Wl,--end-group')
			_p(2, '-Wl,--start-group')
		end
		for _, link in ipairs(config.getlinks(cfg, "system", "fullpath")) do
			_p(2, '"%s"', link)
		end
		if uselinkgroups then
			_p(2, '-Wl,--end-group')
		end
		_p(1, ')')
	end
end

function m.generateBuildOptions(prj, cfg)
	-- setting build options
	all_build_options = ""
	for _, option in ipairs(cfg.buildoptions) do
		all_build_options = all_build_options .. option .. " "
	end
	
	if all_build_options ~= "" then
		_p(1, 'if(CMAKE_BUILD_TYPE STREQUAL %s)', clion.cfgname(cfg))
		_p(2, 'set_target_properties("%s" PROPERTIES COMPILE_FLAGS %s)', prj.name, all_build_options)
		_p(1, 'endif()')
	end
end

function m.generateLinkOptions(prj, cfg)
	-- setting link options
	all_link_options = ""
	for _, option in ipairs(cfg.linkoptions) do
		all_link_options = all_link_options .. option .. " "
	end

	if all_link_options ~= "" or (cfg.sanitize and #cfg.sanitize ~= 0) then
		if all_link_options ~= "" then
			_p(1, 'set_target_properties("%s" PROPERTIES LINK_FLAGS "%s")', prj.name, all_link_options)
		end
		if cfg.sanitize and #cfg.sanitize ~= 0 then
			_p(1, 'if (NOT MSVC)')
			if table.contains(cfg.sanitize, "Address") then
				_p(2, 'target_link_options("%s" PRIVATE "-fsanitize=address")', prj.name)
			end
			if table.contains(cfg.sanitize, "Fuzzer") then
				_p(2, 'target_link_options("%s" PRIVATE "-fsanitize=fuzzer")', prj.name)
			end
			_p(1, 'endif()')
		end
	end

	local toolset = m.getcompiler(cfg)
	if #toolset.getcflags(cfg) > 0 or #toolset.getcxxflags(cfg) > 0 then
		_p(1, 'if (MSVC)')
		_p(2, 'target_compile_options("%s" PRIVATE', prj.name)
		for _, flag in ipairs(p.tools.msc.getcflags(cfg)) do
			_p(3, '$<$<COMPILE_LANGUAGE:C>:%s>', flag)
		end
		for _, flag in ipairs(p.tools.msc.getcxxflags(cfg)) do
			_p(3, '$<$<COMPILE_LANGUAGE:CXX>:%s>', flag)
		end
		_p(2, ')')
		_p(1, 'else()')
		_p(2, 'target_compile_options("%s" PRIVATE', prj.name)
		for _, flag in ipairs(p.tools.gcc.getcflags(cfg)) do
			_p(3, '$<$<COMPILE_LANGUAGE:C>:%s>', flag)
		end
		for _, flag in ipairs(p.tools.gcc.getcxxflags(cfg)) do
			_p(3, '$<$<COMPILE_LANGUAGE:CXX>:%s>', flag)
		end
		_p(2, ')')
		_p(1, 'endif()')
	end
end

function m.generateCppStandard(prj, cfg)
	-- C++ standard
	-- only need to configure it specified
	if (cfg.cppdialect ~= nil and cfg.cppdialect ~= '') or cfg.cppdialect == 'Default' then
		local standard = {}
		standard["C++98"] = 98
		standard["C++11"] = 11
		standard["C++14"] = 14
		standard["C++17"] = 17
		standard["C++20"] = 20
		standard["gnu++98"] = 98
		standard["gnu++11"] = 11
		standard["gnu++14"] = 14
		standard["gnu++17"] = 17
		standard["gnu++20"] = 20

		local extentions = iif(cfg.cppdialect:find('^gnu') == nil, 'NO', 'YES')
		local pic = iif(cfg.pic == 'On', 'True', 'False')
		local lto = iif(cfg.flags.LinkTimeOptimization, 'True', 'False')

		_p(1, 'set_target_properties("%s" PROPERTIES', prj.name)
		_p(2, 'CXX_STANDARD %s', standard[cfg.cppdialect])
		_p(2, 'CXX_STANDARD_REQUIRED YES')
		_p(2, 'CXX_EXTENSIONS %s', extentions)
		_p(2, 'POSITION_INDEPENDENT_CODE %s', pic)
		_p(2, 'INTERPROCEDURAL_OPTIMIZATION %s', lto)
		_p(1, ')')
	end
end

function m.generatePrecompiledHeaders(prj, cfg)
	-- precompiled headers
	-- copied from gmake2_cpp.lua
	if not cfg.flags.NoPCH and cfg.pchheader then
		local pch = cfg.pchheader
		local found = false

		-- test locally in the project folder first (this is the most likely location)
		local testname = path.join(cfg.project.basedir, pch)
		if os.isfile(testname) then
			pch = project.getrelative(cfg.project, testname)
			found = true
		else
			-- else scan in all include dirs.
			for _, incdir in ipairs(cfg.includedirs) do
				testname = path.join(incdir, pch)
				if os.isfile(testname) then
					pch = project.getrelative(cfg.project, testname)
					found = true
					break
				end
			end
		end

		if not found then
			pch = project.getrelative(cfg.project, path.getabsolute(pch))
		end

		_p(1, 'target_precompile_headers("%s" PUBLIC "%s")', prj.name, pch)
	end
end

function m.generateBuildCommands(prj, cfg)
	m.generateBuildCommandsPreBuild(prj, cfg)
	m.generateBuildCommandsPreLink(prj, cfg)
	m.generateBuildCommandsPostBuild(prj, cfg)
end

function m.generateBuildCommandsPreBuild(prj, cfg)
	if cfg.prebuildmessage or #cfg.prebuildcommands > 0 then
		-- add_custom_command PRE_BUILD runs just before generating the target
		-- so instead, use add_custom_target to run it before any rule (as obj)
		_p(1, 'add_custom_target(prebuild-%s', prj.name)
		if cfg.prebuildmessage then
			local command = os.translateCommandsAndPaths("{ECHO} " .. m.quote(cfg.prebuildmessage), cfg.project.basedir, cfg.workspace.location.."/.clion-cmake/cfg")
			_p(2, 'COMMAND %s', command)
		end
		local commands = os.translateCommandsAndPaths(cfg.prebuildcommands, cfg.project.basedir, cfg.workspace.location.."/.clion-cmake/cfg")
		for _, command in ipairs(commands) do
			_p(2, 'COMMAND %s', command)
		end
		_p(1, ')')
		_p(1, 'add_dependencies(%s prebuild-%s)', prj.name, prj.name)
	end
end

function m.generateBuildCommandsPreLink(prj, cfg)
	if cfg.prelinkmessage or #cfg.prelinkcommands > 0 then
		_p(1, 'add_custom_command(TARGET %s PRE_LINK', prj.name)
		if cfg.prelinkmessage then
			local command = os.translateCommandsAndPaths("{ECHO} " .. m.quote(cfg.prelinkmessage), cfg.project.basedir, cfg.workspace.location.."/../../")
			_p(2, 'COMMAND %s', command)
		end
		local commands = os.translateCommandsAndPaths(cfg.prelinkcommands, cfg.project.basedir, cfg.workspace.location.."/../../")
		for _, command in ipairs(commands) do
			_p(2, 'COMMAND %s', command)
		end
		_p(1, ')')
	end
end

function m.generateBuildCommandsPostBuild(prj, cfg)
	if cfg.postbuildmessage or #cfg.postbuildcommands > 0 then
		_p(1, 'add_custom_command(TARGET %s POST_BUILD', prj.name)
		if cfg.postbuildmessage then
			local command = os.translateCommandsAndPaths("{ECHO} " .. m.quote(cfg.postbuildmessage), cfg.project.basedir, cfg.workspace.location.."/.clion-cmake/cfg/")
			_p(2, 'COMMAND %s', command)
		end
		local commands = os.translateCommandsAndPaths(cfg.postbuildcommands, cfg.project.basedir, cfg.workspace.location.."/.clion-cmake/cfg/")
		for _, command in ipairs(commands) do
			_p(2, 'COMMAND %s', command)
		end
		_p(1, ')')
	end
end

function m.generateCustomCommands(prj, cfg)
	-- custom command
	local function addCustomCommand(fileconfig, filename)
		if #fileconfig.buildcommands == 0 or #fileconfig.buildoutputs == 0 then
			return
		end

		local custom_output_directories = table.unique(table.translate(fileconfig.buildoutputs, function(output) return project.getrelative(cfg.project, path.getdirectory(output)) end))
		-- Alternative would be to add 'COMMAND ${CMAKE_COMMAND} -E make_directory %s' to below add_custom_command
		_p(1, 'file(MAKE_DIRECTORY %s)', table.implode(custom_output_directories, "", "", " "))

		_p(1, 'add_custom_command(TARGET OUTPUT %s', table.implode(project.getrelative(cfg.project, fileconfig.buildoutputs),"",""," "))
		if fileconfig.buildmessage then
			_p(2, 'COMMAND %s', os.translateCommandsAndPaths('{ECHO} ' .. m.quote(fileconfig.buildmessage), cfg.project.basedir, cfg.workspace.location.."/../../"))
		end
		for _, command in ipairs(fileconfig.buildcommands) do
			_p(2, 'COMMAND %s', os.translateCommandsAndPaths(command, cfg.project.basedir, cfg.workspace.location.."/../../"))
		end
		if filename ~= "" and #fileconfig.buildinputs ~= 0 then
			filename = filename .. " "
		end
		if filename ~= "" or #fileconfig.buildinputs ~= 0 then
			_p(2, 'DEPENDS %s', filename .. table.implode(fileconfig.buildinputs,"",""," "))
		end
		_p(1, ')')
		if not fileconfig.compilebuildoutputs then
			local target_name = 'CUSTOM_TARGET_' .. filename:gsub('/', '_'):gsub('\\', '_')
			_p(1, 'add_custom_target(%s DEPENDS %s)', target_name, table.implode(project.getrelative(cfg.project, fileconfig.buildoutputs),"",""," "))
			_p(1, 'add_dependencies(%s %s)', prj.name, target_name)
		end
	end

	local tr = project.getsourcetree(cfg.project)
	p.tree.traverse(tr, {
		onleaf = function(node, depth)
			local filecfg = p.fileconfig.getconfig(node, cfg)
			local rule = p.global.getRuleForFile(node.name, prj.rules)

			if p.fileconfig.hasFileSettings(filecfg) then
				addCustomCommand(filecfg, node.relpath)
			elseif rule then
				local environ = table.shallowcopy(filecfg.environ)

				if rule.propertydefinition then
					p.rule.prepareEnvironment(rule, environ, cfg)
					p.rule.prepareEnvironment(rule, environ, filecfg)
				end
				local rulecfg = p.context.extent(rule, environ)
				addCustomCommand(rulecfg, node.relpath)
			end
		end
	})
	addCustomCommand(cfg, "")
end

function os.translateCommandsAndPaths(cmds, basedir, location, map)
	local translatedBaseDir = path.getrelative(location, basedir)

	map = map or os.target()

	local translateFunction = function(value)
		local result = path.join(translatedBaseDir, value)
		result = os.translateCommandAndPath(result, map)
		if value:endswith('/') or value:endswith('\\') or -- if original path ends with a slash then ensure the same
		   value:endswith('/"') or value:endswith('\\"') then
			result = result .. '/'
		end
		return result
	end

	local processOne = function(cmd)
		local replaceFunction = function(value)
			value = value:sub(3, #value - 1)
			return '"' .. translateFunction(value) .. '"'
		end
		return string.gsub(cmd, "%%%[[^%]\r\n]*%]", replaceFunction)
	end

	if type(cmds) == "table" then
		local result = {}
		for i = 1, #cmds do
			result[i] = processOne(cmds[i])
		end
		return os.translateCommands(result, map)
	else
		return os.translateCommands(processOne(cmds), map)
	end
end