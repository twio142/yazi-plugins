# my-cmd.yazi

## Features

- `smart`: smart actions
    - `enter`: open shell in directory / open file in editor
    - `open-neww`: open in new tmux window
    - `esc`: unyank / escape
    - `up` / `down`: rotate when hitting top / bottom
    - `parent-up` / `parent-down`: Go up / down in the parent directory
    - `next-tab`: go to next tab, create if not exists
    - `split`: open hovered file in a split
    - `vsplit`: open hovered file in a vertical split
    - `copy-path`: copy hovered file's path
    - `copy-cwd`: copy cwd path
- `on_selection`
    - Act on selected files across all tabs
    - `copy` / `copy-force`: copy selected files to the hovered path
    - `move` / `move-force`: move selected files to the hovered path
    - `copy-new-dir`: copy selected files to a new directory in the hovered path
    - `move-new-dir`: move selected files to a new directory in the hovered path
    - `symlink` / `relative-symlink` / `symlink-force` / `relative-symlink-force`: create symlinks to selected files in the hovered path
    - `hardlink` / `relative-hardlink` / `hardlink-force` / `relative-hardlink-force`: create hardlinks to selected files in the hovered path
    - `delete`: delete selected files
    - `diff`: compare two selected files
    - `edit`: open selected files in editor
    - `rename`: rename selected files
    - `exec`: edit a command with selected files and execute.

## Usage

Put this in your `keymap.toml`:

```toml
[manager]
prepend_keys = [
  { on = "enter", run = "plugin my-cmd 'smart enter'", desc = "Open shell / edit file" },
  { on = ["<C-l>", "c"], run = "plugin my-cmd 'on_selection copy'", desc = "Copy selected files here" },
  # ...
]
```
