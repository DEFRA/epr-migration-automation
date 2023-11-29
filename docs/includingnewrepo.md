# Including A New Repo

To add a repo to the list of repos to be sync'd/migrated there are a few steps and potential gotchas.

It is very important that the source and target repo names are the same.

## GitHub

Before updating the pipeline, the source and target repos must already exist.  The resources section of the pipeline will cause the agent to verify the resources are accessable before it begins exection of the steps in the pipeline.  It is therefore important that the repo is properly initialised in GitHub.

## ADO

The pipeline yaml file needs updated to know about the source and target repos and the pipeline will need granted permission to access the new GitHub repo.

### Pipeline Params/object data

The repo name needs added to the Repos parameter.

```yaml
parameters:
- name: Repos
  displayName: Repos to sync
  type: object
  default: 
    - epr-migration-test1
    - epr-migration-test2
    - epr-migration-automation
```

### Pipeline Resources section

The source and target repos need added to the resources section.

```yaml
resources: 
  repositories:
  # epr-migration-test1
  - repository: ado-epr-migration-test1
    name: RWD-CPR-EPR4P-ADO/epr-migration-test1
    type: git
  - repository: github-epr-migration-test1
    name: defra/epr-migration-test1
    type: github
    endpoint: defra

  # epr-migration-test2
  - repository: ado-epr-migration-test2
    name: RWD-CPR-EPR4P-ADO/epr-migration-test2
    type: git
  - repository: github-epr-migration-test2
    name: defra/epr-migration-test2
    type: github
    endpoint: defra

  # epr-migration-automation
  - repository: ado-epr-migration-automation
    name: RWD-CPR-EPR4P-ADO/epr-migration-automation
    type: git
  - repository: github-epr-migration-automation
    name: defra/epr-migration-automation
    type: github
    endpoint: defra
```

### Resource Permissions

The pipeline needs to be granted access to the new repo.  

The easiest approach is to set the repo as "open".  
Settings -> Repositories -> ...repo... -> ... -> Open Access

If however, the repo is not "open", there are two options

1. Run the pipeline and click Permit for each resource.
2. Settings -> Repositories -> ...repo... -> Pipeline Permissions -> + -> ...pipeline...
