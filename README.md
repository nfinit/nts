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

### Terminal Menu System (menu)

`menu` provides a customizable terminal-based interface that allows users to select and execute commands from a configured list. It supports both system-wide defaults and user-specific configurations, with the ability to run in a restricted "captive" mode for controlled environments.

#### Basic Usage

```
menu [options]
```

#### Options

- `-v, --version` - Display version information
- `-h, --help` - Display help message

#### Configuration

The menu system uses several configuration files:

**System-wide configuration:**
- `/opt/nts/etc/menu.conf` - Defines default menu entries (format: `Label=command`)
- `/opt/nts/etc/config` - System settings including banner configuration and captive mode
- `/opt/nts/etc/banner.txt` - Default banner displayed at the top of the menu
- `/opt/nts/etc/allowed-commands` - Commands allowed in captive mode
- `/opt/nts/etc/bypass-groups` - Groups that can bypass captive mode restrictions

**User configuration:**
- `~/.config/nts/menu.conf` - User-defined menu entries (overrides system defaults)
- `~/.config/nts/config` - User preferences and settings

#### Examples

```bash
# Launch the menu with default settings
menu

# Set as a user's login shell for restricted access
chsh -s /opt/nts/bin/menu username
```

#### Menu Configuration Format

Menu configuration files use a simple key=value format:

```
System Info=uname -a
Disk Usage=df -h
Text Editor=vi
Remote Access=ria
```

#### Captive Mode

The menu system can operate in a restricted "captive" mode where users cannot exit the menu and can only execute approved commands. This is configured through the system config file by setting `captive-mode=yes`. Administrators can define which commands are allowed and which user groups can bypass restrictions.

**Please note that this mode is still untested.**

#### Dependencies

`menu` is designed to be highly compatible with various Unix environments and does not have any external dependencies beyond utility scripts included with the NTS distribution.

## Installation
- Clone this repository into `/opt` on the target system
- Ensure `/opt/nts/bin` is in `$PATH`
