param(
  [Parameter(Mandatory)]
  [string]$OrganizationUri,
  [Parameter(Mandatory)]
  [string]$Project,
  [Parameter(Mandatory)]
  [string]$GitHubOrganizationName,
  [Parameter(Mandatory)]
  [string]$GitHubServiceConnection,
  [Parameter(Mandatory)]
  [string]$SourceAdoRepo,
  [Parameter(Mandatory)]
  [string]$TargetGitHubRepo,
  [Parameter(Mandatory)]
  [string]$InputPath,
  [Parameter()]
  [string]$ADOOutputVariableName,
  [Parameter()]
  [string]$AccessToken
)

Set-StrictMode -Version 3.0

[string]$functionName = $MyInvocation.MyCommand
[DateTime]$startTime = [DateTime]::UtcNow
[int]$exitCode = -1
[bool]$setHostExitCode = (Test-Path -Path ENV:TF_BUILD) -and ($ENV:TF_BUILD -eq "true")
[bool]$enableDebug = (Test-Path -Path ENV:SYSTEM_DEBUG) -and ($ENV:SYSTEM_DEBUG -eq "true")

Write-Host "${functionName} started at $($startTime.ToString('u'))"

Set-Variable -Name ErrorActionPreference -Value Continue -scope global
Set-Variable -Name VerbosePreference -Value Continue -Scope global

if ($enableDebug) {
    Set-Variable -Name DebugPreference -Value Continue -Scope global
    Set-Variable -Name InformationPreference -Value Continue -Scope global
}

Write-Debug "${functionName}:OrganizationUri=$OrganizationUri"
Write-Debug "${functionName}:Project=$Project"
Write-Debug "${functionName}:GitHubOrganizationName=$GitHubOrganizationName"
Write-Debug "${functionName}:GitHubServiceConnection=$GitHubServiceConnection"
Write-Debug "${functionName}:SourceAdoRepo=$SourceAdoRepo"
Write-Debug "${functionName}:TargetGitHubRepo=$TargetGitHubRepo"
Write-Debug "${functionName}:InputPath=$InputPath"
Write-Debug "${functionName}:ADOOutputVariableName=$ADOOutputVariableName"

[System.IO.DirectoryInfo]$scriptDir = $PSCommandPath | Split-Path -Parent
Write-Debug "${functionName}:scriptDir.FullName=$scriptDir.FullName"

try {
  [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $scriptDir.FullName -ChildPath "modules/ADO2GitHubMigration"
  Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"

  Import-Module $moduleDir.FullName -Force

  Initialize-AdoCli -OrganizationUri $OrganizationUri -Project $Project -AccessToken $AccessToken

  [System.IO.FileInfo]$inputFile = $InputPath

  if (-not $inputFile.Exists) {
    Write-Host "Could not find input file $($inputFile.FullName)"
    throw [System.IO.FileNotFoundException]::new($inputFile.FullName)
  }
  
  Write-Host "Importing pipeline info from $($inputFile.FullName)"

  [array]$pipelines = @(Get-Content -Path $inputFile.FullName | ConvertFrom-Json -Depth 99)

  Write-Host "Loaded details of $($pipelines.Count) pipelines"

  [array]$repoPipelines = @($pipelines | Where-Object -FilterScript { $_.repository -ne $null -and $_.repository.name -eq $SourceAdoRepo })

  Write-Host "There are $($repoPipelines.Count) pipelines associated with $SourceAdoRepo"

  [array]$adoPipelineInfos = @($repoPipelines | ConvertTo-PipelineInfo -OrganizationUrl $OrganizationUri -Project $Project | Add-PipelineVariables -PassThru)

  [array]$gitHubPipelineInfos = @($adoPipelineInfos | ForEach-Object -Process {
    $_.Id = 0
    $_.Name = $_.Name + ' (GitHub)'
    $_.RepoType = "GitHub"
    $_.RepoUrl = "https://github.com/$GitHubOrganizationName/$($TargetGitHubRepo).git"
    $_.ServiceConnection = $GitHubServiceConnection
    return $_
  })

  if ([string]::IsNullOrEmpty($ADOOutputVariableName)) {
    $gitHubPipelineInfos | ConvertTo-Json -Depth $MAX_JSON_DEPTH | Write-Output
  }
  else {
    [string]$output = $gitHubPipelineInfos | ConvertTo-Json -Depth $MAX_JSON_DEPTH -Compress
    Write-Host "##vso[task.setvariable variable=$ADOOutputVariableName;isoutput=true]$output"
  }

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

