#!/bin/bash

# =============================================================================
# Professional Video Generator Script
# Create videos from images with optional audio overlay
# Author: Claude Code Assistant
# Version: 1.0
# =============================================================================

# Color codes for professional UI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Global variables
VERBOSE=false
DEBUG=false
IMAGES_DIR=""
AUDIO_FILE=""
OUTPUT_NAME=""
FRAME_RATE="1/5"
VIDEO_FPS=30
AUDIO_VOLUME="1.0"
VIDEO_QUALITY="medium"
SUPPORTED_FORMATS=("jpg" "jpeg" "png" "JPG" "JPEG" "PNG")

# Output directories
readonly VIDEO_OUTPUT_DIR="$HOME/generated_videos"
readonly AUDIO_OUTPUT_DIR="$HOME/generated_videos_with_audio"

# Persistent storage files
readonly SETTINGS_FILE="$HOME/.video_generator_settings"
readonly PATHS_HISTORY_FILE="$HOME/.video_generator_paths"

# =============================================================================
# PERSISTENT STORAGE FUNCTIONS
# =============================================================================

load_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        log "VERBOSE" "Loading settings from $SETTINGS_FILE"
        # Read settings file and apply them
        while IFS='=' read -r key value; do
            case $key in
                VERBOSE)
                    VERBOSE="$value"
                    ;;
                DEBUG)
                    DEBUG="$value"
                    ;;
                FRAME_RATE)
                    FRAME_RATE="$value"
                    ;;
                VIDEO_FPS)
                    VIDEO_FPS="$value"
                    ;;
                AUDIO_VOLUME)
                    AUDIO_VOLUME="$value"
                    ;;
                VIDEO_QUALITY)
                    VIDEO_QUALITY="$value"
                    ;;
            esac
        done < "$SETTINGS_FILE"
        log "INFO" "Settings loaded successfully"
    else
        log "INFO" "Settings file not found. Using default settings."
    fi
}

save_settings() {
    log "VERBOSE" "Saving settings to $SETTINGS_FILE"
    cat > "$SETTINGS_FILE" << EOF
VERBOSE=$VERBOSE
DEBUG=$DEBUG
FRAME_RATE=$FRAME_RATE
VIDEO_FPS=$VIDEO_FPS
AUDIO_VOLUME=$AUDIO_VOLUME
VIDEO_QUALITY=$VIDEO_QUALITY
EOF
    log "VERBOSE" "Settings saved successfully"
}

add_path_to_history() {
    local path="$1"
    if [ -n "$path" ] && [ -d "$path" ]; then
        # Add timestamp and path to history file
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $path" >> "$PATHS_HISTORY_FILE"
        log "VERBOSE" "Added path to history: $path"
    fi
}

show_path_history() {
    if [ -f "$PATHS_HISTORY_FILE" ]; then
        echo -e "${CYAN}${BOLD}Recent Image Directory Paths:${NC}"
        echo -e "${PURPLE}────────────────────────────${NC}"
        echo ""
        
        local count=0
        local paths=()
        local timestamps=()
        
        # Read and display paths with ls info
        while IFS=' | ' read -r timestamp path; do
            if [ -d "$path" ]; then
                ((count++))
                paths+=("$path")
                timestamps+=("$timestamp")
                local dir_info=$(ls -lha "$path" | head -1 | awk '{print $2, $3, $4, $5, $6, $7, $8}')
                echo -e "${CYAN}$count.${NC} ${WHITE}$path${NC}"
                echo -e "    ${YELLOW}Last used: $timestamp${NC}"
                echo -e "    ${PURPLE}Directory: $dir_info${NC}"
                echo ""
            fi
        done < "$PATHS_HISTORY_FILE"
        
        if [ "$count" -eq 0 ]; then
            echo -e "${YELLOW}No valid directories found in history${NC}"
            return 1
        else
            echo -e "${CYAN}0.${NC} ${WHITE}Enter new path${NC}"
            echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
            echo ""
            echo -n -e "${YELLOW}Select a directory [1-$count, 0, b]: ${NC}"
            read -r choice
            
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                echo "${paths[$((choice-1))]}"
                return 0
            elif [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
                return 2
            else
                return 1
            fi
        fi
    else
        log "INFO" "Path history file not found. No previous paths to display."
        return 1
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "██╗   ██╗██╗██████╗ ███████╗ ██████╗      ██████╗ ███████╗███╗   ██╗"
    echo "██║   ██║██║██╔══██╗██╔════╝██╔═══██╗    ██╔════╝ ██╔════╝████╗  ██║"
    echo "██║   ██║██║██║  ██║█████╗  ██║   ██║    ██║  ███╗█████╗  ██╔██╗ ██║"
    echo "╚██╗ ██╔╝██║██║  ██║██╔══╝  ██║   ██║    ██║   ██║██╔══╝  ██║╚██╗██║"
    echo " ╚████╔╝ ██║██████╔╝███████╗╚██████╔╝    ╚██████╔╝███████╗██║ ╚████║"
    echo "  ╚═══╝  ╚═╝╚═════╝ ╚══════╝ ╚═════╝      ╚═════╝ ╚══════╝╚═╝  ╚═══╝"
    echo -e "${NC}"
    echo -e "${WHITE}${BOLD}Professional Video Generator - Create Amazing Videos from Images${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${timestamp} - $message"
            ;;
        "DEBUG")
            if [ "$DEBUG" = true ]; then
                echo -e "${BLUE}[DEBUG]${NC} ${timestamp} - $message"
            fi
            ;;
        "VERBOSE")
            if [ "$VERBOSE" = true ]; then
                echo -e "${CYAN}[VERBOSE]${NC} ${timestamp} - $message"
            fi
            ;;
    esac
}

get_status_indicator() {
    local status="$1"
    if [ "$status" = true ]; then
        echo -n -e "${GREEN}●${NC}"
    else
        echo -n -e "${RED}●${NC}"
    fi
}

get_mode_status() {
    local verbose_indicator
    local debug_indicator
    verbose_indicator=$(get_status_indicator "$VERBOSE")
    debug_indicator=$(get_status_indicator "$DEBUG")
    echo -e "${WHITE}[${NC}${verbose_indicator}${WHITE} Verbose ${debug_indicator} Debug${WHITE}]${NC}"
}

check_dependencies() {
    log "INFO" "Checking required dependencies..."
    
    local missing_deps=()
    
    if ! command -v ffmpeg &> /dev/null; then
        missing_deps+=("ffmpeg")
    fi
    
    if ! command -v mediainfo &> /dev/null; then
        missing_deps+=("mediainfo")
    fi
    
    if ! command -v convert &> /dev/null; then
        missing_deps+=("imagemagick")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        echo -e "${RED}Please install missing dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${YELLOW}  - $dep${NC}"
        done
        echo ""
        echo -e "${CYAN}Ubuntu/Debian: ${WHITE}sudo apt install ffmpeg mediainfo imagemagick${NC}"
        echo -e "${CYAN}RHEL/CentOS:   ${WHITE}sudo yum install ffmpeg mediainfo ImageMagick${NC}"
        echo -e "${CYAN}macOS:         ${WHITE}brew install ffmpeg mediainfo imagemagick${NC}"
        exit 1
    fi
    
    log "INFO" "All dependencies satisfied ✓"
}

