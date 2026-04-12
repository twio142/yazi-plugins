# sudo.yazi

Run privileged file operations via `sudo -S`, with the password entered through a hidden input field.

Operates on selected files across all tabs and yanked files.

## Supported modes

- `copy` / `copy-force`: `sudo cp -r`
- `move` / `move-force`: `sudo mv`
- `remove`: `sudo rm -rf`
- `symlink`: `sudo ln -s`
- `hardlink`: `sudo ln`
- `rename`: prompts for a new name, then `sudo mv`
- `shell`: prompts for a shell command, runs it via `sudo $SHELL -c <cmd>` with hovered/selected files as arguments

## Usage

```toml
[manager]
prepend_keymap = [
  { on = ["s", "c"], run = "plugin sudo copy",        desc = "Sudo copy" },
  { on = ["s", "m"], run = "plugin sudo move",        desc = "Sudo move" },
  { on = ["s", "d"], run = "plugin sudo remove",      desc = "Sudo remove" },
  { on = ["s", "l"], run = "plugin sudo symlink",     desc = "Sudo symlink" },
  { on = ["s", "r"], run = "plugin sudo rename",      desc = "Sudo rename" },
  { on = ["s", "s"], run = "plugin sudo shell",       desc = "Sudo shell" },
]
```
