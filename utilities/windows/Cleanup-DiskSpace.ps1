#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Disk Space Cleanup Script
.DESCRIPTION
    Comprehensive PowerShell script to clean up disk space by removing temporary files,
    cache files, logs, and other unnecessary files from specified drives.
.PARAMETER Drives
    Array of drive letters to clean (e.g., @("C:", "D:", "H:"))
.PARAMETER Simulate
    Run in simulation mode - show what would be deleted without actually deleting
.PARAMETER IncludeEventLogs
    Clear Windows Event Logs (use with caution)
.EXAMPLE
    .\Cleanup-DiskSpace.ps1 -Drives @("C:", "H:")
.EXAMPLE
    .\Cleanup-DiskSpace.ps1 -Drives @("C:") -Simulate
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$Drives,
    
    [switch]$Simulate,
    
    [switch]$IncludeEventLogs
)

# Global variables
$TotalSpaceFreed = 0
$LogFile = "$env:TEMP\DiskCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(if($Level -eq "ERROR") {"Red"} elseif($Level -eq "WARN") {"Yellow"} else {"Green"})
    Add-Content -Path $LogFile -Value $logEntry
}

function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            return (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum
        } catch {
            return 0
        }
    }
    return 0
}

function Remove-FilesAndFolders {
    param(
        [string]$Path,
        [string]$Description,
        [string[]]$Exclude = @(),
        [switch]$RecurseOnly
    )
    
    if (-not (Test-Path $Path)) {
        Write-Log "Path not found: $Path" "WARN"
        return 0
    }
    
    $initialSize = Get-FolderSize -Path $Path
    Write-Log "Cleaning: $Description ($Path)"
    Write-Host "  Initial size: $([math]::Round($initialSize / 1MB, 2)) MB" -ForegroundColor Cyan
    
    if ($Simulate) {
        Write-Host "  [SIMULATION] Would clean: $Description" -ForegroundColor Yellow
        return $initialSize
    }
    
    try {
        if ($RecurseOnly) {
            # Only remove contents, not the folder itself
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $Exclude } |
            ForEach-Object {
                try {
                    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "Failed to remove: $($_.FullName) - $($_.Exception.Message)" "WARN"
                }
            }
        } else {
            Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $Exclude } |
            ForEach-Object {
                try {
                    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "Failed to remove: $($_.FullName) - $($_.Exception.Message)" "WARN"
                }
            }
        }
    } catch {
        Write-Log "Error cleaning $Path : $($_.Exception.Message)" "ERROR"
        return 0
    }
    
    $finalSize = Get-FolderSize -Path $Path
    $spaceFreed = $initialSize - $finalSize
    Write-Host "  Space freed: $([math]::Round($spaceFreed / 1MB, 2)) MB" -ForegroundColor Green
    
    return $spaceFreed
}

function Clear-WindowsTemp {
    param([string]$DriveLetter)
    
    Write-Log "=== Clearing Windows Temporary Files ===" 
    $spaceFreed = 0
    
    # Windows Temp folder
    $windowsTemp = "$DriveLetter\Windows\Temp"
    $spaceFreed += Remove-FilesAndFolders -Path $windowsTemp -Description "Windows Temp" -RecurseOnly
    
    # System Temp folders
    $systemTemp = "$env:TEMP"
    if ($systemTemp.StartsWith($DriveLetter, [System.StringComparison]::OrdinalIgnoreCase)) {
        $spaceFreed += Remove-FilesAndFolders -Path $systemTemp -Description "System Temp" -RecurseOnly
    }
    
    # All user profile temp folders
    $users = Get-ChildItem "$DriveLetter\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($user in $users) {
        $userTemp = "$($user.FullName)\AppData\Local\Temp"
        $spaceFreed += Remove-FilesAndFolders -Path $userTemp -Description "User Temp ($($user.Name))" -RecurseOnly
    }
    
    return $spaceFreed
}

function Clear-BrowserCache {
    param([string]$DriveLetter)
    
    Write-Log "=== Clearing Browser Cache ===" 
    $spaceFreed = 0
    
    $users = Get-ChildItem "$DriveLetter\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($user in $users) {
        $userPath = $user.FullName
        
        # Chrome cache
        $chromeCache = "$userPath\AppData\Local\Google\Chrome\User Data\Default\Cache"
        $spaceFreed += Remove-FilesAndFolders -Path $chromeCache -Description "Chrome Cache ($($user.Name))" -RecurseOnly
        
        # Edge cache  
        $edgeCache = "$userPath\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
        $spaceFreed += Remove-FilesAndFolders -Path $edgeCache -Description "Edge Cache ($($user.Name))" -RecurseOnly
        
        # Firefox cache
        $firefoxProfiles = "$userPath\AppData\Local\Mozilla\Firefox\Profiles"
        if (Test-Path $firefoxProfiles) {
            Get-ChildItem $firefoxProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $cacheFolder = "$($_.FullName)\cache2"
                $spaceFreed += Remove-FilesAndFolders -Path $cacheFolder -Description "Firefox Cache ($($user.Name))" -RecurseOnly
            }
        }
    }
    
    return $spaceFreed
}

