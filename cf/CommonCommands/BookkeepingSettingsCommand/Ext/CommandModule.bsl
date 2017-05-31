
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm("CommonForm.BookkeepingSettingsCommonForm",New Structure("Ref",CommandParameter),CommandExecuteParameters.Source,CommandExecuteParameters.Source);
EndProcedure
