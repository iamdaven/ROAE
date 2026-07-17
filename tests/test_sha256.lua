local sha256 = require("src.crypto.sha256")

local tests = 0
local passed = 0

local function assert_equal(expected, actual, name)
    tests = tests + 1
    if expected == actual then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        print("  FAIL: " .. name)
        print("    Expected: " .. expected)
        print("    Actual:   " .. actual)
    end
end

print("ROAE SHA-256 Tests")
print(string.rep("=", 50))
print("")

local empty_hash = sha256.hash_string("")
assert_equal("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", empty_hash, "Empty string hash")

local abc_hash = sha256.hash_string("abc")
assert_equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", abc_hash, "abc hash")

local hello_hash = sha256.hash_string("hello world")
assert_equal("b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9", hello_hash, "hello world hash")

local short = sha256.short_hash(abc_hash)
assert_equal("ba7816bf", short, "Short hash (first 8 chars)")

local bytes = {0x61, 0x62, 0x63}
local bytes_hash = sha256.hash_bytes(bytes)
assert_equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", bytes_hash, "hash_bytes with abc")

local long_str = string.rep("A", 1000)
local long_hash = sha256.hash_string(long_str)
assert_equal(64, #long_hash, "Long string hash length (64 chars)")

local hash1 = sha256.hash_string("test1")
local hash2 = sha256.hash_string("test2")
if hash1 ~= hash2 then
    passed = passed + 1
    print("  PASS: Different strings produce different hashes")
else
    print("  FAIL: Different strings produced same hash")
end
tests = tests + 1

local hash3 = sha256.hash_string("consistent")
local hash4 = sha256.hash_string("consistent")
if hash3 == hash4 then
    passed = passed + 1
    print("  PASS: Same string produces same hash")
else
    print("  FAIL: Same string produced different hashes")
end
tests = tests + 1

print("")
print(string.rep("=", 50))
print("Results: " .. passed .. "/" .. tests .. " tests passed")
if passed == tests then
    print("All tests passed!")
else
    print(tests - passed .. " test(s) failed")
    os.exit(1)
end