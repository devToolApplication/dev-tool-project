@echo off
setlocal enabledelayedexpansion

echo =========================================
echo  PUSH ALL CHANGED SUBMODULES (CMD)
echo =========================================

REM Lưu thư mục gốc
set ROOT_DIR=%cd%

REM Lấy danh sách submodule
for /f "delims=" %%S in ('git submodule foreach --quiet "echo $path"') do (

    echo.
    echo -----------------------------------------
    echo Checking submodule: %%S
    echo -----------------------------------------

    cd /d "%ROOT_DIR%\%%S"

    REM Kiểm tra thay đổi
    git status --porcelain > temp_git_status.txt

    for %%A in (temp_git_status.txt) do (
        set SIZE=%%~zA
    )

    if NOT "!SIZE!"=="0" (
        echo Changes detected. Committing...
        git add .
        git commit -m "Auto commit from super project"
        git push
    ) else (
        echo No changes.
    )

    del temp_git_status.txt
    cd /d "%ROOT_DIR%"
)

echo.
echo =========================================
echo Updating super project...
echo =========================================

git add .
git status --porcelain > temp_super_status.txt

for %%A in (temp_super_status.txt) do (
    set SUPER_SIZE=%%~zA
)

if NOT "!SUPER_SIZE!"=="0" (
    git commit -m "Update submodule references"
    git push
    echo Super project updated!
) else (
    echo No changes in super project.
)

del temp_super_status.txt

echo.
echo DONE!
pause
