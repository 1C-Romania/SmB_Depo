&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If Not AreFilesInVolumes() Then
		ShowMessageBox(, NStr("en='No files in volumes.';ru='Файлы в томах отсутствуют.'"));
		Return;
	EndIf;
	
	OpenForm("CommonForm.VolumesFileArchivePathSelection", , CommandExecuteParameters.Source);
	
EndProcedure

&AtServer
Function AreFilesInVolumes()
	
	Return FileFunctionsService.AreFilesInVolumes();
	
EndFunction
