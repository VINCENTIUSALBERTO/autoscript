#!/bin/bash
# ==============================================================================
# V2Ray VMess Module
# Provides VMess account management functions
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"
[[ -z "$(type -t get_public_ip 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# VMess accounts directory
VMESS_ACCOUNTS_DIR="${ACCOUNTS_DIR}/vmess"

# Ensure accounts directory exists
ensure_vmess_dir() {
    mkdir -p "$VMESS_ACCOUNTS_DIR"
}

# Show VMess menu
show_vmess_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                    V2RAY VMESS MENU                           ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} Create VMess Account"
        echo -e "  ${BGREEN}2.${NC} View VMess Accounts"
        echo -e "  ${BGREEN}3.${NC} Renew VMess Account"
        echo -e "  ${BGREEN}4.${NC} Delete VMess Account"
        echo -e "  ${BGREEN}5.${NC} Check VMess Account Details"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) create_vmess_account ;;
            2) view_vmess_accounts ;;
            3) renew_vmess_account ;;
            4) delete_vmess_account ;;
            5) check_vmess_account ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Create VMess account
create_vmess_account() {
    ensure_vmess_dir
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                   CREATE VMESS ACCOUNT                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local username exp_days uuid port path domain
    
    # Get username
    while true; do
        read -p "$(echo -e "${YELLOW}Enter username:${NC} ")" username
        if validate_username "$username"; then
            if [[ -f "${VMESS_ACCOUNTS_DIR}/${username}.json" ]]; then
                print_error "Username already exists"
            else
                break
            fi
        else
            print_error "Invalid username (3-32 alphanumeric characters, start with letter)"
        fi
    done
    
    # Get expiry days
    while true; do
        read -p "$(echo -e "${YELLOW}Expiry days (default 30):${NC} ")" exp_days
        exp_days="${exp_days:-30}"
        if validate_number "$exp_days" && [[ "$exp_days" -gt 0 ]] && [[ "$exp_days" -le 365 ]]; then
            break
        else
            print_error "Invalid number (1-365)"
        fi
    done
    
    # Generate UUID
    uuid=$(generate_uuid)
    
    # Get settings from config
    port="${V2RAY_PORT_VMESS:-443}"
    path="${V2RAY_PATH_VMESS:-/vmess}"
    domain=$(get_vps_domain)
    
    if [[ "$domain" == "Not configured" ]]; then
        print_warning "Domain not configured. Please set domain first."
        domain=$(get_public_ip)
    fi
    
    # Calculate expiry date
    local exp_date
    exp_date=$(date -d "+${exp_days} days" '+%Y-%m-%d')
    local created_date
    created_date=$(date '+%Y-%m-%d')
    
    # Create account JSON
    local account_data
    account_data=$(cat <<EOF
{
    "username": "${username}",
    "uuid": "${uuid}",
    "port": ${port},
    "path": "${path}",
    "created": "${created_date}",
    "expiry": "${exp_date}",
    "status": "active"
}
EOF
)
    
    echo "$account_data" > "${VMESS_ACCOUNTS_DIR}/${username}.json"
    
    # Generate VMess link
    local vmess_json
    vmess_json=$(echo -n "{\"v\":\"2\",\"ps\":\"${username}\",\"add\":\"${domain}\",\"port\":\"${port}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"${path}\",\"tls\":\"tls\"}" | base64 -w 0)
    local vmess_link="vmess://${vmess_json}"
    
    # Update V2Ray config (add user to inbound)
    add_vmess_to_v2ray "$uuid" "$username"
    
    # Display result
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BGREEN}              VMESS ACCOUNT CREATED SUCCESSFULLY              ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Username:${NC}     $username"
    echo -e "  ${CYAN}UUID:${NC}         $uuid"
    echo -e "  ${CYAN}Domain:${NC}       $domain"
    echo -e "  ${CYAN}Port:${NC}         $port"
    echo -e "  ${CYAN}Path:${NC}         $path"
    echo -e "  ${CYAN}Security:${NC}     auto"
    echo -e "  ${CYAN}Network:${NC}      ws"
    echo -e "  ${CYAN}TLS:${NC}          tls"
    echo -e "  ${CYAN}Created:${NC}      $created_date"
    echo -e "  ${CYAN}Expires:${NC}      $exp_date"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BCYAN}                      VMESS LINK                               ${NC}"
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${GREEN}${vmess_link}${NC}"
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    log_info "Created VMess account: $username (expires: $exp_date)"
    
    press_any_key
}

