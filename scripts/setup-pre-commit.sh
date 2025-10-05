#!/bin/bash
# Setup pre-commit hooks for homelab infrastructure
set -e

echo "🔧 Setting up pre-commit hooks..."

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "📦 Installing pre-commit..."
    pip install pre-commit
else
    echo "✓ pre-commit already installed ($(pre-commit --version))"
fi

# Install the hooks
echo "🔗 Installing git hooks..."
pre-commit install

# Optionally run on all files
read -p "Run pre-commit on all existing files? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔍 Running pre-commit on all files (this may take a moment)..."
    pre-commit run --all-files || {
        echo "⚠️  Some checks failed - please fix the issues and try again"
        exit 1
    }
fi

echo "✅ Pre-commit hooks installed successfully!"
echo ""
echo "Hooks will now run automatically on git commit."
echo "To run manually: pre-commit run --all-files"
echo "To skip hooks: git commit --no-verify (use sparingly)"
