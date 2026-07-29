function Say {
    param(
        [string]$Message,
        [ConsoleColor]$Color = 'White'
    )
    $oldColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Message
    $Host.UI.RawUI.ForegroundColor = $oldColor
}

function Clean-OldLogs {
    param(
        [string]$Path,
        [int]$DaysThreshold = 14
    )

    if (-Not (Test-Path $Path)) {
        Say "Directory not found: $Path" Yellow
        return @{Deleted=0; Kept=0}
    }

    $now = Get-Date
    $deletedCount = 0
    $keptCount = 0

    # Get only files
    $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        $ageDays = ($now - $file.LastWriteTime).TotalDays
        if ($ageDays -gt $DaysThreshold) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                Say "Deleted: $($file.FullName) (Age: {0:N1} days)" Green
                $deletedCount++
            }
            catch {
                Say "Failed to delete: $($file.FullName) - $_" Red
                $keptCount++
            }
        }
        else {
            Say "Kept: $($file.FullName) (Age: {0:N1} days)" Cyan
            $keptCount++
        }
    }

    return @{Deleted=$deletedCount; Kept=$keptCount}
}

Say "Starting NIFDU old logs cleanup..." Cyan

$logDir = 'C:\nifdu\build\_logs'
$diagDir = 'C:\nifdu\build\_diag'

$logResults = Clean-OldLogs -Path $logDir -DaysThreshold 14
$diagResults = Clean-OldLogs -Path $diagDir -DaysThreshold 14

$totalDeleted = $logResults.Deleted + $diagResults.Deleted
$totalKept = $logResults.Kept + $diagResults.Kept

Say "\nCleanup Summary:" White
Say "  Deleted files: $totalDeleted" Green
Say "  Kept files:    $totalKept" Cyan

Say "NIFDU old logs cleanup completed." Cyan

