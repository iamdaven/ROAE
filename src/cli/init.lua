local cmd = {}
local repo_init = require("src.repo.init")

cmd.name = "init"
cmd.description = "Initialize a new ROAE repository"

function cmd.execute(args)
    local repo_name = args[1] or "MyRobloxGame"
    local author = args[2] or os.getenv("USERNAME") or os.getenv("USER") or "unknown"
    local ok, msg = repo_init.init(repo_name, author)
    if not ok then
        print("Error: " .. msg)
        return 1
    end
    print(msg)
    return 0
end

return cmd