setup_output_directories() {
    log "INFO" "Setting up output directories..."
    
    # Create directories if they don't exist
    if [ ! -d "$VIDEO_OUTPUT_DIR" ]; then
        mkdir -p "$VIDEO_OUTPUT_DIR"
        log "INFO" "Created video output directory: $VIDEO_OUTPUT_DIR"
    fi
    
    if [ ! -d "$AUDIO_OUTPUT_DIR" ]; then
        mkdir -p "$AUDIO_OUTPUT_DIR"
        log "INFO" "Created videos with audio output directory: $AUDIO_OUTPUT_DIR"
    fi
    
    # Check write permissions
    if [ ! -w "$VIDEO_OUTPUT_DIR" ]; then
        log "ERROR" "No write permission for video output directory: $VIDEO_OUTPUT_DIR"
        return 1
    fi
    
    if [ ! -w "$AUDIO_OUTPUT_DIR" ]; then
        log "ERROR" "No write permission for videos with audio output directory: $AUDIO_OUTPUT_DIR"
        return 1
    fi
    
    log "VERBOSE" "Output directories ready: videos → $VIDEO_OUTPUT_DIR, videos with audio → $AUDIO_OUTPUT_DIR"
    return 0
}

validate_directory() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        log "ERROR" "Directory does not exist: $dir"
        return 1
    fi
    
    if [ ! -r "$dir" ]; then
        log "ERROR" "Directory is not readable: $dir"
        return 1
    fi
    
    return 0
}

validate_audio_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log "ERROR" "Audio file does not exist: $file"
        return 1
    fi
    
    if [ ! -r "$file" ]; then
        log "ERROR" "Audio file is not readable: $file"
        return 1
    fi
    
    # Check if it's a valid audio file
    if ! mediainfo "$file" | grep -q "Audio"; then
        log "ERROR" "Invalid audio file format: $file"
        return 1
    fi
    
    return 0
}

count_images() {
    local dir="$1"
    local count=0
    
    for format in "${SUPPORTED_FORMATS[@]}"; do
        count=$((count + $(find "$dir" -maxdepth 1 -name "*.$format" -type f | wc -l)))
    done
    
    echo "$count"
}

get_audio_duration() {
    local audio_file="$1"
    mediainfo --Inform="Audio;%Duration%" "$audio_file" | head -1 | awk '{print $1/1000}'
}

calculate_video_duration() {
    local image_count="$1"
    local frame_rate="$2"
    
    # Convert frame_rate (e.g., "1/5") to decimal
    local rate_decimal
    if [[ $frame_rate == *"/"* ]]; then
        local numerator=${frame_rate%/*}
        local denominator=${frame_rate#*/}
        rate_decimal=$(echo "scale=2; $numerator / $denominator" | bc)
    else
        rate_decimal=$frame_rate
    fi
    
    echo "scale=2; $image_count / $rate_decimal" | bc
}

format_duration() {
    local seconds="$1"
    local hours=$((${seconds%.*} / 3600))
    local minutes=$(((${seconds%.*} % 3600) / 60))
    local secs=$((${seconds%.*} % 60))
    
    if [ "$hours" -gt 0 ]; then
        printf "%02d:%02d:%02d" "$hours" "$minutes" "$secs"
    else
        printf "%02d:%02d" "$minutes" "$secs"
    fi
}

browse_generated_videos() {
    local videos=()
    local count=0
    
    echo -e "${CYAN}${BOLD}Generated Videos Browser${NC}"
    echo -e "${PURPLE}─────────────────────────${NC}"
    echo ""
    
    # Check if directory exists and has videos
    if [ ! -d "$VIDEO_OUTPUT_DIR" ] || [ -z "$(ls -A "$VIDEO_OUTPUT_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No generated videos found in: $VIDEO_OUTPUT_DIR${NC}"
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    # Collect video files
    while IFS= read -r -d '' file; do
        videos+=("$file")
        ((count++))
        local filename=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        local date=$(stat -c %y "$file" | cut -d' ' -f1)
        echo -e "${CYAN}$count.${NC} ${WHITE}$filename${NC} ${YELLOW}($size, $date)${NC}"
    done < <(find "$VIDEO_OUTPUT_DIR" -name "*.mp4" -type f -print0 | sort -z)
    
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No MP4 videos found in generated videos directory${NC}"
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}0.${NC} ${WHITE}Browse external file instead${NC}"
    echo ""
    echo -n -e "${YELLOW}Select a video [0-$count]: ${NC}"
    read -r choice
    
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "$count" ]; then
        echo "${videos[$((choice-1))]}"
        return 0
    elif [ "$choice" = "0" ]; then
        return 2  # Signal to browse external
    else
        echo -e "${RED}Invalid selection${NC}"
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
}

browse_audio_files() {
    local audio_files=()
    local count=0
    local search_dirs=("$AUDIO_OUTPUT_DIR" "$HOME/Music" "$HOME/Downloads")
    
    echo -e "${CYAN}${BOLD}Audio Files Browser${NC}"
    echo -e "${PURPLE}──────────────────${NC}"
    echo ""
    
    # Search common audio locations
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' file; do
                if [[ "$file" =~ \.(mp3|wav|aac|m4a|flac|ogg)$ ]]; then
                    audio_files+=("$file")
                    ((count++))
                    local filename=$(basename "$file")
                    local size=$(du -h "$file" 2>/dev/null | cut -f1)
                    local location=$(dirname "$file")
                    echo -e "${CYAN}$count.${NC} ${WHITE}$filename${NC} ${YELLOW}($size)${NC}"
                    echo -e "    ${PURPLE}└─ $location${NC}"
                fi
            done < <(find "$dir" -maxdepth 2 -type f -print0 2>/dev/null | sort -z)
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No audio files found in common locations${NC}"
        echo -e "${CYAN}0.${NC} ${WHITE}Browse external file manually${NC}"
        echo ""
        echo -n -e "${YELLOW}Press 0 or Enter to browse manually: ${NC}"
        read -r choice
        return 2  # Signal to browse external
    fi
    
    echo ""
    echo -e "${CYAN}0.${NC} ${WHITE}Browse external file instead${NC}"
    echo ""
    echo -n -e "${YELLOW}Select an audio file [0-$count]: ${NC}"
    read -r choice
    
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "$count" ]; then
        echo "${audio_files[$((choice-1))]}"
        return 0
    elif [ "$choice" = "0" ] || [ -z "$choice" ]; then
        return 2  # Signal to browse external
    else
        echo -e "${RED}Invalid selection${NC}"
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
}

get_file_with_browser() {
    local file_type="$1"  # "video" or "audio"
    local prompt="$2"
    local selected_file=""
    
    while true; do
        echo ""
        echo -e "${CYAN}File Selection Options:${NC}"
        echo -e "${CYAN}1.${NC} ${WHITE}Browse generated files${NC}"
        echo -e "${CYAN}2.${NC} ${WHITE}Enter custom path${NC}"
        echo ""
        echo -n -e "${YELLOW}Choose option [1-2]: ${NC}"
        read -r option
        
        case $option in
            1)
                if [ "$file_type" = "video" ]; then
                    selected_file=$(browse_generated_videos)
                    local result=$?
                    if [ $result -eq 0 ]; then
                        echo "$selected_file"
                        return 0
                    elif [ $result -eq 2 ]; then
                        # User chose to browse external, continue to option 2
                        option=2
                    else
                        continue
                    fi
                elif [ "$file_type" = "audio" ]; then
                    selected_file=$(browse_audio_files)
                    local result=$?
                    if [ $result -eq 0 ]; then
                        echo "$selected_file"
                        return 0
                    elif [ $result -eq 2 ]; then
                        # User chose to browse external, continue to option 2
                        option=2
                    else
                        continue
                    fi
                fi
                ;&  # Fall through to option 2 if user chose external browsing
            2)
                echo ""
                echo -n -e "${CYAN}$prompt: ${NC}"
                read -r selected_file
                if [ -f "$selected_file" ]; then
                    echo "$selected_file"
                    return 0
                else
                    echo -e "${RED}File not found: $selected_file${NC}"
                    echo -e "${CYAN}Press Enter to try again...${NC}"
                    read -r
                fi
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

# =============================================================================
# MENU FUNCTIONS
# =============================================================================

