#!/usr/bin/env lua

local script_path = debug.getinfo(1, "S").source
if script_path:match("^@") then
    script_path = script_path:sub(2)
end
script_path = script_path:gsub("\\", "/")
local root_dir = script_path:match("^(.*/)") or "."
package.path = root_dir .. "?.lua;" .. root_dir .. "?/init.lua;" .. package.path

local files = {
    "plugin.src.MainPlugin",
    "plugin.src.BridgeClient",
    "plugin.src.Serializer",
    "plugin.src.InstanceExporter",
    "plugin.src.ChangeDetector"
}

local output = {}
output[#output + 1] = "local Plugin = {}"
output[#output + 1] = ""
output[#output + 1] = "function Plugin.init(plugin)")
output[#output + 1] = "    Plugin.Plugin = plugin"
output[#output + 1] = "    Plugin.Plugin.Name = \"ROAE\""
output[#output + 1] = "    Plugin.Plugin.Version = \"1.0.0\""
output[#output + 1] = "    Plugin.Plugin.Description = \"ROAE, Roblox Version Control System\""
output[#output + 1] = "    "
output[#output + 1] = "    local success, err = pcall(function()"
output[#output + 1] = "        require(script.MainPlugin).init(Plugin.Plugin)"
output[#output + 1] = "    end)"
output[#output + 1] = "    if not success then"
output[#output + 1] = "        warn(\"[ROAE] Failed to initialize: \" .. tostring(err))"
output[#output + 1] = "    end"
output[#output + 1] = "end"
output[#output + 1] = ""
output[#output + 1] = "return Plugin"

for _, file in ipairs(files) do
    local mod = require(file)
    local source = debug.getinfo(mod.init or mod.run or (function() end)).source
    local filepath = root_dir .. "plugin/src/" .. file:match("plugin%.src%.(.+)$") .. ".lua"
    local f = io.open(filepath, "r")
    if f then
        local content = f:read("*all")
        f:close()
        output[#output + 1] = ""
        output[#output + 1] = "--[[ " .. file:match("plugin%.src%.(.+)$") .. " ]]"
        output[#output + 1] = content
    end
end

local out_path = root_dir .. "plugin/ROAE_Plugin.rbxl"
local f = io.open(out_path, "w")
if f then
    f:write(table.concat(output, "\n"))
    f:close()
    print("Plugin built: " .. out_path)
else
    print("Error: could not write plugin file")
    os.exit(1)
end