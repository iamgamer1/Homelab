# ============================================================
# KingSecure Homelab - AD User Management Scripts
# Domain: kingsecure.bj
# ============================================================

# ---- Unlock a locked account ----
# Usage: Unlock-LabAccount -Username "johndoe"
function Unlock-LabAccount {
    param([string]$Username)
    Unlock-ADAccount -Identity $Username
    Write-Host "Account $Username unlocked successfully." -ForegroundColor Green
    Get-ADUser -Identity $Username -Properties LockedOut | Select-Object Name, LockedOut
}

# ---- Reset a user password ----
# Usage: Reset-LabPassword -Username "johndoe" -NewPassword "NewPass@123"
function Reset-LabPassword {
    param(
        [string]$Username,
        [string]$NewPassword
    )
    $SecurePassword = ConvertTo-SecureString $NewPassword -AsPlainText -Force
    Set-ADAccountPassword -Identity $Username -Reset -NewPassword $SecurePassword
    Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
    Write-Host "Password reset for $Username. User must change password at next login." -ForegroundColor Green
}

# ---- Check all locked accounts ----
function Get-LockedAccounts {
    Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LastLogonDate
}

# ---- Disable a user account ----
function Disable-LabAccount {
    param([string]$Username)
    Disable-ADAccount -Identity $Username
    Write-Host "Account $Username has been disabled." -ForegroundColor Yellow
}

# ---- Enable a user account ----
function Enable-LabAccount {
    param([string]$Username)
    Enable-ADAccount -Identity $Username
    Write-Host "Account $Username has been enabled." -ForegroundColor Green
}

# ---- Get account status ----
function Get-AccountStatus {
    param([string]$Username)
    Get-ADUser -Identity $Username -Properties * | 
        Select-Object Name, SamAccountName, Enabled, LockedOut, 
                      PasswordExpired, PasswordLastSet, LastLogonDate
}

# ---- Create a new AD user ----
function New-LabUser {
    param(
        [string]$FirstName,
        [string]$LastName,
        [string]$Department,  # IT, HR, or Management
        [string]$Password
    )

    $Username = ($FirstName[0] + $LastName).ToLower()
    $OU = "OU=Users,OU=$Department Department,DC=kingsecure,DC=bj"
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    New-ADUser `
        -Name "$FirstName $LastName" `
        -GivenName $FirstName `
        -Surname $LastName `
        -SamAccountName $Username `
        -UserPrincipalName "$Username@kingsecure.bj" `
        -Path $OU `
        -AccountPassword $SecurePassword `
        -Enabled $true `
        -ChangePasswordAtLogon $true

    Write-Host "User $Username created in $Department Department OU." -ForegroundColor Green
}

# ---- Move computer to correct OU ----
function Move-LabComputer {
    param(
        [string]$ComputerName,
        [string]$Department  # IT, HR, or Management
    )
    $TargetOU = "OU=Computers,OU=$Department Department,DC=kingsecure,DC=bj"
    Get-ADComputer $ComputerName | Move-ADObject -TargetPath $TargetOU
    Write-Host "Computer $ComputerName moved to $Department Department." -ForegroundColor Green
}

# ---- Force GPO update on all domain computers ----
function Update-AllGPOs {
    $Computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
    foreach ($Computer in $Computers) {
        try {
            Invoke-Command -ComputerName $Computer -ScriptBlock { gpupdate /force } -ErrorAction Stop
            Write-Host "GPO updated on $Computer" -ForegroundColor Green
        } catch {
            Write-Host "Could not reach $Computer" -ForegroundColor Yellow
        }
    }
}

# ---- Check Trust Relationship ----
function Test-DomainTrust {
    param([string]$ComputerName)
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        Test-ComputerSecureChannel -Verbose
    }
}

# ---- Repair Trust Relationship ----
function Repair-DomainTrust {
    param([string]$ComputerName)
    Invoke-Command -ComputerName $ComputerName -Credential (Get-Credential) -ScriptBlock {
        Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
    }
}
