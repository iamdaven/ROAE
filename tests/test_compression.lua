local compressor = require("src.compression.compressor")
local decompressor = require("src.compression.decompressor")

local tests = 0
local passed = 0

local function assert_equal(expected, actual, name)
    tests = tests + 1
    if expected == actual then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        print("  FAIL: " .. name)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assert_true(condition, name)
    tests = tests + 1
    if condition then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        print("  FAIL: " .. name)
    end
end

print("ROAE Compression Tests")
print(string.rep("=", 50))
print("")

local empty = ""
local empty_compressed = compressor.compress(empty)
local empty_decompressed = decompressor.decompress(empty_compressed)
assert_equal(empty, empty_decompressed, "Empty string round-trip")

local simple = "Hello, World! This is a test."
local simple_compressed = compressor.compress(simple)
local simple_decompressed = decompressor.decompress(simple_compressed)
assert_equal(simple, simple_decompressed, "Simple text round-trip")

local repeated = string.rep("A", 100)
local repeated_compressed = compressor.compress(repeated)
local repeated_decompressed = decompressor.decompress(repeated_compressed)
assert_equal(repeated, repeated_decompressed, "Repeated data (RLE) round-trip")

local zeros = string.char(0):rep(50)
local zeros_compressed = compressor.compress(zeros)
local zeros_decompressed = decompressor.decompress(zeros_compressed)
assert_equal(zeros, zeros_decompressed, "Zero bytes round-trip")

local mixed = "HelloWorld!!!!!!!!!!!!!!!!!!!!ROAE"
local mixed_compressed = compressor.compress(mixed)
local mixed_decompressed = decompressor.decompress(mixed_compressed)
assert_equal(mixed, mixed_decompressed, "Mixed data round-trip")

local roblox = string.rep("ScriptContent\n", 50) .. string.rep("0", 30)
local roblox_compressed = compressor.compress(roblox)
local roblox_decompressed = decompressor.decompress(roblox_compressed)
assert_equal(roblox, roblox_decompressed, "Roblox-like data round-trip")

local large = string.rep("RobloxInstance", 100) .. string.rep("ScriptContent\n", 100) .. string.rep("0", 50)
local large_compressed = compressor.compress(large)
local large_decompressed = decompressor.decompress(large_compressed)
assert_equal(large, large_decompressed, "Large data round-trip")

assert_true(#repeated_compressed < #repeated * 0.5, "Compression ratio < 0.5 for repeated data (ratio: " .. string.format("%.3f", #repeated_compressed / #repeated) .. ")")

assert_true(decompressor.is_compressed(simple_compressed), "is_compressed detects compressed data")
assert_true(not decompressor.is_compressed(simple), "is_compressed rejects plain text")

local valid, stored, actual = compressor.verify_integrity(simple, compressor.compute_checksum(simple))
assert_true(valid, "Integrity check passes for valid data")

local bad_data = "This is not compressed"
local result, err = decompressor.decompress(bad_data)
assert_true(result == nil, "Decompress rejects invalid data (returns nil)")

print("")
print(string.rep("=", 50))
print("Results: " .. passed .. "/" .. tests .. " tests passed")
if passed == tests then
    print("All tests passed!")
else
    print(tests - passed .. " test(s) failed")
    os.exit(1)
end