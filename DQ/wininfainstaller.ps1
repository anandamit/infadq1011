
Param(
  [string]$domainHost,
  [string]$domainName,
  [string]$domainUser,
  [string]$domainPassword,
  [string]$nodeName,
  [int]$nodePort,

  [string]$dbType,
  [string]$dbName,
  [string]$dbUser,
  [string]$dbPassword,
  [string]$dbHost,
  [int]$dbPort,

  [string]$sitekeyKeyword,

  [string]$joinDomain = 0,
  [string]$masterNodeHost,
  [string]$osUserName,
  [string]$infaEdition,

  [string]$storageName,
  [string]$storageKey,
  [string]$infaLicense,
  [string]$mrsdbuser,
  [string]$mrsdbpwd,
  [string]$refdatadbuser,
  [string]$refdatadbpwd,
  [string]$profiledbuser,
  [string]$profiledbpwd
)


#echo $domainHost $domainName $domainUser $domainPassword $nodeName $nodePort $dbType $dbName $dbUser $dbPassword $dbHost $dbPort $sitekeyKeyword $joinDomain $masterNodeHost $osUserName $infaEdition $storageName $storageKey $infaLicense

#Adding Windows firewall inbound rule
echo Adding firewall rules for Informatica domain service ports
netsh  advfirewall firewall add rule name="Informatica_DataQuality" dir=in action=allow profile=any localport=6005-6113 protocol=TCP
netsh  advfirewall firewall add rule name="Informatica_AnalystService" dir=in action=allow profile=any localport=8085-8086 protocol=TCP

$shareName = "infaaeshare"

$infaHome = $env:SystemDrive + "\Informatica\10.1.1"
$installerHome = $env:SystemDrive + "\Informatica\Archive\1011_Server_Installer_winem-64t"
$utilityHome = $env:SystemDrive + "\Informatica\Archive\utilities"

#Setting Java in path
$env:JRE_HOME= $installerHome + "\source\java\jre"
$env:Path=$env:JRE_HOME+"\bin;" + $env:Path

# DB Configurations if required
$dbAddress = $dbHost + ":" + $dbPort

$userInstallDir = $infaHome
$defaultKeyLocation = $infaHome + "\isp\config\keys"
$propertyFile = $installerHome + "\SilentInput.properties"

$infaLicenseFile = ""
$CLOUD_SUPPORT_ENABLE = "1"
if($infaLicense -ne "nolicense" -and $joinDomain -eq 0) {
	$infaLicenseFile = $env:SystemDrive + "\Informatica\license.key"
	echo Getting Informatica license
	wget $infaLicense -OutFile $infaLicenseFile

	if (Test-Path $infaLicenseFile) {
		$CLOUD_SUPPORT_ENABLE = "0"
	} else {
		echo Error downloading license file from URL $infaLicense
	}
}

$createDomain = 1
if($joinDomain -eq 1) {
    $createDomain = 0
    # This is buffer time for master node to start
    Start-Sleep -s 300
} else {
	echo Creating shared directory on Azure storage
    cd $utilityHome
    java -jar iadutility.jar createAzureFileShare -storageaccesskey $storageKey -storagename $storageName
}

$env:USERNAME = $osUserName
$env:USERDOMAIN = $env:COMPUTERNAME

#Mounting azure shared file drive
echo Mounting the shared directory
$cmd = "net use I: \\$storageName.file.core.windows.net\$shareName /u:$storageName $storageKey" 
$cmd | Set-Content "$env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\MountShareDrive.cmd"

runas /user:$osUserName net use I: \\$storageName.file.core.windows.net\$shareName /u:$storageName $storageKey

#Services
$dataaccessstring=$dbHost+"@"+$dbName
$metadataaccessstring="'jdbc:informatica:sqlserver://"+$dbAddress+";SelectMethod=cursor;databaseName="+$dbName+"'"