show_main_menu() {
    print_header
    echo -e "${BOLD}${WHITE}MAIN MENU${NC} $(get_mode_status)"
    echo -e "${PURPLE}─────────────${NC}"
    echo ""
    echo -e "${CYAN}1.${NC} ${WHITE}Create Video from Images${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Add Audio to Existing Video${NC}"
    echo -e "${CYAN}3.${NC} ${WHITE}Create Video + Audio (Complete Pipeline)${NC}"
    echo -e "${CYAN}4.${NC} ${WHITE}Settings & Configuration${NC}"
    echo -e "${CYAN}5.${NC} ${WHITE}View Storage Files${NC}"
    echo -e "${CYAN}6.${NC} ${WHITE}Help & Documentation${NC}"
    echo -e "${CYAN}7.${NC} ${WHITE}Exit${NC}"
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -n -e "${YELLOW}Select an option [1-7]: ${NC}"
}

show_settings_menu() {
    print_header
    echo -e "${BOLD}${WHITE}SETTINGS & CONFIGURATION${NC} $(get_mode_status)"
    echo -e "${PURPLE}─────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}Current Settings:${NC}"
    echo -e "  ${WHITE}Frame Rate:${NC} $FRAME_RATE seconds per image"
    echo -e "  ${WHITE}Video FPS:${NC} $VIDEO_FPS"
    echo -e "  ${WHITE}Audio Volume:${NC} $AUDIO_VOLUME"
    echo -e "  ${WHITE}Video Quality:${NC} $VIDEO_QUALITY"
    echo -e "  ${WHITE}Verbose Mode:${NC} $(get_status_indicator "$VERBOSE") $VERBOSE"
    echo -e "  ${WHITE}Debug Mode:${NC} $(get_status_indicator "$DEBUG") $DEBUG"
    echo ""
    echo -e "${CYAN}1.${NC} ${WHITE}Change Frame Rate (seconds per image)${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Change Video FPS${NC}"
    echo -e "${CYAN}3.${NC} ${WHITE}Change Audio Volume${NC}"
    echo -e "${CYAN}4.${NC} ${WHITE}Change Video Quality${NC}"
    echo -e "${CYAN}5.${NC} ${WHITE}Toggle Verbose Mode${NC} $(get_status_indicator "$VERBOSE")"
    echo -e "${CYAN}6.${NC} ${WHITE}Toggle Debug Mode${NC} $(get_status_indicator "$DEBUG")"
    echo -e "${CYAN}7.${NC} ${WHITE}Reset to Defaults${NC}"
    echo -e "${CYAN}8.${NC} ${WHITE}Back to Main Menu${NC}"
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -n -e "${YELLOW}Select an option [1-8]: ${NC}"
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

create_video_from_images() {
    print_header
    echo -e "${BOLD}${WHITE}CREATE VIDEO FROM IMAGES${NC}"
    echo -e "${PURPLE}─────────────────────────${NC}"
    echo ""
    
    # Get images directory
    echo -e "${CYAN}Directory Selection Options:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}Browse previous paths${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Enter new path${NC}"
    echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
    echo ""
    echo -n -e "${YELLOW}Choose option [1-2, b]: ${NC}"
    read -r dir_option
    
    case $dir_option in
        b|B)
            return 0
            ;;
        1)
            IMAGES_DIR=$(show_path_history)
            local result=$?
            if [ $result -eq 2 ]; then
                return 0  # Back to main menu
            elif [ $result -ne 0 ] || [ -z "$IMAGES_DIR" ]; then
                echo ""
                echo -n -e "${CYAN}Enter images directory path: ${NC}"
                read -r IMAGES_DIR
            fi
            ;;
        2)
            echo ""
            echo -n -e "${CYAN}Enter images directory path: ${NC}"
            read -r IMAGES_DIR
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1, 2, or b.${NC}"
            echo ""
            echo -n -e "${CYAN}Enter images directory path: ${NC}"
            read -r IMAGES_DIR
            ;;
    esac
    
    if ! validate_directory "$IMAGES_DIR"; then
        echo -e "${RED}Invalid directory. Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    # Add this path to history
    add_path_to_history "$IMAGES_DIR"
    
    # Count images
    local image_count
    image_count=$(count_images "$IMAGES_DIR")
    
    if [ "$image_count" -eq 0 ]; then
        log "ERROR" "No supported images found in directory"
        echo -e "${RED}Supported formats: ${SUPPORTED_FORMATS[*]}${NC}"
        echo -e "${RED}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    log "INFO" "Found $image_count images"
    
    # Get output filename
    echo -n -e "${CYAN}Enter output video name (without extension): ${NC}"
    read -r OUTPUT_NAME
    
    if [ -z "$OUTPUT_NAME" ]; then
        OUTPUT_NAME="output_video_$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Using default name: $OUTPUT_NAME"
    fi
    
    # Calculate video duration
    local video_duration
    video_duration=$(calculate_video_duration "$image_count" "$FRAME_RATE")
    local formatted_duration
    formatted_duration=$(format_duration "$video_duration")
    
    echo ""
    echo -e "${GREEN}${BOLD}Video Preview:${NC}"
    echo -e "${WHITE}  Images:${NC} $image_count"
    echo -e "${WHITE}  Frame Rate:${NC} $FRAME_RATE seconds per image"
    echo -e "${WHITE}  Duration:${NC} $formatted_duration"
    echo -e "${WHITE}  Output:${NC} ${VIDEO_OUTPUT_DIR}/${OUTPUT_NAME}.mp4"
    echo ""
    
    echo -n -e "${YELLOW}Proceed with video creation? [y/N]: ${NC}"
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log "INFO" "Video creation cancelled"
        return 0
    fi
    
    # Create video
    log "INFO" "Starting video creation..."
    echo -e "${CYAN}Processing images...${NC}"
    
    local output_path="${VIDEO_OUTPUT_DIR}/${OUTPUT_NAME}.mp4"
    
    # Create symbolic links in a temporary directory with sequential names
    local temp_dir="/tmp/ffmpeg_images_$$"
    mkdir -p "$temp_dir"
    log "DEBUG" "Creating temporary directory: $temp_dir"
    
    # Find all supported image files and convert them to PNG format
    local counter=1
    for format in "${SUPPORTED_FORMATS[@]}"; do
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                local output_file="$temp_dir/$(printf "%05d.png" $counter)"
                local ext="${file##*.}"
                
                if [[ "${ext,,}" == "png" ]]; then
                    # If already PNG, just copy it
                    cp "$file" "$output_file"
                    log "VERBOSE" "Copied PNG: $(basename "$file")"
                else
                    # Convert to PNG using ImageMagick convert command
                    log "VERBOSE" "Converting $(basename "$file") to PNG"
                    if convert "$file" "$output_file" 2>/dev/null; then
                        log "VERBOSE" "Successfully converted: $(basename "$file")"
                    else
                        log "WARN" "Failed to convert: $(basename "$file")"
                        continue
                    fi
                fi
                ((counter++))
            fi
        done < <(find "$IMAGES_DIR" -maxdepth 1 -name "*.$format" -type f -print0 | sort -z)
    done
    
    if [ "$counter" -eq 1 ]; then
        log "ERROR" "No image files found or converted successfully"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log "VERBOSE" "Processed $((counter-1)) images to PNG format"
    
    # Use image2 input format with consistent PNG pattern
    local ffmpeg_cmd="ffmpeg -y -framerate $FRAME_RATE -i '$temp_dir/%05d.png'"
    
    case $VIDEO_QUALITY in
        "low")
            ffmpeg_cmd="$ffmpeg_cmd -c:v libx264 -crf 28 -preset fast"
            ;;
        "medium")
            ffmpeg_cmd="$ffmpeg_cmd -c:v libx264 -crf 23 -preset medium"
            ;;
        "high")
            ffmpeg_cmd="$ffmpeg_cmd -c:v libx264 -crf 18 -preset slow"
            ;;
    esac
    
    ffmpeg_cmd="$ffmpeg_cmd -r $VIDEO_FPS -pix_fmt yuv420p '$output_path'"
    
    log "DEBUG" "FFmpeg command: $ffmpeg_cmd"
    
    if eval "$ffmpeg_cmd"; then
        log "INFO" "Video created successfully: $output_path"
        echo ""
        echo -e "${GREEN}${BOLD}✓ Video Creation Complete!${NC}"
        echo -e "${WHITE}Output file:${NC} $output_path"
        echo -e "${WHITE}Duration:${NC} $formatted_duration"
        # Clean up temporary directory
        rm -rf "$temp_dir"
    else
        log "ERROR" "Failed to create video"
        # Clean up temporary directory on failure
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

