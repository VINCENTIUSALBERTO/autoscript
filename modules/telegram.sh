#!/bin/bash
# ==============================================================================
# Telegram Integration Module
# Provides Telegram bot integration for notifications and account management
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"
[[ -z "$(type -t get_public_ip 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# Show Telegram menu
show_telegram_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                    TELEGRAM OWNER MENU                        ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} Configure Telegram Bot"
        echo -e "  ${BGREEN}2.${NC} Test Telegram Connection"
        echo -e "  ${BGREEN}3.${NC} Send Test Message"
        echo -e "  ${BGREEN}4.${NC} View Telegram Settings"
        echo ""
        echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
        echo -e "${BCYAN}               ACCOUNT MANAGEMENT VIA TELEGRAM                ${NC}"
        echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${BGREEN}5.${NC} Send Account Details to Telegram"
        echo -e "  ${BGREEN}6.${NC} Send All Accounts Summary"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) configure_telegram ;;
            2) test_telegram_connection ;;
            3) send_test_message ;;
            4) view_telegram_settings ;;
            5) send_account_to_telegram ;;
            6) send_all_accounts_summary ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Configure Telegram bot
configure_telegram() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                 CONFIGURE TELEGRAM BOT                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}To get a Telegram Bot Token:${NC}"
    echo "  1. Open Telegram and search for @BotFather"
    echo "  2. Send /newbot and follow instructions"
    echo "  3. Copy the token provided"
    echo ""
    echo -e "${CYAN}To get your Chat ID:${NC}"
    echo "  1. Search for @userinfobot on Telegram"
    echo "  2. Send /start"
    echo "  3. Copy your Chat ID"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    local bot_token chat_id
    
    # Get current values as defaults
    local current_token="${TELEGRAM_BOT_TOKEN:-}"
    local current_chat_id="${TELEGRAM_CHAT_ID:-}"
    
    if [[ -n "$current_token" ]]; then
        echo -e "${DIM}Current token: ${current_token:0:20}...${NC}"
    fi
    
    read -p "$(echo -e "${YELLOW}Enter Bot Token (leave empty to keep current):${NC} ")" bot_token
    
    if [[ -n "$current_chat_id" ]]; then
        echo -e "${DIM}Current Chat ID: $current_chat_id${NC}"
    fi
    
    read -p "$(echo -e "${YELLOW}Enter Chat ID (leave empty to keep current):${NC} ")" chat_id
    
    # Update if provided
    local config_file="${SCRIPT_DIR}/config/settings.conf"
    
    if [[ -n "$bot_token" ]]; then
        sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"$bot_token\"|" "$config_file"
        TELEGRAM_BOT_TOKEN="$bot_token"
    fi
    
    if [[ -n "$chat_id" ]]; then
        sed -i "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=\"$chat_id\"|" "$config_file"
        TELEGRAM_CHAT_ID="$chat_id"
    fi
    
    print_success "Telegram configuration updated"
    log_info "Telegram configuration updated"
    
    press_any_key
}

# Test Telegram connection
test_telegram_connection() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                TEST TELEGRAM CONNECTION                       ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        print_error "Telegram Bot Token not configured"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Testing connection to Telegram API...${NC}"
    
    local response
    response=$(curl -sf --max-time 10 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local bot_name
        bot_name=$(echo "$response" | jq -r '.result.username' 2>/dev/null)
        print_success "Connection successful!"
        echo -e "${CYAN}Bot username:${NC} @$bot_name"
    else
        print_error "Connection failed. Check your Bot Token."
    fi
    
    press_any_key
}

# Send test message
send_test_message() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  SEND TEST MESSAGE                            ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        print_error "Telegram not fully configured"
        press_any_key
        return
    fi
    
    local message="🔔 *VPS Autoscript Test Message*\n\n📍 *Server:* $(get_hostname)\n🌐 *IP:* $(get_public_ip)\n⏰ *Time:* $(date '+%Y-%m-%d %H:%M:%S')"
    
    echo -e "${CYAN}Sending test message...${NC}"
    
    if send_telegram_message "$message"; then
        print_success "Test message sent successfully!"
    else
        print_error "Failed to send message"
    fi
    
    press_any_key
}

# View Telegram settings
view_telegram_settings() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  TELEGRAM SETTINGS                            ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then
        echo -e "  ${CYAN}Bot Token:${NC} ${TELEGRAM_BOT_TOKEN:0:20}..."
    else
        echo -e "  ${CYAN}Bot Token:${NC} ${RED}Not configured${NC}"
    fi
    
    if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        echo -e "  ${CYAN}Chat ID:${NC}   $TELEGRAM_CHAT_ID"
    else
        echo -e "  ${CYAN}Chat ID:${NC}   ${RED}Not configured${NC}"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Send account details to Telegram
