
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure ScheduleVersionOnChange(Item)
	
	ClearMessages();
	
	If Record.EDFScheduleVersion = PredefinedValue("Enum.Exchange1CRegulationsVersion.Version10") Then
		MessageText = NStr("en = 'This regulation version is not supported by the operator Tax'");
		CommonUseClientServer.MessageToUser(MessageText, , "Record.EDFScheduleVersion");
	EndIf;
	
EndProcedure
