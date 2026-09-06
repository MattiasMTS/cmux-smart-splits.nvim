# cmux-smart-splits.nvim

[![Tests](https://github.com/MattiasMTS/cmux-smart-splits.nvim/actions/workflows/tests.yml/badge.svg)](https://github.com/MattiasMTS/cmux-smart-splits.nvim/actions/workflows/tests.yml)

Navigate and resize Neovim windows and cmux panes with smart-splits.nvim v2.
Requires Neovim 0.11+, the cmux CLI on PATH, and local cmux socket access.
No dependency on ghostty-smart-splits.nvim.
cmux must report pane frames and cell dimensions through `list-panes`.

## Setup

With lazy.nvim (keep your existing smart-splits options and mappings):

```lua
{
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  dependencies = { "MattiasMTS/cmux-smart-splits.nvim" },
  config = function(_, opts)
    require("smart-splits").setup(opts)
    require("cmux-smart-splits").setup()
  end,
}
```

In the Ghostty config read by cmux, replace conflicting bindings with:

```ini
keybind = ctrl+h=text:\x08
keybind = ctrl+j=text:\x0a
keybind = ctrl+k=text:\x0b
keybind = ctrl+l=text:\x0c
keybind = alt+h=esc:h
keybind = alt+j=esc:j
keybind = alt+k=esc:k
keybind = alt+l=esc:l
```

Move conflicting cmux application shortcuts to other keys, then run
`cmux reload-config`. These changes also affect standalone Ghostty if it shares
the config file.

For shell-to-pane navigation, add this to `.zshrc` after other shell plugins,
using the plugin's installation path:

```zsh
source "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/cmux-smart-splits.nvim/shell/cmux-smart-splits.zsh"
```

Source it once in already-open shells too. Ctrl-h/j/k/l moves between panes;
Alt-h/j/k/l resizes by 7 cells. The shell companion uses Neovim as its Lua runner.
Run `:checkhealth cmux-smart-splits` to check connectivity and configuration.

## Limitations

Other TUIs receive keys normally. SSH, nested tmux/zellij, wrapping,
previous-pane navigation, and zoom detection are unsupported.
CLI calls are synchronous, with a one-second timeout by default.

## Tests

Run from the repository root. Integration tests use smart-splits from
`SMART_SPLITS_DIR` or Neovim's default lazy.nvim installation directory:

```sh
nvim --headless -u NONE -i NONE -l tests/run.lua
nvim --headless -u NONE -i NONE -l tests/integration.lua
python3 tests/shell.py
CMUX_TEST_INSTALLED_SHELL=1 python3 tests/shell.py
```

Tests cover pane logic, smart-splits integration, and real zsh key handling
against a simulated cmux CLI. The last command also checks installed zsh startup.
Actual cmux shortcut interception and GUI focus still need a manual check.

## Contributing

Include a regression test with fixes. For bug reports, include Neovim, cmux,
and smart-splits versions, reproduction steps, and relevant keybindings.
