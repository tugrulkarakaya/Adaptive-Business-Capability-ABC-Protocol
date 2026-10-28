
$appProcessId = (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1).OwningProcess
Get-CimInstance Win32_Process -Filter "ProcessId=$appProcessId" | Select-Object ProcessId,Name,CommandLine
