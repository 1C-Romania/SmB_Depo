
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



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
