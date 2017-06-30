&AtClient
Function GetFieldArray(Val SelectedRow)
	Result = New Array;
	While Find(SelectedRow, ".") > 0 Do
		Value = Left(SelectedRow, Find(SelectedRow,".") - 1);
		SelectedRow = Right(SelectedRow, StrLen(SelectedRow) - Find(SelectedRow, "."));
		Result.Add(Value);
	EndDo;
	
	Result.Add(SelectedRow);
	
	Return Result;
EndFunction

&AtClient
Function FindField(SelectedRow)
	FieldArray = GetFieldArray(SelectedRow);
	If FieldArray.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	i = 0;
	CurrentItemName = "";
	For Each Field In FieldArray Do
		If i = 0 Then
			Result = SettingsComposer.Settings.SelectionAvailableFields.Items.Find(Field);
			CurrentItemName = Field;
		Else
			CurrentItemName = CurrentItemName + "." + Field;
			Result = Result.Items.Find(CurrentItemName);
		EndIf;
		i = i + 1;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure SettingsComposerSettingsSelectionSelectionAvailableFieldsSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	Field = FindField(String(SelectedRow));
	Notify("SelectionAvailableFields", New Structure("Field, Description, Type", SelectedRow, Field.Title, Field.Type));
	DeleteFromTempStorage(SchemeURL);
	Close();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	CurrentAttribute = Parameters.CurrentAttribute;
	//Items.SettingsComposerSettingsSelectionSelectionAvailableFields.CurrentRow = ;
	QueryTextTemplate = "SELECT
	                    |	*
	                    |FROM
	                    |	Document." + Parameters.EmptyObjectRef.Metadata().Name + " AS Doc";
	DCS = New DataCompositionSchema;
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	
	DataSource = TemplateReports.AddLocalDataSource(DCS);
	DataSet = TemplateReports.AddDataSetQuery(DCS.DataSets, DataSource);
	DataSet.Query = QueryTextTemplate;
	
	SchemeURL = PutToTempStorage(DCS);
	
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(SchemeURL);
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	DataCompositionSettingsComposer.Initialize(AvailableSettingsSource);
	
	SettingsComposer = DataCompositionSettingsComposer;
	NewGroup = SettingsComposer.Settings.Structure.Add(Type("DataCompositionNestedObjectSettings"));
	SettingsComposer.Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	
	//CurrentField = FindField(CurrentAttribute);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurrentField = FindField(CurrentAttribute);
	If Not CurrentField = Undefined Then
		
		Items.SettingsComposerSettingsSelectionSelectionAvailableFields.CurrentRow = SettingsComposer.Settings.SelectionAvailableFields.GetIDByObject(CurrentField);
		q = "";
	EndIf;
EndProcedure
