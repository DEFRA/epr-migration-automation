# GitHub Configuration

## Apps

The GitHub App `Azure Pipelines` needs granted access to the target repos.

## Personal Access Token

The [ADO service connection](./adoconfiguration.md#service-connections) used by the migration automation will need more permissions than Grant Authorization will provide.  This means an access token for GitHub will need to be generated.  It requires the following permissions:

`Tokens (classic)`

- admin:repo_hook
- read:org, repo, workflow

The token is shown only once.  If it is lost, it will need regenerated and reassigned to the service connection.

Note that the active permission set is the intersection of the user's permission set and the PAT's permission set.  This means it is vital that the account associated with the token has the `admin` role on **all** the target GitHub repos.
