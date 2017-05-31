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

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	For Each Row In CurrentObject Do
		If Not ValueIsFilled(Row.AttributeValue) Then
			Row.AttributeValue = Undefined;
		EndIf;
		Row.Attribute = Attribute;
	EndDo;
EndProcedure

&AtServer
Procedure SetType(CurrentRow)
	Row = Records.FindByID(CurrentRow);
	Row.Period = Period;
	Common.AdjustValueToTypeRestriction(Row.AttributeValue, AttributeType);
EndProcedure

&AtClient
Procedure RecordsOnStartEdit(Item, NewRow, Clone)
	If NewRow Then
		SetType(Items.Records.CurrentRow);
	EndIf;
EndProcedure

&AtServer
Procedure SelectionAvailableFieldsAtServer(Parameter)
	Attribute = Parameter.Field;
	AttributeString = SettingsComposer.Settings.GroupAvailableFields.GetObjectByID(Parameter.Field).Title;
	AttributeType = Parameter.Type;
	Common.AdjustValueToTypeRestriction(Records.Filter.AttributeValue.Value, Parameter.Type);
	For Each Row In Records Do
		Common.AdjustValueToTypeRestriction(Row.AttributeValue, Parameter.Type);
	EndDo;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "SelectionAvailableFields" Then
		SelectionAvailableFieldsAtServer(Parameter);
	EndIf;
	Items.Records.Visible = ValueIsFilled(Attribute);
	Items.GroupPrefixInitialCounter.Visible = Not ValueIsFilled(Attribute);
EndProcedure

&AtClient
Procedure AttributeOpening(Item, StandardProcessing)
	StandardProcessing = False;
	OpenForm("CommonForm.SettingsComposerAvailableFilterItemsFormManaged", New Structure("EmptyObjectRef, CurrentAttribute", DocumentType, Attribute), ThisForm);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.DocumentType.ChoiceList.Clear();
	
	AvailableTypes = Metadata.InformationRegisters.DocumentsNumberingSettings.Dimensions.DocumentType.Type;
	For Each MetadataObject In Metadata.Documents Do
		
		EmptyRef = Documents[MetadataObject.Name].EmptyRef();
		
		If AvailableTypes.ContainsType(TypeOf(EmptyRef)) Then
			Items.DocumentType.ChoiceList.Add(Documents[MetadataObject.Name].EmptyRef(),MetadataObject.Synonym);
		EndIf;
		
	EndDo;
	Items.DocumentType.ChoiceList.SortByPresentation();
	
	DocumentType = Documents[Parameters.DocumentType.Metadata().Name].EmptyRef();
	If 	Parameters.Property("Period") Then
		Period = Parameters.Period;
	Else
		Query = New Query;
		Query.Text = "SELECT
		|	MAX(DocumentsNumberingSettings.Period) AS Period
		|FROM
		|	InformationRegister.DocumentsNumberingSettings AS DocumentsNumberingSettings
		|WHERE
		|	DocumentsNumberingSettings.DocumentType = &DocumentType";
		
		Query.SetParameter("DocumentType",  DocumentType);
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		If Selection.Next() Then
			Period = Selection.Period;
		Else
			Period = CurrentDate();
		EndIf;
	EndIf;
	DocumentTypeOnChangeAtServer();
	If Records.Count() > 0 Then
		Attribute = Records[0].Attribute;
	ElsIf Records.Count() = 0 Then
		NewRecord = Records.Add();
		NewRecord.Period = Period;
	EndIf;
EndProcedure

&AtClient
Procedure RecordsOnActivateRow(Item)
	
EndProcedure

&AtServer
Procedure ChangeHeader()
	RecordsSet = FormDataToValue(Records, Type("InformationRegisterRecordSet.DocumentsNumberingSettings"));
	
	RecordsSet.Filter.Period.Value = Period;
	RecordsSet.Filter.Period.Use = True;
	RecordsSet.Filter.DocumentType.Value = DocumentType;
	RecordsSet.Filter.DocumentType.Use = True;
	RecordsSet.Read();
	ValueToFormData(RecordsSet, Records);
		
	Items.Records.Enabled = ValueIsFilled(Period);
	Items.GroupPrefixInitialCounter.Enabled = ValueIsFilled(Period);
	Items.Records.Visible = ValueIsFilled(AttributeString);
	Items.GroupPrefixInitialCounter.Visible = Not ValueIsFilled(AttributeString);
	
	If Records.Count() = 0 Then
		NewRecord = Records.Add();
		NewRecord.Period = Period;
	EndIf;
EndProcedure
	
&AtServer
Procedure DocumentTypeOnChangeAtServer()
	
	ChangeHeader();
	
	QueryTextTemplate = "SELECT *
	                    |FROM
	                    |	Document." + DocumentType.Metadata().Name + " AS Doc";
	
	If ValueIsFilled(SchemeURL) Then
		DCS = GetFromTempStorage(SchemeURL);
	Else						
		DCS = New DataCompositionSchema;
	EndIf;
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	
	DataSource = TemplateReports.AddLocalDataSource(DCS);
	If DCS.DataSets.Count() = 0 Then
		DataSet = TemplateReports.AddDataSetQuery(DCS.DataSets, DataSource);
	Else
		DataSet = DCS.DataSets[0];
	EndIf;
	DataSet.Query = QueryTextTemplate;
	
	IsNew = Not ValueIsFilled(SchemeURL);
	If ValueIsFilled(SchemeURL) Then
		DeleteFromTempStorage(SchemeURL);
	EndIf;
	
	SchemeURL = PutToTempStorage(DCS, UUID);
	
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(SchemeURL);
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	If IsNew Then
		DataCompositionSettingsComposer.Initialize(AvailableSettingsSource);
	Else
		DataCompositionSettingsComposer.Refresh();
	EndIf;
	SettingsComposer = DataCompositionSettingsComposer;
EndProcedure

&AtServer
Procedure PeriodOnChangeAtServer()
	ChangeHeader();
EndProcedure

&AtClient
Procedure DocumentTypeOnChange(Item)
	DocumentTypeOnChangeAtServer();
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ValueIsFilled(Attribute) Then
		FindField = FindField(Attribute);
		AttributeString = FindField.Title;
	EndIf;
EndProcedure

&AtClient
Procedure AttributeClearing(Item, StandardProcessing)
	For Each Row In Records Do
		Row.AttributeValue = Undefined;
	EndDo;
	Items.Records.Visible = ValueIsFilled(AttributeString);
	Items.GroupPrefixInitialCounter.Visible = Not ValueIsFilled(AttributeString);
	SchemeURL = "";
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	DocumentTypeOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure OnClose()

EndProcedure

&AtClient
Procedure AttributeOnChange(Item)
	DocumentTypeOnChangeAtServer();
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	If Not FormOwner = Undefined Then
		Notify("ChangePrefixList", , FormOwner);
	EndIf;
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	For Each Row In Records Do
		Row.Period = Period;
	EndDo;
EndProcedure
