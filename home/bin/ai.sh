#!/usr/bin/env zsh
set -euo pipefail

# Single-key launcher for local agentic AI CLIs.

TOOLS=(
  "c:Codex:codex --dangerously-bypass-approvals-and-sandbox"
  "l:Claude Code:claude --dangerously-skip-permissions"
  "g:Gemini:gemini --yolo --sandbox=false"
  "d:Droid:droid --skip-permissions-unsafe"
  "h:Hermes:hermes --yolo"
  "q:Quit:"
)

print_menu() {
  echo
  echo "Select AI tool (single key):"
  echo "  [c] Codex (--model <MODEL>; model list not exposed by codex CLI)"
  echo "  [l] Claude Code (sonnet | opus | claude-sonnet-4-6)"
  echo "  [g] Gemini (--model <MODEL>; model list not exposed by gemini CLI)"
  echo "  [d] Droid (claude-opus-4-6, gpt-5.4, gpt-5.4-mini, gemini-3.1-pro-preview, custom:*)"
  echo "  [h] Hermes (set model via 'hermes model'; list is interactive)"
  echo "  [q] Quit"
}

is_ssh_session() {
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]
}

unlock_login_keychain_if_needed() {
  [[ "$(uname -s)" == "Darwin" ]] || return 0
  is_ssh_session || return 0
  command -v security >/dev/null 2>&1 || return 0

  if security show-keychain-info login.keychain-db >/dev/null 2>&1; then
    return 0
  fi

  echo "Login keychain appears to be locked for this SSH session."
  echo "Please unlock it to continue."
  security unlock-keychain
}

launch_cmd() {
  local key="$1"
  local entry

  for entry in "${TOOLS[@]}"; do
    IFS=':' read -r e_key e_name e_cmd <<< "$entry"
    if [[ "$e_key" == "$key" ]]; then
      if [[ "$e_key" == "q" ]]; then
        echo "Exiting."
        exit 0
      fi

      local bin="${e_cmd%% *}"
      if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Error: '$bin' is not in PATH." >&2
        exit 1
      fi

      unlock_login_keychain_if_needed
      echo "Launching $e_name..."
      exec ${(z)e_cmd}
    fi
  done

  echo "Invalid selection: '$key'" >&2
  exit 1
}

print_menu
printf "Choice: "
read -rsk1 choice
echo

launch_cmd "$choice"
