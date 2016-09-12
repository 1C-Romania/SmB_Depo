////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	TableOfDocuments = GetTableOfDocumentsOutOfContext();
	DataExchangeServer.NodesSettingFormOnCreateAtServer(ThisForm, Cancel);
	
	DocumentKinds.Load(TableOfDocuments);
	
	For Each TableRow IN Companies Do
		Try
			CompanyID = New UUID(TableRow.RefUUID);
			TableRow.Company = Catalogs.Companies.GetRef(CompanyID);
		Except
		EndTry;
	EndDo;
	
	SynchronizationMode = 
		?(NOT ManualExchange, "AutomaticSynchronization", "ManualSynchronization")
	;
	
	CompaniesSyncMode =
		?(UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies")
	;
	
	DocumentSynchronizationMode =
		?(UseDocumentTypesFilter, "DataSynchronizeOnlyForSelectedOfDocumentKinds", "SynchronizateDataByAllDocuments")
	;
	
	SetVisibleAtServer();
	OnChangeOfDataSynchronization();
	RefreshDescriptionCommandsForms();
	
	GetContextDetails();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SettingFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	UpdateObjectData(ValueSelected);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure WriteAndClose(Command)
	
	ManualExchange = 
		?(SynchronizationMode = "AutomaticSynchronization", False, True)
	;
	
	If SynchronizationMode <> "AutomaticSynchronization" Then
		
		UseCompaniesFilter = False;
		Companies.Clear();
		
		UseDocumentTypesFilter = False;
		DocumentKinds.Clear();
		
	Else
		
		If Companies.Count() > 0 Then
			If CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly" Then
				UseCompaniesFilter = True;
			Else
				UseCompaniesFilter = False;
				Companies.Clear();
			EndIf;
		Else
			UseCompaniesFilter = False;
		EndIf;
		
		If DocumentKinds.Count() > 0 Then
			If DocumentSynchronizationMode = "DataSynchronizeOnlyForSelectedOfDocumentKinds" Then
				UseDocumentTypesFilter = True;
			Else
				UseDocumentTypesFilter = False;
				DocumentKinds.Clear();
			EndIf;
		Else
			UseDocumentTypesFilter = False;
		EndIf;
		
	EndIf;
	
	GetContextDetails();
	
	Modified = False;
	
	Close(ExportContextForms());
	
EndProcedure

&AtClient
Procedure OpenFilterFormByCompanies(Command)
	
	FormParameters = New Structure();
	FormParameters.Insert("CompaniesArray", GetObjectArrayTableParts("Companies", "Company"));
	
	OpenForm("ExchangePlan.ExchangeSmallBusinessAccounting30.Form.ChoiceFormCompanies",
		FormParameters,
		ThisForm);
	
EndProcedure

&AtClient
Procedure SynchronizationModeCompanyOnChange(Item)
	
	SetVisibleAtServer();
	
EndProcedure

&AtClient
Procedure DocumentSynchronizationModeOnChange(Item)
	
	If DocumentSynchronizationMode = "SynchronizeDataOnlyOnDocumentsSelectedManually" Then
		DirectionSynchronization = "SingleSidedSynchronisation";
	EndIf;
	
	SetVisibleAtServer();
	
EndProcedure

&AtClient
Procedure OpenFormFilterByDocumentTypes(Command)
	
	FormParameters = New Structure();
	FormParameters.Insert("DocumentKinds", GetObjectArrayTableParts("DocumentKinds", "MetadataObjectName"));
	
	OpenForm("ExchangePlan.ExchangeSmallBusinessAccounting30.Form.DocumentKindsChoiceForm",
		FormParameters,
		ThisForm);
		
EndProcedure

&AtClient
Procedure CompanyFilterClean(Command)
	
	HeaderText = NStr("en='Confirmation';ru='Подтверждение'");
	QuestionText   = NStr("en='Do you want to clear the filter by companies?';ru='Очистить отбор по организациям?'");
	Response = Undefined;

	ShowQueryBox(New NotifyDescription("ClearFilterByCompanyEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
	
EndProcedure

&AtClient
Procedure ClearFilterByCompanyEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response=DialogReturnCode.Yes Then
        Companies.Clear();
        SetVisibleAtServer();
        RefreshDescriptionCommandsForms();
    EndIf;

EndProcedure

&AtClient
Procedure ClearDocumentTypesFilter(Command)
	
	HeaderText = NStr("en='Confirmation';ru='Подтверждение'");
	QuestionText   = NStr("en='Do you want to clear the filter by document types?';ru='Очистить отбор по видам документов?'");
	Response = Undefined;

	ShowQueryBox(New NotifyDescription("ClearFilterByDocumentKindEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
	
EndProcedure

&AtClient
Procedure ClearFilterByDocumentKindEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response=DialogReturnCode.Yes Then
        DocumentKinds.Clear();
        SetVisibleAtServer();
        RefreshDescriptionCommandsForms();
    EndIf;

EndProcedure

&AtClient
Procedure AutomaticSynchronizationOnChange(Item)
	
	OnChangeOfDataSynchronization();
	
EndProcedure

&AtClient
Procedure ManualSynchronizationOnChange(Item)
	
	OnChangeOfDataSynchronization();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure SetVisibleAtServer()
	
	//Visible of filter by company
	If Not GetFunctionalOption("MultipleCompaniesAccounting") Then
		Items.CompaniesFilterGroup.Visible = False;
	Else
		Items.CompaniesFilterGroup.Visible = True;
		FilterByCompaniesInUse = CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly";
		FilterByCompaniesConfigured = Companies.Count() > 0;
		Items.OpenFilterFormByCompanies.Visible = FilterByCompaniesInUse;
		Items.CompanyFilterClean.Visible = FilterByCompaniesInUse AND FilterByCompaniesConfigured;
	EndIf;
	
	//Visible of filter by document kind
	DocumentTypesFilterInUse = DocumentSynchronizationMode = "DataSynchronizeOnlyForSelectedOfDocumentKinds";
	DocumentTypesFilterConfigured = DocumentKinds.Count() > 0;
	Items.OpenFormFilterByDocumentTypes.Visible = DocumentTypesFilterInUse;
	Items.ClearDocumentTypesFilter.Visible = DocumentTypesFilterInUse AND DocumentTypesFilterConfigured;

EndProcedure

&AtServer
Function GetObjectArrayTableParts(TabularSectionName, ColumnName)

	Return ThisForm[TabularSectionName].Unload().UnloadColumn(ColumnName);

EndFunction

&AtServer
Procedure UpdateObjectData(ParametersStructure)
	
	TableNameForFill = ParametersStructure.TableNameForFill;
	
	ThisForm[TableNameForFill].Clear();
	
	SelectedValuesList = GetFromTempStorage(ParametersStructure.AddressTableInTemporaryStorage);
	
	If SelectedValuesList.Count() > 0 Then
		ThisForm[TableNameForFill].Load(SelectedValuesList);
	EndIf;
	
	For Each TableRow IN ThisForm[TableNameForFill] Do
		TableRow.Use = True;
		If TableNameForFill = "Companies" Then
			TableRow.RefUUID = TableRow.Company.UUID();
		EndIf;
	EndDo;
	
	SetVisibleAtServer();
	RefreshDescriptionCommandsForms();
	
EndProcedure

&AtServer
Procedure RefreshDescriptionCommandsForms()
	
	//Update the title of selected companies
	If Companies.Count() > 0 Then
		
		SelectedCompanies = Companies.Unload().UnloadColumn("Company");
		NewTitleCompanies = ExchangePlans.ExchangeSmallBusinessAccounting30.ShortPresentationOfCollectionsOfValues(SelectedCompanies);
		
	Else
		
		NewTitleCompanies = NStr("en='Select companies ';ru='Выбрать организации '");
		
	EndIf;
	
	Items.OpenFilterFormByCompanies.Title = NewTitleCompanies;
	
	//Update the title of selected document kinds
	If DocumentKinds.Count() > 0 Then
		
		SelectedDocumentKinds = DocumentKinds.Unload().UnloadColumn("Presentation");
		NewTitleOfDocuments = ExchangePlans.ExchangeSmallBusinessAccounting30.ShortPresentationOfCollectionsOfValues(SelectedDocumentKinds);
		
	Else
		
		NewTitleOfDocuments = NStr("en='Select documents types ';ru='Выбрать виды документов '");
		
	EndIf;
	
	Items.OpenFormFilterByDocumentTypes.Title = NewTitleOfDocuments;
	
EndProcedure

&AtServer
Procedure GetContextDetails()
	
	TextDescription = NStr("en='All normative-reference information is automatically registered for sending;';ru='Вся нормативно-справочная информация автоматически регистрируется к отправке;'");
	
	If ManualExchange Then
		
		TextDescription = NStr("en='User individually selects and registers the documents for sending;';ru='Пользователь самостоятельно отбирает и регистрирует документы к отправке;'");
		
	Else
		
		If UseDocumentTypesFilter Then
			TextDescription = TextDescription + Chars.LF + NStr("en='Documents are automatically registered for sending:';ru='Документы автоматически регистрируются к отправке:'");
		Else
			TextDescription = TextDescription + Chars.LF + NStr("en='All the documents are automatically registered for sending:';ru='Все документы автоматически регистрируются к отправке:'");
		EndIf;
		
		If ValueIsFilled(DocumentsDumpStartDate) Then
			TextDescription = TextDescription + Chars.LF + NStr("en='since %StartDate%';ru='начиная с %ДатаНачала%'");
			TextDescription = StrReplace(TextDescription,"%StartDate%", Format(DocumentsDumpStartDate, "DF=dd.MM.yyyy"));
		EndIf;
		
		If UseCompaniesFilter Then
			CollectionValues = Companies.Unload().UnloadColumn("Company");
			PresentationCollections = ExchangePlans.ExchangeSmallBusinessAccounting30.ShortPresentationOfCollectionsOfValues(CollectionValues);
			TextDescription = TextDescription + Chars.LF + NStr("en='with filter by companies: %CollectionPresentation%';ru='с отбором по организациям: %ПредставлениеКоллекции%'");
			TextDescription = StrReplace(TextDescription, "%CollectionPresentation%", PresentationCollections);
		Else
			TextDescription = TextDescription + Chars.LF + NStr("en='By all companies';ru='по всем организациям'");
		EndIf;
		
		If UseDocumentTypesFilter Then
			CollectionValues = DocumentKinds.Unload().UnloadColumn("Presentation");
			PresentationCollections = ExchangePlans.ExchangeSmallBusinessAccounting30.ShortPresentationOfCollectionsOfValues(CollectionValues);
			TextDescription = TextDescription + Chars.LF + NStr("en='with filter by document kinds: %CollectionPresentation%';ru='с отбором по видам документов: %ПредставлениеКоллекции%'");
			TextDescription = StrReplace(TextDescription, "%CollectionPresentation%", PresentationCollections);
		EndIf;
		
	EndIf;
	
	ContextDetails = TextDescription;
	
EndProcedure

&AtClient
Function ExportContextForms()
	
	NameArrayMetadataObjects = New Array;
	PresentationArray = New Array;
	
	For Each TableRow IN DocumentKinds Do
		NameArrayMetadataObjects.Add(TableRow.MetadataObjectName);
		PresentationArray.Add(TableRow.Presentation);
	EndDo;
	
	FilterStructureByTypesOfDocuments = New Structure;
	FilterStructureByTypesOfDocuments.Insert("MetadataObjectName", NameArrayMetadataObjects);
	FilterStructureByTypesOfDocuments.Insert("Presentation", PresentationArray);
	
	//Save the entered values of this application.
	SettingsStructure = ThisObject.Context.FilterSsettingsAtNode;
	CorrespondingAttributes = ThisObject.AttributeNames;
	
	For Each SettingItem IN SettingsStructure Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			
			AttributeName = CorrespondingAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = ThisObject[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item IN ThisObject[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, ThisObject[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	SettingsStructure.DocumentKinds		   = FilterStructureByTypesOfDocuments;
	ThisObject.Context.FilterSsettingsAtNode = SettingsStructure;
	
	//Save the entered values of another application
	SettingsStructure = ThisObject.Context.CorrespondentInfobaseNodeFilterSetup;
	CorrespondingAttributes = ThisObject.CorrespondentBaseAttributeNames;
	
	For Each SettingItem IN SettingsStructure Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			
			AttributeName = CorrespondingAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = ThisObject[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item IN ThisObject[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, ThisObject[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	ThisObject.Context.CorrespondentInfobaseNodeFilterSetup = SettingsStructure;
	
	ThisObject.Context.Insert("ContextDetails", ThisObject.ContextDetails);
	ThisObject.Context.Insert("DocumentKinds", FilterStructureByTypesOfDocuments);
	
	Return ThisObject.Context;
	
EndFunction

&AtServer
Procedure OnChangeOfDataSynchronization()

	If SynchronizationMode = "AutomaticSynchronization" Then
		
		Items.DataSendConditionsGroup.Enabled = True;
		
	Else
		
		Items.DataSendConditionsGroup.Enabled = False;
		
	EndIf;

EndProcedure

&AtServer
Function GetTableOfDocumentsOutOfContext();

	TableOfDocuments = DocumentKinds.Unload().CopyColumns();
	
	If TypeOf(Parameters.Settings) <> Type("Structure")
		OR Not Parameters.Settings.Property("DocumentKinds")
		OR TypeOf(Parameters.Settings.DocumentKinds) <> Type("Structure") Then
		
		Return TableOfDocuments;
	EndIf;
	
	StructureDocumentKinds = Parameters.Settings.DocumentKinds;
	
	LineCount = StructureDocumentKinds.MetadataObjectName.Count();
	SetTableRowQuantity(TableOfDocuments, LineCount);
	TableOfDocuments.LoadColumn(StructureDocumentKinds.MetadataObjectName, "MetadataObjectName");
	
	LineCount = StructureDocumentKinds.Presentation.Count();
	SetTableRowQuantity(TableOfDocuments, LineCount);
	TableOfDocuments.LoadColumn(StructureDocumentKinds.Presentation, "Presentation");
	
	Parameters.Settings.Delete("DocumentKinds");
	
	Return TableOfDocuments;
	
EndFunction

Procedure SetTableRowQuantity(Table, LineCount)
	
	While Table.Count() < LineCount Do
		
		Table.Add();
		
	EndDo;
	
EndProcedure



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
