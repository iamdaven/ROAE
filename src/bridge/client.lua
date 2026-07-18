local bridge_client = {}

local function safe_socket()
    local ok, sock = pcall(require, "socket")
    if ok then return sock end
    return nil
end

function bridge_client.connect(host, port, auth_token)
    local socket = safe_socket()
    if not socket then return nil, "LuaSocket not available" end
    host = host or "127.0.0.1"
    port = port or 54321
    local s = socket.tcp()
    s:settimeout(5)
    local ok, err = s:connect(host, port)
    if not ok then
        return nil, err
    end
    s:send(auth_token .. "\n")
    s:settimeout(0)
    local running = true
    local handlers = {}
    local function read_loop()
        while running do
            local line, err = s:receive("*l")
            if line then
                for _, h in ipairs(handlers) do
                    pcall(h, line)
                end
            elseif err == "closed" then
                running = false
                break
            end
            socket.sleep(0.01)
        end
    end
    local co = coroutine.create(read_loop)
    return {
        send = function(msg)
            return s:send(msg .. "\n")
        end,
        on_message = function(handler)
            handlers[#handlers + 1] = handler
        end,
        close = function()
            running = false
            s:close()
        end,
        is_connected = function()
            return running
        end
    }
end

return bridge_client