# Spawn Multi-Root Workspace Script - Key Features

## Flexible Input Options
- **Multiple Repository Support**: Add unlimited repositories using multiple `-r` flags
- **Per-Repository Branch Control**: Specify different branches for each repo with `-r /path/to/repo:branch-name` syntax
- **Global Branch Option**: Use `-b branch-name` to apply the same branch across all repositories
- **Mixed Mode**: Combine both approaches—some repos with specific branches, others using the global branch
- **Smart Fallback**: Automatically uses current branch if no branch specified

## Git Worktree Management
- **Automated Worktree Creation**: Creates linked worktrees for all repositories in a single operation
- **Branch Validation**: Checks if branches exist before creating worktrees
- **Auto-Create Branches**: Creates new branches from HEAD if they don't exist
- **Duplicate Prevention**: Detects and skips existing worktrees
- **Repository Validation**: Verifies all paths are valid git repositories before starting

## VS Code Integration
- **Multi-Root Workspace File**: Generates properly formatted `.code-workspace` JSON file
- **Folder Organization**: Each repository worktree added as a named folder
- **One-Command Launch**: Open entire workspace with `code workspace.code-workspace`
- **Customizable Settings**: Includes default workspace settings (extensible)

## Output Organization
- **Structured Directory Layout**: All worktrees organized under a single workspace directory
- **Custom Output Location**: Specify where workspaces are created with `-o` flag
- **Named Workspaces**: Provide custom workspace names with `-n` flag
- **Timestamp Naming**: Auto-generates unique workspace names using timestamps

## User Experience
- **Colored Terminal Output**: Visual feedback with icons and colors (info, success, warnings, errors)
- **Comprehensive Help**: Built-in `--help` with usage examples
- **Progress Logging**: Real-time feedback during worktree creation
- **Summary Report**: Post-creation summary with all worktree info and useful commands
- **Interactive Prompts**: Confirms before overwriting existing workspaces

## Safety & Error Handling
- **Input Validation**: Validates all arguments before execution
- **Exit on Error**: `set -euo pipefail` prevents silent failures
- **Repository Checks**: Verifies `.git` directory exists for each repo
- **Graceful Warnings**: Non-blocking warnings for edge cases
- **Cleanup Support**: Provides commands for managing and removing worktrees

## Workflow Benefits
- **Concurrent Development**: Work on multiple branches across all repos simultaneously
- **Agent-Ready**: Perfect for spawning isolated environments for AI agents or parallel tasks
- **No Branch Switching**: Avoid constant `git checkout` between branches
- **Disk Efficient**: Worktrees share git objects with main repository
- **Context Preservation**: Each workspace maintains independent working s


# Usage
## Example
```bash
# All repos on same branch
./spawn-workspace.sh -r ~/repo1 -r ~/repo2 -r ~/repo3 -b feature/new-thing

# Different branches per repo
./spawn-workspace.sh -r ~/repo1:feature/auth -r ~/repo2:feature/api -r ~/repo3:main

# Custom output directory and workspace name
./spawn-workspace.sh \
  -r ~/app -r ~/lib -r ~/config \
  -b dev \
  -o ~/workspaces \
  -n "my-dev-env"

# Mixed approach
./spawn-workspace.sh \
  -r ~/repo1:hotfix/bug \
  -r ~/repo2 \
  -b staging
```

## What gets created
```
workspaces/workspace-20260105-195400/
├── workspace.code-workspace    # VS Code workspace file
├── repo1/                       # Git worktree
│   ├── .git (pointer file)
│   └── [repo contents]
├── repo2/                       # Git worktree
└── repo3/                       # Git worktree
```
