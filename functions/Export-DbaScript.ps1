function Export-DbaScript {
    <#
    .SYNOPSIS
        Exports scripts from SQL Management Objects (SMO)

    .DESCRIPTION
        Exports scripts from SQL Management Objects

    .PARAMETER InputObject
        A SQL Management Object such as the one returned from Get-DbaLogin

    .PARAMETER Path
        The output filename and location. If no path is specified, one will be created. If the file already exists, the output will be appended.

    .PARAMETER Encoding
        Specifies the file encoding. The default is UTF8.

        Valid values are:
        -- ASCII: Uses the encoding for the ASCII (7-bit) character set.
        -- BigEndianUnicode: Encodes in UTF-16 format using the big-endian byte order.
        -- Byte: Encodes a set of characters into a sequence of bytes.
        -- String: Uses the encoding type for a string.
        -- Unicode: Encodes in UTF-16 format using the little-endian byte order.
        -- UTF7: Encodes in UTF-7 format.
        -- UTF8: Encodes in UTF-8 format.
        -- Unknown: The encoding type is unknown or invalid. The data can be treated as binary.

    .PARAMETER Passthru
        Output script to console

    .PARAMETER ScriptingOptionsObject
        An SMO Scripting Object that can be used to customize the output - see New-DbaScriptingOption

    .PARAMETER BatchSeparator
        Specifies the Batch Separator to use. Default is None

    .PARAMETER NoPrefix
        Do not include a Prefix

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed

    .PARAMETER NoClobber
        Do not overwrite file

    .PARAMETER Append
        Append to file

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Migration, Backup, Export
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Export-DbaScript

    .EXAMPLE
        PS C:\> Get-DbaAgentJob -SqlInstance sql2016 | Export-DbaScript

        Exports all jobs on the SQL Server sql2016 instance using a trusted connection - automatically determines filename as .\sql2016-Job-Export-date.sql

    .EXAMPLE
        PS C:\> Get-DbaAgentJob -SqlInstance sql2016 | Export-DbaScript -Path C:\temp\export.sql -Append

        Exports all jobs on the SQL Server sql2016 instance using a trusted connection - Will append the output to the file C:\temp\export.sql if it already exists
        Script does not include Batch Separator and will not compile

    .EXAMPLE
        PS C:\> Get-DbaDbTable -SqlInstance sql2016 -Database MyDatabase -Table 'dbo.Table1', 'dbo.Table2' -SqlCredential sqladmin | Export-DbaScript -Path C:\temp\export.sql

        Exports only script for 'dbo.Table1' and 'dbo.Table2' in MyDatabase to C:temp\export.sql and uses the SQL login "sqladmin" to login to sql2016

    .EXAMPLE
        PS C:\> Get-DbaAgentJob -SqlInstance sql2016 -Job syspolicy_purge_history, 'Hourly Log Backups' -SqlCredential sqladmin | Export-DbaScript -Path C:\temp\export.sql -NoPrefix

        Exports only syspolicy_purge_history and 'Hourly Log Backups' to C:temp\export.sql and uses the SQL login "sqladmin" to login to sql2016
        Suppress the output of a Prefix

    .EXAMPLE
        PS C:\> $options = New-DbaScriptingOption
        PS C:\> $options.ScriptSchema = $true
        PS C:\> $options.IncludeDatabaseContext  = $true
        PS C:\> $options.IncludeHeaders = $false
        PS C:\> $Options.NoCommandTerminator = $false
        PS C:\> $Options.ScriptBatchTerminator = $true
        PS C:\> $Options.AnsiFile = $true
        PS C:\> Get-DbaAgentJob -SqlInstance sql2016 -Job syspolicy_purge_history, 'Hourly Log Backups' -SqlCredential sqladmin | Export-DbaScript -Path C:\temp\export.sql -ScriptingOptionsObject $options

        Exports only syspolicy_purge_history and 'Hourly Log Backups' to C:temp\export.sql and uses the SQL login "sqladmin" to login to sql2016
        Appends a batch separator at end of each script.

    .EXAMPLE
        PS C:\> Get-DbaAgentJob -SqlInstance sql2014 | Export-DbaScript -Passthru | ForEach-Object { $_.Replace('sql2014','sql2016') } | Set-Content -Path C:\temp\export.sql

        Exports jobs and replaces all instances of the servername "sql2014" with "sql2016" then writes to C:\temp\export.sql

    .EXAMPLE
        PS C:\> $options = New-DbaScriptingOption
        PS C:\> $options.ScriptSchema = $true
        PS C:\> $options.IncludeDatabaseContext  = $true
        PS C:\> $options.IncludeHeaders = $false
        PS C:\> $Options.NoCommandTerminator = $false
        PS C:\> $Options.ScriptBatchTerminator = $true
        PS C:\> $Options.AnsiFile = $true
        PS C:\> $Databases = Get-DbaDatabase -SqlInstance sql2016 -ExcludeDatabase master, model, msdb, tempdb
        PS C:\> foreach ($db in $Databases) {
        >>        Export-DbaScript -InputObject $db -Path C:\temp\export.sql -Append -Encoding UTF8 -ScriptingOptionsObject $options -NoPrefix
        >> }

        Exports Script for each database on sql2016 excluding system databases
        Uses Scripting options to ensure Batch Terminator is set
        Will append the output to the file C:\temp\export.sql if it already exists

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        [Alias("ScriptingOptionObject")]
        [Microsoft.SqlServer.Management.Smo.ScriptingOptions]$ScriptingOptionsObject,
        [string]$Path,
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Byte', 'String', 'Unicode', 'UTF7', 'UTF8', 'Unknown')]
        [string]$Encoding = 'UTF8',
        [string]$BatchSeparator = '',
        [switch]$NoPrefix,
        [switch]$Passthru,
        [switch]$NoClobber,
        [switch]$Append,
        [Alias('Silent')]
        [switch]$EnableException
    )

    begin {
        $executingUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $commandName = $MyInvocation.MyCommand.Name
        $timeNow = (Get-Date -uformat "%m%d%Y%H%M%S")
        $prefixArray = @()
    }

    process {
        foreach ($object in $InputObject) {

            $typename = $object.GetType().ToString()

            if ($typename.StartsWith('Microsoft.SqlServer.')) {
                $shortype = $typename.Split(".")[-1]
            } else {
                Stop-Function -Message "InputObject is of type $typename which is not a SQL Management Object. Only SMO objects are supported." -Category InvalidData -Target $object -Continue
            }

            if ($shortype -in "LinkedServer", "Credential", "Login") {
                Write-Message -Level Warning -Message "Support for $shortype is limited at this time. No passwords, hashed or otherwise, will be exported if they exist."
            }

            # Just gotta add the stuff that Nic Cain added to his script

            if ($shortype -eq "Configuration") {
                Write-Message -Level Warning -Message "Support for $shortype is limited at this time."
            }

            # Find the server object to pass on to the function
            $parent = $object.parent

            do {
                if ($parent.Urn.Type -ne "Server") {
                    $parent = $parent.Parent
                }
            }
            until (($parent.Urn.Type -eq "Server") -or (-not $parent))

            if (-not $parent -and -not (Get-Member -InputObject $object -Name ScriptCreate) ) {
                Stop-Function -Message "Failed to find valid SMO server object in input: $object." -Category InvalidData -Target $object -Continue
            }

            try {
                $server = $parent
                if (-not $server) {
                    $server = $object.Parent
                }
                $serverName = $server.Name.Replace('\', '$')

                if ($ScriptingOptionsObject) {
                    $scripter = New-Object Microsoft.SqlServer.Management.Smo.Scripter $server
                    $scripter.Options = $ScriptingOptionsObject
                }

                if (!$passthru) {
                    if ($path) {
                        $actualPath = $path
                    } else {
                        $actualPath = "$serverName-$shortype-Export-$timeNow.sql"
                    }
                }

                if ($NoPrefix) {
                    $prefix = ""
                } else {
                    $prefix = "/*`n`tCreated by $executingUser using dbatools $commandName for objects on $serverName at $(Get-Date)`n`tSee https://dbatools.io/$commandName for more information`n*/"
                }

                if ($passthru) {
                    $prefix | Out-String
                } else {
                    if ($prefixArray -notcontains $actualPath) {

                        if ((Test-Path -Path $actualPath) -and $NoClobber) {
                            Stop-Function -Message "File already exists. If you want to overwrite it remove the -NoClobber parameter. If you want to append data, please Use -Append parameter." -Target $actualPath -Continue
                        }
                        #Only at the first output we use the passed variables Append & NoClobber. For this execution the next ones need to buse -Append
                        $prefix | Out-File -FilePath $actualPath -Encoding $encoding -Append:$Append -NoClobber:$NoClobber
                        $prefixArray += $actualPath
                    }
                }

                if ($Pscmdlet.ShouldProcess($env:computername, "Exporting $object from $server to $actualPath")) {
                    Write-Message -Level Verbose -Message "Exporting $object"

                    if ($passthru) {
                        if ($ScriptingOptionsObject) {
                            foreach ($script in $scripter.EnumScript($object)) {
                                if ($BatchSeparator -ne "") {
                                    $script = "$script`r`n$BatchSeparator`r`n"
                                }
                                $script | Out-String
                            }
                        } else {
                            if (Get-Member -Name ScriptCreate -InputObject $object) {
                                $script = $object.ScriptCreate().GetScript()
                            } else {
                                $script = $object.Script()
                            }

                            if ($BatchSeparator -ne "") {
                                $script = "$script`r`n$BatchSeparator`r`n"
                            }
                            $script  | Out-String
                        }
                    } else {
                        if ($ScriptingOptionsObject) {
                            if ($ScriptingOptionsObject.ScriptBatchTerminator) {
                                $ScriptingOptionsObject.AppendToFile = $true
                                $ScriptingOptionsObject.ToFileOnly = $true
                                $ScriptingOptionsObject.FileName = $actualPath
                                $object.Script($ScriptingOptionsObject)
                            } else {
                                foreach ($script in $scripter.EnumScript($object)) {
                                    if ($BatchSeparator -ne "") {
                                        $script = "$script`r`n$BatchSeparator`r`n"
                                    }
                                    $script | Out-File -FilePath $actualPath -Encoding $encoding -Append
                                }
                            }

                        } else {
                            if (Get-Member -Name ScriptCreate -InputObject $object) {
                                $script = $object.ScriptCreate().GetScript()
                            } else {
                                $script = $object.Script()
                            }
                            if ($BatchSeparator -ne "") {
                                $script = "$script`r`n$BatchSeparator`r`n"
                            }
                            $script | Out-File -FilePath $actualPath -Encoding $encoding -Append
                        }
                    }

                    if (-not $passthru) {
                        Write-Message -Level Verbose -Message "Exported $object on $($server.Name) to $actualPath"
                        Get-ChildItem -Path $actualPath
                    }
                }
            } catch {
                $message = $_.Exception.InnerException.InnerException.InnerException.Message
                if (-not $message) {
                    $message = $_.Exception
                }
                Stop-Function -Message "Failure on $($server.Name) | $message" -Target $server
            }
        }
    }
}