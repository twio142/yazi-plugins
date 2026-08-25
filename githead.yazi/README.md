An update of the original [githead.yazi](https://github.com/llanosrocas/githead.yazi), with adaptations to yazi v0.4.

---

# githead.yazi

Git status header for yazi inspired by [powerlevel10k](https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#what-do-different-symbols-in-git-status-mean).

![preview](https://github.com/llanosrocas/githead.yazi/blob/main/.github/images/preview.png)

All supported features are listed [here](#features)

## Requirements

- yazi version >= 0.3.0
- Font with symbol support. For example [Nerd Fonts](https://www.nerdfonts.com/).

## Installation

```sh
ya pkg add llanosrocas/githead
```

Or manually copy `init.lua` to the `~/.config/yazi/plugins/githead.yazi/init.lua`

## Usage

Add this to your `~/.config/yazi/init.lua`:

```lua
require("githead"):setup()
```

Read more about indicators [here](https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#what-do-different-symbols-in-git-status-mean).

Optionally, toggle the individual segments:

```lua
require("githead"):setup({
  show_branch = true,
  show_behind_ahead = true,
  show_stashes = true,
  show_state = true,
  show_state_prefix = true,
  show_staged = true,
  show_unstaged = true,
  show_untracked = true,
})
```

## Theme

The colors and symbols live in your `~/.config/yazi/theme.toml`, under a `[githead]` section:

```toml
[githead]
branch           = { fg = "blue" }
branch_prefix    = "on"
branch_symbol    = ""
branch_borders   = "()"
commit           = { fg = "lightmagenta" }
commit_symbol    = "@"
behind           = { fg = "lightmagenta" }
behind_symbol    = "⇣"
ahead            = { fg = "lightmagenta" }
ahead_symbol     = "⇡"
stashes          = { fg = "lightmagenta" }
stashes_symbol   = "$"
state            = { fg = "red" }
state_symbol     = "~"
staged           = { fg = "lightyellow" }
staged_symbol    = "+"
unstaged         = { fg = "lightyellow" }
unstaged_symbol  = "!"
untracked        = { fg = "lightblue" }
untracked_symbol = "?"
```

Those are the defaults. The color keys take any [Style](https://yazi-rs.github.io/docs/configuration/theme#style)
table, so `bold`, `italic` and the rest work too, and both colors and symbols are re-read whenever the theme
changes.

## Features

- [x] Current branch (or current commit if branch is not presented)
- [x] Behind/Ahead of the remote
- [x] Stashes
- [x] States
    - [x] merge
    - [x] cherry
    - [x] rebase (+ done counter)
- [x] Staged
- [x] Unstaged
- [x] Untracked

### Under the hood

The goal is to use minimum amount of shell commands.

```shell
git status --ignore-submodules=dirty --branch --show-stash
```

This command provides information about branches, stashes, staged files, unstaged files, untracked files, and other statistics.

## Credits

- [yazi source code](https://github.com/sxyazi/yazi)
- [powerlevel10k](https://github.com/romkatv/powerlevel10k)
