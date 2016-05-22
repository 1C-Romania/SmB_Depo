
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	
	OpenForm("InformationRegister.AddressObjects.Form.ClearAddressClassifier", FormParameters, 
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, 
		CommandExecuteParameters.URL
	);
	
EndProcedure
