#!/bin/sh
# hr - Horizontal Rule
# Prints a horizontal line across the terminal width
# Part of the NTS (New Terminal System)

# Print usage information
print_usage() {
  echo "Usage: hr [options]"
  echo ""
  echo "Options:"
  echo "  -c, --char CHAR     Character to use for the line (default: -)"
  echo "  -l, --length NUM    Specific length to use (default: terminal width-1)"
  echo "  -h, --help          Display this help message"
  echo ""
  echo "Examples:"
  echo "  hr                  Print a dashed line across the terminal"
  echo "  hr -c =             Print a line of equal signs"
  echo "  hr -l 40            Print a 40-character line"
  echo "  hr -c '*' -l 50     Print a 50-character line of asterisks"
}

# Detect terminal width using various methods
get_terminal_width() {
  width=0
  
  # Try using tput if available
  if command -v tput >/dev/null 2>&1; then
    width=$(tput cols 2>/dev/null)
  fi
  
  # If tput failed or isn't available, try stty
  if [ -z "$width" ] || [ "$width" -eq 0 ]; then
    if command -v stty >/dev/null 2>&1; then
      width=$(stty size 2>/dev/null | cut -d' ' -f2)
    fi
  fi
  
  # Try COLUMNS environment variable
  if [ -z "$width" ] || [ "$width" -eq 0 ]; then
    if [ -n "$COLUMNS" ]; then
      width=$COLUMNS
    fi
  fi
  
  # Fall back to a reasonable default
  if [ -z "$width" ] || [ "$width" -eq 0 ]; then
    width=80
  fi
  
  # Adjust to leave one character at the end (to prevent wrapping)
  width=$((width - 1))
  
  echo "$width"
}

# Print a horizontal line of specified length with specified character
print_line() {
  char="$1"
  length="$2"
  
  # Create the line by repeating the character
  line=""
  i=0
  while [ "$i" -lt "$length" ]; do
    line="${line}${char}"
    i=$((i + 1))
  done
  
  # Print the line
  echo "$line"
}

# Main function
main() {
  # Initialize variables with defaults
  char="-"
  length=""
  
  # Parse command line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -c|--char)
        shift
        if [ -n "$1" ]; then
          # Take only the first character if more are provided
          char=$(echo "$1" | cut -c1)
        fi
        ;;
      -l|--length)
        shift
        length="$1"
        if ! echo "$length" | grep -q '^[0-9]\+$'; then
          echo "Error: Length must be a positive number" >&2
          print_usage
          exit 1
        fi
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
  
  # If no specific length given, detect terminal width
  if [ -z "$length" ]; then
    length=$(get_terminal_width)
  fi
  
  # Print the horizontal line
  print_line "$char" "$length"
}

# Execute main function
main "$@"
