# Hoax - Fake Hacked Prank (built-in Windows PowerShell, nothing to install)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Host.UI.RawUI.WindowTitle = 'Hoax - Fake Hacked Prank'

# nice default window size (100 x 32) and big scroll-back
try {
  $raw = $Host.UI.RawUI
  $buf = $raw.BufferSize
  if ($buf.Width -lt 100) { $buf.Width = 100; $raw.BufferSize = $buf }
  $win = $raw.WindowSize; $win.Width = 100; $win.Height = 32; $raw.WindowSize = $win
} catch { }

# ---------------- little UI helpers ----------------
function Rule  { Write-Host ("  " + '────────────────────────────────────────────────────────────────') -ForegroundColor DarkGray }
function Title($t) { Write-Host ""; Write-Host "  $t" -ForegroundColor Cyan; Rule }
function Ok($t)   { Write-Host "  " -NoNewline; Write-Host "■ " -NoNewline -ForegroundColor Green;  Write-Host $t -ForegroundColor White }
function Warn($t) { Write-Host "  " -NoNewline; Write-Host "■ " -NoNewline -ForegroundColor Yellow; Write-Host $t -ForegroundColor White }
function Err($t)  { Write-Host "  " -NoNewline; Write-Host "■ " -NoNewline -ForegroundColor Red;    Write-Host $t -ForegroundColor White }
function Ask($label, $defText, $default) {
  Write-Host "  » " -NoNewline -ForegroundColor Cyan
  Write-Host $label.PadRight(34) -NoNewline -ForegroundColor White
  Write-Host "default: $defText" -ForegroundColor DarkGray
  Write-Host "    ► " -NoNewline -ForegroundColor Green
  $a = Read-Host
  if ([string]::IsNullOrWhiteSpace($a)) { return $default } else { return $a.Trim() }
}

# ---------------- banner ----------------
Clear-Host
Write-Host ""
$rows = @(
  '██╗  ██╗ ██████╗  █████╗ ██╗  ██╗',
  '██║  ██║██╔═══██╗██╔══██╗╚██╗██╔╝',
  '███████║██║   ██║███████║ ╚███╔╝ ',
  '██╔══██║██║   ██║██╔══██║ ██╔██╗ ',
  '██║  ██║╚██████╔╝██║  ██║██╔╝ ██╗',
  '╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝'
)
$colors = 'Cyan', 'Cyan', 'DarkCyan', 'DarkCyan', 'Blue', 'Blue'
for ($i = 0; $i -lt $rows.Count; $i++) { Write-Host "   $($rows[$i])" -ForegroundColor $colors[$i] }
Write-Host ""
Write-Host "   F A K E   H A C K E D   P R A N K" -NoNewline -ForegroundColor White
Write-Host "      v1.0" -ForegroundColor DarkGray
Write-Host "   A harmless joke: fake hack screen, then a fullscreen video." -ForegroundColor DarkGray

# ---------------- setup questions ----------------
Title 'SETUP'
$name   = Ask 'Hacked by (name)'              'Hafiz Ibrahim' 'Hafiz Ibrahim'
$video  = Ask 'Video link (YouTube or .mp4)'  'Rickroll'      'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
$portIn = Ask 'Port'                          '8080'          '8080'
$tIn    = Ask 'Public Cloudflare link? (Y/N)' 'Y'             'y'
$port = 0
if (-not [int]::TryParse($portIn, [ref]$port) -or $port -lt 1 -or $port -gt 65535) { $port = 8080 }
$tunnel = -not ($tIn -match '^(n|no)$')

# ---------------- page ----------------
function Get-VideoConfig($v) {
  $v = $v.Trim()
  if ($v -match '\.(mp4|webm|ogg)(\?.*)?$')                    { return @{ kind = 'file'; src = $v } }
  if ($v -match '(?:v=|youtu\.be/|embed/|shorts/)([\w-]{11})') { return @{ kind = 'youtube'; id = $Matches[1] } }
  if ($v -match '^[\w-]{11}$')                                 { return @{ kind = 'youtube'; id = $v } }
  return @{ kind = 'youtube'; id = 'dQw4w9WgXcQ' }
}
$json = (ConvertTo-Json (Get-VideoConfig $video) -Compress).Replace('<', '\u003c')
$page = (Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8).Replace('__NAME__', [Net.WebUtility]::HtmlEncode($name)).Replace('__CONFIG__', $json)
$pageBytes = [Text.Encoding]::UTF8.GetBytes($page)

# ---------------- server ----------------
Title 'LAUNCH'
$wifi = $true
$listener = New-Object Net.HttpListener
try {
  $listener.Prefixes.Add("http://+:$port/"); $listener.Start()
} catch {
  $wifi = $false   # no admin rights: this PC only (the Cloudflare link still works)
  $listener = New-Object Net.HttpListener
  try { $listener.Prefixes.Add("http://localhost:$port/"); $listener.Start() }
  catch { Err "Could not start on port $port (already in use?). Try another port."; exit 1 }
}
Ok "Server running on port $port"

# ---------------- cloudflared ----------------
$cfProc = $null
$cfLog = Join-Path $env:TEMP 'hoax-cloudflared.log'
$link = $null

