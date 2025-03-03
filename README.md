# The New Terminal System
This repository stores scripts and utilities supporting a multi-system interactive Unix shell environment that provides a variety of services to users via CLI and TUI front-ends. On NTS hosts, the contents of this repository is intended to reside in `/opt/nts`.

## Utilities

### Remote Interactive Access (ria)

`ria` provides a unified interface for connecting to NTS hosts within the network that support various protocols. It automatically detects and uses the best available protocol (SSH or Telnet) for each target host, always attempting SSH first when supported.

#### Basic Usage

```
ria [options] hostname
```

#### Options

- `-u, --user USERNAME` - Specify username for connection
- `-p, --port PORT` - Specify custom port for connection
- `-q, --quiet` - Suppress non-error messages
- `-v, --verbose` - Show detailed connection information
- `-h, --help` - Display help message

#### Examples

```bash
# Connect to a host using the best available protocol
ria server1

# Connect with a specific username
ria -u admin server2

# Connect to a non-standard SSH port
ria -p 2222 server3

# Show detailed connection information
ria -v legacy-host
```

#### Dependencies

`ria` naturally requires SSH and/or Telnet clients on the host system. For port checking, the `checkport` utility supports `nc` and `nmap` if available. The command will automatically adapt to use whatever tools are available on the local system.

## Installation
- Clone this repository into `/opt` on the target system
- Ensure `/opt/nts/bin` is in `$PATH`
