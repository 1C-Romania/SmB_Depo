////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	Object.ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Object.Multiplicity = ?(
	    //( elmi # 08.5
	    //StructureByCurrency.ExchangeRate = 0,
	    StructureByCurrency.Multiplicity = 0,
		//) elmi
		1,
		StructureByCurrency.Multiplicity
	);
	
EndProcedure // FillByDocument()

// The function moves the AdvancesPaid tabular section
// to the temporary storage and returns the address
//
&AtServer
Function PlaceAdvancesPaidToStorage()
	
	Return PutToTempStorage(
		Object.AdvancesPaid.Unload(,
			"Document, Amount"
		),
		UUID
	);
	
EndFunction // PlaceAdvancesPaidToStorage()

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
			StructureProductsAndServicesData.Insert("ProductsAndServices", BarcodeData.ProductsAndServices);
			StructureProductsAndServicesData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsAndServicesData.Insert("VATTaxation", StructureData.VATTaxation);
			BarcodeData.Insert("StructureProductsAndServicesData", GetDataProductsAndServicesOnChange(StructureProductsAndServicesData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

// Procedure processes the received barcodes.
//
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
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
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
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
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
		
		MessageString = NStr("en='Data by barcode is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure 

// End Peripherals

// The function receives the AdvancesPaid tabular section from the temporary storage.
//
&AtServer
Procedure GetAdvancesPaidFromStorage(AddressAdvancesPaidInStorage)
	
	TableAdvancesPaid = GetFromTempStorage(AddressAdvancesPaidInStorage);
	Object.AdvancesPaid.Clear();
	For Each StringAdvancesPaid IN TableAdvancesPaid Do
		String = Object.AdvancesPaid.Add();
		FillPropertyValues(String, StringAdvancesPaid);
	EndDo;
	
EndProcedure // GetAdvancesPaidFromStorage()

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
	
	// Generate price and currency label.
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
	
	Var LabelStructure;
	
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation);
	DocumentCurrency = GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure // RecalculateRateRatioOfDocumentCurrency()

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonEditCurrency()
	
	ParametersStructure = New Structure();
	
	ParametersStructure.Insert("DocumentDate",			Object.Date);
	ParametersStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",		Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",		Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",	Object.IncludeVATInPrice);
	ParametersStructure.Insert("RecalculatePricesByCurrency",	False);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",				Object.Multiplicity);
	
	ReturnStructure = Undefined;

	
	OpenForm("CommonForm.CurrencyForm", ParametersStructure,,,,, New NotifyDescription("ProcessChangesOnEditCurrencyButtonEnd", ThisObject, New Structure("ParametersStructure", ParametersStructure)));
	
EndProcedure

&AtClient
Procedure ProcessChangesOnEditCurrencyButtonEnd(Result, AdditionalParameters) Export
	
	ParametersStructure = AdditionalParameters.ParametersStructure;
	
	ReturnStructure = Result;
	
	If Not ValueIsFilled(ReturnStructure)
		OR Not ReturnStructure.WereMadeChanges
		OR ReturnStructure.DialogReturnCode = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	FillPropertyValues(Object, ReturnStructure);
	
	// Clearing the tabular section of the issued advances.
	If ParametersStructure.DocumentCurrency <> ReturnStructure.DocumentCurrency Then
		Object.AdvancesPaid.Clear();
	EndIf;
	
	// Recalculate prices by currency.
	If ReturnStructure.RecalculatePricesByCurrency Then
		SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, ParametersStructure.DocumentCurrency, "Inventory");
		SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, ParametersStructure.DocumentCurrency, "Expenses");
	EndIf;
	
	// Recalculate the amount if VAT taxation flag is changed.
	If Not ReturnStructure.VATTaxation = ReturnStructure.PrevVATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
	// Recalculate the amount if the "Amount includes VAT" flag is changed.
	If Not Object.AmountIncludesVAT = ParametersStructure.AmountIncludesVAT Then
		SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Expenses");
	EndIf;
	
	For Each RowPayment IN Object.Payments Do
		CalculatePaymentSUM(RowPayment);
	EndDo;
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	// Generate price and currency label.
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation);
	DocumentCurrency = GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure // ProcessChangesUsingEditCurrency()

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100);
		
