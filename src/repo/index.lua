local index = {}

function index.load(repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/.roae/index"
    local f = io.open(filepath, "r")
    if not f then
        return {}
    end
    local entries = {}
    local section = nil
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line and #line > 0 and not line:match("^#") then
            if line:match("^%[") then
                section = line:match("^%[(.-)%]$")
            else
                entries[#entries + 1] = {section = section, data = line}
            end
        end
    end
    f:close()
    return entries
end

function index.save(entries, repo_path)
    repo_path = repo_path or "."
    local filepath = repo_path .. "/.roae/index"
    local f, err = io.open(filepath, "w")
    if not f then
        return nil, err
    end
    f:write("# ROAE Index\n\n")
    local groups = {}
    for _, entry in ipairs(entries) do
        local s = entry.section or "objects"
        if not groups[s] then groups[s] = {} end
        groups[s][#groups[s] + 1] = entry.data or entry
    end
    for s, items in pairs(groups) do
        f:write("[" .. s .. "]\n")
        for _, item in ipairs(items) do
            f:write(tostring(item) .. "\n")
        end
        f:write("\n")
    end
    f:close()
    return true
end

function index.add(section, data, repo_path)
    local entries = index.load(repo_path)
    entries[#entries + 1] = {section = section, data = data}
    return index.save(entries, repo_path)
end

function index.get_section(section_name, repo_path)
    local entries = index.load(repo_path)
    local results = {}
    for _, entry in ipairs(entries) do
        if entry.section == section_name then
            results[#results + 1] = entry.data
        end
    end
    return results
end

function index.clear_section(section_name, repo_path)
    local entries = index.load(repo_path)
    local keep = {}
    for _, entry in ipairs(entries) do
        if entry.section ~= section_name then
            keep[#keep + 1] = entry
        end
    end
    return index.save(keep, repo_path)
end

function index.get_modified(repo_path)
    return index.get_section("modified", repo_path)
end

function index.clear_modified(repo_path)
    return index.clear_section("modified", repo_path)
end

function index.stage(object_hash, repo_path)
    return index.add("staged", object_hash, repo_path)
end

function index.get_staged(repo_path)
    return index.get_section("staged", repo_path)
end

function index.clear_staged(repo_path)
    return index.clear_section("staged", repo_path)
end

return index