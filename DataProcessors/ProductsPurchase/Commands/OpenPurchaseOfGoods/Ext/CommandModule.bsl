
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("DataProcessor.ProductsPurchase.Form",, CommandExecuteParameters.Source, "ProductsPurchase", CommandExecuteParameters.Window);
	
EndProcedure
