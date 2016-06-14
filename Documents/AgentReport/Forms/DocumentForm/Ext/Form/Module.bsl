
////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

&AtClient
Var LineCopyInventory;

&AtClient
Var UpdateSubordinatedInvoice;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
// The procedure handles the change of the Price kind and Settlement currency document attributes
//
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	SettlementsCurrencyBeforeChange = DocumentParameters.SettlementsCurrencyBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QueryPriceKind = DocumentParameters.QueryPriceKind;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	RecalculationRequired = DocumentParameters.RecalculationRequired;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate      = ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
	EndIf;
	
	If PriceKindChanged Then
		
		Object.PriceKind = ContractData.PriceKind;
		
	EndIf;
	
	LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, PriceKind, VATTaxation",
		ContractData.SettlementsCurrency,
		SettlementsCurrency,
		Object.ExchangeRate,
		RateNationalCurrency,
		Object.AmountIncludesVAT,
		CurrencyTransactionsAccounting,
		Object.PriceKind,
		Object.VATTaxation);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind AND RecalculationRequired Then
			
			WarningText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document! 
				|Recalculate the document according to the contract?'") + Chars.LF + Chars.LF;
				
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed! 
			|It is necessary to check the document currency!'");
			
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, QueryPriceKind, WarningText);
		
	ElsIf QueryPriceKind Then
		
		If RecalculationRequired Then
			
			QuestionText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document! 
				|Recalculate the document according to the contract?'");
				
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure // ProcessPricesKindAndSettlementsCurrencyChange()

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", SettlementsCurrency));
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Receives the data set from the server for the CompanyOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Object.Company));
	StructureData.Insert("VATRate", Object.Company.DefaultVATRate);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

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
	
	If StructureData.Property("PriceKind") Then
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
	StructureData.Insert("Price", Price);
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

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
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", ContractByDefault.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"PriceKind",
		ContractByDefault.PriceKind
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
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
		"PriceKind",
		Contract.PriceKind
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction // GetDataContractOnChange()

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

// Procedure fills the VAT rate in the tabular section according to the taxation system.
//
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATAmountTransfer.Visible = True;
		
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
											
			TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.TransmissionAmount * VATRate / 100);
								                    											
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATAmountTransfer.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then	
		    DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;	
		
		For Each TabularSectionRow IN Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.TransmissionVATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure // FillVATRateByVATTaxation()	

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

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
	
EndProcedure // CalculateAmountInTabularSectionLine()

// Calculates the brokerage in the row of the document tabular section
//
// Parameters:
//  TabularSectionRow - String of the document tabular section,
//
&AtClient
Procedure CalculateCommissionRemuneration(TabularSectionRow)
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
	
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromSaleAmount") Then
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * TabularSectionRow.Amount / 100;
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts") Then
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * (TabularSectionRow.Amount - TabularSectionRow.TransmissionAmount) / 100;
	Else
		TabularSectionRow.BrokerageAmount = 0;
	EndIf;
	
	VATRate = SmallBusinessReUse.GetVATRateValue(Object.VATCommissionFeePercent);
	
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.BrokerageAmount * VATRate / 100);
	
	
EndProcedure // CalculateBrokerage()

