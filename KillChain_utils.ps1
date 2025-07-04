﻿# Checks whether the domain has MX records pointing to MS cloud
# Jun 16th 2020
# Aug 30th 2022: Fixed by maxgrim
# Fe. 19th 2025: Add new mx.microsoft check by Michael Morten Sonne

function HasCloudMX
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Domain,
        [Parameter(Mandatory=$False)]
        [String]$SubScope
    )
    Process
    {
        # Use the correct filter
        switch($SubScope)
        {
            "DOD" # DoD
            {
                $filter = "*.protection.office365.us"
            }
            "DODCON" # GCC-High
            {
                $filter = "*.protection.office365.us"
            }
            default # Commercial/GCC
            {
                $filter = @("*.mail.protection.outlook.com","*.mx.microsoft")
            }
        }

        $results = Resolve-DnsName -Name $Domain -Type MX -DnsOnly -NoHostsFile -NoIdn -ErrorAction SilentlyContinue |
               Select-Object -ExpandProperty nameexchange

        # Normalize $filter into an array
        if (-not ($filter -is [System.Collections.IEnumerable])) {
            $filter = @($filter)
        }

        # Check results
        $filteredResults = @()
        foreach ($pat in $filter) {
            $filteredResults += $results | Where-Object { $_ -like $pat }
        }

        return $filteredResults.Count -gt 0
    }
}

# Checks whether the domain has SPF records allowing sending from cloud
# Jun 16th 2020
function HasCloudSPF
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Domain,
        [Parameter(Mandatory=$False)]
        [String]$SubScope
    )
    Process
    {
        # Use the correct filter
        switch($SubScope)
        {
            "DOD" # DoD
            {
                $filter = "*include:spf.protection.office365.us*"
            }
            "DODCON" # GCC-High
            {
                $filter = "*include:spf.protection.office365.us*"
            }
            default # Commercial/GCC
            {
                $filter = "*include:spf.protection.outlook.com*"
            }
        }

        $results=Resolve-DnsName -Name $Domain -Type txt -DnsOnly -NoHostsFile -NoIdn -ErrorAction SilentlyContinue | Select-Object strings | Select-Object -ExpandProperty strings 

        return ($results -like $filter).Count -gt 0
    }
}

# Checks whether the domain has SPF records allowing sending from cloud
# Sep 23rd 2020
function HasDMARC
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Domain
    )
    Process
    {
        try
        {
            $results=Resolve-DnsName -Name "_dmarc.$Domain" -Type txt -DnsOnly -NoHostsFile -NoIdn -ErrorAction SilentlyContinue | Select-Object strings | Select-Object -ExpandProperty strings 
        }catch{}

        return ($results -like "v=DMARC1*").Count -gt 0
    }
}

# Checks whether the domain has DKIM records for Exchange Online
# Aug 14rd 2023 by Michael Morten Sonne
function HasCloudDKIM
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Domain,
        [Parameter(Mandatory=$False)]
        [String]$SubScope
    )
    Process
    {
        # Use the correct filter
        switch($SubScope)
        {
            "DOD" # DoD
            {
                $filter = "*_domainkey.*.onmicrosoft.us*"
            }
            "DODCON" # GCC-High
            {
                $filter = "*_domainkey.*.onmicrosoft.us*"
            }
            default # Commercial/GCC
            {
                $filter = "*_domainkey.*.onmicrosoft.com*"
            }
        }
        $selectors = @("selector1", "selector2")
        foreach ($selector in $selectors)
        {
            try
            {
                $results = Resolve-DnsName -Name "$selector._domainkey.$($Domain)" -Type CNAME -DnsOnly -NoHostsFile -NoIdn -ErrorAction SilentlyContinue

                if($results.NameHost -like $filter)
                {
                    return $true
                }
            }catch {}
        }
        
        return $false
    }
}

