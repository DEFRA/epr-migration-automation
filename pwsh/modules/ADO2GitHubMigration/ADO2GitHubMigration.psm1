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
      $Pipeline.Variables = @(Get-PipelineVariable -PipelineName $Pipeline.Name)
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
      Write-Debug "${functionName}:process:InputObject.name=$($InputObject.name)"
      Write-Debug "${functionName}:process:InputObject.id=$($InputObject.id)"

      $pipelineInfo = [PipelineInfo]::new()
      $pipelineInfo.Organization = $OrganizationUrl
      $pipelineInfo.Project = $Project
      $pipelineInfo.Name = $InputObject.name
      $pipelineInfo.Id = $InputObject.id
      $pipelineInfo.Description = $InputObject.Description
      $pipelineInfo.RepoName = $InputObject.repository.name
      $pipelineInfo.RepoType = $InputObject.repository.type
      $pipelineInfo.RepoUrl = $InputObject.repository.url
      $pipelineInfo.Branch = (Resolve-Property -InputObject $InputObject -Property repository.properties.defaultBranch -Default 'refs/heads/main').Split('/')[-1]
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


function ConvertTo-AdoAcesDictionary {
  param(
    [Parameter(ValueFromPipeline)]
    [PSCustomObject]$InputObject
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    [hashtable]$acesDictionary = @{}
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    [string]$inputType = $InputObject.GetType().Name
    Write-Debug "${functionName}:process:inputType=$inputType"

    [array]$noteProperties = @($InputObject.acesDictionary | Get-Member -MemberType NoteProperty)

    Write-Debug "${functionName}:process:noteProperties.Count=$($noteProperties.Count)"

    if ($noteProperties.Count -ne 1) { throw "Expected one NoteProperty, received $($noteProperties.Count)."}

    [string]$name = $noteProperties[0].Name
    Write-Debug "${functionName}:process:name=$name"

    $acesDictionary.Add($InputObject.token, $InputObject.acesDictionary.$name)

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Output $acesDictionary
    Write-Debug "${functionName}:end:end"
  }
}


