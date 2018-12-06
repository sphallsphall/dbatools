$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 6
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaDbMailProfile).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Profile', 'ExcludeProfile', 'InputObject', 'EnableException'
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
        $profilename = "dbatoolsci_test_$(get-random)"
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $mailProfile = "EXEC msdb.dbo.sysmail_add_profile_sp
            @profile_name='$profilename',
            @description='Profile for system email';"
        $server.query($mailProfile)
    }
    AfterAll{
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $mailProfile = "EXEC msdb.dbo.sysmail_delete_profile_sp
            @profile_name='$profilename';"
        $server.query($mailProfile)
    }

    Context "Gets DbMail Profile" {
        $results = Get-DbaDbMailProfile -SqlInstance $script:instance2 | Where-Object {$_.name -eq "$profilename"}
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should have Name of $profilename" {
            $results.name | Should Be $profilename
        }
        It "Should have Desctiption of 'Profile for system email' " {
            $results.description | Should Be 'Profile for system email'
        }
    }
    Context "Gets DbMailProfile when using -Profile" {
        $results = Get-DbaDbMailProfile -SqlInstance $script:instance2 -Profile $profilename
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should have Name of $profilename" {
            $results.name | Should Be $profilename
        }
        It "Should have Desctiption of 'Profile for system email' " {
            $results.description | Should Be 'Profile for system email'
        }
    }
    Context "Gets no DbMailProfile when using -ExcludeProfile" {
        $results = Get-DbaDbMailProfile -SqlInstance $script:instance2 -ExcludeProfile $profilename
        It "Gets no results" {
            $results | Should Be $null
        }
    }
}