# Checks whether the domain has MTA-STS records for Exchange Online
# Aug 14rd 2023 by Michael Morten Sonne
function HasCloudMTASTS {
    param (
        [Parameter(Mandatory=$True)]
        [string]$Domain,
        [Parameter(Mandatory=$False)]
        [String]$SubScope
    )
    Process
    {
        # Use the correct filter
        switch($SubScope)
        {
            "DOD" # DoD
            {
                $filter = "*include:spf.protection.office365.us*"
            }
            "DODCON" # GCC-High
            {
                $filter = "*mx: *.mail.protection.office365.us*"
            }
            default # Commercial/GCC
            {
                $filter = "*mx: *.mail.protection.outlook.com*"
            }
        }

        $url = "https://mta-sts.$Domain/.well-known/mta-sts.txt"
        $mtaStsFound = $false
        $outlookMxFound = $false

        try {
            $mtaStsResponse = Invoke-WebRequest -UseBasicParsing -Uri $url -ErrorAction Stop -Headers @{"User-agent" = Get-UserAgent}
            $mtaStsContent = $mtaStsResponse.Content
            $mtaStsLines = $mtaStsContent -split "`r?`n"

            foreach ($line in $mtaStsLines) {
                if ($line -like "version: STSv1") {
                    $mtaStsFound = $true
                }
                if ($line -like $filter) {
                    $outlookMxFound = $true
                }
            }
        } catch {
            $mtaStsFound = $false
            $outlookMxFound = $false
        }

        return ($mtaStsFound -eq $true) -and ($outlookMxFound -eq $true)
    }
}

# Checks whether the domain has DesktopSSO enabled
# Jun 16th 2020
function HasDesktopSSO
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Domain,
        [Parameter(Mandatory=$False)]
        [String]$SubScope
    )
    Process
    {
        (Get-CredentialType -UserName "nn@$domain" -SubScope $Subscope).EstsProperties.DesktopSsoEnabled -eq "True"
    }
}

# Checks whether the domain has CBA enabled
# Jun 17th 2022
function HasCBA
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$UserName,
        [Parameter(Mandatory=$False)]
        [String]$SubScope
    )
    Process
    {
        (Get-CredentialType -UserName $UserName -SubScope $SubScope).Credentials.HasCertAuth -eq "True"
    }
}



