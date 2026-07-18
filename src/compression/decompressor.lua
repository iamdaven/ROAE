local decompressor = {}

local MAGIC = {0x52, 0x4F, 0x41, 0x45}

local function check_magic(data, pos)
    for i = 1, 4 do
        if string.byte(data, pos + i - 1) ~= MAGIC[i] then
            return false
        end
    end
    return true
end

local function read_u32(data, pos)
    local b1 = string.byte(data, pos)
    local b2 = string.byte(data, pos + 1)
    local b3 = string.byte(data, pos + 2)
    local b4 = string.byte(data, pos + 3)
    return b1 | (b2 << 8) | (b3 << 16) | (b4 << 24)
end

local function read_u16(data, pos)
    local b1 = string.byte(data, pos)
    local b2 = string.byte(data, pos + 1)
    return b1 | (b2 << 8)
end

function decompressor.decompress(data)
    if not data or #data == 0 then
        return ""
    end
    local pos = 1
    local n = #data
    if not check_magic(data, pos) then
        return nil, "bad magic"
    end
    pos = pos + 4
    local dict_size = string.byte(data, pos)
    pos = pos + 1
    local dict = {}
    for i = 1, dict_size do
        local b1 = string.byte(data, pos)
        local b2 = string.byte(data, pos + 1)
        local b3 = string.byte(data, pos + 2)
        local b4 = string.byte(data, pos + 3)
        dict[i - 1] = {b1, b2, b3, b4}
        pos = pos + 4
    end
    local orig_size = read_u32(data, pos)
    pos = pos + 4
    local parts = {}
    while pos <= n do
        local token = string.byte(data, pos)
        pos = pos + 1
        if token == 0xFF then
            break
        end
        if token < 0x80 then
            local count = token
            if count > 0 then
                parts[#parts + 1] = string.sub(data, pos, pos + count - 1)
                pos = pos + count
            end
        elseif token == 0x81 then
            -- Short run of same byte
            local run_len = string.byte(data, pos)
            pos = pos + 1
            local val = string.byte(data, pos)
            pos = pos + 1
            parts[#parts + 1] = string.rep(string.char(val), run_len)
        elseif token == 0x82 then
            -- Long run of same byte
            local kind = string.byte(data, pos)
            pos = pos + 1
            local run_len = read_u16(data, pos)
            pos = pos + 2
            if kind == 0 then
                -- Zero run
                parts[#parts + 1] = string.rep(string.char(0), run_len)
            else
                local val = string.byte(data, pos)
                pos = pos + 1
                parts[#parts + 1] = string.rep(string.char(val), run_len)
            end
        elseif token == 0x83 then
            -- Dictionary reference
            local idx = string.byte(data, pos)
            pos = pos + 1
            local entry = dict[idx]
            if entry then
                parts[#parts + 1] = string.char(entry[1], entry[2], entry[3], entry[4])
            else
                return nil, "bad dict ref " .. idx
            end
        elseif token == 0x84 then
            -- Short zero run (was redundant with 0x82 kind=0, but kept for compat)
            local run_len = string.byte(data, pos)
            pos = pos + 1
            parts[#parts + 1] = string.rep(string.char(0), run_len)
        else
            return nil, "bad token " .. token
        end
    end
    local result = table.concat(parts)
    -- Verify checksum if present
    local checksum_pos = n - 3
    if checksum_pos > pos then
        local stored = read_u32(data, checksum_pos)
        local actual = 0
        for i = 1, #result do
            actual = actual + string.byte(result, i)
            actual = actual & 0xFFFFFFFF
        end
        if actual ~= stored then
            return nil, "integrity fail"
        end
    end
    return result
end

function decompressor.is_compressed(data)
    if not data or #data < 4 then
        return false
    end
    return check_magic(data, 1)
end

return decompressor