#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.local/share/prjcts"
DEV_BIN="$BIN_DIR/dev-cli"
VERSION_FILE="$CONFIG_DIR/version"
GITHUB_REPO="prjcts/cli"
VERSION="{{VERSION}}"
BASE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$VERSION"

mkdir -p "$BIN_DIR" "$CONFIG_DIR"

echo "📦 Installing dev CLI..."

# Detect local clone vs GitHub install
if [[ -f "./dev-cli" && -f "./version" ]]; then
  echo "🛠 Installing from local clone..."
  cp ./dev-cli "$DEV_BIN"
  cp ./version "$VERSION_FILE"
else
  echo "🌐 Installing from GitHub release..."
  curl -fsSL "$BASE_URL/dev-cli" -o "$DEV_BIN"
  curl -fsSL "$BASE_URL/version" -o "$VERSION_FILE"
fi

chmod +x "$DEV_BIN"
echo "✅ Installed dev-cli to $DEV_BIN"
echo "✅ Version set to $(<"$VERSION_FILE")"

# Detect shell config
detect_shell_rc() {
  case "$SHELL" in
    */zsh) echo "$HOME/.zshrc" ;;
    */bash) echo "$HOME/.bashrc" ;;
    */fish) echo "$HOME/.config/fish/config.fish" ;;
    *) echo "$HOME/.profile" ;;
  esac
}

# Zsh/Bash shell function
install_function_zsh_bash() {
  local rc_file="$1"
  if ! grep -q "function dev()" "$rc_file"; then
    echo "🧩 Adding dev() to $rc_file"
    cat <<'EOF' >> "$rc_file"

function dev() {
  local config="$HOME/.local/share/prjcts/command"
  local cmd

  if [[ $# -gt 0 ]]; then
    "$HOME/.local/bin/dev-cli" "$@"
    return
  fi

  local dir
  dir=$( "$HOME/.local/bin/dev-cli" )
  local exit_code=$?

  if [[ $exit_code -ne 0 || -z "$dir" || ! -d "$dir" ]]; then
    return $exit_code
  fi

  cmd=$(<"$config")
  cd "$dir" || return
  echo -ne "\033]0;${cmd}: ${dir##*/}\007"
  exec "$cmd" "$dir"
}
EOF
  else
    echo "✔ dev function already present in $rc_file"
  fi
}

# Fish shell function
install_function_fish() {
  local config="$HOME/.config/fish/functions/dev.fish"
  mkdir -p "$(dirname "$config")"
  echo "🧩 Installing Fish function to $config"
  cat > "$config" <<'EOF'
function dev
  if test (count $argv) -gt 0
    command dev-cli $argv
    return
  end

  set dir (bash -c "$HOME/.local/bin/dev-cli")
  set cmd (cat "$HOME/.local/share/prjcts/command" 2>/dev/null)
  if test -n "$dir"
    cd $dir
    printf "\033]0;%s: %s\007" $cmd (basename $dir)
    exec $cmd $dir
  end
end
EOF
}

# Install shell function
RC_FILE=$(detect_shell_rc)
case "$RC_FILE" in
  *.zshrc|*.bashrc|*.profile)
    install_function_zsh_bash "$RC_FILE"
    ;;
  *.fish)
    install_function_fish
    ;;
esac

echo "✅ dev CLI installed successfully!"
echo "💡 To activate 'dev', run: source $RC_FILE"
echo "🩺 Then try: dev doctor"
