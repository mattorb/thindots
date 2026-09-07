# thindots

Extracted some broader shareable dot files for things like git config/aliases
and general utility scripts from a larger dotfiles setup.

## Install

```sh
./install-symlinks.sh
```

Symlinks `.gitaliases`, `.gitignore_global`, and `~/bin` into `$HOME`, then
points git at the two git files:

```sh
git config --global --add include.path ~/.gitaliases
git config --global core.excludesfile ~/.gitignore_global
```

Git locates both through `~/.gitconfig`, not by where they sit, so the symlinks
alone would leave them unused. `include.path` is multi-valued, so ours is added
alongside anything already there; `core.excludesfile` is single-valued, so an
existing value pointing elsewhere is only replaced after confirming, and
`~/.gitconfig` is backed up before either change.

### Nothing is overwritten without asking

The installer never replaces, moves or edits something already on the machine
without confirming first, and every confirmed overwrite leaves a backup:

- **Already pointing at this repo?** Nothing to do, no prompt.
- **A real file or directory is in the way?** You are asked before it is moved
  to `<path>.thindots.bak` and the symlink put in its place.
- **A symlink pointing somewhere else** (another dotfiles repo)? You are asked
  before it is repointed, and the old symlink is kept as `<path>.thindots.bak`
  — still pointing where it did, so it can be moved back.
- **Backups are never clobbered.** If `<path>.thindots.bak` already exists, the
  next one becomes `.thindots.bak.1`, `.thindots.bak.2`, and so on.
- **Answering no** (or just pressing Enter) leaves that path exactly as it was;
  the install carries on with the rest.
- **Non-interactive runs** (no terminal to prompt on) decline by default and
  report what they skipped. Pass `-y`/`--yes`, or set `THINDOTS_ASSUME_YES=1`,
  to accept every prompt up front.

Undo an install by moving the `.thindots.bak` entries back over the symlinks.

### zsh

`~/.zshrc` is *not* replaced with a symlink — it stays the machine's own file.
The installer only appends a managed block to it that sources this repo's
`home/.zshrc`:

```sh
# >>> thindots >>>
# Managed by thindots. Do not edit between these markers.
[ -r "/path/to/thindots/home/.zshrc" ] && . "/path/to/thindots/home/.zshrc"
# <<< thindots <<<
```

So machine-local settings stay put, and anything the local `.zshrc` defines
before the block (e.g. `compinit`) is in effect when this repo's config loads.

Details:

- **Idempotent.** Re-running updates the block in place instead of appending a
  second one. If nothing changed, the file is left untouched and you are not
  prompted.
- **Confirmed, and backed up.** Adding or updating the block asks first, and
  copies the file to `~/.zshrc.thindots.bak` before touching it.
- **Symlinked `~/.zshrc` is skipped.** If `~/.zshrc` is a symlink — to another
  dotfiles repo, or to this one from an older symlink-style install — the
  installer touches neither the symlink nor the file it points at. It prints
  the block and skips the step. Add it to that file by hand, or replace the
  symlink with a real file and re-run.
- **Uninstall.** Delete the lines between (and including) the two markers.

The block goes at the end of the file, so this repo's `PATH` and aliases take
precedence over local ones.
