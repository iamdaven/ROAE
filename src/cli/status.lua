local cmd = {}
local config = require("src.repo.config")
local history_mod = require("src.commit.history")
local storage = require("src.snapshot.storage")
local index = require("src.repo.index")

cmd.name = "status"
cmd.description = "Show repository status"

function cmd.execute(args)
    local repo_path = config.find_root(".")
    if not repo_path then
        print("Error: not a ROAE repository")
        return 1
    end
    local cfg = config.load(repo_path)
    print("ROAE Repository: " .. (cfg.repo_name or "untitled"))
    print("Author: " .. (cfg.author or "unknown"))
    print("")
    local head = config.read_head(repo_path)
    if head and #head > 0 then
        print("HEAD: " .. head:sub(1, 8))
    else
        print("HEAD: (no commits)")
    end
    local commit_list = history_mod.get_history(repo_path, 5)
    print("Commits: " .. #commit_list)
    print("")
    local modified = index.get_modified(repo_path)
    if #modified > 0 then
        print("Modified files:")
        for _, m in ipairs(modified) do
            print("  " .. m)
        end
    else
        print("Working directory clean")
    end
    print("")
    local snapshots = storage.list_snapshots(repo_path)
    print("Snapshots: " .. #snapshots)
    return 0
end

return cmd