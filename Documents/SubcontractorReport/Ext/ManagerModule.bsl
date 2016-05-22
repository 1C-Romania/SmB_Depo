#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// AccountingRecords

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	//elmi start
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATExpenses ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATExpensesCur 
	|FROM
	|	TemporaryTableForCalculationOfReserves AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATExpenses = 0;
	VATExpensesCur = 0;
	
	While Selection.Next() Do  
		  VATExpenses    = Selection.VATExpenses;
	      VATExpensesCur = Selection.VATExpensesCur;
	EndDo;
	//elmi end

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("SetOffAdvancePayment", NStr("en = 'Setoff of advance payment'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.GLAccountVendorSettlements AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.VendorAdvancesGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	&SetOffAdvancePayment AS Content
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency AS VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency AS GLAccountVendorSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|			DocumentTable.VendorAdvancesGLAccount.Currency AS VendorAdvancesGLAccountCurrency,
	|			DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|			DocumentTable.GLAccountVendorSettlements.Currency AS GLAccountVendorSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|	
	|UNION ALL
	|	
	|SELECT
	|	2,
	|	1,
	|	TableManagerial.Date,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE TableManagerial.GLAccount
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences < 0
	|				AND TableManagerial.GLAccountForeignCurrency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.GLAccount
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|				AND TableManagerial.GLAccountForeignCurrency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.AmountOfExchangeDifferences
	|		ELSE -TableManagerial.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount AS GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency AS Currency,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS TableManagerial
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	3 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
    |	&TextVAT,
	|   UNDEFINED,
	|	0 ,
	|	TableManagerial.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END ,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN &VATExpensesCur
	|		ELSE 0
	|	END,
	|	&VATExpenses,
	|	&VAT 
	|FROM
	|	TemporaryTableForCalculationOfReserves AS TableManagerial
	|WHERE &VATExpenses <> 0
	|";

	//elmi start
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATExpenses", VATExpenses);
	Query.SetParameter("VATExpensesCur", VATExpensesCur);
	//elmi end

	
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure // GenerateTableManagerial()

////////////////////////////////////////////////////////////////////////////////
// Services

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount)
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableServiceSupplies.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableServiceSupplies[n];
		
		// Generate postings.
		If RowTableInventory.Amount > 0 Then
			RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
			FillPropertyValues(RowTableManagerial, RowTableInventory);
		EndIf;
		
		// If this is a production, then assign WIP received costs to products cost.
		If RowTableInventory.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then
				
			// Service receipt to WIP.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
				
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
			TableRowReceipt.StructuralUnitCorr = Undefined;
			TableRowReceipt.CorrGLAccount = Undefined;
			TableRowReceipt.ProductsAndServicesCorr = Undefined;
			TableRowReceipt.CharacteristicCorr = Undefined;
			TableRowReceipt.BatchCorr = Undefined;
			TableRowReceipt.SpecificationCorr = Undefined;
			TableRowReceipt.CustomerCorrOrder  = Undefined;
			TableRowReceipt.FixedCost = True;
			
			// Costs writeoff.
			// Generate postings.
			If RowTableInventory.Amount > 0 Then
				RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerial, RowTableInventory);
				RowTableManagerial.AccountCr = RowTableManagerial.AccountDr;
				RowTableManagerial.CurrencyCr = Undefined;
				RowTableManagerial.AmountCurCr = 0;
				RowTableManagerial.AccountDr = RowTableInventory.CorrGLAccount;
			EndIf;
		
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
				
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			
			TableRowExpense.CorrOrganization = RowTableInventory.CorrOrganization;
			TableRowExpense.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
			TableRowExpense.CorrGLAccount = RowTableInventory.CorrGLAccount;
			TableRowExpense.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
			TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
			TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
			TableRowExpense.SpecificationCorr = RowTableInventory.SpecificationCorr;
			
 			TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
				
			TableRowExpense.GLAccount = RowTableInventory.GLAccount;
		    TableRowExpense.FixedCost = False;
			TableRowExpense.ProductionExpenses = True;
				
			// Assign costs to prime cost.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
				
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
						
			TableRowReceipt.Company = RowTableInventory.CorrOrganization;
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
			
			TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
			
			TableRowReceipt.CorrOrganization = RowTableInventory.Company;
			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
			
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
		    TableRowReceipt.FixedCost = False;
			
			ServicesAmount = ServicesAmount + RowTableInventory.Amount;
				
		Else
			
			// Assign costs to prime cost.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
				
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
			
			TableRowReceipt.Company = RowTableInventory.CorrOrganization;
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
			TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
			
			TableRowReceipt.StructuralUnitCorr = Undefined;
			TableRowReceipt.CorrGLAccount = Undefined;
			TableRowReceipt.ProductsAndServicesCorr = Undefined;
			TableRowReceipt.CharacteristicCorr = Undefined;
			TableRowReceipt.BatchCorr = Undefined;
			TableRowReceipt.SpecificationCorr = Undefined;
		    TableRowReceipt.CustomerCorrOrder  = Undefined;
		    TableRowReceipt.FixedCost = True;
			
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			
			ServicesAmount = ServicesAmount + RowTableInventory.Amount;
			
		EndIf;
		
	EndDo;
	
