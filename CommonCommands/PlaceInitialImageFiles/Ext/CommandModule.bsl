&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If Not AreFilesInVolumes() Then
		ShowMessageBox(, NStr("en = 'Files are absent in volumes.'"));
		Return;
	EndIf;
	
	OpenForm("CommonForm.VolumesFileArchivePathSelection", , CommandExecuteParameters.Source);
	
EndProcedure

&AtServer
Function AreFilesInVolumes()
	
	Return FileFunctionsService.AreFilesInVolumes();
	
EndFunction
