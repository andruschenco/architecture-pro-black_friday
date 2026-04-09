# test-cache-speed.ps1
# Script to test Redis caching performance

Write-Host "=== Cache Speed Test ===" -ForegroundColor Cyan

$url = "http://localhost:8089/users/users"

# First request (without cache)
Write-Host "`n1. First request (without cache):" -ForegroundColor Yellow
$firstRequest = Measure-Command {
    $response1 = Invoke-RestMethod -Uri $url
}
Write-Host "   Time: $($firstRequest.TotalMilliseconds) ms" -ForegroundColor White

# Second request (with cache)
Write-Host "`n2. Second request (with cache):" -ForegroundColor Yellow
$secondRequest = Measure-Command {
    $response2 = Invoke-RestMethod -Uri $url
}
Write-Host "   Time: $($secondRequest.TotalMilliseconds) ms" -ForegroundColor White

# Third request (with cache)
Write-Host "`n3. Third request (with cache):" -ForegroundColor Yellow
$thirdRequest = Measure-Command {
    $response3 = Invoke-RestMethod -Uri $url
}
Write-Host "   Time: $($thirdRequest.TotalMilliseconds) ms" -ForegroundColor White

# Results
Write-Host "`n=== Results ===" -ForegroundColor Cyan
Write-Host "First request: $($firstRequest.TotalMilliseconds) ms" -ForegroundColor Magenta
Write-Host "Second request: $($secondRequest.TotalMilliseconds) ms" -ForegroundColor Green
Write-Host "Third request: $($thirdRequest.TotalMilliseconds) ms" -ForegroundColor Green

if ($secondRequest.TotalMilliseconds -lt 100) {
    Write-Host "`Caching is working! Response time < 100 ms" -ForegroundColor Green
} else {
    Write-Host "`Caching is not working or not configured" -ForegroundColor Red
}