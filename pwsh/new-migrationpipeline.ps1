[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$TemplatePath,
    [Parameter(Mandatory)]
    [string]$StatePath,
    [Parameter(Mandatory)]
    [string]$OutputPath,
    [switch]$Force
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

Write-Debug "${functionName}:TemplatePath=$TemplatePath"
Write-Debug "${functionName}:StatePath=$StatePath"
Write-Debug "${functionName}:OutputPath=$OutputPath"
Write-Debug "${functionName}:Force=$Force"

[System.IO.DirectoryInfo]$scriptDir = $PSCommandPath | Split-Path -Parent
Write-Debug "${functionName}:scriptDir.FullName=$($scriptDir.FullName)"


function ConvertTo-MigrationData {
  param(
    [Parameter(Mandatory,ValueFromPipeline)]
    $InputObject
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    if ($InputObject.Action -ne "ignore") {

      [System.Collections.Specialized.OrderedDictionary]$repoEntry = @{}
      $repoEntry['SourceAdoRepo'] = $InputObject.SourceAdoRepo
      $repoEntry['TargetGitHubRepo'] = $InputObject.TargetGitHubRepo
      $repoEntry['Action'] = $InputObject.Action

      [hashtable]$wrapper = @{ "repo" = $repoEntry}

      Write-Output $wrapper
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function ConvertTo-RepositoryEntry {
  param(
    [Parameter(Mandatory,ValueFromPipeline)]
    $InputObject,
    [Parameter(Mandatory)]
    [string]$GitHubServiceConnection,
    [Parameter(Mandatory)]
    [string]$GitHubOrganization,
    [Parameter(Mandatory)]
    [string]$TeamProject
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:GitHubServiceConnection=$GitHubServiceConnection"
    Write-Debug "${functionName}:begin:GitHubOrganization=$GitHubOrganization"
    Write-Debug "${functionName}:begin:TeamProject=$TeamProject"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    if ($InputObject.Action -ne "ignore") {

      [System.Collections.Specialized.OrderedDictionary]$sourceRepoEntry = @{}
      $sourceRepoEntry['repository'] = $InputObject.SourceAdoRepo
      $sourceRepoEntry['name'] = "$TeamProject/$($InputObject.SourceAdoRepo)"
      $sourceRepoEntry['type'] = 'git'
  
      Write-Output $sourceRepoEntry
  
      [System.Collections.Specialized.OrderedDictionary]$targetRepoEntry = @{}
      $targetRepoEntry['repository'] = "github-$($InputObject.TargetGitHubRepo)"
      $targetRepoEntry['name'] = "$GitHubOrganization/$($InputObject.TargetGitHubRepo)"
      $targetRepoEntry['type'] = 'github'
      $targetRepoEntry['endpoint'] = $GitHubServiceConnection
  
      Write-Output $targetRepoEntry
  
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


try {
  if (@(Get-InstalledModule -Name powershell-yaml -ErrorAction Ignore).Length -eq 0) {
    Write-Debug "${functionName}:Installing powershell-yaml"
    Install-Module -Name powershell-yaml -Force
  }

  Import-Module powershell-yaml -Force
  
  [System.IO.FileInfo]$templateFile = $TemplatePath
  [System.IO.FileInfo]$stateFile = $StatePath
  [System.IO.FileInfo]$outputFile = $OutputPath

  Write-Debug "${functionName}:templateFile.FullName=$($templateFile.FullName)"
  Write-Debug "${functionName}:stateFile.FullName=$($stateFile.FullName)"
  Write-Debug "${functionName}:outputFile.FullName=$($outputFile.FullName)"

  if (-not $templateFile.Exists) {
    throw [System.IO.FileNotFoundException]::new($templateFile.FullName)
  }

  if (-not $stateFile.Exists) {
    throw [System.IO.FileNotFoundException]::new($templateFile.FullName)
  }

  if (-not $outputFile.Directory.Exists) {
    $outputFile.Directory.Create()
  }
  elseif ($outputFile.Exists) {
    if (-not $Force) {
      throw "Target file exists and -Force was not specified. $($outputFile.FullName)"
    }
  } 
  
  $model = Get-Content -Path $templateFile.FullName | ConvertFrom-Yaml
  $state = Get-Content -Path $stateFile.FullName | ConvertFrom-Json

  [hashtable]$migrationDataParam = $model.parameters | Where-Object -FilterScript { $_.name -eq "MigrationData" }
  $migrationDataParam['default'] = @($state.repos | ConvertTo-MigrationData)
  $model.resources.repositories = @($state.repos | ConvertTo-RepositoryEntry -GitHubServiceConnection $state.GitHubServiceConnection -GitHubOrganization $state.GitHubOrganization -TeamProject $state.TeamProject)

  [array]$reservedKeys = @('parameters', 'variables', 'resources', 'extends')

  [System.Collections.Specialized.OrderedDictionary]$newModel = [System.Collections.Specialized.OrderedDictionary]@{}
  $newModel['parameters'] = $model.parameters
  $newModel['variables'] = $model.variables

  foreach($key in $model.keys) {
    if ($key -notin $reservedKeys) {
      $newModel[$key] = $model.$key
    }
  }

  $newModel['resources'] = $model.resources
  $newModel['extends'] = $model.extends

  $newModel | ConvertTo-Yaml | Set-Content -Path $outputFile.FullName -Force:$Force -PassThru | Write-Output 

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