function Clear-WindowsUpdateFiles {
    param([string]$DriveLetter)
    
    Write-Log "=== Clearing Windows Update Files ===" 
    $spaceFreed = 0
    
    # Windows Update Download folder
    $updateFolder = "$DriveLetter\Windows\SoftwareDistribution\Download"
    $spaceFreed += Remove-FilesAndFolders -Path $updateFolder -Description "Windows Update Downloads" -RecurseOnly
    
    # Windows Update Logs
    $updateLogs = "$DriveLetter\Windows\Logs\WindowsUpdate"
    $spaceFreed += Remove-FilesAndFolders -Path $updateLogs -Description "Windows Update Logs" -RecurseOnly
    
    return $spaceFreed
}

function Clear-RecycleBin {
    param([string]$DriveLetter)
    
    Write-Log "=== Clearing Recycle Bin ===" 
    $spaceFreed = 0
    
    $recycleBin = "$DriveLetter\`$Recycle.Bin"
    if (Test-Path $recycleBin) {
        $initialSize = Get-FolderSize -Path $recycleBin
        
        if ($Simulate) {
            Write-Host "  [SIMULATION] Would empty Recycle Bin" -ForegroundColor Yellow
            return $initialSize
        }
        
        try {
            # Use Shell.Application to properly empty recycle bin
            $shell = New-Object -ComObject Shell.Application
            $shell.Namespace(10).Items() | ForEach-Object { $_.InvokeVerb("delete") }
            
            $finalSize = Get-FolderSize -Path $recycleBin
            $spaceFreed = $initialSize - $finalSize
            Write-Host "  Space freed from Recycle Bin: $([math]::Round($spaceFreed / 1MB, 2)) MB" -ForegroundColor Green
        } catch {
            Write-Log "Error emptying Recycle Bin: $($_.Exception.Message)" "ERROR"
        }
    }
    
    return $spaceFreed
}

function Clear-SystemFiles {
    param([string]$DriveLetter)
    
    Write-Log "=== Clearing System Files ===" 
    $spaceFreed = 0
    
    # Prefetch files
    $prefetch = "$DriveLetter\Windows\Prefetch"
    $spaceFreed += Remove-FilesAndFolders -Path $prefetch -Description "Prefetch Files" -RecurseOnly
    
    # Thumbnail cache
    $users = Get-ChildItem "$DriveLetter\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($user in $users) {
        $thumbCache = "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer"
        $spaceFreed += Remove-FilesAndFolders -Path $thumbCache -Description "Thumbnail Cache ($($user.Name))" -Exclude @("desktop.ini") -RecurseOnly
    }
    
    # Windows Error Reporting
    $wer = "$DriveLetter\ProgramData\Microsoft\Windows\WER"
    $spaceFreed += Remove-FilesAndFolders -Path $wer -Description "Windows Error Reporting" -RecurseOnly
    
    # Memory dumps
    $memoryDumps = "$DriveLetter\Windows\memory.dmp"
    if (Test-Path $memoryDumps) {
        $dumpSize = (Get-Item $memoryDumps).Length
        if (-not $Simulate) {
            Remove-Item $memoryDumps -Force -ErrorAction SilentlyContinue
            Write-Host "  Removed memory dump: $([math]::Round($dumpSize / 1MB, 2)) MB" -ForegroundColor Green
        } else {
            Write-Host "  [SIMULATION] Would remove memory dump: $([math]::Round($dumpSize / 1MB, 2)) MB" -ForegroundColor Yellow
        }
        $spaceFreed += $dumpSize
    }
    
    return $spaceFreed
}

function Clear-EventLogs {
    param([string]$DriveLetter)
    
    if (-not $IncludeEventLogs) {
        return 0
    }
    
    Write-Log "=== Clearing Windows Event Logs (Use with caution!) ===" 
    $spaceFreed = 0
    
    if ($Simulate) {
        Write-Host "  [SIMULATION] Would clear Windows Event Logs" -ForegroundColor Yellow
        # Estimate space (difficult to calculate exactly)
        return 100MB  # Conservative estimate
    }
    
    try {
        $logs = Get-WinEvent -ListLog * | Where-Object { $_.RecordCount -gt 0 -and $_.LogName -notlike "*Security*" }
        foreach ($log in $logs) {
            try {
                [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName)
                Write-Log "Cleared event log: $($log.LogName)"
            } catch {
                Write-Log "Failed to clear log $($log.LogName): $($_.Exception.Message)" "WARN"
            }
        }
        $spaceFreed = 50MB  # Estimate
        Write-Host "  Event logs cleared (estimated): $([math]::Round($spaceFreed / 1MB, 2)) MB" -ForegroundColor Green
    } catch {
        Write-Log "Error clearing event logs: $($_.Exception.Message)" "ERROR"
    }
    
    return $spaceFreed
}

