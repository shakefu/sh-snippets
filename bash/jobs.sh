# shellcheck shell=bash
# Give a terminal hint so we don't get a ton of error messages
export TERM="${TERM:-xterm-256color}"

# Colored logger for outputting multiline messages with log name prefixes
function logger {
    # Disable xtrace output
    { local -; set +x; } 2>/dev/null
    local name="$1"; shift
    # Check we have commands needed for colors
    if command -v echo cksum awk bc &>/dev/null; then
        # Generate colors from hashing the name
        local bold
        local color
        # shellcheck disable=1083
        color=$(echo "$name" | cksum | awk {'print $1 % 8 + 30'} | bc)
        # shellcheck disable=1083
        bold=$(echo "$name" | cksum | awk {'print $1 % 2'} | bc)
        name=$(printf "\033[0m\033[$bold;${color}m%s\033[0m" "$name")
    fi
    printf "[%s] %s\n" "$name" "${*//$'\n'/$'\n'[$name] }"
}
export -f logger

# Run a command and log the output, exit if there's an error
# $ log_job "name" "command"
# Very useful if "command" is a locally defined function
function log_job {
    local name="$1"; shift
    local log="logger $name"
    local cmd="$*"
    local out
    # Use this for full debug output
    # out="$(set -x && $cmd 2>&1)"
    out="$($cmd 2>&1)"
    local result=$?
    if [ -n "$out" ]; then
        # The log output from the sub-job should have its own logger, so this
        # just prints whatever we get
        printf "%s" "$out"
    fi
    if [ $result -ne 0 ]; then
        $log "Command exited with non-zero exit code: $result"
    fi
    return $result
}
export -f log_job


# Wait for all the background jobs to finish, and return the exit code of the
# first one that errors, killing the rest
function wait_for_jobs {
    while true; do
        local exited
        { read -r -d '' exited; } < <(jobs -l 2>&1)
        exited=$(echo "$exited" | grep -o 'Exit [0-9]\+' | head -n1 | awk '{print $2}')
        if [ -n "$exited" ]; then
            if [ "$exited" -ne 0 ]; then
                # shellcheck disable=SC2046
                if [ "$(jobs -p | wc -l)" -ne 0 ]; then
                    kill $(jobs -p) || true
                    wait
                fi
                # shellcheck disable=SC2086
                return $exited
            fi
        fi
        if [ "$(jobs -p | wc -l)" -eq 0 ]; then
            echo
            echo "Done"
            break
        fi
        sleep 1
    done
}
export -f wait_for_jobs
