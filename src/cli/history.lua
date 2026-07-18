local cmd = {}
local history_mod = require("src.commit.history")
local config = require("src.repo.config")

cmd.name = "history"
cmd.description = "Display commit history"

function cmd.execute(args)
    local repo_path = config.find_root(".")
    if not repo_path then
        print("Error: not a ROAE repository")
        return 1
    end
    local limit = tonumber(args[1]) or 10
    local commits = history_mod.get_history(repo_path, limit)
    if #commits == 0 then
        print("No commits yet")
        return 0
    end
    for i, c in ipairs(commits) do
        print("")
        print("commit " .. c.short_id)
        print("Author: " .. c.author)
        print("Date: " .. c.timestamp)
        print("")
        print("    " .. c.message)
    end
    print("")
    print(#commits .. " commit(s)")
    return 0
end

return cmd