// Procedure recalculates the rate and multiplicity of
// settlement currency when document date change.
//
&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(NationalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(NationalCurrency);
		
		QuestionText = NStr("en = 'As of the date of document the settlement currency (" + CurrencyRateInLetters + ") exchange rate was specified.
							|Set the settlements rate (" + RateNewCurrenciesInLetters + ") according to exchange rate?'");
							
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate", NewExchangeRate);
		AdditionalParameters.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewCurrencyRateSettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure // RecalculateRateAccountCurrencyRepetition()

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PriceKind",				Object.PriceKind);
	ParametersStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",	Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",			Object.Counterparty);
	ParametersStructure.Insert("Contract",				Object.Contract);
	ParametersStructure.Insert("Company",			Counterparty);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",	RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",		RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",False);
	ParametersStructure.Insert("WarningText", WarningText);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()

// Column value Total PM is being calculated Customers on client.
//
&AtClient
Procedure CalculateColumnTotalAtClient(RowCustomers)
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ConnectionKey", RowCustomers.ConnectionKey);
	SearchResult = Object.Inventory.FindRows(FilterParameters);
	If SearchResult.Count() = 0 Then
		RowCustomers.Total = 0;
	Else
		TotalAmount = 0;
		For Each TSRow IN SearchResult Do
			TotalAmount = TotalAmount + TSRow.Total;
		EndDo;
		RowCustomers.Total = TotalAmount;
	EndIf;
	
EndProcedure // CalculateColumnTotalAtClient

// Update the column value Total PM Customers on client.
//
&AtClient
Procedure UpdateColumnTotalAtClient(UpdateAllRows = False)
	
	CurrentRowCustomers = Items.Customers.CurrentData;
	If CurrentRowCustomers = Undefined Then
		Return;
	EndIf;
	
	If UpdateAllRows Then
		
		For Each RowCustomers IN Object.Customers Do
			
			CalculateColumnTotalAtClient(RowCustomers);
			
		EndDo;
		
	Else
		
		CalculateColumnTotalAtClient(CurrentRowCustomers);
		
	EndIf;
	
EndProcedure // UpdateColumnTotalAtClient()

// Procedure of updating the invoices refs.
//
&AtServer
Procedure UpdateRefsOfInvoicesAtServer(ChangeSubordinateInc)
	
	Document = FormAttributeToValue("Object");
	Document.UpdateRefsOfInvoices();
	ValueToFormAttribute(Document, "Object");
	
	If ChangeSubordinateInc Then
		
		SmallBusinessServer.ChangeSubordinateInvoice(Object.Ref, True);
		
	EndIf;
	
EndProcedure // UpdateRefsOfInvoicesAtServer()

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = NStr("en = '%Currency%'");
			LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
		EndIf;
	EndIf;
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en = '%PriceKind%'");
		Else
			LabelText = LabelText + NStr("en = ' • %PriceKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en = '%VATTaxation%'");
		Else
			LabelText = LabelText + NStr("en = ' • %VATTaxation%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
	EndIf;
	
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then	
		If LabelStructure.AmountIncludesVAT Then	
			LabelText = NStr("en = 'Amount includes VAT'");
		Else
			LabelText = NStr("en = 'Amount does not include VAT'");
		EndIf;
	EndIf;
	
	Return LabelText;
	
EndFunction // GenerateLabelPricesAndCurrency()

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
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsAndServicesData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsAndServicesData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsAndServicesData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsAndServicesData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsAndServicesData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsAndServicesData.Insert("Factor", 1);
				EndIf;
			EndIf;
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
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	GetDataByBarCodes(StructureData);
	
	CurrentConnectionKey = Items.Inventory.RowFilter["ConnectionKey"];
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,Batch,MeasurementUnit,ConnectionKey",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit,CurrentConnectionKey));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsAndServicesData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsAndServicesData.VATRate;
				NewRow.ConnectionKey = CurrentConnectionKey;
				CalculateAmountInTabularSectionLine(NewRow);
				CalculateCommissionRemuneration(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				CalculateCommissionRemuneration(FoundString);
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

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	CounterpartyDoSettlementsByOrders = Object.Counterparty.DoOperationsByOrders;
	Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
	
EndProcedure // SetContractVisible()

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, Cancel)
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND Constants.DoNotPostDocumentsWithIncorrectContracts.Get() Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
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
Function GetContractByDefault(Document, Counterparty, Company)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		DocumentParameters = New Structure;
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
			
		Else
			
			DocumentParameters.Insert("CounterpartyBeforeChange", ContractData.CounterpartyBeforeChange);
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", ContractData.CounterpartyDoSettlementsByOrdersBeforeChange);
			
		EndIf;
		
		QueryBoxPrepayment = Object.Prepayment.Count() > 0 AND Object.Contract <> ContractBeforeChange;
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		QueryPriceKind = ValueIsFilled(Object.Contract) AND PriceKindChanged;
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("RecalculationRequired", RecalculationRequired);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("QueryBoxPrepayment", QueryBoxPrepayment);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
		
		If QueryBoxPrepayment = True Then
			
			QuestionText = NStr("en = 'Prepayment set-off will be cleared, do you want to continue?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeEnd1(Result, AdditionalParameters) Export
	
	
	//ProcessContractChangeFragment1(ContractBeforeChange);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName = "Customers";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	
	TabularSectionName	= "Inventory";
	
	SelectionParameters	= New Structure;
	
	SelectionParameters.Insert("Period",					Object.Date);
	SelectionParameters.Insert("Company",			Counterparty);
	SelectionParameters.Insert("PriceKind",					Object.PriceKind);
	SelectionParameters.Insert("Currency",					Object.DocumentCurrency);
	SelectionParameters.Insert("AmountIncludesVAT",		Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",	Object.Company);
	SelectionParameters.Insert("VATTaxation",		Object.VATTaxation);
	SelectionParameters.Insert("ThisIsReceiptDocument", 	True);
	
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
	
EndProcedure // Selection()

// Procedure - event handler Action of the command pick by balances.
//
&AtClient
Procedure SelectionByBalances(Command)
	
	TabularSectionName = "Customers";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory");
	
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en = 'Field ""Company"" is not filled'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText,,, "Company", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Counterparty) Then
		MessageText = NStr("en = 'Field ""Counterparty"" is not filled'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText,,, "Counterparty", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		MessageText = NStr("en = 'Field ""Contract"" is not filled'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText,,, "Contract", Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	TabularSectionName = "Inventory";
	
	SelectionParameters = New Structure("
		|Company,
		|Counterparty,
		|Contract,
		|DocumentCurrency,
		|DocumentDate",
		Counterparty,
		Object.Counterparty,
		Object.Contract,
		Object.DocumentCurrency,
		Object.Date
	);
	
	OpenForm("Document.AgentReport.Form.PickFormByBalances", SelectionParameters, ThisForm);
	
	FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
	Items[TabularSectionName].RowFilter = FilterStr;
	
EndProcedure // SelectionByBalances()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		NewRow.TransmissionPrice = NewRow.Price;
		NewRow.TransmissionAmount = NewRow.Amount;
		NewRow.TransmissionVATAmount = NewRow.VATAmount;
		
		NewRow.ConnectionKey = Items[TabularSectionName].RowFilter["ConnectionKey"];
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

// Function receives the inventory list transferred from the temporary storage
//
&AtServer
Procedure GetInventoryTransferredFromStorage(AddressInventoryTransferredInStorage)
	
	InventoryTransferred = GetFromTempStorage(AddressInventoryTransferredInStorage);
	
	For Each TabularSectionRow IN InventoryTransferred Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		
		StructureData = GetDataProductsAndServicesOnChange(StructureData);
		
		NewRow.MeasurementUnit = StructureData.MeasurementUnit;
		NewRow.VATRate = StructureData.VATRate;
		
		If TabularSectionRow.Quantity > TabularSectionRow.Balance
			OR TabularSectionRow.Quantity = 0
			OR TabularSectionRow.SettlementsAmount = 0 Then
			NewRow.TransmissionAmount = 0;
		ElsIf TabularSectionRow.Quantity = TabularSectionRow.Balance Then
			NewRow.TransmissionAmount = TabularSectionRow.SettlementsAmount;
		Else
			NewRow.TransmissionAmount = Round(TabularSectionRow.SettlementsAmount / TabularSectionRow.Balance * TabularSectionRow.Quantity,2,0);
		EndIf;
		
		NewRow.TransmissionPrice = NewRow.TransmissionAmount / NewRow.Quantity;
		
		VATRate = SmallBusinessReUse.GetVATRateValue(NewRow.VATRate);
		NewRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
										NewRow.TransmissionAmount - (NewRow.TransmissionAmount) / ((VATRate + 100) / 100),
										NewRow.TransmissionAmount * VATRate / 100);
		
		NewRow.ConnectionKey = Items[TabularSectionName].RowFilter["ConnectionKey"];
		
	EndDo;
	
EndProcedure // GetInventoryTransferredFromStorage()

// Function places the list of advances into temporary storage and returns the address
//
&AtServer
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction // PlacePrepaymentToStorage()

// Function gets the list of advances from the temporary storage
//
&AtServer
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure // GetPrepaymentFromStorage()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtClient
Procedure SetVisibleAndEnabled()
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
		Object.CommissionFeePercent = 0;
		Items.CommissionFeePercent.Enabled = False;
	Else
		Items.CommissionFeePercent.Enabled = True;
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

// Procedure sets the links of the selection parameters of the Invoice input field.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetFilterMakeOutInvoicesConsolidated()
	
	If Object.MakeOutInvoicesCollective Then
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.CustomersInvoiceNote.ChoiceParameterLinks = NewConnections;
	Else
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Items.Customers.CurrentData.Customer");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.CustomersInvoiceNote.ChoiceParameterLinks = NewConnections;
	EndIf;
	
EndProcedure // SetFilterMakeOutInvoicesConsolidated()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
			Object.ExchangeRate      = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.PriceKind = Object.Contract.PriceKind;
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
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	NationalCurrency = Constants.NationalCurrency.Get();
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", NationalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATAmountTransfer.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATAmountTransfer.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.VATCommissionFeePercent = SubsidiaryCompany.DefaultVATRate;
	
	// Customer invoice notes for sold products and services
	MakeOutInvoicesCollective = DocumentDate >= '20150101';
	Items.MakeOutInvoicesCollective.Enabled = DocumentDate >= '20150101';
	SetFilterMakeOutInvoicesConsolidated();
	
	SmallBusinessServer.SetTextAboutInvoice(ThisForm, True);
	
	// Setting contract visible.
	SetContractVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPriceOfTransfer.ReadOnly 	   = Not AllowedEditDocumentPrices;
	Items.InventorySumOfTransfers.ReadOnly    = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmountTransfer.ReadOnly = Not AllowedEditDocumentPrices;
	
		SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
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

&AtClient
//Procedure - event handler of the form BeforeWrite
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	UpdateSubordinatedInvoice = Modified;
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Document is not posted! '") + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
			
		EndIf;
		
		If SmallBusinessReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		EndIf;
		
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	
	// Do not ask the question, as it is the basic script for this document:
	// - update the content of all invoice notes (either issued in PM or received document);
	ChangeSubordinateInc = Not (InvoiceText = "Enter invoice note")
		AND ?(NOT UpdateSubordinatedInvoice = Undefined, UpdateSubordinatedInvoice, False);

	UpdateRefsOfInvoicesAtServer(ChangeSubordinateInc);
	
EndProcedure // AfterWrite()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibleAndEnabled();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	
    //( elmi # 08.5 
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "Prepayment");
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

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
	   If EventName = "ScanData" Then
			TabularSectionName = "Customers";
			If SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory") Then
				Return;
			EndIf;
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
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetContractVisible();
		
	ElsIf EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		InventoryAddressInStorage = Parameter;
		TabularSectionName	= "Inventory";
		
		GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
		
		FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
		Items[TabularSectionName].RowFilter = FilterStr;
		
		UpdateColumnTotalAtClient();
		
	EndIf;
	
EndProcedure // NotificationProcessing()

// Procedure - event handler ChoiceProcessing.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.SupplierInvoiceNote.Form.DocumentForm" Then
		
		InvoiceText = ValueSelected;
		
	ElsIf ChoiceSource.FormName = "Document.AgentReport.Form.PickFormByBalances" Then
		
		GetInventoryTransferredFromStorage(ValueSelected);
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure // EditPricesAndCurrency()

// Procedure is called when clicking the "AddCounterpartyToCustomers" button
//
&AtClient
Procedure AddCounterpartyToCustomers(Command)
	
	If ValueIsFilled(Object.Counterparty) Then
		
		NewRow = Object.Customers.Add();
		NewRow.Customer = Object.Counterparty;
		
		TabularSectionName = "Customers";
		NewRow.ConnectionKey = SmallBusinessClient.CreateNewLinkKey(ThisForm);
		SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "Inventory");
		
		Items.Customers.CurrentRow = NewRow.GetID();
		
	EndIf;
	
EndProcedure // AddCounterpartyToCustomers()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Specify the counterparty first.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Specify the counterparty contract first.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem IN Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = CurItem.CustomerOrder;
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	SelectionParameters = New Structure(
		"AddressPrepaymentInStorage,
		|Pick,
		|IsOrder,
		|OrderInHeader,
		|SubsidiaryCompany,
		|Order,
		|Date,
		|Ref,
		|Counterparty,
		|Contract,
		|ExchangeRate,
		|Multiplicity,
		|DocumentCurrency,
		|DocumentAmount",
		AddressPrepaymentInStorage, // AddressPrepaymentInStorage
		True, // Pick
		True, // IsOrder
		False, // OrderInHeader
		Counterparty, // Counterparty
		?(CounterpartyDoSettlementsByOrders, OrdersArray, Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Inventory.Total("Total") // DocumentAmount
	);
	
	ReturnCode = Undefined;

	
	OpenForm("CommonForm.CustomerAdvancesPickForm", SelectionParameters,,,,, New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage)));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    
    
    ReturnCode = Result;
    
    If ReturnCode = DialogReturnCode.OK Then
        GetPrepaymentFromStorage(AddressPrepaymentInStorage);
    EndIf;

