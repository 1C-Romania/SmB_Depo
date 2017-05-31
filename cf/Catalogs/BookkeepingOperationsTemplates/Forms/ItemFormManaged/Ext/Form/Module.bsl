&AtServer
Var FillingMethods;

#Region BaseFormProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	CatalogObject = FormDataToValue(Object, Type("CatalogObject.BookkeepingOperationsTemplates"));
	CatalogObject.UpdateStringInternalFromType();
	CatalogObject.UpdateFilterAsXML();
	ValueToFormData(CatalogObject, Object);
	
	
	FillingMethods = New Array;
	FillingMethods.Add(Nstr("en='Fills by value';pl='Wypełnia się wartością'")); 
	FillingMethods.Add(Nstr("en='Fills by parameters value';pl='Wypełnia się wartością parametru'"));
	FillingMethods.Add(Nstr("en='Evaluated by formula expression';pl='Wylicza się zgodnie ze wzorem'"));

	If Object.Ref.IsEmpty() Then
		
		Object.Type = Enums.BookkeepingOperationTemplateTypes.Normal;
		Object.Author = SessionParameters.CurrentUser;
		Object.AlgorithmType = Enums.BookkeepingOperationTemplateAlgorithmTypes.None;
		
	Else
		
		Items.Pages.CurrentPage = Items.GroupRecords;
		ReadOnly = Object.WorkMode;
		DocumentBasePresentation = ?(Object.DocumentBase = Undefined, "", Object.DocumentBase.Metadata().Synonym);
	EndIf;
	
	InitializeAllSelectedTables();
	
	OnRowOutputInTableBox(True);	

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	Items.Records.RowFilter = New FixedStructure("HideRow",False);	
	Items.SalesVATRecords.RowFilter = New FixedStructure("HideRow",False);
	Items.PurchaseVATRecords.RowFilter = New FixedStructure("HideRow",False);		
	
	ItemsStructure = GetCurrentItemsForPage();
	
	UpdateDialog();
	UpdateModeLabel();
	DocumentsFormAtClient.ExpandTreeRows(Items.SelectedTables,SelectedTables);
	DocumentsFormAtClient.ExpandTreeRows(Items.SelectedPurchaseVATTables,SelectedPurchaseVATTables);
	DocumentsFormAtClient.ExpandTreeRows(Items.SelectedSalesVATTables,SelectedSalesVATTables);
	RestoreFillingMethodsAndValues();
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)

	// Checking of correct parameter's settings
	Checking = New Structure();
	For each Param In Object.Parameters Do
		
		If TrimAll(Param.Presentation) = "" Then
			ShowMessageBox( , Nstr("en = 'There is no presentation for one of parameters.
			|Item was not written!'; pl = 'Brak przedstawienia dla jednego z parametrów.
			|Element nie został zapisany!'"), 6);
			Cancel = True;
			Return;
		EndIf;
		
		Try
			Checking.Insert(Param.Name, Param.Value);
		Except
			ShowMessageBox( , Alerts.ParametrizeString(Nstr("en = 'There is incorrect Name for parameter %P1.
			|Item was not written!'; pl = 'Niepoprawna nazwa parametru %P1.
			|Element nie został zapisany!'"), New Structure("P1", Param.Name)), 6);
			Cancel = True;
			Return;
		EndTry;
		
	EndDo;
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	RestoreFillingMethodsAndValues();
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	Try
		RestoreFillingMethodsAndValues();	
	Except
		//if form does not exist
	EndTry;

EndProcedure

#EndRegion

#Region StandardCommonCommands

&AtClient
Procedure ExportTemplate(Command)
	SaveTemplateAsFile();
EndProcedure

&AtClient
Procedure ImportTemplate(Command)
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	
	FileDialog.Filter  = Nstr("en='XML files';pl='Pliki XML'")+"(*.xml)|*.xml";
	FileDialog.Title   = Nstr("en='Import bookkeeping operation template';pl='Importuj schemat księgowania'");
	FileDialog.Preview = False;
	FileDialog.DefaultExt = "XML";
	
	XMLFileName = "";
	If FileDialog.Choose() Then
		XMLFileName = FileDialog.FullFileName;
	Else
		Return;
	EndIf;
	
	If Not IsBlankString(XMLFileName) Then
		TextDocument = New TextDocument;
		TextDocument.Read(XMLFileName, TextEncoding.UTF8);
		HeaderStructure = New Structure("Code,Author,Parent,Owner");
		FillPropertyValues(HeaderStructure,Object);
		
		Try

			GetNewBookkeepingTemplate(TextDocument);			
			
		Except
			ShowMessageBox( , Nstr("en = 'Choosen file is corrupted or has incompatible format!
                       |Could not load data!'; pl = 'Wybrany plik jest uszkodzony lub ma niezgodny format!
                       |Nie można zaimportować dane!'"));
			Return;
		EndTry;
		
		
		//Object Header
		FillPropertyValues(Object, HeaderStructure);
		
		// Tabular parts
		InitializeAllSelectedTables();
		
		OnRowOutputInTableBox();		
		UpdateDialog();
		UpdateModeLabel();
		ThisForm.Modified = True;
	Else
		ShowMessageBox( , Nstr("en = 'Choosen file does not exist!'; pl = 'Wybrany plik nie istnieje!'"));
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportTemplateTabularPartsAtServer(NewBookkeepingTemplate)
	For Each TabularPart In Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections Do
		Object[TabularPart.Name].Clear();
		For Each Row In NewBookkeepingTemplate[TabularPart.Name] Do
			NewRow = Object[TabularPart.Name].Add();
			FillPropertyValues(NewRow, Row);
		EndDo;	
	EndDo;
EndProcedure

&AtClient
Procedure UpdateDialog(UpdateFilterOnTables=True,UpdateAdditionalItems=True)
	If UpdateFilterOnTables Then
		SetFilterOnTable(Items.SelectedTables, Items.Records);
		SetFilterOnTable(Items.SelectedSalesVATTables, Items.SalesVATRecords);
		SetFilterOnTable(Items.SelectedPurchaseVATTables, Items.PurchaseVATRecords);
	EndIf;
	
	Items.SelectedTables.ChangeRowSet = Not ReadOnly;
	Items.SelectedPurchaseVATTables.ChangeRowSet = Not ReadOnly;
	Items.SelectedSalesVATTables.ChangeRowSet = Not ReadOnly;	
	
	Items.SelectedTables.Visible = (Object.DocumentBase <> Undefined);
	Items.SelectedPurchaseVATTables.Visible = (Object.DocumentBase <> Undefined);
	Items.SelectedSalesVATTables.Visible = (Object.DocumentBase <> Undefined);	
	
	DocumentsFormAtClient.ShowHideColumns(Object.DocumentBase = Undefined, New Structure("Obligatory, NotRequest", Items.ParametersObligatory, Items.ParametersNotRequest));
	
	UpdateViewOnFillingMethod();
	
	If UpdateAdditionalItems Then
		If Object.DocumentBase <> Undefined Then
			SetFilterDescription();
		Else
			FilterDescription = "";
		EndIf;			
		// Manage block button caption
		ChangeSetBlockedMarkTitleAtServer();
		Items.AlgorithmText.Enabled = (Object.AlgorithmType <> PredefinedValue("Enum.BookkeepingOperationTemplateAlgorithmTypes.None") AND Object.AlgorithmType <> PredefinedValue("Enum.BookkeepingOperationTemplateAlgorithmTypes.EmptyRef"));
		
		If Object.AlgorithmType.IsEmpty() Then
			Items.GroupLabelInformation.CurrentPage = Items["GroupNone"];
		Else
			Items.GroupLabelInformation.CurrentPage = Items["Group" + CommonAtServer.GetEnumNameByValue(Object.AlgorithmType)];
		EndIf;	
		
		Items.AutoDifferenceCompensationAmount.Enabled = Object.AutoDifferenceCompensation;
		
		Items.DocumentBasePresentation.Enabled = Not ReadOnly;
		Items.FilterDescription.Enabled = Not ReadOnly;		
	EndIf;
	
	//Not implemented in managed forms
	//EnabledFlag = Undefined;
	//
	//If Object.Type = PredefinedValue("Enum.BookkeepingOperationTemplateTypes.Normal") Then
	//	EnabledFlag = False;	
	//ElsIf Object.Type = PredefinedValue("Enum.BookkeepingOperationTemplateTypes.AsDataProcessor") Then		
	//	EnabledFlag = True;		
	//EndIf;	
	
EndProcedure

&AtClient
Procedure WorkMode(Command)
	
	Object.WorkMode = Not Object.WorkMode;
	
	Try
		Written = Write();
	Except
		Written = False;
	EndTry;
		
	If Written Then
		ReadOnly = Object.WorkMode;
		UpdateModeLabel();
	Else
		Object.WorkMode = Not Object.WorkMode;
	EndIf;
	UpdateDialog()
EndProcedure

&AtClient
Procedure SetBlockedMark(Command)
	If Not DialogsAtClient.WriteObjectInForm(ThisForm,Undefined,Nstr("en = 'Saving bookkeeping operations template'; pl = 'Zapis schematu księgowania'")) Then
		Return;
	EndIf;
	
	SetBlockedMarkAtServer();
	
	UpdateDialog();
EndProcedure

&AtServer
Procedure SetBlockedMarkAtServer()
	
	RecordManager = InformationRegisters.BlockedBookkeepingOperationTemplates.CreateRecordManager();
	RecordManager.Template = Object.Ref;
	RecordManager.Read();
	If RecordManager.Selected() Then
		RecordManager.Delete();
	Else
		RecordManager.Template = Object.Ref;
		RecordManager.Write();
	EndIf;
	
EndProcedure

&AtClient
Procedure AddOperation(Command)
	GenerateOrEmulateNewOperation(False);
EndProcedure

&AtClient
Procedure EmulateOperation(Command)
	GenerateOrEmulateNewOperation(True);
EndProcedure

&AtClient
Procedure NewParameter(Command)
	DocumentsFormAtClient.CreateNewParameter(ThisForm,ThisForm,ItemsStructure.CurrentRecords,ItemsStructure);
EndProcedure

&AtClient
Procedure NewParameterOnCloseResult(Result, AdditionalParameters) Export
	If Result <> Undefined  And Not IsBlankString(Result.Name) Then
		If AdditionalParameters <> Undefined Then
			SetFieldValueOnChange(Items[AdditionalParameters.CurrentRecords], PredefinedValue("Enum.FieldFillingMethods.Parameter"), Undefined, Result.Name, True);		
		EndIf;	
		RestoreFillingMethodsAndValues();			
	EndIf;
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure DocumentBasePresentationOnChange(SelectedItem, Parameters) Export 
	
	If SelectedItem <> Undefined Then
		Object.DocumentBase = SelectedItem.Value;
		DocumentBasePresentation = SelectedItem.Presentation;
		DocumentBaseChange();
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentBasePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	ShowChooseFromList(New NotifyDescription("DocumentBasePresentationOnChange", ThisForm), GetListOfDocumentTypes(), Item);
EndProcedure

&AtClient
Procedure DocumentBasePresentationClearing(Item, StandardProcessing)
	Object.DocumentBase = Undefined;
	DocumentBaseChange();

EndProcedure

&AtClient
Procedure DocumentBaseChange()
	Object.FilterAsXML = "";
	OnRowOutputInTableBox();
	
	ChangeAvailablesOfTablesOfDocumentBaseChange();
	Modified=True;	
	UpdateDialog();
	
	DocumentsFormAtClient.ExpandTreeRows(Items.SelectedTables,SelectedTables);
	DocumentsFormAtClient.ExpandTreeRows(Items.SelectedPurchaseVATTables,SelectedPurchaseVATTables);
	DocumentsFormAtClient.ExpandTreeRows(Items.SelectedSalesVATTables,SelectedSalesVATTables);	
EndProcedure

&AtClient
Procedure FilterDescriptionClick(Item, StandardProcessing)
	StandardProcessing = False;
	OpenForm("Catalog.BookkeepingOperationsTemplates.Form.DocumentFilterSettingsManaged", , ThisForm, , , , New NotifyDescription("FilterChangeOnClose", ThisForm));
EndProcedure

&AtClient
Procedure FilterChangeOnClose(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		If Result.IsChanged Then
			Object.FilterAsXML = Result.FilterAsXML;
			Modified=True;
		EndIf;
	EndIf;
	
	UpdateDialog();
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)   
	ItemsStructure = GetCurrentItemsForPage();		
	TableBoxName = StrReplace(CurrentPage.Name,"Group","");
	If TableBoxName = "Records" or TableBoxName = "PurchaseVATRecords" or TableBoxName = "ExchangeRateDifferences" or TableBoxName = "SalesVATRecords" Then
		SetRecordsCurrentItemToLineNumber(TableBoxName)		
	EndIf;
	UpdateViewOnFillingMethod();

EndProcedure

&AtClient
Procedure AutoDifferenceCompensationOnChange(Item)
	If NOT Object.AutoDifferenceCompensation Then
		Object.AutoDifferenceCompensationAmount = 0;
	EndIf;
	
	UpdateDialog();
EndProcedure

&AtClient
Procedure FillingMethodOnChange(Item)
	FormulaStructure = GetFormulaStructure(Items[ItemsStructure.CurrentRecords]);
	
	If FormulaStructure.FillingMethod <> FillingMethod Then
		Formula = "";
		FormulaPresentation = "";
		SetFieldValueOnChange(Items[ItemsStructure.CurrentRecords], FillingMethod, Undefined, Formula, True);
		
		UpdateViewOnFillingMethod();
		
		RestoreFillingMethodsAndValues();	
		Modified = True;		
	EndIf;	
EndProcedure

&AtClient
Procedure AnyRecordsFormulaStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormulaStructure = GetFormulaStructure(Items[ItemsStructure.CurrentRecords]);

	If Items[ItemsStructure.CurrentRecords].CurrentData = Undefined
		OR Not CommonAtServer.IsDocumentTabularPartAttribute("TableName", Object.Ref, ItemsStructure.CurrentRecords)
		OR Not CommonAtServer.IsDocumentTabularPartAttribute("TableKind", Object.Ref, ItemsStructure.CurrentRecords) Then
		TableName = "";
		TableKind = PredefinedValue("Enum.BookkeepingOperationTemplateTableKind.EmptyRef");
	Else
		TableName = Items[ItemsStructure.CurrentRecords].CurrentData.TableName;
		TableKind = Items[ItemsStructure.CurrentRecords].CurrentData.TableKind;
	EndIf;
	DocumentsFormAtClient.EditFormula(ThisForm, FillingMethod, TableKind, TableName, Items[ItemsStructure.CurrentRecords].Name, FormulaStructure.TypeRestriction);	
EndProcedure

&AtClient
Procedure AnyRecordsFormulaClearing(Item, StandardProcessing)
	FormulaStructure = GetFormulaStructure(Items[ItemsStructure.CurrentRecords]);
	SetFieldValueOnChange(Items[ItemsStructure.CurrentRecords],FormulaStructure.FillingMethod,Undefined,"",True);
	
	RestoreFillingMethodsAndValues();		
	Modified = True;	
EndProcedure

&AtClient
Procedure AnyValueOnChange(Item)
	SetFieldValueOnChange(Items[ItemsStructure.CurrentRecords], FillingMethod, Value, Formula);
	
	RestoreFillingMethodsAndValues();			
	Modified = True;
	
EndProcedure

&AtClient
Procedure AnyRecordsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	If ThisForm[Item.Name+"ChangeRowSet"] Then
		CurrentSelectedTablesControl = Undefined;	
		RecordsTableName = Item.Name;
		If RecordsTableName = "Records" Then
			CurrentSelectedTablesControl = Items.SelectedTables;
		ElsIf RecordsTableName = "PurchaseVATRecords"  Then
			CurrentSelectedTablesControl = Items.SelectedPurchaseVATTables;
		ElsIf RecordsTableName = "SalesVATRecords" Then		
			CurrentSelectedTablesControl = Items.SelectedSalesVATTables;
		EndIf;
		If CurrentSelectedTablesControl <> Undefined Then
			CurrentTable = CurrentSelectedTablesControl.CurrentData;
			If Object.DocumentBase = Undefined Then
				TableName = "";
				TableKind = PredefinedValue("Enum.BookkeepingOperationTemplateTableKind.DocumentRecords");	
			Else	
				TableName = CurrentTable.TableName;
				TableKind = CurrentTable.TableKind;	
			EndIf;
					
			AnyRecordsBeforeAddRowAtServer(RecordsTableName, TableName, TableKind);
			Modified = True;
		EndIf;		
	EndIf;	
EndProcedure

&AtServer
Procedure AnyRecordsBeforeAddRowAtServer(RecordsTableName, TableName, TableKind)
	CurrentData = Object[RecordsTableName].Add();
	CurrentData.TableName = TableName;
	CurrentData.TableKind = TableKind;	
	SetRowAvailability(CurrentData, RecordsTableName);
EndProcedure

&AtClient
Procedure AnyRecordsBeforeDeleteRow(Item, Cancel)
	If NOT ThisForm[Item.Name+"ChangeRowSet"] Then
		Cancel = True;
	EndIf;	
EndProcedure

&AtClient
Procedure OnSelectionInTableBox(TableBox)
	
	If ReadOnly Or TableBox.ReadOnly Then
		Return;
	EndIf;
	CurrentColumnName = GetObjectFieldName(TableBox.CurrentItem.Name);						
	If CurrentColumnName = "Condition" Then

		FormulaStructure = GetFormulaStructure(TableBox);
		If Items[ItemsStructure.CurrentRecords].CurrentData = Undefined Then
			TableName = "";
			TableKind = PredefinedValue("Enum.BookkeepingOperationTemplateTableKind.EmptyRef");
		Else
			TableName = Items[ItemsStructure.CurrentRecords].CurrentData.TableName;
			TableKind = Items[ItemsStructure.CurrentRecords].CurrentData.TableKind;
		EndIf;
		DocumentsFormAtClient.EditFormula(ThisForm, FillingMethod, TableKind, TableName, Items[ItemsStructure.CurrentRecords].Name, FormulaStructure.TypeRestriction);	

	ElsIf CurrentColumnName = "LineNumber"
		OR CurrentColumnName = "UseInExchangeRateDifferenceCalculation"
		OR CurrentColumnName = "Type"
		OR CurrentColumnName = "ExchangeRateDifferencesCarriedOut" Then
		// Do nothing
	Else
		
		If IsExtDimensionControlAvailable(TableBox, , CurrentColumnName) Then
			
			FormulaStructure = GetFormulaStructure(TableBox);
			
			FormParameters = New Structure;
			FormParameters.Insert("FillingMethod", FormulaStructure.FillingMethod);
			
			If FormulaStructure.FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value") Then
				FormParameters.Insert("Value", FormulaStructure.Value);
			Else
				FormParameters.Insert("Formula", FormulaStructure.Value);
			EndIf;
			
			FormParameters.Insert("TypeRestriction", FormulaStructure.TypeRestriction);
			FormParameters.Insert("DocumentBase", Object.DocumentBase);
			
			If TableBox.CurrentData = Undefined
				OR Items[TableBox.Name].ChildItems.Find(TableBox.Name + "TableName") = Undefined         
				OR Items[TableBox.Name].ChildItems.Find(TableBox.Name + "TableKind") = Undefined Then
				FormParameters.Insert("TableName", "");
				FormParameters.Insert("TableKind", PredefinedValue("Enum.BookkeepingOperationTemplateTableKind.EmptyRef"));
			Else
				FormParameters.Insert("TableName", TableBox.CurrentData.TableName);
				FormParameters.Insert("TableKind", TableBox.CurrentData.TableKind);
			EndIf;
			
			FormParameters.Insert("TableBoxName", TableBox.Name);
			OpenForm("Catalog.BookkeepingOperationsTemplates.Form.ParameterWizardManaged", FormParameters, ThisForm, , , , New NotifyDescription("ParameterWizardOnClose", ThisForm,));
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Function OnActivateCellInTableBox(TableBox)
	CurRow  = TableBox.CurrentData;

	If CurRow = Undefined Then
		Return "";
	EndIf;
	
	//ColumnName = GetObjectFieldName(TableBox.CurrentItem.Name); //optimisation		
	ColumnName = Right(TableBox.CurrentItem.Name,StrLen(TableBox.CurrentItem.Name)-StrLen(TableBox.Name));		
	If ColumnName = "Condition" Then
		
		FormulaStructure = GetFormulaStructure(TableBox, CurRow, ColumnName);
		
		Items[ItemsStructure.CurrentFillingMethod].Enabled  = True;
		Items[ItemsStructure.CurrentFormulaPresentation].Enabled = True;
		Items[ItemsStructure.CurrentValue].Enabled = True;
		Items[ItemsStructure.CurrentValue].TypeRestriction = FormulaStructure.TypeRestriction;
		Items[ItemsStructure.CurrentValue].ChooseType = Items[ItemsStructure.CurrentValue].TypeRestriction.Types().Count() <> 1;
		Items[ItemsStructure.CurrentButtonNewParameter].Enabled = True;
		
		FillingMethod = FormulaStructure.FillingMethod;
		Formula = FormulaStructure.Value;
		FormulaPresentation = GetFormulaPresentationAtServer(FormulaStructure, TableBox.Name); 		
		Value = Items[ItemsStructure.CurrentValue].TypeRestriction.AdjustValue(FormulaStructure.Value);
	
	ElsIf ColumnName <> "LineNumber"
		AND ColumnName <> "ExchangeRateDifferencesCarriedOut"
		AND ColumnName <> "Type"
		AND ColumnName <> "UseInExchangeRateDifferenceCalculation" Then

		If IsExtDimensionControlAvailable(TableBox, , ColumnName) Then
			
			FormulaStructure = GetFormulaStructure(TableBox, CurRow, ColumnName);
			
			Items[ItemsStructure.CurrentFillingMethod].Enabled  = True;
			Items[ItemsStructure.CurrentFormulaPresentation].Enabled = True;
			Items[ItemsStructure.CurrentValue].Enabled = True;
			Items[ItemsStructure.CurrentValue].TypeRestriction = FormulaStructure.TypeRestriction;
			Items[ItemsStructure.CurrentValue].ChooseType = Items[ItemsStructure.CurrentValue].TypeRestriction.Types().Count() <> 1;
			Items[ItemsStructure.CurrentButtonNewParameter].Enabled = True;
			
			FillingMethod = FormulaStructure.FillingMethod;
			Formula = FormulaStructure.Value;
			FormulaPresentation = GetFormulaPresentationAtServer(FormulaStructure, TableBox.Name);
			Value = Items[ItemsStructure.CurrentValue].TypeRestriction.AdjustValue(FormulaStructure.Value);
			
		Else
			
			DisableAllControlsForFieldEditing(ItemsStructure);
			
		EndIf;
	Else
		
		DisableAllControlsForFieldEditing(ItemsStructure);
		
	EndIf;
	
	UpdateDialog(False,False);
	
	Return FillingMethod;
	
EndFunction

#EndRegion

#Region SelectedTablesEvents

&AtClient
Procedure SelectedTablesOnActivateRow(Item)
	If ThisForm.CurrentItem = Item Then		
		SetRecordsCurrentItemToLineNumber("Records");						
		UpdateDialog(,False);
	EndIf;	
EndProcedure

&AtClient
Procedure SelectedTablesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	AddTableAction(Item, SelectedTables, "SelectedTables");
EndProcedure

&AtClient
Procedure SelectedTablesBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	BeforeDeleteTableAction(Item.CurrentData, "Records");
EndProcedure

#EndRegion

#Region RecordsEvents
&AtClient
Procedure RecordsOnActivateCell(Item)
	If ThisForm.CurrentItem = Item Then			
		OnActivateCellInTableBox(Item);
	EndIf;
EndProcedure

&AtClient
Procedure RecordsSelection(Item, SelectedRow, Field, StandardProcessing)
	If ThisForm.CurrentItem = Item Then				
		OnSelectionInTableBox(Item);
	EndIF;
EndProcedure

#EndRegion

#Region SelectedPurchaseVATTablesEvents

&AtClient
Procedure SelectedPurchaseVATTablesOnActivateRow(Item)
	If ThisForm.CurrentItem = Item Then	
		SetRecordsCurrentItemToLineNumber("PurchaseVATRecords");				
		UpdateDialog();
	EndIf;	
EndProcedure

&AtClient
Procedure SelectedPurchaseVATTablesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	AddTableAction(Item, SelectedPurchaseVATTables, "SelectedPurchaseVATTables");
EndProcedure

&AtClient
Procedure SelectedPurchaseVATTablesBeforeDeleteRow(Item, Cancel)
	Cancel = True;	
	BeforeDeleteTableAction(Item.CurrentData, "PurchaseVATRecords");
EndProcedure

#EndRegion

#Region PurchaseVATEvents

&AtClient
Procedure PurchaseVATRecordsOnActivateCell(Item)
	If ThisForm.CurrentItem = Item Then			
		OnActivateCellInTableBox(Item);
	EndIf;
EndProcedure

&AtClient
Procedure PurchaseVATRecordsSelection(Item, SelectedRow, Field, StandardProcessing)
	If ThisForm.CurrentItem = Item Then			
		OnSelectionInTableBox(Item);
	EndIf;	
EndProcedure

#EndRegion

#Region SelectedSalesVATTablesEvents

&AtClient
Procedure SelectedSalesVATTablesOnActivateRow(Item)
	If ThisForm.CurrentItem = Item Then	
		SetRecordsCurrentItemToLineNumber("SalesVATRecords");		
		UpdateDialog();
	EndIf;	
EndProcedure

&AtClient
Procedure SelectedSalesVATTablesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	AddTableAction(Item, SelectedSalesVATTables, "SelectedSalesVATTables");
EndProcedure

&AtClient
Procedure SelectedSalesVATTablesBeforeDeleteRow(Item, Cancel)
	Cancel = True;	
	BeforeDeleteTableAction(Item.CurrentData, "SalesVATRecords");
EndProcedure

#EndRegion

#Region SalesVATEvents
&AtClient
Procedure SalesVATRecordsOnActivateCell(Item)
	If ThisForm.CurrentItem = Item Then			
		OnActivateCellInTableBox(Item);
	EndIf;
EndProcedure

&AtClient
Procedure SalesVATRecordsSelection(Item, SelectedRow, Field, StandardProcessing)
	If ThisForm.CurrentItem = Item Then			
		OnSelectionInTableBox(Item);
	EndIf;	
EndProcedure

#EndRegion

#Region ExchangeRateDifferencesEvents

&AtClient
Procedure ExchangeRateDifferencesSelection(Item, SelectedRow, Field, StandardProcessing)
	CurrentData = Item.CurrentData;	
	If Field.Name = "ExchangeRateDifferencesExchangeRateDifferencesCarriedOut" Then
		StandardProcessing = False;
		If CurrentData.Type = PredefinedValue("Enum.BookkeepingOperationBalanceDifferenceTypes.ExchangeRateDifference") Then
			CurrentData.ExchangeRateDifferencesCarriedOut = Not CurrentData.ExchangeRateDifferencesCarriedOut;
			ThisForm.Modified = True;
		EndIf;
		Return;
	ElsIf Not Field.Name = "ExchangeRateDifferencesType"  Then
		StandardProcessing = False;
		OnSelectionInTableBox(Item);		
	EndIf;	
EndProcedure

&AtClient
Procedure ExchangeRateDifferencesOnActivateCell(Item)
	If ThisForm.CurrentItem = Item Then
		OnActivateCellInTableBox(Item);
	EndIf;	
EndProcedure

&AtClient
Procedure ExchangeRateDifferencesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	ExchangeRateDifferencesBeforeAddRowAtServer(Cancel);	
EndProcedure

&AtServer
Procedure ExchangeRateDifferencesBeforeAddRowAtServer(Cancel)
	ExchangeRateDifferenceRow = Undefined;
	GeneralRoundingDifferenceRow = Undefined;
	For Each TableItem In Object.ExchangeRateDifferences Do
		
		If TableItem.Type = Enums.BookkeepingOperationBalanceDifferenceTypes.ExchangeRateDifference Then	
			ExchangeRateDifferenceRow = TableItem;
		ElsIf TableItem.Type = Enums.BookkeepingOperationBalanceDifferenceTypes.GeneralRoundingDifference Then	
			GeneralRoundingDifferenceRow = TableItem;
		EndIf;	
		
	EndDo;	
	
	ExchangeRateDifferencesCount = Object.ExchangeRateDifferences.Count();
	If ExchangeRateDifferencesCount >= 2 OR (ExchangeRateDifferencesCount = 2 AND (ExchangeRateDifferenceRow = Undefined OR GeneralRoundingDifferenceRow = Undefined)) Then
		
		Message(Nstr("en = 'Only one record for each type can be in tabulart part of exchange rate differences!'; pl = 'Tylko po jednym wierszu dla każdego typu może znajdować się w części tabelarycznej różnic kursowych!'"));
		Cancel = True;
		
	EndIf;	
EndProcedure

&AtClient
Procedure ExchangeRateDifferencesTypeOnChange(Item)
	ExchangeRateDifferencesTypeOnChangeAtServer(Items.ExchangeRateDifferences.CurrentData.GetID());
EndProcedure

&AtServer
Procedure ExchangeRateDifferencesTypeOnChangeAtServer(CurrentRowID)
	CurrentRow = Object.ExchangeRateDifferences.FindByID(CurrentRowID);
	
	If Object.ExchangeRateDifferences.Count() = 2 Then
		If Object.ExchangeRateDifferences[0].Type = Object.ExchangeRateDifferences[1].Type AND ValueIsFilled(Object.ExchangeRateDifferences[0].Type) Then
			If CurrentRow.Type = Enums.BookkeepingOperationBalanceDifferenceTypes.ExchangeRateDifference Then
				CurrentRow.Type = Enums.BookkeepingOperationBalanceDifferenceTypes.GeneralRoundingDifference;
			ElsIf CurrentRow.Type = Enums.BookkeepingOperationBalanceDifferenceTypes.GeneralRoundingDifference Then
				CurrentRow.Type = Enums.BookkeepingOperationBalanceDifferenceTypes.ExchangeRateDifference;
			EndIf;	
		EndIf;	
	EndIf;
	If CurrentRow.Type = Enums.BookkeepingOperationBalanceDifferenceTypes.GeneralRoundingDifference Then
		CurrentRow.ExchangeRateDifferencesCarriedOut = False;
	EndIf;
EndProcedure

#EndRegion

#Region ParametersEvents

&AtClient
Procedure ParametersBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;

	FormParameters = New Structure;	
	If Clone Then
		FormParameters = DocumentsFormAtServer.GetParameterStructure(Object,Items.Parameters.CurrentData.GetID());
	EndIf;
	FormParameters.Insert("DocumentBase", Object.DocumentBase);	
	FormParameters.Insert("IsNew",True);	
	OpenForm("Catalog.BookkeepingOperationsTemplates.Form.ParameterManaged", FormParameters, ThisForm, ThisForm.UUID, , , New NotifyDescription("ParameterRowChangeOnClose", ThisForm, Undefined));			
EndProcedure

&AtClient
Procedure ParametersBeforeRowChange(Item, Cancel)
	Cancel = True;
	CurrentColumnName = Items.Parameters.CurrentItem.Name;
	CurrentParameter = Items.Parameters.CurrentData;

	If CurrentColumnName = "ParametersObligatory" Then
		CurrentParameter.Obligatory = Not CurrentParameter.Obligatory;
		ThisForm.Modified = True;
		Return;
	ElsIf CurrentColumnName = "ParametersNotRequest" Then
		CurrentParameter.NotRequest = Not CurrentParameter.NotRequest;
		ThisForm.Modified = True;		
		Return;
	EndIf;
	
	If CurrentParameter.Name = Undefined 
		Or IsBlankString(CurrentParameter.Name) Then
		Return;
	EndIf;	
	
	FormParameters = DocumentsFormAtServer.GetParameterStructure(Object,CurrentParameter.GetID());	
	OpenForm("Catalog.BookkeepingOperationsTemplates.Form.ParameterManaged", FormParameters, ThisForm, ThisForm.UUID, , , New NotifyDescription("ParameterRowChangeOnClose", ThisForm, Undefined));			
EndProcedure

&AtClient
Procedure ParameterRowChangeOnClose(Result, AdditionalParameters) Export
	If Result<>Undefined Then
		ThisForm.Modified = True;
		SetParametersAppearanceAtServer();
	EndIf;
EndProcedure

&AtClient
Procedure ParametersBeforeDeleteRow(Item, Cancel)
	Array = CheckParameterBeforeDeleteRowAtServer(Items.Parameters.CurrentData.Name);	
	If Array.Count() > 0 Then

		Cancel = True;
		Str   = Nstr("en = 'Parameter could not be removed, because it used in formulas:'; pl = 'Parametr nie może być usunięty dlatego że jest używany we wzórach:'");

		Message(Str);

		For each ArrayItem In Array Do
			Message(Chars.Tab + ArrayItem);
		EndDo;

	EndIf;
EndProcedure

&AtServer
Function CheckParameterBeforeDeleteRowAtServer(CurrentParameterName)
	Result = New Array;	
	TableBoxesArray = New Array();
	TableBoxesArray.Add("Records");
	TableBoxesArray.Add("SalesVATRecords");
	TableBoxesArray.Add("PurchaseVATRecords");
	TableBoxesArray.Add("ExchangeRateDifferences");		
	
	For Each TableBoxeName In TableBoxesArray Do
		For each Record In Object[TableBoxeName] Do 
			CurrentFormula = TrimAll(Record.Formulas);
			If CurrentFormula <> "" Then
				FormulasMap = ValueFromStringInternal(CurrentFormula);
				RecordsSynonym = Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections[TableBoxeName].Synonym;
				For each MDAttribute In Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections[TableBoxeName].Attributes Do
					ColumnName = MDAttribute.Name;
					If ColumnName = "Formulas"
						OR ColumnName = "Condition" Then
						Continue
					EndIf;
					
					FormulaStructure = FormulasMap[ColumnName];	
					If FormulaStructure<>Undefined Then
						UsedInFormula=False;
						If FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Parameter And FormulaStructure.Value = CurrentParameterName Then
							UsedInFormula = True;
						ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Formula And StrFind(FormulaStructure.Value,"["+CurrentParameterName+"]")>0 Then
							UsedInFormula = True;								
						ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.ProgrammisticFormula And StrFind(FormulaStructure.Value,"."+CurrentParameterName)>0 Then
							UsedInFormula = True;								
						EndIf;		
						If UsedInFormula Then									
							Str = RecordsSynonym + Nstr("en=' Nr';pl=' nr'") + (1 + Object[TableBoxeName].Indexof(Record)) + " " + Nstr("en='Attribute';pl='Atrybut'") +": " +  MDAttribute.Synonym;
							Result.Add(Str);
						EndIf;							
					EndIf;					
				EndDo;
			EndIf;
		EndDo;		
	EndDo;
	Return Result;
EndFunction

#EndRegion

#Region AlgorithmEvents

&AtClient
Procedure AlgorithmTypeOnChange(Item)
	If Object.AlgorithmType = PredefinedValue("Enum.BookkeepingOperationTemplateAlgorithmTypes.None") Then
		Object.AlgorithmText = "";
	EndIf;	
	
	UpdateDialog();
EndProcedure

#EndRegion

#Region ConditionalAppearance

&AtServer
Procedure OnRowOutputInTableBox(CreateFillingMethod=False)
	RecordsTables = New ValueList;
	RecordsTables.Add("Records");
	RecordsTables.Add("SalesVATRecords");
	RecordsTables.Add("PurchaseVATRecords");
	RecordsTables.Add("ExchangeRateDifferences");
		
	For Each TableName In RecordsTables Do
		If CreateFillingMethod Then
			CreateFillingMethodAndValueAttributes(TableName.Value);		
		EndIf;
		
		RecordsTableItem = Items[TableName.Value];
		RecordsTableObject = Object[TableName.Value];
		
		For Each Row In RecordsTableObject Do
			
			SetRowAvailability(Row, TableName.Value);
			GetCurrentRowFillingMethodAndValue(Row, TableName.Value);
			
		EndDo;
		
		ItemsList = New ValueList;
		GetItemsListForConditionalAppearance(ItemsList, RecordsTableItem);		
		ApplyConditionalAppearance(ItemsList, RecordsTableItem, RecordsTableObject);
	EndDo;	
	
EndProcedure

&AtServer
Procedure CreateFillingMethodAndValueAttributes(TableName)
	NewAttributesArray = New Array;
	
	For Each Attribute In Object.Ref.Metadata().TabularSections.Find(TableName).Attributes Do
		If Attribute.Name = "LineNumber"
			OR Attribute.Name = "UseInExchangeRateDifferenceCalculation" 
			OR Attribute.Name = "Type"
			OR Attribute.Name = "ExchangeRateDifferencesCarriedOut"
			OR Attribute.Name = "Formulas" 
			OR Attribute.Name = "TableKind" 
			OR Attribute.Name = "TableName" Then
			Continue;
		EndIf;
		
		AttributeFillingMethod = New FormAttribute(Attribute.Name + "FillingMethod", New TypeDescription("EnumRef.FieldFillingMethods"), "Object." + TableName + ".", , True);	 
		AttributeValue = New FormAttribute(Attribute.Name + "Value", New TypeDescription("String"), "Object." + TableName + ".", , True);
		
		NewAttributesArray.Add(AttributeFillingMethod);
		NewAttributesArray.Add(AttributeValue);
	EndDo;
	
	ChangeAttributes(NewAttributesArray);
	
EndProcedure

&AtServer
Procedure GetCurrentRowFillingMethodAndValue(VTRow, TableName)
	
	FormulasMapAsInternalString = TrimAll(VTRow.Formulas);
	If FormulasMapAsInternalString <> "" Then
		FormulasMap = ValueFromStringInternal(FormulasMapAsInternalString);
		For Each Attribute In Object.Ref.Metadata().TabularSections.Find(TableName).Attributes Do
			If Attribute.Name = "LineNumber"
				OR Attribute.Name = "UseInExchangeRateDifferenceCalculation" 
				OR Attribute.Name = "Type"
				OR Attribute.Name = "ExchangeRateDifferencesCarriedOut"
				OR Attribute.Name = "Formulas" Then
				Continue;
			EndIf;
			
			FormulaStructure = FormulasMap[TrimAll(Attribute.Name)];
			
			If FormulaStructure <> Undefined Then
				VTRow[Attribute.Name + "FillingMethod"] = FormulaStructure.FillingMethod;
				
				CellText = "";			
				If FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Value Then
					// value
					CellText = FormatAmount(FormulaStructure.Value);
				Else
					// formula
					CellText = Catalogs.BookkeepingOperationsTemplates.GetFormulaPresentation(FormulaStructure, TableName,Object.Parameters.Unload());						
					If FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Parameter
						AND NOT IsBlankString(CellText) Then
						CellText = "<" + CellText + ">";
					EndIf;	
				EndIf;
				
				VTRow[Attribute.Name + "Value"] = CellText;
			EndIf;
		EndDo;
		
	EndIf;
EndProcedure

&AtServer
Procedure GetItemsListForConditionalAppearance(ItemsList, RecordsTableItem)
	For Each Column In RecordsTableItem.ChildItems Do
		If TypeOf(Column) = Type("FormGroup") Then
			GetItemsListForConditionalAppearance(ItemsList, Column);
		Else
			If Not Column.Visible Then
				Continue;
			EndIf;
			
			If Column.Name = RecordsTableItem.Name + "LineNumber"
				OR Column.Name = RecordsTableItem.Name + "UseInExchangeRateDifferenceCalculation" 
				OR Column.Name = RecordsTableItem.Name + "Type"
				OR Column.Name = RecordsTableItem.Name + "ExchangeRateDifferencesCarriedOut" Then
				Continue;
			EndIf;
			
			ItemsList.Add(Column.Name);
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure ApplyConditionalAppearance(ItemsList, RecordsTableItem, RecordsTableObject)
	For Each Attribute In Object.Ref.Metadata().TabularSections.Find(RecordsTableItem.Name).Attributes Do
		
		If ItemsList.FindByValue(RecordsTableItem.Name + Attribute.Name) = Undefined Then
			Continue;
		EndIf;
		
		NewConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		NewConditionalAppearanceItem.Use = True;
		
		NewField = NewConditionalAppearanceItem.Fields.Items.Add();
		NewField.Use = True;
		NewField.Field = New DataCompositionField(RecordsTableItem.Name + Attribute.Name);
		
		NewFilter = NewConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewFilter.Use = True;
		
		NewFilter.LeftValue = New DataCompositionField("Object." + RecordsTableItem.Name + "." + Attribute.Name + "FillingMethod");
		NewFilter.ComparisonType = DataCompositionComparisonType.Filled;
		
		NewConditionalAppearanceItem.Appearance.SetParameterValue("Text", New DataCompositionField("Object." + RecordsTableItem.Name + "." + Attribute.Name + "Value"));
	EndDo;	
EndProcedure

&AtServer
Procedure RestoreFillingMethodsAndValues()

	TabularSectionsList = New ValueList;
	TabularSectionsList.Add("Records");
	TabularSectionsList.Add("PurchaseVATRecords");
	TabularSectionsList.Add("SalesVATRecords");
	TabularSectionsList.Add("ExchangeRateDifferences");
	
	For Each Table In TabularSectionsList Do
		For Each Row In Object[Table.Value] Do
			GetCurrentRowFillingMethodAndValue(Row, Table.Value);
			SetRowAvailability(Row, Table.Value);
		EndDo;
	EndDo;
	SetParametersAppearanceAtServer();
EndProcedure

&AtServer
Procedure SetParametersAppearanceAtServer()
	TableOfTables = Catalogs.BookkeepingOperationsTemplates.GetTableOfTables(Object.DocumentBase);
	
	For Each RowData In Object.Parameters Do
		If RowData.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase Then
			
			FoundRows = TableOfTables.FindRows(New Structure("TableName, TableKind",RowData.TableName,RowData.TableKind));
			
			If FoundRows.Count() = 0 Then
				RowData.IsInTables = False;				
			Else				
				RowData.IsInTables = True;				
			EndIf;
			If FoundRows.Count() = 1 Then
				FoundRow = FoundRows[0];
				RowData.TablePicture = FoundRow.TablePicture;
				RowData.TablePresentation = FoundRow.TableSynonym;		
			EndIf;				
		Else
			RowData.IsInTables = True;				
		EndIf;
	    RowData.TypePresentation = String(ValueFromStringInternal(RowData.TypeStringInternal));
	EndDo;
EndProcedure
#EndRegion

#Region Other
&AtServer
Procedure InitializeAllSelectedTables()
	InitializeSelectedTables(SelectedTables, Object.Records);
	InitializeSelectedTables(SelectedSalesVATTables, Object.SalesVATRecords);
	InitializeSelectedTables(SelectedPurchaseVATTables, Object.PurchaseVATRecords);
EndProcedure

&AtServer
Procedure GetNewBookkeepingTemplate(TextDocument)
	CatalogObject = Common.GetObjectFromXML(TextDocument.GetText(), Type("CatalogObject.BookkeepingOperationsTemplates"));	
	ValueToFormData(CatalogObject, Object);	
EndProcedure

&AtServer
Function SerializeBookkeepingTemplate()
	CatalogObject = FormDataToValue(Object, Type("CatalogObject.BookkeepingOperationsTemplates"));
	
	XMLText = Common.SerializeObject(CatalogObject);
	
	Return XMLText;	
EndFunction

&AtServer
Procedure SetRowAvailability(VTRow, TableName)
	If TableName = "ExchangeRateDifferences" Then
		Return;
	EndIf;

	VTRow.Availability = True;
	If Common.IsDocumentTabularPartAttribute("TableName", Object.Ref.Metadata(), TableName) 
		AND Common.IsDocumentTabularPartAttribute("TableKind", Object.Ref.Metadata(), TableName) Then
		TableOfTables = Catalogs.BookkeepingOperationsTemplates.GetTableOfTables(Object.DocumentBase);
		FoundRows = TableOfTables.FindRows(New Structure("TableName, TableKind", VTRow.TableName, VTRow.TableKind));
		If FoundRows.Count() = 0 Then		
			VTRow.Availability = False;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Function GetObjectFieldName(CurrentItemName) Export
	Return DocumentsFormAtServer.GetObjectFieldName(ThisForm,CurrentItemName);		
EndFunction

// Returns structure with list of current controls in page
&AtServer
Function GetCurrentItemsForPage()
	
	GeneralPanelControlPages = Items.Pages;
	GeneralPanelControlCurrentPage = GeneralPanelControlPages.CurrentPage;
	
	CurrentSelectedTables = Undefined;
	CurrentRecords = Undefined;
	CurrentFillingMethod = Undefined;
	CurrentButtonNewParameter = Undefined;
	CurrentPanelFillingMethod = Undefined;
	CurrentFormulaPresentation = Undefined;
	CurrentValue = Undefined;
	IsEmpty = True;
	
	If GeneralPanelControlCurrentPage = Items.GroupRecords Then
		CurrentSelectedTables = Items.SelectedTables.Name;
		CurrentRecords = Items.Records.Name;
		CurrentFillingMethod = Items.FillingMethod.Name;
		CurrentButtonNewParameter = Items.ButtonNewParameter.Name;
		CurrentPanelFillingMethod = Items.GroupFillingMethod.Name;
		CurrentFormulaPresentation = Items.FormulaPresentation.Name;
		CurrentValue = Items.Value.Name;
		IsEmpty = False;
	ElsIf GeneralPanelControlCurrentPage = Items.GroupPurchaseVATRecords Then		
		CurrentSelectedTables = Items.SelectedPurchaseVATTables.Name;
		CurrentRecords = Items.PurchaseVATRecords.Name;
		CurrentFillingMethod = Items.PurchaseVATFillingMethod.Name;
		CurrentButtonNewParameter = Items.PurchaseVATButtonNewParameter.Name;
		CurrentPanelFillingMethod = Items.GroupPurchaseVATFillingMethod.Name;
		CurrentFormulaPresentation = Items.PurchaseVATFormulaPresentation.Name;
		CurrentValue = Items.PurchaseVATValue.Name;
		IsEmpty = False;
	ElsIf GeneralPanelControlCurrentPage = Items.GroupSalesVATRecords Then
		CurrentSelectedTables = Items.SelectedSalesVATTables.Name;
		CurrentRecords = Items.SalesVATRecords.Name;
		CurrentFillingMethod = Items.SalesVATFillingMethod.Name;
		CurrentButtonNewParameter = Items.SalesVATButtonNewParameter.Name;
		CurrentPanelFillingMethod = Items.GroupSalesVATFillingMethod.Name;
		CurrentFormulaPresentation = Items.SalesVATFormulaPresentation.Name;
		CurrentValue = Items.SalesVATValue.Name;
		IsEmpty = False;
	ElsIf GeneralPanelControlCurrentPage = Items.GroupExchangeRateDifferences Then	
		CurrentSelectedTables = Undefined;
		CurrentRecords = Items.ExchangeRateDifferences.Name;
		CurrentFillingMethod = Items.ExchangeRateDifferencesFillingMethod.Name;
		CurrentButtonNewParameter = Items.ExchangeRateDifferencesButtonNewParameter.Name;
		CurrentPanelFillingMethod = Items.GroupExchangeRateDifferencesFillingMethod.Name;
		CurrentFormulaPresentation = Items.ExchangeRateDifferencesFormulaPresentation.Name;
		CurrentValue = Items.ExchangeRateDifferencesValue.Name;
		IsEmpty = False;
	EndIf;	
		
	Return New Structure("CurrentSelectedTables, CurrentRecords, CurrentFillingMethod, CurrentButtonNewParameter, CurrentPanelFillingMethod, CurrentFormulaPresentation, CurrentValue, IsEmpty", CurrentSelectedTables, CurrentRecords, CurrentFillingMethod, CurrentButtonNewParameter, CurrentPanelFillingMethod, CurrentFormulaPresentation, CurrentValue, IsEmpty);	
EndFunction


&AtServer
Procedure UpdateModeLabel()
	
	If Object.WorkMode Then
		Items.LabelWorkMode.Title = NStr("en = 'Work mode'; pl = 'Tryb roboczy'");
		Items.LabelWorkModePicture.Visible = False;
		Commands["WorkMode"].Title = NStr("en = 'Turn back to test mode'; pl = 'Wróć do trybu testowego'");
	Else
		Items.LabelWorkMode.Title = NStr("en = 'Test mode'; pl = 'Tryb testowy'");
		Items.LabelWorkModePicture.Visible = True;
		Commands["WorkMode"].Title = NStr("en = 'Turn to work mode'; pl = 'Przełącz na tryb roboczy'");
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeSelectedTables(CurrentSelectedTables, RecordsTable)
	
	CurrentSelectedTablesObject = FormDataToValue(CurrentSelectedTables, Type("ValueTree"));
	
	CurrentSelectedTablesObject.Rows.Clear();
	
	AllRecordsRow = CurrentSelectedTablesObject.Rows.Add();
	AllRecordsRow.TableName = "AllRecords";
	AllRecordsRow.TableSynonym = Nstr("en='All records';pl='Wszystkie zapisy'");
	AllRecordsRow.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef();
	AllRecordsRow.TablePicture = PictureLib.AllRecords;
	AllRecordsRow.Filter = New ValueList;
	
	GroupedRecords = RecordsTable.Unload(,"TableName, TableKind");
	GroupedRecords.GroupBy("TableName, TableKind");
		
	TableOfTables = Catalogs.BookkeepingOperationsTemplates.GetTableOfTables(Object.DocumentBase);
	
	TabularSectionRows = Undefined;
	InformationRegisterRows = Undefined;
	AccumulationRegisterRows = Undefined;
	
	For Each GroupedRecordsItem In GroupedRecords Do
		
		FoundRows = TableOfTables.FindRows(New Structure("TableName, TableKind", GroupedRecordsItem.TableName, GroupedRecordsItem.TableKind));
		If FoundRows.Count() = 0 Then
			
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='There is no table with name %P1 in configuration!';pl='Brak tabeli o nazwie %P1 w konfiguracji!'"), New Structure("P1", GroupedRecordsItem.TableName)), Enums.AlertType.Error);
			OneRow = Undefined;
			
		ElsIf FoundRows.Count() > 1 Then
			
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='Too many tables with name %P1 in configuration!';pl='Za dużo tabel o nazwie %P1 w konfiguracji!'"), New Structure("P1", GroupedRecordsItem.TableName)), Enums.AlertType.Error);
			OneRow = FoundRows[0];
			
		Else
			
			OneRow = FoundRows[0];
			
		EndIf;
		
		ParentRows = Catalogs.BookkeepingOperationsTemplates.GetParentRowsByKind(GroupedRecordsItem.TableKind, AllRecordsRow);			
		TablePicture = Catalogs.BookkeepingOperationsTemplates.GetKindPicture(GroupedRecordsItem.TableKind);
		
		NewRow = ParentRows.Rows.Add();
		NewRow.TableName = GroupedRecordsItem.TableName;
		If OneRow = Undefined Then
			NewRow.TableSynonym = "<" + GroupedRecordsItem.TableName + ">";
		Else	
			NewRow.TableSynonym = OneRow.TableSynonym;
		EndIf;
		NewRow.TableKind = GroupedRecordsItem.TableKind;
		NewRow.TablePicture = TablePicture;
					
	EndDo;
	
	UnMarkAllSelectedTables(CurrentSelectedTablesObject.Rows);
	ListOfNotAvailableTables = Catalogs.BookkeepingOperationsTemplates.GetListOfNotAvailableTables(CurrentSelectedTablesObject.Rows, TableOfTables,,Object.DocumentBase);
	MarkUnavailableTables(ListOfNotAvailableTables);	
	ValueToFormData(CurrentSelectedTablesObject, CurrentSelectedTables);
	
EndProcedure

&AtClient
Procedure UpdateViewOnFillingMethod()
	
	If ItemsStructure.CurrentRecords <> Undefined Then
		ControlsEnabled = Items[ItemsStructure.CurrentRecords].CurrentData <> Undefined 
		AND Items[ItemsStructure.CurrentRecords].CurrentItem <> Undefined;
		
		ControlsEnabled = ?(ReadOnly,False,ControlsEnabled);
		If NOT ControlsEnabled Then
			
			Items[ItemsStructure.CurrentFillingMethod].Enabled = ControlsEnabled;
			Items[ItemsStructure.CurrentButtonNewParameter].Enabled = ControlsEnabled;
			Items[ItemsStructure.CurrentFormulaPresentation].Enabled = ControlsEnabled;
			Items[ItemsStructure.CurrentValue].Enabled = ControlsEnabled;
		EndIf;
		If Items[ItemsStructure.CurrentFillingMethod] <> Undefined Then
			
			If FillingMethod = PredefinedValue("Enum.FieldFillingMethods.EmptyRef") Then
				Items[ItemsStructure.CurrentPanelFillingMethod].CurrentPage = Items[ItemsStructure.CurrentPanelFillingMethod + "Empty"];
			ElsIf FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value") Then
				Items[ItemsStructure.CurrentPanelFillingMethod].CurrentPage = Items[ItemsStructure.CurrentPanelFillingMethod + "Value"];	
			Else
				Items[ItemsStructure.CurrentPanelFillingMethod].CurrentPage = Items[ItemsStructure.CurrentPanelFillingMethod + "Formula"];	
			EndIf;	
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateOrEmulateNewOperation(Emulate)
	
	If Modified Then
		ShowQueryBox(New NotifyDescription("GenerateNewOperationAnswerHandler", ThisForm, Emulate), Nstr("en = 'Bookkeeping operation template was modified. Before generation or emulation template should be written. Are you sure you want to write this template?'; pl = 'Schemat księgowanie został zmodifikowany. Przed generacją lub wprobuwaniem trzeba zapisać schemat. Czy chcesz zapisać schemat?'"), QuestionDialogMode.YesNo);	
	Else
		GenerateOperation(Emulate);
	EndIf;	
		
EndProcedure

&AtClient
Procedure GenerateNewOperationAnswerHandler(Result, AdditionalParameters) Export
	If Result = DialogReturnCode.Yes Then
		Write();	
		GenerateOperation(AdditionalParameters);		
	EndIf;
EndProcedure

&AtClient
Procedure GenerateOperation(Emulate)
	
	If Object.Type = PredefinedValue("Enum.BookkeepingOperationTemplateTypes.AsDataProcessor") Then
		//Not implemented in managed forms
		//If Object.InternalDataProcessor Then     
		//	
		//	DataProcessor = DataProcessors[Object.FileName].Create();
		//	
		//Else
		//	
		//	BinaryData = Object.OperationTemplateAsDataProcessor.Get();
		//	TempFileName = GetTempFileName("epf");
		//	BinaryData.Write(TempFileName);
		//	DataProcessor = ExternalDataProcessors.Create(TempFileName);
		//	
		//EndIf;
		//
		//DataProcessor.Perform(Object.Ref);
		
	ElsIf Object.Type = PredefinedValue("Enum.BookkeepingOperationTemplateTypes.Normal") Then	
	
		FormParameters = New Structure;
		
		FormParameters.Insert("Basis", Object.Ref);
		FormParameters.Insert("IsEmulated", Emulate);
		OpenForm("Document.BookkeepingOperation.ObjectForm", FormParameters, ThisForm);
	
	EndIf;
		
EndProcedure


&AtClient
Function SaveTemplateAsFile()
	
	FileName = TrimAll(Object.Code + " " + Object.Description);
	
	Mode = FileDialogMode.Save;
	SaveFileDialog = New FileDialog(Mode);
	SaveFileDialog.FullFileName = FileName;
	SaveFileDialog.DefaultExt = "xml";
	SaveFileDialogFilter = "XML files(*.xml)|*.xml";
	SaveFileDialog.Filter = SaveFileDialogFilter;
	SaveFileDialog.CheckFileExist = True;
	SaveFileDialog.Multiselect = False;
	SaveFileDialog.Title = Nstr("en='Save bookkeeping operation template as XML file';pl='Zapisz schemat księgowania jako plik XML'");
	
	If SaveFileDialog.Choose() Then
		FileInXMLFormat = SaveFileDialog.FullFileName;
	Else
		Return "";
	EndIf;
			
	TextDocument = New TextDocument;

	XMLText = SerializeBookkeepingTemplate();

	TextDocument.SetText(XMLText);
	Try
		TextDocument.Write(FileInXMLFormat,TextEncoding.UTF8);
	Except
		Return "";
	EndTry;	
	
	Return FileInXMLFormat;
	
EndFunction


&AtServer
Procedure ChangeAvailablesOfTablesOfDocumentBaseChange()
	TableOfTables = Catalogs.BookkeepingOperationsTemplates.GetTableOfTables(Object.DocumentBase);
	
	ChangeAvailablesTable(SelectedTables,TableOfTables);	
	ChangeAvailablesTable(SelectedPurchaseVATTables,TableOfTables);	
	ChangeAvailablesTable(SelectedSalesVATTables,TableOfTables);
	
	SetParametersAppearanceAtServer();
	
EndProcedure

&AtServer
Procedure ChangeAvailablesTable(CurrentTable,TableOfTables)
	
	SelectedTablesTree = FormDataToValue(CurrentTable, Type("ValueTree"));
	SelectedTablesListOfNotAvailableTables = Catalogs.BookkeepingOperationsTemplates.GetListOfNotAvailableTables(SelectedTablesTree.Rows, TableOfTables,,Object.DocumentBase);
	UnMarkAllSelectedTables(SelectedTablesTree.Rows, TableOfTables);
	MarkUnavailableTables(SelectedTablesListOfNotAvailableTables);
	ValueToFormData(SelectedTablesTree, CurrentTable);

EndProcedure

&AtClient
Procedure SetFilterOnTable(SelectedTablesItem, RecordsItem)
	
	CurrentData = SelectedTablesItem.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentDataStructure = New Structure;
		CurrentDataStructure.Insert("Filter",CurrentData.Filter);
		CurrentDataStructure.Insert("Root",?(CurrentData.getParent()=Undefined,True,False));
		CurrentDataStructure.Insert("Node",?(CurrentData.GetItems().Count()>0,True,False));
		CurrentDataStructure.Insert("TableName",CurrentData.TableName);
		CurrentDataStructure.Insert("TableKind",CurrentData.TableKind);	
		
		SetFilterOnTableAtServer(SelectedTablesItem.Name, RecordsItem.Name, CurrentDataStructure);		
		If (CurrentDataStructure.Root OR CurrentDataStructure.Node) 
			AND Object.DocumentBase <> Undefined Then
			ThisForm[RecordsItem.Name+"ChangeRowSet"]= False;    			
			Items[RecordsItem.Name+"ButtonAdd"].Enabled = False;    
		Else
			ThisForm[RecordsItem.Name+"ChangeRowSet"]=True;    		
			Items[RecordsItem.Name+"ButtonAdd"].Enabled = True;    			
		EndIf;			
				
		//If (CurrentDataStructure.Root OR CurrentDataStructure.Node) 
		//	AND Object.DocumentBase <> Undefined Then
		//	RecordsItem.ChangeRowSet = False;    			
		//Else
		//	RecordsItem.ChangeRowSet = True;    						
		//EndIf;			
	Else	
		If Object.DocumentBase=Undefined Then
			ThisForm[RecordsItem.Name+"ChangeRowSet"]=True;   
			Items[RecordsItem.Name+"ButtonAdd"].Enabled = True;    						
		Else			
			ThisForm[RecordsItem.Name+"ChangeRowSet"]=False;  
			Items[RecordsItem.Name+"ButtonAdd"].Enabled = False;    			
		EndIf;
		
		//If Object.DocumentBase=Undefined Then
		//	RecordsItem.ChangeRowSet = True;    		
		//Else			
		//	RecordsItem.ChangeRowSet = False;    
		//EndIf;
	EndIf;	

EndProcedure

&AtServer
Procedure SetFilterOnTableAtServer(SelectedTablesItemName, RecordsItemName, CurrentData);
	If CurrentData.Root Then
		For Each CurrentRow In Object[RecordsItemName] Do
			CurrentRow.HideRow = False;			
		EndDo;		
	ElsIf CurrentData.Node Then	
		If CurrentData.Filter = Undefined Then
			For Each CurrentRow In Object[RecordsItemName] Do
				CurrentRow.HideRow = True;			
			EndDo;				
		Else
			For Each CurrentRow In Object[RecordsItemName] Do
				If CurrentData.Filter.FindByValue(CurrentRow.TableKind) = Undefined Then
					CurrentRow.HideRow = True;								
				Else	
					CurrentRow.HideRow = False;								
				EndIf;

			EndDo;			
		EndIf;
	Else	
		For Each CurrentRow In Object[RecordsItemName] Do
			If CurrentRow.TableKind = CurrentData.TableKind AND CurrentRow.TableName = CurrentData.TableName Then
				CurrentRow.HideRow = False;						
			Else	
			    CurrentRow.HideRow = True;			
			EndIf;
		EndDo;	
	EndIf;	   	
	
EndProcedure

&AtClient
Procedure SetFieldValueOnChange(CurrentTableBox, CurrentFillingMethod, CurrentValue = Undefined, CurrentFormula = Undefined, NeedRefresh = False)
	
	FormulaStructure = New Structure("FillingMethod", CurrentFillingMethod);
	If CurrentFillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value") Then
		FormulaStructure.Insert("Value", CurrentValue);
	Else
		FormulaStructure.Insert("Value", CurrentFormula);
	EndIf;	
	
	SetFormulaStructure(CurrentTableBox, , , FormulaStructure);
	
	If NeedRefresh Then
	
		OnActivateCellInTableBox(CurrentTableBox);
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure SetFormulaStructure(TableBox, VTRow = "", ColumnName = "", FormulaStructure = Undefined)

	If VTRow = "" Then
		VTRow = TableBox.CurrentData;
	EndIf;
		
	If ColumnName = "" Then
		ColumnName = GetObjectFieldName(TableBox.CurrentItem.Name);								
	EndIf;

	FormulasMapAsInternalString = TrimAll(VTRow.Formulas);
	If FormulasMapAsInternalString = "" Then
		FormulasMap = New Map();
	Else
		FormulasMap = GetFormulasMap(FormulasMapAsInternalString);
	EndIf;
	
	FormulasMap.Insert(TrimAll(ColumnName), FormulaStructure);
	
	VTRow.Formulas = SetFormulasMap(FormulasMap);

EndProcedure

&AtClient
Procedure AddTableAction(TableBox, CurrentSelectedTables,CurrentSelectedTablesName)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentSelectedTables", CurrentSelectedTables);	
	FormParameters.Insert("DocumentBase", Object.DocumentBase);
	
	OpenForm("Catalog.BookkeepingOperationsTemplates.Form.TableChoiceFormManaged", FormParameters, ThisForm, ThisForm, , , New NotifyDescription("TableChoiceProcessing", ThisForm, New Structure("TableBox, CurrentSelectedTablesName", TableBox, CurrentSelectedTablesName)));
		
EndProcedure

&AtClient
Procedure TableChoiceProcessing(Result, AdditionalParameters) Export
	If Result <> Undefined Then	
		AdditionalParameters.TableBox.Expand(AddSelectedTableRowAtServer(Result, AdditionalParameters.CurrentSelectedTablesName));	
	EndIf;	
EndProcedure

&AtServer
Function AddSelectedTableRowAtServer(Result, CurrentSelectedTablesName)
	ParentRows = DocumentsFormAtServer.GetParentRowsByKindFormItem(Result.TableKind, ThisForm[CurrentSelectedTablesName].GetItems()[0]);					
	ParentRows.Availability = True;
	NewRow = ParentRows.GetItems().Add();
	NewRow.TableName = Result.TableName;
	NewRow.TableKind = Result.TableKind;                    
	NewRow.TablePicture = Result.TablePicture;
	NewRow.TableSynonym = Result.TableSynonym;                                 
	NewRow.Availability = True;
	
	Return NewRow.GetParent().GetID(); 
EndFunction

&AtClient
Procedure BeforeDeleteTableAction(CurrentData, CurrentRecordsName)
	Cancel = True;	
	If CurrentData.GetParent() = Undefined Or CurrentData.TableKind = PredefinedValue("Enum.BookkeepingOperationTemplateTableKind.EmptyRef") Then		
		ShowMessageBox( , Nstr("en='This row is predefined and could not be deleted!';pl='Ten wiersz jest predifiniowany i nie może być usunięty!'"));
	Else
		FoundRows = Object[CurrentRecordsName].FindRows(New Structure("TableKind, TableName", CurrentData.TableKind, CurrentData.TableName));

		If FoundRows.Count() > 0 Then
			ShowQueryNotifyDescription = New NotifyDescription("RecordsDeletionQueryResult", ThisForm, New Structure("CurrentData, FoundRows, CurrentRecordsName",CurrentData, FoundRows, CurrentRecordsName));
			ShowQueryBox(ShowQueryNotifyDescription, Nstr("en='Some records linked to this table! After deleting table this records also will be deleted. Are you sure want to delete this table?';pl='Niektóre zapisy powiązane z tabelą! Po usunięcu tabeli zapisu zostaną również usunięty. Czy napewno chcesz usunąć tabelę?'"), QuestionDialogMode.YesNo);	
		EndIf;			
	EndIf;		
EndProcedure

&AtClient
Procedure RecordsDeletionQueryResult(Result, AdditionalParameters) Export
	If Result = DialogReturnCode.Yes Then
		// delete records linked with table
		For Each FoundRow In AdditionalParameters.FoundRows Do
			Object[AdditionalParameters.CurrentRecordsName].Delete(FoundRow)
		EndDo;		
		CurrentParent = AdditionalParameters.CurrentData.GetParent();
		CurrentParent.GetItems().Delete(AdditionalParameters.CurrentData);
	
		If CurrentParent.GetParent() <> Undefined
			AND CurrentParent.TableKind = PredefinedValue("Enum.BookkeepingOperationTemplateTableKind.EmptyRef") 
			AND CurrentParent.GetItems().Count() = 0 Then
			CurrentParent.GetParent().GetItems().Delete(CurrentParent);
		EndIf;		
	EndIf;
EndProcedure

&AtClient
Procedure ParameterWizardOnClose(Result, AdditionalParameters) Export
	
	If Result<>Undefined Then
		SetFieldValueOnChange(Items[Result.TableBoxName], Result.FillingMethod, Result.Value, Result.Formula, True);		
	EndIf;		
	RestoreFillingMethodsAndValues();
EndProcedure

&AtServer
Procedure UnMarkAllSelectedTables(SelectedTablesRows, TableOfTables = Undefined)
	
	If TableOfTables = Undefined Then
		TableOfTables = Catalogs.BookkeepingOperationsTemplates.GetTableOfTables(Object.DocumentBase);
	EndIf;	
	
	For Each Row In SelectedTablesRows Do
		
		Row.Availability = True;
		
		If Row.Rows.Count() > 0 Then
			UnMarkAllSelectedTables(Row.Rows, TableOfTables);
		Else
			FoundRows = TableOfTables.FindRows(New Structure("TableName, TableKind", Row.TableName, Row.TableKind));
			If FoundRows.Count() > 0 Then
				Row.TableSynonym = FoundRows[0].TableSynonym;
			EndIf;	
		EndIf;	
	
	EndDo;	
	
EndProcedure

&AtServer
Procedure MarkUnavailableTables(ListOfNotAvailableTables)
	
	ParentsValueList = New ValueList();
	
	For Each NotAvailableTable In ListOfNotAvailableTables Do
		
		If ParentsValueList.FindByValue(NotAvailableTable.Parent)=Undefined Then
			
			ParentsValueList.Add(NotAvailableTable.Parent);
			
		EndIf;	
		
		NotAvailableTable.Availability = False;
		
	EndDo;	
	
	For Each ParentTable In ParentsValueList Do
		
		WasAvailable = False;
		For Each Row In ParentTable.Value.Rows Do
			
			If Row.Availability Then
				WasAvailable = True;
				Break;
			EndIf;	
			
		EndDo;
		
		If NOT WasAvailable Then
			ParentTable.Value.Availability = False;
		EndIf;	
		
	EndDo;	
	
EndProcedure

// Returns formula's expression of given field and given record's template
//
// Parameters:
//  TableBox - control of table box Records
//  VTRow       -  row of table box Records
//  ColumnName     - column Name of table box Records, formula for which should be returned
//
// Return Value:
//  String - formula's expression of given field and given record's template 
&AtClient
Function GetFormulaStructure(TableBox, VTRow = "", ColumnName = "") Export

	If VTRow = "" Then
		VTRow = TableBox.CurrentData;
	EndIf;

	If ColumnName = "" Then
		ColumnName = GetObjectFieldName(TableBox.CurrentItem.Name);				
	EndIf;

	If VTRow = Undefined Then
		FormulaStructure = New Structure("FillingMethod, Value", PredefinedValue("Enum.FieldFillingMethods.Parameter"), "");
	EndIf;

	FormulasMapAsInternalString = TrimAll(VTRow.Formulas);
	If FormulasMapAsInternalString = "" Then
		
		FormulaStructure = New Structure("FillingMethod, Value", PredefinedValue("Enum.FieldFillingMethods.Parameter"), "");
		
	Else
		
		FormulasMap = GetFormulasMap(FormulasMapAsInternalString);
		FormulaStructure = FormulasMap[TrimAll(ColumnName)];
		
		If FormulaStructure = Undefined Then
			
			FormulaStructure = New Structure("FillingMethod, Value", PredefinedValue("Enum.FieldFillingMethods.Parameter"), "");	
			
		EndIf;	
		
	EndIf;
	
	If StrFind(ColumnName, "ExtDimension") > 0 Then
		AccountFormulaStructure = GetFormulaStructure(TableBox, VTRow, "Account");
		FoundRow = CommonAtClient.FindTabularPartRow(Object.Parameters, New Structure("Name", AccountFormulaStructure.Value));
		If (AccountFormulaStructure.FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value")
			AND ValueIsFilled(AccountFormulaStructure.Value)) 
			OR (AccountFormulaStructure.FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Parameter") 
			AND FoundRow <> Undefined AND FoundRow.ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.NotLinked")
			AND TypeOf(FoundRow.Value) = TypeOf(PredefinedValue("ChartOfAccounts.Bookkeeping.EmptyRef")) AND ValueIsFilled(FoundRow.Value)) Then

			If AccountFormulaStructure.FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value") Then
				CurrentAccount = AccountFormulaStructure.Value;
			Else
				CurrentAccount = FoundRow.Value;
			EndIf;

			ExtDimNumber = Number(Right(ColumnName, 1)) - 1;
			
			If ExtDimNumber > GetAccountExtDimensionTypesCount(CurrentAccount) - 1 Then    
				CurrentTypeDescription = Undefined;
			Else					
				CurrentTypeDescription = GetAccountValueType(CurrentAccount,ExtDimNumber);				
			EndIf;
		Else
			
			CurrentTypeDescription = GetCurrentTypeDescription(ColumnName, TableBox.Name);
			
		EndIf;	
	Else
		 
		CurrentTypeDescription = GetCurrentTypeDescription(ColumnName, TableBox.Name);
		
	EndIf;
	
	FormulaStructure.Insert("TypeRestriction", CurrentTypeDescription);
	
	Return FormulaStructure;

EndFunction

&AtServerNoContext
Function GetAccountExtDimensionTypesCount(CurrentAccount)
	Return CurrentAccount.ExtDimensionTypes.Count();
EndFunction

&AtServerNoContext
Function GetAccountValueType(CurrentAccount,ExtDimNumber)
	Return CurrentAccount.ExtDimensionTypes[ExtDimNumber].ExtDimensionType.ValueType;
EndFunction


&AtServerNoContext
Function GetCurrentTypeDescription(ColumnName, TableBoxName)
	Return Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections[TableBoxName].Attributes[ColumnName].Type;
EndFunction

&AtClient
Function IsExtDimensionControlAvailable(TableBox, VTRow = Undefined, ColumnName) 
	
	If VTRow = Undefined Then
		VTRow = TableBox.CurrentData;
	EndIf;	
	
	If Left(ColumnName, 12) = "ExtDimension" Then
		
		AccountFormulaStructure = GetFormulaStructure(TableBox, VTRow, "Account");
		If AccountFormulaStructure.FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value") Then
			If ValueIsFilled(AccountFormulaStructure.Value) Then
				If Number(Right(ColumnName, 1)) > GetAccountExtDimensionTypesCount(AccountFormulaStructure.Value) Then   
					Return False;
				EndIf;
			Else
				Alerts.AddAlert(Nstr("en = 'Please, choose account first!'; pl = 'Najperw należy wybrać konto!'"));
				Return False;

			EndIf;	
		ElsIf AccountFormulaStructure.FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Parameter") Then
			FoundRow = CommonAtClient.FindTabularPartRow(Object.Parameters, New Structure("Name", AccountFormulaStructure.Value));
			If FoundRow <> Undefined 
				AND FoundRow.ParameterKind = PredefinedValue("Enum.BookkeepingOperationTemplateParameterKinds.NotLinked")
				AND TypeOf(FoundRow.Value) = TypeOf(PredefinedValue("ChartOfAccounts.Bookkeeping.EmptyRef")) Then
				
				If ValueIsFilled(FoundRow.Value) Then
					If Number(Right(ColumnName, 1)) > GetAccountExtDimensionTypesCount(FoundRow.Value) Then   					
						Return False;
					EndIf;
				Else
					Alerts.AddAlert(Nstr("en = 'Please, choose account first!'; pl = 'Najperw należy wybrać konto!'"));
					Return False;
				EndIf;	
				
			EndIf;	
			
		EndIf;	
		
	EndIf;	
	
	Return True;
	
EndFunction

&AtClient
Procedure DisableAllControlsForFieldEditing(ItemsStructure)
	
	If NOT ItemsStructure.IsEmpty Then
		Items[ItemsStructure.CurrentFormulaPresentation].Enabled = False;
		Items[ItemsStructure.CurrentFillingMethod].Enabled  = False;
		Items[ItemsStructure.CurrentButtonNewParameter].Enabled = False;
		Items[ItemsStructure.CurrentValue].Enabled = False;
	EndIf;
	
	FormulaPresentation = "";
	Formula = "";
	
EndProcedure

&AtServer
Function TemplateIsBlocked()
	
	If Object.Ref.IsEmpty() Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	BlockedBookkeepingOperationTemplates.Template
	             |FROM
	             |	InformationRegister.BlockedBookkeepingOperationTemplates AS BlockedBookkeepingOperationTemplates
	             |WHERE
	             |	BlockedBookkeepingOperationTemplates.Template = &Template";
	
	Query.SetParameter("Template", Object.Ref);
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtServer
Procedure ChangeSetBlockedMarkTitleAtServer()
	If TemplateIsBlocked() Then
		Commands["SetBlockedMark"].Title =  NStr("en = 'Unlock this template for use in new documents'; pl = 'Odblokuj używanie tego schematu dla nowych dokumentów'");
		Items.PictureLock.Visible = True;
		Items.DecorationLock.Visible = True;				
	Else
		Commands["SetBlockedMark"].Title = NStr("en = 'Lock this template for use in new documents'; pl = 'Zablokuj używanie tego schematu dla nowych dokumentów'");
		Items.PictureLock.Visible = False;		
		Items.DecorationLock.Visible = False;						
	EndIf;	
EndProcedure

&AtServer
Function GetFormulasMap(FormulasMapAsInternalString)
	Return ValueFromStringInternal(FormulasMapAsInternalString);
EndFunction

&AtServer
Function SetFormulasMap(FormulasMap)
	Return ValueToStringInternal(FormulasMap);
EndFunction

&AtServer
Function GetFormulaPresentationAtServer(FormulaStructure, TableBoxName)
	FormulaPresentation = Catalogs.BookkeepingOperationsTemplates.GetFormulaPresentation(FormulaStructure, TableBoxName,Object.Parameters.Unload());						
	Return FormulaPresentation;
EndFunction

&AtClient
Procedure EditingFormulaOnClose(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		Formula = Result;
	EndIf;
		
	FormulaStructure = GetFormulaStructure(Items[ItemsStructure.CurrentRecords]);
	
	GetFormulaPresentationAtServer(FormulaStructure, ItemsStructure.CurrentRecords);
	
	SetFieldValueOnChange(Items[ItemsStructure.CurrentRecords], FillingMethod, Undefined, Formula, True);
	
	RestoreFillingMethodsAndValues();
EndProcedure

&AtServer
Function GetListOfDocumentTypes()
	DocumentsList = New ValueList;
	
	For Each Document In Documents Do
		DocumentsList.Add(Document.EmptyRef(), Metadata.Documents[StrReplace(String(Document), "DocumentManager.", "")].Synonym);
	EndDo;
	
	Return DocumentsList;
EndFunction

&AtClient
Procedure SetFilterDescription()
	FilterDescription = "";
	If IsBlankString(Object.FilterAsXML) Then
		FilterDescription = Nstr("en='<Set filter>';pl='<Ustaw filtr>';");
	Else
		FilterObject = Common.GetObjectFromXML(Object.FilterAsXML, Type("DataCompositionFilter"));        
		FilterDescription = Nstr("en='<Filter:';pl='<Filtr:>';");
		For Each FilterItem In FilterObject.Items Do
			If FilterItem.Use Then
				FilterDescription = FilterDescription + String(FilterItem.LeftValue) + "; ";
			EndIf;
		EndDo;                                                                                           
		FilterDescription = TrimAll(FilterDescription) + ">";
	EndIf;
EndProcedure

&AtClient
Procedure SetRecordsCurrentItemToLineNumber(TableBoxName)
	CurrentTableBox = Items.Find(TableBoxName);
	If CurrentTableBox<>Undefined Then
		CurrentTableBox.CurrentItem = CurrentTableBox.ChildItems.Find(TableBoxName + "LineNumber");	
		OnActivateCellInTableBox(CurrentTableBox);
	EndIf;
EndProcedure



#EndRegion
