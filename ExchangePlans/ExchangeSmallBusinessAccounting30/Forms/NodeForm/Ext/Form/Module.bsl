////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
		
		Items.Service.Visible 			 = False;
		Items.Service.Enabled			 = False;
		
		InaccessibleItem = Items.Find("FormCommonCommandSentDataContent");
		If InaccessibleItem <> Undefined Then
			InaccessibleItem.Visible = False;
		EndIf;
		
		InaccessibleItem = Items.Find("FormCommonCommandDeleteSynchronizationSetting");
		If InaccessibleItem <> Undefined Then
			InaccessibleItem.Visible = False;
		EndIf;
		
		InaccessibleItem = Items.Find("FormDelete");
		If InaccessibleItem <> Undefined Then
			InaccessibleItem.Visible = False;
		EndIf;
		
	EndIf;
	
	SynchronizationMode = 
		?(NOT Object.ManualExchange, "AutomaticSynchronization", "ManualSynchronization")
	;
	
	CompaniesSyncMode =
		?(Object.UseCompaniesFilter, "SynchronizeDataBySelectedCompaniesOnly", "SynchronizeDataByAllCompanies")
	;
	
	DocumentSynchronizationMode =
		?(Object.UseDocumentTypesFilter, "DataSynchronizeOnlyForSelectedOfDocumentKinds", "SynchronizateDataByAllDocuments")
	;
	
	SetVisibleAtServer();
	OnChangeOfDataSynchronization();
	RefreshDescriptionCommandsForms();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If SynchronizationMode <> "AutomaticSynchronization" Then
		
		CurrentObject.UseCompaniesFilter = False;
		CurrentObject.Companies.Clear();
		
		CurrentObject.UseDocumentTypesFilter = False;
		CurrentObject.DocumentKinds.Clear();
		
		CurrentObject.ManualExchange = True;
		CurrentObject.SynchronizationModeData = Enums.ExchangeObjectsExportModes.ExportManually;
		
	Else
		
		If CurrentObject.Companies.Count() > 0 Then
			If CompaniesSyncMode = "SynchronizeDataBySelectedCompaniesOnly" Then
				CurrentObject.UseCompaniesFilter = True;
			Else
				CurrentObject.UseCompaniesFilter = False;
				CurrentObject.Companies.Clear();
			EndIf;
		Else
			CurrentObject.UseCompaniesFilter = False;
		EndIf;
		
		If CurrentObject.DocumentKinds.Count() > 0 Then
			If DocumentSynchronizationMode = "DataSynchronizeOnlyForSelectedOfDocumentKinds" Then
				CurrentObject.UseDocumentTypesFilter = True;
			Else
				CurrentObject.UseDocumentTypesFilter = False;
				CurrentObject.DocumentKinds.Clear();
			EndIf;
		Else
			CurrentObject.UseDocumentTypesFilter = False;
		EndIf;
		
		CurrentObject.ManualExchange = False;
		CurrentObject.SynchronizationModeData = Enums.ExchangeObjectsExportModes.AlwaysExport;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify("NodeExchangePlanFormClosed");
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	UpdateObjectData(ValueSelected);
	Modified = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

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
		SynchronizationMode = "ManualSynchronization";
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
	
	HeaderText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Do you want to clear the filter by companies?'");
	Response = Undefined;

	ShowQueryBox(New NotifyDescription("ClearFilterByCompanyEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
	
EndProcedure

&AtClient
Procedure ClearFilterByCompanyEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response=DialogReturnCode.Yes Then
        Object.Companies.Clear();
        SetVisibleAtServer();
        RefreshDescriptionCommandsForms();
        Modified = True;
    EndIf;

EndProcedure

&AtClient
Procedure ClearDocumentTypesFilter(Command)
	
	HeaderText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Do you want to clear the filter by document types?'");
	Response = Undefined;

	ShowQueryBox(New NotifyDescription("ClearFilterByDocumentKindEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
	
EndProcedure

&AtClient
Procedure ClearFilterByDocumentKindEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response=DialogReturnCode.Yes Then
        Object.DocumentKinds.Clear();
        SetVisibleAtServer();
        RefreshDescriptionCommandsForms();
        Modified = True;
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
		FilterByCompaniesConfigured = Object.Companies.Count() > 0;
		Items.OpenFilterFormByCompanies.Visible = FilterByCompaniesInUse;
		Items.CompanyFilterClean.Visible = FilterByCompaniesInUse AND FilterByCompaniesConfigured;
	EndIf;
	
	//Visible of filter by document kind
	DocumentTypesFilterInUse = DocumentSynchronizationMode = "DataSynchronizeOnlyForSelectedOfDocumentKinds";
	DocumentTypesFilterConfigured = Object.DocumentKinds.Count() > 0;
	Items.OpenFormFilterByDocumentTypes.Visible = DocumentTypesFilterInUse;
	Items.ClearDocumentTypesFilter.Visible = DocumentTypesFilterInUse AND DocumentTypesFilterConfigured;

EndProcedure

&AtServer
Function GetObjectArrayTableParts(TabularSectionName, ColumnName)

	Return Object[TabularSectionName].Unload().UnloadColumn(ColumnName);

EndFunction

&AtServer
Procedure UpdateObjectData(ParametersStructure)
	
	Object[ParametersStructure.TableNameForFill].Clear();
	
	SelectedValuesList = GetFromTempStorage(ParametersStructure.AddressTableInTemporaryStorage);
	
	If SelectedValuesList.Count() > 0 Then
		Object[ParametersStructure.TableNameForFill].Load(SelectedValuesList);
	EndIf;
	
	SetVisibleAtServer();
	RefreshDescriptionCommandsForms();
	
EndProcedure

&AtServer
Procedure RefreshDescriptionCommandsForms()
	
	//Update the title of selected companies
	If Object.Companies.Count() > 0 Then
		
		SelectedCompanies = Object.Companies.Unload().UnloadColumn("Company");
		NewTitleCompanies = ExchangePlans.ExchangeSmallBusinessAccounting30.ShortPresentationOfCollectionsOfValues(SelectedCompanies);
		
	Else
		
		NewTitleCompanies = NStr("en = 'Select companies '");
		
	EndIf;
	
	Items.OpenFilterFormByCompanies.Title = NewTitleCompanies;
	
	//Update the title of selected document kinds
	If Object.DocumentKinds.Count() > 0 Then
		
		SelectedDocumentKinds = Object.DocumentKinds.Unload().UnloadColumn("Presentation");
		NewTitleOfDocuments = ExchangePlans.ExchangeSmallBusinessAccounting30.ShortPresentationOfCollectionsOfValues(SelectedDocumentKinds);
		
	Else
		
		NewTitleOfDocuments = NStr("en = 'Select documents types '");
		
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
