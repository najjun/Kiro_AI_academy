@echo off
REM AIDLC 시작 도우미 (Windows)
REM Python/Node가 없어도 더블클릭 한 번으로 개발 준비를 끝냅니다.
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo [AIDLC 시작 도우미] 실행 중입니다. 설치가 끝나면 이 창은 닫아도 됩니다.
echo.

REM --- 1) uv (파이썬 관리자) 확인/설치 ---
where uv >nul 2>nul
if %ERRORLEVEL%==0 (
  echo [OK] uv 가 이미 설치되어 있습니다.
) else (
  echo uv^(파이썬을 자동 관리하는 초경량 도구^)를 설치합니다...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
  set "PATH=%USERPROFILE%\.local\bin;%PATH%"
)

REM --- 2) 파이썬 확보 ---
where uv >nul 2>nul
if %ERRORLEVEL%==0 (
  echo 파이썬 3.12 를 준비합니다^(이미 있으면 건너뜁니다^)...
  uv python install 3.12
  echo [OK] 파이썬 준비 완료.
)

REM --- 3) Node.js 확인/설치 (공식 LTS zip 자동 다운로드, 관리자 권한 불필요) ---
where node >nul 2>nul
if %ERRORLEVEL%==0 (
  echo [OK] Node.js 가 이미 설치되어 있습니다.
) else if exist "%USERPROFILE%\.aidlc\node\node.exe" (
  set "PATH=%USERPROFILE%\.aidlc\node;%PATH%"
  echo [OK] Node.js 준비됨 ^(%USERPROFILE%\.aidlc\node^).
) else (
  echo Node.js^(공식 LTS 빌드^)를 설치합니다...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ver='v22.14.0'; $arch= if($env:PROCESSOR_ARCHITECTURE -match 'ARM64'){'arm64'}else{'x64'}; $dir=Join-Path $env:USERPROFILE '.aidlc\node'; New-Item -ItemType Directory -Force -Path $dir | Out-Null; $zip=Join-Path $env:TEMP 'aidlc-node.zip'; Invoke-WebRequest -UseBasicParsing -Uri ('https://nodejs.org/dist/{0}/node-{0}-win-{1}.zip' -f $ver,$arch) -OutFile $zip; $tmp=Join-Path $env:TEMP 'aidlc-node-x'; Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue; Expand-Archive -Path $zip -DestinationPath $tmp -Force; $inner=(Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName; Copy-Item (Join-Path $inner '*') $dir -Recurse -Force; $u=[Environment]::GetEnvironmentVariable('PATH','User'); if($u -notlike '*\.aidlc\node*'){[Environment]::SetEnvironmentVariable('PATH', $dir+';'+$u,'User')}; Write-Host ('[OK] Node 설치 완료: '+$dir)"
  set "PATH=%USERPROFILE%\.aidlc\node;%PATH%"
)

echo.
echo [완료] 준비가 끝났습니다!
echo 다음 단계: 이 폴더를 사용하는 AI 코딩 툴^(Claude Code, Kiro, Codex 등^)에서 열고,
echo           "requirements 폴더의 문서를 보고 AIDLC 워크플로우를 시작해줘" 라고 요청하세요.
echo.
pause
