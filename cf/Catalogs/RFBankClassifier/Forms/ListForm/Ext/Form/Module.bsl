
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	CommonUseClientServer.MessageToUser(
		NStr("en='Interactive adding to the classifier is not supported.
		|Use command ""Import classifier""';ru='Интерактивное добавление в классификатор не поддерживается.
		|Воспользуйтесь командой ""Загрузить классификатор""'"));
	
EndProcedure

#EndRegion