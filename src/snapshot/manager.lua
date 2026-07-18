local manager = {}
local storage = require("src.snapshot.storage")
local sha256 = require("src.crypto.sha256")

function manager.create_snapshot(serialized_data, repo_path)
    repo_path = repo_path or "."
    local id, path = storage.store(serialized_data, repo_path)
    if not id then
        return nil, "failed to store snapshot"
    end
    local meta = {
        id = id,
        created_at = os.date("%Y-%m-%dT%H:%M:%S"),
        size = #serialized_data,
        compressed_size = storage.get_size(id, repo_path),
        tree_hash = sha256.hash_string(serialized_data)
    }
    local meta_path = repo_path .. "/.roae/snapshots/" .. id .. ".meta"
    local f = io.open(meta_path, "w")
    if f then
        f:write(meta.tree_hash .. "\n")
        f:write(tostring(meta.size) .. "\n")
        f:write(tostring(meta.compressed_size) .. "\n")
        f:write(meta.created_at .. "\n")
        f:close()
    end
    return id, meta
end

function manager.restore_snapshot(snapshot_id, repo_path)
    repo_path = repo_path or "."
    local data = storage.load(snapshot_id, repo_path)
    if not data then
        return nil, "snapshot not found"
    end
    return data
end

function manager.compute_changes(old_data, new_data)
    if old_data == new_data then
        return {total_changes = 0, added = 0, removed = 0, modified = 0}
    end
    local changes = {total_changes = 1, added = 0, removed = 0, modified = 1}
    if #new_data > #old_data then
        changes.added = #new_data - #old_data
    elseif #new_data < #old_data then
        changes.removed = #old_data - #new_data
    end
    return changes
end

function manager.diff(old_data, new_data)
    local old_lines = {}
    for line in old_data:gmatch("[^\n]+") do
        old_lines[#old_lines + 1] = line
    end
    local new_lines = {}
    for line in new_data:gmatch("[^\n]+") do
        new_lines[#new_lines + 1] = line
    end
    local diff = {added = {}, removed = {}, unchanged = {}}
    local max = math.max(#old_lines, #new_lines)
    for i = 1, max do
        local old_line = old_lines[i]
        local new_line = new_lines[i]
        if old_line and new_line then
            if old_line == new_line then
                diff.unchanged[#diff.unchanged + 1] = {line = old_line, num = i}
            else
                diff.removed[#diff.removed + 1] = {line = old_line, num = i}
                diff.added[#diff.added + 1] = {line = new_line, num = i}
            end
        elseif old_line then
            diff.removed[#diff.removed + 1] = {line = old_line, num = i}
        elseif new_line then
            diff.added[#diff.added + 1] = {line = new_line, num = i}
        end
    end
    return diff
end

function manager.get_snapshot_info(snapshot_id, repo_path)
    repo_path = repo_path or "."
    local meta_path = repo_path .. "/.roae/snapshots/" .. snapshot_id .. ".meta"
    local f = io.open(meta_path, "r")
    if not f then
        return nil
    end
    local info = {id = snapshot_id}
    info.tree_hash = f:read("*line")
    info.size = tonumber(f:read("*line")) or 0
    info.compressed_size = tonumber(f:read("*line")) or 0
    info.created_at = f:read("*line")
    f:close()
    return info
end

function manager.list_snapshots(repo_path)
    repo_path = repo_path or "."
    local snap_ids = storage.list_snapshots(repo_path)
    local snapshots = {}
    for _, id in ipairs(snap_ids) do
        local info = manager.get_snapshot_info(id, repo_path)
        if info then
            snapshots[#snapshots + 1] = info
        end
    end
    return snapshots
end

function manager.prune_old_snapshots(keep_count, repo_path)
    repo_path = repo_path or "."
    keep_count = keep_count or 10
    local snapshots = manager.list_snapshots(repo_path)
    if #snapshots <= keep_count then
        return 0
    end
    local to_delete = {}
    for i = keep_count + 1, #snapshots do
        to_delete[#to_delete + 1] = snapshots[i].id
    end
    for _, id in ipairs(to_delete) do
        storage.delete(id, repo_path)
        os.remove(repo_path .. "/.roae/snapshots/" .. id .. ".meta")
    end
    return #to_delete
end

return manager