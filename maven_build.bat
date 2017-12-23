@echo off
REM 编译逻辑：
REM 1.先从resPath目录查找所有的application-xxx.properties文件，并复制到临时文件夹tempFolder中。
REM 2.删除resPath目录下非profile的application-xxx.properties文件，比如profile为xdesign，
REM 	则删除除了application.properties和application-xdesign.properties的application-xxx.properties文件
REM 3.将resPath目录下application-profile.properties文件的spring.profiles.active配置改成profile
REM 4.编译
REM 5.将tempFolder目录下保存的application-xxx.properties文件恢复到resPath目录，同时删除tempFolder目录
setlocal enabledelayedexpansion

set profile=%1%
if "%profile%"=="" (
	echo 必须指定一个profile
	goto end
)

REM 查找所有properties，并赋给“数组”PROFILES
set resPath=.\src\main\resources
set idx=0
for /f "delims=\" %%a in ('dir /b /a-d "%resPath%\application*.properties"') do (
	if not %%a==application.properties (
		set /a idx+=1
		set file=%%a
		REM echo 找到profile文件：!file:~12,-11!
		set PROFILES[!idx!]=!file:~12,-11!
	)
)

for /f "tokens=2 delims==" %%s in ('set PROFILES[') do if %profile%==%%s goto backFiles

echo 未找到对应的profile
goto end



:backFiles
REM 将%resPath%目录下的properties文件备份至%tempFolder%目录下
set tempFolder=temp-compile
if exist %tempFolder% rd /s /q %tempFolder%
mkdir %tempFolder%

for /f "delims=\" %%a in ('dir /b /a-d "%resPath%\application*.properties"') do (
	set propFile=%%a
	copy %resPath%\!propFile! .\%tempFolder%\!propFile! > nul
)



:deleteFiles
REM 删除%resPath%下非%profile%的properties文件
for /f "delims=\" %%a in ('dir /b /a-d "%resPath%\application*.properties"') do (
	if not %%a==application-%profile%.properties (
		if not %%a==application.properties (
			REM echo 即将删除 %resPath%\%%a
			del %resPath%\%%a /f /s
		)
	)
)



:modifyProfileConfig
REM 修改application.properties文件中的启用profile配置（key为spring.profiles.active）
set index=0
set targetIdx=0
for /f "delims=" %%i in (%resPath%\application.properties) do (
	set /a index+=1
	set content=%%i
	set prefix=!content:~0,22!
	set var!index!=%%i
	if !prefix!==spring.profiles.active set targetIdx=!index!
)

set content=spring.profiles.active=
REM 修改application.properties文件中spring.profiles.active=xxxx的内容
set var%targetIdx%=%content%%profile%
(for /l %%j in (1 1 !index!) do echo !var%%j!) > %resPath%\application.properties



:build
call mvn clean package
if %errorlevel%==0 goto restore
echo 编译失败！
goto restore



:restore
REM 将备份的文件复制回%resPath%目录
for /f "delims=\" %%a in ('dir /b /a-d ".\%tempFolder%\application*.properties"') do (
	set tmpFile=%%a
	copy /y .\%tempFolder%\!tmpFile! %resPath%\!tmpFile! > nul
)
if exist %tempFolder% rd /s /q %tempFolder%



:end
pause