EndProcedure // CalculateVATAmount()

// Recalculate a payment amount in the passed tabular section string.
//
&AtClient
Procedure CalculatePaymentSUM(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		Object.ExchangeRate,
		TabularSectionRow.Multiplicity,
		Object.Multiplicity
	);
	
EndProcedure // CalculatePaymentAmount()

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // CalculateAmountInTabularSectionLine()

// It receives data set from server for the ContractOnChange procedure.
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

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		SmallBusinessServer.GetCompany(Company)
	);
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Procedure fills the VAT rate in the tabular section according to the taxation system.
//
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		
		For Each TabularSectionRow IN Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.ProductsAndServices.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.ProductsAndServices.VATRate;
			Else
				TabularSectionRow.VATRate = Object.Company.DefaultVATRate;
			EndIf;	
			
			VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
		
		For Each TabularSectionRow IN Object.Expenses Do
			
			If ValueIsFilled(TabularSectionRow.ProductsAndServices.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.ProductsAndServices.VATRate;
			Else
				TabularSectionRow.VATRate = Object.Company.DefaultVATRate;
			EndIf;	
			
			VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then	
			DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;	
		
		For Each TabularSectionRow IN Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
		
		For Each TabularSectionRow IN Object.Expenses Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;	
	
EndProcedure // FillVATRateByVATTaxation()	

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateWithoutVAT());
		Else
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateZero());
		EndIf;	
																
	ElsIf ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		StructureData.Insert("VATRate", StructureData.ProductsAndServices.VATRate);
	Else
		StructureData.Insert("VATRate", StructureData.Company.DefaultVATRate);
	EndIf;
	
	StructureData.Insert("ClearOrderAndDivision", False);
	StructureData.Insert("ClearBusinessActivity", False);
	
	If StructureData.ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND StructureData.ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Incomings
	   AND StructureData.ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.UnfinishedProduction
	   AND StructureData.ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		StructureData.ClearOrderAndDivision = True;
	EndIf;
	
	If StructureData.ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND StructureData.ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfGoodsSold
	   AND StructureData.ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Incomings Then
		StructureData.ClearBusinessActivity = True;
	EndIf;
	
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

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetPaymentDataContractOnChange(Date, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction // GetPaymentDataContractOnChange()

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, Counterparty, Company)
	
	StructureData = New Structure;
	
	Contract = Counterparty.ContractByDefault;
	StructureData.Insert("Contract", Contract);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByDocuments", Counterparty.DoOperationsByDocuments);
	StructureData.Insert("DoOperationsByOrders", Counterparty.DoOperationsByOrders);
	StructureData.Insert("TrackPaymentsByBills", Counterparty.TrackPaymentsByBills);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	
	SetAccountsAttributesVisible(
		Counterparty.DoOperationsByContracts,
		Counterparty.DoOperationsByDocuments,
		Counterparty.DoOperationsByOrders,
		Counterparty.TrackPaymentsByBills
	);
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataBusinessActivityStartChoice(ProductsAndServices)
	
	StructureData = New Structure;
	
	AvailabilityOfPointingBusinessActivities = True;
	
	If ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfGoodsSold
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Incomings Then
		AvailabilityOfPointingBusinessActivities = False;
	EndIf;
	
	StructureData.Insert("AvailabilityOfPointingBusinessActivities", AvailabilityOfPointingBusinessActivities);
	
	Return StructureData;
	
