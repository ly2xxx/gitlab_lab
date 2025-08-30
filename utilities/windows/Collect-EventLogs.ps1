#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Event Log Collection Script for System Freeze Troubleshooting
.DESCRIPTION
    Comprehensive PowerShell script to collect and analyze Windows event logs related to 
    system freezes, crashes, and hardware failures. Designed for troubleshooting HP ZBook
    and other Windows 11 systems experiencing frequent freezing issues.
.PARAMETER OutputPath
    Custom output directory for collected logs and reports (default: current directory)
.PARAMETER TimeRange
    Number of hours to look back for events (default: 48 hours)
.PARAMETER IncludeMinidumps
    Include analysis of minidump files from C:\Windows\Minidump
.PARAMETER Format
    Output format: Text, CSV, HTML, or All (default: All)
.PARAMETER Simulate
    Run in simulation mode - show what would be collected without generating files
.PARAMETER EventIDs
    Specific Event IDs to focus on (comma-separated, e.g., "41,1001,6008")
.PARAMETER Verbose
    Enable detailed progress output
.EXAMPLE
    .\Collect-EventLogs.ps1
    Collect logs from last 48 hours with default settings
.EXAMPLE
    .\Collect-EventLogs.ps1 -TimeRange 72 -Format HTML -OutputPath "C:\Temp\Logs"
    Collect 72 hours of logs in HTML format to specific directory
.EXAMPLE
    .\Collect-EventLogs.ps1 -EventIDs "41,1001,6008" -IncludeMinidumps -Verbose
    Focus on specific freeze-related events with minidump analysis
.EXAMPLE
    .\Collect-EventLogs.ps1 -Simulate
    Preview what would be collected without generating files
#>

param(
    [string]$OutputPath = (Get-Location).Path,
    
    [int]$TimeRange = 48,
    
    [switch]$IncludeMinidumps,
    
    [ValidateSet("Text", "CSV", "HTML", "All")]
    [string]$Format = "All",
    
    [switch]$Simulate,
    
    [string]$EventIDs = "",
    
    [switch]$Verbose
)

# Global variables
$Script:CollectionStartTime = Get-Date
$Script:TotalEventsCollected = 0
$Script:LogFile = ""
$Script:OutputDirectory = ""
$Script:EventIdFilter = @()

# Event statistics for summary generation
$Script:EventStatistics = @{
    SystemEvents = 0
    ApplicationEvents = 0
    KernelPowerEvents = 0
    BugCheckEvents = 0
    HardwareEvents = 0
    ReliabilityEvents = 0
    MinidumpFiles = 0
    CriticalCount = 0
    ErrorCount = 0
    WarningCount = 0
}

# Common freeze-related Event IDs
$Script:CriticalEventIDs = @{
    41 = "Kernel-Power - Unexpected shutdown/freeze"
    1001 = "BugCheck - System crash (BSOD)"
    6008 = "EventLog - Unexpected system shutdown"
    137 = "NTFS - Delayed write failed"
    153 = "Disk - IO error"
    7031 = "Service Control Manager - Service crashed"
    1000 = "Application Error - Application crash"
    1002 = "Application Hang - Application stopped responding"
}

function Initialize-Environment {
    <#
    .SYNOPSIS
        Initialize the collection environment and validate parameters
    #>
    
    # Create output directory with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:OutputDirectory = Join-Path $OutputPath "EventLogs_$timestamp"
    
    if (-not $Simulate) {
        try {
            New-Item -Path $Script:OutputDirectory -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $Script:OutputDirectory "Raw_Logs") -ItemType Directory -Force | Out-Null
        } catch {
            Write-Error "Failed to create output directory: $($_.Exception.Message)"
            exit 1
        }
    }
    
    # Initialize log file
    $Script:LogFile = Join-Path $Script:OutputDirectory "Collection_Log.txt"
    
    # Parse Event ID filter if provided
    if ($EventIDs) {
        $Script:EventIdFilter = $EventIDs.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    }
    
    Write-Log "Event Log Collection Script Started" "INFO"
    Write-Log "Output Directory: $Script:OutputDirectory" "INFO"
    Write-Log "Time Range: $TimeRange hours" "INFO"
    Write-Log "Format: $Format" "INFO"
    Write-Log "Include Minidumps: $IncludeMinidumps" "INFO"
    Write-Log "Simulation Mode: $Simulate" "INFO"
    
    if ($Script:EventIdFilter.Count -gt 0) {
        Write-Log "Event ID Filter: $($Script:EventIdFilter -join ', ')" "INFO"
    }
}

function Write-Log {
    param(
        [string]$Message, 
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    
    if ($Verbose -or $Level -in @("ERROR", "WARN", "SUCCESS")) {
        Write-Host $logEntry -ForegroundColor $color
    }
    
    # File output (only if not in simulation mode)
    if (-not $Simulate -and $Script:LogFile) {
        Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
}

function Write-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = -1
    )
    
    if ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    } else {
        Write-Progress -Activity $Activity -Status $Status
    }
    
    # Removed Write-Log call to prevent infinite recursion
}

function Initialize-EventFile {
    <#
    .SYNOPSIS
        Initialize a CSV file with headers for streaming event collection
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [Parameter(Mandatory=$true)]
        [string[]]$Headers
    )
    
    if ($Simulate) {
        return
    }
    
    $csvPath = Join-Path $Script:OutputDirectory "$FileName.csv"
    
    try {
        # Create CSV header row
        $headerLine = ($Headers | ForEach-Object { "`"$_`"" }) -join ","
        $headerLine | Out-File -FilePath $csvPath -Encoding UTF8
        Write-Log "Initialized streaming file: $csvPath" "INFO"
    } catch {
        Write-Log "Error initializing file $csvPath : $($_.Exception.Message)" "ERROR"
    }
}

function Write-EventToFile {
    <#
    .SYNOPSIS
        Write a single event object to a CSV file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$EventObject
    )
    
    if ($Simulate) {
        return
    }
    
    $csvPath = Join-Path $Script:OutputDirectory "$FileName.csv"
    
    try {
        # Convert object properties to CSV row
        $properties = $EventObject.PSObject.Properties.Name
        $values = foreach ($prop in $properties) {
            $value = $EventObject.$prop
            if ($value -eq $null) { $value = "" }
            "`"$($value.ToString().Replace('"', '""'))`""
        }
        $csvLine = $values -join ","
        
        # Append to file
        $csvLine | Out-File -FilePath $csvPath -Encoding UTF8 -Append
    } catch {
        Write-Log "Error writing event to file $csvPath : $($_.Exception.Message)" "ERROR"
    }
}

