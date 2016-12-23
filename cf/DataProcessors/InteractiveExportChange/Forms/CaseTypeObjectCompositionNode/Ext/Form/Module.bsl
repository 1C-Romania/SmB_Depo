
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	CloseOnChoice = False;
	
	Object.InfobaseNode = Parameters.InfobaseNode;
	
	TreeSelect = FormAttributeToValue("AvailableObjectKinds");
	SelectionTreeRows = TreeSelect.Rows;
	SelectionTreeRows.Clear();
	
	AllData = DataExchangeReUse.ExchangePlanContent(Object.InfobaseNode.Metadata().Name);

	// Hide objects, for which it is specified "DoNotExport".
	DoNotExportMode = Enums.ExchangeObjectsExportModes.DoNotExport;
	ImportMode   = DataExchangeReUse.UserExchangePlanContent(Object.InfobaseNode);
	Position = AllData.Count() - 1;
	While Position >= 0 Do
		DataRow = AllData[Position];
		If ImportMode[DataRow.FullMetadataName] = DoNotExportMode Then
			AllData.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	// Delete standard metadata image for leaves.
	AllData.FillValues(-1, "PictureIndex");
	
	AddAllObjects(AllData, SelectionTreeRows);
	
	ValueToFormAttribute(TreeSelect, "AvailableObjectKinds");
	
	SelectedColumns = "";
	For Each Attribute IN GetAttributes("AvailableObjectKinds") Do
		SelectedColumns = SelectedColumns + "," + Attribute.Name;
	EndDo;
	SelectedColumns = Mid(SelectedColumns, 2);
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersAvailableObjectKinds

&AtClient
Procedure AvailableKindsObjectsCase(Item, SelectedRow, Field, StandardProcessing)
	ExecuteCase(SelectedRow);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PickAndClose(Command)
	ExecuteCase();
	Close();
EndProcedure

&AtClient
Procedure Pick(Command)
	ExecuteCase();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function ThisObject(NewObject = Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtClient
Procedure ExecuteCase(SelectedRow = Undefined)
	
	FormTable = Items.AvailableObjectKinds;
	ChoiceData = New Array;
	
	If SelectedRow = Undefined Then
		For Each String IN FormTable.SelectedRows Do
			ChoiceItem = New Structure(SelectedColumns);
			FillPropertyValues(ChoiceItem, FormTable.RowData(String) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	ElsIf TypeOf(SelectedRow) = Type("Array") Then
		For Each String IN SelectedRow Do
			ChoiceItem = New Structure(SelectedColumns);
			FillPropertyValues(ChoiceItem, FormTable.RowData(String) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	Else
		ChoiceItem = New Structure(SelectedColumns);
		FillPropertyValues(ChoiceItem, FormTable.RowData(SelectedRow) );
		ChoiceData.Add(ChoiceItem);
	EndIf;
	
	NotifyChoice(ChoiceData);
EndProcedure

&AtServer
Procedure AddAllObjects(AllReferenceDataNode, TargetRows)
	
	ThisDataProcessor = ThisObject();
	
	DocumentsGroup = TargetRows.Add();
	DocumentsGroup.ListPresentation = ThisDataProcessor.AllDocumentsFilterTitleGroup();
	DocumentsGroup.FullMetadataName = ThisDataProcessor.AllDocumentsID();
	DocumentsGroup.PictureIndex = 7;
	
	CatalogsGroup = TargetRows.Add();
	CatalogsGroup.ListPresentation = ThisDataProcessor.AllCatalogsFilterGroupsTitle();
	CatalogsGroup.FullMetadataName = ThisDataProcessor.AllCatalogsID();
	CatalogsGroup.PictureIndex = 3;
	
	For Each String IN AllReferenceDataNode Do
		If String.PeriodSelection Then
			FillPropertyValues(DocumentsGroup.Rows.Add(), String);
		Else
			FillPropertyValues(CatalogsGroup.Rows.Add(), String);
		EndIf;
	EndDo;
	
	// Delete empty
	If DocumentsGroup.Rows.Count() = 0 Then
		TargetRows.Delete(DocumentsGroup);
	EndIf;
	If CatalogsGroup.Rows.Count() = 0 Then
		TargetRows.Delete(CatalogsGroup);
	EndIf;
	
EndProcedure

#EndRegion














