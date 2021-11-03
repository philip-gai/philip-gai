# Workflows

| Workflow | Description |
| -------- | --- |
| gh-set-secret.yml | Sets a repo environment secret using the gh cli<br/>You can tell that it works because it masks the `secret_body` in the `echo secret` step 😄<br/>Use of a PAT token is required. Permissions needed: `repo (all)`, `read:org` |
