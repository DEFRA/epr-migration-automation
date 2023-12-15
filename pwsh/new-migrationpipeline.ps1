[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$TemplatePath = (Join-Path -Path $PSScriptRoot -ChildPath '../.azuredevops/migrate.yaml.template'),
    [Parameter()]
    [string]$StatePath = (Join-Path -Path $PSScriptRoot -ChildPath '../migration-state.json'),
    [Parameter()]
    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath '../.azuredevops/migrate-generated.yaml'),
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
    Write-Debug "${functionName}:process:InputObject.Action=$($InputObject.Action)"

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


function ConvertTo-Parameter {
  param(
    [Parameter(Mandatory,ValueFromPipeline)]
    [hashtable]$InputObject
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    [System.Collections.ArrayList]$paramEntryOrder = @('name', 'displayName', 'type', 'default')
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    [string]$inputType = $InputObject.GetType().Name
    Write-Debug "${functionName}:process:inputType=$inputType"
    Write-Debug "${functionName}:process:InputObject.name=$($InputObject.name)"

    [hashtable]$paramDictionary = @{}
    foreach($key in $InputObject.Keys) {
      Write-Debug "${functionName}:process:key=$key"
      $paramDictionary.Add($key, $InputObject[$key])
    }

    [System.Collections.Specialized.OrderedDictionary]$parameter = @{}
    foreach($entryName in $paramEntryOrder) {
      Write-Debug "${functionName}:process:entryName=$entryName"
      if ($paramDictionary.ContainsKey($entryName)) {
        $parameter[$entryName] = $paramDictionary[$entryName]
        $paramDictionary.Remove($entryName)
      }
    }

    foreach($key in $paramDictionary.Keys) {
      Write-Debug "${functionName}:process:key=$key"
      $parameter[$key] = $paramDictionary[$key]
    }

    Write-Debug "${functionName}:process:parameter.Count=$($parameter.Count)"
    
    Write-Output $parameter
  
    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}

function ConvertTo-Variable {
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
    Write-Debug "${functionName}:process:InputObject.name=$($InputObject.name)"
    Write-Debug "${functionName}:process:InputObject.value=$($InputObject.value)"

    [System.Collections.Specialized.OrderedDictionary]$variable = @{}
    $variable['name'] = $InputObject.name
    $variable['value'] = $InputObject.value

    Write-Output $variable
  
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
    throw [System.IO.FileNotFoundException]::new($stateFile.FullName)
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


  [array]$reservedKeys = @('trigger', 'pr', 'parameters', 'variables', 'resources', 'extends')
  [System.Collections.Specialized.OrderedDictionary]$newModel = [System.Collections.Specialized.OrderedDictionary]@{}
  $newModel['trigger'] = $model.trigger
  $newModel['pr'] = $model.pr

  Write-Debug "${functionName}:Building parameters"
  [array]$parameters = $model.parameters | ConvertTo-Parameter
  $newModel['parameters'] = $parameters
  $migrationDataParam = $parameters | Where-Object -FilterScript { $_['name'] -eq "MigrationData" }

  Write-Debug "${functionName}:Building migration data"

  $migrationDataParam['default'] = @($state.repos | ConvertTo-MigrationData)

  Write-Debug "${functionName}:Building variables"
  $newModel['variables'] = $model.variables | ConvertTo-Variable

  Write-Debug "${functionName}:Processing 'other' entries"

  foreach($key in $model.keys) {
    if ($key -notin $reservedKeys) {
      $newModel[$key] = $model.$key
    }
  }

  Write-Debug "${functionName}:Processing resources"

  $model.resources.repositories = @($state.repos | ConvertTo-RepositoryEntry -GitHubServiceConnection $state.GitHubServiceConnection -GitHubOrganization $state.GitHubOrganization -TeamProject $state.TeamProject)
  $newModel['resources'] = $model.resources
  $newModel['extends'] = $model.extends

  Write-Debug "${functionName}:Outputting"

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
