$ErrorActionPreference = "Stop"

$BaseUrl = "https://messenger-server.tail9da30d.ts.net"
$ResultsDir = Join-Path $PSScriptRoot "..\results"

New-Item -ItemType Directory -Force $ResultsDir | Out-Null

function Save-Curl {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $Path = Join-Path $ResultsDir $Name
    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
    & curl.exe @Arguments | Tee-Object -FilePath $Path
}

Write-Host "Checking Matrix API..." -ForegroundColor Green

Save-Curl "01_versions.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/versions"
)

Save-Curl "02_login_flows.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/v3/login"
)

Write-Host ""
Write-Host "Paste access token from Element." -ForegroundColor Yellow
$secureToken = Read-Host "Access token" -AsSecureString
$token = (New-Object System.Net.NetworkCredential("", $secureToken)).Password

Save-Curl "03_whoami_without_token.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/v3/account/whoami"
)

Save-Curl "04_whoami_with_token.txt" @(
    "-sS", "-i",
    "-H", "Authorization: Bearer $token",
    "$BaseUrl/_matrix/client/v3/account/whoami"
)

Save-Curl "05_joined_rooms_without_token.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/v3/joined_rooms"
)

Save-Curl "06_joined_rooms_with_token.txt" @(
    "-sS", "-i",
    "-H", "Authorization: Bearer $token",
    "$BaseUrl/_matrix/client/v3/joined_rooms"
)

Save-Curl "07_public_rooms_without_token.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/v3/publicRooms?limit=10"
)

Save-Curl "08_public_rooms_with_token.txt" @(
    "-sS", "-i",
    "-H", "Authorization: Bearer $token",
    "$BaseUrl/_matrix/client/v3/publicRooms?limit=10"
)

$whoami = Invoke-RestMethod `
    -Uri "$BaseUrl/_matrix/client/v3/account/whoami" `
    -Headers @{ Authorization = "Bearer $token" }

$userId = $whoami.user_id
$userIdEscaped = [uri]::EscapeDataString($userId)

Save-Curl "09_profile_without_token.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/v3/profile/$userIdEscaped"
)

Save-Curl "10_profile_with_token.txt" @(
    "-sS", "-i",
    "-H", "Authorization: Bearer $token",
    "$BaseUrl/_matrix/client/v3/profile/$userIdEscaped"
)

Save-Curl "11_sync_without_token.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/v3/sync?timeout=0"
)

Save-Curl "12_sync_with_token.txt" @(
    "-sS", "-i",
    "-H", "Authorization: Bearer $token",
    "$BaseUrl/_matrix/client/v3/sync?timeout=0"
)

Write-Host ""
Write-Host "Paste test room_id from Element." -ForegroundColor Yellow
$roomId = '!xFgvWGzimsIkzuApJj:kirill417163'
$roomIdEscaped = [uri]::EscapeDataString($roomId)

Save-Curl "13_messages_without_token.txt" @(
    "-sS", "-i",
    "$BaseUrl/_matrix/client/v3/rooms/$roomIdEscaped/messages?dir=b&limit=10"
)

Save-Curl "14_messages_with_token.txt" @(
    "-sS", "-i",
    "-H", "Authorization: Bearer $token",
    "$BaseUrl/_matrix/client/v3/rooms/$roomIdEscaped/messages?dir=b&limit=10"
)

$bodyWithoutToken = @{
    msgtype = "m.text"
    body = "API test without token"
} | ConvertTo-Json -Compress

$txn = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

Save-Curl "15_send_without_token.txt" @(
    "-sS", "-i",
    "-X", "PUT",
    "-H", "Content-Type: application/json",
    "--data-raw", $bodyWithoutToken,
    "$BaseUrl/_matrix/client/v3/rooms/$roomIdEscaped/send/m.room.message/$txn"
)

$bodyWithToken = @{
    msgtype = "m.text"
    body = "Message sent through Matrix API"
} | ConvertTo-Json -Compress

$txn = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

Save-Curl "16_send_with_token.txt" @(
    "-sS", "-i",
    "-X", "PUT",
    "-H", "Authorization: Bearer $token",
    "-H", "Content-Type: application/json",
    "--data-raw", $bodyWithToken,
    "$BaseUrl/_matrix/client/v3/rooms/$roomIdEscaped/send/m.room.message/$txn"
)

Write-Host ""
Write-Host "Done. Results are saved to api_research/results." -ForegroundColor Green
Write-Host "Before commit, check that token was not saved." -ForegroundColor Yellow