param(
  [string]$ProjectRoot = "",
  [string]$WebRoot     = "C:\webroot\sophyane.com\www\apps\vibe",
  [ValidateSet("A","B")]
  [string]$Slot        = "A"
)
$ErrorActionPreference="Stop"

function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }
function EnsureDir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

if([string]::IsNullOrWhiteSpace($ProjectRoot)){ throw "Provide -ProjectRoot" }
if(!(Test-Path $ProjectRoot)){ throw "Missing ProjectRoot: $ProjectRoot" }

$slotDir = Join-Path $WebRoot ("slot" + $Slot.ToLower())
$active  = Join-Path $WebRoot "ACTIVE_SLOT.txt"
EnsureDir $slotDir

Say "`n=== DEPLOY SLOT $Slot ===`n" Yellow
Say "Copying build/artifacts to $slotDir" Cyan

# naive deploy: copy everything except node_modules and .git
$items = Get-ChildItem $ProjectRoot -Force
foreach($it in $items){
  if($it.Name -in @("node_modules",".git",".nifdu")){ continue }
  $dst = Join-Path $slotDir $it.Name
  if(Test-Path $dst){ Remove-Item $dst -Recurse -Force }
  Copy-Item $it.FullName $dst -Recurse -Force
}

Set-Content -Path $active -Value ("slot" + $Slot.ToLower()) -Encoding ASCII
Say "ACTIVE_SLOT -> $(Get-Content $active)" Green
Say "DONE." Green