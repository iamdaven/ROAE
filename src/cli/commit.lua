local cmd = {}
local commit = require("src.commit.commit")
local config = require("src.repo.config")

cmd.name = "commit"
cmd.description = "Create a new version snapshot with a commit message"

function cmd.execute(args)
    if #args == 0 then
        print("Error: commit message required")
        print('Usage: roae commit "message"')
        return 1
    end
    local repo_path = config.find_root(".")
    if not repo_path then
        print("Error: not a ROAE repository")
        return 1
    end
    local message = args[1]
    local author = config.load(repo_path).author or "unknown"
    local ok, result = pcall(function()
        return commit.create(message, author, "snapshot_data_placeholder", repo_path)
    end)
    if not ok then
        print("Error: " .. tostring(result))
        return 1
    end
    local commit_id, data = result
    if not commit_id then
        print("Error: " .. tostring(data))
        return 1
    end
    print("[" .. data.short_id .. "] " .. data.message)
    print("Author: " .. data.author)
    print("Date: " .. data.timestamp)
    return 0
end

return cmd