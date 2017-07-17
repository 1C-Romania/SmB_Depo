
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FieldList = Parameters.FieldList;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Apply(Command)
	
	MarkedListItemArray = CommonUseClientServer.GetArrayOfMarkedListItems(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("en='Specify at least one field';ru='Следует указать хотя бы одно поле'");
		
		CommonUseClientServer.MessageToUser(NString,,"FieldList");
		
		Return;
		
	EndIf;
	
	NotifyChoice(FieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion
