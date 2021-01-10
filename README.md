# odbc2parquet-PSscripts

PowerShell script(s) to programatically run the ODBC to Parquet tool written by pacman82 (<https://github.com/pacman82/odbc2parquet>)

&nbsp;

## Overview

The scripts will download the latest version of ODBC to Parquet and proceed to extract database tables to a subfolder of the location where the script is located.

&nbsp;

## Usage

This has been designed to be easy to run with only three key steps.

1. Where you run the script is where it will save the extracts. So pick a suitable location.
1. The script should be reviewed and edited to suite your situation. In windows 10 you just need to right click and select 'Open' to open the script in Notepad.
1. Then in Windows 10 all you need to do right click the script and select 'Run with PowerShell'.

&nbsp;

## Customisation

The script has a few areas that can be edited to make it work in your situation.

&nbsp;

### Database Selection

The below parameters are the core options. Server, database and bitness.

``` PowerShell
param (
    [Parameter()]
    [string]$winX = "win64", # win64 or win32 (version of odbc2parquet to use)
    [Parameter()]
    [string]$server = "localhost", # server\instance
    [Parameter()]
    [string]$database = "ContosoRetailDW" # database
)
```

&nbsp;

### Extract Selection

Limiting the exported rows can be achieved by changing this block SQL code.

``` PowerShell
"SELECT * FROM [$($row[0])].[$($row[1])]"
```

i.e. this would limit to the first 10 rows of each table.

``` PowerShell
"SELECT TOP 10 * FROM [$($row[0])].[$($row[1])]"
```

&nbsp;

### Table Selection

The table selection can also be changed by changing this block of SQL code.

``` PowerShell
"SELECT s.name AS schemaName, t.name AS tableName FROM sys.tables t INNER JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.name <> 'sysdiagrams' ORDER BY 1, 2"
```

i.e. this would limit to tables in the database schema 'sales'.

``` PowerShell
"SELECT s.name AS schemaName, t.name AS tableName FROM sys.tables t INNER JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.name <> 'sysdiagrams' AND s.name = 'sales' ORDER BY 1, 2"
```
