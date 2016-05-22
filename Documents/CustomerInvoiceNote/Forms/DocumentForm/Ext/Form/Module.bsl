
#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure CheckCCD(CCDNo, DateCCD)
	
	SmallBusinessServer.FillDateByCCDNumber(String(CCDNo), DateCCD);
	
EndProcedure

// The procedure initializes document form filling by the base document
//
&AtClient
Procedure FillByDocumentBase()
	
	If Not ValueIsFilled(Object.BasisDocument) 
		AND Object.BasisDocuments.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	QuestionText = NStr("en = 'The document will be completely refilled by ""Base"".
								|Continue?'");
								
	NotifyDescription = New NotifyDescription("DetermineNeedForDocumentFillByBasis", ThisObject);
	
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure // FillByDocumentBase()

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
		
		QuestionText = NStr("ru = 'On the document date, the document currency (" + CurrencyRateInLetters + ") exchange rate was specified.
									|Set document rate (" + RateNewCurrenciesInLetters + ") according to exchange rate?'");
									
		NewCurrencyRateUnitConversionFactor = New Structure;
		NewCurrencyRateUnitConversionFactor.Insert("NewExchangeRate", NewExchangeRate);
		NewCurrencyRateUnitConversionFactor.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("DetermineNewCurrencyRateAndUnitConversionFactorSettingNeed", ThisObject, NewCurrencyRateUnitConversionFactor);
		
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure // RecalculateRateRatioOfDocumentCurrency()

// The procedure sets the possibility to edit base documents with a list.
//
&AtClient
Procedure SetEditInListOption()
	
	Items.BasisDocumentsEditInList.Check = Not Items.BasisDocumentsEditInList.Check;
	
	LineCount = Object.BasisDocuments.Count();
	
	If Not Items.BasisDocumentsEditInList.Check
		  AND Object.BasisDocuments.Count() > 1 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)), 
			NStr("en='All specified base documents except for the first one will be deleted from the list. Continue?'"),
			QuestionDialogMode.YesNo
		);
        Return;
		
	EndIf;
	
	SetEditInListFragmentOption();
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
    
    LineCount = AdditionalParameters.LineCount;
    
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Items.BasisDocumentsEditInList.Check = True;
        Return;
    EndIf;
    
    While LineCount > 1 Do
        Object.BasisDocuments.Delete(Object.BasisDocuments[LineCount - 1]);
        LineCount = LineCount - 1;
    EndDo;
    
    Object.BasisDocument = Object.BasisDocuments[0].BasisDocument;
    
    
    SetEditInListFragmentOption();

EndProcedure

&AtClient
Procedure SetEditInListFragmentOption()
    
    If Items.BasisDocumentsEditInList.Check Then
        Items.BasisPages.CurrentPage = Items.PageBasisDocuments;
    Else
        Items.BasisPages.CurrentPage = Items.PageBasisDocument;
    EndIf;

EndProcedure // SetEditByListOption()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument()
	
	Document = FormAttributeToValue("Object");
	Document.Filling(New Structure("FillByBasisDocuments", True), );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	SetContractVisible();
	
EndProcedure // FillByDocument()

