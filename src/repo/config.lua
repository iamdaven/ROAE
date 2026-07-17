local config = {}

local defaults = {
    format_version = 1, repo_name = "", created_at = "",
    author = "", plugin_port = 0, auth_token = "",
    compression_enabled = true, auto_snapshot = true
}

local ROAE = ".roae"
local paths = {
    root = ROAE, config = ROAE .. "/config", index = ROAE .. "/index",
    refs = ROAE .. "/refs", snapshots = ROAE .. "/snapshots",
    commits = ROAE .. "/commits", objects = ROAE .. "/objects",
    head = ROAE .. "/HEAD", log = ROAE .. "/log"
}
config.paths = paths

function config.is_repo(path)
    path = path or "."
    local f = io.open(path .. "/" .. paths.config, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function config.find_root(start)
    start = start or "."
    local path = start:gsub("\\", "/")
    while true do
        if config.is_repo(path) then
            return path
        end
        local parent = path:match("^(.*)/[^/]+$")
        if not parent or parent == path then
            return nil, "not a repo"
        end
        path = parent
    end
end

function config.load(repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/" .. paths.config
    local f, err = io.open(filepath, "r")
    if not f then
        return nil, err
    end
    local cfg = {}
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line and #line > 0 and not line:match("^#") then
            local k, v = line:match("^([^=]+)=(.*)$")
            if k and v then
                cfg[k:match("^%s*(.-)%s*$")] = v:match("^%s*(.-)%s*$")
            end
        end
    end
    f:close()
    if cfg.compression_enabled then
        cfg.compression_enabled = cfg.compression_enabled == "true"
    end
    if cfg.auto_snapshot then
        cfg.auto_snapshot = cfg.auto_snapshot == "true"
    end
    if cfg.plugin_port then
        cfg.plugin_port = tonumber(cfg.plugin_port) or 0
    end
    if cfg.format_version then
        cfg.format_version = tonumber(cfg.format_version) or 1
    end
    return cfg
end

function config.save(cfg, repo_path)
    repo_path = repo_path or "."
    local dir = repo_path .. "/" .. ROAE
    os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '" 2>nul')
    os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    local filepath = repo_path .. "/" .. paths.config
    local f, err = io.open(filepath, "w")
    if not f then
        return nil, err
    end
    f:write("# ROAE Config\n")
    local merged = {}
    for k, v in pairs(defaults) do
        merged[k] = cfg[k] ~= nil and cfg[k] or v
    end
    for k, v in pairs(cfg) do
        merged[k] = v
    end
    for k, v in pairs(merged) do
        f:write(tostring(k) .. "=" .. tostring(v) .. "\n")
    end
    f:close()
    return true
end

function config.create_defaults(repo_name, author)
    local cfg = {}
    for k, v in pairs(defaults) do
        cfg[k] = v
    end
    cfg.repo_name = repo_name or "untitled"
    cfg.created_at = os.date("%Y-%m-%dT%H:%M:%S")
    cfg.author = author or os.getenv("USERNAME") or os.getenv("USER") or "unknown"
    local seed = tostring(os.time()) .. cfg.repo_name .. math.random()
    local token = ""
    local chars = "abcdef0123456789"
    for i = 1, 32 do
        local idx = (string.byte(seed, (i % #seed) + 1) % #chars) + 1
        token = token .. chars:sub(idx, idx)
    end
    cfg.auth_token = token
    return cfg
end

function config.read_head(repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/" .. paths.head
    local f = io.open(filepath, "r")
    if not f then
        return nil
    end
    local ref = f:read("*line")
    f:close()
    return ref
end

function config.write_head(ref, repo_path)
    repo_path = repo_path or "."
    local dir = repo_path .. "/" .. ROAE
    os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '" 2>nul')
    os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    local filepath = repo_path .. "/" .. paths.head
    local f = io.open(filepath, "w")
    if not f then
        return nil, "could not write HEAD"
    end
    f:write(ref .. "\n")
    f:close()
    return true
end

return config