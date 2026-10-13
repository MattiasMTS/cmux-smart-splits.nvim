local M = {}

-- Optional: configures the cmux CLI. smart-splits selects the backend via `mux.backend`.
function M.setup(opts)
  opts = opts or {}
  local client = require("cmux-smart-splits.client")
  local timeout = opts.timeout or 1000
  assert(type(timeout) == "number" and timeout > 0, "timeout must be positive")
  client.executable = opts.executable or "cmux"
  client.timeout = timeout
end

return M
