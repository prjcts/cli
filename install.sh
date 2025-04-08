#!/usr/bin/env bash

set -euo pipefail

# Determine if running from a local repo or via curl
IS_LOCAL_CLONE=true
if [[ "${BASH_SOURCE[0]}" =~ ^/dev/fd/.* || "${BASH_SOURCE[0]}" == "bash" ]]; then
  IS_LOCAL_CLONE=false
fi

BIN_DIR="$HOME/.local/bin"
PRJCTS_DIR="$HOME/.local/share/prjcts"
DEV_CLI="$BIN_DIR/dev-cli"

mkdir -p "$BIN_DIR" "$PRJCTS_DIR"

if $IS_LOCAL_CLONE; then
  cp ./version "$PRJCTS_DIR/version"
else
  curl -fsSL https://raw.githubusercontent.com/prjcts/cli/main/version -o "$PRJCTS_DIR/version"
fi

echo "Installing dev-cli to $DEV_CLI"
cp ./dev-cli "$DEV_CLI"
chmod +x "$DEV_CLI"

detect_shell_rc() {
  case "$SHELL" in
    */zsh) echo "$HOME/.zshrc" ;;
    */bash) echo "$HOME/.bashrc" ;;
    */fish) echo "$HOME/.config/fish/config.fish" ;;
    *) echo "$HOME/.profile" ;;
  esac
}

install_function_zsh_bash() {
  local rc_file="$1"
  if ! grep -q "function dev()" "$rc_file"; then
    echo "Adding dev function to $rc_file"
    cat <<'EOF' >> "$rc_file"

# dev shell function
function dev() {
  local dir
  local config="$HOME/.local/share/prjcts/command"
  local cmd

  dir=$("$HOME/.local/bin/dev-cli")

  if [[ -f "$config" ]]; then
    cmd=$(<"$config")
  else
    echo "No launch command is configured. Please run: dev set -c"
    return 1
  fi

  if [[ -n "$dir" ]]; then
    cd "$dir" || return
    echo -ne "\033]0;${cmd}: ${dir##*/}\007"
    exec "$cmd" "$dir"
  fi
}
EOF
  else
    echo "dev function already present in $rc_file"
  fi
}

install_function_fish() {
  local config="$HOME/.config/fish/functions/dev.fish"
  echo "Installing dev function for Fish: $config"
  mkdir -p "$(dirname "$config")"
  cat > "$config" <<'EOF'
function dev
  set -l dir (bash -c "$HOME/.local/bin/dev-cli")
  set -l cmd (cat $HOME/.local/share/prjcts/command 2>/dev/null)
  if test -z "$cmd"
    echo "No launch command is configured. Please run: dev set -c"
    return 1
  end
  if test -n "$dir"
    cd $dir
    printf "\033]0;%s: %s\007" $cmd (basename $dir)
    exec $cmd $dir
  end
end
EOF
}

install_completion_zsh() {
  local completion="$PRJCTS_DIR/dev-completion.zsh"
  cat > "$completion" <<'EOF'
#compdef dev

_arguments \
  '1: :->subcmds' \
  '*::options:->options'

case $state in
  subcmds)
    _values 'subcommands' \
      'add' 'clean' 'set' 'show' 'triggers' 'help'
    ;;
  options)
    case $words[2] in
      add|clean)
        _values 'options' -d --directories -t --triggers
        ;;
      set)
        _values 'options' -c --command
        ;;
      show)
        _values 'options' command
        ;;
    esac
    ;;
esac
EOF

  local rc_file="$1"
  if ! grep -q "$completion" "$rc_file"; then
    echo "fpath+=(\"$PRJCTS_DIR\")" >> "$rc_file"
    echo "autoload -Uz compinit && compinit" >> "$rc_file"
  fi
}

install_completion_fish() {
  local completion="$HOME/.config/fish/completions/dev.fish"
  echo "Installing Fish completion: $completion"
  mkdir -p "$(dirname "$completion")"
  cat > "$completion" <<'EOF'
complete -c dev -f -n "__fish_use_subcommand" -a "add clean set show triggers help"
complete -c dev -n "__fish_seen_subcommand_from add clean" -s d -l directories -d "Work with directories"
complete -c dev -n "__fish_seen_subcommand_from add clean" -s t -l triggers -d "Work with triggers"
complete -c dev -n "__fish_seen_subcommand_from set" -s c -l command -d "Set launch command"
complete -c dev -n "__fish_seen_subcommand_from show" -a "command" -d "Show configured command"
EOF
}

echo "Detecting shell..."
RC_FILE=$(detect_shell_rc)

case "$RC_FILE" in
  *.zshrc|*.bashrc|*.profile)
    install_function_zsh_bash "$RC_FILE"
    [[ "$RC_FILE" == *zshrc ]] && install_completion_zsh "$RC_FILE"
    ;;
  *.fish)
    install_function_fish
    install_completion_fish
    ;;
esac

echo "Installation complete. Please restart your terminal or run:"
echo "  source $RC_FILE"
