local M = {}

function M.setup(opts)
  opts = opts or {}
  local client = require("cmux-smart-splits.client")
  if not client.detect() then
    return false
  end
  client.executable = opts.executable or "cmux"
  client.timeout = opts.timeout or 1000
  assert(type(client.timeout) == "number" and client.timeout > 0, "timeout must be positive")
  if vim.fn.executable(client.executable) ~= 1 then
    vim.notify("cmux-smart-splits: cmux CLI is not executable", vim.log.levels.ERROR)
    return false
  end
  require("smart-splits").setup({ multiplexer_integration = "cmux", at_edge = "stop" })
  return true
end

return M
