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

local function ensure_dir(dir)
    local f = io.open(dir, "r")
    if f then f:close(); return true end
    local ok = os.rename(dir, dir)
    return ok ~= nil or ok
end

function config.is_repo(path)
    path = path or "."
    local f = io.open(path .. "/" .. paths.config, "r")
    if f then f:close(); return true end
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
            return nil
        end
        path = parent
    end
end

local function parse_bool(val)
    if val == nil then return nil end
    local s = tostring(val):lower()
    if s == "true" or s == "1" or s == "yes" then return true end
    return false
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
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed and #trimmed > 0 and not trimmed:match("^#") then
            local k, v = trimmed:match("^([^=]+)=(.*)$")
            if k and v then
                local key = k:match("^%s*(.-)%s*$")
                local val = v:match("^%s*(.-)%s*$")
                if key == "compression_enabled" or key == "auto_snapshot" then
                    cfg[key] = parse_bool(val)
                elseif key == "plugin_port" then
                    cfg[key] = tonumber(val) or 0
                elseif key == "format_version" then
                    cfg[key] = tonumber(val) or 1
                else
                    cfg[key] = val
                end
            end
        end
    end
    f:close()
    -- Apply defaults for missing keys
    for k, v in pairs(defaults) do
        if cfg[k] == nil then
            cfg[k] = v
        end
    end
    return cfg
end

function config.save(cfg, repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/" .. paths.config
    local f, err = io.open(filepath, "w")
    if not f then
        return nil, err
    end
    f:write("# ROAE Config\n")
    local merged = {}
    for k, v in pairs(defaults) do
        merged[k] = v
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
    -- Stronger auth token generation
    local seed = tostring(os.time()) .. cfg.repo_name .. tostring(math.random()) .. cfg.author
    local hash_bytes = {}
    for i = 1, #seed do
        hash_bytes[i] = string.byte(seed, i)
    end
    local token_parts = {}
    local chars = "abcdef0123456789"
    for i = 1, 32 do
        local idx = ((hash_bytes[((i - 1) % #hash_bytes) + 1] or 48) + i * 7) % 16 + 1
        token_parts[i] = chars:sub(idx, idx)
    end
    cfg.auth_token = table.concat(token_parts)
    return cfg
end

function config.read_head(repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/" .. paths.head
    local f = io.open(filepath, "r")
    if not f then return nil end
    local ref = f:read("*line")
    f:close()
    if not ref or #ref == 0 then return nil end
    return ref
end

function config.write_head(ref, repo_path)
    repo_path = repo_path or "."
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