$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        <#
            Get commands, Default count = 11
            Commands with SupportShouldProcess = 13
        #>
        $defaultParamCount = 13
        [object[]]$params = (Get-ChildItem function:\Add-DbaAgDatabase).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'AvailabilityGroup', 'Database', 'InputObject', 'EnableException', 'SeedingMode', 'SharedPath', 'UseLastBackup', 'Secondary', 'SecondarySqlCredential'
        $paramCount = $knownParameters.Count
        It "Should contain our specific parameters" {
            ((Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $null = Get-DbaProcess -SqlInstance $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
        $server = Connect-DbaInstance -SqlInstance $script:instance3
        $agname = "dbatoolsci_addagdb_agroup"
        $dbname = "dbatoolsci_addagdb_agroupdb"
        $newdbname = "dbatoolsci_addag_agroupdb_2"
        $server.Query("create database $dbname")
        $backup = Get-DbaDatabase -SqlInstance $script:instance3 -Database $dbname | Backup-DbaDatabase
        $ag = New-DbaAvailabilityGroup -Primary $script:instance3 -Name $agname -ClusterType None -FailoverMode Manual -Database $dbname -Confirm:$false -Certificate dbatoolsci_AGCert
    }
    AfterAll {
        $null = Remove-DbaAvailabilityGroup -SqlInstance $server -AvailabilityGroup $agname -Confirm:$false
        $null = Remove-DbaDatabase -SqlInstance $server -Database $dbname, $newdbname -Confirm:$false
    }
    Context "adds ag db" {
        It "returns proper results" {
            $server.Query("create database $newdbname")
            $backup = Get-DbaDatabase -SqlInstance $script:instance3 -Database $newdbname | Backup-DbaDatabase
            $results = Add-DbaAgDatabase -SqlInstance $script:instance3 -AvailabilityGroup $agname -Database $newdbname -Confirm:$false
            $results.AvailabilityGroup | Should -Be $agname
            $results.Name | Should -Be $newdbname
            $results.IsJoined | Should -Be $true
        }
    }
} #$script:instance2 for appveyor