#!/bin/bash

# Detect the absolute path of the repo
REPO_ROOT=$(pwd)

echo "🗑️  Uninstalling HyperQL Development Environment..."

# 1. Remove LSP Symlink
echo "🔍 Checking for LSP symlink..."
LSP_LINK="$HOME/.cargo/bin/hyperql-lsp"
if [ -L "$LSP_LINK" ]; then
    rm "$LSP_LINK"
    echo "✅ Removed LSP symlink: $LSP_LINK"
elif [ -e "$LSP_LINK" ]; then
    echo "⚠️  Found '$LSP_LINK' but it is not a symlink. Keeping it for safety."
else
    echo "ℹ️  LSP symlink not found (skipped)."
fi

# 2. Clean Build Artifacts
echo "🧹 Cleaning build artifacts..."

# Remove temporary grammar repo
if [ -d "$REPO_ROOT/.grammar-tmp" ]; then
    rm -rf "$REPO_ROOT/.grammar-tmp"
    echo "✅ Removed .grammar-tmp/"
fi

# Remove LSP build artifacts
if [ -d "$REPO_ROOT/hyperql-lsp/zig-out" ]; then
    rm -rf "$REPO_ROOT/hyperql-lsp/zig-out"
    rm -rf "$REPO_ROOT/hyperql-lsp/zig-cache"
    echo "✅ Removed LSP build artifacts (zig-out, zig-cache)"
fi

# Remove Zed extension artifacts
if [ -d "$REPO_ROOT/hyperql-zed/target" ] || [ -f "$REPO_ROOT/hyperql-zed/extension.wasm" ]; then
    rm -rf "$REPO_ROOT/hyperql-zed/target"
    rm -f "$REPO_ROOT/hyperql-zed/extension.wasm"
    echo "✅ Removed Zed extension artifacts (target/, extension.wasm)"
fi

# 3. Restore extension.toml to git state
EXTENSION_TOML="hyperql-zed/extension.toml"
if [ -f "$EXTENSION_TOML" ] && command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "🔄 Restoring $EXTENSION_TOML to original state..."
    git checkout "$EXTENSION_TOML"
    echo "✅ Restored $EXTENSION_TOML"
fi

echo ""
echo "🎉 Clean up complete!"
echo "⚠️  FINAL STEP: Remove the extension from Zed"
echo "   (This must be done manually as Zed registers dev extensions internally)"
echo "1. Open Zed."
echo "2. Open the Extensions view (Cmd/Ctrl + Shift + X)."
echo "3. Locate 'HyperQL' (marked as Dev)."
echo "4. Click the gear icon or 'Uninstall' button."
