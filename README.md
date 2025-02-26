# Azure DevOps Repository Backup
The idea was to create a simple tool, to help keep anything stored in Azure DevOps repositories backed up outside of DevOps.
DevOps repositories are quite safe for storing data (if DevOps is configured correctly), but other factors can come into play.

But if a codebase is somehow affected by for instance a Supply-Chain Attack, with code injected and committed by malicious attackers and this isn't caught in time,
it can be necessary to go further back than DevOps's builtin 30 days.
Relying on developer devices for backup shouldn't be the solution.

This is where this solution attempts to help, by easily backing up DevOps repositories to a place outside DevOps.
Like on an Azure Storage Account as blobs, where another regular backup system can also pick it up, for example for legal-hold, using Azure Backup, Veeam and others.

The script does the following:

- Exporting repositories as ZIP files from all or specific projects, provided the identity has access to it.
- Uploading exported files to Azure Storage Account as blobs - You choose storage tier and further backup/archiving from there.

The script is built to be run automatically and scheduled, like from an Azure Automation Runbook or Scheduled Tasks in Windows, if this is the prefered method.
It can ofcourse also be run manually from PowerShell, VSCode or similar.

# How does this solution differentiate from others?
This solution is a simple single PowerShell script, so it's easy to check the content of the source.

This solution:

- Downloads a ZIP file with correct folder structure and files
Others download a ZIP file and a metadata file, extract/combine and ZIP it again.
Not only does this take a long time, on large repositories, it can also make it difficult to run in i.e. Azure Automation, due to the limited disk space available.

- Takes a single repository and branch at a time, downloads and uploads to Storage Account, before continuing. This again limits the required disk space, while running.
Other solutions download and keep everything local, which limits execution possibilities.

- Is built to run in Azure Automation and utilize managed identities in Azure.
Other solutions still rely on Personal Access Tokens (PAT), which then again requires safekeeping and maintenance. I do have the functions to use PAT and retrieving it from Azure Key Vault, which is available on request.

# Documentation
Please visit the [Wiki](../../wiki/) for suggestions on how to use it.

This includes both how to run in manually and automatically/scheduled using Azure Automation.

The TL;DR for deploment in Azure Automation is:
1. Create an Azure Automation account with system- or user- assigned identity.
2. Create an Azure Storage Account for Blob storage and a container for backups.
    - Grant 'Storage Blob Data Contributor' access to the Automation identity on the container.
3. Add the Automation identity to DevOps and grant it Contributor access to individual projects or Project Collection Administrator
4. In the Automation account, create a PowerShell 7.x+ Runbook and paste the PowerShell script in.
5. Edit the $AzureDevOpsOrganization, $storageAccountName and $containerName with values from steps 1 & 2.
    - Change $ProjectsInScope to only include single projects to starts with.
6. Save and start the Runbook 
7. Schedule the Runbook, to run as you see fit.
8. Verify data ends up in the storage account and the ZIP files works and contain the expected.
