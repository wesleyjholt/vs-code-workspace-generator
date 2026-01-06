#!/bin/bash

###############################################################################
# spawn-workspace.sh
# 
# Creates git worktrees for multiple repositories and generates a VS Code
# multi-root workspace file.
#
# Usage:
#   ./spawn-workspace.sh -r repo1:branch1 -r repo2:branch2 -r repo3:branch3
#   ./spawn-workspace.sh -r repo1:repo2:repo3 -b feature/my-feature
#   ./spawn-workspace.sh -r /path/to/repo1 -r /path/to/repo2 -b main
#
# Options:
#   -r, --repo PATH              Absolute path to a repository (can be used multiple times)
#   -r, --repo PATH:BRANCH       Path and branch for a specific repo (can be used multiple times)
#   -b, --branch NAME            Branch name to use for all repos (default: current branch)
#   -o, --output DIR             Output directory for worktrees (default: ./workspaces)
#   -n, --name WORKSPACE_NAME    Name for the workspace (default: auto-generated timestamp)
#   -h, --help                   Show this help message
#
# Examples:
#   # Create worktrees with same branch for all repos
#   ./spawn-workspace.sh -r ~/my-app -r ~/my-lib -r ~/my-config -b feature/new-thing
#
#   # Create worktrees with different branches
#   ./spawn-workspace.sh -r ~/repo1:feature/one -r ~/repo2:feature/two -r ~/repo3:hotfix/bug
#
#   # Specify output directory and workspace name
#   ./spawn-workspace.sh -r ~/repo1 -r ~/repo2 -b dev -o ~/workspaces -n "dev-env"
###############################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
declare -a REPO_PATHS
declare -a REPO_BRANCHES
GLOBAL_BRANCH=""
OUTPUT_DIR="./workspaces"
WORKSPACE_NAME=""
WORKSPACE_DIR=""

# Helper functions
print_help() {
    grep "^#" "$0" | grep -E "^\s*#\s+" | sed 's/^#\s*//'
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--repo)
                if [[ -z "${2:-}" ]]; then
                    log_error "Repository path required after -r"
                    exit 1
                fi
                
                # Check if branch is specified with colon
                if [[ "$2" == *":"* ]]; then
                    REPO_PATHS+=("${2%:*}")
                    REPO_BRANCHES+=("${2#*:}")
                else
                    REPO_PATHS+=("$2")
                    REPO_BRANCHES+=("")
                fi
                shift 2
                ;;
            -b|--branch)
                if [[ -z "${2:-}" ]]; then
                    log_error "Branch name required after -b"
                    exit 1
                fi
                GLOBAL_BRANCH="$2"
                shift 2
                ;;
            -o|--output)
                if [[ -z "${2:-}" ]]; then
                    log_error "Output directory required after -o"
                    exit 1
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--name)
                if [[ -z "${2:-}" ]]; then
                    log_error "Workspace name required after -n"
                    exit 1
                fi
                WORKSPACE_NAME="$2"
                shift 2
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
}

