
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ObjectVersioning.OnCreateAtServer(ThisForm);
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

#EndRegion
