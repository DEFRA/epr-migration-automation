param(
    [Parameter(Mandatory)]
    [string]$OrganizationUri,
    [Parameter(Mandatory)]
    [string]$Project,
    [Parameter()]
    [string]$OutputPath = (Join-Path -Path $PWD -ChildPath pipelines-all.json),
    [Parameter()]
    [string]$DebugOutputLocation = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "get-pipelines.ps1"),
    [Parameter()]
    [switch]$SuppressInterimFileGeneration,
    [Parameter()]
    [string]$HostingRepoType,
    [Parameter()]
    [switch]$EnabledOnly,
    [Parameter()]
    [switch]$Type2Only,
    [Parameter()]
    [string]$ExclusionFilter,
    [Parameter()]
    [string]$AccessToken
)

Set-StrictMode -Version 3.0

[string]$functionName = $MyInvocation.MyCommand
[DateTime]$startTime = [DateTime]::UtcNow
[int]$exitCode = -1
[bool]$setHostExitCode = (Test-Path -Path ENV:TF_BUILD) -and ($ENV:TF_BUILD -eq "true")
[bool]$enableDebug = (Test-Path -Path ENV:SYSTEM_DEBUG) -and ($ENV:SYSTEM_DEBUG -eq "true")
[System.IO.DirectoryInfo]$debugDir = $DebugOutputLocation

Write-Host "${functionName} started at $($startTime.ToString('u'))"

Set-Variable -Name ErrorActionPreference -Value Continue -scope global
Set-Variable -Name VerbosePreference -Value Continue -Scope global

if ($enableDebug) {
    Set-Variable -Name DebugPreference -Value Continue -Scope global
    Set-Variable -Name InformationPreference -Value Continue -Scope global
}

Write-Debug "${functionName}:OrganizationUri=$OrganizationUri"
Write-Debug "${functionName}:Project=$Project"
Write-Debug "${functionName}:OutputPath=$OutputPath"
Write-Debug "${functionName}:HostingRepoType=$HostingRepoType"
Write-Debug "${functionName}:DebugOutputLocation=$DebugOutputLocation"
Write-Debug "${functionName}:SuppressInterimFileGeneration=$SuppressInterimFileGeneration"
Write-Debug "${functionName}:EnabledOnly=$EnabledOnly"
Write-Debug "${functionName}:Type2Only=$Type2Only"
Write-Debug "${functionName}:ExclusionFilter=$ExclusionFilter"

[System.IO.DirectoryInfo]$scriptDir = $PSCommandPath | Split-Path -Parent
Write-Debug "${functionName}:scriptDir.FullName=$($scriptDir.FullName)"

if (-not $SuppressInterimFileGeneration) {
  Write-Debug "${functionName}:Creating debug dir $($debugDir.FullName)"
  [void]$debugDir.Create()
}

try {
    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $scriptDir.FullName -ChildPath "modules/ADO2GitHubMigration"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"

    Import-Module $moduleDir.FullName -Force

    Initialize-AdoCli -OrganizationUri $OrganizationUri -Project $Project -AccessToken $AccessToken
    
    [array]$pipelineSummaries = @(Get-AdoPipelineModel -Summary)
    Write-Host "There are $($pipelineSummaries.Length) pipelines in Team Project $Project"

    if (-not $SuppressInterimFileGeneration) {
      [System.IO.FileInfo]$allSummaryFile = Join-Path -Path $debugDir.FullName -ChildPath 'debug-summary-all.json'
      $pipelineSummaries | ConvertTo-Json -Depth $MAX_JSON_DEPTH | Set-Content -Path $allSummaryFile.FullName -Force 
      Write-Debug "${functionName}:pipelineSummaries dumped to $($allSummaryFile.FullName)"
    }

    if ($EnabledOnly) {
      $pipelineSummaries = @($pipelineSummaries | Where-Object -FilterScript { $_.queueStatus -eq "enabled" } )
      Write-Host "There are $($pipelineSummaries.Length) enabled pipelines in Team Project $Project"
    }

    if ($pipelineSummaries.Length -gt 10) {
      Write-Warning "For $($pipelineSummaries.Length) pipelines, this could take a while."
    }

    [array]$pipelines = @($pipelineSummaries | Select-Object -ExpandProperty id `
                                             | Sort-Object -Unique `
                                             | ForEach-Object -ThrottleLimit $pipelineSummaries.Count -Parallel {
        try {
          Import-Module $using:moduleDir.FullName -Force
          Set-Variable -Name ErrorActionPreference -Value Continue -scope global
          Set-Variable -Name VerbosePreference -Value Continue -Scope global
          if ($using:enableDebug) {
            Set-Variable -Name DebugPreference -Value Continue -Scope global
            Set-Variable -Name InformationPreference -Value Continue -Scope global
          }
          Get-AdoPipelineModel -Pipeline $_ -OrganizationUri $using:OrganizationUri -Project $using:Project 
        } 
        catch {
          Write-Error $_.Exception.ToString()
          throw $_.Exception
        }
      }
    )

    Write-Host "Obtained details for $($pipelines.Length) pipelines"

    if ($Type2Only) {
      $pipelines = @($pipelines | Where-Object -FilterScript { $_.process -ne $null -and $_.process.type -eq 2 } )
      Write-Host "Have details for $($pipelines.Length) Type2 pipelines"
    }

    if (-not [string]::IsNullOrWhiteSpace($HostingRepoType)) {
      $pipelines = @($pipelines | Where-Object -FilterScript { $_.repository -ne $null -and $_.repository.type -eq $HostingRepoType } )
      Write-Host "Have details for $($pipelines.Length) '$HostingRepoType' hosted pipelines"
    }

    [System.IO.FileInfo]$outputFile = $OutputPath

    $output = $pipelines | ConvertTo-Json -Depth $MAX_JSON_DEPTH
    $output | Set-Content -Path $outputFile.FullName -Force 
    Write-Host "Output file $($outputFile.FullName) created."
    $exitCode = 0
}
catch {
    $exitCode = -2
    Write-Error $_.Exception.ToString()
    throw $_.Exception
}
finally {
    [DateTime]$endTime = [DateTime]::UtcNow
    [Timespan]$duration = $endTime.Subtract($startTime)

    Write-Host "${functionName} finished at $($endTime.ToString('u')) (duration $($duration -f 'g')) with exit code $exitCode"

    if ($setHostExitCode) {
        Write-Debug "${functionName}:Setting host exit code"
        $host.SetShouldExit($exitCode)
    }
    exit $exitCode
}