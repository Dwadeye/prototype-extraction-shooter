# Fetches CC0 placeholder models for features we don't have art for yet.
#
# Source: https://github.com/trebeljahr/quaternius-showcase
# Models are by Quaternius (https://quaternius.com), released CC0 1.0 (public domain).
# The showcase repo itself is MIT (its website code); the GLB art is Quaternius CC0.
#
# These are temporary stand-ins. Kimi's generated "draft pack" / enhanced models
# are intended to replace them feature by feature.
#
# Re-runnable: existing files are skipped. Delete assets/placeholder/ to re-fetch.

$sha  = "e90ffea347393537703ae6f9d73e36492820f5a9"
$base = "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/$sha/public/glb"
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root "assets\placeholder"

# category|pack|file  (category == folder under assets/placeholder/)
$manifest = @"
armor|rpg_items_pack|Armor_Leather.glb
armor|rpg_items_pack|Armor_Metal.glb
armor|rpg_items_pack|Armor_Metal2.glb
armor|single_knight_pack|Helmet1.glb
armor|single_knight_pack|Helmet2.glb
armor|single_knight_pack|Helmet3.glb
attachments|modular_sci_fi_guns_pack|Scope_1.glb
attachments|modular_sci_fi_guns_pack|Scope_2.glb
attachments|modular_sci_fi_guns_pack|Sight_1.glb
attachments|modular_sci_fi_guns_pack|Grip_AR_1.glb
attachments|modular_sci_fi_guns_pack|Magazine_AR.glb
consumables|survival_pack|Bandages.glb
consumables|survival_pack|FirstAidKit.glb
consumables|survival_pack|FirstAidKit_Hard.glb
consumables|survival_pack|FlareGun.glb
consumables|survival_pack|GasCan.glb
loot|rpg_items_pack|Bone.glb
loot|rpg_items_pack|Skull.glb
loot|rpg_items_pack|Coin.glb
loot|rpg_items_pack|Gold_Ingots.glb
loot|rpg_items_pack|Mineral.glb
loot|rpg_items_pack|Crystal1.glb
loot|rpg_items_pack|Scroll.glb
loot|rpg_items_pack|Parchment.glb
loot|rpg_items_pack|Book1_Closed.glb
loot|rpg_items_pack|Key1.glb
loot|rpg_items_pack|Padlock.glb
loot|rpg_items_pack|Bag.glb
loot|rpg_items_pack|Backpack.glb
loot|rpg_items_pack|Chest_Closed.glb
loot|rpg_items_pack|Chest_Open.glb
props|survival_pack|Tent.glb
props|survival_pack|Bonfire_Fire.glb
props|survival_pack|WoodLog.glb
props|survival_pack|BearTrap_Open.glb
props|survival_pack|PropaneTank.glb
props|survival_pack|Radio.glb
props|medieval_village_pack|MarketStand_1.glb
props|medieval_village_pack|Cart.glb
props|medieval_village_pack|Barrel.glb
props|medieval_village_pack|Crate.glb
props|medieval_village_pack|Well.glb
props|medieval_village_pack|Bell_Tower.glb
props|medieval_village_pack|Gazebo.glb
props|medieval_village_pack|Hay.glb
props|medieval_village_pack|Smoke.glb
props|house_interior_pack|Shelf_Large.glb
props|house_interior_pack|Kitchen_Fridge.glb
buildings|medieval_village_pack|House_1.glb
buildings|medieval_village_pack|House_2.glb
buildings|medieval_village_pack|Inn.glb
buildings|medieval_village_pack|Blacksmith.glb
buildings|medieval_village_pack|Mill.glb
buildings|buildings_pack_2|Building1_Large.glb
buildings|buildings_pack_2|House1.glb
animals|animals_pack|Wolf.glb
animals|animals_pack|Fox.glb
animals|animals_pack|Deer.glb
animals|animals_pack|Stag.glb
animals|animals_pack|Bull.glb
animals|easy_enemies_pack|Rat.glb
animals|easy_enemies_pack|Spider.glb
characters|modular_men|Suit.glb|Suit_Man.glb
characters|modular_men|Worker.glb|Worker_Man.glb
characters|modular_women|Suit.glb|Suit_Woman.glb
"@

$ok = 0; $skip = 0; $fail = 0
foreach ($line in ($manifest -split "`n")) {
    $line = $line.Trim()
    if ($line -eq "") { continue }
    $parts = $line -split '\|'
    $cat = $parts[0]; $pack = $parts[1]; $file = $parts[2]
    $outname = if ($parts.Count -ge 4 -and $parts[3].Trim() -ne "") { $parts[3].Trim() } else { $file }
    $dir = Join-Path $dest $cat
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $out = Join-Path $dir $outname
    if (Test-Path $out) { $skip++; continue }
    $url = "$base/$pack/$file"
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 90
        $ok++
    } catch {
        $fail++
        Write-Output "FAIL $cat/$outname : $($_.Exception.Message)"
    }
}
Write-Output "done ok=$ok skip=$skip fail=$fail"
