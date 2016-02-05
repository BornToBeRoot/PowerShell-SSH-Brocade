###############################################################################################################
# Language     :  PowerShell 4.0
# Script Name  :  Brocade.psm1
# Autor        :  BornToBeRoot (https://github.com/BornToBeRoot)
# Description  :  Module with functions to manage Brocade Switch devices
# Repository   :  https://github.com/BornToBeRoot/PowerShell-SSH-Brocade
###############################################################################################################

# Global Array for Brocade Sessions
if (!(Test-Path Variable:Global:BrocadeSessions)) 
{
    $Global:BrocadeSessions = New-Object System.Collections.ArrayList
}

###############################################################################################################
### Function: New-BrocadeSession
###########################
####################################################################################

function New-BrocadeSession
{
    [CmdletBinding()]
    param
    (
        [Parameter(
	        Position=0,
	        Mandatory=$true,
	        HelpMessage="Hostname or IP-Address of the Brocade switch device")]
	    [String]$ComputerName, 
	  
	    [Parameter(
	        Position=1,
	        Mandatory=$false,
	        HelpMessage="PSCredentials")]
        [System.Management.Automation.PSCredential]$Credentials
	)
     
    if($Credentials -eq $null)
	{		
		try{
			$Credentials = Get-Credential $null
		}catch{
			Write-Host "Entering credentials was aborted. Can't connect to $ComputerName without credentials..." -ForegroundColor Yellow
			return
		}
    }	
	
	try {
	   	$created_SSH_Session = New-SSHSession -ComputerName $ComputerName -Credential $Credentials -AcceptKey
    	$SSH_Session = Get-SSHSession -Index $created_SSH_Session.SessionID
    	$SSH_Stream = $SSH_Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    }catch [Exception]{
		Write-Host $_.Exception.Message
		return
	}
	
    $Session = New-Object -TypeName PSObject 
    Add-Member -InputObject $Session -MemberType NoteProperty -Name SessionID -Value $created_SSH_Session.SessionID
	Add-Member -InputObject $Session -MemberType NoteProperty -Name ComputerName -Value $created_SSH_Session.Host
    Add-Member -InputObject $Session -MemberType NoteProperty -Name Session -Value $SSH_Session
    Add-Member -InputObject $Session -MemberType NoteProperty -Name Stream -Value $SSH_Stream
    
    Invoke-BrocadeCommand -Session $Session -Command "skip-page-display" -WaitTime 300 | Out-Null
        
    $Global:BrocadeSessions.Add($Session) | Out-Null
	
    return $Session
}

###############################################################################################################
### Function: Get-BrocadeSession
###############################################################################################################

function Get-BrocadeSession {
	[CmdletBinding(DefaultParameterSetName='SessionID')]
	param
    (
	    [Parameter(
		    ParameterSetName='SessionID',	
		    Position=0,
		    Mandatory=$false)]
		[Int32[]]$SessionID,
	
	    [Parameter(
		    ParameterSetName='ComputerName',
	    	Position=0,
		    Mandatory=$false)]
		[String[]]$ComputerName,

        [Parameter(Mandatory=$false,
            ParameterSetName = 'ComputerName',
            Position=1)]        
        [Switch]$ExactMatch
	)

 	$Sessions = @()

	if($PSCmdlet.ParameterSetName -eq 'SessionID')
	{
		if($PSBoundParameters.ContainsKey('SessionID'))
		{
    		foreach($ID in $SessionID)
			{
				foreach($Session in $BrocadeSessions)
				{
					if($Session.SessionId -eq $ID)
					{
						$Sessions += $Session
					}
				}
			}
		}
		else
		{
			foreach($Session in $BrocadeSessions) 
			{
				$Sessions += $Session
			}
		}
	}
	else
	{
		if($PSBoundParameters.ContainsKey('ComputerName'))
		{
			foreach($Name in $ComputerName)
			{
				foreach($Session in $BrocadeSessions)
				{
					if($Session.ComputerName -like $Name -and (-not $ExactMatch -or $Session.ComputerName -eq $Name))
					{
						$Sessions += $Session
					}
				}
			}
		}
	} 
	
	return $Sessions
}

###############################################################################################################
### Function: Remove-BrocadeSession
###############################################################################################################

function Remove-BrocadeSession {
	[CmdletBinding(DefaultParameterSetName='SessionID')]
	param
    (
        [Parameter(
            ParameterSetName='SessionID',
		    Position=0,
		    Mandatory=$true,
		    HelpMessage="Brocade Session ID")]
		[Int32[]]$SessionID,

	    [Parameter(
            ParameterSetName='Session',
		    Position=0,
		    Mandatory=$true,
		    HelpMessage="Brocade Session")]
		[PSObject[]]$Session
	)
    
    $Sessions2Remove = @()

    if($PSCmdlet.ParameterSetName -eq 'SessionID')
    {
        $Sessions2Remove += Get-BrocadeSession -SessionID $SessionID
    } 
    else
    {
        $Sessions2Remove += $Session
    }
	
	foreach($Session2Remove in $Sessions2Remove)
	{
		$Session2Remove
		"bla"
		Remove-SSHSession -SessionId $Session2Remove.SessionID | Out-Null
	
	    $Global:BrocadeSessions.Remove($Session2Remove)
	}
}

###############################################################################################################
### Function: Invoke-BrocadeCommand
###############################################################################################################

function Invoke-BrocadeCommand
{ 
	[CmdletBinding()]
	param(
	    [Parameter(
		    Position=0,
		    Mandatory=$true,
		    HelpMessage="Brocade Session")]
		$Session,
		
    	[Parameter(
	    	Position=1,
	    	Mandatory=$true,
		    HelpMessage="Command to execute")]
		[String]$Command,
		
	    [Parameter(
	    	Position=2,
		    Mandatory=$true,
		    HelpMessage="Wait time in milliseconds")]
		[Int32]$WaitTime=500
	)

    if(-not($Command.EndsWith("`n")))
    { 
		$StreamCommand = $Command + "`n" 
	}
    else
	{ 
		$StreamCommand = $Command 
	}
        
    $Session.Stream.Write($StreamCommand)
	
    Start-Sleep -Milliseconds $WaitTime
    
	$Session.Stream.Read() -split '[\r\n]' |? {$_} 
}