
local p = premake

newaction {
    -- Metadata for the command line and help system

	trigger         = "clion",
	shortname       = "CLion",
	description     = "Generate CLion files",

	-- The capabilities of this action

	valid_kinds     = { "ConsoleApp", "WindowedApp", "Makefile", "SharedLib", "StaticLib", "Utility" },
	valid_languages = { "C", "C++" },
	valid_tools     = {
		cc = { "gcc", "clang", "msc" }
	},

	-- Workspace and project generation logic

	onWorkspace = function(wks)
		p.modules.clion.generateWorkspace(wks)
	end,
	onProject = function(prj)
		p.modules.clion.generateProject(prj)
	end,

	onCleanWorkspace = function(wks)
		p.modules.clion.cleanWorkspace(wks)
	end,
	onCleanProject = function(prj)
		p.modules.clion.cleanProject(prj)
	end
}

newoption {
	trigger = "globs",
	description = "Activate file-globs for source-files. Excluding files does not work."
}

return function(cfg)
    return (_ACTION == "clion")
end