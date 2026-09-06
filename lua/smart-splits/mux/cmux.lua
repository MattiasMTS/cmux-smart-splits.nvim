local client = require("cmux-smart-splits.client")

local function report(fn)
  return function(...)
    local ok, err = fn(...)
    if err then
      vim.schedule(function()
        vim.notify_once("cmux-smart-splits: " .. err, vim.log.levels.WARN)
      end)
    end
    return ok
  end
end

return {
  type = "cmux",
  is_in_session = client.detect,
  -- smart-splits compares focus before/after a move, not the originating surface.
  current_pane_id = client.focused_id,
  current_pane_at_edge = client.at_edge,
  next_pane = report(client.move),
  resize_pane = report(client.resize),
  split_pane = report(client.split),
  current_pane_is_zoomed = function()
    return false
  end,
  update_mux_layout_details = function() end,
}
