
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences, 1, 10, False);
		
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure Attachable_ClickOnInformationLink(Command)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Command);
	
EndProcedure

#EndRegion
