

$RESOURCE_GROUP_NAME='tfstatesRG'
$STORAGE_ACCOUNT_NAME="tfstates$(get-random)"
$CONTAINER_NAME='tfstatejenkins'

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

#Get the storage access key and store it as an environment variable
$ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv) 
$env:ARM_ACCESS_KEY=$ACCOUNT_KEY

Write-Output "
    resource_group_name  = '$RESOURCE_GROUP_NAME'
    storage_account_name = '$STORAGE_ACCOUNT_NAME'
    container_name       = '$CONTAINER_NAME'
    key                  = 'terraform.tfstate'
    account_key          = '$ACCOUNT_KEY'
" > output.txt