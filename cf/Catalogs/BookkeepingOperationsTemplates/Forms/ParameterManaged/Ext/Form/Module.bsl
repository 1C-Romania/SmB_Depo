
&AtServer
Var SystemDataCompositionDataSchema;
&AtServer
Var DCS;

#Region BaseFormsProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsNew = Parameters.IsNew;

	LineNumber = ?(Parameters.Property("LineNumber"), Parameters.LineNumber, 0);	
	
	DocumentBase = ?(Parameters.Property("DocumentBase"), Parameters.DocumentBase, Undefined);
	TableKind = ?(Parameters.Property("TableKind"), Parameters.TableKind, Enums.BookkeepingOperationTemplateTableKind.EmptyRef());
	TableKindFilter = ?(Parameters.Property("TableKindFilter"), Parameters.TableKindFilter, New ValueList);
	TableName = ?(Parameters.Property("TableName"), Parameters.TableName, "");
	TableBox = ?(Parameters.Property("TableBox"), Parameters.TableBox, "");	
	TypeRestriction = ?(Parameters.Property("TypeRestriction"), Parameters.TypeRestriction, New TypeDescription);
	
	Name = ?(Parameters.Property("Name"), Parameters.Name, Undefined);		
	Presentation = ?(Parameters.Property("Presentation"), Parameters.Presentation, Undefined);		
	Type = ?(Parameters.Property("Type"), Parameters.Type, Undefined);		
	Value = ?(Parameters.Property("Value"), Parameters.Value, Undefined);		
	NotRequest = ?(Parameters.Property("NotRequest"), Parameters.NotRequest, Undefined);		
	LinkByOwner = ?(Parameters.Property("LinkByOwner"), Parameters.LinkByOwner, Undefined);		
	LinkByType = ?(Parameters.Property("LinkByType"), Parameters.LinkByType, Undefined);		
	ExtDimensionNumber = ?(Parameters.Property("ExtDimensionNumber"), Parameters.ExtDimensionNumber, Undefined);		
	LongDescription = ?(Parameters.Property("LongDescription"), Parameters.LongDescription, Undefined);		
	Obligatory = ?(Parameters.Property("Obligatory"), Parameters.Obligatory, Undefined);		
	ParameterKind = ?(Parameters.Property("ParameterKind"), Parameters.ParameterKind, Undefined);		
	ParameterFormula = ?(Parameters.Property("ParameterFormula"), Parameters.ParameterFormula, Undefined);			
		
	ExtDimensionNumber = ?(Parameters.Property("ExtDimensionNumber"), Parameters.ExtDimensionNumber, 1);				
	
	CatalogObject = FormDataToValue(Object, Type("CatalogObject.BookkeepingOperationsTemplates"));
	
	// global data initializing
	NeedToSetSelectionAvailableFields = False;
	DocumentTableSynonym = Nstr("en = 'Document''s data'; pl = 'Dane dokumentu'");
	TableOfTables.Load(Catalogs.BookkeepingOperationsTemplates.GetTableOfTables(DocumentBase,DocumentTableSynonym));
	
	SystemDataCompositionDataSchema = CatalogObject.GetTemplate("SystemData");
	SystemDataSchemaInTempStorage = PutToTempStorage(SystemDataCompositionDataSchema, New UUID());
	SystemDataDataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SystemDataSchemaInTempStorage));
	SystemDataDataCompositionSettingsComposer.LoadSettings(SystemDataCompositionDataSchema.DefaultSettings);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CopyFormData(ThisForm.FormOwner.Object,Object);
	OnOpenAtServer();
	UpdateDialog();
EndProcedure

