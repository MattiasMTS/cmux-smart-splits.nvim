local M = { timeout = 1000, executable = "cmux" }
local layout = require("cmux-smart-splits.layout")
local flags = { left = "-L", right = "-R", up = "-U", down = "-D" }
local opposite = { left = "right", right = "left", up = "down", down = "up" }

function M.detect()
  return vim.env.CMUX_WORKSPACE_ID ~= nil
    and vim.env.CMUX_WORKSPACE_ID ~= ""
    and vim.env.CMUX_SURFACE_ID ~= nil
    and vim.env.CMUX_SURFACE_ID ~= ""
    and not vim.env.SSH_CONNECTION
    and not vim.env.TMUX
    and not vim.env.ZELLIJ
end

function M.call(args)
  if not M.detect() then
    return nil, "Not in a local cmux surface"
  end
  local argv = { M.executable, "--json", "--id-format", "uuids" }
  vim.list_extend(argv, args)
  vim.list_extend(argv, { "--workspace", vim.env.CMUX_WORKSPACE_ID })
  local ok, result = pcall(function()
    return vim.system(argv, { text = true, timeout = M.timeout }):wait()
  end)
  if not ok then
    return nil, tostring(result)
  end
  if result.code ~= 0 then
    return nil,
      vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr) or ("cmux exited with code " .. result.code)
  end
  local decoded, value = pcall(vim.json.decode, result.stdout)
  if not decoded or type(value) ~= "table" then
    return nil, "cmux returned invalid JSON"
  end
  return value
end

function M.panes()
  local result, err = M.call({ "list-panes" })
  if not result then
    return nil, err
  end
  if type(result.panes) ~= "table" then
    return nil, "cmux returned no pane list"
  end
  return result.panes
end

function M.source()
  local panes, err = M.panes()
  if not panes then
    return nil, nil, err
  end
  local pane = layout.surface_pane(panes, vim.env.CMUX_SURFACE_ID)
  if not pane then
    return nil, nil, "The originating cmux surface no longer exists"
  end
  return pane, panes
end

function M.focused_id()
  local panes = M.panes()
  for _, pane in ipairs(panes or {}) do
    if pane.focused then
      return pane.id
    end
  end
end

function M.at_edge(direction)
  local pane, panes = M.source()
  return not pane or layout.neighbor(panes, pane, direction) == nil
end

function M.move(direction)
  if not flags[direction] then
    return false, "Invalid direction"
  end
  local pane, panes, err = M.source()
  if not pane then
    return false, err
  end
  local target = layout.neighbor(panes, pane, direction)
  if not target then
    return false
  end
  local result
  result, err = M.call({ "focus-pane", "--pane", target.id })
  return result ~= nil, err
end

function M.resize(direction, amount)
  if not flags[direction] or type(amount) ~= "number" or amount < 1 or amount ~= math.floor(amount) then
    return false, "Resize requires a direction and a positive integer amount"
  end
  local pane, panes, err = M.source()
  if not pane then
    return false, err
  end
  local horizontal = direction == "left" or direction == "right"
  local cell_size = horizontal and pane.cell_width_points or pane.cell_height_points
  if type(cell_size) ~= "number" or cell_size <= 0 then
    return false, "cmux has not reported cell dimensions for this pane"
  end
  -- smart-splits counts cells; cmux's resize amount is in layout points.
  local points = math.max(1, math.floor(amount * cell_size + 0.5))
  -- An outer edge has no divider. Move the neighboring pane's matching edge.
  local target = layout.neighbor(panes, pane, direction) and pane or layout.neighbor(panes, pane, opposite[direction])
  if not target then
    return false
  end
  local result
  result, err = M.call({ "resize-pane", "--pane", target.id, flags[direction], "--amount", tostring(points) })
  return result ~= nil, err
end

function M.split(direction)
  if not flags[direction] then
    return false, "Invalid direction"
  end
  local result, err = M.call({ "new-split", direction, "--surface", vim.env.CMUX_SURFACE_ID, "--focus", "true" })
  return result ~= nil, err
end

return M
