#!/bin/bash
# ==============================================================================
# Services Module
# Provides service error checking and diagnostics
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# Services to monitor
MONITORED_SERVICES=("v2ray" "nginx" "ssh" "sshd" "webmin")

# Show services menu
show_services_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                   SERVICE ERROR CHECKER                       ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} Check All Services Status"
        echo -e "  ${BGREEN}2.${NC} Check V2Ray Errors"
        echo -e "  ${BGREEN}3.${NC} Check Nginx Errors"
        echo -e "  ${BGREEN}4.${NC} Check SSH Errors"
        echo -e "  ${BGREEN}5.${NC} View System Journal (Recent)"
        echo -e "  ${BGREEN}6.${NC} Check Custom Service"
        echo -e "  ${BGREEN}7.${NC} View Failed Services"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) check_all_services ;;
            2) check_service_errors "v2ray" ;;
            3) check_service_errors "nginx" ;;
            4) check_ssh_errors ;;
            5) view_recent_journal ;;
            6) check_custom_service ;;
            7) view_failed_services ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Check all services status
check_all_services() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                   ALL SERVICES STATUS                         ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    printf "  ${CYAN}%-20s %-15s %-20s${NC}\n" "SERVICE" "STATUS" "DETAILS"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    
    for service in "${MONITORED_SERVICES[@]}"; do
        local status details
        
        if systemctl list-unit-files | grep -q "^${service}"; then
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                status="${GREEN}● Active${NC}"
                local pid
                pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2)
                details="PID: $pid"
            elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
                status="${YELLOW}○ Inactive${NC}"
                details="Enabled but not running"
            else
                status="${RED}○ Stopped${NC}"
                details="Disabled"
            fi
        else
            status="${DIM}Not installed${NC}"
            details=""
        fi
        
        printf "  %-20s %-25b %-20s\n" "$service" "$status" "$details"
    done
    
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Summary
    local running_count=0 stopped_count=0
    for service in "${MONITORED_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            ((running_count++))
        else
            ((stopped_count++))
        fi
    done
    
    echo -e "  ${CYAN}Summary:${NC} ${GREEN}$running_count running${NC}, ${RED}$stopped_count stopped${NC}"
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Check service errors
check_service_errors() {
    local service="$1"
    
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}              ${service^^} SERVICE ERRORS                      ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^${service}"; then
        print_warning "Service $service is not installed"
        press_any_key
        return
    fi
    
    # Service status
    echo -e "${CYAN}Service Status:${NC}"
    if systemctl is-active --quiet "$service"; then
        echo -e "  Status: ${GREEN}● Running${NC}"
    else
        echo -e "  Status: ${RED}○ Stopped${NC}"
    fi
    echo ""
    
    # Recent logs with errors
    echo -e "${CYAN}Recent Error Logs (last 50 lines):${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"
    
    local errors
    errors=$(journalctl -u "$service" --no-pager -n 50 --since "1 hour ago" 2>/dev/null | grep -iE "error|fail|critical|warning" | tail -20)
    
    if [[ -n "$errors" ]]; then
        echo "$errors" | while read -r line; do
            if echo "$line" | grep -qiE "error|fail|critical"; then
                echo -e "  ${RED}$line${NC}"
            else
                echo -e "  ${YELLOW}$line${NC}"
            fi
        done
    else
        echo -e "  ${GREEN}No errors found in the last hour${NC}"
    fi
    
    echo ""
    echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Full recent logs
    echo -e "${CYAN}Most Recent Logs (last 10 entries):${NC}"
    journalctl -u "$service" --no-pager -n 10 2>/dev/null | tail -10
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Check SSH errors (checks both ssh and sshd)
check_ssh_errors() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    SSH SERVICE ERRORS                         ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Determine SSH service name
    local ssh_service
    if systemctl is-active --quiet sshd; then
        ssh_service="sshd"
    elif systemctl is-active --quiet ssh; then
        ssh_service="ssh"
    else
        ssh_service="sshd"
    fi
    
    # Service status
    echo -e "${CYAN}Service Status:${NC}"
    if systemctl is-active --quiet "$ssh_service"; then
        echo -e "  Status: ${GREEN}● Running${NC}"
    else
        echo -e "  Status: ${RED}○ Stopped${NC}"
    fi
    
    # Current port
    local ssh_port
    ssh_port=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    ssh_port="${ssh_port:-22}"
    echo -e "  Port: $ssh_port"
    echo ""
    
    # Failed login attempts
    echo -e "${CYAN}Failed Login Attempts (last 24 hours):${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"
    
    local failed_logins
    failed_logins=$(journalctl --since "24 hours ago" 2>/dev/null | grep -iE "failed password|authentication failure|invalid user" | tail -15)
    
    if [[ -n "$failed_logins" ]]; then
        echo "$failed_logins" | while read -r line; do
            echo -e "  ${RED}$line${NC}"
        done
    else
        echo -e "  ${GREEN}No failed login attempts found${NC}"
    fi
    
    echo ""
    
    # Recent errors
    echo -e "${CYAN}Recent SSH Errors:${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"
    
    local ssh_errors
    ssh_errors=$(journalctl -u "$ssh_service" --since "1 hour ago" 2>/dev/null | grep -iE "error|fail" | tail -10)
    
    if [[ -n "$ssh_errors" ]]; then
        echo "$ssh_errors"
    else
        echo -e "  ${GREEN}No SSH errors in the last hour${NC}"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# View recent journal
