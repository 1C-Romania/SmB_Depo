
#Region FormEventHandlers

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_AttachedFile" Then
	
		Items.List.Refresh();
	
	EndIf;
	
EndProcedure

#EndRegion