&AtServer
Procedure OnOpenAtServer()
	If DocumentBase = Undefined Then
		
		If LinkByType <> "" Then
			TypeSelectionMethod = 1;
		Else
			TypeSelectionMethod = 0;
		EndIf;
		
		If IsNew Then
			// new parameter
			Type = TypeRestriction;
		EndIf;	
		
		TypeOnChangeAtServer();
		TypeSelectionMethodOnChangeAtServer();
					
	Else
		
		Items.ValueWithDocumentBase.TypeRestriction = TypeRestriction;
		Items.ValueWithDocumentBase.ChooseType = TypeRestriction.Types().Count() <> 1;
		Value = TypeRestriction.AdjustValue(Value);
				
	EndIf;	
	
	If TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef() Then
		
		TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords;
		
	EndIf;
	
	If ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.EmptyRef() Then
		
		ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.NotLinked;
		Presentation = GetValueWithDocumentBaseParameterPresentation(Value);
		
	EndIf;	
	
	If DocumentBase <> Undefined Then
		DataCompositionSettingsComposer =  Catalogs.BookkeepingOperationsTemplates.ApplyDocumentBaseTableChange(DocumentBase, TableName, TableKind,DCSInTempStorage);
	EndIf;		
	
	If ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.SystemData Then
		
		FoundField = SystemDataDataCompositionSettingsComposer.Settings.SelectionAvailableFields.FindField(New DataCompositionField(ParameterFormula));
		If FoundField = Undefined Then
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='Field with such nam %P1 is not found in table %P2!';pl='Pole o nazwie %P1 nie znaleziono w tabeli %P2!'"),New Structure("P1, P2",ParameterFormula,TableName)));
		Else	
			ParameterFormulaPresentation = FoundField.Title;
			NeedToSetSelectionAvailableFields = True;		
		EndIf;	
		
	ElsIf ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase Then
		
		If NOT IsBlankString(ParameterFormula) Then
			FoundField = DataCompositionSettingsComposer.Settings.SelectionAvailableFields.FindField(New DataCompositionField(ParameterFormula));
			If FoundField = Undefined Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='Field with such nam %P1 is not found in table %P2!';pl='Pole o nazwie %P1 nie znaleziono w tabeli %P2!'"),New Structure("P1, P2",ParameterFormula,TableName)));
			Else	
				ParameterFormulaPresentation = FoundField.Title;
				NeedToSetSelectionAvailableFields = True;
			EndIf;
		EndIf;
		
	EndIf;	
	
	SetTablePresentation();
	
	If DocumentBase = Undefined Then
		Items.GroupParameterKind.CurrentPage = Items.GroupParameterKindWithoutDocumentBase;
	Else
		Items.GroupParameterKind.CurrentPage = Items.GroupParameterKindWithDocumentBase;
	EndIf;

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	CopyFormData(Object,ThisForm.FormOwner.Object);	
EndProcedure

#EndRegion

#Region StandardCommonCommands

&AtClient
Procedure UpdateDialog()
	
	If DocumentBase = Undefined Then
		PageToSet = Items.GroupParametersKindsNotLinked;
	Else
		PageToSet = Items.GroupParametersKindsNotLinkedWithDocumentBase;
	Endif;
	
	If ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase") Then
		PageToSet = Items.GroupParametersKindsLinkedToDocumentBase;
	ElsIf ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.SystemData") Then
		PageToSet = Items.GroupParametersKindsSystemData;	
	EndIf;	
	
	Items.GroupParametersKindsNotLinked.Visible = Items.GroupParametersKindsNotLinked = PageToSet;
	Items.GroupParametersKindsNotLinkedWithDocumentBase.Visible = Items.GroupParametersKindsNotLinkedWithDocumentBase = PageToSet;
	Items.GroupParametersKindsLinkedToDocumentBase.Visible = Items.GroupParametersKindsLinkedToDocumentBase = PageToSet;
	Items.GroupParametersKindsSystemData.Visible = Items.GroupParametersKindsSystemData = PageToSet;
	Items.GroupParametersKinds.CurrentPage = PageToSet;		
		
EndProcedure