function Update-EventStatistics {
    <#
    .SYNOPSIS
        Update global event statistics for summary generation
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$EventType,
        [string]$Level = "Info"
    )
    
    $Script:EventStatistics[$EventType]++
    $Script:TotalEventsCollected++
    
    # Update level counters
    switch ($Level) {
        "Critical" { $Script:EventStatistics.CriticalCount++ }
        "Error" { $Script:EventStatistics.ErrorCount++ }
        "Warning" { $Script:EventStatistics.WarningCount++ }
    }
}

function Get-CriticalSystemEvents {
    <#
    .SYNOPSIS
        Collect critical and error events from System log using streaming or in-memory collection
    #>
    param(
        [string]$FileName = ""
    )
    
    Write-Progress -Activity "Collecting System Events" -Status "Collecting System log critical/error events"
    
    # Initialize streaming file with headers (only for CSV format)
    $headers = @("TimeCreated", "Id", "LevelDisplayName", "LogName", "ProviderName", "Message", "Description", "MachineName", "UserId", "ProcessId", "ThreadId")
    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
        Initialize-EventFile -FileName $FileName -Headers $headers
    }
    
    # Array to collect events for non-CSV formats
    $collectedEvents = @()
    
    $startTime = (Get-Date).AddHours(-$TimeRange)
    $eventCount = 0
    
    try {
        $filterXml = @"
<QueryList>
    <Query Id="0" Path="System">
        <Select Path="System">
            *[System[Level=1 or Level=2] and System[TimeCreated[@SystemTime&gt;='$($startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"))']]]
        </Select>
    </Query>
</QueryList>
"@
        
        # Process events in batches to avoid memory overflow
        $batchSize = 500
        $moreEvents = $true
        $oldestEventTime = $null
        
        while ($moreEvents) {
            try {
                # Get batch of events
                $currentFilterXml = $filterXml
                if ($oldestEventTime) {
                    # Adjust filter to get events older than the last processed event
                    $currentFilterXml = @"
<QueryList>
    <Query Id="0" Path="System">
        <Select Path="System">
            *[System[Level=1 or Level=2] and System[TimeCreated[@SystemTime&gt;='$($startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"))'] and System[TimeCreated[@SystemTime&lt;'$($oldestEventTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"))']]]]
        </Select>
    </Query>
</QueryList>
"@
                }
                
                $eventBatch = Get-WinEvent -FilterXml $currentFilterXml -MaxEvents $batchSize -ErrorAction Stop
                
                if ($eventBatch.Count -eq 0) {
                    $moreEvents = $false
                    break
                }
                
                # Process the batch
                foreach ($event in $eventBatch) {
                    # Apply Event ID filter if specified
                    if ($Script:EventIdFilter.Count -gt 0 -and $event.Id -notin $Script:EventIdFilter) {
                        continue
                    }
                    
                    $eventObject = [PSCustomObject]@{
                        TimeCreated = $event.TimeCreated
                        Id = $event.Id
                        LevelDisplayName = $event.LevelDisplayName
                        LogName = $event.LogName
                        ProviderName = $event.ProviderName
                        Message = $event.Message -replace "`r`n", " " -replace "`n", " "
                        Description = if ($Script:CriticalEventIDs.ContainsKey($event.Id)) { 
                            $Script:CriticalEventIDs[$event.Id] 
                        } else { 
                            "System event" 
                        }
                        MachineName = $event.MachineName
                        UserId = $event.UserId
                        ProcessId = $event.ProcessId
                        ThreadId = $event.ThreadId
                    }
                    
                    # Stream event to file immediately (only for CSV format)
                    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
                        Write-EventToFile -FileName $FileName -EventObject $eventObject
                    } else {
                        # Collect in memory for other formats
                        $collectedEvents += $eventObject
                    }
                    
                    # Update statistics
                    Update-EventStatistics -EventType "SystemEvents" -Level $event.LevelDisplayName
                    $eventCount++
                    
                    # Track oldest event for next batch
                    $oldestEventTime = $event.TimeCreated
                }
                
                # Update progress
                Write-Progress -Activity "Collecting System Events" -Status "Processed $eventCount events (batch of $($eventBatch.Count))"
                
                # Check if we got a full batch (if not, we're done)
                if ($eventBatch.Count -lt $batchSize) {
                    $moreEvents = $false
                }
                
            } catch {
                if ($_.Exception.Message -like "*No events were found*") {
                    $moreEvents = $false
                } else {
                    throw
                }
            }
        }
        
        Write-Log "Collected $eventCount system events using batch processing" "SUCCESS"
        
    } catch {
        if ($_.Exception.Message -notlike "*No events were found*") {
            Write-Log "Error collecting system events: $($_.Exception.Message)" "ERROR"
        } else {
            Write-Log "No system events found in the specified time range" "INFO"
        }
    }
    
    if ($FileName) {
        return $eventCount
    } else {
        return $collectedEvents
    }
}

