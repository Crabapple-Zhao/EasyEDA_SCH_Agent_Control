[CmdletBinding()]
param(
    [ValidateSet('discover', 'health', 'windows', 'execute')]
    [string]$Action = 'discover',

    [ValidateRange(0, 65535)]
    [int]$Port = 0,

    [string]$WindowId,

    [string]$Code
)

$ErrorActionPreference = 'Stop'

function Get-CandidatePorts {
    if ($Port -gt 0) {
        return ,$Port
    }
    return 49620..49629
}

function Find-EasyEdaGateway {
    foreach ($candidatePort in Get-CandidatePorts) {
        try {
            $health = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$candidatePort/health" `
                -Method Get `
                -TimeoutSec 1

            if ($null -ne $health) {
                return [pscustomobject]@{
                    Port   = $candidatePort
                    Health = $health
                }
            }
        }
        catch {
            continue
        }
    }

    throw 'No EasyEDA Run API Gateway was found on ports 49620-49629.'
}

$gateway = Find-EasyEdaGateway
$baseUri = "http://127.0.0.1:$($gateway.Port)"

switch ($Action) {
    'discover' {
        [pscustomobject]@{
            port   = $gateway.Port
            health = $gateway.Health
        } | ConvertTo-Json -Depth 32
    }

    'health' {
        $gateway.Health | ConvertTo-Json -Depth 32
    }

    'windows' {
        Invoke-RestMethod `
            -Uri "$baseUri/eda-windows" `
            -Method Get `
            -TimeoutSec 5 | ConvertTo-Json -Depth 32
    }

    'execute' {
        if ([string]::IsNullOrWhiteSpace($Code)) {
            throw 'The execute action requires -Code.'
        }

        $payload = [ordered]@{
            code = $Code
        }
        if (-not [string]::IsNullOrWhiteSpace($WindowId)) {
            $payload.windowId = $WindowId
        }

        Invoke-RestMethod `
            -Uri "$baseUri/execute" `
            -Method Post `
            -ContentType 'application/json' `
            -Body ($payload | ConvertTo-Json -Compress) `
            -TimeoutSec 35 | ConvertTo-Json -Depth 64
    }
}
