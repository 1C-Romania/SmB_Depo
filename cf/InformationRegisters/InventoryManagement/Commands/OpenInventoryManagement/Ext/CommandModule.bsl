
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure("ProductsAndServices", CommandParameter);
	FormParameters = New Structure("Filter", Filter);
	OpenForm("InformationRegister.InventoryManagement.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
