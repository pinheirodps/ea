param(
    [switch]$DryRun
)

$root = Split-Path -Parent $PSScriptRoot
$scratch = Join-Path $root "scratch"

if (-not (Test-Path -LiteralPath $scratch)) {
    New-Item -ItemType Directory -Path $scratch | Out-Null
}

$preserve = @(".gitkeep", "README.md")
$patterns = @("*.py", "*.json", "*.md", "*.txt", "*.log", "*.csv", "*.tmp")
$removed = 0

foreach ($pattern in $patterns) {
    Get-ChildItem -LiteralPath $scratch -Filter $pattern -File -Force | ForEach-Object {
        if ($preserve -contains $_.Name) {
            return
        }

        if ($DryRun) {
            Write-Host "[dry-run] removeria $($_.FullName)"
        }
        else {
            Remove-Item -LiteralPath $_.FullName -Force
            $removed++
        }
    }
}

if ($DryRun) {
    Write-Host "Dry-run concluido."
}
else {
    Write-Host "Limpeza concluida. Arquivos removidos: $removed"
}
