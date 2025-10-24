# Push README to GitHub (PowerShell)
# Run this in VS Code terminal

# Set Git identity (repo-local)
git config user.name "Michael Wamai Gatane"
git config user.email "your@email.com"

# Initialize Git and commit README
if (-not (Test-Path .git)) {
  git init
}

git add README.md

# Commit only if there are staged changes
$staged = git diff --cached --name-only
if ($staged) {
  git commit -m "Add poetic profile README"
} else {
  Write-Output "No staged changes to commit."
}

# Set branch and remote (SSH)
git branch -M main
# If remote exists, update it; otherwise add it
if (git remote | Select-String origin) {
  git remote set-url origin git@github.com:michaelmainawamai-ship-it/michaelmainawamai-ship-it.git
} else {
  git remote add origin git@github.com:michaelmainawamai-ship-it/michaelmainawamai-ship-it.git
}

# Test SSH connection (optional but recommended)
ssh -T git@github.com

# Push to GitHub
git push -u origin main

Write-Output "Done. If push failed, check SSH keys and repo existence on GitHub."