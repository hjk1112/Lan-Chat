@echo off
chcp 65001 >nul

REM ============================================================
REM  ★ 关键：先设置一个临时标题
REM     这样下面的 taskkill 按 "LAN-Chat 服务器" 匹配时不会杀掉自己
REM ============================================================
title LAN-Chat 重启中

cd /d "%~dp0"

REM ---- 检测 3000 端口是否被监听 ----
netstat -ano | findstr ":3000" | findstr "LISTENING" >nul 2>&1
if errorlevel 1 goto :start

echo ========================================
echo   检测到正在运行的服务器
echo   正在请求旧服务器优雅退出...
echo ========================================
echo.

REM ---- 1. 请求优雅关闭（保存数据） ----
where curl.exe >nul 2>&1
if %errorlevel%==0 (
    curl.exe -s -X POST "http://localhost:3000/api/shutdown" -o nul 2>nul
) else (
    powershell -NoProfile -Command ^
      "try { Invoke-RestMethod -Uri 'http://localhost:3000/api/shutdown' -Method POST -TimeoutSec 3 | Out-Null } catch { }" >nul 2>&1
)

REM ---- 2. 等 3 秒让旧 node 保存数据并退出 ----
timeout /t 3 /nobreak >nul

REM ---- 3. 强杀残留的 node（按端口找 PID，防优雅关闭失败） ----
netstat -ano | findstr ":3000" | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo 旧服务器未完全退出，强制结束...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3000" ^| findstr "LISTENING"') do (
        echo     结束 PID: %%a
        taskkill /F /PID %%a >nul 2>&1
    )
    timeout /t 1 /nobreak >nul
)

REM ---- 4. ★ 按窗口标题强杀所有旧的服务器 cmd 窗口 ----
REM     前面的 title 已改成 "LAN-Chat 重启中"，所以这里不会杀自己
echo 正在关闭旧的服务器窗口...
taskkill /F /FI "WINDOWTITLE eq LAN-Chat 服务器*" >nul 2>&1
timeout /t 1 /nobreak >nul

REM ============================================================
REM  启动服务器
REM ============================================================
:start
REM ---- 把自己的标题改成"服务器"（下次重启时会被新窗口识别并关闭） ----
title LAN-Chat 服务器

echo.
echo ========================================
echo   微信 · 局域网  服务端
echo ========================================
echo.
echo   端口：3000
echo   本窗口 = 服务器窗口，请勿关闭
echo   重启：再次双击 server.bat
echo   停止：直接关闭本窗口
echo.
echo ========================================
echo.

set PORT=3000

REM ============================================================
REM ★ 内存优化启动参数：
REM   --expose-gc                 : 允许服务端代码在深度清理后手动调用全局垃圾回收
REM   --max-old-space-size=1024   : 限制 Node.js 最大堆内存为 1GB (如果你的机器内存极小，可改为 512)
REM   --optimize-for-size         : 提示 V8 引擎优先优化内存占用而不是执行速度
REM ============================================================
node --expose-gc --max-old-space-size=1024 --optimize-for-size server.js

exit
node server.js

exit