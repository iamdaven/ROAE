local Plugin = {}

function Plugin.init(plugin)
    Plugin.Plugin = plugin
    Plugin.Plugin.Name = "ROAE"
    Plugin.Plugin.Version = "1.0.0"
    Plugin.Plugin.Description = "ROAE - Roblox Version Control System"
    
    local success, err = pcall(function()
        require(script.MainPlugin).init(Plugin.Plugin)
    end)
    if not success then
        warn("[ROAE] Failed to initialize: " .. tostring(err))
    end
end

return Plugin