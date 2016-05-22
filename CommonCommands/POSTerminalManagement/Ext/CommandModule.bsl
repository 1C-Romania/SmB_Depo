
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.Peripherals.Form.POSTerminalManagement", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness);
	
EndProcedure
