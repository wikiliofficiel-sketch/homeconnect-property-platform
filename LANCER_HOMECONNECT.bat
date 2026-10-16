@echo off
:: ============================================================
:: HomeConnect - Démarrage COMPLET (serveur + hotspot WiFi)
:: Double-clic pour tout relancer
:: ============================================================

:: Vérifier les droits admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Relancement en mode administrateur...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title HomeConnect - Démarrage complet
color 0A
echo ============================================================
echo   HomeConnect - Démarrage complet
echo ============================================================
echo.

:: Arrêter les anciens processus
echo [1/4] Arrêt des anciens serveurs...
taskkill /IM php.exe /F >nul 2>&1
taskkill /IM httpd.exe /F >nul 2>&1
timeout /t 2 /nobreak >nul

:: Démarrer le hotspot WiFi (pour le téléphone)
echo [2/4] Démarrage du hotspot WiFi...
netsh wlan start hostednetwork >nul 2>&1
if %errorlevel%==0 (
    echo [OK] Hotspot WiFi actif
    echo      Le téléphone doit se connecter à ce réseau WiFi
) else (
    echo [WARN] Hotspot non démarré - configure-le manuellement dans :
    echo         Paramètres - Réseau - Point d'accès mobile
)

:: Ouvrir le pare-feu pour le port 8000
echo [3/4] Ouverture du port 8000...
netsh advfirewall firewall delete rule name="HomeConnect" >nul 2>&1
netsh advfirewall firewall add rule name="HomeConnect" dir=in action=allow protocol=TCP localport=8000 >nul 2>&1
echo [OK] Port 8000 ouvert

:: Démarrer le serveur PHP Symfony
echo [4/4] Démarrage du serveur Symfony...
cd /d "d:\magni\homeconnect"
php bin/console doctrine:migrations:migrate --no-interaction --quiet >nul 2>&1
php bin/console cache:clear --env=dev --quiet >nul 2>&1

echo.
echo ============================================================
echo   TOUT EST EN MARCHE !
echo ============================================================
echo.
echo   Site web    : http://localhost:8000
echo   Mobile/WiFi : http://192.168.137.1:8000
echo.
echo   Comptes :
echo     Admin      : admin@homeconnect.com / admin123
echo     Proprio    : (email inscription) / (ton mdp)
echo     Locataire  : (email inscription) / (ton mdp)
echo.
echo   IMPORTANT : Garde cette fenêtre ouverte !
echo   (Fermer = arrêter le serveur)
echo ============================================================
echo.

:: Garder le serveur en marche (cette commande bloque jusqu'à CTRL+C)
php -d memory_limit=1G -S 0.0.0.0:8000 -t public
