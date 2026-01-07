# VPS Autoscript Management System

A production-ready VPS management script with modular architecture for Ubuntu and Debian systems.

## Features

### V2Ray Management
- **VMess Account Management**: Create, view, renew, delete, and check VMess accounts
- **VLESS Account Management**: Create, view, renew, delete, and check VLESS accounts
- Automatic UUID generation
- Connection link generation (VMess/VLESS)
- Account expiration tracking

### System Management
- **Telegram Integration**: Bot configuration, notifications, send accounts/backups
- **Backup System**: Full backup, accounts backup, Telegram upload, restore
- **Domain Management**: View, change domain, DNS verification, SSL generation
- **Port Management**: View and change ports for VMess, VLESS, SSH, Webmin
- **DNS Management**: Preset DNS (Google, Cloudflare, etc.) or custom DNS
- **Certificate Management**: View, renew, import, auto-renewal setup
- **Webmin Integration**: Install, configure, manage Webmin

### Monitoring & Tools
- RAM usage monitoring with visual bar
- VPS speedtest
- System information display
- Service error checking (systemctl & journalctl)
- Safe VPS reboot with confirmation

## Requirements

- **OS**: Ubuntu 18.04+ or Debian 10+
- **Access**: Root privileges required
- **Dependencies**: 
  - `jq` (for JSON processing)
  - `curl` or `wget`
  - `openssl` (for certificate management)
  - Optional: `certbot`, `speedtest-cli`

## Installation

```bash
# Clone the repository
git clone https://github.com/VINCENTIUSALBERTO/autoscript.git
cd autoscript

# Make scripts executable
chmod +x menu.sh
chmod +x lib/*.sh
chmod +x modules/*.sh

# Run the script (requires root)
sudo ./menu.sh
```

## Directory Structure

```
autoscript/
├── menu.sh                 # Main entry point
├── config/
│   ├── settings.conf       # Main configuration
│   └── ports.conf          # Port configuration
├── lib/
│   ├── colors.sh           # Color definitions
│   ├── utils.sh            # Utility functions
│   └── system.sh           # System functions
└── modules/
    ├── vmess.sh            # VMess management
    ├── vless.sh            # VLESS management
    ├── telegram.sh         # Telegram integration
    ├── backup.sh           # Backup/restore
    ├── domain.sh           # Domain management
    ├── port.sh             # Port management
    ├── dns.sh              # DNS management
    ├── certificate.sh      # SSL certificate management
    ├── webmin.sh           # Webmin management
    └── services.sh         # Service monitoring
```

## Configuration

### Main Configuration (`config/settings.conf`)

```bash
# VPS Settings
VPS_DOMAIN=""           # Your domain name
VPS_IP=""               # Server IP (auto-detected)

# Telegram Settings
TELEGRAM_BOT_TOKEN=""   # Bot token from @BotFather
TELEGRAM_CHAT_ID=""     # Your chat ID

# V2Ray Settings
V2RAY_PORT_VMESS="443"
V2RAY_PORT_VLESS="8443"
V2RAY_PATH_VMESS="/vmess"
V2RAY_PATH_VLESS="/vless"

# Backup Settings
BACKUP_DIR="/root/backup"
BACKUP_RETENTION_DAYS="30"
```

## Menu Structure

```
MAIN MENU
├── 1. V2Ray VMess Menu
│   ├── Create Account
│   ├── View Accounts
│   ├── Renew Account
│   ├── Delete Account
│   └── Check Account Details
├── 2. V2Ray VLESS Menu (same structure)
├── 3. Telegram Owner
├── 4. Backup System
├── 5. Add / Change Domain
├── 6. Change Port Service
├── 7. Change DNS Server
├── 8. Renew V2Ray Certificate
├── 9. Webmin Menu
├── 10. Check RAM Usage
├── 11. Reboot VPS
├── 12. Speedtest VPS
├── 13. Display System Information
├── 14. Info Script
├── 15. Check Service Error
└── 0. Exit
```

## Logging

All actions are logged to `/var/log/autoscript.log` with timestamps:

```
[2024-01-01 12:00:00] [INFO] VPS Autoscript started
[2024-01-01 12:01:00] [INFO] Created VMess account: user1 (expires: 2024-01-31)
[2024-01-01 12:02:00] [WARN] Domain DNS not found
```

## Technical Details

- **Idempotent**: Safe to rerun without side effects
- **Error Handling**: Comprehensive error catching and logging
- **Input Validation**: All user inputs are validated
- **Modular Design**: Each feature is a separate module
- **Colors**: Full terminal color support for better UX
- **Service Management**: Uses systemctl for service control
- **Journal Integration**: Uses journalctl for error checking

## Extending the Script

### Adding a New Module

1. Create a new file in `modules/` directory
2. Source required libraries:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
```
3. Implement your menu function `show_yourmodule_menu()`
4. Add the module to `menu.sh`

### Adding a New Menu Option

1. Add the option number in `show_main_menu()`
2. Create the corresponding function
3. Add the case statement handler

## License

MIT License

## Author

VPS Autoscript
