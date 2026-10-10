import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import fengari from "fengari";

const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

export const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const FINDER_TESTS = "tests/finder/";

const moduleSearchRootsFor = (entryRelativePath) => {
    const pluginFolder = entryRelativePath.startsWith(FINDER_TESTS) ? "rsprite-finder" : "rsprite";
    return [repositoryRoot, join(repositoryRoot, "plugins", pluginFolder)];
};

export const describePath = (path) => relative(repositoryRoot, path).split("\\").join("/");

const bootstrap = `
local loadedModules = package.loaded

function require(name)
    local cached = loadedModules[name]
    if cached ~= nil then
        return cached
    end
    local source, chunkName = __readmodule(name)
    local chunk = assert(load(source, chunkName))
    local module = chunk(name)
    if type(module) ~= "table" then
        error(chunkName .. " must return a table, the client rejects anything else")
    end
    loadedModules[name] = module
    return module
end

io = io or {}

function io.open(path, mode)
    if mode ~= nil and mode ~= "r" and mode ~= "rb" then
        return nil, path .. ": this runner opens files for reading only"
    end
    local contents = __readfile(path)
    if contents == nil then
        return nil, path .. ": no such file"
    end
    local handle = {}
    local exhausted = false
    function handle:read(format)
        if format ~= nil and format ~= "a" and format ~= "*a" then
            error("this runner reads whole files only, not " .. tostring(format))
        end
        if exhausted then
            return ""
        end
        exhausted = true
        return contents
    end
    function handle:close()
        return true
    end
    return handle
end

selftest = {}

function selftest.ListFiles(path)
    local listing = __listfiles(path)
    local files = {}
    for file in string.gmatch(listing, "[^\\n]+") do
        files[#files + 1] = file
    end
    return files
end

function selftest.NewUserdata()
    return __newuserdata()
end

function selftest.LoadPlugin(folder)
    local pluginModules = {}
    local environment = setmetatable({}, { __index = _G })
    local function pluginRequire(name)
        local cached = pluginModules[name]
        if cached ~= nil then
            return cached
        end
        local source, chunkName = __readpluginmodule(folder, name)
        local module = assert(load(source, chunkName, "t", environment))(name)
        if type(module) ~= "table" then
            error(chunkName .. " must return a table, the client rejects anything else")
        end
        pluginModules[name] = module
        return module
    end
    environment.require = pluginRequire
    local source, chunkName = __readpluginmodule(folder, "main")
    local main = assert(load(source, chunkName, "t", environment))
    return main(), environment
end
`;

const registerFunction = (state, name, implementation) => {
    lua.lua_pushjsfunction(state, implementation);
    lua.lua_setglobal(state, to_luastring(name));
};

const listFilesUnder = (absolutePath) => {
    if (!existsSync(absolutePath)) return [];
    return readdirSync(absolutePath, { withFileTypes: true })
        .sort((first, second) => first.name.localeCompare(second.name))
        .flatMap((entry) => {
            const entryPath = join(absolutePath, entry.name);
            return entry.isDirectory() ? listFilesUnder(entryPath) : [describePath(entryPath)];
        });
};

export const runLuaFile = (entryRelativePath) => {
    const entryPath = join(repositoryRoot, entryRelativePath);
    if (!existsSync(entryPath)) {
        console.error(`No Lua file at ${entryRelativePath}. Pass a path relative to the repository root, such as tests/sprite_lookup_selftest.lua.`);
        return 1;
    }

    const moduleSearchRoots = moduleSearchRootsFor(entryRelativePath.split("\\").join("/"));
    const state = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(state);

    registerFunction(state, "__readmodule", (innerState) => {
        const name = to_jsstring(lauxlib.luaL_checkstring(innerState, 1));
        const candidates = moduleSearchRoots.map((searchRoot) => join(searchRoot, `${name}.lua`));
        const found = candidates.find((candidate) => existsSync(candidate));
        if (found === undefined) {
            return lauxlib.luaL_error(innerState, to_luastring(`no module ${name}, looked in ${candidates.map(describePath).join(" and ")}`));
        }
        lua.lua_pushstring(innerState, to_luastring(readFileSync(found, "utf8")));
        lua.lua_pushstring(innerState, to_luastring(`@${describePath(found)}`));
        return 2;
    });

    registerFunction(state, "__readpluginmodule", (innerState) => {
        const folder = to_jsstring(lauxlib.luaL_checkstring(innerState, 1));
        const name = to_jsstring(lauxlib.luaL_checkstring(innerState, 2));
        const path = join(repositoryRoot, folder, `${name}.lua`);
        if (!existsSync(path)) {
            return lauxlib.luaL_error(innerState, to_luastring(`no module ${name} in ${folder}`));
        }
        lua.lua_pushstring(innerState, to_luastring(readFileSync(path, "utf8")));
        lua.lua_pushstring(innerState, to_luastring(`@${describePath(path)}`));
        return 2;
    });

    registerFunction(state, "__readfile", (innerState) => {
        const requested = to_jsstring(lauxlib.luaL_checkstring(innerState, 1));
        try {
            lua.lua_pushstring(innerState, to_luastring(readFileSync(resolve(repositoryRoot, requested), "utf8")));
        } catch {
            lua.lua_pushnil(innerState);
        }
        return 1;
    });

    registerFunction(state, "__listfiles", (innerState) => {
        const requested = to_jsstring(lauxlib.luaL_checkstring(innerState, 1));
        lua.lua_pushstring(innerState, to_luastring(listFilesUnder(resolve(repositoryRoot, requested)).join("\n")));
        return 1;
    });

    registerFunction(state, "__newuserdata", (innerState) => {
        lua.lua_newuserdata(innerState, 0);
        return 1;
    });

    if (lauxlib.luaL_dostring(state, to_luastring(bootstrap)) !== lua.LUA_OK) {
        console.error(`bootstrap: ${to_jsstring(lua.lua_tostring(state, -1))}`);
        return 1;
    }

    const chunkName = to_luastring(`@${entryRelativePath.split("\\").join("/")}`);
    if (lauxlib.luaL_loadbuffer(state, to_luastring(readFileSync(entryPath, "utf8")), null, chunkName) !== lua.LUA_OK) {
        console.error(`load: ${to_jsstring(lua.lua_tostring(state, -1))}`);
        return 1;
    }
    if (lua.lua_pcall(state, 0, 0, 0) !== lua.LUA_OK) {
        console.error(`run: ${to_jsstring(lua.lua_tostring(state, -1))}`);
        return 1;
    }
    return 0;
};