EndFunction // GetDataBusinessActivityStartChoice()

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataStructuralUnitStartChoice(ProductsAndServices)
	
	StructureData = New Structure;
	
	AbilityToSpecifyDivisions = True;
	
	If ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Incomings
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.UnfinishedProduction
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		AbilityToSpecifyDivisions = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyDivisions", AbilityToSpecifyDivisions);
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitStartChoice()

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataOrderStartChoice(ProductsAndServices)
	
	StructureData = New Structure;
	
	AbilityToSpecifyOrder = True;
	
	If ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Incomings
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.UnfinishedProduction
	   AND ProductsAndServices.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		AbilityToSpecifyOrder = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyOrder", AbilityToSpecifyOrder);
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitStartChoice()

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			//===============================
			//©# (Begin)	AlekS [2016-09-13]
			//LabelText = NStr("en='%Currency%';ru='%Вал%'");
			//LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
			LabelText = TrimAll(String(LabelStructure.DocumentCurrency));
			//©# (End)		AlekS [2016-09-13]
			//===============================
		EndIf;
	EndIf;
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		//If IsBlankString(LabelText) Then
		//	LabelText = LabelText + NStr("en='%VATTaxation%';ru='%VATTaxation%'");
		//Else
		//	LabelText = LabelText + NStr("en=' • %VATTaxation%';ru=' • %НалогообложениеНДС%'");
		//EndIf;
		//LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
		LabelText = LabelText + " • " + TrimAll(String(LabelStructure.VATTaxation));
		//©# (End)		AlekS [2016-09-13]
		//===============================
	EndIf;
	
	
//===============================
//©# (Begin)	AlekS [2016-09-13]
//
//  THIS FLAG HAS NO CHANCE TO BE SHOWED - need attention !   8-(
//
//©# (End)		AlekS [2016-09-13]
//===============================
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then
		If LabelStructure.AmountIncludesVAT Then
			LabelText = NStr("en='Amount includes VAT';ru='Сумма включает НДС'");
		Else
			LabelText = NStr("en='Amount does not include VAT';ru='Сумма не включает НДС'");
		EndIf;
	EndIf;
	
	Return LabelText;
	
EndFunction // GenerateLabelPricesAndCurrency()

// Procedure fills out the service attributes.
//
&AtServerNoContext
Procedure FillServiceAttributesByCounterpartyInCollection(DataCollection)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.LineNumber AS NUMBER) AS LineNumber,
	|	Table.Counterparty AS Counterparty
	|INTO TableOfCounterparty
	|FROM
	|	&DataCollection AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableOfCounterparty.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	TableOfCounterparty.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	TableOfCounterparty.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	TableOfCounterparty.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills
	|FROM
	|	TableOfCounterparty AS TableOfCounterparty";
	
	Query.SetParameter("DataCollection", DataCollection.Unload( ,"LineNumber, Counterparty"));
	
	Selection = Query.Execute().Select();
	For Ct = 0 To DataCollection.Count() - 1 Do
		Selection.Next(); // Number of rows in the query selection always equals to the number of rows in the collection
		FillPropertyValues(DataCollection[Ct], Selection, "DoOperationsByContracts, DoOperationsByDocuments, DoOperationsByOrders, TrackPaymentsByBills");
	EndDo;
	
EndProcedure // FillServiceAttributesByCounterpartyInCollection()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName = "Inventory";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",				   Object.Date); 
	SelectionParameters.Insert("Company",		   Counterparty);
	SelectionParameters.Insert("VATTaxation",	   Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT",	   Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",  Object.Company);
	
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
	
EndProcedure // InventoryPick()

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ExpensesPick(Command)
	
	TabularSectionName = "Expenses";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",				   Object.Date);
	SelectionParameters.Insert("Company",		   Counterparty);
	SelectionParameters.Insert("VATTaxation",	   Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT",	   Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",  Object.Company);
	SelectionParameters.Insert("CharacteristicsUsed", False);
	SelectionParameters.Insert("BatchesUsed", False);
	
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
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExpensesPick()

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure AdvancesPick(Command)
	
	AddressAdvancesPaidInStorage = PlaceAdvancesPaidToStorage();
	
	SelectionParameters = New Structure(
		"AddressAdvancesPaidInStorage,
		|SubsidiaryCompany,
		|Period,
		|Employee,
		|DocumentCurrency,
		|Refs",
		AddressAdvancesPaidInStorage,
		SubsidiaryCompany,
		Object.Date,
		Object.Employee,
		Object.DocumentCurrency,
		Object.Ref
	);
	
	Result = Undefined;

	
	OpenForm("CommonForm.AdvanceHolderAdvancesPickForm", SelectionParameters,,,,, New NotifyDescription("AdvancesFilterEnd", ThisObject, New Structure("AddressAdvancesPaidInStorage", AddressAdvancesPaidInStorage)));
	
