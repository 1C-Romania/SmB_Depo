
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("EventType", PredefinedValue("Enum.EventTypes.Email"));
	FormParameters.Insert("PurposeUseKey", "Email");
	
	OpenForm("Document.Event.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure
