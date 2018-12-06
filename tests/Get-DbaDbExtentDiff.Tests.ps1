$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 5
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaDbExtentDiff).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $dbname = "dbatoolsci_test_$(get-random)"
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $server.Query("Create Database [$dbname]")
    }
    AfterAll {
        Remove-DbaDatabase -SqlInstance $script:instance2 -Database $dbname -Confirm:$false
    }

    Context "Gets Changed Extents for Multiple Databases" {
        $results = Get-DbaDbExtentDiff -SqlInstance $script:instance2
        It "Gets results" {
            $results | Should Not Be $null
        }
        Foreach ($row in $results) {
            It "Should have extents for $($row.DatabaseName)" {
                $row.ExtentsTotal | Should BeGreaterThan 0
            }
            It "Should have extents changed for $($row.DatabaseName)" {
                $row.ExtentsChanged | Should BeGreaterOrEqual 0
            }
        }
    }
    Context "Gets Changed Extents for Single Database" {
        $results = Get-DbaDbExtentDiff -SqlInstance $script:instance2 -Database $dbname
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should have extents for $($results.DatabaseName)" {
            $results.ExtentsTotal | Should BeGreaterThan 0
        }
        It "Should have extents changed for $($results.DatabaseName)" {
            $results.ExtentsChanged | Should BeGreaterOrEqual 0
        }
    }
}