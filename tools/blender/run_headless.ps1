# Run a Python script in Blender without opening a window and print what the script wrote to $Out.
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script job.py -Out C:\tmp\job.txt [-Blend file.blend] [-TimeoutSec 900]
#
# Blender here is the Microsoft Store build: blender.exe inside WindowsApps can't be started directly ("access
# denied"), so this goes through blender-launcher.exe. The launcher returns before Blender finishes, so the job script
# must write its result to $Out and then create "$Out.done"; this waits for that file. Pattern for job scripts:
#
#   import sys, traceback
#   OUT = sys.argv[sys.argv.index("--") + 1]; log = []
#   try:
#       ...                                  # work; append lines to log
#   except Exception:
#       log.append(traceback.format_exc())
#   open(OUT, "w").write("\n".join(log)); open(OUT + ".done", "w").write("x")
param([string]$Script, [string]$Out, [int]$TimeoutSec = 600, [string]$Blend = "")
Remove-Item "$Out", "$Out.done", "$Out.log" -ErrorAction SilentlyContinue
$a = @('-b')
if ($Blend) { $a += "`"$Blend`"" } else { $a += '--factory-startup' }
$a += @('--python', "`"$Script`"", '--python-exit-code', '1', '--', "`"$Out`"")
Start-Process "$env:LOCALAPPDATA\Microsoft\WindowsApps\blender-launcher.exe" -ArgumentList $a -RedirectStandardOutput "$Out.log" -RedirectStandardError "$Out.err" -Wait | Out-Null
$t = 0
while (-not (Test-Path "$Out.done") -and $t -lt $TimeoutSec) { Start-Sleep 2; $t += 2 }
if (Test-Path $Out) { Get-Content $Out } else { "NO OUTPUT after $t s"; Get-Content "$Out.log","$Out.err" -ErrorAction SilentlyContinue | Select-Object -Last 30 }