EndProcedure

&AtClient
Procedure AdvancesFilterEnd(Result1, AdditionalParameters) Export
	
	AddressAdvancesPaidInStorage = AdditionalParameters.AddressAdvancesPaidInStorage;
	
	
	Result = Result1;
	If Result = DialogReturnCode.OK Then
		GetAdvancesPaidFromStorage(AddressAdvancesPaidInStorage);
		
	EndIf;

EndProcedure // AdvancesFilter()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Inventory" Then
			
			NewRow.StructuralUnit = MainWarehouse;
			
		EndIf;
		
		If TabularSectionName = "Expenses" Then
			
			NewRow.StructuralUnit = MainDivision;
			
		EndIf;
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

// Procedure - handler of clicking the button "Fill in by basis".
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en='Basis document is not selected!';ru='Не выбран документ основание!'"));
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en='Document will be completely refilled by ""Basis""! Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
		
		Counterparty = SmallBusinessServer.GetCompany(Object.Company);
		SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
		
		LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation);
		DocumentCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;

EndProcedure // FillByBasis()

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en='Enter barcode';ru='Введите штрихкод'"));

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
		
		ShowMessageBox(Undefined, NStr("en='It is required to select a line to get weight for it.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
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
			MessageText = NStr("en='Electronic scales returned zero weight.';ru='Электронные весы вернули нулевой вес.'");
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

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	If Parameters.Key.IsEmpty() Then
		
		If Not ValueIsFilled(Object.DocumentCurrency) Then
			Object.DocumentCurrency = NationalCurrency;
		EndIf;
		
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation);
	DocumentCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	User = Users.CurrentUser();
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainWarehouse);
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDivision");
	MainDivision = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDivision);
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	Items.InventoryInventoryPick.Visible = AccessRight("Read", Metadata.AccumulationRegisters.Inventory);
	Items.ExpensesExpensesSelection.Visible = AccessRight("Read", Metadata.AccumulationRegisters.Inventory);
	
	SmallBusinessServer.SetTextAboutInvoice(ThisForm, True);
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible();
	
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
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

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	//( elmi # 08.5
    SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "Prepayment"); //?? - PaymentsRatio, PaymentRate
    //) elmi
	
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notification of payment.
	NotifyAboutBillPayment = False;
	NotifyAboutOrderPayment = False;
	
	For Each CurRow IN Object.Payments Do
		NotifyAboutBillPayment = ?(
			NotifyAboutBillPayment,
			NotifyAboutBillPayment,
			ValueIsFilled(CurRow.InvoiceForPayment)
		);
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	If NotifyAboutBillPayment Then
		Notify("NotificationAboutBillPayment");
	EndIf;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
EndProcedure // AfterWrite()

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
	
	If EventName = "RefreshOfTextAboutInvoiceReceived" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Parameter.BasisDocument = Object.Ref Then
				
		InvoiceText = Parameter.Presentation;
		
	ElsIf EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter) Then
			
		For Each CurRow IN Object.Payments Do
			
			If Parameter = CurRow.Counterparty Then
				
				SetAccountsAttributesVisible();
				Break;
				
			EndIf;
			
		EndDo;
			
	ElsIf EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
			
		InventoryAddressInStorage	= Parameter;
		CurrentPagesInventory	= (Items.Pages.CurrentPage = Items.Products);
		TabularSectionName		= ?(CurrentPagesInventory, "Inventory", "Expenses");
		
		GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, CurrentPagesInventory, CurrentPagesInventory);
		
	EndIf;
	
EndProcedure // NotificationProcessing()

// Procedure - selection handler.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.SupplierInvoiceNote.Form.DocumentForm" Then
		InvoiceText = ValueSelected;
	EndIf;
	
EndProcedure 

// Procedure - EditDocumentCurrency command handler.
//
&AtClient
Procedure EditDocumentCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonEditCurrency();
	Modified = True;
	
EndProcedure // EditDocumentCurrency()

// Procedure - clicking handler on the hyperlink InvoiceText.
//
&AtClient
Procedure InvoiceNoteTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SmallBusinessClient.OpenInvoice(ThisForm, True);
	
