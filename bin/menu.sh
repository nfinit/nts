#!/bin/sh
# menu - Terminal menuing system for NTS
# Part of the NTS (New Terminal System)

# Configuration paths
SYSTEM_CONFIG_DIR="/opt/nts/etc"
USER_CONFIG_DIR="${HOME}/.config/nts"
SYSTEM_MENU_FILE="${SYSTEM_CONFIG_DIR}/menu.conf"
USER_MENU_FILE="${USER_CONFIG_DIR}/menu.conf"
SYSTEM_CONFIG_FILE="${SYSTEM_CONFIG_DIR}/config"
USER_CONFIG_FILE="${USER_CONFIG_DIR}/config"
DEFAULT_BANNER_FILE="${SYSTEM_CONFIG_DIR}/banner.txt"
ALLOWED_COMMANDS_FILE="${SYSTEM_CONFIG_DIR}/allowed-commands"
BYPASS_GROUPS_FILE="${SYSTEM_CONFIG_DIR}/bypass-groups"

# Constants
VERSION="1.0.0"

# Print usage information
print_usage() {
  echo "Usage: menu [options]"
  echo ""
  echo "Options:"
  echo "  -v, --version     Display version information"
  echo "  -h, --help        Display this help message"
  echo ""
}

# Clear the screen in a terminal-compatible way
clear_screen() {
  # Use the clear command if available
  if command -v clear >/dev/null 2>&1; then
    clear
  else
    # Fall back to ANSI escape sequence
    printf "\033c"
  fi
}

# Display the banner/title
display_banner() {
  banner_command=""
  banner_file=""
  
  # Check user config for custom banner command or file
  if [ -f "$USER_CONFIG_FILE" ]; then
    banner_command=$(grep "^banner_command=" "$USER_CONFIG_FILE" | cut -d= -f2-)
    banner_file=$(grep "^banner_file=" "$USER_CONFIG_FILE" | cut -d= -f2-)
  fi
  
  # If no user config, check system config
  if [ -z "$banner_command" ] && [ -z "$banner_file" ] && [ -f "$SYSTEM_CONFIG_FILE" ]; then
    banner_command=$(grep "^banner_command=" "$SYSTEM_CONFIG_FILE" | cut -d= -f2-)
    banner_file=$(grep "^banner_file=" "$SYSTEM_CONFIG_FILE" | cut -d= -f2-)
  fi
  
  # If a banner command is specified, execute it
  if [ -n "$banner_command" ]; then
    eval "$banner_command"
    return
  fi
  
  # If a banner file is specified and exists, display it
  if [ -n "$banner_file" ] && [ -f "$banner_file" ]; then
    cat "$banner_file"
    return
  fi
  
  # Fall back to default banner if it exists
  if [ -f "$DEFAULT_BANNER_FILE" ]; then
    cat "$DEFAULT_BANNER_FILE"
    return
  fi
  
  # If no banner is found, show a simple text header
  echo "NTS Menu System v${VERSION}"
  echo "------------------"
}