add_audio_to_video() {
    print_header
    echo -e "${BOLD}${WHITE}ADD AUDIO TO VIDEO${NC}"
    echo -e "${PURPLE}──────────────────${NC}"
    echo ""
    
    # Get video file using browser
    echo -e "${CYAN}${BOLD}Step 1: Select Video File${NC}"
    echo ""
    echo -e "${CYAN}File Selection Options:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}Browse generated videos${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Enter video file path manually${NC}"
    echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
    echo ""
    echo -n -e "${YELLOW}Choose option [1-2, b]: ${NC}"
    read -r file_option
    
    video_file=""
    case $file_option in
        b|B)
            return 0
            ;;
        1)
            # Browse generated videos directly inline
            echo ""
            echo -e "${CYAN}${BOLD}Generated Videos Browser${NC}"
            echo -e "${PURPLE}─────────────────────────${NC}"
            echo ""
            
            # Ensure directory exists
            mkdir -p "$VIDEO_OUTPUT_DIR"
            
            # Check if directory has videos
            if [ -z "$(ls -A "$VIDEO_OUTPUT_DIR" 2>/dev/null)" ]; then
                echo -e "${YELLOW}No generated videos found in: $VIDEO_OUTPUT_DIR${NC}"
                echo -e "${CYAN}You can still enter a video file path manually.${NC}"
                echo ""
                echo -n -e "${CYAN}Enter video file path: ${NC}"
                read -r video_file
            else
                # Collect video files
                log "DEBUG" "Starting video collection..."
                videos=()
                count=0
                log "DEBUG" "About to run find command..."
                while IFS= read -r -d '' file; do
                    log "DEBUG" "Processing file: $file"
                    videos+=("$file")
                    ((count++))
                    filename=$(basename "$file")
                    size=$(du -h "$file" | cut -f1)
                    date=$(stat -c %y "$file" | cut -d' ' -f1)
                    echo -e "${CYAN}$count.${NC} ${WHITE}$filename${NC} ${YELLOW}($size, $date)${NC}"
                done < <(find "$VIDEO_OUTPUT_DIR" -name "*.mp4" -type f -print0 | sort -z)
                log "DEBUG" "Find command completed. Count: $count"
                
                if [ "$count" -eq 0 ]; then
                    echo -e "${YELLOW}No MP4 videos found in generated videos directory${NC}"
                    echo ""
                    echo -n -e "${CYAN}Enter video file path: ${NC}"
                    read -r video_file
                else
                    echo ""
                    echo -e "${CYAN}0.${NC} ${WHITE}Enter custom path instead${NC}"
                    echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
                    echo ""
                    echo -n -e "${YELLOW}Select a video [0-$count, b]: ${NC}"
                    read -r choice
                    
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                        video_file="${videos[$((choice-1))]}"
                    elif [ "$choice" = "0" ]; then
                        echo ""
                        echo -n -e "${CYAN}Enter video file path: ${NC}"
                        read -r video_file
                    elif [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
                        return 0
                    else
                        echo -e "${RED}Invalid selection. Please try again.${NC}"
                        echo ""
                        echo -n -e "${CYAN}Enter video file path: ${NC}"
                        read -r video_file
                    fi
                fi
            fi
            ;;
        2)
            echo ""
            echo -n -e "${CYAN}Enter video file path: ${NC}"
            read -r video_file
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1, 2, or b.${NC}"
            echo ""
            echo -n -e "${CYAN}Enter video file path: ${NC}"
            read -r video_file
            ;;
    esac
    
    # Validate video file
    while [ -z "$video_file" ] || [ ! -f "$video_file" ]; do
        if [ -z "$video_file" ]; then
            echo -e "${YELLOW}No file path entered.${NC}"
        else
            echo -e "${RED}File not found: $video_file${NC}"
        fi
        echo ""
        echo -n -e "${CYAN}Please enter a valid video file path (q=quit, b=back to main menu): ${NC}"
        read -r video_file
        if [ "$video_file" = "q" ] || [ "$video_file" = "Q" ]; then
            log "INFO" "Video selection cancelled by user"
            return 1
        elif [ "$video_file" = "b" ] || [ "$video_file" = "B" ]; then
            log "INFO" "Returning to main menu"
            return 0
        fi
    done
    
    log "INFO" "Selected video: $(basename "$video_file")"
    
    # Get audio file using browser
    echo -e "${CYAN}${BOLD}Step 2: Select Audio File${NC}"
    echo ""
    echo -e "${CYAN}File Selection Options:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}Browse available audio files${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Enter audio file path manually${NC}"
    echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
    echo ""
    echo -n -e "${YELLOW}Choose option [1-2, b]: ${NC}"
    read -r audio_option
    
    AUDIO_FILE=""
    case $audio_option in
        b|B)
            return 0
            ;;
        1)
            # Browse audio files directly inline
            echo ""
            echo -e "${CYAN}${BOLD}Audio Files Browser${NC}"
            echo -e "${PURPLE}──────────────────${NC}"
            echo ""
            
            # Ensure audio directory exists
            mkdir -p "$AUDIO_OUTPUT_DIR"
            
            # Search common audio locations
            audio_files=()
            count=0
            search_dirs=("$AUDIO_OUTPUT_DIR" "$HOME/Music" "$HOME/Downloads")
            
            for dir in "${search_dirs[@]}"; do
                if [ -d "$dir" ]; then
                    while IFS= read -r -d '' file; do
                        if [[ "$file" =~ \.(mp3|wav|aac|m4a|flac|ogg)$ ]]; then
                            audio_files+=("$file")
                            ((count++))
                            filename=$(basename "$file")
                            size=$(du -h "$file" 2>/dev/null | cut -f1)
                            location=$(dirname "$file")
                            echo -e "${CYAN}$count.${NC} ${WHITE}$filename${NC} ${YELLOW}($size)${NC}"
                            echo -e "    ${PURPLE}└─ $location${NC}"
                        fi
                    done < <(find "$dir" -maxdepth 2 -type f -print0 2>/dev/null | sort -z)
                fi
            done
            
            if [ "$count" -eq 0 ]; then
                echo -e "${YELLOW}No audio files found in common locations${NC}"
                echo ""
                echo -n -e "${CYAN}Enter audio file path: ${NC}"
                read -r AUDIO_FILE
            else
                echo ""
                echo -e "${CYAN}0.${NC} ${WHITE}Enter custom path instead${NC}"
                echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
                echo ""
                echo -n -e "${YELLOW}Select an audio file [0-$count, b]: ${NC}"
                read -r choice
                
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                    AUDIO_FILE="${audio_files[$((choice-1))]}"
                elif [ "$choice" = "0" ] || [ -z "$choice" ]; then
                    echo ""
                    echo -n -e "${CYAN}Enter audio file path: ${NC}"
                    read -r AUDIO_FILE
                elif [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
                    return 0
                else
                    echo -e "${RED}Invalid selection. Please try again.${NC}"
                    echo ""
                    echo -n -e "${CYAN}Enter audio file path: ${NC}"
                    read -r AUDIO_FILE
                fi
            fi
            ;;
        2)
            echo ""
            echo -n -e "${CYAN}Enter audio file path: ${NC}"
            read -r AUDIO_FILE
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1, 2, or b.${NC}"
            echo ""
            echo -n -e "${CYAN}Enter audio file path: ${NC}"
            read -r AUDIO_FILE
            ;;
    esac
    
    if [ -z "$AUDIO_FILE" ] || ! validate_audio_file "$AUDIO_FILE"; then
        echo -e "${RED}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    log "INFO" "Selected audio: $(basename "$AUDIO_FILE")"
    
    # Get output filename
    echo -n -e "${CYAN}Enter output filename (without extension): ${NC}"
    read -r OUTPUT_NAME
    
    if [ -z "$OUTPUT_NAME" ]; then
        local base_name
        base_name=$(basename "$video_file" .mp4)
        OUTPUT_NAME="${base_name}_with_audio_$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Using default name: $OUTPUT_NAME"
    fi
    
    # Get video and audio durations
    local video_duration
    video_duration=$(mediainfo --Inform="Video;%Duration%" "$video_file" | head -1 | awk '{print $1/1000}')
    local audio_duration
    audio_duration=$(get_audio_duration "$AUDIO_FILE")
    
    local video_formatted
    video_formatted=$(format_duration "$video_duration")
    local audio_formatted
    audio_formatted=$(format_duration "$audio_duration")
    
    echo ""
    echo -e "${GREEN}${BOLD}Audio/Video Analysis:${NC}"
    echo -e "${WHITE}  Video Duration:${NC} $video_formatted"
    echo -e "${WHITE}  Audio Duration:${NC} $audio_formatted"
    echo ""
    
    # Check duration compatibility
    local duration_diff
    duration_diff=$(echo "$audio_duration - $video_duration" | bc)
    
    if (( $(echo "$duration_diff > 3" | bc -l) )); then
        echo -e "${YELLOW}⚠ WARNING: Audio is ${duration_diff%.*} seconds longer than video${NC}"
        echo -e "${YELLOW}  Audio will be trimmed to match video duration${NC}"
    elif (( $(echo "$duration_diff < -3" | bc -l) )); then
        echo -e "${YELLOW}⚠ WARNING: Audio is ${duration_diff#-} seconds shorter than video${NC}"
        echo -e "${YELLOW}  Video will end with silence${NC}"
    else
        echo -e "${GREEN}✓ Audio and video durations are compatible${NC}"
    fi
    
    echo ""
    echo -n -e "${YELLOW}Proceed with audio addition? [y/N]: ${NC}"
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log "INFO" "Audio addition cancelled"
        return 0
    fi
    
    # Add audio to video
    log "INFO" "Adding audio to video..."
    echo -e "${CYAN}Processing audio/video merge...${NC}"
    
    local output_path="${VIDEO_OUTPUT_DIR}/${OUTPUT_NAME}.mp4"
    local ffmpeg_cmd="ffmpeg -y -i '$video_file' -i '$AUDIO_FILE' -c:v copy -c:a aac -filter:a 'volume=$AUDIO_VOLUME' -shortest '$output_path'"
    
    log "DEBUG" "FFmpeg command: $ffmpeg_cmd"
    
    if eval "$ffmpeg_cmd"; then
        log "INFO" "Audio added successfully: $output_path"
        echo ""
        echo -e "${GREEN}${BOLD}✓ Audio Addition Complete!${NC}"
        echo -e "${WHITE}Output file:${NC} $output_path"
    else
        log "ERROR" "Failed to add audio to video"
        return 1
    fi
    
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

