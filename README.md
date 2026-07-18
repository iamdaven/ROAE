# ROAE

ROAE (R-Oh-Ay-Ee) is a custom Roblox focused version control system. It consists of a Lua desktop application that manages repositories, commits, snapshots, compression, and communication with Roblox Studio, along with a Luau Roblox Studio plugin that provides access to Roblox data.
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
