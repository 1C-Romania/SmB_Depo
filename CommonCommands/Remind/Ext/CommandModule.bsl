
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	RecordKey = GetRecordKeyBySource(CommandParameter);
	If RecordKey <> Undefined Then
		FormParameters = New Structure("Key", RecordKey);
	Else
		FormParameters = New Structure("Source", CommandParameter);		
	EndIf;
	OpenForm("InformationRegister.UserReminders.Form.Reminder", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function GetRecordKeyBySource(Source)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	QueryText = 
	"SELECT TOP 1
	|	UserReminders.User,
	|	UserReminders.EventTime,
	|	UserReminders.Source
	|FROM
	|	InformationRegister.UserReminders AS UserReminders
	|WHERE
	|	UserReminders.User = &User
	|	AND UserReminders.Source = &Source";
	
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Source", Source);
	
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	
	ReminderParameters = New Structure("User,Source,EventTime");
	
	Result = Undefined;
	If Selection.Next() Then
		FillPropertyValues(ReminderParameters, Selection);
		Result = InformationRegisters.UserReminders.CreateRecordKey(ReminderParameters);
	EndIf;
	
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

#EndRegion
