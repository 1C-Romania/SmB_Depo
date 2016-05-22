#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("StateNameForImporting") Then
		Items.Label.Title = StringFunctionsClientServer.PlaceParametersIntoString(Items.Label.Title, Parameters.StateNameForImporting);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Load(Command)
	SetClassifierImportReminderFlag();
	Close(DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure Cancel(Command)
	SetClassifierImportReminderFlag();
	Close(DialogReturnCode.No);
EndProcedure

#EndRegion


#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetClassifierImportReminderFlag()
	If DoNotRemindAboutExport Then
		ApplicationParameters.Insert("AddressClassifier.DoNotImportClassifier", True);
	EndIf;
EndProcedure

#EndRegion