EndProcedure // GenerateTableInventoryInventory()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount) Export

	//elmi start
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATExpenses ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATExpensesCur 
	|FROM
	|	TemporaryTableForCalculationOfReserves AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATExpenses = 0;
	VATExpensesCur = 0;
	
	While Selection.Next() Do  
		  VATExpenses    = Selection.VATExpenses;
	      VATExpensesCur = Selection.VATExpensesCur;
	EndDo;
	//elmi end
	
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	0 AS LineNumber,
	|	SubcontractorReport.Date AS Period,
	|	SubcontractorReport.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	&Company AS CorrOrganization,
	|	SubcontractorReport.StructuralUnit AS StructuralUnit,
	|	SubcontractorReport.StructuralUnit AS StructuralUnitCorr,
	|	SubcontractorReport.Expense.ExpensesGLAccount AS GLAccount,
	|	CASE
	|		WHEN SubcontractorReport.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN SubcontractorReport.ProductsAndServices.InventoryGLAccount
	|		ELSE SubcontractorReport.ProductsAndServices.ExpensesGLAccount
	|	END AS CorrGLAccount,
	|	VALUE(Catalog.ProductsAndServices.EmptyRef) AS ProductsAndServices,
	|	SubcontractorReport.ProductsAndServices AS ProductsAndServicesCorr,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReport.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReport.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS BatchCorr,
	|	VALUE(Catalog.Specifications.EmptyRef) AS Specification,
	|	SubcontractorReport.Specification AS SpecificationCorr,
	|	SubcontractorReport.CustomerOrder AS CustomerOrder,
	|	SubcontractorReport.CustomerOrder AS CustomerCorrOrder,
	|	0 AS Quantity,
	|	CAST(CASE
	|			WHEN SubcontractorReport.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReport.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)   - &VATExpenses  //elmi
	|			ELSE SubcontractorReport.Total * SubcontractorReport.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * SubcontractorReport.Multiplicity) - &VATExpenses  //elmi
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SubcontractorReport.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReport.Total * RegCurrencyRates.ExchangeRate * SubcontractorReport.Ref.Multiplicity / (SubcontractorReport.Ref.ExchangeRate * RegCurrencyRates.Multiplicity) - &VATExpensesCur  //elmi
	|			ELSE SubcontractorReport.Total - &VATExpensesCur  //elmi
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CASE
	|		WHEN SubcontractorReport.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN SubcontractorReport.Expense.ExpensesGLAccount
	|		ELSE SubcontractorReport.ProductsAndServices.InventoryGLAccount
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	SubcontractorReport.Counterparty.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN SubcontractorReport.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN SubcontractorReport.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN SubcontractorReport.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN CAST(CASE
	|						WHEN SubcontractorReport.DocumentCurrency = ConstantNationalCurrency.Value
	|							THEN SubcontractorReport.Total * RegCurrencyRates.ExchangeRate * SubcontractorReport.Ref.Multiplicity / (SubcontractorReport.Ref.ExchangeRate * RegCurrencyRates.Multiplicity) - &VATExpensesCur  //elmi
	|						ELSE SubcontractorReport.Total - &VATExpensesCur  //elmi
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&ReflectionCostsOnProcessing AS Content,
	|	&ReflectionCostsOnProcessing AS ContentOfAccountingRecord
	|FROM
	|	Document.SubcontractorReport AS SubcontractorReport
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrencyRates
	|		ON (TRUE),
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SubcontractorReport.Ref = &Ref
	|	AND SubcontractorReport.Total > 0";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("ReflectionCostsOnProcessing", NStr("en = 'Reflection of the processing costs'"));
    //elmi start
	Query.SetParameter("VATExpenses", VATExpenses);
	Query.SetParameter("VATExpensesCur", VATExpensesCur);
	//elmi end

	Result = Query.Execute();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableServiceSupplies", Result.Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount);
	
EndProcedure // InitializeDataByService()

////////////////////////////////////////////////////////////////////////////////
// Disposals 

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
				
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		
	EndDo;
	
EndProcedure // GenerateTableInventoryDisposals()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SubcontractorReportDisposals.LineNumber AS LineNumber,
	|	SubcontractorReportDisposals.Ref.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorReportDisposals.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN SubcontractorReportDisposals.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	SubcontractorReportDisposals.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	SubcontractorReportDisposals.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReportDisposals.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReportDisposals.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportDisposals.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN SubcontractorReportDisposals.Quantity
	|		ELSE SubcontractorReportDisposals.Quantity * SubcontractorReportDisposals.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	&ReturnWaste AS ContentOfAccountingRecord
	|FROM
	|	Document.SubcontractorReport.Disposals AS SubcontractorReportDisposals
	|WHERE
	|	SubcontractorReportDisposals.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportDisposals.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorReportDisposals.Ref.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorReportDisposals.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN SubcontractorReportDisposals.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SubcontractorReportDisposals.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReportDisposals.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReportDisposals.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportDisposals.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN SubcontractorReportDisposals.Quantity
	|		ELSE SubcontractorReportDisposals.Quantity * SubcontractorReportDisposals.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SubcontractorReport.Disposals AS SubcontractorReportDisposals
	|WHERE
	|	SubcontractorReportDisposals.Ref = &Ref
	|	AND (NOT SubcontractorReportDisposals.Ref.StructuralUnit.OrderWarehouse)";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("ReturnWaste", NStr("en = 'Return waste'"));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", ResultsArray[0].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties);

	// Expand table for inventory.
	ResultsSelection = ResultsArray[1].Select();
	While ResultsSelection.Next() Do
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
	EndDo;

