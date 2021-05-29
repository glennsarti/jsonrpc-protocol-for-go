param(
  [Switch]$Clean
)

$PLSVersion = 'gopls/v0.6.11'
$DownloadURL = "https://github.com/golang/tools/archive/refs/tags/$PLSVersion.zip"
$rootNamespace = 'github.com/glennsarti/jsonrpc-protocol-for-go'
$DestRoot = $PSScriptRoot
$ExtractDir = Join-Path -Path $ENV:TEMP -ChildPath 'gopls-revendor'

# Download and extract Golang tools
if ($Clean -or !(Test-Path -Path $ExtractDir)) {
  Write-Host "Downloading GoLang Tools version $PLSVersion ..."
  $TempZIP = Join-Path -Path $ENV:TEMP -ChildPath 'gopls.zip'
  if (Test-Path -Path $TempZIP) { Remove-Item -Path $TempZIP -Force -Confirm:$false | Out-Null }
  Invoke-WebRequest -URI $DownloadURL -UseBasicParsing -OutFile $TempZIP

  Write-Host "Extracting ZIP file ..."
  if (Test-Path -Path $ExtractDir) { Remove-Item -Path $ExtractDir -Force -Confirm:$false -Recurse | Out-Null }
  Expand-Archive -Path $TempZIP -DestinationPath $ExtractDir -Force
}

$rootExtract = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
$srcInternal = Join-Path -Path $rootExtract -ChildPath 'internal'

# Remove any child directories
Get-ChildItem -Path $DestRoot -Directory | ForEach-Object {
  Write-Host "Cleaning $_ ..."
  Remove-Item -Path $_ -Recurse -Force -Confirm:$False
}

$Allowed = @(
  '/jsonrpc2'
  # '/jsonrpc2_v2' # Can't use this yet :-(
  '/lsp/debug/tag'
  '/event'
)

# Copy Directories
Get-ChildItem -Path $srcInternal -Directory -Recurse | ForEach-Object {
  $RelativeName = $_.FullName.Replace($srcInternal, '').Replace('\','/')
  if ($Allowed -contains $RelativeName) {
    Write-Host "Copying $($_.FullName) ..."
    Copy-Item -Path $_.FullName -Destination  (Join-Path $DestRoot $RelativeName) -Recurse -Force | Out-Null

  }
}

# Copy Files
$Allowed |
  Where-Object {
    $ItemPath = Join-Path $srcInternal $_
    Write-Output ((Test-Path -Path $ItemPath) -And (-Not (Get-Item -Path $ItemPath).PSIsContainer))
  } |
  ForEach-Object {
    $ParentDir = Join-Path $DestRoot (Split-Path -Path $_ -Parent)
    if (-Not (Test-Path -Path $ParentDir)) { New-Item -Path $ParentDir -ItemType Directory -Confirm:$false -Force | Out-Null }
    Write-Host "Copying $($_) ..."
    Copy-Item -Path (Join-Path $srcInternal $_) -Destination (Join-Path $DestRoot $_) -Force -Confirm:$false
  }

# Remove test files
Get-ChildItem -Path $DestRoot -Filter '*_test.go' -Recurse |
  ForEach-Object {
    Write-Host "Removing test file $_"
    Remove-Item -Path $_ -Confirm:$false -Force | Out-Null
  }

# Munge Content
Get-ChildItem -Path $DestRoot -Filter '*.go' -Recurse |
  ForEach-Object {
    $FileContent = Get-Content -Path $_ -Raw
    $FileContent = $FileContent.Replace('"golang.org/x/tools/internal/', "`"$rootNamespace/")

    Write-Host "Modifying $($_.FullName)"
    [System.IO.File]::WriteAllText($_.FullName, $FileContent)
}

# Fix for https://github.com/golang/go/issues/46052
# $FilePath = Join-Path $dstInternal 'lsp\protocol\tsprotocol.go'
# $FileContent = Get-Content -Path $FilePath -Raw
# $FileContent = $FileContent.Replace(' bool `json:"resolveProvider,omitempty"`', ' *bool `json:"resolveProvider,omitempty"`')
# Write-Host "Modifying $FilePath"
# [System.IO.File]::WriteAllText($FilePath, $FileContent)

# TODO
# !!! Make all parameters in `ServerCapabilities` optional
