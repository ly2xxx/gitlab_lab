@echo off
REM setup-gitlab-windows.bat - Windows batch script for GitLab CE setup
REM This script provides a simple Command Prompt interface for Windows users

echo ===================================================================
echo 🐳 GitLab CE Self-Hosting Setup for Windows 11
echo ===================================================================
echo.

REM Check if Docker is available
echo [INFO] Checking Docker installation...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH.
    echo Please install Docker Desktop first.
    pause
    exit /b 1
)

docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker Compose is not available.
    echo Please ensure Docker Desktop is properly installed.
    pause
    exit /b 1
)

echo [SUCCESS] Docker and Docker Compose found!

REM Check if Docker is running
echo [INFO] Checking if Docker daemon is running...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker daemon is not running.
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

echo [SUCCESS] Docker daemon is running!

REM Create data directories
echo [INFO] Creating GitLab data directories...
if not exist "gitlab-data" mkdir gitlab-data
if not exist "gitlab-data\config" mkdir gitlab-data\config
if not exist "gitlab-data\logs" mkdir gitlab-data\logs
if not exist "gitlab-data\data" mkdir gitlab-data\data

if not exist "config" mkdir config
if not exist "config\ssl" mkdir config\ssl

echo [SUCCESS] Directories created!

REM Check if docker-compose.yml exists
if not exist "docker-compose.yml" (
    echo [ERROR] docker-compose.yml not found.
    echo Please run this script from the lab-00-gitlab-self-host-docker directory.
    pause
    exit /b 1
)

REM Pull latest images
echo [INFO] Pulling latest Docker images...
docker-compose pull

REM Start GitLab
echo [INFO] Starting GitLab CE...
echo This may take 5-10 minutes on Windows...
docker-compose up -d

if %errorlevel% neq 0 (
    echo [ERROR] Failed to start GitLab.
    echo Check the logs with: docker-compose logs gitlab
    pause
    exit /b 1
)

echo [SUCCESS] GitLab services started!

REM Wait for GitLab to be ready
echo [INFO] Waiting for GitLab to be ready...
echo This may take several minutes. Please be patient...

REM Simple wait loop (basic implementation)
set /a count=0
set /a timeout=300

:wait_loop
timeout /t 15 /nobreak >nul 2>&1
set /a count+=15

REM Try to access GitLab (basic check)
curl -k -s https://localhost >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] GitLab is ready!
    goto :gitlab_ready
)

if %count% geq %timeout% (
    echo [WARNING] GitLab startup is taking longer than expected.
    echo You can check the status with: docker-compose logs gitlab
    goto :show_info
)

echo Still waiting... (%count%/%timeout% seconds)
goto :wait_loop

:gitlab_ready
echo.
echo ===================================================================
echo 🚀 GitLab is now running!
echo ===================================================================

:show_info
echo.
echo 📍 Access URLs:
echo    Web Interface: https://localhost
echo    Container Registry: https://localhost:5050
echo    SSH Git Access: ssh://git@localhost:2224
echo.
echo 🔐 Initial Login:
echo    Username: root
echo    Password: Run this command to get the password:
echo    docker-compose exec gitlab cat /etc/gitlab/initial_root_password
echo.
echo 🏃 GitLab Runner:
echo    Runner will start automatically after GitLab is ready
echo    Register it using the token from: Admin Area → Runners
echo.
echo 📋 Next Steps:
echo    1. Open https://localhost in your browser
echo    2. Accept the SSL certificate warning
echo    3. Login with root and the initial password
echo    4. Change the root password immediately
echo    5. Register the GitLab Runner
echo    6. Create your first project
echo.
echo 🛠️ Useful Commands:
echo    View logs:     docker-compose logs -f gitlab
echo    Stop GitLab:   docker-compose down
echo    Restart:       docker-compose restart
echo    Status:        docker-compose ps
echo.
echo 📁 Data Location:
echo    GitLab data is stored in: %cd%\gitlab-data
echo.
echo Happy coding with GitLab! 🎉

REM Try to get initial password
echo.
echo ===================================================================
echo Attempting to retrieve initial root password...
echo ===================================================================
timeout /t 10 /nobreak >nul 2>&1
docker-compose exec gitlab cat /etc/gitlab/initial_root_password 2>nul | findstr "Password:"

if %errorlevel% neq 0 (
    echo [INFO] Password not ready yet. Try the command above in a few minutes.
)

echo.
echo Press any key to exit...
pause >nul