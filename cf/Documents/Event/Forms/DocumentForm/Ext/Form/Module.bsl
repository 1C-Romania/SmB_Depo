
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		PrepareFormOnServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	PrepareFormOnServer();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure ListOperationsTypesChoice(Item, SelectedRow, Field, StandardProcessing)
	
	TableRow = ListOperationsTypes.FindByID(SelectedRow);
	
	OpenDocumentKind(TableRow.Value);

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenDocument(Command)
	
	TableRow = Items.ListOperationsTypes.CurrentData;
	
	If Not TableRow = Undefined Then
		
		OpenDocumentKind(TableRow.Value);
		
	EndIf; 
		
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure PrepareFormOnServer()
	
	CopyingValue	= Parameters.CopyingValue;
	FillingValues	= Parameters.FillingValues;
	Basis           = ?(Parameters.Basis = Undefined, Undefined, New Structure("FillingBasis", Parameters.Basis));
	
	Parameters.CopyingValue		= Undefined;
	Parameters.FillingValues	= Undefined;
	Parameters.Basis			= Undefined;
	
	DocumentForms = New FixedMap(
		Documents.Event.GetOperationKindMapToForms());
		
	OperationKinds = GetOperationKindList();
	For Each OperationKind IN OperationKinds Do
		NewOperation = ListOperationsTypes.Add();
		FillPropertyValues(NewOperation, OperationKind);
	EndDo;
	
	If ValueIsFilled(Object.EventType) Then
		SelectedListItem = ListOperationsTypes.FindByValue(Object.EventType);
		If SelectedListItem <> Undefined Then
			Items.ListOperationsTypes.CurrentRow = SelectedListItem.GetID();
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetOperationKindList()

	ListOperationsTypes = New ValueList;
	
	EnumValues = Metadata.Enums.EventTypes.EnumValues;
	For Each EnumValue IN EnumValues Do
		CurrentOperationKind = Enums.EventTypes[EnumValue.Name];
		ListOperationsTypes.Add(CurrentOperationKind, String(CurrentOperationKind));
	EndDo;
	
	Return ListOperationsTypes;

EndFunction

&AtClient
Procedure OpenDocumentKind(SelectedEventType)
	
	If Basis = Undefined Then
		FillingValues.Insert("EventType",	SelectedEventType);
	Else
		Basis.Insert("EventType",			SelectedEventType);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Key",                Parameters.Key);
	ParametersStructure.Insert("CopyingValue",       CopyingValue);
	ParametersStructure.Insert("FillingValues",      FillingValues);
	ParametersStructure.Insert("Basis",              Basis);
	
	Modified = False;
	Close();
	
	OpenForm("Document.Event.Form." + DocumentForms[SelectedEventType], ParametersStructure, FormOwner);
	
EndProcedure

#EndRegion