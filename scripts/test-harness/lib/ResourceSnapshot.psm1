$ErrorActionPreference = "Stop"

function ConvertTo-MemoryStoryInvariantDouble {
    param(
        [AllowNull()]
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $normalized = $Value.Trim().TrimEnd("%").Replace(",", ".")
    $result = 0.0
    if ([double]::TryParse($normalized, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $result)) {
        return $result
    }

    return $null
}

function ConvertTo-MemoryStoryByteCount {
    param(
        [AllowNull()]
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    if ($Value.Trim() -notmatch '^([0-9]+(?:[\.,][0-9]+)?)\s*([kmgtpe]?i?b)$') {
        return $null
    }

    $number = ConvertTo-MemoryStoryInvariantDouble -Value $Matches[1]
    if ($null -eq $number) {
        return $null
    }

    $unit = $Matches[2]
    $multipliers = @{
        "b" = 1L
        "kb" = 1000L
        "mb" = 1000000L
        "gb" = 1000000000L
        "tb" = 1000000000000L
        "pb" = 1000000000000000L
        "kib" = 1024L
        "mib" = 1048576L
        "gib" = 1073741824L
        "tib" = 1099511627776L
        "pib" = 1125899906842624L
    }

    if (-not $multipliers.ContainsKey($unit.ToLowerInvariant())) {
        return $null
    }

    return [int64] [math]::Round($number * $multipliers[$unit.ToLowerInvariant()])
}

function ConvertFrom-MemoryStoryDockerMemoryUsage {
    param(
        [AllowNull()]
        [string] $Value
    )

    $result = [ordered] @{
        usageBytes = $null
        limitBytes = $null
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject] $result
    }

    $parts = $Value -split '\s*/\s*', 2
    if ($parts.Count -ge 1) {
        $result.usageBytes = ConvertTo-MemoryStoryByteCount -Value $parts[0]
    }
    if ($parts.Count -eq 2) {
        $result.limitBytes = ConvertTo-MemoryStoryByteCount -Value $parts[1]
    }

    return [pscustomobject] $result
}

function Test-MemoryStoryDockerAvailable {
    return $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
}

function Invoke-MemoryStoryDocker {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    if (-not (Test-MemoryStoryDockerAvailable)) {
        return [pscustomobject] @{
            success = $false
            output = @()
            status = "docker command is not available"
        }
    }

    $output = & docker @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject] @{
            success = $false
            output = @()
            status = "docker command failed or daemon/container is unavailable"
        }
    }

    return [pscustomobject] @{
        success = $true
        output = @($output)
        status = "ok"
    }
}

function Get-MemoryStoryBackendProcessSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [int] $BackendPort
    )

    try {
        $connection = Get-NetTCPConnection -LocalPort $BackendPort -State Listen -ErrorAction Stop |
            Select-Object -First 1
    } catch {
        return [pscustomobject] @{
            available = $false
            warning = "backend listener could not be resolved"
            pid = $null
            processName = $null
            cumulativeCpuSeconds = $null
            workingSetBytes = $null
            privateMemoryBytes = $null
            handleCount = $null
        }
    }

    if ($null -eq $connection) {
        return [pscustomobject] @{
            available = $false
            warning = "no process is listening on the configured backend port"
            pid = $null
            processName = $null
            cumulativeCpuSeconds = $null
            workingSetBytes = $null
            privateMemoryBytes = $null
            handleCount = $null
        }
    }

    try {
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction Stop
    } catch {
        return [pscustomobject] @{
            available = $false
            warning = "backend process disappeared after port resolution"
            pid = $connection.OwningProcess
            processName = $null
            cumulativeCpuSeconds = $null
            workingSetBytes = $null
            privateMemoryBytes = $null
            handleCount = $null
        }
    }

    return [pscustomobject] @{
        available = $true
        warning = $null
        pid = $process.Id
        processName = $process.ProcessName
        cumulativeCpuSeconds = $process.CPU
        workingSetBytes = $process.WorkingSet64
        privateMemoryBytes = $process.PrivateMemorySize64
        handleCount = $process.HandleCount
    }
}

function Get-MemoryStoryDockerStatsSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ContainerName
    )

    $stats = Invoke-MemoryStoryDocker -Arguments @("stats", $ContainerName, "--no-stream", "--format", "{{json .}}")
    if (-not $stats.success -or $stats.output.Count -eq 0) {
        return [pscustomobject] @{
            available = $false
            status = $stats.status
            cpuPercent = $null
            memoryUsageBytes = $null
            memoryLimitBytes = $null
            memoryPercent = $null
            pids = $null
        }
    }

    try {
        $json = $stats.output[0] | ConvertFrom-Json
    } catch {
        return [pscustomobject] @{
            available = $false
            status = "docker stats output could not be parsed"
            cpuPercent = $null
            memoryUsageBytes = $null
            memoryLimitBytes = $null
            memoryPercent = $null
            pids = $null
        }
    }

    $memory = ConvertFrom-MemoryStoryDockerMemoryUsage $json.MemUsage
    $pids = $null
    if ($null -ne $json.PIDs) {
        $parsedPids = 0
        if ([int]::TryParse([string] $json.PIDs, [ref] $parsedPids)) {
            $pids = $parsedPids
        }
    }

    return [pscustomobject] @{
        available = $true
        status = "ok"
        cpuPercent = ConvertTo-MemoryStoryInvariantDouble -Value $json.CPUPerc
        memoryUsageBytes = $memory.usageBytes
        memoryLimitBytes = $memory.limitBytes
        memoryPercent = ConvertTo-MemoryStoryInvariantDouble -Value $json.MemPerc
        pids = $pids
    }
}

function Get-MemoryStoryPostgresConnectionsSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ContainerName
    )

    $query = "select state, count(*) from pg_stat_activity where datname = current_database() group by state order by state;"
    $shellCommand = "psql -X --no-align --tuples-only --field-separator='|' -U " + '$POSTGRES_USER' + " -d " + '$POSTGRES_DB' + " -c '$query'"
    $result = Invoke-MemoryStoryDocker -Arguments @("exec", $ContainerName, "sh", "-lc", $shellCommand)
    if (-not $result.success) {
        return [pscustomobject] @{
            available = $false
            status = $result.status
            counts = [pscustomobject] @{}
        }
    }

    $counts = [ordered] @{}
    $lines = @($result.output) -join "`n"
    foreach ($line in ($lines -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = ([string] $line) -split "\|", 2
        if ($parts.Count -ne 2) {
            continue
        }

        $state = $parts[0].Trim()
        $count = 0
        if (-not [int]::TryParse($parts[1].Trim(), [ref] $count)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($state)) {
            $state = "unknown"
        }
        $counts[$state] = $count
    }

    return [pscustomobject] @{
        available = $true
        status = "ok"
        counts = [pscustomobject] $counts
    }
}

function Get-MemoryStoryPostgresSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ContainerName
    )

    $stats = Get-MemoryStoryDockerStatsSnapshot -ContainerName $ContainerName
    $connections = Get-MemoryStoryPostgresConnectionsSnapshot -ContainerName $ContainerName
    $available = $stats.available -or $connections.available
    $status = "unavailable"
    if ($stats.available -and $connections.available) {
        $status = "ok"
    } elseif ($stats.available) {
        $status = "stats available; connection query unavailable"
    } elseif ($connections.available) {
        $status = "connection query available; stats unavailable"
    }

    return [pscustomobject] @{
        available = $available
        status = $status
        cpuPercent = $stats.cpuPercent
        memoryUsageBytes = $stats.memoryUsageBytes
        memoryLimitBytes = $stats.memoryLimitBytes
        memoryPercent = $stats.memoryPercent
        pids = $stats.pids
        connections = $connections.counts
        connectionQueryAvailable = $connections.available
        connectionQueryStatus = $connections.status
    }
}

