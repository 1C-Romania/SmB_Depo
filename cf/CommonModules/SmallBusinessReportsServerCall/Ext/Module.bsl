Function ReportVariantSettingsLinker(ReportOptionProperties) Export
	
	DataCompositionSchema = CommonUse.ObjectManagerByFullName(ReportOptionProperties.ObjectKey).GetTemplate("MainDataCompositionSchema");
	DesiredReportOption = DataCompositionSchema.SettingVariants.Find(ReportOptionProperties.VariantKey);
	
	If DesiredReportOption <> Undefined Then
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.LoadSettings(DesiredReportOption.Settings);
		Return SettingsComposer;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function ReceiveDecryptionValue(Field, Details, ReportDetailsData) Export
	
	DetailsData = GetFromTempStorage(ReportDetailsData);
	DecryptionFieldsArray = GetDecryptionFieldsArray(Details, DetailsData,, True);
	For Each FieldDetailsValue IN DecryptionFieldsArray Do
		If FieldDetailsValue.Field = Field Then
			Return FieldDetailsValue.Value;
		EndIf;
	EndDo;
	
	Return Undefined;
		
EndFunction

// Returns an array according to which a report should be decrypted
Function GetDecryptionFieldsArray(Details, DetailsData, CurrentReport = Undefined, IncludeResources = False) Export
	
	DecryptionFieldsArray = New Array;
	
	If TypeOf(Details) <> Type("DataCompositionDetailsID") 
	   AND TypeOf(Details) <> Type("DataCompositionDetailsData") Then
		Return DecryptionFieldsArray;
	EndIf;
	
	If CurrentReport = Undefined Then
		CurrentReport = DetailsData;
	EndIf;
	
	// Add fields of parent groupings
	AddParents(DetailsData.Items[Details], CurrentReport, DecryptionFieldsArray, IncludeResources);
	
	Count = DecryptionFieldsArray.Count();
	For IndexOf = 1 To Count Do
		ReverseIndex = Count - IndexOf;
		For IndexInside = 0 To ReverseIndex - 1 Do
			If DecryptionFieldsArray[ReverseIndex].Field = DecryptionFieldsArray[IndexInside].Field Then
				DecryptionFieldsArray.Delete(ReverseIndex);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	// Add filter set in the report
	For Each FilterItem IN CurrentReport.Settings.Filter.Items Do
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		DecryptionFieldsArray.Add(FilterItem);
	EndDo;
	
	Return DecryptionFieldsArray;
	
EndFunction

Function AddParents(ItemDetails, CurrentReport, DecryptionFieldsArray, IncludeResources = False)  Export
	
	If TypeOf(ItemDetails) = Type("DataCompositionFieldDetailsItem") Then
		For Each Field IN ItemDetails.GetFields() Do
			AvailableField = GetAvailableFieldByDataLayoutField(New DataCompositionField(Field.Field), CurrentReport);
			If AvailableField = Undefined Then
				Continue;
			EndIf;
			If Not IncludeResources AND AvailableField.Resource Then
				Continue;
			EndIf;
			DecryptionFieldsArray.Add(Field);
		EndDo;
	EndIf;
	For Each Parent IN ItemDetails.GetParents() Do
		AddParents(Parent, CurrentReport, DecryptionFieldsArray, IncludeResources);
	EndDo;
	
EndFunction

// Returns an available field by a layout field
Function GetAvailableFieldByDataLayoutField(DataCompositionField, SearchArea) Export
	
	If TypeOf(DataCompositionField) = Type("String") Then
		AfterSearch = New DataCompositionField(DataCompositionField);
	Else
		AfterSearch = DataCompositionField;
	EndIf;
	
	If TypeOf(SearchArea) = Type("DataCompositionSettingsComposer")
	 Or TypeOf(SearchArea) = Type("DataCompositionDetailsData")
	 Or TypeOf(SearchArea) = Type("DataCompositionNestedObjectSettings") Then
		Return SearchArea.Settings.SelectionAvailableFields.FindField(AfterSearch);
	Else
		Return SearchArea.FindField(AfterSearch);
	EndIf;
	
EndFunction







