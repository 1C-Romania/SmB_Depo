
#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ActiveUsersListClick(Item)
	
	StandardSubsystemsClient.OpenActiveUsersList();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Copy(Command)
	
	If Parameters.Action <> "CopyAndClose" Then
		Close();
	EndIf;
	
	Result = New Structure("Action", Parameters.Action);
	Notify("CopySettingsActiveUsers", Result);
	
EndProcedure

#EndRegion














