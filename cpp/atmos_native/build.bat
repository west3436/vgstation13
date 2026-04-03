@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x86
cd /d "%~dp0"
cl /O2 /fp:fast /std:c++17 /EHsc /DWIN32 /LD /Iinclude src\byondapi_cpp_wrappers.cpp src\gas_mixture.cpp src\state.cpp src\main.cpp /Fe:atmos_native.dll /link include\byondapi.lib
if %errorlevel% neq 0 (
    echo BUILD FAILED
    exit /b 1
)
echo BUILD SUCCEEDED
copy /Y atmos_native.dll ..\..\atmos_native.dll
echo DLL copied to project root
