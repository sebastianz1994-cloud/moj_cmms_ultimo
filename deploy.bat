@echo off
echo ===================================================
echo   URUCHAMIAM AUTOMATYCZNĄ AKTUALIZACJĘ APKLIKACJI
echo ===================================================

echo.
echo [1/3] Zapisywanie kodu zrodlowego na GitHubie...
git add .
git commit -m "Automatyczna aktualizacja kodu"
git push origin main

echo.
echo [2/3] Budowanie wersji przegladarkowej (Web)...
call flutter build web --base-href "/moj_cmms_ultimo/"

echo.
echo [3/3] Wysylanie wersji WWW na GitHub Pages...
cd build\web
git init
git checkout -b gh-pages
git add .
git commit -m "Automatyczny deploy strony WWW"
git push -f https://github.com/sebastianz1994-cloud/moj_cmms_ultimo.git gh-pages
cd ..\..

echo.
echo ===================================================
echo   SUKCES! Kod zapisany, a strona zaktualizowana!
echo ===================================================
pause