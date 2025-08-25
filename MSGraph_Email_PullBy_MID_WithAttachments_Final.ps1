<# 
  Export emails by Internet Message ID (Graph) — bulk/v3
  - Input: 1 Message-ID per line, with or without < >
  - Output: .eml + attachments in per-message folders, plus manifest.csv
  - Scales to thousands with retries, throttling, progress, resume
  - Creates: duplicates.txt, misses.txt, errors.log
#>

# ==================== CONFIG ====================
$User             = 'email@company.com'                                # target mailbox
$MidFile          = 'C:\Path\To\File\WithMIDs.txt'                                 # one MID per line
$OutRoot          = Join-Path $env:USERPROFILE 'Downloads\MID_Export'     # export root
$PauseAtEnd       = $true                                                 # prompt at end
$DeduplicateMids  = $true                                                 # remove duplicates
$MaxSubjectChars  = 80                                                    # trims folder names to avoid MAX_PATH pain
$ThrottleDelayMs  = 200                                                   # base delay between MIDs
$MaxRetry         = 6                                                     # retries per request on 429/5xx
$RetryBaseMs      = 600                                                   # starting backoff
$ResumeCheckpoint = Join-Path $OutRoot 'checkpoint.json'                  # resume file

# ==================== AUTH ======================
Disconnect-MgGraph -ErrorAction SilentlyContinue
# Delegated: you need Mail.Read + Mail.Read.Shared to read another mailbox
Connect-MgGraph -Scopes "Mail.Read","Mail.Read.Shared"
# App-only alternative:
# Connect-MgGraph -TenantId 'TENANT_GUID' -ClientId 'APP_ID' -CertificateThumbprint 'CERT_THUMB'

# ==================== PREP ======================
$null = New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$ErrorLog = Join-Path $OutRoot 'errors.log'
if (Test-Path $ErrorLog) { Remove-Item $ErrorLog -Force }
function Log-Err($msg){ $ts = Get-Date -Format s; "$ts  $msg" | Add-Content -Path $ErrorLog }

function Sanitize([string]$name){
  if ([string]::IsNullOrWhiteSpace($name)) { return '_' }
  $s = ($name -replace '[^\w\-. ]','_').Trim()
  if ($s.Length -gt $MaxSubjectChars) { $s.Substring(0,$MaxSubjectChars) } else { $s }
}

function Save-Bytes($path, [byte[]]$bytes){
  $dir = Split-Path $path
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllBytes($path, $bytes)
}

# Graph call with retry/backoff on 429/5xx
function Invoke-GraphWithRetry {
  param(
    [Parameter(Mandatory)] [string]$Method,
    [Parameter(Mandatory)] [string]$Uri,
    [hashtable]$Headers,
    [string]$OutputFilePath
  )
  $attempt = 0
  while ($true) {
    try {
      if ($OutputFilePath) {
        return Invoke-MgGraphRequest -Method $Method -Uri $Uri -Headers $Headers -OutputFilePath $OutputFilePath
      } else {
        return Invoke-MgGraphRequest -Method $Method -Uri $Uri -Headers $Headers
      }
    } catch {
      $attempt++
      $code = $_.Exception.Response.StatusCode.value__
      $retryAfter = $_.Exception.Response.Headers.'Retry-After'
      if ($attempt -le $MaxRetry -and ($code -eq 429 -or $code -ge 500)) {
        $sleep = if ($retryAfter) { [int]$retryAfter * 1000 } else { [int]([math]::Min($RetryBaseMs * [math]::Pow(2, $attempt-1), 15000)) }
        Start-Sleep -Milliseconds $sleep
        continue
      }
      throw
    }
  }
}

# Cache folder display names to cut calls
$FolderNameCache = @{}
function Get-FolderName {
  param([string]$UserId,[string]$FolderId)
  if (-not $FolderId) { return $null }
  if ($FolderNameCache.ContainsKey($FolderId)) { return $FolderNameCache[$FolderId] }
  try {
    $f = Get-MgUserMailFolder -UserId $UserId -MailFolderId $FolderId -Property displayName
    $FolderNameCache[$FolderId] = $f.DisplayName
    return $f.DisplayName
  } catch {
    return $null
  }
}