EndProcedure // EditPrepaymentOffset()

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	TabularSectionName = "Customers";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
        
        TabularSectionName = "Inventory";
        FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
        Items[TabularSectionName].RowFilter = FilterStr;
        
        UpdateColumnTotalAtClient();
        
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
			
			// Amount of the transfer.
			TabularSectionRow.TransmissionAmount = TabularSectionRow.TransmissionPrice * TabularSectionRow.Quantity;
			
			VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			// VAT amount of the transfer.
			TabularSectionRow.TransmissionVATAmount = ?(
				Object.AmountIncludesVAT,
				TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
				TabularSectionRow.TransmissionAmount * VATRate / 100
			);
			
			// Amount of brokerage
			CalculateCommissionRemuneration(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	TabularSectionName = "Customers";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		
		BarcodesReceived(Result);
		
		TabularSectionName = "Inventory";
		FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
		Items[TabularSectionName].RowFilter = FilterStr;
		
		UpdateColumnTotalAtClient();
		
	EndIf;
	
EndProcedure

// End Peripherals

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
// IN procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;	
		
		LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		// Customer invoice notes for sold products and services
		InvoiceConsolidated = Object.MakeOutInvoicesCollective;
		If DocumentDate < '20150101' Then
			Object.MakeOutInvoicesCollective = False;
			Items.MakeOutInvoicesCollective.Enabled = False;
		Else
			Object.MakeOutInvoicesCollective = True;
			Items.MakeOutInvoicesCollective.Enabled = True;
		EndIf;
		If InvoiceConsolidated <> Object.MakeOutInvoicesCollective Then
			SetFilterMakeOutInvoicesConsolidated();
		EndIf;
		
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	Counterparty = StructureData.Counterparty;
	Object.VATCommissionFeePercent = StructureData.VATRate;
	
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the MakeOutInvoicesCollective input field.
//
&AtClient
Procedure MakeOutInvoicesCollectiveOnChange(Item)
	
	SetFilterMakeOutInvoicesConsolidated();
	
EndProcedure

// Procedure - event handler OnChange of the BrokerageCalculationMethod input field.
//
&AtClient
Procedure BrokerageCalculationMethodOnChange(Item)
	
	If Object.BrokerageCalculationMethod <> PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating")
		AND ValueIsFilled(Object.CommissionFeePercent) Then
		If Object.Inventory.Count() > 0 Then
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("BrokerageCalculationMethodOnChangeEnd", ThisObject), "Calculation method has been changed. Do you want to recalculate the brokerage?",
							QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
            Return;
		EndIf;
	EndIf;
	
	BrokerageCalculationMethodOnChangeFragment();
EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        For Each TabularSectionRow IN Object.Inventory Do
            CalculateCommissionRemuneration(TabularSectionRow);
        EndDo;
    EndIf;
    
    BrokerageCalculationMethodOnChangeFragment();

EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeFragment()
    
    SetVisibleAndEnabled();

EndProcedure // BrokerageCalculationMethodOnChange()

// Procedure - handler of the OnChange event of the BrokerageVATRate input field.
//
&AtClient
Procedure VATCommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("BrokerageVATRateOnChangeEnd", ThisObject), "Do you want to recalculate VAT amounts of remuneration?", QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure BrokerageVATRateOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    VATRate = SmallBusinessReUse.GetVATRateValue(Object.VATCommissionFeePercent);
    
    For Each TabularSectionRow IN Object.Inventory Do
        
        TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
        TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
        TabularSectionRow.BrokerageAmount * VATRate / 100);
        
    EndDo;

