class PipelineInfo {
  [string]$Organization
  [string]$Project
  [string]$Branch
  [string]$Id
  [string]$Name
  [string]$Description
  [string]$ServiceConnection
  [string]$AdoPath
  [string]$YamlPath
  [int]$QueueId
  [string]$RepoName
  [string]$RepoType
  [string]$RepoUrl
  [bool]$Enabled
  [PipelineVariableInfo[]]$Variables
}

class PipelineVariableInfo {
  [string]$Name
  [bool]$AllowOverride
  [bool]$IsSecret
  [string]$Value
}
