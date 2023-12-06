[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)]
  [string]$Path,
  [Parameter()]
  [string]$EnvVarPrefix = "MIGRATED_"
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

Write-Debug "${functionName}:Path=$Path"
Write-Debug "${functionName}:EnvVarPrefix=$EnvVarPrefix"

[System.IO.DirectoryInfo]$scriptDir = $PSCommandPath | Split-Path -Parent
Write-Debug "${functionName}:scriptDir.FullName=$($scriptDir.FullName)"


function Format-StateData {
  param(
    [Parameter(Mandatory,ValueFromPipeline)]
    $InputObject
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    [hashtable]$dictionary = @{}
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    Write-Debug "${functionName}:process:formatting $($InputObject.SourceAdoRepo)"
    [System.Collections.Specialized.OrderedDictionary]$stateData = @{}
    $stateData['SourceAdoRepo'] = $InputObject.SourceAdoRepo
    $stateData['TargetGitHubRepo'] = $InputObject.TargetGitHubRepo
    $stateData['Action'] = $InputObject.Action
    $stateData['Memo'] = $InputObject.Memo

    $dictionary.Add($InputObject.TargetGitHubRepo, $stateData)
    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:sorting output by target"
    [array]$keys = $dictionary.Keys | Sort-Object 

    foreach($key in $keys) {
      Write-Output $dictionary[$key]
    }
    Write-Debug "${functionName}:end:end"
  }
}


try {

  dir ENV: | ForEach-Object -Process { Write-Debug "${functionName}:ENV:$($_.Key)='$($_.Value)'" }

  [System.IO.FileInfo]$stateFile = $Path
  Write-Debug "${functionName}:stateFile.FullName=$($stateFile.FullName)"
  [array]$stateModel = Get-Content -Path $stateFile.FullName | ConvertFrom-Json 
  
  Write-Debug "${functionName}:Loaded model, creating dictionary"

  [hashtable]$stateDictionary = @{}
  foreach($stateItem in $stateModel.repos) {
    [string]$key = $stateItem.SourceAdoRepo
    Write-Debug "${functionName}:key=$key"
    $stateDictionary.Add($key, $stateItem)
  }

  Write-Debug "${functionName}:Check environment variables"

  [array]$envVars = @(dir ENV:$EnvVarPrefix*)
  Write-Debug "${functionName}:Found $($envVars.Count) items to process"

  if ($envVars.Count -gt 0) {
    [array]$stateChangeModel = @($envVars.Value | ConvertFrom-Json)

    foreach($changedItem in $stateChangeModel) {
      [string]$key = $changedItem.SourceAdoRepo
      Write-Debug "${functionName}:key=$key"

      if ($stateDictionary.ContainsKey($key)) {
        Write-Debug "${functionName}:Updating $key with '$($changedItem.Action)' and '$($changedItem.Memo)'"
        $stateItem = $stateDictionary[$key]
        $stateItem.Memo = $changedItem.Memo
        $stateItem.Action = $changedItem.Action
      }
      else {
        Write-Warning "State entry missing for '$($changedItem.SourceAdoRepo)'"
      }
    }
  }

  [System.Collections.Specialized.OrderedDictionary]$newModel = @{}
  $newModel['gitHubOrganization'] = $stateModel.gitHubOrganization
  $newModel['githubServiceConnection'] = $stateModel.githubServiceConnection
  $newModel['teamProject'] = $stateModel.teamProject
  $newModel['repos'] = @($stateModel.Repos | Format-StateData)

  if ($PSCmdlet.ShouldProcess("Updating state file $($stateFile.FullName)")) {
    Write-Host "Updating $($stateFile.FullName)"
    $newModel | ConvertTo-Json | Set-Content -Path $stateFile.FullName -Force -PassThru | Write-Output
  }
  else {
    $newModel | ConvertTo-Json | Write-Output 
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
