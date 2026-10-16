@echo off
title HomeConnect - Serveur
color 0A
echo ============================================================
echo   HomeConnect - Demarrage du serveur Symfony
echo ============================================================
echo.

:: Tuer Apache s'il tourne sur le port 8000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8000"') do (
    taskkill /PID %%a /F >nul 2>&1
)
timeout /t 1 /nobreak >nul

cd /d "d:\magni\homeconnect"

:: Verifier PHP
php --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERREUR] PHP introuvable. Ajoutez C:\xampp\php au PATH.
    pause
    exit /b 1
)

:: Appliquer migrations
echo [INFO] Application des migrations...
php bin/console doctrine:migrations:migrate --no-interaction --quiet 2>nul
echo [OK] Migrations OK.

:: Vider le cache
echo [INFO] Vidage du cache...
php bin/console cache:clear --env=dev --quiet 2>nul
echo [OK] Cache vide.

:: Demarrer le serveur PHP
echo.
echo ============================================================
echo   SERVEUR EN LIGNE
echo   Web local  : http://localhost:8000
echo   Web reseau : http://192.168.137.1:8000
echo   Mobile     : http://192.168.137.1:8000
echo ============================================================
echo.
echo  Comptes :
echo    Admin      : admin@homeconnect.com / admin123
echo    Proprio    : proprio@test.com / test123
echo    Locataire  : locataire@test.com / test123
echo.
echo  CTRL+C pour arreter.
echo ============================================================

php -S 0.0.0.0:8000 -t public
