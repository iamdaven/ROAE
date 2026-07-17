local history = {}
local commit = require("src.commit.commit")
local storage = require("src.snapshot.storage")
local manager = require("src.snapshot.manager")

function history.get_history(repo_path, limit)
    repo_path = repo_path or "."
    local head = commit.get_head(repo_path)
    if not head then
        return {}
    end
    local commits = {}
    local count = 0
    commit.walk(head.id, repo_path, function(c)
        commits[#commits + 1] = {
            id = c.id,
            short_id = c.short_id,
            message = c.message,
            author = c.author,
            timestamp = c.timestamp,
            parent = c.parent,
            snapshot = c.snapshot
        }
        count = count + 1
        if limit and count >= limit then
            return false
        end
    end)
    return commits
end

function history.get_commit(commit_id, repo_path)
    repo_path = repo_path or "."
    local c = commit.load(commit_id, repo_path)
    if not c then
        return nil
    end
    local snapshot_data = nil
    if c.snapshot then
        snapshot_data = manager.restore_snapshot(c.snapshot, repo_path)
    end
    return {
        id = c.id,
        short_id = c.short_id,
        message = c.message,
        author = c.author,
        timestamp = c.timestamp,
        parent = c.parent,
        snapshot = c.snapshot,
        snapshot_data = snapshot_data
    }, snapshot_data
end

function history.search(query, repo_path)
    repo_path = repo_path or "."
    local commits = history.get_history(repo_path, 1000)
    local results = {}
    query = query:lower()
    for _, c in ipairs(commits) do
        if c.message:lower():find(query, 1, true) or c.author:lower():find(query, 1, true) then
            results[#results + 1] = c
        end
    end
    return results
end

function history.count(repo_path)
    repo_path = repo_path or "."
    local commits = history.get_history(repo_path, 1000)
    return #commits
end

function history.get_branch(repo_path)
    repo_path = repo_path or "."
    local head = commit.get_head(repo_path)
    if not head then
        return nil
    end
    return "main"
end

function history.show(commit_id, repo_path)
    repo_path = repo_path or "."
    local c = commit.load(commit_id, repo_path)
    if not c then
        return nil, "commit not found"
    end
    local info = {
        id = c.id,
        short_id = c.short_id,
        message = c.message,
        author = c.author,
        timestamp = c.timestamp,
        parent = c.parent,
        snapshot = c.snapshot
    }
    if c.snapshot then
        local snap_info = manager.get_snapshot_info(c.snapshot, repo_path)
        if snap_info then
            info.snapshot_size = snap_info.size
            info.snapshot_compressed = snap_info.compressed_size
        end
    end
    return info
end

return history