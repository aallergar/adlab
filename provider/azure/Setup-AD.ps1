param(
    [Parameter(Mandatory=$false)]
    [string]$DomainName = "${domain_name}",
    
    [Parameter(Mandatory=$false)]
    [string]$DomainNetBiosName = "${domain_netbios_name}",
    
    [Parameter(Mandatory=$false)]
    [string]$SafeModePassword = "${safe_mode_password}"
)

# Log file path
$logFile = "C:\Temp\AD-Setup.log"
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Output $logMessage
    $logMessage | Out-File -FilePath $logFile -Append
}

try {
    Write-Log "=========================================="
    Write-Log "Starting Active Directory setup..."
    Write-Log "=========================================="
    Write-Log "Domain Name: $DomainName"
    Write-Log "NetBIOS Name: $DomainNetBiosName"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Log "OS Version: $([System.Environment]::OSVersion.VersionString)"

    # Set execution policy
    Write-Log "Setting execution policy..."
    Set-ExecutionPolicy Unrestricted -Force -Confirm:$false
    Write-Log "Execution policy set to Unrestricted"

    # Disable Windows Firewall temporarily
    Write-Log "Disabling Windows Firewall..."
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Write-Log "Windows Firewall disabled"

    # Install AD DS Role and Management Tools
    Write-Log "Installing AD-Domain-Services feature..."
    Write-Log "This may take 5-10 minutes..."
    
    $adInstall = Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    
    if ($adInstall.Success) {
        Write-Log "AD-Domain-Services installed successfully"
        Write-Log "Restart needed: $($adInstall.RestartNeeded)"
        Write-Log "Exit code: $($adInstall.ExitCode)"
    } else {
        Write-Log "ERROR: Failed to install AD-Domain-Services"
        Write-Log "Exit code: $($adInstall.ExitCode)"
        exit 1
    }

    # Convert password to secure string
    Write-Log "Converting safe mode password to secure string..."
    $SecureSafeModePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force
    Write-Log "Password converted successfully"

    # Install AD Forest
    Write-Log "=========================================="
    Write-Log "Installing AD Forest..."
    Write-Log "This will take 10-15 minutes and will reboot the server"
    Write-Log "=========================================="
    
    $forestParams = @{
        DomainName                    = $DomainName
        DomainNetbiosName             = $DomainNetBiosName
        SafeModeAdministratorPassword = $SecureSafeModePassword
        InstallDns                    = $true
        CreateDnsDelegation           = $false
        DatabasePath                  = "C:\Windows\NTDS"
        LogPath                       = "C:\Windows\NTDS"
        SysvolPath                    = "C:\Windows\SYSVOL"
        NoRebootOnCompletion          = $false
        Force                         = $true
    }

    Write-Log "Forest parameters configured:"
    $forestParams.Keys | ForEach-Object {
        if ($_ -ne 'SafeModeAdministratorPassword') {
            Write-Log "  $_ = $($forestParams[$_])"
        }
    }

    Install-ADDSForest @forestParams
    
    Write-Log "=========================================="
    Write-Log "AD Forest installation command executed"
    Write-Log "System will reboot automatically..."
    Write-Log "=========================================="
    
} catch {
    Write-Log "=========================================="
    Write-Log "ERROR OCCURRED!"
    Write-Log "=========================================="
    Write-Log "Error Message: $($_.Exception.Message)"
    Write-Log "Error Type: $($_.Exception.GetType().FullName)"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
    Write-Log "=========================================="
    exit 1
}

