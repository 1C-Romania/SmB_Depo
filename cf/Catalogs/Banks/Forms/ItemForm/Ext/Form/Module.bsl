
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		If Parameters.Code <> "" Then
			Object.Code = Parameters.Code;
		EndIf;
		
		If Parameters.CorrAccount <> "" Then
			Object.CorrAccount = Parameters.CorrAccount;
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notify the bank account form about the change of bank attributes
	Notify("RecordedItemBank", Object.Ref, ThisForm);

EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion















