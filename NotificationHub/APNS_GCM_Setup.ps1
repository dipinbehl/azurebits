param(
    [Parameter(Mandatory = $True, HelpMessage="Name of the Azure subscription under which the Notification Hub is created")]
    [string]
    $subscriptionName,
	
	[Parameter(Mandatory = $True, HelpMessage="Name of the resource group under which the Notification Hub is created")]
    [string]
    $resourceGroup,

    [Parameter(Mandatory = $True, HelpMessage="Name of the Notification Hub Namespace under which the Notification Hub is created")]
    [string]
    $ANHNamespace,
	
	[Parameter(Mandatory = $True, HelpMessage="Name of the Azure Notification Hub")]
    [string]
    $ANHName,
	
	[Parameter(HelpMessage="Endpoint to be used while pusing to Google Cloud Messaging service")]
    [string]
    $gcmEndpoint = "https://android.googleapis.com/gcm/send",
	
	[Parameter(HelpMessage="API Key to be used to push to Google Cloud Messaging service")]
    [string]
    $gcmAPIKey,
	
	[Parameter(HelpMessage="Environment (production/sandbox) to be used for Azure Push Notification service")]
	[string]
    $apnsEnvironment = "sandbox",
	
	[Parameter(HelpMessage="Path of the psk/p12 certificate file to authenticate with Apple Push Notification service")]
	[string]
    $apnsCertificatePath,
	
	[Parameter(HelpMessage="Private key associate with the certificate file to authenticate with Apple Push Notification service")]
    [string]
    $apnsCertificateKey,
	
	[Parameter(HelpMessage="Team Id of the account to authenticate with Apple Push Notification Service")]
	[string]
	$apnsAppId,
	
	[Parameter(HelpMessage="Name of the iOS app to push the notification to via Apple Push Notification service")]
	[string]
	$apnsAppName,
	
	[Parameter(HelpMessage="Key Id of the token key to authenticate with Apple Push Notification service")]
	[string]
	$apnsKeyId,
	
	[Parameter(HelpMessage="Token to authenticate with Apple Push Notification service")]
	[string]
	$apnsToken
)

#Interactive login for user
Connect-AzureRmAccount -Subscription $subscriptionName

#Getting the instance for notification hub
$notificationHubInstance = Get-AzureRmNotificationHub -ResourceGroup $resourceGroup -Namespace $ANHNamespace -NotificationHub $ANHName

if(-not ([string]::IsNullOrEmpty($gcmAPIKey)))
{
	$notificationHubInstance.GcmCredential = New-Object Microsoft.Azure.Management.NotificationHubs.Models.GcmCredential -Property @{GcmEndpoint = $gcmEndpoint; GoogleApiKey = $gcmAPIKey}
	Write-Output "Added GCM credentials to Notification Hub `"$ANHNamespace/$ANHName`" in resource group `"$resourceGroup`" `n"
}
else
{
	Write-Output "Google API Key not provided. Not updating GCM credentials for Notification Hub `"$ANHNamespace/$ANHName`" in resource group `"$resourceGroup`" `n"
}

if((-not ([string]::IsNullOrEmpty($apnsCertificatePath))) -and (-not ([string]::IsNullOrEmpty($apnsCertificateKey))))
{
	$certPath = [System.IO.Path]::GetFullPath($apnsCertificatePath)
	
	if(-not [System.IO.File]::Exists($certPath))
	{
		Write-Error "APNS certificate was not found at $apnsCertificatePath `n"
		return
	}
	
	$endpoint = "gateway$(if($apnsEnvironment.ToLower() -eq 'production') {''} else {'.sandbox'}).push.apple.com"
	$certBytes = get-content $certPath -Encoding Byte
	$certString = [System.Convert]::ToBase64String($certBytes)
	
	$notificationHubInstance.ApnsCredential = New-Object Microsoft.Azure.Management.NotificationHubs.Models.ApnsCredential -Property @{ApnsCertificate = $certString; CertificateKey = $apnsCertificateKey; Endpoint = $endpoint}
	
	Write-Output "Added APNS certificate credentials to Notification Hub `"$ANHNamespace/$ANHName`" in resource group `"$resourceGroup`" `n"
}
else 
{
	Write-Output "APNS certificate-key pair not provided. Checking for APNS token credentials `n"
	
	if((-not ([string]::IsNullOrEmpty($apnsAppId))) -and (-not ([string]::IsNullOrEmpty($apnsAppName))) -and (-not ([string]::IsNullOrEmpty($apnsKeyId))) -and (-not ([string]::IsNullOrEmpty($apnsToken))))
	{
		$endpoint = "gateway$(if($apnsEnvironment.ToLower() -eq 'production') {''} else {'.sandbox'}).push.apple.com"
	
		$notificationHubInstance.ApnsCredential = New-Object Microsoft.Azure.Management.NotificationHubs.Models.ApnsCredential -Property @{AppId = $apnsAppId; AppName = $apnsAppName; KeyId = $apnsKeyId; Token = $apnsToken; Endpoint = $endpoint}
		
		Write-Output "Added APNS token credentials to Notification Hub `"$ANHNamespace/$ANHName`" in resource group `"$resourceGroup`" `n"
	}
	else
	{
		Write-Output "APNS token credentials details not provided. Not updating APNS credentials for Notification Hub `"$ANHNamespace/$ANHName`" in resource group `"$resourceGroup`" `n"
	}
}

Write-Output "Updating Notification Hub `"$ANHNamespace/$ANHName`" in resource group `"$resourceGroup`" of subscription `"$subscriptionName`" `n"
Set-AzureRmNotificationHub -Namespace $ANHNamespace -ResourceGroup $resourceGroup -NotificationHubObj $notificationHubInstance -Force