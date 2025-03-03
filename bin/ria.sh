#!/bin/sh
# ria - Remote Interactive Access
# A unified interface for connecting to NTS hosts via various protocols
# Part of the NTS (New Terminal System)

# Protocol priority and port mapping
# Format: protocol_name:default_port
PROTOCOLS="ssh:22 telnet:23"

# Function to print usage information
print_usage() {
  echo "Usage: ria [options] hostname"
  echo ""
  echo "Options:"
  echo "  -u, --user USERNAME   Specify username for connection"
  echo "  -p, --port PORT       Specify custom port for connection"
  echo "  -q, --quiet           Suppress non-error messages"
  echo "  -v, --verbose         Show detailed connection information"
  echo "  -h, --help            Display this help message"
  echo ""
  echo "Examples:"
  echo "  ria server1                  Connect to server1 using best available protocol"
  echo "  ria -u admin server2         Connect to server2 as user 'admin'"
  echo "  ria -p 2222 server3          Connect to server3 on port 2222"
  echo ""
}

# Function to log messages based on verbosity level
log_msg() {
  level=$1
  message=$2
  
  if [ "$level" = "error" ]; then
    echo "ERROR: $message" >&2
    return
  fi
  
  if [ "$quiet" = "true" ]; then
    return
  fi
  
  if [ "$level" = "info" ] || [ "$verbose" = "true" ]; then
    echo "$message" >&2
  fi
}

# Function to check if a port is open using the checkport utility
check_port() {
  host=$1
  port=$2
  
  # Use the checkport utility if available
  if command -v checkport >/dev/null 2>&1; then
    checkport -t 3 "$host" "$port" >/dev/null 2>&1
    return $?
  fi
  
  # Fallback methods if checkport isn't available
  log_msg "debug" "checkport utility not found, using fallback methods"
  
  # Try nc if available
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 3 "$host" "$port" >/dev/null 2>&1
    return $?
  fi
  
  # Try nmap if available
  if command -v nmap >/dev/null 2>&1; then
    nmap -p "$port" -T4 --max-retries 1 --host-timeout 3s "$host" | grep -q "open" >/dev/null 2>&1
    return $?
  fi
  
  # Try a direct connection as last resort (bash-specific)
  (echo > "/dev/tcp/$host/$port") >/dev/null 2>&1
  return $?
}

# Function to attempt SSH connection
connect_ssh() {
  host=$1
  port=$2
  user=$3
  
  log_msg "debug" "Attempting SSH connection to $host:$port"
  
  # Check if ssh command is available
  if ! command -v ssh >/dev/null 2>&1; then
    log_msg "debug" "SSH client not available"
    return 1
  fi
  
  # Construct SSH command
  ssh_cmd="ssh"
  
  # Add port if specified and not default
  if [ -n "$port" ] && [ "$port" != "22" ]; then
    ssh_cmd="$ssh_cmd -p $port"
  fi
  
  # Add user if specified
  if [ -n "$user" ]; then
    ssh_cmd="$ssh_cmd ${user}@${host}"
  else
    ssh_cmd="$ssh_cmd $host"
  fi
  
  log_msg "info" "Connecting via SSH..."
  $ssh_cmd
  return $?
}

# Function to attempt Telnet connection
connect_telnet() {
  host=$1
  port=$2
  
  log_msg "debug" "Attempting Telnet connection to $host:$port"
  
  # Check if telnet command is available
  if ! command -v telnet >/dev/null 2>&1; then
    log_msg "debug" "Telnet client not available"
    return 1
  fi
  
  # Construct Telnet command
  if [ -n "$port" ] && [ "$port" != "23" ]; then
    log_msg "info" "Connecting via Telnet to port $port..."
    telnet "$host" "$port"
  else
    log_msg "info" "Connecting via Telnet..."
    telnet "$host"
  fi
  
  # On BSD systems, telnet often returns the exit code of the remote shell
  # which doesn't necessarily indicate connection failure.
  # If we got this far, assume the connection worked and the user has completed their session
  return 0
}

# Main function
main() {
  # Initialize variables
  host=""
  port=""
  user=""
  quiet="false"
  verbose="false"
  
  # Parse command line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -u|--user)
        shift
        user="$1"
        ;;
      -p|--port)
        shift
        port="$1"
        ;;
      -q|--quiet)
        quiet="true"
        ;;
      -v|--verbose)
        verbose="true"
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        if [ -z "$host" ]; then
          host="$1"
        else
          log_msg "error" "Unexpected argument: $1"
          print_usage
          exit 1
        fi
        ;;
    esac
    shift
  done
  
  # Check if hostname is provided
  if [ -z "$host" ]; then
    log_msg "error" "No hostname specified"
    print_usage
    exit 1
  fi
  
  # Custom port handling
  if [ -n "$port" ]; then
    log_msg "debug" "Custom port specified: $port"
    
    # Check if the port is open
    if ! check_port "$host" "$port"; then
      log_msg "error" "Port $port is not open on $host"
      exit 1
    fi
    
    # Try to determine protocol based on common port numbers
    case "$port" in
      22|222|2222)
        connect_ssh "$host" "$port" "$user"
        exit $?
        ;;
      23|2323)
        connect_telnet "$host" "$port"
        exit $?
        ;;
      *)
        # For non-standard ports, try SSH first, then telnet
        log_msg "debug" "Trying protocols on custom port $port"
        
        connect_ssh "$host" "$port" "$user"
        ssh_exit=$?
        if [ $ssh_exit -eq 0 ]; then
          exit 0
        fi
        
        log_msg "debug" "SSH failed, trying Telnet"
        connect_telnet "$host" "$port"
        exit $?
        ;;
    esac
  fi
  
  # Check and try protocols in order of preference
  connection_attempted=false
  
  for protocol_info in $PROTOCOLS; do
    protocol=$(echo "$protocol_info" | cut -d ':' -f 1)
    default_port=$(echo "$protocol_info" | cut -d ':' -f 2)
    
    log_msg "debug" "Checking protocol: $protocol (port $default_port)"
    
    # Check if the port for this protocol is open
    if check_port "$host" "$default_port"; then
      log_msg "debug" "$protocol port is open on $host"
      connection_attempted=true
      
      # Try to connect using the protocol
      case "$protocol" in
        ssh)
          connect_ssh "$host" "$default_port" "$user"
          exit_code=$?
          if [ $exit_code -eq 0 ]; then
            exit 0
          fi
          log_msg "debug" "SSH connection failed with exit code $exit_code"
          ;;
        telnet)
          connect_telnet "$host" "$default_port"
          exit_code=$?
          if [ $exit_code -eq 0 ]; then
            exit 0
          fi
          log_msg "debug" "Telnet connection failed with exit code $exit_code"
          ;;
      esac
    else
      log_msg "debug" "$protocol port is not open on $host"
    fi
  done
  
  # If we got here, all connection methods failed
  if [ "$connection_attempted" = "true" ]; then
    log_msg "error" "All connection attempts to $host failed"
  else
    log_msg "error" "No supported connection methods available for $host"
  fi
  exit 1
}

# Execute main function
main "$@"
