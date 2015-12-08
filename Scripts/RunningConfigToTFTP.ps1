##################################################################################################################
###
### Running-Config to TFTP
###
##################################################################################################################

<#
    .SYNOPSIS
    Copy the Running-Config to TFTP from all active switch devices

    .DESCRIPTION
    This Script uses the ScanNetworkAsync.ps1 Script to scan for all active switch devices (Identified by $SwitchIdentifier) and execute the command to copy the running-config to the TFTP-Server.  
    
    Requirements: Posh-SSH and Module "Brocade" 

    .EXAMPLE
    ./RunningConfigToTFTP.ps1 -TFTPServer 172.16.XX.XX -StartIP 192.168.1.XX -EndIP 192.168.1.XX -SwitchIdentifier XX_

    .LINK
    https://github.com/BornToBeRoot/PowerShell-SSH-Brocade
    https://github.com/BornToBeRoot/PowerShell-Async-IPScanner
    https://github.com/darkoperator/Posh-SSH
#>

##################################################################################################################
### Parameter
##################################################################################################################

[CmdletBinding()]
param(
	[Parameter(
		Position=0,
		Mandatory=$true,
		HelpMessage='Enter the TFTP-Server IP-Address (e.g. 172.16.XX.XX)')]
	[String]$TFTPServer,
	
	[Parameter(
		Position=1,
		Mandatory=$true,
		HelpMessage='Start IP like 192.168.XX.XX')]
	[String]$StartIP,
	
	[Parameter(
		Position=2,
		Mandatory=$true,
		HelpMessage='End IP like 192.168.XX.XX')]
	[String]$EndIP,

    [Parameter(
        Posistion=3,
        Mandatory=$False,
        HelpMessage='Switch Identifiert like XX_')]
    [String]$SwitchIdentifier = "XX_"    

)

##################################################################################################################
### Basic Informations to execute Script + Network Scan
##################################################################################################################

Begin{
    $Script_Startup_Path = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Timestamp = Get-Date -UFormat "%Y%m%d"

    ### Get Credentials
    while($Switch_Credential -eq $null)
    {
        $Switch_Credential = Get-Credential -Message "Enter Username and Password"

        if($Switch_Credential -eq $null)
        {
            Write-Host "Username and Password required!" -ForegroundColor Red
        }        
    }
    
    ### Scanning Network...
    $NetworkScan  = Invoke-Expression -Command "$Script_Startup_Path\ScanNetworkAsync.ps1 -StartIP $StartIP -EndIP $EndIP"
    if($NetworkScan -eq $null) { return }
        
    $StartTime = Get-Date
    $DeviceCount = 0

    Write-Host "`n----------------------------------------------------------------------------------------------------"
    Write-Host "----------------------------------------------------------------------------------------------------`n"
    Write-Host "Start: Script (BackupToTFTP) at $StartTime" -ForegroundColor Green
    Write-Host "`n----------------------------------------------------------------------------------------------------`n"
    Write-Host "Executing Commands on Switches...`n" -ForegroundColor Yellow
}

##################################################################################################################
### SSH Session, Backup Config to TFTP, Close Session
##################################################################################################################

Process{    
    foreach($Switch in ($NetworkScan | Where-Object {$_.Status -eq "Up" -and $_.Hostname.StartsWith($SwitchIdentifier.ToUpper())}))
    {
   	    $Hostname = $Switch.Hostname
	    Write-Host "Device:`t`t`t$Hostname" -ForegroundColor Cyan
		
	    # Create new Brocade Session	
 	    $Session = New-BrocadeSession -ComputerName $Hostname -Credentials $Switch_Credential

        $Command = [String]::Format("copy running-config tftp {0} {1}_{2}.bak", $TFTPServer, $Timestamp, $Hostname)
        Write-Host "Command:`t`t$Command" -ForegroundColor Cyan
	    Write-Host "`n- - - Host Output - - -`n"

	    # Execute Command in Session
        Invoke-BrocadeCommand -Session $Session -Command $Command -WaitTime 5000

        Write-Host "`n- - - / Host Output - - -`n"

	    # Close Brocade Session
        Remove-BrocadeSession -Session $Session

	    $DeviceCount ++	
	
	    Start-Sleep -Seconds 1
    }
}

##################################################################################################################
### Some cleanup and user output
##################################################################################################################
End{
    $Switch_Credential = $null
    $EndTime = Get-Date
    $ExecutionTime = (New-TimeSpan -Start $StartTime -End $EndTime).Seconds

    Write-Host "Executing Commands on Switches finished!" -ForegroundColor Yellow
    Write-Host "`n----------------------------------------------------------------------------------------------------`n"
    Write-Host "Number of Devices:`t$DeviceCount"
    Write-Host "`n----------------------------------------------------------------------------------------------------`n"
    Write-Host "Script duration:`t$ExecutionTime (Seconds)`n" -ForegroundColor Yellow
    Write-Host "End:`tScript (BackupToTFTP) at $EndTime" -ForegroundColor Green
    Write-Host "`n----------------------------------------------------------------------------------------------------"
    Write-Host "----------------------------------------------------------------------------------------------------`n"
}
