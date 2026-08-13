$ErrorActionPreference = 'Stop'
$client = Join-Path $PSScriptRoot 'tools\neolabs.py'
if (-not (Test-Path $client)) { throw 'NeoLabs client file is missing from this toolkit.' }
if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 $client @args
    exit $LASTEXITCODE
}
if (Get-Command python -ErrorAction SilentlyContinue) {
    & python $client @args
    exit $LASTEXITCODE
}
throw 'Python 3.10 or newer is required.'
