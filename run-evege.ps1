$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeHome = if ($env:EVEGE_RUNTIME_HOME) { $env:EVEGE_RUNTIME_HOME } else { 'D:\evege-runtime' }
$javaHome = Join-Path $runtimeHome 'jdk\jdk8u504-b01'
$postgresHome = Join-Path $runtimeHome 'postgresql'
$dataDirectory = Join-Path $runtimeHome 'postgresql-data'
$passwordFile = Join-Path $runtimeHome 'evege-db-password.txt'
$databaseWasRunning = $false

$java = Join-Path $javaHome 'bin\java.exe'
$initdb = Join-Path $postgresHome 'bin\initdb.exe'
$pgctl = Join-Path $postgresHome 'bin\pg_ctl.exe'
$psql = Join-Path $postgresHome 'bin\psql.exe'
$createdb = Join-Path $postgresHome 'bin\createdb.exe'

foreach ($requiredPath in @($java, $initdb, $pgctl, $psql, $createdb)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Required local runtime file not found: $requiredPath. See README.md for setup."
    }
}

$env:JAVA_HOME = $javaHome
$env:PATH = "$(Join-Path $javaHome 'bin');$env:PATH"
$env:PGPASSWORD = 'evege_password'

Push-Location $projectRoot
try {
    & (Join-Path $projectRoot 'mvnw.cmd') -B package
    if ($LASTEXITCODE -ne 0) {
        throw "Maven build failed with exit code $LASTEXITCODE."
    }

    if (-not (Test-Path (Join-Path $dataDirectory 'PG_VERSION'))) {
        if (Test-Path $dataDirectory) {
            throw "PostgreSQL data folder exists but is not initialized: $dataDirectory"
        }
        Set-Content -Path $passwordFile -Value $env:PGPASSWORD -NoNewline -Encoding ASCII
        try {
            & $initdb "--pgdata=$dataDirectory" '--username=evege_user' '--auth=scram-sha-256' "--pwfile=$passwordFile" '--encoding=UTF8'
            if ($LASTEXITCODE -ne 0) {
                throw "PostgreSQL initialization failed with exit code $LASTEXITCODE."
            }
        } finally {
            Remove-Item -LiteralPath $passwordFile -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path (Join-Path $dataDirectory 'postmaster.pid')) {
        & $pgctl "--pgdata=$dataDirectory" status
        if ($LASTEXITCODE -ne 0) {
            throw 'PostgreSQL has a stale PID file. Check the local database before retrying.'
        }
        $databaseWasRunning = $true
    }
    if (-not $databaseWasRunning) {
        & $pgctl "--pgdata=$dataDirectory" "--log=$(Join-Path $runtimeHome 'postgresql.log')" --wait start
        if ($LASTEXITCODE -ne 0) {
            throw 'PostgreSQL did not start. Check D:\evege-runtime\postgresql.log.'
        }
    }

    $databaseExists = & $psql --host=127.0.0.1 --username=evege_user --dbname=postgres --tuples-only --no-align --command="SELECT 1 FROM pg_database WHERE datname = 'evege';"
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not connect to the local PostgreSQL server.'
    }
    if ($databaseExists -notcontains '1') {
        & $createdb --host=127.0.0.1 --username=evege_user evege
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the evege database.'
        }
    }

    Write-Host ''
    Write-Host 'evege is starting at http://localhost:8080'
    Write-Host 'Press Ctrl+C to stop evege. PostgreSQL data stays on D:.'
    & $java '-jar' (Join-Path $projectRoot 'target\evege-1.0.0.jar')
    if ($LASTEXITCODE -ne 0) {
        throw "evege exited with code $LASTEXITCODE."
    }
} finally {
    if (-not $databaseWasRunning -and (Test-Path (Join-Path $dataDirectory 'PG_VERSION'))) {
        & $pgctl "--pgdata=$dataDirectory" --wait stop
    }
    Pop-Location
}
