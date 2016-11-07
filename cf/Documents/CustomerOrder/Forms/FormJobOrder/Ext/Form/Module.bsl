#Region ModuleVariables

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

&AtClient
Var RowCopyWorks;

&AtClient
Var CopyingProductsRow;

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Document.Date AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order = &Order
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Document.Date,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsReceivable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsReceivable.Order = &Order
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsReceivableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsReceivableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsReceivableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsReceivableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsReceivableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (AccountsReceivableBalances.SettlementsCurrencyCurrencyRatesRate / AccountsReceivableBalances.SettlementsCurrencyCurrencyRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesRate AS DocumentCurrencyCurrencyRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesMultiplicity AS DocumentCurrencyCurrencyRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) * SettlementsCurrencyCurrencyRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyCurrencyRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyCurrencyRates.ExchangeRate AS SettlementsCurrencyCurrencyRatesRate,
	|		SettlementsCurrencyCurrencyRates.Multiplicity AS SettlementsCurrencyCurrencyRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyCurrencyRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyCurrencyRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &AccountingCurrency) AS SettlementsCurrencyCurrencyRates
	|			ON (TRUE)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency,
	|	AccountsReceivableBalances.SettlementsCurrencyCurrencyRatesRate,
	|	AccountsReceivableBalances.SettlementsCurrencyCurrencyRatesMultiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyCurrencyRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";

	
	Query.SetParameter("Order", ?(CounterpartyDoSettlementsByOrders, CurrentObject.Ref, Documents.CustomerOrder.EmptyRef()));
	
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("Counterparty", CurrentObject.Counterparty);
	Query.SetParameter("Contract", CurrentObject.Contract);
	Query.SetParameter("Period", CurrentObject.Date);
	Query.SetParameter("DocumentCurrency", Object.DocumentCurrency);
	Query.SetParameter("AccountingCurrency", SmallBusinessReUse.GetAccountCurrency());
	If SettlementsCurrency = Object.DocumentCurrency Then
		Query.SetParameter("DocumentCurrencyRate", Object.ExchangeRate);
		Query.SetParameter("MultiplicityOfDocumentCurrency", Object.Multiplicity);
	Else
		Query.SetParameter("DocumentCurrencyRate", 1);
		Query.SetParameter("MultiplicityOfDocumentCurrency", 1);
	EndIf;
	Query.SetParameter("Ref", CurrentObject.Ref);
	
	Query.Text = QueryText;
	
	CurrentObject.Prepayment.Clear();
	AmountLeftToDistribute = CurrentObject.Inventory.Total("Total") + CurrentObject.Works.Total("Total");
	
	SelectionOfQueryResult = Query.Execute().Select();
	AmountLeftToDistribute = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
		AmountLeftToDistribute,
		?(SettlementsCurrency = Object.DocumentCurrency, Object.ExchangeRate, 1),
		Object.ExchangeRate,
		?(SettlementsCurrency = Object.DocumentCurrency, Object.Multiplicity, 1),
		Object.Multiplicity
	);
	
	While AmountLeftToDistribute > 0 Do
		
		If SelectionOfQueryResult.Next() Then
			
			If SelectionOfQueryResult.SettlementsAmount <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow = CurrentObject.Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.SettlementsAmount;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow = CurrentObject.Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				NewRow.SettlementsAmount = AmountLeftToDistribute;
				NewRow.PaymentAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					NewRow.SettlementsAmount,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.DocumentCurrencyCurrencyRatesRate,
					SelectionOfQueryResult.Multiplicity,
					SelectionOfQueryResult.DocumentCurrencyCurrencyRatesMultiplicity
				);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

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
	DiscountKindChanged = DocumentParameters.DiscountKindChanged;
	If DocumentParameters.Property("ClearDiscountCard") Then
		ClearDiscountCard = True;
	Else
		ClearDiscountCard = False;
	EndIf;
	RecalculationRequiredInventory = DocumentParameters.RecalculationRequiredInventory;
	RecalculationRequiredWork = DocumentParameters.RecalculationRequiredWork;
	
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
	
	If DiscountKindChanged Then
		
		Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		
	EndIf;
	
	If ClearDiscountCard Then
		
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
		
	EndIf;
	
	If Object.DocumentCurrency <> ContractData.SettlementsCurrency Then
		
		Object.BankAccount = Undefined;
		
	EndIf;
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged OR DiscountKindChanged Then
			
			WarningText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Perhaps you have to refill prices.';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Возможно, необходимо перезаполнить цены.'") + Chars.LF + Chars.LF;
			
		EndIf;
		
		WarningText = WarningText + NStr("en='Settlement currency of the contract with counterparty changed! 
		|It is necessary to check the document currency!';ru='Изменилась валюта расчетов по договору с контрагентом! 
		|Необходимо проверить валюту документа!'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, (PriceKindChanged OR DiscountKindChanged), WarningText);
		
	ElsIf QueryPriceKind Then
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation, 
			Object.DiscountCard, 
			Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If (RecalculationRequiredInventory AND Object.Inventory.Count() > 0)
			OR (RecalculationRequiredWork AND Object.Works.Count() > 0) Then
			
			QuestionText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Recalculate the document according to the contract?';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Пересчитать документ в соответствии с договором?'");
			
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation, 
			Object.DiscountCard, 
			Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure // ProcessPricesKindAndSettlementsCurrencyChange()

// Procedure initializes the data update in rows table
// part Performers in case of key parameters change in work row of the same name PM document.
//
&AtClient
Procedure ReflectChangeKeyParameterInAccrualPerformers()
	
	CurrentRowOfWork = Items.Works.CurrentData; 
	If CurrentRowOfWork <> Undefined Then
		
		ReflectChangesByTablePerformers(CurrentRowOfWork.ConnectionKey);
		
	EndIf;
	
EndProcedure // ReflectChangeKeyParameterInAccrualPerformers()

// Procedure initializes data update in tabular section Performers
//
&AtClient
Procedure RefreshTabularSectionPerformers()
	
	CurrentRowPerformers = Items.Performers.CurrentData;
	
	If Not CurrentRowPerformers = Undefined 
		AND ValueIsFilled(CurrentRowPerformers.ConnectionKey) Then
		
		ReflectChangesByTablePerformers(CurrentRowPerformers.ConnectionKey);
		
	EndIf;
	
EndProcedure // UpdateTabularSectionPerformers()

// Procedure recalculates all charge amounts by specified work
//
&AtServer
Procedure RecalculateAmountAccrualsBySpecifiedWork(ConnectionKey)
	
	// There is not option to work out correctly without key...
	If Not ValueIsFilled(ConnectionKey) Then
		
		Return;
		
	EndIf;
	
	PerformersArray	= Documents.CustomerOrder.GetRowsPerformersByConnectionKey(Object.Performers, ConnectionKey);
	
	//If there are not performers, there is nothing to recalculate...
	If PerformersArray.Count() = 0 Then 
		
		Return;
		
	EndIf;
	
	CurrentWorks		= Documents.CustomerOrder.GetRowWorksByConnectionKey(Object.Works, ConnectionKey);
	AmountLPF			= Documents.CustomerOrder.ComputeLPFSumByConnectionKey(Object.Performers, ConnectionKey);
	WorkCoefficients	= CurrentWorks.Quantity * CurrentWorks.Factor * CurrentWorks.Multiplicity;
	WorkAmount			= CurrentWorks.Amount;
	
	For Each PerformerRow IN PerformersArray Do
		
		PerformerRow.AccruedAmount = 
			Documents.CustomerOrder.ComputeAccrualValueByRowAtServer(
				WorkCoefficients, 
				WorkAmount, 
				PerformerRow.LPF, 
				AmountLPF, 
				PerformerRow.AccrualDeductionKind, 
				PerformerRow.AmountAccrualDeduction);
		
	EndDo;
	
EndProcedure // RecalculateChargeAmountBySpecifiedWork()

// Procedure recalculates charge amount in tabular section Performers
//
//
&AtServer
Procedure ReflectChangesByTablePerformers(ConnectionKey = Undefined)
	
	If ConnectionKey <> Undefined Then
		
		RecalculateAmountAccrualsBySpecifiedWork(ConnectionKey);
		
	Else
		
		// It is used to update/fill by all works.
		ArrayOfWorks = Object.Works.FindRows(New Structure("ProductsAndServicesTypeService", False));
		For Each WorkRow IN ArrayOfWorks Do
			
			RecalculateAmountAccrualsBySpecifiedWork(WorkRow.ConnectionKey);
			
		EndDo;
		
	EndIf;
	
EndProcedure // ReflectChangesKTU()

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

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	StructureData.Insert("IsService", StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.Service"));
	StructureData.Insert("IsInventoryItem", StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = SmallBusinessServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	If StructureData.Property("VATTaxation")
		AND Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotTaxableByVAT") Then
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateWithoutVAT());
		Else
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateZero());
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		StructureData.Insert("VATRate", StructureData.ProductsAndServices.VATRate);
	Else
		StructureData.Insert("VATRate", StructureData.Company.DefaultVATRate);
	EndIf;
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
		EndIf;
		
		If StructureData.Property("WorkKind") Then
		
			If StructureData.ProductsAndServices.FixedCost Then
				
				Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
				StructureData.Insert("Price", Price);
			
			Else
				
				StructureData.ProductsAndServices = StructureData.WorkKind;
				StructureData.Characteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
				Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
				StructureData.Insert("Price", Price);
				
			EndIf;
		
		Else
			
			Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
		EndIf;
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind")
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
	
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = SmallBusinessServer.GetWorkTimeRate(StructureData);
	EndIf;
	
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

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
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
		"DiscountMarkupKind",
		ContractByDefault.DiscountMarkupKind
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
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind
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

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function MaterialsGetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	Return StructureData;
	
EndFunction // MaterialsGetDataProductsAndServicesOnChange()

&AtServerNoContext
// It receives data set from the server for the EmployeeOnChange procedure.
//
Function GetEmployeeDataOnChange(StructureData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccrualsAndDeductionsPlanSliceLast.Employee AS Employee,
	|	MIN(AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind) AS AccrualDeductionKind
	|INTO TemporaryTableEmployeesAndAccrualDeductionSorts
	|FROM
	|	InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	|			&ToDate,
	|			Company = &Company
	|				AND Actuality
	|				AND Employee = &Employee
	|				AND AccrualDeductionKind IN (VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment), VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent), VALUE(Catalog.AccrualAndDeductionKinds.FixedAmount))) AS AccrualsAndDeductionsPlanSliceLast
	|
	|GROUP BY
	|	AccrualsAndDeductionsPlanSliceLast.Employee
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.Employee AS Employee,
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.AccrualDeductionKind AS AccrualDeductionKind,
	|	AccrualsAndDeductionsPlanSliceLast.Amount * AccrualCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccrualCurrencyRate.Multiplicity) AS Amount
	|FROM
	|	TemporaryTableEmployeesAndAccrualDeductionSorts AS TemporaryTableEmployeesAndAccrualDeductionSorts
	|		LEFT JOIN InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality) AS AccrualsAndDeductionsPlanSliceLast
	|		ON TemporaryTableEmployeesAndAccrualDeductionSorts.Employee = AccrualsAndDeductionsPlanSliceLast.Employee
	|			AND TemporaryTableEmployeesAndAccrualDeductionSorts.AccrualDeductionKind = AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ToDate, ) AS AccrualCurrencyRate
	|		ON (AccrualsAndDeductionsPlanSliceLast.Currency = AccrualCurrencyRate.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ToDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate";
	
	Query.SetParameter("ToDate", StructureData.ToDate);
	Query.SetParameter("Company", StructureData.Company);
	Query.SetParameter("DocumentCurrency", StructureData.DocumentCurrency);
	Query.SetParameter("Employee", StructureData.Employee);
	
	ResultsArray = Query.ExecuteBatch();
	EmployeesTable = ResultsArray[1].Unload();
	
	If EmployeesTable.Count() = 0 Then
		StructureData.Insert("AccrualDeductionKind", Catalogs.AccrualAndDeductionKinds.EmptyRef());
		StructureData.Insert("Amount", 0);
	Else
		StructureData.Insert("AccrualDeductionKind", EmployeesTable[0].AccrualDeductionKind);
		StructureData.Insert("Amount", EmployeesTable[0].Amount);
	EndIf; 
	
	Return StructureData;
	
EndFunction // GetEmployeeDataOnChange()

&AtServerNoContext
// Gets payment term by the contract.
//
Function GetCustomerPaymentDueDate(Contract)
	
	Return Contract.CustomerPaymentDueDate;

EndFunction // GetCustomerPaymentDueDate()

&AtServer
// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.WOPaymentCalendarPaymentVATAmount.Visible = True;
		Items.WOListPaymentCalendarVATAmountPayments.Visible = True;
		
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
		
		Items.OWWorksVATRate.Visible = True;
		Items.OWWorksAmountVAT.Visible = True;
		Items.WOWorksTotal.Visible = True;
		
		For Each TabularSectionRow IN Object.Works Do
			
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
		Items.WOPaymentCalendarPaymentVATAmount.Visible = False;
		Items.WOListPaymentCalendarVATAmountPayments.Visible = False;
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotTaxableByVAT") Then
			DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;
		
		For Each TabularSectionRow IN Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
		Items.OWWorksVATRate.Visible = False;
		Items.OWWorksAmountVAT.Visible = False;
		Items.WOWorksTotal.Visible = False;
		
		For Each TabularSectionRow IN Object.Works Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

&AtServerNoContext
// It receives data set from the server for the StructuralUnitOnChange procedure.
//
Function GetDataStructuralUnitOnChange(StructureData)
	
	If StructureData.Division.TransferSource.StructuralUnitType = PredefinedValue("Enum.StructuralUnitsTypes.Warehouse")
		OR StructureData.Division.TransferSource.StructuralUnitType = PredefinedValue("Enum.StructuralUnitsTypes.Division") Then
	
		StructureData.Insert("InventoryStructuralUnit", StructureData.Division.TransferSource);
		StructureData.Insert("CellInventory", StructureData.Division.TransferSourceCell);

	Else
		
		StructureData.Insert("InventoryStructuralUnit", Undefined);
		StructureData.Insert("CellInventory", Undefined);
		
	EndIf;
		
	StructureData.Insert("OrderWarehouseOfInventory", Not StructureData.Division.TransferSource.OrderWarehouse);
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitOnChange()

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
											
EndProcedure // RecalculateDocumentAmounts() 

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined, ColumnTS = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	// Amount.
	If TabularSectionName = "Works" Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Multiplicity * TabularSectionRow.Factor * TabularSectionRow.Price;
	Else
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	// Discounts.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RefreshFormFooter();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // CalculateAmountInTabularSectionLine()	

// Procedure recalculates amounts in the payment calendar.
//
&AtClient
Procedure RecalculatePaymentCalendar()
	
	For Each CurRow IN Object.PaymentCalendar Do
		CurRow.PaymentAmount = Round((Object.Inventory.Total("Total") + Object.Works.Total("Total")) * CurRow.PaymentPercentage / 100, 2, 1);
		CurRow.PayVATAmount = Round((Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount")) * CurRow.PaymentPercentage / 100, 2, 1);
	EndDo;
	
EndProcedure // RecalculatePaymentCalendar()

&AtClient
// Procedure recalculates the exchange rate and multiplicity of
// the settlement currency when the date of a document is changed.
//
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

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate", Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity", Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation", Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	ParametersStructure.Insert("Contract", Object.Contract);
	ParametersStructure.Insert("Company",	Counterparty); 
	ParametersStructure.Insert("DocumentDate", Object.Date);
	ParametersStructure.Insert("RefillPrices", RefillPrices);
	ParametersStructure.Insert("RecalculatePrices", RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	ParametersStructure.Insert("WarningText", WarningText);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()	

&AtClient
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind() 
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",			Counterparty);
	DataStructure.Insert("PriceKind",				Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	DataStructure.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	DataStructure.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	DataStructure.Insert("DiscountMarkupPercent", 0);
	
	If WorkKindInHeader Then
		
		For Each TSRow IN Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.ProductsAndServices) Then
				Continue;
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			Object.WorkKind);
			TabularSectionRow.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
	
	Else
	
		For Each TSRow IN Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.WorkKind) Then
				Continue;
			EndIf;
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			TSRow.WorkKind);
			TabularSectionRow.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
	
	EndIf;
	
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	For Each TSRow IN DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		
		SearchResult = Object.Works.FindRows(SearchStructure);
		
		For Each ResultRow IN SearchResult Do
			ResultRow.Price = TSRow.Price;
			CalculateAmountInTabularSectionLine("Works", ResultRow, "Price");
		EndDo;
		
	EndDo;
	
	For Each TabularSectionRow IN Object.Works Do
		TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow, "Price");
	EndDo;
	
