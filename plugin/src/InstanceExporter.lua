local InstanceExporter = {}

function InstanceExporter.export_project(root)
    local data = {
        class_name = root.ClassName,
        name = root.Name,
        properties = {},
        attributes = {},
        children = {},
        contents = nil
    }
    for _, prop in ipairs(root:GetProperties()) do
        local ok, val = pcall(function()
            return root[prop.Name]
        end)
        if ok then
            data.properties[prop.Name] = tostring(val)
        end
    end
    for _, attr in ipairs(root:GetAttributes()) do
        data.attributes[attr.Name] = tostring(attr.Value)
    end
    if root:IsA("LuaSourceContainer") then
        data.contents = root.Source
    end
    for _, child in ipairs(root:GetChildren()) do
        data.children[#data.children + 1] = InstanceExporter.export_project(child)
    end
    return data
end

function InstanceExporter.import_project(data, parent)
    local instance = Instance.new(data.class_name)
    instance.Name = data.name
    for k, v in pairs(data.properties) do
        pcall(function()
            instance[k] = v
        end)
    end
    for k, v in pairs(data.attributes) do
        instance:SetAttribute(k, v)
    end
    if data.contents and instance:IsA("LuaSourceContainer") then
        instance.Source = data.contents
    end
    instance.Parent = parent
    for _, child_data in ipairs(data.children) do
        InstanceExporter.import_project(child_data, instance)
    end
    return instance
end

return InstanceExporter