complete_pipeline() {
    print_header
    echo -e "${BOLD}${WHITE}COMPLETE PIPELINE: IMAGES → VIDEO + AUDIO${NC}"
    echo -e "${PURPLE}─────────────────────────────────────────${NC}"
    echo ""
    
    # Get images directory
    echo -e "${CYAN}${BOLD}Step 1: Select Images Directory${NC}"
    echo -e "${CYAN}Directory Selection Options:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}Browse previous paths${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Enter new path${NC}"
    echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
    echo ""
    echo -n -e "${YELLOW}Choose option [1-2, b]: ${NC}"
    read -r dir_option
    
    case $dir_option in
        b|B)
            return 0
            ;;
        1)
            IMAGES_DIR=$(show_path_history)
            local result=$?
            if [ $result -eq 2 ]; then
                return 0  # Back to main menu
            elif [ $result -ne 0 ] || [ -z "$IMAGES_DIR" ]; then
                echo ""
                echo -n -e "${CYAN}Enter images directory path: ${NC}"
                read -r IMAGES_DIR
            fi
            ;;
        2)
            echo ""
            echo -n -e "${CYAN}Enter images directory path: ${NC}"
            read -r IMAGES_DIR
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1, 2, or b.${NC}"
            echo ""
            echo -n -e "${CYAN}Enter images directory path: ${NC}"
            read -r IMAGES_DIR
            ;;
    esac
    
    if ! validate_directory "$IMAGES_DIR"; then
        echo -e "${RED}Invalid directory. Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    # Add this path to history
    add_path_to_history "$IMAGES_DIR"
    
    log "INFO" "Selected images directory: $IMAGES_DIR"
    
    # Get audio file using browser
    echo -e "${CYAN}${BOLD}Step 2: Select Audio File${NC}"
    echo ""
    echo -e "${CYAN}File Selection Options:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}Browse available audio files${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Enter audio file path manually${NC}"
    echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
    echo ""
    echo -n -e "${YELLOW}Choose option [1-2, b]: ${NC}"
    read -r audio_option
    
    AUDIO_FILE=""
    case $audio_option in
        b|B)
            return 0
            ;;
        1)
            # Browse audio files directly inline
            echo ""
            echo -e "${CYAN}${BOLD}Audio Files Browser${NC}"
            echo -e "${PURPLE}──────────────────${NC}"
            echo ""
            
            # Ensure audio directory exists
            mkdir -p "$AUDIO_OUTPUT_DIR"
            
            # Search common audio locations
            audio_files=()
            count=0
            search_dirs=("$AUDIO_OUTPUT_DIR" "$HOME/Music" "$HOME/Downloads")
            
            for dir in "${search_dirs[@]}"; do
                if [ -d "$dir" ]; then
                    while IFS= read -r -d '' file; do
                        if [[ "$file" =~ \.(mp3|wav|aac|m4a|flac|ogg)$ ]]; then
                            audio_files+=("$file")
                            ((count++))
                            filename=$(basename "$file")
                            size=$(du -h "$file" 2>/dev/null | cut -f1)
                            location=$(dirname "$file")
                            echo -e "${CYAN}$count.${NC} ${WHITE}$filename${NC} ${YELLOW}($size)${NC}"
                            echo -e "    ${PURPLE}└─ $location${NC}"
                        fi
                    done < <(find "$dir" -maxdepth 2 -type f -print0 2>/dev/null | sort -z)
                fi
            done
            
            if [ "$count" -eq 0 ]; then
                echo -e "${YELLOW}No audio files found in common locations${NC}"
                echo ""
                echo -n -e "${CYAN}Enter audio file path: ${NC}"
                read -r AUDIO_FILE
            else
                echo ""
                echo -e "${CYAN}0.${NC} ${WHITE}Enter custom path instead${NC}"
                echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
                echo ""
                echo -n -e "${YELLOW}Select an audio file [0-$count, b]: ${NC}"
                read -r choice
                
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                    AUDIO_FILE="${audio_files[$((choice-1))]}"
                elif [ "$choice" = "0" ] || [ -z "$choice" ]; then
                    echo ""
                    echo -n -e "${CYAN}Enter audio file path: ${NC}"
                    read -r AUDIO_FILE
                elif [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
                    return 0
                else
                    echo -e "${RED}Invalid selection. Please try again.${NC}"
                    echo ""
                    echo -n -e "${CYAN}Enter audio file path: ${NC}"
                    read -r AUDIO_FILE
                fi
            fi
            ;;
        2)
            echo ""
            echo -n -e "${CYAN}Enter audio file path: ${NC}"
            read -r AUDIO_FILE
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1, 2, or b.${NC}"
            echo ""
            echo -n -e "${CYAN}Enter audio file path: ${NC}"
            read -r AUDIO_FILE
            ;;
    esac
    
    if [ -z "$AUDIO_FILE" ] || ! validate_audio_file "$AUDIO_FILE"; then
        echo -e "${RED}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    log "INFO" "Selected audio: $(basename "$AUDIO_FILE")"
    
    # Get output filename
    echo -n -e "${CYAN}Enter output filename (without extension): ${NC}"
    read -r OUTPUT_NAME
    
    if [ -z "$OUTPUT_NAME" ]; then
        OUTPUT_NAME="complete_video_$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Using default name: $OUTPUT_NAME"
    fi
    
    # Analyze content
    local image_count
    image_count=$(count_images "$IMAGES_DIR")
    
    if [ "$image_count" -eq 0 ]; then
        log "ERROR" "No supported images found"
        echo -e "${RED}Press Enter to continue...${NC}"
        read -r
        return 1
    fi
    
    local video_duration
    video_duration=$(calculate_video_duration "$image_count" "$FRAME_RATE")
    local audio_duration
    audio_duration=$(get_audio_duration "$AUDIO_FILE")
    
    local video_formatted
    video_formatted=$(format_duration "$video_duration")
    local audio_formatted
    audio_formatted=$(format_duration "$audio_duration")
    
    echo ""
    echo -e "${GREEN}${BOLD}Pipeline Preview:${NC}"
    echo -e "${WHITE}  Images:${NC} $image_count"
    echo -e "${WHITE}  Video Duration:${NC} $video_formatted"
    echo -e "${WHITE}  Audio Duration:${NC} $audio_formatted"
    echo -e "${WHITE}  Frame Rate:${NC} $FRAME_RATE seconds per image"
    echo -e "${WHITE}  Output:${NC} ${VIDEO_OUTPUT_DIR}/${OUTPUT_NAME}.mp4"
    echo ""
    
    # Duration analysis
    local duration_diff
    duration_diff=$(echo "$audio_duration - $video_duration" | bc)
    
    if (( $(echo "$duration_diff > 3" | bc -l) )); then
        echo -e "${YELLOW}⚠ Audio is longer than video by ${duration_diff%.*} seconds${NC}"
    elif (( $(echo "$duration_diff < -3" | bc -l) )); then
        echo -e "${YELLOW}⚠ Video is longer than audio by ${duration_diff#-} seconds${NC}"
    else
        echo -e "${GREEN}✓ Durations are well synchronized${NC}"
    fi
    
    echo ""
    echo -n -e "${YELLOW}Proceed with complete pipeline? [y/N]: ${NC}"
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log "INFO" "Pipeline cancelled"
        return 0
    fi
    
    # Execute pipeline
    log "INFO" "Starting complete pipeline..."
    
    # Step 1: Create video from images
    echo -e "${CYAN}Step 1/2: Creating video from images...${NC}"
    local temp_video="/tmp/${OUTPUT_NAME}_temp.mp4"
    local final_output="${VIDEO_OUTPUT_DIR}/${OUTPUT_NAME}.mp4"
    
    # Create symbolic links in a temporary directory with sequential names
    local temp_dir="/tmp/ffmpeg_images_pipeline_$$"
    mkdir -p "$temp_dir"
    log "DEBUG" "Creating temporary directory: $temp_dir"
    
    # Find all supported image files and convert them to PNG format
    local counter=1
    for format in "${SUPPORTED_FORMATS[@]}"; do
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                local output_file="$temp_dir/$(printf "%05d.png" $counter)"
                local ext="${file##*.}"
                
                if [[ "${ext,,}" == "png" ]]; then
                    # If already PNG, just copy it
                    cp "$file" "$output_file"
                    log "VERBOSE" "Copied PNG: $(basename "$file")"
                else
                    # Convert to PNG using ImageMagick convert command
                    log "VERBOSE" "Converting $(basename "$file") to PNG"
                    if convert "$file" "$output_file" 2>/dev/null; then
                        log "VERBOSE" "Successfully converted: $(basename "$file")"
                    else
                        log "WARN" "Failed to convert: $(basename "$file")"
                        continue
                    fi
                fi
                ((counter++))
            fi
        done < <(find "$IMAGES_DIR" -maxdepth 1 -name "*.$format" -type f -print0 | sort -z)
    done
    
    if [ "$counter" -eq 1 ]; then
        log "ERROR" "No image files found or converted successfully"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log "VERBOSE" "Processed $((counter-1)) images to PNG format"
    
    local ffmpeg_cmd1="ffmpeg -y -framerate $FRAME_RATE -i '$temp_dir/%05d.png'"
    
    case $VIDEO_QUALITY in
        "low")
            ffmpeg_cmd1="$ffmpeg_cmd1 -c:v libx264 -crf 28 -preset fast"
            ;;
        "medium")
            ffmpeg_cmd1="$ffmpeg_cmd1 -c:v libx264 -crf 23 -preset medium"
            ;;
        "high")
            ffmpeg_cmd1="$ffmpeg_cmd1 -c:v libx264 -crf 18 -preset slow"
            ;;
    esac
    
    ffmpeg_cmd1="$ffmpeg_cmd1 -r $VIDEO_FPS -pix_fmt yuv420p '$temp_video'"
    
    log "DEBUG" "Step 1 FFmpeg command: $ffmpeg_cmd1"
    
    if ! eval "$ffmpeg_cmd1"; then
        log "ERROR" "Failed to create video from images"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Step 2: Add audio
    echo -e "${CYAN}Step 2/2: Adding audio to video...${NC}"
    
    local ffmpeg_cmd2="ffmpeg -y -i '$temp_video' -i '$AUDIO_FILE' -c:v copy -c:a aac -filter:a 'volume=$AUDIO_VOLUME' -shortest '$final_output'"
    
    log "DEBUG" "Step 2 FFmpeg command: $ffmpeg_cmd2"
    
    if eval "$ffmpeg_cmd2"; then
        # Clean up temporary files
        rm -f "$temp_video"
        rm -rf "$temp_dir"
        
        log "INFO" "Complete pipeline finished successfully"
        echo ""
        echo -e "${GREEN}${BOLD}✓ Complete Pipeline Finished!${NC}"
        echo -e "${WHITE}Output file:${NC} $final_output"
        echo -e "${WHITE}Final Duration:${NC} $video_formatted (with audio)"
    else
        log "ERROR" "Failed to add audio to video"
        rm -f "$temp_video"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