view_recent_journal() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  RECENT SYSTEM JOURNAL                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}Select time range:${NC}"
    echo "  1. Last 10 minutes"
    echo "  2. Last 1 hour"
    echo "  3. Last 24 hours"
    echo "  4. Since boot"
    echo ""
    
    local choice
    read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
    
    local since
    case $choice in
        1) since="10 minutes ago" ;;
        2) since="1 hour ago" ;;
        3) since="24 hours ago" ;;
        4) since="" ;;
        *) since="1 hour ago" ;;
    esac
    
    echo ""
    echo -e "${CYAN}Journal entries with errors/warnings:${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"
    
    local entries
    if [[ -n "$since" ]]; then
        entries=$(journalctl --since "$since" --no-pager 2>/dev/null | grep -iE "error|fail|critical|warning" | tail -30)
    else
        entries=$(journalctl -b --no-pager 2>/dev/null | grep -iE "error|fail|critical|warning" | tail -30)
    fi
    
    if [[ -n "$entries" ]]; then
        echo "$entries" | while read -r line; do
            if echo "$line" | grep -qiE "error|fail|critical"; then
                echo -e "${RED}$line${NC}"
            else
                echo -e "${YELLOW}$line${NC}"
            fi
        done
    else
        echo -e "  ${GREEN}No errors or warnings found${NC}"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Check custom service
check_custom_service() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  CHECK CUSTOM SERVICE                         ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local service
    read -p "$(echo -e "${YELLOW}Enter service name:${NC} ")" service
    
    if [[ -z "$service" ]]; then
        print_error "No service name provided"
        press_any_key
        return
    fi
    
    check_service_errors "$service"
}

# View failed services
view_failed_services() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    FAILED SERVICES                            ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}Failed systemd units:${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"
    
    local failed
    failed=$(systemctl --failed --no-pager 2>/dev/null)
    
    if echo "$failed" | grep -q "0 loaded"; then
        echo -e "  ${GREEN}No failed services${NC}"
    else
        echo "$failed" | while read -r line; do
            if echo "$line" | grep -qE "failed|error"; then
                echo -e "  ${RED}$line${NC}"
            else
                echo -e "  $line"
            fi
        done
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Speedtest function
run_speedtest() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                      VPS SPEEDTEST                            ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if speedtest-cli is installed
    if ! command_exists speedtest-cli && ! command_exists speedtest; then
        echo -e "${CYAN}Installing speedtest-cli...${NC}"
        
        if command_exists apt; then
            apt update -q && apt install -y speedtest-cli 2>/dev/null || pip install speedtest-cli 2>/dev/null
        elif command_exists pip; then
            pip install speedtest-cli 2>/dev/null
        fi
    fi
    
    if command_exists speedtest-cli; then
        echo -e "${CYAN}Running speedtest (this may take a moment)...${NC}"
        echo ""
        speedtest-cli --simple
    elif command_exists speedtest; then
        echo -e "${CYAN}Running speedtest (this may take a moment)...${NC}"
        echo ""
        speedtest --simple
    else
        print_error "Could not install speedtest-cli"
        echo ""
        print_info "You can manually install with: pip install speedtest-cli"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Export functions
export -f show_services_menu check_all_services check_service_errors
export -f check_ssh_errors view_recent_journal check_custom_service
export -f view_failed_services run_speedtest
