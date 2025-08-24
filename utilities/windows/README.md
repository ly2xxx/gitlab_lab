  Key Features:

  Core Cleanup Operations:
  - Windows temp folders (%TEMP%, %WINDIR%\Temp)
  - User profile temp directories for all users
  - Browser caches (Chrome, Edge, Firefox)
  - Windows Update downloaded files
  - Recycle Bin contents
  - Prefetch files and thumbnail cache
  - Windows Error Reporting files
  - Memory dumps and IIS logs (older than 7 days)

  Safety & Usability:
  - Requires Administrator privileges
  - Shows space freed for each operation
  - Simulation mode (-Simulate) to preview without deleting
  - Comprehensive logging to temp file
  - Before/after drive space comparison
  - Error handling for locked/protected files

  Usage Examples:

  # Clean C: and H: drives
  .\Cleanup-DiskSpace.ps1 -Drives @("C:", "H:")

  # Preview cleanup without deleting (simulation mode)
  .\Cleanup-DiskSpace.ps1 -Drives @("C:") -Simulate

  # Include Windows Event Logs (use cautiously)
  .\Cleanup-DiskSpace.ps1 -Drives @("C:") -IncludeEventLogs