#!/bin/bash
# Compile markdown notes for LLM consumption
# Creates _index/<folder>.md for each folder and _index/ALL.md for everything

set -e

INDEX_DIR="_index"
PREFIX="Jose_J_Ruiz_KB"
SEPARATOR="

---

"

# Clean and create index directory
rm -rf "$INDEX_DIR"
mkdir -p "$INDEX_DIR"

# Function to strip YAML frontmatter from a file
strip_frontmatter() {
    local file="$1"
    awk '
        BEGIN { in_frontmatter = 0; frontmatter_done = 0 }
        /^---$/ && !frontmatter_done {
            if (in_frontmatter) {
                frontmatter_done = 1
                next
            } else {
                in_frontmatter = 1
                next
            }
        }
        !in_frontmatter || frontmatter_done { print }
    ' "$file"
}

# Function to compile a folder
compile_folder() {
    local folder="$1"
    local folder_name=$(basename "$folder")
    # Remove " (Folder)" suffix if present
    folder_name="${folder_name% (Folder)}"
    local output_file="$INDEX_DIR/${PREFIX}-${folder_name}.md"

    echo "Compiling: $folder_name"

    # Start with folder header
    echo "# $folder_name" > "$output_file"
    echo "" >> "$output_file"
    echo "_Compiled: $(date -u '+%Y-%m-%d %H:%M:%S UTC')_" >> "$output_file"
    echo "" >> "$output_file"

    # Find all .md files in the folder (not recursive)
    local count=0
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file" .md)
            echo "$SEPARATOR" >> "$output_file"
            echo "## $filename" >> "$output_file"
            echo "" >> "$output_file"
            strip_frontmatter "$file" >> "$output_file"
            count=$((count + 1))
        fi
    done < <(find "$folder" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)

    echo "  -> $count files compiled to $output_file"
}

# Function to compile root-level files
compile_root() {
    local output_file="$INDEX_DIR/${PREFIX}-Root.md"

    echo "Compiling: Root files"

    echo "# Root Files" > "$output_file"
    echo "" >> "$output_file"
    echo "_Compiled: $(date -u '+%Y-%m-%d %H:%M:%S UTC')_" >> "$output_file"
    echo "" >> "$output_file"

    local count=0
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        # Skip README and other special files
        if [[ "$filename" != "README.md" && "$filename" != "metadata.yaml" ]]; then
            local name=$(basename "$file" .md)
            echo "$SEPARATOR" >> "$output_file"
            echo "## $name" >> "$output_file"
            echo "" >> "$output_file"
            strip_frontmatter "$file" >> "$output_file"
            count=$((count + 1))
        fi
    done < <(find . -maxdepth 1 -name "*.md" -type f -print0 | sort -z)

    echo "  -> $count files compiled to $output_file"
}

# Function to create the master ALL.md file
compile_all() {
    local output_file="$INDEX_DIR/${PREFIX}_All.md"

    echo "Creating master file: ALL.md"

    echo "# Knowledge Base - Complete" > "$output_file"
    echo "" >> "$output_file"
    echo "_Compiled: $(date -u '+%Y-%m-%d %H:%M:%S UTC')_" >> "$output_file"
    echo "" >> "$output_file"
    echo "This file contains all notes from the Knowledge Base, optimized for LLM consumption." >> "$output_file"
    echo "" >> "$output_file"

    # Concatenate all compiled files
    for compiled in "$INDEX_DIR"/*.md; do
        local name=$(basename "$compiled")
        if [[ "$name" != "${PREFIX}_All.md" ]]; then
            echo "" >> "$output_file"
            echo "---" >> "$output_file"
            echo "" >> "$output_file"
            cat "$compiled" >> "$output_file"
        fi
    done

    # Show stats
    local total_size=$(du -h "$output_file" | cut -f1)
    local total_lines=$(wc -l < "$output_file")
    echo "  -> ALL.md created: $total_size, $total_lines lines"
}

echo "=== Compiling Knowledge Base for LLM ==="
echo ""

# Compile root-level files first
compile_root

# Compile each folder (excluding hidden folders and _index)
while IFS= read -r -d '' folder; do
    folder_name=$(basename "$folder")
    # Skip hidden folders, _index, and non-folders
    if [[ ! "$folder_name" =~ ^[._] && "$folder_name" != "_index" ]]; then
        compile_folder "$folder"
    fi
done < <(find . -maxdepth 1 -type d -print0 | sort -z)

# Create master file
compile_all

echo ""
echo "=== Compilation complete ==="
echo ""
ls -lh "$INDEX_DIR"
