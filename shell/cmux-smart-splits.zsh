# Source after other zsh plugins. Keys are owned only while ZLE is active.
[[ -o interactive && -n ${CMUX_WORKSPACE_ID:-} && -n ${CMUX_SURFACE_ID:-} ]] || return 0
[[ -z ${TMUX:-}${ZELLIJ:-}${SSH_CONNECTION:-} ]] || return 0
typeset -g CMUX_SMART_SPLITS_ROOT=${${(%):-%x}:A:h:h}

_cmux_smart_splits_widget() {
  local action=${WIDGET#cmux-smart-}
  local direction=${action#*-}
  action=${action%%-*}
  command nvim --headless -u NONE -i NONE -l "$CMUX_SMART_SPLITS_ROOT/scripts/control.lua" "$action" "$direction" 7
  zle redisplay
}

for _cmux_ss_map in emacs viins vicmd; do
  for _cmux_ss_key _cmux_ss_dir in h left j down k up l right; do
    zle -N "cmux-smart-move-$_cmux_ss_dir" _cmux_smart_splits_widget
    zle -N "cmux-smart-resize-$_cmux_ss_dir" _cmux_smart_splits_widget
    bindkey -M "$_cmux_ss_map" "^${(U)_cmux_ss_key}" "cmux-smart-move-$_cmux_ss_dir"
    bindkey -M "$_cmux_ss_map" "^[${_cmux_ss_key}" "cmux-smart-resize-$_cmux_ss_dir"
  done
done
unset _cmux_ss_map _cmux_ss_key _cmux_ss_dir
