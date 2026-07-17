local serializer = require("src.serialization.serializer")

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

print("ROAE Serializer Tests")
print(string.rep("=", 50))
print("")

local obj = serializer.create_object("Folder", "Root", {Name = "Root"})
assert_equal("Folder", obj.class_name, "Object class_name")
assert_equal("Root", obj.name, "Object name")
assert_equal("Root", obj.properties.Name, "Object property")

local script = serializer.create_object("Script", "Main", {Name = "Main"}, "print('hello')")
assert_equal("Script", script.class_name, "Script type")
assert_equal("print('hello')", script.contents, "Script contents")

local module = serializer.create_object("ModuleScript", "Helper", {Name = "Helper"}, "return {}")
assert_equal("ModuleScript", module.class_name, "ModuleScript type")

local part = serializer.create_object("Part", "Base", {Name = "Base", Size = "10,1,10"})
assert_equal("Part", part.class_name, "Part type")

local model = serializer.create_object("Model", "World", {Name = "World"})
assert_equal("Model", model.class_name, "Model type")

local unknown = serializer.create_object("CustomClass", "Thing", {Name = "Thing"})
assert_equal("X", serializer.classify("CustomClass"), "Unknown type")

local lines = serializer.serialize_object(obj, 0)
assert_true(#lines > 0, "Serialized object has lines")
assert_true(lines[1]:match("^@F"), "First line is object header")

local project = serializer.serialize_project({obj, script})
assert_true(#project > 0, "Serialized project has content")
assert_true(project:match("^ROAE_SER:"), "Serialized starts with ROAE_SER header")

local deserialized = serializer.deserialize_project(project)
assert_true(deserialized ~= nil, "Deserialized project is not nil")
assert_equal(2, #deserialized, "Deserialized has 2 root objects")

local root_obj = deserialized[1]
assert_equal("Folder", root_obj.class_name, "First object is Folder")
assert_equal("Root", root_obj.name, "First object name is Root")

local script_obj = deserialized[2]
assert_equal("Script", script_obj.class_name, "Second object is Script")
assert_equal("Main", script_obj.name, "Second object name is Main")

local parent = serializer.create_object("Folder", "Root", {Name = "Root"})
parent.children = {serializer.create_object("ModuleScript", "Helper", {Name = "Helper"}, "return {}")}
local proj2 = serializer.serialize_project({parent})
local deser2 = serializer.deserialize_project(proj2)
assert_true(deser2[1].children and #deser2[1].children == 1, "Root has children")
assert_equal("ModuleScript", deser2[1].children[1].class_name, "Child is ModuleScript")
assert_equal("Helper", deser2[1].children[1].name, "Child name is Helper")

local script_with_content = serializer.create_object("Script", "Main", {Name = "Main"}, "print('test')")
local proj3 = serializer.serialize_project({script_with_content})
local deser3 = serializer.deserialize_project(proj3)
assert_equal("print('test')", deser3[1].contents, "Script contents preserved")

local module_with_content = serializer.create_object("ModuleScript", "Config", {Name = "Config"}, "return {version = 1}")
local proj4 = serializer.serialize_project({module_with_content})
local deser4 = serializer.deserialize_project(proj4)
assert_equal("return {version = 1}", deser4[1].contents, "ModuleScript contents preserved")

local obj_with_attrs = serializer.create_object("Folder", "Root", {Name = "Root"})
obj_with_attrs.attributes = {Tag = "Important", Priority = "1"}
local proj5 = serializer.serialize_project({obj_with_attrs})
local deser5 = serializer.deserialize_project(proj5)
assert_equal("Important", deser5[1].attributes.Tag, "Object with attributes deserialized")

local part_obj = serializer.create_object("Part", "BasePlate", {Name = "BasePlate", Size = "10,1,10"})
local proj6 = serializer.serialize_project({part_obj})
local deser6 = serializer.deserialize_project(proj6)
assert_equal("Part", deser6[1].class_name, "Part class preserved")
assert_equal("BasePlate", deser6[1].name, "Part name preserved")

local obj1 = serializer.create_object("Folder", "Root", {Name = "Root"})
local obj2 = serializer.create_object("Folder", "Root", {Name = "Root"})
assert_equal(serializer.compute_tree_hash(obj1), serializer.compute_tree_hash(obj2), "Same object produces same tree hash")

local obj3 = serializer.create_object("Folder", "Root", {Name = "Root"})
local obj4 = serializer.create_object("Folder", "Different", {Name = "Different"})
assert_true(serializer.compute_tree_hash(obj3) ~= serializer.compute_tree_hash(obj4), "Different objects produce different tree hashes")

local empty_proj = serializer.serialize_project({})
local deser_empty = serializer.deserialize_project(empty_proj)
assert_true(deser_empty ~= nil, "Empty project deserialized")
assert_equal(0, #deser_empty, "Empty project has 0 objects")

local bad_data = "This is not valid ROAE data"
local bad_result = serializer.deserialize_project(bad_data)
assert_true(bad_result == nil, "Invalid data returns nil")

print("")
print(string.rep("=", 50))
print("Results: " .. passed .. "/" .. tests .. " tests passed")
if passed == tests then
    print("All tests passed!")
else
    print(tests - passed .. " test(s) failed")
    os.exit(1)
end