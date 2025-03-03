#!/bin/sh
# reverse-lines - Reverse the order of lines from input
# Part of the NTS (New Terminal System)
# 
# This utility provides a portable way to reverse lines of text,
# similar to GNU 'tac' but works on BSD and other UNIX systems.

# Print usage information
print_usage() {
  echo "Usage: reverse-lines [file]"
  echo ""
  echo "Reverses the order of lines from input."
  echo ""
  echo "If a file is specified, reads from the file."
  echo "Otherwise, reads from standard input."
  echo ""
  echo "Examples:"
  echo "  reverse-lines file.txt     # Reverse lines from file.txt"
  echo "  cat file.txt | reverse-lines  # Same as above"
  echo "  echo -e \"line1\\nline2\" | reverse-lines  # Outputs line2 then line1"
  echo ""
}

# Main function
main() {
  # Check for help option
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_usage
    exit 0
  fi
  
  # If file is specified, use it as input
  if [ -n "$1" ]; then
    if [ ! -f "$1" ]; then
      echo "Error: File not found: $1" >&2
      exit 1
    fi
    sed '1!G;h;$!d' "$1"
  else
    # Otherwise read from stdin
    sed '1!G;h;$!d'
  fi
}

# Execute main function
main "$@"
