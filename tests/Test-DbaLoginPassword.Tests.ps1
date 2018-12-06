$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"
. "$PSScriptRoot\..\internal\functions\Get-PasswordHash.ps1"

Describe "$CommandName Unit Tests" -Tag UnitTests, Get-DbaLogin {
    Context "Validate parameters" {
        $paramCount = 6
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Test-DbaLoginPassword).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Dictionary', 'Login', 'InputObject', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance1
        $weaksauce = "dbatoolsci_testweak"
        $weakpass = ConvertTo-SecureString $weaksauce -AsPlainText -Force
        $newlogin = New-DbaLogin -SqlInstance $script:instance1 -Login $weaksauce -HashedPassword (Get-PasswordHash $weakpass $server.VersionMajor) -Force
    }
    AfterAll {
        try {
            $newlogin.Drop()
        } catch {
            # don't care
        }
    }

    Context "making sure command works" {
        It "finds the new weak password and supports piping" {
            $results = Get-DbaLogin -SqlInstance $script:instance1 | Test-DbaLoginPassword
            $results.SqlLogin | Should -Contain $weaksauce
        }
        It "returns just one login" {
            $results = Test-DbaLoginPassword -SqlInstance $script:instance1 -Login $weaksauce
            $results.SqlLogin | Should -Be $weaksauce
        }
    }
}