# Checks whether the user exists in Azure AD or not
# Jun 16th 2020
function DoesUserExists
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$User,
        [Parameter(Mandatory=$False)]
        [ValidateSet("Normal","Login","Autologon","RST2")]
        [String]$Method="Normal",
        [Parameter(Mandatory=$False)]
        [String]$SubScope
    )
    Process
    {
        $exists = $false 

        # Get Tenant Region subscope from Open ID configuration if not provided
        if([string]::IsNullOrEmpty($SubScope))
        {
            $SubScope = Get-TenantSubscope -Domain $DomainName
        }

        if($Method -eq "Normal")
        {
            # Get the credential type information
            $credType=Get-CredentialType -UserName $User -SubScope $SubScope

            # Works only if desktop sso (aka. Seamless SSO) is enabled
            # Since August 2021 this seems to work for all tenants!
            #if($credType.EstsProperties.DesktopSsoEnabled -eq "True")
            #{
                # Return empty if throttling
                if($credType.ThrottleStatus -eq 1)
                {
                    Write-Warning "Requests throttled!"
                    Remove-Variable exists
                }
                else
                {
                    $exists = $credType.IfExistsResult -eq 0 -or $credType.IfExistsResult -eq 6
                }
            #}
            #else
            #{
            #    Remove-Variable exists
            #}
        }
        else
        {
            if($Method -eq "Login")
            {
                # Try to log in as the user
                $randomGuid = New-Guid
                $body = @{
                    "resource"=$randomGuid
                    "client_id"=$randomGuid
                    "grant_type"="password"
                    "username"=$User
                    "password"="none"
                    "scope"="openid"
                }

                try
                {
                    $jsonResponse=Invoke-RestMethod -UseBasicParsing -Uri "$(Get-TenantLoginUrl -SubScope $SubScope)/common/oauth2/token" -ContentType "application/x-www-form-urlencoded" -Method POST -Body $body -Headers @{"User-agent" = Get-UserAgent}
                    $exists = $True # May be should change password..?
                }
                catch
                {
                    $errorDetails = ($_.ErrorDetails.Message | convertfrom-json).error_description
                }
            }
            elseif("Autologon","RST2".Contains($Method))
            {
                $requestId = (New-Guid).ToString()

                $domain = $User.Split("@")[1]
                $password = "none"

                $now = Get-Date
                $created = $now.toUniversalTime().toString("o")
                $expires = $now.addMinutes(10).toUniversalTime().toString("o")

                if($Method -eq "RST2")
                {
                    # RST2
                    $url = "$(Get-TenantLoginUrl -SubScope $SubScope)/RST2.srf"
                    $endPoint = "sharepoint.com"
                }
                else
                {
                    # AutoLogon
                    $url = "https://autologon.microsoftazuread-sso.com/$domain/winauth/trust/2005/usernamemixed?client-request-id=$requestid"
                    $endPoint = "urn:federation:MicrosoftOnline"
                }
                
                $exists = $false

                try
                {
                    $response = Get-RSTToken -Url $url -EndpointAddress $endPoint -UserName $User -Password $password
                    $exists = $true # Very bad password
                }
                catch
                {
                    $errorDetails = $_.Exception.Message
                }
            }

            # Parse the error code. Only AADSTS50034 would need to be checked but good to know other errors too.
            if(!$exists -and $errorDetails)
            {
                if($errorDetails.startsWith("AADSTS50053")) # The account is locked, you've tried to sign in too many times with an incorrect user ID or password.
                {
                    $exists = $True
                }
                elseif($errorDetails.StartsWith("AADSTS50126")) # Error validating credentials due to invalid username or password.
                {
                    $exists = $True
                }
                elseif($errorDetails.StartsWith("AADSTS50076")) # Due to a configuration change made by your administrator, or because you moved to a new location, you must use multi-factor authentication to access '{resource}'
                {
                    $exists = $True
                }
                elseif($errorDetails.StartsWith("AADSTS700016")) # Application with identifier '{appIdentifier}' was not found in the directory '{tenantName}'. This can happen if the application has not been installed by the administrator of the tenant or consented to by any user in the tenant. You may have sent your authentication request to the wrong tenant.
                {
                    $exists = $True
                }
                elseif($errorDetails.StartsWith("AADSTS70046")) # The session has expired or is invalid due to re-authentication checks by conditional access. (= Blocked due to risky sign-in)
                {
                    $exists = $True
                }
                elseif($errorDetails.StartsWith("AADSTS50034")) # The user account {identifier} does not exist in the {tenant} directory. To sign into this application, the account must be added to the directory.
                {
                    $exists = $False
                }
                elseif($errorDetails.StartsWith("AADSTS50059")) # No tenant-identifying information found in either the request or implied by any provided credentials.
                {
                    $exists = $False
                }
                elseif($errorDetails.StartsWith("AADSTS81016")) # Invalid STS request.
                {
                    Write-Warning "Got Invalid STS request. The tenant may not have DesktopSSO or Directory Sync enabled."
                    Remove-Variable exists
                }
                else
                {
                    # Can't be sure so return empty
                    Remove-Variable exists
                }
            }
        }

        return $exists
    }
}

# Checks whether the tenant has MDI enabled
# Mar 11th 2023
function GetMDIInstance
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Tenant
    )
    Process
    {
        # Ref: https://learn.microsoft.com/en-us/defender-for-identity/configure-proxy#enable-access-to-defender-for-identity-service-urls-in-the-proxy-server
        # Ref: https://github.com/thalpius/Microsoft-Defender-for-Identity-Check-Instance
        # The MDI url is <instance>.atp.azure.com where instance is the tenant or tenant-onmicrosoft-com

        # Get the instance part if FQDN is provided
        if($Tenant.IndexOf(".") -ge 0)
        {
            $Tenant=$Tenant.Substring(0,$Tenant.IndexOf("."))
        }

        Write-Verbose "Getting MDI Instance for $Tenant"

        $domains =@(
            "$tenant.atp.azure.com",
            "$tenant-onmicrosoft-com.atp.azure.com"
        )
        foreach($domain in $domains)
        {
            $results=Resolve-DnsName -Name $Domain -DnsOnly -NoHostsFile -NoIdn -ErrorAction SilentlyContinue
            if($results)
            {
                return $domain
            }
        }

        return $null
    }
}
