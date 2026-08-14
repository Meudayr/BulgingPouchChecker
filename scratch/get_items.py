import urllib.request
import urllib.parse
import re

items = [
    'Twilight Blade Barrier',
    'Fetish of the Vanquished Foe',
    'Amani Hex Crest',
    'Hex-Horn Buckler',
    "Forest Berserker's Hatchet",
    'Blood Oath Tome',
    'Sunfury Great Bulwark',
    "Sin'dorei Crystal Focus",
    'Onyx Bloodknight Bladestaff'
]

for item in items:
    url = 'https://www.wowhead.com/search?q=' + urllib.parse.quote(item)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        resp = urllib.request.urlopen(req)
        final_url = resp.geturl()
        html = resp.read().decode('utf-8')
        
        item_id = 'Unknown'
        icon = 'Unknown'
        
        if '/item=' in final_url:
            m = re.search(r'/item=(\d+)', final_url)
            if m: item_id = m.group(1)
            icon_m = re.search(r'"icon":"([^"]+)"', html)
            if icon_m: icon = icon_m.group(1)
        else:
            m = re.search(r'"id":(\d+),.*?"name":"[^"]*?'+re.escape(item)+r'[^"]*?".*?"icon":"([^"]+)"', html, re.IGNORECASE)
            if m:
                item_id = m.group(1)
                icon = m.group(2)
                
        print(f'{item}: itemID={item_id}, icon={icon}')
    except Exception as e:
        print(f'{item}: Error {e}')
