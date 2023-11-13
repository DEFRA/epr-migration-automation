Set-StrictMode -Version 3.0
Set-Variable -Option ReadOnly -Name MAX_JSON_DEPTH -Value 99 -Scope global -Force -Whatif:$false

function Add-PipelineVariables {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineInfo]$Pipeline,
    [switch]$PassThru,
    [switch]$Force
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:PassThru=$PassThru"
    Write-Debug "${functionName}:begin:Force=$Force"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    if ($null -eq $Pipeline.Variables -or $Force) {
      Write-Debug "${functionName}:process:fetching pipeline variables for $($Pipeline.Name)"
      $Pipeline.Variables = @(Get-PipelineVariable -Pipeline $Pipeline.Name)
    }
    else {
      Write-Debug "${functionName}:process:Pipeline $($Pipeline.Name) already has associated variables."
    }

    if ($PassThru) {
      Write-Output $Pipeline
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}

function ConvertTo-Boolean (
  [Parameter(ValueFromPipeline)]
  $InputObject,
  [bool]$Default = $false
)
{
  [string]$functionName = $MyInvocation.MyCommand
  Write-Debug "${functionName}:start"

  [bool]$result = $Default

  if ($null -ne $InputObject) {
    [string]$trimmedValue = $InputObject.ToString().Trim()
    Write-Debug "${functionName}:trimmedValue=$trimmedValue"
    
    if (-not [bool]::TryParse($trimmedValue, [ref]$result)) {
      switch ($trimmedValue) {
        "1"        { $result = $true;  break; }
        "0"        { $result = $false; break; }
        "-1"       { $result = $true;  break; }
        "true"     { $result = $true;  break; }
        "false"    { $result = $false; break; }
        "enabled"  { $result = $true;  break; }
        "disabled" { $result = $false; break; }
        "yes"      { $result = $true;  break; }
        "no"       { $result = $false; break; }
        "on"       { $result = $true;  break; }
        "off"      { $result = $false; break; }
      }
    }
  }

  Write-Debug "${functionName}:returning $result"
  Write-Output $result
  Write-Debug "${functionName}:start"
}

