$items = @(
    'Twilight Blade Barrier', 
    'Fetish of the Vanquished Foe', 
    'Amani Hex Crest', 
    'Hex-Horn Buckler', 
    "Forest Berserker's Hatchet", 
    'Blood Oath Tome', 
    'Sunfury Great Bulwark', 
    "Sin'dorei Crystal Focus", 
    'Onyx Bloodknight Bladestaff'
)

foreach ($item in $items) {
    $url = 'https://www.wowhead.com/search?q=' + [uri]::EscapeDataString($item) + '&opensearch'
    try {
        $response = Invoke-RestMethod -Uri $url -Headers @{'User-Agent'='Mozilla/5.0'}
        Write-Host "$item : $($response[3][0])"
    } catch {
        Write-Host "$item : Error"
    }
}
