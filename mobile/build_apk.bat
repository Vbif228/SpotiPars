@echo off
chcp 65001 >nul
echo ========================================================
echo       SpotiPars Mobile - Автоматическая сборка APK
echo ========================================================

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [!] Flutter SDK не найден в PATH.
    echo Пожалуйста, установите Flutter: https://docs.flutter.dev/get-started/install/windows
    pause
    exit /b 1
)

echo [*] Загрузка зависимостей (flutter pub get)...
call flutter pub get

echo [*] Сборка релизного APK (flutter build apk --release)...
call flutter build apk --release

if %errorlevel% equ 0 (
    echo.
    echo [OK] Сборка успешно завершена!
    echo APK файл находится в: build\app\outputs\flutter-apk\app-release.apk
) else (
    echo.
    echo [ERR] Ошибка при сборке APK.
)

pause
