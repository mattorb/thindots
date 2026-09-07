#!/usr/bin/env zsh
set -euo pipefail

if ! command -v tmux >/dev/null 2>&1; then
  echo "tm.sh: tmux is not installed or not in PATH" >&2
  exit 1
fi

attach_or_switch() {
  local session_name="$1"

  if [[ -n "${TMUX:-}" ]]; then
    exec tmux switch-client -t "$session_name"
  fi

  exec tmux attach-session -t "$session_name"
}

ensure_session_exists() {
  local session_name="$1"

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name"
  fi
}

if [[ $# -gt 1 ]]; then
  echo "usage: tm.sh [session-name]" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  ensure_session_exists "$1"
  attach_or_switch "$1"
fi

sessions=("${(@f)$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)}")
sessions=("${(@)sessions:#}")

if (( ${#sessions[@]} > 0 )); then
  windows_output="$(tmux list-windows -a -F '#{session_name}	#{window_index}	#{window_name}	#{pane_current_command}' 2>/dev/null || true)"
  echo "Existing tmux sessions:"
  i=1
  for session_name in "${sessions[@]}"; do
    echo "  [$i] $session_name"
    while IFS=$'\t' read -r w_session w_index w_name w_cmd; do
      [[ "$w_session" == "$session_name" ]] || continue
      echo "        $w_index: $w_name — $w_cmd"
    done <<< "$windows_output"
    ((i++))
  done
  echo "  [n] Create a new session"
  echo "  [q] Quit"
  printf "Choice: "
  read -r choice

  if [[ "$choice" == [Qq] ]]; then
    exit 0
  fi

  if [[ "$choice" == [Nn] ]]; then
    selected_session=""
  elif [[ "$choice" == <-> ]] && (( choice >= 1 && choice <= ${#sessions[@]} )); then
    selected_session="${sessions[$choice]}"
    attach_or_switch "$selected_session"
  else
    echo "Invalid selection: $choice" >&2
    exit 1
  fi
else
  selected_session=""
fi

while true; do
  printf "New session name: "
  read -r selected_session

  if [[ -z "$selected_session" ]]; then
    echo "Session name cannot be empty." >&2
    continue
  fi

  if [[ "$selected_session" =~ ^[A-Za-z0-9._-]+$ ]]; then
    break
  fi

  echo "Use only letters, numbers, dot, underscore, or dash." >&2
done

ensure_session_exists "$selected_session"
attach_or_switch "$selected_session"
