<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 [string]
 $resourceGroupLocation,

 [string]
 $deploymentNameMdmi = "mdmi-rt-service",

 [string]
 $deploymentNameTransformation = "transformation-service",

 [string]
 $deploymentNameTerminology = "terminology-service",

 [string]
 $deploymentNameNifi = "nifi",

 [string]
 $deploymentNameNifiSa = "nifisa",

 [string]
 $templateFilePathMdmi = "../templates/azuredeploy-aci-importer-mdmi.json",

 [string]
 $templateFilePathNifi = "../templates/azuredeploy-aci-importer-nifi.json",

 [string]
 $templateFilePathTerminology = "../templates/azuredeploy-aci-importer-terminology.json",
 
 [string]
 $templateFilePathTransformation = "../templates/azuredeploy-aci-importer-transformation.json",

 [string]
 $parametersFilePath = "parameters.json"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# sign in
#Write-Host "Logging in...";
#Login-AzureRmAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.containerinstance");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

$tenantDomain = $tenantInfo.TenantDomain
$aadAuthority = "https://login.microsoftonline.com/${tenantDomain}"

$serviceClientId = (Get-AzureKeyVaultSecret -VaultName "${resourceGroupName}-ts" -Name "${resourceGroupName}-service-client-id").SecretValueText
$serviceClientSecret = (Get-AzureKeyVaultSecret -VaultName "${resourceGroupName}-ts" -Name "${resourceGroupName}-service-client-secret").SecretValueText
#$storageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName "${resourceGroupName}" -AccountName "${deploymentNameNifi}sa").Value[0]
$fhirServerUrl = "https://${resourceGroupName}srvr.azurewebsites.net"

Write-Host "Deploying Nifi";
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentNameNifi -TemplateFile $templateFilePathNifi -aadAuthority $aadAuthority -aadServiceClientId $serviceClientId -aadServiceClientSecret $serviceClientSecret -fhirServerUrl $fhirServerUrl;
Write-Host "Deploying MDMI";
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentNameMdmi -TemplateFile $templateFilePathMdmi;
Write-Host "Deploying Transformation";
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentNameTransformation -TemplateFile $templateFilePathTransformation;
Write-Host "Deploying Terminology";
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentNameTerminology -TemplateFile $templateFilePathTerminology;