function Get-CriticalApplicationEvents {
    <#
    .SYNOPSIS
        Collect critical and error events from Application log using streaming or in-memory collection
    #>
    param(
        [string]$FileName = ""
    )
    
    Write-Progress -Activity "Collecting Application Events" -Status "Collecting Application log critical/error events"
    
    # Initialize streaming file with headers (only for CSV format)
    $headers = @("TimeCreated", "Id", "LevelDisplayName", "LogName", "ProviderName", "Message", "Description", "MachineName", "UserId", "ProcessId", "ThreadId")
    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
        Initialize-EventFile -FileName $FileName -Headers $headers
    }
    
    # Array to collect events for non-CSV formats
    $collectedEvents = @()
    
    $startTime = (Get-Date).AddHours(-$TimeRange)
    $eventCount = 0
    
    try {
        $filterXml = @"
<QueryList>
    <Query Id="0" Path="Application">
        <Select Path="Application">
            *[System[Level=1 or Level=2] and System[TimeCreated[@SystemTime&gt;='$($startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"))']]]
        </Select>
    </Query>
</QueryList>
"@
        
        # Process events in batches to avoid memory overflow
        $batchSize = 500
        $moreEvents = $true
        $oldestEventTime = $null
        
        while ($moreEvents) {
            try {
                # Get batch of events
                $currentFilterXml = $filterXml
                if ($oldestEventTime) {
                    # Adjust filter to get events older than the last processed event
                    $currentFilterXml = @"
<QueryList>
    <Query Id="0" Path="Application">
        <Select Path="Application">
            *[System[Level=1 or Level=2] and System[TimeCreated[@SystemTime&gt;='$($startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"))'] and System[TimeCreated[@SystemTime&lt;'$($oldestEventTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"))']]]]
        </Select>
    </Query>
</QueryList>
"@
                }
                
                $eventBatch = Get-WinEvent -FilterXml $currentFilterXml -MaxEvents $batchSize -ErrorAction Stop
                
                if ($eventBatch.Count -eq 0) {
                    $moreEvents = $false
                    break
                }
                
                # Process the batch
                foreach ($event in $eventBatch) {
                    # Apply Event ID filter if specified
                    if ($Script:EventIdFilter.Count -gt 0 -and $event.Id -notin $Script:EventIdFilter) {
                        continue
                    }
                    
                    $eventObject = [PSCustomObject]@{
                        TimeCreated = $event.TimeCreated
                        Id = $event.Id
                        LevelDisplayName = $event.LevelDisplayName
                        LogName = $event.LogName
                        ProviderName = $event.ProviderName
                        Message = $event.Message -replace "`r`n", " " -replace "`n", " "
                        Description = if ($Script:CriticalEventIDs.ContainsKey($event.Id)) { 
                            $Script:CriticalEventIDs[$event.Id] 
                        } else { 
                            "Application event" 
                        }
                        MachineName = $event.MachineName
                        UserId = $event.UserId
                        ProcessId = $event.ProcessId
                        ThreadId = $event.ThreadId
                    }
                    
                    # Stream event to file immediately (only for CSV format)
                    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
                        Write-EventToFile -FileName $FileName -EventObject $eventObject
                    } else {
                        # Collect in memory for other formats
                        $collectedEvents += $eventObject
                    }
                    
                    # Update statistics
                    Update-EventStatistics -EventType "ApplicationEvents" -Level $event.LevelDisplayName
                    $eventCount++
                    
                    # Track oldest event for next batch
                    $oldestEventTime = $event.TimeCreated
                }
                
                # Update progress
                Write-Progress -Activity "Collecting Application Events" -Status "Processed $eventCount events (batch of $($eventBatch.Count))"
                
                # Check if we got a full batch (if not, we're done)
                if ($eventBatch.Count -lt $batchSize) {
                    $moreEvents = $false
                }
                
            } catch {
                if ($_.Exception.Message -like "*No events were found*") {
                    $moreEvents = $false
                } else {
                    throw
                }
            }
        }
        
        Write-Log "Collected $eventCount application events using batch processing" "SUCCESS"
        
    } catch {
        if ($_.Exception.Message -notlike "*No events were found*") {
            Write-Log "Error collecting application events: $($_.Exception.Message)" "ERROR"
        } else {
            Write-Log "No application events found in the specified time range" "INFO"
        }
    }
    
    if ($FileName) {
        return $eventCount
    } else {
        return $collectedEvents
    }
    
    return $eventCount
}

function Get-KernelPowerEvents {
    <#
    .SYNOPSIS
        Collect Kernel-Power events (Event ID 41) indicating unexpected shutdowns
    #>
    param(
        [string]$FileName = ""
    )
    
    Write-Progress -Activity "Collecting Kernel-Power Events" -Status "Collecting unexpected shutdown events (Event ID 41)"
    
    # Initialize streaming file with headers (only for CSV format)
    $headers = @("TimeCreated", "Id", "LevelDisplayName", "LogName", "ProviderName", "Message", "Description", "MachineName", "BugCheckCode", "BugCheckParameter1", "BugCheckParameter2", "BugCheckParameter3", "BugCheckParameter4")
    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
        Initialize-EventFile -FileName $FileName -Headers $headers
    }
    
    # Array to collect events for non-CSV formats
    $collectedEvents = @()
    
    $startTime = (Get-Date).AddHours(-$TimeRange)
    $eventCount = 0
    
    try {
        $kernelPowerEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ID = 41
            StartTime = $startTime
        } -ErrorAction Stop
        
        foreach ($event in $kernelPowerEvents) {
            $eventObject = [PSCustomObject]@{
                TimeCreated = $event.TimeCreated
                Id = $event.Id
                LevelDisplayName = $event.LevelDisplayName
                LogName = $event.LogName
                ProviderName = $event.ProviderName
                Message = $event.Message -replace "`r`n", " " -replace "`n", " "
                Description = "Kernel-Power - System reboot without clean shutdown (FREEZE/CRASH)"
                MachineName = $event.MachineName
                BugCheckCode = "N/A"
                BugCheckParameter1 = "N/A"
                BugCheckParameter2 = "N/A"
                BugCheckParameter3 = "N/A"
                BugCheckParameter4 = "N/A"
            }
            
            # Stream event to file immediately (only for CSV format)
            if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
                Write-EventToFile -FileName $FileName -EventObject $eventObject
            } else {
                # Collect in memory for other formats
                $collectedEvents += $eventObject
            }
            
            # Update statistics
            Update-EventStatistics -EventType "KernelPowerEvents" -Level $event.LevelDisplayName
            $eventCount++
        }
        
        Write-Log "Collected $eventCount Kernel-Power events (Event ID 41)" "SUCCESS"
        
    } catch {
        if ($_.Exception.Message -notlike "*No events were found*") {
            Write-Log "Error collecting Kernel-Power events: $($_.Exception.Message)" "ERROR"
        } else {
            Write-Log "No Kernel-Power events found in the specified time range" "INFO"
        }
    }
    
    if ($FileName) {
        return $eventCount
    } else {
        return $collectedEvents
    }
}

