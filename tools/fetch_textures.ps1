# Fetches CC0 PBR textures from Poly Haven (https://polyhaven.com, CC0) into
# assets/textures/<name>/ as 1k JPGs: Diffuse, nor_gl (OpenGL normal), Rough, AO.
# Re-runnable: existing files are skipped.

$textures = @(
	@{ id = "grass_medium_01"; name = "grass" },
	@{ id = "asphalt_03"; name = "asphalt" },
	@{ id = "brushed_concrete"; name = "concrete" },
	@{ id = "corrugated_iron"; name = "metal" }
)

$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root "assets\textures"
$ok = 0; $skip = 0; $fail = 0

foreach ($t in $textures) {
	$dir = Join-Path $dest $t.name
	New-Item -ItemType Directory -Force -Path $dir | Out-Null
	try {
		$json = Invoke-RestMethod "https://api.polyhaven.com/files/$($t.id)" -TimeoutSec 60
	} catch {
		Write-Output "FAIL $($t.name): api $($_.Exception.Message)"
		$fail++
		continue
	}
	foreach ($map in @("Diffuse", "nor_gl", "Rough", "AO")) {
		$entry = $json.$map
		if ($null -eq $entry) { continue }
		$url = $entry.'1k'.jpg.url
		if (-not $url) { $url = $entry.'1k'.png.url }
		if (-not $url) { continue }
		$ext = [System.IO.Path]::GetExtension($url)
		$out = Join-Path $dir ("$($map)$ext")
		if (Test-Path $out) { $skip++; continue }
		try {
			Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 120
			$ok++
		} catch {
			Write-Output "FAIL $($t.name)/$map"
			$fail++
		}
	}
}
Write-Output "textures done ok=$ok skip=$skip fail=$fail"