function Clear-IISLogs {
    param([string]$DriveLetter)
    
    Write-Log "=== Clearing IIS Logs ===" 
    $spaceFreed = 0
    
    $iisLogs = "$DriveLetter\inetpub\logs\LogFiles"
    if (Test-Path $iisLogs) {
        # Keep logs from last 7 days
        $cutoffDate = (Get-Date).AddDays(-7)
        Get-ChildItem $iisLogs -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        ForEach-Object {
            $fileSize = $_.Length
            if (-not $Simulate) {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
            $spaceFreed += $fileSize
        }
        
        Write-Host "  IIS logs cleaned (>7 days old): $([math]::Round($spaceFreed / 1MB, 2)) MB" -ForegroundColor Green
    }
    
    return $spaceFreed
}

function Show-DriveSpaceInfo {
    param([string]$DriveLetter, [string]$Stage)
    
    try {
        $drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $DriveLetter }
        if ($drive) {
            $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            $totalGB = [math]::Round($drive.Size / 1GB, 2)
            $usedGB = [math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 2)
            $freePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
            
            Write-Host "`n$Stage - Drive $DriveLetter" -ForegroundColor Magenta
            Write-Host "  Total: $totalGB GB" -ForegroundColor White
            Write-Host "  Used:  $usedGB GB" -ForegroundColor Red
            Write-Host "  Free:  $freeGB GB ($freePercent%)" -ForegroundColor Green
        }
    } catch {
        Write-Log "Error getting drive info for $DriveLetter : $($_.Exception.Message)" "ERROR"
    }
}

# Main execution
Write-Log "Starting Disk Cleanup Script"
Write-Log "Log file: $LogFile"

if ($Simulate) {
    Write-Host "`n*** SIMULATION MODE - No files will be deleted ***" -ForegroundColor Yellow -BackgroundColor Black
}

# Validate drives
$validDrives = @()
foreach ($drive in $Drives) {
    $driveLetter = $drive.TrimEnd(':') + ":"
    if (Test-Path $driveLetter) {
        $validDrives += $driveLetter
        Show-DriveSpaceInfo -DriveLetter $driveLetter -Stage "BEFORE CLEANUP"
    } else {
        Write-Log "Drive $driveLetter not found or inaccessible" "ERROR"
    }
}

if ($validDrives.Count -eq 0) {
    Write-Log "No valid drives specified. Exiting." "ERROR"
    exit 1
}

# Perform cleanup operations
foreach ($drive in $validDrives) {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "CLEANING DRIVE: $drive" -ForegroundColor Cyan -BackgroundColor DarkBlue
    Write-Host "="*60 -ForegroundColor Cyan
    
    $driveSpaceFreed = 0
    
    # Execute cleanup functions
    $driveSpaceFreed += Clear-WindowsTemp -DriveLetter $drive
    $driveSpaceFreed += Clear-BrowserCache -DriveLetter $drive
    $driveSpaceFreed += Clear-WindowsUpdateFiles -DriveLetter $drive
    $driveSpaceFreed += Clear-RecycleBin -DriveLetter $drive
    $driveSpaceFreed += Clear-SystemFiles -DriveLetter $drive
    $driveSpaceFreed += Clear-EventLogs -DriveLetter $drive
    $driveSpaceFreed += Clear-IISLogs -DriveLetter $drive
    
    Show-DriveSpaceInfo -DriveLetter $drive -Stage "AFTER CLEANUP"
    
    Write-Host "`nTotal space freed on $drive : $([math]::Round($driveSpaceFreed / 1GB, 2)) GB" -ForegroundColor Green -BackgroundColor Black
    $global:TotalSpaceFreed += $driveSpaceFreed
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "CLEANUP SUMMARY" -ForegroundColor Green -BackgroundColor Black
Write-Host "="*60 -ForegroundColor Green
Write-Host "Total space freed across all drives: $([math]::Round($global:TotalSpaceFreed / 1GB, 2)) GB" -ForegroundColor Green -BackgroundColor Black
Write-Host "Log file saved to: $LogFile" -ForegroundColor Cyan

if ($Simulate) {
    Write-Host "`nRun without -Simulate to perform actual cleanup." -ForegroundColor Yellow
}

Write-Log "Disk cleanup completed. Total space freed: $([math]::Round($global:TotalSpaceFreed / 1GB, 2)) GB"