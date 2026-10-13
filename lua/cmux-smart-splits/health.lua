local M = {}

function M.report()
  local client = require("cmux-smart-splits.client")
  if not client.detect() then
    vim.health.warn("Not in a local cmux surface (SSH/tmux/zellij are excluded)")
    return
  end
  vim.health.ok("cmux workspace and surface IDs are present")
  if vim.fn.executable(client.executable) ~= 1 then
    vim.health.error("cmux CLI is not executable: " .. client.executable)
    return
  end
  local source, _, err = client.source()
  if source then
    vim.health.ok("cmux API reachable; originating pane: " .. source.id)
  else
    vim.health.error(err)
  end
  vim.health.info(
    "Forward Ctrl/Alt-h/j/k/l in terminal config and source shell/cmux-smart-splits.zsh for shell navigation"
  )
  vim.health.warn("No key-table ownership API: other TUIs receive the keys normally; zoom detection is not implemented")
end

function M.check()
  vim.health.start("cmux-smart-splits")
  M.report()
  local backend = require("smart-splits.backend").resolve()
  if backend and backend.name == "cmux" then
    vim.health.ok("smart-splits cmux backend is active")
  else
    vim.health.error('Add "smart-splits-backend-cmux" to smart-splits `mux.backend`')
  end
end

return M