# Load menu items from config files
load_menu_items() {
  # Initialize variables for storing menu items
  menu_labels=""
  menu_commands=""
  menu_count=0
  
  # Check if master menu should be loaded
  load_master="yes"
  if [ -f "$USER_CONFIG_FILE" ]; then
    disable_master=$(grep "^disable-master-menu=yes" "$USER_CONFIG_FILE")
    if [ -n "$disable_master" ]; then
      load_master="no"
    fi
  fi
  
  # Load system menu if enabled and exists
  if [ "$load_master" = "yes" ] && [ -f "$SYSTEM_MENU_FILE" ]; then
    while IFS= read -r line; do
      # Skip empty lines and comments
      case "$line" in
        ""|"#"*) continue ;;
      esac
      
      # Extract label and command
      label=$(echo "$line" | cut -d= -f1)
      command=$(echo "$line" | cut -d= -f2-)
      
      # Add item to the menu
      menu_labels="${menu_labels}:${label}"
      menu_commands="${menu_commands}:${command}"
      menu_count=$((menu_count + 1))
    done < "$SYSTEM_MENU_FILE"
  fi
  
  # Load user menu if it exists
  if [ -f "$USER_MENU_FILE" ]; then
    while IFS= read -r line; do
      # Skip empty lines and comments
      case "$line" in
        ""|"#"*) continue ;;
      esac
      
      # Extract label and command
      label=$(echo "$line" | cut -d= -f1)
      command=$(echo "$line" | cut -d= -f2-)
      
      # Check if this label already exists (for overriding)
      existing_index=0
      current_idx=1
      IFS=":"
      for existing_label in $menu_labels; do
        if [ "$existing_label" = "$label" ]; then
          existing_index=$current_idx
          break
        fi
        current_idx=$((current_idx + 1))
      done
      unset IFS
      
      if [ "$existing_index" -gt 0 ]; then
        # In Bourne shell, modifying items in a "string array" is tricky
        # For simplicity, we'll add the new entry and handle duplicates during display
        menu_labels="${menu_labels}:${label}"
        menu_commands="${menu_commands}:${command}"
      else
        # Add new item
        menu_labels="${menu_labels}:${label}"
        menu_commands="${menu_commands}:${command}"
        menu_count=$((menu_count + 1))
      fi
    done < "$USER_MENU_FILE"
  fi
  
  # Remove leading separators
  menu_labels=$(echo "$menu_labels" | sed 's/^://')
  menu_commands=$(echo "$menu_commands" | sed 's/^://')
}

# Check if the current user is a member of any bypass group
user_in_bypass_group() {
  # If the bypass groups file doesn't exist, no bypass
  if [ ! -f "$BYPASS_GROUPS_FILE" ]; then
    return 1
  fi
  
  # Try to get username
  current_user=""
  if [ -n "$USER" ]; then
    current_user="$USER"
  elif [ -n "$LOGNAME" ]; then
    current_user="$LOGNAME"
  elif command -v whoami >/dev/null 2>&1; then
    current_user=$(whoami)
  elif command -v id >/dev/null 2>&1; then
    current_user=$(id -un)
  fi
  
  # If we couldn't determine the username, assume not in bypass group
  if [ -z "$current_user" ]; then
    return 1
  fi
  
  # Try different methods to get user's groups
  user_groups=""
  
  # Method 1: Use id command with -G option (most systems)
  if command -v id >/dev/null 2>&1; then
    # Try to get numeric group IDs
    user_groups=$(id -G "$current_user" 2>/dev/null)
    
    # If that failed, try getting group names
    if [ -z "$user_groups" ]; then
      user_groups=$(id -Gn "$current_user" 2>/dev/null | tr ' ' '\n')
    fi
  fi
  
  # Method 2: Parse /etc/group directly (very broadly compatible)
  if [ -z "$user_groups" ] && [ -f "/etc/group" ]; then
    user_groups=$(grep -E ":([^:]*,)?$current_user(,[^:]*)?$" /etc/group | cut -d: -f1)
  fi
  
  # Now check if any of the user's groups are in the bypass file
  if [ -n "$user_groups" ]; then
    while IFS= read -r bypass_group; do
      # Skip comments and empty lines
      case "$bypass_group" in
        ""|\#*) continue ;;
      esac
      
      # Check if this bypass group is in the user's groups
      echo "$user_groups" | tr ' ' '\n' | grep -q "^$bypass_group$"
      if [ $? -eq 0 ]; then
        # User is in a bypass group
        return 0
      fi
      
      # Also check numeric group ID if the bypass group is numeric
      if echo "$bypass_group" | grep -q "^[0-9]\+$"; then
        echo "$user_groups" | tr ' ' '\n' | grep -q "^$bypass_group$"
        if [ $? -eq 0 ]; then
          # User is in a bypass group (numeric match)
          return 0
        fi
      fi
    done < "$BYPASS_GROUPS_FILE"
  fi
  
  # If we get here, user is not in any bypass group
  return 1
}

