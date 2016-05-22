
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.CommandScanAvailable Then
		Items.CreationMode.ChoiceList.Delete(2);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CreateFileExecute()
	Close(CreationMode);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetUsageParameters(CreationModeParameter) Export
	CreationMode = CreationModeParameter;
EndProcedure	

#EndRegion
