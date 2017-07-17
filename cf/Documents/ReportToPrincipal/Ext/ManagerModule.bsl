#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// DOCUMENT POSTING PROCEDURES

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATAmount ,
	|	Sum(TemporaryTable.BrokerageVATAmount) AS BrokerageVATAmount, 
	|	Sum(TemporaryTable.VATAmountCur) AS VATAmountCur ,
	|	Sum(TemporaryTable.BrokerageVATAmountCur) AS BrokerageVATAmountCur,
	|	Sum(TemporaryTable.CostVAT) AS CostVAT, 
	|	Sum(TemporaryTable.CostVATCur) AS CostVATCur
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	VATAmount = 0;
	VATAmountCur = 0;
    BrokerageVATAmount=0;
	BrokerageVATAmountCur = 0;
	CostVAT = 0;
	CostVATCur = 0;
	
	While Selection.Next() Do  
		VATAmount = Selection.VATAmount;
		VATAmountCur = Selection.VATAmountCur;
		BrokerageVATAmount = Selection.BrokerageVATAmount;
		BrokerageVATAmountCur = Selection.BrokerageVATAmountCur;
		CostVAT = Selection.CostVAT;
		CostVATCur = Selection.CostVATCur;
	EndDo;
    //) elmi

	
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.GLAccountVendorSettlements AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableManagerial.KeepBackComissionFee
	//( elmi #11
	//|						THEN TableManagerial.Amount - TableManagerial.Cost + TableManagerial.BrokerageAmount
	|						THEN (TableManagerial.Amount - TableManagerial.VATAmount ) - (TableManagerial.Cost - TableManagerial.CostVAT) + (TableManagerial.BrokerageAmount -TableManagerial.BrokerageVATAmount) 
	//|					ELSE TableManagerial.Amount - TableManagerial.Cost
	|					ELSE (TableManagerial.Amount - TableManagerial.VATAmount ) - (TableManagerial.Cost - TableManagerial.CostVAT)             
	//) elmi
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableManagerial.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableManagerial.KeepBackComissionFee
	//( elmi #11
	//|			THEN TableManagerial.Amount - TableManagerial.Cost + TableManagerial.BrokerageAmount  
	|   		THEN (TableManagerial.Amount - TableManagerial.VATAmount ) - (TableManagerial.Cost - TableManagerial.CostVAT) + (TableManagerial.BrokerageAmount -TableManagerial.BrokerageVATAmount) 
	//|		ELSE TableManagerial.Amount - TableManagerial.Cost
	|		ELSE (TableManagerial.Amount - TableManagerial.VATAmount ) - (TableManagerial.Cost - TableManagerial.CostVAT)     
	//) elmi
	|	END AS Amount,
	|	&IncomeReflection AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	TableManagerial.BrokerageAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableManagerial.LineNumber,
	|	TableManagerial.Period,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableManagerial.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableManagerial.KeepBackComissionFee
	//( elmi #11
	//|						THEN TableManagerial.Cost - TableManagerial.BrokerageAmount
	|						THEN (TableManagerial.Cost - TableManagerial.CostVAT ) -  (TableManagerial.BrokerageAmount - TableManagerial.BrokerageVATAmount)   
	//|					ELSE TableManagerial.Cost
	|					ELSE TableManagerial.Cost - TableManagerial.CostVAT     
	//) elmi
	|				END
	|		ELSE 0
	|	END,
	|	TableManagerial.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	//( elmi #11
	//|			THEN TableManagerial.CostPriceCur - TableManagerial.BrokerageAmountCur
	|			THEN (TableManagerial.CostPriceCur - TableManagerial.CostVATCur ) -  (TableManagerial.BrokerageAmountCur - TableManagerial.BrokerageVATAmountCur)   
	//|		ELSE TableManagerial.CostPriceCur
	|		ELSE TableManagerial.CostPriceCur  - TableManagerial.CostVATCur
	|	END,
	|	CASE
	|		WHEN TableManagerial.KeepBackComissionFee
    //|			THEN TableManagerial.Cost - TableManagerial.BrokerageAmount
	|			THEN (TableManagerial.Cost - TableManagerial.CostVAT ) -  (TableManagerial.BrokerageAmount - TableManagerial.BrokerageVATAmount) 
	//|		ELSE TableManagerial.Cost
	|		ELSE TableManagerial.Cost - TableManagerial.CostVAT     
	//) elmi
	|	END,
	|	&ComitentDebt
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment
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
	|	4,
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
	//( elmi #11
	|UNION ALL
    | 
	|SELECT TOP 1
	|	5 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableManagerial.GLAccountVendorSettlements AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableManagerial.KeepBackComissionFee
	|						THEN &VATAmount - &CostVAT  + &BrokerageVATAmount
	|					ELSE &VATAmount - &CostVAT
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&TextVAT,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableManagerial.KeepBackComissionFee
	|   		THEN &VATAmount - &CostVAT  + &BrokerageVATAmount
	|		ELSE &VATAmount - &CostVAT
	|	END AS Amount,
	|	&VAT Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	&BrokerageVATAmount > 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	6 AS Ordering,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Period AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&TextVAT,
	|	UNDEFINED,
	|	0,
	|	TableManagerial.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN TableManagerial.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END, 
	|	CASE
	|		WHEN TableManagerial.GLAccountVendorSettlements.Currency
	|			THEN &CostVATCur  -  &BrokerageVATAmountCur
	|		ELSE &CostVATCur
	|	END ,
	|	CASE
	|		WHEN TableManagerial.KeepBackComissionFee
	|   		THEN &CostVAT  -  &BrokerageVATAmount
	|		ELSE &CostVAT
	|	END AS Amount,
	|	&VAT Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	 &CostVAT  -  &BrokerageVATAmount >0
	//) elmi
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	Query.SetParameter("SetOffAdvancePayment", NStr("en='Prepayment setoff';ru='Зачет предоплаты'"));
	Query.SetParameter("IncomeReflection", NStr("en='Revenue from sale';ru='Выручка от продажи'"));
	Query.SetParameter("ComitentDebt", NStr("en='Debt to principal';ru='Задолженность комитенту'"));
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	//( elmi #11
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);       
	Query.SetParameter("VATAmount", VATAmount);
	Query.SetParameter("VATAmountCur", VATAmountCur);
	Query.SetParameter("BrokerageVATAmount", BrokerageVATAmount);
	Query.SetParameter("BrokerageVATAmountCur", BrokerageVATAmountCur);
	Query.SetParameter("CostVATCur", CostVATCur);
	Query.SetParameter("CostVAT", CostVAT);
    //) elmi

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure // GenerateTableManagerial()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryReceived(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableInventoryReceived.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryReceived.Period AS Period,
	|	TableInventoryReceived.Company AS Company,
	|	TableInventoryReceived.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryReceived.Characteristic AS Characteristic,
	|	TableInventoryReceived.Batch AS Batch,
	|	TableInventoryReceived.Counterparty AS Counterparty,
	|	TableInventoryReceived.Contract AS Contract,
	|	CASE
	|		WHEN TableInventoryReceived.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableInventoryReceived.PurchaseOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableInventoryReceived.GLAccount AS GLAccount,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReceiptFromPrincipal) AS ReceptionTransmissionType,
	|	SUM(TableInventoryReceived.Quantity) AS Quantity,
	//( elmi #11
	//|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed) AS SettlementsAmount,
	|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.ReceiptVATAmount) AS SettlementsAmount,           
	|	0 AS SalesAmount,
	//|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed) AS Amount,
	|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.ReceiptVATAmount) AS Amount,                     
	|	ConstantNationalCurrency.Value AS Currency,
	//|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.ReceiptVATAmount) AS AmountCur,
	|	SUM(TableInventoryReceived.SettlementsAmountTakenPassed - TableInventoryReceived.ReceiptVATAmount) AS AmountCur,                  
	//) elmi
	|	&InventoryReception AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableInventoryReceived,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|
	|GROUP BY
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	TableInventoryReceived.Counterparty,
	|	TableInventoryReceived.Contract,
	|	CASE
	|		WHEN TableInventoryReceived.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableInventoryReceived.PurchaseOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableInventoryReceived.GLAccount,
	|	ConstantNationalCurrency.Value
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableInventoryReceived.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	UNDEFINED,
	|	UNDEFINED,
	|	CASE
	|		WHEN TableInventoryReceived.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN TableInventoryReceived.CustomerOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableInventoryReceived.GLAccountVendorSettlements,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReportToPrincipal),
	|	SUM(TableInventoryReceived.Quantity),
	|	0,
	|	SUM(TableInventoryReceived.Amount),
	|	SUM(TableInventoryReceived.Amount),
	|	ConstantNationalCurrency.Value,
	|	SUM(TableInventoryReceived.Amount),
	|	&InventoryreceptionPostponedIncome
	|FROM
	|	TemporaryTableInventory AS TableInventoryReceived,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|
	|GROUP BY
	|	TableInventoryReceived.Period,
	|	TableInventoryReceived.Company,
	|	TableInventoryReceived.ProductsAndServices,
	|	TableInventoryReceived.Characteristic,
	|	TableInventoryReceived.Batch,
	|	TableInventoryReceived.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableInventoryReceived.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN TableInventoryReceived.CustomerOrder
	|		ELSE UNDEFINED
	|	END,
	|	ConstantNationalCurrency.Value";
	
	Query.SetParameter("InventoryReception", "");
	Query.SetParameter("InventoryreceptionPostponedIncome", NStr("en='Inventory receipt';ru='Прием запасов'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryReceived", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryReceived()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.ProductsAndServices AS ProductsAndServices,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.CustomerOrder AS CustomerOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	0 AS Quantity,
	|	0 AS Amount,
	|	0 AS VATAmount,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackComissionFee
	|				THEN TableSales.Cost - TableSales.BrokerageAmount
	|			ELSE TableSales.Cost
	|		END) AS Cost
	|FROM
	|	TemporaryTableInventory AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.ProductsAndServices,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.CustomerOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DepartmentSales,
	|	TableSales.Responsible";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MAX(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessActivitySales AS BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder AS CustomerOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableIncomeAndExpenses.KeepBackComissionFee
	//( elmi #11
	//|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost + TableIncomeAndExpenses.BrokerageAmount
	|				THEN (TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT) + (TableIncomeAndExpenses.BrokerageAmount - TableIncomeAndExpenses.BrokerageVATAmount)  
	//|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost
	|			ELSE (TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT)   
	//) elmi
	|		END) AS AmountIncome,
	|	0 AS AmountExpense,
	|	SUM(CASE
	|			WHEN TableIncomeAndExpenses.KeepBackComissionFee
	//( elmi #11
	//|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost + TableIncomeAndExpenses.BrokerageAmount
	|				THEN (TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT) + (TableIncomeAndExpenses.BrokerageAmount - TableIncomeAndExpenses.BrokerageVATAmount) 
	//|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost
	|			ELSE (TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT)        
	//) elmi
	|		END) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	(TableIncomeAndExpenses.KeepBackComissionFee
	|				AND TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost + TableIncomeAndExpenses.BrokerageAmount > 0
	|			OR Not TableIncomeAndExpenses.KeepBackComissionFee
	|				AND TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost > 0)
	|	
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.DepartmentSales,
	|	TableIncomeAndExpenses.BusinessActivitySales,
	|	TableIncomeAndExpenses.CustomerOrder,
	|	TableIncomeAndExpenses.AccountStatementSales
	|	
	|UNION ALL
	|	
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
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
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable";
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("IncomeReflection", NStr("en='Record income';ru='Отражение доходов'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor", NStr("en='Incurrence of liabilities to supplier';ru='Возникновение обязательств перед поставщикт'"));
	Query.SetParameter("AdvanceCredit", NStr("en='Prepayment setoff';ru='Зачет предоплаты'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
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
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Cost
	|		END) AS Amount,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.CostPriceCur
	|		END) AS AmountCur,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Cost
	|		END) AS AmountForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.CostPriceCur
	|		END) AS AmountCurForBalance,
	|	CAST(&AppearenceOfLiabilityToVendor AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
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
	|			THEN DocumentTable.PurchaseOrder
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
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
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
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
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
	|	TemporaryTableAccountsPayable";

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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
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
	|	DocumentTable.BusinessActivitySales AS BusinessActivity,
	|	CASE
	|		WHEN DocumentTable.KeepBackComissionFee
	//( elmi #11
	//|			THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|			THEN (DocumentTable.Cost - DocumentTable.CostVAT ) - (DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount)    
	//|		ELSE DocumentTable.Cost
	|		ELSE DocumentTable.Cost - DocumentTable.CostVAT                                          
	//) elmi
	|	END AS AmountExpense
	|FROM
	|	TemporaryTableInventory AS DocumentTable
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
Procedure GenerateTableIncomeAndExpensesUndistributed(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
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
Procedure InitializeDocumentData(DocumentRefReportToCommissioner, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ReportToPrincipalInventory.LineNumber AS LineNumber,
	|	ReportToPrincipalInventory.ConnectionKey AS ConnectionKey,
	|	ReportToPrincipalInventory.Ref AS Ref,
	|	ReportToPrincipalInventory.Ref AS Document,
	|	ReportToPrincipalInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	ReportToPrincipalInventory.Ref.Counterparty AS Counterparty,
	|	ReportToPrincipalInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	ReportToPrincipalInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	ReportToPrincipalInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	ReportToPrincipalInventory.Ref.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills,
	|	ReportToPrincipalInventory.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	ReportToPrincipalInventory.Ref.Contract AS Contract,
	|	ReportToPrincipalInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	ReportToPrincipalInventory.Ref.KeepBackComissionFee AS KeepBackComissionFee,
	|	ReportToPrincipalInventory.Ref.Department AS DepartmentSales,
	|	ReportToPrincipalInventory.Ref.Responsible AS Responsible,
	|	ReportToPrincipalInventory.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	ReportToPrincipalInventory.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS AccountStatementSales,
	|	ReportToPrincipalInventory.ProductsAndServices.InventoryGLAccount AS GLAccount,
	|	ReportToPrincipalInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ReportToPrincipalInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ReportToPrincipalInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(ReportToPrincipalInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ReportToPrincipalInventory.Quantity
	|		ELSE ReportToPrincipalInventory.Quantity * ReportToPrincipalInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	ReportToPrincipalInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ReportToPrincipalInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ReportToPrincipalInventory.VATAmount * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ReportToPrincipalInventory.VATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ReportToPrincipalInventory.VATAmount * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ReportToPrincipalInventory.Total * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ReportToPrincipalInventory.Total * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ReportToPrincipalInventory.ReceiptVATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ReportToPrincipalInventory.ReceiptVATAmount * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS CostVAT,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ReportToPrincipalInventory.ReceiptVATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ReportToPrincipalInventory.ReceiptVATAmount * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS CostVATSale,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|							THEN ReportToPrincipalInventory.AmountReceipt * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|						ELSE (ReportToPrincipalInventory.AmountReceipt + ReportToPrincipalInventory.ReceiptVATAmount) * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|						THEN ReportToPrincipalInventory.AmountReceipt * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|					ELSE (ReportToPrincipalInventory.AmountReceipt + ReportToPrincipalInventory.ReceiptVATAmount) * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS Cost,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ReportToPrincipalInventory.BrokerageVATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ReportToPrincipalInventory.BrokerageVATAmount * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmount,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ReportToPrincipalInventory.BrokerageVATAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE ReportToPrincipalInventory.BrokerageVATAmount * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATSaleBrokerages,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|							THEN ReportToPrincipalInventory.BrokerageAmount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|						ELSE (ReportToPrincipalInventory.BrokerageAmount + ReportToPrincipalInventory.BrokerageVATAmount) * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|						THEN ReportToPrincipalInventory.BrokerageAmount * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|					ELSE (ReportToPrincipalInventory.BrokerageAmount + ReportToPrincipalInventory.BrokerageVATAmount) * ReportToPrincipalInventory.Ref.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmount,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ReportToPrincipalInventory.BrokerageVATAmount * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ReportToPrincipalInventory.BrokerageVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmountCur,
	//( elmi #11
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ReportToPrincipalInventory.ReceiptVATAmount * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ReportToPrincipalInventory.ReceiptVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS CostVATCur,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN ReportToPrincipalInventory.VATAmount * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					ELSE ReportToPrincipalInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	//|	CAST(CASE
	//|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	//|				THEN ReportToPrincipalInventory.BrokerageAmount * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	//|			ELSE ReportToPrincipalInventory.BrokerageAmount
	//|		END AS NUMBER(15, 2)) AS BrokerageAmountCur,
	|		CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|							THEN ReportToPrincipalInventory.BrokerageAmount * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|						ELSE (ReportToPrincipalInventory.BrokerageAmount + ReportToPrincipalInventory.BrokerageVATAmount) * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					END 
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|						THEN ReportToPrincipalInventory.BrokerageAmount
	|					ELSE ReportToPrincipalInventory.BrokerageAmount + ReportToPrincipalInventory.BrokerageVATAmount
	|				END 
	|		END AS NUMBER(15, 2)) AS BrokerageAmountCur,
	|	ReportToPrincipalInventory.ReceiptVATAmount AS ReceiptVATAmount,
	//) elmi
	|	ReportToPrincipalInventory.CustomerOrder AS CustomerOrder,
	|	ReportToPrincipalInventory.PurchaseOrder AS PurchaseOrder,
	|	ReportToPrincipalInventory.Ref.VATCommissionFeePercent,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|							THEN ReportToPrincipalInventory.AmountReceipt * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|						ELSE (ReportToPrincipalInventory.AmountReceipt + ReportToPrincipalInventory.ReceiptVATAmount) * RegCurrencyRates.ExchangeRate * ReportToPrincipalInventory.Ref.Multiplicity / (ReportToPrincipalInventory.Ref.ExchangeRate * RegCurrencyRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|						THEN ReportToPrincipalInventory.AmountReceipt
	|					ELSE ReportToPrincipalInventory.AmountReceipt + ReportToPrincipalInventory.ReceiptVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS CostPriceCur,
	|	CAST(CASE
	|			WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|				THEN ReportToPrincipalInventory.AmountReceipt
	|			ELSE ReportToPrincipalInventory.AmountReceipt + ReportToPrincipalInventory.ReceiptVATAmount
	|		END AS NUMBER(15, 2)) AS SettlementsAmountTakenPassed
	|INTO TemporaryTableInventory
	|FROM
	|	Document.ReportToPrincipal.Inventory AS ReportToPrincipalInventory
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
	|	ReportToPrincipalInventory.Ref = &Ref
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
	|	DocumentTable.Order AS Order,
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
	|	Document.ReportToPrincipal.Prepayment AS DocumentTable
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
	|	DocumentTable.Order,
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
	|	DocumentTable.Ref.Counterparty.TrackPaymentsByBills
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportToPrincipalSerialNumbers.ConnectionKey,
	|	ReportToPrincipalSerialNumbers.SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.ReportToPrincipal.SerialNumbers AS ReportToPrincipalSerialNumbers
	|WHERE
	|	ReportToPrincipalSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefReportToCommissioner, StructureAdditionalProperties);

	GenerateTableInventoryReceived(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesUndistributed(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	GenerateTableManagerial(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersGuarantees information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,		
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.ProductsAndServices AS ProductsAndServices,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", QueryResult.Unload());
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefReportToCommissioner, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryReceivedChange" contain records,
	// control products implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryReceivedChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
	
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryReceivedChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType) AS ReceptionTransmissionTypePresentation,
		|	REFPRESENTATION(InventoryReceivedBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.QuantityChange, 0) + ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS BalanceInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS QuantityBalanceInventoryReceived,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.SettlementsAmountChange, 0) + ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) AS SettlementsAmountBalanceInventoryReceived
		|FROM
		|	RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange
		|		LEFT JOIN AccumulationRegister.InventoryReceived.Balance(
		|				&ControlTime,
		|				(Company, ProductsAndServices, Characteristic, Batch, Counterparty, Contract, Order, ReceptionTransmissionType) In
		|					(SELECT
		|						RegisterRecordsInventoryReceivedChange.Company AS Company,
		|						RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryReceivedChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryReceivedChange.Batch AS Batch,
		|						RegisterRecordsInventoryReceivedChange.Counterparty AS Counterparty,
		|						RegisterRecordsInventoryReceivedChange.Contract AS Contract,
		|						RegisterRecordsInventoryReceivedChange.Order AS Order,
		|						RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType AS ReceptionTransmissionType
		|					FROM
		|						RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange)) AS InventoryReceivedBalances
		|		ON RegisterRecordsInventoryReceivedChange.Company = InventoryReceivedBalances.Company
		|			AND RegisterRecordsInventoryReceivedChange.ProductsAndServices = InventoryReceivedBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryReceivedChange.Characteristic = InventoryReceivedBalances.Characteristic
		|			AND RegisterRecordsInventoryReceivedChange.Batch = InventoryReceivedBalances.Batch
		|			AND RegisterRecordsInventoryReceivedChange.Counterparty = InventoryReceivedBalances.Counterparty
		|			AND RegisterRecordsInventoryReceivedChange.Contract = InventoryReceivedBalances.Contract
		|			AND RegisterRecordsInventoryReceivedChange.Order = InventoryReceivedBalances.Order
		|			AND RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType = InventoryReceivedBalances.ReceptionTransmissionType
		|WHERE
		|	(ISNULL(InventoryReceivedBalances.QuantityBalance, 0) < 0
		|			OR ISNULL(InventoryReceivedBalances.SettlementsAmountBalance, 0) < 0)
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
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectReportToPrincipal = DocumentRefReportToCommissioner.GetObject();
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryReceivedRegisterErrors(DocumentObjectReportToPrincipal, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectReportToPrincipal, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

// Function generates tabular document as certificate of
// services provided to the amount of reward
// 
Function PrintCertificate(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesReportToPrincipal_ServicesReport";
	
	Query = New Query;
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text =
	"SELECT
	|	SalesReportToPrincipal.Ref,
	|	SalesReportToPrincipal.Number,
	|	SalesReportToPrincipal.Date,
	|	SalesReportToPrincipal.Contract,
	|	SalesReportToPrincipal.Counterparty AS Recipient,
	|	SalesReportToPrincipal.Company AS Company,
	|	SalesReportToPrincipal.Company AS Vendor,
	|	SalesReportToPrincipal.DocumentAmount,
	|	SalesReportToPrincipal.DocumentCurrency,
	|	SalesReportToPrincipal.VATCommissionFeePercent,
	|	SUM(ReportToPrincipalInventory.BrokerageAmount) AS Amount
	|FROM
	|	Document.ReportToPrincipal.Inventory AS ReportToPrincipalInventory
	|		LEFT JOIN Document.ReportToPrincipal AS SalesReportToPrincipal
	|		ON ReportToPrincipalInventory.Ref = SalesReportToPrincipal.Ref
	|WHERE
	|	SalesReportToPrincipal.Ref IN(&ObjectsArray)
	|
	|GROUP BY
	|	SalesReportToPrincipal.Ref,
	|	SalesReportToPrincipal.DocumentCurrency,
	|	SalesReportToPrincipal.VATCommissionFeePercent,
	|	SalesReportToPrincipal.Number,
	|	SalesReportToPrincipal.Date,
	|	SalesReportToPrincipal.Contract,
	|	SalesReportToPrincipal.Counterparty,
	|	SalesReportToPrincipal.Company,
	|	SalesReportToPrincipal.DocumentAmount,
	|	SalesReportToPrincipal.Company";

	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Template		= GetTemplate("ServicesReport");

		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		
		InfoAboutCompany		= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date);
		CompanyPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		InfoAboutCounterparty     = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Recipient, Header.Date);
		PresentationOfCounterparty = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
		
		TemplateArea.Parameters.VendorPresentation = CompanyPresentation;
		TemplateArea.Parameters.RecipientPresentation = PresentationOfCounterparty;
		
		TemplateArea.Parameters.HeaderText			= NStr("en='Services acceptance certificate';ru='Акт выполненных работ'");
		TemplateArea.Parameters.TextAboutSumInWords		= 
			"Commission charge amount is " 
			+ SmallBusinessServer.GenerateAmountInWords(Header.Amount, Header.DocumentCurrency)
			+ ", including VAT " + Header.VATCommissionFeePercent;

		SpreadsheetDocument.Put(TemplateArea);

		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	Return SpreadsheetDocument;

EndFunction // CertificatePrinting() 

// Function generates tabular document with invoice
// printing form developed by coordinator
//
// Returns:
//  Spreadsheet document - invoice printing form
//
Function ReportToPrincipalPrinting(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument	= New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesReportToPrincipal_SalesReportToPrincipal";
	Template				= GetTemplate("SalesReportToPrincipal");
	
	Query = New Query;
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text =
	"SELECT
	|	SalesReportToPrincipal.Ref,
	|	SalesReportToPrincipal.Number,
	|	SalesReportToPrincipal.Date,
	|	SalesReportToPrincipal.Contract,
	|	SalesReportToPrincipal.Counterparty AS Recipient,
	|	SalesReportToPrincipal.Company AS Company,
	|	SalesReportToPrincipal.Company AS Vendor,
	|	SalesReportToPrincipal.DocumentAmount,
	|	SalesReportToPrincipal.DocumentCurrency,
	|	SalesReportToPrincipal.AmountIncludesVAT,
	|	SalesReportToPrincipal.VATCommissionFeePercent,
	|	SUM(ReportToPrincipalInventory.BrokerageAmount) AS BrokerageAmount
	|FROM
	|	Document.ReportToPrincipal.Inventory AS ReportToPrincipalInventory
	|		LEFT JOIN Document.ReportToPrincipal AS SalesReportToPrincipal
	|		ON ReportToPrincipalInventory.Ref = SalesReportToPrincipal.Ref
	|WHERE
	|	SalesReportToPrincipal.Ref IN(&ObjectsArray)
	|
	|GROUP BY
	|	SalesReportToPrincipal.Ref,
	|	SalesReportToPrincipal.DocumentCurrency,
	|	SalesReportToPrincipal.VATCommissionFeePercent,
	|	SalesReportToPrincipal.Number,
	|	SalesReportToPrincipal.Date,
	|	SalesReportToPrincipal.Contract,
	|	SalesReportToPrincipal.Counterparty,
	|	SalesReportToPrincipal.Company,
	|	SalesReportToPrincipal.DocumentAmount,
	|	SalesReportToPrincipal.Company";

	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		Template		= GetTemplate("SalesReportToPrincipal");
		
		If Not FirstDocument Then
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query;
		
		Query.SetParameter("CurrentDocument", Header.Ref);
		
		Query.Text =
		"SELECT
		|	SalesReportToPrincipalInventory.ProductsAndServices AS InventoryItem,
		|	SalesReportToPrincipalInventory.Characteristic AS Characteristic,
		|	SalesReportToPrincipalInventory.ProductsAndServices.Code AS Code,
		|	SalesReportToPrincipalInventory.ProductsAndServices.SKU AS SKU,
		|	SalesReportToPrincipalInventory.MeasurementUnit,
		|	SalesReportToPrincipalInventory.ProductsAndServices.MeasurementUnit AS StorageUnit,
		|	SalesReportToPrincipalInventory.Quantity AS Quantity,
		|	SalesReportToPrincipalInventory.Price,
		|	SalesReportToPrincipalInventory.Amount AS Amount,
		|	SalesReportToPrincipalInventory.VATAmount AS VATAmount,
		|	SalesReportToPrincipalInventory.Total AS Total,
		|	SalesReportToPrincipalInventory.Customer AS Customer,
		|	SalesReportToPrincipalInventory.DateOfSale AS SaleDate
		|FROM
		|	Document.ReportToPrincipal.Inventory AS SalesReportToPrincipalInventory
		|WHERE
		|	SalesReportToPrincipalInventory.Ref = &CurrentDocument
		|
		|ORDER BY
		|	Customer,
		|	SalesReportToPrincipalInventory.LineNumber
		|TOTALS
		|	SUM(Quantity),
		|	SUM(Amount),
		|	SUM(VATAmount)
		|BY
		|	Customer";
		
		CustomersSelection = Query.Execute().Select(QueryResultIteration.ByGroups, "Customer");
		
		Total	= 0;
		SerialNumber = 1;
		
		// Displaying invoice header
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = NStr("en='Report to principal';ru='Отчет комитенту'");
		SpreadsheetDocument.Put(TemplateArea);

		InfoAboutCompany    = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date);
		CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
		
		InfoAboutCounterparty     = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Recipient, Header.Date);
		PresentationOfCounterparty = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,");
		
		TemplateArea = Template.GetArea("Vendor");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.VendorPresentation = PresentationOfCounterparty;
		TemplateArea.Parameters.Vendor               = Header.Recipient;
		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.RecipientPresentation = CompanyPresentation;
		TemplateArea.Parameters.Recipient              = Header.Company;
		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);

		While CustomersSelection.Next() Do
			
			InfoAboutCustomer = SmallBusinessServer.InfoAboutLegalEntityIndividual(CustomersSelection.Customer, CustomersSelection.SaleDate);
			TextCustomer = "Customer: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr,LegalAddress,TIN,");

			TemplateArea = Template.GetArea("RowCustomer");
			TemplateArea.Parameters.CustomerPresentation = TextCustomer;
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("String");
			
			TotalByCounterparty = 0;
			
			StringSelectionProducts = CustomersSelection.Select();
			While StringSelectionProducts.Next() Do
				
				TemplateArea.Parameters.Fill(StringSelectionProducts);
				
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(StringSelectionProducts.InventoryItem, 
					StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
					
				TemplateArea.Parameters.LineNumber = SerialNumber;
				
				If Not Header.AmountIncludesVAT Then
					
					AmountByRow 					= StringSelectionProducts.Total;
					TemplateArea.Parameters.Price	= ?(StringSelectionProducts.Quantity <> 0, Round(AmountByRow/StringSelectionProducts.Quantity, 2), 0);
					TemplateArea.Parameters.Amount	= AmountByRow;
					
				Else
					
					AmountByRow = StringSelectionProducts.Amount;
					
				EndIf;
				
				SpreadsheetDocument.Put(TemplateArea);
				
				SerialNumber				= SerialNumber 				+ 1;
				Total				= Total 				+ AmountByRow;
				TotalByCounterparty	= TotalByCounterparty	+ AmountByRow;
				
			EndDo;
			
			TemplateArea = Template.GetArea("RowCustomerTotal");
			TemplateArea.Parameters.Fill(CustomersSelection);
			TemplateArea.Parameters.Amount = TotalByCounterparty;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total = Total;
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("AmountInWords");
		TemplateArea.Parameters.AmountInWords       = SmallBusinessServer.GenerateAmountInWords(Total, Header.DocumentCurrency);
		TemplateArea.Parameters.BrokerageAmount = "Commission charge amount is " 
													+ SmallBusinessServer.GenerateAmountInWords(Header.BrokerageAmount, Header.DocumentCurrency);
		TemplateArea.Parameters.TotalRow      = "Total titles " + StringSelectionProducts.Count() 
													+ ", in the amount of " + SmallBusinessServer.AmountsFormat(Total, Header.DocumentCurrency);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
		
	Return SpreadsheetDocument;

EndFunction // PrintReportToPrincipal()

// Procedure prints document. You can send printing to the screen or printer and print required number of copies.
//
//  Printing layout name is passed
// as a parameter, find layout name by the passed name in match.
//
// Parameters:
//  TemplateName - String, layout name.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ServicesAcceptanceCertificate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ServicesAcceptanceCertificate", "Services acceptance certificate", PrintCertificate(ObjectsArray, PrintObjects));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ReportToPrincipal") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ReportToPrincipal", "Principal report", ReportToPrincipalPrinting(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure // Print

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ServicesAcceptanceCertificate,ReportToPrincipal";
	PrintCommand.Presentation = NStr("en='Customized document set';ru='Настраиваемый комплект документов'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ServicesAcceptanceCertificate";
	PrintCommand.Presentation = NStr("en='Services acceptance certificate';ru='Акт выполненных работ'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ReportToPrincipal";
	PrintCommand.Presentation = NStr("en='Report to principal';ru='Отчет комитенту'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
EndProcedure

#EndRegion

#EndIf