EndProcedure

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
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE PARTS ATTRIBUTE EVENT HANDLERS

// Procedure - SelectionStart event handler of the Document input field.
//
&AtClient
Procedure AdvancesPaidDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Employee) Then
		MessageText = NStr("en='Specify employee first!';ru='Укажите вначале сотрудника!'");
		ShowMessageBox(Undefined,MessageText);
		StandardProcessing = False;
	EndIf;
	
EndProcedure // AdvancesPaidDocumentSelectionStart()

// Procedure - OnStartEdit event handler of the Inventory list string.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then 
		TabularSectionRow = Items.Inventory.CurrentData;
		TabularSectionRow.StructuralUnit = MainWarehouse;
	EndIf;
	
EndProcedure // InventoryOnStartEdit()

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
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
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
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
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure // InventoryPriceOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // InventoryAmountOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure  // InventoryVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // InventoryVATAmountOnChange()

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // InventoryAfterDeletion()

// Procedure - event handler OnStartEdit of the Expenses list row.
//
&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		TabularSectionRow = Items.Expenses.CurrentData;
		TabularSectionRow.StructuralUnit = MainDivision;
	EndIf;	
	
EndProcedure // ExpensesOnStartEdit()

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure ExpensesProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	
	If StructureData.ClearOrderAndDivision Then
		TabularSectionRow.StructuralUnit = Undefined;
		TabularSectionRow.CustomerOrder = Undefined;
	EndIf;
	
	If StructureData.ClearBusinessActivity Then
		TabularSectionRow.BusinessActivity = Undefined;
	EndIf;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure // ExpensesProductsAndServicesOnChange()

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure CostsContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Expenses.CurrentData;
		ContentPattern = SmallBusinessServer.GetContentText(TabularSectionRow.ProductsAndServices);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure ExpensesQuantityOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure // ExpensesQuantityOnChange()

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure ExpensesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
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
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure // ExpensesUOMSelectionDataProcessor()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ExpensesPriceOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure // ExpensesPriceOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure AmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // AmountExpensesOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ExpensesVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure  // ExpensesVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure AmountExpensesVATOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // ExpensesVATAmountOnChange()

