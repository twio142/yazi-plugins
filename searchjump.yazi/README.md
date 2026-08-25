# searchjump.yazi

A Yazi plugin which the behavior consistent with flash.nvim in Neovim, allow search str to generate label to jump.




https://github.com/DreamMaoMao/searchjump.yazi/assets/30348075/4a00eb39-211b-47c5-8e22-644a7d7bc6b1



> [!NOTE]
> The latest main branch of Yazi is required at the moment.


## Install

### Linux

```bash
git clone https://github.com/DreamMaoMao/searchjump.yazi.git ~/.config/yazi/plugins/searchjump.yazi
```

### Windows

With `Powershell` :

```powershell
if (!(Test-Path $env:APPDATA\yazi\config\plugins\)) {mkdir $env:APPDATA\yazi\config\plugins\}
git clone https://github.com/DreamMaoMao/searchjump.yazi.git $env:APPDATA\yazi\config\plugins\searchjump.yazi
```

## Usage

set shortcut key to toggle searchjump mode in `~/.config/yazi/keymap.toml`. for example set `i` to toggle searchjump mode

```toml
[[manager.prepend_keymap]]
on   = [ "i" ]
run = "plugin searchjump"
desc = "searchjump mode"
```

Or enter directory automatically when jumping onto it:

```toml
[[manager.prepend_keymap]]
on   = [ "i" ]
run = "plugin searchjump -- autocd"
desc = "searchjump mode"
```

## opts setting (~/.config/yazi/init.lua)

```lua
require("searchjump"):setup({
	only_current = false, -- only search the current window
	show_search_in_statusbar = false,
	auto_exit_when_unmatch = true,
	enable_capital_label = false,
	search_patterns = {}, -- demo: { "%.e%d+", "s%d+e%d+" }
})
```

## Theme

The colors live in your `~/.config/yazi/theme.toml`, under a `[searchjump]` section:

```toml
[searchjump]
unmatch = { fg = "#b2a496" }
match   = { fg = "#000000", bg = "#73AC3A" }
label   = { fg = "#EADFC8", bg = "#BA603D" }
```

- `unmatch` - the part of a filename that doesn't match
- `match` - the matched part of a filename
- `label` - the jump label appended to a match

Each takes any [Style](https://yazi-rs.github.io/docs/configuration/theme#style) table, so `bold`, `italic`
and the rest work too. Those values are the defaults, and they're re-read whenever the theme changes.

When you see some character singal label in right of the entry.
Press the key of the character will jump to the corresponding entry
