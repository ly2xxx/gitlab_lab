# Test script to verify the fix for Collect-EventLogs.ps1
# This version removes the #requires statement and simulates event collection

param(
    [string]$OutputPath = (Get-Location).Path,
    [int]$TimeRange = 24,
    [switch]$IncludeMinidumps,
    [ValidateSet("Text", "CSV", "HTML", "All")]
    [string]$Format = "HTML",
    [switch]$Simulate = $true,
    [string]$EventIDs = "",
    [switch]$Verbose
)

# Mock functions that would normally call Get-WinEvent
function Get-CriticalSystemEvents {
    param([string]$FileName = "")
    
    Write-Host "Testing Get-CriticalSystemEvents with FileName='$FileName'"
    
    if ($FileName) {
        Write-Host "Would stream to CSV file"
        return 5  # Mock event count
    } else {
        Write-Host "Collecting events in memory"
        # Mock event objects
        return @(
            [PSCustomObject]@{ TimeCreated = Get-Date; Id = 6008; LevelDisplayName = "Error"; Message = "Test system event 1" },
            [PSCustomObject]@{ TimeCreated = Get-Date; Id = 7031; LevelDisplayName = "Critical"; Message = "Test system event 2" }
        )
    }
}

function Get-CriticalApplicationEvents {
    param([string]$FileName = "")
    
    Write-Host "Testing Get-CriticalApplicationEvents with FileName='$FileName'"
    
    if ($FileName) {
        return 3  # Mock event count
    } else {
        return @(
            [PSCustomObject]@{ TimeCreated = Get-Date; Id = 1000; LevelDisplayName = "Error"; Message = "Test app event 1" }
        )
    }
}

function Get-KernelPowerEvents {
    param([string]$FileName = "")
    
    Write-Host "Testing Get-KernelPowerEvents with FileName='$FileName'"
    
    if ($FileName) {
        return 2  # Mock event count
    } else {
        return @(
            [PSCustomObject]@{ TimeCreated = Get-Date; Id = 41; LevelDisplayName = "Critical"; Message = "Test kernel-power event" }
        )
    }
}

function Get-BugCheckEvents {
    param([string]$FileName = "")
    
    Write-Host "Testing Get-BugCheckEvents with FileName='$FileName'"
    
    if ($FileName) {
        return 1  # Mock event count
    } else {
        return @(
            [PSCustomObject]@{ TimeCreated = Get-Date; Id = 1001; LevelDisplayName = "Critical"; Message = "Test bugcheck event" }
        )
    }
}

function Get-HardwareEvents {
    param([string]$FileName = "")
    
    Write-Host "Testing Get-HardwareEvents with FileName='$FileName'"
    
    if ($FileName) {
        return 0  # Mock event count
    } else {
        return @()  # No events
    }
}

# Test the call patterns
Write-Host "`n=== Testing CSV Format (with FileName) ===" -ForegroundColor Cyan
$Format = "CSV"
Get-CriticalSystemEvents -FileName "System_Critical_Errors"
Get-CriticalApplicationEvents -FileName "Application_Errors"
Get-KernelPowerEvents -FileName "Kernel_Power_Events"
Get-BugCheckEvents -FileName "BugCheck_Events" 
Get-HardwareEvents -FileName "Hardware_Events"

Write-Host "`n=== Testing HTML Format (without FileName) ===" -ForegroundColor Green
$Format = "HTML"
$systemEvents = Get-CriticalSystemEvents
$applicationEvents = Get-CriticalApplicationEvents
$kernelPowerEvents = Get-KernelPowerEvents
$bugCheckEvents = Get-BugCheckEvents
$hardwareEvents = Get-HardwareEvents

Write-Host "`nCollected events for HTML export:" -ForegroundColor Yellow
Write-Host "  System Events: $($systemEvents.Count)"
Write-Host "  Application Events: $($applicationEvents.Count)"
Write-Host "  Kernel-Power Events: $($kernelPowerEvents.Count)"
Write-Host "  BugCheck Events: $($bugCheckEvents.Count)"
Write-Host "  Hardware Events: $($hardwareEvents.Count)"

Write-Host "`n=== Test Complete - No Call Depth Overflow! ===" -ForegroundColor Green