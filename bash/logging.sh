# shellcheck shell=bash
# This code depends on having the color functions available.
source colors.sh


############################
# Colorful logging functions


prefix () {
    if [[ -z "$LOG_PREFIX" ]]; then return; fi
    grey "[$LOG_PREFIX] "
}

info () {
    prefix
    blue "[INFO] "
    echo "$*"
}


warn () {
    prefix
    yellow "[WARN] "
    echo "$*"
}


error () {
    prefix
    red "[ERROR] "
    echo "$*"
    _cleanup
    exit 1
}


debug () {
    if [[ -z "$LOG_DEBUG" ]]; then return; fi
    prefix
    cyan "[DEBUG] "
    echo "$*"
}

##################
# Compact versions

prefix () { if [[ -z "$LOG_PREFIX" ]]; then return; fi; grey "[$LOG_PREFIX] "; }
info () { prefix; blue "[INFO] "; echo "$*"; }
warn () { prefix; yellow "[WARN] "; echo "$*"; }
error () { prefix; red "[ERROR] "; echo "$*"; _cleanup; exit 1; }
debug () { if [[ -z "$LOG_DEBUG" ]]; then return; fi; prefix; cyan "[DEBUG] "; echo "$*"; }
