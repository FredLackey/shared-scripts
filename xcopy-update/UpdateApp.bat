@echo off
REM ============================================================================
REM UpdateApp.bat - Automatic Application Update Script
REM ============================================================================
REM This script uses RoboCopy to safely update application files from a
REM network location to the local machine. It only copies files that have
REM changed and maintains detailed logs of all operations.
REM
REM INSTRUCTIONS FOR CONFIGURATION:
REM Update the three variables below with your specific paths:
REM ============================================================================

REM === CONFIGURATION VARIABLES - UPDATE THESE FOR YOUR ENVIRONMENT ===
REM Friendly name for the application (displayed in messages to users)
SET APP_NAME=My Application

REM Full UNC path to the network folder containing the updated application files
SET NETWORK_SOURCE_PATH=\\server\share\application

REM Full local path where the application should be installed/updated
SET LOCAL_DEST_PATH=C:\Applications\MyApp

REM Full path to the RoboCopy executable (usually in System32)
SET ROBOCOPY_EXE=C:\Windows\System32\robocopy.exe

REM ============================================================================
REM DO NOT MODIFY BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING
REM ============================================================================

REM Set up logging variables
SET SCRIPT_DIR=%~dp0
SET LOG_DIR=%SCRIPT_DIR%logs
SET TIMESTAMP=%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%
SET TIMESTAMP=%TIMESTAMP: =0%
SET LOG_FILE=%LOG_DIR%\UpdateApp_%TIMESTAMP%.log
SET SUMMARY_LOG=%LOG_DIR%\UpdateApp_Summary.log

REM Create logs directory if it doesn't exist
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Start logging
echo ============================================================================ >> "%LOG_FILE%"
echo %APP_NAME% Update - Started: %DATE% %TIME% >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Display startup message
echo.
echo ============================================================================
echo %APP_NAME% - Checking for Updates
echo ============================================================================
echo Started: %DATE% %TIME%
echo.
echo Please wait while we check for the latest version of %APP_NAME%...
echo This may take a few moments.
echo.

REM Log configuration
echo Configuration: >> "%LOG_FILE%"
echo   Application Name: %APP_NAME% >> "%LOG_FILE%"
echo   Source Path: %NETWORK_SOURCE_PATH% >> "%LOG_FILE%"
echo   Destination Path: %LOCAL_DEST_PATH% >> "%LOG_FILE%"
echo   RoboCopy Path: %ROBOCOPY_EXE% >> "%LOG_FILE%"
echo   Log Directory: %LOG_DIR% >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Verify RoboCopy executable exists
if not exist "%ROBOCOPY_EXE%" (
    echo ERROR: System file copying utility not found.
    echo ERROR: RoboCopy executable not found at: %ROBOCOPY_EXE% >> "%LOG_FILE%"
    echo Please contact your system administrator for assistance.
    echo Please check the ROBOCOPY_EXE variable in this script. >> "%LOG_FILE%"
    goto :error_exit
)

REM Verify source path exists and is accessible
if not exist "%NETWORK_SOURCE_PATH%" (
    echo ERROR: Unable to connect to the %APP_NAME% update server.
    echo ERROR: Source path not accessible: %NETWORK_SOURCE_PATH% >> "%LOG_FILE%"
    echo Please check your network connection or contact your system administrator.
    echo Please check network connectivity and path configuration. >> "%LOG_FILE%"
    goto :error_exit
)

REM Create destination directory if it doesn't exist
if not exist "%LOCAL_DEST_PATH%" (
    echo Setting up %APP_NAME% for the first time...
    echo Creating destination directory: %LOCAL_DEST_PATH% >> "%LOG_FILE%"
    mkdir "%LOCAL_DEST_PATH%"
    if errorlevel 1 (
        echo ERROR: Unable to set up %APP_NAME% installation folder.
        echo ERROR: Could not create destination directory: %LOCAL_DEST_PATH% >> "%LOG_FILE%"
        goto :error_exit
    )
)

