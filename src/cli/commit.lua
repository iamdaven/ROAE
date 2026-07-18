local cmd = {}
local commit_mod = require("src.commit.commit")
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
    local commit_id, commit_data = commit_mod.create(message, author, "snapshot_data_placeholder", repo_path)
    if not commit_id then
        print("Error: " .. tostring(commit_data))
        return 1
    end
    print("[" .. commit_data.short_id .. "] " .. commit_data.message)
    print("Author: " .. commit_data.author)
    print("Date: " .. commit_data.timestamp)
    return 0
end

return cmd