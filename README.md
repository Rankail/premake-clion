[CLion](https://www.jetbrains.com/clion/) generator for [Premake](https://github.com/premake/premake-core).


# Usage
1. Put these files in a `clion` subdirectory in one of [Premake's search paths](https://github.com/premake/premake-core/wiki/Locating-Scripts).

2. Add the line `require "clion"` preferably to your [premake-system.lua](https://github.com/premake/premake-core/wiki/System-Scripts), or to your premake5.lua script.

3. Generate
```sh
premake5 clion [--globs]
```
\
This is a fork of [Enhex's premake-clion](https://github.com/Enhex/premake-clion) with some little changes and additions:
- [cmake-module](https://github.com/Enhex/premake-cmake) is no longer a dependency
- custom configurations are added automatically in CLion's configurations
- build commands work correctly
- projects are now correctly linked with `add_subdirectory` instead of `include` (`include` broke CLion's "Add to CMake Project")
- cmake's file-globs can be used with `--globs`

CLion sadly does not simply let you add new source files.
