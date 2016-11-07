
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.Peripherals.Form.FiscalRegisterManagement", , CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness,,,, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure
