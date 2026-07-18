local sha256 = {}

local H = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
}

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function rotate_right(x, n)
    return ((x >> n) | (x << (32 - n))) & 0xffffffff
end

local function shift_right(x, n)
    return x >> n
end

local function sum0(x)
    return rotate_right(x, 2) ~ rotate_right(x, 13) ~ rotate_right(x, 22)
end

local function sum1(x)
    return rotate_right(x, 6) ~ rotate_right(x, 11) ~ rotate_right(x, 25)
end

local function sigma0(x)
    return rotate_right(x, 7) ~ rotate_right(x, 18) ~ shift_right(x, 3)
end

local function sigma1(x)
    return rotate_right(x, 17) ~ rotate_right(x, 19) ~ shift_right(x, 10)
end

local function pad_message(bytes)
    local len = #bytes
    local bit_len = len * 8
    bytes[#bytes + 1] = 0x80
    while (#bytes % 64) ~= 56 do
        bytes[#bytes + 1] = 0
    end
    for i = 7, 0, -1 do
        bytes[#bytes + 1] = (bit_len >> (i * 8)) & 0xff
    end
    return bytes
end

local function compress(state, block)
    local w = {}
    for t = 1, 16 do
        local idx = (t - 1) * 4 + 1
        w[t] = (block[idx] << 24) | (block[idx + 1] << 16) | (block[idx + 2] << 8) | block[idx + 3]
    end
    for t = 17, 64 do
        w[t] = (sigma1(w[t - 2]) + w[t - 7] + sigma0(w[t - 15]) + w[t - 16]) & 0xffffffff
    end
    local a, b, c, d, e, f, g, h = state[1], state[2], state[3], state[4], state[5], state[6], state[7], state[8]
    for t = 1, 64 do
        local not_e = (~e) & 0xffffffff
        local T1 = (h + sum1(e) + ((e & f) ~ (not_e & g)) + K[t] + w[t]) & 0xffffffff
        local T2 = (sum0(a) + ((a & b) ~ (a & c) ~ (b & c))) & 0xffffffff
        h = g; g = f; f = e
        e = (d + T1) & 0xffffffff
        d = c; c = b; b = a
        a = (T1 + T2) & 0xffffffff
    end
    state[1] = (state[1] + a) & 0xffffffff
    state[2] = (state[2] + b) & 0xffffffff
    state[3] = (state[3] + c) & 0xffffffff
    state[4] = (state[4] + d) & 0xffffffff
    state[5] = (state[5] + e) & 0xffffffff
    state[6] = (state[6] + f) & 0xffffffff
    state[7] = (state[7] + g) & 0xffffffff
    state[8] = (state[8] + h) & 0xffffffff
end

local function word_to_bytes(w)
    return {
        (w >> 24) & 0xff,
        (w >> 16) & 0xff,
        (w >> 8) & 0xff,
        w & 0xff
    }
end

local function bytes_to_hex(bytes)
    local hex = {}
    for i = 1, #bytes do
        hex[i] = string.format("%02x", bytes[i])
    end
    return table.concat(hex)
end

local function string_to_bytes(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i)
    end
    return bytes
end

function sha256.hash_bytes(bytes)
    local state = {table.unpack(H)}
    local padded = pad_message(bytes)
    for i = 1, #padded, 64 do
        local block = {}
        for j = 1, 64 do
            block[j] = padded[i + j - 1]
        end
        compress(state, block)
    end
    local result_bytes = {}
    for i = 1, 8 do
        local wb = word_to_bytes(state[i])
        for j = 1, 4 do
            result_bytes[#result_bytes + 1] = wb[j]
        end
    end
    return bytes_to_hex(result_bytes)
end

function sha256.hash_string(str)
    return sha256.hash_bytes(string_to_bytes(str))
end

function sha256.hash_file(filepath)
    local file, err = io.open(filepath, "rb")
    if not file then
        return nil, err
    end
    local content = file:read("*all")
    file:close()
    return sha256.hash_bytes(content)
end

function sha256.short_hash(hash)
    if #hash >= 8 then
        return hash:sub(1, 8)
    end
    return hash
end

return sha256