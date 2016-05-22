&AtClient
Var InterruptIfNotCompleted;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
// Generate a filter structure according to passed parameters
//
// DetailsMatch - map received from details
//
Function GetPriceKindsChoiceList(DetailsMatch, CopyChangeDelete = FALSE)
	
	ChoiceList = New ValueList;
	
	If TypeOf(DetailsMatch) = Type("Map") Then
		
		For Each MapItem IN DetailsMatch Do
			
			If CopyChangeDelete 
				AND Not TypeOf(MapItem.Value) = Type("Structure") Then
				
				Continue;
				
			EndIf;
			
			If CopyChangeDelete
				AND TypeOf(MapItem.Value) = Type("Structure")
				AND MapItem.Value.Property("Price")
				AND Not ValueIsFilled(MapItem.Value.Price) Then
				
				Continue;
				
			EndIf;
			
			If CopyChangeDelete
				AND MapItem.Value.Dynamic Then
				
				Continue;
				
			EndIf;
			
			ChoiceList.Add(MapItem.Key, TrimAll(MapItem.Key));
			
		EndDo;
		
	EndIf;
	
	Return ChoiceList;
	
EndFunction // GetSelectionStructure()

&AtServer
// Procedure updates the form title
//
Procedure UpdateFormTitleAtServer()
	
	ThisForm.Title	= NStr("en = 'Counterparty''s price list'") + 
		?(ValueIsFilled(ToDate), NStr("en = ' on '") + Format(ToDate, "DLF=DD"), NStr("en = '.'"));
	
EndProcedure // UpdateFormTitleAtServer()

&AtServer
// Procedure updates the constant values (global pricelist settings)
//
Procedure UpdateValuesOfConstantsOnServer()
	
	Constants.PriceListShowCode.Set(OutputCode);
	Constants.PriceListShowFullDescr.Set(OutputFullDescr);
	Constants.PriceListUseProductsAndServicesHierarchy.Set(ItemHierarchy);
	Constants.FormPriceListByAvailabilityInWarehouses.Set(FormateByAvailabilityInWarehouses);
	
EndProcedure //UpdateConstantValuesAtServer()

&AtServer
// Procedure fills tabular document.
//
Procedure UpdateAtServer()
	
	UpdateFormTitleAtServer();
	
	UpdateValuesOfConstantsOnServer();
	
	If CommonUse.FileInfobase() Then 
		
		DataProcessors.PriceList.PrepareSpreadsheetDocument(GetParametersStructureFormation(), SpreadsheetDocument);
		Completed = True;
		
	Else
		
		PrepareSpreadsheetDocumentInLongActions();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure, ActualOnly = False)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	MAX(ProductsAndServicesPricesSliceLast.Period) AS Period,
	|	ProductsAndServicesPricesSliceLast.Price
	|FROM
	|	InformationRegister.ProductsAndServicesPrices.SliceLast(
	|			,
	|			Period <= &ToDate
	|				AND PriceKind = &PriceKind
	|				AND ProductsAndServices = &ProductsAndServices
	|				AND Characteristic = &Characteristic
	|				AND &ActualOnly) AS ProductsAndServicesPricesSliceLast
	|
	|GROUP BY
	|	ProductsAndServicesPricesSliceLast.Price";
	
	If ActualOnly Then
		
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "Actuality");
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "True");
		
	EndIf;
	
	Query.SetParameter("ToDate", 
		?(ValueIsFilled(ParametersStructure.Period), BegOfDay(ParametersStructure.Period), CurrentDate()));
	Query.SetParameter("ProductsAndServices", 	ParametersStructure.ProductsAndServices);
	Query.SetParameter("Characteristic", ParametersStructure.Characteristic);
	Query.SetParameter("PriceKind", 		ParametersStructure.PriceKind);
	
	ReturnStructure = New Structure("CreateNewRecord, Period, PriceKind, ProductsAndServices, Characteristic, Price", True);
	FillPropertyValues(ReturnStructure, ParametersStructure);
	
	ResultTable = Query.Execute().Unload();
	If ResultTable.Count() > 0 Then
		
		ReturnStructure.Period				= ResultTable[0].Period;
		ReturnStructure.Price					= ResultTable[0].Price;
		ReturnStructure.CreateNewRecord	= False;
		
	EndIf; 
	
	Return ReturnStructure;
	
EndFunction // GetRecordKey()

