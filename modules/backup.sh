#!/bin/bash
# ==============================================================================
# Backup and Restore Module
# Provides backup, restore, and Telegram backup functionality
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"
[[ -z "$(type -t get_public_ip 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# Load Telegram module for sending backups
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/modules/telegram.sh" ]] && source "${SCRIPT_DIR}/modules/telegram.sh"

# Show backup menu
show_backup_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                    BACKUP SYSTEM MENU                         ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} Create Full Backup"
        echo -e "  ${BGREEN}2.${NC} Create Accounts Backup"
        echo -e "  ${BGREEN}3.${NC} Send Backup to Telegram"
        echo -e "  ${BGREEN}4.${NC} Restore from Backup"
        echo -e "  ${BGREEN}5.${NC} View Backup Files"
        echo -e "  ${BGREEN}6.${NC} Delete Old Backups"
        echo -e "  ${BGREEN}7.${NC} Configure Backup Settings"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) create_full_backup ;;
            2) create_accounts_backup ;;
            3) send_backup_telegram ;;
            4) restore_backup ;;
            5) view_backup_files ;;
            6) delete_old_backups ;;
            7) configure_backup ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Create full backup
create_full_backup() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CREATE FULL BACKUP                         ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local backup_dir="${BACKUP_DIR:-/root/backup}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="full_backup_${timestamp}"
    local backup_path="${backup_dir}/${backup_name}"
    local backup_archive="${backup_dir}/${backup_name}.tar.gz"
    
    mkdir -p "$backup_dir"
    mkdir -p "$backup_path"
    
    echo -e "${CYAN}Creating full backup...${NC}"
    echo ""
    
    # Backup accounts
    echo -e "  ${YELLOW}→${NC} Backing up accounts..."
    if [[ -d "${ACCOUNTS_DIR}" ]]; then
        cp -r "${ACCOUNTS_DIR}" "${backup_path}/accounts" 2>/dev/null && echo -e "    ${GREEN}✓${NC} Accounts backed up" || echo -e "    ${RED}✗${NC} Failed to backup accounts"
    fi
    
    # Backup V2Ray config
    echo -e "  ${YELLOW}→${NC} Backing up V2Ray configuration..."
    if [[ -d "${V2RAY_CONFIG_DIR}" ]]; then
        mkdir -p "${backup_path}/v2ray"
        cp -r "${V2RAY_CONFIG_DIR}"/* "${backup_path}/v2ray/" 2>/dev/null && echo -e "    ${GREEN}✓${NC} V2Ray config backed up" || echo -e "    ${RED}✗${NC} Failed to backup V2Ray"
    fi
    
    # Backup script configuration
    echo -e "  ${YELLOW}→${NC} Backing up script configuration..."
    if [[ -d "${SCRIPT_DIR}/config" ]]; then
        cp -r "${SCRIPT_DIR}/config" "${backup_path}/script_config" 2>/dev/null && echo -e "    ${GREEN}✓${NC} Script config backed up" || echo -e "    ${RED}✗${NC} Failed to backup config"
    fi
    
    # Backup nginx config if exists
    echo -e "  ${YELLOW}→${NC} Backing up Nginx configuration..."
    if [[ -d "/etc/nginx" ]]; then
        mkdir -p "${backup_path}/nginx"
        cp -r /etc/nginx/* "${backup_path}/nginx/" 2>/dev/null && echo -e "    ${GREEN}✓${NC} Nginx config backed up" || echo -e "    ${RED}✗${NC} Failed to backup Nginx"
    fi
    
    # Create archive
    echo ""
    echo -e "${CYAN}Creating archive...${NC}"
    
    if tar -czf "$backup_archive" -C "$backup_dir" "$backup_name" 2>/dev/null; then
        rm -rf "$backup_path"
        local size
        size=$(du -h "$backup_archive" | cut -f1)
        print_success "Backup created successfully!"
        echo ""
        echo -e "  ${CYAN}File:${NC} $backup_archive"
        echo -e "  ${CYAN}Size:${NC} $size"
        log_info "Full backup created: $backup_archive"
    else
        print_error "Failed to create backup archive"
        rm -rf "$backup_path"
    fi
    
    press_any_key
}

# Create accounts only backup
create_accounts_backup() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  CREATE ACCOUNTS BACKUP                       ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local backup_dir="${BACKUP_DIR:-/root/backup}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_archive="${backup_dir}/accounts_backup_${timestamp}.tar.gz"
    
    mkdir -p "$backup_dir"
    
    if [[ ! -d "${ACCOUNTS_DIR}" ]]; then
        print_error "Accounts directory not found"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Creating accounts backup...${NC}"
    
    if tar -czf "$backup_archive" -C "$(dirname "${ACCOUNTS_DIR}")" "$(basename "${ACCOUNTS_DIR}")" 2>/dev/null; then
        local size
        size=$(du -h "$backup_archive" | cut -f1)
        print_success "Accounts backup created!"
        echo ""
        echo -e "  ${CYAN}File:${NC} $backup_archive"
        echo -e "  ${CYAN}Size:${NC} $size"
        log_info "Accounts backup created: $backup_archive"
    else
        print_error "Failed to create accounts backup"
    fi
    
    press_any_key
}

# Send backup to Telegram
send_backup_telegram() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                SEND BACKUP TO TELEGRAM                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        print_error "Telegram not configured"
        press_any_key
        return
    fi
    
    local backup_dir="${BACKUP_DIR:-/root/backup}"
    
    if [[ ! -d "$backup_dir" ]]; then
        print_error "Backup directory not found"
        press_any_key
        return
    fi
    
    # List backup files
    echo -e "${CYAN}Available backups:${NC}"
    echo ""
    
    local count=0
    local -a backup_files
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            ((count++))
            backup_files+=("$file")
            local filename size date
            filename=$(basename "$file")
            size=$(du -h "$file" | cut -f1)
            date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
            echo -e "  ${BGREEN}${count}.${NC} $filename ($size) - $date"
        fi
    done < <(find "$backup_dir" -name "*.tar.gz" -type f | sort -r | head -10)
    
    if [[ $count -eq 0 ]]; then
        print_error "No backup files found"
        press_any_key
        return
    fi
    
    echo ""
    local choice
    read -p "$(echo -e "${YELLOW}Select backup to send (1-${count}):${NC} ")" choice
    
    if ! validate_number "$choice" || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$count" ]]; then
        print_error "Invalid selection"
        press_any_key
        return
    fi
    
    local selected_file="${backup_files[$((choice-1))]}"
    local filename
    filename=$(basename "$selected_file")
    
    echo ""
    echo -e "${CYAN}Sending backup to Telegram...${NC}"
    echo -e "${DIM}This may take a while for large files...${NC}"
    
    local caption="📦 VPS Backup\n\n📄 File: $filename\n🖥️ Server: $(get_hostname)\n⏰ Sent: $(date '+%Y-%m-%d %H:%M:%S')"
    
    if send_telegram_file "$selected_file" "$caption"; then
        print_success "Backup sent to Telegram!"
    else
        print_error "Failed to send backup"
    fi
    
    press_any_key
}

# Restore from backup
restore_backup() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BRED}                    RESTORE FROM BACKUP                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will overwrite existing configuration!${NC}"
    echo ""
    
    local backup_dir="${BACKUP_DIR:-/root/backup}"
    
    if [[ ! -d "$backup_dir" ]]; then
        print_error "Backup directory not found"
        press_any_key
        return
    fi
    
    # List backup files
    echo -e "${CYAN}Available backups:${NC}"
    echo ""
    
    local count=0
    local -a backup_files
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            ((count++))
            backup_files+=("$file")
            local filename size date
            filename=$(basename "$file")
            size=$(du -h "$file" | cut -f1)
            date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
            echo -e "  ${BGREEN}${count}.${NC} $filename ($size) - $date"
        fi
    done < <(find "$backup_dir" -name "*.tar.gz" -type f | sort -r | head -10)
    
    if [[ $count -eq 0 ]]; then
        print_error "No backup files found"
        press_any_key
        return
    fi
    
    echo ""
    local choice
    read -p "$(echo -e "${YELLOW}Select backup to restore (1-${count}):${NC} ")" choice
    
    if ! validate_number "$choice" || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$count" ]]; then
        print_error "Invalid selection"
        press_any_key
        return
    fi
    
    local selected_file="${backup_files[$((choice-1))]}"
    
    if ! confirm "Are you SURE you want to restore from this backup?"; then
        print_info "Restore cancelled"
        press_any_key
        return
    fi
    
    echo ""
    echo -e "${CYAN}Restoring from backup...${NC}"
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if tar -xzf "$selected_file" -C "$temp_dir" 2>/dev/null; then
        local backup_name
        backup_name=$(ls "$temp_dir" | head -1)
        local backup_content="${temp_dir}/${backup_name}"
        
        # Restore accounts
        if [[ -d "${backup_content}/accounts" ]]; then
            echo -e "  ${YELLOW}→${NC} Restoring accounts..."
            mkdir -p "$(dirname "${ACCOUNTS_DIR}")"
            rm -rf "${ACCOUNTS_DIR}"
            cp -r "${backup_content}/accounts" "${ACCOUNTS_DIR}" && echo -e "    ${GREEN}✓${NC} Accounts restored"
        fi
        
        # Restore V2Ray config
        if [[ -d "${backup_content}/v2ray" ]]; then
            echo -e "  ${YELLOW}→${NC} Restoring V2Ray configuration..."
            mkdir -p "${V2RAY_CONFIG_DIR}"
            cp -r "${backup_content}/v2ray"/* "${V2RAY_CONFIG_DIR}/" 2>/dev/null && echo -e "    ${GREEN}✓${NC} V2Ray config restored"
        fi
        
        # Restore script config
        if [[ -d "${backup_content}/script_config" ]]; then
            echo -e "  ${YELLOW}→${NC} Restoring script configuration..."
            cp -r "${backup_content}/script_config"/* "${SCRIPT_DIR}/config/" 2>/dev/null && echo -e "    ${GREEN}✓${NC} Script config restored"
        fi
        
        # Cleanup
        rm -rf "$temp_dir"
        
        print_success "Backup restored successfully!"
        log_info "Backup restored from: $selected_file"
        
        # Restart services
        if confirm "Restart V2Ray service?"; then
            restart_service "v2ray" 2>/dev/null || true
        fi
    else
        print_error "Failed to extract backup"
        rm -rf "$temp_dir"
    fi
    
    press_any_key
}

# View backup files
view_backup_files() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    BACKUP FILES                               ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local backup_dir="${BACKUP_DIR:-/root/backup}"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo -e "  ${DIM}Backup directory not found: $backup_dir${NC}"
        echo ""
        press_any_key
        return
    fi
    
    printf "  ${CYAN}%-40s %-10s %-20s${NC}\n" "FILENAME" "SIZE" "DATE"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    
    local count=0
    local total_size=0
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local filename size date size_bytes
            filename=$(basename "$file")
            size=$(du -h "$file" | cut -f1)
            size_bytes=$(stat -c %s "$file" 2>/dev/null)
            date=$(stat -c %y "$file" 2>/dev/null | cut -d'.' -f1)
            
            printf "  %-40s %-10s %-20s\n" "$filename" "$size" "$date"
            
            total_size=$((total_size + size_bytes))
            ((count++))
        fi
    done < <(find "$backup_dir" -name "*.tar.gz" -type f | sort -r)
    
    if [[ $count -eq 0 ]]; then
        echo -e "  ${DIM}No backup files found${NC}"
    else
        echo ""
        echo -e "  ${CYAN}Total backups:${NC} $count"
        echo -e "  ${CYAN}Total size:${NC} $(format_bytes $total_size)"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Delete old backups
delete_old_backups() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  DELETE OLD BACKUPS                           ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local backup_dir="${BACKUP_DIR:-/root/backup}"
    local retention_days="${BACKUP_RETENTION_DAYS:-30}"
    
    if [[ ! -d "$backup_dir" ]]; then
        print_error "Backup directory not found"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Current retention period:${NC} $retention_days days"
    echo ""
    
    # Find old backups
    local old_count=0
    local -a old_files
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            old_files+=("$file")
            ((old_count++))
        fi
    done < <(find "$backup_dir" -name "*.tar.gz" -type f -mtime "+${retention_days}" 2>/dev/null)
    
    if [[ $old_count -eq 0 ]]; then
        print_info "No backups older than $retention_days days"
        press_any_key
        return
    fi
    
    echo -e "${YELLOW}Found $old_count backup(s) older than $retention_days days:${NC}"
    echo ""
    
    for file in "${old_files[@]}"; do
        echo -e "  - $(basename "$file")"
    done
    
    echo ""
    
    if confirm "Delete these $old_count old backup(s)?"; then
        local deleted=0
        for file in "${old_files[@]}"; do
            if rm -f "$file"; then
                ((deleted++))
            fi
        done
        print_success "Deleted $deleted old backup(s)"
        log_info "Deleted $deleted old backup files"
    else
        print_info "Deletion cancelled"
    fi
    
    press_any_key
}

# Configure backup settings
configure_backup() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                CONFIGURE BACKUP SETTINGS                      ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local config_file="${SCRIPT_DIR}/config/settings.conf"
    
    echo -e "${CYAN}Current settings:${NC}"
    echo -e "  Backup directory: ${BACKUP_DIR:-/root/backup}"
    echo -e "  Retention days: ${BACKUP_RETENTION_DAYS:-30}"
    echo ""
    
    local new_dir new_days
    
    read -p "$(echo -e "${YELLOW}Backup directory [${BACKUP_DIR:-/root/backup}]:${NC} ")" new_dir
    new_dir="${new_dir:-${BACKUP_DIR:-/root/backup}}"
    
    read -p "$(echo -e "${YELLOW}Retention days [${BACKUP_RETENTION_DAYS:-30}]:${NC} ")" new_days
    new_days="${new_days:-${BACKUP_RETENTION_DAYS:-30}}"
    
    if ! validate_number "$new_days"; then
        print_error "Invalid number for retention days"
        press_any_key
        return
    fi
    
    # Update config
    sed -i "s|^BACKUP_DIR=.*|BACKUP_DIR=\"$new_dir\"|" "$config_file"
    sed -i "s|^BACKUP_RETENTION_DAYS=.*|BACKUP_RETENTION_DAYS=\"$new_days\"|" "$config_file"
    
    # Create directory if needed
    mkdir -p "$new_dir"
    
    BACKUP_DIR="$new_dir"
    BACKUP_RETENTION_DAYS="$new_days"
    
    print_success "Backup settings updated"
    log_info "Backup settings updated: dir=$new_dir, retention=$new_days days"
    
    press_any_key
}

# Export functions
export -f show_backup_menu create_full_backup create_accounts_backup
export -f send_backup_telegram restore_backup view_backup_files
export -f delete_old_backups configure_backup
