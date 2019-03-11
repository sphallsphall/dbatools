$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tags "UnitTests" {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance','SqlCredential','Name','InputObject','EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {
    Context "Setup" {
        BeforeAll {
            $group = "dbatoolsci-group1"
            $newGroup = Add-DbaCmsRegServerGroup -SqlInstance $script:instance1 -Name $group

            $group2 = "dbatoolsci-group1a"
            $newGroup2 = Add-DbaCmsRegServerGroup -SqlInstance $script:instance1 -Name $group2

            $hellagroup = Get-DbaCmsRegServerGroup -SqlInstance $script:instance1 -Id 1 | Add-DbaCmsRegServerGroup -Name dbatoolsci-first | Add-DbaCmsRegServerGroup -Name dbatoolsci-second | Add-DbaCmsRegServerGroup -Name dbatoolsci-third | Add-DbaCmsRegServer -ServerName dbatoolsci-test -Description ridiculous
        }
        AfterAll {
            Get-DbaCmsRegServerGroup -SqlInstance $script:instance1 | Where-Object Name -match dbatoolsci | Remove-DbaCmsRegServerGroup -Confirm:$false
        }

        It "supports dropping via the pipeline" {
            $results = $newGroup | Remove-DbaCmsRegServerGroup -Confirm:$false
            $results.Name | Should -Be $group
            $results.Status | Should -Be 'Dropped'
        }

        It "supports dropping manually" {
            $results = Remove-DbaCmsRegServerGroup -Confirm:$false -SqlInstance $script:instance1 -Name $group2
            $results.Name | Should -Be $group2
            $results.Status | Should -Be 'Dropped'
        }

        It "supports hella long group name" {
            $results = Get-DbaCmsRegServerGroup -SqlInstance $script:instance1 -Group $hellagroup.Group
            $results.Name | Should -Be 'dbatoolsci-third'
        }
    }
}