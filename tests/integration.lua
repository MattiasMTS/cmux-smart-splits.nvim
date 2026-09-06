vim.opt.runtimepath:prepend(vim.fn.getcwd())
local smart_path = vim.env.SMART_SPLITS_DIR or (vim.fn.stdpath("data") .. "/lazy/smart-splits.nvim")
assert(vim.fn.isdirectory(smart_path) == 1, "Set SMART_SPLITS_DIR to a smart-splits.nvim checkout")
vim.opt.runtimepath:append(smart_path)

vim.env.CMUX_WORKSPACE_ID = "workspace"
vim.env.CMUX_SURFACE_ID = "editor"
vim.env.SSH_CONNECTION = nil
vim.env.TMUX = nil
vim.env.ZELLIJ = nil
local panes = {
  {
    id = "editor-pane",
    surface_ids = { "editor" },
    focused = true,
    pixel_frame = { x = 0, y = 0, width = 500, height = 500 },
    cell_width_points = 10,
    cell_height_points = 20,
  },
  {
    id = "shell-pane",
    surface_ids = { "shell" },
    focused = false,
    pixel_frame = { x = 500, y = 0, width = 500, height = 500 },
  },
}
local calls = {}
vim.system = function(argv)
  assert(argv[1] == vim.v.progpath)
  assert(argv[#argv] == "workspace")
  table.insert(calls, argv)
  if argv[5] == "focus-pane" then
    for _, pane in ipairs(panes) do
      pane.focused = pane.id == argv[7]
    end
  end
  return {
    wait = function()
      return { code = 0, stdout = vim.json.encode(argv[5] == "list-panes" and { panes = panes } or {}) }
    end,
  }
end
local function count(action)
  return #vim.tbl_filter(function(argv)
    return argv[5] == action
  end, calls)
end
local function check(condition, label)
  assert(condition, label)
  print("PASS: " .. label)
end

local smart = require("smart-splits")
smart.setup({ default_amount = 7, cursor_follows_swapped_bufs = true })
require("cmux-smart-splits").setup({ executable = vim.v.progpath })
local config = require("smart-splits.config")
check(config.default_amount == 7 and config.cursor_follows_swapped_bufs, "preserves smart-splits options")
check(config.at_edge == "stop", "disables wrapping")
check(require("smart-splits.mux").get().type == "cmux", "loads cmux adapter through smart-splits")

vim.o.columns = 120
vim.cmd("vsplit")
vim.cmd("wincmd h")
local left = vim.api.nvim_get_current_win()
smart.move_cursor_right()
check(vim.api.nvim_get_current_win() ~= left and count("focus-pane") == 0, "moves inside Neovim first")
smart.move_cursor_right()
check(panes[2].focused and count("focus-pane") == 1, "moves from Neovim edge to cmux")
panes[1].focused, panes[2].focused = true, false
smart.move_cursor_left()
check(vim.api.nvim_get_current_win() == left, "moves back inside Neovim")
smart.move_cursor_left()
check(vim.api.nvim_get_current_win() == left and count("focus-pane") == 1, "stops at workspace edge")
local width = vim.api.nvim_win_get_width(left)
smart.resize_right()
check(vim.api.nvim_win_get_width(left) ~= width and count("resize-pane") == 0, "resizes inside Neovim first")
vim.cmd("only")
smart.resize_right()
check(count("resize-pane") == 1, "resizes cmux when no editor divider exists")
local resize = vim.tbl_filter(function(argv)
  return argv[5] == "resize-pane"
end, calls)[1]
check(resize[7] == "editor-pane" and resize[10] == "70", "converts configured resize cells to points")
