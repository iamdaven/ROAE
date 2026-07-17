#!/usr/bin/env lua

local script_path = debug.getinfo(1, "S").source
if script_path:match("^@") then
    script_path = script_path:sub(2)
end
script_path = script_path:gsub("\\", "/")
local root_dir = script_path:match("^(.*/)") or "."
package.path = root_dir .. "?.lua;" .. root_dir .. "?/init.lua;" .. package.path

local commands = {
    init = require("src.cli.init"),
    status = require("src.cli.status"),
    commit = require("src.cli.commit"),
    history = require("src.cli.history"),
    restore = require("src.cli.restore"),
    connect = require("src.cli.connect")
}

local function show_help()
    print("ROAE, Roblox Version Control System")
    print("")
    print("Usage: roae <command> [arguments]")
    print("")
    print("Commands:")
    local cmd_list = {}
    for name, cmd in pairs(commands) do
        table.insert(cmd_list, {name = name, desc = cmd.description or ""})
    end
    table.sort(cmd_list, function(a, b) return a.name < b.name end)
    for _, cmd in ipairs(cmd_list) do
        print(string.format("  %-12s %s", cmd.name, cmd.desc))
    end
    print("")
    print("Examples:")
    print("  roae init")
    print('  roae commit "Added inventory system"')
    print("  roae history")
    print("  roae restore a82f91")
    print("  roae connect")
end

local function main(args)
    if #args == 0 then
        show_help()
        return 0
    end
    local command = args[1]
    if command == "help" or command == "--help" or command == "-h" then
        show_help()
        return 0
    end
    local cmd = commands[command]
    if not cmd then
        print("Unknown command: " .. command)
        print("")
        show_help()
        return 1
    end
    local cmd_args = {}
    for i = 2, #args do
        table.insert(cmd_args, args[i])
    end
    local ok, result = pcall(cmd.execute, cmd_args)
    if not ok then
        print("Error: " .. tostring(result))
        return 1
    end
    return result or 0
end

local exit_code = main({...})
os.exit(exit_code)