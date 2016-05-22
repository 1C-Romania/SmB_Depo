////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

//// The procedure initializes document form filling by the base document
//
//
&AtClient
Procedure FillByDocumentBase()
	
	If Not ValueIsFilled(Object.BasisDocument) Then 
		
		Return;
		
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillAccordingToBasisDocumentEnd", ThisObject), NStr("en = 'Document will be completely refilled by ""Basis""! Continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillAccordingToBasisDocumentEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument();
		ProcessOperationKindChange(False);
		
		SetLabelPricesAndCurrency();
		
	EndIf;
	
EndProcedure //FillByDocumentBase()

// The procedure calls the tabular section filling processing with CCD numbers.
//
&AtServer
Procedure FillCCDNumbersAtServer()
	
	SetPrivilegedMode(True);
	
	// Receive turnovers by CCD numbers.
	TemporaryTableInventory = New ValueTable;
	
	Array = New Array;
	
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	TemporaryTableInventory.Columns.Add("ProductsAndServices", TypeDescription);
	Array.Clear();
	
	Array.Add(Type("CatalogRef.ProductsAndServicesCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	TemporaryTableInventory.Columns.Add("Characteristic", TypeDescription);
	Array.Clear();
	
	Array.Add(Type("CatalogRef.ProductsAndServicesBatches"));
	TypeDescription = New TypeDescription(Array, ,);
	TemporaryTableInventory.Columns.Add("Batch", TypeDescription);
	Array.Clear();
	
	For Each TSRow IN Object.Inventory Do
		
		NewRow = TemporaryTableInventory.Add();
		FillPropertyValues(NewRow, TSRow);
		
	EndDo;
	
	Query = New Query;
	
	Query.SetParameter("TemporaryTableInventory",	TemporaryTableInventory);
	Query.SetParameter("Company", 			SmallBusinessServer.GetCompany(Object.Company));
	
	Query.Text = 
	"SELECT
	|	InvoiceInventory.ProductsAndServices,
	|	InvoiceInventory.Characteristic,
	|	InvoiceInventory.Batch
	|INTO TableInventory
	|FROM
	|	&TemporaryTableInventory AS InvoiceInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryByCCDTurnovers.Recorder.Counterparty AS Counterparty,
	|	InventoryByCCDTurnovers.CountryOfOrigin,
	|	InventoryByCCDTurnovers.ProductsAndServices,
	|	InventoryByCCDTurnovers.Characteristic,
	|	InventoryByCCDTurnovers.Batch,
	|	InventoryByCCDTurnovers.CCDNo,
	|	InventoryByCCDTurnovers.CCDNo.Code AS CCDCode,
	|	DATETIME(1, 1, 1) AS DateCCD
	|FROM
	|	TableInventory AS TableInventory
	|		LEFT JOIN AccumulationRegister.InventoryByCCD.Turnovers(, , Record, Company = &Company) AS InventoryByCCDTurnovers
	|		ON TableInventory.ProductsAndServices = InventoryByCCDTurnovers.ProductsAndServices
	|			AND TableInventory.Characteristic = InventoryByCCDTurnovers.Characteristic
	|			AND TableInventory.Batch = InventoryByCCDTurnovers.Batch
	|			AND &ConditionOfCounterparty";
	
	If ValueIsFilled(Object.Counterparty) Then 
		
		Query.Text = StrReplace(Query.Text, "&ConditionOfCounterparty", "(InventoryByCCDTurnovers.Recorder.Counterparty = &Counterparty)");
		Query.SetParameter("Counterparty", Object.Counterparty);
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&ConditionOfCounterparty", "True");
		
	EndIf;
	
	InventoryTurnoversByCCD = Query.Execute().Unload();
	
	// Extract dates from CCD numbers (dates should be in a new format = 6 characters)
	For Each TableRow IN InventoryTurnoversByCCD Do
		
		FirstDelimiterPosition	= Find(TableRow.CCDCode, "/");
		DateCCD						= Right(TableRow.CCDCode, StrLen(TableRow.CCDCode) - FirstDelimiterPosition);
		SecondDelimiterPosition	= Find(DateCCD, "/");
		DateCCD						= Left(DateCCD, SecondDelimiterPosition - 1);
		
		If StrLen(DateCCD) = 6 Then
			
			DateDay	= Left(DateCCD, 2);
			DateMonth	= Mid(DateCCD, 3, 2);
			DateYear		= Mid(DateCCD, 5, 2);
			
			Try
				DateYear					= ?(Number(DateYear) >= 30, "19" + DateYear, "20" + DateYear);
				TableRow.DateCCD	= Date(DateYear, DateMonth, DateDay);
			Except
			
			EndTry;
			
		EndIf; 
	
	EndDo; 
	
	// Sort to receive CCD number with the newest date
	InventoryTurnoversByCCD.Sort("ProductsAndServices, Characteristic, Batch, DateCCD Desc");
	
	// Counterparty filter:
	//  - if a counterparty is specified in the document, filter is not critical
	//  - if the counterparty is empty, set the filter by the first CCD position (before finishing the first cycle integration) and fill in the field in the header
	FilterStructure = New Structure("ProductsAndServices, Characteristic, Batch");
	
	// Fill in fields in the queries table
	For Each TSRow IN Object.Inventory Do
		
		FilterStructure.ProductsAndServices	= TSRow.ProductsAndServices;
		FilterStructure.Characteristic	= TSRow.Characteristic;
		FilterStructure.Batch			= TSRow.Batch;
		
		RowsArrayCCD = InventoryTurnoversByCCD.FindRows(FilterStructure);
		
		If RowsArrayCCD.Count() < 1 Then
			
			If ValueIsFilled(TSRow.ProductsAndServices) Then
				
				TSRow.CountryOfOrigin = TSRow.ProductsAndServices.CountryOfOrigin;
				
			EndIf;
			
			Continue;
			
		EndIf;
		
		TSRow.CountryOfOrigin	= RowsArrayCCD[0].CountryOfOrigin;
		TSRow.CCDNo				= RowsArrayCCD[0].CCDNo;
		
		// Consider the counterparty if CCD from different vendors is present in the selection
		If Not FilterStructure.Property("Counterparty")
			AND ValueIsFilled(RowsArrayCCD[0].Counterparty) Then
			
			FilterStructure.Insert("Counterparty", RowsArrayCCD[0].Counterparty);
			
			// Select CCD by one counterparty, fill in field for a user if it is empty
			If Not ValueIsFilled(Object.Counterparty) Then
				
				Object.Counterparty = RowsArrayCCD[0].Counterparty;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
EndProcedure // FillCCDNumbersAtServer()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument()
	  
	Document = FormAttributeToValue("Object");
	Document.Filling(Object.BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	SetAttributesVisible();
	
EndProcedure // FillByDocument()

// It receives data set from server for the DateOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange, DocumentCurrency)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(DateNew, New Structure("Currency", DocumentCurrency));
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		DataVATRate = StructureData.ProductsAndServices.VATRate;
	Else
		DataVATRate = StructureData.Company.DefaultVATRate;
	EndIf;
	
	If StructureData.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance")
		AND ValueIsFilled(DataVATRate) AND Not DataVATRate.Calculated Then
		
		DataVATRate = SmallBusinessReUse.GetVATRateEstimated(DataVATRate);
		
	EndIf;
	
	StructureData.Insert("VATRate", DataVATRate);
	
	StructureData.Insert("Price", 0);		
	StructureData.Insert("DiscountMarkupPercent", 0);
	
	StructureData.Insert("CountryOfOrigin", StructureData.ProductsAndServices.CountryOfOrigin);
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetCompanyVATRate(StructureData)
	
	DataVATRate = StructureData.Company.DefaultVATRate;
	
	If ValueIsFilled(DataVATRate) AND Not DataVATRate.Calculated Then
		
		DataVATRate = SmallBusinessReUse.GetVATRateEstimated(DataVATRate);
		
	EndIf;
	
	StructureData.Insert("VATRate", DataVATRate);
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;	
		
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else	
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;	
	
	Return StructureData;
	
EndFunction // GetDataMeasurementUnitOnChange()

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;		
	
EndProcedure // RecalculateDocumentAmounts() 

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
		
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
	
EndProcedure // CalculateAmountInTabularSectionLine()	

// The procedure calculates the rate and ratio of
// the document currency when changing the document date.
//
&AtClient
Procedure RecalculateRateRepetitionOfDocumentCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(Object.DocumentCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(NationalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(Object.DocumentCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(NationalCurrency);
		
		MessageText = NStr("ru = 'On the document date, the document currency (" + CurrencyRateInLetters + ") exchange rate was specified.
									|Set document rate (" + RateNewCurrenciesInLetters + ") according to exchange rate?'");
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CalculateRateDocumentCurrencyRatioEnd", ThisObject, New Structure("NewUnitConversionFactor, NewExchangeRate", NewRatio, NewExchangeRate)), MessageText, Mode, 0);
        Return;		
		
	EndIf;	
	
	CalculateRateDocumentCurrencyRatioFragment();
EndProcedure

&AtClient
Procedure CalculateRateDocumentCurrencyRatioEnd(Result, AdditionalParameters) Export
    
    NewRatio = AdditionalParameters.NewRatio;
    NewExchangeRate = AdditionalParameters.NewExchangeRate;
    
    
    Response = Result;
    
    If Response = DialogReturnCode.Yes Then
        
        Object.ExchangeRate = NewExchangeRate;
        Object.Multiplicity = NewRatio;
        
    EndIf;		
    
    
    CalculateRateDocumentCurrencyRatioFragment();

EndProcedure

&AtClient
Procedure CalculateRateDocumentCurrencyRatioFragment()
    
    SetLabelPricesAndCurrency();

EndProcedure // RecalculateRateRatioOfDocumentCurrency()

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val DocumentCurrencyBeforeChange, RecalculatePrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Contract",			Object.Contract);
	ParametersStructure.Insert("ThisIsInvoice", 	True);
	ParametersStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate", 			Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity", 		Object.Multiplicity);
	ParametersStructure.Insert("Company",		Counterparty); 
	ParametersStructure.Insert("DocumentDate", 	Object.Date);
	ParametersStructure.Insert("RefillPrices", False);
	ParametersStructure.Insert("RecalculatePrices", RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("WarningText", WarningText);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("DocumentCurrencyBeforeChange", DocumentCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()	

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetAttributesVisible()
	
	CommonUseClientServer.SetFormItemProperty(Items, "Contract", "Visible", Object.Counterparty.DoOperationsByContracts);
	CommonUseClientServer.SetFormItemProperty(Items, "InvoiceNotesIssuedToCustomers", "Visible", (TypeOf(Object.BasisDocument) = Type("DocumentRef.ReportToPrincipal") AND Object.IncomingDocumentDate >= '20150101'));
	
EndProcedure // SetAttributeVisible()

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, OperationKind, Cancel)
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND Constants.DoNotPostDocumentsWithIncorrectContracts.Get() Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the settlements method.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// Performs actions when the operation kind changes.
//
&AtServer
Procedure ProcessOperationKindChange(UpdateOperations = True)
	
	If UpdateOperations Then
		Object.BasisDocument = Undefined;
		Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance") Then
		
		FilterArray = New Array;
		FilterArray.Add(Type("DocumentRef.PurchaseOrder"));
		FilterArray.Add(Type("DocumentRef.CashPayment"));
		FilterArray.Add(Type("DocumentRef.PaymentExpense"));
		
		ValidTypes = New TypeDescription(FilterArray);
		
		Items.InventoryProductsAndServices.AutoChoiceIncomplete = False;
		Items.InventoryProductsAndServices.AutoMarkIncomplete = False;
		
		For Each TSRow IN Object.Inventory Do
			
			If UpdateOperations AND ValueIsFilled(TSRow.VATRate) AND Not TSRow.VATRate.Calculated Then
				
				TSRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(TSRow.VATRate);
				
			EndIf;
		
			TSRow.CountryOfOrigin = Undefined;
			TSRow.CCDNo = Undefined;
			
		EndDo;
		
	Else
		
		For Each TSRow IN Object.Inventory Do
			
			If UpdateOperations AND ValueIsFilled(TSRow.VATRate) AND TSRow.VATRate.Calculated Then
				
				If ValueIsFilled(TSRow.ProductsAndServices.VATRate) Then
					TSRow.VATRate = TSRow.ProductsAndServices.VATRate;
				Else
					TSRow.VATRate = Object.Company.DefaultVATRate;
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If ForReturn Then
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.SupplierInvoice"));
		Else
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.AgentReport"));
			FilterArray.Add(Type("DocumentRef.ReportToPrincipal"));
			FilterArray.Add(Type("DocumentRef.SupplierInvoice"));
			FilterArray.Add(Type("DocumentRef.ExpenseReport"));
			FilterArray.Add(Type("DocumentRef.SubcontractorReport"));
			FilterArray.Add(Type("DocumentRef.AdditionalCosts"));
		EndIf;
		
		ValidTypes = New TypeDescription(FilterArray);
		
		Items.InventoryProductsAndServices.AutoChoiceIncomplete = True;
		Items.InventoryProductsAndServices.AutoMarkIncomplete = True;
		
	EndIf;
	
	If ValueIsFilled(Object.BasisDocument) 
		AND TypeOf(Object.BasisDocument) = Type("DocumentRef.AgentReport") Then
		
		Items.InventoryProductsAndServices.Visible			= False;
		Items.InventoryCharacteristic.Visible			= False;
		Items.InventoryBatch.Visible					= False;
		Items.InventoryMeasurementUnit.Visible		= False;
		Items.InventoryCountryOfOrigin.Visible	= False;
		Items.InventoryCCDNo.Visible 				= False;
		
		Items.OperationKind.Enabled				= False;
		
		Items.InventoryContent.Visible				= True;
		
	Else
		
		Items.InventoryProductsAndServices.Visible			= True;
		Items.InventoryCharacteristic.Visible			= True;
		Items.InventoryBatch.Visible					= True;
		Items.InventoryMeasurementUnit.Visible 		= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryQuantity.Visible 			= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryPrice.Visible 					= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryCountryOfOrigin.Visible 	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryCCDNo.Visible 				= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		
		Items.GroupFillCCDNumbers.Enabled 	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.SetCCDNumber.Enabled 		= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		
		Items.InventoryContent.Visible				= False;
		
	EndIf;
	
	Items.BasisDocument.TypeRestriction = ValidTypes;
	
EndProcedure // ProcessOperationKindChange()

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange	= Contract;
	Contract 				= Object.Contract;
		
	If ContractBeforeChange <> Object.Contract Then
		
		StructureData = GetDataContractOnChange(Object.Date, Object.Contract);
		
		SettlementsCurrencyBeforeChange = Object.DocumentCurrency;
		SettlementsCurrency = StructureData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then 
			
			Object.ExchangeRate		= ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0,		1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity= ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0,	1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
			
		EndIf;
		
		Object.DocumentCurrency = StructureData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract)
			AND ValueIsFilled(StructureData.SettlementsCurrency)
			AND Object.Contract <> ContractBeforeChange
			AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
			AND Object.Inventory.Count() > 0 Then
			
			WarningText = NStr("en = 'Settlement currency of the contract with counterparty changed! 
				|It is necessary to check the document currency!'");
			
			ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, WarningText);
			
		EndIf;
		
		SetLabelPricesAndCurrency();
		
	EndIf;
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Object.Company, Object.OperationKind);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	SetAttributesVisible();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, Contract)
		
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);	
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		False
	);
	
	Return StructureData;
	
EndFunction // GetDataContractOnChange()

// Function checks products and services by type
//
&AtServerNoContext
Function ProductsAndServicesTypeInventory(ProductsAndServicesRef)
	
	Return ProductsAndServicesRef.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
	
EndFunction // ProductsAndServicesInventory()

// The function puts inventories list to the temporary storage and returns an address 
//
&AtServer
Function PlaceInventoryToStorage() 
	
	Return PutToTempStorage(Object.Inventory.Unload(), UUID);
	
EndFunction // PlaceInventoryToStorage()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		NewRow.CountryOfOrigin = NewRow.ProductsAndServices.CountryOfOrigin; 
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

// The procedure receives the list of goods and CCD number from the temporary storage
//
&AtServer
Procedure GetInventoryOfStoreForFillCCDNumbers(InventoryAddressInStorage, TabularSectionName)
	
	Object[TabularSectionName].Clear();
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

// Peripherals

// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		InformationRegisters.ProductsAndServicesBarcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsAndServicesData = New Structure();
			StructureProductsAndServicesData.Insert("Company", StructureData.Company);
			StructureProductsAndServicesData.Insert("OperationKind", StructureData.OperationKind);
			StructureProductsAndServicesData.Insert("ProductsAndServices", BarcodeData.ProductsAndServices);
			StructureProductsAndServicesData.Insert("Characteristic", BarcodeData.Characteristic);
			BarcodeData.Insert("StructureProductsAndServicesData", GetDataProductsAndServicesOnChange(StructureProductsAndServicesData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			
		EndIf; 
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,Batch,MeasurementUnit",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.CountryOfOrigin = BarcodeData.StructureProductsAndServicesData.CountryOfOrigin;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsAndServicesData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsAndServicesData.VATRate;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				Items.Inventory.CurrentRow = FoundString.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction // FillByBarcodesData()

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.ProductsAndServicesBarcodes.Form.ProductsAndServicesBarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure // BarcodesAreReceived()

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement IN ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement IN ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode IN UnknownBarcodes Do
		
		MessageString = NStr("en = 'Data by barcode is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

////////////////////////////////////////////////////////////////////////////////
// Subsystem 'ElectronicDocuments'

&AtServer
Procedure SetEDStateTextAtServer()
	
	EDStateText = ElectronicDocumentsClientServer.GetTextOfEDState(Object.Ref, ThisForm);
	
EndProcedure

// Event handler of clicking the EDState attribute
//
&AtClient
Procedure EDStateClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Uniqueness",	Object.Ref.UUID());
	OpenParameters.Insert("Source",		ThisForm);
	OpenParameters.Insert("Window", 			ThisForm.Window);
	
	ElectronicDocumentsClient.OpenEDTree(Object.Ref, OpenParameters);
	
EndProcedure // EDStateClick()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtClient
Procedure SetLabelPricesAndCurrency()
	
	If ValueIsFilled(Object.DocumentCurrency) Then
		
		PricesAndCurrency = NStr("en = '%Currency%'");
		PricesAndCurrency = StrReplace(PricesAndCurrency, "%Currency%", TrimAll(String(Object.DocumentCurrency)));
		
	Else
		
		PricesAndCurrency = NStr("en = 'The currency is not specified'");
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("ForReturn", ForReturn);
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	If TypeOf(Parameters.Basis) = Type("DocumentRef.CashPayment") OR TypeOf(Parameters.Basis) = Type("DocumentRef.PaymentExpense") Then
	
		Document = ?(TypeOf(Parameters.Basis) = Type("DocumentRef.CashPayment"), "CashPayment", "PaymentExpense");
		
		Query = New Query(
		"SELECT TOP 1
		|		CashExpensePaymentDetails.Contract AS Contract
		|	FROM
		|		Document." + Document + ".PaymentDetails
		|	AS
		|	CashExpensePaymentDetails WHERE CashExpensePaymentDetails.Ref
		|		= &Ref AND CashExpensePaymentDetails.AdvanceFlag"
		);
		                 
		Query.SetParameter("Ref", Parameters.Basis);
			
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			DoNotOpenForm = True;
			Return;
		EndIf;
	
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If Not ValueIsFilled(Object.DocumentCurrency) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
		EndIf;
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	
	NationalCurrency 			= Constants.NationalCurrency.Get();
	StructureByCurrency			= InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", NationalCurrency));
	RateNationalCurrency 		= StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance") Then
		
		FilterArray = New Array;
		FilterArray.Add(Type("DocumentRef.PurchaseOrder"));
		FilterArray.Add(Type("DocumentRef.CashPayment"));
		FilterArray.Add(Type("DocumentRef.PaymentExpense"));
		
		ValidTypes = New TypeDescription(FilterArray);
		
		Items.InventoryProductsAndServices.AutoChoiceIncomplete = False;
		Items.InventoryProductsAndServices.AutoMarkIncomplete = False;
		
	Else
		
		If ForReturn Then
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.SupplierInvoice"));
		Else
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.AgentReport"));
			FilterArray.Add(Type("DocumentRef.ReportToPrincipal"));
			FilterArray.Add(Type("DocumentRef.SupplierInvoice"));
			FilterArray.Add(Type("DocumentRef.ExpenseReport"));
			FilterArray.Add(Type("DocumentRef.SubcontractorReport"));
			FilterArray.Add(Type("DocumentRef.AdditionalCosts"));
		EndIf;
		
		ValidTypes = New TypeDescription(FilterArray);
		
		Items.InventoryProductsAndServices.AutoChoiceIncomplete = True;
		Items.InventoryProductsAndServices.AutoMarkIncomplete = True;
		
	EndIf;
	
	//When there is the ReportToPrincipal base, items visible management takes another form
	If ValueIsFilled(Object.BasisDocument) 
		AND TypeOf(Object.BasisDocument) = Type("DocumentRef.AgentReport") Then
		
		Items.InventoryProductsAndServices.Visible			= False;
		Items.InventoryCharacteristic.Visible			= False;
		Items.InventoryBatch.Visible					= False;
		Items.InventoryMeasurementUnit.Visible		= False;
		Items.InventoryCountryOfOrigin.Visible	= False;
		Items.InventoryCCDNo.Visible 				= False;
		
		Items.OperationKind.Enabled				= False;
		
		Items.InventoryContent.Visible				= True;
		
	Else
		
		Items.InventoryMeasurementUnit.Visible 		= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryQuantity.Visible 			= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryPrice.Visible 					= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryCountryOfOrigin.Visible 	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.InventoryCCDNo.Visible 				= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		
		Items.GroupFillCCDNumbers.Enabled 	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		Items.SetCCDNumber.Enabled 		= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance"));
		
		Items.InventoryContent.Visible				= False;
		
	EndIf;
	
	Items.BasisDocument.TypeRestriction = ValidTypes;
	
	// CCD numbers
	If Not ValueIsFilled(Object.Ref)
		AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance")) 
		AND Object.Inventory.Count() > 0 Then
		
		FillCCDNumbersAtServer();
		
	EndIf;
	
	// For CIN based on the commission document:
	// If you can not see that there are no products and services, then you need to enable visible for a content
	If Not (Items.InventoryProductsAndServices.Visible 
		AND Items.InventoryContent.Visible) Then
		
		Items.InventoryContent.Visible = True;
		
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices()
		OR IsInRole("AddChangePurchasesSubsystem");
	
	Items.InventoryPrice.ReadOnly 		= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 	= Not AllowedEditDocumentPrices;
	
	If ForReturn Then
		
		NewArray = New Array();
		NewArray.Add(Enums.OperationKindsSupplierInvoice.ReturnFromAgent);
		NewArray.Add(Enums.OperationKindsSupplierInvoice.ReturnFromSubcontractor);
		NewArray.Add(Enums.OperationKindsSupplierInvoice.ReturnFromCustomer);
		NewArray.Add(Enums.OperationKindsSupplierInvoice.ReturnFromSafeCustody);
		AvailableOperationKindsArray = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.OperationKind", AvailableOperationKindsArray);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
		
	EndIf;
	
	// Setting contract visible.
	SetAttributesVisible();
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	// End PickProductsAndServicesInDocuments
	
	// Subsystem 'ElectronicDocuments'
	SetEDStateTextAtServer();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

// Procedure-handler of the BeforeWriteAtServer event.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Document is not posted! '") + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
			EndIf;
			Message.Message();
			
		EndIf;
		
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// If you open this form from the document form, then you should change the text there
	If Not FormOwner = Undefined Then
		
		If TypeOf(FormOwner) = Type("ManagedForm") Then
			
			CloseOnChoice = False;
			
			If Find(FormOwner.FormName, "DocumentForm") <> 0 AND FormOwner.Object.Ref = Object.BasisDocument Then
				
				NotifyChoice(SmallBusinessClient.InvoicePresentation(Object.Date, Object.Number));
				
			Else
				
				NotifyChoice("Enter invoice note");
				
				Structure = New Structure;
				Structure.Insert("BasisDocument", Object.BasisDocument);
				Structure.Insert("Presentation", SmallBusinessClient.InvoicePresentation(Object.Date, Object.Number));
				Notify("RefreshOfTextAboutInvoiceReceived", Structure);
				
			EndIf;
			
		EndIf;
		
	Else
		
		Structure = New Structure;
		Structure.Insert("BasisDocument", Object.BasisDocument);
		Structure.Insert("Presentation", SmallBusinessClient.InvoicePresentation(Object.Date, Object.Number));
		Notify("RefreshOfTextAboutInvoiceReceived", Structure);
		
	EndIf;
	
EndProcedure // AfterWrite()

// Procedure - handler of the AfterWriteAtServer event.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Subsystem 'ElectronicDocuments'
	SetEDStateTextAtServer();
	
EndProcedure // AfterWriteOnServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If DoNotOpenForm Then
		Cancel = True;
	Else	
		SetLabelPricesAndCurrency();
	EndIf;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure // OnOpen()

// Procedure - event handler ChoiceProcessing.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Catalog.CCDNumbers.Form.ChoiceForm" Then
		
		For Each RowID IN Items.Inventory.SelectedRows Do
			
			StringInventory = Object.Inventory.FindByID(RowID);
			If StringInventory = Undefined Then
				Continue;
			Else
				StringInventory.CCDNo = ValueSelected;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			//Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	// Subsystem 'ElectronicDocuments'
	If EventName = "RefreshStateED" Then
		
		SetEDStateTextAtServer();
		
	ElsIf EventName = "UpdateIBDocumentAfterFilling" Then
		
		ThisForm.Read();
		
	EndIf;
	// End "ElectronicDocuments" subsystem
	
	If EventName = "AfterRecordingOfCounterparty"
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetAttributesVisible();
		
	ElsIf EventName = "FillingNumbersOfCFD"
		AND ValueIsFilled(Parameter) 
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		InventoryAddressInStorage = Parameter;
		
		GetInventoryOfStoreForFillCCDNumbers(InventoryAddressInStorage, "Inventory");
		
	ElsIf EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		InventoryAddressInStorage = Parameter;
		
		GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
		
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange, Object.DocumentCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(Object.DocumentCurrency) Then
			RecalculateRateRepetitionOfDocumentCurrency(StructureData);
		EndIf;	
		
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	ProcessContractChange();
	
EndProcedure // OperationKindOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance") Then
		
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
			
		StructureData = GetCompanyVATRate(StructureData);
	
		TabularSectionRow.VATRate = StructureData.VATRate;
		
	EndIf;

EndProcedure

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity 			= 1;
	TabularSectionRow.Price 					= StructureData.Price;
	TabularSectionRow.VATRate 				= StructureData.VATRate;
	TabularSectionRow.Content 			= "";
	TabularSectionRow.CountryOfOrigin 	= StructureData.CountryOfOrigin;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Inventory.CurrentData;
		ContentPattern = SmallBusinessServer.GetContentText(TabularSectionRow.ProductsAndServices, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryQuantityOnChange()

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;	
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;	
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf; 		
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryPriceOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.	
	TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
	
EndProcedure // InventoryAmountOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.	
	TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
	
EndProcedure  // InventoryVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.	
	TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;	
	
EndProcedure // InventoryVATAmountOnChange()

// Procedure - OnChange event handler of the Total input field.
//
&AtClient
Procedure InventoryTotalOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);	
	TabularSectionRow.VATAmount = TabularSectionRow.Total * VATRate / (100 + VATRate);		
	TabularSectionRow.Amount = TabularSectionRow.Total * 100 / (100 + VATRate);
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange(Object.Counterparty);
		Object.Contract = StructureData.Contract;
		
		ProcessContractChange();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Contract input field.
// Fills form attributes - exchange rate and multiplicity.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure // ContractOnChange()

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the BasisDocument input field.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	FillByDocumentBase();
	
EndProcedure // BasisDocumentOnChange()

// Procedure - SelectionProcessing event handler of the OriginCountry field of the Inventory tabular section
//
&AtClient
Procedure InventoryCountryOfOriginChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	DataCurrentRows = Items.Inventory.CurrentData;
	
	If DataCurrentRows <> Undefined
		AND ValueIsFilled(ValueSelected) Then
		
		If ValueIsFilled(DataCurrentRows.ProductsAndServices)
			AND Not ProductsAndServicesTypeInventory(DataCurrentRows.ProductsAndServices) Then
			
			ValueSelected = Undefined;
			
			MessageText = NStr("en = 'CCD account is kept only for products and services with the ""Inventory"" type.'");
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure // InventoryCountryOfOriginChoiceProcessing()

// Procedure - SelectionProcessing event handler of the CCDNumber field of the Inventory tabular section
//
&AtClient
Procedure InventoryCCDNumberChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	DataCurrentRows = Items.Inventory.CurrentData;
	
	If DataCurrentRows <> Undefined 
		AND ValueIsFilled(ValueSelected) Then
		
		MessageText = "";
		
		If (ValueIsFilled(DataCurrentRows.ProductsAndServices) 
			AND Not ProductsAndServicesTypeInventory(DataCurrentRows.ProductsAndServices)) Then
			
			ValueSelected = Undefined;
			
			MessageText = NStr("en = 'CCD account is kept only for products and services with the ""Inventory"" type.'");
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
		If Not ValueIsFilled(DataCurrentRows.CountryOfOrigin)
			OR	(ValueIsFilled(DataCurrentRows.CountryOfOrigin)
					AND DataCurrentRows.CountryOfOrigin = PredefinedValue("Catalog.WorldCountries.Russia")) Then
			
			ValueSelected = Undefined;
			
			MessageText = NStr("en = 'CCD accounting for the native products is not kept!'");
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure // InventoryCCDNumberChoiceProcessing()

&AtClient
Procedure IncomingDocumentDateOnChange(Item)
	
	SetAttributesVisible();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - FillIn button click handler.
//
&AtClient
Procedure Fill(Command)
	
	FillByDocumentBase();
	
EndProcedure  // FillExecute()

// Procedure - FillInCCDNumbers button clicking handler.
//
&AtClient
Procedure FillCCDNumbers(Command)
	
	If Object.Inventory.Count() < 1 Then
		
		MessageText = NStr("en = 'Unfilled tabular section with inventory. An execution is impossible.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
		
	QuestionText = NStr("en = 'The column ""Origin country"" and ""CCD number"" columns will be refilled in the tabular section. Continue?'");
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillInCCDNumbersEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillInCCDNumbersEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        FillCCDNumbersAtServer(); 
        
    EndIf;

EndProcedure

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName = "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			Counterparty);
	SelectionParameters.Insert("DocumentOrganization",	Object.Company);
	SelectionParameters.Insert("VATTaxation",		PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT"));
	SelectionParameters.Insert("AmountIncludesVAT",		False);
	SelectionParameters.Insert("Currency", 				Object.DocumentCurrency);
	SelectionParameters.Insert("ThisIsReceiptDocument",	True);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.InventoryPrice.ReadOnly);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoiceNote.Advance") Then
		SelectionParameters.Insert("AccrualVATRate", True);
	EndIf;
	
	ProductsAndServicesType = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "ProductsAndServices"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.ProductsAndServicesType" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					ProductsAndServicesType.Add(FixArrayItem);
				EndDo; 
			Else
				ProductsAndServicesType.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	SelectionParameters.Insert("ProductsAndServicesType", ProductsAndServicesType);
	
	BatchStatus = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo;
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExecutePick()

// PickupCCDNumbers command handler procedure
//
&AtClient
Procedure PickupCCDNumbers(Command)
	
	If Object.Inventory.Count() < 1 Then
		
		MessageText = NStr("en = 'Unfilled tabular section with inventory. An execution is impossible.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("DocumentDate", Object.Date); 
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	SelectionParameters.Insert("InventoryAddressInStorage", PlaceInventoryToStorage());
	
	OpenForm("CommonForm.PickupCCDNumbers", SelectionParameters);
	
EndProcedure // PickupCCDNumbers()

// Procedure - SetCCDNumber button clicking handler.
//
&AtClient
Procedure SetCCDNumber(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TabularSectionRow = Undefined Then
		MessageText = NStr("en = 'The tabular section row is not selected. An execution is impossible.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	OpenForm("Catalog.CCDNumbers.ChoiceForm",, ThisForm);
	
EndProcedure // SetCCDNumber()

// Procedure - PricesAndCurrency attribute clicking handler
//
&AtClient
Procedure PricesAndCurrencyClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure // PricesAndCurrencyClick()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

// Peripherals

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
    EndIf;

EndProcedure // SearchByBarcode()

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='It is required to select a line to get weight for it.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NOTifyDescription, UUID);
		
	EndIf;
	
EndProcedure // GetWeight()

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'Electronic scales returned zero weight.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure")
		AND ClosingResult.WereMadeChanges Then
		
		Modified		= True;
		
		Object.DocumentCurrency	= ClosingResult.DocumentCurrency;
		Object.ExchangeRate				= ClosingResult.PaymentsRate;
		Object.Multiplicity		= ClosingResult.SettlementsMultiplicity;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, AdditionalParameters.DocumentCurrencyBeforeChange, "Inventory");
			
		EndIf;
		
	EndIf;
	
	SetLabelPricesAndCurrency();
	
EndProcedure // OpenPricesAndCurrencyFormEnd()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