# View all VMess accounts
view_vmess_accounts() {
    ensure_vmess_dir
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    VMESS ACCOUNTS LIST                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local count=0
    printf "  ${CYAN}%-20s %-15s %-12s %-10s${NC}\n" "USERNAME" "CREATED" "EXPIRES" "STATUS"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    
    for file in "${VMESS_ACCOUNTS_DIR}"/*.json; do
        if [[ -f "$file" ]]; then
            local username created expiry status
            username=$(jq -r '.username' "$file" 2>/dev/null)
            created=$(jq -r '.created' "$file" 2>/dev/null)
            expiry=$(jq -r '.expiry' "$file" 2>/dev/null)
            
            # Check if expired
            local exp_epoch current_epoch
            exp_epoch=$(date -d "$expiry" +%s 2>/dev/null)
            current_epoch=$(date +%s)
            
            if [[ "$exp_epoch" -lt "$current_epoch" ]]; then
                status="${RED}Expired${NC}"
            else
                status="${GREEN}Active${NC}"
            fi
            
            printf "  %-20s %-15s %-12s %-10b\n" "$username" "$created" "$expiry" "$status"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "  ${DIM}No VMess accounts found${NC}"
    fi
    
    echo ""
    echo -e "  ${CYAN}Total accounts:${NC} $count"
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Renew VMess account
renew_vmess_account() {
    ensure_vmess_dir
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    RENEW VMESS ACCOUNT                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # List accounts
    echo -e "${CYAN}Available accounts:${NC}"
    local count=0
    for file in "${VMESS_ACCOUNTS_DIR}"/*.json; do
        if [[ -f "$file" ]]; then
            local username expiry
            username=$(jq -r '.username' "$file" 2>/dev/null)
            expiry=$(jq -r '.expiry' "$file" 2>/dev/null)
            echo "  - $username (expires: $expiry)"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_error "No VMess accounts found"
        press_any_key
        return
    fi
    
    echo ""
    local username exp_days
    read -p "$(echo -e "${YELLOW}Enter username to renew:${NC} ")" username
    
    local account_file="${VMESS_ACCOUNTS_DIR}/${username}.json"
    if [[ ! -f "$account_file" ]]; then
        print_error "Account not found: $username"
        press_any_key
        return
    fi
    
    # Get current expiry
    local current_expiry
    current_expiry=$(jq -r '.expiry' "$account_file")
    echo -e "${CYAN}Current expiry:${NC} $current_expiry"
    
    # Get renewal days
    while true; do
        read -p "$(echo -e "${YELLOW}Add days (default 30):${NC} ")" exp_days
        exp_days="${exp_days:-30}"
        if validate_number "$exp_days" && [[ "$exp_days" -gt 0 ]] && [[ "$exp_days" -le 365 ]]; then
            break
        else
            print_error "Invalid number (1-365)"
        fi
    done
    
    # Calculate new expiry from current expiry
    local current_epoch new_expiry
    current_epoch=$(date -d "$current_expiry" +%s 2>/dev/null)
    
    # If already expired, renew from today
    local today_epoch
    today_epoch=$(date +%s)
    if [[ "$current_epoch" -lt "$today_epoch" ]]; then
        new_expiry=$(date -d "+${exp_days} days" '+%Y-%m-%d')
    else
        new_expiry=$(date -d "$current_expiry +${exp_days} days" '+%Y-%m-%d')
    fi
    
    # Update account
    local tmp_file="${account_file}.tmp"
    jq ".expiry = \"${new_expiry}\" | .status = \"active\"" "$account_file" > "$tmp_file"
    mv "$tmp_file" "$account_file"
    
    print_success "Account renewed successfully"
    echo -e "${CYAN}New expiry date:${NC} $new_expiry"
    
    log_info "Renewed VMess account: $username (new expiry: $new_expiry)"
    
    press_any_key
}

# Delete VMess account
delete_vmess_account() {
    ensure_vmess_dir
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    DELETE VMESS ACCOUNT                       ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # List accounts
    echo -e "${CYAN}Available accounts:${NC}"
    local count=0
    for file in "${VMESS_ACCOUNTS_DIR}"/*.json; do
        if [[ -f "$file" ]]; then
            local username
            username=$(jq -r '.username' "$file" 2>/dev/null)
            echo "  - $username"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_error "No VMess accounts found"
        press_any_key
        return
    fi
    
    echo ""
    local username
    read -p "$(echo -e "${YELLOW}Enter username to delete:${NC} ")" username
    
    local account_file="${VMESS_ACCOUNTS_DIR}/${username}.json"
    if [[ ! -f "$account_file" ]]; then
        print_error "Account not found: $username"
        press_any_key
        return
    fi
    
    if confirm "Are you sure you want to delete account '$username'?"; then
        local uuid
        uuid=$(jq -r '.uuid' "$account_file")
        
        # Remove from V2Ray config
        remove_vmess_from_v2ray "$uuid"
        
        # Delete account file
        rm -f "$account_file"
        
        print_success "Account deleted successfully: $username"
        log_info "Deleted VMess account: $username"
    else
        print_info "Deletion cancelled"
    fi
    
    press_any_key
}

# Check VMess account details
check_vmess_account() {
    ensure_vmess_dir
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  CHECK VMESS ACCOUNT DETAILS                  ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # List accounts
    echo -e "${CYAN}Available accounts:${NC}"
    local count=0
    for file in "${VMESS_ACCOUNTS_DIR}"/*.json; do
        if [[ -f "$file" ]]; then
            local username
            username=$(jq -r '.username' "$file" 2>/dev/null)
            echo "  - $username"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_error "No VMess accounts found"
        press_any_key
        return
    fi
    
    echo ""
    local username
    read -p "$(echo -e "${YELLOW}Enter username to check:${NC} ")" username
    
    local account_file="${VMESS_ACCOUNTS_DIR}/${username}.json"
    if [[ ! -f "$account_file" ]]; then
        print_error "Account not found: $username"
        press_any_key
        return
    fi
    
    # Read account details
    local uuid port path created expiry
    uuid=$(jq -r '.uuid' "$account_file")
    port=$(jq -r '.port' "$account_file")
    path=$(jq -r '.path' "$account_file")
    created=$(jq -r '.created' "$account_file")
    expiry=$(jq -r '.expiry' "$account_file")
    
    local domain
    domain=$(get_vps_domain)
    [[ "$domain" == "Not configured" ]] && domain=$(get_public_ip)
    
    # Check status
    local status_text exp_epoch current_epoch
    exp_epoch=$(date -d "$expiry" +%s 2>/dev/null)
    current_epoch=$(date +%s)
    
    if [[ "$exp_epoch" -lt "$current_epoch" ]]; then
        status_text="${RED}Expired${NC}"
    else
        local days_left=$(( (exp_epoch - current_epoch) / 86400 ))
        status_text="${GREEN}Active${NC} ($days_left days left)"
    fi
    
    # Generate VMess link
    local vmess_json
    vmess_json=$(echo -n "{\"v\":\"2\",\"ps\":\"${username}\",\"add\":\"${domain}\",\"port\":\"${port}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"${path}\",\"tls\":\"tls\"}" | base64 -w 0)
    local vmess_link="vmess://${vmess_json}"
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    ACCOUNT DETAILS                            ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Username:${NC}     $username"
    echo -e "  ${CYAN}UUID:${NC}         $uuid"
    echo -e "  ${CYAN}Domain:${NC}       $domain"
    echo -e "  ${CYAN}Port:${NC}         $port"
    echo -e "  ${CYAN}Path:${NC}         $path"
    echo -e "  ${CYAN}Created:${NC}      $created"
    echo -e "  ${CYAN}Expires:${NC}      $expiry"
    echo -e "  ${CYAN}Status:${NC}       $status_text"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BCYAN}                      VMESS LINK                               ${NC}"
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${GREEN}${vmess_link}${NC}"
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Add VMess user to V2Ray configuration
add_vmess_to_v2ray() {
    local uuid="$1"
    local email="$2"
    local v2ray_config="${V2RAY_CONFIG_DIR}/config.json"
    
    if [[ ! -f "$v2ray_config" ]]; then
        log_warn "V2Ray config not found: $v2ray_config"
        return 1
    fi
    
    # Create backup
    cp "$v2ray_config" "${v2ray_config}.bak"
    
    # Add user to vmess inbound
    local tmp_config="${v2ray_config}.tmp"
    jq --arg uuid "$uuid" --arg email "$email" '
        .inbounds[] |= if .protocol == "vmess" then
            .settings.clients += [{"id": $uuid, "alterId": 0, "email": $email}]
        else . end
    ' "$v2ray_config" > "$tmp_config" 2>/dev/null
    
    if [[ -s "$tmp_config" ]]; then
        mv "$tmp_config" "$v2ray_config"
        restart_service "v2ray" 2>/dev/null || true
        log_info "Added VMess user to V2Ray: $email"
    else
        rm -f "$tmp_config"
        log_error "Failed to add VMess user to V2Ray config"
    fi
}

# Remove VMess user from V2Ray configuration
remove_vmess_from_v2ray() {
    local uuid="$1"
    local v2ray_config="${V2RAY_CONFIG_DIR}/config.json"
    
    if [[ ! -f "$v2ray_config" ]]; then
        return 1
    fi
    
    # Create backup
    cp "$v2ray_config" "${v2ray_config}.bak"
    
    # Remove user from vmess inbound
    local tmp_config="${v2ray_config}.tmp"
    jq --arg uuid "$uuid" '
        .inbounds[] |= if .protocol == "vmess" then
            .settings.clients |= map(select(.id != $uuid))
        else . end
    ' "$v2ray_config" > "$tmp_config" 2>/dev/null
    
    if [[ -s "$tmp_config" ]]; then
        mv "$tmp_config" "$v2ray_config"
        restart_service "v2ray" 2>/dev/null || true
        log_info "Removed VMess user from V2Ray: $uuid"
    else
        rm -f "$tmp_config"
    fi
}

# Export functions
export -f show_vmess_menu create_vmess_account view_vmess_accounts
export -f renew_vmess_account delete_vmess_account check_vmess_account
export -f add_vmess_to_v2ray remove_vmess_from_v2ray
