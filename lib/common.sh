#!/usr/bin/env sh
#
# common.sh - Shared library for shell scripts
# Source this file at the top of any script for shared functions:
#   source ./lib/common.sh
#   # or: . ./lib/common.sh
#

# Prevent multiple sourcing (idempotent)
if [ -n "${COMMON_LOADED:-}" ]; then
    return 0
fi
COMMON_LOADED=1

# ANSI color codes
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
RESET="\033[0m"

# Print helpers
success() {
    printf "${GREEN}[OK]${RESET} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${RESET} %s\n" "$1"
}

info() {
    printf "${YELLOW}[INFO]${RESET} %s\n" "$1"
}

warning() {
    printf "${MAGENTA}[WARN]${RESET} %s\n" "$1"
}

# Consent helpers
#
# Nothing here ever replaces, moves or edits something that is already on the
# machine without asking first. The default answer is always "no", so an
# accidental Enter (or a non-interactive run) leaves the machine as it was.

# Ask a yes/no question. Returns 0 for yes, non-zero for no.
# Reads from the terminal rather than stdin so it still works when the calling
# script is piped. With no terminal available the answer is "no" unless
# THINDOTS_ASSUME_YES=1 is set.
# Usage: confirm "Question?"
confirm() {
    _cf_prompt=$1

    if [ "${THINDOTS_ASSUME_YES:-0}" = "1" ]; then
        info "$_cf_prompt -> yes (THINDOTS_ASSUME_YES=1)"
        return 0
    fi

    # Probe by actually opening it: /dev/tty can pass -r and still be
    # unusable (no controlling terminal).
    if { : < /dev/tty; } 2>/dev/null; then
        _cf_in=/dev/tty
    elif [ -t 0 ]; then
        _cf_in=/dev/stdin
    else
        warning "$_cf_prompt -> no (no terminal to ask on; set THINDOTS_ASSUME_YES=1 to accept)"
        return 1
    fi

    while :; do
        printf "%s [y/N] " "$_cf_prompt"
        if ! IFS= read -r _cf_answer < "$_cf_in" 2>/dev/null; then
            printf "\n"
            return 1
        fi
        case "$_cf_answer" in
            [Yy] | [Yy][Ee][Ss]) return 0 ;;
            [Nn] | [Nn][Oo] | "") return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# Print a backup path for <target> that is not already taken, so an existing
# backup from an earlier run is never clobbered.
# Usage: backup_name <target>
backup_name() {
    _bn_base="$1.thindots.bak"
    _bn_dest=$_bn_base
    _bn_n=0
    while [ -e "$_bn_dest" ] || [ -L "$_bn_dest" ]; do
        _bn_n=$((_bn_n + 1))
        _bn_dest="$_bn_base.$_bn_n"
    done
    printf '%s\n' "$_bn_dest"
}

