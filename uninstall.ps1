$ErrorActionPreference = "Stop"
$RepoRoot = Get-Location

Write-Host "🗑️  Uninstalling HyperQL Development Environment..."

# 1. Clean artifacts
$PathsToRemove = @(
    ".grammar-tmp",
    "hyperql-lsp\zig-out",
    "hyperql-lsp\zig-cache",
    "hyperql-zed\target",
    "hyperql-zed\extension.wasm"
)

foreach ($RelPath in $PathsToRemove) {
    $FullPath = Join-Path $RepoRoot $RelPath
    if (Test-Path $FullPath) {
        Remove-Item -Recurse -Force $FullPath
        Write-Host "✅ Removed $RelPath"
    }
}

# 2. Restore extension.toml
$ExtensionToml = Join-Path $RepoRoot "hyperql-zed\extension.toml"
if (Test-Path $ExtensionToml) {
    git checkout $ExtensionToml
    Write-Host "✅ Restored $ExtensionToml"
}

Write-Host ""
Write-Host "🎉 Clean up complete!"
Write-Host "⚠️  Remove the extension from Zed manually."
