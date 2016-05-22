// Form expects mandatory parameters:
//
// ObjectToMap   - String - object description in current application.
// Application1      - String - Application name - correspondent.
// Application2    - String - name of current application.
//
// ListOfUsedFields - ValueList - fields that are being mapped.
//     Value        - String    - field name,
//     Presentation - String    - field description (title).
//     Check        - Boolean   - flag showing that the field is being used now.
//
// MaximumQuantityOfCustomFields - Number - restriction on mapping field quantity.
//
// StartRowSerialNumber - Number - current row key in the input table.
//
// TemporaryStorageAddress - String - mapping input table address. Columns are used in table:
//     PictureIndex   - Number
//     SerialNumber   - Number, unique row key.
//     OrderField1    - String, attribute value 1 from the used field list.
//     ...
//     FieldSortingNN - String, attribute value NN from used field list.
//
// After form opening the data with address TemporaryStorageAddress will be deleted from the temporary storage.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ObjectToMap = Parameters.ObjectToMap;
	
	Items.ObjectToMap.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Object in ""%1""'"), Parameters.Application1);
		
	Items.Header.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Object in ""%1""'"), Parameters.Application2);
	
	// Make and prepare the choice table on a form.
	BuildSelectionTable(Parameters.MaximumQuantityOfCustomFields, Parameters.ListOfUsedFields, 
		Parameters.TemporaryStorageAddress);
		
	SetCursorSelectTables(Parameters.StartRowSerialNumber);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersChoiceTable

&AtClient
Procedure SelectionTableSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	MakeSelection(SelectedRow);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	MakeSelection(Items.ChoiceTable.CurrentRow);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure MakeSelection(Val SelectionStringID)
	If SelectionStringID=Undefined Then
		Return;
	EndIf;
		
	ChoiceData = ChoiceTable.FindByID(SelectionStringID);
	If ChoiceData<>Undefined Then
		NotifyChoice(ChoiceData.SerialNumber);
	EndIf;
	
EndProcedure

&AtServer
Procedure BuildSelectionTable(Val TotalFields, Val UsedFields, Val DataAddress)
	
	// Add attributes-columns.
	Adding = New Array;
	StringType   = New TypeDescription("String");
	For FieldNumber=1 To TotalFields Do
		Adding.Add(New FormAttribute("SortField" + Format(FieldNumber, "NZ=; NG="), StringType, "ChoiceTable"));
	EndDo;
	ChangeAttributes(Adding);
	
	// Add on form
	ColumnGroup = Items.GroupFields;
	PointType   = Type("FormField");
	ListSize  = UsedFields.Count() - 1;
	
	For FieldNumber=0 To TotalFields-1 Do
		Attribute = Adding[FieldNumber];
		
		NewColumn = Items.Add("ChoiceTable" + Attribute.Name, PointType, ColumnGroup);
		NewColumn.DataPath = Attribute.Path + "." + Attribute.Name;
		If FieldNumber<=ListSize Then
			Field = UsedFields[FieldNumber];
			NewColumn.Visible = Field.Check;
			NewColumn.Title = Field.Presentation;
		Else
			NewColumn.Visible = False;
		EndIf;
	EndDo;
	
	// Fill by values and clear source.
	If Not IsBlankString(DataAddress) Then
		ChoiceTable.Load( GetFromTempStorage(DataAddress) );
		DeleteFromTempStorage(DataAddress);
	EndIf;
EndProcedure

&AtServer
Procedure SetCursorSelectTables(Val StartRowSerialNumber)
	
	For Each String IN ChoiceTable Do
		If String.SerialNumber=StartRowSerialNumber Then
			Items.ChoiceTable.CurrentRow = String.GetID();
			Break;
			
		ElsIf String.SerialNumber>StartRowSerialNumber Then
			IndexOfPrevious = ChoiceTable.IndexOf(String) - 1;
			If IndexOfPrevious>0 Then
				Items.ChoiceTable.CurrentRow = ChoiceTable[IndexOfPrevious].GetID();
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
