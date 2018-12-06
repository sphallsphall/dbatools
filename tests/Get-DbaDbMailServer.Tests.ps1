$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 6
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaDbMailServer).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Server', 'Account', 'InputObject', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll{
        $accountname = "dbatoolsci_test_$(get-random)"
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $mailAccountSettings = "EXEC msdb.dbo.sysmail_add_account_sp
            @account_name='$accountname',
            @description='Mail account for email alerts',
            @email_address='dbatoolssci@dbatools.io',
            @display_name ='dbatoolsci mail alerts',
            @mailserver_name='smtp.dbatools.io',
            @replyto_address='no-reply@dbatools.io';"
        $server.query($mailAccountSettings)
    }
    AfterAll{
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $mailAccountSettings = "EXEC msdb.dbo.sysmail_delete_account_sp
            @account_name = '$accountname';"
        $server.query($mailAccountSettings)
    }

    Context "Gets DbMailServer" {
        $results = Get-DbaDbMailServer -SqlInstance $script:instance2 | Where-Object {$_.account -eq "$accountname"}
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should have Account of $accounName" {
            $results.Account | Should Be $accountname
        }
        It "Should have Name of 'smtp.dbatools.io' " {
            $results.Name | Should Be 'smtp.dbatools.io'
        }
        It "Should have Port on 25" {
            $results.Port | Should Be 25
        }
        It "Should have SSL Disabled" {
            $results.EnableSSL | Should Be $false
        }
        It "Should have ServerType of 'SMTP' " {
            $results.ServerType | Should Be 'SMTP'
        }
    }
    Context "Gets DbMailServer using -Server" {
        $results = Get-DbaDbMailServer -SqlInstance $script:instance2 -Server 'smtp.dbatools.io'
        It "Gets results" {
            $results | Should Not Be $null
        }
    }
    Context "Gets DbMailServer using -Account" {
        $results = Get-DbaDbMailServer -SqlInstance $script:instance2 -Account $accounname
        It "Gets results" {
            $results | Should Not Be $null
        }
    }
}