EndProcedure // RefillTabularSectionPricesByPriceKind()

&AtServerNoContext
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary
//  when recalculation DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection)
	
	// Discounts.
	If DataStructure.Property("DiscountMarkupKind") 
		AND ValueIsFilled(DataStructure.DiscountMarkupKind) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupKind.Percent;
		
	EndIf;
	
	// Discount card.
	If DataStructure.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(DataStructure.DiscountPercentByDiscountCard) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent + DataStructure.DiscountPercentByDiscountCard;
		
	EndIf;
		
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsAndServicesTable = New ValueTable;
	
	Array = New Array;
	
	// Work kind.
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("WorkKind", TypeDescription);
	
	// ProductsAndServices.
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("ProductsAndServices", TypeDescription);
	
	// FixedValue.
	Array.Add(Type("Boolean"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("FixedCost", TypeDescription);
	
	// Characteristic.
	Array.Add(Type("CatalogRef.ProductsAndServicesCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("Characteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("VATRate", TypeDescription);
	
	For Each TSRow IN DocumentTabularSection Do
		
		NewRow = ProductsAndServicesTable.Add();
		NewRow.WorkKind	 	 = TSRow.WorkKind;
		NewRow.FixedCost	 = TSRow.ProductsAndServices.FixedCost;
		NewRow.ProductsAndServices	 = TSRow.ProductsAndServices;
		NewRow.Characteristic	 = TSRow.Characteristic;
		If TypeOf(TSRow) = Type("Structure") AND TSRow.Property("VATRate") Then
			NewRow.VATRate	 = TSRow.VATRate;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ProductsAndServicesTable.WorkKind,
	|	ProductsAndServicesTable.FixedCost,
	|	ProductsAndServicesTable.ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic,
	|	ProductsAndServicesTable.VATRate
	|INTO TemporaryProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable";
	
	Query.SetParameter("ProductsAndServicesTable", ProductsAndServicesTable);
	Query.Execute();
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
		RoundingOrder = DataStructure.PriceKind.RoundingOrder;
		RoundUp = DataStructure.PriceKind.RoundUp;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.VATRate AS VATRate,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency AS ProductsAndServicesPricesCurrency,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundingOrder AS RoundingOrder,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundUp AS RoundUp,
	|	ISNULL(ProductsAndServicesPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	TemporaryProductsAndServicesTable AS ProductsAndServicesTable
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS ProductsAndServicesPricesSliceLast
	|		ON (CASE
	|				WHEN ProductsAndServicesTable.FixedCost
	|					THEN ProductsAndServicesTable.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|				ELSE ProductsAndServicesTable.WorkKind = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|			END)
	|			AND (CASE
	|				WHEN ProductsAndServicesTable.FixedCost
	|					THEN ProductsAndServicesTable.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
	|				ELSE TRUE
	|			END)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON (ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	ProductsAndServicesPricesSliceLast.Actuality";
		
	Query.SetParameter("ProcessingDate",	 DataStructure.Date);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	Query.SetParameter("DocumentCurrency", DataStructure.DocumentCurrency);
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow IN DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		If TypeOf(TSRow) = Type("Structure") AND TabularSectionRow.Property("VATRate") Then
			SearchStructure.Insert("VATRate", TabularSectionRow.VATRate);
		EndIf;
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
					
				Else
					
					RoundingOrder = SearchResult[0].RoundingOrder;
					RoundUp = SearchResult[0].RoundUp;
					
				EndIf;
				
				If DataStructure.Property("AmountIncludesVAT") 
					AND ((DataStructure.AmountIncludesVAT AND Not SearchResult[0].PriceIncludesVAT) 
					OR (NOT DataStructure.AmountIncludesVAT AND SearchResult[0].PriceIncludesVAT)) Then
					Price = SmallBusinessServer.RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
				EndIf;
				
				TabularSectionRow.Price = SmallBusinessServer.RoundPrice(Price, RoundingOrder, RoundUp);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close()
	
EndProcedure // GetTabularSectionPricesByPriceKind()

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
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		//===============================
		//©# (Begin)	AlekS [2016-09-13]
		//If IsBlankString(LabelText) Then
		//	LabelText = LabelText + NStr("en='%PriceKind%';ru='%PriceKind%'");
		//Else
		//	LabelText = LabelText + NStr("en=' • %PriceKind%';ru=' • %ВидЦен%'");
		//EndIf;
		//LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
		LabelText = LabelText + " • " + TrimAll(String(LabelStructure.PriceKind));
		//©# (End)		AlekS [2016-09-13]
		//===============================
	EndIf;
	
	// Margins discount kind.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		//===============================
		//©# (Begin)	AlekS [2016-09-13]
		//If IsBlankString(LabelText) Then
		//	LabelText = LabelText + NStr("en='%DiscountMarkupKind%';ru='%ВидСкидкиНаценки%'");
		//Else
		//	LabelText = LabelText + NStr("en=' • %MarkupDiscountKind%';ru=' • %ВидСкидкиНаценки%'");
		//EndIf;
		//LabelText = StrReplace(LabelText, "%DiscountMarkupKind%", TrimAll(String(LabelStructure.DiscountKind)));
		LabelText = LabelText + " • " + TrimAll(String(LabelStructure.DiscountKind));
		//©# (End)		AlekS [2016-09-13]
		//===============================
	EndIf;
	
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		//===============================
		//©# (Begin)	AlekS [2016-09-13]
		//If IsBlankString(LabelText) Then
		//	LabelText = LabelText + NStr("en='%DiscountCard%';ru='%ДисконтнаяКарта%'");
		//Else
		//	LabelText = LabelText + NStr("en=' • %DiscountCard%';ru=' • %ДисконтнаяКарта%'");
		//EndIf;
		//LabelText = StrReplace(LabelText, "%DiscountCard%", String(LabelStructure.DiscountPercentByDiscountCard)+"% by map"); //ShortLP(String(LabelStructure.DiscountCard)));
		LabelText = LabelText + " • " + String(LabelStructure.DiscountPercentByDiscountCard) + 
							NStr("en='% by card';ru='% по карте'"); 
		//©# (End)		AlekS [2016-09-13]
		//===============================
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

&AtClient
// Procedure updates data in form footer.
//
Procedure RefreshFormFooter()
	
	TotalAmount = Object.Works.Total("Total") + Object.Inventory.Total("Total");
	TotalVATAmount = Object.Works.Total("VATAmount") + Object.Inventory.Total("VATAmount");
	
EndProcedure // UpdateFormFooter()

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
		
		If BarcodeData <> Undefined AND BarcodeData.Count() <> 0 Then
			
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
				StructureProductsAndServicesData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			
			// DiscountCards
			StructureProductsAndServicesData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsAndServicesData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
			
			BarcodeData.Insert("StructureProductsAndServicesData", GetDataProductsAndServicesOnChange(StructureProductsAndServicesData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit = BarcodeData.ProductsAndServices.MeasurementUnit;
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
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	// DiscountCards
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// End DiscountCards
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined AND BarcodeData.Count() = 0 Then
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
				NewRow.Price = BarcodeData.StructureProductsAndServicesData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsAndServicesData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsAndServicesData.VATRate;
				NewRow.Specification = BarcodeData.StructureProductsAndServicesData.Specification;
				
				NewRow.ProductsAndServicesTypeInventory = BarcodeData.StructureProductsAndServicesData.IsInventoryItem;
				
				CalculateAmountInTabularSectionLine( , NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
				
			Else
				
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine( , FoundString);
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

&AtServer
// Procedure fills inventories by specification.
//
Procedure FillBySpecificationsAtServer(BySpecification, RequiredQuantity, UsedMeasurementUnit = Undefined)
	
	Query = New Query(
	"SELECT
	|	MAX(SpecificationsContent.LineNumber) AS SpecificationsContentLineNumber,
	|	SpecificationsContent.ProductsAndServices AS ProductsAndServices,
	|	SpecificationsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SpecificationsContent.MeasurementUnit AS MeasurementUnit,
	|	SpecificationsContent.Specification AS Specification,
	|	SUM(SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * &Factor * &Quantity) AS Quantity
	|FROM
	|	Catalog.Specifications.Content AS SpecificationsContent
	|WHERE
	|	SpecificationsContent.Ref = &Specification
	|	AND SpecificationsContent.ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType
	|
	|GROUP BY
	|	SpecificationsContent.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	SpecificationsContent.MeasurementUnit,
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.ContentRowType
	|
	|ORDER BY
	|	SpecificationsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("Quantity", RequiredQuantity);
	
	If Not TypeOf(UsedMeasurementUnit) = Type("CatalogRef.UOMClassifier")
		AND UsedMeasurementUnit <> Undefined Then
		Query.SetParameter("Factor", UsedMeasurementUnit.Factor);
	Else
		Query.SetParameter("Factor", 1);
	EndIf;
	
	Query.SetParameter("ProductsAndServicesType", PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = PredefinedValue("Enum.SpecificationContentRowTypes.Node") Then
			
			FillBySpecificationsAtServer(Selection.Specification, Selection.Quantity, Selection.MeasurementUnit);
			
		Else
			
			NewRow = Object.Materials.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.ConnectionKey = Items.OWMaterials.RowFilter["ConnectionKey"];
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillBySpecificationOnServer()

&AtServer
//Get materials by specifications
//
Procedure MoveMaterialsToTableFieldWithRecordKeys(TableOfSpecifications)
	
	Query	= New Query;
	
	Query.Text = 
	"SELECT
	|	TableOfSpecifications.Specification,
	|	TableOfSpecifications.Multiplicity AS Multiplicity,
	|	TableOfSpecifications.CoefficientFromBaseMeasurementUnit AS CoefficientFromBaseMeasurementUnit,
	|	TableOfSpecifications.ConnectionKey
	|INTO TmpSpecificationTab
	|FROM
	|	&TableOfSpecifications AS TableOfSpecifications
	|WHERE
	|	Not TableOfSpecifications.ProductsAndServicesTypeService
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TmpSpecificationTab.ConnectionKey,
	|	TmpSpecificationTab.Multiplicity,
	|	SpecificationsContent.ContentRowType,
	|	SpecificationsContent.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SpecificationsContent.MeasurementUnit,
	|	CASE
	|		WHEN SpecificationsContent.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)
	|			THEN CASE
	|					WHEN Not SpecificationsContent.MeasurementUnit = SpecificationsContent.ProductsAndServices.MeasurementUnit
	|						THEN CASE
	|								WHEN SpecificationsContent.MeasurementUnit.Factor = 0
	|									THEN 1
	|								ELSE SpecificationsContent.MeasurementUnit.Factor
	|							END
	|					ELSE 1
	|				END
	|		ELSE 1
	|	END AS CoefficientFromBaseMeasurementUnit,
	|	SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * TmpSpecificationTab.Multiplicity * CASE
	|		WHEN ISNULL(TmpSpecificationTab.CoefficientFromBaseMeasurementUnit, 0) = 0
	|			THEN 1
	|		ELSE TmpSpecificationTab.CoefficientFromBaseMeasurementUnit
	|	END AS Quantity,
	|	SpecificationsContent.ProductsQuantity,
	|	SpecificationsContent.Specification AS Specification
	|FROM
	|	TmpSpecificationTab AS TmpSpecificationTab
	|		LEFT JOIN Catalog.Specifications.Content AS SpecificationsContent
	|		ON TmpSpecificationTab.Specification = SpecificationsContent.Ref
	|WHERE
	|	(SpecificationsContent.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Material)
	|			OR SpecificationsContent.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.NODE))
	|	AND SpecificationsContent.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)";
	
	Query.SetParameter("TableOfSpecifications", TableOfSpecifications);
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	
	QueryResult = Query.Execute().Unload();
	
	TableOfNodes = TableOfSpecifications.Copy();
	TableOfNodes.Clear();
	
	For Each TableRow IN QueryResult Do
		
		If TableRow.ContentRowType = PredefinedValue("Enum.SpecificationContentRowTypes.Node") Then
			
			NewRow = TableOfNodes.Add();
			
		Else
			
			NewRow = Object.Materials.Add();
			
		EndIf;
		
		FillPropertyValues(NewRow, TableRow);
		
	EndDo;
	
	If TableOfNodes.Count() > 0 Then
		
		MoveMaterialsToTableFieldWithRecordKeys(TableOfNodes);
		
	EndIf;
	
EndProcedure

&AtServer
// Calls the material fill procedure by
// all specifications Next minimizes the row duplicates
Procedure FillMaterialsByAllSpecificationsAtServer()
	
	Works_ValueTable = FormAttributeToValue("Object").Works.Unload();
	
	//Delete rows without specifications and with specifications without content
	Counter = (Works_ValueTable.Count() - 1);
	While Counter >= 0 Do
		If Works_ValueTable[Counter].Specification.Content.Count() = 0 Then 
			Works_ValueTable.Delete(Works_ValueTable[Counter]);
		EndIf;
		Counter = Counter - 1;
	EndDo;
	
	Works_ValueTable.Columns.Add("CoefficientFromBaseMeasurementUnit", New TypeDescription("Number"));
	MoveMaterialsToTableFieldWithRecordKeys(Works_ValueTable);
	
	//Everything is filled now we will minimize the duplicating rows.
	MaterialsTable = Object.Materials.Unload();
	MaterialsTable.GroupBy("ConnectionKey, ProductsAndServices, Characteristic, Batch, MeasurementUnit", "Count, Reserve, ReserveShipment");
	
	Object.Materials.Clear();
	Object.Materials.Load(MaterialsTable);
	
EndProcedure // FillMaterialsByAllSpecificationsOnServer()

&AtServer
// Generates column content Materials and Performers in the PM Works Job order.
//
Procedure MakeNamesOfMaterialsAndPerformers()
	
	// Subordinate TP
	UseJobSharing = GetFunctionalOption("UseJobSharing");
	For Each WorkRow IN Object.Works Do
	
		StringMaterials = "";
		ArrayByKeyRecords = Object.Materials.FindRows(New Structure("ConnectionKey", WorkRow.ConnectionKey));
		For Each TSRow IN ArrayByKeyRecords Do
			StringMaterials = StringMaterials + ?(StringMaterials = "", "", ", ") + TSRow.ProductsAndServices 
								+ ?(ValueIsFilled(TSRow.Characteristic), " (" + TSRow.Characteristic + ")", "");
		EndDo;
		WorkRow.Materials = StringMaterials;
		
		TablePerformers = Object.Performers.Unload(New Structure("ConnectionKey", WorkRow.ConnectionKey), "Employee");
		Query = New Query;
		
		Query.Text = 
		"SELECT
		|	Employees.Code,
		|	Employees.Description,
		|	IndividualsDescriptionFullSliceLast.Surname,
		|	IndividualsDescriptionFullSliceLast.Name,
		|	IndividualsDescriptionFullSliceLast.Patronymic
		|FROM
		|	Catalog.Employees AS Employees
		|		LEFT JOIN InformationRegister.IndividualsDescriptionFull.SliceLast(&ToDate, ) AS IndividualsDescriptionFullSliceLast
		|		ON Employees.Ind = IndividualsDescriptionFullSliceLast.Ind
		|WHERE
		|	Employees.Ref IN(&TablePerformers)";
		
		Query.SetParameter("ToDate", Object.Date);
		Query.SetParameter("TablePerformers", TablePerformers);
		
		Selection = Query.Execute().Select();
		
		StringPerformers = "";
		While Selection.Next() Do
			PresentationEmployee = SmallBusinessServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic);
			StringPerformers = StringPerformers + ?(StringPerformers = "", "", ", ") 
								+ ?(ValueIsFilled(PresentationEmployee), PresentationEmployee, Selection.Description);
			If UseJobSharing Then
				StringPerformers = StringPerformers + " (" + TrimAll(Selection.Code) + ")";
			EndIf;
		EndDo;
		WorkRow.Performers = StringPerformers;
	
	EndDo;
	
EndProcedure // GenerateMaterialsAndPerformersNames()

// Procedure fills tabular section Performers by enterprise resources.
//
&AtServer
Procedure FillTabularSectionPerformersByResourcesAtServer(PerformersConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionPerformersByResources(PerformersConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
	ReflectChangesByTablePerformers(PerformersConnectionKey);
	
EndProcedure // FillTabularSectionPerformersByResourcesOnServer()

// Procedure fills the tabular section Performers by crews.
//
&AtServer
Procedure FillTabularSectionPerformersByCrewsAtServer(ArrayOfCrews, PerformersConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionPerformersByCrews(ArrayOfCrews, PerformersConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
	ReflectChangesByTablePerformers(PerformersConnectionKey);
	
EndProcedure // FillTabularSectionPerformersByCrewsOnServer()

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure OWGoodsFillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.GoodsFillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // WOGoodsFillColumnReserveByBalancesOnServer()

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure OWGoodsFillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.GoodsFillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // WOGoodsFillColumnReserveByReservesOnServer()

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure OWMaterialsFillColumnReserveByBalancesAtServer(MaterialsConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.MaterialsFillColumnReserveByBalances(MaterialsConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // WOMaterialsFillColumnReserveByBalancesOnServer()

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure OWMaterialsFillColumnReserveByReservesAtServer(MaterialsConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.MaterialsFillColumnReserveByReserves(MaterialsConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // WOMaterialsFillColumnReserveByReservesOnServer()

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
		AND GetFunctionalOption("DoNotPostDocumentsWithIncorrectContracts") Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract, OperationKind)
	
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

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
			
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		DiscountKindChanged = Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind AND ValueIsFilled(ContractData.DiscountMarkupKind);
		If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
			ClearDiscountCard = ValueIsFilled(Object.DiscountCard); // Attribute DiscountCard will be cleared later.
		Else
			ClearDiscountCard = False;
		EndIf;			
		QueryPriceKind = (ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged));
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
										AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0);
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("DiscountKindChanged", DiscountKindChanged);
		DocumentParameters.Insert("ClearDiscountCard", ClearDiscountCard);
		DocumentParameters.Insert("RecalculationRequiredInventory", Object.Inventory.Count() > 0);
		DocumentParameters.Insert("RecalculationRequiredWork", Object.Works.Count() > 0);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureForWorksWithPick

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName = "Inventory";
	SelectionMarker = "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			Counterparty);
	SelectionParameters.Insert("SpecificationsUsed", True);
	
	If FunctionalOptionInventoryReservation Then
		
		SelectionParameters.Insert("StructuralUnit",			Object.StructuralUnitReserve);
		SelectionParameters.Insert("FillReserve",			True);
		SelectionParameters.Insert("ReservationUsed", True);
		
	Else
		
		SelectionParameters.Insert("FillReserve", 			False);
		
	EndIf;
	
	SelectionParameters.Insert("AvailableStructuralUnitEdit", True);
	
	SelectionParameters.Insert("ExcludeProductsAndServicesTypeWork", True);
	
	SelectionParameters.Insert("DiscountMarkupKind", 		Object.DiscountMarkupKind);
	SelectionParameters.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionParameters.Insert("PriceKind", 				Object.PriceKind);
	SelectionParameters.Insert("Currency", 				Object.DocumentCurrency);
	SelectionParameters.Insert("AmountIncludesVAT", 		Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization", 	Object.Company);
	SelectionParameters.Insert("VATTaxation",		Object.VATTaxation);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.InventoryPrice.ReadOnly);
	
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
	
	SelectionParameters.Insert("ProductsAndServicesType",		ProductsAndServicesType);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	#If WebClient Then
		//Form data transmission platform error crawl in Web client when form item content change
		OpenForm("CommonForm.BalanceReservesPricesPickForm", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	#Else
		
		OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	#EndIf
	
EndProcedure // ExecutePick()

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure WorkSelection(Command)
	
	TabularSectionName = "Works";
	SelectionMarker = "Works";
	
	PickupForMaterialsInWorks = False;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			Counterparty);
	SelectionParameters.Insert("DiscountMarkupKind", 		Object.DiscountMarkupKind);
	SelectionParameters.Insert("DiscountCard", Object.DiscountCard);
	SelectionParameters.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionParameters.Insert("WorkKind", 				Object.WorkKind);
	SelectionParameters.Insert("SpecificationsUsed", True);
	SelectionParameters.Insert("Currency", 				Object.DocumentCurrency);
	SelectionParameters.Insert("DocumentOrganization", 	Object.Company);
	SelectionParameters.Insert("NormsUsed", 		True);
	
	SelectionParameters.Insert("AmountIncludesVAT", 		Object.AmountIncludesVAT);
	SelectionParameters.Insert("PriceKindsByWorkKinds", 		Object.PriceKind);
	SelectionParameters.Insert("VATTaxation", 	Object.VATTaxation);
	SelectionParameters.Insert("ShowPriceColumn", 	False);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.ValWorksPrice.ReadOnly);
	
	ProductsAndServicesType = New ValueList;
	For Each ArrayElement IN Items.ValWorksProductsAndServices.ChoiceParameters Do
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
	
EndProcedure // ExecutePick()

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure MaterialsPick(Command)
	
	TabularSectionName = "ConsumerMaterials";
	SelectionMarker = "ConsumerMaterials";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 		Object.Date);
	SelectionParameters.Insert("Company",	Counterparty);
	
	ProductsAndServicesType = New ValueList;
	For Each ArrayElement IN Items["WO" + TabularSectionName + "ProductsAndServices"].ChoiceParameters Do
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
	
	#If WebClient Then
		//Form data transmission platform error crawl in Web client when form item content change
		OpenForm("CommonForm.BalanceReservesPricesPickForm", SelectionParameters, ThisForm);
		
	#Else
		
		OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
		
	#EndIf
	
EndProcedure // ExecutePick()

// Fixes error in event log
//
&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogMonitorClient.AddMessageForEventLogMonitor("Error", , EventLogMonitorErrorText);
	
EndProcedure // WriteErrorReadingDataFromStorage()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If Not (TypeOf(TableForImport) = Type("ValueTable")
		OR TypeOf(TableForImport) = Type("Array")) Then
		
		EventLogMonitorErrorText = "Mismatch the type of passed to the document from pick [" + TypeOf(TableForImport) + "].
				|Address of inventories in storage: " + TrimAll(InventoryAddressInStorage) + "
				|Tabular section name: " + TrimAll(TabularSectionName);
		
		Return;
		
	Else
		
		EventLogMonitorErrorText = "";
		
	EndIf;
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If NewRow.Property("Total")
			AND Not ValueIsFilled(NewRow.Total) Then
			
			NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
			
		EndIf;
		
		// Refilling
		If TabularSectionName = "Works" Then
			
			NewRow.ConnectionKey = SmallBusinessServer.CreateNewLinkKey(ThisForm);
			
			If ValueIsFilled(ImportRow.ProductsAndServices) Then
				
				NewRow.ProductsAndServicesTypeService = (ImportRow.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.Service"));
				
			EndIf;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If ValueIsFilled(ImportRow.ProductsAndServices) Then
				
				NewRow.ProductsAndServicesTypeInventory = (ImportRow.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
				
			EndIf;
			
			// If the order is "Executed" val. in pick select the
			// shipped good, else in pick select good to reserve, but the field too needs to be filled.
			NewRow.ReserveShipment = NewRow.Reserve;
			
		EndIf;
		
		If NewRow.Property("Specification") Then 
			
			NewRow.Specification = SmallBusinessServer.GetDefaultSpecification(ImportRow.ProductsAndServices, ImportRow.Characteristic);
			
		EndIf;
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure // GetInventoryFromStorage()

&AtServer
// Function places the list of advances into temporary storage and returns the address
//
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|SettlementsAmount,
			//( elmi # 08.5
			//|Rate,
			|ExchangeRate,
			//) elmi
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction // PlacePrepaymentToStorage()

&AtServer
// Function gets the list of advances from the temporary storage
//
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure // GetPrepaymentFromStorage()

#EndRegion

#Region DataProcessorProcedureButtonPressPickTPWOMaterials

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure OWMaterialsPick(Command)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en='Main tabular section row is not selected.';ru='Не выбрана строка основной табличной части!'");
		Message.Message();
		Return;
	EndIf;
	
	TabularSectionName = "OWMaterials";
	SelectionMarker = "Works";
	
	PickupForMaterialsInWorks = True;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 					Object.Date);
	SelectionParameters.Insert("Company", 				Counterparty);
	SelectionParameters.Insert("ReservationUsed", True);
	
	SelectionParameters.Insert("StructuralUnit", 		Object.StructuralUnitReserve);
	
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
	
EndProcedure // WOMaterialsPick()

&AtServer
// Function gets a product list from the temporary storage
//
Procedure OWMaterialsGetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object.Materials.Add();
		FillPropertyValues(NewRow, ImportRow);
		NewRow.ConnectionKey = Items.OWMaterials.RowFilter["ConnectionKey"];
		
		NewRow.ReserveShipment = NewRow.Reserve;
		
	EndDo;
	
EndProcedure // WOMaterialsGetInventoryFromStorage()

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure sets form item availability from order stage.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabledFromState()
	
	If Object.OrderState.OrderStatus = PredefinedValue("Enum.OrderStatuses.Open") Then
		
		Items.OWSchedulePay.Enabled = False;
		Items.WOGroupPaymentsCalendar.Visible = False;
		
		Object.SchedulePayment = False;
		
		If Object.PaymentCalendar.Count() > 0 Then
			Object.PaymentCalendar.Clear();
		EndIf;
		
	Else
		
		Items.OWSchedulePay.Enabled = True;
		
	EndIf;
	
	If Object.OrderState.OrderStatus = PredefinedValue("Enum.OrderStatuses.Completed") Then
		
		Items.InventoryReserve.Visible = False;
		Items.InventoryReserveShipment.Visible = True;
		
		Items.InventoryChangeReserveFillByBalances.Visible = False;
		Items.InventoryChangeReserveFillByReserves.Visible = True;
		
		Items.OWMaterialsReserve.Visible = False;
		Items.ValMaterialsReserveShipment.Visible = True;
		
		Items.MaterialsChangeReserveFillByBalances.Visible = False;
		Items.MaterialsChangeReserveFillByBalancesForAll.Visible = False;
		Items.MaterialsChangeReserveFillByReserves.Visible = True;
		Items.MaterialsChangeReserveFillByReservesForAll.Visible = True;
		
		Items.VALoupPrepayment.Enabled = True;
		
	Else
		
		Items.InventoryReserve.Visible = True;
		Items.InventoryReserveShipment.Visible = False;
		
		Items.InventoryChangeReserveFillByBalances.Visible = True;
		Items.InventoryChangeReserveFillByReserves.Visible = False;
		
		Items.OWMaterialsReserve.Visible = True;
		Items.ValMaterialsReserveShipment.Visible = False;
		
		Items.MaterialsChangeReserveFillByBalances.Visible = True;
		Items.MaterialsChangeReserveFillByBalancesForAll.Visible = True;
		Items.MaterialsChangeReserveFillByReserves.Visible = False;
		Items.MaterialsChangeReserveFillByReservesForAll.Visible = False;
		
		For Each StringInventory IN Object.Inventory Do
			StringInventory.ReserveShipment = StringInventory.Reserve;
		EndDo;
		
		For Each StringMaterials IN Object.Materials Do
			StringMaterials.ReserveShipment = StringMaterials.Reserve;
		EndDo;
		
		Items.VALoupPrepayment.Enabled = False;
		
		If Object.Prepayment.Count() > 0 Then
			Object.Prepayment.Clear();
		EndIf;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabledFromState()

// Procedure sets the form item availability from schedule payment.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabledFromSchedulePayment()
	
	If Object.SchedulePayment Then
		
		Items.WOGroupPaymentsCalendar.Visible = True;
		
	Else
		
		Items.WOGroupPaymentsCalendar.Visible = False;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabledFromSchedulePayment()

&AtServer
// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	Items.OWGroupPerformers.Visible = UseSubsystemPayroll;
	
EndProcedure // SetVisibleByFOUseSubsystemPayroll()

// Procedure sets the form item visible.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	If Object.WorkKindPosition = PredefinedValue("Enum.AttributePositionOnForm.InHeader") Then
		Items.OWWorkKind.Visible = True;
		Items.OWWorksWorkKind.Visible = False;
		Items.TableWorksWorkKind.Visible = False;
		WorkKindInHeader = True;
	Else
		Items.OWWorkKind.Visible = False;
		Items.OWWorksWorkKind.Visible = True;
		Items.TableWorksWorkKind.Visible = True;
		WorkKindInHeader = False;
	EndIf;
	
	If Object.UseProducts Then
		Items.VALGroupInventory.Visible = True;
	Else
		Items.VALGroupInventory.Visible = False;
	EndIf;
	
	If Object.UseConsumerMaterials Then
		Items.WOGroupConsumerMaterials.Visible = True
	Else
		Items.WOGroupConsumerMaterials.Visible = False;
	EndIf;
	
	If Object.UseMaterials Then
		Items.OWMaterials.Visible = True
	Else
		Items.OWMaterials.Visible = False;
	EndIf;
	
	If Object.UsePerformerSalaries 
		AND UseSubsystemPayroll Then
		
		Items.OWGroupPerformers.Visible = True
		
	Else
		
		Items.OWGroupPerformers.Visible = False;
		
	EndIf;
	
EndProcedure // SetVisibleFromUserSettings()

// Sets the current page for document operation kind.
//
// Parameters:
// No
//
&AtClient
Procedure OWSetCurrentPage()
	
	PageName = "";
	
	If Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		PageName = "ValPageBankAccount";
	ElsIf Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		PageName = "OWPagePettyCash";
	EndIf;
	
	PageItem = Items.Find(PageName);
	If PageItem <> Undefined Then
		Items.WOCashboxBankAccount.Visible = True;
		Items.WOCashboxBankAccount.CurrentPage = PageItem;
	Else
		Items.WOCashboxBankAccount.Visible = False;
	EndIf;
	
EndProcedure // SetCurrentPage()

// Procedure - Set edit by list option.
//
&AtClient
Procedure OWSetPossibilityOfEditInList()
	
	Items.OWEditInList.Check = Not Items.OWEditInList.Check;
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not Items.OWEditInList.Check
		  AND Object.PaymentCalendar.Count() > 1 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("WOSetEditByListOptionEnd", ThisObject, New Structure("LineCount", LineCount)), 
			NStr("en='All rows except the first will be deleted. Continue?';ru='Все строки кроме первой будут удалены. Продолжить?'"),
			QuestionDialogMode.YesNo
		);
		Return;
	EndIf;
	
	WOSetEditByListOptionFragment();
	
EndProcedure

&AtClient
Procedure WOSetEditByListOptionEnd(Result, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Items.OWEditInList.Check = True;
		Return;
	EndIf;
	
	While LineCount > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar[LineCount - 1]);
		LineCount = LineCount - 1;
	EndDo;
	Items.ValPaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	
	WOSetEditByListOptionFragment();
	
EndProcedure

&AtClient
Procedure WOSetEditByListOptionFragment()
	
	If Items.OWEditInList.Check Then
		Items.WOGroupPaymentCalendarAsListAsString.CurrentPage = Items.WOGroupPaymentCalendarAsList;
	Else
		Items.WOGroupPaymentCalendarAsListAsString.CurrentPage = Items.WOGroupPaymentCalendarAsString;
	EndIf;
	
EndProcedure // SetEditByListOption()

&AtClient
// Procedure - command handler of the tabular section command panel.
//
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en='Specify the counterparty first.';ru='Укажите вначале контрагента!'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en='Specify the counterparty contract first.';ru='Укажите вначале договор контрагента!'"));
		Return;
	EndIf;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	SelectionParameters = New Structure(
		"AddressPrepaymentInStorage,
		|Pick,
		//( elmi # 08.5
		//|ThereIsOrder,
		|IsOrder,
		//) elmi
		|ThereIsOrder,
		|OrderInHeader,
		|Company,
		|Order,
		|Date,
		//( elmi # 08.5
		//|Refs,
		|Ref,
		//) elmi
		|Counterparty,
		|Contract,
		//( elmi # 08.5
		//|Rate,
		|ExchangeRate,
		//) elmi
		|Multiplicity,
		|DocumentCurrency,
		|DocumentAmount",
		AddressPrepaymentInStorage, // AddressPrepaymentInStorage
		True, // Pick
		False, // IsOrder
		True, // OrderInHeader
		Counterparty, // Counterparty
		?(CounterpartyDoSettlementsByOrders, Object.Ref, Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Works.Total("Total") + Object.Inventory.Total("Total")
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

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	If ValueIsFilled(Object.Counterparty) Then
		
		CalculationParametersWithCounterparty = CommonUse.ObjectAttributesValues(Object.Counterparty, "DoOperationsByOrders, DoOperationsByContracts");
		
		CounterpartyDoSettlementsByOrders = CalculationParametersWithCounterparty.DoOperationsByOrders;
		Items.OWContract.Visible = CalculationParametersWithCounterparty.DoOperationsByContracts;
		
	Else
		
		CounterpartyDoSettlementsByOrders = False;
		Items.OWContract.Visible = False;
		
	EndIf;
	
EndProcedure // SetContractVisible()

#EndRegion

#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		Object.OperationKind,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	CounterpartyContractParameters = New Structure;
	If Not ValueIsFilled(Object.Ref)
		AND ValueIsFilled(Object.Counterparty)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			ContractParametersByDefault = CommonUse.ObjectAttributesValues(Object.Counterparty, "ContractByDefault");
			Object.Contract = ContractParametersByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			CounterpartyContractParameters = CommonUse.ObjectAttributesValues(Object.Contract, "SettlementsCurrency, DiscountMarkupKind, PriceKind");
			Object.DocumentCurrency = CounterpartyContractParameters.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", CounterpartyContractParameters.SettlementsCurrency));
			Object.ExchangeRate      = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.DiscountMarkupKind = CounterpartyContractParameters.DiscountMarkupKind;
			Object.PriceKind = CounterpartyContractParameters.PriceKind;
		EndIf;
	Else
		CounterpartyContractParameters = CommonUse.ObjectAttributesValues(Object.Contract, "SettlementsCurrency");
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	CounterpartyContractParameters.Property("SettlementsCurrency", SettlementsCurrency);
	NationalCurrency = SmallBusinessReUse.GetNationalCurrency();
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", NationalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	TabularSectionName = "Works";
	
	FunctionalOptionInventoryReservation = GetFunctionalOption("InventoryReservation");
	
	If Not ValueIsFilled(Object.Ref) Then
		
		// Start and Finish
		If Not (Parameters.FillingValues.Property("Start") OR Parameters.FillingValues.Property("Finish")) Then
			Object.Start = CurrentDate();
			Object.Finish = EndOfDay(CurrentDate());
		EndIf;
		
		If Not ValueIsFilled(Parameters.CopyingValue) Then
		
			Query = New Query(
			"SELECT ALLOWED
			|	CASE
			|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
			|			THEN Companies.BankAccountByDefault
			|		ELSE UNDEFINED
			|	END AS BankAccount
			|FROM
			|	Catalog.Companies AS Companies
			|WHERE
			|	Companies.Ref = &Company");
			Query.SetParameter("Company", Object.Company);
			Query.SetParameter("CashCurrency", Object.DocumentCurrency);
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			If Selection.Next() Then
				Object.BankAccount = Selection.BankAccount;
			EndIf;
			Object.PettyCash = Catalogs.PettyCashes.GetPettyCashByDefault(Object.Company);
			
		EndIf;
		
	EndIf;
	
	MakeNamesOfMaterialsAndPerformers();
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.OWWorksVATRate.Visible = True;
		Items.OWWorksAmountVAT.Visible = True;
		Items.WOWorksTotal.Visible = True;
		Items.WOPaymentCalendarPaymentVATAmount.Visible = True;
		Items.WOListPaymentCalendarVATAmountPayments.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.OWWorksVATRate.Visible = False;
		Items.OWWorksAmountVAT.Visible = False;
		Items.WOWorksTotal.Visible = False;
		Items.WOPaymentCalendarPaymentVATAmount.Visible = False;
		Items.WOListPaymentCalendarVATAmountPayments.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	CurrencyTransactionsAccounting = GetFunctionalOption("CurrencyTransactionsAccounting");
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	SetVisibleAndEnabledFromState();
	SetVisibleAndEnabledFromSchedulePayment();
	
	UseSubsystemPayroll = GetFunctionalOption("UseSubsystemPayroll")
		AND (AccessManagement.IsRole("AddChangePayrollSubsystem") OR AccessManagement.IsRole("FullRights"));
	
	// FO Use Payroll subsystem.
	SetVisibleByFOUseSubsystemPayroll();
	
	Items.VALoupPrepayment.Enabled = Object.OrderState.OrderStatus = PredefinedValue("Enum.OrderStatuses.Completed");
	Items.OWSchedulePay.Enabled = Object.OrderState.OrderStatus <> PredefinedValue("Enum.OrderStatuses.Open");
	
	// If the document is opened from pick, fill the tabular section products
	If Parameters.FillingValues.Property("InventoryAddressInStorage") 
		AND ValueIsFilled(Parameters.FillingValues.InventoryAddressInStorage) Then
		
		GetInventoryFromStorage(Parameters.FillingValues.InventoryAddressInStorage, 
							Parameters.FillingValues.TabularSectionName,
							Parameters.FillingValues.AreCharacteristics,
							Parameters.FillingValues.AreBatches);
		
	EndIf;
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	// End PickProductsAndServicesInDocuments
	
	// Footer, invoice
	SmallBusinessServer.SetTextAboutInvoice(ThisForm);
	
	TotalAmount = Object.Works.Total("Total") + Object.Inventory.Total("Total");
	TotalVATAmount = Object.Works.Total("VATAmount") + Object.Inventory.Total("VATAmount");
	
	// Form title setting.
	If Not ValueIsFilled(Object.Ref) Then
		AutoTitle = False;
		Title = "Job order (Creation)";
	EndIf;
	
	// Status.
	If Not GetFunctionalOption("UseCustomerOrderStates") Then
		
		Items.OWGroupState.Visible = False;
		
		InProcessStatus = SmallBusinessReUse.GetStatusInProcessOfCustomerOrders();
		CompletedStatus = SmallBusinessReUse.GetStatusCompletedCustomerOrders();
		Items.ValStatus.ChoiceList.Add("In process", "In process");
		Items.ValStatus.ChoiceList.Add("Completed", "Completed");
		Items.ValStatus.ChoiceList.Add("Canceled", "Canceled");
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			ValStatus = "In process";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			ValStatus = "Completed";
		Else
			ValStatus = "Canceled";
		EndIf;
		
	Else
		
		Items.OWGroupStatuses.Visible = False;
		
	EndIf;
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings(); 
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf;
	
	// Set filter for TableWorks by Products and services type.
	FilterStructure = New Structure;
	FilterStructure.Insert("ProductsAndServicesTypeService", False);
	FixedFilterStructure = New FixedStructure(FilterStructure);
	Items.TableWorks.RowFilter = FixedFilterStructure;
	
	// Setting contract visible.
	SetContractVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.ValWorksPrice.ReadOnly 				  = Not AllowedEditDocumentPrices;
	Items.WOWorksPercentDiscountMarkup.ReadOnly  = Not AllowedEditDocumentPrices;
	Items.ValWorksAmount.ReadOnly 				  = Not AllowedEditDocumentPrices;
	Items.OWWorksAmountVAT.ReadOnly 			  = Not AllowedEditDocumentPrices;
	
	Items.InventoryPrice.ReadOnly 					  = Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	  = Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 				  = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly	 			  = Not AllowedEditDocumentPrices;
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ChangeProhibitionDates
	ChangeProhibitionDatesOverridable.CheckDateBanEditingJobOrder(ThisForm, Object);
	// End StandardSubsystems.ChangeProhibitionDates
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsJobOrder);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "WOGroupAdditionalAttributes");
	// End StandardSubsystems.Properties
	
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
	MakeNamesOfMaterialsAndPerformers();
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	OWSetCurrentPage();
	
	LineCount = Object.PaymentCalendar.Count();
	Items.OWEditInList.Check = LineCount > 1;
	
	If Object.PaymentCalendar.Count() > 0 Then
		Items.ValPaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	EndIf;
	
	If Items.OWEditInList.Check Then
		Items.WOGroupPaymentCalendarAsListAsString.CurrentPage = Items.WOGroupPaymentCalendarAsList;
	Else
		Items.WOGroupPaymentCalendarAsListAsString.CurrentPage = Items.WOGroupPaymentCalendarAsString;
	EndIf;
	
	
    //( elmi # 08.5 
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "Prepayment");
   //) elmi

	
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// AutomaticDiscounts
	// Display the message about discount calculation when user clicks the "Post and close" button or closes the form by the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification("Update:", 
										GetURL(Object.Ref), 
										String(Object.Ref)+". Automatic discounts (markups) are calculated!", 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		
		NotifyWorkCalendar = True;
		DocumentModified = False;
		
		Notify("NotificationAboutChangingDebt");
		
		If Not InvoiceText = "Enter invoice note" Then
			
			QuestionText = NStr("en='Changes were made in the document. 
		|Is it required to fill in the subordinate invoice once again?';ru='В документе были произведены изменения. 
		|Требуется ли повторно заполнить подчиненный Счет-фактуру?'");
				
			NotifyDescription = New NotifyDescription("DefineNecessityToFillSubordinateInvoiceNote", ThisObject);
			
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, 0);
			
		EndIf;
		
	EndIf;
	
EndProcedure // AfterWrite()

// BeforeRecord event handler procedure.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerOrderPosting");
	// StandardSubsystems.PerformanceEstimation
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = "Automatic discounts (markups) are calculated!";
			Message.DataKey = Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// 'Properties' subsystem handler
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// 'Properties' subsystem handler
	
	If Modified Then
		
		DocumentModified = True;
		
	EndIf;
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(
			MessageText, 
			CurrentObject.Contract, 
			CurrentObject.Ref, 
			CurrentObject.Company, 
			CurrentObject.Counterparty, 
			CurrentObject.OperationKind, 
			Cancel
		);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en='Document is not posted! ';ru='Документ не проведен! '") + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
		If SmallBusinessReUse.GetAdvanceOffsettingSettingValue() = PredefinedValue("Enum.YesNo.Yes")
			AND Items.VALoupPrepayment.Enabled
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		EndIf;
	EndIf;
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure // BeforeWriteAtServer()

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

&AtServer
// Procedure-handler  of the AfterWriteOnServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Form title setting.
	Title = "";
	AutoTitle = True;
	
	MakeNamesOfMaterialsAndPerformers();
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerOrderAfterWriteOnServer");
	
EndProcedure // AfterWriteOnServer()

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If NotifyWorkCalendar Then
		Notify("ChangedJobOrder", Object.Responsible);
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
	// Peripherals
	If Source = "Peripherals"
		AND IsInputAvailable() AND Not DiscountCardRead Then
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
	
	// DiscountCards
	If DiscountCardRead Then
		DiscountCardRead = False;
	EndIf;
	// End DiscountCards
	
	// Subsystem 'ElectronicDocuments'
	If EventName = "UpdateIBDocumentAfterFilling" Then
		
		ThisForm.Read();
		
	EndIf;
	// End "ElectronicDocuments" subsystem
	
	If EventName = "RefreshOfTextAboutInvoice" 
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
			
		InventoryAddressInStorage	= Parameter;
		AreCharacteristics 		= True;
		
		If SelectionMarker = "Works" Then
			
			If PickupForMaterialsInWorks Then
				
				TabularSectionName 	= "OWMaterials";
				AreBatches 			= True;
				
				OWMaterialsGetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
				FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
				Items[TabularSectionName].RowFilter = FilterStr;
				
			Else
				
				TabularSectionName 	= "Works";
				AreBatches 			= False;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
				TotalAmount = Object.Works.Total("Total") + Object.Inventory.Total("Total");
				TotalVATAmount = Object.Works.Total("VATAmount") + Object.Inventory.Total("VATAmount");
				
				// Payment calendar.
				RecalculatePaymentCalendar();
				
			EndIf;
			
		ElsIf SelectionMarker = "Inventory" Then
			
			TabularSectionName	= "Inventory";
			AreBatches 			= True;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
			
			If Not IsBlankString(EventLogMonitorErrorText) Then
				WriteErrorReadingDataFromStorage();
			EndIf;
			
			//Footer
			TotalAmount = Object.Works.Total("Total") + Object.Inventory.Total("Total");
			TotalVATAmount = Object.Works.Total("VATAmount") + Object.Inventory.Total("VATAmount");
			
			// Payment calendar.
			RecalculatePaymentCalendar();
			
		ElsIf SelectionMarker = "ConsumerMaterials" Then
			
			TabularSectionName	= "ConsumerMaterials";
			AreBatches 			= False;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
			
		EndIf;
		
	EndIf;

EndProcedure // NotificationProcessing()

// Procedure - selection handler.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.CustomerInvoiceNote.Form.DocumentForm" Then
		InvoiceText = ValueSelected;
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandFormPanelsActionProcedures

// Procedure is called by clicking the PricesCurrency
// button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure // EditPricesAndCurrency()

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
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // SearchByBarcode()

// Gets the weight for tabular section row.
//
&AtClient
Procedure GetWeightForTabularSectionRow(TabularSectionRow)
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='It is required to select a line to get weight for it.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NOTifyDescription, UUID);
		
	EndIf;
	
EndProcedure // GetWeightForTabularSectionRow()

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

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure OWGetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	GetWeightForTabularSectionRow(TabularSectionRow);
	
EndProcedure // GetWeight()

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillBySpecification(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en='Main tabular section row is not selected.';ru='Не выбрана строка основной табличной части!'");
		Message.Message();
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentTSLine.Specification) Then
		SmallBusinessClient.ShowMessageAboutError(Object, "Specification is not specified!");
		Return;
	EndIf;
	
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", Items.OWMaterials.RowFilter["ConnectionKey"]));
	
	If SearchResult.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillBySpecificationEnd", ThisObject, New Structure("SearchResult", SearchResult)),
			NStr("en='Tabular section ""Materials"" will be refilled! Continue the operation?';ru='Табличная часть ""Материалы"" будет перезаполнена! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillBySpecificationFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillBySpecificationEnd(Result, AdditionalParameters) Export
	
	SearchResult = AdditionalParameters.SearchResult;
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillBySpecificationFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillBySpecificationFragment(Val SearchResult)
	
	Var IndexOfDeletion, SearchString, FilterStr, CurrentTSLine;
	
	Modified = True;
	
	For Each SearchString IN SearchResult Do
		IndexOfDeletion = Object.Materials.IndexOf(SearchString);
		Object.Materials.Delete(IndexOfDeletion);
	EndDo;
	
	CurrentTSLine = Items.Works.CurrentData;
	FillBySpecificationsAtServer(CurrentTSLine.Specification, CurrentTSLine.Multiplicity);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.OWMaterials.RowFilter["ConnectionKey"]);
	Items.OWMaterials.RowFilter = FilterStr;
	
EndProcedure // FillBySpecification()

// Procedure - fill button handler by all specifications of tabular field Works
&AtClient
Procedure FillMaterialsFromAllSpecifications(Command)
	
	If Not Object.Works.Count() > 0 Then
		
		Message		= New UserMessage;
		Message.Text = NStr("en='Fill tabular section ""Works"".';ru='Заполните табличную часть ""Работы"".'");
		Message.DataPath = "Works";
		Message.Message();
		
		Return;
		
	EndIf;
	
	If Object.Materials.Count() > 0 Then
		
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("FillMaterialsFromAllSpecificationsEnd", ThisObject),
			NStr("en='It is necessary to clear tabular section ""Materials"" to execute operation! Continue the operation?';ru='Для выполнения операции требуется очистить табличную часть """"Материалы""""! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillMaterialsFromAllSpecificationsFragment();
	
EndProcedure

&AtClient
Procedure FillMaterialsFromAllSpecificationsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillMaterialsFromAllSpecificationsFragment();
	
EndProcedure

&AtClient
Procedure FillMaterialsFromAllSpecificationsFragment()
	
	Modified = True;
	
	Object.Materials.Clear();
	
	FillMaterialsByAllSpecificationsAtServer();
	
	// For the WEB we will repeat pick, what it is correct to display the following PM
	TabularSectionName = "Works";
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "OWMaterials");
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "Performers");
	
EndProcedure //FillMaterialsFromAllSpecifications()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByResourcesForCurrentWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, TabularSectionName);
	If Cancel Then
		
		Return;
		
	EndIf;
	
	CurrentTSLine = Items.TableWorks.CurrentData;
	If Not ValueIsFilled(CurrentTSLine.ProductsAndServices) Then
		
		SmallBusinessClient.ShowMessageAboutError(Object, "Work is not specified!");
		Return;
		
	EndIf;
	
	If Object.EnterpriseResources.Count() = 0 Then
		
		SmallBusinessClient.ShowMessageAboutError(Object, NStr("en='Tabular section ""Used resources has no any records!""';ru='В табличной части ""Задействованные ресурсы"" нет записей!'"));
		Return;
		
	EndIf;
	
	SearchResult = Object.Performers.FindRows(New Structure("ConnectionKey", Items.Performers.RowFilter["ConnectionKey"]));
	
	If SearchResult.Count() <> 0 Then
		
		QuestionText = NStr("en='Tabular section ""Performers"" for current work will be refilled! Continue the operation?';ru='Табличная часть """"Исполнители"""" для текущей работы будет перезаполнена! Продолжить выполнение операции?'");
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillByResourcesForCurrentWorksEnd", ThisObject, New Structure("SearchResult", SearchResult)), QuestionText, QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillByResourcesForCurrentWorksFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillByResourcesForCurrentWorksEnd(Result, AdditionalParameters) Export
	
	SearchResult = AdditionalParameters.SearchResult;
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		
		Return;
		
	EndIf;
	
	FillByResourcesForCurrentWorksFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillByResourcesForCurrentWorksFragment(Val SearchResult)
	
	Var IndexOfDeletion, PerformersConnectionKey, SearchString, FilterStr;
	
	For Each SearchString IN SearchResult Do
		
		IndexOfDeletion = Object.Performers.IndexOf(SearchString);
		Object.Performers.Delete(IndexOfDeletion);
		
	EndDo;
	
	PerformersConnectionKey = Items.Performers.RowFilter["ConnectionKey"];
	FillTabularSectionPerformersByResourcesAtServer(PerformersConnectionKey);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.Performers.RowFilter["ConnectionKey"]);
	Items.Performers.RowFilter = FilterStr;
	
EndProcedure // FillByResourcesForCurrentWorks()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByResourcesForAllWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, TabularSectionName);
	If Cancel Then
		Return;
	EndIf;
	
	If Object.EnterpriseResources.Count() = 0 Then
		SmallBusinessClient.ShowMessageAboutError(Object, NStr("en='Tabular section ""Used resources has no any records!""';ru='В табличной части ""Задействованные ресурсы"" нет записей!'"));
		Return;
	EndIf;
	
	If Object.Performers.Count() <> 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillByResourcesForAllWorksEnd", ThisObject),
			NStr("en='Tabular section ""Performers"" will be refilled! Continue the operation?';ru='Табличная часть ""Исполнители"" будет перезаполнена! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillByResourcesForAllWorksFragment();
	
EndProcedure

&AtClient
Procedure FillByResourcesForAllWorksEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByResourcesForAllWorksFragment();
	
EndProcedure

&AtClient
Procedure FillByResourcesForAllWorksFragment()
	
	Var FilterStr;
	
	Object.Performers.Clear();
	
	FillTabularSectionPerformersByResourcesAtServer();
	
	FilterStr = New FixedStructure("ConnectionKey", Items.Performers.RowFilter["ConnectionKey"]);
	Items.Performers.RowFilter = FilterStr;
	
EndProcedure // FillByResourcesForAllWorks()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByCrewsForCurrentWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, TabularSectionName);
	If Cancel Then
		Return;
	EndIf;
	
	CurrentTSLine = Items.TableWorks.CurrentData;
	If Not ValueIsFilled(CurrentTSLine.ProductsAndServices) Then
		SmallBusinessClient.ShowMessageAboutError(Object, "Work is not specified!");
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MultiselectList", True);
	ArrayOfCrews = Undefined;

	OpenForm("Catalog.Crews.ChoiceForm", OpenParameters,,,,, New NotifyDescription("FillByCrewsForCurrentWorksEnd1", ThisObject));
	
EndProcedure

&AtClient
Procedure FillByCrewsForCurrentWorksEnd1(Result, AdditionalParameters) Export
	
	ArrayOfCrews = Result;
	If ArrayOfCrews = Undefined Then
		Return;
	EndIf;
	
	SearchResult = Object.Performers.FindRows(New Structure("ConnectionKey", Items.Performers.RowFilter["ConnectionKey"]));
	
	If SearchResult.Count() <> 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillByCrewsForCurrentWorksEnd", ThisObject, New Structure("ArrayOfCrews, SearchResult", ArrayOfCrews, SearchResult)), NStr("en='Tabular section ""Performers"" for current work will be refilled! Continue the operation?';ru='Табличная часть """"Исполнители"""" для текущей работы будет перезаполнена! Продолжить выполнение операции?'"),
		QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillByCrewsForCurrentWorksFragment(ArrayOfCrews, SearchResult);
	
EndProcedure

&AtClient
Procedure FillByCrewsForCurrentWorksEnd(Result, AdditionalParameters) Export
	
	ArrayOfCrews = AdditionalParameters.ArrayOfCrews;
	SearchResult = AdditionalParameters.SearchResult;
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByCrewsForCurrentWorksFragment(ArrayOfCrews, SearchResult);
	
EndProcedure

&AtClient
Procedure FillByCrewsForCurrentWorksFragment(Val ArrayOfCrews, Val SearchResult)
	
	Var IndexOfDeletion, PerformersConnectionKey, SearchString, FilterStr;
	
	For Each SearchString IN SearchResult Do
		IndexOfDeletion = Object.Performers.IndexOf(SearchString);
		Object.Performers.Delete(IndexOfDeletion);
	EndDo;
	
	PerformersConnectionKey = Items.Performers.RowFilter["ConnectionKey"];
	FillTabularSectionPerformersByCrewsAtServer(ArrayOfCrews, PerformersConnectionKey);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.Performers.RowFilter["ConnectionKey"]);
	Items.Performers.RowFilter = FilterStr;
	
EndProcedure // FillByCrewsForCurrentWorks()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByCrewsForAllWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, TabularSectionName);
	If Cancel Then
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MultiselectList", True);
	ArrayOfCrews = Undefined;

	OpenForm("Catalog.Crews.ChoiceForm", OpenParameters,,,,, New NotifyDescription("FillByCrewsForAllWorksEnd1", ThisObject));
	
EndProcedure

&AtClient
Procedure FillByCrewsForAllWorksEnd1(Result, AdditionalParameters) Export
	
	ArrayOfCrews = Result;
	If ArrayOfCrews = Undefined Then
		Return;
	EndIf;
	
	If Object.Performers.Count() <> 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillByCrewsForAllWorksEnd", ThisObject, New Structure("ArrayOfCrews", ArrayOfCrews)),
			NStr("en='Tabular section ""Performers"" will be refilled! Continue the operation?';ru='Табличная часть ""Исполнители"" будет перезаполнена! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillByCrewsForAllWorksFragment(ArrayOfCrews);
	
EndProcedure

&AtClient
Procedure FillByCrewsForAllWorksEnd(Result, AdditionalParameters) Export
	
	ArrayOfCrews = AdditionalParameters.ArrayOfCrews;
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByCrewsForAllWorksFragment(ArrayOfCrews);
	
EndProcedure

&AtClient
Procedure FillByCrewsForAllWorksFragment(Val ArrayOfCrews)
	
	Var FilterStr;
	
	Object.Performers.Clear();
	
	FillTabularSectionPerformersByCrewsAtServer(ArrayOfCrews);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.Performers.RowFilter["ConnectionKey"]);
	Items.Performers.RowFilter = FilterStr;
	
EndProcedure // FillByCrewsForAllWorks()

// Procedure - EditByList command handler.
//
&AtClient
Procedure OWEditInList(Command)
	
	OWSetPossibilityOfEditInList();
	
EndProcedure // EditByList()

// Procedure - clicking handler on the hyperlink InvoiceText.
//
&AtClient
Procedure InvoiceNoteTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SmallBusinessClient.OpenInvoice(ThisForm);
	
EndProcedure

// Procedure - command handler DocumentSetting.
//
&AtClient
Procedure DocumentSetting(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WorkKindPositionInJobOrder", 					Object.WorkKindPosition);
	ParametersStructure.Insert("UseProductsInJobOrder", 					Object.UseProducts);
	ParametersStructure.Insert("UseConsumerMaterialsInJobOrder", 		Object.UseConsumerMaterials);
	ParametersStructure.Insert("UseMaterialsInJobOrder", 				Object.UseMaterials);
	
	If UseSubsystemPayroll Then
		
		ParametersStructure.Insert("UsePerformerSalariesInJobOrder",	Object.UsePerformerSalaries);
		
	EndIf;
	
	ParametersStructure.Insert("WereMadeChanges", False);
	
	StructureDocumentSetting = Undefined;
	
	OpenForm("CommonForm.DocumentSetting", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	// 2. Open "Setting document" form.
	StructureDocumentSetting = Result;
	
	// 3. Apply changes made in "Document setting" form.
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.WorkKindPosition 				= StructureDocumentSetting.WorkKindPositionInJobOrder;
		Object.UseProducts 				= StructureDocumentSetting.UseProductsInJobOrder;
		Object.UseConsumerMaterials 	= StructureDocumentSetting.UseConsumerMaterialsInJobOrder;
		Object.UseMaterials 			= StructureDocumentSetting.UseMaterialsInJobOrder;
		Object.UsePerformerSalaries = StructureDocumentSetting.UsePerformerSalariesInJobOrder;
		
		If Not ValueIsFilled(Object.ShipmentDate) Then
			Object.ShipmentDate = Object.Finish;
		EndIf;
		
		SetVisibleFromUserSettings();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ChangeReserveProducts

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure OWChangeGoodsReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Goods"" is not filled!';ru='Табличная часть ""Товары"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	OWGoodsFillColumnReserveByBalancesAtServer();
	
EndProcedure // WOChangeGoodsReserveFillByBalances()

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure OWChangeGoodsReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Goods"" is not filled!';ru='Табличная часть ""Товары"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	OWGoodsFillColumnReserveByReservesAtServer();
	
EndProcedure // WOChangeGoodsReserveFillByReserves()

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure OWChangeProductsReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Goods"" is not filled!';ru='Табличная часть ""Товары"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow IN Object.Inventory Do
		
		If TabularSectionRow.ProductsAndServicesTypeInventory Then
			TabularSectionRow.Reserve = 0;
			TabularSectionRow.ReserveShipment = 0;
		EndIf;
		
	EndDo;
	
EndProcedure // WOChangeProductsReserveClearReserve()

#EndRegion

#Region ChangeReserveMaterials

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure OWChangeMaterialsReserveFillByBalances(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en='Main tabular section row is not selected.';ru='Не выбрана строка основной табличной части!'");
		Message.Message();
		Return;
	EndIf;
	
	MaterialsConnectionKey = Items.OWMaterials.RowFilter["ConnectionKey"];
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
	If SearchResult.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Materials"" is not filled!';ru='Табличная часть ""Материалы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	OWMaterialsFillColumnReserveByBalancesAtServer(MaterialsConnectionKey);
	
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "OWMaterials");
	
EndProcedure // WOChangeMaterialsReserveFillByBalances()

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure OWChangeMaterialsReserveFillByBalancesForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Materials"" is not filled!';ru='Табличная часть ""Материалы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("WOChangeMaterialsReserveFillByBalancesForAllEnd", ThisObject),
			NStr("en='In the tabular section ""Materials"" column ""Reserve"" will be refilled for all works! Continue the operation?';ru='В табличной части ""Материалы"" колонка ""Резерв"" будет перезаполнена для всех работ! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByBalancesForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByBalancesForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByBalancesForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByBalancesForAllFragment()
	
	OWMaterialsFillColumnReserveByBalancesAtServer();
	
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "OWMaterials");
	
EndProcedure // WOChangeMaterialsReserveFillByBalancesForAll()

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure OWChangeMaterialsReserveFillByReserves(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en='Main tabular section row is not selected.';ru='Не выбрана строка основной табличной части!'");
		Message.Message();
		Return;
	EndIf;
	
	MaterialsConnectionKey = Items.OWMaterials.RowFilter["ConnectionKey"];
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
	If SearchResult.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Materials"" is not filled!';ru='Табличная часть ""Материалы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	OWMaterialsFillColumnReserveByReservesAtServer(MaterialsConnectionKey);
	
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "OWMaterials");
	
EndProcedure // WOChangeMaterialsReserveFillByReserves()

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure OWChangeMaterialsReserveFillByReservesForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Materials"" is not filled!';ru='Табличная часть ""Материалы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("WOChangeMaterialsReserveFillByReservesForAllEnd", ThisObject),
			NStr("en='In the tabular section ""Materials"" column ""Reserve"" will be refilled for all works! Continue the operation?';ru='В табличной части ""Материалы"" колонка ""Резерв"" будет перезаполнена для всех работ! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByReservesForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByReservesForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByReservesForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByReservesForAllFragment()
	
	OWMaterialsFillColumnReserveByReservesAtServer();
	
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "OWMaterials");
	
EndProcedure // WOChangeMaterialsReserveFillByReservesForAll()

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure OWChangeMaterialsReserveClearReserve(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en='Main tabular section row is not selected.';ru='Не выбрана строка основной табличной части!'");
		Message.Message();
		Return;
	EndIf;
	
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", Items.OWMaterials.RowFilter["ConnectionKey"]));
	If SearchResult.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Materials"" is not filled!';ru='Табличная часть ""Материалы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow IN SearchResult Do
		
		TabularSectionRow.Reserve = 0;
		TabularSectionRow.ReserveShipment = 0;
		
	EndDo;
	
EndProcedure // WOChangeMaterialsReserveClearReserve()

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure OWChangeMaterialsReserveClearReserveForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Materials"" is not filled!';ru='Табличная часть ""Материалы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("WOChangeMaterialsReserveClearReserveForAllEnd", ThisObject),
			NStr("en='In the tabular section ""Materials"" column ""Reserve"" will be refilled for all works! Continue the operation?';ru='В табличной части ""Материалы"" колонка ""Резерв"" будет перезаполнена для всех работ! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveClearReserveForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveClearReserveForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveClearReserveForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveClearReserveForAllFragment()
	
	Var TabularSectionRow;
	
	For Each TabularSectionRow IN Object.Materials Do
		
		TabularSectionRow.Reserve = 0;
		TabularSectionRow.ReserveShipment = 0;
		
	EndDo;
	
EndProcedure // WOChangeMaterialsReserveClearReserveForAll()

#EndRegion

#Region CommandActionsPanelOrderState

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure VALStatusOnChange(Item)
	
	If ValStatus = "In process" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf ValStatus = "Completed" Then
		Object.OrderState = CompletedStatus;
		Object.Closed = True;
	ElsIf ValStatus = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
	SetVisibleAndEnabledFromState();
	
EndProcedure // StatusOnChange()

#EndRegion

#Region ProceduresEventHandlersHeaderAttributes

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
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		RecalculatePaymentCalendar();
		RefreshFormFooter();
		
		// DiscountCards
		// IN this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards		
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
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
	StructureData = GetCompanyDataOnChange();
	Counterparty = StructureData.Counterparty;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	RecalculatePaymentCalendar();
	RefreshFormFooter();
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ContractData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = ContractData.Contract;
		ProcessContractChange(ContractData);
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

// Procedure - event handler OnChange of the Contract input field.
// Fills form attributes - exchange rate and multiplicity.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure // ContractOnChange()

// Procedure - event handler SelectionStart input field WOContract.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormOfContractParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure SalesStructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.SalesStructuralUnit) Then
		
		If Not ValueIsFilled(Object.StructuralUnitReserve) Then
			
			StructureData = New Structure();
			StructureData.Insert("Division", Object.SalesStructuralUnit);
			
			StructureData = GetDataStructuralUnitOnChange(StructureData);
			
			Object.StructuralUnitReserve = StructureData.InventoryStructuralUnit;
			Object.Cell = StructureData.CellInventory;
			Items.WOCellInventory.Enabled = StructureData.OrderWarehouseOfInventory;
			
		EndIf;
		
	Else
		
		Items.WOCellInventory.Enabled = False;
		
	EndIf;
	
EndProcedure // StructuralUnitOnChange()

// Procedure - event handler OnChange of the OrderState input field.
//
&AtClient
Procedure OWOrderStatusOnChange(Item)
	
	SetVisibleAndEnabledFromState();
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure WOStartOnChange(Item)
	
	If Object.Start > Object.Finish Then
		Object.Start = WhenChangingStart;
		Message(NStr("en='Start date can not be later than the end date.';ru='Дата старта не может быть больше даты финиша.'"));
	Else
		WhenChangingStart = Object.Start;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure WOFinishOnChange(Item)
	
	If Hour(Object.Finish) = 0 AND Minute(Object.Finish) = 0 Then
		Object.Finish = EndOfDay(Object.Finish);
	EndIf;
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		Message(NStr("en='Finish date can not be less than the start date.';ru='Дата финиша не может быть меньше даты старта.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field WorkKind.
//
&AtClient
Procedure WorkKindOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
		
		RefillTabularSectionPricesByPriceKind();
		
	EndIf;
	
EndProcedure // WorksProductsAndServicesOnChange()

// Procedure - event handler OnChange input field CashAssetsType.
//
&AtClient
Procedure OWCashAssetsTypeOnChange(Item)
	
	OWSetCurrentPage();
	
EndProcedure // CashAssetsTypeOnChange()

// Procedure - event handler OnChange of the ReflectInPaymentCalendar input field.
//
&AtClient
Procedure OWSchedulePayOnChange(Item)
	
	SetVisibleAndEnabledFromSchedulePayment();
	
	If Object.SchedulePayment
		AND Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		NewRow.PayDate = Object.Date + GetCustomerPaymentDueDate(Object.Contract) * 86400;
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Object.Inventory.Total("Total") + Object.Works.Total("Total");
		NewRow.PayVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
		Items.ValPaymentCalendar.CurrentRow = NewRow.GetID();
	ElsIf Not Object.SchedulePayment
		AND Object.PaymentCalendar.Count() > 0 Then
		Object.PaymentCalendar.Clear();
	EndIf;
	
EndProcedure // SchedulePayOnChange()

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure OWPaymentsCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.ValPaymentCalendar.CurrentData;
	PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PercentOfPaymentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
	EndIf;
	
	CurrentRow.PaymentAmount = Round((Object.Inventory.Total("Total") + Object.Works.Total("Total")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PayVATAmount = Round((Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // PaymentCalendarPaymentPercentOnChange()

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure OWPaymentsCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.ValPaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("Total") + Object.Works.Total("Total");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentAmount = CurrentRow.PaymentAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PayVATAmount = Round((Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // PaymentCalendarPaymentSumOnChange()

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure OWPaymentsCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.ValPaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("VATAmount") + Object.Works.Total("Total");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PayVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PayVATAmount = CurrentRow.PayVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
EndProcedure // PaymentCalendarPayVATAmountOnChange()

// Procedure - event handler SelectionStart input field BankAccount.
//
&AtClient
Procedure BankAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Contract) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParametersBankAccount(Object.Contract, Object.Company, NationalCurrency);
	If FormParameters.SettlementsInStandardUnits Then
		
		StandardProcessing = False;
		OpenForm("Catalog.BankAccounts.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Gets the banking account selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParametersBankAccount(Contract, Company, NationalCurrency)
	
	AttributesContract = CommonUse.ObjectAttributesValues(Contract, "SettlementsCurrency, SettlementsInStandardUnits");
	
	CurrenciesList = New ValueList;
	CurrenciesList.Add(AttributesContract.SettlementsCurrency);
	CurrenciesList.Add(NationalCurrency);
	
	FormParameters = New Structure;
	FormParameters.Insert("SettlementsInStandardUnits", AttributesContract.SettlementsInStandardUnits);
	FormParameters.Insert("Owner", Company);
	FormParameters.Insert("CurrenciesList", CurrenciesList);
	
	Return FormParameters;
	
EndFunction

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersTabularSectionAttributesProducts

// Procedure - event handler OnEditEnd tabular section Products.
//
&AtClient
Procedure ProductsOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // ProductsOnEditEnd()

// Procedure - event handler AfterDeleteRow tabular section Products.
//
&AtClient
Procedure ProductsAfterDeletion(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure // ProductsAfterDeletion()

&AtClient
// Procedure - event handler BeforeAddStart tabular section "Products".
//
Procedure ProductsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		TotalAmount = Object.Works.Total("Total") + Object.Inventory.Total("Total");
		TotalVATAmount = Object.Works.Total("VATAmount") + Object.Inventory.Total("VATAmount");
		CopyingProductsRow = True;
	EndIf;
	
EndProcedure // ProductsBeforeAddStart()

&AtClient
// Procedure - event handler OnChange tabular section "Products".
//
Procedure ProductsOnChange(Item)
	
	If CopyingProductsRow = Undefined OR Not CopyingProductsRow Then
		RefreshFormFooter();
	Else
		CopyingProductsRow = False;
	EndIf;
	
EndProcedure // ProductsOnChange()

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure ProductsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	
	TabularSectionRow.ProductsAndServicesTypeInventory = StructureData.IsInventoryItem;
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure // ProductsProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", 			TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", 			TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", 			Object.Date);
		StructureData.Insert("DocumentCurrency", 		Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 		Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 				TabularSectionRow.VATRate);
		StructureData.Insert("Price", 					TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure // ProductsCharacteristicOnChange()

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
Procedure ProductsQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // ProductsQuantityOnChange()

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure GoodsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		Or TabularSectionRow.Price = 0 Then
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
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure // ProductsMeasurementUnitChoiceProcessing()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ProductsPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // ProductsPriceOnChange()

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure GoodsDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // ProductsDiscountMarkupPercentOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure ProductsAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // ProductsAmountOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ProductsVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure  // ProductsVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ProductsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure // ProductsVATAmountOnChange()

// Procedure - event handler OnChange input field Reserve.
//
&AtClient
Procedure WOProductsReserveOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.ReserveShipment = TabularSectionRow.Reserve;
	
EndProcedure // WOProductsReserveOnChange()

// Procedure - event handler OnChange input field ReserveShipment.
//
&AtClient
Procedure OWProductsReserveShipmentOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.ReserveShipment < TabularSectionRow.Reserve Then
		
		TabularSectionRow.Reserve = TabularSectionRow.ReserveShipment;
		
	EndIf;
	
EndProcedure // WOProductsReserveShipmentOnChange()

#EndRegion

#Region ProceduresTabularSectionAttributesEventHandlersWOWorks

// Procedure - event handler OnActivateRow tabular sectionp "Works".
//
&AtClient
Procedure WorksOnActivateRow(Item)
	
	TabularSectionName = "Works";
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "OWMaterials");
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.OWWorkMaterials.Enabled = Not TabularSectionRow.ProductsAndServicesTypeService;
	EndIf;
	
EndProcedure // WorksOnActivateRow()

// Procedure - event handler OnActivateRow tabular section "TableWorks".
//
&AtClient
Procedure TableWorkOnActivateRow(Item)
	
	TabularSectionName = "TableWorks";
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "Performers");
	
EndProcedure // TableWorkOnActivateRow()

// Procedure - event handler OnStartEdit tabular section Works.
//
&AtClient
Procedure WorksOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Works";
	If NewRow Then
		
		SmallBusinessClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "OWMaterials");
		
	EndIf;
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.OWWorkMaterials.Enabled = Not TabularSectionRow.ProductsAndServicesTypeService;
	EndIf;
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine("Works", Item.CurrentData);
	EndIf;
	// End AutomaticDiscounts

EndProcedure // WorksOnStartEdit()

// Procedure - event handler BeforeAddStart tabular section "Works".
//
&AtClient
Procedure WorksBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		TotalAmount = Object.Works.Total("Total") + Object.Inventory.Total("Total") + Item.CurrentData.Total;
		TotalVATAmount = Object.Works.Total("VATAmount") + Object.Inventory.Total("VATAmount") + Item.CurrentData.VATAmount;
		RowCopyWorks = True;
	EndIf;
	
EndProcedure // InventoryBeforeAddStart()

// Procedure - event handler OnChange tabular section "Works".
//
&AtClient
Procedure WorksOnChange(Item)
	
	If RowCopyWorks = Undefined OR Not RowCopyWorks Then
		RefreshFormFooter();
	Else
		RowCopyWorks = False;
	EndIf;
	
EndProcedure // InventoryOnChange()

// Procedure - event handler OnEditEnd of tabular section Works.
//
&AtClient
Procedure WorksOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// Set filter for TableWorks by Products and services type.
	FilterStructure = New Structure;
	FilterStructure.Insert("ProductsAndServicesTypeService", False);
	FixedFilterStructure = New FixedStructure(FilterStructure);
	Items.TableWorks.RowFilter = FixedFilterStructure;
	
EndProcedure // WorksOnEditEnd()

// Procedure - event handler BeforeDelete tabular section Works.
//
&AtClient
Procedure WorksBeforeDelete(Item, Cancel)

	TabularSectionName = "Works";
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Materials");
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Performers");
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.OWWorkMaterials.Enabled = Not TabularSectionRow.ProductsAndServicesTypeService;
	EndIf;
	
EndProcedure // WorksBeforeDeletion()

// Procedure - event handler AfterDeleteRow tabular section Works.
//
&AtClient
Procedure JobsAfterDeleteRow(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure // WorksAfterDeletion()

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure WorksProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	TabularSectionName = "Works";
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Materials");
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Performers");
	TabularSectionRow.Materials = "";
	TabularSectionRow.Performers = "";
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("TimeNorm", 1);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If WorkKindInHeader AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("WorkKind", Object.WorkKind);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	ElsIf (NOT WorkKindInHeader) AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("WorkKind", TabularSectionRow.WorkKind);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards

	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.Quantity = StructureData.TimeNorm;
	TabularSectionRow.Multiplicity = 1; 
	TabularSectionRow.Factor = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Content = "";
	
	If (WorkKindInHeader AND ValueIsFilled(Object.PriceKind) AND StructureData.Property("Price")) OR StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	EndIf;
	
	TabularSectionRow.ProductsAndServicesTypeService = StructureData.IsService;
	
	If TabularSectionRow <> Undefined Then
		Items.OWWorkMaterials.Enabled = Not TabularSectionRow.ProductsAndServicesTypeService;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Works");
	
EndProcedure // WorksProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure WorksCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("TimeNorm", 1);
	
	If WorkKindInHeader AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("WorkKind", Object.WorkKind);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards

	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.Quantity = StructureData.TimeNorm;
	TabularSectionRow.Multiplicity = 1; 
	TabularSectionRow.Factor = 1; 
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	If (WorkKindInHeader AND ValueIsFilled(Object.PriceKind)) OR StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Works");
	
EndProcedure // WorksCharacteristicOnChange()

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure VALWorksContentAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Works.CurrentData;
		ContentPattern = SmallBusinessServer.GetContentText(TabularSectionRow.ProductsAndServices, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field WorkKind.
//
&AtClient
Procedure WorksWorkKindOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
		
		TabularSectionRow = Items.Works.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("Company", 		Counterparty);
		StructureData.Insert("ProductsAndServices", 		TabularSectionRow.ProductsAndServices);
		StructureData.Insert("Characteristic", 		TabularSectionRow.Characteristic);
		StructureData.Insert("WorkKind", 			TabularSectionRow.WorkKind);
		
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", 				Object.PriceKind);
		StructureData.Insert("Factor", 		1);
		
		StructureData.Insert("DiscountMarkupKind", 	Object.DiscountMarkupKind);
		
		// DiscountCards
		StructureData.Insert("DiscountCard", 	Object.DiscountCard);
		StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
		// End DiscountCards

		StructureData = GetDataProductsAndServicesOnChange(StructureData);
		
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
		
		CalculateAmountInTabularSectionLine("Works");
		
	EndIf;
	
EndProcedure // WorksProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure WorksQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
EndProcedure // WorksQuantityOnChange()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure WorksFactorOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
EndProcedure // WorksQuantityOnChange()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure WorksRepetitionOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
EndProcedure // WorksQuantityOnChange()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure WorksPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
EndProcedure // WorksPriceOnChange()

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure WorksDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
EndProcedure // WorksDiscountMarkupPercentOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure WorksAmountOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // WorksAmountOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure WorksVATRateOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
EndProcedure  // WorksVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure WorksAmountVATOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	//Performers
	ReflectChangeKeyParameterInAccrualPerformers();
	
EndProcedure // WorksAmountVATOnChange()

#EndRegion

#Region ProceduresTablePartEventHandlersMaterials

// Procedure - event handler BeforeAddStart tabular section Materials.
//
&AtClient
Procedure OWMaterialsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Works";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure // WOMaterialsBeforeAddStart()

// Procedure - event handler OnStartEdit tabular section Materials.
//
&AtClient
Procedure OWMaterialsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Works";
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
EndProcedure // WOMaterialsOnStartEdit()

#EndRegion

#Region ProceduresTablePartEventHandlersPerformers

// Procedure - event handler AfterDeleteRow tabular section Performers
//
//
&AtClient
Procedure PerformersAfterDeleteRow(Item)
	
	RefreshTabularSectionPerformers();
	
EndProcedure

// Procedure - event handler OnEditEnd tabular section Performers
//
&AtClient
Procedure PerformersOnEditEnd(Item, NewRow, CancelEdit)
	
	RefreshTabularSectionPerformers();
	
EndProcedure // PerformersOnEditEnd()

// Procedure - event handler BeforeAddStart of tabular section Performers.
//
&AtClient
Procedure PerformersBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "TableWorks";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure // PerformersBeforeAddStart()

// Procedure - event handler OnStartEdit tabular section Performers.
//
&AtClient
Procedure PerformersOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "TableWorks";
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
EndProcedure // PerformersOnStartEdit()

#EndRegion

#Region ProceduresTabularSectionAttributesEventHandlersWOMaterials

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure OWMaterialsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.OWMaterials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = MaterialsGetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Reserve = 0;
	TabularSectionRow.ReserveShipment = 0;
	
EndProcedure // WOMaterialsProductsAndServicesOnChange()

// Procedure - event handler OnChange input field Reserve.
//
&AtClient
Procedure OWMaterialsReserveOnChange(Item)
	
	TabularSectionRow = Items.OWMaterials.CurrentData;
	TabularSectionRow.ReserveShipment = TabularSectionRow.Reserve;
	
EndProcedure // WOMaterialsReserveOnChange()

// Procedure - event handler OnChange input field ReserveShipment.
//
&AtClient
Procedure OWMaterialsReserveShipmentOnChange(Item)
	
	TabularSectionRow = Items.OWMaterials.CurrentData;
	
	If TabularSectionRow.ReserveShipment < TabularSectionRow.Reserve Then
		
		TabularSectionRow.Reserve = TabularSectionRow.ReserveShipment;
		
	EndIf;
	
EndProcedure // WOMaterialsReserveShipmentOnChange()

#EndRegion

#Region ProceduresTabularSectionAttributesEventHandlersPerformers

// Procedure - event handler OnChange input field Employee.
//
&AtClient
Procedure PerformersEmployeeOnChange(Item)
	
	TabularSectionRow = Items.Performers.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ToDate", Object.Date);
	StructureData.Insert("Company", Counterparty);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("Employee", TabularSectionRow.Employee);
	
	StructureData = GetEmployeeDataOnChange(StructureData);
	
	TabularSectionRow.AccrualDeductionKind = StructureData.AccrualDeductionKind;
	TabularSectionRow.AmountAccrualDeduction = StructureData.Amount;
	TabularSectionRow.LPF = 1;
	
EndProcedure // PerformersEmployeeOnChange()

#EndRegion

#Region ProceduresTabularSectionAttributesEventHandlersConsumerMaterials

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure OWCustomerMaterialsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.WOConsumerMaterials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Counterparty);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure // MaterialsProductsAndServicesOnChange()

// Procedure - OnStartEdit event handler of the .PaymentCalendar list
//
&AtClient
Procedure OWPaymentsCalendarOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		CurrentRow = Items.ValPaymentCalendar.CurrentData;
		PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
		
		If PercentOfPaymentTotal > 100 Then
			CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
		EndIf;
		
		CurrentRow.PaymentAmount = Round((Object.Inventory.Total("Total") + Object.Works.Total("Total")) * CurrentRow.PaymentPercentage / 100, 2, 1);
		CurrentRow.PayVATAmount = Round((Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	EndIf;
	
EndProcedure // PaymentCalendarOnStartEdit()

// Procedure - event handler BeforeDelete tabular section WOPaymentCalendar.
//
&AtClient
Procedure OWPaymentsCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure // WOPaymentCalendarBeforeDeletion()

// Procedure - event handler OnChange input field ListPaymentCalendarPaymentPercent.
//
&AtClient
Procedure OWListPaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.ValPaymentCalendar.CurrentData;
	PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PercentOfPaymentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
	EndIf;
	
	CurrentRow.PaymentAmount = Round((Object.Inventory.Total("Total") + Object.Works.Total("Total")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PayVATAmount = Round((Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // ListPaymentCalendarPaymentPercentOnChange()

// Procedure - event handler OnChange of the ListPaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure OWListPaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.ValPaymentCalendar.CurrentData;
	InventoryTotal = Object.Inventory.Total("Total") + Object.Works.Total("Total");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentAmount = CurrentRow.PaymentAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PayVATAmount = Round((Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure // ListPaymentCalendarPaymentSumOnChange()

// Procedure - event handler OnChange of the ListPaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure OWListPaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.ValPaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PayVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PayVATAmount = CurrentRow.PayVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;

EndProcedure // ListPaymentCalendarPayVATAmountOnChange()

#EndRegion

#Region ProceduresTabularSectionAttributesEventHandlersEnterpriseResources

// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
&AtClient
Function CalculateDuration(CurrentRow)
	
	DurationInSeconds = CurrentRow.Finish - CurrentRow.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	
	Return Duration;
	
EndFunction // CalculateDuration()

// It receives data set from the server for the EnterpriseResourcesOnStartEdit procedure.
//
&AtClient
Function GetDataEnterpriseResourcesOnStartEdit(DataStructure)
	
	DataStructure.Start = Object.Start - Second(Object.Start);
	DataStructure.Finish = Object.Finish - Second(Object.Finish);
	
	If ValueIsFilled(DataStructure.Start) AND ValueIsFilled(DataStructure.Finish) Then
		If BegOfDay(DataStructure.Start) <> BegOfDay(DataStructure.Finish) Then
			DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		EndIf;
		If DataStructure.Start >= DataStructure.Finish Then
			DataStructure.Finish = DataStructure.Start + 1800;
			If BegOfDay(DataStructure.Finish) <> BegOfDay(DataStructure.Start) Then
				If EndOfDay(DataStructure.Start) = DataStructure.Start Then
					DataStructure.Start = DataStructure.Start - 29 * 60;
				EndIf;
				DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
			EndIf;
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Start) Then
		DataStructure.Start = DataStructure.Start;
		DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Start = BegOfDay(DataStructure.Start);
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Finish) Then
		DataStructure.Start = BegOfDay(DataStructure.Finish);
		DataStructure.Finish = DataStructure.Finish;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Finish = EndOfDay(DataStructure.Finish) - 59;
		EndIf;
	Else
		DataStructure.Start = BegOfDay(CurrentDate());
		DataStructure.Finish = EndOfDay(CurrentDate()) - 59;
	EndIf;
	
	DurationInSeconds = DataStructure.Finish - DataStructure.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	DataStructure.Duration = Duration;
	
	Return DataStructure;
	
EndFunction // GetDataEnterpriseResourcesOnStartEdit()

// Procedure - event handler OnStartEdit tabular section EnterpriseResources.
//
&AtClient
Procedure EnterpriseResourcesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.EnterpriseResources.CurrentData;
		
		DataStructure = New Structure;
		DataStructure.Insert("Start", '00010101');
		DataStructure.Insert("Finish", '00010101');
		DataStructure.Insert("Duration", '00010101');
		
		DataStructure = GetDataEnterpriseResourcesOnStartEdit(DataStructure);
		TabularSectionRow.Start = DataStructure.Start;
		TabularSectionRow.Finish = DataStructure.Finish;
		TabularSectionRow.Duration = DataStructure.Duration;
		
	EndIf;
	
EndProcedure // EnterpriseResourcesOnStartEdit()

// Procedure - event handler OnChange input field EnterpriseResource.
//
&AtClient
Procedure EnterpriseResourcesEnterpriseResourceOnChange(Item)
	
	TabularSectionRow = Items.EnterpriseResources.CurrentData;
	TabularSectionRow.Capacity = 1;
	
EndProcedure // EnterpriseResourcesEnterpriseResourceOnChange()

// Procedure - event handler OnChange input field Day.
//
&AtClient
Procedure EnterpriseResourcesDayOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = CurrentDate();
	EndIf;
	
	FinishInSeconds = Hour(CurrentRow.Finish) * 3600 + Minute(CurrentRow.Finish) * 60;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	CurrentRow.Finish = BegOfDay(CurrentRow.Start) + FinishInSeconds;
	CurrentRow.Start = CurrentRow.Finish - DurationInSeconds;
	
EndProcedure // EnterpriseResourcesDayOnChange()

// Procedure - event handler OnChange input field Duration.
//
&AtClient
Procedure EnterpriseResourcesDurationOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	If DurationInSeconds = 0 Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
	Else
		CurrentRow.Finish = CurrentRow.Start + DurationInSeconds;
	EndIf;
	If BegOfDay(CurrentRow.Start) <> BegOfDay(CurrentRow.Finish) Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure // EnterpriseResourcesDurationOnChange()

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure EnterpriseResourcesStartOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = BegOfDay(CurrentRow.Finish);
	EndIf;
	
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure // EnterpriseResourcesStartOnChange()

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure EnterpriseResourcesFinishOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If Hour(CurrentRow.Finish) = 0 AND Minute(CurrentRow.Finish) = 0 Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure // EnterpriseResourcesFinishOnChange()

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
				TabularSectionRow.SettlementsAmount/ TabularSectionRow.PaymentAmount * Object.Multiplicity
		);
	Else
		TabularSectionRow.ExchangeRate =
			?(TabularSectionRow.SettlementsAmount = 0,
				1,
				TabularSectionRow.PaymentAmount  / TabularSectionRow.SettlementsAmount * Object.ExchangeRate
		);
	EndIf;
	//) elmi
EndProcedure

#EndRegion

#Region EventHandlerProcedureTips

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanelSB.Form.SectionSales");
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Modified = True;
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			
			Object.BankAccount = Undefined;
			
		EndIf;
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
				Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonUseClientServer.MessageToUser(
				NStr("en='Discount card is not read. Discount card owner does not match with a counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
				,
				"Counterparty",
				"Object");
			EndIf;
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		EndIf;
		// End DiscountCards
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.VATTaxation = ClosingResult.VATTaxation;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Works");
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Works");
			
		EndIf;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, RepetitionNationalCurrency, Object.Multiplicity));
				
		EndDo;
		
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation, 
			Object.DiscountCard, 
			Object.DiscountPercentByDiscountCard);
			
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
	EndIf;
	
	RecalculatePaymentCalendar();
	RefreshFormFooter();
	
EndProcedure // OpenPricesAndCurrencyFormEnd()

&AtClient
// Procedure-handler of the response to question about the necessity to set a new currency rate
//
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
				?(Object.DocumentCurrency = NationalCurrency, RepetitionNationalCurrency, Object.Multiplicity));  
			
		EndDo;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
			Object.PriceKind, 
			Object.DiscountMarkupKind, 
			Object.DocumentCurrency, 
			SettlementsCurrency, 
			Object.ExchangeRate, 
			RateNationalCurrency, 
			Object.AmountIncludesVAT, 
			CurrencyTransactionsAccounting, 
			Object.VATTaxation, 
			Object.DiscountCard, 
			Object.DiscountPercentByDiscountCard
			);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure // DefineNewCurrencyRateSettingNeed()

&AtClient
// Procedure-handler response on question about document recalculate by contract data
//
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		
		If AdditionalParameters.RecalculationRequiredInventory Then
			
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			
		EndIf;
		
		If AdditionalParameters.RecalculationRequiredWork Then
			
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		RecalculatePaymentCalendar();
		RefreshFormFooter();
		
	EndIf;
	
EndProcedure // DefineDocumentRecalculateNeedByContractTerms()

&AtClient
// Procedure-handler response on question about filling of subordinate document Invoice
//
Procedure DefineNecessityToFillSubordinateInvoiceNote(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		SmallBusinessServer.ChangeSubordinateInvoice(Object.Ref);
		Notify("UpdateIBDocumentAfterFilling");
		
	EndIf;
	
EndProcedure // DefineNecessityToFillSubordinateInvoiceNote()

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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

#EndRegion

#Region DiscountCards

// Procedure - selection handler of discount card, beginning.
//
&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.ValCounterparty);
		
		ShowUserNotification(
			NStr("en='Counterparty is filled and discount card is read';ru='Заполнен контрагент и считана дисконтная карта'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='The counterparty is filled out in the document and discount card %1 is read';ru='В документе заполнен контрагент и считана дисконтная карта %1'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Discount card is not read. Discount card owner does not match with a counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
			,
			"Counterparty",
			"Object");
		
		Return;
	Else
		ShowUserNotification(
			NStr("en='Discount card read';ru='Считана дисконтная карта'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Discount card %1 is read';ru='Считана дисконтная карта %1'"), DiscountCard),
			PictureLib.Information32);
	EndIf;
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
			
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.Inventory.Count() > 0 Or Object.Works.Count() > 0 Then
		Text = NStr("en='Refill discounts in all rows?';ru='Перезаполнить скидки во всех строках?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Works");
	EndIf;
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

// Function returns the discount card owner.
//
&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

// Function returns True if the discount card, which is passed as the parameter, is fixed.
//
&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountKindsForDiscountCards.FixedDiscount;
	
EndFunction

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.Inventory.Count() > 0 Then
			Text = NStr("en = 'Change the percent of discount of the progressive discount card with "+PreDiscountPercentByDiscountCard+"% on "+NewDiscountPercentByDiscountCard+"% and refill discounts in all rows?'");
			
			AdditionalParameters = New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification = New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
		Else
			Text = NStr("en = 'Change the percent of discount of the progressive discount card with "+PreDiscountPercentByDiscountCard+"% on "+NewDiscountPercentByDiscountCard+"%?'");
			
			AdditionalParameters = New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification = New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
		EndIf;
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
				Object.PriceKind,
				Object.DiscountMarkupKind,
				Object.DocumentCurrency,
				SettlementsCurrency,
				Object.ExchangeRate,
				RateNationalCurrency,
				Object.AmountIncludesVAT,
				CurrencyTransactionsAccounting,
				Object.VATTaxation,
				Object.DiscountCard,
				Object.DiscountPercentByDiscountCard);
				
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
			
			// Payment calendar.
			RecalculatePaymentCalendar();
		EndIf;
				
	EndIf;
	
EndProcedure

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of command handler ReadDiscountCard forms.
// Is called after read form closing of discount card.
//
&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 AND Object.Works.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

// Procedure calculates discounts by document.
//
&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If discounts changed the function returns the value True.
//
&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	DiscountsChanged = False;
	
	LineCount = AppliedDiscounts.TableDiscountsMarkups.Count();
	If LineCount <> Object.DiscountsMarkups.Count() Then
		DiscountsChanged = True;
	Else
		
		If Object.Inventory.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
			DiscountsChanged = True;
		EndIf;
		
		If Not DiscountsChanged Then
			For LineNumber = 1 To LineCount Do
				If    Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
					OR Object.DiscountsMarkups[LineNumber-1].ConnectionKey <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].ConnectionKey
					OR Object.DiscountsMarkups[LineNumber-1].DiscountMarkup <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].DiscountMarkup Then
					DiscountsChanged = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	If DiscountsChanged Then
		AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	EndIf;
	
	Return DiscountsChanged;
	
EndFunction

// Procedure calculates discounts by document.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Inventory");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.FunctionalOptionUseDiscountsMarkups.Get();
	For Each CurrentRow IN Object.Inventory Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
	For Each CurrentRow IN Object.Works Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure - command handler "OpenDiscountInformation" for tabular section "Inventory".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient("Inventory")
	
EndProcedure

// Procedure - command handler "OpenDiscountInformation" for tabular section "Works".
//
&AtClient
Procedure OpenInformationAboutDiscountsWorks(Command)
	
	CurrentData = Items.Works.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient("Works");
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure OpenInformationAboutDiscountsClient(TSName)
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration",   False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en='Discounts (markups) are not calculated, calculate?';ru='Скидки (наценки) не рассчитаны, рассчитать?'");
		
		AdditionalParameters = New Structure("TSName", TSName); 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, TSName);
	EndIf;
	
EndProcedure

// End modeless window opening "ShowQuestion()". Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, AdditionalParameters.TSName);
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row after calculation of automatic discounts (if it was necessary).
//
&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, TSName)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items[TSName].CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Procedure - event handler Table parts selection Inventory.
//
&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient("Inventory");
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Inventory forms.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler Table parts selection Works.
//
&AtClient
Procedure ChoiceWorks(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.WOWorksAutomaticDiscountPercent OR Item.CurrentItem = Items.VALWorksAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient("Works");
		
	EndIf;
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0) AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to recalculate discounts.
//
&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0) AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn, "Inventory", "Works");
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 AND Object.Works.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

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
