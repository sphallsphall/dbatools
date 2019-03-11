#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#

function Test-DbaConnection {
    <#
    .SYNOPSIS
        Tests the connection to a single instance.

    .DESCRIPTION
        Tests the ability to connect to an SQL Server instance outputting information about the server and instance.

    .PARAMETER SqlInstance
        The SQL Server Instance to test connection

    .PARAMETER Credential
        Credential object used to connect to the Computer as a different user

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: CIM, Test, Connection
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Test-DbaConnection

    .EXAMPLE
        PS C:\> Test-DbaConnection SQL2016
        ```
        ComputerName         : SQL2016
        InstanceName         : MSSQLSERVER
        SqlInstance          : sql2016
        SqlVersion           : 13.0.4001
        ConnectingAsUser     : BASE\ctrlb
        ConnectSuccess       : True
        AuthType             : Windows Authentication
        AuthScheme           : KERBEROS
        TcpPort              : 1433
        IPAddress            : 10.2.1.5
        NetBiosName          : sql2016.base.local
        IsPingable           : True
        PSRemotingAccessible : True
        DomainName           : base.local
        LocalWindows         : 10.0.15063.0
        LocalPowerShell      : 5.1.15063.502
        LocalCLR             : 4.0.30319.42000
        LocalSMOVersion      : 13.0.0.0
        LocalDomainUser      : True
        LocalRunAsAdmin      : False
        ```

        Test connection to SQL2016 and outputs information collected
    #>
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstance[]]$SqlInstance,
        [PSCredential]$Credential,
        [PSCredential]$SqlCredential,
        [Alias('Silent')]
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            # Get local environment
            Write-Message -Level Verbose -Message "Getting local environment information"
            $localInfo = [pscustomobject]@{
                Windows    = [environment]::OSVersion.Version.ToString()
                Edition    = $PSVersionTable.PSEdition
                PowerShell = $PSVersionTable.PSversion.ToString()
                CLR        = [string]$PSVersionTable.CLRVersion
                SMO        = ((([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Fullname -like "Microsoft.SqlServer.SMO,*" }).FullName -Split ", ")[1]).TrimStart("Version=")
                DomainUser = $env:computername -ne $env:USERDOMAIN
                RunAsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            }

            try {
                <# gather following properties #>
                <#
                        InputName        :
                        ComputerName     :
                        IPAddress        :
                        DNSHostName      :
                        DNSDomain        :
                        Domain           :
                        DNSHostEntry     :
                        FQDN             :
                        FullComputerName :
                     #>
                $resolved = Resolve-DbaNetworkName -ComputerName $instance.ComputerName -Credential $Credential
            } catch {
                Stop-Function -Message "Unable to resolve server information" -Category ConnectionError -Target $instance -ErrorRecord $_ -Continue
            }

            # Test for WinRM #Test-WinRM neh
            Write-Message -Level Verbose -Message "Checking remote acccess"
            try {
                $null = Invoke-Command2 -ComputerName $instance.ComputerName -Credential $Credential -ScriptBlock { Get-ChildItem } -ErrorAction Stop
                $remoting = $true
            } catch {
                $remoting = $_
            }

            # Test Connection first using Ping class which requires ICMP access then failback to tcp if pings are blocked
            Write-Message -Level Verbose -Message "Testing ping to $($instance.ComputerName)"
            $ping = New-Object System.Net.NetworkInformation.Ping
            $timeout = 1000 #milliseconds
            $reply = $ping.Send($instance.ComputerName, $timeout)
            $pingable = $reply.Status -eq 'Success'

            # this whole section does nothing and returns errors for default instances with a non-default port - baseaddress not defined
            # commenting it all out
            # SQL Server connection
            # if ($instance.InstanceName -ne "MSSQLSERVER") {
            #     #Variable marked as unused by PSScriptAnalyzer, need to be in PSCustomObject?
            #     #$sqlport = "N/A"
            # } else {
            #     Write-Message -Level Verbose -Message "Testing raw socket connection to default SQL port"
            #     $tcp = New-Object System.Net.Sockets.TcpClient
            #     try {
            #         $tcp.Connect($baseaddress, 1433)
            #         $tcp.Close()
            #         $tcp.Dispose()
            #     } catch {
            #         # here to avoid an empty catch
            #         $null = 1
            #     }
            # }

            try {
                $server = Connect-SqlInstance -SqlInstance $instance.FullSmoName -SqlCredential $SqlCredential
                $connectSuccess = $true
                $instanceName = $server.InstanceName
            } catch {
                $connectSuccess = $false
                $instanceName = $instance.InstanceName
                Stop-Function -Message "Issue connection to SQL Server on $instance" -Category ConnectionError -Target $instance -ErrorRecord $_ -Continue
            }

            $username = $server.ConnectionContext.TrueLogin
            if ($username -like "*\*") {
                $authType = "Windows Authentication"
            } else {
                $authType = "SQL Authentication"
            }

            # TCP Port
            try {
                $tcpport = (Get-DbaTcpPort -SqlInstance $server -EnableException).Port
            } catch {
                $tcpport = $_
            }

            # Auth Scheme
            try {
                $authscheme = (Test-DbaConnectionAuthScheme -SqlInstance $server -WarningVariable authwarning -WarningAction SilentlyContinue).AuthScheme
            } catch {
                $authscheme = $_
            }

            if ($authwarning) {
                $authscheme = "N/A"
            }

            [pscustomobject]@{
                ComputerName         = $resolved.ComputerName
                InstanceName         = $instanceName
                SqlInstance          = $instance.FullSmoName
                SqlVersion           = $server.Version
                ConnectingAsUser     = $username
                ConnectSuccess       = $connectSuccess
                AuthType             = $authType
                AuthScheme           = $authscheme
                TcpPort              = $tcpport
                IPAddress            = $resolved.IPAddress
                NetBiosName          = $resolved.FullComputerName
                IsPingable           = $pingable
                PSRemotingAccessible = $remoting
                DomainName           = $resolved.Domain
                LocalWindows         = $localInfo.Windows
                LocalPowerShell      = $localInfo.PowerShell
                LocalCLR             = $localInfo.CLR
                LocalSMOVersion      = $localInfo.SMO
                LocalDomainUser      = $localInfo.DomainUser
                LocalRunAsAdmin      = $localInfo.RunAsAdmin
                LocalEdition         = $localInfo.Edition
            }
        }
    }
    end {
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Test-SqlConnection
    }
}