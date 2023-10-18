
local p = premake
local project = p.project
local workspace = p.workspace
local tree = p.tree
local clion = p.modules.clion

clion.workspace = {}
local m = clion.workspace

function getPlatforms(wks)
    local _platforms = {}
    local platforms = {}
    for cfg in workspace.eachconfig(wks) do
        local platform = cfg.platform
        if platform and not _platforms[platform] then
            _platforms[platform] = true
        end
    end

    for k, _ in pairs(_platforms) do
        table.insert(platforms, k)
    end

    return platforms
end

function getConfigurations(wks)
    local cfgs = {}
    for cfg in workspace.eachconfig(wks) do
        local name = clion.cfgname(cfg)
        table.insert(cfgs, name)
    end

    return cfgs
end

function m.generate(wks)
    p.utf8()
    _p('cmake_minimum_required(VERSION 3.16)')
    _p('')

    local platforms = getPlatforms(wks)

    clion.workspace.multiplePlatforms = #platforms > 1

    m.clearDefualtFlags(wks)

    m.projectIncludes(wks)
end

function m.clearDefualtFlags(wks)
    _p('set(CMAKE_MSVC_RUNTIME_LIBRARY "")')
    _p('set(CMAKE_C_FLAGS "")')
    _p('set(CMAKE_CXX_FLAGS "")')

    local cfgs = getConfigurations(wks)

    for _, cfg in pairs(cfgs) do
        _p('set(CMAKE_C_FLAGS_%s "")', string.upper(cfg))
        _p('set(CMAKE_CXX_FLAGS_%s "")', string.upper(cfg))
    end
    _p('')
end

function m.projectIncludes(wks)
    _p('project("%s")', wks.name)

    local tr = workspace.grouptree(wks)
    tree.traverse(tr, {
        onleaf = function(n)
            local prj = n.project

            local prjpath = path.getrelative(prj.workspace.location, prj.basedir)
            _p('add_subdirectory(%s)', prjpath)
        end
    })
end