# Check if a command is allowed in captive mode
is_command_allowed() {
  input_cmd="$1"
  
  # Extract the main command (ignore arguments)
  main_cmd=$(echo "$input_cmd" | awk '{print $1}')
  
  # Check if the allowed commands file exists
  if [ -f "$ALLOWED_COMMANDS_FILE" ]; then
    # Check if the command is in the allowed list
    if grep -q "^$main_cmd$" "$ALLOWED_COMMANDS_FILE" 2>/dev/null; then
      return 0
    fi
    
    # Also check if we have a command with path that matches
    cmd_name=$(basename "$main_cmd")
    if grep -q "^$cmd_name$" "$ALLOWED_COMMANDS_FILE" 2>/dev/null; then
      return 0
    fi
    
    # Check for wildcard entries in the allowed list (e.g., vi*)
    while IFS= read -r allowed_pattern; do
      case "$allowed_pattern" in
        *\*)
          # Convert wildcard pattern to shell pattern
          pattern=$(echo "$allowed_pattern" | sed 's/\*/.*/g')
          if echo "$main_cmd" | grep -q "^$pattern$"; then
            return 0
          fi
          ;;
      esac
    done < "$ALLOWED_COMMANDS_FILE"
    
    # Command not found in allowed list
    return 1
  else
    # If no allowed commands file, use built-in safety list
    case "$main_cmd" in
      sh|bash|zsh|csh|ksh|tcsh|dash|rbash|fish)
        # Block common shells
        return 1
        ;;
      */sh|*/bash|*/zsh|*/csh|*/ksh|*/tcsh|*/dash|*/rbash|*/fish)
        # Block shells with path
        return 1
        ;;
      su|sudo|doas|pkexec|chsh)
        # Block privilege escalation
        return 1
        ;;
      nc|netcat|ncat|socat)
        # Block network tools that could be used to escape
        return 1
        ;;
      python*|perl|ruby|lua|php|node|nodejs)
        # Block scripting interpreters
        return 1
        ;;
      *)
        # Allow other commands
        return 0
        ;;
    esac
  fi
}

# Setup captive mode if configured
setup_captive_mode() {
  # Default captive mode setting
  captive_mode="no"
  allow_user_disable="no"
  
  # Check system config for captive mode
  if [ -f "$SYSTEM_CONFIG_FILE" ]; then
    system_captive=$(grep "^captive-mode=" "$SYSTEM_CONFIG_FILE" | cut -d= -f2-)
    user_disable=$(grep "^allow-user-disable-captive=" "$SYSTEM_CONFIG_FILE" | cut -d= -f2-)
    
    if [ "$system_captive" = "yes" ]; then
      captive_mode="yes"
    fi
    
    if [ "$user_disable" = "yes" ]; then
      allow_user_disable="yes"
    fi
  fi
  
  # Check user config for captive mode override if allowed
  if [ "$allow_user_disable" = "yes" ] && [ -f "$USER_CONFIG_FILE" ]; then
    user_captive=$(grep "^captive-mode=" "$USER_CONFIG_FILE" | cut -d= -f2-)
    if [ "$user_captive" = "no" ]; then
      captive_mode="no"
    fi
  fi
  
  # Check if user is in a bypass group - this overrides all captive mode settings
  if user_in_bypass_group; then
    captive_mode="no"
    echo "Captive mode bypassed due to group membership"
    sleep 1
  fi
  
  # Set up signal handling if captive mode is enabled
  if [ "$captive_mode" = "yes" ]; then
    # Trap common exit signals (SIGINT, SIGTERM, SIGTSTP)
    trap '' 2 15 20
    
    # Trap attempts to exit with Ctrl+D (EOF)
    trap 'echo "Exit disabled in captive mode"; sleep 1' EXIT
    
    # In true captive shells, also override the quit function
    handle_quit_captive="true"
  else
    # Reset traps if captive mode is disabled
    trap - 2 15 20 EXIT
    handle_quit_captive="false"
  fi
}

