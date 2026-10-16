@echo off
rem Start HomeConnect PHP server on localhost
cd /d "%~dp0"
php -S 0.0.0.0:8000 -t public