EndProcedure // BrokerageVATRateOnChange()

// Procedure - event handler OnChange of the BrokeragePercent.
//
&AtClient
Procedure CommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("BrokeragePercentOnChangeEnd", ThisObject), "Brokerage percent has been changed. Recalculate the brokerage", QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
		
EndProcedure

&AtClient
Procedure BrokeragePercentOnChangeEnd(Result, AdditionalParameters) Export
    
    // We must offer to recalculate brokerage.
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        For Each TabularSectionRow IN Object.Inventory Do
            CalculateCommissionRemuneration(TabularSectionRow);
        EndDo;
    EndIf;

EndProcedure // BrokeragePercentOnChange()

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		StructureData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		StructureData.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		
		ProcessContractChange(StructureData);
		
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
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR SECTION ATTRIBUTES CUSTOMERS

// Procedure - event handler OnActivateRow of the Customers tabular section.
//
&AtClient
Procedure CustomersOnActivateRow(Item)
	
	TabularSectionName = "Customers";
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "Inventory");
	
EndProcedure // CustomersOnActivateRow()

// Procedure - OnStartEdit event handler of the Customers tabular section.
//
&AtClient
Procedure CustomersOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Customers";
	TabularSectionRow = Item.CurrentData;
	
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "Inventory");
	EndIf;
	
	If Copy Then
		TabularSectionRow.Total = 0;
	EndIf;
	
