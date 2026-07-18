local compressor = {}

local MIN_RUN = 4
local MAX_RUN = 65535
local MAX_DICT_ENTRIES = 16

local function build_dictionary(data)
    local freq = {}
    local n = #data
    for i = 1, n - 3 do
        local pattern = string.sub(data, i, i + 3)
        freq[pattern] = (freq[pattern] or 0) + 1
    end
    local list = {}
    for pattern, count in pairs(freq) do
        if count >= 3 then
            list[#list + 1] = {pattern = pattern, count = count}
        end
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    local dict = {}
    for i = 1, math.min(MAX_DICT_ENTRIES, #list) do
        dict[i] = list[i].pattern
    end
    return dict
end

local function write_varint(parts, value)
    parts[#parts + 1] = string.char(value & 0xFF, (value >> 8) & 0xFF)
end

function compressor.compress(data)
    if not data or #data == 0 then
        return ""
    end
    local dict = build_dictionary(data)
    local parts = {}
    local pos = 1
    local n = #data
    -- Magic header
    parts[#parts + 1] = string.char(0x52, 0x4F, 0x41, 0x45)
    -- Dictionary
    parts[#parts + 1] = string.char(#dict)
    for _, entry in ipairs(dict) do
        parts[#parts + 1] = string.char(string.byte(entry, 1, 4))
    end
    -- Original size
    parts[#parts + 1] = string.char(n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF)

    while pos <= n do
        local remaining = n - pos + 1
        local byte = string.byte(data, pos)

        -- Check for long zero run
        if byte == 0 and remaining >= 4 then
            local run_len = 0
            while pos + run_len <= n and string.byte(data, pos + run_len) == 0 and run_len < MAX_RUN do
                run_len = run_len + 1
            end
            if run_len >= 4 then
                if run_len <= 255 then
                    parts[#parts + 1] = string.char(0x84, run_len)
                else
                    parts[#parts + 1] = string.char(0x82, 0)
                    parts[#parts + 1] = string.char(run_len & 0xFF, (run_len >> 8) & 0xFF)
                end
                pos = pos + run_len
                goto continue
            end
        end

        -- Check for run of same non-zero byte
        if remaining >= 4 then
            local run_len = 1
            while pos + run_len <= n and string.byte(data, pos + run_len) == byte and run_len < MAX_RUN do
                run_len = run_len + 1
            end
            if run_len >= 4 then
                if run_len <= 255 then
                    parts[#parts + 1] = string.char(0x81, run_len, byte)
                else
                    parts[#parts + 1] = string.char(0x82, 1)
                    parts[#parts + 1] = string.char(run_len & 0xFF, (run_len >> 8) & 0xFF, byte)
                end
                pos = pos + run_len
                goto continue
            end
        end

        -- Check for dictionary match
        if remaining >= 4 then
            local four = string.sub(data, pos, pos + 3)
            for i = 1, #dict do
                if dict[i] == four then
                    parts[#parts + 1] = string.char(0x83, i - 1)
                    pos = pos + 4
                    goto continue
                end
            end
        end

        -- Literal run
        local start = pos
        local count = 0
        while pos <= n and count < 127 do
            -- Look ahead to avoid breaking a potential run
            if remaining > 3 then
                local next_byte = string.byte(data, pos)
                local look_ahead = pos + 1
                local potential_run = 1
                while look_ahead <= n and string.byte(data, look_ahead) == next_byte and potential_run < 4 do
                    potential_run = potential_run + 1
                    look_ahead = look_ahead + 1
                end
                if potential_run >= 4 then
                    break
                end
            end
            count = count + 1
            pos = pos + 1
        end
        parts[#parts + 1] = string.char(count)
        parts[#parts + 1] = string.sub(data, start, pos - 1)
        ::continue::
    end

    -- End marker
    parts[#parts + 1] = string.char(0xFF)
    -- Checksum
    local checksum = 0
    for i = 1, n do
        checksum = checksum + string.byte(data, i)
        checksum = checksum & 0xFFFFFFFF
    end
    parts[#parts + 1] = string.char(checksum & 0xFF, (checksum >> 8) & 0xFF, (checksum >> 16) & 0xFF, (checksum >> 24) & 0xFF)
    return table.concat(parts)
end

function compressor.verify_integrity(data, checksum_value)
    local actual = 0
    for i = 1, #data do
        actual = actual + string.byte(data, i)
        actual = actual & 0xFFFFFFFF
    end
    return actual == checksum_value, checksum_value, actual
end

function compressor.compute_checksum(data)
    local checksum = 0
    for i = 1, #data do
        checksum = checksum + string.byte(data, i)
        checksum = checksum & 0xFFFFFFFF
    end
    return checksum
end

return compressor