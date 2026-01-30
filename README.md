# HyperQL

HyperQL is a modern, graph-relational query language designed to unify the power of SQL with the flexibility of Graph databases.

## Editions

HyperQL is available in two editions: Community and Enterprise.

| Feature | Community Edition (OSS) | Enterprise Edition |
| --- | --- | --- |
| **License** | Apache 2.0 | Commercial |
| **Syntax Highlighting** | ✅ (Tree-sitter) | ✅ (Enhanced) |
| **Core LSP Features** | ✅ Basic Diagnostics | ✅ Advanced Refactoring |
| **Support** | GitHub Issues | 24/7 SLA Support |
| **Security** | - | ✅ SSO & Audit Logs |

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
