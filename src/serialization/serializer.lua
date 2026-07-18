local serializer = {}

local function escape(str)
    if not str then return "" end
    return str:gsub("\\", "\\\\"):gsub("|", "\\p"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

local function unescape(str)
    if not str then return "" end
    return str:gsub("\\t", "\t"):gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\\p", "|"):gsub("\\\\", "\\")
end

local TYPE_MAP = {
    string = "s",
    number = "n",
    boolean = "b"
}

local function pack_value(value)
    local t = type(value)
    if t == "string" then return "s:" .. escape(value) end
    if t == "number" then
        if value % 1 == 0 and math.abs(value) < 9007199254740992 then
            return "i:" .. tostring(value)
        end
        return "f:" .. tostring(value)
    end
    if t == "boolean" then return "b:" .. tostring(value) end
    if t == "table" then
        local keys = {}
        for k in pairs(value) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = escape(tostring(k)) .. "=" .. escape(tostring(value[k]))
        end
        if #parts > 0 then
            return "t:{" .. table.concat(parts, ",") .. "}"
        end
        return "t:{}"
    end
    if t == "nil" then return "n:" end
    return "s:" .. escape(tostring(value))
end

local function unpack_value(str)
    if not str or #str < 2 then return nil end
    local prefix = str:sub(1, 2)
    local val = str:sub(3)
    if prefix == "s:" then return unescape(val) end
    if prefix == "i:" or prefix == "f:" then return tonumber(val) end
    if prefix == "b:" then return val == "true" end
    if prefix == "n:" then return nil end
    if prefix == "t:" then
        local t = {}
        local inner = val:match("^{(.-)}$")
        if inner and #inner > 0 then
            for pair in inner:gmatch("[^,]+") do
                local eq = pair:find("=", 1, true)
                if eq then
                    t[unescape(pair:sub(1, eq - 1))] = unescape(pair:sub(eq + 1))
                end
            end
        end
        return t
    end
    return unescape(str)
end

local function serialize_obj(object, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local lines = {}
    local n = 0
    local cn = object.class_name or "Unknown"
    local ot = serializer.classify(cn)
    local nm = object.name or ""
    n = n + 1; lines[n] = pad .. "@" .. ot .. "|" .. escape(cn) .. "|" .. escape(nm)
    if object.properties then
        n = n + 1; lines[n] = pad .. ">props"
        for k, v in pairs(object.properties) do
            n = n + 1; lines[n] = pad .. "=" .. escape(k) .. "|" .. pack_value(v)
        end
        n = n + 1; lines[n] = pad .. "<props"
    end
    if object.attributes then
        n = n + 1; lines[n] = pad .. ">attrs"
        for k, v in pairs(object.attributes) do
            n = n + 1; lines[n] = pad .. "=" .. escape(k) .. "|" .. pack_value(v)
        end
        n = n + 1; lines[n] = pad .. "<attrs"
    end
    if object.contents then
        n = n + 1; lines[n] = pad .. ">contents"
        for line in object.contents:gmatch("[^\r\n]+") do
            n = n + 1; lines[n] = pad .. "|" .. escape(line)
        end
        n = n + 1; lines[n] = pad .. "<contents"
    end
    if object.children and #object.children > 0 then
        n = n + 1; lines[n] = pad .. ">children"
        for _, child in ipairs(object.children) do
            local child_lines = serialize_obj(child, indent + 1)
            for _, line in ipairs(child_lines) do
                n = n + 1; lines[n] = line
            end
        end
        n = n + 1; lines[n] = pad .. "<children"
    end
    n = n + 1; lines[n] = pad .. "~end"
    return lines
end

function serializer.serialize_object(object, indent)
    return serialize_obj(object, indent)
end

function serializer.serialize_project(objects)
    local lines = {}
    local n = 0
    n = n + 1; lines[n] = "ROAE_SER:1"
    n = n + 1; lines[n] = "#ROAE Serialization"
    n = n + 1; lines[n] = "#" .. os.date("%Y-%m-%d %H:%M:%S")
    n = n + 1; lines[n] = "#Objects: " .. #objects
    n = n + 1; lines[n] = ""
    for _, obj in ipairs(objects) do
        local obj_lines = serialize_obj(obj, 0)
        for _, line in ipairs(obj_lines) do
            n = n + 1; lines[n] = line
        end
    end
    n = n + 1; lines[n] = ""
    n = n + 1; lines[n] = "~eof"
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
        local tag = trimmed
        if tag == ">props" then
            i = i + 1
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<props" then i = i + 1; break end
                local k, v = line:match("^%s*=(.-)|(.*)$")
                if k and v then obj.properties[unescape(k)] = unpack_value(v) end
                i = i + 1
            end
        elseif tag == ">attrs" then
            i = i + 1
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<attrs" then i = i + 1; break end
                local k, v = line:match("^%s*=(.-)|(.*)$")
                if k and v then obj.attributes[unescape(k)] = unpack_value(v) end
                i = i + 1
            end
        elseif tag == ">contents" then
            i = i + 1
            local content = {}
            local cn = 0
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<contents" then i = i + 1; break end
                local c = line:match("^%s*|(.*)$")
                if c then cn = cn + 1; content[cn] = unescape(c) end
                i = i + 1
            end
            obj.contents = table.concat(content, "\n")
        elseif tag == ">children" then
            i = i + 1
            while i <= #lines do
                line = lines[i]
                local t = line:match("^%s*(.-)%s*$")
                if t == "<children" then i = i + 1; break end
                local child, next_i = parse_obj(lines, i)
                if child then obj.children[#obj.children + 1] = child end
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
    local n = 0
    for line in data:gmatch("[^\n]+") do
        n = n + 1; lines[n] = line
    end
    if n < 1 then return nil, "empty" end
    if not lines[1]:match("^ROAE_SER:") then return nil, "bad header" end
    local objects = {}
    local i = 2
    while i <= n do
        local line = lines[i]
        if line:match("^#") or line:match("^%s*$") then
            i = i + 1
        elseif line:match("^~eof$") then
            break
        elseif line:match("^@") then
            local obj, next_i = parse_obj(lines, i)
            if obj then objects[#objects + 1] = obj end
            i = next_i
        else
            i = i + 1
        end
    end
    return objects
end

function serializer.classify(cn)
    if cn == "Folder" then return "F" end
    if cn == "Script" then return "S" end
    if cn == "ModuleScript" then return "M" end
    if cn == "LocalScript" then return "L" end
    if cn == "Part" then return "P" end
    if cn == "Model" then return "O" end
    if cn == "Tool" then return "T" end
    if cn == "StringValue" then return "V" end
    if cn == "NumberValue" or cn == "IntValue" then return "V" end
    if cn == "BoolValue" or cn == "ObjectValue" then return "V" end
    if cn == "Animation" then return "A" end
    if cn == "Sound" then return "N" end
    -- GUI types
    local gui_types = {ScreenGui = true, Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true}
    if gui_types[cn] then return "U" end
    return "X"
end

function serializer.create_object(cn, name, props, contents)
    return {class_name = cn, name = name or "", properties = props or {}, attributes = {}, children = {}, contents = contents}
end

function serializer.compute_tree_hash(object)
    local parts = {}
    parts[1] = object.class_name or "?"
    parts[2] = object.name or "?"
    local idx = 3
    if object.properties then
        local keys = {}
        for k in pairs(object.properties) do
            keys[#keys + 1] = k
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            idx = idx + 1; parts[idx] = k .. "=" .. tostring(object.properties[k])
        end
    end
    if object.contents then
        idx = idx + 1; parts[idx] = "len=" .. #object.contents
        idx = idx + 1; parts[idx] = "head=" .. object.contents:sub(1, math.min(50, #object.contents))
    end
    if object.children then
        for _, child in ipairs(object.children) do
            idx = idx + 1; parts[idx] = serializer.compute_tree_hash(child)
        end
    end
    return table.concat(parts, "|")
end

return serializer