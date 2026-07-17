local commit = {}
local sha256 = require("src.crypto.sha256")
local storage = require("src.snapshot.storage")
local config = require("src.repo.config")

function commit.create(message, author, serialized_data, repo_path)
    repo_path = repo_path or "."
    local snapshot_id, meta = storage.store(serialized_data, repo_path)
    if not snapshot_id then
        return nil, "failed to store snapshot"
    end
    local parent = config.read_head(repo_path)
    local timestamp = os.date("%Y-%m-%dT%H:%M:%S")
    local content = snapshot_id .. "\n" .. message .. "\n" .. author .. "\n" .. timestamp .. "\n" .. (parent or "") .. "\n"
    local commit_id = sha256.hash_string(content)
    local commit_dir = repo_path .. "/.roae/commits"
    os.execute('if not exist "' .. commit_dir .. '" mkdir "' .. commit_dir .. '" 2>nul')
    os.execute('mkdir -p "' .. commit_dir .. '" 2>/dev/null')
    local f = io.open(commit_dir .. "/" .. commit_id, "w")
    if not f then
        return nil, "failed to write commit"
    end
    f:write("tree " .. snapshot_id .. "\n")
    if parent then
        f:write("parent " .. parent .. "\n")
    end
    f:write("author " .. author .. " " .. timestamp .. "\n")
    f:write("message " .. message .. "\n")
    f:close()
    config.write_head(commit_id, repo_path)
    local log_path = repo_path .. "/.roae/log"
    f = io.open(log_path, "a")
    if f then
        f:write(commit_id:sub(1, 8) .. " " .. message .. "\n")
        f:close()
    end
    return commit_id, {
        id = commit_id,
        short_id = commit_id:sub(1, 8),
        message = message,
        author = author,
        timestamp = timestamp,
        parent = parent,
        snapshot = snapshot_id
    }
end

function commit.load(commit_id, repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/.roae/commits/" .. commit_id
    local f = io.open(filepath, "r")
    if not f then
        return nil
    end
    local data = {
        id = commit_id,
        short_id = commit_id:sub(1, 8),
        tree = nil,
        parent = nil,
        author = "",
        timestamp = "",
        message = ""
    }
    for line in f:lines() do
        if line:match("^tree ") then
            data.tree = line:match("^tree (.+)$")
        elseif line:match("^parent ") then
            data.parent = line:match("^parent (.+)$")
        elseif line:match("^author ") then
            local rest = line:match("^author (.+)$")
            local ts = rest:match("^(.+) %d%d%d%d%-%d%d%-%d%d")
            if ts then
                data.author = ts:match("^(.+) %d%d:%d%d:%d%d") or ts
                data.timestamp = ts:match("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") or ""
            else
                data.author = rest
            end
        elseif line:match("^message ") then
            data.message = line:match("^message (.+)$")
        end
    end
    f:close()
    return data
end

function commit.get_head(repo_path)
    repo_path = repo_path or "."
    local head = config.read_head(repo_path)
    if not head then
        return nil
    end
    return commit.load(head, repo_path)
end

function commit.get_parent(commit_id, repo_path)
    repo_path = repo_path or "."
    local c = commit.load(commit_id, repo_path)
    if not c or not c.parent then
        return nil
    end
    return commit.load(c.parent, repo_path)
end

function commit.get_ancestors(commit_id, repo_path)
    repo_path = repo_path or "."
    local ancestors = {}
    local current = commit_id
    while current do
        ancestors[#ancestors + 1] = current
        local c = commit.load(current, repo_path)
        current = c and c.parent or nil
    end
    return ancestors
end

function commit.walk(commit_id, repo_path, callback)
    repo_path = repo_path or "."
    local current = commit_id
    while current do
        local c = commit.load(current, repo_path)
        if not c then
            break
        end
        local should_continue = callback(c)
        if should_continue == false then
            break
        end
        current = c.parent
    end
end

return commit