REM Log pre-copy status
echo Pre-copy verification completed successfully. >> "%LOG_FILE%"
echo Starting file synchronization... >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Execute RoboCopy with appropriate flags
REM /MIR = Mirror directory tree (delete files in dest that don't exist in source)
REM /FFT = Assume FAT file times (2-second granularity)
REM /Z = Copy files in restartable mode
REM /W:5 = Wait 5 seconds between retries
REM /R:3 = Retry 3 times on failed copies
REM /LOG+= Append to log file
REM /TEE = Output to console and log file
REM /NP = No progress percentage in log
REM /NDL = No directory list in log

echo Updating %APP_NAME%...
echo Command: "%ROBOCOPY_EXE%" "%NETWORK_SOURCE_PATH%" "%LOCAL_DEST_PATH%" /MIR /FFT /Z /W:5 /R:3 /LOG+:"%LOG_FILE%" /TEE /NP >> "%LOG_FILE%"

"%ROBOCOPY_EXE%" "%NETWORK_SOURCE_PATH%" "%LOCAL_DEST_PATH%" /MIR /FFT /Z /W:5 /R:3 /LOG+:"%LOG_FILE%" /TEE /NP

REM Capture RoboCopy exit code
SET ROBOCOPY_EXIT_CODE=%ERRORLEVEL%

REM Log completion
echo. >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"
echo Update process completed with exit code: %ROBOCOPY_EXIT_CODE% >> "%LOG_FILE%"
echo Completed: %DATE% %TIME% >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"

REM Interpret RoboCopy exit codes
echo.
echo ============================================================================
echo %APP_NAME% Update Complete
echo ============================================================================

if %ROBOCOPY_EXIT_CODE% EQU 0 (
    echo Great news! %APP_NAME% is already up to date.
    echo No updates were needed at this time.
    echo Status: SUCCESS - No files needed copying >> "%SUMMARY_LOG%"
) else if %ROBOCOPY_EXIT_CODE% EQU 1 (
    echo Success! %APP_NAME% has been updated to the latest version.
    echo New files have been installed.
    echo Status: SUCCESS - Files copied successfully >> "%SUMMARY_LOG%"
) else if %ROBOCOPY_EXIT_CODE% EQU 2 (
    echo Success! %APP_NAME% has been cleaned up and synchronized.
    echo Some outdated files were removed to keep everything current.
    echo Status: SUCCESS - Extra files/directories detected >> "%SUMMARY_LOG%"
) else if %ROBOCOPY_EXIT_CODE% EQU 3 (
    echo Success! %APP_NAME% has been fully updated and optimized.
    echo New files installed and outdated files removed.
    echo Status: SUCCESS - Files copied and extra files removed >> "%SUMMARY_LOG%"
) else if %ROBOCOPY_EXIT_CODE% GEQ 8 (
    echo We encountered a problem updating %APP_NAME%.
    echo Please contact your system administrator for assistance.
    echo Status: ERROR - Update process encountered errors >> "%SUMMARY_LOG%"
    goto :error_exit
) else (
    echo %APP_NAME% update completed, but with an unusual result.
    echo Please contact your system administrator if you experience any issues.
    echo Status: WARNING - Unusual exit code: %ROBOCOPY_EXIT_CODE% >> "%SUMMARY_LOG%"
)

echo.
echo Completed: %DATE% %TIME%
echo.

REM Update summary log
echo %DATE% %TIME% - Exit Code: %ROBOCOPY_EXIT_CODE% - Log: %LOG_FILE% >> "%SUMMARY_LOG%"

REM Success exit
echo %APP_NAME% is ready to use!
exit /b 0

:error_exit
REM Error exit routine
echo.
echo ============================================================================
echo %APP_NAME% Update Could Not Be Completed
echo ============================================================================
echo We're sorry, but we encountered a problem while updating %APP_NAME%.
echo Please contact your system administrator for assistance.
echo.
echo %DATE% %TIME% - ERROR - Update failed - Log: %LOG_FILE% >> "%SUMMARY_LOG%"
echo Update process failed with errors. >> "%LOG_FILE%"
pause
exit /b 1 