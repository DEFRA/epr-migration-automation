[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$OrganizationUri,
    [Parameter(Mandatory)]
    [string]$Project,
    [Parameter()]
    [string]$InputJson = "",
    [Parameter()]
    [string]$OutputPath,
    [Parameter()]
    [string]$SecretsCountAdoVariableName,
    [Parameter()]
    [string]$SecretsReportPath,
    [Parameter()]
    [switch]$Force,
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
Write-Debug "${functionName}:InputJson=$InputJson"
Write-Debug "${functionName}:OutputPath=$OutputPath"
Write-Debug "${functionName}:SecretsReportPath=$SecretsReportPath"

[System.IO.DirectoryInfo]$scriptDir = $PSCommandPath | Split-Path -Parent
Write-Debug "${functionName}:scriptDir.FullName=$($scriptDir.FullName)"

try {
  [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $scriptDir.FullName -ChildPath "modules/ADO2GitHubMigration"
  Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"

  if ([string]::IsNullOrWhiteSpace($InputJson)) {
    Write-Warning "There is no input data to process"
  }
  else {
    Import-Module $moduleDir.FullName -Force

    Initialize-AdoCli -OrganizationUri $OrganizationUri -Project $Project -AccessToken $AccessToken

    [array]$pipelinesToProcess = @($InputJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH)

    Write-Host "Details of $($pipelinesToProcess.Length) pipelines supplied"
    
    if ($pipelinesToProcess.Count -eq 0) {
      Write-Warning "There are no pipelines to process"
    }
    else {
      Write-Debug "${functionName}:Resolving endpoints"
      [hashtable]$endpoints = Get-AdoEndpoint -AsHashtable
      Write-Debug "${functionName}:Updating pipelines"
      [array]$processedPipelines = @($pipelinesToProcess | Set-AdoPipeline -EndpointDictionary $endpoints)
      Write-Debug "${functionName}:Updating pipeline variables"
      [array]$processedVariables = @($pipelinesToProcess | Sync-AdoPipelineVariables)

      [array]$outputs = @()
      if ($processedPipelines.Count -gt 0) {
        $outputs += @($processedPipelines)
      }
      if ($processedVariables.Count -gt 0) {
        $outputs += @($processedVariables)
      }

      if ($null -ne $outputs -and $outputs.Count -gt 0) {
        Write-Debug "${functionName}:Setting outputs ($($outputs.Count))"

        if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
          Write-Debug "${functionName}:Outputting to $($outputFile.FullName)"
          [System.IO.FileInfo]$outputFile = $OutputPath
          $outputs | ConvertTo-Json -Depth $MAX_JSON_DEPTH | Set-Content -Path $outputFile.FullName -Force 
          Write-Host "Output file $($outputFile.FullName) created."
        }
        else {
          Write-Debug "${functionName}:Outputting to Write-Output"
          $outputs | ConvertTo-Json -Depth $MAX_JSON_DEPTH | Write-Output
        }
      }
      else {
        Write-Warning "no updates performed"
      }

      if (-not [string]::IsNullOrWhiteSpace($SecretsReportPath)) {
        Write-Debug "${functionName}:Pipeline variable secret report requested"
        [System.IO.FileInfo]$secretsReportFile = $SecretsReportPath

        if ($secretsReportFile.Exists -and -not $Force) {
          throw "$($secretsReportFile.FullName) already exists and -Force was not specified."
        }

        if (-not $secretsReportFile.Directory.Exists) {
          Write-Debug "${functionName}:Creating directory $($secretsReportFile.Directory.FullName)"
          $secretsReportFile.Directory.Create()
        }

        [array]$secrets = @($processedVariables | Where-Object -FilterScript { $_.IsSecret })
        Write-Debug "${functionName}:There are $($secrets.Count) pipeline secret pipeline variables."
        
        if ($secrets.Count -gt 0) {
          Write-Debug "${functionName}:Generating report file $($secretsReportFile.FullName)"
          $secrets | Select-Object -Property @('PipelineName', 'Name') `
                   | Sort-Object -Property PipelineName `
                   | ConvertTo-Csv `
                   | Set-Content -Path $secretsReportFile.FullName -Force:$Force
        }

        if (-not [string]::IsNullOrWhiteSpace($SecretsCountAdoVariableName)) {
          Write-Debug "${functionName}:Updating $SecretsCountAdoVariableName"
          Write-Host "##vso[task.setvariable variable=$SecretsCountAdoVariableName;isoutput=true]$($secrets.Count)"
        }
      }
      else {
        Write-Debug "${functionName}:Not reporting on pipeline secrets"
      }
    }
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
