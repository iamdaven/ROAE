local serializer = {}

local function escape(str)
    if not str then return "" end
    str = str:gsub("\\", "\\\\")
    str = str:gsub("|", "\\p")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")
    return str
end

local function unescape(str)
    if not str then return "" end
    str = str:gsub("\\t", "\t")
    str = str:gsub("\\r", "\r")
    str = str:gsub("\\n", "\n")
    str = str:gsub("\\p", "|")
    str = str:gsub("\\\\", "\\")
    return str
end

local function pack_value(value)
    local t = type(value)
    if t == "string" then
        return "s:" .. escape(value)
    elseif t == "number" then
        if value % 1 == 0 and math.abs(value) < 9007199254740992 then
            return "i:" .. tostring(value)
        else
            return "f:" .. tostring(value)
        end
    elseif t == "boolean" then
        return "b:" .. tostring(value)
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(value) do
            parts[#parts + 1] = escape(tostring(k)) .. "=" .. escape(tostring(v))
        end
        if #parts > 0 then
            return "t:{" .. table.concat(parts, ",") .. "}"
        else
            return "t:{}"
        end
    elseif t == "nil" then
        return "n:"
    else
        return "s:" .. escape(tostring(value))
    end
end

local function unpack_value(str)
    if not str or #str < 2 then
        return nil
    end
    local prefix = str:sub(1, 2)
    local val = str:sub(3)
    if prefix == "s:" then
        return unescape(val)
    elseif prefix == "i:" then
        return tonumber(val)
    elseif prefix == "f:" then
        return tonumber(val)
    elseif prefix == "b:" then
        return val == "true"
    elseif prefix == "n:" then
        return nil
    elseif prefix == "t:" then
        local t = {}
        local inner = val:match("^{(.-)}$")
        if inner and #inner > 0 then
            for pair in inner:gmatch("[^,]+") do
                local eq = pair:find("=")
                if eq then
                    t[unescape(pair:sub(1, eq - 1))] = unescape(pair:sub(eq + 1))
                end
            end
        end
        return t
    else
        return unescape(str)
    end
end

local function serialize_obj(object, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local lines = {}
    local cn = object.class_name or "Unknown"
    local ot = serializer.classify(cn)
    local nm = object.name or ""
    lines[#lines + 1] = pad .. "@" .. ot .. "|" .. escape(cn) .. "|" .. escape(nm)
    if object.properties then
        lines[#lines + 1] = pad .. ">props"
        for k, v in pairs(object.properties) do
            lines[#lines + 1] = pad .. "=" .. escape(k) .. "|" .. pack_value(v)
        end
        lines[#lines + 1] = pad .. "<props"
    end
    if object.attributes then
        lines[#lines + 1] = pad .. ">attrs"
        for k, v in pairs(object.attributes) do
            lines[#lines + 1] = pad .. "=" .. escape(k) .. "|" .. pack_value(v)
        end
        lines[#lines + 1] = pad .. "<attrs"
    end
    if object.contents then
        lines[#lines + 1] = pad .. ">contents"
        for line in object.contents:gmatch("[^\r\n]+") do
            lines[#lines + 1] = pad .. "|" .. escape(line)
        end
        lines[#lines + 1] = pad .. "<contents"
    end
    if object.children and #object.children > 0 then
        lines[#lines + 1] = pad .. ">children"
        for _, child in ipairs(object.children) do
            local child_lines = serialize_obj(child, indent + 1)
            for _, line in ipairs(child_lines) do
                lines[#lines + 1] = line
            end
        end
        lines[#lines + 1] = pad .. "<children"
    end
    lines[#lines + 1] = pad .. "~end"
    return lines
end

function serializer.serialize_object(object, indent)
    return serialize_obj(object, indent)
end

function serializer.serialize_project(objects)
    local lines = {}
    lines[#lines + 1] = "ROAE_SER:1"
    lines[#lines + 1] = "#ROAE Serialization"
    lines[#lines + 1] = "#" .. os.date("%Y-%m-%d %H:%M:%S")
    lines[#lines + 1] = "#Objects: " .. #objects
    lines[#lines + 1] = ""
    for _, obj in ipairs(objects) do
        local obj_lines = serialize_obj(obj, 0)
        for _, line in ipairs(obj_lines) do
            lines[#lines + 1] = line
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "~eof"
    return table.concat(lines, "\n")
end

local function parse_obj(lines, start)
    local obj = {class_name = "Unknown", name = "", properties = {}, attributes = {}, children = {}, contents = nil}
    local i = start
    local line = lines[i]
    local obj_type, cn, nm = line:match("^%s*@(.)|([^|]*)|(.*)$")
    if not obj_type then
        return nil, i + 1
    end
    obj.class_name = unescape(cn)
    obj.name = unescape(nm)
    i = i + 1
    while i <= #lines do
        line = lines[i]
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed == "~end" then
            i = i + 1
            break
        end
        if trimmed == ">props" then
            i = i + 1
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<props" then
                    i = i + 1
                    break
                end
                local k, v = line:match("^%s*=(.-)|(.*)$")
                if k and v then
                    obj.properties[unescape(k)] = unpack_value(v)
                end
                i = i + 1
            end
        elseif trimmed == ">attrs" then
            i = i + 1
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<attrs" then
                    i = i + 1
                    break
                end
                local k, v = line:match("^%s*=(.-)|(.*)$")
                if k and v then
                    obj.attributes[unescape(k)] = unpack_value(v)
                end
                i = i + 1
            end
        elseif trimmed == ">contents" then
            i = i + 1
            local content = {}
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<contents" then
                    i = i + 1
                    break
                end
                local c = line:match("^%s*|(.*)$")
                if c then
                    content[#content + 1] = unescape(c)
                end
                i = i + 1
            end
            obj.contents = table.concat(content, "\n")
        elseif trimmed == ">children" then
            i = i + 1
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<children" then
                    i = i + 1
                    break
                end
                local child, next_i = parse_obj(lines, i)
                if child then
                    obj.children[#obj.children + 1] = child
                end
                i = next_i
            end
        else
            i = i + 1
        end
    end
    return obj, i
end

function serializer.deserialize_project(data)
    if not data or #data == 0 then
        return nil, "empty"
    end
    local lines = {}
    for line in data:gmatch("[^\n]+") do
        lines[#lines + 1] = line
    end
    if #lines < 1 then
        return nil, "empty"
    end
    if not lines[1]:match("^ROAE_SER:") then
        return nil, "bad header"
    end
    local objects = {}
    local i = 2
    while i <= #lines do
        local line = lines[i]
        if line:match("^#") or line:match("^%s*$") then
            i = i + 1
        elseif line:match("^~eof$") then
            break
        elseif line:match("^@") then
            local obj, next_i = parse_obj(lines, i)
            if obj then
                objects[#objects + 1] = obj
            end
            i = next_i
        else
            i = i + 1
        end
    end
    return objects
end

function serializer.classify(cn)
    local map = {
        Folder = "F", Script = "S", ModuleScript = "M", LocalScript = "L",
        Part = "P", Model = "O", Tool = "T",
        ScreenGui = "U", Frame = "U", TextLabel = "U", TextButton = "U",
        ImageLabel = "U", ImageButton = "U", ScrollingFrame = "U",
        StringValue = "V", NumberValue = "V", BoolValue = "V", IntValue = "V", ObjectValue = "V",
        Animation = "A", Sound = "N"
    }
    return map[cn] or "X"
end

function serializer.create_object(cn, name, props, contents)
    return {class_name = cn, name = name or "", properties = props or {}, attributes = {}, children = {}, contents = contents}
end

function serializer.compute_tree_hash(object)
    local parts = {}
    parts[#parts + 1] = object.class_name or "?"
    parts[#parts + 1] = object.name or "?"
    if object.properties then
        local keys = {}
        for k in pairs(object.properties) do
            keys[#keys + 1] = k
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = k .. "=" .. tostring(object.properties[k])
        end
    end
    if object.contents then
        parts[#parts + 1] = "len=" .. #object.contents
        parts[#parts + 1] = "head=" .. object.contents:sub(1, math.min(50, #object.contents))
    end
    if object.children then
        for _, child in ipairs(object.children) do
            parts[#parts + 1] = serializer.compute_tree_hash(child)
        end
    end
    return table.concat(parts, "|")
end

return serializer