&AtClient
// Procedure opens the register record.
//
Procedure OpenRegisterRecordForm(ParametersStructure)
	
	RecordKey = GetRecordKey(ParametersStructure, Actuality);
	
	If ValueIsFilled(RecordKey) 
		AND TypeOf(RecordKey) = Type("Structure") 
		AND Not RecordKey.CreateNewRecord Then
		
		RecordKey.Delete("CreateNewRecord");
		RecordKey.Delete("Price");
		
		ParametersArray = New Array;
		ParametersArray.Add(RecordKey);
		
		RecordKeyRegister = New("InformationRegisterRecordKey.ProductsAndServicesPrices", ParametersArray);
		OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("Key", RecordKeyRegister));
		
	Else
		
		OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("FillingValues", RecordKey));
		
	EndIf; 
	
EndProcedure // OpenRegisterRecordForm()

&AtServerNoContext
// Procedure saves the form settings.
//
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("DataProcessorPriceListForm", "SettingsStructure", SettingsStructure);
	
EndProcedure

&AtClient
// Toggling pages with filters(Quick/Multiple)
//
Procedure ChangeFilterPage(TabularSectionName, List)
	
	GroupPages = Items["FilterPages" + TabularSectionName];
	
	SetAsCurrentPage = Undefined;
	
	For Each PageOfGroup in GroupPages.ChildItems Do
		
		If List Then
			
			If Find(PageOfGroup.Name, "MultipleFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
			
			EndIf;
			
		Else
			
			If Find(PageOfGroup.Name, "QuickFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Items["DecorationMultipleFilter" + TabularSectionName].Title = GetDecorationTitleContent(TabularSectionName);
	
	GroupPages.CurrentPage = SetAsCurrentPage;
	
EndProcedure // ChangeFilterPage()

&AtClient
// Function returns the value array containing tabular section units
//
// TabularSectionName - tabular section ID,the units of which fill the array
//
Function FillArrayByTabularSectionAtClient(TabularSectionName)
	
	ValueArray = New Array;
	
	For Each TableRow IN Object[TabularSectionName] Do
		
		ValueArray.Add(TableRow.Ref);
		
	EndDo;
	
	Return ValueArray;
	
EndFunction //FillArrayByTabularSectionAtClient()

&AtClient
// Fills out the specified tabular section with values from the passed array on the client
//
Procedure FillTabularSectionFromArrayItemsAtClient(TabularSectionName, ItemArray, ClearTable)
	
	If ClearTable Then
		
		Object[TabularSectionName].Clear();
		
	EndIf;
	
	For Each ArrayElement IN ItemArray Do
		
		NewRow 		= Object[TabularSectionName].Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure // FillTabularSectionFromArrayItemsAtClient()

&AtClient
// Procedure analyses executed specified filters
//
Procedure AnalyzeChoice(TabularSectionName)
	
	ItemCount = Object[TabularSectionName].Count();
	
	ChangeFilterPage(TabularSectionName, ItemCount > 0);
	
EndProcedure // AnalyzeChoice()

&AtServerNoContext
// Additionally analyses the specified filter when executing the Add command
//
Function PickPriceKindForNewRecord(PriceKind)
	
	Return ?(PriceKind.CalculatesDynamically, PriceKind.PricesBaseKind, PriceKind);
	
EndFunction //SelectPricesKindForNewRecord()

&AtServer
//Procedure fills the filters with the values from the saved settings
//
Procedure RestoreValuesOfFilters(SettingsStructure, TSNamesStructure)
	
	For Each NamesStructureItem IN TSNamesStructure Do
		
		TabularSectionName	= NamesStructureItem.Key;
		If SettingsStructure.Property(NamesStructureItem.Value) Then
			
			ItemArray		= SettingsStructure[NamesStructureItem.Value];
			
		EndIf;
		
		If Not TypeOf(ItemArray) = Type("Array") 
			OR ItemArray.Count() < 1 Then
			
			Continue;
			
		EndIf;
		
		Object[TabularSectionName].Clear();
		
		For Each ArrayElement IN ItemArray Do
			
			NewRow 		= Object[TabularSectionName].Add();
			NewRow.Ref	= ArrayElement;
			
		EndDo;
	
	EndDo;
	
	If Object.PriceKinds.Count() < 1 Then
		
		PriceKind = SettingsStructure.PriceKind;
		
	EndIf;
	
	If Object.PriceGroups.Count() < 1 Then 
		
		PriceGroup = SettingsStructure.PriceGroup;
	
	EndIf;
	
	If Object.ProductsAndServices.Count() < 1 Then
		
		ProductsAndServices = SettingsStructure.ProductsAndServices;
		
	EndIf;
	
	If SettingsStructure.Property("Actuality") Then
		
		Actuality		= SettingsStructure.Actuality;
		
	EndIf;
	
	If SettingsStructure.Property("EnableAutoCreation") Then
		
		EnableAutoCreation = SettingsStructure.EnableAutoCreation;
		
	EndIf;
	
	If SettingsStructure.Property("FullDescr") Then
		
		FullDescr	= SettingsStructure.FullDescr;
		
	EndIf;
	
EndProcedure // RestoreFiltersValues()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	SettingsStructure = FormDataSettingsStorage.Load("DataProcessorPriceListForm", "SettingsStructure");
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		TSNamesStructure = New Structure("PriceKinds, PriceGroups, ProductsAndServices", "CWT_PriceKinds", "CWT_PriceGroups", "CWT_ProductsAndServices");
		RestoreValuesOfFilters(SettingsStructure, TSNamesStructure);
		
	Else
		
		PriceKind						= Catalogs.PriceKinds.Wholesale;
		Actuality				= True;
		EnableAutoCreation	= True;
		
	EndIf;
	
	ToDate 									= Undefined;
	OutputCode								= Constants.PriceListShowCode.Get();
	OutputFullDescr				= Constants.PriceListShowFullDescr.Get();
	ItemHierarchy					= Constants.PriceListUseProductsAndServicesHierarchy.Get();
	FormateByAvailabilityInWarehouses			= Constants.FormPriceListByAvailabilityInWarehouses.Get();
	UseCharacteristics				= GetFunctionalOption("UseCharacteristics");
	Items.ShowTitle.Check	= False;
	
	Items.AbortPriceListBackGroundFormation.Visible = Not CommonUse.FileInfobase();
	
	UpdateFormTitleAtServer();
	
	CurrentArea = "R1C1";
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.Add.Visible 	   = AllowedEditDocumentPrices;
	Items.Copy.Visible 	   = AllowedEditDocumentPrices;
	Items.Change.Visible 	   = AllowedEditDocumentPrices;
	Items.History.Visible 		   = AllowedEditDocumentPrices;
	Items.Pricing.Visible = AllowedEditDocumentPrices;
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.InformationRegisters.ProductsAndServicesPrices, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	
	//Set current form pages depending on the saved filters
	AnalyzeChoice("PriceKinds");
	AnalyzeChoice("PriceGroups");
	AnalyzeChoice("ProductsAndServices");
	
	StatePresentation = Items.SpreadsheetDocument.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Text = NStr("en = 'Click the Update command for creating price list.'");
	
EndProcedure // OnOpen()

&AtClient
// Procedure - event handler OnClose form.
//
Procedure OnClose()
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("PriceKind", 			PriceKind);
	SettingsStructure.Insert("CWT_PriceKinds", 		FillArrayByTabularSectionAtClient("PriceKinds"));
	
	SettingsStructure.Insert("PriceGroup", 	PriceGroup);
	SettingsStructure.Insert("CWT_PriceGroups",	FillArrayByTabularSectionAtClient("PriceGroups"));
	
	SettingsStructure.Insert("ProductsAndServices", 		ProductsAndServices);
	SettingsStructure.Insert("CWT_ProductsAndServices",	FillArrayByTabularSectionAtClient("ProductsAndServices"));
	
	SettingsStructure.Insert("ToDate", 			ToDate);
	SettingsStructure.Insert("Actuality",		Actuality);
	SettingsStructure.Insert("EnableAutoCreation", EnableAutoCreation);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure

&AtClient
Function GetDecorationTitleContent(TabularSectionName) 
	
	If Object[TabularSectionName].Count() < 1 Then
		
		DecorationTitle = "Multiple filter isn't filled";
		
	ElsIf Object[TabularSectionName].Count() = 2 Then
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref);
		
	ElsIf Object[TabularSectionName].Count() > 2 Then
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref) + "...";
		
	Else
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref);
		
	EndIf;
	
	Return DecorationTitle;
	
