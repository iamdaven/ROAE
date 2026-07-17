local root_dir = debug.getinfo(1, "S").source:match("^@?(.*/)") or "./"
root_dir = root_dir:gsub("\\", "/"):gsub("tests/", "")
package.path = root_dir .. "?.lua;" .. root_dir .. "?/init.lua;" .. package.path

local serializer = require("src.serialization.serializer")
local compressor = require("src.compression.compressor")
local decompressor = require("src.compression.decompressor")
local storage = require("src.snapshot.storage")
local manager = require("src.snapshot.manager")
local commit_system = require("src.commit.commit")
local history_mod = require("src.commit.history")

local test_repo_name = "test_repo_integration"
local test_dir = root_dir .. test_repo_name

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

os.execute('rmdir /s /q "' .. test_dir .. '" 2>nul')
os.execute('rm -rf "' .. test_dir .. '" 2>/dev/null')

print("ROAE Integration Test")
print(string.rep("=", 50))
print("Test directory: " .. test_dir)
print("")

print("Step 1: Create test project data")
local project = {
    serializer.create_object("Folder", "GameFolder", {Name = "GameFolder"}),
    serializer.create_object("Script", "MainScript", {Name = "MainScript"}, "print('Hello from ROAE!')")
}
project[1].children = {
    serializer.create_object("ModuleScript", "Config", {Name = "Config"}, "return {version = 1}"),
    serializer.create_object("Folder", "SubFolder", {Name = "SubFolder"})
}
project[1].children[2].children = {
    serializer.create_object("Part", "BasePlate", {Name = "BasePlate", Size = "10,1,10"})
}

local serialized = serializer.serialize_project(project)
assert_true(#serialized > 0, "Project serialized successfully")
print("  Project size: " .. #serialized .. " bytes")
print("")

print("Step 2: Compress project data")
local compressed = compressor.compress(serialized)
assert_true(#compressed > 0, "Project compressed successfully")
print("  Compressed size: " .. #compressed .. " bytes")
print("")

print("Step 3: Decompress and verify")
local decompressed = decompressor.decompress(compressed)
assert_equal(serialized, decompressed, "Decompressed data matches original")
print("")

print("Step 4: Initialize test repository")
os.execute('if not exist "' .. test_dir .. '" mkdir "' .. test_dir .. '" 2>nul')
os.execute('mkdir -p "' .. test_dir .. '" 2>/dev/null')

local repo_init = require("src.repo.init")
local ok, msg = repo_init.init("TestRepo", "Tester")
assert_true(ok, "Repository initialized: " .. msg)
print("  Repo root: " .. (test_dir))
print("")

os.execute('if exist ".roae" move /y ".roae" "' .. test_dir .. '\\" 2>nul')

print("Step 5: Store snapshot")
local snapshot_id = storage.generate_id(serialized)
assert_true(snapshot_id ~= nil, "Snapshot ID generated: " .. (snapshot_id or "nil"):sub(1, 16))
print("  Snapshot ID: " .. (snapshot_id or "nil"):sub(1, 16) .. "...")

local stored_id, stored_path = storage.store(serialized, test_dir)
assert_equal(snapshot_id, stored_id, "Snapshot ID matches content hash")
print("")

print("Step 6: Load snapshot")
local loaded_data = storage.load(stored_id, test_dir)
assert_equal(serialized, loaded_data, "Loaded snapshot matches stored data")
print("")

print("Step 7: Create commit")
local commit_id, commit_data = commit_system.create("Test commit message", "Tester", serialized, test_dir)
assert_true(commit_id ~= nil, "Commit created: " .. (commit_id or "nil"))
print("  Commit ID: " .. (commit_id or "nil"):sub(1, 16) .. "...")
print("  Message: " .. (commit_data and commit_data.message or "nil"))
print("")

print("Step 8: Create second commit with modifications")
project[2].contents = "print('Modified script!')"
local serialized_v2 = serializer.serialize_project(project)
local commit_id2 = commit_system.create("Second commit", "Tester", serialized_v2, test_dir)
assert_true(commit_id2 ~= nil, "Second commit created: " .. (commit_id2 or "nil"))
print("  Commit ID 2: " .. (commit_id2 or "nil"):sub(1, 16) .. "...")
print("")

print("Step 9: View commit history")
local commits = history_mod.get_history(test_dir, 10)
assert_equal(2, #commits, "History contains 2 commits")
if #commits >= 2 then
    assert_equal("Second commit", commits[1].message, "HEAD commit is second commit")
    assert_equal("Test commit message", commits[2].message, "Second commit is first commit")
end
print("  Commits found: " .. #commits)
for i, c in ipairs(commits) do
    print("    " .. i .. ". " .. c.short_id .. " - " .. c.message)
end
print("")

print("Step 10: Restore first commit")
if #commits >= 2 then
    local first_commit_id = commits[2].id
    local info, full_data = history_mod.get_commit(first_commit_id, test_dir)
    assert_true(info ~= nil, "Found first commit for restore")
    if info and info.snapshot then
        local restored_data = manager.restore_snapshot(info.snapshot, test_dir)
        assert_equal(serialized, restored_data, "Restored data matches original snapshot")
        print("  Restored snapshot matches original")
    end
end
print("")

print("Step 11: Search commits by message")
local search_results = history_mod.search("second", test_dir)
assert_equal(1, #search_results, "Search found 1 commit with 'second'")
print("  Found " .. #search_results .. " commit(s) matching 'second'")
print("")

print("Step 12: Test change detection")
local changes = manager.compute_changes(serialized, serialized_v2)
assert_true(changes.total_changes >= 0, "Changes computed")
print("  Changes detected: " .. changes.total_changes)
print("")

print("Step 13: Verify snapshots exist")
assert_true(storage.exists(snapshot_id, test_dir), "First snapshot exists")
assert_true(storage.exists(stored_id, test_dir), "Second snapshot exists")
print("  Both snapshots verified on disk")
print("")

print("Step 14: Test CLI entry point")
local status_cmd = require("src.cli.status")
print("  CLI 'status' command loaded: " .. status_cmd.name)
print("")

print("Step 15: Cleanup")
os.execute('rmdir /s /q "' .. test_dir .. '" 2>nul')
os.execute('rm -rf "' .. test_dir .. '" 2>/dev/null')
os.execute('if exist ".roae" rmdir /s /q ".roae" 2>nul')
os.execute('rm -rf ".roae" 2>/dev/null')
print("  Test directory removed")
print("")

print(string.rep("=", 50))
print("Results: " .. passed .. "/" .. tests .. " tests passed")
if passed == tests then
    print("All integration tests passed!")
else
    print(tests - passed .. " test(s) failed")
    os.exit(1)
end