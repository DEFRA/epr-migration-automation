# ADO Configuration

## Agent Pools

The "Project Collection Build Service" needs to be able to see the agent pools.

Project Settings -> Agent Pools -> Security

Grant "Project Collection Build Service (org name)" User permissions.

## Service Connections

The "Project Collection Build Service" needs to be able to see the service connections.

Project Settings -> Agent Pools -> Service connections -> ... -> Security

Grant "Project Collection Build Service (org name)" User permissions.

## Pipelines

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