function ConvertTo-PipelineInfo {
  param(
    [Parameter(ValueFromPipeline)]
    [PSCustomObject]$InputObject,
    [string]$OrganizationUrl,
    [string]$Project
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:OrganizationUrl=$OrganizationUrl"
    Write-Debug "${functionName}:begin:Project=$Project"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    [string]$inputType = $InputObject.GetType().Name
    Write-Debug "${functionName}:process:inputType=$inputType"

    [PipelineInfo]$pipelineInfo = $null

    # note that the order of the type checks matter is the -is operator looks for
    # compatible matches and not exact matches 
    # check pscustomobject last as it matches pretty much everything
    if ($InputObject -is [PipelineInfo]) {
      Write-Debug "${functionName}:process:InputObject is [PipelineInfo]"
      $pipelineInfo = $InputObject
    } 
    elseif ($InputObject -is [PSCustomObject]) {
      Write-Debug "${functionName}:process:InputObject is [PSCustomObject]"

      $pipelineInfo = [PipelineInfo]::new()
      $pipelineInfo.Organization = $OrganizationUrl
      $pipelineInfo.Project = $Project
      $pipelineInfo.Name = $InputObject.name
      $pipelineInfo.Description = $InputObject.Description
      $pipelineInfo.RepoName = $InputObject.repository.name
      $pipelineInfo.RepoType = $InputObject.repository.type
      $pipelineInfo.RepoUrl = $InputObject.repository.url
      $pipelineInfo.Branch = ($InputObject.repository.properties.defaultBranch).Split('/')[-1]
      $pipelineInfo.QueueId =  $InputObject.queue.id
      $pipelineInfo.AdoPath = $InputObject.path
      $pipelineInfo.YamlPath = $InputObject.process.yamlFilename
      $pipelineInfo.Enabled = ConvertTo-Boolean -InputObject $InputObject.queueStatus
    } 
    else {
      Write-Debug "${functionName}:process:InputObject is $inputType" 
      throw [System.ArgumentException]::("Unsupported type $inputType", "InputObject")
    }

    Write-Output $pipelineInfo

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Get-AdoEndpoint {
  param(
    [Parameter(ValueFromPipeline)]
    [string]$Name,
    [string]$OrganizationUrl,
    [string]$Project,
    [switch]$AsHashtable
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:AsHashtable=$AsHashtable"
    Write-Debug "${functionName}:begin:OrganizationUrl=$OrganizationUrl"
    Write-Debug "${functionName}:begin:Project=$Project"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new('az devops service-endpoint list')
    if (-not [string]::IsNullOrWhiteSpace($Project)) {
      [void]$builder.Append(" --project '$Project'")
    }
    [string]$command = $builder.ToString()
    [string]$endpointsJson = Invoke-CommandLine -Command $command 
    [array]$endpoints = $endpointsJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH
    [hashtable]$endpointDictionary = @{}
    foreach($endpoint in $endpoints) {
      Write-Debug "${functionName}:begin:adding $($endpoint.serviceEndpointProjectReferences.name) to master dictionary"
      $endpointDictionary.Add($endpoint.serviceEndpointProjectReferences.name, $endpoint)
    }
    [bool]$returnAll = $true
    [array]$matches = @()
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Name=$Name"

    if (-not [string]::IsNullOrEmpty($Name)) {
      $returnAll = $false
      Write-Debug "${functionName}:process:checking for $Name"
      if ($endpointDictionary.ContainsKey($Name)) {
        Write-Debug "${functionName}:process:matched $Name"
        $matches.Add($endpointDictionary[$key])
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"

    if ($returnAll) {
      if ($AsHashtable) {
        Write-Debug "${functionName}:end:returning entire master dictionary of $($endpointDictionary.Count) items"
        Write-Output $endpointDictionary
      }
      else {
        Write-Debug "${functionName}:end:returning $($endpointDictionary.Count) values from the master dictionary"
        Write-Output $endpointDictionary.Values
      }
    }
    else {
      if ($AsHashtable) {
        [hashtable]$dictionary = @{}
        foreach($endpoint in $matches) {
          Write-Debug "${functionName}:end:adding $($endpoint.serviceEndpointProjectReferences.name) to the output dictionary"
          $dictionary.Add($endpoint.serviceEndpointProjectReferences.name, $endpoint)
        }
        Write-Debug "${functionName}:end:returning $($dictionary.Count) items"
        Write-Output $dictionary
      }
      else {
        Write-Debug "${functionName}:end:returning $($matches.Count) matches"
        Write-Output $matches
      }
    }

    Write-Debug "${functionName}:end:end"
  }
}

function Get-AdoPipelineModel {
  param(
    [Parameter()]
    [string]$OrganizationUri,
    [Parameter()]
    [string]$Project,
    [Parameter(ValueFromPipeline)]
    [string]$Pipeline,
    [switch]$AsJson,
    [switch]$Summary
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:OrganizationUri=$OrganizationUri"
    Write-Debug "${functionName}:begin:Project=$Project"
    Write-Debug "${functionName}:begin:AsJson=$AsJson"
    Write-Debug "${functionName}:begin:Summary=$Summary"

    [bool]$getAll = $true

    [string]$specificOrgAndProjectPart = $null

    if (-not [string]::IsNullOrWhiteSpace($OrganizationUri) -and -not [string]::IsNullOrWhiteSpace($Project)) {
      $specificOrgAndProjectPart = " --org $OrganizationUri --project $Project "
    } 
    elseif (-not [string]::IsNullOrWhiteSpace($OrganizationUri)) {
      throw [System.ArgumentNullException]::new("Either pass values for both OrganizationUri and Project or neither of them.", "Project")
    } 
    elseif (-not [string]::IsNullOrWhiteSpace($Project)) {
      throw [System.ArgumentNullException]::new("Either pass values for both OrganizationUri and Project or neither of them.", "OrganizationUri")
    }
    else {
      Write-Debug "${functionName}:Not setting default organization and project."
    }
    
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Pipeline=$Pipeline"

    if ([string]::IsNullOrWhiteSpace($Pipeline)) {
      Write-Debug "${functionName}:process:No pipeline(s) specified - will fetch all."
      $getAll = $true
    }
    else {
      $getAll = $false

      [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az pipelines show ")

      [int]$id = 0
      if ([int]::TryParse($Pipeline, [ref]$id)) {
        Write-Debug "${functionName}:process:provided identifier is numeric - assuming id"
        [void]$commandBuilder.Append("--id $pipeline ")
      } 
      else {
        Write-Debug "${functionName}:process:provided identifier is not numeric - assuming name"
        [void]$commandBuilder.Append("--name '$pipeline' ")
      }

      [string]$command = $commandBuilder.ToString()
      Write-Verbose "Fetching details for pipeline $pipeline"
      [string]$pipelinesJson = Invoke-CommandLine -Command $command -SuppressOutputDebug

      if ($AsJson) {
        Write-Debug "${functionName}:process:return json string"
        Write-Output $pipelinesJson
      }
      else {
        Write-Debug "${functionName}:process:return objects"
        $pipelinesJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"

    if ($getAll) {
      Write-Verbose "Listing all pipelines"
      [string]$command = "az pipelines list $specificOrgAndProjectPart"
      [string]$allPipelinesJson = Invoke-CommandLine -Command $command -SuppressOutputDebug

      Write-Debug "${functionName}:end:allPipelinesJson=$allPipelinesJson"
      [array]$pipelineSummaries = @($allPipelinesJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH)

      if ($Summary) {
        Write-Verbose "Fetching summary information for $($pipelineSummaries.Length) pipelines."
        Write-Output $pipelineSummaries
      }
      else {
        Write-Verbose "Fetching details for $($pipelineSummaries.Length) pipelines. "
        [array]$pipelineDetail = @($pipelineSummaries | Select-Object -ExpandProperty id `
                                                      | Sort-Object -Unique `
                                                      | Get-AdoPipelineModel -OrganizationUri $OrganizationUri -Project $Project -AsJson:$AsJson
        )
        
        if ($AsJson) {
          # Need to rebuild the json because the pipeline details array contains multiple indepentant blocks of json and 
          # the output of this function needs to be one large block of json with all the information.
          # Easiest way is to convert to objects and then back to json
          [string]$rebuiltJson = $pipelineDetail | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | ConvertTo-Json -Depth $MAX_JSON_DEPTH
          
          # Facepalm: Cannot safely send to the debug stream as it may contain ##vso statements and the debug stream is erronously processed by the ADO agents
          #Write-Debug "${functionName}:end:rebuiltJson=$rebuiltJson"
          Write-Output $rebuiltJson
        }
        else {
          Write-Output $pipelineDetail
        }
      }

      Write-Verbose "Information for $($pipelineSummaries.Length) pipelines obtained."
    }
    else {
      Write-Debug "${functionName}:end:Specific pipeline(s) named - not fetching all"
    }

    Write-Debug "${functionName}:end:end"
  }
}


function Get-PipelineVariable {
  param(
    [Parameter(ValueFromPipeline)]
    [string]$Name,
    [string]$PipelineName,
    [switch]$AsHashtable
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:PipelineName=$PipelineName"
    Write-Debug "${functionName}:begin:AsHashtable=$AsHashtable"
    [hashtable]$pipelineVariablesDictionary = @{}
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Name=$Name"

    [string]$command = "az pipelines variable list --pipeline-name '$PipelineName'"

    [string]$variablesJson = Invoke-CommandLine -Command $command
    Write-Debug "${functionName}:process:variablesJson=$variablesJson"

    [hashtable]$adoVariablesDictionary = $variablesJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH -AsHashtable

    if ($null -ne $adoVariablesDictionary -and $adoVariablesDictionary.Count -gt 0) {
      Write-Debug "${functionName}:process:pipeline $PipelineName has $($adoVariablesDictionary.Count) variables"

      if (-not [string]::IsNullOrWhiteSpace($Name)) {
        if ($adoVariablesDictionary.ContainsKey($Name)) {
          $entry = $adoVariablesDictionary[$Name]
  
          [PipelineVariableInfo]$variableInfo = [PipelineVariableInfo]::new()
          $variableInfo.Name = $Name
          $variableInfo.AllowOverride = ConvertTo-Boolean -InputObject $entry.allowOverride
          $variableInfo.IsSecret = ConvertTo-Boolean -InputObject $entry.isSecret
          $variableInfo.Value = ConvertTo-Boolean -InputObject $entry.value
  
          Write-Debug "${functionName}:process:adding $Name"
          $pipelineVariablesDictionary.Add($Name, $variableInfo)
        }
        else {
          Write-Debug "${functionName}:process:variable $Name not found"
        }
      }    
      else {
        Write-Debug "${functionName}:process:returning all variables for $PipelineName"

        foreach($key in $adoVariablesDictionary.Keys) {
          Write-Debug "${functionName}:process:key=$key"
          $entry = $adoVariablesDictionary[$key]
  
          [PipelineVariableInfo]$variableInfo = [PipelineVariableInfo]::new()
          $variableInfo.Name = $key
          $variableInfo.AllowOverride = ConvertTo-Boolean -InputObject $entry['allowOverride']
          $variableInfo.IsSecret = ConvertTo-Boolean -InputObject $entry['isSecret']
          $variableInfo.Value = $entry['value']
    
          $pipelineVariablesDictionary.Add($key, $variableInfo)
          Write-Debug "${functionName}:process:adding $key"
        }
      }
    }
    else {
      Write-Debug "${functionName}:process:no variables for $PipelineName"
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    if ($AsHashtable) {
      Write-Debug "${functionName}:process:returning as hashtable"
      Write-Output $pipelineVariablesDictionary
    }
    else {
      Write-Debug "${functionName}:process:returning as values"
      write-output $pipelineVariablesDictionary.Values
    }
    Write-Debug "${functionName}:end:end"
  }
}


function Get-AzCliExtension {
  param(
    [Parameter(ValueFromPipeline)]
    [string]$Name
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    
    [array]$soughtExtensions = @()
    [string]$command = "az extension list"
    [string]$extensionJson = Invoke-CommandLine -Command $command
    [array]$extensions = $extensionJson | ConvertFrom-Json
    Write-Debug "${functionName}:begin:extensionJson=$extensionJson"
    Write-Debug "${functionName}:begin:extensions.Length=$($extensions.Length)"

    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Name=$Name"
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
      $soughtExtensions += $Name.Trim()
    }
    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"

    if ($soughtExtensions.Length -gt 0) {
      Write-Debug "${functionName}:process:Searching for specific extensions ..."
      $extensions | Where-Object -FilterScript { $soughtExtensions.Contains($_.Name) } | Write-Output
    }
    else {
      Write-Debug "${functionName}:process:Returning all extensions."
      Write-Output $extensions
    }

    Write-Debug "${functionName}:end:end"
  }
}

function Install-AzCliExtension {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [string]$Name
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    [array]$installedExtensionNames = @()
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Name=$Name"

    Write-Verbose "Installing $extensionName ..."
    [string]$command = "az extension add --name $Name"
    [string]$output = Invoke-CommandLine -Command $command
    Write-Verbose $output
    $installedExtensionNames += $Name
    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    $installedExtensionNames | Get-AzCliExtension | Write-Output
    Write-Debug "${functionName}:end:end"
  }
}


function Initialize-AdoCli {
  param(
    [Parameter()]
    [string]$OrganizationUri,
    [Parameter()]
    [string]$Project,
    [Parameter()]
    [string]$AccessToken
  )  

  [string]$functionName = $MyInvocation.MyCommand
  Write-Debug "${functionName}:start"
  Write-Debug "${functionName}:OrganizationUri=$OrganizationUri"
  Write-Debug "${functionName}:Project=$Project"

  [string]$adoExtensionName = "azure-devops"
  Write-Debug "${functionName}:adoExtensionName=$adoExtensionName"
  
  if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
    $ENV:AZURE_DEVOPS_EXT_PAT = $AccessToken
    Write-Verbose "Setting AZURE_DEVOPS_EXT_PAT environment variable."
  }
  else {
    Write-Debug "${functionName}:AccessToken not set - checking environment for AZURE_DEVOPS_EXT_PAT"
  }

  if ([string]::IsNullOrWhiteSpace($ENV:AZURE_DEVOPS_EXT_PAT)) {
    throw [System.ArgumentException]::new("Either set the environment variable AZURE_DEVOPS_EXT_PAT or supply the AccessToken parameter", "AccessToken")
  }

  if (-not (Test-AzCliExtension -Name $adoExtensionName)) {
    Write-Verbose "Installing az cli extension $adoExtensionName."
    Install-AzCliExtension -Name $adoExtensionName | Out-Null
    Write-Verbose "az cli extension $adoExtensionName installed."
  }
  else {
    Write-Verbose "az cli extension $adoExtensionName already installed."
  }


  if (-not [string]::IsNullOrWhiteSpace($OrganizationUri) -and -not [string]::IsNullOrWhiteSpace($Project)) {
    Write-Verbose "Setting default organization and project to $OrganizationUri and $Project"
    [string]$command = "az devops configure --defaults organization=$OrganizationUri project=$Project"
    Invoke-CommandLine -Command $command | Out-Null
  } 
  elseif (-not [string]::IsNullOrWhiteSpace($OrganizationUri)) {
    throw [System.ArgumentNullException]::new("Either pass values for both OrganizationUri and Project or neither of them.", "Project")
  } 
  elseif (-not [string]::IsNullOrWhiteSpace($Project)) {
    throw [System.ArgumentNullException]::new("Either pass values for both OrganizationUri and Project or neither of them.", "OrganizationUri")
  }
  else {
    Write-Debug "${functionName}:Not setting default organization and project."
  }

  Write-Debug "${functionName}:end"
}


function Invoke-CommandLine {
  param(
      [Parameter(Mandatory)]
      [string]$Command,
      [switch]$IsSensitive,
      [switch]$IgnoreErrorCode,
      [switch]$ReturnExitCode,
      [switch]$SuppressOutputDebug
  )

  [string]$functionName = $MyInvocation.MyCommand
  Write-Debug "${functionName}:start"
  Write-Debug "${functionName}:IsSensitive=$IsSensitive"
  Write-Debug "${functionName}:IgnoreErrorCode=$IgnoreErrorCode"
  Write-Debug "${functionName}:ReturnExitCode=$ReturnExitCode"

  if ($IsSensitive) {
      Write-Debug "${functionName}:Command=<hidden>"
  } 
  else {
      Write-Debug "${functionName}:Command=$Command"
  }

  [string]$errorMessage = ""
  [string]$warningMessage = ""
  [string]$outputMessage = ""
  [string]$informationMessage = ""

  [string]$output = Invoke-Expression -Command $Command -ErrorVariable errorMessage -WarningVariable warningMessage -OutVariable outputMessage -InformationVariable informationMessage 
  [int]$errCode = $LASTEXITCODE

  if (-not $SuppressOutputDebug) {
    Write-Debug "${functionName}:output=$output"
  }
  Write-Debug "${functionName}:errCode=$errCode"

  if (-not [string]::IsNullOrWhiteSpace($outputMessage)) { 
      Write-Debug "${functionName}:outputMessage=$outputMessage"
      Write-Verbose $outputMessage 
  }

  if (-not [string]::IsNullOrWhiteSpace($informationMessage)) { 
      Write-Debug "${functionName}:informationMessage=$informationMessage"
      Write-Verbose $informationMessage 
  }

  if (-not [string]::IsNullOrWhiteSpace($warningMessage)) {
      Write-Debug "${functionName}:warningMessage=$warningMessage"
      Write-Warning $warningMessage 
  }

  if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
      Write-Debug "${functionName}:errorMessage=$errorMessage"
      Write-Verbose $errorMessage
      Write-Error $errorMessage
      throw "$errorMessage"
  }

  if ($errCode -ne 0 -and -not $IgnoreErrorCode) {
      throw "unexpected exit code $errCode"
  }

  if ($ReturnExitCode) {
      Write-Output $errCode
  }
  else {
      Write-Output $output
  }
  Write-Debug "${functionName}:end"
}

function New-AdoPipeline {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineInfo]$Pipeline,
    [Parameter()]
    [hashtable]$EndpointDictionary = (Get-AdoEndpoint -AsHashtable),
    [switch]$AsJson
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Project=$Project"
    Write-Debug "${functionName}:begin:AsJson=$AsJson"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [string]$serviceConnection = $null

    if ($EndpointDictionary.ContainsKey($Pipeline.ServiceConnection)) {
      $endpoint = $EndpointDictionary[$Pipeline.ServiceConnection]
      $serviceConnection = $endpoint.id
      Write-Debug "${functionName}:process:endpoint.id=$($endpoint.id)"
    }
    else {
      $serviceConnection = $Pipeline.ServiceConnection
      Write-Warning "Endpoint '$serviceConnection' not found in dictionary."
    }

    [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az pipelines create ")
    
    [void]$commandBuilder.Append(" --skip-first-run true ")
    [void]$commandBuilder.Append(" --name '$($Pipeline.Name)' ")
    [void]$commandBuilder.Append(" --queue-id '$($Pipeline.QueueId)' ")
    [void]$commandBuilder.Append(" --folder-path '$($Pipeline.AdoPath)' ")
    [void]$commandBuilder.Append(" --repository-type '$($Pipeline.RepoType)' ")
    [void]$commandBuilder.Append(" --yaml-path '$($Pipeline.YamlPath)' ")

    if (-not [string]::IsNullOrWhiteSpace($Pipeline.Organization)) {
      [void]$commandBuilder.Append(" --org '$($Pipeline.Organization)' ")
    }

    if (-not [string]::IsNullOrWhiteSpace($Pipeline.Project)) {
      [void]$commandBuilder.Append(" --project '$($Pipeline.Project)' ")
    }

    if (-not [string]::IsNullOrWhiteSpace($Pipeline.Branch)) {
      [void]$commandBuilder.Append(" --branch '$($Pipeline.Branch)' ")
    }

    if (-not [string]::IsNullOrWhiteSpace($Pipeline.Description)) {
      [void]$commandBuilder.Append(" --description '$($Pipeline.Description)' ")
    }

    if (-not [string]::IsNullOrWhiteSpace($Pipeline.ServiceConnection)) {
      [void]$commandBuilder.Append(" --repository '$($Pipeline.ServiceConnection)/$($Pipeline.RepoName)' ")
      [void]$commandBuilder.Append(" --service-connection '$serviceConnection' ")
    }
    else {
      [void]$commandBuilder.Append(" --repository '$($Pipeline.RepoName)' ")
    }
    
    [string]$command = $commandBuilder.ToString()
    Write-Verbose "Creating pipeline $($Pipeline.Name)"

    if ($PSCmdlet.ShouldProcess("Creating pipeline $($Pipeline.Name)")) {

      [string]$pipelinesJson = Invoke-CommandLine -Command $command 

      if ($AsJson) {
        Write-Debug "${functionName}:process:return json string"
        Write-Output $pipelinesJson
      }
      else {
        Write-Debug "${functionName}:process:return objects"
        $pipelinesJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function New-AdoPipelineVariable {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$PipelineName,
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineVariableInfo]$VariableInfo,
    [switch]$SuppressSecret
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:PipelineName=$PipelineName"
    Write-Debug "${functionName}:begin:SuppressSecret=$SuppressSecret"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [string]$value = [string]::IsNullOrEmpty($($VariableInfo.Value)) ? "(null)" : $VariableInfo.Value
    Write-Debug "${functionName}:process:VariableInfo.Name=$VariableInfo.Name"
    Write-Debug "${functionName}:process:value=$value"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az pipelines variable create ")
    [void]$builder.Append(" --pipeline-name '$PipelineName'")
    [void]$builder.Append(" --name '$($VariableInfo.Name)'")
    [void]$builder.Append(" --secret $($VariableInfo.IsSecret) ")
    [void]$builder.Append(" --allow-override $($VariableInfo.AllowOverride) ")
    if ($VariableInfo.IsSecret -and -not $SuppressSecret) {
      Write-Debug "${functionName}:process:SuppressSecret switch is active.  Value will be null."
    }
    else {
      [void]$builder.Append(" --value '$value' ")
    }

    [string]$command = $builder.ToString()
    Write-Debug "${functionName}:process:command=$command"
    if ($PSCmdlet.ShouldProcess($command)) {
      [string]$jsonResponse = Invoke-CommandLine -Command $command -ReturnExitCode
      Write-Debug "${functionName}:process:jsonResponse=$jsonResponse"

      $jsonResponse | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}

function Remove-AdoPipelineVariable {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$PipelineName,
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineVariableInfo]$VariableInfo
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:PipelineName=$PipelineName"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az pipelines variable delete --yes ")
    [void]$builder.Append(" --pipeline-name '$PipelineName'")
    [void]$builder.Append(" --name '$($VariableInfo.Name)'")

    [string]$command = $builder.ToString()
    Write-Debug "${functionName}:process:command=$command"
    if ($PSCmdlet.ShouldProcess($command)) {
      [int]$exitCode = Invoke-CommandLine -Command $command -ReturnExitCode
      Write-Debug "${functionName}:process:exitCode=$exitCode"
  
      if ($exitCode -ne 0) {
        throw "az pipelines command returned non-zero exit code $exitCode"
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Set-AdoPipeline {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineInfo]$Pipeline,
    [Parameter()]
    [hashtable]$EndpointDictionary,
    [switch]$AsJson
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Project=$Project"
    Write-Debug "${functionName}:begin:AsJson=$AsJson"
    [hashtable]$endpoints = $EndpointDictionary
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    if (Test-AdoPipeline -InputObject $Pipeline) {
  
      $pipelineModel = Get-AdoPipelineModel -Pipeline $Pipeline.Name
      
      [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az pipelines update ")
    
      [void]$commandBuilder.Append(" --id '$($pipelineModel.id)' ")
      [void]$commandBuilder.Append(" --branch '$($Pipeline.Branch)' ")
      [void]$commandBuilder.Append(" --new-folder-path '$($Pipeline.AdoPath)' ")
      [void]$commandBuilder.Append(" --queue-id '$($Pipeline.QueueId)' ")
      [void]$commandBuilder.Append(" --yaml-path '$($Pipeline.YamlPath)' ")
  
      if (-not [string]::IsNullOrWhiteSpace($Pipeline.Organization)) {
        [void]$commandBuilder.Append(" --org '$($Pipeline.Organization)' ")
      }
  
      if (-not [string]::IsNullOrWhiteSpace($Pipeline.Project)) {
        [void]$commandBuilder.Append(" --project '$($Pipeline.Project)' ")
      }

      if (-not [string]::IsNullOrWhiteSpace($Pipeline.Description)) {
        [void]$commandBuilder.Append(" --description '$($Pipeline.Description)' ")
      }
  
      [string]$command = $commandBuilder.ToString()
      Write-Verbose "Updating pipeline $($Pipeline.Name)"
  
      if ($PSCmdlet.ShouldProcess("Updating pipeline $($Pipeline.Name)")) {
  
        [string]$pipelinesJson = Invoke-CommandLine -Command $command 
  
        if ($AsJson) {
          Write-Debug "${functionName}:process:return json string"
          Write-Output $pipelinesJson
        }
        else {
          Write-Debug "${functionName}:process:return objects"
          $pipelinesJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
        }
      }

    }
    else {
      if ($null -eq $endpoints) {
        Write-Debug "${functionName}:process:first use of endpoints - creating dictionary"
        $endPoints = Get-AdoEndpoint -AsHashtable
      }
      New-AdoPipeline -Pipeline $Pipeline -EndpointDictionary $endPoints -AsJson:$AsJson | Write-Output
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Set-AdoPipelineVariable {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$PipelineName,
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineVariableInfo]$VariableInfo,
    [switch]$SuppressSecret
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:PipelineName=$PipelineName"
    Write-Debug "${functionName}:begin:SuppressSecret=$SuppressSecret"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [string]$value = [string]::IsNullOrEmpty($($VariableInfo.Value)) ? "(null)" : $VariableInfo.Value
    Write-Debug "${functionName}:process:VariableInfo.Name=$VariableInfo.Name"
    Write-Debug "${functionName}:process:value=$value"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az pipelines variable update ")
    [void]$builder.Append(" --pipeline-name '$PipelineName'")
    [void]$builder.Append(" --name '$($VariableInfo.Name)'")
    [void]$builder.Append(" --secret $($VariableInfo.IsSecret) ")
    [void]$builder.Append(" --allow-override $($VariableInfo.AllowOverride) ")

    if ($VariableInfo.IsSecret -and -not $SuppressSecret) {
      Write-Debug "${functionName}:process:SuppressSecret switch is active.  Value will be null."
    }
    else {
      [void]$builder.Append(" --value '$value' ")
    }

    [string]$command = $builder.ToString()
    Write-Debug "${functionName}:process:command=$command"
    if ($PSCmdlet.ShouldProcess($command)) {
      [string]$jsonResponse = Invoke-CommandLine -Command $command -ReturnExitCode
      Write-Debug "${functionName}:process:jsonResponse=$jsonResponse"

      $jsonResponse | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}

function Sync-AdoPipelineVariables {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineInfo]$Pipeline
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Pipeline.Name=$($Pipeline.Name)"

    [hashtable]$existingVariables = Get-PipelineVariable -PipelineName $Pipeline.Name -AsHashtable
    [array]$variablesToCreate = @()
    [array]$variablesToUpdate = @()
    [array]$variablesToDelete = @()

    Write-Debug "Previously $($existingVariables.Count) variables associated with $($Pipeline.Name)"

    if ($null -eq $Pipeline.Variables -or $Pipeline.Variables.Count -eq 0) {
      Write-Debug "Now no variables associated with $($Pipeline.Name)"
      $variablesToDelete += @($existingVariables.Values)
      Write-Debug "$($variablesToDelete.Count) existing variables to delete on pipeline $($Pipeline.Name)"
    }
    else {
      [array]$variableNamesInUse = @()
      Write-Debug "Now $($Pipeline.Variables.Count) variables associated with $($Pipeline.Name)"

      foreach($entry in $Pipeline.Variables){

        if ($existingVariables.ContainsKey($entry.Name)) {
          Write-Debug "$($entry.Name) needs updated"
          $variablesToUpdate += $entry
          $variableNamesInUse += $entry.Name
        }
        else {
          Write-Debug "$($entry.Name) needs added"
          $variablesToCreate += $entry
          $variableNamesInUse += $entry.Name
        }
      }

      foreach($key in $existingVariables.Keys) {
        if (-not $variableNamesInUse.Contains($key) ) {
          Write-Debug "$($entry.Name) needs removed"
          $variablesToDelete += $existingVariables[$key]
        }
      }
    }

    $variablesToDelete | Remove-AdoPipelineVariable -PipelineName $Pipeline.Name | Out-Null
    $variablesToUpdate | Set-AdoPipelineVariable -PipelineName $Pipeline.Name -SuppressSecret | Write-Output
    $variablesToCreate | New-AdoPipelineVariable -PipelineName $Pipeline.Name -SuppressSecret | Write-Output

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Test-AzCliExtension {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [string]$Name
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    [array]$soughtExtensions = @()
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Name=$Name"
    $soughtExtensions += $Name.Trim()
    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"

    [array]$extensions = @($soughtExtensions | Get-AzCliExtension)
    [bool]$result = ($extensions.Length -gt 0)

    Write-Debug "${functionName}:end:result=$result"
    Write-Output $result

    Write-Debug "${functionName}:end:end"
  }
}

function Test-AdoPipeline {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    $InputObject
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [string]$pipelineName = $null

    if ($InputObject -is [PipelineInfo]) {
      Write-Debug "${functionName}:process:InputObject is [PipelineInfo]"
      $pipelineName = $InputObject.Name
    } 
    elseif ($InputObject -is [hashtable]) {
      Write-Debug "${functionName}:process:InputObject is [PSCustomObject]"
      $pipelineName = $InputObject['name']
    } 
    elseif ($InputObject -is [PSCustomObject]) {
      Write-Debug "${functionName}:process:InputObject is [PSCustomObject]"
      $pipelineName = $InputObject.name
    } 
    else {
      Write-Debug "${functionName}:process:InputObject is $inputType" 
      throw [System.ArgumentException]::("Unsupported type $inputType", "InputObject")
    }

    Write-Debug "${functionName}:process:pipelineName=$pipelineName"
    [string]$command = "az pipelines show --name '$pipelineName'"

    Write-Debug "${functionName}:process:command=$command"
    [int]$exitCode = Invoke-CommandLine -Command $command -ReturnExitCode -IgnoreErrorCode
    Write-Debug "${functionName}:process:exitCode=$exitCode"

    [bool]$exists = ($exitCode -eq 0)
    Write-Debug "${functionName}:process:exists=$exists"

    Write-Output $exists

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}