# ==================== LOAD & NORMALIZE ======================
if (!(Test-Path $MidFile)) { throw "MID file not found: $MidFile" }

$rawMids = Get-Content $MidFile | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
  $s = $_.Trim()
  if ($s -notmatch '^<.*>$') { "<$s>" } else { $s }
}

$dups = $rawMids | Group-Object | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name
if ($dups) { $dups | Out-File (Join-Path $OutRoot 'duplicates.txt') }

$uniqueMids = $rawMids | Select-Object -Unique
$mids = if ($DeduplicateMids) { $uniqueMids } else { $rawMids }

$RawMidCount    = $rawMids.Count
$UniqueMidCount = $uniqueMids.Count
$DupCount       = $RawMidCount - $UniqueMidCount
if ($mids.Count -eq 0) { throw "No message IDs to process after normalization." }

# Resume support
$Processed = @{}
if (Test-Path $ResumeCheckpoint) {
  try { $Processed = Get-Content $ResumeCheckpoint | ConvertFrom-Json | Group-Object -Property InternetMessageId -AsHashTable -AsString }
  catch { $Processed = @{} }
}

# ==================== EXPORT ===============================
$AllRows = New-Object System.Collections.Generic.List[object]
$ErrorCount = 0
$TotalAttachments = 0
$TotalMessages = 0
$Misses = New-Object System.Collections.Generic.List[string]

$manifest = Join-Path $OutRoot 'manifest.csv'

for ($i=0; $i -lt $mids.Count; $i++) {
  $mid = $mids[$i]

  # Skip if already processed in a previous run
  if ($Processed.ContainsKey($mid)) {
    Write-Progress -Activity "Exporting emails" -Status "Skipping (already done) $($i+1)/$($mids.Count)" -PercentComplete ((($i+1)/$mids.Count)*100)
    continue
  }

  Write-Progress -Activity "Exporting emails" -Status "Processing $($i+1)/$($mids.Count)" -PercentComplete ((($i+1)/$mids.Count)*100)
  try {
    $msgs = Get-MgUserMessage -UserId $User `
      -Filter "internetMessageId eq '$mid'" `
      -Property id,subject,from,sender,receivedDateTime,parentFolderId `
      -PageSize 50 -All

    if (-not $msgs) {
      $Misses.Add($mid)
      # Record in checkpoint so we don't re-try on resume unless you delete the checkpoint
      @{ InternetMessageId = $mid; Status = 'NotFound' } | ConvertTo-Json | Add-Content -Path $ResumeCheckpoint
      Start-Sleep -Milliseconds $ThrottleDelayMs
      continue
    }

    foreach ($m in $msgs) {
      $TotalMessages++

      $folderName = Get-FolderName -UserId $User -FolderId $m.ParentFolderId

      $stamp  = (Get-Date $m.receivedDateTime -Format 'yyyyMMdd_HHmmss')
      $subj   = if ($m.Subject) { $m.Subject } else { '(no subject)' }
      $slug   = Sanitize($subj)
      $msgDir = Join-Path $OutRoot ("{0}_{1}_{2}" -f $stamp,$slug,$m.Id.Substring(0,8))
      New-Item -ItemType Directory -Force -Path $msgDir | Out-Null

      # MIME
      $emlPath = Join-Path $msgDir 'message.eml'
      $mimeUri = "https://graph.microsoft.com/v1.0/users/$User/messages/$($m.Id)/`$value"
      Invoke-GraphWithRetry -Method GET -Uri $mimeUri -OutputFilePath $emlPath | Out-Null

      # Attachments
      $atts = @()
      try { $atts = Get-MgUserMessageAttachment -UserId $User -MessageId $m.Id -All } catch { Log-Err "Attach list failed: MID $mid - $($_.Exception.Message)" }
      $TotalAttachments += @($atts).Count

      foreach ($a in $atts) {
        switch ($a.'@odata.type') {
          '#microsoft.graph.fileAttachment' {
            $name = Sanitize(($a.Name -or $a.Id))
            if (-not $name.Contains('.') -and $a.ContentType) {
              try { $ext = [System.Web.MimeMapping]::GetExtension($a.ContentType); if ($ext) { $name = "$name$ext" } } catch {}
            }
            $bytes = [Convert]::FromBase64String($a.ContentBytes)
            Save-Bytes (Join-Path $msgDir $name) $bytes
          }
          '#microsoft.graph.itemAttachment' {
            $attName = Sanitize(($a.Name -or 'embedded'))
            $aUri = "https://graph.microsoft.com/v1.0/users/$User/messages/$($m.Id)/attachments/$($a.Id)/`$value"
            $out = Join-Path $msgDir ($attName + '.eml')
            try { Invoke-GraphWithRetry -Method GET -Uri $aUri -OutputFilePath $out | Out-Null }
            catch { ($a | ConvertTo-Json -Depth 8) | Out-File (Join-Path $msgDir ($attName + '.json')) }
          }
          '#microsoft.graph.referenceAttachment' {
            ($a | ConvertTo-Json -Depth 8) | Out-File (Join-Path $msgDir ((Sanitize(($a.Name -or $a.Id))) + '.link.json'))
          }
          default {
            ($a | ConvertTo-Json -Depth 8) | Out-File (Join-Path $msgDir ((Sanitize(($a.Name -or $a.Id))) + '.unknown.json'))
          }
        }
      }

      # Manifest row
      $AllRows.Add([pscustomobject]@{
        TargetMailbox     = $User
        InternetMessageId = $mid
        GraphId           = $m.Id
        Subject           = $m.Subject
        FromName          = $m.From.EmailAddress.Name
        FromAddress       = $m.From.EmailAddress.Address
        SenderAddress     = $m.Sender.EmailAddress.Address
        ReceivedDateTime  = $m.ReceivedDateTime
        FolderId          = $m.ParentFolderId
        FolderName        = $folderName
        ExportFolder      = $msgDir
        EmlPath           = $emlPath
        AttachmentCount   = @($atts).Count
      })

      # Mark processed in checkpoint
      @{ InternetMessageId = $mid; Status = 'Exported'; GraphId = $m.Id } | ConvertTo-Json | Add-Content -Path $ResumeCheckpoint
    }
  } catch {
    $ErrorCount++
    Log-Err "MID $mid failed: $($_.Exception.Message)"
  }

  Start-Sleep -Milliseconds $ThrottleDelayMs
}

