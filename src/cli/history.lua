local cmd = {}
local history = require("src.commit.history")

cmd.name = "history"
cmd.description = "Display commit history"

function cmd.execute(args)
    local repo_path = args[1] or "."
    local limit = tonumber(args[2]) or 10
    local commits = history.get_history(repo_path, limit)
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