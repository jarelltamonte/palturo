# End-to-end serving audit: every seeded account, both directions, fresh and
# cached, against the REAL get-matches Edge Function.
#
#   npx supabase@3.1.0 functions serve get-matches --env-file <dummy keys>
#   powershell -ExecutionPolicy Bypass -File supabase\tests\audit_local_serving.ps1
#
# Exits non-zero if any deck differs from the expected set.

$ErrorActionPreference = 'Stop'

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$status = cmd /c "npx --yes supabase@3.1.0 status -o env 2>nul"
$ErrorActionPreference = $previous

$anon = ($status | Where-Object { $_ -match '^ANON_KEY=' } | Select-Object -First 1) -replace '^ANON_KEY=', '' -replace '"', ''
$api = ($status | Where-Object { $_ -match '^API_URL=' } | Select-Object -First 1) -replace '^API_URL=', '' -replace '"', ''
if ([string]::IsNullOrWhiteSpace($anon)) { throw 'Local Supabase is not running.' }

$emails = @(
  'marisol.rivera@example.test', 'diego.santos@example.test', 'althea.cruz@example.test',
  'rafael.mendoza@example.test', 'lourdes.bautista@example.test', 'emilio.garcia@example.test',
  'bianca.reyes@example.test', 'marco.villanueva@example.test', 'carmela.delacruz@example.test',
  'nathaniel.ramos@example.test', 'sofia.aquino@example.test', 'gabriel.navarro@example.test',
  'isabella.torres@example.test', 'joaquin.castillo@example.test', 'camille.domingo@example.test',
  'elias.mercado@example.test', 'teresa.salazar@example.test', 'miguel.ferrer@example.test',
  'patricia.lim@example.test', 'andres.velasco@example.test'
)

# viewer|target|candidate name|skill path|kind
$rows = @(
  'marisol.rivera@example.test|learner|Rafael Mendoza|modern_practical_skills.programming.web_development|learn',
  'marisol.rivera@example.test|learner|Lourdes Bautista|modern_practical_skills.programming.web_development|learn',
  'marisol.rivera@example.test|learner|Gabriel Navarro|modern_practical_skills.programming.web_development|learn',
  'marisol.rivera@example.test|mentor|Lourdes Bautista|cooking_culinary.filipino_cooking|teach',
  'diego.santos@example.test|mentor|Andres Velasco|performing_arts.traditional_music|teach',
  'althea.cruz@example.test|learner|Sofia Aquino|modern_practical_skills.programming.python_programming|learn',
  'althea.cruz@example.test|mentor|Rafael Mendoza|modern_practical_skills.graphic_design|teach',
  'rafael.mendoza@example.test|learner|Althea Cruz|modern_practical_skills.graphic_design|learn',
  'rafael.mendoza@example.test|learner|Isabella Torres|modern_practical_skills.graphic_design|learn',
  'rafael.mendoza@example.test|mentor|Marisol Rivera|modern_practical_skills.programming.web_development|teach',
  'lourdes.bautista@example.test|learner|Marisol Rivera|cooking_culinary.filipino_cooking|learn',
  'lourdes.bautista@example.test|mentor|Marisol Rivera|modern_practical_skills.programming.web_development|teach',
  'emilio.garcia@example.test|learner|Andres Velasco|language_writing.calligraphy|learn',
  'emilio.garcia@example.test|mentor|Andres Velasco|performing_arts.traditional_music|teach',
  'bianca.reyes@example.test|learner|Marco Villanueva|performing_arts.folk_dance|learn',
  'bianca.reyes@example.test|mentor|Marco Villanueva|performing_arts.vocal_music|teach',
  'marco.villanueva@example.test|learner|Bianca Reyes|performing_arts.vocal_music|learn',
  'marco.villanueva@example.test|mentor|Bianca Reyes|performing_arts.folk_dance|teach',
  'carmela.delacruz@example.test|learner|Nathaniel Ramos|modern_practical_skills.sewing|learn',
  'carmela.delacruz@example.test|mentor|Nathaniel Ramos|traditional_crafts.philippine_handweaving|teach',
  'nathaniel.ramos@example.test|learner|Carmela Dela Cruz|traditional_crafts.philippine_handweaving|learn',
  'nathaniel.ramos@example.test|mentor|Carmela Dela Cruz|modern_practical_skills.sewing|teach',
  'sofia.aquino@example.test|mentor|Althea Cruz|modern_practical_skills.programming.python_programming|teach',
  'gabriel.navarro@example.test|mentor|Marisol Rivera|modern_practical_skills.programming.web_development|teach',
  'isabella.torres@example.test|learner|Miguel Ferrer|modern_practical_skills.tshirt_printing|learn',
  'isabella.torres@example.test|mentor|Rafael Mendoza|modern_practical_skills.graphic_design|teach',
  'joaquin.castillo@example.test|learner|Camille Domingo|traditional_crafts.filipino_embroidery|learn',
  'joaquin.castillo@example.test|mentor|Camille Domingo|traditional_crafts.costume_making|teach',
  'camille.domingo@example.test|learner|Joaquin Castillo|traditional_crafts.costume_making|learn',
  'camille.domingo@example.test|mentor|Joaquin Castillo|traditional_crafts.filipino_embroidery|teach',
  'elias.mercado@example.test|learner|Teresa Salazar|modern_practical_skills.motorcycle_maintenance|learn',
  'elias.mercado@example.test|mentor|Teresa Salazar|agriculture_livelihood.farming|teach',
  'teresa.salazar@example.test|learner|Elias Mercado|agriculture_livelihood.farming|learn',
  'teresa.salazar@example.test|mentor|Elias Mercado|modern_practical_skills.motorcycle_maintenance|teach',
  'miguel.ferrer@example.test|learner|Patricia Lim|modern_practical_skills.woodworking|learn',
  'miguel.ferrer@example.test|mentor|Isabella Torres|modern_practical_skills.tshirt_printing|teach',
  'miguel.ferrer@example.test|mentor|Patricia Lim|modern_practical_skills.tshirt_printing|teach',
  'patricia.lim@example.test|learner|Miguel Ferrer|modern_practical_skills.tshirt_printing|learn',
  'patricia.lim@example.test|mentor|Miguel Ferrer|modern_practical_skills.woodworking|teach',
  'andres.velasco@example.test|learner|Diego Santos|performing_arts.traditional_music|learn',
  'andres.velasco@example.test|learner|Emilio Garcia|performing_arts.traditional_music|learn',
  'andres.velasco@example.test|mentor|Emilio Garcia|language_writing.calligraphy|teach'
)

