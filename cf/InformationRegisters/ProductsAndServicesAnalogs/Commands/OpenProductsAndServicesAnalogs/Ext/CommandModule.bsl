
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Filter = New Structure("ProductsAndServices", CommandParameter);
	FormParameters = New Structure("Filter", Filter);
	OpenForm("InformationRegister.ProductsAndServicesAnalogs.Form.ProductsAndServicesForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
