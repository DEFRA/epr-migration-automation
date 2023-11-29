# Limitations

1. Pipeline variables holding secrets cannot be migrated.  A secret can be created on the target but the value cannot be obtained from the source.  Consequently, secrets need to be updated by hand.

1. Null/empty values are not suppored by the ado cli.  This means that removing a value from source cannot be mirrored to the target.  Instead the literal string "(null)" will be populated into the target.

1. The automation needs to omit the `--value` parameter to the ado cli call when creating or updating an existing variable with a secret.  This preserves the target value for each re-run.

1. Neither the ADO CLI nor REST API have the functionality to disable a repo programatically.  This needs to be done manually after the migration has completed.  Note that it should not be done beforehand as it will prevent the automation from being able to access it.

1. Renaming repos requires the repo to be referenced as a resource as well as doing a "checkout" for that repo.  Otherwise the build account isn't allowed to see it in order to rename it.  This is contrary to the expected behaviour based on the permissions granted to the "Project Collection Build Service (org)" so it's more of a workaround.

1. Cannot use "Project Valid Users" for assigning the Deny permissions to the repo post-migration.
