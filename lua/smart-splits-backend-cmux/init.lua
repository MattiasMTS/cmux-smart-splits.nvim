-- smart-splits v3 backend. Select it with `mux.backend = "smart-splits-backend-cmux"`.
local client = require("cmux-smart-splits.client")

local function report(ok, err)
  if err then
    vim.schedule(function()
      vim.notify_once("cmux-smart-splits: " .. err, vim.log.levels.WARN)
    end)
  end
  return ok == true
end

local M = { name = "cmux", protocol_version = "3.0.0" }

function M.detect()
  return client.detect() and vim.fn.executable(client.executable) == 1
end

-- cmux cannot wrap, so `wrap` and `stop` are left to core; `split` becomes a cmux split.
function M.move(direction, opts)
  if report(client.move(direction)) then
    return true
  end
  if (opts or {}).at_edge == "split" and client.at_edge(direction) then
    return report(client.split(direction))
  end
  return false
end

function M.resize(direction, opts)
  return report(client.resize(direction, (opts or {}).amount))
end

function M.health()
  require("cmux-smart-splits.health").report()
end

return M