echo Editing Informatica silent installation file
(gc $propertyFile | %{$_ -replace '^LICENSE_KEY_LOC=.*$',"LICENSE_KEY_LOC=$infaLicenseFile"  `
`
-replace '^CREATE_DOMAIN=.*$',"CREATE_DOMAIN=$createDomain"  `
`
-replace '^JOIN_DOMAIN=.*$',"JOIN_DOMAIN=$joinDomain"  `
`
-replace '^CLOUD_SUPPORT_ENABLE=.*$',"CLOUD_SUPPORT_ENABLE=$CLOUD_SUPPORT_ENABLE"  `
`
-replace '^ENABLE_USAGE_COLLECTION=.*$',"ENABLE_USAGE_COLLECTION=1"  `
`
-replace '^USER_INSTALL_DIR=.*$',"USER_INSTALL_DIR=$userInstallDir"  `
`
-replace '^KEY_DEST_LOCATION=.*$',"KEY_DEST_LOCATION=$defaultKeyLocation"  `
`
-replace '^PASS_PHRASE_PASSWD=.*$',"PASS_PHRASE_PASSWD=$sitekeyKeyword"  `
`
-replace '^SERVES_AS_GATEWAY=.*$',"SERVES_AS_GATEWAY=1" `
`
-replace '^DB_TYPE=.*$',"DB_TYPE=$dbTYPE" `
`
-replace '^DB_UNAME=.*$',"DB_UNAME=$dbUser" `
`
-replace '^DB_SERVICENAME=.*$',"DB_SERVICENAME=$dbName" `
`
-replace '^DB_ADDRESS=.*$',"DB_ADDRESS=$dbAddress" `
`
-replace '^DOMAIN_NAME=.*$',"DOMAIN_NAME=$domainName" `
`
-replace '^NODE_NAME=.*$',"NODE_NAME=$nodeName" `
`
-replace '^DOMAIN_PORT=.*$',"DOMAIN_PORT=$nodePort" `
`
-replace '^JOIN_NODE_NAME=.*$',"JOIN_NODE_NAME=$nodeName" `
`
-replace '^JOIN_HOST_NAME=.*$',"JOIN_HOST_NAME=$env:COMPUTERNAME" `
`
-replace '^JOIN_DOMAIN_PORT=.*$',"JOIN_DOMAIN_PORT=$nodePort" `
`
-replace '^DOMAIN_USER=.*$',"DOMAIN_USER=$domainUser" `
`
-replace '^DOMAIN_HOST_NAME=.*$',"DOMAIN_HOST_NAME=$domainHost" `
`
-replace '^DOMAIN_PSSWD=.*$',"DOMAIN_PSSWD=$domainPassword" `
`
-replace '^DOMAIN_CNFRM_PSSWD=.*$',"DOMAIN_CNFRM_PSSWD=$domainPassword" `
`
-replace '^DB_PASSWD=.*$',"DB_PASSWD=$dbPassword" `
`
-replace '^CREATE_SERVICES=.*$',"CREATE_SERVICES=0" `
`
-replace '^MRS_DB_TYPE=.*$',"MRS_DB_TYPE=MSSQLServer" `
`
-replace '^MRS_DB_UNAME=.*$',"MRS_DB_UNAME=$mrsdbuser" `
`
-replace '^MRS_DB_PASSWD=.*$',"MRS_DB_PASSWD=$mrsdbpwd" `
`
-replace '^MRS_DB_SERVICENAME=.*$',"MRS_DB_SERVICENAME=$dbName" `
`
-replace '^MRS_DB_ADDRESS=.*$',"MRS_DB_ADDRESS=$dbAddress" `
`
-replace '^MRS_SERVICE_NAME=.*$',"MRS_SERVICE_NAME=ModelRepositoryService" `
`
-replace '^DIS_SERVICE_NAME=.*$',"DIS_SERVICE_NAME=DataIntegrationService" `
`
-replace '^DIS_PROTOCOL_TYPE=.*$',"DIS_PROTOCOL_TYPE=http" `
`
-replace '^DIS_HTTP_PORT=.*$',"DIS_HTTP_PORT=8095"

}) | sc $propertyFile


# To speed up installation
Rename-Item $installerHome/source $installerHome/source_temp
mkdir $installerHome/source

echo Installing Informatica domain
cd $installerHome
$installCmd = $installerHome + "\silentInstall.bat"
Start-Process $installCmd -Verb runAs -workingdirectory $installerHome -wait | Out-Null

# Revert speed up changes
rmdir $installerHome/source
Rename-Item $installerHome/source_temp $installerHome/source

if($infaLicenseFile -ne "") {
	rm $infaLicenseFile
}

function createDQServices() {
	ac  C:\DQServiceLog.log "Create STAGE connection"
    ($out = C:\Informatica\10.1.1\isp\bin\infacmd createConnection -dn $domainName -un $domainUser -pd $domainPassword -cn STAGE -cid STAGE -ct SQLSERVER -cun $refdatadbuser -cpd $refdatadbpwd -o CodePage='UTF-8' DataAccessConnectString=''$dataaccessstring'' MetadataAccessConnectString='"'$metadataaccessstring''"" ) | Out-Null
	ac C:\InfaServiceLog.log $out

	ac  C:\DQServiceLog.log "Create PROFILE connection"
    ($out = C:\Informatica\10.1.1\isp\bin\infacmd createConnection -dn $domainName -un $domainUser -pd $domainPassword -cn PROFILE -cid PROFILE -ct SQLSERVER -cun $profiledbuser -cpd $profiledbpwd -o CodePage='UTF-8' DataAccessConnectString=''$dataaccessstring'' MetadataAccessConnectString='"'$metadataaccessstring''"" ) | Out-Null
	ac C:\InfaServiceLog.log $out

    ac  C:\DQServiceLog.log "Create Content Management Service"
    ($out = C:\Informatica\10.1.1\isp\bin\infacmd cms createService -dn $domainName -nn $nodeName -un $domainUser -pd $domainPassword -sn ContentManagementService -ds DataIntegrationService -rs ModelRepositoryService -rsu $domainUser -rsp $domainPassword -rdl STAGE -HttpPort 8105 ) | Out-Null
	ac C:\InfaServiceLog.log $out

    ac  C:\DQServiceLog.log "Create Analyst Service"
    ($out = C:\Informatica\10.1.1\isp\bin\infacmd as createService -dn $domainName -nn $nodeName -un $domainUser -pd $domainpass -sn AnalystService -ds DataIntegrationService -rs ModelRepositoryService -au $domainUser -ap $domainPassword -HttpPort 8085 ) | Out-Null
    ac C:\InfaServiceLog.log $out
}

echo Informatica setup Complete.