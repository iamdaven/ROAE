local config = require("src.repo.config")

local repo_init = {}

function repo_init.init(repo_name, author)
    local path = "."
    local roae_dir = path .. "/.roae"
    if config.is_repo(path) then
        return nil, "already a repo"
    end
    local dirs = {
        roae_dir, roae_dir .. "/refs", roae_dir .. "/snapshots",
        roae_dir .. "/commits", roae_dir .. "/objects", roae_dir .. "/refs/heads"
    }
    for _, dir in ipairs(dirs) do
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '" 2>nul')
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
    local cfg = config.create_defaults(repo_name, author)
    local ok, err = config.save(cfg, path)
    if not ok then
        return nil, err
    end
    config.write_head("refs/heads/main", path)
    local f = io.open(roae_dir .. "/index", "w")
    if f then
        f:write("# ROAE Index\n\n[objects]\n\n")
        f:close()
    end
    f = io.open(roae_dir .. "/log", "w")
    if f then
        f:write("# ROAE Log\n# " .. os.date() .. "\n\n")
        f:close()
    end
    return true, "initialized empty repo in " .. roae_dir
end

function repo_init.status(repo_path)
    repo_path = repo_path or "."
    if not config.is_repo(repo_path) then
        return nil, "not a repo"
    end
    return config.load(repo_path)
end

return repo_init