&AtClient
Procedure CommandOK(Command)
	
	If TrimAll(Presentation) = "" Then
		ShowMessageBox( , Nstr("en = 'There is no parameter''s presentation!'; pl = 'Brak przedstawienia parametru!'"));
		
		Return;
	Else               
		If ParameterExist() Then
			ShowMessageBox( , Alerts.ParametrizeString(Nstr("en = 'Parameter with name %P1 already exists in current bookkeeping operation template for table %P2!'; pl = 'Parameter z nazwą %P1 już istnieje w schemacie dla tabeli %P2!'"),New Structure("P1, P2",Presentation,TablePresentation)));
			
			Return;
		EndIf; 
	EndIf;

	If ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.NotLinked") Then
		FieldName = "";
		If DocumentBase = Undefined Then
			If TypeSelectionMethod = 1 Then
				If TrimAll(LinkByType) = "" Then
					ShowMessageBox( , Nstr("en = 'Not specified parameter-account!'; pl = 'Nie został wskazany parametr-konto!'"));

					Return;
				EndIf;
			Else
				If Type = Undefined OR Type.Types().Count() = 0 Then
					ShowMessageBox( , Nstr("en = 'Parameter''s value type is not specified!'; pl = 'Typ wartości parametru nie został wskazany!'"));

					Return;
				EndIf;
			EndIf;
		Else
			
			If Value = Undefined Then
				ShowMessageBox( , Nstr("en = 'Parameter''s value is not specified!'; pl = 'Wartość parametru nie została wskazana!'"));

				Return;
			EndIf;
			
		EndIf;	
		
	ElsIf ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase") Then
		
		FoundFieldDescription = FindFieldAtServer();
		If FoundFieldDescription = Undefined Then
			FieldName = StrReplace(ParameterFormula, ".", "");
		Else
			FieldName = FoundFieldDescription.FieldName;
		EndIf;	

		If IsBlankString(ParameterFormula) Then
			ShowMessageBox( , Nstr("en = 'Field of document base which should be linked with parameter is not specified!'; pl = 'Pole dokumentu podstawy, które ma być powiązane z parametrem nie zostało wskazane!'"));

			Return;
		Else
			If Find(ParameterFormula, ".") = 0 Then
				If FoundFieldDescription = Undefined OR Not FoundFieldDescription.IsDataSetField Then
					ShowMessageBox( , Nstr("en = 'Selected field could not be used in parameter!'; pl = 'Wybrane pole nie może być użyte w parametrze!'"));

					Return;
				EndIf;	
			EndIf;
		EndIf;	
		
		
	ElsIf ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.SystemData") Then	
		
		FoundFieldDescription = FindFieldAtServer();
		If FoundFieldDescription = Undefined Then
			FieldName = StrReplace(ParameterFormula, ".", "");
		Else
			FieldName = FoundFieldDescription.FieldName;
		EndIf;	
		
		If IsBlankString(ParameterFormula) Then
			ShowMessageBox( , Nstr("en = 'Field of system data which should be linked with parameter is not specified!'; pl = 'Pole danych systemowych, które ma być powiązane z parametrem nie zostało wskazane!'"));

			Return;
			
		Else
			If Find(ParameterFormula, ".") = 0 Then
				If FoundFieldDescription = Undefined OR Not FoundFieldDescription.IsDataSetField Then
					ShowMessageBox( , Nstr("en = 'Selected field could not be used in parameter!'; pl = 'Wybrane pole nie może być użyte w parametrze!'"));

					Return;		
				EndIf;			
			EndIf;	
		EndIf;
		
	EndIf;
	
	Close(UdateParametersTable());	
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure TypeOnChange(Item)
	
	TypeOnChangeAtServer();
	LinkByOwner = "";

EndProcedure

&AtServer
Procedure TypeOnChangeAtServer()
	
	If Type = Undefined Then
		Return;
	EndIf;
	
	Value = Type.AdjustValue(Value);
	If Type.Types().Count() = 1 Then

		If Type.ContainsType(Type("Number")) Then
			Items.Value.Format = "ND=" + Type.NumberQualifiers.Digits
			                              + "; NFD=" + Type.NumberQualifiers.FractionDigits;
		EndIf;

	EndIf;
	Items.Value.ChooseType     = Type.Types().Count() > 1;
	Items.Value.TypeRestriction = Type;
		
EndProcedure

&AtClient
Procedure TypeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenForm("Catalog.BookkeepingOperationsTemplates.Form.TypeChoiceFormManaged", New Structure("TypeDescription", PutToTempStorage(Type, New UUID())), ThisForm, , , , New NotifyDescription("TypeChoiceOnClose", ThisForm));
EndProcedure

&AtClient
Procedure TypeChoiceOnClose(Result, AdditionalParameters) Export
	If Result<>Undefined Then
		Type = Result;
		TypeOnChange(Items.Type);
	EndIf;
EndProcedure

&AtClient
Procedure TypeSelectionMethodOnChange(Item)
	TypeSelectionMethodOnChangeAtServer();
