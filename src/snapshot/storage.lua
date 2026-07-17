local storage = {}
local sha256 = require("src.crypto.sha256")

function storage.generate_id(data)
    if type(data) == "string" then
        return sha256.hash_string(data)
    end
    return sha256.hash_bytes(data)
end

function storage.store(data, repo_path)
    repo_path = repo_path or "."
    local snap_dir = repo_path .. "/.roae/snapshots"
    os.execute('if not exist "' .. snap_dir .. '" mkdir "' .. snap_dir .. '" 2>nul')
    os.execute('mkdir -p "' .. snap_dir .. '" 2>/dev/null')
    local id = storage.generate_id(data)
    local filepath = snap_dir .. "/" .. id
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
    local f, err = io.open(filepath, "rb")
    if not f then
        return nil, err
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
    local f = io.open(snap_dir, "r")
    if not f then
        return {}
    end
    f:close()
    local snapshots = {}
    local ok, iter = pcall(function()
        return require("lfs").dir(snap_dir)
    end)
    if ok and iter then
        for file in iter do
            if file ~= "." and file ~= ".." and #file == 64 and file:match("^[0-9a-f]+$") then
                snapshots[#snapshots + 1] = file
            end
        end
    else
        local handle = io.popen('cmd /c "cd /d ' .. snap_dir:gsub("/", "\\") .. ' && dir /b"')
        if handle then
            for line in handle:lines() do
                line = line:match("^%s*(.-)%s*$")
                if line and #line == 64 and line:match("^[0-9a-f]+$") then
                    snapshots[#snapshots + 1] = line
                end
            end
            handle:close()
        end
    end
    table.sort(snapshots, function(a, b) return a > b end)
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
    local f = io.open(filepath, "r")
    if not f then
        return 0
    end
    local data = f:read("*all")
    f:close()
    return #data
end

return storage