handle_settings() {
    while true; do
        show_settings_menu
        read -r choice
        
        case $choice in
            1)
                echo ""
                echo -e "${CYAN}Current frame rate: $FRAME_RATE seconds per image${NC}"
                echo -e "${YELLOW}Examples: 0.5 (fast), 1 (normal), 2 (slow), 1/5 (very slow)${NC}"
                echo -n -e "${CYAN}Enter new frame rate: ${NC}"
                read -r new_rate
                if [[ $new_rate =~ ^[0-9]+(\.[0-9]+)?$|^[0-9]+/[0-9]+$ ]]; then
                    FRAME_RATE="$new_rate"
                    log "INFO" "Frame rate updated to: $FRAME_RATE"
                    save_settings
                else
                    log "ERROR" "Invalid frame rate format"
                fi
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            2)
                echo ""
                echo -e "${CYAN}Current video FPS: $VIDEO_FPS${NC}"
                echo -e "${YELLOW}Common values: 24, 30, 60${NC}"
                echo -n -e "${CYAN}Enter new video FPS: ${NC}"
                read -r new_fps
                if [[ $new_fps =~ ^[0-9]+$ ]] && [ "$new_fps" -gt 0 ] && [ "$new_fps" -le 120 ]; then
                    VIDEO_FPS="$new_fps"
                    log "INFO" "Video FPS updated to: $VIDEO_FPS"
                    save_settings
                else
                    log "ERROR" "Invalid FPS (must be 1-120)"
                fi
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            3)
                echo ""
                echo -e "${CYAN}Current audio volume: $AUDIO_VOLUME${NC}"
                echo -e "${YELLOW}Range: 0.1 (quiet) to 2.0 (loud), 1.0 = normal${NC}"
                echo -n -e "${CYAN}Enter new volume: ${NC}"
                read -r new_volume
                if [[ $new_volume =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$new_volume >= 0.1 && $new_volume <= 2.0" | bc -l) )); then
                    AUDIO_VOLUME="$new_volume"
                    log "INFO" "Audio volume updated to: $AUDIO_VOLUME"
                    save_settings
                else
                    log "ERROR" "Invalid volume (must be 0.1-2.0)"
                fi
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            4)
                echo ""
                echo -e "${CYAN}Current quality: $VIDEO_QUALITY${NC}"
                echo -e "${YELLOW}Options: low, medium, high${NC}"
                echo -n -e "${CYAN}Enter new quality: ${NC}"
                read -r new_quality
                case $new_quality in
                    low|medium|high)
                        VIDEO_QUALITY="$new_quality"
                        log "INFO" "Video quality updated to: $VIDEO_QUALITY"
                        save_settings
                        ;;
                    *)
                        log "ERROR" "Invalid quality option"
                        ;;
                esac
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            5)
                if [ "$VERBOSE" = true ]; then
                    VERBOSE=false
                    log "INFO" "Verbose mode disabled"
                else
                    VERBOSE=true
                    log "INFO" "Verbose mode enabled"
                fi
                save_settings
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            6)
                if [ "$DEBUG" = true ]; then
                    DEBUG=false
                    log "INFO" "Debug mode disabled"
                else
                    DEBUG=true
                    log "INFO" "Debug mode enabled"
                fi
                save_settings
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            7)
                FRAME_RATE="1/5"
                VIDEO_FPS=30
                AUDIO_VOLUME="1.0"
                VIDEO_QUALITY="medium"
                VERBOSE=false
                DEBUG=false
                save_settings
                log "INFO" "Settings reset to defaults"
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            8)
                break
                ;;
            *)
                log "ERROR" "Invalid option"
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
        esac
    done
}