# Resolve a symlink to an absolute path (one level, made absolute).
# Usage: resolve_link <symlink>
resolve_link() {
    _rl_link=$(readlink "$1")
    case "$_rl_link" in
        /*) ;;
        *) _rl_link="$(dirname "$1")/$_rl_link" ;;
    esac
    _rl_dir=$(cd "$(dirname "$_rl_link")" 2>/dev/null && pwd -P) || _rl_dir=""
    if [ -n "$_rl_dir" ]; then
        printf '%s\n' "$_rl_dir/$(basename "$_rl_link")"
    else
        printf '%s\n' "$_rl_link"
    fi
}

# Symlink <source> at <target>.
# Already pointing at <source>: nothing to do. Anything else already there --
# a file, a directory, or a symlink somewhere else -- is only replaced after
# the user says so, and real files/directories are moved to a backup rather
# than deleted.
# Usage: link_path <source> <target> [description]
link_path() {
    _lp_source=$1
    _lp_target=$2
    _lp_desc=${3:-$(basename "$_lp_target")}

    if [ -L "$_lp_target" ]; then
        _lp_current=$(resolve_link "$_lp_target")
        if [ "$_lp_current" = "$_lp_source" ]; then
            info "$_lp_desc already symlinked"
            return 0
        fi
        _lp_backup=$(backup_name "$_lp_target")
        if ! confirm "$_lp_target is a symlink to $_lp_current. Back it up to $_lp_backup and repoint it at $_lp_source?"; then
            warning "Left $_lp_target as it was"
            return 0
        fi
        # mv keeps the link itself, so the backup still points where the
        # original did and can be moved back.
        mv "$_lp_target" "$_lp_backup"
        info "Backed up $_lp_target to $_lp_backup"
    elif [ -e "$_lp_target" ]; then
        _lp_backup=$(backup_name "$_lp_target")
        if ! confirm "$_lp_target already exists. Back it up to $_lp_backup and symlink $_lp_source in its place?"; then
            warning "Left $_lp_target as it was"
            return 0
        fi
        mv "$_lp_target" "$_lp_backup"
        info "Backed up $_lp_target to $_lp_backup"
    fi

    ln -s "$_lp_source" "$_lp_target"
    success "Symlinked $_lp_desc"
}

# Global git config helpers
#
# A file in $HOME does nothing for git on its own -- git finds .gitaliases and
# .gitignore_global through ~/.gitconfig, not by their location. These wire
# that up under the same rule as everything else: an existing value is only
# replaced with permission, and ~/.gitconfig is backed up before any change.

# Expand a leading ~/ so a value written by hand compares equal to ours.
expand_tilde() {
    case "$1" in
        "~/"*) printf '%s\n' "$HOME/${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# Copy ~/.gitconfig aside, at most once per run, before the first change to it.
gitconfig_backup_once() {
    if [ -n "${GITCONFIG_BACKED_UP:-}" ]; then
        return 0
    fi
    GITCONFIG_BACKED_UP=1

    _gb_file="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"
    if [ -e "$_gb_file" ]; then
        _gb_backup=$(backup_name "$_gb_file")
        cp -p "$_gb_file" "$_gb_backup"
        info "Backed up $_gb_file to $_gb_backup"
    fi
}

# Set a single-valued global git setting. A different existing value is a real
# overwrite, so it is only replaced after confirming.
# Usage: git_config_set <key> <value>
git_config_set() {
    _gs_key=$1
    _gs_value=$2

    _gs_current=$(git config --global --get "$_gs_key" 2>/dev/null) || _gs_current=""

    if [ -n "$_gs_current" ] && [ "$(expand_tilde "$_gs_current")" = "$_gs_value" ]; then
        info "git $_gs_key already points at $_gs_value"
        return 0
    fi

    if [ -n "$_gs_current" ]; then
        if ! confirm "git $_gs_key is set to $_gs_current. Replace it with $_gs_value?"; then
            warning "Left git $_gs_key as it was"
            return 0
        fi
    fi

    gitconfig_backup_once
    git config --global "$_gs_key" "$_gs_value"
    success "Set git $_gs_key to $_gs_value"
}

# Add a value to a multi-valued global git setting. Additive: whatever is
# already configured stays, so there is nothing to overwrite and nothing to ask.
# Usage: git_config_add <key> <value>
git_config_add() {
    _ga_key=$1
    _ga_value=$2

    if git config --global --get-all "$_ga_key" 2>/dev/null \
        | sed "s|^~/|$HOME/|" \
        | grep -qxF "$_ga_value"; then
        info "git $_ga_key already includes $_ga_value"
        return 0
    fi

    gitconfig_backup_once
    git config --global --add "$_ga_key" "$_ga_value"
    success "Added $_ga_value to git $_ga_key"
}

# Managed block helpers
#
# Rather than taking ownership of a user's rc file with a symlink, these keep a
# small marker-delimited block inside it that sources one of our files. The
# local file stays the user's own; only the block between the markers is ours.

# Print the managed block that sources a file.
# Usage: managed_block <source_file> <marker_id>
managed_block() {
    printf '# >>> %s >>>\n' "$2"
    printf '# Managed by thindots. Do not edit between these markers.\n'
    printf '[ -r "%s" ] && . "%s"\n' "$1" "$1"
    printf '# <<< %s <<<\n' "$2"
}

# Strip an existing managed block (if any) from stdin.
# Usage: strip_managed_block <marker_id> < file
strip_managed_block() {
    awk -v b="# >>> $1 >>>" -v e="# <<< $1 <<<" '
        $0 == b { skip = 1 }
        skip != 1 { print }
        $0 == e { skip = 0 }
    '
}

# Ensure <target_file> sources <source_file> via a managed block.
# Idempotent: re-running updates the block in place instead of appending again.
# Creating the file when it is missing needs no permission; every path that
# edits or replaces a file already on the machine asks first.
# Usage: ensure_sourced <target_file> <source_file> [marker_id]
ensure_sourced() {
    _es_target=$1
    _es_source=$2
    _es_marker=${3:-thindots}

    # A symlink here means the file is owned by some other setup (or by an
    # older symlink-style install of ours). Detaching it or writing into
    # whatever it points at would both take over something that isn't ours, so
    # leave it alone entirely and say what to do by hand.
    if [ -L "$_es_target" ]; then
        _es_link=$(resolve_link "$_es_target")
        warning "$_es_target is a symlink to $_es_link - skipping"
        if [ "$_es_link" = "$_es_source" ]; then
            # Adding the block to the file it points at would make that file
            # source itself, so a real file is the only way forward here.
            info "Replace it with a real file and re-run to pick up the $_es_marker block."
        else
            info "To load $_es_source, add this to that file, or replace the symlink with a real file and re-run:"
            managed_block "$_es_source" "$_es_marker" | sed 's/^/    /'
        fi
        return 0
    fi

    if [ ! -e "$_es_target" ]; then
        managed_block "$_es_source" "$_es_marker" > "$_es_target"
        success "Created $_es_target sourcing $_es_source"
        return 0
    fi

    # Already correct? Compare the current block against the desired one.
    if grep -qxF "# >>> $_es_marker >>>" "$_es_target"; then
        _es_current=$(awk -v b="# >>> $_es_marker >>>" -v e="# <<< $_es_marker <<<" '
            $0 == b { skip = 1 }
            skip == 1 { print }
            $0 == e { skip = 0 }
        ' "$_es_target")
        if [ "$_es_current" = "$(managed_block "$_es_source" "$_es_marker")" ]; then
            info "$_es_target already sources $_es_source"
            return 0
        fi
        _es_action="Update the thindots block in $_es_target to source $_es_source?"
    else
        _es_action="Append a thindots block to $_es_target that sources $_es_source?"
    fi

    _es_backup=$(backup_name "$_es_target")
    if ! confirm "$_es_action (a backup is written to $_es_backup)"; then
        warning "Left $_es_target as it was"
        return 0
    fi

    cp -p "$_es_target" "$_es_backup"
    # Seed the temp file from the original so it inherits its mode, then
    # truncate and rewrite it.
    _es_tmp="$_es_target.thindots.tmp.$$"
    cp -p "$_es_target" "$_es_tmp"
    {
        strip_managed_block "$_es_marker" < "$_es_target"
        managed_block "$_es_source" "$_es_marker"
    } > "$_es_tmp"
    mv "$_es_tmp" "$_es_target"
    success "Updated $_es_target to source $_es_source (backup: $_es_backup)"
}
