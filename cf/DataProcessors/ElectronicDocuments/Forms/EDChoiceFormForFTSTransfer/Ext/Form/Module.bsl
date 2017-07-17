////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
		MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("WorkWithED");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;
	
	// VersionCall parameter can contain values:
	//  1 - import in the file;
	//  2 - array references return;
	//  3 - structures array return (in this case the
	//      form is opened modelessly and on close the IBDocumentsChoiceFormForTransferToFTSClosed event notification is executed).
	If Not Parameters.Property("VersionCall", VersionCall) Then
		VersionCall = ?(Parameters.Property("ExportToFile") AND Parameters.ExportToFile = True, 1, 2);
	EndIf;
	
	If VersionCall <> 1 Then
		If VersionCall = 3 Then
			Multiselect = True;
		Else
			Multiselect = (Parameters.Property("Multiselect", Multiselect) AND Multiselect = True);
			If Not Multiselect Then
				Items.AvailableDocuments.SelectionMode = TableSelectionMode.SingleRow;
				CloseOnChoice = True;
			EndIf;
		EndIf;
		Items.SelectedDocumentsTableExportToFile.Visible = False;
		Items.SelectedDocumentsTableExportToArray.Visible = True;
		Items.SelectedDocumentsTableExportToArray.DefaultButton = True;
	EndIf;
	
	AvailableDocuments.Parameters.SetParameterValue("EDKindsList", EDKindsArray());
	
	GenerateTableRapidFilter();
	
	SetFiltersOnOpenningByDefault();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SetFiltersOnOpenningByDefault();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		Items.AvailableDocuments.Refresh();
		RefreshDataRepresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If NotExportedDocumentsExist AND SelectedDocumentsTable.Count() > 0 Then
		QuestionText = NStr("en='There are non-loaded documents in the choice list!
		|Do you really want to close the form?';ru='В списке выбора есть невыгруженные документы!
		|Выдействительно хотите закрыть форму?'");
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DYNAMIC FORM LIST EVENTS HANDLERS AvailableDocuments

&AtClient
Procedure AvailableDocumentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	RowArray = New Array;
	RowArray.Add(SelectedRow);
	
	AddToSelectedDocuments(RowArray);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Shortcut menu commands list forms AvailableDocuments

&AtClient
Procedure OpenDocumentFormAvailableList(Command)
	
	OpenDocumentToView(Items.AvailableDocuments.CurrentData);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DYNAMIC FORM LIST EVENTS HANDLERS SelectedDocumentsTable

&AtClient
Procedure OpenDocumentFormSelectedList(Command)
	
	OpenDocumentToView(Items.SelectedDocumentsTable.CurrentData);
	
EndProcedure

&AtClient
Procedure SelectedDocumentsTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.ReadOnly Then
		OpenDocumentToView(Items.SelectedDocumentsTable.CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectedDocumentsTableBasisDocumentNumberOnChange(Item)
	
	SetBasisDocumentFillingNeedSign();
	
EndProcedure

&AtClient
Procedure SelectedDocumentsTableBasisDocumentDateOnChange(Item)
	
	SetBasisDocumentFillingNeedSign();
	
EndProcedure

&AtClient
Procedure SelectedDocumentsTableDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	RowArray = DragParameters.Value;
	If RowArray.Count() > 0 AND TypeOf(RowArray[0]) = Type("CatalogRef.EDAttachedFiles") Then
		AddToSelectedDocuments(RowArray);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectedDocumentsTableBeforeAdding(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENTS HANDLERS TABLES FORMS QuickFilters

&AtClient
Procedure QuickFiltersValueOnChange(Item)
	
	SetFilters();
	If Item.Parent.CurrentData.Type = "Number" Then
		EnteredNumber = True;
	EndIf;
	
	OnFilterChange();
	
EndProcedure

&AtClient
Procedure QuickFiltersOnStartEdit(Item, NewRow, Copy)
	
	If Item.CurrentData.Value = Undefined Then
		Item.CurrentData.Value = 0;
	Else
		EnteredNumber = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure QuickFiltersOnEditEnd(Item, NewRow, CancelEdit)
	
	If Not EnteredNumber AND Item.CurrentData.Type = "Number" Then
		Item.CurrentData.Value = Undefined;
	EndIf;
	
	EnteredNumber = False;
	
EndProcedure

&AtClient
Procedure QuickFiltersValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Items.QuickFilters.CurrentData.Parameter = "EDKind" Then
		EDKindsList = New ValueList;
		EDKindsList.LoadValues(EDKindsArray());
		ChoiceData = EDKindsList;
		StandardProcessing = False;
	ElsIf Items.QuickFilters.CurrentData.Parameter = "EDDirection" Then
		DestinationsList = New ValueList;
		DestinationsList.Add(PredefinedValue("Enum.EDDirections.Incoming"));
		DestinationsList.Add(PredefinedValue("Enum.EDDirections.Outgoing"));
		ChoiceData = DestinationsList;
		StandardProcessing = False;
	EndIf
	
EndProcedure

&AtClient
Procedure QuickFiltersValueClearing(Item, StandardProcessing)

	DescriptionCounterpartiesCatalog = AppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;
	
	DescriptionCompanyCatalog = AppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;

	
	String = Items.QuickFilters.CurrentData;
	If String.Type = "String" Then
		String.Value = "";
	ElsIf String.Type = "Date" Then
		String.Value = Date(1, 1, 1);
	ElsIf String.Type = "Number" Then
		String.Value = Undefined;
	ElsIf String.Type = "EnumRef.EDKinds" Then
		String.Value = PredefinedValue("Enum.EDKinds.EmptyRef");
	ElsIf String.Type = "CatalogRef."+ DescriptionCounterpartiesCatalog Then
		String.Value = PredefinedValue("Catalog."+ DescriptionCounterpartiesCatalog +".EmptyRef");
	ElsIf String.Type = "CatalogRef." + DescriptionCompanyCatalog Then
		String.Value = PredefinedValue("Catalog." + DescriptionCompanyCatalog + ".EmptyRef");
	ElsIf String.Type = "CatalogRef.Users" Then
		String.Value = PredefinedValue("Catalog.Users.EmptyRef");
	ElsIf String.Type = "EnumRef.EDDirections" Then
		String.Value = PredefinedValue("Enum.EDDirections.EmptyRef");
	ElsIf String.Type = "EnumRef.EDVersionsStatuses" Then
		String.Value = PredefinedValue("Enum.EDVersionsStates.EmptyRef");
	EndIf;
	Items.QuickFilters.EndEditRow(False);
	
	SetFilters();
	
	OnFilterChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure Select(Command)
	
	RowArray = Items.AvailableDocuments.SelectedRows;
	AddToSelectedDocuments(RowArray);
	
EndProcedure

&AtClient
Procedure UnsetFilter(Command)
	
	DescriptionCounterpartiesCatalog = AppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;

	For Each String IN QuickFilters Do
		If String.Type = "String" Then
			String.Value = "";
		ElsIf String.Type = "Date" Then
			String.Value = Date(1,1,1);
		ElsIf String.Type = "Number" Then
			String.Value = Undefined;
		ElsIf String.Type = "EnumRef.EDKinds" Then
			String.Value = PredefinedValue("Enum.EDKinds.EmptyRef");
		ElsIf String.Type = "CatalogRef." + DescriptionCounterpartiesCatalog Then
			String.Value = PredefinedValue("Catalog." + DescriptionCounterpartiesCatalog + ".EmptyRef");
		ElsIf String.Type = "CatalogRef.Companies" Then
			String.Value = PredefinedValue("Catalog.Companies.EmptyRef");
		ElsIf String.Type = "CatalogRef.Users" Then
			String.Value = PredefinedValue("Catalog.Users.EmptyRef");
		ElsIf String.Type = "EnumRef.EDDirections" Then
			String.Value = PredefinedValue("Enum.EDDirections.EmptyRef");
		ElsIf String.Type = "EnumRef.EDVersionsStatuses" Then
			String.Value = PredefinedValue("Enum.EDVersionsStates.EmptyRef");
		EndIf;
	EndDo;
	
	SetFilters();
	
	SetCommandsEnabledOfFilterReset(False);
	
EndProcedure

&AtClient
Procedure ExportToFile(Command)
	
	Exporting();
	
EndProcedure

&AtClient
Procedure ExportToArray(Command)
	
	Exporting();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Filters

&AtClient
Procedure SetCommandsEnabledOfFilterReset(Enabled)
	
	Items.UnsetFilter.Enabled = Enabled;
	
EndProcedure

&AtClient
Procedure OnFilterChange()
	
	SetCommandsEnabledOfFilterReset(False);
	
	For Each String IN QuickFilters Do
		If ValueIsFilled(String.Value) OR TypeOf(String.Value) = Type("Number") Then
			SetCommandsEnabledOfFilterReset(True);
			Break;
		EndIf
	EndDo
	
EndProcedure

&AtClient
Procedure SetFilters()
	
	CommonUseClientServer.DeleteItemsOfFilterGroup(AvailableDocuments.Filter, "DocumentAmount");
	CommonUseClientServer.DeleteItemsOfFilterGroup(AvailableDocuments.Filter, "DocumentDate");
	
	SetDynamicListFilters(ThisObject, QuickFilters);
	
EndProcedure

&AtServer
Procedure GenerateTableRapidFilter()
	
	QuickFilters.Clear();
	
	DescriptionCounterpartiesCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;
	
	DescriptionCompanyCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;

	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Company";
	NewRow.ParameterPresentation = NStr("en='Company:';ru='Организация:'");
	NewRow.Type = "CatalogRef."+ DescriptionCompanyCatalog;
	NewRow.Value = ElectronicDocumentsReUse.GetEmptyRef("Companies");
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Counterparty";
	NewRow.ParameterPresentation = NStr("en='Counterparty:';ru='Контрагент:'");
	NewRow.Type = "CatalogRef."+ DescriptionCounterpartiesCatalog;
	NewRow.Value = ElectronicDocumentsReUse.GetEmptyRef("Counterparties");
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Date_From";
	NewRow.ParameterPresentation = NStr("en='Date from:';ru='Дата с:'");
	NewRow.Type = "Date";
	NewRow.Value = Date(1,1,1);
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Date_To";
	NewRow.ParameterPresentation = NStr("en='Date to:';ru='Дата по:'");
	NewRow.Type = "Date";
	NewRow.Value = Date(1,1,1);
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Amount_From";
	NewRow.ParameterPresentation = NStr("en='Amount from:';ru='Сумма с:'");
	NewRow.Type = "Number";
	NewRow.Value = Undefined;
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Amount_To";
	NewRow.ParameterPresentation = NStr("en='Amount to:';ru='Сумма по:'");
	NewRow.Type = "Number";
	NewRow.Value = Undefined;
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "EDKind";
	NewRow.ParameterPresentation = NStr("en='Document kind:';ru='Вид документа:'");
	NewRow.Type = "EnumRef.EDKinds";
	NewRow.Value = Enums.EDKinds.EmptyRef();
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "EDDirection";
	NewRow.ParameterPresentation = NStr("en='Direction:';ru='Направление:'");
	NewRow.Type = "EnumRef.EDDirections";
	NewRow.Value = Enums.EDDirections.EmptyRef();
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Responsible";
	NewRow.ParameterPresentation = NStr("en='Responsible person:';ru='Ответственный:'");
	NewRow.Type = "CatalogRef.Users";
	NewRow.Value = Users.AuthorizedUser();
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "EDVersionState";
	NewRow.ParameterPresentation = NStr("en='ED state:';ru='Состояние ЭД:'");
	NewRow.Type = "EnumRef.EDVersionsStatuses";
	NewRow.Value = Enums.EDVersionsStates.ExchangeCompleted;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetDynamicListFilters(Form, Filters)
	
	For Each FilterRow IN Filters Do
		If FilterRow.Parameter = "Responsible" Then
			CommonUseClientServer.SetFilterItem(
												Form.AvailableDocuments.Filter,
												"Responsible",
												FilterRow.Value,
												DataCompositionComparisonType.Equal,
												,
												ValueIsFilled(FilterRow.Value));
		ElsIf FilterRow.Parameter = "Counterparty" Then
			CommonUseClientServer.SetFilterItem(
												Form.AvailableDocuments.Filter,
												"Counterparty",
												FilterRow.Value,
												DataCompositionComparisonType.Equal,
												,
												ValueIsFilled(FilterRow.Value));
		ElsIf FilterRow.Parameter = "Company" Then
			CommonUseClientServer.SetFilterItem(
												Form.AvailableDocuments.Filter,
												"Company",
												FilterRow.Value,
												DataCompositionComparisonType.Equal,
												,
												ValueIsFilled(FilterRow.Value));
		ElsIf FilterRow.Parameter = "EDDirection" Then
			CommonUseClientServer.SetFilterItem(
												Form.AvailableDocuments.Filter,
												"EDDirection",
												FilterRow.Value,
												DataCompositionComparisonType.Equal,
												,
												ValueIsFilled(FilterRow.Value));
		ElsIf FilterRow.Parameter = "EDKind" Then
			CommonUseClientServer.SetFilterItem(
												Form.AvailableDocuments.Filter,
												"EDKind",
												FilterRow.Value,
												DataCompositionComparisonType.Equal,
												,
												ValueIsFilled(FilterRow.Value));
		ElsIf FilterRow.Parameter = "Amount_From"
				AND (ValueIsFilled(FilterRow.Value) OR FilterRow.Value = 0) Then
			CommonUseClientServer.AddCompositionItem(
															Form.AvailableDocuments.Filter,
															"DocumentAmount",
															DataCompositionComparisonType.GreaterOrEqual,
															FilterRow.Value);
		ElsIf FilterRow.Parameter = "Amount_To"
				AND (ValueIsFilled(FilterRow.Value) OR FilterRow.Value = 0) Then
			CommonUseClientServer.AddCompositionItem(
															Form.AvailableDocuments.Filter,
															"DocumentAmount",
															DataCompositionComparisonType.LessOrEqual,
															FilterRow.Value);
		ElsIf FilterRow.Parameter = "Date_From" AND ValueIsFilled(FilterRow.Value) Then
			CommonUseClientServer.AddCompositionItem(
													Form.AvailableDocuments.Filter,
													"DocumentDate",
													DataCompositionComparisonType.GreaterOrEqual,
													BegOfDay(FilterRow.Value));
		ElsIf FilterRow.Parameter = "Date_To" AND ValueIsFilled(FilterRow.Value) Then
			CommonUseClientServer.AddCompositionItem(
													Form.AvailableDocuments.Filter,
													"DocumentDate",
													DataCompositionComparisonType.LessOrEqual,
													EndOfDay(FilterRow.Value));
		ElsIf FilterRow.Parameter = "EDVersionState" Then
			CommonUseClientServer.SetFilterItem(
												Form.AvailableDocuments.Filter,
												"EDVersionState",
												FilterRow.Value,
												DataCompositionComparisonType.Equal,
												,
												ValueIsFilled(FilterRow.Value));
		EndIf;
	EndDo
	
EndProcedure

&AtServer
Procedure SetFiltersOnOpenningByDefault()
	
	If Parameters.Property("EDDirection") Then
		Filter = New Structure("Parameter", "EDDirection");
		RowArray = QuickFilters.FindRows(Filter);
		If RowArray.Count() > 0 Then
			RowArray[0].Value = Parameters.EDDirection;
		EndIf;
	EndIf;
	
	If Parameters.Property("DocumentKind") Then
		Filter = New Structure("Parameter", "EDKind");
		RowArray = QuickFilters.FindRows(Filter);
		If RowArray.Count() > 0 Then
			RowArray[0].Value = EDKindByEnumeration(Parameters.DocumentKind);
		EndIf;
	EndIf;
	
	If Parameters.Property("Company") Then
		Filter = New Structure("Parameter", "Company");
		RowArray = QuickFilters.FindRows(Filter);
		If RowArray.Count() > 0 Then
			RowArray[0].Value = Parameters.Company;
		EndIf;
	EndIf;
	
	If Parameters.Property("Counterparty") Then
		Filter = New Structure("Parameter", "Counterparty");
		RowArray = QuickFilters.FindRows(Filter);
		If RowArray.Count() > 0 Then
			RowArray[0].Value = Parameters.Counterparty;
		EndIf;
	EndIf;
	
	Filter = New Structure("Parameter", "EDVersionState");
	RowArray = QuickFilters.FindRows(Filter);
	If RowArray.Count() > 0 Then
		RowArray[0].Value = Enums.EDVersionsStates.ExchangeCompleted;
	EndIf;
	
	SetDynamicListFilters(ThisObject, QuickFilters);
	
EndProcedure

// SelectedDocumentsTable

&AtClient
Procedure AddToSelectedDocuments(RowArray)
	
	EDKindAct = PredefinedValue("Enum.EDKinds.ActPerformer");
	EDStatusExchangeCompleted = PredefinedValue("Enum.EDVersionsStates.ExchangeCompleted");
	RefArray = New Array;
	MessagePattern = NStr("en='Electronic document flow for the ""%1"" document is not completed.';ru='Для документа ""%1"" не завершён электронный документооборот!'");
	MessageText = "";
	For Each String IN RowArray Do
		RowData = Items.AvailableDocuments.RowData(String);
		SearchStructure = New Structure;
		SearchStructure.Insert("ElectronicDocument", RowData.ElectronicDocument);
		FoundStrings = SelectedDocumentsTable.FindRows(SearchStructure);
		
		If FoundStrings.Count() = 0 Then
			NotExportedDocumentsExist = True;
			If RowData.EDVersionState <> EDStatusExchangeCompleted Then
				MessageText = MessageText
					+ ?(ValueIsFilled(MessageText), Chars.LF, "") + StrReplace(MessagePattern, "%1", RowData.Document);
			EndIf;
			NewRow = SelectedDocumentsTable.Add();
			FillPropertyValues(NewRow, RowData);
			If RowData.EDKind = EDKindAct Then
				RefArray.Add(RowData.Document);
				NewRow.RequiredFillSourceDocument = Not (ValueIsFilled(NewRow.BasisDocumentNumber)
					AND ValueIsFilled(NewRow.BasisDocumentDate));
			EndIf;
		EndIf;
	EndDo;
	If RefArray.Count() > 0 Then
		Map = BasisDocumentDataMap(RefArray);
		If Map.Count() <> 0 Then
			For Each DocumentRef IN RefArray Do
				SearchStructure = New Structure;
				SearchStructure.Insert("Document", DocumentRef);
				FoundStrings = SelectedDocumentsTable.FindRows(SearchStructure);
				Structure = Map.Get(DocumentRef);
				If TypeOf(Structure) <> Type("Structure") Then
					Structure = New Structure;
				EndIf;
				For Each String IN FoundStrings Do
					Structure.Property("ContractNo", String.BasisDocumentNumber);
					Structure.Property("ContractDate", String.BasisDocumentDate);
					FillBasisDocument = Not (ValueIsFilled(String.BasisDocumentNumber)
													AND ValueIsFilled(String.BasisDocumentDate));
					String.RequiredFillSourceDocument = FillBasisDocument;
				EndDo;
			EndDo;
		EndIf;
	EndIf;
	If VersionCall <> 1 AND Multiselect = False AND SelectedDocumentsTable.Count() > 0 Then
		If ValueIsFilled(MessageText) Then
			QuestionText = MessageText + Chars.LF + NStr("en='Continue exporting?';ru='Продолжить выгрузку?'");
			AdditParameters = New Structure("MessageText", MessageText);
			NotifyDescription = New NotifyDescription("CompleteAdditionToSelectedDocuments", ThisObject, AdditParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, 30, DialogReturnCode.No);
			MessageText = "";
		Else
			Exporting();
		EndIf;
	EndIf;
	If ValueIsFilled(MessageText) Then
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function BasisDocumentDataMap(RefArray)
	
	Map = New Map;
	ElectronicDocumentsOverridable.GetNumberDateContractDocuments(RefArray, Map);
	If TypeOf(Map) <> Type("Map") Then
		Map = New Map;
	EndIf;
	Return Map;
	
EndFunction

// Creating import file

&AtServerNoContext
Function CreateImportFile(Val DocumentsTable)
	
	MapFileDataAddressInStorage = New Map;
	VT = DocumentsTable.Unload();
	
	VTCompanies = VT.Copy(, "Company");
	VTCompanies.GroupBy("Company");
	VTInventory = StructureTablesInventory();
	For Each StringCompany IN VTCompanies Do
		Company = StringCompany.Company;
		DirectoryAddress = ElectronicDocumentsService.WorkingDirectory("Send", Company.UUID());
		DeleteFiles(DirectoryAddress, "*");
		Filter = New Structure("Company", Company);
		RowArray = VT.FindRows(Filter);
		For Each VTRow IN RowArray Do
			AccordanceFileED = New Map;
			VTInventoryString = VTInventory.Add();
			FillPropertyValues(VTInventoryString, VTRow);
			ED = VTRow.ElectronicDocument;
			FileData = ElectronicDocumentsService.GetFileData(ED);
			ElectronicDocumentsService.SaveWithDS(ED, FileData, DirectoryAddress, AccordanceFileED);
			DataFileFound = False;
			SignatureFileFound = False;
			For Each MapItem IN AccordanceFileED Do
				If Find(MapItem.Key, ".xml") > 0 Then
					VTInventoryString.DataFileName = TrimAll(MapItem.Key);
					Files = FindFiles(DirectoryAddress, MapItem.Key);
					If Files.Count() > 0 Then
						File = New File(Files[0].FullName);
						VTInventoryString.DataFileSize = File.Size();
						DataFileFound = True;
						Break;
					EndIf;
				EndIf;
			EndDo;
			If DataFileFound Then
				Files = FindFiles(DirectoryAddress, ED.Description + "*.p7s");
				If Files.Count() = 0 Then
					MessageText = NStr("en='Not managed to import the signature for
		|the electronic document ""%1"", created on the basis of the document ""%2""!';ru='Не удалось выгрузить подпись для электронного документа ""%1"",
		|сформированного на основании документа ""%2""!'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ED, VTRow.Document);
					CommonUseClientServer.MessageToUser(MessageText);
				Else
					SignatureFileFound = True;
					SignatureFile = Files[0];
					VTInventoryString.SignatureFileName = FileData.Description + "SGN.sgn";
					MoveFile(SignatureFile.FullName, SignatureFile.Path + VTInventoryString.SignatureFileName);
					File = New File(SignatureFile.Path + VTInventoryString.SignatureFileName);
					VTInventoryString.SignatureFileSize = File.Size();
				EndIf;
			Else
				MessageText = NStr("en='Not managed to import the
		|electronic document ""%1"",created on the basis of the document ""%2""!';ru='Не удалось выгрузить подпись для электронного документа ""%1"",
		|сформированного на основании документа ""%2""!'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ED, VTRow.IBDocument);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
			If Not(DataFileFound AND SignatureFileFound) Then
				VTInventory.Delete(VTInventoryString);
			EndIf;
		EndDo;
		
		Files = FindFiles(DirectoryAddress, "*");
		If Files.Count() = 0 Then
			MessageText = NStr("en='Cannot import documents for Company ""%1"".';ru='Не удалось выгрузить документы по Организации ""%1""!'");
			MessageText = StrReplace(MessageText, "%1", Company);
			CommonUseClientServer.MessageToUser(MessageText);
			DeleteFiles(DirectoryAddress);
			Continue;
		EndIf;
		
		FileNameArray = New Array;
		For Each FoundFile IN Files Do
			
			FileNameArray.Add(FoundFile.Name);
		EndDo;
		
		CompanyAttributes = CommonUse.ObjectAttributesValues(Company, "TIN");
		TIN = TrimAll(CompanyAttributes.TIN);
		SenderID = TIN;
		IDImport = Format(CurrentSessionDate(), "DF=YyyyMMddHHMMss");
		FileName = "EDI_" + SenderID + "_" + IDImport;
		FileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(FileName);
		ZipContainer = New ZipFileWriter(DirectoryAddress + FileName + ".zip");
		
		For Each File IN Files Do
			ZipContainer.Add(File.FullName);
		EndDo;
		
		If ImportDescriptionFile(Company, VTInventory, DirectoryAddress) Then
			ZipContainer.Add(DirectoryAddress + "definition.xml");
			
			ZipContainer.Write();
			
			DDImport = New BinaryData(DirectoryAddress + FileName + ".zip");
			ZipFile = New File(DirectoryAddress + FileName + ".zip");
			FileData = New Structure("FileName, Extension, Size",
				ZipFile.Name, ZipFile.Extension, ZipFile.Size());
			AddressInStorage = PutToTempStorage(DDImport, Company.UUID());
			
			MapFileDataAddressInStorage.Insert(FileData, AddressInStorage);
		EndIf;
		
		DeleteFiles(DirectoryAddress);
	EndDo;
	
	Return MapFileDataAddressInStorage;
	
EndFunction

&AtServerNoContext
Function ImportDescriptionFile(Company, VTInventory, DirectoryAddress)
	
	ErrorText = "";
	CompanyAttributes = CommonUse.ObjectAttributesValues(Company, "Name, TIN");
	TIN = TrimAll(CompanyAttributes.TIN);
	TargetNamespaceSchema = "Import2Statements";
	Try
		File = ElectronicDocumentsInternal.GetCMLObjectType("File", TargetNamespaceSchema);
		
		FileOnDrive = New File(DirectoryAddress + "definition.xml");
		
		ElectronicDocumentsInternal.FillXDTOProperty(File, "VersForm", "1.00", True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(File, "ExportDate", Format(CurrentSessionDate(), "DF=dd.MM.yyyy"), True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(File, "ImportTime", Format(CurrentSessionDate(), "DF=HH.mm.cc"), True, ErrorText);
		
		SvCompany = ElectronicDocumentsInternal.GetCMLObjectType("File.Company", TargetNamespaceSchema);
		
		ElectronicDocumentsInternal.FillXDTOProperty(SvCompany, "Description", CompanyAttributes.Description, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(SvCompany, "TIN", CompanyAttributes.TIN, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(File, "Company", SvCompany, True, ErrorText);
		
		SvCounterparties = ElectronicDocumentsInternal.GetCMLObjectType("File.Counterparties", TargetNamespaceSchema);
		Counterparty = "";
		CounterpartID = "";
		For Each InventoryString IN VTInventory Do
			If InventoryString.Counterparty <> Counterparty Then
				svCounterparty = ElectronicDocumentsInternal.GetCMLObjectType("File.Counterparties.Counterparty", TargetNamespaceSchema);
				Counterparty = InventoryString.Counterparty;
				CounterpartyAttributes = CommonUse.ObjectAttributesValues(Counterparty, "Name, TIN");
				ElectronicDocumentsInternal.FillXDTOProperty(svCounterparty, "ID", CounterpartID, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(svCounterparty, "Description", CounterpartyAttributes.Description, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(svCounterparty, "TIN", CounterpartyAttributes.TIN, True, ErrorText);
				SvCounterparties.Counterparty.Add(svCounterparty);
			EndIf;
			SvDocument = ElectronicDocumentsInternal.GetCMLObjectType("File.Document", TargetNamespaceSchema);
			
			DocumentKind = DocumentKindByEDKind(InventoryString.EDKind);
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "Kind", DocumentKind, True, ErrorText);
			CTD = CTDOnEDKind(InventoryString.EDKind);
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "CTD", CTD, True, ErrorText);
			Direction = ?(InventoryString.EDDirection = Enums.EDDirections.Incoming, "0", "1");
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "Direction", Direction, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "Number", InventoryString.DocumentNumber, True, ErrorText);
			DocDate = Format(InventoryString.DocumentDate, "DF=dd.MM.yyyy");
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "Date", DocDate, True, ErrorText);
			If ValueIsFilled(InventoryString.BasisDocumentDate)
				AND ValueIsFilled(InventoryString.BasisDocumentNumber) Then
				ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "BasDocNo", InventoryString.BasisDocumentNumber, , ErrorText);
				DocDate = Format(InventoryString.BasisDocumentDate, "DF=dd.MM.yyyy");
				ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "BasDocDate", DocDate, , ErrorText);
			EndIf;
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "CounterpartyId", CounterpartID, True, ErrorText);
			
			SvFile = ElectronicDocumentsInternal.GetCMLObjectType("File.Document.FileDoc", TargetNamespaceSchema);
			
			ElectronicDocumentsInternal.FillXDTOProperty(SvFile, "Name", InventoryString.DataFileName, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(SvFile, "Size", InventoryString.DataFileSize, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "FileDoc", SvFile, True, ErrorText);
			
			SvFile = ElectronicDocumentsInternal.GetCMLObjectType("File.Document.EDSFile", TargetNamespaceSchema);
			
			ElectronicDocumentsInternal.FillXDTOProperty(SvFile, "Name", InventoryString.SignatureFileName, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(SvFile, "Size", InventoryString.SignatureFileSize, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(SvDocument, "EDSFile", SvFile, True, ErrorText);
			
			File.Document.Add(SvDocument);
		EndDo;
		ElectronicDocumentsInternal.FillXDTOProperty(File, "Counterparties", SvCounterparties, True, ErrorText);
		
		File.Validate();
		If ValueIsFilled(ErrorText) Then
			Raise ErrorText;
		EndIf;
		
		ElectronicDocumentsInternal.ExportEDtoFile(File, DirectoryAddress + "definition.xml", False, "windows-1251");
		Return True;
	Except
		MessagePattern = NStr("en='%1 (for more information, see Event log).';ru='%1 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
			?(ValueIsFilled(ErrorText), ErrorText, BriefErrorDescription(ErrorInfo())));
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='Generate ED import into 1C:Reporting';ru='Формирование выгрузки ЭД в 1с-Отчетность'"),
																					DetailErrorDescription(ErrorInfo()),
																					MessageText);
		
		Return False;
	EndTry;
	
EndFunction

&AtServerNoContext
Function StructureTablesInventory()
	
	VT = New ValueTable;
	
	VT.Columns.Add("Document");
	VT.Columns.Add("Counterparty");
	VT.Columns.Add("EDKind");
	VT.Columns.Add("CTD");
	VT.Columns.Add("EDDirection");
	VT.Columns.Add("DocumentNumber");
	VT.Columns.Add("DocumentDate");
	VT.Columns.Add("BasisDocumentNumber");
	VT.Columns.Add("BasisDocumentDate");
	VT.Columns.Add("DataFileName");
	VT.Columns.Add("SignatureFileName");
	VT.Columns.Add("DataFileSize");
	VT.Columns.Add("SignatureFileSize");
	
	Return VT;
	
EndFunction

&AtServerNoContext
Function DocumentKindByEDKind(EDKind)
	
	DocumentKind = Undefined;
	If EDKind = Enums.EDKinds.ActPerformer Then
		DocumentKind = "02";
	ElsIf EDKind = Enums.EDKinds.TORG12Seller Then
		DocumentKind = "03";
	EndIf;
	
	Return DocumentKind;
	
EndFunction

&AtServerNoContext
Function CTDOnEDKind(EDKind)
	
	CTD = Undefined;
	If EDKind = Enums.EDKinds.ActPerformer Then
		CTD = "1175006";
	ElsIf EDKind = Enums.EDKinds.TORG12Seller Then
		CTD = "1175004";
	EndIf;
	
	Return CTD;
	
EndFunction

// Other

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		NotExportedDocumentsExist = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure CompleteAdditionToSelectedDocuments(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		SelectedDocumentsTable.Clear();
	Else
		MessageText = "";
		If TypeOf(AdditionalParameters) = Type("Structure")
			AND AdditionalParameters.Property("MessageText", MessageText)
			AND ValueIsFilled(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		Exporting();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetBasisDocumentFillingNeedSign()
	
	CurrentData = Items.SelectedDocumentsTable.CurrentData;
	CurrentData.RequiredFillSourceDocument = Not (ValueIsFilled(CurrentData.BasisDocumentNumber) 
		AND ValueIsFilled(CurrentData.BasisDocumentDate));
	
EndProcedure

&AtClient
Function EDKindByString(EDKind)
	
	EDKindByString = Undefined;
	If EDKind = PredefinedValue("Enum.EDKinds.ActPerformer") Then
		EDKindByString = "AcceptanceCertificate";
	ElsIf EDKind = PredefinedValue("Enum.EDKinds.TORG12Seller") Then
		EDKindByString = "TORG12DeliveryNote";
	EndIf;
	
	Return EDKindByString;
	
EndFunction

&AtServer
Function EDKindByEnumeration(EDKind)
	
	ReturnedEDKind = Undefined;
	If TypeOf(EDKind) = Type("EnumRef.EDKinds") Then
		ReturnedEDKind = EDKind;
	ElsIf EDKind = "AcceptanceCertificate" Then
		ReturnedEDKind = Enums.EDKinds.ActPerformer;
	ElsIf EDKind = "TORG12DeliveryNote" Then
		ReturnedEDKind = Enums.EDKinds.TORG12Seller;
	EndIf;
	
	Return ReturnedEDKind;
	
EndFunction

&AtServerNoContext
Function EDKindsArray()
	
	EDKindsArray = New Array;
	EDKindsArray.Add(Enums.EDKinds.TORG12Seller);
	EDKindsArray.Add(Enums.EDKinds.ActPerformer);
	
	Return EDKindsArray;
	
EndFunction

&AtServerNoContext
Function AppliedCatalogName(Description)
	
	Return ElectronicDocumentsReUse.GetAppliedCatalogName(Description);
	
EndFunction

&AtClient
Procedure OpenDocumentToView(SelectedRow)
	
	If SelectedRow <> Undefined Then
		ShowValue(, SelectedRow.Document);
	EndIf;
	
EndProcedure

&AtClient
Procedure HandleAnswerToTheQuestionOnGroundsOf(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		If VersionCall = 1 Then
			Map = CreateImportFile(SelectedDocumentsTable);
			If Map.Count() > 0 Then
				FullFileName = "";
#If Not WebClient Then
				ChoiceDialog = New FileDialog(FileDialogMode.ChooseDirectory);
				ChoiceDialog.Title = NStr("en='Select a directory to save the export file (files)';ru='Выберите каталог для сохранения файла (файлов) выгрузки'");
				ChoiceDialog.FullFileName = "";
				If Not ChoiceDialog.Choose() Then
					Return;
				EndIf;
#EndIf
				AllDocumentsImported = True;
				For Each Item IN Map Do
#If WebClient Then
					FileData = Item.Key;
					FileData.Insert("FileBinaryDataRef", Item.Value);
					AttachedFilesClient.SaveFileAs(FileData);
#Else
					DDImport = GetFromTempStorage(Item.Value);
					FullFileName = FileFunctionsServiceClient.NormalizeDirectory(ChoiceDialog.Directory)
									+ Item.Key.FileName;
					DDImport.Write(FullFileName);
					RecordedFile = New File(FullFileName);
					AllDocumentsImported = AllDocumentsImported AND RecordedFile.Exist();
#EndIf
				EndDo;
				NotExportedDocumentsExist = Not AllDocumentsImported;
			EndIf;
		Else
			NotExportedDocumentsExist = False;
			If VersionCall = 2 Then
				RefArray = New Array;
				For Each String IN SelectedDocumentsTable Do
					RefArray.Add(String.Document);
				EndDo;
				NotifyChoice(RefArray);
			Else
				StructuresArray = New Array;
				For Each String IN SelectedDocumentsTable Do
					Structure = New Structure;
					Structure.Insert("RefIBDocument", String.Document);
					Structure.Insert("DocumentKind", EDKindByString(String.EDKind));
					Structure.Insert("ContractNo", String.BasisDocumentNumber);
					Structure.Insert("ContractDate", String.BasisDocumentDate);
					StructuresArray.Add(Structure);
				EndDo;
				Notify("ClosedIBDocumentsChoiceFormForTransfertoFTS", StructuresArray);
				Close();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure Exporting()
	
	If SelectedDocumentsTable.Count() = 0 Then
		MessageText = NStr("en='At least one document is required to generate export.';ru='Для формирования выгрузки необходимо выбрать хотя бы один документ.'");
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		Filter = New Structure("RequiredFillSourceDocument", True);
		FoundStrings = SelectedDocumentsTable.FindRows(Filter);
		NotifyDescription = New NotifyDescription("HandleAnswerToTheQuestionOnGroundsOf", ThisObject);
		If FoundStrings.Count() > 0 Then
			QuestionText = NStr("en='The list of selected documents has the
		|documents of the type ""%1"" with the blank basis documents attributes (number, date)!
		|Continue importing?';ru='В списке выбранных документов, присутствуют
		|документы вида ""%1"", с незаполненными реквизитами документов-оснований (номер, дата)!
		|Продолжить выгрузку?'");
			QuestionText = StrReplace(QuestionText, "%1", FoundStrings[0].EDKind);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, 30, DialogReturnCode.No);
		Else
			ExecuteNotifyProcessing(NOTifyDescription, DialogReturnCode.Yes);
		EndIf;
	EndIf;
	
EndProcedure