# Including A New Repo

To add a repo to the list of repos to be sync'd/migrated there are a few steps and potential gotchas.

It is very important that the source and target repo names are the same.

## GitHub

Before updating the pipeline, the source and target repos must already exist.  The resources section of the pipeline will cause the agent to verify the resources are accessable before it begins exection of the steps in the pipeline.  It is therefore important that the repo is properly initialised in GitHub.

## ADO

The pipeline yaml file needs updated to know about the source and target repos and the pipeline will need granted permission to access the new GitHub repo.

### State File

In the root of the repo is a state file `migration-state.json` which holds a json representation of the migration to be performed.  This file is used to generate the pipeline yaml file.

```json
    {
      "SourceAdoRepo": "<Source Repo In Azure DevOps>",
      "TargetGitHubRepo": "<Target Repo In GitHub>",
      "Action": "<ignore|simulate|synchronize|migrate>",
      "Memo": "(Free text note to self - not processed)"
    },
```

#### Action

| Action      | Description |
| ------      | ----------- |
| ignore      | Ignore the entry.  This value is assigned automatically by the automation after it has run in `migrate` mode |
| simulate    | Simulate the migration.  Performs all actions possible without making changes. |
| synchronize | Mirrors the content of the ADO source repo to the GitHub repo and creates ADO pipelines against the GitHub repo |
| migrate     | Performs the one-way trip of migrating the ADO repo to GitHub.  It will lock all branches, sync the contents and pipelines, abandon all pull requests and rename the source repo.  Finally, it will update the state file to mark the repo as "ignore" with a memo of "migrated" |

### Generated Pipeline

After updating the state file, the pipeline yaml needs regenerated.  This is performed by running the `new-migrationpipeline.ps1` script.  The default values to the parameters are set for ease of use but `-Force` is required to make it overwrite an existing file.

1. Open pwsh
1. Change directory to the repo's `pwsh` directory
1. Run the script:

```pwsh
./new-migrationpipeline.ps1 -Force
```

### Resource Permissions

The pipeline needs to be granted access to the new repo.  

The easiest approach is to set the repo as "open".  
Settings -> Repositories -> ...repo... -> ... -> Open Access

If however, the repo is not "open", there are two options

1. Run the pipeline and click Permit for each resource.
2. Settings -> Repositories -> ...repo... -> Pipeline Permissions -> + -> ...pipeline...
