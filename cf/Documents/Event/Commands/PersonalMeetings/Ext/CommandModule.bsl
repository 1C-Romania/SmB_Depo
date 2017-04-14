
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("EventType", PredefinedValue("Enum.EventTypes.PersonalMeeting"));
	FormParameters.Insert("PurposeUseKey", "PersonalMeetings");
	
	OpenForm("Document.Event.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure
