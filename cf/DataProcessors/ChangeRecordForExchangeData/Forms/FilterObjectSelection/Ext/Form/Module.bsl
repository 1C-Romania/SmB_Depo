
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DataTableName = Parameters.TableName;
	CurrentObject = ThisObject();
	TableTitle  = "";
	
	// Determine what is the table that came to us.
	Definition = CurrentObject.MetadataCharacteristics(DataTableName);
	MetaInfo = Definition.Metadata;
	Title = MetaInfo.Presentation();
	
	// List and columns
	DataStructure = "";
	If Definition.IsReference Then
		TableTitle = MetaInfo.ObjectPresentation;
		If IsBlankString(TableTitle) Then
			TableTitle = Title;
		EndIf;
		
		DataList.CustomQuery = False;
		DataList.MainTable = DataTableName;
		
		Field = DataList.Filter.FilterAvailableFields.Items.Find(New DataCompositionField("Ref"));
		ColumnsTable = New ValueTable;
		Columns = ColumnsTable.Columns;
		Columns.Add("Ref", Field.ValueType, TableTitle);
		DataStructure = "Ref";
		
		KeyDataForms = "Ref";
		
	ElsIf Definition.ThisIsSet Then
		Columns = CurrentObject.RegisterSetDimensions(MetaInfo);
		For Each CurrentColumnItem IN Columns Do
			DataStructure = DataStructure + "," + CurrentColumnItem.Name;
		EndDo;
		DataStructure = Mid(DataStructure, 2);
		
		DataList.CustomQuery = True;
		DataList.QueryText = "SELECT DISTINCT " + DataStructure + " IN " + DataTableName;
		
		If Definition.ThisSequence Then
			KeyDataForms = "Recorder";
		Else
			KeyDataForms = New Structure(DataStructure);
		EndIf;
			
	Else
		// Without columns???
		Return;
	EndIf;
	DataList.DynamicDataRead = True;
	
	CurrentObject.FormTableAddColumns(
		Items.DataList, 
		"Order, Filter, Group, DefaultPicture, Parameters, ConditionalAppearance",
		Columns);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers
//

&AtClient
Procedure FilterOnChange(Item)
	
	Items.DataList.Refresh();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersDataList
//

&AtClient
Procedure DataListChoice(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	OpenFormCurrentObject();
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

&AtClient
Procedure OpenCurrentObject(Command)
	OpenFormCurrentObject();
EndProcedure

&AtClient
Procedure SelectFilteredValues(Command)
	MakeSelection(True);
EndProcedure

&AtClient
Procedure ChooseCurrentString(Command)
	MakeSelection(False);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenFormCurrentObject()
	CurParameters = FormParametersCurrentObject(Items.DataList.CurrentData);
	If CurParameters <> Undefined Then
		OpenForm(CurParameters.FormName, CurParameters.Key);
	EndIf;
EndProcedure

&AtClient
Procedure MakeSelection(EntireFilterResult = True)
	
	If EntireFilterResult Then
		Data = AllSelectedItems();
	Else
		Data = New Array;
		For Each CurRow IN Items.DataList.SelectedRows Do
			Item = New Structure(DataStructure);
			FillPropertyValues(Item, Items.DataList.RowData(CurRow));
			Data.Add(Item);
		EndDo;
	EndIf;
	
	NotifyChoice(New Structure("TableName, ChoiceData, ChoiceAction, FieldStructure",
		Parameters.TableName,
		Data,
		Parameters.ActionSelect,
		DataStructure));
EndProcedure

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function FormParametersCurrentObject(Val Data)
	
	If Data = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(KeyDataForms) = Type("String") Then
		Value = Data[KeyDataForms];
		CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
	Else
		// There structure with measurement names.
		CurFormName = "";
		FillPropertyValues(KeyDataForms, Data);
		CurParameters = New Array;
		CurParameters.Add(KeyDataForms);
		RecordKeyName = StrReplace(Parameters.TableName, ".", "RecordKey.");
		Try
			Value = New(RecordKeyName, CurParameters);
			CurFormName = Parameters.TableName + ".RecordForm";
		Except
			// The set without record keys of the reverse register type.
		EndTry;
		
		If IsBlankString(CurFormName) Then
			If Data.Property("Recorder") Then
				Value = Data.Recorder;
			Else
				For Each KeyValue IN KeyDataForms Do
					Value = Data[KeyValue.Key];
					Break;
				EndDo;
			EndIf;
			CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
		EndIf;
	EndIf;		
	
	Return New Structure("FormName, Key", 
		CurFormName, 
		New Structure("Key", Value));
EndFunction

&AtServer
Function AllSelectedItems()
	
	Data = ThisObject().DynamicListCurrentData(DataList);
	
	Result = New Array();
	For Each CurRow IN Data Do
		Item = New Structure(DataStructure);
		FillPropertyValues(Item, CurRow);
		Result.Add(Item);
	EndDo;
	
	Return Result;
EndFunction	

#EndRegion














