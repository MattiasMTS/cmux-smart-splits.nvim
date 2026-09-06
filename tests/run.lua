vim.opt.runtimepath:prepend(vim.fn.getcwd())
local layout = require("cmux-smart-splits.layout")
local client = require("cmux-smart-splits.client")
local checks = 0
local function eq(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect({ actual = actual, expected = expected }))
  checks = checks + 1
end
local function pane(id, x, y, w, h, surface)
  return { id = id, pixel_frame = { x = x, y = y, width = w, height = h }, surface_ids = { surface or id } }
end
local left = pane("left", 0, 0, 100, 200, "editor")
local top = pane("top", 101, 0, 100, 99)
local bottom = pane("bottom", 101, 101, 100, 99)
local panes = { left, top, bottom }
for _, p in ipairs(panes) do
  p.cell_width_points, p.cell_height_points = 10, 20
end
left.focused = true

eq(layout.surface_pane(panes, "editor"), left)
eq(layout.surface_pane(panes, "missing"), nil)
eq(layout.neighbor(panes, top, "left"), left)
eq(layout.neighbor(panes, bottom, "up"), top)
eq(layout.neighbor(panes, top, "down"), bottom)
eq(layout.neighbor(panes, left, "left"), nil)
eq(layout.neighbor(panes, top, "right"), nil)
eq(layout.neighbor({ top, pane("diagonal", 202, 200, 100, 100) }, top, "right"), nil)

vim.env.CMUX_WORKSPACE_ID = "test-workspace"
vim.env.CMUX_SURFACE_ID = "editor"
vim.env.SSH_CONNECTION = nil
vim.env.TMUX = nil
vim.env.ZELLIJ = nil
local calls = {}
local system = vim.system
vim.system = function(argv, opts)
  eq(opts.timeout, 1000)
  eq(argv[#argv - 1], "--workspace")
  eq(argv[#argv], "test-workspace")
  table.insert(calls, argv)
  local action = argv[5]
  local result = {}
  if action == "list-panes" then
    result = { panes = panes }
  elseif action == "focus-pane" then
    for _, p in ipairs(panes) do
      p.focused = p.id == argv[7]
    end
  end
  return {
    wait = function()
      return { code = 0, stdout = vim.json.encode(result) }
    end,
  }
end

eq(client.detect(), true)
eq(client.focused_id(), "left")
eq(client.move("right"), true)
eq(client.focused_id(), "top")
-- Requests still originate at the editor, even though focus moved elsewhere.
eq(client.move("left"), false)
eq(client.source(), left)
eq(client.resize("right", 7), true)
eq(calls[#calls][7], "left")
eq(calls[#calls][10], "70")
vim.env.CMUX_SURFACE_ID = "top"
eq(client.resize("right", 7), true)
eq(calls[#calls][7], "left")
eq(calls[#calls][8], "-R")
eq(client.resize("down", 3), true)
eq(calls[#calls][10], "60")
eq(client.resize("right", -1), false)
eq(client.move("diagonal"), false)
vim.env.CMUX_SURFACE_ID = "missing"
eq(client.move("right"), false)
vim.env.SSH_CONNECTION = "remote"
eq(client.detect(), false)
vim.env.SSH_CONNECTION = nil
vim.env.CMUX_SURFACE_ID = "editor"

vim.system = function()
  return {
    wait = function()
      return { code = 0, stdout = "not json" }
    end,
  }
end
local result, err = client.panes()
eq(result, nil)
eq(err, "cmux returned invalid JSON")
vim.system = function()
  return {
    wait = function()
      return { code = 124, stderr = "timeout" }
    end,
  }
end
result, err = client.panes()
eq(result, nil)
eq(err, "timeout")
vim.system = system
print(("PASS: %d layout, surface targeting, command, and failure checks"):format(checks))
