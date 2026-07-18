local cmd = {}
local history_mod = require("src.commit.history")
local manager = require("src.snapshot.manager")
local config = require("src.repo.config")

cmd.name = "restore"
cmd.description = "Restore a previous Roblox project version"

function cmd.execute(args)
    if #args == 0 then
        print("Error: commit ID required")
        print("Usage: roae restore <commit>")
        return 1
    end
    local repo_path = config.find_root(".")
    if not repo_path then
        print("Error: not a ROAE repository")
        return 1
    end
    local commit_id = args[1]
    local info, data = history_mod.get_commit(commit_id, repo_path)
    if not info then
        print("Error: commit not found")
        return 1
    end
    print("Restoring commit " .. info.short_id .. "...")
    print("Message: " .. info.message)
    print("Author: " .. info.author)
    print("Date: " .. info.timestamp)
    if data then
        local restored = manager.restore_snapshot(info.snapshot, repo_path)
        if restored then
            print("")
            print("Project restored successfully")
            print("Snapshot: " .. info.snapshot:sub(1, 16) .. "...")
            return 0
        else
            print("Error: failed to restore snapshot")
            return 1
        end
    else
        print("Error: no snapshot data found")
        return 1
    end
end

return cmd