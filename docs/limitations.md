# Limitations

1. The migration automation does not support Type 1 (xaml based) pipelines.  Only Type 2 (yaml based) pipelines are supported.  Type 1 pipelines will be ignored by the automation.

1. Pipeline variables holding secrets cannot be migrated.  A secret can be created on the target but the value cannot be obtained from the source.  Consequently, secrets need to be updated by hand.

1. Null/empty values are not suppored by the ado cli.  This means that removing a value from source cannot be mirrored to the target.  Instead the literal string "(null)" will be populated into the target.

1. The automation needs to omit the `--value` parameter to the ado cli call when creating or updating an existing variable with a secret.  This preserves the target value for each re-run.

1. Neither the ADO CLI nor REST API have the functionality to disable a repo programatically.  This can be done manually after the migration has completed should disable be desired.  Once disabled, a repo cannot be read so it must not be done beforehand as it will prevent the automation from being able to access it.  Disabling is also not recommended as a short term action after migration.

1. Renaming repos requires the repo to be referenced as a resource as well as doing a "checkout" for that repo.  Otherwise the build account isn't allowed to see it in order to rename it.  This is contrary to the expected behaviour based on the permissions granted to the "Project Collection Build Service (org)" so it's more of a workaround.

1. Cannot use "Project Valid Users" for assigning the Deny permissions to the repo post-migration.

1. Due to [issue 1020](https://github.com/Azure/azure-devops-cli-extension/issues/1020), updating Pipeline Variables needs to use double quotes within single quotes for the value or it will fail.  e.g. `--value '"this is fine"'`.  

1. az pipelines cli does not support disabling pipelines so cannot disable old pipelines.  Delete seems a bit final making rollback much harder so not touching old pipelines.
