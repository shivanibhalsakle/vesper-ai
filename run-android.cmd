@echo off
rem Runs Vesper on the USB-connected Android phone, against the local backend.
rem
rem   Usage, from the repo root:   run-android
rem   Extra arguments go to "flutter run", for example:   run-android --release
rem
rem It starts the backend (Docker Desktop must be running), finds your phone,
rem forwards port 8010 so the phone's localhost reaches this laptop, then runs
rem the app. Re-run it any time the USB cable has been unplugged.

setlocal

rem 1. The backend.
docker compose -f "%~dp0backend\docker-compose.yml" up -d >nul 2>nul
if errorlevel 1 echo [warn] Could not start the backend. Is Docker Desktop running?

rem 2. The phone: the first device adb lists as ready.
set "DEVICE="
for /f "skip=1 tokens=1,2" %%a in ('adb devices') do if "%%b"=="device" if not defined DEVICE set "DEVICE=%%a"
if not defined DEVICE (
  echo No Android phone found. Plug it in, unlock it, and allow USB debugging.
  exit /b 1
)
echo Using phone %DEVICE%

rem 3. Make the phone's localhost:8010 reach this laptop's backend.
adb -s %DEVICE% reverse tcp:8010 tcp:8010
if errorlevel 1 (
  echo Could not forward port 8010 to the phone.
  exit /b 1
)

rem 4. Give the backend up to about 40 seconds to start answering.
set "UP="
echo Waiting for the backend...
for /l %%i in (1,1,20) do if not defined UP (curl -s -o nul -m 3 http://localhost:8010/health && set "UP=1" || ping -n 3 127.0.0.1 >nul)
if not defined UP echo [warn] The backend is not answering on port 8010. The app will show errors until it is up.
if defined UP echo Backend is up.

rem 5. Flutter: use the one on PATH, else the usual install folder.
where flutter >nul 2>nul
if errorlevel 1 set "PATH=%PATH%;C:\src\flutter\bin"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Could not find flutter. Add its bin folder to PATH, or edit run-android.cmd.
  exit /b 1
)

rem 6. Run the app.
pushd "%~dp0client"
flutter run -d %DEVICE% %*
popd