// The procedure calls the tabular section filling processing with CCD numbers.
//
&AtServer
Procedure FillCCDNumbersAtServer()
	
	SetPrivilegedMode(True);
	
	// RECEIVE BALANCE BY CCD
	TemporaryTableInventory = New ValueTable;
	
	Array = New Array;
	
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TemporaryTableInventory.Columns.Add("ProductsAndServices", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsAndServicesCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TemporaryTableInventory.Columns.Add("Characteristic", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsAndServicesBatches"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TemporaryTableInventory.Columns.Add("Batch", TypeDescription);
	
	For Each TSRow IN Object.Inventory Do
		
		NewRow					= TemporaryTableInventory.Add();
		NewRow.ProductsAndServices	= TSRow.ProductsAndServices;
		NewRow.Characteristic	= TSRow.Characteristic;
		NewRow.Batch			= TSRow.Batch;
		
	EndDo;
	
	Query = New Query(
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
	|	InventoryBalanceOnRegisterCCD.CountryOfOrigin,
	|	SUM(InventoryBalanceOnRegisterCCD.QuantityBalance) AS QuantityBalance,
	|	InventoryBalanceOnRegisterCCD.ProductsAndServices,
	|	InventoryBalanceOnRegisterCCD.Characteristic,
	|	InventoryBalanceOnRegisterCCD.Batch,
	|	InventoryBalanceOnRegisterCCD.CCDNo,
	|	InventoryBalanceOnRegisterCCD.CCDNo.Code AS CCDCode,
	|	InventoryBalanceOnRegisterCCD.DateCCD AS DateCCD
	|FROM
	|	(SELECT
	|		InventoryByCCDBalances.CountryOfOrigin AS CountryOfOrigin,
	|		InventoryByCCDBalances.QuantityBalance AS QuantityBalance,
	|		InventoryByCCDBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryByCCDBalances.Characteristic AS Characteristic,
	|		InventoryByCCDBalances.Batch AS Batch,
	|		InventoryByCCDBalances.CCDNo AS CCDNo,
	|		InventoryByCCDBalances.CCDNo.Code AS CCDCode,
	|		DATETIME(1, 1, 1) AS DateCCD
	|	FROM
	|		TableInventory AS TableInventory
	|			LEFT JOIN AccumulationRegister.InventoryByCCD.Balance(, Company = &Company) AS InventoryByCCDBalances
	|			ON TableInventory.ProductsAndServices = InventoryByCCDBalances.ProductsAndServices
	|				AND TableInventory.Characteristic = InventoryByCCDBalances.Characteristic
	|				AND TableInventory.Batch = InventoryByCCDBalances.Batch
	|	WHERE
	|		InventoryByCCDBalances.QuantityBalance > 0
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentDocumentInvoice.CountryOfOrigin,
	|		CASE
	|			WHEN CurrentDocumentInvoice.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(CurrentDocumentInvoice.Quantity, 0)
	|			ELSE -ISNULL(CurrentDocumentInvoice.Quantity, 0)
	|		END,
	|		CurrentDocumentInvoice.ProductsAndServices,
	|		CurrentDocumentInvoice.Characteristic,
	|		CurrentDocumentInvoice.Batch,
	|		CurrentDocumentInvoice.CCDNo,
	|		CurrentDocumentInvoice.CCDNo.Code,
	|		DATETIME(1, 1, 1)
	|	FROM
	|		AccumulationRegister.InventoryByCCD AS CurrentDocumentInvoice
	|	WHERE
	|		CurrentDocumentInvoice.Recorder = &Ref
	|		AND CurrentDocumentInvoice.Period <= &Period
	|		AND CurrentDocumentInvoice.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalanceOnRegisterCCD
	|
	|GROUP BY
	|	InventoryBalanceOnRegisterCCD.CountryOfOrigin,
	|	InventoryBalanceOnRegisterCCD.ProductsAndServices,
	|	InventoryBalanceOnRegisterCCD.Characteristic,
	|	InventoryBalanceOnRegisterCCD.Batch,
	|	InventoryBalanceOnRegisterCCD.CCDNo,
	|	InventoryBalanceOnRegisterCCD.CCDNo.Code,
	|	InventoryBalanceOnRegisterCCD.DateCCD");
	
	Query.SetParameter("Period", Object.Date);
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("TemporaryTableInventory", TemporaryTableInventory);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Object.Company));
	BalancesByCCD = Query.Execute().Unload();
	
	// Extract dates from CCD numbers (dates should be in a new format = 6 characters)
	For Each TableRow IN BalancesByCCD Do
		
		SmallBusinessServer.FillDateByCCDNumber(TableRow.CCDCode, TableRow.DateCCD);
		
		//
		// Delete extra strings. Document date can not be later than the CCD number.
		//
		
	EndDo; 
	
	BalancesByCCD.Sort("ProductsAndServices, Characteristic, Batch, DateCCD");
	
	// BALANCE DIVERSITY
	TableInventory	= Object.Inventory.Unload();
	TableInventory.Clear();
	
	FilterStructure	= New Structure("ProductsAndServices, Characteristic, Batch");
	
	For Each TSRow IN Object.Inventory Do
		
		AmountByRow		= TSRow.Amount;
		VATAmountByRow	= TSRow.VATAmount;
		TotalOnLine		= TSRow.Total;
		
		FilterStructure.ProductsAndServices	= TSRow.ProductsAndServices;
		FilterStructure.Characteristic	= TSRow.Characteristic;
		FilterStructure.Batch			= TSRow.Batch;
		
		RowsArrayCCD		= BalancesByCCD.FindRows(FilterStructure);
		
		QuantityBalance	= TSRow.Quantity;
		For Each ArrayRow IN RowsArrayCCD Do
			
			NewRow = TableInventory.Add();
			FillPropertyValues(NewRow, TSRow);
			
			NewRow.CCDNo			= ArrayRow.CCDNo;
			NewRow.CountryOfOrigin	= ArrayRow.CountryOfOrigin;
			
			If QuantityBalance <= ArrayRow.QuantityBalance Then
				
				NewRow.Quantity			= QuantityBalance;
				ArrayRow.QuantityBalance	= ArrayRow.QuantityBalance - QuantityBalance;
				QuantityBalance				= 0;
				BalancesByCCD.Delete(ArrayRow);
				
				NewRow.Amount		= AmountByRow;
				NewRow.VATAmount	= VATAmountByRow;
				NewRow.Total		= TotalOnLine;
				
				Break;
				
			Else
				
				NewRow.Quantity	= ArrayRow.QuantityBalance;
				QuantityBalance		= QuantityBalance - ArrayRow.QuantityBalance;
				BalancesByCCD.Delete(ArrayRow);
				
				NewRow.Amount		= NewRow.Quantity * NewRow.Price;
				VATRate				= ?(ValueIsFilled(NewRow.VATRate), NewRow.VATRate.Rate, 0);
				NewRow.VATAmount	= NewRow.Amount * VATRate / 100;
				NewRow.Total		= NewRow.Amount + NewRow.VATAmount;
				
				AmountByRow			= AmountByRow - NewRow.Amount;
				VATAmountByRow		= VATAmountByRow - NewRow.VATAmount;
				TotalOnLine			= TotalOnLine - NewRow.Total;
				
			EndIf;
			
		EndDo;
		
		If QuantityBalance > 0 Then
		
			NewRow				= TableInventory.Add();
			FillPropertyValues(NewRow, TSRow);
			
			NewRow.Quantity			= QuantityBalance;
			NewRow.CCDNo			= Catalogs.CCDNumbers.EmptyRef();
			NewRow.CountryOfOrigin = TSRow.ProductsAndServices.CountryOfOrigin;
			
			NewRow.Amount				= AmountByRow;
			NewRow.VATAmount			= VATAmountByRow;
			NewRow.Total				= TotalOnLine;
			
		EndIf;
	
	EndDo;
	
	Object.Inventory.Load(TableInventory);
	
	SetPrivilegedMode(False);
	
EndProcedure // FillCCDNumbersAtServer()

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	
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
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Object.Company));
	
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
	
	If StructureData.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance") 
		AND ValueIsFilled(DataVATRate) AND Not DataVATRate.Calculated Then
		
		DataVATRate = SmallBusinessReUse.GetVATRateEstimated(DataVATRate);
		
	EndIf;
	
	StructureData.Insert("VATRate", DataVATRate);
	
	StructureData.Insert("Price", 0);		
	StructureData.Insert("DiscountMarkupPercent", 0);
	StructureData.Insert("CountryOfOrigin", StructureData.ProductsAndServices.CountryOfOrigin);
	
	If Not StructureData.Property("Quantity") Then 
		StructureData.Insert("Quantity", 1);
	EndIf;
	
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
	
