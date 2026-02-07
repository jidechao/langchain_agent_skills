@echo off
chcp 65001 >nul 2>nul
setlocal

rem ============================================================
rem  start.bat - Start backend and frontend for Skills Agent
rem  Windows equivalent of start.sh
rem ============================================================

rem --- Script directory (remove trailing backslash) ---
set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "WEB_DIR=%ROOT_DIR%\web"

rem --- Default ports (override via environment variables) ---
if not defined BACKEND_PORT set "BACKEND_PORT=8000"
if not defined FRONTEND_PORT set "FRONTEND_PORT=5173"
if defined VITE_API_BASE_URL (
    set "API_BASE_URL=%VITE_API_BASE_URL%"
) else (
    set "API_BASE_URL=http://127.0.0.1:%BACKEND_PORT%"
)

rem --- Check required commands ---
where uv >nul 2>nul
if errorlevel 1 (
    echo [start] Missing required command: uv
    exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo [start] Missing required command: npm
    exit /b 1
)

rem --- Check frontend directory ---
if not exist "%WEB_DIR%\" (
    echo [start] Frontend directory not found: %WEB_DIR%
    exit /b 1
)

rem --- Install backend dependencies ---
echo [start] Installing backend dependencies with uv sync...
cd /d "%ROOT_DIR%"
call uv sync
if errorlevel 1 (
    echo [start] Failed to install backend dependencies.
    exit /b 1
)

rem --- Install frontend dependencies ---
echo [start] Installing frontend dependencies with npm install...
cd /d "%WEB_DIR%"
call npm install
if errorlevel 1 (
    echo [start] Failed to install frontend dependencies.
    exit /b 1
)

rem --- Start backend in a new window ---
echo [start] Starting backend on :%BACKEND_PORT% ...
cd /d "%ROOT_DIR%"
set "SKILLS_WEB_HOST=0.0.0.0"
set "SKILLS_WEB_PORT=%BACKEND_PORT%"
set "SKILLS_WEB_RELOAD=true"
start "SkillsAgentBackend" cmd /k "chcp 65001 >nul && title SkillsAgentBackend && uv run langchain-skills-web"
set "SKILLS_WEB_HOST="
set "SKILLS_WEB_PORT="
set "SKILLS_WEB_RELOAD="

rem --- Start frontend in a new window ---
echo [start] Starting frontend on :%FRONTEND_PORT% ...
cd /d "%WEB_DIR%"
set "VITE_API_BASE_URL=%API_BASE_URL%"
start "SkillsAgentFrontend" cmd /k "chcp 65001 >nul && title SkillsAgentFrontend && npm run dev -- --host 0.0.0.0 --port %FRONTEND_PORT%"
set "VITE_API_BASE_URL="

echo.
echo ============================================
echo [start] Backend:  http://127.0.0.1:%BACKEND_PORT%
echo [start] Frontend: http://127.0.0.1:%FRONTEND_PORT%
echo ============================================
echo.
echo [start] Press any key to stop both services...
pause >nul

rem --- Cleanup: kill both service windows ---
echo [start] Shutting down services...
taskkill /FI "WINDOWTITLE eq SkillsAgentBackend" /T /F >nul 2>nul
taskkill /FI "WINDOWTITLE eq SkillsAgentFrontend" /T /F >nul 2>nul
echo [start] Done.

endlocal
