local MainPlugin = {}
local BridgeClient = require(script.BridgeClient)
local Serializer = require(script.Serializer)
local InstanceExporter = require(script.InstanceExporter)
local ChangeDetector = require(script.ChangeDetector)

function MainPlugin.init(plugin)
    -- Plugin setup
    plugin.Name = "ROAE"
    plugin.Version = "1.0.0"
    plugin.Description = "ROAE - Roblox Version Control System"

    -- Create toolbar
    local toolbar = plugin:CreateToolbar("ROAE")
    local connectBtn = toolbar:CreateButton("Connect", "Connect to ROAE desktop", "rbxassetid://123456789")
    local snapshotBtn = toolbar:CreateButton("Snapshot", "Create a snapshot", "rbxassetid://123456789")

    local connected = false
    local bridge = nil

    connectBtn.Click:Connect(function()
        if connected then
            if bridge then bridge:close() end
            connected = false
            connectBtn:SetActive(false)
            warn("[ROAE] Disconnected")
        else
            pcall(function()
                bridge = BridgeClient.connect("127.0.0.1", 54321, "test")
                if bridge then
                    connected = true
                    connectBtn:SetActive(true)
                    print("[ROAE] Connected to ROAE desktop")
                end
            end)
        end
    end)

    snapshotBtn.Click:Connect(function()
        if not connected then
            warn("[ROAE] Not connected to ROAE desktop")
            return
        end
        local success, err = pcall(function()
            local data = InstanceExporter.export_project(game:GetService("Workspace"))
            local serialized = Serializer.serialize_project({data})
            bridge:send(serialized)
        end)
        if not success then
            warn("[ROAE] Snapshot failed: " .. tostring(err))
        end
    end)
end

return MainPlugin