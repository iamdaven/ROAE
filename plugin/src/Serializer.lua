local Serializer = {}

function Serializer.serialize_instance(instance)
    local data = {
        class_name = instance.ClassName,
        name = instance.Name,
        properties = {},
        attributes = {},
        children = {},
        contents = nil
    }
    for _, prop in ipairs(instance:GetProperties()) do
        local ok, val = pcall(function()
            return instance[prop.Name]
        end)
        if ok then
            data.properties[prop.Name] = tostring(val)
        end
    end
    for _, attr in ipairs(instance:GetAttributes()) do
        data.attributes[attr.Name] = tostring(attr.Value)
    end
    if instance:IsA("LuaSourceContainer") then
        data.contents = instance.Source
    end
    for _, child in ipairs(instance:GetChildren()) do
        data.children[#data.children + 1] = Serializer.serialize_instance(child)
    end
    return data
end

function Serializer.deserialize_instance(data, parent)
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
        Serializer.deserialize_instance(child_data, instance)
    end
    return instance
end

return Serializer