function Get-BugCheckEvents {
    <#
    .SYNOPSIS
        Collect BugCheck events (Event ID 1001) indicating system crashes/BSODs
    #>
    param(
        [string]$FileName = ""
    )
    
    Write-Progress -Activity "Collecting BugCheck Events" -Status "Collecting system crash events (Event ID 1001)"
    
    # Initialize streaming file with headers (only for CSV format)
    $headers = @("TimeCreated", "Id", "LevelDisplayName", "LogName", "ProviderName", "Message", "Description", "MachineName", "BugCheckCode", "BugCheckParameter1", "BugCheckParameter2", "BugCheckParameter3", "BugCheckParameter4")
    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
        Initialize-EventFile -FileName $FileName -Headers $headers
    }
    
    # Array to collect events for non-CSV formats
    $collectedEvents = @()
    
    $startTime = (Get-Date).AddHours(-$TimeRange)
    $eventCount = 0
    
    try {
        $bugCheckEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ID = 1001
            StartTime = $startTime
        } -ErrorAction Stop
        
        foreach ($event in $bugCheckEvents) {
            # Parse bug check parameters from the message
            $message = $event.Message
            $bugCheckCode = "Unknown"
            $param1 = $param2 = $param3 = $param4 = "N/A"
            
            if ($message -match "BugcheckCode\s+(\w+)") {
                $bugCheckCode = $matches[1]
            }
            if ($message -match "BugcheckParameter1\s+(\w+)") {
                $param1 = $matches[1]
            }
            if ($message -match "BugcheckParameter2\s+(\w+)") {
                $param2 = $matches[1]
            }
            if ($message -match "BugcheckParameter3\s+(\w+)") {
                $param3 = $matches[1]
            }
            if ($message -match "BugcheckParameter4\s+(\w+)") {
                $param4 = $matches[1]
            }
            
            $eventObject = [PSCustomObject]@{
                TimeCreated = $event.TimeCreated
                Id = $event.Id
                LevelDisplayName = $event.LevelDisplayName
                LogName = $event.LogName
                ProviderName = $event.ProviderName
                Message = $event.Message -replace "`r`n", " " -replace "`n", " "
                Description = "BugCheck - System crash (Blue Screen of Death)"
                MachineName = $event.MachineName
                BugCheckCode = $bugCheckCode
                BugCheckParameter1 = $param1
                BugCheckParameter2 = $param2
                BugCheckParameter3 = $param3
                BugCheckParameter4 = $param4
            }
            
            # Stream event to file immediately (only for CSV format)
            if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
                Write-EventToFile -FileName $FileName -EventObject $eventObject
            } else {
                # Collect in memory for other formats
                $collectedEvents += $eventObject
            }
            
            # Update statistics
            Update-EventStatistics -EventType "BugCheckEvents" -Level $event.LevelDisplayName
            $eventCount++
        }
        
        Write-Log "Collected $eventCount BugCheck events (Event ID 1001)" "SUCCESS"
        
    } catch {
        if ($_.Exception.Message -notlike "*No events were found*") {
            Write-Log "Error collecting BugCheck events: $($_.Exception.Message)" "ERROR"
        } else {
            Write-Log "No BugCheck events found in the specified time range" "INFO"
        }
    }
    
    if ($FileName) {
        return $eventCount
    } else {
        return $collectedEvents
    }
}

function Get-HardwareEvents {
    <#
    .SYNOPSIS
        Collect hardware-related events that might indicate system instability
    #>
    param(
        [string]$FileName = ""
    )
    
    Write-Progress -Activity "Collecting Hardware Events" -Status "Collecting hardware-related errors"
    
    # Initialize streaming file with headers (only for CSV format)
    $headers = @("TimeCreated", "Id", "LevelDisplayName", "LogName", "ProviderName", "Message", "Description", "MachineName", "UserId", "ProcessId", "ThreadId")
    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
        Initialize-EventFile -FileName $FileName -Headers $headers
    }
    
    # Array to collect events for non-CSV formats
    $collectedEvents = @()
    
    $startTime = (Get-Date).AddHours(-$TimeRange)
    $eventCount = 0
    $hardwareEventIds = @(137, 153, 7031, 219, 455, 10016)
    
    try {
        foreach ($eventId in $hardwareEventIds) {
            try {
                $hardwareEvents = Get-WinEvent -FilterHashtable @{
                    LogName = 'System'
                    ID = $eventId
                    StartTime = $startTime
                } -ErrorAction Stop
                
                foreach ($event in $hardwareEvents) {
                    $description = switch ($event.Id) {
                        137 { "NTFS - Delayed write failed (disk issue)" }
                        153 { "Disk - IO error" }
                        7031 { "Service Control Manager - Service crashed" }
                        219 { "Kernel-PnP - Device not migrated" }
                        455 { "ESENT - Database error" }
                        10016 { "DistributedCOM - Permission error" }
                        default { "Hardware-related event" }
                    }
                    
                    $eventObject = [PSCustomObject]@{
                        TimeCreated = $event.TimeCreated
                        Id = $event.Id
                        LevelDisplayName = $event.LevelDisplayName
                        LogName = $event.LogName
                        ProviderName = $event.ProviderName
                        Message = $event.Message -replace "`r`n", " " -replace "`n", " "
                        Description = $description
                        MachineName = $event.MachineName
                        UserId = $event.UserId
                        ProcessId = $event.ProcessId
                        ThreadId = $event.ThreadId
                    }
                    
                    # Stream event to file immediately (only for CSV format)
                    if ($FileName -and ($Format -eq "All" -or $Format -eq "CSV")) {
                        Write-EventToFile -FileName $FileName -EventObject $eventObject
                    } else {
                        # Collect in memory for other formats
                        $collectedEvents += $eventObject
                    }
                    
                    # Update statistics
                    Update-EventStatistics -EventType "HardwareEvents" -Level $event.LevelDisplayName
                    $eventCount++
                }
            } catch {
                # Ignore "no events found" errors for individual event IDs
                if ($_.Exception.Message -notlike "*No events were found*") {
                    Write-Log "Error collecting hardware events (ID $eventId): $($_.Exception.Message)" "WARN"
                }
            }
        }
        
        Write-Log "Collected $eventCount hardware-related events" "SUCCESS"
        
    } catch {
        Write-Log "Error collecting hardware events: $($_.Exception.Message)" "ERROR"
    }
    
    if ($FileName) {
        return $eventCount
    } else {
        return $collectedEvents
    }
}