$expected = @{}
foreach ($row in $rows) {
  $p = $row.Split('|')
  $key = "$($p[0])|$($p[1])"
  if (-not $expected.ContainsKey($key)) { $expected[$key] = @() }
  $expected[$key] += "$($p[2])|$($p[3])|$($p[4])"
}

function Get-Token([string]$email) {
  $body = @{ email = $email; password = 'TestPass123!' } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri "$api/auth/v1/token?grant_type=password" -Method Post `
    -Headers @{ apikey = $anon } -ContentType 'application/json' -Body $body
  return $r.access_token
}

function Get-Deck([string]$token, [string]$role, [bool]$useCache) {
  $body = @{ as_role = $role; refresh = $useCache } | ConvertTo-Json
  return Invoke-RestMethod -Uri "$api/functions/v1/get-matches" -Method Post `
    -Headers @{ Authorization = "Bearer $token"; apikey = $anon } `
    -ContentType 'application/json' -Body $body -TimeoutSec 120
}

$audit = @()
$failures = 0

foreach ($email in $emails) {
  $token = Get-Token $email
  foreach ($target in @('learner', 'mentor')) {
    $expectedKey = "$email|$target"
    $exp = if ($expected.ContainsKey($expectedKey)) { @($expected[$expectedKey]) } else { @() }

    $fresh = Get-Deck $token $target $false
    $freshSet = @($fresh.results | ForEach-Object { "$($_.display_name)|$($_.skill_path)|$($_.skill_kind)" })

    $missing = @($exp | Where-Object { $freshSet -notcontains $_ })
    $extra = @($freshSet | Where-Object { $exp -notcontains $_ })
    $dupes = @($freshSet | Group-Object | Where-Object { $_.Count -gt 1 })

    $badFields = @($fresh.results | Where-Object {
      [string]::IsNullOrWhiteSpace($_.card_id) -or
      [string]::IsNullOrWhiteSpace($_.source_card_id) -or
      [string]::IsNullOrWhiteSpace($_.skill_path) -or
      [string]::IsNullOrWhiteSpace($_.skill_kind) -or
      [double]$_.compatibility -lt 0.5
    })

    $perUser = @($fresh.results | Group-Object user_id | Where-Object { $_.Count -gt 2 })
    $perSkill = @($fresh.results | Group-Object skill_id | Where-Object { $_.Count -gt 3 })
    $self = @($fresh.results | Where-Object { $_.user_id -eq (($fresh.results | Select-Object -First 0).user_id) })

    $cached = Get-Deck $token $target $true
    $cachedSet = @($cached.results | ForEach-Object { "$($_.display_name)|$($_.skill_path)|$($_.skill_kind)" })
    $cacheMismatch = @($freshSet | Where-Object { $cachedSet -notcontains $_ }) +
                     @($cachedSet | Where-Object { $freshSet -notcontains $_ })

    $ok = ($missing.Count -eq 0) -and ($extra.Count -eq 0) -and ($dupes.Count -eq 0) -and
          ($badFields.Count -eq 0) -and ($perUser.Count -eq 0) -and ($perSkill.Count -eq 0) -and
          ($cacheMismatch.Count -eq 0)
    if (-not $ok) { $failures++ }

    $audit += [pscustomobject]@{
      viewer = $email
      target = $target
      expected = $exp.Count
      fresh = $freshSet.Count
      missing = $missing.Count
      extra = $extra.Count
      dupes = $dupes.Count
      bad_fields = $badFields.Count
      cache_diff = $cacheMismatch.Count
      status = if ($ok) { 'PASS' } else { 'FAIL' }
    }
  }
}

$audit | Format-Table -AutoSize
Write-Host "decks=$($audit.Count) failures=$failures"
if ($failures -gt 0) { exit 1 }