EndProcedure // InitializeDataByDisposals()

////////////////////////////////////////////////////////////////////////////////
// INVENTORY

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
						
		If QuantityRequiredAvailableBalance > 0 Then
								
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			
			// Receipt.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
								
				TableRowReceipt.Company = RowTableInventory.CorrOrganization;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.CorrOrganization = RowTableInventory.Company;
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
 						
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure // GenerateInventoryTable()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProcesserReportInventory.LineNumber AS LineNumber,
	|	ProcesserReportInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS CorrOrganization,
	|	ProcesserReportInventory.Ref.Counterparty AS StructuralUnit,
	|	ProcesserReportInventory.Ref.StructuralUnit AS StructuralUnitCorr,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN ProcesserReportInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	ProcesserReportInventory.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	CASE
	|		WHEN ProcesserReportInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN ProcesserReportInventory.Ref.ProductsAndServices.InventoryGLAccount
	|		ELSE ProcesserReportInventory.Ref.ProductsAndServices.ExpensesGLAccount
	|	END AS CorrGLAccount,
	|	ProcesserReportInventory.ProductsAndServices AS ProductsAndServices,
	|	ProcesserReportInventory.Ref.ProductsAndServices AS ProductsAndServicesCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProcesserReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProcesserReportInventory.Ref.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProcesserReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProcesserReportInventory.Ref.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS BatchCorr,
	|	ProcesserReportInventory.Specification AS Specification,
	|	ProcesserReportInventory.Ref.Specification AS SpecificationCorr,
	|	ProcesserReportInventory.Ref.CustomerOrder AS CustomerOrder,
	|	ProcesserReportInventory.Ref.CustomerOrder AS CustomerCorrOrder,
	|	ProcesserReportInventory.Ref.BasisDocument AS TransmissionOrder,
	|	ProcesserReportInventory.Ref.Counterparty AS Counterparty,
	|	ProcesserReportInventory.Ref.Contract AS Contract,
	|	CASE
	|		WHEN VALUETYPE(ProcesserReportInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ProcesserReportInventory.Quantity
	|		ELSE ProcesserReportInventory.Quantity * ProcesserReportInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(CASE
	|			WHEN ProcesserReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcesserReportInventory.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ProcesserReportInventory.Total * ProcesserReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcesserReportInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	//elmi start
	|	CAST(CASE 
	|            WHEN ProcesserReportInventory.Ref.IncludeVATInPrice
	|			 THEN 0   
	|			 ELSE CASE
	|                 WHEN ProcesserReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				  THEN ProcesserReportInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			      ELSE ProcesserReportInventory.VATAmount * ProcesserReportInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ProcesserReportInventory.Ref.Multiplicity)
	|            END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	//elmi end
	|	ProcesserReportInventory.Total AS SettlementsAmountTransferred,
	|	&InventoryDistribution AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SubcontractorReport.Inventory AS ProcesserReportInventory
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrencyRates
	|		ON (TRUE),
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	ProcesserReportInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	TableInventory.CorrGLAccount AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.CustomerOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventoryTransferred.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryTransferred.Period AS Period,
	|	TableInventoryTransferred.Company AS Company,
	|	TableInventoryTransferred.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryTransferred.Characteristic AS Characteristic,
	|	TableInventoryTransferred.Batch AS Batch,
	|	TableInventoryTransferred.Counterparty AS Counterparty,
	|	TableInventoryTransferred.Contract AS Contract,
	|	CASE
	|		WHEN TableInventoryTransferred.TransmissionOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableInventoryTransferred.TransmissionOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	VALUE(Enum.ProductsReceiptTransferTypes.TransferToProcessing) AS ReceptionTransmissionType,
	|	SUM(TableInventoryTransferred.Quantity) AS Quantity,
	//|	SUM(TableInventoryTransferred.SettlementsAmountTransferred) AS SettlementsAmount
	|	SUM(TableInventoryTransferred.SettlementsAmountTransferred - TableInventoryTransferred.VATAmount) AS SettlementsAmount     //elmi
	|FROM
	|	TemporaryTableInventory AS TableInventoryTransferred
	|
	|GROUP BY
	|	TableInventoryTransferred.Period,
	|	TableInventoryTransferred.Company,
	|	TableInventoryTransferred.ProductsAndServices,
	|	TableInventoryTransferred.Characteristic,
	|	TableInventoryTransferred.Batch,
	|	TableInventoryTransferred.Counterparty,
	|	TableInventoryTransferred.Contract,
	|	CASE
	|		WHEN TableInventoryTransferred.TransmissionOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableInventoryTransferred.TransmissionOrder
	|		ELSE UNDEFINED
	|	END";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory distribution'"));
		
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount);
        	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryTransferred", ResultsArray[2].Unload());
	
