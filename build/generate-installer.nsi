Name "$%READABLE_SCRIPT_NAME% $%TAG% ($%COMMIT_HASH%)"
RequestExecutionLevel admin
Unicode True
InstallDir "C:\X-Plane 11"

Page directory 
Page components checkDirectoryFunction
Page instfiles

Function checkDirectoryFunction
	IfFileExists $INSTDIR\Resources\plugins\FlyWithLua LuaInstallationFound NoLuaInstallationFound
	NoLuaInstallationFound:
	MessageBox MB_OK "No FlyWithLua installation found in $INSTDIR. Installing there will not work."
	LuaInstallationFound:
FunctionEnd

Section "$%READABLE_SCRIPT_NAME% (required)"
	SectionIn RO
	SetOutPath $INSTDIR\Resources\plugins\FlyWithLua\Scripts
	
	File /r ..\scripts\*
SectionEnd

Section "$%READABLE_SCRIPT_NAME% Components (required)"
	SectionIn RO
	SetOutPath $INSTDIR\Resources\plugins\FlyWithLua\Modules
	
	File /r ..\script_modules\*
SectionEnd

Section "Dependencies"
	SetOutPath $INSTDIR\Resources\plugins\FlyWithLua\Modules
	
	File ..\modules\*
SectionEnd
