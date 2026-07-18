local storage = {}
local sha256 = require("src.crypto.sha256")

local function ensure_dir(dir)
    local f = io.open(dir, "r")
    if f then f:close(); return true end
    os.execute('if not exist "' .. dir:gsub("/", "\\") .. '" mkdir "' .. dir:gsub("/", "\\") .. '"')
    return true
end

function storage.generate_id(data)
    if type(data) == "string" then
        return sha256.hash_string(data)
    end
    return sha256.hash_bytes(data)
end

function storage.store(data, repo_path)
    repo_path = repo_path or "."
    local snap_dir = repo_path .. "/.roae/snapshots"
    ensure_dir(snap_dir)
    local id = storage.generate_id(data)
    local filepath = snap_dir .. "/" .. id
    -- Avoid writing if file already exists (content-addressable dedup)
    local existing = io.open(filepath, "r")
    if existing then
        existing:close()
        return id, filepath
    end
    local f, err = io.open(filepath, "wb")
    if not f then
        return nil, err
    end
    f:write(data)
    f:close()
    return id, filepath
end

function storage.load(snapshot_id, repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/.roae/snapshots/" .. snapshot_id
    local f = io.open(filepath, "rb")
    if not f then
        return nil
    end
    local data = f:read("*all")
    f:close()
    return data
end

function storage.exists(snapshot_id, repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/.roae/snapshots/" .. snapshot_id
    local f = io.open(filepath, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function storage.list_snapshots(repo_path)
    repo_path = repo_path or "."
    local snap_dir = repo_path .. "/.roae/snapshots"
    local snapshots = {}
    local f = io.popen('dir /b "' .. snap_dir:gsub("/", "\\") .. '" 2>nul')
    if f then
        for line in f:lines() do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed and not trimmed:match("%.meta$") and #trimmed == 64 and trimmed:match("^[0-9a-f]+$") then
                snapshots[#snapshots + 1] = trimmed
            end
        end
        f:close()
    end
    table.sort(snapshots)
    return snapshots
end

function storage.delete(snapshot_id, repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/.roae/snapshots/" .. snapshot_id
    os.remove(filepath)
end

function storage.get_size(snapshot_id, repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/.roae/snapshots/" .. snapshot_id
    local f = io.open(filepath, "rb")
    if not f then
        return 0
    end
    local data = f:read("*all")
    f:close()
    return #data
end

return storage