function Get-ReliabilityEvents {
    <#
    .SYNOPSIS
        Extract events from Windows Reliability Monitor
    #>
    
    Write-Progress -Activity "Collecting Reliability Events" -Status "Querying Reliability Monitor data"
    
    $events = @()
    $startTime = (Get-Date).AddHours(-$TimeRange)
    
    try {
        # Query Reliability Monitor via WMI
        $reliabilityRecords = Get-WmiObject -Class Win32_ReliabilityRecords | 
            Where-Object { $_.TimeGenerated -ge $startTime } |
            Sort-Object TimeGenerated -Descending
        
        foreach ($record in $reliabilityRecords) {
            $eventObject = [PSCustomObject]@{
                TimeCreated = $record.TimeGenerated
                EventType = $record.EventIdentifier
                SourceName = $record.SourceName
                Message = $record.Message
                ProductName = $record.ProductName
                Version = $record.Version
                Description = "Reliability Monitor Event"
                Severity = switch ($record.EventIdentifier) {
                    1 { "Application failure" }
                    2 { "Windows failure" }
                    3 { "Miscellaneous failure" }
                    4 { "Warning" }
                    5 { "Information" }
                    default { "Unknown" }
                }
            }
            
            $events += $eventObject
        }
        
        Write-Log "Collected $($events.Count) Reliability Monitor events" "SUCCESS"
        
    } catch {
        Write-Log "Error accessing Reliability Monitor data: $($_.Exception.Message)" "ERROR"
        
        # Fallback: Try to get reliability events from event logs
        try {
            $reliabilityEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'Microsoft-Windows-Reliability-Analysis-Component'
                StartTime = $startTime
            } -ErrorAction Stop
            
            foreach ($event in $reliabilityEvents) {
                $eventObject = [PSCustomObject]@{
                    TimeCreated = $event.TimeCreated
                    EventType = $event.Id
                    SourceName = $event.ProviderName
                    Message = $event.Message -replace "`r`n", " " -replace "`n", " "
                    ProductName = "System"
                    Version = "N/A"
                    Description = "Reliability Analysis Event"
                    Severity = $event.LevelDisplayName
                }
                
                $events += $eventObject
            }
            
            Write-Log "Collected $($events.Count) reliability events from event log fallback" "SUCCESS"
            
        } catch {
            Write-Log "No reliability events found via fallback method" "INFO"
        }
    }
    
    return $events
}

function Get-MinidumpAnalysis {
    <#
    .SYNOPSIS
        Analyze minidump files for crash information
    #>
    
    if (-not $IncludeMinidumps) {
        return @()
    }
    
    Write-Progress -Activity "Analyzing Minidump Files" -Status "Scanning C:\Windows\Minidump directory"
    
    $minidumpPath = "C:\Windows\Minidump"
    $analysis = @()
    
    if (-not (Test-Path $minidumpPath)) {
        Write-Log "Minidump directory not found: $minidumpPath" "INFO"
        return $analysis
    }
    
    try {
        $startTime = (Get-Date).AddHours(-$TimeRange)
        $dumpFiles = Get-ChildItem -Path $minidumpPath -Filter "*.dmp" -ErrorAction Stop |
            Where-Object { $_.LastWriteTime -ge $startTime } |
            Sort-Object LastWriteTime -Descending
        
        foreach ($dumpFile in $dumpFiles) {
            $fileInfo = [PSCustomObject]@{
                FileName = $dumpFile.Name
                FilePath = $dumpFile.FullName
                FileSize = [math]::Round($dumpFile.Length / 1KB, 2)
                CreatedTime = $dumpFile.CreationTime
                LastWriteTime = $dumpFile.LastWriteTime
                Description = "Memory dump file from system crash"
                Recommendation = "Analyze with WinDbg or BlueScreenView for detailed crash analysis"
            }
            
            $analysis += $fileInfo
            $Script:EventStatistics.MinidumpFiles++
        }
        
        Write-Log "Found $($analysis.Count) minidump files in the specified time range" "SUCCESS"
        
    } catch {
        Write-Log "Error analyzing minidump files: $($_.Exception.Message)" "ERROR"
    }
    
    return $analysis
}

