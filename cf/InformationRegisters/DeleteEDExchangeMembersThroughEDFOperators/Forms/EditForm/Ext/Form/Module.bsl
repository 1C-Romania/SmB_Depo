
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure ScheduleVersionOnChange(Item)
	
	ClearMessages();
	
	If Record.EDFScheduleVersion = PredefinedValue("Enum.Exchange1CRegulationsVersion.Version10") Then
		MessageText = NStr("en='This regulation version is not supported by the operator Tax';ru='Данная версия регламента не поддерживается оператором Такском'");
		CommonUseClientServer.MessageToUser(MessageText, , "Record.EDFScheduleVersion");
	EndIf;
	
EndProcedure



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