EndProcedure // InitializeDataByInventory()

////////////////////////////////////////////////////////////////////////////////
// Products

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForWarehouses(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(ProcesserReportProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ProcesserReportProduction.Period AS Period,
	|	ProcesserReportProduction.Company AS Company,
	|	ProcesserReportProduction.ProductsAndServices AS ProductsAndServices,
	|	ProcesserReportProduction.Characteristic AS Characteristic,
	|	ProcesserReportProduction.Batch AS Batch,
	|	ProcesserReportProduction.StructuralUnit AS StructuralUnit,
	|	SUM(ProcesserReportProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS ProcesserReportProduction
	|WHERE
	|	ProcesserReportProduction.OrderWarehouse
	|	AND ProcesserReportProduction.Period >= ProcesserReportProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	ProcesserReportProduction.ProductsAndServices,
	|	ProcesserReportProduction.Characteristic,
	|	ProcesserReportProduction.Batch,
	|	ProcesserReportProduction.Period,
	|	ProcesserReportProduction.Company,
	|	ProcesserReportProduction.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(SubcontractorReportDisposals.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	SubcontractorReportDisposals.Ref.Date,
	|	SubcontractorReportDisposals.Ref.Company,
	|	SubcontractorReportDisposals.ProductsAndServices,
	|	SubcontractorReportDisposals.Characteristic,
	|	SubcontractorReportDisposals.Batch,
	|	SubcontractorReportDisposals.Ref.StructuralUnit,
	|	SUM(CASE
	|			WHEN VALUETYPE(SubcontractorReportDisposals.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN SubcontractorReportDisposals.Quantity
	|			ELSE SubcontractorReportDisposals.Quantity * SubcontractorReportDisposals.MeasurementUnit.Factor
	|		END)
	|FROM
	|	Document.SubcontractorReport.Disposals AS SubcontractorReportDisposals
	|WHERE
	|	SubcontractorReportDisposals.Ref.StructuralUnit.OrderWarehouse
	|	AND SubcontractorReportDisposals.Ref = &Ref
	|	AND SubcontractorReportDisposals.Ref.Date >= &UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	SubcontractorReportDisposals.Ref,
	|	SubcontractorReportDisposals.ProductsAndServices,
	|	SubcontractorReportDisposals.Characteristic,
	|	SubcontractorReportDisposals.Batch,
	|	SubcontractorReportDisposals.Ref.Date,
	|	SubcontractorReportDisposals.Ref.Company,
	|	SubcontractorReportDisposals.Ref.StructuralUnit";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	
	// Temporarily: change motions by the order warehouse.
	Query.SetParameter("UpdateDateToRelease_1_2_1", Constants.UpdateDateToRelease_1_2_1.Get());
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryForWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProducts(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount)
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If customer order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		
		// If production order is filled in and there is no
		// customer, check whether there are located customer orders in the order to vendor.
		If Not ValueIsFilled(RowTableInventoryProducts.CustomerOrder) 
		   AND ValueIsFilled(RowTableInventoryProducts.PurchaseOrder) Then
		 
			// Then there is a receipt either to available balance, or to purchase orders placed in order.
			OutputCost = AssemblyAmount;
			OutputQuantity = RowTableInventoryProducts.Quantity;
			
			OutputAmountToReserve = StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.Total("Quantity");

			If OutputQuantity = OutputAmountToReserve Then
				OutputCostInReserve = OutputCost;
			Else
				OutputCostInReserve = Round(OutputCost * OutputAmountToReserve / OutputQuantity, 2, 1);
			EndIf;

			If OutputAmountToReserve > 0 Then	

				TotalToWriteOffByOrder = 0;
					
				For IndexOf = 0 to StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.Count() - 1 Do

					StringTablePlacedOrders = StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement[IndexOf];
						
					AmountToBeWrittenOffByOrder = Round(OutputCostInReserve * StringTablePlacedOrders.Quantity / OutputAmountToReserve, 2, 1);
					TotalToWriteOffByOrder = TotalToWriteOffByOrder + AmountToBeWrittenOffByOrder;
						
					If IndexOf = StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.Count() - 1 Then // It is the last string, it is required to correct amount.
						AmountToBeWrittenOffByOrder = AmountToBeWrittenOffByOrder + (OutputCostInReserve - TotalToWriteOffByOrder);
					EndIf;

					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
					
					TableRowExpense.RecordType = AccumulationRecordType.Expense;
					
					TableRowExpense.CorrOrganization = RowTableInventoryProducts.Company;
					TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;
 									
					TableRowExpense.CustomerCorrOrder = StringTablePlacedOrders.CustomerOrder;
					TableRowExpense.Quantity = StringTablePlacedOrders.Quantity;
					TableRowExpense.Amount = AmountToBeWrittenOffByOrder;
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
									
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
									
					TableRowReceipt.CustomerOrder = StringTablePlacedOrders.CustomerOrder;
									
					TableRowExpense.CorrOrganization = RowTableInventoryProducts.Company;
					TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;

					TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.CustomerOrder;
					TableRowReceipt.Quantity = StringTablePlacedOrders.Quantity;
					TableRowReceipt.Amount = AmountToBeWrittenOffByOrder;
					
				EndDo;
			
			EndIf;			

		EndIf;

	EndDo;

EndProcedure // GenerateTableInventoryProducts()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableOrdersPlacement(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableProduction.Company AS Company,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.SupplySource <> Undefined
	|
	|GROUP BY
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.SupplySource";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.OrdersPlacement");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	CASE
	|		WHEN TableProduction.Quantity > ISNULL(OrdersPlacementBalances.Quantity, 0)
	|			THEN ISNULL(OrdersPlacementBalances.Quantity, 0)
	|		WHEN TableProduction.Quantity <= ISNULL(OrdersPlacementBalances.Quantity, 0)
	|			THEN TableProduction.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN (SELECT
	|			OrdersPlacementBalances.Company AS Company,
	|			OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic AS Characteristic,
	|			OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|			OrdersPlacementBalances.SupplySource AS SupplySource,
	|			SUM(OrdersPlacementBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				OrdersPlacementBalances.Company AS Company,
	|				OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|				OrdersPlacementBalances.Characteristic AS Characteristic,
	|				OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|				OrdersPlacementBalances.SupplySource AS SupplySource,
	|				OrdersPlacementBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.OrdersPlacement.Balance(
	|						&ControlTime,
	|						(Company, ProductsAndServices, Characteristic, SupplySource) In
	|							(SELECT
	|								TableProduction.Company AS Company,
	|								TableProduction.ProductsAndServices AS ProductsAndServices,
	|								TableProduction.Characteristic AS Characteristic,
	|								TableProduction.SupplySource AS SupplySource
	|							FROM
	|								TemporaryTableProduction AS TableProduction
	|							WHERE
	|								TableProduction.SupplySource <> UNDEFINED)) AS OrdersPlacementBalances
			
	|			UNION ALL
			
	|			SELECT
	|				DocumentRegisterRecordsOrdersPlacement.Company,
	|				DocumentRegisterRecordsOrdersPlacement.ProductsAndServices,
	|				DocumentRegisterRecordsOrdersPlacement.Characteristic,
	|				DocumentRegisterRecordsOrdersPlacement.CustomerOrder,
	|				DocumentRegisterRecordsOrdersPlacement.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsOrdersPlacement.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.OrdersPlacement AS DocumentRegisterRecordsOrdersPlacement
	|			WHERE
	|				DocumentRegisterRecordsOrdersPlacement.Recorder = &Ref
	|				AND DocumentRegisterRecordsOrdersPlacement.Period <= &ControlPeriod) AS OrdersPlacementBalances
		
	|		GROUP BY
	|			OrdersPlacementBalances.Company,
	|			OrdersPlacementBalances.ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic,
	|			OrdersPlacementBalances.CustomerOrder,
	|			OrdersPlacementBalances.SupplySource) AS OrdersPlacementBalances
	|		ON TableProduction.Company = OrdersPlacementBalances.Company
	|			AND TableProduction.ProductsAndServices = OrdersPlacementBalances.ProductsAndServices
	|			AND TableProduction.Characteristic = OrdersPlacementBalances.Characteristic
	|			AND TableProduction.SupplySource = OrdersPlacementBalances.SupplySource
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|	AND OrdersPlacementBalances.CustomerOrder IS Not NULL ";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOrdersPlacement", QueryResult.Unload());
	
EndProcedure // GenerateTableOrdersPlacement()

////////////////////////////////////////////////////////////////////////////////
// ACCOUNTS PAYABLE

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor", NStr("en='Appearance of vendor liabilities'"));
	Query.SetParameter("AdvanceCredit", NStr("en='Setoff of advance payment'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CAST(&AppearenceOfLiabilityToVendor AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableForCalculationOfReserves AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.VendorAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS String(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of settlements with suppliers.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = SmallBusinessServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference'"));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	UNDEFINED AS CustomerOrder,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS Amount
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	//|	DocumentTable.Amount AS AmountExpense
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountExpense    //elmi
	|FROM
	|	TemporaryTableForCalculationOfReserves AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained IN TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountExpense;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountExpense = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained IN TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessActivity AS BusinessActivity,
	|	Table.AmountExpense AS AmountExpense
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure // GenerateTableIncomeAndExpensesRetained()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesUndistributed", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesUndistributed()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessActivity,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessActivity,
	|	Table.Item,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpensesCashMethod() 

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationAccountsPayable(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SubcontractorReportCosts.Date AS Period,
	|	1 AS LineNumber,
	|	&Company AS Company,
	|	SubcontractorReportCosts.Counterparty AS Counterparty,
	|	SubcontractorReportCosts.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SubcontractorReportCosts.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	SubcontractorReportCosts.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorReportCosts.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	SubcontractorReportCosts.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	SubcontractorReportCosts.Contract AS Contract,
	|	SubcontractorReportCosts.Expense.ExpensesGLAccount AS GLAccount,
	|	SubcontractorReportCosts.Expense.BusinessActivity AS BusinessActivity,
	|	SubcontractorReportCosts.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS Document,
	|	SubcontractorReportCosts.BasisDocument AS Order,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN SubcontractorReportCosts.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE SubcontractorReportCosts.VATAmount * SubcontractorReportCosts.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportCosts.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE SubcontractorReportCosts.Total * SubcontractorReportCosts.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN SubcontractorReportCosts.VATAmount * RegCurrencyRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity / (SubcontractorReportCosts.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE SubcontractorReportCosts.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportCosts.Total * RegCurrencyRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity / (SubcontractorReportCosts.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE SubcontractorReportCosts.Total
	|		END AS NUMBER(15, 2)) AS AmountCur
	|INTO TemporaryTableForCalculationOfReserves
	|FROM
	|	Document.SubcontractorReport AS SubcontractorReportCosts
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.NationalCurrency AS ConstantNationalCurrency)) AS RegCurrencyRates
	|		ON (TRUE),
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SubcontractorReportCosts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Ref.BasisDocument AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivitySales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END AS DocumentDate,
	|	SUM(CAST(DocumentTable.SettlementsAmount * DocumentTable.Ref.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SubcontractorReport.Prepayment AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.BasisDocument,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN Not DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = Type(Document.Netting)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.ExecuteBatch();
	
	GenerateTableAccountsPayable(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
EndProcedure // InitializeDataAccountsPayable()

////////////////////////////////////////////////////////////////////////////////
// DATA INITIALIZATION

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSubcontractorReport, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	0 AS LineNumber,
	|	SubcontractorReport.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.Companies.EmptyRef) AS CorrOrganization,
	|	SubcontractorReport.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	ISNULL(SubcontractorReport.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	ISNULL(VALUE(Catalog.StructuralUnits.EmptyRef), VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnitCorr,
	|	SubcontractorReport.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN SubcontractorReport.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	SubcontractorReport.Specification AS Specification,
	|	VALUE(Catalog.Specifications.EmptyRef) AS SpecificationCorr,
	|	CASE
	|		WHEN SubcontractorReport.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN SubcontractorReport.ProductsAndServices.InventoryGLAccount
	|		ELSE SubcontractorReport.ProductsAndServices.ExpensesGLAccount
	|	END AS GLAccount,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS CorrGLAccount,
	|	SubcontractorReport.ProductsAndServices AS ProductsAndServices,
	|	VALUE(Catalog.ProductsAndServices.EmptyRef) AS ProductsAndServicesCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReport.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReport.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS BatchCorr,
	|	SubcontractorReport.CustomerOrder AS CustomerOrder,
	|	SubcontractorReport.BasisDocument AS PurchaseOrder,
	|	CASE
	|		WHEN SubcontractorReport.BasisDocument = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE SubcontractorReport.BasisDocument
	|	END AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReport.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN SubcontractorReport.Quantity
	|		ELSE SubcontractorReport.Quantity * SubcontractorReport.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerCorrOrder,
	|	&InventoryAssembly AS ContentOfAccountingRecord,
	|	&UpdateDateToRelease_1_2_1 AS UpdateDateToRelease_1_2_1
	|INTO TemporaryTableProduction
	|FROM
	|	Document.SubcontractorReport AS SubcontractorReport
	|WHERE
	|	SubcontractorReport.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	UNDEFINED AS PlanningPeriod,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.PurchaseOrder AS PurchaseOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableProduction AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.CustomerOrder,
	|	TableInventory.PurchaseOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.Period < TableInventoryInWarehouses.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell,
	|	SUM(TableInventoryInWarehouses.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableInventoryInWarehouses
	|WHERE
	|	(NOT TableInventoryInWarehouses.OrderWarehouse)
	|	AND TableInventoryInWarehouses.Period >= TableInventoryInWarehouses.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.ProductsAndServices,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.ProductsAndServices AS ProductsAndServices,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.PurchaseOrder AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.ProductsAndServices,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProductRelease.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProductRelease.Period AS Period,
	|	TableProductRelease.Company AS Company,
	|	TableProductRelease.StructuralUnit AS StructuralUnit,
	|	TableProductRelease.ProductsAndServices AS ProductsAndServices,
	|	TableProductRelease.Characteristic AS Characteristic,
	|	TableProductRelease.Batch AS Batch,
	|	TableProductRelease.CustomerOrder AS CustomerOrder,
	|	TableProductRelease.Specification AS Specification,
	|	SUM(TableProductRelease.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProductRelease
	|
	|GROUP BY
	|	TableProductRelease.Period,
	|	TableProductRelease.Company,
	|	TableProductRelease.StructuralUnit,
	|	TableProductRelease.ProductsAndServices,
	|	TableProductRelease.Characteristic,
	|	TableProductRelease.Batch,
	|	TableProductRelease.CustomerOrder,
	|	TableProductRelease.Specification";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells",  StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	
	// Temporarily: change motions by the order warehouse.
	Query.SetParameter("UpdateDateToRelease_1_2_1", Constants.UpdateDateToRelease_1_2_1.Get());
		
	Query.SetParameter("InventoryAssembly", NStr("en = 'Production'"));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", ResultsArray[4].Unload());
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableOrdersPlacement(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount);	
	
	// Accounts payable.
	DataInitializationAccountsPayable(DocumentRefSubcontractorReport, StructureAdditionalProperties);  //elmi
	
	
	// Services.
	ServicesAmount = 0;
	DataInitializationByService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount);	
	
	// Products.
	AssemblyAmount = AssemblyAmount + ServicesAmount;
	GenerateTableInventoryProducts(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	// Inventory for receipt.
	GenerateTableInventoryForWarehouses(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	// Accounts payable.
	//DataInitializationAccountsPayable(DocumentRefSubcontractorReport, StructureAdditionalProperties);    //elmi
	
	GenerateTableManagerial(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSubcontractorReport, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange", "MovementsInventoryPassedChange", "RegisterRecordsPurchaseOrdersChange", "RegisterRecordsOrdersPlacementChange", contain records, it is required to control goods implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryTransferredChange 
	 OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
	 OR StructureTemporaryTables.RegisterRecordsOrdersPlacementChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, ProductsAndServices, Characteristic, Batch, Cell) In
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.ProductsAndServices = InventoryInWarehousesOfBalance.ProductsAndServices
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.GLAccount) AS GLAccountPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.CustomerOrder) AS CustomerOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|						RegisterRecordsInventoryChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.CustomerOrder AS CustomerOrder
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.ProductsAndServices = InventoryBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.CustomerOrder = InventoryBalances.CustomerOrder
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryTransferredChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType) AS ReceptionTransmissionTypePresentation,
		|	REFPRESENTATION(InventoryTransferredBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.QuantityChange, 0) + ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS BalanceInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.QuantityBalance, 0) AS QuantityBalanceInventoryTransferred,
		|	ISNULL(RegisterRecordsInventoryTransferredChange.SettlementsAmountChange, 0) + ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryTransferred,
		|	ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryTransferred
		|FROM
		|	RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange
		|		LEFT JOIN AccumulationRegister.InventoryTransferred.Balance(
		|				&ControlTime,
		|				(Company, ProductsAndServices, Characteristic, Batch, Counterparty, Contract, Order, ReceptionTransmissionType) In
		|					(SELECT
		|						RegisterRecordsInventoryTransferredChange.Company AS Company,
		|						RegisterRecordsInventoryTransferredChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryTransferredChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryTransferredChange.Batch AS Batch,
		|						RegisterRecordsInventoryTransferredChange.Counterparty AS Counterparty,
		|						RegisterRecordsInventoryTransferredChange.Contract AS Contract,
		|						RegisterRecordsInventoryTransferredChange.Order AS Order,
		|						RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType AS ReceptionTransmissionType
		|					FROM
		|						RegisterRecordsInventoryTransferredChange AS RegisterRecordsInventoryTransferredChange)) AS InventoryTransferredBalances
		|		ON RegisterRecordsInventoryTransferredChange.Company = InventoryTransferredBalances.Company
		|			AND RegisterRecordsInventoryTransferredChange.ProductsAndServices = InventoryTransferredBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryTransferredChange.Characteristic = InventoryTransferredBalances.Characteristic
		|			AND RegisterRecordsInventoryTransferredChange.Batch = InventoryTransferredBalances.Batch
		|			AND RegisterRecordsInventoryTransferredChange.Counterparty = InventoryTransferredBalances.Counterparty
		|			AND RegisterRecordsInventoryTransferredChange.Contract = InventoryTransferredBalances.Contract
		|			AND RegisterRecordsInventoryTransferredChange.Order = InventoryTransferredBalances.Order
		|			AND RegisterRecordsInventoryTransferredChange.ReceptionTransmissionType = InventoryTransferredBalances.ReceptionTransmissionType
		|WHERE
		|	(ISNULL(InventoryTransferredBalances.QuantityBalance, 0) < 0
		|			OR ISNULL(InventoryTransferredBalances.SettlementsAmountBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.PurchaseOrder) AS PurchaseOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(PurchaseOrdersBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		LEFT JOIN AccumulationRegister.PurchaseOrders.Balance(
		|				&ControlTime,
		|				(Company, PurchaseOrder, ProductsAndServices, Characteristic) In
		|					(SELECT
		|						RegisterRecordsPurchaseOrdersChange.Company AS Company,
		|						RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrder,
		|						RegisterRecordsPurchaseOrdersChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsPurchaseOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange)) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.ProductsAndServices = PurchaseOrdersBalances.ProductsAndServices
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsOrdersPlacementChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.CustomerOrder) AS CustomerOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(OrdersPlacementBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsOrdersPlacementChange.QuantityChange, 0) + ISNULL(OrdersPlacementBalances.QuantityBalance, 0) AS BalanceOrdersPlacement,
		|	ISNULL(OrdersPlacementBalances.QuantityBalance, 0) AS QuantityBalanceOrdersPlacement
		|FROM
		|	RegisterRecordsOrdersPlacementChange AS RegisterRecordsOrdersPlacementChange
		|		LEFT JOIN AccumulationRegister.OrdersPlacement.Balance(
		|				&ControlTime,
		|				(Company, CustomerOrder, ProductsAndServices, Characteristic, SupplySource) In
		|					(SELECT
		|						RegisterRecordsOrdersPlacementChange.Company AS Company,
		|						RegisterRecordsOrdersPlacementChange.CustomerOrder AS CustomerOrder,
		|						RegisterRecordsOrdersPlacementChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsOrdersPlacementChange.Characteristic AS Characteristic,
		|						RegisterRecordsOrdersPlacementChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsOrdersPlacementChange AS RegisterRecordsOrdersPlacementChange)) AS OrdersPlacementBalances
		|		ON RegisterRecordsOrdersPlacementChange.Company = OrdersPlacementBalances.Company
		|			AND RegisterRecordsOrdersPlacementChange.CustomerOrder = OrdersPlacementBalances.CustomerOrder
		|			AND RegisterRecordsOrdersPlacementChange.ProductsAndServices = OrdersPlacementBalances.ProductsAndServices
		|			AND RegisterRecordsOrdersPlacementChange.Characteristic = OrdersPlacementBalances.Characteristic
		|			AND RegisterRecordsOrdersPlacementChange.SupplySource = OrdersPlacementBalances.SupplySource
		|WHERE
		|	ISNULL(OrdersPlacementBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() 
			OR Not ResultsArray[5].IsEmpty() Then
			DocumentObjectSubcontractorReport = DocumentRefSubcontractorReport.GetObject();
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// The negative balance of transferred inventory.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryTransferredRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			SmallBusinessServer.ShowMessageAboutPostingToOrdersPlacementRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf