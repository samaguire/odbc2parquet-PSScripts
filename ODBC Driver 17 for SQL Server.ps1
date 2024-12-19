[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("win64", "win32")]
    [string]$winX = "win64",
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$server = "localhost",
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()] 
    [string]$database = "ContosoRetailDW",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$odbcDriver = "ODBC Driver 17 for SQL Server"
)

# Add error handling for database operations
try {
    Write-Verbose "Connecting to database $database on $server"
    $connectionTemplate = "Data Source={0};Integrated Security=SSPI;Initial Catalog={1};"
    $connectionString = [string]::Format($connectionTemplate, $server, $database)
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()

    $tableQuery = @"
        SELECT s.name AS schemaName, t.name AS tableName 
        FROM sys.tables t 
        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id 
        WHERE t.name <> 'sysdiagrams' 
        ORDER BY 1, 2
"@
    
    $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($tableQuery, $connection)
    $dataset = New-Object System.Data.DataSet
    $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($sqlCommand)
    $sqlAdapter.Fill($dataset) | Out-Null
}
catch {
    Write-Error "Database error: $_"
    exit 1
}
finally {
    if ($connection.State -eq 'Open') { $connection.Close() }
}

# Download odbc2parquet with error handling
try {
    Write-Verbose "Downloading odbc2parquet tool"
    $repo = "pacman82/odbc2parquet"
    $releases = "https://api.github.com/repos/$repo/releases/latest"
    $tag = (Invoke-WebRequest $releases -ErrorAction Stop | ConvertFrom-Json)[0].tag_name
    $file = "odbc2parquet-$winX"
    $fileLocal = Join-Path $PSScriptRoot "$file.exe"
    $download = "https://github.com/$repo/releases/download/$tag/$file"
    
    if (Test-Path $fileLocal) { Remove-Item $fileLocal -Force }
    Invoke-WebRequest $download -OutFile $fileLocal -ErrorAction Stop
}
catch {
    Write-Error "Download failed: $_"
    exit 1
}

# Export tables to Parquet
try {
    $path = Join-Path $PSScriptRoot "Parquet"
    if (Test-Path $path) { Remove-Item -Recurse -Path $path -Force }
    New-Item -ItemType Directory -Path $path -Force | Out-Null

    $connectionTemplateODBC = "Driver={0};Server={1};Trusted_Connection=Yes;Database={2};"
    $connectionStringODBC = [string]::Format($connectionTemplateODBC, 
                                           $odbcDriver, 
                                           $server, 
                                           $database)

    $totalTables = $dataset.Tables[0].Rows.Count
    $currentTable = 0

    foreach ($row in $dataset.Tables[0].Rows) {
        $currentTable++
        $tableName = "[$($row[0])].[$($row[1])]"
        Write-Progress -Activity "Exporting tables to Parquet" `
                      -Status "Processing $tableName" `
                      -PercentComplete (($currentTable/$totalTables)*100)

        $processParams = @{
            FilePath = $fileLocal
            ArgumentList = @(
                "query",
                "--connection-string",
                "`"$connectionStringODBC`"",
                "`"$path\$($row[0])-$($row[1]).par`"",
                "`"SELECT * FROM $tableName`""
            )
            Wait = $true
            NoNewWindow = $true
        }
        Start-Process @processParams
    }
}
catch {
    Write-Error "Export error: $_"
    exit 1}
finally {
    if (Test-Path $fileLocal) { Remove-Item $fileLocal -Force }
    Write-Progress -Activity "Exporting tables to Parquet" -Completed
}
