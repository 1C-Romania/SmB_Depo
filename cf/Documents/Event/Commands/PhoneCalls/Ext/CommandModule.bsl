
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("EventType", PredefinedValue("Enum.EventTypes.PhoneCall"));
	FormParameters.Insert("PurposeUseKey", "PhoneCalls");
	
	OpenForm("Document.Event.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure
