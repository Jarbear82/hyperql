# HyperQL

HyperQL is a modern, graph-relational query language designed to unify the power of SQL with the flexibility of Graph databases.

## Editions

HyperQL is currently available as a **Community Edition**.

| Feature | Community Edition (OSS) |
| --- | --- |
| **License** | Apache 2.0 |
| **Syntax Highlighting** | ✅ (Tree-sitter) |
| **Core LSP Features** | ✅ Basic Diagnostics |
| **Support** | GitHub Issues |
| **Security** | - |

## Getting Started

### Zed Editor
1. Open Zed.
2. Go to Extensions.
3. Search for "HyperQL".
4. Install.

### Building from Source

```bash
# Clone the repository
git clone https://github.com/jarbear82/hyperql.git
cd hyperql

# Build the Tree-sitter parser
cd tree-sitter-hyperql
npm install
npm run build
```

## Contributing

We welcome contributions to the Community Edition! Please read our [Contributing Guidelines](CONTRIBUTING.md) for details.

**Note:** All community contributions are licensed under Apache 2.0.

## Prerequisites

To build and run the HyperQL tools, you need:

- **Zig 0.15.x**: Required to build the LSP server. [Download Zig](https://ziglang.org/download/).
- **Rust & rustup**: Required for the Zed extension. [Install Rust](https://rustup.rs/).
- **Node.js & npm**: Required to build the Tree-sitter grammar.

## Development Setup (Installing as Dev Extension)

To install this repo as a local Zed extension:

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Jarbear82/hyperql.git
    cd hyperql
    ```

2.  **Run the Setup Script**:
    This script builds the LSP and configures the extension to use your local paths.
    ```bash
    ./setup.sh
    ```

3.  **Link the LSP**:
    Follow the instructions from the script to add `hyperql-lsp` to your PATH.
    ```bash
    ln -sf $(pwd)/hyperql-lsp/zig-out/bin/hyperql-lsp ~/.cargo/bin/hyperql-lsp
    ```

4.  **Install in Zed**:
    *   Open Zed.
    *   Open Command Palette (`Ctrl/Cmd + Shift + P`).
    *   Run `extensions: install dev extension`.
    *   Select the `hyperql-zed` folder.

