local server = {}

local function safe_socket()
    local ok, sock = pcall(require, "socket")
    if ok then return sock end
    return nil
end

function server.find_free_port()
    local socket = safe_socket()
    if not socket then return 54321 end
    local s = socket.tcp()
    s:setoption("reuseaddr", true)
    s:bind("127.0.0.1", 0)
    local port = s:getsockname().port
    s:close()
    return port
end

function server.start(port, on_connect, on_message, on_disconnect)
    local socket = safe_socket()
    if not socket then
        return nil, "LuaSocket not available"
    end
    port = port or server.find_free_port()
    local s = socket.tcp()
    s:setoption("reuseaddr", true)
    local ok, err = s:bind("127.0.0.1", port)
    if not ok then
        return nil, err
    end
    s:listen(5)
    s:settimeout(0)
    local clients = {}
    local running = true
    local auth_token = tostring(os.time()):sub(-8) .. tostring(math.random(1000, 9999))
    local function accept_loop()
        while running do
            local client = s:accept()
            if client then
                client:settimeout(5)
                local token = client:receive("*l")
                if token == auth_token then
                    client:settimeout(0)
                    clients[client] = {connected = true, last_seen = os.time()}
                    if on_connect then
                        pcall(on_connect, client)
                    end
                else
                    client:close()
                end
            end
            socket.sleep(0.01)
        end
    end
    local function broadcast(msg)
        for client, _ in pairs(clients) do
            pcall(function()
                client:send(msg .. "\n")
            end)
        end
    end
    local function stop()
        running = false
        for client, _ in pairs(clients) do
            pcall(function()
                client:close()
            end)
        end
        s:close()
    end
    local co = coroutine.create(accept_loop)
    return {
        port = port,
        auth_token = auth_token,
        start = function()
            coroutine.resume(co)
        end,
        broadcast = broadcast,
        stop = stop,
        is_running = function()
            return running
        end
    }
end

return server