# Validate repositories
validate_repos() {
    if [[ ${#REPO_PATHS[@]} -eq 0 ]]; then
        log_error "At least one repository path must be specified with -r"
        exit 1
    fi
    
    for repo in "${REPO_PATHS[@]}"; do
        if [[ ! -d "$repo/.git" ]]; then
            log_error "Invalid git repository: $repo"
            exit 1
        fi
    done
}

# Resolve branch for a repository
get_branch_for_repo() {
    local index=$1
    
    # If a specific branch was provided for this repo, use it
    if [[ -n "${REPO_BRANCHES[$index]}" ]]; then
        echo "${REPO_BRANCHES[$index]}"
    # If a global branch was specified, use it
    elif [[ -n "$GLOBAL_BRANCH" ]]; then
        echo "$GLOBAL_BRANCH"
    # Otherwise, use the current branch of the repo
    else
        git -C "${REPO_PATHS[$index]}" rev-parse --abbrev-ref HEAD
    fi
}

# Create git worktrees
create_worktrees() {
    log_info "Creating workspace directory: $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR"
    
    declare -a WORKTREE_PATHS
    
    for i in "${!REPO_PATHS[@]}"; do
        repo_path="${REPO_PATHS[$i]}"
        branch=$(get_branch_for_repo "$i")
        
        # Get repo name from path
        repo_name=$(basename "$repo_path")
        worktree_path="$WORKSPACE_DIR/$repo_name"
        
        WORKTREE_PATHS+=("$worktree_path")
        
        log_info "Creating worktree for $repo_name on branch '$branch'"
        
        # Check if worktree already exists
        if [[ -d "$worktree_path" ]]; then
            log_warn "Worktree already exists at $worktree_path, skipping..."
            continue
        fi
        
        # Check if branch exists, create if it doesn't
        if git -C "$repo_path" rev-parse --verify "$branch" >/dev/null 2>&1; then
            # Branch exists, create worktree from existing branch
            git -C "$repo_path" worktree add "$worktree_path" "$branch"
        else
            # Branch doesn't exist, create new branch from HEAD
            log_warn "Branch '$branch' doesn't exist in $repo_name, creating from HEAD"
            git -C "$repo_path" worktree add -b "$branch" "$worktree_path"
        fi
        
        log_success "Created worktree at $worktree_path"
    done
    
    # Store worktree paths for workspace generation
    printf '%s\n' "${WORKTREE_PATHS[@]}" > "$WORKSPACE_DIR/.worktree_paths"
}

# Generate VS Code workspace file
generate_workspace_file() {
    local workspace_file="$WORKSPACE_DIR/workspace.code-workspace"
    
    log_info "Generating VS Code workspace file: $workspace_file"
    
    local -a worktree_paths
    worktree_paths=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] && worktree_paths+=("$line")
    done < "$WORKSPACE_DIR/.worktree_paths"

    # Start JSON
    {
        echo "{"
        echo '  "folders": ['

        for i in "${!worktree_paths[@]}"; do
            local path="${worktree_paths[$i]}"
            local name
            name=$(basename "$path")

            echo "    {"
            echo "      \"path\": \"$path\","
            echo "      \"name\": \"$name\""

            # Add comma except for last item
            if [[ $i -lt $((${#worktree_paths[@]} - 1)) ]]; then
                echo "    },"
            else
                echo "    }"
            fi
        done

        echo "  ],"
        echo "  \"settings\": {"
        echo "    \"editor.formatOnSave\": true"
        echo "  }"
        echo "}"
    } > "$workspace_file"
    
    log_success "Workspace file created: $workspace_file"
    
    # Clean up temporary file
    rm "$WORKSPACE_DIR/.worktree_paths"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Workspace Created Successfully${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Workspace Directory: ${BLUE}$WORKSPACE_DIR${NC}"
    echo -e "Workspace File: ${BLUE}$WORKSPACE_DIR/workspace.code-workspace${NC}"
    echo ""
    echo "To open this workspace in VS Code:"
    echo -e "  ${BLUE}code \"$WORKSPACE_DIR/workspace.code-workspace\"${NC}"
    echo ""
    echo "Repositories:"
    
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local name
        name=$(basename "$path")
        local branch
        branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        echo -e "  • ${BLUE}$name${NC} (branch: ${YELLOW}$branch${NC})"
    done < <(find "$WORKSPACE_DIR" -maxdepth 1 -type d -not -name ".*" -not -path "$WORKSPACE_DIR")
    
    echo ""
    echo "Useful commands:"
    echo "  List worktrees: git worktree list"
    echo "  Remove a worktree: git worktree remove <path>"
    echo "  Switch branch in worktree: cd $WORKSPACE_DIR/<repo> && git checkout <branch>"
    echo ""
}

# Main execution
main() {
    log_info "Spawn Multi-Root Workspace Script"
    echo ""
    
    parse_arguments "$@"
    validate_repos
    
    # Generate workspace name if not provided
    if [[ -z "$WORKSPACE_NAME" ]]; then
        WORKSPACE_NAME="workspace-$(date +%Y%m%d-%H%M%S)"
    fi
    
    WORKSPACE_DIR="$OUTPUT_DIR/$WORKSPACE_NAME"
    
    # Check if workspace already exists
    if [[ -d "$WORKSPACE_DIR" ]]; then
        log_warn "Workspace directory already exists: $WORKSPACE_DIR"
        read -p "Continue and update worktrees? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled."
            exit 0
        fi
    fi
    
    create_worktrees
    generate_workspace_file
    print_summary
}

# Run main function
main "$@"