EndProcedure // CustomersOnStartEdit()

// Procedure - event handler BeforeDelete of the Customers tabular section.
//
&AtClient
Procedure CustomersBeforeDeleteRow(Item, Cancel)
	
	TabularSectionName = "Customers";
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Inventory");
	
EndProcedure // CustomersBeforeDeleteRow()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Customers";
	
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
EndProcedure // InventoryOnStartEdit()

// Procedure - event handler BeforeAddStart of the Inventory tabular section.
//
&AtClient
Procedure InventoryBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Customers";
	
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
	If Not Cancel AND Copy Then
		
		UpdateColumnTotalAtClient();
		
		CurRowCustomers = Items.Customers.CurrentData;
		CurRowCustomers.Total = CurRowCustomers.Total + Item.CurrentData.Total;
		
		LineCopyInventory = True;
		
	EndIf;
	
EndProcedure // InventoryBeforeAddStart()

// Procedure - event handler OnChange of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnChange(Item)
	
	If LineCopyInventory = Undefined OR Not LineCopyInventory Then
		UpdateColumnTotalAtClient();
	Else
		LineCopyInventory = False;
	EndIf;
	
EndProcedure // InventoryOnChange()

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		StructureData.Insert("Factor",		 1);
	EndIf;
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity		  = 1;
	TabularSectionRow.Price			  = StructureData.Price;
	TabularSectionRow.VATRate		  = StructureData.VATRate;
	TabularSectionRow.TransmissionPrice	  = 0;
	TabularSectionRow.TransmissionAmount	  = 0;
	TabularSectionRow.TransmissionVATAmount = 0;
	
	CalculateAmountInTabularSectionLine();
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
		
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 		 TabularSectionRow.VATRate);
		StructureData.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
		StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		StructureData.Insert("Price",			 TabularSectionRow.Price);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.Price = StructureData.Price;
		
		CalculateAmountInTabularSectionLine();
		CalculateCommissionRemuneration(TabularSectionRow);
		
	EndIf;
	
