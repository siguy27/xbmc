@ECHO OFF

SETLOCAL

SET EXITCODE=0

SET getdepends=true
SET install=false
FOR %%b in (%1) DO (
	IF %%b==nodepends SET getdepends=false
	IF %%b==install SET install=true
)

rem set Visual C++ build environment
call "%VS120COMNTOOLS%..\..\VC\bin\vcvars32.bat"

SET WORKDIR=%WORKSPACE%

IF "%WORKDIR%"=="" (
  SET WORKDIR=%CD%\..\..\..
)

rem setup some paths that we need later
SET CUR_PATH=%CD%
SET BASE_PATH=%WORKDIR%\project\cmake
SET ADDONS_PATH=%BASE_PATH%\addons
SET ADDON_DEPENDS_PATH=%ADDONS_PATH%\output
SET ADDONS_BUILD_PATH=%ADDONS_PATH%\build

SET ERRORFILE=%BASE_PATH%\make-addons.error

SET XBMC_INCLUDE_PATH=%ADDON_DEPENDS_PATH%\include\xbmc
SET XBMC_LIB_PATH=%ADDON_DEPENDS_PATH%\lib\xbmc

IF %getdepends%==true (
  CALL make-addon-depends.bat
  IF ERRORLEVEL 1 (
    ECHO make-addon-depends error level: %ERRORLEVEL% > %ERRORFILE%
    GOTO ERROR
  )
)

rem make sure the xbmc include and library paths exist
IF EXIST "%XBMC_INCLUDE_PATH%" (
  RMDIR "%XBMC_INCLUDE_PATH%" /S /Q > NUL
)
IF EXIST "%XBMC_LIB_PATH%" (
  RMDIR "%XBMC_LIB_PATH%" /S /Q > NUL
)
MKDIR "%XBMC_INCLUDE_PATH%"
MKDIR "%XBMC_LIB_PATH%"

rem go into the addons directory
CD %ADDONS_PATH%

rem remove the build directory if it exists
IF EXIST "%ADDONS_BUILD_PATH%" (
  RMDIR "%ADDONS_BUILD_PATH%" /S /Q > NUL
)

rem create the build directory
MKDIR "%ADDONS_BUILD_PATH%"

rem go into the build directory
CD "%ADDONS_BUILD_PATH%"

rem determine the proper install path for the built addons
IF %install%==true (
  SET ADDONS_INSTALL_PATH=%WORKDIR%\addons
) ELSE (
  SET ADDONS_INSTALL_PATH=%WORKDIR%\project\Win32BuildSetup\BUILD_WIN32\Xbmc\xbmc-addons
)

rem execute cmake to generate makefiles processable by nmake
cmake "%ADDONS_PATH%" -G "NMake Makefiles" ^
      -DCMAKE_BUILD_TYPE=Release ^
      -DCMAKE_USER_MAKE_RULES_OVERRIDE="%BASE_PATH%/xbmc-c-flag-overrides.cmake" ^
      -DCMAKE_USER_MAKE_RULES_OVERRIDE_CXX="%BASE_PATH%/xbmc-cxx-flag-overrides.cmake" ^
      -DCMAKE_INSTALL_PREFIX=%ADDONS_INSTALL_PATH% ^
      -DXBMCROOT=%WORKDIR% ^
      -DDEPENDS_PATH=%ADDON_DEPENDS_PATH% ^
      -DPACKAGE_ZIP=1 ^
      -DARCH_DEFINES="-DTARGET_WINDOWS -DNOMINMAX -D_CRT_SECURE_NO_WARNINGS -D_USE_32BIT_TIME_T -D_WINSOCKAPI_"
IF ERRORLEVEL 1 (
  ECHO cmake error level: %ERRORLEVEL% > %ERRORFILE%
  GOTO ERROR
)

rem execute nmake to build the addons
nmake
IF ERRORLEVEL 1 (
  ECHO nmake error level: %ERRORLEVEL% > %ERRORFILE%
  GOTO ERROR
)

rem everything was fine
GOTO END

:ERROR
rem something went wrong
ECHO Failed to build addons
ECHO See %ERRORFILE% for more details
SET EXITCODE=1

:END
rem go back to the original directory
cd %CUR_PATH%

rem exit the script with the defined exitcode
EXIT /B %EXITCODE%
