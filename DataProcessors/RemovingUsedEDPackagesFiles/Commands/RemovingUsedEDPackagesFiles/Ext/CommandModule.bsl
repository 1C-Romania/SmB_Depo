
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	 OpenForm("DataProcessor.RemovingUsedEDPackagesFiles.Form", , CommandExecuteParameters.Source, 
	 				CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
