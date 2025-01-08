# About the project
The idea was to create a simple tool, to help keep anything stored in Azure DevOps repositories backed up outside of DevOps
DevOps repositories are safe for storing data (if DevOps is configured correctly), but other factors can come into play.

If codebase is somehow affected by a Supply-Chain Attack, with code injected and committed by malicious attackers and this isn't caught in time,
it can be necessary to go further back than DevOps's builtin 30 days.
And relying on developer devices for backup should be the solution.

This is where this solution attempts to help, but easily backing up DevOps repositories to a place outside DevOps.

Like on an Azure Storage Account as blobs, where another regular backup system can also pick it up, for example for legal-hold, using Azure Backup, Veeam and others.

The script provides:

- Exporting repositories as ZIP files from all or specific projects, provided the Personal Access Token has access to it.
- Uploading exported files to Azure Storage Account as blobs - You choose storage tier and further backup/archiving from there.

The script is built to be run automatically and scheduled, like from an Azure Automation Runbook or Scheduled Tasks in Windows, if this is the prefered method.
It can ofcourse also be run manually from PowerShell, VSCode or similar.

## PowerShell info

The script is tested to work with PowerShell 5.1 and 7+, but support depends on requirements on the Azure modules (Az.KeyVault and Az.Storage) to support current version.
Its highly recommended to use PowerShell 7.x or higher.

The two modules used (Az.KeyVault and Az.Storage) are present on Azure Automation hosts, but must be installed manually (using Install-Module) if running on private host.

Script is currently tested with:

| Module Name | Module Version |
|-------------|----------------|
| Az.Keyvault | 6.3.0 |
| Az.Storage | 8.0.0 |

## How does it work?

For the script to access Azure DevOps, it uses the REST API provided by DevOps.

The script gets all projects and goes through those projects to find any repositories and branches in each.

For each found repository and branch, Azure DevOps is requested to generate a ZIP file and this file is saved locally, where the script runs.
Once the all repositories and branches have been exported, the script will connect to Azure and upload the files to a storage account, for safekeeping.

Cleaning up old data can be done with Storage Account Data Management / Life-cycle policies (https://learn.microsoft.com/en-us/azure/storage/blobs/lifecycle-management-overview)
Further more you can backup the storage account, if you want/need to keep data stored for legal reasons.

## Disclaimer

Use at your own risk.

Its highly recommended to verify that:

  1) ZIP files are not corrupt
  2) They contain the expected files and folders.
  3) The ZIP files can be retrieved and extracted.

As with any backup solution, you should really verify and test backup AND restore.

For a few of the repositories and branches, it can be recommended to synchronize them to a local host.
Then extract the backup of of the same repository/branch
