[CmdletBinding()]
param (
    [Parameter()]
    [string]$winX = "win64", # win64 or win32
    [Parameter()]
    [string]$server = "localhost", # server\instance
    [Parameter()]
    [string]$database = "ContosoRetailDW"
)

# Create sql connection and load the list of tables to a dataset
$connectionTemplate = "Data Source={0};Integrated Security=SSPI;Initial Catalog={1};"
$connectionString = [string]::Format($connectionTemplate, $server, $database)
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$tableQuery = "SELECT s.name AS schemaName, t.name AS tableName FROM sys.tables t INNER JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.name <> 'sysdiagrams' ORDER BY 1, 2"
$sqlCommand = New-Object System.Data.SqlClient.SqlCommand
$sqlCommand.CommandText = $tableQuery
$sqlCommand.Connection = $connection
$sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$sqlAdapter.SelectCommand = $sqlCommand
$dataset = New-Object System.Data.DataSet
$sqlAdapter.Fill($dataset) | Out-Null
$connection.Close()

# Download latest release details of odbc2parquet https://docs.github.com/en/free-pro-team@latest/rest/reference/repos#releases
$repo = "pacman82/odbc2parquet"
$releases = "https://api.github.com/repos/$repo/releases/latest" # is the most recent non-prerelease, non-draft release
$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
$file = "odbc2parquet-$winX"
$fileLocal = "$PSScriptRoot\$file.exe"
$download = "https://github.com/$repo/releases/download/$tag/$file"
If (Test-Path $fileLocal) { Remove-Item $fileLocal }
Invoke-WebRequest $download -Out $fileLocal

# Loop through all tables and export the table data
$path = "$PSScriptRoot\Parquet"
If (Test-Path $path) { Remove-Item -Recurse $path }
New-Item -ItemType Directory -Force $path | Out-Null
$connectionTemplateODBC = "Driver={0};Server={1};Trusted_Connection=Yes;Database={2};"
$connectionStringODBC = [string]::Format($connectionTemplateODBC, "ODBC Driver 17 for SQL Server", $server, $database)
foreach ($row in $dataset.Tables[0].Rows) {
    Write-Host "Extracting table [$($row[0])].[$($row[1])]"
    Start-Process -Wait -FilePath "$PSScriptRoot\odbc2parquet-$winX.exe" -ArgumentList @("query --connection-string ""$connectionStringODBC"" ""$path\$($row[0])-$($row[1]).par"" ""SELECT * FROM [$($row[0])].[$($row[1])]""")
}
Remove-Item $fileLocal
