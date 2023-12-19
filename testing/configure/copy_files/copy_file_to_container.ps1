# .\copy_file_to_container.ps1 -LocalFilePath "C:\path\to\your\file.zip"

param(
    [Parameter(Mandatory=$true)]
    [string]$LocalFilePath
)

# Upload file to the blob container
az storage blob upload `
    --container-name $ContainerName `
    --file $LocalFilePath `
    --name (Split-Path $LocalFilePath -Leaf) `
    --account-name $StorageAccountName `
    --account-key $StorageAccountKey