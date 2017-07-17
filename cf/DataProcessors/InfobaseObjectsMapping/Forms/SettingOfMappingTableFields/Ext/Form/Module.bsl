
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
	
	Cancel = False;
	
	MarkedListItemArray = CommonUseClientServer.GetArrayOfMarkedListItems(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("en='Specify at least one field';ru='Следует указать хотя бы одно поле'");
		
		CommonUseClientServer.MessageToUser(NString,,"FieldList",, Cancel);
		
	ElsIf MarkedListItemArray.Count() > MaximumQuantityOfCustomFields() Then
		
		// Value can not be greater than the set one.
		MessageString = NStr("en='Reduce the number of fields (select no more than [FieldQuantity] fields)';ru='Уменьшите количество полей (можно выбирать не более [КоличествоПолей] полей)'");
		MessageString = StrReplace(MessageString, "[FieldsCount]", String(MaximumQuantityOfCustomFields()));
		CommonUseClientServer.MessageToUser(MessageString,,"FieldList",, Cancel);
		
	EndIf;
	
	If Not Cancel Then
		
		NotifyChoice(FieldList.Copy());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function MaximumQuantityOfCustomFields()
	
	Return DataExchangeClient.MaximumQuantityOfFieldsOfObjectMapping();
	
EndFunction

#EndRegion
