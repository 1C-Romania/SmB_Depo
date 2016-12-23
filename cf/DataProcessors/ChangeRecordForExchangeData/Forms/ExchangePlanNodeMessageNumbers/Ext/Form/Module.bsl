#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Parameters.Property("ExchangeNodeRef", ExchangeNodeRef);
	If Parameters.Property("Name", WarningOnOpening) Then
		If WarningOnOpening = "FormEditMessagesNumber" Then
			WarningOnOpening = Undefined;
		ElsIf WarningOnOpening = "MetadataTree" Then
			WarningOnOpening = True;
		Else 
			Cancel = True;
		EndIf 
	Else
		Cancel = True;
	EndIf;
	
	ReadNumberMessages();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(WarningOnOpening) Then
		ShowValue(, WarningOnOpening);
		Cancel = True;
	EndIf;
	
	Title = ExchangeNodeRef;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Writes modified data and closes form.
//
&AtClient
Procedure WriteNodeChanges(Command)
	
	WriteMessagesNumber();
	Notify("ExchangeNodeDataChange", ExchangeNodeRef, ThisObject);
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Procedure ReadNumberMessages()
	
	Data = ThisObject().GetNodExchangeParameters(ExchangeNodeRef, "SentNo, ReceivedNo, DataVersion", Items.ReceivedNo, WarningOnOpening);
	If Data = Undefined Then
		SentNo = Undefined;
		ReceivedNo     = Undefined;
		DataVersion       = Undefined;
	Else
		SentNo = Data.SentNo;
		ReceivedNo     = Data.ReceivedNo;
		DataVersion       = Data.DataVersion;
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteMessagesNumber()
	
	Data = New Structure("SentNo, ReceivedNo", SentNo, ReceivedNo);
	ThisObject().SetNodExchangePArameters(ExchangeNodeRef, Data);
EndProcedure

#EndRegion














