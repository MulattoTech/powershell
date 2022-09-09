#Detailed Server Audit to Text File
#
#Thanks to all the Powershell Users who contributed their code. Created on 8/24/15.
#
#This Powershell script outputs a very verbose and detailed audit for a list of servers that can be put in a Word or OneNote Document. This script runs on the local server with the Invoke-Command command and saves the information to a detailed text file on a network file share. It requires the following commands to connect remotely and save to a network file share.
#
#Run Commands on Server in Powershell Console
#"Set-ExecutionPolicy RemoteSigned -Force"
#"Enable-PSRemoting -Force"
#"Enable-WsManCredSSP -Role Server -Force"
#
#Run Commands on Your Computer in Powershell Console
#"Enable-WSManCredSSP -Role Client -DelegateComputer *.YOURDOMAIN.COM"
#
#Replace the path to the text files in the script with your network file share location.
#\\YOURSERVER\YOURFILESHARE\YOURTEXTFILE.txt
#
#Features To Update
#-Add More Write-Host
#-Add Logging
#-Fix Date Time Formatting
#-Cleanup Formatting

#Pre-Script Commands
Clear-Host

#Get Credentials
if($cred = $host.ui.PromptForCredential("Need credentials", "Please enter your user name and password.", "", "")){}else{exit}