// Procedure - SelectionStart event handler of the ExpensesBusinessActivity input field.
//
&AtClient
Procedure ExpensesBusinessActivityStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessActivityStartChoice(TabularSectionRow.ProductsAndServices);
	
	If Not StructureData.AvailabilityOfPointingBusinessActivities Then
		ShowMessageBox(, NStr("en='The business activity is not specified for this type of expense!';ru='Для данного расхода направление деятельности не указывается!'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure // ExpensesBusinessActivityStartChoice()

&AtClient
// Procedure - event handler SelectionStart of the StructuralUnit input field.
//
Procedure ExpensesStructuralUnitStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataStructuralUnitStartChoice(TabularSectionRow.ProductsAndServices);
	
	If Not StructureData.AbilityToSpecifyDivisions Then
		ShowMessageBox(, NStr("en='The division is not specified for this type of expense!';ru='Для этого расхода подразделение не указывается!'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure // ExpensesStructuralUnitStartChoice()

&AtClient
// Procedure - event handler SelectionStart of input field Order.
//
Procedure ExpensesOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataOrderStartChoice(TabularSectionRow.ProductsAndServices);
	
	If Not StructureData.AbilityToSpecifyOrder Then
		ShowMessageBox(, NStr("en='The order is not specified for this type of expense!';ru='Для этого расхода заказ не указывается!'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure // ExpensesOrderStartChoice()

// Procedure - event handler AfterDeletion of the Expenses list row.
//
&AtClient
Procedure ExpensesAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // ExpensesAfterDeletion()

// Procedure - OnChange event handler of the CounterpartyPayment input field.
// Sets exchange rate and unit conversion factor of the contract currency.
//
&AtClient
Procedure PaymentsCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(Object.Date, TabularSectionRow.Counterparty, Object.Company);
	
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	TabularSectionRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
	
	TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.ExchangeRate = 0,
			1,
			TabularSectionRow.ExchangeRate
		);
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.Multiplicity = 0,
			1,
			TabularSectionRow.Multiplicity
	);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		TabularSectionRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TabularSectionRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
	EndIf;
	
	TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		Object.ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Object.Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure // PaymentCounterpartyOnChange()

// Procedure - OnChange event handler of the PaymentContract input field.
// Sets exchange rate and unit conversion factor of the contract currency.
//
&AtClient
Procedure PaymentsContractOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetPaymentDataContractOnChange(
			Object.Date,
			TabularSectionRow.Contract
		);
		TabularSectionRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TabularSectionRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
	EndIf;
	
	TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		Object.ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Object.Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure // PaymentsContractOnChange()

// Procedure - OnChange event handler of the PaymentsSettlementKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		TabularSectionRow.Document = Undefined;
	EndIf;
	
EndProcedure // PaymentsAdvanceFlagOnChange()

// Procedure - SelectionStart event handler of the PaymentDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		ShowMessageBox(, NStr("en='The current document with the ""Advance"" flag will be used for settlement!';ru='Для вида расчета с признаком ""Аванс"" документом расчетов будет текущий!'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure // PaymentsDocumentSelectionStart()

// Procedure - OnChange event handler of the PaymentsSettlementAmount field.
// Calculates the amount of the payment.
//
&AtClient
Procedure SettlementsAccountsAmountOnChange(Item)
	
	CalculatePaymentSUM(Items.Payments.CurrentData);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // PaymentsSettlementAmountsOnChange()

// Procedure - OnChange event handler of the PaymentRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsExchangeRateOnChange(Item)
	
	CalculatePaymentSUM(Items.Payments.CurrentData);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // PaymentsRateOnChange()

// Procedure - OnChange event handler of the PaymentsRatio input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsMultiplicityOnChange(Item)
	
	CalculatePaymentSUM(Items.Payments.CurrentData);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // PaymentsRatioOnChange()

// Procedure - OnChange event handler of the PaymentPaymentAmount input field.
// Calculates exchange rate and unit conversion factor of the settlements currency and VAT amount.
//
&AtClient
Procedure PaymentsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	//( elmi # 08.5
	//TabularSectionRow.ExchangeRate = ?(
	//	TabularSectionRow.SettlementsAmount = 0,
	//	1,
	//	TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * Object.ExchangeRate
	//);
	If SmallBusinessServer.IndirectQuotationInUse() Then 
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.PaymentAmount = 0,
			1,
			TabularSectionRow.SettlementsAmount / TabularSectionRow.PaymentAmount * Object.Multiplicity
		);
	Else
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * Object.ExchangeRate
		);
	EndIf;
	//( elmi # 08.5
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // PaymentsPaymentAmountOnChange()

// Procedure - event handler AfterDeletion of the Payments list row.
//
&AtClient
Procedure PaymentsAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	SetAccountsAttributesVisible();
	
EndProcedure // PaymentsAfterDeleteRow()

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // InventoryOnEditEnd()

// Procedure - event handler OnEditEnd of the Expenses list row.
//
&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // ExpensesOnEditEnd()

// Procedure - event handler OnEditEnd of the Payments list row.
//
&AtClient
Procedure PaymentsOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure // PaymentsOnEditEnd()

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
&AtServer
Procedure SetAccountsAttributesVisible(Val DoOperationsByContracts = False, Val DoOperationsByDocuments = False, Val DoOperationsByOrders = False, Val TrackPaymentsByBills = False)
	
	FillServiceAttributesByCounterpartyInCollection(Object.Payments);
	
	For Each CurRow IN Object.Payments Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByDocuments Then
			DoOperationsByDocuments = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
		If CurRow.TrackPaymentsByBills Then
			TrackPaymentsByBills = True;
		EndIf;
	EndDo;
	
	Items.PaymentContract.Visible = DoOperationsByContracts;
	Items.PaymentDocument.Visible = DoOperationsByDocuments;
	Items.PaymentSchedule.Visible = DoOperationsByOrders;
	Items.PaymentInvoiceForPayment.Visible = TrackPaymentsByBills;
	
EndProcedure // SetAccountsAttributesVisible()

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible();

EndProcedure

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
