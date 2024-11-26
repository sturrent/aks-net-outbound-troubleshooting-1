# aks-net-outbound-troubleshooting-1

This repository provides a bicep template to deploy an AKS cluster scenario for AKS outbound network troubleshoting.
This will setup an AKS cluster, PostgresQL flexiserver, and workload running on AKS that connects to the database.

Clone the repo, go to the directory, and run:

```plain-text
az deployment sub create --name <DEPLOYMENT_NAME> -l <LOCATION> --template-file main.bicep
```

Note: Currently all files are referencing southcentralus location, but it can be change using params.
