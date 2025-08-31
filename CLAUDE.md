# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **Exarch Scripts** repository - a collection of post-installation setup scripts specifically designed for Omarchy Linux (Arch-based distro with Hyprland). The main script (`install.sh`) provides an interactive menu system for installing and configuring development tools, applications, and system optimizations.

## Key Commands

### Running the main script
```bash
# Interactive menu mode (default)
./install.sh

# Debug mode - simulates without installing
./install.sh --debug

# Test 1Password integration only
./install.sh --1pass

# Force Dell XPS 13 Plus mode
./install.sh --xps
```

### Testing and validation
```bash
# Check script syntax
bash -n install.sh

# Run in debug mode to see what would be installed
./install.sh --debug
```

## Architecture and Structure

### Core Script: install.sh

The main installation script is structured as follows:

1. **Configuration Variables (lines 44-75)**: Boolean flags for each installable component
2. **Menu System (lines 347-770)**: Interactive ncurses-style menu with keyboard navigation
3. **Installation Functions (lines 900-2500)**: Individual functions for each component
4. **Background Job System**: Parallel installation support for faster execution
5. **Logging System**: Comprehensive logging with colored output and summary report

### Key Functions

- `interactive_menu()`: Main menu system with arrow key navigation
- `setup_temporary_dns()`: Configures temporary DNS for installation session
- `pac()` / `aur()`: Wrapper functions for package installation with logging
- `setup_dev_pgpass()`: 1Password integration for PostgreSQL credentials (lines 2199-2362)
- `setup_dell_xps_9320_*()`: Dell XPS specific optimizations and webcam support
- `configure_mise_runtimes()`: Sets up Node.js and .NET via mise
- `setup_dotfiles_management()`: Chezmoi + Age configuration for dotfiles

### Installation Flow

1. DNS setup (temporary 8.8.8.8/1.1.1.1)
2. Interactive menu or direct execution
3. Parallel package installation via background jobs
4. Runtime configuration (mise, npm packages)
5. Configuration file synchronization
6. Hardware-specific optimizations (if applicable)
7. Summary report generation

### Special Features

#### 1Password Integration (--1pass mode)
- Automatically installs dependencies (jq, 1password-cli)
- Authenticates with 1Password CLI
- Searches for database credentials
- Generates `.pgpass` file with proper permissions

#### Dell XPS 13 Plus Support
- Auto-detects hardware
- Installs IPU6 webcam drivers
- Configures power management (TLP, thermald)
- Sets up proper kernel modules

#### Parallel Installation
- Uses background jobs for faster installation
- Real-time progress tracking
- Comprehensive error handling

## Important Notes

- The script requires Omarchy Linux (or Arch with yay, mise, hyprland pre-installed)
- Must be run with sudo privileges but NOT as root user
- DNS is temporarily modified during execution and restored on exit
- All installations are logged to `/tmp/exarch_install_*.log`
- The script is idempotent - safe to run multiple times

## Common Development Tasks

### Adding a new package
1. Add a boolean flag variable (e.g., `INSTALL_NEWAPP=true`)
2. Add menu entry in `show_menu()` function
3. Update `toggle_option()` case statement
4. Create installation function or add to existing category
5. Add to main execution flow if needed

### Modifying menu behavior
- Menu rendering: `show_menu()` function
- Navigation logic: `interactive_menu()` function
- Toggle logic: `toggle_option()` function
- Profile presets: Look for cases 'a', 'r', 'd' in toggle_option

### Debugging installations
- Use `--debug` flag for simulation mode
- Check logs in `/tmp/exarch_install_*.log`
- Look for `[ERR]`, `[ !! ]` markers in output
- Background job logs are in `/tmp/exarch_job_*.log`

## Error Handling

The script uses several error handling strategies:
- `warn()`: Non-critical failures that allow continuation
- `err()`: Critical failures that stop execution
- `FAILED_PACKAGES` array: Tracks failed installations
- Automatic DNS restoration on exit via trap handlers
- Background job monitoring with timeout detection

## Hardware Detection

The script automatically detects:
- Dell XPS 13 Plus (9320) via `dmidecode`
- Offers hardware-specific configurations when detected
- Can be forced with `--xps` flag for testing

## GIT
- Always generate commit messages in English and without Claude as author.