function Get-Cloudflared {
  $c = Get-Command cloudflared -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $bin = Join-Path $root 'bin'
  New-Item -ItemType Directory -Force $bin | Out-Null
  $exe = Join-Path $bin 'cloudflared.exe'
  if (Test-Path $exe) { return $exe }
  $arch = if ([Environment]::Is64BitOperatingSystem) { 'amd64' } else { '386' }
  Warn 'Downloading cloudflared (one time only)...'
  $ProgressPreference = 'SilentlyContinue'
  Invoke-WebRequest "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$arch.exe" -OutFile $exe -UseBasicParsing
  return $exe
}

if ($tunnel) {
  try {
    $cf = Get-Cloudflared
    Remove-Item $cfLog, "$cfLog.out" -ErrorAction SilentlyContinue
    $cfProc = Start-Process -FilePath $cf -WindowStyle Hidden -PassThru `
      -RedirectStandardError $cfLog -RedirectStandardOutput "$cfLog.out" `
      -ArgumentList @('tunnel', '--url', "http://127.0.0.1:$port", '--http-host-header', "localhost:$port", '--no-autoupdate')
    $spin = '|', '/', '-', '\'
    for ($i = 0; $i -lt 240 -and -not $link; $i++) {
      Write-Host ("`r  " + $spin[$i % 4] + " Opening Cloudflare tunnel...") -NoNewline -ForegroundColor Yellow
      Start-Sleep -Milliseconds 250
      if ($cfProc.HasExited) { break }
      try {
        $fs = [IO.File]::Open($cfLog, 'Open', 'Read', 'ReadWrite'); $sr = New-Object IO.StreamReader($fs)
        $txt = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
        if ($txt -match 'https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com') { $link = $Matches[0] }
      } catch { }
    }
    Write-Host ("`r" + (' ' * 50) + "`r") -NoNewline
    if ($link) { Ok 'Cloudflare tunnel ready' }
    else {
      Err 'Could not open the Cloudflare tunnel. Check your internet connection.'
      if (Test-Path $cfLog) { Get-Content $cfLog -Tail 4 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray } }
    }
  } catch { Write-Host ""; Err "Cloudflare not available: $($_.Exception.Message)" }
}

# ---------------- links ----------------
Title 'LINKS'
if ($link) { Write-Host "    Public   " -NoNewline -ForegroundColor DarkGray; Write-Host $link -ForegroundColor Cyan }
Write-Host "    Local    " -NoNewline -ForegroundColor DarkGray; Write-Host "http://localhost:$port" -ForegroundColor White
if ($wifi) {
  $ip = [Net.Dns]::GetHostAddresses([Net.Dns]::GetHostName()) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
  if ($ip) { Write-Host "    WiFi     " -NoNewline -ForegroundColor DarkGray; Write-Host "http://${ip}:$port" -ForegroundColor White }
}

Title 'LIVE ACTIVITY'
Write-Host "  Waiting for targets...   (Ctrl + C to stop)" -ForegroundColor DarkGray
Write-Host ""

# ---------------- main loop (no IPs or personal info are logged) ----------------
$visitors = @{}
function Get-Num($id) {
  if (-not $id) { $id = 'unknown' }
  if (-not $visitors.ContainsKey($id)) { $visitors[$id] = $visitors.Count + 1 }
  return $visitors[$id]
}
$messages = @{
  opened  = @('Yellow',   'opened the link')
  playing = @('Green',    'is watching the video')
  ended   = @('Cyan',     'watched the whole video')
  left    = @('DarkGray', 'left the page')
}

try {
  $task = $listener.GetContextAsync()
  while ($true) {
    if (-not $task.AsyncWaitHandle.WaitOne(300)) { continue }   # short wait keeps Ctrl+C working
    $ctx = $task.Result
    $task = $listener.GetContextAsync()
    try {
      $req = $ctx.Request; $res = $ctx.Response
      $path = $req.Url.AbsolutePath
      if ($req.HttpMethod -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
        $res.ContentType = 'text/html; charset=utf-8'
        $res.Headers.Add('Cache-Control', 'no-store')
        $res.OutputStream.Write($pageBytes, 0, $pageBytes.Length)
      }
      elseif ($req.HttpMethod -eq 'POST' -and $path -eq '/event') {
        $m = $messages[$req.QueryString['e']]
        if ($m) {
          $n = Get-Num $req.QueryString['id']
          Write-Host ("  " + (Get-Date -Format 'HH:mm:ss') + "  ") -NoNewline -ForegroundColor DarkGray
          Write-Host "► " -NoNewline -ForegroundColor $m[0]
          Write-Host "Target #$n " -NoNewline -ForegroundColor White
          Write-Host $m[1] -ForegroundColor $m[0]
        }
        $res.StatusCode = 204
      }
      else { $res.StatusCode = 404 }
      $res.Close()
    } catch { }
  }
}
finally {
  try { $listener.Stop() } catch { }
  if ($cfProc -and -not $cfProc.HasExited) { try { $cfProc.Kill() } catch { } }
}
