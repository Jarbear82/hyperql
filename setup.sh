#!/bin/bash
set -e

# Detect the absolute path of the repo
REPO_ROOT=$(pwd)
GRAMMAR_PATH="$REPO_ROOT/tree-sitter-hyperql"
LSP_PATH="$REPO_ROOT/hyperql-lsp"
EXTENSION_PATH="$REPO_ROOT/hyperql-zed"

echo "🚀 Setting up HyperQL Development Environment..."

# 1. Check Prerequisites
echo "🔍 Checking Prerequisites..."

# Check Zig
if command -v zig &> /dev/null; then
    ZIG_VERSION=$(zig version)
    echo "✅ Found Zig: $ZIG_VERSION"
    if [[ ! "$ZIG_VERSION" =~ ^0\.1[56] ]]; then
        echo "   ⚠️  Warning: Tested with Zig 0.15.x. Your version might have breaking changes."
    fi
else
    echo "❌ Zig not found. Please install Zig 0.15.x (https://ziglang.org/download/)."
    exit 1
fi

# Check Rustup
if command -v rustup &> /dev/null; then
    echo "✅ Found rustup."
    if ! rustup target list --installed | grep -qE "wasm32-wasi|wasm32-wasip1"; then
        echo "📦 Installing wasm32-wasip1 target (required for Zed)..."
        rustup target add wasm32-wasip1 || rustup target add wasm32-wasi
    fi
else
    echo "❌ rustup not found. Zed requires rustup to compile extensions."
    echo "   Install it via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

# 2. Build the LSP Server
echo "📦 Building LSP Server (hyperql-lsp)..."
cd "$LSP_PATH"
zig build
cd "$REPO_ROOT"

BIN_PATH="$LSP_PATH/zig-out/bin/hyperql-lsp"
echo "✅ LSP Built: $BIN_PATH"

# 3. Update extension.toml with local grammar path
echo "🔧 Configuring Zed Extension..."
EXTENSION_TOML="$EXTENSION_PATH/extension.toml"

# Update repository path
sed -i "s|repository = \"file://.*\"|repository = \"file://$GRAMMAR_PATH\"|" "$EXTENSION_TOML"

# Ensure local grammar is a git repo (required by Zed for file:// URLs)
if [ ! -d "$GRAMMAR_PATH/.git" ]; then
    echo "📦 Initializing local grammar git repo..."
    cd "$GRAMMAR_PATH"
    git init -q
    git add .
    git commit -m "Local grammar update" -q || true
    cd "$REPO_ROOT"
fi

CURRENT_REV=$(cd "$GRAMMAR_PATH" && git rev-parse HEAD)
sed -i "s|rev = \".*\"|rev = \"$CURRENT_REV\"|" "$EXTENSION_TOML"
echo "✅ Updated extension.toml with local path and revision ($CURRENT_REV)."

echo ""
echo "🎉 Setup Complete!"
echo "⚠️  ACTION REQUIRED: Add the LSP to your PATH:"
echo "   ln -sf $BIN_PATH ~/.cargo/bin/hyperql-lsp"
echo ""
echo "To install in Zed:"
echo "1. Open Command Palette (Cmd/Ctrl + Shift + P)"
echo "2. Run 'Install Dev Extension'"
echo "3. Select: $EXTENSION_PATH"