# epr-migration-automation

The "EPR Migration Automation" provides pipelines, templates and scripts used to automate the migration of EPR from ADO repos to GitHub repos.

The migration automation does not support Type 1 (xaml based) pipelines.

## Prerequisites

- [pwsh 7.3](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.3)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
- [Azure Devops Extension for Azure CLI](https://learn.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)
- [VSCode](https://code.visualstudio.com/)
  - Git Extension Pack
  - PowerShell
  - YAML
  - Azure CLI Tools
  - Markdown All in One
  - markdownlint

## Setup

### ADO

Before the automation can work, certain permissions need assigned to the "Collection Build Service (org)" account.  Details are in the [ADO Configuration guide](./docs/adoconfiguration.md).

### GitHub

Before the automation can work, the "Azure DevOps Pipelines" app needs installed on the GitHub repo.  Details are in the [GitHub Configuration guide](./docs/githubconfiguration.md).

### Development

Local development of pipelines is nigh impossible because the pipeline yaml cannot be validated nor run locally.  Use standard branching and pull requests and run the most appropriate test pipelines for the changes being made.

Pwsh scripts can be developed locally.  Make sure to create an ADO PAT with suitable permissions and set the `AZURE_DEVOPS_EXT_PAT` environment variable.

```pwsh
$ENV:AZURE_DEVOPS_EXT_PAT='your-pat'
```

### Test

With the main pipeline being pretty heavy, there are multiple test pipelines available to use.  The yaml files for these are in the `.azuredevops` folder.  Simply create the pipeline in ADO and use the existing yaml file.

## Licence

THIS INFORMATION IS LICENSED UNDER THE CONDITIONS OF THE OPEN GOVERNMENT LICENCE found at:

<http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3>

The following attribution statement MUST be cited in your products and applications when using this information.

> Contains public sector information licensed under the Open Government license v3

### About the licence

The Open Government Licence (OGL) was developed by the Controller of Her Majesty's Stationery Office (HMSO) to enable information providers in the public sector to license the use and re-use of their information under a common open licence.

It is designed to encourage use and re-use of information freely and flexibly, with only a few conditions.
