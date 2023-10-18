
local p = premake

p.modules.clion = {}
p.modules.clion._VERSION = p._VERSION

local clion = p.modules.clion
local project = p.project

function clion.generateWorkspace(wks)
    p.eol("\r\n")
    p.indent("  ")
	
    p.generate(wks, wks.location .. "/.idea/misc.xml", clion.idea.generateMisc)
    
    local wksXmlPath = "/.idea/workspace.xml"
    if os.isfile(wks.location .. wksXmlPath) then
        p.generate(wks, wks.location .. wksXmlPath, clion.idea.generateWorkspaceExisting)
    else
        p.generate(wks, wks.location .. wksXmlPath, clion.idea.generateWorkspaceNew)
    end

    p.generate(wks, "CMakeLists.txt", clion.workspace.generate)
end

function clion.generateProject(prj)
    p.eol("\r\n")
    p.indent("  ")

    if project.isc(prj) or project.iscpp(prj) then
        p.generate(prj, "CMakeLists.txt", clion.project.generate)
    end
end

function clion.cfgname(cfg)
    local cfgname = cfg.buildcfg

    if clion.workspace.multiplePlatforms then
        cfgname = string.format("%s-%s", cfg.platform, cfg.buildcfg)
    end
    
    return cfgname
end

function clion.cleanWorkspace(wks)
    p.clean.file(wks, "CMakeLists.txt")
end

function clion.cleanProject(prj)
    p.clean.file(prj, prj.name .. ".cmake")
end

include("clion_workspace.lua")
include("clion_project.lua")
include("clion_idea.lua")

include("_preload.lua")

return clion