EndProcedure

&AtServer
Procedure TypeSelectionMethodOnChangeAtServer()
	
	If TypeSelectionMethod = 0 Then
		Items.LinkByType.Enabled      = False;
		Items.ExtDimensionNumber.Enabled    = False;

		Items.Type.Enabled              = True;
		Items.LinkByOwner.Enabled = True;
		Items.Value.Enabled         = True;

		LinkByType = "";

	ElsIf TypeSelectionMethod = 1 Then
		
		Items.LinkByType.Enabled      = True;
		Items.ExtDimensionNumber.Enabled    = True;

		Items.Type.Enabled              = False;
		Items.LinkByOwner.Enabled = False;
		Items.Value.Enabled         = False;
		
		Type = Undefined;
		LinkByOwner = "";
		Value = Undefined;

		TypesArray = New Array;
		TypesArray.Add(TypeOf(PredefinedValue("ChartOfAccounts.Bookkeeping.EmptyRef")));
		TypeDescription    = New TypeDescription(TypesArray);
		ParametersArray = GetParametersValueListAtServer(TypeDescription).UnloadValues();
		Items.LinkByType.ChoiceList.LoadValues(ParametersArray);

	EndIf;
		
EndProcedure

&AtClient
Procedure TablePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	FormParameters = New Structure;
	FormParameters.Insert("DocumentTableSynonym", DocumentTableSynonym);
	FormParameters.Insert("TableKindFilter", TableKindFilter);
	FormParameters.Insert("TableKind", TableKind);	
	FormParameters.Insert("TableName", TableName);
	FormParameters.Insert("DocumentBase", DocumentBase);
	FormParameters.Insert("GoToCurrentRow", True);	
	FormParameters.Insert("DontAllowToCheckBoxShowOnlyAvailable",True);
	
	OpenForm("Catalog.BookkeepingOperationsTemplates.Form.TableChoiceFormManaged", FormParameters, ThisForm, ThisForm, , , New NotifyDescription("TableChoiceProcessing", ThisForm,));
	
EndProcedure

