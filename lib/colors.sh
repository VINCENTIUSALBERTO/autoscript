#!/bin/bash
# ==============================================================================
# Color Definitions for Terminal Output
# ==============================================================================

# Reset
NC='\033[0m'

# Regular Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Bold Colors
BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BBLUE='\033[1;34m'
BPURPLE='\033[1;35m'
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'

# Background Colors
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'

# Text formatting
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
BLINK='\033[5m'

# Export all colors
export NC RED GREEN YELLOW BLUE PURPLE CYAN WHITE
export BRED BGREEN BYELLOW BBLUE BPURPLE BCYAN BWHITE
export BG_RED BG_GREEN BG_YELLOW BG_BLUE
export BOLD DIM UNDERLINE BLINK