#Get Servers
$ServerList = Get-Content "\\YOURSERVER\YOURFILESHARE\Servers.txt"
ForEach ($Server in $ServerList) {

#Remote Script
Invoke-Command -ComputerName $Server -Credential $cred -Authentication CredSSP -ScriptBlock {

	#Start Script
	#Import Modules
	Import-Module ServerManager

	#Misc Variables
	$ServerName = $env:computername
	$CurrentDateTime = Get-Date
	$FileOutput = "\\YOURSERVER\YOURFILESHARE\$ServerName.txt"
	Write-Host "$($ServerName) - Starting Script"
	#Create Files
	If(Test-Path -path $FileOutput)
	    {}
	    else {New-Item $FileOutput -type file}

	#Clear File Content
	Clear-Content $FileOutput
	
	#WMI Queries
	$OperatingSystems = Get-WmiObject -Class Win32_OperatingSystem | Select -Property Caption , CSDVersion , OSArchitecture , Description
	$Disk = Get-WmiObject -Class Win32_LogicalDisk -Filter DriveType=3 | Select SystemName , DeviceID , @{Name=”sizeGB”;Expression={“{0:N1}” -f($_.size/1gb)}} , @{Name=”freespaceGB”;Expression={“{0:N1}” -f($_.freespace/1gb)}}
	$BIOS = Get-WmiObject -Class Win32_BIOS | Select -Property Manufacturer , Model , Version , SerialNumber
	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem | Select -Property Name , Model , Manufacturer , NumberOfProcessors , Description
	$Processor = [object[]]$(get-WMIObject Win32_Processor)
	$ProcessorName = Get-WmiObject -Class Win32_Processor | Select -First 1 -Property Name
	$PhysicalMemory = (Get-WMIObject Win32_PhysicalMemory |  Measure-Object Capacity -Sum).sum/1GB
	$Adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration
	$Features = Get-WindowsFeature | Where-Object {$_.Installed -eq $True} | Select -Property DisplayName 
		
	#Virtual or Physical System
	if($BIOS.Version -match "VRTUAL") {$PhysicalOrVirtual = "Virtual - Hyper-V"}
	elseif($BIOS.Version -match "A M I") {$PhysicalOrVirtual = "Virtual - Virtual PC"}
	elseif($BIOS.Version -like "*Xen*") {$PhysicalOrVirtual = "Virtual - Xen"}
	elseif($BIOS.SerialNumber -like "*VMware*") {$PhysicalOrVirtual = "Virtual - VMWare"}
	elseif($ComputerSystem.manufacturer -like "*Microsoft*") {$PhysicalOrVirtual = "Virtual - Hyper-V"}
	elseif($ComputerSystem.manufacturer -like "*VMWare*") {$PhysicalOrVirtual = "Virtual - VMWare"}
	elseif($ComputerSystem.model -like "*Virtual*") {$PhysicalOrVirtual = "Virtual"}
	else {$PhysicalOrVirtual = "Physical"}
	
	#Computer.txt File Content
	#Overview
	Add-Content $FileOutput "Overview"
	Add-Content $FileOutput "The $env:computername Server is the $($OperatingSystems.Description).  This Server was last queried on $CurrentDateTime."
	Add-Content $FileOutput ""
	
	#Specifications
	Add-Content $FileOutput "Specifications"
	Write-Output "The $PhysicalOrVirtual Server $($ComputerSystem.Name) runs the $($OperatingSystems.Caption)$($OperatingSystems.CSDVersion) $($OperatingSystems.OSArchitecture) Operating System on $($ComputerSystem.Model) with $($PhysicalMemory) GBs of Memory running on $($SystemProcessor.Name) with $(($Processor|measure-object NumberOfLogicalProcessors -sum).Sum) Logical processors and $($Processor.count) Cores." | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
	Add-Content $FileOutput ""
	Write-Output "The Operating System is installed on the $env:SystemDrive Drive, and the rest of the drives are for data.  The server has the following $($Disk.count) drives:" | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
	
	#Drives
	$Disk | Foreach-Object {
		Write-Output "The $($_.DeviceID) Drive size is $($_.sizeGB) GBs with $($_.freespaceGB) GBs of free space." | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
		}
	Add-Content $FileOutput ""
	
	#Network Adapters
	Add-Content $FileOutput "This Server has the following active Network Adapters:"
	Foreach ($Adapter in ($Adapters | Where {$_.IPEnabled -eq $True})) {
		$AdapterDetails = "" | Select Description, "Physical address" , "IP Address" , "Subnet Mask" , "Default Gateway" , "DHCP Enabled", DNSServerSearchOrder , WINS , DNS
		$AdapterDetails.Description = "$($Adapter.Description)"
		$AdapterDetails."Physical address" = "$($Adapter.MACaddress)"
		If ($Adapter.IPAddress -ne $Null) {
		$AdapterDetails."IP Address" = "$($Adapter.IPAddress)"
		$AdapterDetails."Subnet Mask" = "$($Adapter.IPSubnet)"
		$AdapterDetails."Default Gateway" = "$($Adapter.DefaultIPGateway)"
		}
		If ($Adapter.DHCPEnabled -eq "True")	{
		$AdapterDetails."DHCP Enabled" = "enabled"
		}
		Else {
			$AdapterDetails."DHCP Enabled" = "not enabled"
		}
		If ($Adapter.DNSServerSearchOrder -ne $Null)	{
			$AdapterDetails.DNS =  "$($Adapter.DNSServerSearchOrder)"
		}
		$AdapterDetails.WINS = "$($Adapter.WINSPrimaryServer) $($Adapter.WINSSecondaryServer)"
	    Write-Output "The Network Adapter '$($AdapterDetails.Description)' has the IP Address of $($AdapterDetails.”IP Address"), Subnet Mask of $($AdapterDetails.”Subnet Mask"), Default Gateway of $($AdapterDetails.”Default Gateway"), WINS Servers are $($AdapterDetails.WINS) and the DNS Servers are $($AdapterDetails.DNS) with the MAC Address of $($AdapterDetails.”Physical address"). DHCP Addressing is $($AdapterDetails."DHCP Enabled")." | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
		Add-Content $FileOutput ""
	}
	
	#Local Administrators
	Add-Content $FileOutput "Local Administrators"
	Add-Content $FileOutput "$env:ComputerName has the following Local Administrators:"	
	net localgroup administrators | where {$_ -AND $_ -notmatch "command completed successfully"} | select -skip 4 | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
	Add-Content $FileOutput ""
	
	#Roles and Features Section
	Add-Content $FileOutput "Roles and Features"
	Add-Content $FileOutput "$env:ComputerName has the following Roles and Features installed:"
	$Features | Foreach-Object {
		Write-Output $_.DisplayName | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
		}
	Add-Content $FileOutput ""	
	
	#Applications Section
	Add-Content $FileOutput "Applications"
	Add-Content $FileOutput "This Server has the following non-default Applications installed:"
	$ServerAppFilter = Get-Content -Path "\\YOURSERVER\YOURFILESHARE\ServerAppFilter.txt"
	$ServerApps = Get-WmiObject Win32_Product | Select Name , Version
	$ServerApps | Where-Object {!($ServerAppFilter -contains $_.Name -or $_.Name -like "*Microsoft*" -or $_.Name -Like "*NetIQ*" -or $_.Name -like "*SQL Server*" -or $_.Name -like "*Symantec*" -or $_.Name -like "*Visual Studio*" -or $_.Name -like "*Visual Basic*")} | Sort Name | Foreach-Object {
			Write-Output "$($_.Name)" | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
			}
	Add-Content $FileOutput ""
	Add-Content $FileOutput "This Server has the following default Applications installed:"
	$ServerAppFilter = Get-Content -Path "\\YOURSERVER\YOURFILESHARE\ServerAppFilter.txt"
	$ServerApps | Where-Object {$ServerAppFilter -contains $_.Name -or $_.Name -like "*Microsoft*" -or $_.Name -Like "*NetIQ*" -or $_.Name -like "*SQL Server*" -or $_.Name -like "*Symantec*" -or $_.Name -like "*Visual Studio*" -or $_.Name -like "*Visual Basic*"} | Sort Name | Foreach-Object {
			Write-Output "$($_.Name)" | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
			}
	Add-Content $FileOutput ""
	
	#Services Section
	Add-Content $FileOutput "Services"
	Add-Content $FileOutput "This Server has the following non-default services installed:"
	$ServerServiceFilter = Get-Content -Path "\\YOURSERVER\YOURFILESHARE\ServerServiceFilter.txt"
	$Service = Get-WmiObject win32_service | Select DisplayName , State , StartName | Where-Object { $ServerServiceFilter -notcontains $_.DisplayName}
	$Service | Foreach-Object {
			Write-Output "$($_.DisplayName) runs as $($_.State) on $($_.StartName)." | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
			}
	Add-Content $FileOutput ""
	
	#File Shares
	Add-Content $FileOutput "File Shares"
	Add-Content $FileOutput "$env:ComputerName has the following File Shares installed:"
	$FileShares = Get-WmiObject -Class Win32_Share | Select -Property Name , Path , Description
	$FileShares | Foreach-Object {
		Write-Output "$($_.Name) with the path of $($_.Path) is used for $($_.Description)." | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
		}
	Add-Content $FileOutput ""
	
	#Scheduled Tasks Section
	$SchedTasks = New-Object -Com "Schedule.Service"
	$SchedTasks.Connect()
	$SchedOut = @()
	$SchedTasks.GetFolder("\").GetTasks(0) | % {
	    $xml = [xml]$_.xml
	    $SchedOut += New-Object psobject -Property @{
	        "Name" = $_.Name
			"Path" = $_.Path
	        "Status" = switch($_.State) {0 {"Unknown"} 1 {"Disabled"} 2 {"Queued"} 3 {"Ready"} 4 {"Running"}}
	        "NextRunTime" = $_.NextRunTime
	        "LastRunTime" = $_.LastRunTime
	        "LastRunResult" = $_.LastTaskResult
			"NumberOfMissedRuns" = $_.numberofmissedruns
			"Actions" = ($xml.Task.Actions.Exec | % { "$($_.Command) $($_.Arguments)" }) -join "`n"
	        "Author" = $xml.Task.RegistrationInfo.Author
	        "Created" = $xml.Task.RegistrationInfo.Date
			"Description" = ([xml]$_.xml).Task.RegistrationInfo.Description
	        "UserId" = ([xml]$_.xml).Task.Principals.Principal.UserId		
	    }
	}
	Add-Content $FileOutput "Scheduled Tasks"
	Add-Content $FileOutput "This Server has the following Scheduled Tasks:"
	$SchedOut | Select Name , Path , Status , NextRunTime , LastRunTime , LastRunResult , NumberOfMissedRuns , Actions , Author , Created , Description , UserId , GroupId |`
	Foreach-Object {
		Write-Output "The Scheduled Task '$($_.Name)' which $($_.Description) was created by $($_.Author). This task runs the command '$($_.Actions)' with the NT Account '$($_.UserId)'. The Status is $($_.Status), the Last Run Time is $($_.LastRunTime), the Next Run Time is $($_.NextRunTime), and it has missed running $($_.NumberOfMissedRuns) times." | Out-File -FilePath “$FileOutput” -Encoding "UTF8" -Append
		Add-Content $FileOutput ""
		}

	#Replace Text
	(Get-Content $FileOutput) | Foreach-Object {$_ -replace "NT Account 'S-1-5-18'", "NT Account 'NT Authority\SYSTEM'"} | Set-Content $FileOutput
	
	#End of Remote Script
	Write-Host "$($ServerName) - Stopping Script"
	}
}
