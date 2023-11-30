[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$OrganizationUri,
    [Parameter(Mandatory)]
    [string]$Project,
    [Parameter(Mandatory)]
    [string]$Repo,
    [Parameter(Mandatory)]
    [ValidateSet('Abandoned','Active')]
    [string]$State,
    [Parameter()]
    [int]$PullRequestId = 0,
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

Set-Variable -Name ErrorActionPreference -Value Continue -scope global -Whatif:$false
Set-Variable -Name VerbosePreference -Value Continue -Scope global -Whatif:$false

if ($enableDebug) {
    Set-Variable -Name DebugPreference -Value Continue -Scope global -Whatif:$false
    Set-Variable -Name InformationPreference -Value Continue -Scope global -Whatif:$false
}

Write-Debug "${functionName}:OrganizationUri=$OrganizationUri"
Write-Debug "${functionName}:Project=$Project"
Write-Debug "${functionName}:Repo=$Repo"
Write-Debug "${functionName}:PullRequestId=$PullRequestId"
Write-Debug "${functionName}:State=$State"

[System.IO.DirectoryInfo]$scriptDir = $PSCommandPath | Split-Path -Parent
Write-Debug "${functionName}:scriptDir.FullName=$scriptDir.FullName"

try {
  [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $scriptDir.FullName -ChildPath "modules/ADO2GitHubMigration"
  Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"

  Import-Module $moduleDir.FullName -Force

  Initialize-AdoCli -OrganizationUri $OrganizationUri -Project $Project -AccessToken $AccessToken

  [array]$pullRequests = @(Get-AdoPullRequest -Repo $Repo -PullRequestId $PullRequestId -Status active)

  if ($null -eq $pullRequests -or $pullRequests.Count -eq 0) {
    if ($PullRequestId -eq 0) {
        Write-Host "Repo $Repo has no active pull requests."
    }
    else {
        Write-Host "Pull request $PullRequestId not found."
    }
  }
  else {
    if ($PullRequestId -eq 0) {
        Write-Host "Repo $Repo has $($pullRequests.Count) active pull requests."
    }
    else {
        Write-Host "Pull request $PullRequestId found."
    }
    
    $pullRequests | Select-Object -ExpandProperty pullRequestId | Set-AdoPullRequestState -State $State | Out-Null
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