&AtClient
Procedure TableChoiceProcessing(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		SetDataCompositionSettingsComposer(Result);		
	EndIf;	
	SetTablePresentation();
	
EndProcedure

&AtServer
Procedure SetDataCompositionSettingsComposer(Result)
	TableName = Result.TableName;
	TableKind = Result.TableKind;
	TablePresentation = Result.TableSynonym;
	DataCompositionSettingsComposer =  Catalogs.BookkeepingOperationsTemplates.ApplyDocumentBaseTableChange(DocumentBase, TableName, TableKind,DCSInTempStorage);
EndProcedure

&AtClient
Procedure LinkByOwnerStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	LinkByOwnerList = GetParametersValueListAtServer(GetGetPossibleOwnersTypesAtServer(Type));
	If LinkByOwnerList.FindByValue(Name)<>Undefined Then
		LinkByOwnerList.Delete(LinkByOwnerList.FindByValue(Name));
	EndIf;
	SelectedValue = ThisForm.ChooseFromList(LinkByOwnerList, Item, LinkByOwnerList.FindByValue(LinkByOwner));
	If Not SelectedValue = Undefined Then
		LinkByOwner = SelectedValue.Value;                    
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueClearing(Item, StandardProcessing)
	StandardProcessing = False;
	Value = Type.AdjustValue(Undefined);
EndProcedure

&AtClient
Procedure ParameterKindOnChange(Item)
	UpdateDialog();
	Type = Undefined;
	ParameterFormulaTypeDescription = Undefined;
	ParameterFormula = "";	
	ParameterFormulaPresentation = "";
	SetTablePresentation();

EndProcedure

&AtClient
Procedure DataCompositionSettingsComposerSettingsSelectionSelectionAvailableFieldsOnActivateRow(Item)	
	If NeedToSetSelectionAvailableFields Then
		NeedToSetSelectionAvailableFields = False;
		//Items.DataCompositionSettingsComposerSettingsSelectionSelectionAvailableFields.CurrentRow = DataCompositionSettingsComposer.Settings.SelectionAvailableFields.GetIDByObject(CurrentComposerField);
		CurrentComposerField = DataCompositionSettingsComposer.Settings.SelectionAvailableFields.FindField(New DataCompositionField(ParameterFormula));					
		Item.CurrentRow = DataCompositionSettingsComposer.Settings.SelectionAvailableFields.GetIDByObject(CurrentComposerField);		
	EndIf;
	If ThisForm.CurrentItem=Item Then
		//AvailableFieldSelect(Items.DataCompositionSettingsComposerSettingsSelectionSelectionAvailableFields.CurrentRow, DataCompositionSettingsComposer);				
		AvailableFieldSelect(Item.CurrentRow, DataCompositionSettingsComposer);						
	EndIf; 
EndProcedure

&AtClient
Procedure SystemDataDataCompositionSettingsComposerSettingsSelectionSelectionAvailableFieldsOnActivateRow(Item)
	If NeedToSetSelectionAvailableFields Then
		NeedToSetSelectionAvailableFields = False;
		//Items.SystemDataDataCompositionSettingsComposerSettingsSelectionSelectionAvailableFields.CurrentRow = SystemDataDataCompositionSettingsComposer.Settings.SelectionAvailableFields.FindField(New DataCompositionField(ParameterFormula));
		CurrentComposerField = SystemDataDataCompositionSettingsComposer.Settings.SelectionAvailableFields.FindField(New DataCompositionField(ParameterFormula));					
		Item.CurrentRow = SystemDataDataCompositionSettingsComposer.Settings.SelectionAvailableFields.GetIDByObject(CurrentComposerField);		
	EndIf;			
	
	If ThisForm.CurrentItem=Item Then			
		//AvailableFieldSelect(Items.SystemDataDataCompositionSettingsComposerSettingsSelectionSelectionAvailableFields.CurrentRow, SystemDataDataCompositionSettingsComposer);									
		AvailableFieldSelect(Item.CurrentRow, SystemDataDataCompositionSettingsComposer);							
	EndIf;
EndProcedure

&AtClient
Procedure ParameterKindWithoutDocumentBaseOnChange(Item)
	Type = Undefined;
	ParameterFormulaTypeDescription = Undefined;
	ParameterFormula = "";	
	ParameterFormulaPresentation = "";
	SetTablePresentation();
	UpdateDialog();
EndProcedure

#EndRegion

#Region Other

&AtServer
Procedure SetTablePresentation()
	If ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase Then
		FoundRow = Common.FindTabularPartRow(TableOfTables, New Structure("TableName, TableKind", TableName, TableKind));
		If FoundRow = Undefined Then
			TablePresentation = "";
		Else	
			TablePresentation = FoundRow.TableSynonym;
		EndIf;
	EndIf;	
	
EndProcedure

&AtServer
Function GetNewParameterName()	
	
	MaxParameterNumber = 0;
	For Each Row In Object.Parameters Do
		
		RowName = TrimAll(Row.Name);
	
		Prefix = Mid(RowName,1,1);
		ParameterNumberAsString = Mid(RowName,2);
		
		If Prefix = "P" Then
			
			Try 
				ParameterNumber = Number(ParameterNumberAsString);
			Except
				Continue;
			EndTry;	
			
			If ParameterNumber>MaxParameterNumber Then
				MaxParameterNumber = ParameterNumber;
			EndIf;	
			
		EndIf;	
		
	EndDo;	
	
	Return "P"+String(MaxParameterNumber+1);
	
EndFunction

&AtServer
Function GetValueWithDocumentBaseParameterPresentation(CurrentValue)
	
	If CurrentValue = Undefined Then
		Return Nstr("en = 'Value: Undefined'; pl = 'Wartość: Niezdefiniowany'");
	ElsIf ValueIsNotFilled(CurrentValue) Then
		Return Alerts.ParametrizeString(Nstr("en = 'Value: Empty value of type %P1'; pl = 'Wartość: Pusta wartość typu %P1'"),New Structure("P1",String(TypeOf(Value))));
	Else	
		Return Alerts.ParametrizeString(Nstr("en = 'Value: %P1'; pl = 'Wartość: %P1'"),New Structure("P1",String(Value)));
	EndIf;	
	
EndFunction

&AtClient
Procedure AvailableFieldSelect(CurrentRow, CurrentSettingsComposer)
	CurrentField = CurrentSettingsComposer.Settings.Selection.SelectionAvailableFields.GetObjectByID(CurrentRow);	
	
	If CurrentField <> Undefined Then
		ParameterFormulaPresentation = CurrentField.Title;
		ParameterFormula = String(CurrentField.Field);
		ParameterFormulaTypeDescription = CurrentField.Type;
		Presentation = ParameterFormulaPresentation;
	EndIf;	
			
EndProcedure

&AtServer
Function FindFieldAtServer()
	If ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase") Then
		FoundField = GetFromTempStorage(DCSInTempStorage).DataSets.DataSet1.Fields.Find(ParameterFormula);		
		If FoundField <> Undefined Then
			Return New Structure("FieldName, IsDataSetField", FoundField.Field, TypeOf(FoundField) = Type("DataCompositionSchemaDataSetField"));
		EndIf;
	ElsIf ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.SystemData") Then
		FoundField = GetFromTempStorage(SystemDataSchemaInTempStorage).DataSets.SystemData.Fields.Find(ParameterFormula);
		If FoundField <> Undefined Then
			Return New Structure("FieldName, IsDataSetField", FoundField.Field, TypeOf(FoundField) = Type("DataCompositionSchemaDataSetField"));
		EndIf; 
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Function GetParametersValueListAtServer(CurTypeDescription)
	Return 	Catalogs.BookkeepingOperationsTemplates.GetParametersValueList(CurTypeDescription,TableKind, TableName, Object.Parameters.Unload());	
EndFunction

&AtServer
Function GetGetPossibleOwnersTypesAtServer(CurTypeDescription)
	Return 	Catalogs.BookkeepingOperationsTemplates.GetPossibleOwnersTypes(CurTypeDescription);	
EndFunction

&AtServer
Function ParameterExist()
	ObjectParameters = Object.Parameters.Unload();
	FoundRows = ObjectParameters.FindRows(New Structure("TableName, TableKind, Presentation", TableName, TableKind, Presentation));
	If FoundRows.Count() > 1
		OR (FoundRows.Count() = 1 AND IsNew) Then			
		Return True;
	Else
		Return False
	EndIf;	
EndFunction	

&AtServer
Function UdateParametersTable()
	FoundRows = Object.Parameters.FindRows(New Structure("TableName, TableKind, Presentation", TableName, TableKind, Presentation));
	
	If IsNew Then
		CurrentParameter = Object.Parameters.Add();		
		CurrentParameter.Name = GetNewParameterName();
	ElsIf LineNumber>0 Then
		FoundRows = Object.Parameters.FindRows(New Structure("LineNumber", LineNumber));		
		CurrentParameter = FoundRows[0];		
	Else
	    Return Undefined;
	EndIf;

	CurrentParameter.ParameterKind = ParameterKind;
	CurrentParameter.ParameterFormula = ParameterFormula;
	If ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.NotLinked") Then
		If DocumentBase = Undefined Then
			CurrentParameter.TypeStringInternal = ValueToStringInternal(Type);
		Else	
			TempArray = New Array();
			TempArray.Add(TypeOf(Value));
			CurrentParameter.TypeStringInternal = ValueToStringInternal(New TypeDescription(TempArray));
		EndIf;	
	Else	
		CurrentParameter.TypeStringInternal = ValueToStringInternal(ParameterFormulaTypeDescription);		
	EndIf;
	CurrentParameter.Presentation    = Presentation;
	CurrentParameter.Value         = Value;
	CurrentParameter.NotRequest    = NotRequest;
	CurrentParameter.LinkByOwner = LinkByOwner;
	CurrentParameter.LinkByType      = LinkByType;
	CurrentParameter.TableName = TableName;
	CurrentParameter.TableKind = TableKind;
	CurrentParameter.FieldName = FieldName;

	If Not IsBlankString(LinkByType) Then
		CurrentParameter.ExtDimensionNumber = ?(ExtDimensionNumber=0, 1, ExtDimensionNumber);
	Else
		CurrentParameter.ExtDimensionNumber = 0;
	EndIf;

	CurrentParameter.LongDescription        = LongDescription;
	CurrentParameter.Obligatory     = Obligatory;
	Return New Structure("Name",CurrentParameter.Name)
EndFunction	

#EndRegion
