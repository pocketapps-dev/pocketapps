#Requires -Version 5.1
<#
.SYNOPSIS
    Configura o Cloudflare Email Routing para o domínio pocketapps.pt.

.DESCRIPTION
    Script reutilizável que:
      1. Ativa o Email Routing na zona Cloudflare.
      2. Cria os endereços de destino (Gmail).
      3. Cria as rotas de reencaminhamento (geral@, suporte@, billing@, marketing@).
      4. Valida o estado final (lista destinos e rotas).

    Necessita de um API Token da Cloudflare com permissões de edição sobre:
      - Zone > Email Routing Rules
      - Zone > Email Routing Addresses (ou Account > Email Routing Addresses)

.NOTES
    Requer curl.exe (incluído no Windows 10/11).
    Preencher as variáveis da secção "CONFIGURACAO" antes de executar.
#>

[CmdletBinding()]
param(
    [switch]$SkipEnable,
    [switch]$SkipDnsCheck
)

# =============================================================================
# CONFIGURACAO - PREENCHER
# =============================================================================

# Token de API (Cloudflare Dashboard > My Profile > API Tokens)
# NAO colar valores diretamente no script - usar variaveis de ambiente:
#   $env:CF_API_TOKEN = "cfut_..." ; & .\scripts\cloudflare-email-routing.ps1
$CF_API_TOKEN = $env:CF_API_TOKEN

# Account ID da Cloudflare (Dashboard > aceder a uma zona > ver URL do painel)
$CF_ACCOUNT_ID = $env:CF_ACCOUNT_ID

# Zone ID da zona pocketapps.pt (Dashboard > pocketapps.pt > Overview)
# Pode ficar vazio: o script tenta descobri-lo pelo domínio.
$CF_ZONE_ID = ""

$Domain = "pocketapps.pt"

# Mapeamento: endereço local -> destino Gmail
# Todos os endereços encaminham para a única mailbox (pocketapps.dev.pt@gmail.com);
# a distinção faz-se pelo campo To original (filtros Gmail).
$Routes = @(
    @{ Local = "geral@$Domain";     Dest = "pocketapps.dev.pt@gmail.com" },
    @{ Local = "suporte@$Domain";   Dest = "pocketapps.dev.pt@gmail.com" },
    @{ Local = "billing@$Domain";   Dest = "pocketapps.dev.pt@gmail.com" },
    @{ Local = "marketing@$Domain"; Dest = "pocketapps.dev.pt@gmail.com" }
)

# =============================================================================
# HELPERS
# =============================================================================

$Api = "https://api.cloudflare.com/client/v4"

function Invoke-CfApi {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [string]$Body
    )

    $args = @("-s", "-X", $Method, $Uri, "-H", "Authorization: Bearer $CF_API_TOKEN", "-H", "Content-Type: application/json")
    if ($Body) { $args += @("-d", $Body) }

    $raw = & curl.exe @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "curl falhou ($LASTEXITCODE): $($raw -join ' ')"
    }

    $resp = $raw | Out-String | ConvertFrom-Json
    if (-not $resp.success) {
        $err = ($resp.errors | ForEach-Object { $_.message }) -join '; '
        throw "API Cloudflare: $err"
    }
    return $resp
}

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "    OK: $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "    [!] $Msg" -ForegroundColor Yellow }

# =============================================================================
# 1. RESOLVER ZONE ID
# =============================================================================

if (-not $CF_ZONE_ID) {
    Write-Step "A descobrir Zone ID de $Domain"
    $resp = Invoke-CfApi -Method "GET" -Uri "$Api/zones?name=$Domain"
    if ($resp.result.Count -eq 0) { throw "Zona nao encontrada para $Domain" }
    $CF_ZONE_ID = $resp.result[0].id
    Write-Ok "Zone ID: $CF_ZONE_ID"
} else {
    Write-Host "`n==> Zone ID: $CF_ZONE_ID"
}

# =============================================================================
# 2. ATIVAR EMAIL ROUTING
# =============================================================================

if (-not $SkipEnable) {
    Write-Step "A ativar Email Routing na zona"
    $resp = Invoke-CfApi -Method "POST" -Uri "$Api/zones/$CF_ZONE_ID/email/routing/enable" -Body '{\"skip_wizard\": false}'
    Write-Ok "Enabled: $($resp.result.enabled)"
} else {
    Write-Warn "SkipEnable definido - nao a ativar."
}

# =============================================================================
# 3. CRIAR DESTINOS (GMAIL)
# =============================================================================

Write-Step "A criar enderecos de destino"

# Lista de destinos ja existentes (para nao duplicar)
$resp = Invoke-CfApi -Method "GET" -Uri "$Api/accounts/$CF_ACCOUNT_ID/email/routing/addresses"
$existingDests = @{}
foreach ($d in $resp.result) { $existingDests[$d.email] = $d }

$uniqueDests = @($Routes.Dest | Select-Object -Unique)

foreach ($dest in $uniqueDests) {
    if ($existingDests.ContainsKey($dest)) {
        Write-Ok "Ja existe: $dest (estado: $($existingDests[$dest].status))"
    } else {
        $body = '{\"email\": \"' + $dest + '\"}'
        $r = Invoke-CfApi -Method "POST" -Uri "$Api/accounts/$CF_ACCOUNT_ID/email/routing/addresses" -Body $body
        Write-Ok "Criado: $dest (estado: $($r.result.status))"
        Write-Warn "Confirme o endereco $dest no email de verificacao que a Cloudflare enviou."
    }
}

# =============================================================================
# 4. CRIAR ROTAS (REENCAMINHAMENTO)
# =============================================================================

Write-Step "A criar rotas de reencaminhamento"

$resp = Invoke-CfApi -Method "GET" -Uri "$Api/zones/$CF_ZONE_ID/email/routing/rules"
$existingRules = @{}
foreach ($rule in $resp.result) {
    $matcherValue = $rule.matchers[0].value
    if ($matcherValue) { $existingRules[$matcherValue] = $rule }
}

foreach ($route in $Routes) {
    if ($existingRules.ContainsKey($route.Local)) {
        Write-Ok "Ja existe: $($route.Local) -> $($existingRules[$route.Local].actions[0].value -join ',')"
    } else {
        $body = '{\"matchers\": [{\"field\": \"to\", \"type\": \"literal\", \"value\": \"' + $route.Local + '\"}], \"actions\": [{\"type\": \"forward\", \"value\": [\"' + $route.Dest + '\"]}]}'
        $r = Invoke-CfApi -Method "POST" -Uri "$Api/zones/$CF_ZONE_ID/email/routing/rules" -Body $body
        Write-Ok "Criada: $($route.Local) -> $($route.Dest)"
    }
}

# =============================================================================
# 5. VALIDACAO FINAL
# =============================================================================

Write-Step "Validacao final"

$resp = Invoke-CfApi -Method "GET" -Uri "$Api/accounts/$CF_ACCOUNT_ID/email/routing/addresses"
Write-Host "  Destinos:" -ForegroundColor Gray
foreach ($d in $resp.result) {
    Write-Host "    - $($d.email) [$($d.status)]"
}

$resp = Invoke-CfApi -Method "GET" -Uri "$Api/zones/$CF_ZONE_ID/email/routing/rules"
Write-Host "  Rotas:" -ForegroundColor Gray
foreach ($rule in $resp.result) {
    $from = $rule.matchers[0].value
    $to   = $rule.actions[0].value -join ', '
    Write-Host "    - $from -> $to"
}

Write-Step "Concluido. Verifique a caixa de entrada de cada Gmail e confirme os enderecos."