function Export-EventsToCSV {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Events,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    
    if ($Events.Count -eq 0) {
        Write-Log "No events to export for $FileName" "INFO"
        return
    }
    
    $csvPath = Join-Path $Script:OutputDirectory "$FileName.csv"
    
    if (-not $Simulate) {
        try {
            $Events | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Log "Exported $($Events.Count) events to $csvPath" "SUCCESS"
        } catch {
            Write-Log "Error exporting CSV $csvPath : $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "[SIMULATION] Would export $($Events.Count) events to $csvPath" "INFO"
    }
}

function Export-EventsToHTML {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Events,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    
    if ($Events.Count -eq 0) {
        Write-Log "No events to export for $FileName" "INFO"
        return
    }
    
    $htmlPath = Join-Path $Script:OutputDirectory "$FileName.html"
    
    if ($Simulate) {
        Write-Log "[SIMULATION] Would export $($Events.Count) events to $htmlPath" "INFO"
        return
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>$Title</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2E86C1; border-bottom: 2px solid #2E86C1; padding-bottom: 10px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .error { background-color: #ffebee; }
        .critical { background-color: #ffcdd2; }
        .warning { background-color: #fff3e0; }
        .timestamp { white-space: nowrap; }
        .message { max-width: 400px; word-wrap: break-word; }
    </style>
</head>
<body>
    <h1>$Title</h1>
    <p><strong>Generated:</strong> $(Get-Date)</p>
    <p><strong>Time Range:</strong> Last $TimeRange hours</p>
    <p><strong>Total Events:</strong> $($Events.Count)</p>
    
    <table>
        <thead>
            <tr>
"@

    # Add headers based on event type
    $sampleEvent = $Events[0]
    $headers = $sampleEvent.PSObject.Properties.Name
    
    foreach ($header in $headers) {
        $html += "<th>$header</th>"
    }
    
    $html += @"
            </tr>
        </thead>
        <tbody>
"@

    foreach ($event in $Events) {
        $rowClass = switch ($event.LevelDisplayName) {
            "Critical" { "critical" }
            "Error" { "error" }
            "Warning" { "warning" }
            default { "" }
        }
        
        $html += "<tr class='$rowClass'>"
        
        foreach ($header in $headers) {
            $value = $event.$header
            if ($header -eq "TimeCreated") {
                $html += "<td class='timestamp'>$value</td>"
            } elseif ($header -eq "Message") {
                $truncatedMessage = if ($value.Length -gt 200) { 
                    $value.Substring(0, 200) + "..." 
                } else { 
                    $value 
                }
                $html += "<td class='message' title='$([System.Web.HttpUtility]::HtmlEncode($value))'>$([System.Web.HttpUtility]::HtmlEncode($truncatedMessage))</td>"
            } else {
                $html += "<td>$([System.Web.HttpUtility]::HtmlEncode($value))</td>"
            }
        }
        
        $html += "</tr>"
    }
    
    $html += @"
        </tbody>
    </table>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $htmlPath -Encoding UTF8
        Write-Log "Exported $($Events.Count) events to $htmlPath" "SUCCESS"
    } catch {
        Write-Log "Error exporting HTML $htmlPath : $($_.Exception.Message)" "ERROR"
    }
}

function Export-EventsToText {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Events,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    
    if ($Events.Count -eq 0) {
        Write-Log "No events to export for $FileName" "INFO"
        return
    }
    
    $textPath = Join-Path $Script:OutputDirectory "$FileName.txt"
    
    if ($Simulate) {
        Write-Log "[SIMULATION] Would export $($Events.Count) events to $textPath" "INFO"
        return
    }
    
    $content = @"
$Title
$("=" * $Title.Length)

Generated: $(Get-Date)
Time Range: Last $TimeRange hours
Total Events: $($Events.Count)

"@

    foreach ($event in $Events) {
        $content += @"
----------------------------------------
Time: $($event.TimeCreated)
Event ID: $($event.Id)
Level: $($event.LevelDisplayName)
Source: $($event.ProviderName)
Log: $($event.LogName)
Description: $($event.Description)
Message: $($event.Message)

"@
    }
    
    try {
        $content | Out-File -FilePath $textPath -Encoding UTF8
        Write-Log "Exported $($Events.Count) events to $textPath" "SUCCESS"
    } catch {
        Write-Log "Error exporting text file $textPath : $($_.Exception.Message)" "ERROR"
    }
}

function Generate-SummaryReport {
    <#
    .SYNOPSIS
        Generate summary report using statistics counters instead of event arrays
    #>
    
    Write-Progress -Activity "Generating Summary Report" -Status "Creating comprehensive analysis from statistics"
    
    $reportPath = Join-Path $Script:OutputDirectory "Summary_Report.html"
    
    if ($Simulate) {
        Write-Log "[SIMULATION] Would generate summary report at $reportPath" "INFO"
        return
    }
    
    # Use statistics from global counters
    $totalEvents = $Script:EventStatistics.SystemEvents + $Script:EventStatistics.ApplicationEvents + 
                   $Script:EventStatistics.KernelPowerEvents + $Script:EventStatistics.BugCheckEvents + 
                   $Script:EventStatistics.HardwareEvents + $Script:EventStatistics.ReliabilityEvents
    
    $criticalCount = $Script:EventStatistics.CriticalCount
    $errorCount = $Script:EventStatistics.ErrorCount
    
    # Analyze patterns using statistics
    $freezeIndicators = $Script:EventStatistics.KernelPowerEvents + $Script:EventStatistics.BugCheckEvents
    $hardwareIssues = $Script:EventStatistics.HardwareEvents  # Simplified - all hardware events are relevant
    
    # Generate recommendations
    $recommendations = @()
    
    if ($Script:EventStatistics.KernelPowerEvents -gt 0) {
        $recommendations += "• Found $($Script:EventStatistics.KernelPowerEvents) unexpected shutdown events - check for system freezes, power issues, or hardware failures"
    }
    
    if ($Script:EventStatistics.BugCheckEvents -gt 0) {
        $recommendations += "• Found $($Script:EventStatistics.BugCheckEvents) blue screen crashes - analyze minidump files for driver or hardware issues"
    }
    
    if ($hardwareIssues -gt 0) {
        $recommendations += "• Found $hardwareIssues hardware-related errors - check disk health, memory, and device drivers"
    }
    
    if ($Script:EventStatistics.MinidumpFiles -gt 0) {
        $recommendations += "• Found $($Script:EventStatistics.MinidumpFiles) crash dump files - use WinDbg or BlueScreenView for detailed analysis"
    }
    
    if ($recommendations.Count -eq 0) {
        $recommendations += "• No critical freeze-related events found in the specified time range"
        $recommendations += "• Consider checking Windows Update status, driver updates, and hardware health"
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Windows Event Log Analysis - System Freeze Troubleshooting</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        h1 { color: #1B4F72; border-bottom: 3px solid #2E86C1; padding-bottom: 15px; }
        h2 { color: #2E86C1; margin-top: 30px; }
        .summary-box { background-color: #EBF5FB; padding: 20px; border-radius: 5px; margin: 20px 0; border-left: 5px solid #2E86C1; }
        .critical { color: #C0392B; font-weight: bold; }
        .warning { color: #E67E22; font-weight: bold; }
        .success { color: #27AE60; font-weight: bold; }
        .stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .stat-card { background-color: #F8F9FA; padding: 15px; border-radius: 5px; border: 1px solid #DEE2E6; text-align: center; }
        .stat-number { font-size: 2em; font-weight: bold; color: #2E86C1; }
        .stat-label { color: #6C757D; margin-top: 5px; }
        .recommendations { background-color: #FFF3CD; padding: 20px; border-radius: 5px; border-left: 5px solid #FFC107; }
        .recommendations ul { margin: 10px 0; padding-left: 20px; }
        .recommendations li { margin: 8px 0; line-height: 1.4; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #f2f2f2; }
        .timestamp { white-space: nowrap; }
        .files-section { margin-top: 30px; }
        .file-list { background-color: #F8F9FA; padding: 15px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Windows Event Log Analysis Report</h1>
        
        <div class="summary-box">
            <h2>Collection Summary</h2>
            <p><strong>Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
            <p><strong>Analysis Period:</strong> Last $TimeRange hours ($($(Get-Date).AddHours(-$TimeRange)) to $(Get-Date))</p>
            <p><strong>Computer:</strong> $env:COMPUTERNAME</p>
            <p><strong>Total Events Collected:</strong> $totalEvents</p>
        </div>
        
        <h2>Event Statistics</h2>
        <div class="stat-grid">
            <div class="stat-card">
                <div class="stat-number critical">$($Script:EventStatistics.KernelPowerEvents)</div>
                <div class="stat-label">Kernel-Power Events<br>(Unexpected Shutdowns)</div>
            </div>
            <div class="stat-card">
                <div class="stat-number critical">$($Script:EventStatistics.BugCheckEvents)</div>
                <div class="stat-label">BugCheck Events<br>(System Crashes)</div>
            </div>
            <div class="stat-card">
                <div class="stat-number warning">$($Script:EventStatistics.HardwareEvents)</div>
                <div class="stat-label">Hardware Events<br>(Device Issues)</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$($Script:EventStatistics.SystemEvents)</div>
                <div class="stat-label">System Critical/Error<br>Events</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$($Script:EventStatistics.ApplicationEvents)</div>
                <div class="stat-label">Application Critical/Error<br>Events</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$($Script:EventStatistics.MinidumpFiles)</div>
                <div class="stat-label">Crash Dump Files<br>Found</div>
            </div>
        </div>
        
        <div class="recommendations">
            <h2>Analysis & Recommendations</h2>
            <ul>
$($recommendations | ForEach-Object { "                <li>$_</li>" })
            </ul>
        </div>
        
        <h2>Generated Files</h2>
        <div class="files-section">
            <div class="file-list">
                <h3>Event Log Reports:</h3>
                <ul>
                    <li>System_Critical_Errors.csv - Critical and error events from System log</li>
                    <li>Application_Errors.csv - Critical and error events from Application log</li>
                    <li>Kernel_Power_Events.csv - Unexpected shutdown events (Event ID 41)</li>
                    <li>BugCheck_Events.csv - System crash events (Event ID 1001)</li>
                    <li>Hardware_Events.csv - Hardware-related error events</li>
                    <li>Reliability_Events.csv - Windows Reliability Monitor data</li>
                    <li>Minidump_Analysis.csv - Crash dump file information</li>
                </ul>
            </div>
        </div>
        
        <h2>Next Steps</h2>
        <div class="summary-box">
            <ol>
                <li><strong>Review the generated CSV files</strong> for detailed event information</li>
                <li><strong>Analyze minidump files</strong> using WinDbg or BlueScreenView if crashes occurred</li>
                <li><strong>Check Windows Updates</strong> and install any pending updates</li>
                <li><strong>Update device drivers</strong>, especially graphics, storage, and network drivers</li>
                <li><strong>Run hardware diagnostics</strong> to check memory, storage, and other components</li>
                <li><strong>Monitor system temperature</strong> and ensure adequate cooling</li>
                <li><strong>Check Event Viewer regularly</strong> for new critical events</li>
            </ol>
        </div>
        
        <p style="text-align: center; color: #6C757D; margin-top: 30px; padding-top: 20px; border-top: 1px solid #DEE2E6;">
            Generated by Windows Event Log Collection Script v1.0<br>
            For technical support and troubleshooting assistance, consult your IT administrator.
        </p>
    </div>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Log "Generated summary report: $reportPath" "SUCCESS"
    } catch {
        Write-Log "Error generating summary report: $($_.Exception.Message)" "ERROR"
    }
}

# Main execution function
function Start-EventLogCollection {
    Write-Host "`n=== Windows Event Log Collection Script ===" -ForegroundColor Cyan
    Write-Host "Collecting system freeze and crash-related events..." -ForegroundColor White
    
    if ($Simulate) {
        Write-Host "`n*** SIMULATION MODE - No files will be created ***" -ForegroundColor Yellow -BackgroundColor Black
    }
    
    # Initialize environment
    Initialize-Environment
    
    # Collect events using streaming architecture
    Write-Progress -Activity "Event Collection" -Status "Starting streaming log collection process" -PercentComplete 0
    
    # CSV files are created and populated during collection (streaming)
    if ($Format -eq "All" -or $Format -eq "CSV") {
        Get-CriticalSystemEvents -FileName "System_Critical_Errors"
        Write-Progress -Activity "Event Collection" -Status "System events streamed" -PercentComplete 15
        
        Get-CriticalApplicationEvents -FileName "Application_Errors"
        Write-Progress -Activity "Event Collection" -Status "Application events streamed" -PercentComplete 30
        
        Get-KernelPowerEvents -FileName "Kernel_Power_Events"
        Write-Progress -Activity "Event Collection" -Status "Kernel-Power events streamed" -PercentComplete 45
        
        Get-BugCheckEvents -FileName "BugCheck_Events"
        Write-Progress -Activity "Event Collection" -Status "BugCheck events streamed" -PercentComplete 60
        
        Get-HardwareEvents -FileName "Hardware_Events"
        Write-Progress -Activity "Event Collection" -Status "Hardware events streamed" -PercentComplete 70
        
        # Handle reliability events and minidump (these are smaller datasets)
        $reliabilityEvents = Get-ReliabilityEvents
        Export-EventsToCSV -Events $reliabilityEvents -FileName "Reliability_Events"
        Write-Progress -Activity "Event Collection" -Status "Reliability events processed" -PercentComplete 80
        
        $minidumpAnalysis = Get-MinidumpAnalysis
        Export-EventsToCSV -Events $minidumpAnalysis -FileName "Minidump_Analysis"
        Write-Progress -Activity "Event Collection" -Status "Minidump analysis completed" -PercentComplete 90
    } else {
        # For non-CSV formats, collect events in memory first
        $systemEvents = Get-CriticalSystemEvents
        Write-Progress -Activity "Event Collection" -Status "System events collected" -PercentComplete 15
        
        $applicationEvents = Get-CriticalApplicationEvents
        Write-Progress -Activity "Event Collection" -Status "Application events collected" -PercentComplete 30
        
        $kernelPowerEvents = Get-KernelPowerEvents
        Write-Progress -Activity "Event Collection" -Status "Kernel-Power events collected" -PercentComplete 45
        
        $bugCheckEvents = Get-BugCheckEvents
        Write-Progress -Activity "Event Collection" -Status "BugCheck events collected" -PercentComplete 60
        
        $hardwareEvents = Get-HardwareEvents
        Write-Progress -Activity "Event Collection" -Status "Hardware events collected" -PercentComplete 70
        
        $reliabilityEvents = Get-ReliabilityEvents
        Write-Progress -Activity "Event Collection" -Status "Reliability events collected" -PercentComplete 80
        
        $minidumpAnalysis = Get-MinidumpAnalysis
        Write-Progress -Activity "Event Collection" -Status "Minidump analysis completed" -PercentComplete 90
        
        # Export to selected formats
        if ($Format -eq "All" -or $Format -eq "HTML") {
            Export-EventsToHTML -Events $systemEvents -FileName "System_Critical_Errors" -Title "System Critical and Error Events"
            Export-EventsToHTML -Events $applicationEvents -FileName "Application_Errors" -Title "Application Critical and Error Events"
            Export-EventsToHTML -Events $kernelPowerEvents -FileName "Kernel_Power_Events" -Title "Kernel-Power Events (Event ID 41)"
            Export-EventsToHTML -Events $bugCheckEvents -FileName "BugCheck_Events" -Title "BugCheck Events (Event ID 1001)"
            Export-EventsToHTML -Events $hardwareEvents -FileName "Hardware_Events" -Title "Hardware Error Events"
            Export-EventsToHTML -Events $reliabilityEvents -FileName "Reliability_Events" -Title "Windows Reliability Events"
            Export-EventsToHTML -Events $minidumpAnalysis -FileName "Minidump_Analysis" -Title "Crash Dump Analysis"
        }
        
        if ($Format -eq "All" -or $Format -eq "Text") {
            Export-EventsToText -Events $systemEvents -FileName "System_Critical_Errors" -Title "System Critical and Error Events"
            Export-EventsToText -Events $applicationEvents -FileName "Application_Errors" -Title "Application Critical and Error Events"
            Export-EventsToText -Events $kernelPowerEvents -FileName "Kernel_Power_Events" -Title "Kernel-Power Events (Event ID 41)"
            Export-EventsToText -Events $bugCheckEvents -FileName "BugCheck_Events" -Title "BugCheck Events (Event ID 1001)"
            Export-EventsToText -Events $hardwareEvents -FileName "Hardware_Events" -Title "Hardware Error Events"
            Export-EventsToText -Events $reliabilityEvents -FileName "Reliability_Events" -Title "Windows Reliability Events"
            Export-EventsToText -Events $minidumpAnalysis -FileName "Minidump_Analysis" -Title "Crash Dump Analysis"
        }
    }
    
    Write-Progress -Activity "Event Collection" -Status "Generating reports" -PercentComplete 95
    
    # Generate summary report using statistics
    Generate-SummaryReport
    
    Write-Progress -Activity "Event Collection" -Status "Complete" -PercentComplete 100 -Completed
    
    # Final summary
    $endTime = Get-Date
    $duration = $endTime - $Script:CollectionStartTime
    
    Write-Host "`n=== Collection Complete ===" -ForegroundColor Green
    Write-Host "Total events collected: $Script:TotalEventsCollected" -ForegroundColor White
    Write-Host "Collection duration: $($duration.TotalSeconds.ToString("F2")) seconds" -ForegroundColor White
    
    if (-not $Simulate) {
        Write-Host "Output directory: $Script:OutputDirectory" -ForegroundColor Cyan
        Write-Host "`nGenerated files:" -ForegroundColor White
        Get-ChildItem $Script:OutputDirectory | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Gray
        }
        Write-Host "`nOpen Summary_Report.html for comprehensive analysis and recommendations." -ForegroundColor Yellow
    } else {
        Write-Host "`nRun without -Simulate to generate actual files." -ForegroundColor Yellow
    }
}

# Execute the main function
Start-EventLogCollection