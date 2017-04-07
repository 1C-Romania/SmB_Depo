#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefReceiptCRReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ReceiptCRInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ReceiptCRInventory.Date AS Period,
	|	ReceiptCRInventory.Company AS Company,
	|	ReceiptCRInventory.ProductsAndServices AS ProductsAndServices,
	|	ReceiptCRInventory.Characteristic AS Characteristic,
	|	ReceiptCRInventory.Batch AS Batch,
	|	ReceiptCRInventory.StructuralUnit AS StructuralUnit,
	|	SUM(ReceiptCRInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS ReceiptCRInventory
	|WHERE
	|	ReceiptCRInventory.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND &CheckIssued
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	ReceiptCRInventory.LineNumber,
	|	ReceiptCRInventory.Date,
	|	ReceiptCRInventory.Company,
	|	ReceiptCRInventory.ProductsAndServices,
	|	ReceiptCRInventory.Characteristic,
	|	ReceiptCRInventory.Batch,
	|	ReceiptCRInventory.StructuralUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefReceiptCRReturn);
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure // GenerateTableInventoryInWarehouses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefReceiptCRReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentData.Date AS Date,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentData.Company AS Company,
	|	DocumentData.CashCR AS CashCR,
	|	DocumentData.CashCRGLAccount AS GLAccount,
	|	DocumentData.DocumentCurrency AS Currency,
	|	SUM(DocumentData.Amount) AS Amount,
	|	SUM(DocumentData.AmountCur) AS AmountCur,
	|	-SUM(DocumentData.Amount) AS AmountForBalance,
	|	-SUM(DocumentData.AmountCur) AS AmountCurForBalance,
	|	CAST(&CashFundsReceipt AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableInventory AS DocumentData
	|WHERE
	|	&CheckIssued
	|	AND Not &Archival
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentData.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency,
	|	SUM(DocumentData.Amount),
	|	SUM(DocumentData.AmountCur),
	|	SUM(DocumentData.Amount),
	|	SUM(DocumentData.AmountCur),
	|	CAST(&PaymentWithPaymentCards AS String(100))
	|FROM
	|	TemporaryTablePaymentCards AS DocumentData
	|WHERE
	|	&CheckIssued
	|	AND Not &Archival
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|INDEX BY
	|	Company,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefReceiptCRReturn);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	Query.SetParameter("CashFundsReceipt", NStr("en='Cash receipt to the cash registers';ru='Поступление денежных средств в кассу ККМ'"));
	Query.SetParameter("PaymentWithPaymentCards", NStr("en='Payment by cards';ru='Оплата платежными картами'"));
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssetsInRetailCashes.Company AS Company,
	|	TemporaryTableCashAssetsInRetailCashes.CashCR AS CashCR
	|FROM
	|	TemporaryTableCashAssetsInRetailCashes";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashInCashRegisters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult IN QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text =  SmallBusinessServer.GetQueryTextExchangeRateDifferencesCashInCashRegisters(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashInCashRegisters", ResultsArray[QueryNumber].Unload());
	
