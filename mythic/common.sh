common_check_mythic_dir() {
    # Validate that there's a Makefile in the current directory and that the mythic-docker directory exists 
    if [ ! -f "Makefile" ] || [ ! -d "mythic-docker" ]; then
        echo "This script must be run from the root of the Mythic repository."
        exit 1
    fi
}