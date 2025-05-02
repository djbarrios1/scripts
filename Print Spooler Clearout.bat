@echo off
echo.
echo Purging the print queue . . .

:: Stop the Print Spooler service
net stop Spooler
if %errorlevel% neq 0 (
    echo Failed to stop Print Spooler. Exiting...
    exit /b 1
)

echo Deleting all print jobs . . .
ping localhost -n 2 > nul

:: Delete all print job files
del /q "%SystemRoot%\System32\spool\PRINTERS\*.*"
if %errorlevel% neq 0 (
    echo Failed to delete print jobs. Ensure you have administrative privileges.
    exit /b 1
)

:: Restart the Print Spooler service
net start Spooler
if %errorlevel% neq 0 (
    echo Failed to start Print Spooler. Please start it manually.
    exit /b 1
)

echo Done!
ping localhost -n 2 > nul