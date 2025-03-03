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
  reversed_labels=$(echo "$menu_labels" | tr ':' '\n' | tac | tr '\n' ':')
  reversed_commands=$(echo "$menu_commands" | tr ':' '\n' | tac | tr '\n' ':')
  
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
  
  echo " q) Quit"
  echo ""
  
  # Get user selection
  printf "Enter selection: "
  read -r selection
  
  # Process selection
  case "$selection" in
    q|Q)
      echo "Exiting menu..."
      exit 0
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
