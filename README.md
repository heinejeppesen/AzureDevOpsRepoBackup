# AzureDevOpsRepoBackup
This PowerShell script will help backing up repositories from all or selected projects in Azure DevOps, by having Azure DevOps generate a ZIP file using Azure DevOps REST API. Files can then be safely stored as blobs in an Azure Storage Account container, in a very cheap way.


# What does it do?
The script gets all projects and goes through those projects to find any repositories and branches in each.

For each found repository and branch, Azure DevOps is requested to generate a ZIP file and this file is saved locally, where the script runs.
Once the all repositories and branches have been exported, the script will connect to Azure and upload the files to a storage account, for safekeeping.

Cleaning up old data can be done with Storage Account Data Management / Life-cycle policies (https://learn.microsoft.com/en-us/azure/storage/blobs/lifecycle-management-overview)
Further more you can backup the storage account, if you want/need to keep data stored for legal reasons.




# Disclaimer:
Use at your own risk - Its highly recommended to verify that 
  1) ZIP files are not corrupt
  2) They contain the expected files and folders.



