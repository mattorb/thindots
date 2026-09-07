# locally installed tools
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# zsh command history
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
# setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don\'t record an entry that was just recorded again.
# setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don\'t record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don\'t write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.

# ripgrep most common usage: search everything except .git and lock flies
alias rg='rg --hidden -g "!.git" -g "!.git/**" -g "!*.lock"'

# applescript for quick connect to screen share (script in bin/)
alias ai="ai.sh"
alias tm="tm.sh"

# git status
_git_fetch_upstream() {
  local repo_dir=$1
  local upstream
  local remote

  upstream=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null) || return 0
  remote=${upstream%%/*}
  [[ -n "$remote" ]] || return 0

  git -C "$repo_dir" fetch --quiet --prune --no-tags --no-recurse-submodules "$remote" >/dev/null 2>&1 || true
}

_git_print_repo_summary() {
  local repo_dir=$1
  local repo_name=$2
  local show_files=${3:-0}
  shift 3

  setopt local_options null_glob
  local status_output
  local line
  local branch_summary
  local added
  local modified
  local removed
  local untracked
  local renamed
  local conflicts
  local x
  local y
  local summary
  local file_path

  _git_fetch_upstream "$repo_dir"

  if (( $# )); then
    status_output=$(git -C "$repo_dir" status --porcelain=1 --branch "$@" 2>&1)
  else
    status_output=$(git -C "$repo_dir" status --porcelain=1 --branch 2>&1)
  fi

  branch_summary=""
  added=0
  modified=0
  removed=0
  untracked=0
  renamed=0
  conflicts=0

  for line in ${(f)status_output}; do
    if [[ "$line" == "## "* ]]; then
      branch_summary=${line#\#\# }
      continue
    fi

    x=${line[1,1]}
    y=${line[2,2]}

    if [[ "$x$y" == "??" ]]; then
      ((untracked++))
      continue
    fi

    if [[ "$x" == "U" || "$y" == "U" || "$x$y" == "AA" || "$x$y" == "DD" ]]; then
      ((conflicts++))
    fi
    [[ "$x" == "A" || "$y" == "A" ]] && ((added++))
    [[ "$x" == "M" || "$y" == "M" || "$x" == "T" || "$y" == "T" ]] && ((modified++))
    [[ "$x" == "D" || "$y" == "D" ]] && ((removed++))
    [[ "$x" == "R" || "$y" == "R" || "$x" == "C" || "$y" == "C" ]] && ((renamed++))
  done

  if (( added == 0 && modified == 0 && removed == 0 && untracked == 0 && renamed == 0 && conflicts == 0 )); then
    print -P "%F{green}✓%f %F{cyan}${repo_name}%f  %F{242}${branch_summary:-clean}%f"
    return
  fi

  summary=""
  (( added > 0 )) && summary+=" %F{green}added:${added}%f"
  (( modified > 0 )) && summary+=" %F{yellow}modified:${modified}%f"
  (( removed > 0 )) && summary+=" %F{red}removed:${removed}%f"
  (( untracked > 0 )) && summary+=" %F{magenta}untracked:${untracked}%f"
  (( renamed > 0 )) && summary+=" %F{blue}renamed:${renamed}%f"
  (( conflicts > 0 )) && summary+=" %F{red}conflicts:${conflicts}%f"

  print -P "%F{yellow}!%f %F{cyan}${repo_name}%f  %F{242}${branch_summary:-changes}%f${summary}"

  (( show_files )) || return

  for line in ${(f)status_output}; do
    [[ "$line" == "## "* ]] && continue

    x=${line[1,1]}
    y=${line[2,2]}
    file_path=${line[4,-1]}

    if [[ "$x$y" == "??" ]]; then
      print -P "  %F{magenta}??%f ${file_path}"
      continue
    fi

    if [[ "$x" == "U" || "$y" == "U" || "$x$y" == "AA" || "$x$y" == "DD" ]]; then
      print -P "  %F{red}${x}${y}%f ${file_path}"
      continue
    fi

    if [[ "$x" == "A" || "$y" == "A" ]]; then
      print -P "  %F{green}${x}${y}%f ${file_path}"
    elif [[ "$x" == "M" || "$y" == "M" || "$x" == "T" || "$y" == "T" ]]; then
      print -P "  %F{yellow}${x}${y}%f ${file_path}"
    elif [[ "$x" == "D" || "$y" == "D" ]]; then
      print -P "  %F{red}${x}${y}%f ${file_path}"
    elif [[ "$x" == "R" || "$y" == "R" || "$x" == "C" || "$y" == "C" ]]; then
      print -P "  %F{blue}${x}${y}%f ${file_path}"
    else
      print -P "  %F{242}${x}${y}%f ${file_path}"
    fi
  done
}

gs() {
  if [[ -d .git ]]; then
    _git_fetch_upstream "."
    if (( $# )); then
      git status "$@"
    else
      git status
    fi
    return
  fi

  setopt local_options null_glob
  local dir
  local found=0

  for dir in */; do
    [[ -d "${dir}.git" ]] || continue
    found=1
    if (( $# )); then
      _git_print_repo_summary "$dir" "${dir%/}" 0 "$@"
    else
      _git_print_repo_summary "$dir" "${dir%/}" 0
    fi
  done

  if (( found )); then
    return
  fi

  if (( $# )); then
    git status "$@"
  else
    git status
  fi
}

gsd() {
  if [[ -d .git ]]; then
    if (( $# )); then
      _git_print_repo_summary "." "${PWD:t}" 1 "$@"
    else
      _git_print_repo_summary "." "${PWD:t}" 1
    fi
    return
  fi

  setopt local_options null_glob
  local dir
  local found=0

  for dir in */; do
    [[ -d "${dir}.git" ]] || continue
    found=1
    if (( $# )); then
      _git_print_repo_summary "$dir" "${dir%/}" 1 "$@"
    else
      _git_print_repo_summary "$dir" "${dir%/}" 1
    fi
  done

  if (( found )); then
    return
  fi

  if (( $# )); then
    git status "$@"
  else
    git status
  fi
}
alias gp="git pull"
alias gps="git push"
alias gpl="git pull"
alias gc="git commit"
alias gd="git diff"
alias gl="git lds"
alias gll="git ll"
alias glll="git filelog"
alias grc="gh repo clone"
alias grl="gh repo list --source --no-archived --limit 1000"
compdef _git gs=git-status
compdef _git gsd=git-status
compdef _git gp=git-pull
compdef _git gps=git-push
compdef _git gpl=git-pull
compdef _git gc=git-commit
compdef _git gd=git-diff
compdef _git gl=git-log
compdef _git gll=git-log
compdef _git glll=git-log

# Fix backspace keymap using ssh within Ghostty to mac
export TERM=xterm-256color

# Enable Ctrl-S for forward in Ctrl-R zshell history search
[[ -t 0 ]] && stty -ixon

# Discourage muscle memory for launching Terminal.app, in favor of Ghostty
if [[ -o interactive && -t 1 \
   && -z "$SSH_CONNECTION" && -z "$SSH_CLIENT" && -z "$SSH_TTY" \
   && "$TERM_PROGRAM" == "Apple_Terminal" ]]; then

  print -P "%F{red}Nope, switch to Ghostty!%f"
  sleep 2

  logout 2>/dev/null || exit
fi

# Prompt styles.  Consider starship.rs when needed something more elaborate
alias prompt_mini='export PROMPT_MODE=mini'
alias prompt_main='export PROMPT_MODE=main'

# History help
alias ll='ls -alhG $@'

history_clear() {
  echo Note: Clearing history will also IMMEDIATELY kill this terminal session.
  read -q "REPLY?Clear ALL command history? (y/N) " || return
  echo > ~/.zsh_history
  fc -p     # reset in-memory history
  kill -9 $$
}

# cat a markdown file uses glow to render it
fzf-path() {
  emulate -L zsh
  setopt pipefail

  local mode="${1:-file}"

  if [[ "$mode" == dir ]]; then
    command find . -path '*/.git' -prune -o -mindepth 1 -type d -print 2>/dev/null |
      sed 's#^\./##' |
      command fzf --height=40% --layout=reverse --prompt='dir> ' --scheme=path
    return
  fi

  if (( $+commands[rg] )); then
    command rg --files --hidden -g '!.git' -g '!.git/**' 2>/dev/null |
      command fzf --height=40% --layout=reverse --prompt='file> ' --scheme=path
  else
    command find . -type f -not -path '*/.git/*' -print 2>/dev/null |
      sed 's#^\./##' |
      command fzf --height=40% --layout=reverse --prompt='file> ' --scheme=path
  fi
}

_fzf_widget_mode() {
  emulate -L zsh

  if [[ "$LBUFFER" =~ '(^|[;&|][[:space:]]*)[[:space:]]*cd([[:space:]]+[^[:space:]]*)?$' ]]; then
    echo dir
    return
  fi

  echo file
}

_fzf_replace_cd_path() {
  emulate -L zsh

  local insert_text="$1" cd_prefix cd_spacing right_fragment

  [[ "$LBUFFER" =~ '^(.*(^|[;&|][[:space:]]*)[[:space:]]*cd)([[:space:]]+)([^[:space:]]*)$' ]] || return 1
  cd_prefix="${match[1]}"
  cd_spacing="${match[3]}"

  if [[ "$RBUFFER" =~ '^([^[:space:]]*)' ]]; then
    right_fragment="${match[1]}"
  else
    right_fragment=''
  fi

  LBUFFER="${cd_prefix}${cd_spacing}${insert_text}"
  RBUFFER="${RBUFFER[$(( ${#right_fragment} + 1 )),-1]}"
}

_fzf_insert_file_widget() {
  emulate -L zsh
  setopt pipefail

  local mode selected_path insert_text

  if ! (( $+commands[fzf] )); then
    zle -M 'fzf is not installed'
    return 0
  fi

  mode="$(_fzf_widget_mode)"

  zle -I
  selected_path="$(fzf-path "$mode")" || {
    zle redisplay
    return 0
  }
  [[ -n "$selected_path" ]] || {
    zle redisplay
    return 0
  }

  insert_text="${(q)selected_path}"

  if [[ "$mode" == dir ]] && _fzf_replace_cd_path "$insert_text"; then
    zle redisplay
    return 0
  fi

  [[ -n "$LBUFFER" && "$LBUFFER[-1]" != [[:space:]] ]] && insert_text=" $insert_text"
  [[ -n "$RBUFFER" && "$RBUFFER[1]" != [[:space:]] ]] && insert_text="$insert_text "

  LBUFFER+="$insert_text"
  zle redisplay
}

zle -N _fzf_insert_file_widget
bindkey '^O' _fzf_insert_file_widget

export PROMPT_MODE=main

zmodload zsh/datetime
autoload -Uz add-zsh-hook

_prompt_precmd() {
    local exit_code=$?

    if [[ "${PROMPT_MODE:-}" != "main" ]]; then
        PROMPT="$ "
        RPROMPT=""
        unset _cmd_start
        return
    fi

    # Git dirty + unpushed indicator
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local indicators=""
        [[ -n $(git status --porcelain 2>/dev/null) ]] && indicators+="%F{red}●%f"
        local unpushed=$(git rev-list --count @{u}..HEAD 2>/dev/null)
        (( unpushed > 0 )) && indicators+="%F{yellow}⇡${unpushed}%f"
        if [[ -n "$indicators" ]]; then
            PROMPT="%n@%m %~ ${indicators} %# "
        else
            PROMPT="%n@%m %~ %# "
        fi
    else
        PROMPT="%n@%m %~ %# "
    fi

    # Command duration + exit code
    if [[ -n "${_cmd_start:-}" ]]; then
        local elapsed=$(( EPOCHREALTIME - _cmd_start ))
        local duration
        if (( elapsed >= 60 )); then
            local mins=$(( elapsed / 60 ))
            local secs=$(( elapsed % 60 ))
            printf -v duration "%dm%.1fs" $mins $secs
        elif (( elapsed >= 1 )); then
            printf -v duration "%.1fs" $elapsed
        # elif (( elapsed >= 0.50 )); then
        #     local ms=$(( elapsed * 1000 ))
        #     printf -v duration "%dms" $ms
        else
            # skip printing <50ms (noise)
        fi

        if (( exit_code == 0 )); then
            RPROMPT="${duration}"
        else
            RPROMPT="%F{red}✗ ${exit_code}%f ${duration}"
        fi
        unset _cmd_start
    else
        RPROMPT=""
    fi
}

_prompt_preexec() {
    [[ "${PROMPT_MODE:-}" == "main" ]] && _cmd_start=$EPOCHREALTIME
}

add-zsh-hook precmd _prompt_precmd
add-zsh-hook preexec _prompt_preexec

# fordir... execute a command in each of the immediate subdirectories.... i.e. - 'fd git status' or 'fd git pull'
fd() {
  setopt local_options null_glob
  local dir

  for dir in */; do
    [[ -d "$dir" ]] || continue
    echo $dir
    (cd "$dir" && eval "$*") 2>&1 | sed 's/^/  /'
    echo
  done
}
