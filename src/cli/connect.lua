local cmd = {}
local config = require("src.repo.config")
local server = require("src.bridge.server")

cmd.name = "connect"
cmd.description = "Connect ROAE to the Roblox Studio plugin"

function cmd.execute(args)
    local repo_path = config.find_root(".")
    if not repo_path then
        print("Error: not a ROAE repository")
        return 1
    end
    local cfg = config.load(repo_path)
    local port = cfg.plugin_port or server.find_free_port()
    local auth_token = cfg.auth_token
    print("Starting ROAE bridge server...")
    print("Port: " .. port)
    print("Auth token: " .. auth_token:sub(1, 16) .. "...")
    print("")
    print("Waiting for Roblox Studio plugin to connect...")
    print("Press Ctrl+C to stop")
    local srv = server.start(port)
    if not srv then
        print("Error: failed to start server")
        return 1
    end
    srv.start()
    local running = true
    local function stop_handler()
        running = false
        srv.stop()
        print("")
        print("Bridge server stopped")
    end
    signal.signal("INT", stop_handler)
    while running do
        os.execute("timeout /t 1 >nul 2>&1")
    end
    return 0
end

return cmd