$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8123
$url = "http://localhost:$port/camera.html"
$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".js" = "application/javascript; charset=utf-8"
    ".css" = "text/css; charset=utf-8"
    ".wasm" = "application/wasm"
    ".png" = "image/png"
    ".jpg" = "image/jpeg"
    ".ico" = "image/x-icon"
    ".data" = "application/octet-stream"
    ".tflite" = "application/octet-stream"
    ".binarypb" = "application/octet-stream"
}
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
try { $listener.Start() } catch { Write-Host "Port $port is busy: $($_.Exception.Message)"; exit 1 }
Write-Host ""
Write-Host "  Xingyu Particle server: $url"
Write-Host "  Close this window to stop."
Write-Host ""
Start-Process $url
$rootFull = [System.IO.Path]::GetFullPath($root)
while ($true) {
    try { $client = $listener.AcceptTcpClient() } catch { continue }
    try {
        $stream = $client.GetStream()
        $stream.ReadTimeout = 10000
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
        $first = $reader.ReadLine()
        $reqPath = "/"
        if ($first) {
            $parts = $first.Split(' ')
            if ($parts.Count -ge 2) { $reqPath = $parts[1] }
        }
        for ($i = 0; $i -lt 64; $i++) {
            $h = $reader.ReadLine()
            if ($h -eq $null -or $h -eq "") { break }
        }
        $q = $reqPath.IndexOf('?')
        if ($q -ge 0) { $reqPath = $reqPath.Substring(0, $q) }
        $reqPath = [System.Uri]::UnescapeDataString($reqPath)
        $rel = $reqPath.TrimStart('/') -replace '/', '\'
        if ($rel -eq "") { $rel = "camera.html" }
        $file = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
        $status = "200 OK"
        $ct = "application/octet-stream"
        if ($file.StartsWith($rootFull + "\") -and (Test-Path $file -PathType Leaf)) {
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            if ($mime.ContainsKey($ext)) { $ct = $mime[$ext] }
            $body = [System.IO.File]::ReadAllBytes($file)
        } else {
            $status = "404 Not Found"
            $ct = "text/plain; charset=utf-8"
            $body = [System.Text.Encoding]::ASCII.GetBytes("404")
        }
        $head = "HTTP/1.1 $status`r`nContent-Type: $ct`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
        $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
        $stream.Write($headBytes, 0, $headBytes.Length)
        $stream.Write($body, 0, $body.Length)
        $stream.Flush()
    } catch { }
    finally { $client.Close() }
}
