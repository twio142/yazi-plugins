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
	unmatch_fg = "#b2a496",
    match_str_fg = "#000000",
    match_str_bg = "#73AC3A",
    first_match_str_fg = "#000000",
    first_match_str_bg = "#73AC3A",
    lable_fg = "#EADFC8",
    lable_bg = "#BA603D",
    only_current = false,
    show_search_in_statusbar = false,
    auto_exit_when_unmatch = false,
    enable_capital_lable = true,
	search_patterns = ({"hell[dk]d","%d+.1080p","第%d+集","第%d+话","%.E%d+","S%d+E%d+",})
})
```

When you see some character singal label in right of the entry.
Press the key of the character will jump to the corresponding entry
