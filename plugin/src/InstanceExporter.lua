local InstanceExporter = {}
local Serializer = require(script.Serializer)

function InstanceExporter.export_project(root)
    return Serializer.serialize_instance(root)
end

function InstanceExporter.import_project(data, parent)
    return Serializer.deserialize_instance(data, parent)
end

return InstanceExporter