# Helper function to handle common command-line arguments for test scripts.
#
# Arguments:
#   $1: The name of the script itself (usually "$0")
#   $@: The arguments passed to the script
#
# Usage:
#   source ../lib/helper.sh
#   TEST_FILES=(file1.py file2.conf)
#   handle_args "$0" "$@"

handle_args() {
    local script_path="$1"
    shift
    local script_name=$(basename "$script_path")

    # Ensure TEST_FILES is defined and has at least one element
    if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
        echo "Error: TEST_FILES array must be defined and contain at least one element in $script_name"
        exit 1
    fi

    # Iterate over all arguments
    for arg in "$@"; do
        # Check for a help flag (-h or --help)
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            echo "Usage: $script_name [OPTION]"
            echo "Run the tests associated with this script."
            echo ""
            echo "Options:"
            echo "  -h, --help      Show this help message and exit"
            echo "  -m, --metadata  Output test metadata (YAML) and exit"
            echo "  -f, --files     List dependent files to download and exit"
            echo ""
            echo "If no option is provided, the tests are executed."
            exit 0
        fi

        # Check for a metadata flag (-m or --metadata)
        if [[ "$arg" == "-m" || "$arg" == "--metadata" ]]; then
            # Use awk to parse the calling script file.
            awk '/# METADATA_END/{exit} f{print substr($0,3)}; /# METADATA_START/{f=1}' "$script_path"
            exit 0
        fi

        # Check for a files flag (-f or --files)
        if [[ "$arg" == "-f" || "$arg" == "--files" ]]; then
            # Output a space-separated list of dependent files defined in TEST_FILES
            if [[ -n "${TEST_FILES[@]}" ]]; then
                echo "${TEST_FILES[*]}"
            fi
            exit 0
        fi
    done
}
ensure_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

ensure_command_available() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' command is not available."
        exit 1
    fi
}