EndFunction // GetCompanyVATRate()

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
	
	SetContractVisible();
	
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

// The procedure puts the table to the storage.
//
&AtServer
Function PutPaymentDocumentsToStorage()
	
	Return PutToTempStorage(
		Object.PaymentDocumentsDateNumber.Unload(),
		UUID
	);
	
EndFunction // PutPaymentDocumentsToStorage()

// The procedure receives the table from the storage.
//
&AtServer
Procedure GetPaymentDocumentsFromStorage(AddressPaymentDocumentsInStorage)
	
	TableForImport = GetFromTempStorage(AddressPaymentDocumentsInStorage);
	Object.PaymentDocumentsDateNumber.Load(TableForImport);
	
EndProcedure // GetPaymentDocumentsFromStorage()

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
	
EndProcedure // SetContractVisible()

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
		Object.BasisDocuments.Clear();
		Object.BasisDocument = Undefined;
		Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	EndIf;
	
	IsAdvance = (Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		
	CommonUseClientServer.SetFormItemProperty(Items, "GroupVisibleManagementWhenAdvances", "Visible", Not IsAdvance);
	
	If IsAdvance Then
		
		FilterArray = New Array;
		FilterArray.Add(Type("DocumentRef.InvoiceForPayment"));
		FilterArray.Add(Type("DocumentRef.CashReceipt"));
		FilterArray.Add(Type("DocumentRef.PaymentReceipt"));
		
		ValidTypesBasisDocument = New TypeDescription(FilterArray);
		
		Items.InventoryProductsAndServices.AutoChoiceIncomplete		= False;
		Items.InventoryProductsAndServices.AutoMarkIncomplete	= False;
		
		For Each TSRow IN Object.Inventory Do
			
			If UpdateOperations AND ValueIsFilled(TSRow.VATRate) AND Not TSRow.VATRate.Calculated Then
				
				TSRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(TSRow.VATRate);
				
			EndIf;
		
			TSRow.CountryOfOrigin = Undefined;
			TSRow.CCDNo = Undefined;
			
		EndDo;
		
		Object.Consignor = Undefined;;
		Object.Consignee = Undefined;
		
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
			FilterArray.Add(Type("DocumentRef.CustomerInvoice"));
		Else
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.CustomerInvoice"));
			FilterArray.Add(Type("DocumentRef.AcceptanceCertificate"));
			FilterArray.Add(Type("DocumentRef.CustomerOrder"));
			FilterArray.Add(Type("DocumentRef.AgentReport"));
			FilterArray.Add(Type("DocumentRef.ReportToPrincipal"));
		EndIf;
		
		ValidTypesBasisDocument = New TypeDescription(FilterArray);
		
		Items.InventoryProductsAndServices.AutoChoiceIncomplete		= True;
		Items.InventoryProductsAndServices.AutoMarkIncomplete	= True;
		
		If ValueIsFilled(Object.Consignor) Then
			Items.Consignor.Enabled = True;
			Object.Same = False;
		Else
			Items.Consignor.Enabled = False;
			Object.Same = True;
		EndIf;
		
	EndIf;
	
	Items.BasisDocument.TypeRestriction = ValidTypesBasisDocument;
	
	If ValueIsFilled(Object.BasisDocument)
		AND TypeOf(Object.BasisDocument) = Type("DocumentRef.ReportToPrincipal") Then
		
		Items.InventoryContent.Visible 			= True;
		
		Items.InventoryProductsAndServices.Visible			= False;
		Items.InventoryCharacteristic.Visible			= False;
		Items.InventoryBatch.Visible 				= False;
		Items.InventoryMeasurementUnit.Visible 		= False;
		Items.InventoryCountryOfOrigin.Visible	= False;
		Items.InventoryCCDNo.Visible				= False;
		Items.OperationKind.Enabled 				= False;
		
	Else
		
		Items.InventoryProductsAndServices.Visible			= True;
		Items.InventoryCharacteristic.Visible			= True;
		Items.InventoryBatch.Visible 				= True;
		
		Items.InventoryMeasurementUnit.Visible 		= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryQuantity.Visible 			= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryPrice.Visible 					= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryCountryOfOrigin.Visible 	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryCCDNo.Visible 				= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		
		Items.GroupFillCCDNumbers.Enabled	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.SetCCDNumber.Enabled			= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.OperationKind.Enabled 				= True;
		
	EndIf;
	
EndProcedure // ProcessOperationKindChange()

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
		
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

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val DocumentCurrencyBeforeChange, RecalculatePrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Contract",			Object.Contract);
	ParametersStructure.Insert("ThisIsInvoice",	True);
	ParametersStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate", 			Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity", 		Object.Multiplicity);
	ParametersStructure.Insert("Company",		Counterparty); 
	ParametersStructure.Insert("DocumentDate",	Object.Date);
	ParametersStructure.Insert("RefillPrices",False);
	ParametersStructure.Insert("RecalculatePrices", RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",False);
	ParametersStructure.Insert("WarningText",WarningText);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("DocumentCurrencyBeforeChange", DocumentCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()

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

// ElectronicInteraction.ElectronicDocuments

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

// End ElectronicInteraction.ElectronicDocuments

#EndRegion

#Region AppearanceManagement

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
		
		PricesAndCurrency = NStr("en = '<Currency is not specified>'");
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

// The procedure sets the payment document label.
//
// Parameters:
//  No.
//
&AtClient
Procedure SetLabelPaymentDocuments()
	
	PaymentDocuments = "";
	
	If Object.PaymentDocumentsDateNumber.Count() = 0 Then
		PaymentDocuments = NStr("en='Edit...'");
	EndIf;
	
	For Each CurRow IN Object.PaymentDocumentsDateNumber Do
		PaymentDocuments =
			?(PaymentDocuments = "", "", PaymentDocuments + ", ")
		  + "# "
		  + CurRow.PaymentAccountingDocumentNumber
		  + " from "
		  + Format(CurRow.PaymentAccountingDocumentDate, "DF=dd.MM.yy");
	EndDo;
	  
	If Object.PaymentDocumentsDateNumber.Count() = 1 Then
		Items.PaymentDocuments.Title = "Payment document";
	Else
		Items.PaymentDocuments.Title = "Payment document";
	EndIf;
	
EndProcedure // SetLabelPaymentDocuments()

#EndRegion

#Region FormEvents

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
	
	If TypeOf(Parameters.Basis) = Type("DocumentRef.CashReceipt") OR TypeOf(Parameters.Basis) = Type("DocumentRef.PaymentReceipt") Then
	
		Document = ?(TypeOf(Parameters.Basis) = Type("DocumentRef.CashReceipt"), "CashReceipt", "PaymentReceipt");
		
		Query = New Query(
		"SELECT TOP 1
		|		CashReceiptPaymentDetails.Contract AS Contract
		|	FROM
		|		Document." + Document + ".PaymentDetails
		|	AS
		|	CashReceiptPaymentDetails WHERE CashReceiptPaymentDetails.Ref
		|		= &Ref AND CashReceiptPaymentDetails.AdvanceFlag"
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
	
	Counterparty					= SmallBusinessServer.GetCompany(Object.Company);
	Counterparty					= Object.Counterparty;
	Contract						= Object.Contract;
	
	NationalCurrency			= Constants.NationalCurrency.Get();
	StructureByCurrency			= InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", NationalCurrency));
	RateNationalCurrency 		= StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		Object.Same = True;
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance") Then
		
		FilterArray = New Array;
		FilterArray.Add(Type("DocumentRef.InvoiceForPayment"));
		FilterArray.Add(Type("DocumentRef.CashReceipt"));
		FilterArray.Add(Type("DocumentRef.PaymentReceipt"));
		
		ValidTypesBasisDocument = New TypeDescription(FilterArray);
		
	Else
		
		If ForReturn Then
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.CustomerInvoice"));
		Else
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.CustomerInvoice"));
			FilterArray.Add(Type("DocumentRef.AcceptanceCertificate"));
			FilterArray.Add(Type("DocumentRef.CustomerOrder"));
			FilterArray.Add(Type("DocumentRef.AgentReport"));
			FilterArray.Add(Type("DocumentRef.ReportToPrincipal"));
			FilterArray.Add(Type("DocumentRef.ProcessingReport"));
		EndIf;
		
		ValidTypesBasisDocument = New TypeDescription(FilterArray);
		
		Items.InventoryProductsAndServices.AutoChoiceIncomplete = True;
		Items.InventoryProductsAndServices.AutoMarkIncomplete = True;
		
		If Object.Same Then
			Items.Consignor.Enabled = False;
		EndIf;
	
	EndIf;
	
	Items.BasisDocument.TypeRestriction = ValidTypesBasisDocument;
	
	If ValueIsFilled(Object.BasisDocument)
		AND TypeOf(Object.BasisDocument) = Type("DocumentRef.ReportToPrincipal") Then
		
		If Not (Parameters.Property("Basis")
			AND TypeOf(Parameters.Basis) = Type("Structure")
			AND Parameters.Basis.Property("FillCCDNumbers")
			AND Parameters.Basis.FillCCDNumbers) Then
		
			Items.InventoryContent.Visible 			= True;
			
			Items.InventoryProductsAndServices.Visible			= False;
			Items.InventoryCharacteristic.Visible			= False;
			Items.InventoryBatch.Visible 				= False;
			Items.InventoryMeasurementUnit.Visible 		= False;
			Items.InventoryCountryOfOrigin.Visible	= False;
			Items.InventoryCCDNo.Visible				= False;
			Items.OperationKind.Enabled 				= False;
			
		EndIf;
		
	Else
		
		Items.InventoryMeasurementUnit.Visible 		= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryQuantity.Visible 			= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryPrice.Visible 					= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryCountryOfOrigin.Visible	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.InventoryCCDNo.Visible 				= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		
		Items.GroupFillCCDNumbers.Enabled 	= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		Items.SetCCDNumber.Enabled			= (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")) AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance"));
		
	EndIf;
	
	CurrencyTransactionsAccounting = GetFunctionalOption("CurrencyTransactionsAccounting");
	
	// CCD numbers
	If Not ValueIsFilled(Object.Ref)
		AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance"))
		AND (NOT Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance")) Then
		
		FillCCDNumbersAtServer();
		
	EndIf;
	
	// For CIN based on the commission document:
	// If you can not see that there are no products and services, then you need to enable visible for a content
	If Not (Items.InventoryProductsAndServices.Visible 
		AND Items.InventoryContent.Visible) Then
		
		Items.InventoryContent.Visible = True;
		
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly 		= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 	= Not AllowedEditDocumentPrices;
	
	If ForReturn Then
		
		NewArray = New Array();
		NewArray.Add(Enums.OperationKindsCustomerInvoice.ReturnFromProcessing);
		NewArray.Add(Enums.OperationKindsCustomerInvoice.ReturnToPrincipal);
		NewArray.Add(Enums.OperationKindsCustomerInvoice.ReturnToVendor);
		NewArray.Add(Enums.OperationKindsCustomerInvoice.ReturnFromSafeCustody);
		AvailableOperationKindsArray = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.OperationKind", AvailableOperationKindsArray);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
		
	EndIf;
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// Setting contract visible.
	SetContractVisible();
	
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
			
			If Find(FormOwner.FormName, "DocumentForm") <> 0 
				AND (ValueIsFilled(Object.BasisDocuments.FindRows(New Structure("BasisDocument", FormOwner.Object.Ref)))
				OR (FormOwner.Object.Ref = Object.BasisDocument)) Then
			
				NotifyChoice(SmallBusinessClient.InvoicePresentation(Object.Date, Object.Number));
			
			Else
			
				NotifyChoice("Enter invoice note");
				
				Structure = New Structure;
				Structure.Insert("BasisDocument", Object.BasisDocument);
				Structure.Insert("Presentation", SmallBusinessClient.InvoicePresentation(Object.Date, Object.Number));
				Notify("RefreshOfTextAboutInvoice", Structure);
			
			EndIf; 
			
		EndIf;
		
	Else
		
		Structure = New Structure;
		Structure.Insert("BasisDocument", Object.BasisDocument);
		Structure.Insert("Presentation", SmallBusinessClient.InvoicePresentation(Object.Date, Object.Number));
		Notify("RefreshOfTextAboutInvoice", Structure);
		
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
	
	LineCount = Object.BasisDocuments.Count();
	Items.BasisDocumentsEditInList.Check = LineCount > 1;
	
	If Items.BasisDocumentsEditInList.Check Then
		Items.BasisPages.CurrentPage = Items.PageBasisDocuments;
	Else
		Items.BasisPages.CurrentPage = Items.PageBasisDocument;
	EndIf;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	SetLabelPaymentDocuments();
	
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
		
		SetContractVisible();
		
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

#EndRegion

#Region HeaderAttributes

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
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(Object.DocumentCurrency) Then
			RecalculateRateRepetitionOfDocumentCurrency(StructureData);
		EndIf;	
		
		SetLabelPricesAndCurrency();
		
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
	
	StructureData = GetCompanyDataOnChange();
	Counterparty = StructureData.Counterparty;
	
	SetLabelPricesAndCurrency();
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	ProcessContractChange();
	
EndProcedure // OperationKindOnChange()

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange(Object.Counterparty);
		Object.Contract 	= StructureData.Contract;
		
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

// Procedure - OnChange event handler of the SameAs input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure HeHimselfOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")
		AND Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance") Then
		
		Return;
		
	EndIf;
	
	If Object.Same Then
		
		Items.Consignor.Enabled	= False;
		Object.Consignor 				= Undefined;
		
	Else
		
		Items.Consignor.Enabled = True;
		
	EndIf;
	
EndProcedure

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

#EndRegion

#Region TabularSectionsAttributes

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow 
		AND (Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance")
			OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance")) Then
		
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
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	If Not TabularSectionRow.Quantity = 0 Then 
		StructureData.Insert("Quantity", TabularSectionRow.Quantity);
	EndIf;
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	TabularSectionRow.Content = "";
	
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
	ElsIf (Factor = 0) Then
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

// Function places tabular section BasisDocuments in temporary
// storage and returns the address
//
&AtServer
Function PutBasisDocumentsToStorage()
	
	Return PutToTempStorage(
		Object.BasisDocuments.Unload(,
			"BasisDocument"
		),
		UUID
	);
	
EndFunction // PutBasisDocumentsToStorage()

// Function receives the BasisDocuments tabular section from the temporary storage.
//
&AtServer
Procedure GetBasisDocumentsFromStorage(AddressBasisDocumentsInStorage)
	
	TableBasisDocuments = GetFromTempStorage(AddressBasisDocumentsInStorage);
	Object.BasisDocuments.Clear();
	For Each RowDocumentsBases IN TableBasisDocuments Do
		String = Object.BasisDocuments.Add();
		FillPropertyValues(String, RowDocumentsBases);
	EndDo;
	
EndProcedure // GetBasisDocumentsFromStorage()

// Procedure - GoToList reference clicking handler.
//
&AtClient
Procedure GoToListClick(Item)
	
	StandardProcessing = False;
	
	Modified = True;
	
	AddressBasisDocumentsInStorage = PutBasisDocumentsToStorage();
	
	SelectionParameters = New Structure(
		"AddressBasisDocumentsInStorage,
		|Contract,
		|Counterparty,
		|Currency,
		|ValidTypes",
		AddressBasisDocumentsInStorage,
		Object.Contract,
		Object.Counterparty,
		Object.DocumentCurrency,
		ValidTypesBasisDocument
	);
	
	Result = Undefined;

	
	OpenForm("Document.CustomerInvoiceNote.Form.BasisDocumentsForm", SelectionParameters,,,,, New NotifyDescription("GoToListClickEnd", ThisObject, New Structure("AddressBasisDocumentsInStorage", AddressBasisDocumentsInStorage)), FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure GoToListClickEnd(Result1, AdditionalParameters) Export
    
    AddressBasisDocumentsInStorage = AdditionalParameters.AddressBasisDocumentsInStorage;
    
    
    Result = Result1;
    If Result = DialogReturnCode.OK Then
        GetBasisDocumentsFromStorage(AddressBasisDocumentsInStorage);
    EndIf;

EndProcedure // GoToListClick()

// Procedure - OnChange event handler of the DocumentBase attribute.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	If Object.BasisDocuments.Count() = 0 Then
		Object.BasisDocuments.Add();
	EndIf;
	
	Object.BasisDocuments[0].BasisDocument = Object.BasisDocument;
	
EndProcedure // BasisDocumentOnChange()

//OnChange event handler procedure of the Correction attribute
//
&AtClient
Procedure CorrectionOnChange(Item)
	
	Items.GroupCorrectionVisibleManagement.CurrentPage = 
		?(Object.Correction, 
				Items.GroupCorrectionVisibleManagement.ChildItems.GroupCorrectionVisible, 
				Items.GroupCorrectionVisibleManagement.ChildItems.CorrectionInvisible);
				
	If Not Object.Correction Then
					
		Object.CorrectionNumber 		= 0;
		Object.InitialDocumentDate	= '00010101';
		Object.InitialDocumentNumber	= "";
		
	EndIf;
	
EndProcedure //CorrectionOnChange()

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

// Procedure - SelectionStart event handler of the CCDNumberInventory field of the Inventory tabular section.
//
&AtClient
Procedure InventoryCCDNomberStartChoice(Item, ChoiceData, StandardProcessing)
	
	MessageText = "";
	DataCurrentRows = Items.Inventory.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		If ValueIsFilled(DataCurrentRows.ProductsAndServices) 
			AND Not ProductsAndServicesTypeInventory(DataCurrentRows.ProductsAndServices) Then
			
			MessageText = NStr("en = 'CCD account is kept only for products and services with the ""Inventory"" type.'");
			
		EndIf;
		
		If Not ValueIsFilled(DataCurrentRows.CountryOfOrigin)
			OR (DataCurrentRows.CountryOfOrigin = PredefinedValue("Catalog.WorldCountries.Russia")) Then
			
			MessageText = MessageText + ?(IsBlankString(MessageText), "", Chars.LF) + 
				NStr("en = 'CCD accounting for the native products is not kept!'");
			
		EndIf;
		
	EndIf;
	
	If Not IsBlankString(MessageText) Then
		
		CommonUseClientServer.MessageToUser(MessageText);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryCCDNumberOnChange(Item)
	
	DataCurrentRows = Items.Inventory.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		If ValueIsFilled(DataCurrentRows.CCDNo) Then
			
			DateCCD = Date(0001, 01, 01);
			CheckCCD(DataCurrentRows.CCDNo, DateCCD);
			
			If DateCCD > Object.Date Then
				
				QuestionText = NStr("en ='CCD is selected with the date later than the document date.
					|Continue?'");
				
				WarningResult = New NotifyDescription("WarningsAboutCCDDateResultProcessing", ThisObject);
				ShowQueryBox(WarningResult, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommands

// Procedure - PaymentDocuments reference clicking handler.
//
&AtClient
Procedure PaymentDocumentsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	AddressPaymentDocumentsInStorage = PutPaymentDocumentsToStorage();
	
	SelectionParameters = New Structure(
		"AddressPaymentDocumentsInStorage",
		AddressPaymentDocumentsInStorage
	);
	
	ReturnCode = Undefined;

	
	OpenForm("Document.CustomerInvoiceNote.Form.PaymentDocumentsEditForm", SelectionParameters,,,,, New NotifyDescription("PaymentDocumentsClickEnd", ThisObject, New Structure("AddressPaymentDocumentsInStorage", AddressPaymentDocumentsInStorage)));
	
EndProcedure

&AtClient
Procedure PaymentDocumentsClickEnd(Result, AdditionalParameters) Export
    
    AddressPaymentDocumentsInStorage = AdditionalParameters.AddressPaymentDocumentsInStorage;
    
    
    ReturnCode = Result;
    If ReturnCode = DialogReturnCode.OK Then
        Modified = True;
        GetPaymentDocumentsFromStorage(AddressPaymentDocumentsInStorage);
    EndIf;
    
    SetLabelPaymentDocuments();

EndProcedure // PaymentDocumentsClick()

// Procedure - BaseDocumentEditAsList command handler.
//
&AtClient
Procedure BasisDocumentsEditInList(Command)
	
	SetEditInListOption();
	
EndProcedure // BasisDocumentsEditInList()

// Procedure - FillInCCDNumbers button clicking handler.
//
&AtClient
Procedure FillCCDNumbers(Command)
	
	If Object.Inventory.Count() < 1 Then
		
		MessageText = NStr("en = 'Unfilled tabular section with inventory. An execution is impossible.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	QuestionText= NStr("en = 'The columns ""CCD number"" and ""Origin country"" will be refilled in the tabular section. Continue?'");
	Notification	= New NotifyDescription("FillInCCDNumbersEnd", ThisObject);
	
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillInCCDNumbersEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		FillCCDNumbersAtServer();
		
	EndIf;
	
EndProcedure

// Procedure - FillIn button click handler.
//
&AtClient
Procedure Fill(Command)
	
	FillByDocumentBase();
	SetLabelPaymentDocuments();
	
EndProcedure  // FillExecute()

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName 	= "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			Counterparty);
	SelectionParameters.Insert("DocumentOrganization", 	Object.Company);
	SelectionParameters.Insert("Currency", 				Object.DocumentCurrency);
	SelectionParameters.Insert("VATTaxation",		PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT"));
	SelectionParameters.Insert("AmountIncludesVAT", 		False);
	SelectionParameters.Insert("ThisIsReceiptDocument",	False);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.InventoryPrice.ReadOnly);

	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoiceNote.Advance") Then
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
	SelectionParameters.Insert("DocumentDate",							Object.Date);
	SelectionParameters.Insert("OwnerFormUUID",	UUID);
	SelectionParameters.Insert("InventoryAddressInStorage",					PlaceInventoryToStorage());
	
	OpenForm("CommonForm.PickupCCDNumbers", SelectionParameters);
	
EndProcedure // PickupCCDNumbers()

// Clicking event handler procedure of the PricesAndCurrency attribute
&AtClient
Procedure PricesAndCurrencyClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure // PricesAndCurrencyClick()

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

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the question result document form filling by a basis document
//
//
Procedure DetermineNeedForDocumentFillByBasis(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		FillByDocument();
		ProcessOperationKindChange(False);
		
		SetLabelPricesAndCurrency();
		
	EndIf;
	
EndProcedure // DetermineNeedForDocumentFillByBasis()

&AtClient
// Procedure-handler of the question result of recalculation by a new currency rate or unit conversion factor
//
Procedure DetermineNewCurrencyRateAndUnitConversionFactorSettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		SetLabelPricesAndCurrency();
		
	EndIf;
	
EndProcedure // DetermineNeedForRecalculationByNewRate()

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

&AtClient
// Procedure-handler of the question result about the mismatch of CCD date to the document date
//
Procedure WarningsAboutCCDDateResultProcessing(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		
		DataCurrentRows = Items.Inventory.CurrentData;
		DataCurrentRows.CCDNo = Undefined;
		
	EndIf;
	
EndProcedure // ResultProcessingWarningsAboutDateOfCCD()

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