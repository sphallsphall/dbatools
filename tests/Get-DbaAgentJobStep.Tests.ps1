$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance','SqlCredential','Job','ExcludeJob','ExcludeDisabledJobs','EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$CommandName Unittests" -Tag 'UnitTests' {
    InModuleScope 'dbatools' {
        Context "Return values" {
            Mock Connect-SQLInstance -MockWith {
                [object]@{
                    Name      = 'SQLServerName'
                    NetName   = 'SQLServerName'
                    JobServer = @{
                        Jobs = @(
                            @{
                                Name     = 'Job1'
                                JobSteps = @(
                                    @{
                                        Id   = 1
                                        Name = 'Job1Step1'
                                    },
                                    @{
                                        Id   = 2
                                        Name = 'Job1Step2'
                                    }
                                )
                            },
                            @{
                                Name     = 'Job2'
                                JobSteps = @(
                                    @{
                                        Id   = 1
                                        Name = 'Job2Step1'
                                    },
                                    @{
                                        Id   = 2
                                        Name = 'Job2Step2'
                                    }
                                )
                            },
                            @{
                                Name     = 'Job3'
                                JobSteps = @(
                                    @{
                                        Id   = 1
                                        Name = 'Job3Step1'
                                    },
                                    @{
                                        Id   = 2
                                        Name = 'Job3Step2'
                                    }
                                )
                            }
                        )
                    }
                } #object
            } #mock connect-sqlserver

            It "Honors the Job parameter" {
                $Results = @()
                $Results += Get-DbaAgentJobStep -SqlInstance 'SQLServerName' -Job 'Job1'
                $Results.Length | Should Be 2
                $Results.Name | Should Match 'Job1'
                $Results.Name | Should Match 'Job1Step[12]'
            }
            It "Honors the ExcludeJob parameter" {
                $Results = @()
                $Results += Get-DbaAgentJobStep -SqlInstance 'SQLServerName' -ExcludeJob 'Job1'
                $Results.Length | Should Be 4
                $Results.Name | Should Match 'Job[23]Step[12]'
            }
        }
    }
}