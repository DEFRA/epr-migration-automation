# Configuration

## ADO

### Agent Pools

The "Project Collection Build Service" needs to be able to see the agent pools.

Project Settings -> Agent Pools -> Security

Grant "Project Collection Build Service (org name)" User permissions.

### Service Connections

The "Project Collection Build Service" needs to be able to see the service connections.

Project Settings -> Agent Pools -> Service connections -> ... -> Security

Grant "Project Collection Build Service (org name)" User permissions.

### Pipelines

The "Project Collection Build Service" needs to be able to manage the pipelines.

Pipelines -> ... -> Manage Security

For "Project Collection Build Service (org name)", allow the following

- Edit build pipelines
- Edit build quality
- Manage build queue
- Override check-in validation by build
- Update build information
- View build pipeline
- View builds

All but the first one should be there already as "Allow (system)".

# Limitations

1. Pipeline variables holding secrets cannot be migrated.  A secret can be created on the target but the value cannot be obtained from the source.  Consequently, secrets need to be updated by hand.

1. Null/empty values are not suppored by the ado cli.  This means that removing a value from source cannot be mirrored to the target.  Instead the literal string "(null)" will be populated into the target.

1. The automation needs to omit the `--value` parameter to the ado cli call when creating or updating an existing variable with a secret.  This preserves the target value for each re-run.
