$ErrorActionPreference = "Stop"

$RepoRoot = Get-Location
$GrammarPath = Join-Path $RepoRoot "tree-sitter-hyperql"
$LspPath = Join-Path $RepoRoot "hyperql-lsp"
$ExtensionPath = Join-Path $RepoRoot "hyperql-zed"
$GrammarTmpPath = Join-Path $RepoRoot ".grammar-tmp"
$ExtensionToml = Join-Path $ExtensionPath "extension.toml"

Write-Host "🚀 Setting up HyperQL Development Environment for Windows..."

# 1. Check Prerequisites
Write-Host "🔍 Checking Prerequisites..."

if (Get-Command zig -ErrorAction SilentlyContinue) {
    $ZigVersion = zig version
    Write-Host "✅ Found Zig: $ZigVersion"
} else {
    Write-Host "❌ Zig not found. Please install Zig (https://ziglang.org/download/)."
    exit 1
}

if (Get-Command rustup -ErrorAction SilentlyContinue) {
    Write-Host "✅ Found rustup."
    $Targets = rustup target list --installed
    if ($Targets -notmatch "wasm32-wasip1") {
        Write-Host "📦 Installing wasm32-wasip1 target..."
        rustup target add wasm32-wasip1
    }
} else {
    Write-Host "❌ rustup not found. Install it via https://rustup.rs/"
    exit 1
}

# 2. Build LSP
Write-Host "📦 Building LSP Server..."
Push-Location $LspPath
zig build
Pop-Location

$BinPath = Join-Path $LspPath "zig-out\bin\hyperql-lsp.exe"
if (Test-Path $BinPath) {
    Write-Host "✅ LSP Built: $BinPath"
} else {
    # Fallback check for linux-style binary name just in case
    $BinPath = Join-Path $LspPath "zig-out\bin\hyperql-lsp" 
    if (Test-Path $BinPath) {
         Write-Host "✅ LSP Built: $BinPath"
    } else {
         Write-Host "❌ LSP Build Failed."
         exit 1
    }
}

# 3. Prepare Grammar
Write-Host "🔧 Configuring Zed Extension..."
Write-Host "📦 Preparing temporary grammar repository at $GrammarTmpPath..."

if (Test-Path $GrammarTmpPath) {
    Remove-Item -Recurse -Force $GrammarTmpPath
}
New-Item -ItemType Directory -Force -Path $GrammarTmpPath | Out-Null
Copy-Item -Recurse "$GrammarPath\*" $GrammarTmpPath

git -C $GrammarTmpPath init -q
git -C $GrammarTmpPath add .
git -C $GrammarTmpPath commit -m "Dev build $(Get-Date)" -q

# 4. Update extension.toml
# Need URI format: file:///C:/Users/...
# Convert backslashes to forward slashes for URI
$GrammarTmpUriPath = $GrammarTmpPath.Path.Replace("\", "/")
$GrammarTmpUri = "file:///$GrammarTmpUriPath"

$Content = Get-Content $ExtensionToml -Raw
# Replace repository line
$Content = $Content -replace 'repository = ".*?"', "repository = \"$GrammarTmpUri\""

$CurrentRev = git -C $GrammarTmpPath rev-parse HEAD
# Replace rev line
$Content = $Content -replace 'rev = ".*?"', "rev = \"$CurrentRev\""

Set-Content -Path $ExtensionToml -Value $Content
Write-Host "✅ Updated extension.toml."

Write-Host ""
Write-Host "🎉 Setup Complete!"
Write-Host "⚠️  ACTION REQUIRED: Add the LSP to your PATH."
Write-Host "   You can copy '$BinPath' to a folder in your PATH (e.g. C:\Users\<You>\.cargo\bin)."
Write-Host "   Example command: Copy-Item '$BinPath' -Destination ~\.cargo\bin"