EndProcedure // InventoryCharacteristicOnChange()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
	// Amount of the transfer.
	TabularSectionRow.TransmissionAmount = TabularSectionRow.TransmissionPrice * TabularSectionRow.Quantity;
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
		TabularSectionRow.TransmissionAmount * VATRate / 100
	);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
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
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateCommissionRemuneration(TabularSectionRow);
	
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
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure // InventoryAmountOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);
	
EndProcedure  // InventoryVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // InventoryVATAmountOnChange()

// Procedure - event handler OnChange of the TransmissionPrice input field.
//
&AtClient
Procedure InventoryTransferPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount of the transfer.
	TabularSectionRow.TransmissionAmount = TabularSectionRow.Quantity * TabularSectionRow.TransmissionPrice;
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);	
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure // InventoryTransferPriceOnChange()

// Procedure - event handler OnChange of the TransmissionAmount input field.
//
&AtClient
Procedure InventoryAmountTransferOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.TransmissionPrice = TabularSectionRow.TransmissionAmount / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount of the transfer.
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);	
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure // InventoryAmountTransferOnChange

// Procedure - event handler OnChange of the BrokerageAmount input field.
//
&AtClient
Procedure InventoryBrokerageAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	VATRate = SmallBusinessReUse.GetVATRateValue(Object.VATCommissionFeePercent);
		
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.BrokerageAmount * VATRate / 100);	
	