EndFunction

&AtClient
// Procedure - handler of form notification.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorPriceListGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	If EventName = "PriceChanged" Then
		
		If Parameter Then
			
			InitializeDataRefresh();
			
		EndIf;
		
	ElsIf EventName = "MultipleFilters" AND TypeOf(Parameter) = Type("Structure") Then
		
		ToDate 							= Parameter.ToDate;
		Actuality					= Parameter.Actuality;
		EnableAutoCreation		= Parameter.EnableAutoCreation;
		OutputCode						= Parameter.OutputCode;
		OutputFullDescr		= Parameter.OutputFullDescr;
		ItemHierarchy			= Parameter.ItemHierarchy;
		FormateByAvailabilityInWarehouses	= Parameter.FormateByAvailabilityInWarehouses;
		
		// Price kinds
		ThisIsMultipleFilter = (TypeOf(Parameter.PriceKind) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceKinds", Parameter.PriceKind, True);
			PriceKind = Undefined;
			
		Else
			
			PriceKind = Parameter.PriceKind;
			Object.PriceKinds.Clear();
			
		EndIf;
		
		ChangeFilterPage("PriceKinds", ThisIsMultipleFilter);
		
		// Price groups
		ThisIsMultipleFilter = (TypeOf(Parameter.PriceGroup) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", Parameter.PriceGroup, True);
			PriceGroup = Undefined;
			
		Else
			
			PriceGroup = Parameter.PriceGroup;
			Object.PriceGroups.Clear();
			
		EndIf;
		
		ChangeFilterPage("PriceGroups", ThisIsMultipleFilter);
		
		// ProductsAndServices
		ThisIsMultipleFilter = (TypeOf(Parameter.ProductsAndServices) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("ProductsAndServices", Parameter.ProductsAndServices, True);
			ProductsAndServices = Undefined;
			
		Else
			
			ProductsAndServices = Parameter.ProductsAndServices;
			Object.ProductsAndServices.Clear();
			
		EndIf;
		
		ChangeFilterPage("ProductsAndServices", ThisIsMultipleFilter);
		
		InitializeDataRefresh();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of form.
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		
		ClearTable = True;
		
		If ChoiceSource.FormName = "DataProcessor.PriceList.Form.PricesKindsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceKinds", ValueSelected, ClearTable);
			AnalyzeChoice("PriceKinds");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.PriceList.Form.PriceGroupsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", ValueSelected, ClearTable);
			AnalyzeChoice("PriceGroups");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.PriceList.Form.ProductsAndServicesEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("ProductsAndServices", ValueSelected, ClearTable);
			AnalyzeChoice("ProductsAndServices");
			
		EndIf;
		
		InitializeDataRefresh();
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS

&AtClient
// Procedure - Refresh command handler.
//
Procedure Refresh(Command)
	
	InitializeDataRefresh(True);
	
EndProcedure

&AtClient
// Procedure - handler of the Add command.
//
Procedure Add(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") Then
		
		FillingValues = New Structure("ProductsAndServices", ProductsAndServices);
		
		If ValueIsFilled(PriceKind) Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(PriceKind));
			
		ElsIf Object.PriceKinds.Count() = 1 Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(Object.PriceKinds[0].Ref));
			
		EndIf;
		
		OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("FillingValues",FillingValues));
		Return;
		
	ElsIf DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to add the price.
					|Perhaps, dynamic price type is selected.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetPriceKindsChoiceList(DetailFromArea.DetailsMatch);
		
		If AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		Else
			
			Details 	= Undefined;
			
		EndIf;
			
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	FillingValues = New Structure("Actuality", True);
	
	If Details = Undefined 
		OR Not TypeOf(Details) = Type("Structure") Then
		
		If Object.PriceKinds.Count() < 1 
			AND ValueIsFilled(PriceKind) Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(PriceKind));
			
		ElsIf Object.PriceKinds.Count() = 1 Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(Object.PriceKinds[0].Ref));
			
		ElsIf TypeOf(SelectedPriceKind) = Type("ValueListItem") Then
			
			FillingValues.Insert("PriceKind", SelectedPriceKind.Value);
			
		EndIf;
		
		If Object.ProductsAndServices.Count() < 1 
			AND ValueIsFilled(ProductsAndServices) Then
			
			FillingValues.Insert("ProductsAndServices", ProductsAndServices);
			
		ElsIf DetailFromArea.Property("ProductsAndServices")
			AND ValueIsFilled(DetailFromArea.ProductsAndServices) Then
			
			FillingValues.Insert("ProductsAndServices", DetailFromArea.ProductsAndServices);
			
			If DetailFromArea.Property("Characteristic")
				AND ValueIsFilled(DetailFromArea.Characteristic) Then
				
				FillingValues.Insert("Characteristic", DetailFromArea.Characteristic);
				
			EndIf;
			
		ElsIf TypeOf(Details) = Type("CatalogRef.ProductsAndServicesCharacteristics") Then
			
			FillingValues.Insert("ProductsAndServices", Details.Owner);
			
		EndIf;
		
		OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("FillingValues", FillingValues));
		Return;
		
	EndIf;
	
	FillingValues.Insert("PriceKind", 			Details.PriceKind);
	FillingValues.Insert("ProductsAndServices",		Details.ProductsAndServices);
	FillingValues.Insert("Characteristic",	Details.Characteristic);
	
	If Details.Property("Price") Then
		
		FillingValues.Insert("Price", 		Details.Price);
		
	EndIf;
	
	
	OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("FillingValues", FillingValues),,,,, New NotifyDescription("AddEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure AddEnd(Result, AdditionalParameters) Export
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - the Copy commands.
//
Procedure Copy(Command)

	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") 
		OR (DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to copy the price.
					|Perhaps, dynamic price type or the blank cell has been selected.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetPriceKindsChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceKindsList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No prices available for copying exist for the current products and services in the current price list.'")
						);
						
			Return;
			
		ElsIf AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	
	If Details = Undefined OR Not TypeOf(Details) = Type("Structure") //no details
		OR Not Details.Property("Price") //There are no price details
		OR (Details.Property("Price") AND Not ValueIsFilled(Details.Price)) //there is a price but it is not filled out
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Dynamic price or empty cell is specified.
				|Copying is not possible.'")
				);
				
		Return;
		
	EndIf;
	
	FillingValues = New Structure("PricesKind, ProductsAndServices, Characteristic, MeasurementUnit, Price, Actuality",
		Details.PriceKind,
		Details.ProductsAndServices,
		Details.Characteristic,
		Details.MeasurementUnit,
		Details.Price,
		True);
	
	OpenForm("InformationRegister.ProductsAndServicesPrices.RecordForm", New Structure("FillingValues", FillingValues));
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - the Change commands.
//
Procedure Change(Command)

	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to change the price.
					|Perhaps, dynamic price type or the blank cell has been selected.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetPriceKindsChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceKindsList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No prices available for editing exist for the current products and services in current price list.'")
						);
						
			Return;
			
		ElsIf AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	OpenRegisterRecordForm(Details);
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the History command.
//
Procedure History(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Can not open history of the prices generation.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetPriceKindsChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceKindsList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Can not show price history for the current inventory item.'")
						);
						
			Return;
			
		ElsIf AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	StructureFilter = New Structure;

	If TypeOf(Details) = Type("Structure") Then
		
		StructureFilter.Insert("Characteristic", Details.Characteristic);
		StructureFilter.Insert("ProductsAndServices", Details.ProductsAndServices);
		
		If ValueIsFilled(Details.PriceKind) Then
			
			StructureFilter.Insert("PriceKind", Details.PriceKind);
			
		EndIf;
		
		OpenForm("InformationRegister.ProductsAndServicesPrices.ListForm", New Structure("Filter", StructureFilter),,,,, New NotifyDescription("HistoryEnd", ThisObject));
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure HistoryEnd(Result, AdditionalParameters) Export
    
    InitializeDataRefresh();

