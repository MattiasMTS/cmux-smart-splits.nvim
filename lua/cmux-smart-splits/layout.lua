local M = {}

function M.surface_pane(panes, surface)
  for _, pane in ipairs(panes) do
    for _, id in ipairs(pane.surface_ids or {}) do
      if id == surface then
        return pane
      end
    end
  end
end

-- Prefer panes sharing the requested edge; never jump diagonally or wrap.
function M.neighbor(panes, source, direction)
  local frame = source.pixel_frame
  if not frame then
    return nil
  end
  local horizontal = direction == "left" or direction == "right"
  local forward = direction == "right" or direction == "down"
  local axis, size = horizontal and "x" or "y", horizontal and "width" or "height"
  local cross, extent = horizontal and "y" or "x", horizontal and "height" or "width"
  local best, best_gap, best_offset
  for _, pane in ipairs(panes) do
    local other = pane.pixel_frame
    if pane.id ~= source.id and other then
      local gap = forward and (other[axis] - frame[axis] - frame[size]) or (frame[axis] - other[axis] - other[size])
      local overlap = math.min(frame[cross] + frame[extent], other[cross] + other[extent])
        - math.max(frame[cross], other[cross])
      local offset = math.abs(frame[cross] + frame[extent] / 2 - other[cross] - other[extent] / 2)
      if gap >= -1 and overlap > 1 then
        if not best or gap < best_gap or (gap == best_gap and offset < best_offset) then
          best, best_gap, best_offset = pane, gap, offset
        end
      end
    end
  end
  return best
end

return M
