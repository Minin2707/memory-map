param(
    [string] $Label,
    [int] $BackendPort = 8080,
    [string] $PostgresContainer = "memory-map-postgres",
    [string] $MinioContainer = "memory-map-minio",
    [string] $OutputPath,
    [switch] $Json
)

$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "lib\ResourceSnapshot.psm1"
Import-Module $modulePath -Force

$snapshot = Get-MemoryStoryResourceSnapshot `
    -Label $Label `
    -BackendPort $BackendPort `
    -PostgresContainer $PostgresContainer `
    -MinioContainer $MinioContainer

Write-MemoryStoryResourceSnapshotSummary -Snapshot $snapshot

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    Save-MemoryStoryResourceSnapshotJson -Snapshot $snapshot -OutputPath $OutputPath
    Write-Host ("  json: {0}" -f $OutputPath)
}

if ($Json) {
    $snapshot | ConvertTo-Json -Depth 12
}