send_account_to_telegram() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}              SEND ACCOUNT TO TELEGRAM                         ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        print_error "Telegram not fully configured"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Select account type:${NC}"
    echo "  1. VMess"
    echo "  2. VLESS"
    echo ""
    
    local type_choice
    read -p "$(echo -e "${YELLOW}Select type:${NC} ")" type_choice
    
    local accounts_dir
    case $type_choice in
        1) accounts_dir="${ACCOUNTS_DIR}/vmess"; type_name="VMess" ;;
        2) accounts_dir="${ACCOUNTS_DIR}/vless"; type_name="VLESS" ;;
        *) print_error "Invalid option"; press_any_key; return ;;
    esac
    
    # List accounts
    echo ""
    echo -e "${CYAN}Available $type_name accounts:${NC}"
    local count=0
    for file in "${accounts_dir}"/*.json; do
        if [[ -f "$file" ]]; then
            local username
            username=$(jq -r '.username' "$file" 2>/dev/null)
            echo "  - $username"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_error "No $type_name accounts found"
        press_any_key
        return
    fi
    
    echo ""
    local username
    read -p "$(echo -e "${YELLOW}Enter username:${NC} ")" username
    
    local account_file="${accounts_dir}/${username}.json"
    if [[ ! -f "$account_file" ]]; then
        print_error "Account not found"
        press_any_key
        return
    fi
    
    # Get account details
    local uuid port path created expiry
    uuid=$(jq -r '.uuid' "$account_file")
    port=$(jq -r '.port' "$account_file")
    path=$(jq -r '.path' "$account_file")
    created=$(jq -r '.created' "$account_file")
    expiry=$(jq -r '.expiry' "$account_file")
    
    local domain
    domain=$(get_vps_domain)
    [[ "$domain" == "Not configured" ]] && domain=$(get_public_ip)
    
    # Generate link based on type
    local link
    if [[ "$type_name" == "VMess" ]]; then
        local vmess_json
        vmess_json=$(echo -n "{\"v\":\"2\",\"ps\":\"${username}\",\"add\":\"${domain}\",\"port\":\"${port}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"${path}\",\"tls\":\"tls\"}" | base64 -w 0)
        link="vmess://${vmess_json}"
    else
        link="vless://${uuid}@${domain}:${port}?path=${path}&security=tls&encryption=none&type=ws#${username}"
    fi
    
    # Format message
    local message="📦 *$type_name Account Details*\n\n👤 *Username:* \`$username\`\n🔑 *UUID:* \`$uuid\`\n🌐 *Domain:* \`$domain\`\n🔌 *Port:* \`$port\`\n📁 *Path:* \`$path\`\n📅 *Created:* $created\n⏰ *Expires:* $expiry\n\n🔗 *Link:*\n\`$link\`"
    
    echo -e "${CYAN}Sending account to Telegram...${NC}"
    
    if send_telegram_message "$message"; then
        print_success "Account sent to Telegram!"
    else
        print_error "Failed to send"
    fi
    
    press_any_key
}

# Send all accounts summary
send_all_accounts_summary() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}              SEND ALL ACCOUNTS SUMMARY                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        print_error "Telegram not fully configured"
        press_any_key
        return
    fi
    
    local vmess_count=0 vless_count=0
    local vmess_active=0 vless_active=0
    local current_epoch
    current_epoch=$(date +%s)
    
    # Count VMess accounts
    for file in "${ACCOUNTS_DIR}/vmess"/*.json; do
        if [[ -f "$file" ]]; then
            ((vmess_count++))
            local expiry exp_epoch
            expiry=$(jq -r '.expiry' "$file" 2>/dev/null)
            exp_epoch=$(date -d "$expiry" +%s 2>/dev/null)
            [[ "$exp_epoch" -gt "$current_epoch" ]] && ((vmess_active++))
        fi
    done
    
    # Count VLESS accounts
    for file in "${ACCOUNTS_DIR}/vless"/*.json; do
        if [[ -f "$file" ]]; then
            ((vless_count++))
            local expiry exp_epoch
            expiry=$(jq -r '.expiry' "$file" 2>/dev/null)
            exp_epoch=$(date -d "$expiry" +%s 2>/dev/null)
            [[ "$exp_epoch" -gt "$current_epoch" ]] && ((vless_active++))
        fi
    done
    
    local total=$((vmess_count + vless_count))
    local active=$((vmess_active + vless_active))
    
    local message="📊 *VPS Accounts Summary*\n\n🖥️ *Server:* $(get_hostname)\n🌐 *IP:* $(get_public_ip)\n\n📦 *VMess:* ${vmess_active}/${vmess_count} active\n📦 *VLESS:* ${vless_active}/${vless_count} active\n\n📈 *Total:* ${active}/${total} active accounts\n\n⏰ *Report Time:* $(date '+%Y-%m-%d %H:%M:%S')"
    
    echo -e "${CYAN}Sending summary to Telegram...${NC}"
    
    if send_telegram_message "$message"; then
        print_success "Summary sent to Telegram!"
    else
        print_error "Failed to send"
    fi
    
    press_any_key
}

# Send message to Telegram
send_telegram_message() {
    local message="$1"
    local parse_mode="${2:-Markdown}"
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 1
    fi
    
    local response
    response=$(curl -sf --max-time 30 \
        -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$(echo -e "$message")" \
        -d "parse_mode=${parse_mode}" \
        2>/dev/null)
    
    if echo "$response" | jq -e '.ok == true' &>/dev/null; then
        log_info "Telegram message sent successfully"
        return 0
    else
        log_error "Failed to send Telegram message"
        return 1
    fi
}

# Send file to Telegram
send_telegram_file() {
    local file_path="$1"
    local caption="${2:-}"
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    local response
    response=$(curl -sf --max-time 60 \
        -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
        -F "chat_id=${TELEGRAM_CHAT_ID}" \
        -F "document=@${file_path}" \
        -F "caption=${caption}" \
        2>/dev/null)
    
    if echo "$response" | jq -e '.ok == true' &>/dev/null; then
        log_info "Telegram file sent: $file_path"
        return 0
    else
        log_error "Failed to send Telegram file: $file_path"
        return 1
    fi
}

# Export functions
export -f show_telegram_menu configure_telegram test_telegram_connection
export -f send_test_message view_telegram_settings send_account_to_telegram
export -f send_all_accounts_summary send_telegram_message send_telegram_file
