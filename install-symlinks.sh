#!/usr/bin/env zsh
set -e
set -o pipefail

# Resolve the repo root so this works from any working directory
REPO_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# Source shared library
. "$REPO_DIR/lib/common.sh"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [-y|--yes] [-h|--help]

Symlinks this repo's dotfiles into \$HOME and adds a managed block to
~/.zshrc that sources this repo's zsh config.

Anything already on the machine is left alone unless you say otherwise:
existing files and directories are moved to a .thindots.bak backup, and
symlinks pointing elsewhere are only repointed after you confirm.

  -y, --yes   Answer yes to every prompt (same as THINDOTS_ASSUME_YES=1)
  -h, --help  Show this help
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y | --yes)
            THINDOTS_ASSUME_YES=1
            export THINDOTS_ASSUME_YES
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

echo "Setting up symlinks.."

# Symlink git aliases, ignores
link_path "$REPO_DIR/home/.gitaliases" "$HOME/.gitaliases" ".gitaliases"
link_path "$REPO_DIR/home/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"

# Symlink bin directory
link_path "$REPO_DIR/home/bin" "$HOME/bin" "bin directory"

# The local .zshrc stays the machine's own file; we only add a managed block
# to it that sources ours. Keeps machine-local settings intact and lets this
# repo be updated without touching $HOME/.zshrc again.
ensure_sourced "$HOME/.zshrc" "$REPO_DIR/home/.zshrc" "thindots"

# Symlinking the git files into $HOME is not enough on its own: git locates
# them through ~/.gitconfig. Without this, .gitaliases and .gitignore_global
# sit there unused and `git lds`, `git ll` and friends are undefined.
echo "Configuring git.."

if ! command -v git > /dev/null 2>&1; then
    warning "git is not installed; skipping git config"
else
    if [ -e "$HOME/.gitaliases" ] || [ -L "$HOME/.gitaliases" ]; then
        git_config_add include.path "$HOME/.gitaliases"
    fi
    if [ -e "$HOME/.gitignore_global" ] || [ -L "$HOME/.gitignore_global" ]; then
        git_config_set core.excludesfile "$HOME/.gitignore_global"
    fi
fi