# Display menu and handle selection
display_menu() {
  # Clear the screen and show banner
  clear_screen
  display_banner
  echo ""
  
  # Use associative array to track displayed items (prevent duplicates)
  displayed_labels=""
  displayed_commands=""
  displayed_count=0
  
  # Process items from right to left (user overrides appear first)
  new_menu_labels=""
  new_menu_commands=""
  
  # Build deduplicated list (user entries take precedence)
  idx=1
  IFS=":"
  # Try to use reverse-lines utility, fall back to sed if not available
  if command -v reverse-lines >/dev/null 2>&1; then
    # Use the dedicated NTS utility for line reversal
    reversed_labels=$(echo "$menu_labels" | tr ':' '\n' | reverse-lines | tr '\n' ':')
    reversed_commands=$(echo "$menu_commands" | tr ':' '\n' | reverse-lines | tr '\n' ':')
  else
    # Fallback to inline sed for line reversal
    reversed_labels=$(echo "$menu_labels" | tr ':' '\n' | sed '1!G;h;$!d' | tr '\n' ':')
    reversed_commands=$(echo "$menu_commands" | tr ':' '\n' | sed '1!G;h;$!d' | tr '\n' ':')
  fi
  
  for label in $reversed_labels; do
    # Skip if already processed
    if echo "$displayed_labels" | grep -q ":$label:"; then
      continue
    fi
    
    # Get corresponding command
    command_idx=1
    command=""
    for cmd in $reversed_commands; do
      if [ "$command_idx" = "$idx" ]; then
        command="$cmd"
        break
      fi
      command_idx=$((command_idx + 1))
    done
    
    # Add to displayed items
    displayed_labels="${displayed_labels}:${label}:"
    displayed_commands="${displayed_commands}:${command}:"
    new_menu_labels="${label}:${new_menu_labels}"
    new_menu_commands="${command}:${new_menu_commands}"
    displayed_count=$((displayed_count + 1))
    
    idx=$((idx + 1))
  done
  
  # Remove trailing separators
  new_menu_labels=$(echo "$new_menu_labels" | sed 's/:$//')
  new_menu_commands=$(echo "$new_menu_commands" | sed 's/:$//')
  
  # Display menu items
  item_idx=1
  IFS=":"
  for label in $new_menu_labels; do
    printf " %2d) %s\n" "$item_idx" "$label"
    item_idx=$((item_idx + 1))
  done
  
  printf " %2s) %s\n" "q" "Quit"
  echo ""
  
  # Get user selection
  printf "Enter selection: "
  read -r selection
  
  # Process selection
  case "$selection" in
    q|Q)
      if [ "$handle_quit_captive" = "true" ]; then
        echo "Cannot exit in captive mode"
        sleep 1
        return
      else
        echo "Exiting menu..."
        exit 0
      fi
      ;;
    [0-9]*)
      # Convert string to number
      selection_num=$selection
      
      # Validate selection
      if [ "$selection_num" -lt 1 ] || [ "$selection_num" -gt "$displayed_count" ]; then
        echo "Invalid selection: $selection"
        sleep 1
        return
      fi
      
      # Get the corresponding command
      cmd=""
      idx=1
      IFS=":"
      for command in $new_menu_commands; do
        if [ "$idx" = "$selection_num" ]; then
          cmd="$command"
          break
        fi
        idx=$((idx + 1))
      done
      
      # Execute the command
      if [ -n "$cmd" ]; then
        # Check if in captive mode and if command is allowed
        if [ "$captive_mode" = "yes" ]; then
          if ! is_command_allowed "$cmd"; then
            echo "Error: Command not allowed in captive mode"
            sleep 2
            return
          fi
        fi
        
        # Clear screen and show what we're doing
        clear_screen
        echo "Executing: $cmd"
        echo "----------------------------"
        echo ""
        
        # Execute the command
        eval "$cmd"
        
        # Wait for user to acknowledge completion
        echo ""
        echo "----------------------------"
        echo "Command completed. Press Enter to continue..."
        read -r dummy
      fi
      ;;
    *)
      echo "Invalid selection: $selection"
      sleep 1
      ;;
  esac
}

# Main function
main() {
  # Configure signal handling for captive mode
  setup_captive_mode
  
  # Parse command line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -v|--version)
        echo "NTS Menu System v${VERSION}"
        exit 0
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        echo "Error: Unknown option: $1" >&2
        print_usage
        exit 1
        ;;
    esac
    shift
  done
  
  # Create user config directory if it doesn't exist
  if [ ! -d "$USER_CONFIG_DIR" ]; then
    mkdir -p "$USER_CONFIG_DIR"
  fi
  
  # Load menu items
  load_menu_items
  
  # Main menu loop
  while true; do
    display_menu
  done
}

# Execute main function
main "$@"
