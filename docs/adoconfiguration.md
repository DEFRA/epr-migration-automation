# ADO Configuration

## Agent Pools

The "Project Collection Build Service" needs to be able to see the agent pools.

Project Settings -> Agent Pools -> Security

Grant "Project Collection Build Service (org name)" User permissions.

## Service Connections

### Normal usage

A service connection with "Grant Authorization" needs created for the normal functionality of being able to use GitHub repos in the pipelines.

### Migration Usage

A service connection with enhanced permissions needs created.  This will use the "Personal Access Token" option.  

An [access token for GitHub](./githubconfiguration.md#personal-access-token) will need generated with the right permissions and assigned to this service connection.

### Build Service Permissions

The "Project Collection Build Service" needs to be able to see the service connections.

Project Settings -> Agent Pools -> Service connections -> ... -> Security

Grant "Project Collection Build Service (org name)" User permissions.

## Variable Group

There is a variable group called DefraGitHub that contains entries relating to the migration.

- GitHubAccessToken - the same access token in the migration service connection
- GitHubOrganizationName - the name of the target GitHub organization
- GitHubServiceConnection - the name of the migration service connection

## Pipelines

The "Project Collection Build Service" needs to be able to manage the pipelines.

Pipelines -> ... -> Manage Security

For "Project Collection Build Service (org name)", allow the following

- Edit build pipelines
- Edit build quality
- Manage build queue
- Override check-in validation by build
- Queue builds
- Update build information
- View build pipeline
- View builds

All but the first one should be there already as "Allow (system)".

## Repos

The "Project Collection Build Service" needs to be able to rename repos.

Settings -> Repositories -> Security

For "Project Collection Build Service (org name)", allow the following

- Bypass Policies when pushing
- Contribute
- Pull Request Contribute
- Manage Permissions
- Rename repository
