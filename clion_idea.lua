
local p = premake
local project = p.project
local workspace = p.workspace
local tree = p.tree
local clion = p.modules.clion

clion.idea = {}
local m = clion.idea

function m.generateMisc(wks)
	p.utf8()

	-- replacing CMakeLists.txt as the default root dir with the Premake script's path
	_p('<?xml version="1.0" encoding="UTF-8"?>')
	_p('<project version="4">')
	_p('<component name="CMakeWorkspace" PROJECT_DIR="$PROJECT_DIR$">')
	_p(1,'<contentRoot DIR="%s" />', _MAIN_SCRIPT_DIR)
	_p('</component>')
	_p('</project>')
end

function m.generateWorkspaceExisting(wks)
	p.utf8()

	-- replace existing configurations with new ones
	local file = io.readfile(wks.location .. "/.idea/workspace.xml")
	file = file:gsub('\u{FEFF}', '')
	local cfg_start, cfg_end = string.find(file, '\r?\n[ \t]-<component name="CMakeSettings">%s*<configurations>.-</configurations>%s*</component>[ \t\r]-\n')
	if cfg_start ~= nil then
		p.w(file:sub(0, cfg_start-1))
		m.clionConfigurations(wks)
		p.w(file:sub(cfg_end+3))
		return
	end

	-- workspace.xml exists but does not contain configurations
	local prj_start, prj_end = string.find(file, '\r?\n[ \t]-<project.->[ \t\r]-\n')
	print(prj_start, prj_end)
	if prj_start == nil then
		m.generateWorkspaceNew(wks)
	else
		p.w(file:sub(0, prj_end-2))
		m.clionConfigurations(wks)
		p.w(file:sub(prj_end+3))
	end
end

function m.generateWorkspaceNew(wks)
	_p('<?xml version="1.0" encoding="UTF-8"?>')
	_p('<project version="4">')

	m.clionConfigurations(wks)

	_p('</project>')
end

function m.clionConfigurations(wks)
	_p(1,'<component name="CMakeSettings">')
	_p(2,'<configurations>')
	for _, config in ipairs(wks.configurations) do
		m.clionConfiguration(config)
	end
	_p(2,'</configurations>')
	_p(1,'</component>')
end

function m.clionConfiguration(config)
	_p(3,'<configuration PROFILE_NAME="%s" ENABLED="true" GENERATION_DIR=".clion-cmake/%s" GENERATION_OPTIONS="-DPREMAKE_CONFIG_TYPE=%s" />', config, config, config)
end