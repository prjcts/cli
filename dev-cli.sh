#!/bin/bash

set -euo pipefail

CONFIG_DIR="$HOME/.local/share/prjcts"
VERSION_FILE="$CONFIG_DIR/version"
VERSION=$(<"$VERSION_FILE" 2>/dev/null || echo "0.1.0")
DIRS_FILE="$CONFIG_DIR/dirs"
TRIGGERS_FILE="$CONFIG_DIR/triggers"
COMMAND_FILE="$CONFIG_DIR/command"
BIN_PATH="$HOME/.local/bin/dev-cli"

mkdir -p "$CONFIG_DIR"

cmd_help() {
  cat <<EOF
Usage: dev [command] [options]

Commands:
  dev                            Launch project picker and open with configured command
  dev add                        Add a project directory (default)
  dev add -t, --triggers         Add a project trigger (e.g. .git)
  dev add -d, --directories      Add a project directory
  dev clean                      Remove a project directory (default)
  dev clean -t, --triggers       Remove a trigger
  dev clean -d, --directories    Remove a project directory
  dev set -c, --command          Set the launch command (e.g. nvim, code)
  dev show command               Show the current launch command
  dev uninstall                  Remove dev CLI, config, and shell function
  dev triggers                   Open the trigger list for manual editing
  dev --version                  Show the current version
  dev help                       Show this help message

Current launch command: $(<"$COMMAND_FILE" 2>/dev/null || echo "(not set)")
EOF
}

cmd_set() {
  case "${1:-}" in
    -c|--command)
      read -r -e -p "Enter the launch command (e.g. nvim, code, emacs): " editor_cmd
      if [[ -z "$editor_cmd" ]]; then
        echo "Canceled."
        return
      fi
      echo "$editor_cmd" > "$COMMAND_FILE"
      echo "Set launch command to: $editor_cmd"
      ;;
    *)
      echo "Invalid option for 'set'"
      exit 1
      ;;
  esac
}

cmd_show() {
  case "${1:-}" in
    command)
      if [[ -s "$COMMAND_FILE" ]]; then
        echo "Current launch command: $(<"$COMMAND_FILE")"
      else
        echo "No launch command set."
      fi
      ;;
    *)
      echo "Unknown 'show' option. Try: dev show command"
      ;;
  esac
}

cmd_uninstall() {
  echo "Uninstalling dev CLI..."

  echo "Removing CLI script at $BIN_PATH"
  rm -f "$BIN_PATH"

  echo "Removing config directory $CONFIG_DIR"
  rm -rf "$CONFIG_DIR"

  echo "Cleaning up shell rc files..."
  for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [[ -f "$rc_file" ]]; then
      sed -i.bak '/function dev()/,/^}/d' "$rc_file"
      sed -i.bak '/dev-completion\.zsh/d' "$rc_file"
      sed -i.bak '/fpath+=(.*prjcts.*)/d' "$rc_file"
      sed -i.bak '/autoload -Uz compinit && compinit/d' "$rc_file"
      echo "Updated $rc_file (backup saved as $rc_file.bak)"
    fi
  done

  echo "If you're using Fish, you may want to remove ~/.config/fish/functions/dev.fish and ~/.config/fish/completions/dev.fish manually."
  echo "Uninstall complete."
}

cmd_add() {
  local mode="directories"
  case "${1:-}" in
    -t|--triggers) mode="triggers" ;;
    -d|--directories|'') ;;
    *) echo "Invalid option for 'add'"; exit 1 ;;
  esac

  if [[ "$mode" == "directories" ]]; then
    read -r -e -p "Enter a directory to add: " input_dir
    if [[ -z "$input_dir" ]]; then
      echo "Canceled."
      return
    fi
    proj_dir=$(eval echo "$input_dir")
    if [[ ! -d "$proj_dir" ]]; then
      echo "Directory does not exist: $proj_dir"
      return
    fi
    if grep -Fxq "$proj_dir" "$DIRS_FILE" 2>/dev/null; then
      echo "Already in project list."
    else
      echo "$proj_dir" >> "$DIRS_FILE"
      echo "Added."
    fi
  else
    read -r -e -p "Enter a trigger file to add (e.g., .git): " trigger
    if [[ -z "$trigger" ]]; then
      echo "Canceled."
      return
    fi
    if grep -Fxq "$trigger" "$TRIGGERS_FILE" 2>/dev/null; then
      echo "Already in trigger list."
    else
      echo "$trigger" >> "$TRIGGERS_FILE"
      echo "Added."
    fi
  fi
}

cmd_clean() {
  local mode="directories"
  case "${1:-}" in
    -t|--triggers) mode="triggers" ;;
    -d|--directories|'') ;;
    *) echo "Invalid option for 'clean'"; exit 1 ;;
  esac

  local target_file
  [[ "$mode" == "directories" ]] && target_file="$DIRS_FILE" || target_file="$TRIGGERS_FILE"

  local -a map=()
  if [[ -f "$target_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      map+=("$line")
    done < "$target_file"
  fi

  if (( ${#map[@]:-0} == 0 )); then
    echo "No entries to clean."
    return
  fi

  echo "Saved $mode:"
  for i in "${!map[@]}"; do
    echo "$((i+1)). ${map[$i]}"
  done

  echo ""
  read -rp "Enter number to remove (or leave blank to cancel): " choice
  if [[ -n "$choice" && "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#map[@]} ]]; then
    unset 'map[choice-1]'
    if (( ${#map[@]:-0} > 0 )); then
      printf "%s\n" "${map[@]}" > "$target_file"
    else
      > "$target_file"
    fi
    echo "Removed."
  else
    echo "Canceled."
  fi
}

cmd_triggers() {
  ${EDITOR:-nvim} "$TRIGGERS_FILE"
}

cmd_main() {
  [[ ! -s "$DIRS_FILE" ]] && { echo "No project directories found."; cmd_add --directories; echo "Now try running 'dev' again."; exit 0; }
  [[ ! -s "$COMMAND_FILE" ]] && { echo "No launch command set."; cmd_set --command; echo "Now try running 'dev' again."; exit 0; }
  [[ ! -s "$TRIGGERS_FILE" ]] && { echo -e ".git\npackage.json" > "$TRIGGERS_FILE"; }

  local -a triggers=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    triggers+=("$line")
  done < "$TRIGGERS_FILE"

  find_projects() {
    while IFS= read -r root; do
      [[ -d "$root" ]] || continue

      for trigger in "${triggers[@]}"; do
        [[ -e "$root/$trigger" ]] && echo "$root" && break
      done

      find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r dir; do
        for trigger in "${triggers[@]}"; do
          [[ -e "$dir/$trigger" ]] && echo "$dir" && break
        done
      done
    done < "$DIRS_FILE"
  }

  local editor_cmd selected
  editor_cmd=$(<"$COMMAND_FILE")
  selected=$(find_projects | sort -u | fzf --prompt="Select project: ")
  [[ -n "$selected" ]] && exec "$editor_cmd" "$selected"
}

case "${1:-}" in
  -h|--help|help) cmd_help ;;
  -v|--version|version) echo "dev version $VERSION" ;;
  add) shift; cmd_add "$@" ;;
  clean) shift; cmd_clean "$@" ;;
  set) shift; cmd_set "$@" ;;
  show) shift; cmd_show "$@" ;;
  uninstall) cmd_uninstall ;;
  triggers) cmd_triggers ;;
  *) cmd_main ;;
esac