view_storage_files() {
    print_header
    echo -e "${BOLD}${WHITE}PERSISTENT STORAGE FILES VIEWER${NC}"
    echo -e "${PURPLE}───────────────────────────────${NC}"
    echo ""
    
    # Array to store available files
    local files=()
    local file_descriptions=()
    local count=0
    
    echo -e "${GREEN}${BOLD}Available Storage Files:${NC}"
    echo ""
    
    # Check settings file
    if [ -f "$SETTINGS_FILE" ]; then
        ((count++))
        files+=("$SETTINGS_FILE")
        file_descriptions+=("Settings & Configuration")
        local size=$(du -h "$SETTINGS_FILE" | cut -f1)
        local date=$(stat -c %y "$SETTINGS_FILE" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo -e "${CYAN}$count.${NC} ${WHITE}Settings File${NC} ${YELLOW}($size, $date)${NC}"
        echo -e "    ${PURPLE}Path: $SETTINGS_FILE${NC}"
        echo -e "    ${WHITE}Contains: Debug/Verbose modes, Frame rate, Video FPS, Audio volume, Quality${NC}"
    else
        echo -e "${YELLOW}⚠${NC} ${WHITE}Settings File${NC} ${RED}(Not Found)${NC}"
        echo -e "    ${PURPLE}Path: $SETTINGS_FILE${NC}"
        echo -e "    ${WHITE}Status: File will be created when you change settings${NC}"
    fi
    echo ""
    
    # Check path history file
    if [ -f "$PATHS_HISTORY_FILE" ]; then
        ((count++))
        files+=("$PATHS_HISTORY_FILE")
        file_descriptions+=("Path History")
        local size=$(du -h "$PATHS_HISTORY_FILE" | cut -f1)
        local date=$(stat -c %y "$PATHS_HISTORY_FILE" | cut -d'.' -f1)
        local entries=$(wc -l < "$PATHS_HISTORY_FILE")
        echo -e "${CYAN}$count.${NC} ${WHITE}Path History File${NC} ${YELLOW}($size, $date)${NC}"
        echo -e "    ${PURPLE}Path: $PATHS_HISTORY_FILE${NC}"
        echo -e "    ${WHITE}Contains: $entries directory paths with timestamps${NC}"
    else
        echo -e "${YELLOW}⚠${NC} ${WHITE}Path History File${NC} ${RED}(Not Found)${NC}"
        echo -e "    ${PURPLE}Path: $PATHS_HISTORY_FILE${NC}"
        echo -e "    ${WHITE}Status: File will be created when you use image directories${NC}"
    fi
    echo ""
    
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No storage files found. Files will be created as you use the program.${NC}"
        echo ""
        echo -e "${CYAN}Press Enter to return to main menu...${NC}"
        read -r
        return 0
    fi
    
    # File interaction menu
    echo -e "${GREEN}${BOLD}File Actions:${NC}"
    echo -e "${CYAN}v.${NC} ${WHITE}View file contents${NC}"
    echo -e "${CYAN}d.${NC} ${WHITE}Delete file${NC}"
    echo -e "${CYAN}r.${NC} ${WHITE}Refresh file list${NC}"
    echo -e "${CYAN}b.${NC} ${WHITE}Back to main menu${NC}"
    echo ""
    echo -n -e "${YELLOW}Choose action [v/d/r/b]: ${NC}"
    read -r action
    
    case $action in
        v|V)
            view_file_contents "${files[@]}"
            ;;
        d|D)
            delete_storage_file "${files[@]}"
            ;;
        r|R)
            view_storage_files  # Refresh by calling itself
            ;;
        b|B)
            return 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            echo -e "${CYAN}Press Enter to continue...${NC}"
            read -r
            view_storage_files
            ;;
    esac
}

view_file_contents() {
    local files=("$@")
    
    echo ""
    echo -e "${CYAN}${BOLD}Select file to view:${NC}"
    echo ""
    
    local i=1
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        echo -e "${CYAN}$i.${NC} ${WHITE}$filename${NC}"
        ((i++))
    done
    echo ""
    echo -e "${CYAN}b.${NC} ${WHITE}Back to file list${NC}"
    echo ""
    echo -n -e "${YELLOW}Select file [1-${#files[@]}, b]: ${NC}"
    read -r choice
    
    if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        view_storage_files
        return 0
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#files[@]}" ]; then
        local selected_file="${files[$((choice-1))]}"
        local filename=$(basename "$selected_file")
        
        echo ""
        echo -e "${GREEN}${BOLD}Contents of $filename:${NC}"
        echo -e "${PURPLE}════════════════════════════════════════${NC}"
        echo ""
        
        if [[ "$selected_file" == *"settings"* ]]; then
            # Format settings file nicely
            while IFS='=' read -r key value; do
                echo -e "${CYAN}$key:${NC} ${WHITE}$value${NC}"
            done < "$selected_file"
        else
            # Show path history with formatting
            while IFS=' | ' read -r timestamp path; do
                echo -e "${YELLOW}$timestamp${NC} ${WHITE}→${NC} ${CYAN}$path${NC}"
            done < "$selected_file"
        fi
        
        echo ""
        echo -e "${PURPLE}════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}Actions:${NC}"
        echo -e "${CYAN}v.${NC} ${WHITE}View another file${NC}"
        echo -e "${CYAN}b.${NC} ${WHITE}Back to file list${NC}"
        echo ""
        echo -n -e "${YELLOW}Choose action [v/b]: ${NC}"
        read -r next_action
        
        case $next_action in
            v|V)
                view_file_contents "${files[@]}"
                ;;
            *)
                view_storage_files
                ;;
        esac
    else
        echo -e "${RED}Invalid selection${NC}"
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
        view_file_contents "${files[@]}"
    fi
}

