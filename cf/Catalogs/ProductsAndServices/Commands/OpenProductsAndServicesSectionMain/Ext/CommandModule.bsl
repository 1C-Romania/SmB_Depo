
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpeningParameters = New Structure("IsStartPage", False);
	OpenForm("Catalog.ProductsAndServices.ListForm", OpeningParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
EndProcedure
