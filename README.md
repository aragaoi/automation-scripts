# Automation Scripts

Personal automation scripts and utilities for development workflow.

## Scripts

### create-pr.sh

Automated PR creation script that generates PR titles and descriptions using AI.

**Features:**

- Generates PR title and description from git diff
- Extracts issue ID from branch name (e.g., ID-999)
- Includes dev-exp enhancements in description
- Tries Cursor agent first, falls back to Codex CLI
- Checks for existing PRs and updates them instead of creating duplicates
- Asks for confirmation before creating/updating PRs

**Setup:**

1. Install dependencies:

   ```bash
   npm install -g @openai/codex
   ```

2. Run the setup script:

   ```bash
   ~/bin/git-setup.sh
   ```

3. Use the git alias:
   ```bash
   git pr [base-branch]
   ```

**Usage:**

```bash
# Create PR against default branch (usually main/develop)
git pr

# Create PR against specific branch
git pr develop
```

**Requirements:**

- GitHub CLI (`gh`)
- Codex CLI (`codex`) - optional, used as fallback
- Cursor agent (`cursor agent`) - optional, used as primary

## Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/aragaoi/automation-scripts.git
   cd automation-scripts
   ```

   Or fork it to your own account and clone your fork.

2. Run the setup script (copies files to `~/bin` and configures git alias):
   ```bash
   ./setup.sh
   ```

The setup script will:

- Copy all scripts to `~/bin`
- Make them executable
- Configure the git alias `pr`

**Alternative manual installation:**

If you prefer to install manually:

```bash
git clone https://github.com/aragaoi/automation-scripts.git
cp automation-scripts/bin/* ~/bin/
chmod +x ~/bin/*.sh
~/bin/git-setup.sh
```

**Note:** The scripts use `$HOME` environment variable, which works on all Unix-like systems (macOS, Linux). All paths are relative and will adapt to each user's system.
