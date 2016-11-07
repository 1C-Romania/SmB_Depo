
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	WorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	BackupParameters = WorkParameters.InfobaseBackup;
	
	FormParameters = New Structure();
	
	If BackupParameters.Property("CopyingResult") Then
		FormParameters.Insert("RunMode", ?(BackupParameters.CopyingResult, "ExecutedSuccessfully", "NotCompleted"));
		FormParameters.Insert("BackupFileName", BackupParameters.BackupFileName);
	EndIf;
	
	OpenForm("DataProcessor.InfobaseBackup.Form.DataBackup", FormParameters);
	
EndProcedure
