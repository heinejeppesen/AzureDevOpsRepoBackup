Set-StrictMode -Version Latest
#if ($PSVersionTable.PSVersion.Major -ne 7)
#{
#    Write-Warning "Please use PowerShell v7.x or above - Entra Graph module doesn't work properly under 5.1"
#    Break
#}

Import-Module az.KeyVault, az.Storage
    # Connect using a Managed Service Identity - Comment out '-Identity' if testing from PowerShell / VSCode etc.
    try {
        #Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Output "No system or user assigned identity found. Aborting." 
        exit
    }



#Azure DevOps organization name
    $AzureDevOpsOrganization = 'betaplace'

#KeyVault information for retrieving Personal Access Token.
    $KeyVaultName = 'kvbetaplace'
    $KeyVaultSecret = 'AzureDevOpsBackup'

#Storage Account Name and container name, where files are to be uploaded in.
    $storageAccountName = "sgLogging"
    $containerName = "devopsbackup"

#This is the naming method used for Azure Storage. This will create a sub container called i.e. 2024-12-31 for a jobs that runs December 31th in 2024.
    $SubcontainerName = $(Get-Date -f yyyy-MM-dd)

#Put repositories into subcontainers for the corresponding project in Azure storage account.
    $UseProjectContainers = $true

#What separates project, repository and branch in the exported filenames.
    $FileNameSeparator = '__'

#DevOps projects to backup repositories in - Add multiple comma separated and set to only 'All' for all projects.
    $ProjectsInScope         = @('Maester','DevOpsTesting')
    #$ProjectsInScope         = @('All')

#Get Azure PAT for access to ALL repositories - Replace method with another that sets $AzureDevOpsPAT with a valid DevOps Personal Access Token.
    $AzureDevOpsPAT = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecret -AsPlainText -ErrorAction SilentlyContinue
    If (!($AzureDevOpsPAT)) {Write-Error "Azure DevOps PAT not returned from $($KeyVaultName) - Error was: $($Error[0].Exception.Message)";return}


#Do not change below here.

    #Header used for REST API calls to Azure DevOps
    $AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }

    #Folder used to create backups into.
    $BackupFolder   = "$($env:Temp)\adoBackup"



# Function to get repositories
Function Get-adoRepositories () {

    $ResourceUri = "https://dev.azure.com/$($AzureDevOpsOrganization)/_apis/git/repositories?api-version=7.0"

    Try {
        $Data = (Invoke-RestMethod -Method Get -Uri $ResourceUri -ContentType "application/json;charset=utf-8" -Headers $AzureDevOpsAuthenicationHeader).value
    }
    Catch {
        Write-Output "Error occured retrieving list of repositories (Get-adoRepositories) - Error message was: $($Error[0].Exception.Message)"
        break
    }

    Return $Data

}



# Function to get branches for a repository
Function Get-adoBranches() {
    param( 
        [Parameter(Mandatory=$true)][string]$RepositoryId
    )

    $ResourceUri = "https://dev.azure.com/$($AzureDevOpsOrganization)/_apis/git/repositories/$($RepositoryId)/refs?filter=heads/&api-version=7.0"

    Try {
        $Data = (Invoke-RestMethod -Method Get -Uri $ResourceUri -ContentType "application/json;charset=utf-8" -Headers $AzureDevOpsAuthenicationHeader).value
    }
    Catch {
        Write-Output "Error occured retrieving list of branches for repository: $($RepositoryId) (Get-adoBranches) - Error message was: $($Error[0].Exception.Message)"
        break
    }

    Return $Data

}

Function New-adoRepoExport() {
        param( 
            [Parameter(Mandatory=$true)][string]$ProjectName,
            [Parameter(Mandatory=$true)][string]$Repository,
            [Parameter(Mandatory=$true)][string]$Branch
        )

    # Get all items in the repository - returns an URI to download a ZIP.


    $apiUrl = "https://dev.azure.com/$($AzureDevOpsOrganization)/$($ProjectName)/_apis/git/repositories/$($Repository)/items?scopePath=/&`$format=zip&versionDescriptor[version]=$($Branch)&api-version=7.1-preview.1"
    
    $BranchName = $Branch.Replace('/','-') # replace any forward slashes in branch names with dash
    $outputFilePath = "$($BackupFolder)\$($ProjectName)$($FileNameSeparator)$($Repository)$($FileNameSeparator)$($BranchName).zip"

    try {
        Invoke-RestMethod -Uri $apiUrl -Headers $AzureDevOpsAuthenicationHeader -Method Get -OutFile $outputFilePath
    }
    catch {
        Write-Output "Error occured retrieving zip copy of Project: $($ProjectName) / Repo: $($Repository) / Branch: $($Branch) (New-adoBackup) - Error message was: $($Error[0].Exception.Message)"
        break
    }

}

