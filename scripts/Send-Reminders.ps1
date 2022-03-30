$ErrorActionPreference = 'Stop'

$repository = "philip-gai/philip-gai"

Write-Host "Logging in..."
gh auth login

Write-Host "Getting issues..."
$issues = $(gh issue list -R $repository --state open --json "number,assignees" -L 500) | ConvertFrom-Json
if(!$?) { exit 1 }
Write-Host "Found $($issues.Count) issues"

Write-Host "Filtering out issues that are not assigned..."
$issues = $issues | Where-Object { $_.Assignees -ne $null -and $_.Assignees.Count -gt 0 }
if(!$?) { exit 1 }
Write-Host "Found $($issues.Count) issues with assignees"

foreach ($issue in $issues) {
  $assigneeLogins = $issue.Assignees | Select-Object -ExpandProperty Login
  $assigneesStr = $assigneeLogins -join ", "

  $reminderMessage = ""
            
  $assigneeLogins | ForEach-Object {
    $reminderMessage += "@$_ This is your friendly (automated) reminder!`n"
  }

  Write-Host "Sending reminder to $assigneesStr..."
  gh issue comment $issue.number `
    --body $reminderMessage `
    -R $repository

  if (!$?) {
    Write-Warning "Failed to send reminder to $assignee"
    continue
  }
}

Write-Host "Done"
