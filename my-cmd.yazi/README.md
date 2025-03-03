# my-cmd.yazi

## Features

- `smart`: smart actions
    - `enter`: open shell in directory / open file in editor
    - `open-neww`: open in new tmux window
    - `esc`: unyank / escape
    - `up` / `down`: rotate when hitting top / bottom
    - `parent-up` / `parent-down`: Go up / down in the parent directory
    - `N`: find previous / create new file
    - `create-tab`: create a tab on the hovered file, enter if hovered on a directory
    - `next-tab`: go to next tab, create if not exists
- `on_selection`
    - Act on selected files across all tabs
    - `copy` / `copy-force`: copy selected files to the hovered path
    - `move` / `move-force`: move selected files to the hovered path
    - `copy-new-dir`: copy selected files to a new directory in the hovered path
    - `move-new-dir`: move selected files to a new directory in the hovered path
    - `symlink` / `symlink-force`: create symlinks to selected files in the hovered path
    - `hardlink` / `hardlink-force`: create hardlinks to selected files in the hovered path
    - `delete`: delete selected files
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
