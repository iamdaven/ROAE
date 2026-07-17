local ChangeDetector = {}

function ChangeDetector.detect_changes(old_data, new_data)
    if old_data == new_data then
        return {changed = false, changes = {}}
    end
    local changes = {changed = true, added = {}, removed = {}, modified = {}}
    local old_tree = ChangeDetector.build_tree(old_data)
    local new_tree = ChangeDetector.build_tree(new_data)
    for path, old_val in pairs(old_tree) do
        if not new_tree[path] then
            changes.removed[#changes.removed + 1] = path
        elseif old_val ~= new_tree[path] then
            changes.modified[#changes.modified + 1] = path
        end
    end
    for path, new_val in pairs(new_tree) do
        if not old_tree[path] then
            changes.added[#changes.added + 1] = path
        end
    end
    changes.total = #changes.added + #changes.removed + #changes.modified
    return changes
end

function ChangeDetector.build_tree(data)
    local tree = {}
    local function traverse(obj, path)
        local current = path .. "/" .. obj.name .. ":" .. obj.class_name
        tree[current] = obj.contents or ""
        if obj.properties then
            for k, v in pairs(obj.properties) do
                tree[current .. "." .. k] = tostring(v)
            end
        end
        if obj.children then
            for _, child in ipairs(obj.children) do
                traverse(child, current)
            end
        end
    end
    if type(data) == "table" then
        for _, obj in ipairs(data) do
            traverse(obj, "")
        end
    end
    return tree
end

function ChangeDetector.get_summary(changes)
    return {
        added = #changes.added,
        removed = #changes.removed,
        modified = #changes.modified,
        total = changes.total
    }
end

return ChangeDetector