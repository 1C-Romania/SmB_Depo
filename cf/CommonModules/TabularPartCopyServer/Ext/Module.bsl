
#Region ProgrammInterface


Procedure OnCreateAtServer(FormItems, TPName) Export
	
	IsCopiedRows = CommonSettingsStorage.Load("TabularPartsClipboard", "Rows") <> Undefined;
	SetButtonsVisibility(FormItems, TPName, IsCopiedRows);
	
EndProcedure


Procedure Copy(TP, SelectedRows, CopiedCount) Export
	
	CopiedRows = TP.Unload();
	
	Iterator = TP.Count() - 1;
	While Iterator >= 0 Do
		Identifier = TP[Iterator].GetID();
		If SelectedRows.Find(Identifier) = Undefined Then
			CopiedRows.Удалить(Iterator);
		EndIf;
		
		Iterator = Iterator - 1;
	EndDo;
	
	CommonSettingsStorage.Save("TabularPartsClipboard", "Rows", CopiedRows);
	CopiedCount = CopiedRows.Count();
	
EndProcedure


Procedure Paste(Object, TPName, FormItems, CopiedCount, PastededCount) Export
	
	If TypeOf(TPName) = Type("Structure") Then
		ItemName = TPName.ItemName;
		TPName = TPName.TPName;
	Else
		ItemName = TPName;
	EndIf;
	
	TP = Object[TPName];
	TPMetadata = Object.Ref.Metadata().TabularSections[TPName];
	
	SelectedRows = FormItems[ItemName].SelectedRows;
	SelectedRows.Очистить();
	
	AddedRows = CommonSettingsStorage.Load("TabularPartsClipboard", "Rows");
	If AddedRows = Undefined Then
		Return;
	EndIf;
	CopiedCount = AddedRows.Count();
	
	ExcludedColumns = "";
	
	For Each TPAttribute In TPMetadata.Attributes Do
		
		If AddedRows.Columns.Find(TPAttribute.Name) = Undefined Then
			If ValueIsFilled(ExcludedColumns) Then
				ExcludedColumns = ExcludedColumns + ",";
			EndIf;
			ExcludedColumns = ExcludedColumns + TPAttribute.Name;
			Continue;
		EndIf;
		
		FunctionalOption = Undefined;
		AttributeIsAvailable = CheckObjectAvailability(TPAttribute, FunctionalOption);
		If NOT AttributeIsAvailable Then
			Continue;
		EndIf;
		
		If TPAttribute.Type.ContainsType(Type("Boolean")) Then
			Continue;
		EndIf;
		
		ValuesIterator = 0;
		Condition = "";
		AcceptableValues = New Array;
		
		ChoiceParameterPresentation = "Row." + TPAttribute.Name + ".";
		
		If FormItems.Find(ItemName + TPAttribute.Name) <> Undefined Then
			ChoiceParameters = FormItems[ItemName + TPAttribute.Name].ChoiceParameters;
		Else
			ChoiceParameters = TPAttribute.ChoiceParameters;
		EndIf;
		
		For Each ChoiceParameter In ChoiceParameters Do
			
			If Find(ChoiceParameter.Name, "Filter.") <> 1 Then
				Continue;
			EndIf;
			
			AttributePresentation = Right(ChoiceParameter.Name, StrLen(ChoiceParameter.Name) - StrLen("Filter."));
			ChoiceParameterPresentation = ChoiceParameterPresentation + AttributePresentation;
			
			AttributeCondition = "";
			
			If TypeOf(ChoiceParameter.Value) = Type("FixedArray") OR TypeOf(ChoiceParameter.Value) = Type("Array") Then
				For Each AttributeValue In ChoiceParameter.Value Do
					
					If ValueIsFilled(AttributeCondition) Then
						AttributeCondition = AttributeCondition + "OR "
					EndIf;
					
					AcceptableValues.Добавить(AttributeValue);
					AttributeCondition = AttributeCondition + ChoiceParameterPresentation + "=AcceptableValues[" + ValuesIterator + "] ";
					ValuesIterator = ValuesIterator + 1;
					
				EndDo;
			Else
				AcceptableValues.Добавить(ChoiceParameter.Value);
				AttributeCondition = AttributeCondition + ChoiceParameterPresentation + "=AcceptableValues[" + ValuesIterator + "] ";
				ValuesIterator = ValuesIterator + 1;
			EndIf;
			
			AttributeConditionByTypeAND = "";
			AttributeConditionByTypeOR = "";
			AttributeTypes = TPAttribute.Type.Types();
			If AttributeTypes.Count() > 1 Then
				
				For Each Type In AttributeTypes Do
					
					MetadataObjectByType = Metadata.FindByType(Type);
					If CommonUse.ThisIsCatalog(MetadataObjectByType)
						OR CommonUse.ThisIsDocument(MetadataObjectByType) Then
						
						If MetadataObjectByType.Attributes.Find(AttributePresentation) = Undefined Then
							
							If ValueIsFilled(AttributeConditionByTypeOR) Then
								AttributeConditionByTypeOR = AttributeConditionByTypeOR + " OR ";
							EndIf;
							
							AcceptableValues.Добавить(Type);
							AttributeConditionByTypeOR = AttributeConditionByTypeOR + "ТипЗнч(Строка." + TPAttribute.Name + ")" + "=AcceptableValues[" + ValuesIterator + "] ";
							ValuesIterator = ValuesIterator + 1;
							
						Else
							
							If ValueIsFilled(AttributeConditionByTypeAND) Then
								AttributeConditionByTypeAND = AttributeConditionByTypeAND + " OR ";
							Else
								AttributeConditionByTypeAND = AttributeConditionByTypeAND + "(";
							EndIf;
							
							AcceptableValues.Добавить(Type);
							AttributeConditionByTypeAND = AttributeConditionByTypeAND + "TypeOf(Row." + TPAttribute.Name + ")" + "=AcceptableValues[" + ValuesIterator + "] ";
							ValuesIterator = ValuesIterator + 1;
							
						EndIf;
						
					EndIf;
					
				EndDo;
				
				AttributeConditionByTypeAND = AttributeConditionByTypeAND + ")";
				AttributeCondition = "(" + AttributeConditionByTypeAND + " И (" + AttributeCondition + ")) ИЛИ " + AttributeConditionByTypeOR;
				
			EndIf;
			
			Condition = Condition + AttributeCondition;
			AddedRows = FindByCondition(AddedRows, TPAttribute.Name, Condition, AcceptableValues);
			
		EndDo;
		
	EndDo;
	
	For Each Row In AddedRows Do
		
		NewRow = TP.Add();
		
		ExcludedColumnsNew = "";
		
		For Each Column In TPMetadata.Attributes Do
			
			If Find(ExcludedColumns, Column.Name) <> 0 Then
				Continue;
			EndIf;
			
			If NOT Column.Type.ContainsType(TypeOf(Row[Column.Name])) Then
				ExcludedColumnsNew = ExcludedColumnsNew + "," + Column.Name;
			EndIf;
		EndDo;
		
		FillPropertyValues(NewRow, Row, , ExcludedColumnsNew);
		
		SelectedRows.Add(NewRow.GetID());
		
	EndDo;
	
	PastededCount = AddedRows.Count();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function FindByCondition(VT, FilterAttribute, Condition, AcceptableValues)
	
	NewVT = New ValueTable;
	For Each Column In VT.Колонки Do
		NewVT.Columns.Add(Column.Name, Column.ValueType, Column.Title, Column.Width);
	EndDo;
	
	For Each Row In VT Do
		
		ProperRow = False;
		
		If NOT ValueIsFilled(Row[FilterAttribute]) Then
			ProperRow = True;
		EndIf;
		
		If NOT ProperRow Then
			
			ProperRow = Eval(Condition);
			
		EndIf;
		
		If ProperRow Then
			NewRow = NewVT.Add();
			FillPropertyValues(NewRow, Row);
		EndIf
		
	EndDo;
	
	Возврат NewVT;
	
EndFunction

Procedure SetButtonsVisibility(FormItems, TPName, IsCopiedRows)
	
	FormItems[TPName + "CopyRows"].Enabled = True;
	
	If IsCopiedRows Then
		FormItems[TPName + "PasteRows"].Enabled = True;
	Else
		FormItems[TPName + "PasteRows"].Enabled = False;
	EndIf;
	
EndProcedure


Function CheckObjectAvailability (Object, FunctionalOption)
	
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		
		ContentItem = FunctionalOption.Content.Find(Object);
		If ContentItem <> Undefined Then
			Прервать;
		EndIf;
		
	EndDo;
	
	If ContentItem <> Undefined Then
		Return GetFunctionalOption(FunctionalOption.Name);
	EndIf;
	
	FunctionalOption = Undefined;
	Return True;
	
EndFunction

#EndRegion