function Get-AdoBuild {
  param(
    [Parameter()]
    [string]$OrganizationUri,
    [Parameter()]
    [string]$Project,
    [Parameter(ValueFromPipeline)]
    [int]$Id
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:OrganizationUri=$OrganizationUri"
    Write-Debug "${functionName}:begin:Project=$Project"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Id=$Id"

    [string]$command = "az pipelines build show --id $Id"
    Write-Debug "${functionName}:process:command=$command"

    Invoke-CommandLine -Command $command | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
    
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


function Get-AdoPullRequest {
  param(
    [Parameter(ValueFromPipeline)]
    [int]$PullRequestId,
    [Parameter()]
    [string]$Repo,
    [Parameter()]
    [ValidateSet('active', 'abandoned', 'all', 'completed')]
    [string]$Status = 'all'
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Repo=$Repo"
    Write-Debug "${functionName}:begin:Status=$Status"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:PullRequestId=$PullRequestId"

    if ($PullRequestId -gt 0) {
      [string]$command = "az repos pr show --id '$PullRequestId'"
      Write-Debug "${functionName}:process:command=$command"
      Invoke-CommandLine -Command $command | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
    }
    elseif (-not [String]::IsNullOrWhiteSpace($Repo)) {
      Write-Debug "${functionName}:process:processing all Active PRs in $Repo"

      [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az repos pr list ")
      [void]$commandBuilder.Append(" --repository '$Repo' ")
      [void]$commandBuilder.Append(" --status $Status ")
  
      [string]$command = $commandBuilder.ToString()
      Write-Debug "${functionName}:process:command=$command"

      [array]$pullRequests = @(Invoke-CommandLine -Command $command | ConvertFrom-Json -Depth $MAX_JSON_DEPTH)
     
      Write-Debug "${functionName}:process:there are $($pullRequests.Count) pull requests in $Repo"
      Write-Output $pullRequests
    }
    else {
      throw [System.ArgumentNullException]::new('Repo', 'Either PullRequestId or Repo must have a value.')
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}

function Get-AdoSecurityGroup {
  param(
    [Parameter(ValueFromPipeline)]
    [string]$PrincipalName
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    
    [string]$command = "az devops security group list"
    [string]$securityGroupsJson = Invoke-CommandLine -Command $command
    Write-Debug "${functionName}:begin:securityGroupsJson=$securityGroupsJson"

    $securityGraphs = $securityGroupsJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH

    [hashtable]$securityGroupDictionary = @{}
    [array]$matchedGroups = @()

    foreach($graphGroup in $securityGraphs.graphGroups) {
      $securityGroupDictionary.Add($graphGroup.principalName, $graphGroup)
    }

    Write-Debug "${functionName}:begin:securityGroupDictionary.Count=$($securityGroupDictionary.Count)"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:PrincipalName=$PrincipalName"

    if ([string]::IsNullOrWhiteSpace($PrincipalName)) {
      $matchedGroups += @($securityGroupDictionary.Values)
      Write-Debug "${functionName}:process:matching all $($matchedGroups.Count) items"
    }
    elseif ($securityGroupDictionary.ContainsKey($PrincipalName)) {
      Write-Debug "${functionName}:process:matched $PrincipalName"
      $matchedGroups += $securityGroupDictionary[$PrincipalName]
    }
    else {
      Write-Debug "${functionName}:process:nothing matched $PrincipalName"
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:outputting $($matchedGroups.Count) matches"
    Write-Output $matchedGroups
    Write-Debug "${functionName}:end:end"
  }
}


function Get-AdoSecurityPermission {
  param(
    [Parameter(Mandatory)]
    [string]$NamespaceId,
    [Parameter(Mandatory)]
    [string]$Subject,
    [Parameter(ValueFromPipeline)]
    [string]$Token
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:NamespaceId=$NamespaceId"
    Write-Debug "${functionName}:begin:Subject=$Subject"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Token=$Token"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az devops security permission ")

    if (-not [string]::IsNullOrEmpty($Token)) {
      [void]$builder.Append(" show ")
    }
    else { 
      [void]$builder.Append(" list ")
    }

    [void]$builder.Append(" --id '$NamespaceId' --subject '$Subject' ")

    if (-not [string]::IsNullOrEmpty($Token)) {
      [void]$builder.Append(" --token '$Token' ")
    }

    [string]$command = $builder.ToString()
    [string]$securityPermissionsJson = Invoke-CommandLine -Command $command
    Write-Debug "${functionName}:process:securityPermissionsJson=$securityPermissionsJson"

    $securityPermissionsJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Get-AdoRepo {
  param(
    [Parameter(ValueFromPipeline)]
    [string]$RepoName
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    
    [string]$command = "az repos list"
    [string]$reposJson = Invoke-CommandLine -Command $command
    Write-Debug "${functionName}:begin:reposJson=$reposJson"

    $repos = $reposJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH

    [hashtable]$repoDictionary = @{}
    [array]$matchedRepos = @()

    foreach($repo in $repos) {
      $repoDictionary.Add($repo.name, $repo)
    }

    Write-Debug "${functionName}:begin:repoDictionary.Count=$($repoDictionary.Count)"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:RepoName=$RepoName"

    if ([string]::IsNullOrWhiteSpace($RepoName)) {
      $matchedRepos += @($repoDictionary.Values)
      Write-Debug "${functionName}:process:matching all $($matchedRepos.Count) items"
    }
    elseif ($repoDictionary.ContainsKey($RepoName)) {
      Write-Debug "${functionName}:process:matched $RepoName"
      $matchedRepos += $repoDictionary[$RepoName]
    }
    else {
      Write-Debug "${functionName}:process:nothing matched $RepoName"
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:outputting $($matchedRepos.Count) matches"
    Write-Output $matchedRepos
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
    [array]$extensions = $extensionJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH
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


function Invoke-AdoPipeline {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter()]
    [string]$OrganizationUri,
    [Parameter()]
    [string]$Project,
    [Parameter(Mandatory)]
    $Pipeline,
    [Parameter()]
    [string]$Branch,
    [switch]$Wait,
    [int]$WaitPollInterval = 10,
    [hashtable]$PipelineParameters
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:OrganizationUri=$OrganizationUri"
    Write-Debug "${functionName}:begin:Project=$Project"
    Write-Debug "${functionName}:begin:Wait=$Wait"
    Write-Debug "${functionName}:begin:WaitPollInterval=$WaitPollInterval"

    [int]$id = 0
    [string]$params = $null
    [string]$identityPart = $null

    if ($null -ne $PipelineParameters) {
      [System.Text.StringBuilder]$paramsBuilder = [System.Text.StringBuilder]::new()
      foreach($key in $PipelineParameters.Keys) {
        Write-Debug "${functionName}:begin:key=$key"
        [string]$value = $PipelineParameters[$key]
        Write-Debug "${functionName}:begin:value=$value"
        if ($paramsBuilder.Length -gt 0) {
          [void]$paramsBuilder.Append(",")
        }
        [void]$paramsBuilder.Append("$key=$value")
      }
      $params = $paramsBuilder.ToString()
    }

    if ($Pipeline -is [int]) {
      Write-Debug "${functionName}:process:Pipeline is [int] - will use --id"
      $identityPart = " --id $Pipeline "
    }
    elseif ($Pipeline -is [string]) {
      Write-Debug "${functionName}:process:Pipeline is [string] "
      [int]$id = 0
      if ([int]::TryParse($Pipeline, [ref]$id)) {
        Write-Debug "${functionName}:process:Pipeline is [string] containing number, will use --id"
        $identityPart = " --id $Pipeline "
      }
      else {
        Write-Debug "${functionName}:process:Pipeline is [string] will use --name"
        $identityPart = " --name '$Pipeline' "
      }
    }

    Write-Debug "${functionName}:begin:identityPart=$identityPart"
    Write-Debug "${functionName}:begin:params=$params"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Pipeline=$Pipeline"
    Write-Debug "${functionName}:process:Branch=$Branch"

    [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az pipelines run  $identityPart ")
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
      [void]$commandBuilder.Append(" --branch '$Branch' ")
    }
    if (-not [string]::IsNullOrWhiteSpace($params)) {
      [void]$commandBuilder.Append(" --parameters '$params' ")
    }

    [string]$command = $commandBuilder.ToString()
    Write-Debug "${functionName}:process:command=$command"

    if ($PSCmdlet.ShouldProcess($command)) {
      [string]$runJson = Invoke-CommandLine -Command $command 
      Write-Debug "${functionName}:process:runJson=$runJson"
      $build = $runJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH
      $id = $build.id
      Write-Debug "${functionName}:process:id=$id"
      Write-Verbose "build $id started"

      if ($Wait) {
        Write-Debug "${functionName}:process:will wait for build $id"
      }
      else { 
        Write-Debug "${functionName}:process:started build $id"
        Write-Output $build
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    if ($Wait -and $id -gt 0) {

      [bool]$done = $false
      while(-not $done) {
        Start-Sleep -Seconds $WaitPollInterval
        $build = Get-AdoBuild -Id $id
        Write-Verbose "build $id status $($build.status)"
        Write-Debug "${functionName}:process:build $id status $($build.status)"

        switch ($build.status) {
          "notStarted" {  
            break
          }

          "inProgress" {  
            break
          }

          "completed" {  
            $done = $true
            Write-Output $build
            break
          }
  
          default { 
            $done = $true
            throw "Build failed"
          }
        }
      }
    }
    Write-Debug "${functionName}:end:end"
  }
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


function Get-AdoRepoBranch {
  param(
    [Parameter(ValueFromPipeline)]
    [string]$Branch,
    [Parameter(Mandatory)]
    [string]$Repo
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Repo=$Repo"

    [hashtable]$branchDictionary = @{}
    [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az repos ref list ")
    
    [void]$commandBuilder.Append(" --repository '$Repo' ")

    [string]$command = $commandBuilder.ToString()
    [array]$branches = @(Invoke-CommandLine -Command $command | ConvertFrom-Json -Depth $MAX_JSON_DEPTH)

    if ($branches.Count -gt 0) {
      Write-Debug "${functionName}:begin:$Repo has $($branches.Count) branches."

      foreach($branchItem in $branches) {
        [string]$key = $branchItem.name
        Write-Debug "${functionName}:begin:key=$key"
        $branchDictionary.Add($key, $branchItem)
      }
    }
    else {
      Write-Warning "$Repo has no branches - expected at least 1"
    }

    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:branch=$Branch"

    if ([String]::IsNullOrWhiteSpace($Branch)) {
      # output all the branches
      Write-Debug "${functionName}:process:outputing all branches"
      $branchDictionary.Values | Write-Output
    }
    elseif ($branchDictionary.ContainsKey($Branch)) {
      Write-Debug "${functionName}:process:outputing branch $Branch"
      Write-Output $branchDictionary[$Branch]
    }
    else {
      Write-Warning "${functionName}:process:branch $Branch not found in repo $Repo"
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Lock-AdoRepoBranch {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ValueFromPipeline)]
    [string]$Branch,
    [Parameter(Mandatory)]
    [string]$Repo
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Repo=$Repo"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Branch=$Branch"

    Set-AdoRepoBranchState -Repo $Repo -Branch $Branch -Action lock | Write-Output

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
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
    $Pipeline,
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineVariableInfo]$VariableInfo,
    [switch]$SuppressSecret
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:SuppressSecret=$SuppressSecret"
    [string]$pipelineParam = New-PipelineParamPart -Pipeline $Pipeline
    Write-Debug "${functionName}:begin:pipelineParam=$pipelineParam"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [string]$value = [string]::IsNullOrEmpty($($VariableInfo.Value)) ? "(null)" : $VariableInfo.Value
    Write-Debug "${functionName}:process:VariableInfo.Name=$VariableInfo.Name"
    Write-Debug "${functionName}:process:value=$value"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az pipelines variable create $pipelineParam")
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

function New-PipelineParamPart {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    $Pipeline
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:process:start"

    [string]$inputType = $Pipeline.GetType().Name
    Write-Debug "${functionName}:process:inputType=$inputType"

    [string]$pipelineParam = $null

    if ($Pipeline -is [PipelineInfo]) {
      Write-Debug "${functionName}:process:Pipeline is [PipelineInfo]"
      if ($Pipeline.Id -gt 0) {
        Write-Debug "${functionName}:process:PipelineInfo Id, using --pipeline-id"
        $pipelineParam = " --pipeline-id $($Pipeline.Id) "
      }
      else {
        Write-Debug "${functionName}:process:PipelineInfo has no Id, using --pipeline-name"
        $pipelineParam = " --pipeline-name '$($Pipeline.Name)' "
      }
    }
    elseif ($Pipeline -is [int]) {
      Write-Debug "${functionName}:process:Pipeline is [int] - will use --pipeline-id"
      $pipelineParam = " --pipeline-id $Pipeline "
    }
    elseif ($Pipeline -is [string]) {
      Write-Debug "${functionName}:process:Pipeline is [string] - will use --pipeline-name"
      $pipelineParam = " --pipeline-name '$Pipeline' "
    }
    elseif ($Pipeline -is [hashtable]) {
      Write-Debug "${functionName}:process:Pipeline is [hashtable]"
      if ($Pipeline.ContainsKey('id')) {
        Write-Debug "${functionName}:process:hashtable has id - will use --pipeline-id"
        $pipelineParam = " --pipeline-id $($Pipeline['id']) "
      }
      elseif ($Pipeline.ContainsKey('name')) {
        Write-Debug "${functionName}:process:hashtable has name - will use --pipeline-name"
        $pipelineParam = " --pipeline-name $($Pipeline['name']) "
      }
      else {
        Write-Debug "${functionName}:process:hashtable has neither name nor id"
        throw [System.ArgumentException]::("Invalid [hashtable] - no id or name entry found", "Pipeline")
      }
    }
    elseif ($Pipeline -is [PSCustomObject]) {
      Write-Debug "${functionName}:process:Pipeline is [PSCustomObject]"
      $pipelineParam = " --pipeline-id $($Pipeline.id) "
    }
    else {
      Write-Debug "${functionName}:process:Pipeline is $inputType" 
      throw [System.ArgumentException]::("Unsupported type $inputType", "Pipeline")
    }

    Write-Debug "${functionName}:process:pipelineParam=$pipelineParam"
    Write-Output $pipelineParam

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
    $Pipeline,
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineVariableInfo]$VariableInfo
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    [string]$pipelineParam = New-PipelineParamPart -Pipeline $Pipeline
    Write-Debug "${functionName}:begin:pipelineParam=$pipelineParam"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az pipelines variable delete --yes $pipelineParam")
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


function Resolve-Property {
  param(
    [Parameter(Mandatory)]
    $InputObject,
    [Parameter(Mandatory)]
    [string]$Property,
    [Parameter()]
    $Default = $null
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Property=$Property"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    [string]$inputType = $InputObject.GetType().Name
    Write-Debug "${functionName}:process:inputType=$inputType"

    $result = $Default

    if ($InputObject -is [hashtable]) {
      Write-Debug "${functionName}:process:InputObject is [hashtable]"
      if ($InputObject.ContainsKey($Property)) {
        $result = $InputObject[$Property]
      }
    } 
    elseif ($InputObject -is [PSCustomObject]) {
      Write-Debug "${functionName}:process:InputObject is [PSCustomObject]"
      [System.Collections.Queue]$propertyPartsQueue = [System.Collections.Queue]::new($Property.Split('.'))
      Write-Debug "${functionName}:process:propertyPartsQueue.Count=$($propertyPartsQueue.Count)"

      [string]$currentPropertyName = $propertyPartsQueue.Dequeue()
      [bool]$propertyExists = (Get-Member -InputObject $InputObject -Name $currentPropertyName)
      Write-Debug "${functionName}:process:currentPropertyName=$currentPropertyName"
      Write-Debug "${functionName}:process:propertyExists=$propertyExists"

      if ($propertyExists) {
        $currentItem = $InputObject.$currentPropertyName

        [string]$remaining = $propertyPartsQueue.Count -gt 0 ? $propertyPartsQueue.ToArray() -Join '.' : ""
        Write-Debug "${functionName}:process:remaining=$remaining"
  
        if ([string]::IsNullOrWhiteSpace($remaining)) {
          Write-Debug "${functionName}:process:'$currentPropertyName' resolved"
          $result = $currentItem
        }
        else {
          Write-Debug "${functionName}:process:resolving remaining '$remaining' under '$currentPropertyName'"
          $result = Resolve-Property -InputObject $currentItem -Property $remaining -Default $Default
        }
      }
      else {
        Write-Debug "${functionName}:process:$currentPropertyName not found on InputObject"
      }
    } 
    else {
      Write-Debug "${functionName}:process:InputObject is $inputType" 
      throw [System.ArgumentException]::("Unsupported type $inputType", "InputObject")
    }

    Write-Output $result

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Select-AdoSecurityPermissionDetail {
  param(
    [Parameter(Mandatory)]
    [hashtable]$AcesDictionary,
    [Parameter(Mandatory)]
    [string]$Subject,
    [Parameter(Mandatory)]
    [string]$Token,
    [Parameter(ValueFromPipeline, Mandatory)]
    [string]$Permission
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:AcesDictionary.Count=$($AcesDictionary.Count)"
    Write-Debug "${functionName}:begin:Subject=$Subject"
    Write-Debug "${functionName}:begin:Token=$Token"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Permission=$Permission"

    $acesEntry = $AcesDictionary[$Token]

    if ($null -eq $acesEntry) { throw "Could not find aces entry for $Token" }

    $matchedPermission = $acesEntry.resolvedPermissions | Where-Object -FilterScript { $_.name -eq $Permission -or $_.displayName -eq $Permission }

    if ($null -eq $matchedPermission) {
      Write-Debug "${functionName}:process:Could not match permission $Permission"
    } 
    else {
      Write-Debug "${functionName}:process:Matched permission $Permission"
      Write-Output $matchedPermission
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Set-AdoSecurityPermission {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$SecurityDescriptor,
    [Parameter(Mandatory)]
    [string]$NamespaceId,
    [Parameter(Mandatory)]
    [string]$Token,
    [Parameter(Mandatory)][ValidateSet("Deny","Allow","NotSet")]
    [string]$State,
    [Parameter(ValueFromPipeline, Mandatory)]
    [string]$PermissionBit
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:NamespaceId=$NamespaceId"
    Write-Debug "${functionName}:begin:Token=$Token"
    Write-Debug "${functionName}:begin:SecurityDescriptor=$SecurityDescriptor"
    Write-Debug "${functionName}:begin:PermissionBit=$PermissionBit"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:PermissionBit=$PermissionBit"
    
    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az devops security permission ")

    if ($State -eq "Allow") {
      [void]$builder.Append(" update --allow-bit $PermissionBit ")
    }
    elseif ($State -eq "Deny") {
      [void]$builder.Append(" update --deny-bit $PermissionBit ")
    }
    else {
      [void]$builder.Append(" reset --permission-bit $PermissionBit ")
    }

    [void]$builder.Append(" --token $Token --subject '$SecurityDescriptor' --id $NamespaceId ")

    [string]$command = $builder.ToString()

    if ($PSCmdlet.ShouldProcess($command)) {
      Invoke-CommandLine -Command $command | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Set-AdoRepoBranchState {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ValueFromPipeline)]
    [string]$Branch = '',
    [Parameter(Mandatory)]
    [string]$Repo,
    [Parameter(Mandatory)]
    [ValidateSet('locked','unlocked')]
    [string]$State
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Repo=$Repo"
    Write-Debug "${functionName}:begin:State=$State"

    [string]$action = ($State -eq 'locked') ? 'lock' : 'unlock'

    Write-Debug "${functionName}:begin:action=$action"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    if ([String]::IsNullOrWhiteSpace($Branch)) {
      Write-Debug "${functionName}:process:processing all branches in $Repo"
      [array]$branches = Get-AdoRepoBranch -Repo $Repo 
      Write-Debug "${functionName}:process:processing there are $($branches.Count) branches in $Repo to process"
      $branches | Select-Object -ExpandProperty name | Set-AdoRepoBranchState -Repo $Repo -State $State | Write-Output
      Write-Debug "${functionName}:process:all $($branches.Count) branches in $Repo processed"
    }
    else {
      [string]$branchParam = ($Branch.StartsWith('refs/')) ? $Branch.Substring(5) : $Branch
      Write-Debug "${functionName}:begin:branchParam=$branchParam"

      [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az repos ref $action ")

      [void]$commandBuilder.Append(" --repository '$Repo' ")
      [void]$commandBuilder.Append(" --name '$branchParam' ")

      [string]$command = $commandBuilder.ToString()
      Write-Debug "${functionName}:process:command=$command"

      Write-Verbose "Setting branch '$Branch' on '$Repo' to '$State'"

      if ($PSCmdlet.ShouldProcess("Setting branch '$Branch' on '$Repo' to '$State'")) {
        Invoke-CommandLine -Command $command | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Set-AdoRepoPermission {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$Subject,
    [Parameter(Mandatory)]
    [string]$Permission,
    [Parameter(Mandatory)][ValidateSet("Deny","Allow","NotSet")]
    [string]$State,
    [Parameter(Mandatory,ValueFromPipeline)]
    [string]$RepoName
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Subject=$Subject"
    Write-Debug "${functionName}:begin:Permission=$Permission"
    Write-Debug "${functionName}:begin:State=$State"

    [array]$principalNameParts = $subject.Split('\')
    [string]$principalName = "[$($principalNameParts[0])]\$($principalNameParts[1])"
    [string]$namespaceId = '2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87' # git repos namespace

    Write-Debug "${functionName}:begin:principalName=$principalName"
    Write-Debug "${functionName}:begin:namespaceId=$namespaceId"

    # find the security descriptor for the identity (as that's needed for updating the security)
    $securityGroup = Get-AdoSecurityGroup -PrincipalName $principalName

    if ($null -eq $securityGroup) { throw "could not find security group $principalName" }
  
    [string]$securityDescriptor = $securityGroup.descriptor
    Write-Debug "${functionName}:securityDescriptor=$securityDescriptor"

    # get a list of permissions for the identity 
    $permissionsSummaryModel = Get-AdoSecurityPermission -NamespaceId $namespaceId -Subject $subject

    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:RepoName=$RepoName"
    
    # get the repo list to get the guid for the repo
    $repoInfo = Get-AdoRepo -RepoName $Repo
  
    if ($null -eq $repoInfo) { throw "could not find repo $Repo" }
  
    [string]$repoId = $repoInfo.id
    Write-Debug "${functionName}:repoId=$repoId"
  
    # now filter the list of permissions to the repo we want to change the permissions on
    $permissionSummary = $permissionsSummaryModel | Where-Object -FilterScript { $_.token.EndsWith($repoId) }
  
    if ($null -eq $permissionSummary) { throw "could not find permission entry for $repoId" }
  
    [string]$token = $permissionSummary.token
    Write-Debug "${functionName}:token=$token"
  
    $acesDictionary = Get-AdoSecurityPermission -NamespaceId $namespaceId -Subject $subject -Token $token | ConvertTo-AdoAcesDictionary 
  
    $permissionDetail = Select-AdoSecurityPermissionDetail -AcesDictionary $acesDictionary -Subject $Identity -Token $token -Permission $Permission
  
    if ($null -eq $permissionDetail) { throw "could not find permission $Permission" }
  
    [string]$permissionBit = $permissionDetail.bit
    Write-Debug "${functionName}:permissionBit=$permissionBit"
  
    if ([string]::IsNullOrWhiteSpace($permissionBit)) { throw "permission bit not set" }
  
    Set-AdoSecurityPermission -NamespaceId $namespaceId -SecurityDescriptor $securityDescriptor -Token $token -State $State -PermissionBit $permissionBit | Write-Output

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Set-AdoPullRequestState {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [string]$PullRequestId,
    [Parameter(Mandatory)]
    [ValidateSet('Abandoned','Active')]
    [string]$State
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:State=$State"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:PullRequestId=$PullRequestId"

    [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az repos pr update ")
    [void]$commandBuilder.Append(" --status $State ")
    [void]$commandBuilder.Append(" --id $PullRequestId ")

    [string]$command = $commandBuilder.ToString()
    Write-Debug "${functionName}:process:command=$command"

    Write-Verbose "Setting PR '$PullRequestId' to '$State'"

    if ($PSCmdlet.ShouldProcess("Setting PR '$PullRequestId' to '$State'")) {
      Invoke-CommandLine -Command $command | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
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
    $Pipeline,
    [Parameter(ValueFromPipeline, Mandatory)]
    [PipelineVariableInfo]$VariableInfo,
    [switch]$SuppressSecret
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:SuppressSecret=$SuppressSecret"
    [string]$pipelineParam = New-PipelineParamPart -Pipeline $Pipeline
    Write-Debug "${functionName}:begin:pipelineParam=$pipelineParam"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"

    [string]$value = [string]::IsNullOrEmpty($($VariableInfo.Value)) ? "(null)" : $VariableInfo.Value
    Write-Debug "${functionName}:process:VariableInfo.Name=$VariableInfo.Name"
    Write-Debug "${functionName}:process:value=$value"

    [System.Text.StringBuilder]$builder = [System.Text.StringBuilder]::new("az pipelines variable update $pipelineParam ")
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

function Set-AdoRepoState {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [string]$Repo,
    [string]$Organization,
    [string]$Project,
    [bool]$Enabled
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Enabled=$Enabled"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Repo=$Repo"
     
    [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az repos update ")
  
    [void]$commandBuilder.Append(" --repository '$Repo' ")

    if ($Enabled) {
      [void]$commandBuilder.Append(" --enable ")
    }
    else {
      [void]$commandBuilder.Append(" --disable ")
    }

    if (-not [string]::IsNullOrWhiteSpace($Organization)) {
      [void]$commandBuilder.Append(" --org '$Organization' ")
    }

    if (-not [string]::IsNullOrWhiteSpace($Project)) {
      [void]$commandBuilder.Append(" --project '$Project' ")
    }

    [string]$command = $commandBuilder.ToString()

    [string]$message = $Enabled ? "Enabling repo $Repo" : "Disabling repo $Repo"
    Write-Verbose $message

    if ($PSCmdlet.ShouldProcess($message)) {

      [string]$responseJson = Invoke-CommandLine -Command $command 

      if ($AsJson) {
        Write-Debug "${functionName}:process:return json string"
        Write-Output $responseJson
      }
      else {
        Write-Debug "${functionName}:process:return objects"
        $responseJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}


function Set-AdoRepoName {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$Repo,
    [Parameter(Mandatory)]
    [string]$NewName,
    [string]$Organization,
    [string]$Project,
    [switch]$AsJson
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Project=$Project"
    Write-Debug "${functionName}:begin:Organization=$Organization"
    Write-Debug "${functionName}:begin:AsJson=$AsJson"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:NewName=$NewName"
    Write-Debug "${functionName}:process:Repo=$Repo"
     
    [System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az repos update ")
  
    [void]$commandBuilder.Append(" --repository '$Repo' ")
    [void]$commandBuilder.Append(" --name '$NewName' ")

    if (-not [string]::IsNullOrWhiteSpace($Organization)) {
      [void]$commandBuilder.Append(" --org '$Organization' ")
    }

    if (-not [string]::IsNullOrWhiteSpace($Project)) {
      [void]$commandBuilder.Append(" --project '$Project' ")
    }

    [string]$command = $commandBuilder.ToString()

    [string]$message = "Rename $Repo to $NewName"
    Write-Verbose $message

    if ($PSCmdlet.ShouldProcess($message)) {

      [string]$responseJson = Invoke-CommandLine -Command $command 

      if ($AsJson) {
        Write-Debug "${functionName}:process:return json string"
        Write-Output $responseJson
      }
      else {
        Write-Debug "${functionName}:process:return objects"
        $responseJson | ConvertFrom-Json -Depth $MAX_JSON_DEPTH | Write-Output
      }
    }

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}

function Sync-AdoPipelineVariables {
  [CmdletBinding(SupportsShouldProcess)]
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
    Write-Debug "${functionName}:process:Pipeline.Id=$($Pipeline.Id)"

    if ($PSCmdlet.ShouldProcess("Sync Pipeline Variables")) {

      [hashtable]$existingVariables = Get-PipelineVariable -PipelineName $Pipeline.Name -AsHashtable
      [array]$variablesToCreate = @()
      [array]$variablesToUpdate = @()
      [array]$variablesToDelete = @()

      Write-Debug "${functionName}:process:Previously $($existingVariables.Count) variables associated with $($Pipeline.Name)"

      if ($null -eq $Pipeline.Variables -or $Pipeline.Variables.Count -eq 0) {
        Write-Debug "${functionName}:process:Now no variables associated with $($Pipeline.Name)"
        $variablesToDelete += @($existingVariables.Values)
        Write-Debug "$($variablesToDelete.Count) existing variables to delete on pipeline $($Pipeline.Name)"
      }
      else {
        [array]$variableNamesInUse = @()
        Write-Debug "${functionName}:process:Now $($Pipeline.Variables.Count) variables associated with $($Pipeline.Name)"

        foreach($entry in $Pipeline.Variables){

          if ($existingVariables.ContainsKey($entry.Name)) {
            Write-Debug "${functionName}:process:$($entry.Name) needs updated"
            $variablesToUpdate += $entry
            $variableNamesInUse += $entry.Name
          }
          else {
            Write-Debug "${functionName}:process:$($entry.Name) needs added"
            $variablesToCreate += $entry
            $variableNamesInUse += $entry.Name
          }
        }

        foreach($key in $existingVariables.Keys) {
          if (-not $variableNamesInUse.Contains($key) ) {
            Write-Debug "${functionName}:process:$key needs removed"
            $variablesToDelete += $existingVariables[$key]
          }
        }
      }

      if ($variablesToUpdate.Count -gt 0 -or $variablesToCreate.Count -gt 0 -or $variablesToDelete.Count -gt 0) {
        $pipelineModel = Get-AdoPipelineModel -Pipeline $Pipeline.Name

        $variablesToUpdate | Set-AdoPipelineVariable -Pipeline $pipelineModel -SuppressSecret | Write-Output
        $variablesToCreate | New-AdoPipelineVariable -Pipeline $pipelineModel -SuppressSecret | Write-Output
        $variablesToDelete | Remove-AdoPipelineVariable -Pipeline $pipelineModel | Out-Null
      }
    }

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
    [string]$inputType = $InputObject.GetType().Name
    Write-Debug "${functionName}:process:inputType=$inputType"

    [string]$pipelineName = $null

    if ($InputObject -is [PipelineInfo]) {
      Write-Debug "${functionName}:process:InputObject is [PipelineInfo]"
      $pipelineName = $InputObject.Name
    } 
    elseif ($InputObject -is [hashtable]) {
      Write-Debug "${functionName}:process:InputObject is [hashtable]"
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


function Unlock-AdoRepoBranch {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ValueFromPipeline)]
    [string]$Branch,
    [Parameter(Mandatory)]
    [string]$Repo
  )  

  begin {
    [string]$functionName = $MyInvocation.MyCommand
    Write-Debug "${functionName}:begin:start"
    Write-Debug "${functionName}:begin:Repo=$Repo"
    Write-Debug "${functionName}:begin:end"
  }

  process {
    Write-Debug "${functionName}:process:start"
    Write-Debug "${functionName}:process:Branch=$Branch"

    Set-AdoRepoBranchState -Repo $Repo -Branch $Branch -Action unlock | Write-Output

    Write-Debug "${functionName}:process:end"
  }

  end {
    Write-Debug "${functionName}:end:start"
    Write-Debug "${functionName}:end:end"
  }
}
