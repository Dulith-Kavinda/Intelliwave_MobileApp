@echo off
REM Supabase Functionality Test Runner for Windows
REM This script runs all Supabase tests

title Supabase Integration Tests
color 0A

echo.
echo ======================================================
echo  SUPABASE INTEGRATION TEST SUITE
echo ======================================================
echo.

REM Get dependencies
echo [1/3] Installing dependencies...
call flutter pub get
if errorlevel 1 (
    echo.
    color 0C
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo Dependencies installed successfully.
echo.

REM Build runners (if needed)
echo [2/3] Building code generators...
call flutter pub run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo WARNING: Build runner encountered issues
)
echo.

REM Run integration tests
echo [3/3] Running Supabase integration tests...
echo.
call flutter test test/supabase_integration_test.dart -v
if errorlevel 1 (
    echo.
    color 0C
    echo TEST FAILED
    pause
    exit /b 1
)

echo.
color 02
echo ======================================================
echo  ✅ ALL TESTS PASSED SUCCESSFULLY
echo ======================================================
echo.
pause