delete_storage_file() {
    local files=("$@")
    
    echo ""
    echo -e "${RED}${BOLD}⚠ DELETE STORAGE FILE${NC}"
    echo -e "${YELLOW}Warning: This will permanently delete the selected file!${NC}"
    echo ""
    
    local i=1
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        echo -e "${CYAN}$i.${NC} ${WHITE}$filename${NC}"
        ((i++))
    done
    echo ""
    echo -e "${CYAN}b.${NC} ${WHITE}Back to file list (cancel)${NC}"
    echo ""
    echo -n -e "${YELLOW}Select file to DELETE [1-${#files[@]}, b]: ${NC}"
    read -r choice
    
    if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        view_storage_files
        return 0
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#files[@]}" ]; then
        local selected_file="${files[$((choice-1))]}"
        local filename=$(basename "$selected_file")
        
        echo ""
        echo -e "${RED}${BOLD}CONFIRM DELETION${NC}"
        echo -e "${WHITE}File to delete: ${RED}$filename${NC}"
        echo -e "${WHITE}Path: ${PURPLE}$selected_file${NC}"
        echo ""
        echo -n -e "${YELLOW}Are you sure? Type 'DELETE' to confirm: ${NC}"
        read -r confirm
        
        if [ "$confirm" = "DELETE" ]; then
            if rm "$selected_file" 2>/dev/null; then
                echo -e "${GREEN}✓ File deleted successfully${NC}"
                log "INFO" "Deleted storage file: $selected_file"
            else
                echo -e "${RED}✗ Failed to delete file${NC}"
                log "ERROR" "Failed to delete storage file: $selected_file"
            fi
        else
            echo -e "${YELLOW}Deletion cancelled${NC}"
        fi
        
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
        view_storage_files
    else
        echo -e "${RED}Invalid selection${NC}"
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
        delete_storage_file "${files[@]}"
    fi
}

show_help() {
    print_header
    echo -e "${BOLD}${WHITE}HELP & DOCUMENTATION${NC}"
    echo -e "${PURPLE}────────────────────${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Supported Image Formats:${NC}"
    echo -e "${WHITE}  $(IFS=', '; echo "${SUPPORTED_FORMATS[*]}")${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Supported Audio Formats:${NC}"
    echo -e "${WHITE}  MP3, WAV, AAC, M4A, FLAC, OGG${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Tips for Best Results:${NC}"
    echo -e "${WHITE}  • Use images with consistent resolution${NC}"
    echo -e "${WHITE}  • Organize images in chronological order${NC}"
    echo -e "${WHITE}  • Use high-quality audio files (192kbps+)${NC}"
    echo -e "${WHITE}  • Test with small batches first${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Frame Rate Guide:${NC}"
    echo -e "${WHITE}  • 0.5 = 0.5 seconds per image (fast slideshow)${NC}"
    echo -e "${WHITE}  • 1   = 1 second per image (normal)${NC}"
    echo -e "${WHITE}  • 2   = 2 seconds per image (slow)${NC}"
    echo -e "${WHITE}  • 1/5 = 5 seconds per image (very slow)${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Quality Settings:${NC}"
    echo -e "${WHITE}  • Low:    Fast encoding, larger file size${NC}"
    echo -e "${WHITE}  • Medium: Balanced quality and size${NC}"
    echo -e "${WHITE}  • High:   Best quality, slower encoding${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Output Directories:${NC}"
    echo -e "${WHITE}  • Videos:              $VIDEO_OUTPUT_DIR${NC}"
    echo -e "${WHITE}  • Videos with Audio:   $AUDIO_OUTPUT_DIR${NC}"
    echo -e "${WHITE}  • Auto-created if missing${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Persistent Storage Files:${NC}"
    echo -e "${WHITE}The program creates hidden files in your home directory to remember${NC}"
    echo -e "${WHITE}your preferences and frequently used paths across sessions:${NC}"
    echo ""
    echo -e "${CYAN}  Settings File: ${WHITE}$SETTINGS_FILE${NC}"
    echo -e "${WHITE}    • Stores: Debug/Verbose modes, Frame rate, Video FPS, Audio volume, Quality${NC}"
    echo -e "${WHITE}    • Created: When you change any setting in the Settings menu${NC}"
    echo -e "${WHITE}    • Loaded: Automatically on program startup${NC}"
    echo -e "${WHITE}    • Purpose: Remembers your preferred configuration between sessions${NC}"
    echo ""
    echo -e "${CYAN}  Path History: ${WHITE}$PATHS_HISTORY_FILE${NC}"
    echo -e "${WHITE}    • Stores: Image directory paths with timestamps of last use${NC}"
    echo -e "${WHITE}    • Created: When you successfully use a directory for video creation${NC}"
    echo -e "${WHITE}    • Loaded: When you choose 'Browse previous paths' option${NC}"
    echo -e "${WHITE}    • Purpose: Quick access to frequently used image directories${NC}"
    echo -e "${WHITE}    • Display: Shows directory info with ls -lha style details${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}File Interaction Flow:${NC}"
    echo -e "${WHITE}  1. Startup → Loads settings from $SETTINGS_FILE${NC}"
    echo -e "${WHITE}  2. Settings changed → Immediately saves to $SETTINGS_FILE${NC}"
    echo -e "${WHITE}  3. Directory used → Adds entry to $PATHS_HISTORY_FILE${NC}"
    echo -e "${WHITE}  4. Browse paths → Reads and displays $PATHS_HISTORY_FILE${NC}"
    echo -e "${WHITE}  5. Next session → Repeats cycle with saved preferences${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}File Management:${NC}"
    echo -e "${WHITE}  • Files are automatically created when needed${NC}"
    echo -e "${WHITE}  • Missing files show informational messages (not errors)${NC}"
    echo -e "${WHITE}  • Delete files to reset to defaults: ${CYAN}rm $SETTINGS_FILE $PATHS_HISTORY_FILE${NC}"
    echo -e "${WHITE}  • Files are hidden (start with .) and stored in your home directory${NC}"
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================

main() {
    # Load saved settings first
    load_settings
    
    # Check dependencies first
    check_dependencies
    
    # Setup output directories
    setup_output_directories
    
    # Main menu loop
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)
                create_video_from_images
                ;;
            2)
                add_audio_to_video
                ;;
            3)
                complete_pipeline
                ;;
            4)
                handle_settings
                ;;
            5)
                view_storage_files
                ;;
            6)
                show_help
                ;;
            7)
                print_header
                echo -e "${GREEN}${BOLD}Thank you for using Video Generator!${NC}"
                echo -e "${CYAN}Created with ❤️  by Claude Code Assistant${NC}"
                echo ""
                exit 0
                ;;
            *)
                log "ERROR" "Invalid option selected"
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
        esac
    done
}

# Error handling - disabled to prevent premature exits
# set -eo pipefail
trap 'log "ERROR" "Script interrupted"; exit 1' INT TERM

# Start the program
main "$@"
