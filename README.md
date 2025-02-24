# About the project
The idea was to create a simple tool, to help keep anything stored in Azure DevOps repositories backed up outside of DevOps.
DevOps repositories are quite safe for storing data (if DevOps is configured correctly), but other factors can come into play.

But if a codebase is somehow affected by for instance a Supply-Chain Attack, with code injected and committed by malicious attackers and this isn't caught in time,
it can be necessary to go further back than DevOps's builtin 30 days.
Relying on developer devices for backup should be the solution.

This is where this solution attempts to help, but easily backing up DevOps repositories to a place outside DevOps.

Like on an Azure Storage Account as blobs, where another regular backup system can also pick it up, for example for legal-hold, using Azure Backup, Veeam and others.

The script does the following:

- Exporting repositories as ZIP files from all or specific projects, provided the identity has access to it.
- Uploading exported files to Azure Storage Account as blobs - You choose storage tier and further backup/archiving from there.

The script is built to be run automatically and scheduled, like from an Azure Automation Runbook or Scheduled Tasks in Windows, if this is the prefered method.
It can ofcourse also be run manually from PowerShell, VSCode or similar.
