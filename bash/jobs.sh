# shellcheck shell=bash
# Give a terminal hint so we don't get a ton of error messages
export TERM="${TERM:-xterm-256color}"

function colorize {
    # Disable xtrace output, quit on errors
    { local -; set +x; set -e; } 2>/dev/null
    local name="$1"; shift
    # Check we have commands needed for colors
    if command -v echo cksum awk bc &>/dev/null; then
        # Generate colors from hashing the name
        local bold
        local color
        # This command hashes the logger name into a number between 30 and 37
        # (inclusive), which corresponds to the ANSI colors
        # shellcheck disable=1083
        color=$(echo "$name" | cksum | awk {'print $1 % 8 + 30'} | bc)
        # This command hashes the logger name into 0 or 1, which corresponds to
        # the ANSI Regular or Bold flags
        # shellcheck disable=1083
        bold=$(echo "$name" | cksum | awk {'print $1 % 2'} | bc)
        name=$(printf "\033[$bold;${color}m%s\033[0m" "$name")
    fi
    printf "%s" "$name"
}

# Colored logger for outputting multiline messages with log name prefixes
function logger {
    # Disable xtrace output, quit on errors
    { local -; set +x; set -e; } 2>/dev/null
    local name="$1"; shift
    name=$(colorize "$name")
    printf "\033[0m[%s] %s\n" "$name" "${*//$'\n'/$'\n'[$name] }"
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
    local result

    name=$(colorize "$name")
    if command -v unbuffer &>/dev/null; then
        # This will print line by line, unbuffered, output prefixed with the colorized [name]
        unbuffer "$cmd" 2>&1 | awk -v name="$name" '{print "["name"]", $0}'
        result=$?
    else
        out=$("$cmd" 2>&1)
        result=$?
        # This will print the entire command output in one go, prefixing each line with [name]
        [ -n "$out" ] && printf "%s\n" "$out" | awk -v name="$name" '{print "["name"]", $0}'
    fi
    if [ $result -ne 0 ]; then
        sleep 1  # This helps the logging not bunch up on a single line
        $log "Command exited with non-zero exit code: $result"
    fi
    return $result
}
export -f log_job


# Wait for all the background jobs to finish, and return the exit code of the
# first one that errors, killing the rest
# $ wait_for_jobs; exit $?
function wait_for_jobs {
    local log="logger wait_for_jobs"
    if [ -z "$DEBUG" ]; then
        # Disable xtrace output
        { local -; set +x; } 2>/dev/null
    else
        $log "Debug enabled"
    fi
    while true; do
        local exited
        # Get the output of the jobs command into $exited without invoking a subshell
        { read -r -d '' exited; } < <(jobs -l 2>&1)
        # Parse the jobs output looking for "Exit" and the exit code
        exited=$(echo "$exited" | grep -o 'Exit [0-9]\+' | head -n1 | awk '{print $2}')
        if [ -n "$exited" ]; then
            echo
            $log "Found exited job"
            if [ "$exited" -ne 0 ]; then
                $log "Exited job had error: $exited"
                # Try to kill any remaining jobs if they're still running
                # shellcheck disable=SC2046
                if [ "$(jobs -p | wc -l)" -ne 0 ]; then
                    $log "Killing remaining jobs"
                    kill $(jobs -p) || true
                    wait
                fi
                # Return the exit code of the first job that failed
                # shellcheck disable=SC2086
                return $exited
            fi
        fi
        # Check if we still have background jobs running
        if [ "$(jobs -p | wc -l)" -eq 0 ]; then
            echo
            $log "Done"
            break
        fi
        # Wait a second for the next check
        sleep 1
    done
    $log "Success"
    return 0
}
export -f wait_for_jobs
