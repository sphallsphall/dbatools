$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 5
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaEstimatedCompletionTime).Parameters.Keys
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

    Context "Gets Query Estimated Completion" {
        $results = Get-DbaEstimatedCompletionTime -SqlInstance $script:instance2 | Where-Object {$_.database -eq 'Master'}
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should be SELECT" {
            $results.Command | Should Be 'SELECT'
        }
        It "Should be login dbo" {
            $results.login | Should Be 'dbo'
        }
    }
    Context "Gets Query Estimated Completion when using -Database" {
        $results = Get-DbaEstimatedCompletionTime -SqlInstance $script:instance2 -Database Master
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should be SELECT" {
            $results.Command | Should Be 'SELECT'
        }
        It "Should be login dbo" {
            $results.login | Should Be 'dbo'
        }
    }
    Context "Gets no Query Estimated Completion when using -ExcludeDatabase" {
        $results = Get-DbaEstimatedCompletionTime -SqlInstance $script:instance2 -ExcludeDatabase Master
        It "Gets no results" {
            $results | Should Be $null
        }
    }
}