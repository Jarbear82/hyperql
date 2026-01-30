#!/bin/bash
set -e

# Detect the absolute path of the repo
REPO_ROOT=$(pwd)
GRAMMAR_PATH="$REPO_ROOT/tree-sitter-hyperql"
LSP_PATH="$REPO_ROOT/hyperql-lsp"
EXTENSION_PATH="$REPO_ROOT/hyperql-zed"

echo "🚀 Setting up HyperQL Development Environment..."

# 1. Build the LSP Server
if command -v zig &> /dev/null; then
    echo "📦 Building LSP Server (hyperql-lsp)..."
    cd "$LSP_PATH"
    zig build
    cd "$REPO_ROOT"
    
    BIN_PATH="$LSP_PATH/zig-out/bin/hyperql-lsp"
    echo "✅ LSP Built: $BIN_PATH"
    
    # Suggest adding to PATH
    echo ""
    echo "⚠️  ACTION REQUIRED: Add the LSP to your PATH:"
    echo "   ln -sf $BIN_PATH ~/.cargo/bin/hyperql-lsp"
    echo "   (Or your preferred bin directory)"
    echo ""
else
    echo "❌ Zig not found. Skipping LSP build."
    echo "   Please install Zig 0.15+ to build 'hyperql-lsp'."
fi

# 2. Update extension.toml with local grammar path
echo "🔧 Configuring Zed Extension..."
EXTENSION_TOML="$EXTENSION_PATH/extension.toml"

# We use sed to replace the repository line with the current absolute path
# Use a different delimiter (|) to avoid conflict with / in paths
sed -i "s|repository = \"file://.*\"|repository = \"file://$GRAMMAR_PATH\"|" "$EXTENSION_TOML"

# Also need to ensure the revision matches the local checkout
# We get the current HEAD of the tree-sitter-hyperql dir
if [ -d "$GRAMMAR_PATH/.git" ]; then
    cd "$GRAMMAR_PATH"
    CURRENT_REV=$(git rev-parse HEAD)
    cd "$REPO_ROOT"
    sed -i "s|rev = \".*\"|rev = \"$CURRENT_REV\"|" "$EXTENSION_TOML"
    echo "✅ Updated extension.toml with local path and revision ($CURRENT_REV)."
else
    echo "⚠️  $GRAMMAR_PATH is not a git repository. Zed requires the grammar to be a git repo."
    echo "   Running 'git init' in tree-sitter-hyperql to fix this..."
    cd "$GRAMMAR_PATH"
    git init
    git add .
    git commit -m "Initial local commit for Zed" || true
    CURRENT_REV=$(git rev-parse HEAD)
    cd "$REPO_ROOT"
    sed -i "s|rev = \".*\"|rev = \"$CURRENT_REV\"|" "$EXTENSION_TOML"
    echo "✅ Initialized local grammar repo and updated extension.toml."
fi

echo ""
echo "🎉 Setup Complete!"
echo "To install the extension in Zed:"
echo "1. Open Zed"
echo "2. Press Cmd/Ctrl + Shift + P"
echo "3. Type 'Install Dev Extension'"
echo "4. Select the directory: $EXTENSION_PATH"