EndProcedure

&AtClient
// Procedure - the Print commands.
//
Procedure Print(Command)
	
	If SpreadsheetDocument = Undefined Then
		Return;
	EndIf;

	SpreadsheetDocument.Copies = 1;

	If Not ValueIsFilled(SpreadsheetDocument.PrinterName) Then
		SpreadsheetDocument.FitToPage = True;
	EndIf;
	
	SpreadsheetDocument.Print(False);
	SpreadsheetDocument.Show();

EndProcedure

&AtClient
// Procedure - the PricesGenerating commands.
//
Procedure Pricing(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PriceKind", PriceKind);
	ParametersStructure.Insert("PriceGroup", PriceGroup);
	ParametersStructure.Insert("ProductsAndServices", ProductsAndServices);
	ParametersStructure.Insert("ToDate", ToDate);
	Result = Undefined;

	OpenForm("DataProcessor.Pricing.Form", ParametersStructure,,,,, New NotifyDescription("PricesGeneratingEnd", ThisObject)); 
	
EndProcedure

&AtClient
Procedure PricesGeneratingEnd(Result1, AdditionalParameters) Export
    
    Result = Result1;
    
    If ValueIsFilled(Result) Then
        
        InitializeDataRefresh();
        
    EndIf;

EndProcedure // CommandProcessing()

&AtClient
// Procedure changes the ShowTitle button mark.
//
Procedure ShowTitle(Command)
	
	Items.ShowTitle.Check = Not Items.ShowTitle.Check;
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
//Procedure - event handler of the GoToMultipleFilters clicking button
Procedure GoToMultipleFilters(Command)
	
	FormParameters = New Structure;
	
	// Pass filled filters
	FormParameters.Insert("ToDate", 							ToDate);
	FormParameters.Insert("Actuality",						Actuality);
	FormParameters.Insert("EnableAutoCreation", 		EnableAutoCreation);
	
	ParameterValue = ?(Object.PriceKinds.Count() > 0, FillArrayByTabularSectionAtClient("PriceKinds"), PriceKind);
	FormParameters.Insert("PriceKind", ParameterValue);
	
	ParameterValue = ?(Object.PriceGroups.Count() > 0, FillArrayByTabularSectionAtClient("PriceGroups"), PriceGroup);
	FormParameters.Insert("PriceGroup", ParameterValue);
	
	ParameterValue = ?(Object.ProductsAndServices.Count() > 0, FillArrayByTabularSectionAtClient("ProductsAndServices"), ProductsAndServices);
	FormParameters.Insert("ProductsAndServices", ParameterValue);
	
	OpenForm("DataProcessor.PriceList.Form.MultipleFiltersForm", FormParameters, ThisForm);
	
EndProcedure //GoToMultipleFilters()

&AtClient
// Procedure-handler of the Abort command of the price list generated in the background
//
Procedure AbortPriceListBackGroundFormation(Command)
	
	InterruptIfNotCompleted = True;
	CheckExecution();
	 
EndProcedure // AbortPriceListBackGroundFormation()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - handler of the Selection event of the TabularDocument attribute.
//
Procedure SpreadsheetDocumentSelection(Item, Area, StandardProcessing)
	
	If TypeOf(Area.Details) = Type("Structure") Then
		
		StandardProcessing = False;
		If Area.Left = 3 Or Area.Left = 2 Then //Expand the SKU as ProductsAndServices
			
			OpeningStructure = New Structure("Key", Area.Details.ProductsAndServices);
			OpenForm("Catalog.ProductsAndServices.ObjectForm", OpeningStructure);
			
		ElsIf UseCharacteristics AND Area.Left = 4 Then
			
			OpeningStructure = New Structure("Key", Area.Details.Characteristic);
			OpenForm("Catalog.ProductsAndServicesCharacteristics.ObjectForm", OpeningStructure);
			
		Else
			
			ParametersStructure = Area.Details;
			
			If ParametersStructure.Property("Period") Then
				
				ParametersStructure.Period = CurrentDate();
				
			EndIf;
			
			OpenRegisterRecordForm(ParametersStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of the OnActivateArea event of the TabularDocument attribute.
//
Procedure SpreadsheetDocumentOnActivateArea(Item)
	
	CurrentArea = Item.CurrentArea.Name;

EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the PricesKind attribute.
//
Procedure PricesKindOnChange(Item)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the PriceGroup attribute.
//
Procedure PriceGroupOnChange(Item)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the ProductsAndServices attribute.
//
Procedure ProductsAndServicesOnChange(Item)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PricesKind attribute.
//
Procedure PriceKindClear(Item, StandardProcessing)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PriceGroup attribute.
//
Procedure PriceGroupClear(Item, StandardProcessing)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the ProductsAndServices attribute.
//
Procedure ProductsAndServicesClear(Item, StandardProcessing)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
//Procedure - event handler of the the MultipleFilterByPricesKind decoration clicking
//
Procedure MultipleFilterByPriceKindClick(Item)
	
	OpenForm("DataProcessor.PriceList.Form.PricesKindsEditForm", New Structure("ArrayPriceKinds", FillArrayByTabularSectionAtClient("PriceKinds")), ThisForm);
	
EndProcedure // MultipleFilterByPriceKindClick()

&AtClient
//Procedure - event handler of the MultipleFilterByPriceGroup decoration clicking
//
Procedure MultipleFilterByPriceGroupClick(Item)
	
	OpenForm("DataProcessor.PriceList.Form.PriceGroupsEditForm", New Structure("ArrayPriceGroups", FillArrayByTabularSectionAtClient("PriceGroups")), ThisForm);
	
EndProcedure // MultipleFilterByPriceGroupClick()

&AtClient
//Procedure - event handler of the MultipleFilterOnProductsAndServices decoration clicking
//
Procedure MultipleFilterByProductsAndServicesClick(Item)
	
	OpenForm("DataProcessor.PriceList.Form.ProductsAndServicesEditForm", New Structure("ProductsAndServicesArray", FillArrayByTabularSectionAtClient("ProductsAndServices")), ThisForm);
	
EndProcedure // MultipleFilterByProductsAndServicesClick()

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
// Function returns the parameter structure to generate the price list
//
Function GetParametersStructureFormation()
	
	BackgroundJobLaunchParameters = New Structure;
	
	BackgroundJobLaunchParameters.Insert("ToDate", ToDate);
	BackgroundJobLaunchParameters.Insert("PriceKind", PriceKind);
	BackgroundJobLaunchParameters.Insert("TSPriceKinds", Object.PriceKinds.Unload());
	BackgroundJobLaunchParameters.Insert("PriceGroup", PriceGroup);
	BackgroundJobLaunchParameters.Insert("TSPriceGroups", Object.PriceGroups.Unload());
	BackgroundJobLaunchParameters.Insert("ProductsAndServices", ProductsAndServices);
	BackgroundJobLaunchParameters.Insert("ProductsAndServicesTS", Object.ProductsAndServices.Unload());
	BackgroundJobLaunchParameters.Insert("Actuality", Actuality);
	BackgroundJobLaunchParameters.Insert("EnableAutoCreation", EnableAutoCreation);
	BackgroundJobLaunchParameters.Insert("OutputCode", OutputCode);
	BackgroundJobLaunchParameters.Insert("OutputFullDescr", OutputFullDescr);
	BackgroundJobLaunchParameters.Insert("ShowTitle", Items.ShowTitle.Check);
	BackgroundJobLaunchParameters.Insert("UseCharacteristics", UseCharacteristics);
	BackgroundJobLaunchParameters.Insert("ItemHierarchy", ItemHierarchy);
	BackgroundJobLaunchParameters.Insert("FormateByAvailabilityInWarehouses", FormateByAvailabilityInWarehouses);
	
	Return BackgroundJobLaunchParameters;
	
EndFunction // GetFormationParametersStructure()

&AtClient
// Procedure initializes the tabular document filling
// 
Procedure InitializeDataRefresh(ThisIsManualCall = False)
	
	If Not EnableAutoCreation 
		AND Not ThisIsManualCall Then
		
		Return;
		
	EndIf;
	
	StatePresentation = Items.SpreadsheetDocument.StatePresentation;
	StatePresentation.Visible = False;
	
	//StandardSubsystems.PerformanceEstimation
	OperationsStartTime = PerformanceEstimationClientServer.TimerValue();
	//End StandardSubsystems.PerformanceEstimation
	
	Completed = False;
	
	UpdateAtServer();
	
	If Completed Then
		
		PerformanceEstimationClientServer.EndTimeMeasurement(
			"DataProcessorPriceListGenerating", 
			OperationsStartTime
			);
		
	Else
		
		InterruptIfNotCompleted = False;
		
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndProcedure // InitializeDataUpdating()

&AtServer
// Procedure generates a price list using a background job
//
Procedure PrepareSpreadsheetDocumentInLongActions()
	
	Items.AbortPriceListBackGroundFormation.Enabled = True;
	
	BackgroundJobLaunchParameters = GetParametersStructureFormation();
	
	AssignmentResult = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.PriceList.Generate",
		BackgroundJobLaunchParameters,
		NStr("en = 'Price list data preparation'")
	);
	
	Completed = AssignmentResult.JobCompleted;
	
	If Completed Then
		
		Result = GetFromTempStorage(AssignmentResult.StorageAddress);
		
		If TypeOf(Result) = Type("SpreadsheetDocument") Then
			
			SpreadsheetDocument = Result;
			
		EndIf;
		
		Items.AbortPriceListBackGroundFormation.Enabled = False;
		
	Else
		
		BackgroundJobID  = AssignmentResult.JobID;
		BackgroundJobStorageAddress = AssignmentResult.StorageAddress;
		
		SmallBusinessServer.StateDocumentsTableLongOperation(
			Items.SpreadsheetDocument,
			NStr("en = 'Generating the report...'")
			);
		
	EndIf;
	
EndProcedure // PrepareSpreadsheetDocumentInLongActions()

&AtClient
// Procedure checks the tabular document filling end
//
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted);
	
	If CheckResult.JobCompleted Then
		
		StatePresentation = Items.SpreadsheetDocument.StatePresentation;
		StatePresentation.Visible = False;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		StatePresentation.Picture = New Picture;
		StatePresentation.Text = "";
		
		Items.AbortPriceListBackGroundFormation.Enabled = False;
		
		PerformanceEstimationClientServer.EndTimeMeasurement(
			"DataProcessorPriceListGenerating", 
			OperationsStartTime
			);
		
	ElsIf InterruptIfNotCompleted Then
		
		StatePresentation = Items.SpreadsheetDocument.StatePresentation;
		StatePresentation.Visible = True;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		StatePresentation.Picture = New Picture;
		StatePresentation.Text = NStr("en = 'Data are not actual'");
		
		Items.AbortPriceListBackGroundFormation.Enabled = False;
		
		DetachIdleHandler("CheckExecution");
		
		PerformanceEstimationClientServer.EndTimeMeasurement(
			"DataProcessorPriceListGenerating", 
			OperationsStartTime
			);
		
	Else
		
		If BackgroundJobIntervalChecks < 15 Then
			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;
			
		EndIf;
		
		InterruptIfNotCompleted = False;
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);
		
	EndIf;
	
