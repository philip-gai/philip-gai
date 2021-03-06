<#
  .SYNOPSIS
  This script will revoke pipeline permissions to the given agent queues for an Azure DevOps project using the Azure DevOps REST API.
  This functionality is currently not available in the Azure DevOps UI.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The names of the agent queues to revoke permissions for.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$Queues,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure DevOps org.")]
    [ValidateNotNullOrEmpty()]
    [string]$Organization = $env:ADO_ORG,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure DevOps project.")]
    [ValidateNotNullOrEmpty()]
    [string]$Project = $env:ADO_PROJECT,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure DevOps personal access token.")]
    [ValidateNotNullOrEmpty()]
    [string]$Token = $env:ADO_PAT,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure DevOps API version.")]
    [ValidateNotNullOrEmpty()]
    [string]$Version = '7.1-preview.1',

    [Parameter(Mandatory = $false, HelpMessage = "Don't actually make any changes.")]
    [switch]$WhatIf
)

$ErrorActionPreference + 'Stop'

# Create client headers
# PAT Token requires the following scopes: Agent Pools: Read; Build: Read & execute; Security: Manage
$base64Credentials = [System.Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes([string]::Format(“{0}:{1}”, "", $Token)))
$headers = @{
    Authorization = "Basic $base64Credentials";
    Accept        = "application/json; api-version=$Version"
}

$queueNames = $Queues -join (',')

Write-Host "Organization: $Organization"
Write-Host "Project: $Project"
Write-Host "Queues: $queueNames"

# Get the agent queues to revoke permissions for
Write-Host "Getting agent queues to revoke on the project..."
$queuesToProtect = Invoke-RestMethod `
    -Headers $headers `
    -Method Get `
    -Uri "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/queues?queueNames=$queueNames"
$queueCount = $queuesToProtect.value.count
Write-Host "Found $queueCount agent queues to revoke pipeline access to from this project."

if (!$queueCount -or !$queueCount -gt 0) {
    Write-Warning "No agent queues found to revoke pipeline access from. Exiting."
    return;
}

foreach ($queue in $queuesToProtect.value) {
    $resourceId = $queue.id
    $resourceName = $queue.name
    $resourceType = "queue"

    # Get pipelines that are authorized to run on this agent queue
    Write-Host "Getting all the pipelines authorized on the `"$resourceName`" agent queue..."
    $response = Invoke-RestMethod `
        -Headers $headers `
        -Method Get `
        -Uri "https://dev.azure.com/$Organization/$Project/_apis/pipelines/pipelinepermissions/$resourceType/$resourceId"
    $authorizedPipelines = $response.pipelines
    $pipelineCount = $authorizedPipelines.count
    Write-Host "Found $pipelineCount pipelines that are authorized for this agent queue."
    
    if (!$pipelineCount -or !$pipelineCount -gt 0) {
        Write-Warning "No pipelines found to revoke pipeline access from. Skipping."
        continue;
    }

    # Revoke pipeline permissions to this agent queue
    Write-Host "Revoking pipeline permissions to this agent queue..."
    $pipelineToRevoke = $authorizedPipelines | ForEach-Object { $_.authorized = $false; return $_ } | Select-Object id, authorized
    $revokeRequestBody = @{
        "pipelines" = $pipelineToRevoke
    } | ConvertTo-Json -Compress

    if (!$WhatIf) {
        Invoke-RestMethod -Headers $headers `
            -Method Patch `
            -Uri "https://dev.azure.com/$Organization/$Project/_apis/pipelines/pipelinepermissions/$resourceType/$resourceId" `
            -Body $revokeRequestBody `
            -ContentType "application/json"
        Write-Host "Success! All pipeline access to this agent queue  has been revoked." -ForegroundColor Green
    }
    else {
        Write-Warning "WhatIf - Not making any changes."
    }
}

Write-Host "Done!" -ForegroundColor Green