function Get-MemoryStoryResourceSnapshot {
    param(
        [string] $Label,
        [int] $BackendPort = 8080,
        [string] $PostgresContainer = "memory-map-postgres",
        [string] $MinioContainer = "memory-map-minio"
    )

    return [pscustomobject] @{
        timestampUtc = [DateTimeOffset]::UtcNow.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
        label = $Label
        backendPort = $BackendPort
        containers = [pscustomobject] @{
            postgres = $PostgresContainer
            minio = $MinioContainer
        }
        backend = Get-MemoryStoryBackendProcessSnapshot -BackendPort $BackendPort
        postgres = Get-MemoryStoryPostgresSnapshot -ContainerName $PostgresContainer
        minio = Get-MemoryStoryDockerStatsSnapshot -ContainerName $MinioContainer
    }
}

function Write-MemoryStoryResourceSnapshotSummary {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Snapshot
    )

    Write-Host "Memory Story resource snapshot"
    Write-Host ("  timestampUtc: {0}" -f $Snapshot.timestampUtc)
    if (-not [string]::IsNullOrWhiteSpace($Snapshot.label)) {
        Write-Host ("  label: {0}" -f $Snapshot.label)
    }

    if ($Snapshot.backend.available) {
        Write-Host ("  backend:{0} pid={1} process={2} workingSet={3} privateMemory={4} handles={5}" -f $Snapshot.backendPort, $Snapshot.backend.pid, $Snapshot.backend.processName, $Snapshot.backend.workingSetBytes, $Snapshot.backend.privateMemoryBytes, $Snapshot.backend.handleCount)
    } else {
        Write-Warning ("backend:{0} unavailable ({1})" -f $Snapshot.backendPort, $Snapshot.backend.warning)
    }

    if ($Snapshot.postgres.available) {
        $connectionJson = $Snapshot.postgres.connections | ConvertTo-Json -Compress
        Write-Host ("  postgres:{0} cpu={1}% memory={2}/{3} memoryPercent={4}% pids={5} connections={6}" -f $Snapshot.containers.postgres, $Snapshot.postgres.cpuPercent, $Snapshot.postgres.memoryUsageBytes, $Snapshot.postgres.memoryLimitBytes, $Snapshot.postgres.memoryPercent, $Snapshot.postgres.pids, $connectionJson)
    } else {
        Write-Warning ("postgres:{0} unavailable" -f $Snapshot.containers.postgres)
    }

    if ($Snapshot.minio.available) {
        Write-Host ("  minio:{0} cpu={1}% memory={2}/{3} memoryPercent={4}% pids={5}" -f $Snapshot.containers.minio, $Snapshot.minio.cpuPercent, $Snapshot.minio.memoryUsageBytes, $Snapshot.minio.memoryLimitBytes, $Snapshot.minio.memoryPercent, $Snapshot.minio.pids)
    } else {
        Write-Warning ("minio:{0} unavailable" -f $Snapshot.containers.minio)
    }
}

function Save-MemoryStoryResourceSnapshotJson {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Snapshot,
        [Parameter(Mandatory = $true)]
        [string] $OutputPath
    )

    $resolvedParent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($resolvedParent) -and -not (Test-Path -LiteralPath $resolvedParent)) {
        New-Item -ItemType Directory -Path $resolvedParent | Out-Null
    }

    if (Test-Path -LiteralPath $OutputPath) {
        throw "OutputPath already exists: $OutputPath"
    }

    $Snapshot |
        ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $OutputPath -Encoding utf8
}

Export-ModuleMember -Function Get-MemoryStoryResourceSnapshot, Write-MemoryStoryResourceSnapshotSummary, Save-MemoryStoryResourceSnapshotJson