Function Invoke-adoBackup() {

    #Create backup folder if it doesn't exist.
    New-Item -ItemType Directory "$($BackupFolder)" -ErrorAction SilentlyContinue | Out-Null
    #Clear any files if being rerun, like on a scheduled task.
    Remove-Item -Path "$($BackupFolder)\*.*"  -Recurse -Force

    #Used for counting number of branches.
    [int]$Script:BranchCount = 0

    $Repositories = Get-adoRepositories
    foreach ($Repo in $Repositories) {

        If ( ($ProjectsInScope -notcontains 'All') -And ($Repo.project.name -notin $ProjectsInScope) ) {
            Write-Verbose "$($Repo.project.name) not in Scope"
            Continue
        }

        $Branches = Get-adoBranches -RepositoryId $Repo.id
        
        foreach ($Branch in $Branches) {
            Write-Output "Starting backup of project: $($Repo.project.name) / Repository: $($repo.Name) / Branch: $($Branch.name.Replace('refs/heads/',''))"
            $BranchName = $($Branch.name.Replace('refs/heads/','')) # get rid of refs/heads
            
            $Script:BranchCount += 1
            
            New-adoRepoExport -ProjectName $Repo.project.name -Repository $repo.Name -Branch $BranchName
        }
    }

    #Count number of files expected to be backed up to storage account
    [int]$Script:FilesCount = @(Get-ChildItem -Path "$($BackupFolder)").Count

}


Function Invoke-BackupToAzureStorage() {

    $Backupfiles = @(Get-ChildItem -Path "$($BackupFolder)")
    If ($Backupfiles.count -eq 0) {
        Write-Output 'No files found to upload to Azure - Aborting.'
        return
    }

    # Create connection context for storage account access, using the account currently signed into Azure (Either user or managed service identity)
    Try {
        $storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
    }
    catch {
        Write-Output "Error occured creating storage context for $($storageAccountName) - Error message was: $($Error[0].Exception.Message)"
        return
    }



    #Upload zip files to Storage Account
    Write-Output ''
    
    If ($Backupfiles.count -eq 0) {
        Write-Output "No files found to backup in $($backupReposFolder) - aborting"
        break
    }
    else {
        Write-Output "Uploading to Azure Storage Account: ($($storageAccountName)) in folder $($containerName)"
        $Backupfiles | ForEach-Object {
            try {
                $currentFile = $_

                #Upload each backup into a seperate folder for the project and remove project name from filename.
                If ($UseProjectContainers -eq $true) {
                    $ProjectContainerName = $_.Name.Split($FileNameSeparator)
                    $containerPath = "$($SubcontainerName)/$($ProjectContainerName[0])/$($ProjectContainerName[1])$($FileNameSeparator)$($ProjectContainerName[2])"
                }
                else{
                    $containerPath = "$($SubcontainerName)/$($currentFile.Name)"
                }
            

                Write-Output "Uploading $($currentFile.Name) to Azure Storage in $($containerPath)"
                Set-AzStorageBlobContent -File $currentFile.FullName -Container $containerName -Blob $containerPath -Context $storageContext -Force | Out-Null
            }
            catch {
              Write-Output "Error occured while uploading: Error message was: $($Error[0])"     
              return
            }        
        }
    }

    #Count number of files in specified storage account
    [int]$Script:StorageAccountFileCount = (Get-AzStorageBlob -Container $ContainerName -Prefix $SubcontainerName  -Context $storageContext).Count

}



Invoke-adoBackup
Invoke-BackupToAzureStorage


Write-Output ''
Write-Output ''
Write-Output "Number of branches found  : $($BranchCount)"
Write-Output "Number of files exported  : $($FilesCount)"
Write-Output "Number of files in Storage: $($StorageAccountFileCount)" 