# Write manifest and misses
if ($AllRows.Count -gt 0) { $AllRows | Sort-Object ReceivedDateTime | Export-Csv -NoTypeInformation -Path $manifest }
if ($Misses.Count -gt 0) { $Misses | Out-File (Join-Path $OutRoot 'misses.txt') }

# ==================== SUMMARY ===============================
Write-Progress -Activity "Exporting emails" -Completed
Write-Host ""
Write-Host "===== EXPORT COMPLETE =====" -ForegroundColor Green
Write-Host ("MIDs provided     : {0}" -f $RawMidCount)
Write-Host ("Unique MIDs used  : {0}  (duplicates removed: {1})" -f $UniqueMidCount, $DupCount)
Write-Host ("Messages exported : {0}" -f $TotalMessages)
Write-Host ("Attachments saved : {0}" -f $TotalAttachments)
Write-Host ("Output folder     : {0}" -f $OutRoot)
Write-Host ("Manifest CSV      : {0}" -f $manifest)
if ($dups)   { Write-Host ("Duplicates list   : {0}" -f (Join-Path $OutRoot 'duplicates.txt')) }
if ($Misses) { Write-Host ("Misses list       : {0}" -f (Join-Path $OutRoot 'misses.txt')) }
if (Test-Path $ErrorLog) { Write-Host ("Errors log        : {0}" -f $ErrorLog) }
if ($ErrorCount -gt 0)   { Write-Warning ("Errors observed   : {0}" -f $ErrorCount) }

if ($PauseAtEnd) {
  [void](Read-Host "`nPress Enter to exit")
  exit 0
}