EndProcedure // InventoryBrokerageAmountOnChange(Item)

&AtClient
Procedure PrepaymentAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
		
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
			?(Object.ExchangeRate = 0,
			1,
			Object.ExchangeRate),
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
			?(Object.Multiplicity = 0,
			1,
			Object.Multiplicity),
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);

EndProcedure

&AtClient
Procedure PrepaymentRateOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
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
		?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
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
		?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	

	//( elmi # 08.5
	//TabularSectionRow.Multiplicity = 1;
	//
	//TabularSectionRow.ExchangeRate =
	//	?(TabularSectionRow.SettlementsAmount = 0,
	//		1,
	//		TabularSectionRow.PaymentAmount
	//	  / TabularSectionRow.SettlementsAmount
	//	  * Object.ExchangeRate
	//);
   TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	If SmallBusinessServer.IndirectQuotationInUse() Then
		TabularSectionRow.Multiplicity =
			?(TabularSectionRow.PaymentAmount = 0,
				1,
				TabularSectionRow.SettlementsAmount
			  / TabularSectionRow.PaymentAmount
			  * Object.Multiplicity
		);
	Else
		TabularSectionRow.ExchangeRate =
			?(TabularSectionRow.SettlementsAmount = 0,
				1,
				TabularSectionRow.PaymentAmount
			  / TabularSectionRow.SettlementsAmount
			  * Object.ExchangeRate
		);
	EndIf;
	//) elmi

	
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

#Region InteractiveActionResultHandlers

// Procedure-handler of the result of opening the "Prices and currencies" form
//
&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory");
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			
		EndIf;
		
		// Amount of brokerage
		For Each TabularSectionRow IN Object.Inventory Do
			
			CalculateCommissionRemuneration(TabularSectionRow);
			
		EndDo;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(
					Object.DocumentCurrency = NationalCurrency,
					RateNationalCurrency,
					Object.ExchangeRate
				),
				TabularSectionRow.Multiplicity,
				?(
					Object.DocumentCurrency = NationalCurrency,
					RepetitionNationalCurrency,
					Object.Multiplicity)
				);
				
		EndDo;
		
		UpdateColumnTotalAtClient(True);
		
	EndIf;
	
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", 
		Object.PriceKind, 
		Object.DocumentCurrency, 
		SettlementsCurrency, 
		Object.ExchangeRate, 
		RateNationalCurrency, 
		Object.AmountIncludesVAT, 
		CurrencyTransactionsAccounting, 
		Object.VATTaxation);
		
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure // OpenPricesAndCurrencyFormEnd()

// Procedure-handler of the response to question about the necessity to set a new currency rate
//
&AtClient
Procedure DefineNewCurrencyRateSettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, RepetitionNationalCurrency, Object.Multiplicity)
				);
				
		EndDo;
		
		LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation", 
			Object.PriceKind, 
			Object.DocumentCurrency, 
			SettlementsCurrency, 
			Object.ExchangeRate, 
			RateNationalCurrency, 
			Object.AmountIncludesVAT, 
			CurrencyTransactionsAccounting, 
			Object.VATTaxation
			);
			
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure // DefineNewCurrencyRateSettingNeed()

// Procedure-handler of the answer to the question about repeated advances offset
//
&AtClient
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		
		If AdditionalParameters.Property("CounterpartyBeforeChange") Then
			
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
			
		EndIf;
		
	EndIf;
	
EndProcedure // DefineAdvancePaymentRefreshNeed()

// Procedure-handler response on question about document recalculate by contract data
//
&AtClient
Procedure DefineDocumentRecalculateNeedByContractTerms(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory");
		
	EndIf;
	
EndProcedure // DefineDocumentRecalculateNeedByContractTerms()

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
