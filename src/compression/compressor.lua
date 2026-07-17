local compressor = {}

local MIN_RUN = 4
local MAX_RUN = 65535

local function build_dictionary(data)
    local freq = {}
    for i = 1, #data - 3 do
        local pattern = string.sub(data, i, i + 3)
        freq[pattern] = (freq[pattern] or 0) + 1
    end
    local list = {}
    for pattern, count in pairs(freq) do
        if count >= 3 then
            table.insert(list, {pattern = pattern, count = count})
        end
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    local dict = {}
    for i = 1, math.min(16, #list) do
        table.insert(dict, list[i].pattern)
    end
    return dict
end

function compressor.compress(data)
    if not data or #data == 0 then
        return ""
    end
    local dict = build_dictionary(data)
    local parts = {}
    local pos = 1
    local n = #data
    parts[#parts + 1] = string.char(0x52, 0x4F, 0x41, 0x45)
    parts[#parts + 1] = string.char(#dict)
    for _, entry in ipairs(dict) do
        parts[#parts + 1] = string.char(string.byte(entry, 1, 4))
    end
    local size = n
    parts[#parts + 1] = string.char(size & 0xFF, (size >> 8) & 0xFF, (size >> 16) & 0xFF, (size >> 24) & 0xFF)
    while pos <= n do
        local remaining = n - pos + 1
        local byte = string.byte(data, pos)
        if byte == 0 and remaining >= MIN_RUN then
            local run_len = 0
            while pos + run_len <= n and string.byte(data, pos + run_len) == 0 and run_len < MAX_RUN do
                run_len = run_len + 1
            end
            if run_len >= MIN_RUN then
                if run_len <= 255 then
                    parts[#parts + 1] = string.char(0x84, run_len)
                else
                    parts[#parts + 1] = string.char(0x82, 0)
                    parts[#parts + 1] = string.char(run_len & 0xFF, (run_len >> 8) & 0xFF)
                end
                pos = pos + run_len
                goto next
            end
        end
        if remaining >= MIN_RUN then
            local run_len = 0
            while pos + run_len <= n and string.byte(data, pos + run_len) == byte and run_len < MAX_RUN do
                run_len = run_len + 1
            end
            if run_len >= MIN_RUN then
                if run_len <= 255 then
                    parts[#parts + 1] = string.char(0x81, run_len, byte)
                else
                    parts[#parts + 1] = string.char(0x82, 1)
                    parts[#parts + 1] = string.char(run_len & 0xFF, (run_len >> 8) & 0xFF, byte)
                end
                pos = pos + run_len
                goto next
            end
        end
        if remaining >= 4 then
            local four = string.sub(data, pos, pos + 3)
            for i, entry in ipairs(dict) do
                if entry == four then
                    parts[#parts + 1] = string.char(0x83, i - 1)
                    pos = pos + 4
                    goto next
                end
            end
        end
        local start = pos
        local count = 0
        while pos <= n and count < 127 do
            if count >= 3 then
                local remaining2 = n - pos + 1
                if remaining2 >= MIN_RUN then
                    local b = string.byte(data, pos)
                    local run = 1
                    while run < remaining2 and string.byte(data, pos + run) == b do
                        run = run + 1
                    end
                    if run >= MIN_RUN then
                        break
                    end
                end
            end
            count = count + 1
            pos = pos + 1
        end
        parts[#parts + 1] = string.char(count)
        parts[#parts + 1] = string.sub(data, start, start + count - 1)
        ::next::
    end
    parts[#parts + 1] = string.char(0xFF)
    local checksum = 0
    for i = 1, n do
        checksum = checksum + string.byte(data, i)
        checksum = checksum & 0xFFFFFFFF
    end
    local cs = checksum
    parts[#parts + 1] = string.char(cs & 0xFF, (cs >> 8) & 0xFF, (cs >> 16) & 0xFF, (cs >> 24) & 0xFF)
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