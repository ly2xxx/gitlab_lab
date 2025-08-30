# Windows Utilities

This directory contains PowerShell utilities for Windows system administration and troubleshooting.

## Available Scripts

### 1. Cleanup-DiskSpace.ps1
**Purpose**: Comprehensive disk space cleanup tool

**Key Features**:
- Windows temp folders (%TEMP%, %WINDIR%\Temp)
- User profile temp directories for all users
- Browser caches (Chrome, Edge, Firefox)
- Windows Update downloaded files
- Recycle Bin contents
- Prefetch files and thumbnail cache
- Windows Error Reporting files
- Memory dumps and IIS logs (older than 7 days)

**Safety & Usability**:
- Requires Administrator privileges
- Shows space freed for each operation
- Simulation mode (-Simulate) to preview without deleting
- Comprehensive logging to temp file
- Before/after drive space comparison
- Error handling for locked/protected files

**Usage Examples**:
```powershell
# Clean C: and H: drives
.\Cleanup-DiskSpace.ps1 -Drives @("C:", "H:")

# Preview cleanup without deleting (simulation mode)
.\Cleanup-DiskSpace.ps1 -Drives @("C:") -Simulate

# Include Windows Event Logs (use cautiously)
.\Cleanup-DiskSpace.ps1 -Drives @("C:") -IncludeEventLogs
```

### 2. Collect-EventLogs.ps1
**Purpose**: Automated Windows event log collection for system freeze troubleshooting

**Key Features**:
- **System Event Analysis**: Critical and Error events from System log
- **Application Event Analysis**: Critical and Error events from Application log  
- **Freeze Detection**: Kernel-Power events (Event ID 41) - unexpected shutdowns
- **Crash Detection**: BugCheck events (Event ID 1001) - system crashes/BSODs
- **Hardware Monitoring**: Hardware-related error events (disk, memory, drivers)
- **Reliability Integration**: Windows Reliability Monitor data extraction
- **Minidump Analysis**: Crash dump file detection and cataloging
- **Multiple Output Formats**: CSV, HTML, and Text reports
- **Comprehensive Summary**: HTML report with analysis and recommendations

**Safety & Usability**:
- Requires Administrator privileges
- Configurable time range (default: 48 hours)
- Simulation mode to preview collection without generating files
- Event ID filtering for focused analysis
- Progress indicators and verbose logging
- Professional HTML reports with styling and recommendations

**Usage Examples**:
```powershell
# Basic collection (last 48 hours, all formats)
.\Collect-EventLogs.ps1

# Extended collection with minidump analysis
.\Collect-EventLogs.ps1 -TimeRange 72 -IncludeMinidumps -Verbose

# Focus on specific freeze-related events
.\Collect-EventLogs.ps1 -EventIDs "41,1001,6008" -Format HTML

# Custom output location with simulation
.\Collect-EventLogs.ps1 -OutputPath "C:\Temp\Logs" -Simulate

# HTML-only output for specific time range
.\Collect-EventLogs.ps1 -TimeRange 24 -Format HTML -IncludeMinidumps
```

**Generated Output Structure**:
```
EventLogs_YYYYMMDD_HHMMSS/
├── Summary_Report.html           # Comprehensive analysis dashboard
├── System_Critical_Errors.csv   # System log critical/error events
├── Application_Errors.csv       # Application log critical/error events
├── Kernel_Power_Events.csv      # Unexpected shutdown events (Event ID 41)
├── BugCheck_Events.csv          # System crash events (Event ID 1001)
├── Hardware_Events.csv          # Hardware-related error events
├── Reliability_Events.csv       # Windows Reliability Monitor data
├── Minidump_Analysis.csv        # Crash dump file information
├── Raw_Logs/                    # Raw event log exports (if applicable)
└── Collection_Log.txt           # Detailed operation log
```

**Event ID Reference**:
- **41**: Kernel-Power - Unexpected shutdown/freeze
- **1001**: BugCheck - System crash (BSOD)
- **6008**: EventLog - Unexpected system shutdown
- **137**: NTFS - Delayed write failed (disk issue)
- **153**: Disk - IO error
- **7031**: Service Control Manager - Service crashed
- **1000**: Application Error - Application crash
- **1002**: Application Hang - Application stopped responding

**Troubleshooting Focus**:
Specifically designed for diagnosing HP ZBook and other Windows 11 systems experiencing frequent freezing issues. The script automatically identifies patterns and provides actionable recommendations.

## Prerequisites

- **Windows PowerShell 5.1 or PowerShell 7.x**
- **Administrator privileges** (both scripts require elevation)
- **Windows 10/11** (tested on Windows 11, compatible with Windows 10)

## Installation

1. Clone or download the scripts to a local directory
2. Open PowerShell as Administrator
3. Navigate to the utilities/windows directory
4. Execute the desired script with appropriate parameters

## Security Considerations

Both scripts:
- Require administrator privileges for system access
- Include simulation modes for safe testing
- Provide comprehensive logging for audit trails
- Follow PowerShell security best practices
- Handle errors gracefully without system disruption

## Support

For issues, enhancements, or questions regarding these utilities:
1. Check the script's built-in help: `Get-Help .\ScriptName.ps1 -Full`
2. Review the generated log files for troubleshooting information
3. Use simulation mode to verify operations before execution