EndProcedure // GenerateTableCashAssetsInCashRegisters()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReceiptCRReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Date AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessActivity AS BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder AS CustomerOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales AS GLAccount,
	|	CAST(&IncomeReflection AS String(100)) AS ContentOfAccountingRecord,
	//( elmi #11
	//|	-SUM(TableIncomeAndExpenses.Amount) AS AmountIncome,
	|	-SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,       
	|	0 AS AmountExpense,
	//|	-SUM(TableIncomeAndExpenses.Amount) AS Amount
	|	-SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS Amount               
	//) elmi
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	(NOT TableIncomeAndExpenses.ProductsOnCommission)
	|	AND &CheckIssued
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.BusinessActivity,
	|	TableIncomeAndExpenses.CustomerOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("IncomeReflection", NStr("en='Income accounting';ru='Отражение доходов'"));
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReceiptCRReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.ProductsAndServices AS ProductsAndServices,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.CustomerOrder AS CustomerOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	-SUM(TableSales.Quantity) AS Quantity,
	|	-SUM(TableSales.AmountVATPurchaseSale) AS VATAmount,
	|	-SUM(TableSales.Amount) AS Amount,
	|	0 AS Cost
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.Company,
	|	TableSales.ProductsAndServices,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.CustomerOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefReceiptCRReturn, StructureAdditionalProperties)
	
	//( elmi #11
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.VATAmount) AS VATInventory ,
	|	Sum(TemporaryTable.VATAmountCur) AS VATInventoryCur 
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Date,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATInventory = 0;
	VATInventoryCur = 0;
	
	While Selection.Next() Do  
		  VATInventory    = Selection.VATInventory;
	      VATInventoryCur = Selection.VATInventoryCur;
	EndDo;
	//) elmi

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Date AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	|			THEN VALUE(ChartOfAccounts.Managerial.AccountsPayable)
	|		ELSE TableManagerial.GLAccountRevenueFromSales
	|	END AS AccountDr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	|			THEN &AccountingCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableManagerial.ProductsOnCommission
	//( elmi #11
	//|			THEN TableManagerial.Amount
	|			THEN TableManagerial.Amount - TableManagerial.VATAmount                
	//) elmi
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableManagerial.CashCRGLAccount AS AccountCr,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	//( elmi #11
	//|			THEN TableManagerial.AmountCur
	|			THEN TableManagerial.AmountCur   - TableManagerial.VATAmountCur 
	|		ELSE 0
	|	END AS AmountCurCr,
	//|	TableManagerial.Amount AS Amount,
	|	TableManagerial.Amount  - TableManagerial.VATAmount AS Amount,                 
	//) elmi
	|	&IncomeReflection AS Content
	|FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableManagerial.LineNumber,
	|	TableManagerial.Date,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableManagerial.CashCRGLAccount,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.AmountCur
	|		ELSE 0
	|	END,
	|	TableManagerial.POSTerminalGlAccount,
	|	CASE
	|		WHEN TableManagerial.POSTerminalGlAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableManagerial.POSTerminalGlAccount.Currency
	|			THEN TableManagerial.AmountCur
	|		ELSE 0
	|	END,
	|	TableManagerial.Amount,
	|	&ReflectionOfPaymentByCards
	|FROM
	|	TemporaryTablePaymentCards AS TableManagerial
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableManagerial.LineNumber,
	|	TableManagerial.Date,
	|	TableManagerial.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN TableManagerial.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|				AND TableManagerial.GLAccount.Currency
	|			THEN TableManagerial.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableManagerial.GLAccount
	|	END,
	|	CASE
	|		WHEN TableManagerial.AmountOfExchangeDifferences < 0
	|				AND TableManagerial.GLAccount.Currency
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
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS TableManagerial
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	//( elmi #11
	|UNION ALL
	|
	|SELECT TOP 1
	|	4 AS Order,
	|	TableManagerial.LineNumber AS LineNumber,
	|	TableManagerial.Date AS Period,
	|	TableManagerial.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|   &TextVAT,
	|   UNDEFINED,
    |   0,
	|	TableManagerial.CashCRGLAccount AS AccountCr,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN TableManagerial.DocumentCurrency
	|		ELSE UNDEFINED
	|	END ,
	|	CASE
	|		WHEN TableManagerial.CashCRGLAccount.Currency
	|			THEN &VATInventoryCur 
	|		ELSE 0
	|	END ,
	|	&VATInventory,
	|	&VAT AS Content
    |FROM
	|	TemporaryTableInventory AS TableManagerial
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival) AND &VATInventory > 0
	|
    //) elmi
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("IncomeReflection", NStr("en='Sales revenue';ru='Выручка от продажи'"));
	Query.SetParameter("ReflectionOfPaymentByCards", NStr("en='Payment by cards';ru='Оплата платежными картами'"));
	Query.SetParameter("AccountingCurrency", Constants.AccountingCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", ChartsOfAccounts.Managerial.OtherIncome);
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", ChartsOfAccounts.Managerial.OtherExpenses);
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	//( elmi #11
	Query.SetParameter("VAT", NStr("en=' VAT '"));
	Query.SetParameter("TextVAT",  ChartsOfAccounts.Managerial.Taxes);
	Query.SetParameter("VATInventoryCur", VATInventoryCur);
	Query.SetParameter("VATInventory", VATInventory);
	//) elmi
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure // GenerateTableManagerial()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefReceiptCRReturn, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ReceiptCRInventory.LineNumber AS LineNumber,
	|	ReceiptCRInventory.Ref.ReceiptCR AS Document,
	|	ReceiptCRInventory.Ref.Date AS Date,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder,
	|	ReceiptCRInventory.Ref.CashCR AS CashCR,
	|	ReceiptCRInventory.Ref.CashCR.Owner AS CashCROwner,
	|	ReceiptCRInventory.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	ReceiptCRInventory.Ref.DocumentCurrency AS DocumentCurrency,
	|	&Company AS Company,
	|	ReceiptCRInventory.Ref.StructuralUnit AS StructuralUnit,
	|	ReceiptCRInventory.Ref.Department AS Department,
	|	ReceiptCRInventory.Ref.Responsible AS Responsible,
	|	ReceiptCRInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	ReceiptCRInventory.ProductsAndServices.BusinessActivity AS BusinessActivity,
	|	ReceiptCRInventory.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
	|	ReceiptCRInventory.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCost,
	|	UNDEFINED AS Cell,
	|	ReceiptCRInventory.ProductsAndServices.InventoryGLAccount AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseBatches
	|				AND ReceiptCRInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	ReceiptCRInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ReceiptCRInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ReceiptCRInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(ReceiptCRInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN ReceiptCRInventory.Quantity
	|		ELSE ReceiptCRInventory.Quantity * ReceiptCRInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	ReceiptCRInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN ReceiptCRInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE ReceiptCRInventory.VATAmount * DocCurrencyCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * DocCurrencyCurrencyRates.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(ReceiptCRInventory.VATAmount * DocCurrencyCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * DocCurrencyCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(ReceiptCRInventory.Total * DocCurrencyCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * DocCurrencyCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CAST(ReceiptCRInventory.VATAmount AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(ReceiptCRInventory.Total AS NUMBER(15, 2)) AS AmountCur,
	|	ReceiptCRInventory.ConnectionKey
	|INTO TemporaryTableInventory
	|FROM
	|	Document.ReceiptCRReturn.Inventory AS ReceiptCRInventory
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS ManagCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS DocCurrencyCurrencyRates
	|		ON ReceiptCRInventory.Ref.DocumentCurrency = DocCurrencyCurrencyRates.Currency
	|WHERE
	|	ReceiptCRInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TabularSection.LineNumber AS LineNumber,
	|	TabularSection.Ref.Date AS Date,
	|	&Ref AS Document,
	|	&Company AS Company,
	|	TabularSection.Ref.CashCR AS CashCR,
	|	TabularSection.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	TabularSection.Ref.POSTerminal.GLAccount AS POSTerminalGlAccount,
	|	TabularSection.Ref.DocumentCurrency AS DocumentCurrency,
	|	CAST(TabularSection.Amount * CurrencyRatesOfPettyCashe.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	TabularSection.Amount AS AmountCur
	|INTO TemporaryTablePaymentCards
	|FROM
	|	Document.ReceiptCRReturn.PaymentWithPaymentCards AS TabularSection
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfPettyCashe
	|		ON TabularSection.Ref.DocumentCurrency = CurrencyRatesOfPettyCashe.Currency
	|WHERE
	|	TabularSection.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CRReceiptReturnDiscountsMarkups.ConnectionKey,
	|	CRReceiptReturnDiscountsMarkups.DiscountMarkup,
	|	CAST(CASE
	|			WHEN CRReceiptReturnDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CRReceiptReturnDiscountsMarkups.Amount * RegCurrencyRates.ExchangeRate * ManagCurrencyRates.Multiplicity / (ManagCurrencyRates.ExchangeRate * RegCurrencyRates.Multiplicity)
	|			ELSE CRReceiptReturnDiscountsMarkups.Amount * ManagCurrencyRates.Multiplicity / ManagCurrencyRates.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CRReceiptReturnDiscountsMarkups.Ref.Date AS Period,
	|	CRReceiptReturnDiscountsMarkups.Ref.StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.ReceiptCRReturn.DiscountsMarkups AS CRReceiptReturnDiscountsMarkups
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
	|	CRReceiptReturnDiscountsMarkups.Ref = &Ref
	|	AND CRReceiptReturnDiscountsMarkups.Amount <> 0";
	
	Query.SetParameter("Ref", DocumentRefReceiptCRReturn);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	
	GenerateTableInventoryInWarehouses(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReceiptCRReturn, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefReceiptCRReturn, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl()
	 OR Not Constants.ControlBalancesDuringCreationCRReceipts.Get()
	    OR DocumentRefReceiptCRReturn.Archival Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", control goods implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange Then
		
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
		|	RegisterRecordsCashInCashRegistersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.CashCR) AS CashCRDescription,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.CashCR.CashCurrency) AS CurrencyPresentation,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange + ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashInCashRegistersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashInCashRegistersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange
		|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(
		|				&ControlTime,
		|				(Company, CashCR) In
		|					(SELECT
		|						RegisterRecordsCashInCashRegistersChange.Company AS Company,
		|						RegisterRecordsCashInCashRegistersChange.CashCR AS CashCRType
		|					FROM
		|						RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange)) AS CashAssetsInRetailCashesBalances
		|		ON RegisterRecordsCashInCashRegistersChange.Company = CashAssetsInRetailCashesBalances.Company
		|			AND RegisterRecordsCashInCashRegistersChange.CashCR = CashAssetsInRetailCashesBalances.CashCR
		|WHERE
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
		 OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectReceiptCRReturn = DocumentRefReceiptCRReturn.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectReceiptCRReturn, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectReceiptCRReturn, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#EndRegion

#Region DiscountCards

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefReceiptCRReturn, StructureAdditionalProperties)
	
	If DocumentRefReceiptCRReturn.DiscountCard.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.Document.DiscountCard AS DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner AS CardOwner,
	|	-SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.Document.DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

#EndRegion

#Region AutomaticDiscounts

Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefReceiptCRReturn, StructureAdditionalProperties)
	
	If DocumentRefReceiptCRReturn.DiscountsMarkups.Count() = 0 OR Not GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	-TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TemporaryTableInventory.ProductsAndServices,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Document AS DocumentDiscounts,
	|	TemporaryTableInventory.StructuralUnit AS RecipientDiscounts
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableInventory.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure // GenerateTableSales()

#EndRegion

#Region PrintInterface

// Function generates tabular document of petty cash book cover.
//
Function GeneratePrintFormOfTheBill(ObjectsArray, PrintObjects)
	
	Template = PrintManagement.PrintedFormsTemplate("Document.ReceiptCRReturn.PF_MXL_SalesReceipt");
	
	Spreadsheet = New SpreadsheetDocument;
	Spreadsheet.PrintParametersName = "PRINT_PARAMETERS_Check_SaleInvoice";
	
	FirstDocument = True;
	
	For Each ReceiptCR IN ObjectsArray Do
		
		If Not FirstDocument Then
			Spreadsheet.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = Spreadsheet.TableHeight + 1;
		
		Query = New Query;
		Query.SetParameter("CurrentDocument", ReceiptCR.Ref);
		
		Query.Text =
		"SELECT
		|	ReceiptCRReturn.Number AS Number,
		|	ReceiptCRReturn.Date AS Date,
		|	ReceiptCRReturn.CashCR AS CashCR,
		|	ReceiptCRReturn.DocumentCurrency AS Currency,
		|	ReceiptCRReturn.CashCR.Presentation AS Customer,
		|	ReceiptCRReturn.Company AS Company,
		|	ReceiptCRReturn.Company.Prefix AS Prefix,
		|	ReceiptCRReturn.Company.Presentation AS Vendor,
		|	ReceiptCRReturn.DocumentAmount AS DocumentAmount,
		|	ReceiptCRReturn.AmountIncludesVAT AS AmountIncludesVAT,
		|	ReceiptCRReturn.Inventory.(
		|		LineNumber AS LineNumber,
		|		ProductsAndServices AS ProductsAndServices,
		|		ProductsAndServices.Presentation AS InventoryItem,
		|		ProductsAndServices.DescriptionFull AS InventoryFullDescr,
		|		ProductsAndServices.Code AS Code,
		|		ProductsAndServices.SKU AS SKU,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Price AS Price,
		|		Amount AS Amount,
		|		VATAmount AS VATAmount,
		|		Total AS Total,
		|		DiscountMarkupPercent,
		|		CASE
		|			WHEN ReceiptCRReturn.Inventory.DiscountMarkupPercent <> 0
		|					OR ReceiptCRReturn.Inventory.AutomaticDiscountAmount <> 0
		|				THEN 1
		|			ELSE 0
		|		END AS IsDiscount,
		|		AutomaticDiscountAmount
		|	)
		|FROM
		|	Document.ReceiptCRReturn AS ReceiptCRReturn
		|WHERE
		|	ReceiptCRReturn.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date, ,);
		
		If Header.Date < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		// Output invoice header.
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = NStr("ru = 'Чек ККМ на возврат № '; en = 'Receipt CR on return No '")
												+ DocumentNumber
												+ NStr("ru = ' от '; en = ' from '")
												+ Format(Header.Date, "DLF=DD");

		Spreadsheet.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.VendorPresentation = VendorPresentation;
		TemplateArea.Parameters.Vendor = Header.Company;
		Spreadsheet.Put(TemplateArea);
		
		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;

		NumberArea = Template.GetArea("TableHeader|LineNumber");
		DataArea = Template.GetArea("TableHeader|Data");
		DiscountsArea = Template.GetArea("TableHeader|Discount");
		AmountArea  = Template.GetArea("TableHeader|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		Spreadsheet.Join(AmountArea);
		
		AreaColumnInventory = Template.Area("InventoryItem");
		
		If Not AreDiscounts Then
			AreaColumnInventory.ColumnWidth = AreaColumnInventory.ColumnWidth
											  + Template.Area("AmountWithoutDiscount").ColumnWidth
											  + Template.Area("DiscountAmount").ColumnWidth;
		EndIf;
		
		NumberArea = Template.GetArea("String|LineNumber");
		DataArea = Template.GetArea("String|Data");
		DiscountsArea = Template.GetArea("String|Discount");
		AmountArea  = Template.GetArea("String|Amount");
		
		Amount			= 0;
		VATAmount		= 0;
		Total			= 0;
		TotalDiscounts		= 0;
		TotalWithoutDiscounts	= 0;
		
		LinesSelectionInventory = Header.Inventory.Select();
		While LinesSelectionInventory.Next() Do
			
			If Not ValueIsFilled(LinesSelectionInventory.ProductsAndServices) Then
				Message(NStr("ru = 'В одной из строк не заполнено значение номенклатуры - строка при печати пропущена.'; en = 'Products and services value is not filled in in one of the rows - String during printing is skipped.'"), MessageStatus.Important);
				Continue;
			EndIf;
			
			NumberArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Put(NumberArea);
			
			DataArea.Parameters.Fill(LinesSelectionInventory);
			DataArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																		LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
			
			Spreadsheet.Join(DataArea);
			
			Discount = 0;
			
			If AreDiscounts Then
				If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
					Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
					DiscountsArea.Parameters.Discount         = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = Discount;
				ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
					DiscountsArea.Parameters.Discount         = 0;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount;
				Else
					Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
					DiscountsArea.Parameters.Discount         = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount + Discount;
				EndIf;
				Spreadsheet.Join(DiscountsArea);
			EndIf;
			
			AmountArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Join(AmountArea);
			
			Amount			= Amount			+ LinesSelectionInventory.Amount;
			VATAmount		= VATAmount		+ LinesSelectionInventory.VATAmount;
			Total			= Total			+ LinesSelectionInventory.Total;
			TotalDiscounts		= TotalDiscounts	+ Discount;
			TotalWithoutDiscounts	= Amount			+ TotalDiscounts;
			
		EndDo;
		
		// Output Total.
		NumberArea = Template.GetArea("Total|LineNumber");
		DataArea = Template.GetArea("Total|Data");
		DiscountsArea = Template.GetArea("Total|Discount");
		AmountArea  = Template.GetArea("Total|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			DiscountsArea.Parameters.TotalDiscounts    = TotalDiscounts;
			DiscountsArea.Parameters.TotalWithoutDiscounts = TotalWithoutDiscounts;
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		AmountArea.Parameters.Total = Amount;
		Spreadsheet.Join(AmountArea);
		
		// Output amount in writing.
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = NStr("ru = 'Всего наименований '; en = 'Total titles '")
													+ String(LinesSelectionInventory.Count())
													+ NStr("ru = ', на сумму '; en = ', in the amount of '")
													+ SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Header.Currency);
																						   
		TemplateArea.Parameters.AmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.Currency);
		Spreadsheet.Put(TemplateArea);
	
		// Output signatures.
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.Fill(Header);
		Spreadsheet.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(Spreadsheet, FirstLineNumber, PrintObjects, ReceiptCR);
		
	EndDo;
	
	Spreadsheet.FitToPage = True;
	
	Return Spreadsheet;
	
EndFunction // GeneratePettyCashBookCoverAndLastSheetPrintableForm()

// Document printing procedure.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "SalesReceipt") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "SalesReceipt", "Sales receipt", GeneratePrintFormOfTheBill(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure // Print()

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "SalesReceipt";
	PrintCommand.Presentation = NStr("en='Sales receipt';ru='Товарный чек'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
EndProcedure

#EndRegion

#EndIf