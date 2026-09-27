# Hook PermissionRequest de Claude Code -> JEV. Fail-closed: ante cualquier error, sin salida.
try { & (Join-Path $PSScriptRoot 'jev.ps1') hook @args } catch { }
exit 0