EndProcedure // CheckExecution()

&AtServer
// Procedure checks the tabular document filling end on server
//
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted)
	
	CheckResult = New Structure("JobComplete, Value", False, Undefined);
	
	If LongActions.JobCompleted(BackgroundJobID) Then
		
		CheckResult.JobCompleted	= True;
		SpreadsheetDocument					= GetFromTempStorage(BackgroundJobStorageAddress);
		CheckResult.Value			= SpreadsheetDocument;
		
	ElsIf InterruptIfNotCompleted Then
		
		LongActions.CancelJobExecution(BackgroundJobID);
		
	EndIf;
	
	Return CheckResult;
	
EndFunction // CheckExecutionAtServer()


#Region LibrariesHandlers

// StandardSubsystems.DataLoadFromFile
&AtClient
Procedure ImportPricesFromExternalSource(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		If ImportResult.ActionsDetails = "ChangeDataImportFromExternalSourcesMethod" Then
		
			DataImportFromExternalSources.ChangeDataImportFromExternalSourcesMethod(DataLoadSettings.DataImportFormNameFromExternalSources);
			
			NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
			DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
			
		ElsIf ImportResult.ActionsDetails = "ProcessPreparedData" Then
			
			ProcessPreparedData(ImportResult);
			ShowMessageBox(,NStr("en ='The data import is completed.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataMatchingTable	= ImportResult.DataMatchingTable;
	UpdateExisting		= ImportResult.DataLoadSettings.UpdateExisting;
	CreateNew 				= ImportResult.DataLoadSettings.CreateIfNotMatched;
	
	Try
		
		BeginTransaction();
		
		For Each TableRow IN DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			If ImportToApplicationIsPossible Then
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
					OR (NOT TableRow._RowMatched AND CreateNew);
					
					If CoordinatedStringStatus Then
						
						RecordManager 					= InformationRegisters.ProductsAndServicesPrices.CreateRecordManager();
						RecordManager.Actuality		= True;
						RecordManager.PriceKind			= TableRow.PriceKind;
						RecordManager.MeasurementUnit = TableRow.MeasurementUnit;
						RecordManager.ProductsAndServices		= TableRow.ProductsAndServices;
						RecordManager.Period			= TableRow.Date;
						
						If GetFunctionalOption("UseCharacteristics") Then
							
							RecordManager.Characteristic	= TableRow.Characteristic;
							
						EndIf;
						
						RecordManager.Price				= TableRow.Price;
						RecordManager.Author			= Users.AuthorizedUser();
						RecordManager.Write(True);
						
					EndIf;
					
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(NStr("en='Data Import'"), EventLogLevel.Error, Metadata.InformationRegisters.ProductsAndServicesPrices, , ErrorDescription());
		RollbackTransaction();
		
	EndTry;
	
EndProcedure
// End StandardSubsystems. DataLoadFromFile

#EndRegion
