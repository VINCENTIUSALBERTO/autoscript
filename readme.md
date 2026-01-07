You are a senior DevOps engineer and Linux automation expert.

Your task is to generate a production-ready VPS autoscript with the following requirements:


GENERAL RULES:
- Code must be clean, modular, readable, and maintainable.
- Use Bash scripting best practices.
- Avoid hardcoded values; use variables and config files.
- Implement proper error handling and logging.
- Use functions for each menu feature.
- Display clear user-friendly output.
- Validate user input.
- Add comments for important logic only (no noise).
- Script must be safe to rerun (idempotent).
- Follow separation of concerns.

SYSTEM TARGET:
- OS: Support Ubuntu and Debian
- VPS environment
- Root access assumed

SCRIPT FEATURES:

1. Display VPS Information:
   - IP Address
   - Domain
   - OS Version
   - Kernel Version
   - Certificate Expiry (V2Ray)

2. MAIN MENU:
   1. V2Ray VMess
   2. V2Ray VLESS

3. SYSTEM MENU:
   3. Telegram Owner:
      - Create, edit, delete, renew, read akun vless/vmess

   4. Backup System:
      - Backup config files
      - Send backup to Telegram
      - Restore option

   5. Add / Change Domain VPS
   6. Change Port Service
   7. Change DNS Server
   8. Renew V2Ray Certificate
   9. Webmin Menu
   10. Check RAM Usage
   11. Reboot VPS (with confirmation)
   12. Speedtest VPS
   13. Display System Information
   14. Info Script
   15. Check Service Error (systemctl & journalctl)

0. Exit Menu

TECHNICAL REQUIREMENTS:
- Use systemctl for service management
- Use journalctl for error checking
- Use curl/wget safely
- Use colors for menu display
- Implement logging to /var/log/autoscript.log

OUTPUT:
- Provide full bash script
- Include brief explanation of script architecture
- Ensure script can be extended easily

IMPORTANT:
Do NOT generate minimal or toy code.
Think like this script will be used long-term on real VPS servers.
