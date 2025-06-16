#!/bin/bash
# setup_github_labels.sh - Creates required GitHub labels for the issue watcher
#
# This script ensures all required labels exist in the GitHub repository
# It's called automatically by issue_watcher.sh on startup

REPO="protocolus/promptforge"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Define required labels with their colors and descriptions
# Format: "label_name|color_hex|description"
# Colors are hex codes without the # symbol
REQUIRED_LABELS=(
    # Main tracking label
    "clide-analyzed|0E8A16|Issue has been analyzed by Claude"
    
    # Issue type labels
    "bug|D73A4A|Something isn't working"
    "enhancement|A2EEEF|New feature or request"
    "question|D876E3|Further information is requested"
    "documentation|0075CA|Improvements or additions to documentation"
    "maintenance|FBCA04|Code cleanup, refactoring, or maintenance"
    
    # Priority labels
    "priority-high|B60205|High priority issue"
    "priority-medium|FBCA04|Medium priority issue"
    "priority-low|0E8A16|Low priority issue"
    
    # Difficulty labels
    "difficulty-easy|7ED321|Good for newcomers"
    "difficulty-moderate|FFA500|Moderate difficulty"
    "difficulty-complex|B60205|Complex implementation required"
    
    # Component labels
    "component-frontend|BFD4F2|Frontend/UI related"
    "component-backend|D4C5F9|Backend/Server related"
    "component-database|C5DEF5|Database related"
    
    # Additional useful labels
    "good first issue|7057FF|Good for newcomers"
    "help wanted|008672|Extra attention is needed"
    "wontfix|FFFFFF|This will not be worked on"
    "duplicate|CFD3D7|This issue or pull request already exists"
    "invalid|E4E669|This doesn't seem right"
)

# Function to check if a label exists
label_exists() {
    local label_name=$1
    local exists=$(gh label list --repo "$REPO" --search "$label_name" --json name | jq -r ".[] | select(.name == \"$label_name\") | .name")
    
    if [[ "$exists" == "$label_name" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to create a label
create_label() {
    local label_name=$1
    local color=$2
    local description=$3
    
    if gh label create "$label_name" --repo "$REPO" --color "$color" --description "$description" 2>/dev/null; then
        log_success "Created label: $label_name"
        return 0
    else
        log_error "Failed to create label: $label_name"
        return 1
    fi
}

# Function to update a label (if it exists but needs updating)
update_label() {
    local label_name=$1
    local color=$2
    local description=$3
    
    if gh label edit "$label_name" --repo "$REPO" --color "$color" --description "$description" 2>/dev/null; then
        log_success "Updated label: $label_name"
        return 0
    else
        log_warning "Could not update label: $label_name"
        return 1
    fi
}

# Main function to setup all labels
setup_labels() {
    log_message "Setting up GitHub labels for repository: $REPO"
    log_message "Checking ${#REQUIRED_LABELS[@]} required labels..."
    
    local created_count=0
    local existing_count=0
    local failed_count=0
    
    # Process each required label
    for label_info in "${REQUIRED_LABELS[@]}"; do
        # Parse label information
        IFS='|' read -r label_name color description <<< "$label_info"
        
        # Check if label exists
        if label_exists "$label_name"; then
            log_message "Label already exists: $label_name"
            ((existing_count++))
        else
            # Create the label
            if create_label "$label_name" "$color" "$description"; then
                ((created_count++))
            else
                ((failed_count++))
            fi
        fi
    done
    
    # Summary
    echo ""
    log_message "Label setup complete!"
    log_success "Existing labels: $existing_count"
    log_success "Created labels: $created_count"
    
    if [[ $failed_count -gt 0 ]]; then
        log_warning "Failed to create: $failed_count labels"
        log_warning "You may need to check repository permissions"
        return 1
    fi
    
    return 0
}

# Function to list all configured labels (for documentation)
list_configured_labels() {
    echo ""
    log_message "Configured labels for this repository:"
    echo ""
    
    for label_info in "${REQUIRED_LABELS[@]}"; do
        IFS='|' read -r label_name color description <<< "$label_info"
        echo "  • $label_name - $description"
    done
    echo ""
}

# Main execution
main() {
    # Check if custom repo was provided
    if [ -n "$1" ]; then
        REPO="$1"
        log_message "Using custom repository: ${REPO}"
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Run 'gh auth login'"
        exit 1
    fi
    
    # Setup labels
    setup_labels
    
    # Optionally list all configured labels
    if [[ "${2:-}" == "--list" ]]; then
        list_configured_labels
    fi
}

# Help function
show_help() {
    cat << EOF
GitHub Label Setup Script
=========================

This script ensures all required labels exist in your GitHub repository
for the automated issue watcher to function properly.

Usage: $0 [REPOSITORY] [OPTIONS]

Arguments:
  REPOSITORY    GitHub repository in format "owner/repo" (default: protocolus/promptforge)

Options:
  --list        Also display a list of all configured labels
  -h, --help    Show this help message

Examples:
  $0                              # Setup labels for default repository
  $0 microsoft/vscode            # Setup labels for a different repository
  $0 protocolus/promptforge --list  # Setup and list all labels

The script will:
1. Check for existing labels
2. Create any missing labels with appropriate colors and descriptions
3. Report on the results

Required labels include:
- Issue classification (bug, enhancement, question, etc.)
- Priority levels (high, medium, low)
- Difficulty levels (easy, moderate, complex)
- Component labels (frontend, backend, database)
- Special labels (clide-analyzed, good first issue, etc.)

EOF
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac