local M = {}

function M.check()
  vim.health.start("cmux-smart-splits")
  local client = require("cmux-smart-splits.client")
  if not client.detect() then
    vim.health.warn("Not in a local cmux surface (SSH/tmux/zellij are excluded)")
    return
  end
  vim.health.ok("cmux workspace and surface IDs are present")
  local source, _, err = client.source()
  if source then
    vim.health.ok("cmux API reachable; originating pane: " .. source.id)
  else
    vim.health.error(err)
  end
  if require("smart-splits.config").multiplexer_integration == "cmux" then
    vim.health.ok("smart-splits cmux backend is active")
  else
    vim.health.error("Call setup() after smart-splits.setup()")
  end
  vim.health.info(
    "Forward Ctrl/Alt-h/j/k/l in terminal config and source shell/cmux-smart-splits.zsh for shell navigation"
  )
  vim.health.warn("No key-table ownership API: other TUIs receive the keys normally; zoom detection is not implemented")
end

return M
