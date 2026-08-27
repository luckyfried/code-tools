#!/usr/bin/env bash

# Function to display usage
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Concatenate files into a single output file. Can specify individual files or search a directory.

OPTIONS:
    -f, --file FILE         Add specific file to concatenate (can be used multiple times)
    -p, --path PATH         Directory to search in (default: current directory)
    -t, --types TYPES       Comma-separated list of file extensions (default: py)
                           Example: py,js,txt or "py, js, txt"
    -o, --output FILE       Output file name (default: concatenated_files.txt)
    -r, --recursive         Search recursively in subdirectories
    -h, --help             Display this help message

EXAMPLES:
    # Concatenate specific files
    $(basename "$0") -f file1.py -f file2.py -f file3.py -o output.txt

    # Search directory for file types
    $(basename "$0") -p ./src -t py,txt -o output.txt

    # Mix both: specific files + directory search
    $(basename "$0") -f config.yaml -p ./lib -t py -r -o combined.txt
EOF
}

# Default values
SEARCH_PATH=""
FILE_TYPES="py"
OUTPUT_FILE="concatenated_files.txt"
RECURSIVE=false
declare -a SPECIFIC_FILES=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            SPECIFIC_FILES+=("$2")
            shift 2
            ;;
        -p|--path)
            SEARCH_PATH="$2"
            shift 2
            ;;
        -t|--types)
            FILE_TYPES="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate we have something to do
if [ ${#SPECIFIC_FILES[@]} -eq 0 ] && [ -z "$SEARCH_PATH" ]; then
    echo "Error: Must specify either -f FILE(s) or -p PATH"
    show_help
    exit 1
fi

# Validate search path exists if specified
if [ -n "$SEARCH_PATH" ] && [ ! -d "$SEARCH_PATH" ]; then
    echo "Error: Directory '$SEARCH_PATH' does not exist"
    exit 1
fi

# Clear the output file
> "$OUTPUT_FILE"

# Counter for processed files
file_count=0

# Process specific files first
for file in "${SPECIFIC_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "============= file start: $file ===============" >> "$OUTPUT_FILE"
        cat "$file" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "=============== file end: $file ==============" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        ((file_count++))
    else
        echo "Warning: File '$file' does not exist, skipping"
    fi
done

# Process directory search if path specified
if [ -n "$SEARCH_PATH" ]; then
    # Remove spaces from file types and convert to array
    IFS=',' read -ra TYPES_ARRAY <<< "${FILE_TYPES// /}"

    # Process each file type
    for ext in "${TYPES_ARRAY[@]}"; do
        # Remove leading/trailing whitespace
        ext=$(echo "$ext" | xargs)

        # Build find command based on recursive flag
        if [ "$RECURSIVE" = true ]; then
            # Recursive search
            while IFS= read -r -d '' file; do
                echo "============= file start: $file ===============" >> "$OUTPUT_FILE"
                cat "$file" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
                echo "=============== file end: $file ==============" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
                ((file_count++))
            done < <(find "$SEARCH_PATH" -type f -name "*.$ext" -print0)
        else
            # Non-recursive search
            for file in "$SEARCH_PATH"/*."$ext"; do
                # Check if the file exists (in case no matching files are found)
                if [ -f "$file" ]; then
                    echo "============= file start: $file ===============" >> "$OUTPUT_FILE"
                    cat "$file" >> "$OUTPUT_FILE"
                    echo "" >> "$OUTPUT_FILE"
                    echo "=============== file end: $file ==============" >> "$OUTPUT_FILE"
                    echo "" >> "$OUTPUT_FILE"
                    ((file_count++))
                fi
            done
        fi
    done
fi

# Report completion
if [ $file_count -eq 0 ]; then
    echo "No files found"
    rm "$OUTPUT_FILE"  # Remove empty output file
else
    echo "Successfully concatenated $file_count file(s) into $OUTPUT_FILE"
    if [ ${#SPECIFIC_FILES[@]} -gt 0 ]; then
        echo "Specific files: ${#SPECIFIC_FILES[@]}"
    fi
    if [ -n "$SEARCH_PATH" ]; then
        echo "File types: ${FILE_TYPES}"
        echo "Search path: ${SEARCH_PATH}"
        if [ "$RECURSIVE" = true ]; then
            echo "Search mode: Recursive"
        fi
    fi
fi
