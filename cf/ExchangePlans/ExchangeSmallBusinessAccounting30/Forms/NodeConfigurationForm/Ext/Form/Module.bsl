////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ExchangePlanName = Metadata.ExchangePlans.ExchangeSmallBusinessAccounting30.Name;
	DataExchangeServer.NodeConfigurationFormOnCreateAtServer(ThisForm, ExchangePlanName);
	
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
	
	DataExchangeClient.NodeConfigurationFormCommandCloseForm(ThisForm);
	
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
	QuestionText   = NStr("en='Clear filter by companies?';ru='Очистить отбор по организациям?'");
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
	QuestionText   = NStr("en='Clear filter by document kinds?';ru='Очистить отбор по видам документов?'");
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
	
	ThisForm[ParametersStructure.TableNameForFill].Clear();
	
	SelectedValuesList = GetFromTempStorage(ParametersStructure.AddressTableInTemporaryStorage);
	
	If SelectedValuesList.Count() > 0 Then
		ThisForm[ParametersStructure.TableNameForFill].Load(SelectedValuesList);
	EndIf;
	
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
Procedure OnChangeOfDataSynchronization()

	If SynchronizationMode = "AutomaticSynchronization" Then
		
		Items.DataSendConditionsGroup.Enabled = True;
		
	Else
		
		Items.DataSendConditionsGroup.Enabled = False;
		
	EndIf;

EndProcedure





