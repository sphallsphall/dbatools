$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tags "UnitTests" {
    Context "Validate parameters" {
        $knownParameters = 'Source', 'Destination', 'SourceSqlCredential', 'SourceCredential', 'DestinationSqlCredential', 'DestinationCredential', 'Database', 'BackupNetworkPath', 'BackupLocalPath', 'BackupJob', 'BackupRetention', 'BackupSchedule', 'BackupScheduleDisabled', 'BackupScheduleFrequencyType', 'BackupScheduleFrequencyInterval', 'BackupScheduleFrequencySubdayType', 'BackupScheduleFrequencySubdayInterval', 'BackupScheduleFrequencyRelativeInterval', 'BackupScheduleFrequencyRecurrenceFactor', 'BackupScheduleStartDate', 'BackupScheduleEndDate', 'BackupScheduleStartTime', 'BackupScheduleEndTime', 'BackupThreshold', 'CompressBackup', 'CopyDestinationFolder', 'CopyJob', 'CopyRetention', 'CopySchedule', 'CopyScheduleDisabled', 'CopyScheduleFrequencyType', 'CopyScheduleFrequencyInterval', 'CopyScheduleFrequencySubdayType', 'CopyScheduleFrequencySubdayInterval', 'CopyScheduleFrequencyRelativeInterval', 'CopyScheduleFrequencyRecurrenceFactor', 'CopyScheduleStartDate', 'CopyScheduleEndDate', 'CopyScheduleStartTime', 'CopyScheduleEndTime', 'DisconnectUsers', 'FullBackupPath', 'GenerateFullBackup', 'HistoryRetention', 'NoRecovery', 'NoInitialization', 'PrimaryMonitorServer', 'PrimaryMonitorCredential', 'PrimaryMonitorServerSecurityMode', 'PrimaryThresholdAlertEnabled', 'RestoreDataFolder', 'RestoreLogFolder', 'RestoreDelay', 'RestoreAlertThreshold', 'RestoreJob', 'RestoreRetention', 'RestoreSchedule', 'RestoreScheduleDisabled', 'RestoreScheduleFrequencyType', 'RestoreScheduleFrequencyInterval', 'RestoreScheduleFrequencySubdayType', 'RestoreScheduleFrequencySubdayInterval', 'RestoreScheduleFrequencyRelativeInterval', 'RestoreScheduleFrequencyRecurrenceFactor', 'RestoreScheduleStartDate', 'RestoreScheduleEndDate', 'RestoreScheduleStartTime', 'RestoreScheduleEndTime', 'RestoreThreshold', 'SecondaryDatabasePrefix', 'SecondaryDatabaseSuffix', 'SecondaryMonitorServer', 'SecondaryMonitorCredential', 'SecondaryMonitorServerSecurityMode', 'SecondaryThresholdAlertEnabled', 'Standby', 'StandbyDirectory', 'UseLastBackup', 'UseBackupFolder', 'Force', 'EnableException'
        $paramCount = $knownParameters.Count
        $defaultParamCount = 13

        $command = Get-Command -Name $CommandName
        [object[]]$params = $command.Parameters.Keys

        It "Should contain our specific parameters" {
            ((Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count) | Should Be $paramCount
        }

        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
        $dbname = "dbatoolsci_logshipping"
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $server.Query("CREATE DATABASE $dbname")
    }
    AfterAll {
        Remove-DbaDatabase -SqlInstance $script:instance2, $script:instance3 -Database $dbname -Confirm:$false
    }
    
    It "returns success" {
        $results = Invoke-DbaDbLogShipping -SourceSqlInstance $script:instance2 -DestinationSqlInstance $script:instance3 -Database $dbname -BackupNetworkPath C:\temp -BackupLocalPath "C:\temp\logshipping\backup" -GenerateFullBackup -CompressBackup -SecondaryDatabaseSuffix "_LS" -Force
        $results.Status -eq 'Success' | Should Be $true
    }
}
