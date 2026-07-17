# ROAE - Roblox Version Control System

ROAE (R-Oh-Ay-Ee) is a custom Roblox-focused version control system. It consists of a Lua desktop application that manages repositories, commits, snapshots, compression, and communication with Roblox Studio, along with a Luau Roblox Studio plugin that provides access to Roblox data.

## Architecture

```
ROAE/
├── bin/roae.lua              # CLI entry point
├── src/                       # Desktop application (pure Lua)
│   ├── cli/                   # Command handlers
│   │   ├── init.lua
│   │   ├── status.lua
│   │   ├── commit.lua
│   │   ├── history.lua
│   │   ├── restore.lua
│   │   └── connect.lua
│   ├── repo/                  # Repository management
│   │   ├── init.lua
│   │   ├── config.lua
│   │   └── index.lua
│   ├── snapshot/              # Snapshot storage
│   │   ├── manager.lua
│   │   └── storage.lua
│   ├── commit/                # Commit handling
│   │   ├── commit.lua
│   │   └── history.lua
│   ├── compression/           # Custom compression
│   │   ├── compressor.lua
│   │   └── decompressor.lua
│   ├── crypto/                # SHA-256 and hashing
│   │   └── sha256.lua
│   ├── bridge/                # Local communication
│   │   ├── server.lua
│   │   └── client.lua
│   └── serialization/         # Data serialization
│       └── serializer.lua
├── plugin/                    # Roblox Studio plugin (Luau)
│   └── src/
│       ├── MainPlugin.lua
│       ├── BridgeClient.lua
│       ├── Serializer.lua
│       ├── InstanceExporter.lua
│       └── ChangeDetector.lua
└── build/
    └── build_plugin.lua       # Plugin build script
```

## Usage

```
roae init                    # Initialize a new ROAE repository
roae status                  # Show repository status
roae commit "message"        # Commit changes
roae history                 # Show commit history
roae restore <commit>        # Restore a previous version
roae connect                 # Connect to Roblox Studio plugin
```

## Building the Plugin

```bash
lua build/build_plugin.lua
```

## License

GNU General Public License v3.0