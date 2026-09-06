local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
local client = require("cmux-smart-splits.client")
local action, direction, amount = unpack(arg)
if action ~= "move" and action ~= "resize" then
  io.stderr:write("Usage: nvim -l scripts/control.lua move|resize left|right|up|down [amount]\n")
  vim.cmd("cquit 1")
end
local _, err = client[action](direction, tonumber(amount) or 7)
if err then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
