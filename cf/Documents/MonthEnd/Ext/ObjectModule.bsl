#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure AddErrorIntoTable(ErrorDescription, OperationKind, ErrorsTable, Analytics = Undefined)
	
	If Analytics = Undefined Then
		Analytics = Documents.CustomerOrder.EmptyRef()
	EndIf;
	
	NewRow = ErrorsTable.Add();
	NewRow.Period = Date;
	NewRow.Company = AdditionalProperties.ForPosting.Company;
	NewRow.OperationKind = OperationKind;
	NewRow.Analytics = Analytics;
	NewRow.ErrorDescription = ErrorDescription;
	NewRow.Recorder = Ref;
	NewRow.Active = True;
	
EndProcedure // AddErrorIntoTable()

Function GenerateErrorDescriptionCostAllocation(GLAccount, MethodOfDistribution, FilterByOrder, Amount)
	
	ErrorDescription = NStr("en='The ""%GLAccount%"" cost in the %Amount% amount allocated for production release by %AllocationMethod% can not be allocated as in the calculated period there was no %AdditionalDetails%.';ru='Затрата ""%СчетУчета%"" в сумме %Сумма%, распределяемая на выпуск продукции по %СпособРаспределения% не может быть распределена, т.к. в рассчитываемом периоде не было %ДополнительноеОписание%.'"
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%GLAccount%",
		String(GLAccount)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%Amount%",
		String(Amount) + " " + TrimAll(String(Constants.AccountingCurrency.Get()))
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AllocationMethod%",
		?(MethodOfDistribution = Enums.CostingBases.ProductionVolume,
			"release volume",
			"direct costs"
		)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AdditionalDetails%",
		?(MethodOfDistribution = Enums.CostingBases.ProductionVolume,
			"production release%Order%",
			"allocation of direct costs%Order% specified in the allocation setting"
		)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%Order%",
		?(ValueIsFilled(FilterByOrder),
			" to " + String(FilterByOrder),
			""
		)
	);
	
	Return ErrorDescription;
	
EndFunction // GenerateCostAllocationErrorDescription()

Function GenerateErrorDescriptionExpensesDistribution(GLAccount, MethodOfDistribution, Amount)
	
	ErrorDescription = NStr("en='The ""%GLAccount%"" expense in the %Amount% amount allocated for a financial result by %AllocationMethod% can not be allocated as in the calculated period there was no %AdditionalDetails%.';ru='Затрата ""%СчетУчета%"" в сумме %Сумма%, распределяемая на выпуск продукции по %СпособРаспределения% не может быть распределена, т.к. в рассчитываемом периоде не было %ДополнительноеОписание%.'"
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%GLAccount%",
		String(GLAccount)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%Amount%",
		String(Amount) + " " + TrimAll(String(Constants.AccountingCurrency.Get()))
	);
	
	If MethodOfDistribution = Enums.CostingBases.SalesVolume Then
		TextMethodOfDistribution = "sales volume";
	ElsIf MethodOfDistribution = Enums.CostingBases.SalesRevenue Then
		TextMethodOfDistribution = "sales revenue";
	ElsIf MethodOfDistribution = Enums.CostingBases.CostOfGoodsSold Then
		TextMethodOfDistribution = "sales primecost";
	ElsIf MethodOfDistribution = Enums.CostingBases.GrossProfit Then
		TextMethodOfDistribution = "gross profit";
	EndIf;
		
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AllocationMethod%",
		TextMethodOfDistribution
	);
	
	If MethodOfDistribution = Enums.CostingBases.SalesVolume Then
		TextAdditionalDetails = "sales";
	ElsIf MethodOfDistribution = Enums.CostingBases.SalesRevenue Then
		TextAdditionalDetails = "sales revenue";
	ElsIf MethodOfDistribution = Enums.CostingBases.CostOfGoodsSold Then
		TextAdditionalDetails = "sales primecost";
	ElsIf MethodOfDistribution = Enums.CostingBases.GrossProfit Then
		TextAdditionalDetails = "gross profit";
	EndIf;
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AdditionalDetails%",
		TextAdditionalDetails
	);
	
	Return ErrorDescription;
	
EndFunction // GenerateExpensesAllocationErrorDescription()

////////////////////////////////////////////////////////////////////////////////
// CALCULATE RELEASE ACTUAL COST

// Function generates movements on the WriteOffCostCorrectionNodes information register.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
// Returns:
//  Number - number of a written node.
//
Function MakeRegisterRecordsByRegisterWriteOffCostsCorrectionNodes(Cancel)
	
	Query = New Query();
	
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("EmptyAccount", AdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	// Receive a new nodes table, each node is
	// defined by the combination of all accounting dimensions. An average price is put to the
	// Amount column according to the corresponding InventoryAndCostAccounting register resource by the external receipt for each node.
	// These columns are the right parts in the linear equations system. The
	// total quantity of receipt to each node is put to the Quantity columns. If
	// there are no movements on quantity in this node but there are
	// only movements on cost, then the cost
	// is used instead of the quantity (the node corresponds to the non material expenses). If there is a writeoff
	// by the fixed cost from the node, then reduce
	// the quantity and the cost of accrual to this node on the quantity and the cost by the fixed operation.
	Query.Text =
	"SELECT
	|	CostAccountingForCalculations.Company AS Company,
	|	CostAccountingForCalculations.StructuralUnit AS StructuralUnit,
	|	CostAccountingForCalculations.GLAccount AS GLAccount,
	|	CostAccountingForCalculations.ProductsAndServices AS ProductsAndServices,
	|	CostAccountingForCalculations.Characteristic AS Characteristic,
	|	CostAccountingForCalculations.Batch AS Batch,
	|	CostAccountingForCalculations.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN SUM(NestedSelect.Quantity) = 0
	|			THEN SUM(NestedSelect.SumForQuantity)
	|		ELSE SUM(NestedSelect.Quantity)
	|	END AS Quantity,
	|	CASE
	|		WHEN SUM(NestedSelect.Quantity) = 0
	|				AND SUM(NestedSelect.SumForQuantity) = 0
	|			THEN 0
	|		ELSE CAST(SUM(NestedSelect.Amount) / CASE
	|					WHEN SUM(NestedSelect.Quantity) = 0
	|						THEN SUM(NestedSelect.SumForQuantity)
	|					ELSE SUM(NestedSelect.Quantity)
	|				END AS NUMBER(23, 10))
	|	END AS Amount
	|INTO TableNodsOfCorrectionOfCostWriteOffs
	|FROM
	|	(SELECT DISTINCT
	|		CostAccounting.Company AS Company,
	|		CostAccounting.StructuralUnit AS StructuralUnit,
	|		CostAccounting.GLAccount AS GLAccount,
	|		CostAccounting.ProductsAndServices AS ProductsAndServices,
	|		CostAccounting.Characteristic AS Characteristic,
	|		CostAccounting.Batch AS Batch,
	|		CostAccounting.CustomerOrder AS CustomerOrder
	|	FROM
	|		AccumulationRegister.Inventory AS CostAccounting
	|	WHERE
	|		CostAccounting.Period between &DateBeg AND &DateEnd
	|		AND CostAccounting.Company = &Company
	|		AND (CostAccounting.Quantity <> 0
	|				OR CostAccounting.Amount <> 0)) AS CostAccountingForCalculations
	|		LEFT JOIN (SELECT
	|			CostAccounting.Company AS Company,
	|			CostAccounting.StructuralUnit AS StructuralUnit,
	|			CostAccounting.GLAccount AS GLAccount,
	|			CostAccounting.ProductsAndServices AS ProductsAndServices,
	|			CostAccounting.Characteristic AS Characteristic,
	|			CostAccounting.Batch AS Batch,
	|			CostAccounting.CustomerOrder AS CustomerOrder,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Quantity
	|				ELSE -CostAccounting.Quantity
	|			END AS Quantity,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Amount
	|				ELSE -CostAccounting.Amount
	|			END AS SumForQuantity,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND CostAccounting.FixedCost
	|					THEN CostAccounting.Amount
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND CostAccounting.FixedCost
	|					THEN -CostAccounting.Amount
	|				ELSE 0
	|			END AS Amount
	|		FROM
	|			AccumulationRegister.Inventory AS CostAccounting
	|		WHERE
	|			CostAccounting.Period between &DateBeg AND &DateEnd
	|			AND (CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND Not CostAccounting.Return
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND CostAccounting.Return)
	|			AND CostAccounting.Company = &Company
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			CostAccounting.Company,
	|			CostAccounting.StructuralUnit,
	|			CostAccounting.GLAccount,
	|			CostAccounting.ProductsAndServices,
	|			CostAccounting.Characteristic,
	|			CostAccounting.Batch,
	|			CostAccounting.CustomerOrder,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Quantity
	|				ELSE 0 - CostAccounting.Quantity
	|			END,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Amount
	|				ELSE 0 - CostAccounting.Amount
	|			END,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Amount
	|				ELSE 0 - CostAccounting.Amount
	|			END
	|		FROM
	|			AccumulationRegister.Inventory AS CostAccounting
	|		WHERE
	|			CostAccounting.Period between &DateBeg AND &DateEnd
	|			AND (CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND Not CostAccounting.Return
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND CostAccounting.Return)
	|			AND CostAccounting.FixedCost
	|			AND CostAccounting.Company = &Company
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			AccountingCostBalance.Company,
	|			AccountingCostBalance.StructuralUnit,
	|			AccountingCostBalance.GLAccount,
	|			AccountingCostBalance.ProductsAndServices,
	|			AccountingCostBalance.Characteristic,
	|			AccountingCostBalance.Batch,
	|			AccountingCostBalance.CustomerOrder,
	|			AccountingCostBalance.QuantityBalance,
	|			AccountingCostBalance.AmountBalance,
	|			AccountingCostBalance.AmountBalance
	|		FROM
	|			AccumulationRegister.Inventory.Balance(&DateBeg, Company = &Company) AS AccountingCostBalance) AS NestedSelect
	|		ON CostAccountingForCalculations.Company = NestedSelect.Company
	|			AND CostAccountingForCalculations.StructuralUnit = NestedSelect.StructuralUnit
	|			AND CostAccountingForCalculations.GLAccount = NestedSelect.GLAccount
	|			AND CostAccountingForCalculations.ProductsAndServices = NestedSelect.ProductsAndServices
	|			AND CostAccountingForCalculations.Characteristic = NestedSelect.Characteristic
	|			AND CostAccountingForCalculations.Batch = NestedSelect.Batch
	|			AND CostAccountingForCalculations.CustomerOrder = NestedSelect.CustomerOrder
	|WHERE
	|	CostAccountingForCalculations.ProductsAndServices.EstimationMethod = VALUE(Enum.InventoryValuationMethods.FIFO)
	|
	|GROUP BY
	|	CostAccountingForCalculations.Company,
	|	CostAccountingForCalculations.StructuralUnit,
	|	CostAccountingForCalculations.GLAccount,
	|	CostAccountingForCalculations.ProductsAndServices,
	|	CostAccountingForCalculations.Characteristic,
	|	CostAccountingForCalculations.Batch,
	|	CostAccountingForCalculations.CustomerOrder";
	Query.Execute();
	
	// Generate balance for the end of the period that will be closed according to FIFO.
	Query.Text =
	"SELECT
	|	AccountingCostBalance.Company AS Company,
	|	AccountingCostBalance.StructuralUnit AS StructuralUnit,
	|	AccountingCostBalance.GLAccount AS GLAccount,
	|	AccountingCostBalance.ProductsAndServices AS ProductsAndServices,
	|	AccountingCostBalance.Characteristic AS Characteristic,
	|	AccountingCostBalance.Batch AS Batch,
	|	AccountingCostBalance.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN AccountingCostBalance.QuantityBalance > 0
	|			THEN AccountingCostBalance.QuantityBalance
	|		ELSE 0
	|	END AS QuantityBalance,
	|	CASE
	|		WHEN AccountingCostBalance.QuantityBalance > 0
	|			THEN AccountingCostBalance.QuantityBalance
	|		ELSE 0
	|	END AS BalanceQuantityAtEndOfPeriod,
	|	DATEADD(&DateEnd, Second, 1) AS Period,
	|	0 AS AmountBalance
	|INTO BalanceTableBatches
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND ProductsAndServices.EstimationMethod = VALUE(Enum.InventoryValuationMethods.FIFO)) AS AccountingCostBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Field1
	|INTO PeriodsOfBatches";
	Query.Execute();
	
	Query.Text =
	"DROP PeriodsOfBatches
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccounting.Company AS Company,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CostAccounting.GLAccount AS GLAccount,
	|	CostAccounting.ProductsAndServices AS ProductsAndServices,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.CustomerOrder AS CustomerOrder,
	|	MAX(BEGINOFPERIOD(CostAccounting.Period, Day)) AS Period
	|INTO PeriodsOfBatches
	|FROM
	|	AccumulationRegister.Inventory AS CostAccounting
	|		INNER JOIN BalanceTableBatches AS BalanceTableBatches
	|		ON (BalanceTableBatches.Company = CostAccounting.Company)
	|			AND (BalanceTableBatches.StructuralUnit = CostAccounting.StructuralUnit)
	|			AND (BalanceTableBatches.GLAccount = CostAccounting.GLAccount)
	|			AND (BalanceTableBatches.ProductsAndServices = CostAccounting.ProductsAndServices)
	|			AND (BalanceTableBatches.Characteristic = CostAccounting.Characteristic)
	|			AND (BalanceTableBatches.Batch = CostAccounting.Batch)
	|			AND (BalanceTableBatches.CustomerOrder = CostAccounting.CustomerOrder)
	|			AND (BalanceTableBatches.QuantityBalance <> 0)
	|WHERE
	|	CostAccounting.Period between &DateBeg AND &DateEnd
	|	AND CostAccounting.CorrGLAccount = &EmptyAccount
	|	AND (CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				AND (NOT CostAccounting.Return)
	|			OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				AND CostAccounting.Return)
	|	AND CostAccounting.Period < BalanceTableBatches.Period
	|	AND CostAccounting.Company = &Company
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.GLAccount,
	|	CostAccounting.ProductsAndServices,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.CustomerOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PeriodsOfBatches.Company AS Company,
	|	PeriodsOfBatches.StructuralUnit AS StructuralUnit,
	|	PeriodsOfBatches.GLAccount AS GLAccount,
	|	PeriodsOfBatches.ProductsAndServices AS ProductsAndServices,
	|	PeriodsOfBatches.Characteristic AS Characteristic,
	|	PeriodsOfBatches.Batch AS Batch,
	|	PeriodsOfBatches.CustomerOrder AS CustomerOrder,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN CostAccounting.Quantity
	|			ELSE -CostAccounting.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN CostAccounting.Amount
	|			ELSE -CostAccounting.Amount
	|		END) AS Amount,
	|	PeriodsOfBatches.Period
	|INTO ExternalReceiptForPeriod
	|FROM
	|	PeriodsOfBatches AS PeriodsOfBatches
	|		LEFT JOIN AccumulationRegister.Inventory AS CostAccounting
	|		ON PeriodsOfBatches.Company = CostAccounting.Company
	|			AND PeriodsOfBatches.StructuralUnit = CostAccounting.StructuralUnit
	|			AND PeriodsOfBatches.GLAccount = CostAccounting.GLAccount
	|			AND PeriodsOfBatches.ProductsAndServices = CostAccounting.ProductsAndServices
	|			AND PeriodsOfBatches.Characteristic = CostAccounting.Characteristic
	|			AND PeriodsOfBatches.Batch = CostAccounting.Batch
	|			AND PeriodsOfBatches.CustomerOrder = CostAccounting.CustomerOrder
	|			AND (CostAccounting.Period between PeriodsOfBatches.Period AND ENDOFPERIOD(PeriodsOfBatches.Period, Day))
	|			AND (CostAccounting.CorrGLAccount = &EmptyAccount)
	|			AND (CostAccounting.FixedCost)
	|			AND (CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					AND (NOT CostAccounting.Return)
	|				OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|					AND CostAccounting.Return)
	|
	|GROUP BY
	|	PeriodsOfBatches.Company,
	|	PeriodsOfBatches.StructuralUnit,
	|	PeriodsOfBatches.GLAccount,
	|	PeriodsOfBatches.ProductsAndServices,
	|	PeriodsOfBatches.Characteristic,
	|	PeriodsOfBatches.Batch,
	|	PeriodsOfBatches.CustomerOrder,
	|	PeriodsOfBatches.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BalanceTableBatches.Company AS Company,
	|	BalanceTableBatches.StructuralUnit AS StructuralUnit,
	|	BalanceTableBatches.GLAccount AS GLAccount,
	|	BalanceTableBatches.ProductsAndServices AS ProductsAndServices,
	|	BalanceTableBatches.Characteristic AS Characteristic,
	|	BalanceTableBatches.Batch AS Batch,
	|	BalanceTableBatches.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN BalanceTableBatches.QuantityBalance > ISNULL(ExternalReceiptForPeriod.Quantity, 0)
	|			THEN BalanceTableBatches.QuantityBalance - ISNULL(ExternalReceiptForPeriod.Quantity, 0)
	|		ELSE 0
	|	END AS QuantityBalance,
	|	CASE
	|		WHEN BalanceTableBatches.QuantityBalance >= ISNULL(ExternalReceiptForPeriod.Quantity, 0)
	|			THEN BalanceTableBatches.AmountBalance + ISNULL(ExternalReceiptForPeriod.Amount, 0)
	|		ELSE BalanceTableBatches.AmountBalance + CAST(ExternalReceiptForPeriod.Amount * BalanceTableBatches.QuantityBalance / ExternalReceiptForPeriod.Quantity AS NUMBER(23, 10))
	|	END AS AmountBalance,
	|	BalanceTableBatches.BalanceQuantityAtEndOfPeriod,
	|	ExternalReceiptForPeriod.Period
	|INTO TableOfCurrentBatchesBalances
	|FROM
	|	BalanceTableBatches AS BalanceTableBatches
	|		LEFT JOIN ExternalReceiptForPeriod AS ExternalReceiptForPeriod
	|		ON BalanceTableBatches.Company = ExternalReceiptForPeriod.Company
	|			AND BalanceTableBatches.StructuralUnit = ExternalReceiptForPeriod.StructuralUnit
	|			AND BalanceTableBatches.GLAccount = ExternalReceiptForPeriod.GLAccount
	|			AND BalanceTableBatches.ProductsAndServices = ExternalReceiptForPeriod.ProductsAndServices
	|			AND BalanceTableBatches.Characteristic = ExternalReceiptForPeriod.Characteristic
	|			AND BalanceTableBatches.Batch = ExternalReceiptForPeriod.Batch
	|			AND BalanceTableBatches.CustomerOrder = ExternalReceiptForPeriod.CustomerOrder
	|			AND (BalanceTableBatches.QuantityBalance <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP BalanceTableBatches
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ExternalReceiptForPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfCurrentBatchesBalances.Company AS Company,
	|	TableOfCurrentBatchesBalances.StructuralUnit AS StructuralUnit,
	|	TableOfCurrentBatchesBalances.GLAccount AS GLAccount,
	|	TableOfCurrentBatchesBalances.ProductsAndServices AS ProductsAndServices,
	|	TableOfCurrentBatchesBalances.Characteristic AS Characteristic,
	|	TableOfCurrentBatchesBalances.Batch AS Batch,
	|	TableOfCurrentBatchesBalances.CustomerOrder AS CustomerOrder,
	|	TableOfCurrentBatchesBalances.QuantityBalance AS QuantityBalance,
	|	TableOfCurrentBatchesBalances.BalanceQuantityAtEndOfPeriod AS BalanceQuantityAtEndOfPeriod,
	|	TableOfCurrentBatchesBalances.AmountBalance AS AmountBalance,
	|	TableOfCurrentBatchesBalances.Period AS Period
	|INTO BalanceTableBatches
	|FROM
	|	TableOfCurrentBatchesBalances AS TableOfCurrentBatchesBalances
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableOfCurrentBatchesBalances
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	PeriodsOfBatches AS PeriodsOfBatches";
	
	// Search for batches.
	IterationsQuantity = 0;
	Result = Query.Execute();
	While Not Result.IsEmpty() Do
		IterationsQuantity = IterationsQuantity + 1;
		Result = Query.Execute();
	EndDo;
	
	// Decrease the quantity and receipt amount in nodes
	// to the quantity and amount of the "fixed" end balance.
	Query.Text =
	"SELECT
	|	TableNodsOfCorrectionOfCostWriteOffs.Company AS Company,
	|	TableNodsOfCorrectionOfCostWriteOffs.StructuralUnit AS StructuralUnit,
	|	TableNodsOfCorrectionOfCostWriteOffs.GLAccount AS GLAccount,
	|	TableNodsOfCorrectionOfCostWriteOffs.ProductsAndServices AS ProductsAndServices,
	|	TableNodsOfCorrectionOfCostWriteOffs.Characteristic AS Characteristic,
	|	TableNodsOfCorrectionOfCostWriteOffs.Batch AS Batch,
	|	TableNodsOfCorrectionOfCostWriteOffs.CustomerOrder AS CustomerOrder,
	|	TableNodsOfCorrectionOfCostWriteOffs.Quantity - ISNULL(BalanceTableBatches.BalanceQuantityAtEndOfPeriod, 0) + ISNULL(BalanceTableBatches.QuantityBalance, 0) AS Quantity,
	|	CASE
	|		WHEN TableNodsOfCorrectionOfCostWriteOffs.Quantity - ISNULL(BalanceTableBatches.BalanceQuantityAtEndOfPeriod, 0) + ISNULL(BalanceTableBatches.QuantityBalance, 0) = 0
	|			THEN 0
	|		ELSE (TableNodsOfCorrectionOfCostWriteOffs.Amount * TableNodsOfCorrectionOfCostWriteOffs.Quantity - ISNULL(BalanceTableBatches.AmountBalance, 0)) / (TableNodsOfCorrectionOfCostWriteOffs.Quantity - ISNULL(BalanceTableBatches.BalanceQuantityAtEndOfPeriod, 0) + ISNULL(BalanceTableBatches.QuantityBalance, 0))
	|	END AS Amount
	|FROM
	|	TableNodsOfCorrectionOfCostWriteOffs AS TableNodsOfCorrectionOfCostWriteOffs
	|		LEFT JOIN BalanceTableBatches AS BalanceTableBatches
	|		ON TableNodsOfCorrectionOfCostWriteOffs.Company = BalanceTableBatches.Company
	|			AND TableNodsOfCorrectionOfCostWriteOffs.StructuralUnit = BalanceTableBatches.StructuralUnit
	|			AND TableNodsOfCorrectionOfCostWriteOffs.GLAccount = BalanceTableBatches.GLAccount
	|			AND TableNodsOfCorrectionOfCostWriteOffs.ProductsAndServices = BalanceTableBatches.ProductsAndServices
	|			AND TableNodsOfCorrectionOfCostWriteOffs.Characteristic = BalanceTableBatches.Characteristic
	|			AND TableNodsOfCorrectionOfCostWriteOffs.Batch = BalanceTableBatches.Batch
	|			AND TableNodsOfCorrectionOfCostWriteOffs.CustomerOrder = BalanceTableBatches.CustomerOrder
	|
	|UNION ALL
	|
	|SELECT
	|	CostAccountingForCalculations.Company,
	|	CostAccountingForCalculations.StructuralUnit,
	|	CostAccountingForCalculations.GLAccount,
	|	CostAccountingForCalculations.ProductsAndServices,
	|	CostAccountingForCalculations.Characteristic,
	|	CostAccountingForCalculations.Batch,
	|	CostAccountingForCalculations.CustomerOrder,
	|	CASE
	|		WHEN SUM(NestedSelect.Quantity) = 0
	|			THEN SUM(NestedSelect.SumForQuantity)
	|		ELSE SUM(NestedSelect.Quantity)
	|	END,
	|	CASE
	|		WHEN SUM(NestedSelect.Quantity) = 0
	|				AND SUM(NestedSelect.SumForQuantity) = 0
	|			THEN 0
	|		ELSE CAST(SUM(NestedSelect.Amount) / CASE
	|				WHEN SUM(NestedSelect.Quantity) = 0
	|					THEN SUM(NestedSelect.SumForQuantity)
	|				ELSE SUM(NestedSelect.Quantity)
	|			END AS NUMBER(23, 10))
	|	END
	|FROM
	|	(SELECT DISTINCT
	|		CostAccounting.Company AS Company,
	|		CostAccounting.StructuralUnit AS StructuralUnit,
	|		CostAccounting.GLAccount AS GLAccount,
	|		CostAccounting.ProductsAndServices AS ProductsAndServices,
	|		CostAccounting.Characteristic AS Characteristic,
	|		CostAccounting.Batch AS Batch,
	|		CostAccounting.CustomerOrder AS CustomerOrder
	|	FROM
	|		AccumulationRegister.Inventory AS CostAccounting
	|	WHERE
	|		CostAccounting.Period between &DateBeg AND &DateEnd
	|		AND CostAccounting.Company = &Company
	|		AND (CostAccounting.Quantity <> 0
	|				OR CostAccounting.Amount <> 0)) AS CostAccountingForCalculations
	|		LEFT JOIN (SELECT
	|			CostAccounting.Company AS Company,
	|			CostAccounting.StructuralUnit AS StructuralUnit,
	|			CostAccounting.GLAccount AS GLAccount,
	|			CostAccounting.ProductsAndServices AS ProductsAndServices,
	|			CostAccounting.Characteristic AS Characteristic,
	|			CostAccounting.Batch AS Batch,
	|			CostAccounting.CustomerOrder AS CustomerOrder,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Quantity
	|				ELSE -CostAccounting.Quantity
	|			END AS Quantity,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Amount
	|				ELSE -CostAccounting.Amount
	|			END AS SumForQuantity,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND (CostAccounting.FixedCost)
	|					THEN CostAccounting.Amount
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND (CostAccounting.FixedCost)
	|					THEN -CostAccounting.Amount
	|				ELSE 0
	|			END AS Amount
	|		FROM
	|			AccumulationRegister.Inventory AS CostAccounting
	|		WHERE
	|			CostAccounting.Period between &DateBeg AND &DateEnd
	|			AND (CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND (NOT CostAccounting.Return)
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND CostAccounting.Return)
	|			AND CostAccounting.Company = &Company
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			CostAccounting.Company,
	|			CostAccounting.StructuralUnit,
	|			CostAccounting.GLAccount,
	|			CostAccounting.ProductsAndServices,
	|			CostAccounting.Characteristic,
	|			CostAccounting.Batch,
	|			CostAccounting.CustomerOrder,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Quantity
	|				ELSE 0 - CostAccounting.Quantity
	|			END,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Amount
	|				ELSE 0 - CostAccounting.Amount
	|			END,
	|			CASE
	|				WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					THEN CostAccounting.Amount
	|				ELSE 0 - CostAccounting.Amount
	|			END
	|		FROM
	|			AccumulationRegister.Inventory AS CostAccounting
	|		WHERE
	|			CostAccounting.Period between &DateBeg AND &DateEnd
	|			AND (CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND (NOT CostAccounting.Return)
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND CostAccounting.Return)
	|			AND CostAccounting.FixedCost
	|			AND CostAccounting.Company = &Company
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			AccountingCostBalance.Company,
	|			AccountingCostBalance.StructuralUnit,
	|			AccountingCostBalance.GLAccount,
	|			AccountingCostBalance.ProductsAndServices,
	|			AccountingCostBalance.Characteristic,
	|			AccountingCostBalance.Batch,
	|			AccountingCostBalance.CustomerOrder,
	|			AccountingCostBalance.QuantityBalance,
	|			AccountingCostBalance.AmountBalance,
	|			AccountingCostBalance.AmountBalance
	|		FROM
	|			AccumulationRegister.Inventory.Balance(&DateBeg, Company = &Company) AS AccountingCostBalance) AS NestedSelect
	|		ON CostAccountingForCalculations.Company = NestedSelect.Company
	|			AND CostAccountingForCalculations.StructuralUnit = NestedSelect.StructuralUnit
	|			AND CostAccountingForCalculations.GLAccount = NestedSelect.GLAccount
	|			AND CostAccountingForCalculations.ProductsAndServices = NestedSelect.ProductsAndServices
	|			AND CostAccountingForCalculations.Characteristic = NestedSelect.Characteristic
	|			AND CostAccountingForCalculations.Batch = NestedSelect.Batch
	|			AND CostAccountingForCalculations.CustomerOrder = NestedSelect.CustomerOrder
	|WHERE
	|	(CostAccountingForCalculations.ProductsAndServices.EstimationMethod = VALUE(Enum.InventoryValuationMethods.ByAverage)
	|			OR CostAccountingForCalculations.ProductsAndServices.EstimationMethod = VALUE(Enum.InventoryValuationMethods.EmptyRef)
	|			OR CostAccountingForCalculations.ProductsAndServices = VALUE(Catalog.ProductsAndServices.EmptyRef))
	|
	|GROUP BY
	|	CostAccountingForCalculations.Company,
	|	CostAccountingForCalculations.StructuralUnit,
	|	CostAccountingForCalculations.GLAccount,
	|	CostAccountingForCalculations.ProductsAndServices,
	|	CostAccountingForCalculations.Characteristic,
	|	CostAccountingForCalculations.Batch,
	|	CostAccountingForCalculations.CustomerOrder";
	
	NodeNo = 0;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		RecordSet = InformationRegisters.WriteOffCostsCorrectionNodes.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Ref);
		RecordSet.Write(True);
		Selection = Result.Select();
		While Selection.Next() Do
			NodeNo = NodeNo + 1;
			NewNode = RecordSet.Add();
			NewNode.NodeNo = NodeNo;
			NewNode.Recorder = Ref;
			NewNode.Period = Date;
			FillPropertyValues(NewNode, Selection);
		EndDo;
		RecordSet.Write(False);
	EndIf;
	
	// The first approximation (solution on the first iteration).
	Query.Text =
	"SELECT
	|	WriteOffCostsCorrectionNodes.NodeNo,
	|	WriteOffCostsCorrectionNodes.Amount
	|INTO SolutionsTable
	|FROM
	|	InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
	|WHERE
	|	WriteOffCostsCorrectionNodes.Recorder = &Recorder
	|
	|INDEX BY
	|	NodeNo
	|";
	Query.Execute();
	
	Return NodeNo;
	
EndFunction // GenerateMovementsOnRegisterWriteOffCostCorrectionNodes()

// Solve the linear equations system
//
// Parameters:
// No.
//
// Returns:
//  Boolean - check box of finding a solution.
//
Function SolveLES()
	
	Query = New Query();
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("EmptyAccount", AdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	CurrentVariance = 1;
	RequiredPrecision = 0.00001;
	IterationsQuantity = 0;
	
	// Prepare the table of movements and writeoffs for the report period. The
	// current period returns are processed as usual movements.
	Query.Text =
	"SELECT
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.StructuralUnit AS StructuralUnit,
	|	InventoryAndCostAccounting.GLAccount AS GLAccount,
	|	InventoryAndCostAccounting.ProductsAndServices AS ProductsAndServices,
	|	InventoryAndCostAccounting.Characteristic AS Characteristic,
	|	InventoryAndCostAccounting.Batch AS Batch,
	|	InventoryAndCostAccounting.CustomerOrder AS CustomerOrder,
	|	InventoryAndCostAccounting.OrderSales AS OrderSales,
	|	InventoryAndCostAccounting.SalesDocument AS SalesDocument,
	|	-SUM(InventoryAndCostAccounting.Quantity) AS Quantity,
	|	-SUM(InventoryAndCostAccounting.Amount) AS Amount
	|INTO CostAccountingReturnsCurPeriod
	|FROM
	|	AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|WHERE
	|	InventoryAndCostAccounting.Company = &Company
	|	AND InventoryAndCostAccounting.Period between &DateBeg AND &DateEnd
	|	AND InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND InventoryAndCostAccounting.Return
	|	AND Not InventoryAndCostAccounting.FixedCost
	|	AND InventoryAndCostAccounting.SalesDocument <> UNDEFINED
	|	AND ENDOFPERIOD(InventoryAndCostAccounting.SalesDocument.Date, MONTH) = ENDOFPERIOD(InventoryAndCostAccounting.Period, MONTH)
	|
	|GROUP BY
	|	InventoryAndCostAccounting.Company,
	|	InventoryAndCostAccounting.StructuralUnit,
	|	InventoryAndCostAccounting.GLAccount,
	|	InventoryAndCostAccounting.ProductsAndServices,
	|	InventoryAndCostAccounting.Characteristic,
	|	InventoryAndCostAccounting.Batch,
	|	InventoryAndCostAccounting.CustomerOrder,
	|	InventoryAndCostAccounting.OrderSales,
	|	InventoryAndCostAccounting.SalesDocument
	|
	|INDEX BY
	|	SalesDocument,
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	CustomerOrder,
	|	OrderSales
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccountingReturnsCurPeriod.Company AS Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount AS GLAccount,
	|	CostAccountingReturnsCurPeriod.ProductsAndServices AS ProductsAndServices,
	|	CostAccountingReturnsCurPeriod.Characteristic AS Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch AS Batch,
	|	CostAccountingReturnsCurPeriod.CustomerOrder AS CustomerOrder,
	|	WriteOffCostsCorrectionNodes.NodeNo AS NodeNo,
	|	SUM(ISNULL(InventoryAndCostAccounting.Quantity, 0)) AS QuantitySold,
	|	SUM(ISNULL(InventoryAndCostAccounting.Amount, 0)) AS AmountSold,
	|	CostAccountingReturnsCurPeriod.Quantity AS QuantityReturn,
	|	CostAccountingReturnsCurPeriod.Amount AS AmountReturn,
	|	CostAccountingReturnsCurPeriod.SalesDocument AS SalesDocument
	|INTO CostAccountingReturnsOnReserves
	|FROM
	|	CostAccountingReturnsCurPeriod AS CostAccountingReturnsCurPeriod
	|		LEFT JOIN AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		ON CostAccountingReturnsCurPeriod.SalesDocument = InventoryAndCostAccounting.SalesDocument
	|			AND CostAccountingReturnsCurPeriod.Company = InventoryAndCostAccounting.Company
	|			AND CostAccountingReturnsCurPeriod.ProductsAndServices = InventoryAndCostAccounting.ProductsAndServices
	|			AND CostAccountingReturnsCurPeriod.Characteristic = InventoryAndCostAccounting.Characteristic
	|			AND CostAccountingReturnsCurPeriod.Batch = InventoryAndCostAccounting.Batch
	|			AND CostAccountingReturnsCurPeriod.OrderSales = InventoryAndCostAccounting.OrderSales
	|			AND CostAccountingReturnsCurPeriod.OrderSales = InventoryAndCostAccounting.CustomerOrder
	|			AND (NOT InventoryAndCostAccounting.Return)
	|		LEFT JOIN InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
	|		ON (WriteOffCostsCorrectionNodes.Recorder = &Recorder)
	|			AND (InventoryAndCostAccounting.Company = WriteOffCostsCorrectionNodes.Company)
	|			AND (InventoryAndCostAccounting.StructuralUnit = WriteOffCostsCorrectionNodes.StructuralUnit)
	|			AND (InventoryAndCostAccounting.GLAccount = WriteOffCostsCorrectionNodes.GLAccount)
	|			AND (InventoryAndCostAccounting.ProductsAndServices = WriteOffCostsCorrectionNodes.ProductsAndServices)
	|			AND (InventoryAndCostAccounting.Characteristic = WriteOffCostsCorrectionNodes.Characteristic)
	|			AND (InventoryAndCostAccounting.Batch = WriteOffCostsCorrectionNodes.Batch)
	|			AND (InventoryAndCostAccounting.CustomerOrder = WriteOffCostsCorrectionNodes.CustomerOrder)
	|
	|GROUP BY
	|	CostAccountingReturnsCurPeriod.Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount,
	|	CostAccountingReturnsCurPeriod.ProductsAndServices,
	|	CostAccountingReturnsCurPeriod.Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch,
	|	CostAccountingReturnsCurPeriod.CustomerOrder,
	|	WriteOffCostsCorrectionNodes.NodeNo,
	|	CostAccountingReturnsCurPeriod.Quantity,
	|	CostAccountingReturnsCurPeriod.Amount,
	|	CostAccountingReturnsCurPeriod.SalesDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccountingReturnsCurPeriod.Company AS Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount AS GLAccount,
	|	CostAccountingReturnsCurPeriod.ProductsAndServices AS ProductsAndServices,
	|	CostAccountingReturnsCurPeriod.Characteristic AS Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch AS Batch,
	|	CostAccountingReturnsCurPeriod.CustomerOrder AS CustomerOrder,
	|	WriteOffCostsCorrectionNodes.NodeNo AS NodeNo,
	|	SUM(ISNULL(InventoryAndCostAccounting.Quantity, 0)) AS QuantitySold,
	|	SUM(ISNULL(InventoryAndCostAccounting.Amount, 0)) AS AmountSold,
	|	CostAccountingReturnsCurPeriod.Quantity AS QuantityReturn,
	|	CostAccountingReturnsCurPeriod.Amount AS AmountReturn,
	|	CostAccountingReturnsCurPeriod.SalesDocument AS SalesDocument
	|INTO CostAccountingReturnsFree
	|FROM
	|	CostAccountingReturnsCurPeriod AS CostAccountingReturnsCurPeriod
	|		LEFT JOIN AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		ON CostAccountingReturnsCurPeriod.SalesDocument = InventoryAndCostAccounting.SalesDocument
	|			AND CostAccountingReturnsCurPeriod.Company = InventoryAndCostAccounting.Company
	|			AND CostAccountingReturnsCurPeriod.ProductsAndServices = InventoryAndCostAccounting.ProductsAndServices
	|			AND CostAccountingReturnsCurPeriod.Characteristic = InventoryAndCostAccounting.Characteristic
	|			AND CostAccountingReturnsCurPeriod.Batch = InventoryAndCostAccounting.Batch
	|			AND CostAccountingReturnsCurPeriod.OrderSales = InventoryAndCostAccounting.OrderSales
	|			AND (InventoryAndCostAccounting.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef))
	|			AND (NOT InventoryAndCostAccounting.Return)
	|		LEFT JOIN InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
	|		ON (WriteOffCostsCorrectionNodes.Recorder = &Recorder)
	|			AND (InventoryAndCostAccounting.Company = WriteOffCostsCorrectionNodes.Company)
	|			AND (InventoryAndCostAccounting.StructuralUnit = WriteOffCostsCorrectionNodes.StructuralUnit)
	|			AND (InventoryAndCostAccounting.GLAccount = WriteOffCostsCorrectionNodes.GLAccount)
	|			AND (InventoryAndCostAccounting.ProductsAndServices = WriteOffCostsCorrectionNodes.ProductsAndServices)
	|			AND (InventoryAndCostAccounting.Characteristic = WriteOffCostsCorrectionNodes.Characteristic)
	|			AND (InventoryAndCostAccounting.Batch = WriteOffCostsCorrectionNodes.Batch)
	|			AND (InventoryAndCostAccounting.CustomerOrder = WriteOffCostsCorrectionNodes.CustomerOrder)
	|
	|GROUP BY
	|	CostAccountingReturnsCurPeriod.Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount,
	|	CostAccountingReturnsCurPeriod.ProductsAndServices,
	|	CostAccountingReturnsCurPeriod.Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch,
	|	CostAccountingReturnsCurPeriod.CustomerOrder,
	|	WriteOffCostsCorrectionNodes.NodeNo,
	|	CostAccountingReturnsCurPeriod.Quantity,
	|	CostAccountingReturnsCurPeriod.Amount,
	|	CostAccountingReturnsCurPeriod.SalesDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccountingReturns.Company AS Company,
	|	CostAccountingReturns.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturns.GLAccount AS GLAccount,
	|	CostAccountingReturns.ProductsAndServices AS ProductsAndServices,
	|	CostAccountingReturns.Characteristic AS Characteristic,
	|	CostAccountingReturns.Batch AS Batch,
	|	CostAccountingReturns.CustomerOrder AS CustomerOrder,
	|	CostAccountingReturns.NodeNo AS NodeNo,
	|	CostAccountingReturns.QuantitySold AS QuantitySold,
	|	CostAccountingReturns.AmountSold AS AmountSold,
	|	CostAccountingReturns.QuantityReturn AS QuantityReturn,
	|	CostAccountingReturns.AmountReturn AS AmountReturn,
	|	0 AS QuantityDistributed,
	|	0 AS SumIsDistributed,
	|	CostAccountingReturns.SalesDocument AS SalesDocument
	|FROM
	|	(SELECT
	|		CostAccountingReturns.Company AS Company,
	|		CostAccountingReturns.StructuralUnit AS StructuralUnit,
	|		CostAccountingReturns.GLAccount AS GLAccount,
	|		CostAccountingReturns.ProductsAndServices AS ProductsAndServices,
	|		CostAccountingReturns.Characteristic AS Characteristic,
	|		CostAccountingReturns.Batch AS Batch,
	|		CostAccountingReturns.CustomerOrder AS CustomerOrder,
	|		CostAccountingReturns.NodeNo AS NodeNo,
	|		CostAccountingReturns.QuantitySold AS QuantitySold,
	|		CostAccountingReturns.AmountSold AS AmountSold,
	|		CostAccountingReturns.QuantityReturn AS QuantityReturn,
	|		CostAccountingReturns.AmountReturn AS AmountReturn,
	|		CostAccountingReturns.SalesDocument AS SalesDocument
	|	FROM
	|		CostAccountingReturnsFree AS CostAccountingReturns
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		CostAccountingReturns.StructuralUnit,
	|		CostAccountingReturns.GLAccount,
	|		CostAccountingReturns.ProductsAndServices,
	|		CostAccountingReturns.Characteristic,
	|		CostAccountingReturns.Batch,
	|		CostAccountingReturns.CustomerOrder,
	|		CostAccountingReturns.NodeNo,
	|		CostAccountingReturns.QuantitySold,
	|		CostAccountingReturns.AmountSold,
	|		CostAccountingReturns.QuantityReturn,
	|		CostAccountingReturns.AmountReturn,
	|		CostAccountingReturns.SalesDocument
	|	FROM
	|		CostAccountingReturnsOnReserves AS CostAccountingReturns) AS CostAccountingReturns
	|
	|ORDER BY
	|	NodeNo
	|TOTALS BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	SalesDocument,
	|	AmountReturn,
	|	QuantityReturn";
	
	QueryResult = Query.ExecuteBatch();
	
	ReturnsTable = QueryResult[3].Unload();
	ReturnsTable.Clear();
	
	BypassOnCounterparty = QueryResult[3].Select(QueryResultIteration.ByGroups);
	While BypassOnCounterparty.Next() Do
		BypassByStructuralUnit = BypassOnCounterparty.Select(QueryResultIteration.ByGroups);
		While BypassByStructuralUnit.Next() Do
			BypassingByAccountStatement = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			While BypassingByAccountStatement.Next() Do
				BypassOnProductsAndServices = BypassingByAccountStatement.Select(QueryResultIteration.ByGroups);
				While BypassOnProductsAndServices.Next() Do
					BypassByCharacteristic = BypassOnProductsAndServices.Select(QueryResultIteration.ByGroups);
					While BypassByCharacteristic.Next() Do
						CrawlByBatch = BypassByCharacteristic.Select(QueryResultIteration.ByGroups);
						While CrawlByBatch.Next() Do
							BypassBySalesDocument = CrawlByBatch.Select(QueryResultIteration.ByGroups);
							While BypassBySalesDocument.Next() Do
								BypassOnSumReturn = BypassBySalesDocument.Select(QueryResultIteration.ByGroups);
								While BypassOnSumReturn.Next() Do
									BypassByQuantityReturn = BypassOnSumReturn.Select(QueryResultIteration.ByGroups);
									While BypassByQuantityReturn.Next() Do
										QuantityLeftToDistribute = BypassByQuantityReturn.QuantityReturn;
										AmountLeftToDistribute = BypassByQuantityReturn.AmountReturn;
										SelectionDetailRecords = BypassByQuantityReturn.Select();
										While SelectionDetailRecords.Next() Do
											If QuantityLeftToDistribute > 0 Then
												If QuantityLeftToDistribute <= SelectionDetailRecords.QuantitySold Then
													NewRow = ReturnsTable.Add();
													FillPropertyValues(NewRow, SelectionDetailRecords);
													NewRow.QuantityDistributed = QuantityLeftToDistribute;
													QuantityLeftToDistribute = 0;
													NewRow.SumIsDistributed = AmountLeftToDistribute;
													AmountLeftToDistribute = 0;
												Else
													NewRow = ReturnsTable.Add();
													FillPropertyValues(NewRow, SelectionDetailRecords);
													NewRow.QuantityDistributed = SelectionDetailRecords.QuantitySold;
													QuantityLeftToDistribute = QuantityLeftToDistribute - SelectionDetailRecords.QuantitySold;
													NewRow.SumIsDistributed = SelectionDetailRecords.AmountSold;
													AmountLeftToDistribute = AmountLeftToDistribute - SelectionDetailRecords.AmountSold;
												EndIf;
											EndIf;
										EndDo;
									EndDo;
								EndDo;
							EndDo;
						EndDo;
					EndDo;
				EndDo;
			EndDo;
		EndDo;
	EndDo;
	
	Query.SetParameter("ReturnsTable", ReturnsTable);
	
	Query.Text =
	"SELECT DISTINCT
	|	ReturnsTable.Company AS Company,
	|	ReturnsTable.StructuralUnit AS StructuralUnit,
	|	ReturnsTable.GLAccount AS GLAccount,
	|	ReturnsTable.ProductsAndServices AS ProductsAndServices,
	|	ReturnsTable.Characteristic AS Characteristic,
	|	ReturnsTable.Batch AS Batch,
	|	ReturnsTable.CustomerOrder AS CustomerOrder,
	|	ReturnsTable.NodeNo AS NodeNo,
	|	ReturnsTable.QuantityDistributed AS Quantity,
	|	ReturnsTable.SumIsDistributed AS Amount
	|INTO CostAccountingReturns
	|FROM
	|	&ReturnsTable AS ReturnsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.StructuralUnitCorr AS StructuralUnit,
	|	InventoryAndCostAccounting.CorrGLAccount AS GLAccount,
	|	InventoryAndCostAccounting.ProductsAndServicesCorr AS ProductsAndServices,
	|	InventoryAndCostAccounting.CharacteristicCorr AS Characteristic,
	|	InventoryAndCostAccounting.BatchCorr AS Batch,
	|	InventoryAndCostAccounting.CustomerCorrOrder AS CustomerOrder,
	|	WriteOffCostsCorrectionNodes.NodeNo AS NodeNo,
	|	SUM(CASE
	|			WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|					AND Not InventoryAndCostAccounting.Return
	|				THEN InventoryAndCostAccounting.Quantity
	|			WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|					AND InventoryAndCostAccounting.Return
	|				THEN -InventoryAndCostAccounting.Quantity
	|			ELSE 0
	|		END) AS Quantity,
	|	SUM(CAST(CASE
	|				WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND Not InventoryAndCostAccounting.Return
	|					THEN InventoryAndCostAccounting.Amount
	|				WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND InventoryAndCostAccounting.Return
	|					THEN -InventoryAndCostAccounting.Amount
	|				ELSE 0
	|			END AS NUMBER(23, 10))) AS Amount
	|INTO CostAccountingWithoutReturnAccounting
	|FROM
	|	AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		LEFT JOIN InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
	|		ON (WriteOffCostsCorrectionNodes.Recorder = &Recorder)
	|			AND InventoryAndCostAccounting.Company = WriteOffCostsCorrectionNodes.Company
	|			AND InventoryAndCostAccounting.StructuralUnit = WriteOffCostsCorrectionNodes.StructuralUnit
	|			AND InventoryAndCostAccounting.GLAccount = WriteOffCostsCorrectionNodes.GLAccount
	|			AND InventoryAndCostAccounting.ProductsAndServices = WriteOffCostsCorrectionNodes.ProductsAndServices
	|			AND InventoryAndCostAccounting.Characteristic = WriteOffCostsCorrectionNodes.Characteristic
	|			AND InventoryAndCostAccounting.Batch = WriteOffCostsCorrectionNodes.Batch
	|			AND InventoryAndCostAccounting.CustomerOrder = WriteOffCostsCorrectionNodes.CustomerOrder
	|WHERE
	|	InventoryAndCostAccounting.Period between &DateBeg AND &DateEnd
	|	AND InventoryAndCostAccounting.Company = &Company
	|	AND Not InventoryAndCostAccounting.FixedCost
	|
	|GROUP BY
	|	InventoryAndCostAccounting.Company,
	|	InventoryAndCostAccounting.StructuralUnitCorr,
	|	InventoryAndCostAccounting.CorrGLAccount,
	|	InventoryAndCostAccounting.ProductsAndServicesCorr,
	|	InventoryAndCostAccounting.CharacteristicCorr,
	|	InventoryAndCostAccounting.BatchCorr,
	|	InventoryAndCostAccounting.CustomerCorrOrder,
	|	WriteOffCostsCorrectionNodes.NodeNo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccounting.Company AS Company,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CostAccounting.GLAccount AS GLAccount,
	|	CostAccounting.ProductsAndServices AS ProductsAndServices,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.CustomerOrder AS CustomerOrder,
	|	CostAccounting.NodeNo AS NodeNo,
	|	SUM(CostAccounting.Quantity) AS Quantity,
	|	SUM(CostAccounting.Amount) AS Amount
	|INTO CostAccounting
	|FROM
	|	(SELECT
	|		CostAccountingNetOfRefunds.Company AS Company,
	|		CostAccountingNetOfRefunds.StructuralUnit AS StructuralUnit,
	|		CostAccountingNetOfRefunds.GLAccount AS GLAccount,
	|		CostAccountingNetOfRefunds.ProductsAndServices AS ProductsAndServices,
	|		CostAccountingNetOfRefunds.Characteristic AS Characteristic,
	|		CostAccountingNetOfRefunds.Batch AS Batch,
	|		CostAccountingNetOfRefunds.CustomerOrder AS CustomerOrder,
	|		CostAccountingNetOfRefunds.NodeNo AS NodeNo,
	|		CostAccountingNetOfRefunds.Quantity AS Quantity,
	|		CostAccountingNetOfRefunds.Amount AS Amount
	|	FROM
	|		CostAccountingWithoutReturnAccounting AS CostAccountingNetOfRefunds
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		CostAccountingReturns.StructuralUnit,
	|		CostAccountingReturns.GLAccount,
	|		CostAccountingReturns.ProductsAndServices,
	|		CostAccountingReturns.Characteristic,
	|		CostAccountingReturns.Batch,
	|		CostAccountingReturns.CustomerOrder,
	|		CostAccountingReturns.NodeNo,
	|		CostAccountingReturns.Quantity,
	|		CostAccountingReturns.Amount
	|	FROM
	|		CostAccountingReturns AS CostAccountingReturns
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		UNDEFINED,
	|		VALUE(ChartOfAccounts.Managerial.EmptyRef),
	|		VALUE(Catalog.ProductsAndServices.EmptyRef),
	|		VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef),
	|		VALUE(Catalog.ProductsAndServicesBatches.EmptyRef),
	|		VALUE(Document.CustomerOrder.EmptyRef),
	|		CostAccountingReturns.NodeNo,
	|		-CostAccountingReturns.Quantity,
	|		-CostAccountingReturns.Amount
	|	FROM
	|		CostAccountingReturns AS CostAccountingReturns) AS CostAccounting
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.GLAccount,
	|	CostAccounting.ProductsAndServices,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.CustomerOrder,
	|	CostAccounting.NodeNo
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	CustomerOrder,
	|	NodeNo";
	
	
	Query.ExecuteBatch();
	
	// Iteratively search for the solution of linear
	// equations system until the deviation is less than the required one or 100 calculation iterations are not executed.
	While (CurrentVariance > RequiredPrecision * RequiredPrecision) AND (IterationsQuantity < 100) Do
		
		IterationsQuantity = IterationsQuantity + 1;
		
		// The next settlement iteration.
		Query.Text = 
		"SELECT
		|	WriteOffCostsCorrectionNodes.NodeNo AS NodeNo,
		|	SUM(CAST(CASE
		|				WHEN WriteOffCostsCorrectionNodes.Quantity <> 0
		|					THEN SolutionsTable.Amount * CASE
		|							WHEN CostAccounting.Quantity = 0
		|								THEN CostAccounting.Amount
		|							ELSE CostAccounting.Quantity
		|						END / WriteOffCostsCorrectionNodes.Quantity
		|				ELSE 0
		|			END AS NUMBER(23, 10))) AS Amount
		|INTO TemporaryTableSolutions
		|FROM
		|	InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
		|		LEFT JOIN CostAccounting AS CostAccounting
		|			LEFT JOIN SolutionsTable AS SolutionsTable
		|			ON CostAccounting.NodeNo = SolutionsTable.NodeNo
		|		ON WriteOffCostsCorrectionNodes.Company = CostAccounting.Company
		|			AND WriteOffCostsCorrectionNodes.StructuralUnit = CostAccounting.StructuralUnit
		|			AND WriteOffCostsCorrectionNodes.GLAccount = CostAccounting.GLAccount
		|			AND WriteOffCostsCorrectionNodes.ProductsAndServices = CostAccounting.ProductsAndServices
		|			AND WriteOffCostsCorrectionNodes.Characteristic = CostAccounting.Characteristic
		|			AND WriteOffCostsCorrectionNodes.Batch = CostAccounting.Batch
		|			AND WriteOffCostsCorrectionNodes.CustomerOrder = CostAccounting.CustomerOrder
		|WHERE
		|	WriteOffCostsCorrectionNodes.Recorder = &Recorder
		|
		|GROUP BY
		|	WriteOffCostsCorrectionNodes.NodeNo
		|
		|INDEX BY
		|	NodeNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SUM((ISNULL(SolutionsTable.Amount, 0) - (WriteOffCostsCorrectionNodes.Amount + ISNULL(TemporaryTableSolutions.Amount, 0))) * (ISNULL(SolutionsTable.Amount, 0) - (WriteOffCostsCorrectionNodes.Amount + ISNULL(TemporaryTableSolutions.Amount, 0)))) AS AmountOfSquaresOfRejections
		|FROM
		|	InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
		|		LEFT JOIN TemporaryTableSolutions AS TemporaryTableSolutions
		|		ON (TemporaryTableSolutions.NodeNo = WriteOffCostsCorrectionNodes.NodeNo)
		|		LEFT JOIN SolutionsTable AS SolutionsTable
		|		ON (SolutionsTable.NodeNo = WriteOffCostsCorrectionNodes.NodeNo)
		|WHERE
		|	WriteOffCostsCorrectionNodes.Recorder = &Recorder";
		
		ResultsArray = Query.ExecuteBatch();
		Result = ResultsArray[1];
		
		OldRejection = CurrentVariance;
		If Result.IsEmpty() Then
			CurrentVariance = 0; // there are no deviations
		Else
			Selection = Result.Select();
			Selection.Next();
			
			// Determine the current solution variance.
			CurrentVariance = ?(Selection.AmountOfSquaresOfRejections = NULL, 0, Selection.AmountOfSquaresOfRejections);
		EndIf;
		
		Query.Text =
		"DROP SolutionsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WriteOffCostsCorrectionNodes.NodeNo AS NodeNo,
		|	WriteOffCostsCorrectionNodes.Amount + ISNULL(TemporaryTableSolutions.Amount, 0) AS Amount
		|INTO SolutionsTable
		|FROM
		|	InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
		|		LEFT JOIN TemporaryTableSolutions AS TemporaryTableSolutions
		|		ON (TemporaryTableSolutions.NodeNo = WriteOffCostsCorrectionNodes.NodeNo)
		|WHERE
		|	WriteOffCostsCorrectionNodes.Recorder = &Recorder
		|
		|INDEX BY
		|	NodeNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableSolutions";
		
		Query.ExecuteBatch();
		
	EndDo;

	Return True;
	
EndFunction // SolveLES()

// Generates movements on the costs accountitng register.
//
// Parameters:
//  RecordSet - Inventory RecordsSetManagerial
//  register records set - Managerial MovementString accounting
//  register records set - ValueTableRow containing
//                 data for
//  movements on the Amount register        - Number containing
//  the FixedCost movement amount - Boolean - check box of fixed cost.
//
Procedure GenerateRegisterRecordsByExpensesRegister(RecordSet, RecordSetManagerial, RegisterRecordRow, Amount, FixedCost, ContentOfAccountingRecord = Undefined)
	
	If ContentOfAccountingRecord = Undefined Then
		If RegisterRecordRow.GLAccountGLAccountType = Enums.GLAccountsTypes.Inventory Then
			ContentOfAccountingRecord = NStr("en='Write off warehouse inventory';ru='Списание запасов со склада'");
		Else
			If ValueIsFilled(RegisterRecordRow.ProductsAndServices) Then
				ContentOfAccountingRecord = NStr("en='Expense write-off';ru='Списание расходов'");
			Else
				ContentOfAccountingRecord = NStr("en='Inventory write-off from Production';ru='Списание запасов из производства'");
			EndIf;
		EndIf;
	EndIf;
	
	// Expense by the register Inventory and costs accounting.
	NewRow = RecordSet.Add();
	FillPropertyValues(NewRow, RegisterRecordRow);
	NewRow.RecordType = AccumulationRecordType.Expense;
	NewRow.Period = ?(ValueIsFilled(NewRow.Period), NewRow.Period, Date); // period will be filled in for returns, this is required for FIFO
	NewRow.Recorder = Ref;
	NewRow.FixedCost = FixedCost;
	NewRow.Quantity = 0;
	NewRow.Amount = Amount;
	NewRow.ContentOfAccountingRecord = ContentOfAccountingRecord;
	
	If RegisterRecordRow.CorrGLAccount = AdditionalProperties.ForPosting.EmptyAccount Then
		Return;
	EndIf;
	
	If RegisterRecordRow.CorrAccountFinancialAccountType = Enums.GLAccountsTypes.Inventory Then
		ContentOfAccountingRecord = NStr("en='Inventory capitalization to warehouse';ru='Оприходование запасов на склад'");
	Else
		If ValueIsFilled(RegisterRecordRow.ProductsAndServices) Then
			ContentOfAccountingRecord = NStr("en='Expense receipt';ru='Поступление расходов'");
		Else
			ContentOfAccountingRecord = NStr("en='Inventory capitalization in production';ru='Оприходование запасов в производство'");
		EndIf;
	EndIf;
		
	// Receipt by the register Inventory and costs accounting.
	NewRow = RecordSet.Add();
	NewRow.RecordType = AccumulationRecordType.Receipt;
	NewRow.Period = Date;
	NewRow.Recorder = Ref;
	NewRow.Company = RegisterRecordRow.Company;
	NewRow.StructuralUnit = RegisterRecordRow.StructuralUnitCorr;
	NewRow.GLAccount = RegisterRecordRow.CorrGLAccount;
	NewRow.ProductsAndServices = RegisterRecordRow.ProductsAndServicesCorr;
	NewRow.Characteristic = RegisterRecordRow.CharacteristicCorr;
	NewRow.Batch = RegisterRecordRow.BatchCorr;
	NewRow.CustomerOrder = RegisterRecordRow.CustomerCorrOrder;	
	NewRow.Specification = RegisterRecordRow.SpecificationCorr;
	NewRow.SpecificationCorr = RegisterRecordRow.Specification;
	NewRow.StructuralUnitCorr = RegisterRecordRow.StructuralUnit;
	NewRow.CorrGLAccount = RegisterRecordRow.GLAccount;
	NewRow.ProductsAndServicesCorr = RegisterRecordRow.ProductsAndServices;
	NewRow.CharacteristicCorr = RegisterRecordRow.Characteristic;
	NewRow.BatchCorr = RegisterRecordRow.Batch;
	NewRow.CustomerCorrOrder = RegisterRecordRow.CustomerOrder;
	NewRow.FixedCost = FixedCost;
	NewRow.Amount = Amount;
	NewRow.ContentOfAccountingRecord = ContentOfAccountingRecord;
	
	// Movements by register Managerial.
	NewRow = RecordSetManagerial.Add();
	NewRow.Period = Date;
	NewRow.Recorder = Ref;
	NewRow.Company = RegisterRecordRow.Company;
	NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
	NewRow.AccountDr = RegisterRecordRow.CorrGLAccount;
	NewRow.AccountCr = RegisterRecordRow.GLAccount;
	NewRow.Amount = Amount; 
	NewRow.Content = ContentOfAccountingRecord;
	
EndProcedure // GenerateMovementsByExpensesAccountingRegister()

// Generates correcting movements on the expenses accounting register.
//
// Parameters:
//  No.
//
Procedure GenerateCorrectiveRegisterRecordsByExpensesRegister()
	
	DateBeg = AdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = AdditionalProperties.ForPosting.EndDatePeriod;
	
	Query = New Query();
	
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOff,
	|	CASE
	|		WHEN CostAccounting.RetailTransferAccrualAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.SupplierInvoice)
	|						THEN CostAccounting.SalesDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|						THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS RetailStructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOffAccountType,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.BusinessActivity
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	CostAccounting.Company AS Company,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SalesDocument.StructuralUnit
	|	END AS StructuralUnitPayee,
	|	CostAccounting.GLAccount AS GLAccount,
	|	CostAccounting.ProductsAndServices AS ProductsAndServices,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.CustomerOrder AS CustomerOrder,
	|	CostAccounting.Specification AS Specification,
	|	CostAccounting.SpecificationCorr AS SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount AS CorrGLAccount,
	|	CostAccounting.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.CustomerCorrOrder AS CustomerCorrOrder,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Quantity
	|			ELSE -CostAccounting.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Amount
	|			ELSE -CostAccounting.Amount
	|		END) AS Amount,
	|	CostAccounting.ProductsAndServices.ProductsAndServicesCategory AS ProductsAndServicesProductsAndServicesCategory,
	|	CostAccounting.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS BusinessActivitySalesGLAccountOfSalesCost,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales.TypeOfAccount AS BusinessActivitySalesSalesCostGLAccountAccountType,
	|	CostAccounting.SalesDocument AS SalesDocument,
	|	CostAccounting.OrderSales AS OrderSales,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CostAccounting.RetailTransferAccrualAccounting AS RetailTransferAccrualAccounting
	|INTO CostAccountingWriteOff
	|FROM
	|	AccumulationRegister.Inventory AS CostAccounting
	|WHERE
	|	CostAccounting.Period between &DateBeg AND &DateEnd
	|	AND (CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				AND Not CostAccounting.Return
	|			OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				AND CostAccounting.Return)
	|	AND CostAccounting.Company = &Company
	|	AND Not CostAccounting.FixedCost
	|
	|GROUP BY
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN CostAccounting.RetailTransferAccrualAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.SupplierInvoice)
	|						THEN CostAccounting.SalesDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|						THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.BusinessActivity
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.Company,
	|	CostAccounting.StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SalesDocument.StructuralUnit
	|	END,
	|	CostAccounting.GLAccount,
	|	CostAccounting.ProductsAndServices,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.CustomerOrder,
	|	CostAccounting.Specification,
	|	CostAccounting.SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount,
	|	CostAccounting.ProductsAndServicesCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.CustomerCorrOrder,
	|	CostAccounting.ProductsAndServices.ProductsAndServicesCategory,
	|	CostAccounting.ProductsAndServices.BusinessActivity,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales.TypeOfAccount,
	|	CostAccounting.SalesDocument,
	|	CostAccounting.OrderSales,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CostAccounting.RetailTransferAccrualAccounting
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	CustomerOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WriteOffCostsCorrectionNodes.Company AS Company,
	|	WriteOffCostsCorrectionNodes.StructuralUnit AS StructuralUnit,
	|	CostAccounting.StructuralUnitPayee AS StructuralUnitPayee,
	|	WriteOffCostsCorrectionNodes.GLAccount AS GLAccount,
	|	WriteOffCostsCorrectionNodes.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	WriteOffCostsCorrectionNodes.ProductsAndServices AS ProductsAndServices,
	|	WriteOffCostsCorrectionNodes.Characteristic AS Characteristic,
	|	WriteOffCostsCorrectionNodes.Batch AS Batch,
	|	WriteOffCostsCorrectionNodes.CustomerOrder AS CustomerOrder,
	|	WriteOffCostsCorrectionNodes.NodeNo AS NodeNo,
	|	CostAccounting.Specification AS Specification,
	|	CostAccounting.SpecificationCorr AS SpecificationCorr,
	|	CostAccounting.GLAccountWriteOff AS GLAccountWriteOff,
	|	CostAccounting.GLAccountWriteOffAccountType AS GLAccountWriteOffAccountType,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount AS CorrGLAccount,
	|	CostAccounting.CorrGLAccount.TypeOfAccount AS CorrAccountFinancialAccountType,
	|	CostAccounting.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.CustomerCorrOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN ISNULL(CostAccounting.Quantity, 0) = 0
	|			THEN ISNULL(CostAccounting.Amount, 0)
	|		ELSE ISNULL(CostAccounting.Quantity, 0)
	|	END AS Quantity,
	|	ISNULL(CostAccounting.Amount, 0) AS Amount,
	|	ISNULL(SolutionsTable.Amount, 0) AS Price,
	|	CostAccounting.ProductsAndServicesProductsAndServicesCategory AS ProductsAndServicesProductsAndServicesCategory,
	|	CostAccounting.BusinessActivitySales AS BusinessActivitySales,
	|	CostAccounting.BusinessActivitySalesGLAccountOfSalesCost AS BusinessActivitySalesGLAccountOfSalesCost,
	|	CostAccounting.BusinessActivitySalesSalesCostGLAccountAccountType AS BusinessActivitySalesSalesCostGLAccountAccountType,
	|	CostAccounting.SalesDocument AS SalesDocument,
	|	CostAccounting.OrderSales AS OrderSales,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CostAccounting.ActivityDirectionWriteOff AS ActivityDirectionWriteOff,
	|	CostAccounting.RetailTransferAccrualAccounting AS RetailTransferAccrualAccounting,
	|	CostAccounting.RetailStructuralUnit AS RetailStructuralUnit
	|FROM
	|	InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
	|		LEFT JOIN CostAccountingWriteOff AS CostAccounting
	|		ON WriteOffCostsCorrectionNodes.Company = CostAccounting.Company
	|			AND WriteOffCostsCorrectionNodes.StructuralUnit = CostAccounting.StructuralUnit
	|			AND WriteOffCostsCorrectionNodes.GLAccount = CostAccounting.GLAccount
	|			AND WriteOffCostsCorrectionNodes.ProductsAndServices = CostAccounting.ProductsAndServices
	|			AND WriteOffCostsCorrectionNodes.Characteristic = CostAccounting.Characteristic
	|			AND WriteOffCostsCorrectionNodes.Batch = CostAccounting.Batch
	|			AND WriteOffCostsCorrectionNodes.CustomerOrder = CostAccounting.CustomerOrder
	|		LEFT JOIN SolutionsTable AS SolutionsTable
	|		ON (SolutionsTable.NodeNo = WriteOffCostsCorrectionNodes.NodeNo)
	|WHERE
	|	WriteOffCostsCorrectionNodes.Recorder = &Recorder
	|
	|ORDER BY
	|	NodeNo DESC";
	
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", DateBeg);
	Query.SetParameter("DateEnd", DateEnd);
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.ExecuteBatch();
	
	If Result[1].IsEmpty() Then
		Return;
	EndIf;
	
	// Create the accumulation register records set Inventory and expenses accounting.
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set Sales.
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set IncomeAndExpensesAccounting.
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set RetailAmountAccounting.
	RecordSetRetailAmountAccounting = AccumulationRegisters.RetailAmountAccounting.CreateRecordSet();
	RecordSetRetailAmountAccounting.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set Managerial.
	RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
	RecordSetManagerial.Filter.Recorder.Set(Ref);
	
	SelectionDetailRecords = Result[1].Select();
	
	While SelectionDetailRecords.Next() Do
		
		// Calculate amounts of transfer and correction.
		SumOfMovement = SelectionDetailRecords.Price * SelectionDetailRecords.Quantity;
		CorrectionAmount = SumOfMovement - SelectionDetailRecords.Amount;
		
		If Round(CorrectionAmount, 2) <> 0 Then
			
			// Movements on the register Inventory and costs accounting.
			GenerateRegisterRecordsByExpensesRegister(
				RecordSetInventory,
				RecordSetManagerial,
				SelectionDetailRecords,
				CorrectionAmount,
				False
			);
			
			If SelectionDetailRecords.CorrGLAccount = AdditionalProperties.ForPosting.EmptyAccount Then
				
				If ValueIsFilled(SelectionDetailRecords.SalesDocument)
				   AND ((TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.CustomerInvoice")
					 AND SelectionDetailRecords.SalesDocument.OperationKind <> Enums.OperationKindsCustomerInvoice.ReturnToVendor)
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.RetailReport")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.AcceptanceCertificate")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.AgentReport")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.CustomerOrder")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.ProcessingReport")) Then
					
					// Movements on the register Sales.
					NewRow = RecordSetSales.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.CustomerOrder = SelectionDetailRecords.OrderSales;
					NewRow.Department = SelectionDetailRecords.Department;
					NewRow.Responsible = SelectionDetailRecords.Responsible;
					NewRow.ProductsAndServices = SelectionDetailRecords.ProductsAndServices;
					NewRow.Characteristic = SelectionDetailRecords.Characteristic;
					NewRow.Batch = SelectionDetailRecords.Batch;
					NewRow.Document = SelectionDetailRecords.SalesDocument;
					NewRow.VATRate = SelectionDetailRecords.VATRate;
					NewRow.Cost = CorrectionAmount;
					
					// Movements on the register IncomeAndExpenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.Department;
					NewRow.CustomerOrder = SelectionDetailRecords.OrderSales;
					NewRow.BusinessActivity = SelectionDetailRecords.BusinessActivitySales;
					NewRow.GLAccount = SelectionDetailRecords.BusinessActivitySalesGLAccountOfSalesCost;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en='Record expenses';ru='Отражение расходов'");
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.BusinessActivitySalesGLAccountOfSalesCost;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Record expenses';ru='Отражение расходов'");
					NewRow.Amount = CorrectionAmount;
					
				ElsIf ValueIsFilled(SelectionDetailRecords.SalesDocument)
						AND TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.CustomerInvoice")
						AND SelectionDetailRecords.SalesDocument.OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor Then
						
					// Movements on the register Income and expenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = AdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = Undefined;
					NewRow.CustomerOrder = Undefined;
					NewRow.BusinessActivity = Catalogs.BusinessActivities.Other;
					
					If CorrectionAmount < 0 Then
						NewRow.GLAccount = ChartsOfAccounts.Managerial.OtherExpenses;
						NewRow.AmountExpense = CorrectionAmount;
						NewRow.ContentOfAccountingRecord = NStr("en='Other costs (expenses)';ru='Прочих затраты (расходы)'");
					Else
						NewRow.GLAccount = ChartsOfAccounts.Managerial.OtherIncome;
						NewRow.AmountIncome = CorrectionAmount;
						NewRow.ContentOfAccountingRecord = NStr("en='Other income';ru='Прочие доходы'");
					EndIf;
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					
					If CorrectionAmount < 0 Then
						NewRow.AccountDr = ChartsOfAccounts.Managerial.OtherExpenses;
						NewRow.AccountCr = SelectionDetailRecords.GLAccount;
						NewRow.Amount = - CorrectionAmount;
						NewRow.Content = NStr("en='Other costs (expenses)';ru='Прочих затраты (расходы)'");
					Else
						NewRow.AccountDr = SelectionDetailRecords.GLAccount;
						NewRow.AccountCr = ChartsOfAccounts.Managerial.OtherIncome;
						NewRow.Amount = CorrectionAmount;
						NewRow.Content = NStr("en='Other income';ru='Прочие доходы'");
					EndIf;
					
				ElsIf SelectionDetailRecords.RetailTransferAccrualAccounting Then
					
					// Movements on the register RetailAmountAccounting.
					NewRow = RecordSetRetailAmountAccounting.Add();
					NewRow.Period = Date;
					NewRow.RecordType = AccumulationRecordType.Receipt;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.RetailStructuralUnit;
					NewRow.Currency = SelectionDetailRecords.RetailStructuralUnit.RetailPriceKind.PriceCurrency;
					NewRow.ContentOfAccountingRecord = NStr("en='Move to retail';ru='Перемещение в розницу'");
					NewRow.Cost = CorrectionAmount;
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.RetailStructuralUnit.GLAccountInRetail;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Move to retail';ru='Перемещение в розницу'");
					NewRow.Amount = CorrectionAmount; 
					
				ElsIf SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.OtherExpenses
					  OR SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
					
					// Movements on the register Income and expenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = AdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnitPayee;
					
					If TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.InventoryTransfer")
					   AND SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
						NewRow.BusinessActivity = SelectionDetailRecords.ActivityDirectionWriteOff;
						NewRow.CustomerOrder = SelectionDetailRecords.CustomerOrder;
					Else
						NewRow.BusinessActivity = Catalogs.BusinessActivities.Other;
					EndIf;
					
					NewRow.GLAccount = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en='Other costs (expenses)';ru='Прочих затраты (расходы)'");
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Other costs (expenses)';ru='Прочих затраты (расходы)'");
					NewRow.Amount = CorrectionAmount;
					
				Else
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Inventory write-off to arbitrary account';ru='Списание запасов на произвольный счет'");
					NewRow.Amount = CorrectionAmount;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Write the rest of the records Inventory and expenses accounting.
	RecordSetInventory.Write(False);
	
	// Write the rest of the records Sales.
	RecordSetSales.Write(False);
	
	// Write the rest of the records Income and expenses accounting.
	RecordSetIncomeAndExpenses.Write(False);
	
	// Write the rest of the records Retail amount accounting.
	RecordSetRetailAmountAccounting.Write(False);
	
	// Write the rest of the records Managerial.
	RecordSetManagerial.Write(False);
	
EndProcedure // GenerateCorrectiveMovementsByExpensesAccountingRegister()

// Procedure of hung amounts distribution without quantity (rounding errors while solving SLU).
//
//
Procedure DistributeAmountsWithoutQuantity(OperationKind, ErrorsTable)
	
	ListOfProcessedNodes = New Array();
	ListOfProcessedNodes.Add("");
	
	DateBeg = AdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = AdditionalProperties.ForPosting.EndDatePeriod;
	
	Query = New Query();
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	// Movements table is being prepared.
	Query.Text =
	"SELECT
	|	CostAccounting.Company AS Company,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CostAccounting.GLAccount AS GLAccount,
	|	CostAccounting.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	CostAccounting.ProductsAndServices AS ProductsAndServices,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.CustomerOrder AS CustomerOrder,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount AS CorrGLAccount,
	|	CostAccounting.CorrGLAccount.TypeOfAccount AS CorrAccountFinancialAccountType,
	|	CostAccounting.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.CustomerCorrOrder AS CustomerCorrOrder,
	|	CostAccounting.SalesDocument AS SalesDocument,
	|	CostAccounting.OrderSales AS OrderSales,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOff,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOffAccountType,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.BusinessActivity
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SalesDocument.StructuralUnit
	|	END AS StructuralUnitPayee,
	|	CASE
	|		WHEN CostAccounting.RetailTransferAccrualAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.SupplierInvoice)
	|						THEN CostAccounting.SalesDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|						THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS RetailStructuralUnit,
	|	CostAccounting.RetailTransferAccrualAccounting AS RetailTransferAccrualAccounting,
	|	CostAccounting.ProductsAndServices.ProductsAndServicesCategory AS ProductsAndServicesProductsAndServicesCategory,
	|	CostAccounting.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS BusinessActivitySalesGLAccountOfSalesCost,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales.TypeOfAccount AS BusinessActivitySalesSalesCostGLAccountAccountType,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND Not CostAccounting.Return
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND CostAccounting.Return
	|				THEN CostAccounting.Amount
	|			ELSE 0
	|		END) AS Amount
	|INTO CostAccountingExpenseRecordsRegister
	|FROM
	|	AccumulationRegister.Inventory AS CostAccounting
	|WHERE
	|	CostAccounting.Period between &DateBeg AND &DateEnd
	|	AND CostAccounting.Company = &Company
	|	AND Not CostAccounting.FixedCost
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.GLAccount,
	|	CostAccounting.ProductsAndServices,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.CustomerOrder,
	|	CostAccounting.StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount,
	|	CostAccounting.ProductsAndServicesCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.CustomerCorrOrder,
	|	CostAccounting.SalesDocument,
	|	CostAccounting.OrderSales,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SalesDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.BusinessActivity
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SalesDocument.StructuralUnit
	|	END,
	|	CASE
	|		WHEN CostAccounting.RetailTransferAccrualAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.SupplierInvoice)
	|						THEN CostAccounting.SalesDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SalesDocument) = Type(Document.InventoryTransfer)
	|						THEN CostAccounting.SalesDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.RetailTransferAccrualAccounting,
	|	CostAccounting.ProductsAndServices.ProductsAndServicesCategory,
	|	CostAccounting.ProductsAndServices.BusinessActivity,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales,
	|	CostAccounting.ProductsAndServices.BusinessActivity.GLAccountCostOfSales.TypeOfAccount,
	|	CostAccounting.GLAccount.TypeOfAccount,
	|	CostAccounting.CorrGLAccount.TypeOfAccount
	|
	|INDEX BY
	|	StructuralUnit,
	|	GLAccount,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	CustomerOrder,
	|	StructuralUnitCorr,
	|	CorrGLAccount,
	|	ProductsAndServicesCorr,
	|	CharacteristicCorr,
	|	BatchCorr,
	|	CustomerCorrOrder";
	
	Query.SetParameter("DateBeg", DateBeg);
	Query.SetParameter("DateEnd", DateEnd);
	
	Query.Execute();
	
	// Writeoff directions of all amounts less than a ruble are
	// determined for nodes by which there is balance by amounts and without quantity.
	Query.Text =
	"SELECT DISTINCT
	|	""DistributeAmountsWithoutQuantity"" AS Field1,
	|	AccountingCostBalance.Company AS Company,
	|	AccountingCostBalance.StructuralUnit AS StructuralUnit,
	|	AccountingCostBalance.GLAccount AS GLAccount,
	|	AccountingCostBalance.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	AccountingCostBalance.ProductsAndServices AS ProductsAndServices,
	|	AccountingCostBalance.Characteristic AS Characteristic,
	|	AccountingCostBalance.Batch AS Batch,
	|	AccountingCostBalance.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN AccountingCostBalance.QuantityBalance = 0
	|				AND NestedSelect.Amount <> 0
	|				AND (AccountingCostBalance.AmountBalance between -1 AND 1
	|					OR AccountingCostBalance.ProductsAndServices <> VALUE(Catalog.ProductsAndServices.EmptyRef))
	|			THEN AccountingCostBalance.AmountBalance
	|		ELSE 0
	|	END AS Amount,
	|	NestedSelect.StructuralUnitCorr AS StructuralUnitCorr,
	|	UNDEFINED AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	NestedSelect.CorrGLAccount AS CorrGLAccount,
	|	NestedSelect.CorrAccountFinancialAccountType AS CorrAccountFinancialAccountType,
	|	NestedSelect.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	NestedSelect.CharacteristicCorr AS CharacteristicCorr,
	|	NestedSelect.BatchCorr AS BatchCorr,
	|	NestedSelect.CustomerCorrOrder AS CustomerCorrOrder,
	|	NestedSelect.SalesDocument AS SalesDocument,
	|	NestedSelect.OrderSales AS OrderSales,
	|	NestedSelect.Department AS Department,
	|	NestedSelect.Responsible AS Responsible,
	|	NestedSelect.VATRate AS VATRate,
	|	NestedSelect.ProductionExpenses AS ProductionExpenses,
	|	NestedSelect.ProductsAndServicesProductsAndServicesCategory AS ProductsAndServicesProductsAndServicesCategory,
	|	NestedSelect.BusinessActivitySales AS BusinessActivitySales,
	|	NestedSelect.ActivityDirectionWriteOff AS ActivityDirectionWriteOff,
	|	NestedSelect.BusinessActivitySalesGLAccountOfSalesCost AS BusinessActivitySalesGLAccountOfSalesCost,
	|	NestedSelect.BusinessActivitySalesSalesCostGLAccountAccountType AS BusinessActivitySalesSalesCostGLAccountAccountType,
	|	WriteOffCostsCorrectionNodes.NodeNo AS NodeNo,
	|	CostAdjustmentsNodesWriteOffSource.NodeNo AS NumberNodeSource,
	|	NestedSelect.GLAccountWriteOff AS GLAccountWriteOff,
	|	NestedSelect.GLAccountWriteOffAccountType AS GLAccountWriteOffAccountType,
	|	NestedSelect.StructuralUnitPayee AS StructuralUnitPayee,
	|	NestedSelect.RetailTransferAccrualAccounting AS RetailTransferAccrualAccounting,
	|	NestedSelect.RetailStructuralUnit AS RetailStructuralUnit,
	|	AccountingCostBalanceCorr.QuantityBalance AS QuantityBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(&BoundaryDateEnd, Company = &Company) AS AccountingCostBalance
	|		LEFT JOIN CostAccountingExpenseRecordsRegister AS NestedSelect
	|			LEFT JOIN AccumulationRegister.Inventory.Balance(&BoundaryDateEnd, ) AS AccountingCostBalanceCorr
	|			ON NestedSelect.Company = AccountingCostBalanceCorr.Company
	|				AND NestedSelect.StructuralUnitCorr = AccountingCostBalanceCorr.StructuralUnit
	|				AND NestedSelect.CorrGLAccount = AccountingCostBalanceCorr.GLAccount
	|				AND NestedSelect.ProductsAndServicesCorr = AccountingCostBalanceCorr.ProductsAndServices
	|				AND NestedSelect.CharacteristicCorr = AccountingCostBalanceCorr.Characteristic
	|				AND NestedSelect.BatchCorr = AccountingCostBalanceCorr.Batch
	|				AND NestedSelect.CustomerCorrOrder = AccountingCostBalanceCorr.CustomerOrder
	|			LEFT JOIN InformationRegister.WriteOffCostsCorrectionNodes AS WriteOffCostsCorrectionNodes
	|			ON NestedSelect.Company = WriteOffCostsCorrectionNodes.Company
	|				AND NestedSelect.StructuralUnitCorr = WriteOffCostsCorrectionNodes.StructuralUnit
	|				AND NestedSelect.CorrGLAccount = WriteOffCostsCorrectionNodes.GLAccount
	|				AND NestedSelect.ProductsAndServicesCorr = WriteOffCostsCorrectionNodes.ProductsAndServices
	|				AND NestedSelect.CharacteristicCorr = WriteOffCostsCorrectionNodes.Characteristic
	|				AND NestedSelect.BatchCorr = WriteOffCostsCorrectionNodes.Batch
	|				AND NestedSelect.CustomerCorrOrder = WriteOffCostsCorrectionNodes.CustomerOrder
	|				AND (WriteOffCostsCorrectionNodes.Recorder = &Recorder)
	|		ON AccountingCostBalance.Company = NestedSelect.Company
	|			AND AccountingCostBalance.StructuralUnit = NestedSelect.StructuralUnit
	|			AND AccountingCostBalance.GLAccount = NestedSelect.GLAccount
	|			AND AccountingCostBalance.ProductsAndServices = NestedSelect.ProductsAndServices
	|			AND AccountingCostBalance.Characteristic = NestedSelect.Characteristic
	|			AND AccountingCostBalance.Batch = NestedSelect.Batch
	|			AND AccountingCostBalance.CustomerOrder = NestedSelect.CustomerOrder
	|		LEFT JOIN InformationRegister.WriteOffCostsCorrectionNodes AS CostAdjustmentsNodesWriteOffSource
	|		ON (CostAdjustmentsNodesWriteOffSource.Recorder = &Recorder)
	|			AND AccountingCostBalance.Company = CostAdjustmentsNodesWriteOffSource.Company
	|			AND AccountingCostBalance.StructuralUnit = CostAdjustmentsNodesWriteOffSource.StructuralUnit
	|			AND AccountingCostBalance.GLAccount = CostAdjustmentsNodesWriteOffSource.GLAccount
	|			AND AccountingCostBalance.ProductsAndServices = CostAdjustmentsNodesWriteOffSource.ProductsAndServices
	|			AND AccountingCostBalance.Characteristic = CostAdjustmentsNodesWriteOffSource.Characteristic
	|			AND AccountingCostBalance.Batch = CostAdjustmentsNodesWriteOffSource.Batch
	|			AND AccountingCostBalance.CustomerOrder = CostAdjustmentsNodesWriteOffSource.CustomerOrder
	|WHERE
	|	AccountingCostBalance.AmountBalance <> 0
	|	AND AccountingCostBalance.QuantityBalance = 0
	|	AND NestedSelect.Amount <> 0
	|	AND (AccountingCostBalance.AmountBalance between -1 AND 1
	|			OR AccountingCostBalance.ProductsAndServices <> VALUE(Catalog.ProductsAndServices.EmptyRef))
	|	AND AccountingCostBalance.AmountBalance <> 0
	|	AND Not NestedSelect.GLAccount IS NULL 
	|	AND Not ISNULL(CostAdjustmentsNodesWriteOffSource.NodeNo, 0) = ISNULL(WriteOffCostsCorrectionNodes.NodeNo, 0)
	|
	|ORDER BY
	|	QuantityBalance DESC,
	|	CASE
	|		WHEN WriteOffCostsCorrectionNodes.NodeNo IN (&ListOfProcessedNodes)
	|			THEN 0
	|		ELSE 1
	|	END DESC";
	
	Query.SetParameter("BoundaryDateEnd", New Boundary(DateEnd, BoundaryType.Including));
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("ListOfProcessedNodes", ListOfProcessedNodes);
	
	// Create the accumulation register records set Inventory and expenses accounting.
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set Sales.
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set IncomeAndExpensesAccounting.
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set RetailAmountAccounting.
	RecordSetRetailAmountAccounting = AccumulationRegisters.RetailAmountAccounting.CreateRecordSet();
	RecordSetRetailAmountAccounting.Filter.Recorder.Set(Ref);
	
	// Create the accounting register records set RecordsSetManagerial.
	RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
	RecordSetManagerial.Filter.Recorder.Set(Ref);
	
	IterationsQuantity = 0;
	
	Result = Query.Execute();
	
	While Not Result.IsEmpty() Do
		
		IterationsQuantity = IterationsQuantity + 1;
		If IterationsQuantity > 60 Then
			ErrorDescription = NStr("en='Cannot adjust cost balance values.';ru='Не удалось скорректировать суммовые остатки по затратам.'");
			AddErrorIntoTable(ErrorDescription, OperationKind, ErrorsTable);
			Break;
		EndIf;
		
		RecordSetInventory.Clear();
		RecordSetSales.Clear();
		RecordSetIncomeAndExpenses.Clear();
		RecordSetRetailAmountAccounting.Clear();
		RecordSetManagerial.Clear();
		
		SelectionDetailRecords = Result.Select();
		ListOfNodesProcessedSources = New Array();
		
		While SelectionDetailRecords.Next() Do
			
			If ListOfNodesProcessedSources.Find(SelectionDetailRecords.NumberNodeSource) = Undefined Then
				ListOfNodesProcessedSources.Add(SelectionDetailRecords.NumberNodeSource);
			Else
				Continue; // This source is already corrected.
			EndIf;
			
			If ListOfProcessedNodes.Find(SelectionDetailRecords.NodeNo) = Undefined Then
				ListOfProcessedNodes.Add(SelectionDetailRecords.NodeNo);
			EndIf;
			
			CorrectionAmount = SelectionDetailRecords.Amount;
			
			GenerateRegisterRecordsByExpensesRegister(
				RecordSetInventory,
				RecordSetManagerial,
				SelectionDetailRecords,
				CorrectionAmount,
				False,
			);
			
			If SelectionDetailRecords.CorrGLAccount = AdditionalProperties.ForPosting.EmptyAccount Then
				
				If ValueIsFilled(SelectionDetailRecords.SalesDocument)
				   AND ((TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.CustomerInvoice")
					 AND SelectionDetailRecords.SalesDocument.OperationKind <> Enums.OperationKindsCustomerInvoice.ReturnToVendor)
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.RetailReport")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.AcceptanceCertificate")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.AgentReport")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.CustomerOrder")
				  OR TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.ProcessingReport")) Then
					
					// Movements on the register Sales.
					NewRow = RecordSetSales.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.CustomerOrder = SelectionDetailRecords.OrderSales;
					NewRow.Department = SelectionDetailRecords.Department;
					NewRow.Responsible = SelectionDetailRecords.Responsible;
					NewRow.ProductsAndServices = SelectionDetailRecords.ProductsAndServices;
					NewRow.Characteristic = SelectionDetailRecords.Characteristic;
					NewRow.Batch = SelectionDetailRecords.Batch;
					NewRow.Document = SelectionDetailRecords.SalesDocument;
					NewRow.VATRate = SelectionDetailRecords.VATRate;
					NewRow.Cost = CorrectionAmount;
					
					// Movements on the register IncomeAndExpenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.Department;
					NewRow.CustomerOrder = SelectionDetailRecords.OrderSales;
					NewRow.BusinessActivity = SelectionDetailRecords.BusinessActivitySales;
					NewRow.GLAccount = SelectionDetailRecords.BusinessActivitySalesGLAccountOfSalesCost;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en='Record sale expenses';ru='Отражение расходов по продаже'");
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.BusinessActivitySalesGLAccountOfSalesCost;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Record sale expenses';ru='Отражение расходов по продаже'");
					NewRow.Amount = CorrectionAmount;
					
				ElsIf ValueIsFilled(SelectionDetailRecords.SalesDocument)
						AND TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.CustomerInvoice")
						AND SelectionDetailRecords.SalesDocument.OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor Then
						
					// Movements on the register Income and expenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = AdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = Undefined;
					NewRow.CustomerOrder = Undefined;
					NewRow.BusinessActivity = Catalogs.BusinessActivities.Other;
					
					If CorrectionAmount < 0 Then
						NewRow.GLAccount = ChartsOfAccounts.Managerial.OtherExpenses;
						NewRow.AmountExpense = CorrectionAmount;
						NewRow.ContentOfAccountingRecord = NStr("en='Other expenses on return to the supplier';ru='Прочие расходы по возврату поставщику'");
					Else
						NewRow.GLAccount = ChartsOfAccounts.Managerial.OtherIncome;
						NewRow.AmountIncome = CorrectionAmount;
						NewRow.ContentOfAccountingRecord = NStr("en='Other income on return to the supplier';ru='Прочие доходы по возврату поставщику'");
					EndIf;
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					
					If CorrectionAmount < 0 Then
						NewRow.AccountDr = ChartsOfAccounts.Managerial.OtherExpenses;
						NewRow.AccountCr = SelectionDetailRecords.GLAccount;
						NewRow.Amount = - CorrectionAmount;
						NewRow.Content = NStr("en='Other expenses on return to the supplier';ru='Прочие расходы по возврату поставщику'");
					Else
						NewRow.AccountDr = SelectionDetailRecords.GLAccount;
						NewRow.AccountCr = ChartsOfAccounts.Managerial.OtherIncome;
						NewRow.Amount = CorrectionAmount;
						NewRow.Content = NStr("en='Other income on return to the supplier';ru='Прочие доходы по возврату поставщику'");
					EndIf;
					
				ElsIf SelectionDetailRecords.RetailTransferAccrualAccounting Then
					
					// Movements on the register RetailAmountAccounting.
					NewRow = RecordSetRetailAmountAccounting.Add();
					NewRow.Period = Date;
					NewRow.RecordType = AccumulationRecordType.Receipt;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.RetailStructuralUnit;
					NewRow.Currency = SelectionDetailRecords.RetailStructuralUnit.RetailPriceKind.PriceCurrency;
					NewRow.ContentOfAccountingRecord = NStr("en='Move to retail';ru='Перемещение в розницу'");
					NewRow.Cost = CorrectionAmount;
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.RetailStructuralUnit.GLAccountInRetail;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Move to retail';ru='Перемещение в розницу'");
					NewRow.Amount = CorrectionAmount; 
					
				ElsIf SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.OtherExpenses
					  OR SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
					
					// Movements on the register Income and expenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = AdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnitPayee;
					
					If TypeOf(SelectionDetailRecords.SalesDocument) = Type("DocumentRef.InventoryTransfer")
					   AND SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
						NewRow.BusinessActivity = SelectionDetailRecords.ActivityDirectionWriteOff;
						NewRow.CustomerOrder = SelectionDetailRecords.CustomerOrder;
					Else
						NewRow.BusinessActivity = Catalogs.BusinessActivities.Other;
					EndIf;
					
					NewRow.GLAccount = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en='Other costs (expenses)';ru='Прочих затраты (расходы)'");
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Other costs (expenses)';ru='Прочих затраты (расходы)'");
					NewRow.Amount = CorrectionAmount;
					
				Else
					
					// Movements by register Managerial.
					NewRow = RecordSetManagerial.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en='Inventory write-off to arbitrary account';ru='Списание запасов на произвольный счет'");
					NewRow.Amount = CorrectionAmount;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		RecordSetInventory.Write(False);
		RecordSetSales.Write(False);
		RecordSetIncomeAndExpenses.Write(False);
		RecordSetRetailAmountAccounting.Write(False);
		RecordSetManagerial.Write(False);
		
		If IterationsQuantity = 15 OR IterationsQuantity = 30 OR IterationsQuantity = 45 Then
			// Clear processed nodes list.
			ListOfProcessedNodes.Clear();
			ListOfProcessedNodes.Add("");
		EndIf;
		
		Query.SetParameter("ListOfProcessedNodes", ListOfProcessedNodes);
		Result = Query.Execute();
		
	EndDo;
	
	Query.Text = "DROP CostAccountingExpenseRecordsRegister";
	Query.Execute();
	
EndProcedure // AllocateAmountsWithoutCount()

// Corrects expenses accounting writeoff.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure WriteOffCorrectionAccountingCost(OperationKind, ErrorsTable, Cancel)
	
	// Generate states list.
	CountEquationsSLE = MakeRegisterRecordsByRegisterWriteOffCostsCorrectionNodes(Cancel);
	
	If CountEquationsSLE > 0 Then
		
		// Solve SLU and determine the average price in each state.
		SolutionIsFound = SolveLES();
		
		If Not SolutionIsFound Then
			Return;
		EndIf;
		
		// Correct movements by states.
		GenerateCorrectiveRegisterRecordsByExpensesRegister();
		
		// Allocate kopecks left in the states (rounding errors result).
		DistributeAmountsWithoutQuantity(OperationKind, ErrorsTable);
		
	Else
		
		Query = New Query(
			"SELECT
			|	""There are no equations"" AS Field1
			|INTO CostAccounting
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	""There are no equations"" AS Field1
			|INTO CostAccountingReturnsCurPeriod
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	""There are no equations"" AS Field1
			|INTO CostAccountingWriteOff
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	""There are no equations"" AS Field1
			|INTO CostAccountingReturnsOnReserves
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	""There are no equations"" AS Field1
			|INTO CostAccountingReturnsFree
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	""There are no equations"" AS Field1
			|INTO CostAccountingReturns
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	""There are no equations"" AS Field1
			|INTO CostAccountingWithoutReturnAccounting"
		);
		
		Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
		Query.Execute();
		
	EndIf;
	
EndProcedure // WriteOffCorrectionCostsAccounting()

// Procedure corrects the cost of returns from client.
//
Procedure CalculateCostOfReturns()
	
	Query = New Query(
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.ProductsAndServices AS ProductsAndServices,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.CustomerOrder AS CustomerOrder,
	|	Inventory.OrderSales AS OrderSales,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.SalesDocument AS SalesDocument,
	|	Inventory.Department AS Department,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.Responsible AS Responsible,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SalesDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ItsReturnOfLastPeriod,
	|	-SUM(Inventory.Quantity) AS Quantity,
	|	-SUM(Inventory.Amount) AS Amount
	|INTO TtReturns
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period between &BeginOfPeriod AND &EndOfPeriod
	|	AND Inventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Inventory.Return
	|	AND Inventory.Company = &Company
	|	AND Inventory.CorrGLAccount = &EmptyAccount
	|	AND Inventory.SalesDocument <> UNDEFINED
	|
	|GROUP BY
	|	Inventory.Period,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SalesDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.ProductsAndServices,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.CustomerOrder,
	|	Inventory.OrderSales,
	|	Inventory.VATRate,
	|	Inventory.SalesDocument,
	|	Inventory.Department,
	|	Inventory.CorrGLAccount,
	|	Inventory.Responsible
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReturnsTable.Period AS Period,
	|	TRUE AS Return,
	|	&Company AS Company,
	|	ReturnsTable.StructuralUnit AS StructuralUnit,
	|	ReturnsTable.GLAccount AS GLAccount,
	|	ReturnsTable.ProductsAndServices AS ProductsAndServices,
	|	ReturnsTable.ProductsAndServices.BusinessActivity AS BusinessActivitySales,
	|	ReturnsTable.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS BusinessActivitySalesGLAccountOfSalesCost,
	|	ReturnsTable.Characteristic AS Characteristic,
	|	ReturnsTable.Batch AS Batch,
	|	ReturnsTable.CustomerOrder AS CustomerOrder,
	|	ReturnsTable.OrderSales AS OrderSales,
	|	ReturnsTable.Quantity AS ReturnQuantity,
	|	ReturnsTable.Amount AS AmountOfRefunds,
	|	ReturnsTable.SalesDocument AS SalesDocument,
	|	ReturnsTable.Department AS Department,
	|	ReturnsTable.VATRate AS VATRate,
	|	ReturnsTable.Responsible AS Responsible,
	|	ReturnsTable.ItsReturnOfLastPeriod AS ItsReturnOfLastPeriod,
	|	&EmptyAccount AS CorrGLAccount,
	|	SUM(TableSales.Quantity) AS SalesQuantity,
	|	SUM(TableSales.Amount) AS SalesAmount
	|FROM
	|	TtReturns AS ReturnsTable
	|		LEFT JOIN AccumulationRegister.Inventory AS TableSales
	|		ON ReturnsTable.ProductsAndServices = TableSales.ProductsAndServices
	|			AND ReturnsTable.Characteristic = TableSales.Characteristic
	|			AND ReturnsTable.Batch = TableSales.Batch
	|			AND ReturnsTable.OrderSales = TableSales.OrderSales
	|			AND (TableSales.Company = &Company)
	|			AND ReturnsTable.SalesDocument = TableSales.SalesDocument
	|			AND ReturnsTable.GLAccount = TableSales.GLAccount
	|			AND ReturnsTable.VATRate = TableSales.VATRate
	|			AND (TableSales.CorrGLAccount = &EmptyAccount)
	|			AND (TableSales.RecordType = VALUE(AccumulationRecordType.Expense))
	|			AND (NOT TableSales.Return)
	|
	|GROUP BY
	|	ReturnsTable.Period,
	|	ReturnsTable.StructuralUnit,
	|	ReturnsTable.GLAccount,
	|	ReturnsTable.ProductsAndServices,
	|	ReturnsTable.Characteristic,
	|	ReturnsTable.Batch,
	|	ReturnsTable.CustomerOrder,
	|	ReturnsTable.OrderSales,
	|	ReturnsTable.Quantity,
	|	ReturnsTable.Amount,
	|	ReturnsTable.SalesDocument,
	|	ReturnsTable.Department,
	|	ReturnsTable.VATRate,
	|	ReturnsTable.Responsible,
	|	ReturnsTable.ItsReturnOfLastPeriod,
	|	ReturnsTable.ProductsAndServices.BusinessActivity,
	|	ReturnsTable.ProductsAndServices.BusinessActivity.GLAccountCostOfSales
	|
	|HAVING
	|	(CAST(SUM(TableSales.Amount) - ReturnsTable.Amount AS NUMBER(15, 2))) <> 0");
	
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("EmptyAccount", AdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("BeginOfPeriod", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndOfPeriod", AdditionalProperties.ForPosting.EndDatePeriod);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	// Cost correction.
	
	// Create the accumulation register records set Inventory and expenses accounting.
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set Sales.
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set IncomeAndExpensesAccounting.
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set Managerial.
	RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
	RecordSetManagerial.Filter.Recorder.Set(Ref);
	
	SelectionDetailRecords = Result.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.SalesQuantity = 0 Then
			CorrectionAmount = 0;
		Else
			SalePrice = SelectionDetailRecords.SalesAmount / SelectionDetailRecords.SalesQuantity;
			AmountOfRefunds = SalePrice * SelectionDetailRecords.ReturnQuantity;
			CorrectionAmount = SelectionDetailRecords.AmountOfRefunds - SalePrice * SelectionDetailRecords.ReturnQuantity;
		EndIf;
		
		If (NOT Round(CorrectionAmount, 2) = 0) Then
			
			// Movements on the register Inventory and costs accounting.
			GenerateRegisterRecordsByExpensesRegister(
				RecordSetInventory,
				RecordSetManagerial,
				SelectionDetailRecords,
				CorrectionAmount,
				SelectionDetailRecords.IsPastPeriodReturn, // returns of the last year period by the fixed cost
				NStr("en='Cost of return from customer';ru='Себестоимость возврата от покупателя'")
			);
			
			// Movements on the register Sales.
			NewRow = RecordSetSales.Add();
			NewRow.Period = Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionDetailRecords.Company;
			NewRow.CustomerOrder = SelectionDetailRecords.OrderSales;
			NewRow.Department = SelectionDetailRecords.Department;
			NewRow.Responsible = SelectionDetailRecords.Responsible;
			NewRow.ProductsAndServices = SelectionDetailRecords.ProductsAndServices;
			NewRow.Characteristic = SelectionDetailRecords.Characteristic;
			NewRow.Batch = SelectionDetailRecords.Batch;
			NewRow.Document = SelectionDetailRecords.SalesDocument;
			NewRow.VATRate = SelectionDetailRecords.VATRate;
			NewRow.Cost = CorrectionAmount;
			
			// Movements on the register IncomeAndExpenses.
			NewRow = RecordSetIncomeAndExpenses.Add();
			NewRow.Period = Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionDetailRecords.Company;
			NewRow.StructuralUnit = SelectionDetailRecords.Department;
			NewRow.CustomerOrder = SelectionDetailRecords.OrderSales;
			NewRow.BusinessActivity = SelectionDetailRecords.BusinessActivitySales;
			NewRow.GLAccount = SelectionDetailRecords.BusinessActivitySalesGLAccountOfSalesCost;
			NewRow.AmountExpense = CorrectionAmount;
			NewRow.ContentOfAccountingRecord = NStr("en='Record expenses';ru='Отражение расходов'");
			
			// Movements by register Managerial.
			NewRow = RecordSetManagerial.Add();
			NewRow.Period = Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionDetailRecords.Company;
			NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr = SelectionDetailRecords.BusinessActivitySalesGLAccountOfSalesCost;
			NewRow.AccountCr = SelectionDetailRecords.GLAccount;
			NewRow.Content = NStr("en='Record expenses';ru='Отражение расходов'");
			NewRow.Amount = CorrectionAmount;
			
		EndIf;
		
	EndDo;
	
	// Write the rest of the records Inventory and expenses accounting.
	RecordSetInventory.Write(False);
	
	// Write the rest of the records Sales.
	RecordSetSales.Write(False);
	
	// Write the rest of the records Income and expenses accounting.
	RecordSetIncomeAndExpenses.Write(False);
	
	// Write the rest of the records Managerial.
	RecordSetManagerial.Write(False);

EndProcedure

// The procedure calculates the release actual primecost.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure CalculateActualOutputCostPrice(Cancel, OperationKind, ErrorsTable)
	
	WriteOffCorrectionAccountingCost(OperationKind, ErrorsTable, Cancel);
	
	// Delete temporary tables.
	Query = New Query();
	Query.Text = "DROP SolutionsTable; DROP CostAccounting; DROP TableNodsOfCorrectionOfCostWriteOffs; DROP BalanceTableBatches; DROP PeriodsOfBatches; DROP CostAccountingReturnsCurPeriod; DROP CostAccountingWriteOff; DROP CostAccountingReturnsOnReserves; DROP CostAccountingReturnsFree; DROP CostAccountingReturns; DROP CostAccountingWithoutReturnAccounting";
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.ExecuteBatch();
	
	// Clear records set WriteOffCostCorrectionNodes.
	RecordSet = InformationRegisters.WriteOffCostsCorrectionNodes.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Ref);
	RecordSet.Write(True);
	
EndProcedure // CalculateActualOutputPrice()

////////////////////////////////////////////////////////////////////////////////
// DISTRIBUTION

// Generates allocation base table.
//
// Parameters:
// DistributionBase - Enums.CostingBases
// GLAccountsArray - Array containing filter by
// GL accounts FilterByStructuralUnit - filer by
// structural units FilterByOrder - Filter by goods orders
//
// Returns:
//  ValuesTable containing allocation base.
//
Function GenerateDistributionBaseTable(DistributionBase, AccountingCountsArray, FilterByStructuralUnit, FilterByOrder) Export
	
	ResultTable = New ValueTable;
	
	Query = New Query;
	
	If DistributionBase = Enums.CostingBases.ProductionVolume Then
		
		QueryText =
		"SELECT
		|	ProductReleaseTurnovers.Company AS Company,
		|	ProductReleaseTurnovers.StructuralUnit AS StructuralUnit,
		|	ProductReleaseTurnovers.ProductsAndServices AS ProductsAndServices,
		|	ProductReleaseTurnovers.Characteristic AS Characteristic,
		|	ProductReleaseTurnovers.Batch AS Batch,
		|	ProductReleaseTurnovers.CustomerOrder AS CustomerOrder,
		|	ProductReleaseTurnovers.Specification AS Specification,
		|	ProductReleaseTurnovers.ProductsAndServices.ExpensesGLAccount AS GLAccount,
		|	ProductReleaseTurnovers.ProductsAndServices.ExpensesGLAccount.TypeOfAccount AS GLAccountGLAccountType,
		|	ProductReleaseTurnovers.QuantityTurnover AS Base
		|FROM
		|	AccumulationRegister.ProductRelease.Turnovers(
		|			&BegDate,
		|			&EndDate,
		|			,
		|			Company = &Company
		|			// FilterByOrder
		|			// FilterByStructuralUnit
		|	) AS ProductReleaseTurnovers
		|WHERE
		|	ProductReleaseTurnovers.Company = &Company
		|	AND ProductReleaseTurnovers.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Department)
		|	AND ProductReleaseTurnovers.ProductsAndServices.ProductsAndServicesType <> VALUE(Enum.ProductsAndServicesTypes.Service)";
		
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And CustomerOrder IN (&OrdersArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND StructuralUnit IN (&StructuralUnitsArray)", ""));
		
	ElsIf DistributionBase = Enums.CostingBases.DirectCost Then
		
		QueryText =
		"SELECT
		|	CostAccounting.Company AS Company,
		|	CostAccounting.StructuralUnit AS StructuralUnit,
		|	UNDEFINED AS ProductsAndServices,
		|	UNDEFINED AS Characteristic,
		|	UNDEFINED AS Batch,
		|	UNDEFINED AS CustomerOrder,
		|	UNDEFINED AS Specification,
		|	CostAccounting.GLAccount AS GLAccount,
		|	CostAccounting.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
		|	CostAccounting.AmountClosingBalance AS Base
		|FROM
		|	AccumulationRegister.Inventory.BalanceAndTurnovers(
		|			&BegDate,
		|			&EndDate,
		|			,
		|			,
		|			Company = &Company
		|				AND GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
		|				AND GLAccount IN (&AccountingCountsArray)
		|			// FilterByStructuralUnitTurnovers
		|			// FilterByOrderTurnovers
		|	) AS CostAccounting
		|
		|UNION ALL
		|
		|SELECT
		|	CostAccounting.Company,
		|	CostAccounting.StructuralUnitCorr,
		|	CostAccounting.ProductsAndServicesCorr,
		|	CostAccounting.CharacteristicCorr,
		|	CostAccounting.BatchCorr,
		|	CostAccounting.CustomerCorrOrder,
		|	CostAccounting.SpecificationCorr,
		|	CostAccounting.CorrGLAccount,
		|	CostAccounting.CorrGLAccount.TypeOfAccount,
		|	SUM(CostAccounting.Amount)
		|FROM
		|	AccumulationRegister.Inventory AS CostAccounting
		|WHERE
		|	CostAccounting.Period between &BegDate AND &EndDate
		|	AND CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
		|	AND CostAccounting.Company = &Company
		|	AND CostAccounting.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
		|	AND CostAccounting.GLAccount IN(&AccountingCountsArray)
		|	AND CostAccounting.ProductionExpenses
		|	// FilterByStructuralUnit
		|	// FilterByOrder
		|
		|GROUP BY
		|	CostAccounting.Company,
		|	CostAccounting.StructuralUnitCorr,
		|	CostAccounting.ProductsAndServicesCorr,
		|	CostAccounting.CharacteristicCorr,
		|	CostAccounting.BatchCorr,
		|	CostAccounting.CustomerCorrOrder,
		|	CostAccounting.SpecificationCorr,
		|	CostAccounting.CorrGLAccount,
		|	CostAccounting.CorrGLAccount.TypeOfAccount";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnitTurnovers", ?(ValueIsFilled(FilterByStructuralUnit), "AND StructuralUnit IN (&StructuralUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrderTurnovers", ?(ValueIsFilled(FilterByOrder), "And CustomerOrder IN (&OrdersArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND CostAccounting.StructuralUnitCorr IN (&StructuralUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And CostAccounting.CorrCustomerOrder IN (&OrdersArray)", ""));
		
		Query.SetParameter("AccountingCountsArray", AccountingCountsArray);
		
	Else
		Return ResultTable;
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	If ValueIsFilled(FilterByOrder) Then
		If TypeOf(FilterByOrder) = Type("Array") Then
			Query.SetParameter("OrdersArray", FilterByOrder);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByOrder);
			Query.SetParameter("OrdersArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByStructuralUnit) Then
		If TypeOf(FilterByStructuralUnit) = Type("Array") Then
			Query.SetParameter("StructuralUnitsArray", FilterByStructuralUnit);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByStructuralUnit);
			Query.SetParameter("StructuralUnitsArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction // GenerateAllocationBaseTable()

// Distributes costs.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure DistributeCosts(Cancel, ErrorsTable)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.StructuralUnit AS StructuralUnit,
	|	InventoryAndCostAccounting.GLAccount AS GLAccount,
	|	InventoryAndCostAccounting.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	InventoryAndCostAccounting.GLAccount.MethodOfDistribution AS GLAccountMethodOfDistribution,
	|	InventoryAndCostAccounting.GLAccount.ClosingAccount AS GLAccountClosingAccount,
	|	InventoryAndCostAccounting.GLAccount.ClosingAccount.TypeOfAccount AS GLAccountClosingAccountAccountType,
	|	InventoryAndCostAccounting.ProductsAndServices AS ProductsAndServices,
	|	InventoryAndCostAccounting.Characteristic AS Characteristic,
	|	InventoryAndCostAccounting.Batch AS Batch,
	|	InventoryAndCostAccounting.CustomerOrder AS CustomerOrder,
	|	InventoryAndCostAccounting.AmountBalance AS Amount
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&EndDate,
	|			Company = &Company
	|				AND GLAccount.MethodOfDistribution <> VALUE(Enum.CostingBases.DoNotDistribute)
	|				AND (GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|					OR GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|						AND ProductsAndServices = VALUE(Catalog.ProductsAndServices.EmptyRef))) AS InventoryAndCostAccounting
	|
	|ORDER BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	CustomerOrder
	|TOTALS
	|	SUM(Amount)
	|BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	CustomerOrder";
	
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.LastBoundaryPeriod);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	// Create the accumulation register records set Inventory and expenses accounting.
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(AdditionalProperties.ForPosting.Ref);
	
	// Create the accumulation register records set Income and expenses accounting.
	RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
	RecordSetManagerial.Filter.Recorder.Set(Ref);
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			BypassByOrder = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			// Bypass on orders.
			While BypassByOrder.Next() Do
				
				FilterByOrder = BypassByOrder.CustomerOrder;
				
				If BypassByOrder.GLAccountMethodOfDistribution = Enums.CostingBases.DoNotDistribute Then
					Continue;
				EndIf;
				
				BypassByGLAccounts = BypassByOrder.Select(QueryResultIteration.ByGroups);
				
				// Bypass on the expenses accounts.
				While BypassByGLAccounts.Next() Do
					
					// Generate allocation base table.
					BaseTable = GenerateDistributionBaseTable(
						BypassByGLAccounts.GLAccountMethodOfDistribution,
						BypassByGLAccounts.GLAccount.GLAccounts.UnloadColumn("GLAccount"),
						FilterByStructuralUnit,
						FilterByOrder
					);
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateDistributionBaseTable(
							BypassByGLAccounts.GLAccountMethodOfDistribution,
							BypassByGLAccounts.GLAccount.GLAccounts.UnloadColumn("GLAccount"),
							Undefined,
							FilterByOrder
						);
					EndIf;
				
					// Check distribution base table.
					If BaseTable.Count() = 0 Then
						ErrorDescription = GenerateErrorDescriptionCostAllocation(
							BypassByGLAccounts.GLAccount,
							BypassByGLAccounts.GLAccountMethodOfDistribution,
							FilterByOrder,
							BypassByGLAccounts.Amount
						);
						AddErrorIntoTable(ErrorDescription, "CostAllocation", ErrorsTable, FilterByOrder);
						Continue;
					EndIf;
					
					TotalBaseDistribution = BaseTable.Total("Base");
					DirectionsQuantity  = BaseTable.Count() - 1;
					
					// Allocate amount.
					If BypassByGLAccounts.Amount <> 0 Then
						
						SumDistribution = BypassByGLAccounts.Amount;
						SumWasDistributed = 0;
					
						For Each DistributionDirection IN BaseTable Do
							
							CostAmount = ?(SumDistribution = 0, 0, Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
							SumWasDistributed = SumWasDistributed + CostAmount;
							
							// If it is the last string - , correct amount in it to the rounding error.
							If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
								CostAmount = CostAmount + SumDistribution - SumWasDistributed;
								SumWasDistributed = SumWasDistributed + CostAmount;
							EndIf;
							
							If CostAmount <> 0 Then
								
								If BypassByGLAccounts.GLAccountGLAccountType = Enums.GLAccountsTypes.IndirectExpenses Then // the indirect ones are allocated via the closing account
								
									RegisterRecordRow = New Structure;
									RegisterRecordRow.Insert("Company"           , BypassByGLAccounts.Company);
									RegisterRecordRow.Insert("StructuralUnit"    , BypassByGLAccounts.StructuralUnit);
									RegisterRecordRow.Insert("GLAccount"             , BypassByGLAccounts.GLAccount);
									RegisterRecordRow.Insert("GLAccountGLAccountType"     , BypassByGLAccounts.GLAccountGLAccountType);
									RegisterRecordRow.Insert("ProductsAndServices"          , BypassByGLAccounts.ProductsAndServices);
									RegisterRecordRow.Insert("Characteristic"        , BypassByGLAccounts.Characteristic);
									RegisterRecordRow.Insert("Batch"                , BypassByGLAccounts.Batch);
									RegisterRecordRow.Insert("CustomerOrder"       , BypassByGLAccounts.CustomerOrder);
									RegisterRecordRow.Insert("StructuralUnitCorr", DistributionDirection.StructuralUnit);
									RegisterRecordRow.Insert("CorrGLAccount"         , BypassByGLAccounts.GLAccountClosingAccount);
									RegisterRecordRow.Insert("CorrAccountFinancialAccountType" , BypassByGLAccounts.GLAccountClosingAccountAccountType);
									RegisterRecordRow.Insert("ProductsAndServicesCorr"      , Catalogs.ProductsAndServices.EmptyRef());
									RegisterRecordRow.Insert("CharacteristicCorr"    , Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
									RegisterRecordRow.Insert("BatchCorr"            , Catalogs.ProductsAndServicesBatches.EmptyRef());
									RegisterRecordRow.Insert("CustomerCorrOrder"   , Documents.CustomerOrder.EmptyRef());
									RegisterRecordRow.Insert("SalesDocument"       , Undefined);
									RegisterRecordRow.Insert("ProductionExpenses"       , False);
									RegisterRecordRow.Insert("Specification"          , Catalogs.Specifications.EmptyRef());
									RegisterRecordRow.Insert("SpecificationCorr"      , Catalogs.Specifications.EmptyRef());
									RegisterRecordRow.Insert("VATRate"             , Catalogs.VATRates.EmptyRef());
									
									// Movements on the register Inventory and costs accounting.
									GenerateRegisterRecordsByExpensesRegister(
										RecordSetInventory,
										RecordSetManagerial,
										RegisterRecordRow,
										CostAmount,
										True
									);
									
									If ValueIsFilled(DistributionDirection.ProductsAndServices) Then
										
										RegisterRecordRow = New Structure;
										RegisterRecordRow.Insert("Company"           , BypassByGLAccounts.Company);
										RegisterRecordRow.Insert("StructuralUnit"    , DistributionDirection.StructuralUnit);
										RegisterRecordRow.Insert("GLAccount"             , BypassByGLAccounts.GLAccountClosingAccount);
										RegisterRecordRow.Insert("GLAccountGLAccountType"     , BypassByGLAccounts.GLAccountClosingAccountAccountType);
										RegisterRecordRow.Insert("ProductsAndServices"          , Catalogs.ProductsAndServices.EmptyRef());
										RegisterRecordRow.Insert("Characteristic"        , Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
										RegisterRecordRow.Insert("Batch"                , Catalogs.ProductsAndServicesBatches.EmptyRef());
										RegisterRecordRow.Insert("CustomerOrder"       , Documents.CustomerOrder.EmptyRef());
										RegisterRecordRow.Insert("StructuralUnitCorr", DistributionDirection.StructuralUnit);
										RegisterRecordRow.Insert("CorrGLAccount"         , DistributionDirection.GLAccount);
										RegisterRecordRow.Insert("CorrAccountFinancialAccountType" , DistributionDirection.GLAccountGLAccountType);
										RegisterRecordRow.Insert("ProductsAndServicesCorr"      , DistributionDirection.ProductsAndServices);
										RegisterRecordRow.Insert("CharacteristicCorr"    , DistributionDirection.Characteristic);
										RegisterRecordRow.Insert("BatchCorr"            , DistributionDirection.Batch);
										RegisterRecordRow.Insert("CustomerCorrOrder"   , DistributionDirection.CustomerOrder);
										RegisterRecordRow.Insert("SalesDocument"       , Undefined);
										RegisterRecordRow.Insert("ProductionExpenses"       , True);
										RegisterRecordRow.Insert("Specification"          , Catalogs.Specifications.EmptyRef());
										RegisterRecordRow.Insert("SpecificationCorr"      , DistributionDirection.Specification);
										RegisterRecordRow.Insert("VATRate"             , Catalogs.VATRates.EmptyRef());
									
										// Movements on the register Inventory and costs accounting.
										GenerateRegisterRecordsByExpensesRegister(
											RecordSetInventory,
											RecordSetManagerial,
											RegisterRecordRow,
											CostAmount,
											True
										);
										
									EndIf;
									
								ElsIf ValueIsFilled(DistributionDirection.ProductsAndServices) Then // allocation of the direct ones
									
									RegisterRecordRow = New Structure;
									RegisterRecordRow.Insert("Company"           , BypassByGLAccounts.Company);
									RegisterRecordRow.Insert("StructuralUnit"    , BypassByGLAccounts.StructuralUnit);
									RegisterRecordRow.Insert("GLAccount"             , BypassByGLAccounts.GLAccount);
									RegisterRecordRow.Insert("GLAccountGLAccountType"     , BypassByGLAccounts.GLAccountGLAccountType);
									RegisterRecordRow.Insert("ProductsAndServices"          , BypassByGLAccounts.ProductsAndServices);
									RegisterRecordRow.Insert("Characteristic"        , BypassByGLAccounts.Characteristic);
									RegisterRecordRow.Insert("Batch"                , BypassByGLAccounts.Batch);
									RegisterRecordRow.Insert("CustomerOrder"       , BypassByGLAccounts.CustomerOrder);
									RegisterRecordRow.Insert("StructuralUnitCorr", DistributionDirection.StructuralUnit);
									RegisterRecordRow.Insert("CorrGLAccount"         , DistributionDirection.GLAccount);
									RegisterRecordRow.Insert("CorrAccountFinancialAccountType" , DistributionDirection.GLAccountGLAccountType);
									RegisterRecordRow.Insert("ProductsAndServicesCorr"      , DistributionDirection.ProductsAndServices);
									RegisterRecordRow.Insert("CharacteristicCorr"    , DistributionDirection.Characteristic);
									RegisterRecordRow.Insert("BatchCorr"            , DistributionDirection.Batch);
									RegisterRecordRow.Insert("CustomerCorrOrder"   , DistributionDirection.CustomerOrder);
									RegisterRecordRow.Insert("SalesDocument"       , Undefined);
									RegisterRecordRow.Insert("ProductionExpenses"       , True);
									RegisterRecordRow.Insert("Specification"          , Catalogs.Specifications.EmptyRef());
									RegisterRecordRow.Insert("SpecificationCorr"      , DistributionDirection.Specification);
									RegisterRecordRow.Insert("VATRate"             , Catalogs.VATRates.EmptyRef());
									
									// Movements on the register Inventory and costs accounting.
									GenerateRegisterRecordsByExpensesRegister(
										RecordSetInventory,
										RecordSetManagerial,
										RegisterRecordRow,
										CostAmount,
										True
									);
									
								EndIf;
								
							EndIf;
							
						EndDo;
						
						If SumWasDistributed = 0 Then
							ErrorDescription = GenerateErrorDescriptionCostAllocation(
								BypassByGLAccounts.GLAccount,
								BypassByGLAccounts.GLAccountMethodOfDistribution,
								FilterByOrder,
								BypassByGLAccounts.Amount
							);
							AddErrorIntoTable(ErrorDescription, "CostAllocation", ErrorsTable, FilterByOrder);
							Continue;
						EndIf;
						
					EndIf
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	// Write the rest of the records Inventory and expenses accounting.
	RecordSetInventory.Write(False);
	
	// Write the rest of the records managerial.
	RecordSetManagerial.Write(False);
	
EndProcedure // AllocateExpenses()

////////////////////////////////////////////////////////////////////////////////
// FINANCIAL RESULT CALCULATION

// Generates allocation base table.
//
// Parameters:
// DistributionBase - Enums.CostingBases
// GLAccountsArray - Array containing filter by
// GL accounts FilterByStructuralUnit - filer by
// structural units FilterByOrder - Filter by goods orders
//
// Returns:
//  ValuesTable containing allocation base.
//
Function GenerateFinancialResultDistributionBaseTable(DistributionBase, FilterByStructuralUnit, FilterByBusinessActivity, FilterByOrder) Export
	
	ResultTable = New ValueTable;
	
	Query = New Query;
	
	If DistributionBase = Enums.CostingBases.SalesRevenue
	 OR DistributionBase = Enums.CostingBases.CostOfGoodsSold
	 OR DistributionBase = Enums.CostingBases.SalesVolume
	 OR DistributionBase = Enums.CostingBases.GrossProfit Then
		
		If DistributionBase = Enums.CostingBases.SalesRevenue Then
			TextOfDatabase = "SalesTurnovers.AmountTurnover";
		ElsIf DistributionBase = Enums.CostingBases.CostOfGoodsSold Then 
			TextOfDatabase = "SalesTurnovers.CostTurnover";
		ElsIf DistributionBase = Enums.CostingBases.GrossProfit Then 
			TextOfDatabase = "SalesTurnovers.AmountTurnover - SalesTurnovers.CostTurnover";
		Else
			TextOfDatabase = "SalesTurnovers.QuantityTurnover";
		EndIf; 
		
		QueryText = 
		"SELECT
		|	SalesTurnovers.Company AS Company,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity AS BusinessActivity,
		|	SalesTurnovers.CustomerOrder AS Order,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	SalesTurnovers.ProductsAndServices.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
		|	// TextOfDatabase AS Base,
		|	SalesTurnovers.Department AS StructuralUnit
		|FROM
		|	AccumulationRegister.Sales.Turnovers(
		|			&BegDate,
		|			&EndDate,
		|			Auto,
		|			Company = &Company
		|				// FilterByStructuralUnit
		|				// FilterByBusinessActivity
		|				// FilterByOrder
		|			) AS SalesTurnovers
		|WHERE
		|	SalesTurnovers.ProductsAndServices.BusinessActivity <> VALUE(Catalog.BusinessActivities.Other)";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND Department IN (&StructuralUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessActivity", ?(ValueIsFilled(FilterByBusinessActivity), "And ProductsAndServices.BusinessActivity IN (&BusinessActivityArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And CustomerOrder IN (&OrdersArray)", ""));
		QueryText = StrReplace(QueryText, "// TextOfDatabase", TextOfDatabase);
		
	Else
		Return ResultTable;
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
		
	If ValueIsFilled(FilterByOrder) Then
		If TypeOf(FilterByOrder) = Type("Array") Then
			Query.SetParameter("OrdersArray", FilterByOrder);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByOrder);
			Query.SetParameter("OrdersArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByStructuralUnit) Then
		If TypeOf(FilterByStructuralUnit) = Type("Array") Then
			Query.SetParameter("StructuralUnitsArray", FilterByStructuralUnit);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByStructuralUnit);
			Query.SetParameter("StructuralUnitsArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByBusinessActivity) Then
		If TypeOf(FilterByBusinessActivity) = Type("Array") Then
			Query.SetParameter("BusinessActivityArray", FilterByBusinessActivity);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByBusinessActivity);
			Query.SetParameter("BusinessActivityArray", FilterByBusinessActivity);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction // GenerateAllocationBaseTable()

// Calculates the financial result.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure CalculateFinancialResult(Cancel, ErrorsTable)
	
	// 1) Direct allocation.
	Query = New Query;
	Query.Text =
	"SELECT
	|	IncomeAndExpencesTurnOvers.Company AS Company,
	|	IncomeAndExpencesTurnOvers.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpencesTurnOvers.BusinessActivity AS BusinessActivity,
	|	IncomeAndExpencesTurnOvers.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
	|	IncomeAndExpencesTurnOvers.CustomerOrder AS Order,
	|	IncomeAndExpencesTurnOvers.GLAccount AS GLAccount,
	|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover AS AmountIncome,
	|	IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS AmountExpense
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&BegDate,
	|			&EndDate,
	|			Auto,
	|			Company = &Company
	|				AND (GLAccount.MethodOfDistribution = VALUE(Enum.CostingBases.DoNotDistribute)
	|					OR (BusinessActivity.GLAccountCostOfSales = GLAccount
	|						OR BusinessActivity.GLAccountRevenueFromSales = GLAccount)
	|						AND BusinessActivity <> VALUE(Catalog.BusinessActivities.Other))) AS IncomeAndExpencesTurnOvers";
	
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.LastBoundaryPeriod);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then

		// Create the accumulation register records set Financial result.
		RecordSetFinancialResult = AccumulationRegisters.FinancialResult.CreateRecordSet();
		RecordSetFinancialResult.Filter.Recorder.Set(AdditionalProperties.ForPosting.Ref);
		
		// Create the accounting register records set "Managerial".
		RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
		RecordSetManagerial.Filter.Recorder.Set(Ref);
		
	EndIf;
	
	SelectionQueryResult = QueryResult.Select();

	While SelectionQueryResult.Next() Do
		
		// Movements by register Financial result.
		NewRow = RecordSetFinancialResult.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.StructuralUnit = SelectionQueryResult.StructuralUnit;
		NewRow.BusinessActivity = ?(
			ValueIsFilled(SelectionQueryResult.BusinessActivity), SelectionQueryResult.BusinessActivity, Catalogs.BusinessActivities.MainActivity
		);
		NewRow.CustomerOrder = SelectionQueryResult.Order;
		NewRow.GLAccount = SelectionQueryResult.GLAccount;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AmountIncome = SelectionQueryResult.AmountIncome;
		ElsIf SelectionQueryResult.AmountExpense <> 0 Then
			NewRow.AmountExpense = SelectionQueryResult.AmountExpense;
		EndIf;
		
		NewRow.ContentOfAccountingRecord = "Financial result";
		
		// Movements by register Managerial.
		NewRow = RecordSetManagerial.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AccountDr = SelectionQueryResult.GLAccount;
			NewRow.AccountCr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessActivity),
				SelectionQueryResult.ProfitGLAccount,
				Catalogs.BusinessActivities.MainActivity.ProfitGLAccount
			);
			NewRow.Amount = SelectionQueryResult.AmountIncome; 
		ElsIf SelectionQueryResult.AmountExpense <> 0 Then
			NewRow.AccountDr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessActivity),
				SelectionQueryResult.ProfitGLAccount,
				Catalogs.BusinessActivities.MainActivity.ProfitGLAccount
			);
			NewRow.AccountCr = SelectionQueryResult.GLAccount;
			NewRow.Amount = SelectionQueryResult.AmountExpense;
		EndIf;
		
		NewRow.Content = "Financial result";
		
	EndDo;
	
	If Not QueryResult.IsEmpty() Then
		
		// Write the rest of the records Financial result.
		RecordSetFinancialResult.Write(False);
		
		// Write the rest of the records Managerial.
		RecordSetManagerial.Write(False);
		
	EndIf;
	
	// 2) Allocation by the allocation base.
	Query.Text =
	"SELECT
	|	IncomeAndExpencesTurnOvers.Company AS Company,
	|	IncomeAndExpencesTurnOvers.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpencesTurnOvers.BusinessActivity AS BusinessActivity,
	|	IncomeAndExpencesTurnOvers.BusinessActivity.ProfitGLAccount AS ProfitGLAccount,
	|	IncomeAndExpencesTurnOvers.CustomerOrder AS Order,
	|	IncomeAndExpencesTurnOvers.GLAccount AS GLAccount,
	|	IncomeAndExpencesTurnOvers.GLAccount.MethodOfDistribution AS GLAccountMethodOfDistribution,
	|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover AS AmountIncome,
	|	IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS AmountExpense
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&BegDate,
	|			&EndDate,
	|			Auto,
	|			Company = &Company
	|				AND GLAccount.MethodOfDistribution <> VALUE(Enum.CostingBases.DoNotDistribute)
	|				AND (BusinessActivity.GLAccountCostOfSales <> GLAccount
	|						AND BusinessActivity.GLAccountRevenueFromSales <> GLAccount
	|					OR BusinessActivity = VALUE(Catalog.BusinessActivities.Other)
	|					OR BusinessActivity = VALUE(Catalog.BusinessActivities.EmptyRef))) AS IncomeAndExpencesTurnOvers
	|
	|ORDER BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	BusinessActivity,
	|	Order
	|TOTALS
	|	SUM(AmountIncome),
	|	SUM(AmountExpense)
	|BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	BusinessActivity,
	|	Order";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		// Create the accumulation register records set Inventory and expenses accounting.
		RecordSetFinancialResult = AccumulationRegisters.FinancialResult.CreateRecordSet();
		RecordSetFinancialResult.Filter.Recorder.Set(AdditionalProperties.ForPosting.Ref);
		
		// Create the accumulation register records set Income and expenses accounting.
		RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
		RecordSetManagerial.Filter.Recorder.Set(Ref);
		
	Else
		
		Return;
		
	EndIf;
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	// Bypass by the allocation methods.
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			
			BypassByActivityDirection = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			// Bypass by the activity directions.
			While BypassByActivityDirection.Next() Do
				
				FilterByBusinessActivity = BypassByActivityDirection.BusinessActivity;
				
				BypassByOrder = BypassByActivityDirection.Select(QueryResultIteration.ByGroups);
				
				// Bypass on orders.
				While BypassByOrder.Next() Do
					
					FilterByOrder = BypassByOrder.Order;
					
					If BypassByOrder.GLAccountMethodOfDistribution = Enums.CostingBases.DoNotDistribute Then
						Continue;
					EndIf;
					
					// Generate allocation base table.
					BaseTable = GenerateFinancialResultDistributionBaseTable(
						BypassByOrder.GLAccountMethodOfDistribution,
						FilterByStructuralUnit,
						Undefined,
						Undefined
					);
					
					If BaseTable.Count() > 0 Then
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							FilterByStructuralUnit,
							FilterByBusinessActivity,
							FilterByOrder
						);
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								FilterByStructuralUnit,
								FilterByBusinessActivity,
								Undefined
							);
						EndIf;
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								FilterByStructuralUnit,
								Undefined,
								Undefined
							);
						EndIf;
						
					Else
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							Undefined,
							FilterByBusinessActivity,
							FilterByOrder
						);
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								Undefined,
								FilterByBusinessActivity,
								Undefined
							);
						EndIf;
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								Undefined,
								Undefined,
								Undefined
							);
						EndIf;
					
					EndIf;
					
					If BaseTable.Count() > 0 Then
						TotalBaseDistribution = BaseTable.Total("Base");
						DirectionsQuantity  = BaseTable.Count() - 1;
					Else
						TotalBaseDistribution = 0;
						DirectionsQuantity  = 0;
					EndIf;
					
					BypassByGLAccounts = BypassByOrder.Select(QueryResultIteration.ByGroups);
					
					// Bypass on the expenses accounts.
					While BypassByGLAccounts.Next() Do
						
						If BaseTable.Count() = 0
						 OR TotalBaseDistribution = 0 Then
							BaseTable = New ValueTable;
							BaseTable.Columns.Add("Company");
							BaseTable.Columns.Add("StructuralUnit");
							BaseTable.Columns.Add("BusinessActivity");
							BaseTable.Columns.Add("Order");
							BaseTable.Columns.Add("GLAccountRevenueFromSales");
							BaseTable.Columns.Add("GLAccountCostOfSales");
							BaseTable.Columns.Add("ProfitGLAccount");
							BaseTable.Columns.Add("Base");
							TableRow = BaseTable.Add();
							TableRow.Company = BypassByGLAccounts.Company;
							TableRow.StructuralUnit = BypassByGLAccounts.StructuralUnit;
							TableRow.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
							TableRow.Order = BypassByGLAccounts.Order;
							TableRow.GLAccountRevenueFromSales = BypassByGLAccounts.GLAccount;
							TableRow.GLAccountCostOfSales = BypassByGLAccounts.GLAccount;
							TableRow.ProfitGLAccount = Catalogs.BusinessActivities.MainActivity.ProfitGLAccount;
							TableRow.Base = 1;
							TotalBaseDistribution = 1;
						EndIf;
						
						// Allocate amount.
						If BypassByGLAccounts.AmountIncome <> 0 
						 OR BypassByGLAccounts.AmountExpense <> 0 Then
							
							If BypassByGLAccounts.AmountIncome <> 0 Then
								SumDistribution = BypassByGLAccounts.AmountIncome;
							ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
								SumDistribution = BypassByGLAccounts.AmountExpense;
							EndIf;
							
							SumWasDistributed = 0;
							
							For Each DistributionDirection IN BaseTable Do
								
								CostAmount = ?(SumDistribution = 0, 0, Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
								SumWasDistributed = SumWasDistributed + CostAmount;
								
								// If it is the last string - , correct amount in it to the rounding error.
								If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
									CostAmount = CostAmount + SumDistribution - SumWasDistributed;
									SumWasDistributed = SumWasDistributed + CostAmount;
								EndIf;
								
								If CostAmount <> 0 Then
									
									// Movements by register Financial result.
									NewRow	= RecordSetFinancialResult.Add();
									NewRow.Period = Date;
									NewRow.Recorder	= Ref;
									NewRow.Company	= DistributionDirection.Company;
									NewRow.StructuralUnit = DistributionDirection.StructuralUnit;
									NewRow.BusinessActivity	= DistributionDirection.BusinessActivity;
									NewRow.CustomerOrder	= DistributionDirection.Order;
									
									NewRow.GLAccount = BypassByGLAccounts.GLAccount;
									If BypassByGLAccounts.AmountIncome <> 0 Then
										NewRow.AmountIncome = CostAmount;
									ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
										NewRow.AmountExpense = CostAmount;
									EndIf;
									
									NewRow.ContentOfAccountingRecord = "Financial result";
									
									// Movements by register Managerial.
									NewRow = RecordSetManagerial.Add();
									NewRow.Period = Date;
									NewRow.Recorder = Ref;
									NewRow.Company = DistributionDirection.Company;
									NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
									
									If BypassByGLAccounts.AmountIncome <> 0 Then
										NewRow.AccountDr = BypassByGLAccounts.GLAccount;
										NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
										NewRow.Amount = CostAmount; 
									ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
										NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
										NewRow.AccountCr = BypassByGLAccounts.GLAccount;
										NewRow.Amount = CostAmount;
									EndIf;
									
									NewRow.Content = "Financial result";
									
								EndIf;
								
							EndDo;
							
							If SumWasDistributed = 0 Then
								
								ErrorDescription = GenerateErrorDescriptionExpensesDistribution(
									BypassByGLAccounts.GLAccount,
									BypassByOrder.GLAccountMethodOfDistribution,
									?(BypassByGLAccounts.AmountIncome <> 0,
										BypassByGLAccounts.AmountIncome,
										BypassByGLAccounts.AmountExpense)
								);
								AddErrorIntoTable(ErrorDescription, "FinancialResultCalculation", ErrorsTable);
								Continue;
								
							EndIf;
							
						EndIf
						
					EndDo;
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	// Write Financial result.
	RecordSetFinancialResult.Write(False);
	RecordSetFinancialResult.Clear();
	
	// Write Managerial.
	RecordSetManagerial.Write(False);
	RecordSetManagerial.Clear();
	
EndProcedure // CalculateFinancialResult()

////////////////////////////////////////////////////////////////////////////////
// PRIMECOST IN RETAIL CALCULATION ACCRUAL ACCOUNTING

Procedure CalculateCostPriceInRetailAccrualAccounting(Cancel, ErrorsTable)
	
	Query = New Query;
	
	Query.SetParameter("DateBeg", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	RetailAmountAccountingTurnovers.Company AS Company,
	|	RetailAmountAccountingTurnovers.StructuralUnit AS StructuralUnit,
	|	RetailAmountAccountingTurnovers.Currency AS Currency,
	|	RetailAmountAccountingTurnovers.AmountCurReceipt AS AmountCurReceipt,
	|	RetailAmountAccountingTurnovers.AmountCurExpense AS AmountCurExpense,
	|	RetailAmountAccountingTurnovers.CostReceipt AS CostReceipt,
	|	RetailAmountAccountingTurnovers.CostExpense AS CostExpense,
	|	CASE
	|		WHEN RetailAmountAccountingTurnovers.AmountCurReceipt <> 0
	|			THEN CAST(RetailAmountAccountingTurnovers.AmountCurExpense * RetailAmountAccountingTurnovers.CostReceipt / RetailAmountAccountingTurnovers.AmountCurReceipt AS NUMBER(15, 2)) - RetailAmountAccountingTurnovers.CostExpense
	|		ELSE 0
	|	END AS TotalCorrectionAmount
	|INTO TemporaryTableCorrectionAmount
	|FROM
	|	AccumulationRegister.RetailAmountAccounting.Turnovers(, &DateEnd, , Company = &Company) AS RetailAmountAccountingTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RetailAmountAccounting.Company AS Company,
	|	RetailAmountAccounting.StructuralUnit AS StructuralUnit,
	|	RetailAmountAccounting.Currency AS Currency,
	|	SUM(RetailAmountAccounting.Cost) AS CostExpense
	|INTO TemporaryTableTotalCostPriceExpense
	|FROM
	|	AccumulationRegister.RetailAmountAccounting AS RetailAmountAccounting
	|WHERE
	|	RetailAmountAccounting.Period between &DateBeg AND &DateEnd
	|	AND RetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND RetailAmountAccounting.Cost <> 0
	|	AND RetailAmountAccounting.Company = &Company
	|	AND RetailAmountAccounting.SalesDocument <> VALUE(Document.CashReceipt.EmptyRef)
	|
	|GROUP BY
	|	RetailAmountAccounting.Company,
	|	RetailAmountAccounting.StructuralUnit,
	|	RetailAmountAccounting.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RetailAmountAccounting.Company AS Company,
	|	RetailAmountAccounting.StructuralUnit AS StructuralUnit,
	|	RetailAmountAccounting.Currency AS Currency,
	|	RetailAmountAccounting.SalesDocument AS SalesDocument,
	|	RetailAmountAccounting.SalesDocument.Department AS DocumentSalesUnit,
	|	RetailAmountAccounting.SalesDocument.StructuralUnit.RetailPriceKind.PriceCurrency AS SalesDocumentStructuralUnitPriceTypeRetailCurrencyPrices,
	|	RetailAmountAccounting.SalesDocument.BusinessActivity AS DocumentSalesBusinessActivity,
	|	RetailAmountAccounting.SalesDocument.BusinessActivity.GLAccountCostOfSales AS DocumentSalesBusinessActivityGLAccountCost,
	|	RetailAmountAccounting.SalesDocument.StructuralUnit.GLAccountInRetail AS DocumentSalesUnitAccountStructureInRetail,
	|	RetailAmountAccounting.SalesDocument.StructuralUnit.MarkupGLAccount AS DocumentSalesUnitStructureMarkupAccount,
	|	CASE
	|		WHEN ISNULL(TemporaryTableTotalCostPriceExpense.CostExpense, 0) <> 0
	|			THEN CAST(RetailAmountAccounting.Cost / TemporaryTableTotalCostPriceExpense.CostExpense * TemporaryTableCorrectionAmount.TotalCorrectionAmount AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS CorrectionAmount
	|FROM
	|	AccumulationRegister.RetailAmountAccounting AS RetailAmountAccounting
	|		LEFT JOIN TemporaryTableCorrectionAmount AS TemporaryTableCorrectionAmount
	|		ON RetailAmountAccounting.Company = TemporaryTableCorrectionAmount.Company
	|			AND RetailAmountAccounting.StructuralUnit = TemporaryTableCorrectionAmount.StructuralUnit
	|			AND RetailAmountAccounting.Currency = TemporaryTableCorrectionAmount.Currency
	|		LEFT JOIN TemporaryTableTotalCostPriceExpense AS TemporaryTableTotalCostPriceExpense
	|		ON RetailAmountAccounting.Company = TemporaryTableTotalCostPriceExpense.Company
	|			AND RetailAmountAccounting.StructuralUnit = TemporaryTableTotalCostPriceExpense.StructuralUnit
	|			AND RetailAmountAccounting.Currency = TemporaryTableTotalCostPriceExpense.Currency
	|WHERE
	|	RetailAmountAccounting.Period between &DateBeg AND &DateEnd
	|	AND RetailAmountAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND RetailAmountAccounting.Cost <> 0
	|	AND RetailAmountAccounting.Company = &Company
	|	AND RetailAmountAccounting.SalesDocument <> VALUE(Document.CashReceipt.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableCorrectionAmount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableTotalCostPriceExpense";
	
	QueryResult = Query.ExecuteBatch();
	
	SelectionDetailRecords = QueryResult[2].Select();
	
	// Create the accumulation register records set RetailAmountAccounting.
	RecordSetRetailAmountAccounting = AccumulationRegisters.RetailAmountAccounting.CreateRecordSet();
	RecordSetRetailAmountAccounting.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set IncomeAndExpensesAccounting.
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set Managerial.
	RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
	RecordSetManagerial.Filter.Recorder.Set(Ref);
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.CorrectionAmount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements on the register RetailAmountAccounting.
		NewRow = RecordSetRetailAmountAccounting.Add();
		NewRow.Period = Date;
		NewRow.RecordType = AccumulationRecordType.Expense;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnit;
		NewRow.Currency = SelectionDetailRecords.SalesDocumentStructuralUnitPriceTypeRetailCurrencyPrices;
		NewRow.ContentOfAccountingRecord = NStr("en='Cost';ru='Себестоимость'");
		NewRow.Cost = SelectionDetailRecords.CorrectionAmount;
		
		// Movements on the register IncomeAndExpenses.
		NewRow = RecordSetIncomeAndExpenses.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.StructuralUnit = SelectionDetailRecords.DocumentSalesUnit;
		NewRow.BusinessActivity = SelectionDetailRecords.DocumentSalesBusinessActivity;
		NewRow.GLAccount = SelectionDetailRecords.DocumentSalesBusinessActivityGLAccountCost;
		NewRow.AmountExpense = SelectionDetailRecords.CorrectionAmount;
		NewRow.ContentOfAccountingRecord = NStr("en='Record expenses';ru='Отражение расходов'");
		
		// Movements by register Managerial.
		NewRow = RecordSetManagerial.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		NewRow.AccountDr = SelectionDetailRecords.DocumentSalesBusinessActivityGLAccountCost;
		NewRow.AccountCr = SelectionDetailRecords.DocumentSalesUnitAccountStructureInRetail;
		NewRow.Content = NStr("en='Cost';ru='Себестоимость'");
		NewRow.Amount = SelectionDetailRecords.CorrectionAmount;
		
		// Movements by register Managerial.
		NewRow = RecordSetManagerial.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		NewRow.AccountDr = SelectionDetailRecords.DocumentSalesUnitAccountStructureInRetail;
		NewRow.AccountCr = SelectionDetailRecords.DocumentSalesUnitStructureMarkupAccount;
		NewRow.Content = NStr("en='Markup';ru='Наценка'");
		NewRow.Amount = - SelectionDetailRecords.CorrectionAmount;
		
	EndDo;
	
	// Write the rest of the records Income and expenses accounting.
	RecordSetIncomeAndExpenses.Write(False);
	
	// Write the rest of the records Retail amount accounting.
	RecordSetRetailAmountAccounting.Write(False);
	
	// Write the rest of the records Managerial.
	RecordSetManagerial.Write(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE DIFFERENCES CALCULATION

Procedure CalculateExchangeDifferences(Cancel, ErrorsTable)
	
	// Create the accumulation register records set CashAssets.
	RecordSetCashAssets = AccumulationRegisters.CashAssets.CreateRecordSet();
	RecordSetCashAssets.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set CashInCashRegisters.
	RecordSetCashAssetsInCashRegisters = AccumulationRegisters.CashInCashRegisters.CreateRecordSet();
	RecordSetCashAssetsInCashRegisters.Filter.Recorder.Set(Ref);
	
	// Create accumulation register record set PayrollPayments.
	RecordSetPayrollPayments = AccumulationRegisters.PayrollPayments.CreateRecordSet();
	RecordSetPayrollPayments.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set AdvanceHolderPayments.
	RecordSetSettlementsWithAdvanceHolders = AccumulationRegisters.AdvanceHolderPayments.CreateRecordSet();
	RecordSetSettlementsWithAdvanceHolders.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set AccountsReceivable.
	RecordSetSettlementsWithBuyers = AccumulationRegisters.AccountsReceivable.CreateRecordSet();
	RecordSetSettlementsWithBuyers.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set AccountsPayable.
	RecordSetSettlementsWithSuppliers = AccumulationRegisters.AccountsPayable.CreateRecordSet();
	RecordSetSettlementsWithSuppliers.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set IncomeAndExpensesAccounting.
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	// Create the information register records set ReportOnExchangeRatesDifference.
	RecordSetReportOnCurrencyRatesDifference = InformationRegisters.ReportOnCurrencyRatesDifference.CreateRecordSet();
	RecordSetReportOnCurrencyRatesDifference.Filter.Recorder.Set(Ref);
	
	// Create the accounting register records set Managerial.
	RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
	RecordSetManagerial.Filter.Recorder.Set(Ref);
	
	Query = New Query;
	
	Query.SetParameter("Date", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateEnd", AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference", NStr("en='Exchange rate difference';ru='Курсовая разница'"));
	
	// Cash assets.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.CashAssetsType AS CashAssetsType,
	|	TableBalances.BankAccountPettyCash AS BankAccountPettyCash,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.BankAccountPettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE TableBalances.BankAccountPettyCash.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.BankAccountPettyCash.GLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.BankAccountPettyCash.GLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.CashAssets.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DateEnd, ) AS CurrencyCurrencyRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetCashAssets.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindManagerial;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetManagerial.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetReportOnCurrencyRatesDifference.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindManagerial = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = "" + SelectionDetailRecords.BankAccountPettyCash;
		NewRow.Section = "Cash assets";
		
	EndDo;
	
	// Cash assets in CR receipts.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.CashCR AS CashCR,
	|	TableBalances.CashCR.CashCurrency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.CashCR.GLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE TableBalances.CashCR.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.CashCR.GLAccount.Currency
	|			THEN TableBalances.CashCR.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.CashCR.GLAccount.Currency
	|			THEN TableBalances.CashCR.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.CashInCashRegisters.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DateEnd, ) AS CurrencyCurrencyRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.CashCR.CashCurrency = CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetCashAssetsInCashRegisters.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindManagerial;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetManagerial.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetReportOnCurrencyRatesDifference.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindManagerial = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = "" + SelectionDetailRecords.CashCR;
		NewRow.Section = "Cash in cash registers";
		
	EndDo;
	
	// Staff settlements.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.StructuralUnit AS StructuralUnit,
	|	TableBalances.Employee AS Employee,
	|	TableBalances.Employee.Code AS EmployeeCode,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.RegistrationPeriod AS RegistrationPeriod,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|		ELSE TableBalances.Employee.SettlementsHumanResourcesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.PayrollPayments.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DateEnd, ) AS CurrencyCurrencyRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetPayrollPayments.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindManagerial;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.StructuralUnit = Undefined;
		NewRow = RecordSetManagerial.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetReportOnCurrencyRatesDifference.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindManagerial = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = 
			""
		  + SelectionDetailRecords.Employee + " (" + SelectionDetailRecords.EmployeeCode + ")"
		  + " / "
		  + SelectionDetailRecords.StructuralUnit
		  + " / "
		  + Format(SelectionDetailRecords.RegistrationPeriod, "DF='MMMM yyyy'")+ " g.";
		NewRow.Section = "Personnel settlements";
		
	EndDo;
	
	// Advance holder payments.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.Employee AS Employee,
	|	TableBalances.Document AS Document,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount
	|					ELSE TableBalances.Employee.OverrunGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE CASE
	|				WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|					THEN TableBalances.Employee.AdvanceHoldersGLAccount
	|				ELSE TableBalances.Employee.OverrunGLAccount
	|			END
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount.Currency
	|					ELSE TableBalances.Employee.OverrunGLAccount.Currency
	|				END
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount.Currency
	|					ELSE TableBalances.Employee.OverrunGLAccount.Currency
	|				END
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.AdvanceHolderPayments.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DateEnd, ) AS CurrencyCurrencyRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetSettlementsWithAdvanceHolders.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindManagerial;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetManagerial.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetReportOnCurrencyRatesDifference.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindManagerial = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics =
			""
		  + SelectionDetailRecords.Employee
		  + " / "
		  + SelectionDetailRecords.Document;
		NewRow.Section = "Settlements with advance holders";
		
	EndDo;
	
	// Accounts receivable.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.SettlementsType AS SettlementsType,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.Order AS Order,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountCustomerSettlements
	|					ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|		ELSE CASE
	|				WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|					THEN TableBalances.Counterparty.GLAccountCustomerSettlements
	|				ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount
	|			END
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountCustomerSettlements.Currency
	|					ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountCustomerSettlements.Currency
	|					ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS TableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DateEnd, ) AS CurrencyCurrencyRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Contract.SettlementsCurrency = CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetSettlementsWithBuyers.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindManagerial;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetManagerial.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetReportOnCurrencyRatesDifference.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Currency = SelectionDetailRecords.Contract.SettlementsCurrency;
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindManagerial = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics =
			""
		  + SelectionDetailRecords.Counterparty
		  + " / "
		  + SelectionDetailRecords.Contract
		  + " / "
		  + SelectionDetailRecords.Document
		  + " / "
		  + SelectionDetailRecords.Order;
		NewRow.Section = "Accounts receivable";
		
	EndDo;
	
	// Accounts payable.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.SettlementsType AS SettlementsType,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.Order AS Order,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindManagerial,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(ChartOfAccounts.Managerial.OtherExpenses)
	|		ELSE CASE
	|				WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|					THEN TableBalances.Counterparty.GLAccountVendorSettlements
	|				ELSE TableBalances.Counterparty.VendorAdvancesGLAccount
	|			END
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountVendorSettlements
	|					ELSE TableBalances.Counterparty.VendorAdvancesGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.Managerial.OtherIncome)
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountVendorSettlements.Currency
	|					ELSE TableBalances.Counterparty.VendorAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountVendorSettlements.Currency
	|					ELSE TableBalances.Counterparty.VendorAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS TableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&DateEnd, ) AS CurrencyCurrencyRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Contract.SettlementsCurrency = CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingCurrencyRatesSliceLast.Multiplicity / (AccountingCurrencyRatesSliceLast.ExchangeRate * CurrencyCurrencyRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetSettlementsWithSuppliers.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindManagerial;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetManagerial.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetReportOnCurrencyRatesDifference.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Currency = SelectionDetailRecords.Contract.SettlementsCurrency;
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindManagerial = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics =
			""
		  + SelectionDetailRecords.Counterparty
		  + " / "
		  + SelectionDetailRecords.Contract
		  + " / "
		  + SelectionDetailRecords.Document
		  + " / "
		  + SelectionDetailRecords.Order;
		NewRow.Section = "Accounts payable";
		
	EndDo;
	
	// Write the rest of the records.
	RecordSetCashAssets.Write(False);
	RecordSetCashAssetsInCashRegisters.Write(False);
	RecordSetPayrollPayments.Write(False);
	RecordSetSettlementsWithAdvanceHolders.Write(False);
	RecordSetSettlementsWithBuyers.Write(False);
	RecordSetSettlementsWithSuppliers.Write(False);
	RecordSetIncomeAndExpenses.Write(False);
	RecordsTable = RecordSetReportOnCurrencyRatesDifference.Unload();
	RecordsTable.GroupBy("Period, Active, Company, Analytics, Currency, Section", "Amount, AmountIncome, AmountExpense, AmountBalance, AmountCurBalance");
	RecordSetReportOnCurrencyRatesDifference.Load(RecordsTable);
	RecordSetReportOnCurrencyRatesDifference.Write(False);
	RecordSetManagerial.Write(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS TO ENSURE DOCUMENT POSTING

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	InitialPeriodBoundary = New Boundary(BegOfMonth(Date), BoundaryType.Including);
	LastBoundaryPeriod = New Boundary(EndOfMonth (Date), BoundaryType.Including);
	BeginOfPeriodningDate = BegOfMonth(Date);
	EndDatePeriod   = EndOfMonth (Date);
	
	StructureAdditionalProperties.ForPosting.Insert("EmptyAccount", ChartsOfAccounts.Managerial.EmptyRef());
	
	StructureAdditionalProperties.ForPosting.Insert("InitialPeriodBoundary", InitialPeriodBoundary);
	StructureAdditionalProperties.ForPosting.Insert("LastBoundaryPeriod", LastBoundaryPeriod);
	StructureAdditionalProperties.ForPosting.Insert("BeginOfPeriodningDate", BeginOfPeriodningDate);
	StructureAdditionalProperties.ForPosting.Insert("EndDatePeriod", EndDatePeriod);
	
EndProcedure // AddAttributesToAdditionalPropertiesForPosting()

// Sets property of writing document records to
// the passed value for sets.
//
// Parameters:
//  RecordFlag   - Boolean, check box of permission to write record sets.
//
Procedure SetPropertiesOfDocumentRecordSets(RecordFlag)
	
	RegisterRecords.WriteOffCostsCorrectionNodes.Write = RecordFlag;
	RegisterRecords.Inventory.Write = RecordFlag;
	RegisterRecords.Sales.Write = RecordFlag;
	RegisterRecords.IncomeAndExpenses.Write = RecordFlag;
	RegisterRecords.Managerial.Write = RecordFlag;
	RegisterRecords.MonthEndErrors.Write = RecordFlag;
	RegisterRecords.ReportOnCurrencyRatesDifference.Write = RecordFlag;
	
EndProcedure // SetDocumentRecordSetsProperties()

// Collapses the records set Income and expenses.
//
Procedure GroupRecordSetIncomeAndExpenses(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	IncomeAndExpenses.Period,
	|	IncomeAndExpenses.Active,
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessActivity,
	|	IncomeAndExpenses.CustomerOrder,
	|	IncomeAndExpenses.GLAccount,
	|	SUM(IncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(IncomeAndExpenses.AmountExpense) AS AmountExpense,
	|	IncomeAndExpenses.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|WHERE
	|	IncomeAndExpenses.Recorder = &Recorder
	|
	|GROUP BY
	|	IncomeAndExpenses.Period,
	|	IncomeAndExpenses.Active,
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessActivity,
	|	IncomeAndExpenses.CustomerOrder,
	|	IncomeAndExpenses.GLAccount,
	|	IncomeAndExpenses.ContentOfAccountingRecord
	|
	|HAVING
	|	(SUM(IncomeAndExpenses.AmountIncome) <> 0
	|		OR SUM(IncomeAndExpenses.AmountExpense) <> 0)";
	
	Query.SetParameter("Recorder", Ref);
	
	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);
	
EndProcedure // CollapseRecordsSetIncomeAndExpenses()

// Collapses the records set Inventory.
//
Procedure GroupRecordSetInventory(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	Inventory.Period,
	|	Inventory.Active,
	|	Inventory.RecordType,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.ProductsAndServices,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.CustomerOrder,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	Inventory.StructuralUnitCorr,
	|	Inventory.CorrGLAccount,
	|	Inventory.ProductsAndServicesCorr,
	|	Inventory.CharacteristicCorr,
	|	Inventory.BatchCorr,
	|	Inventory.CustomerCorrOrder,
	|	Inventory.Specification,
	|	Inventory.SpecificationCorr,
	|	Inventory.OrderSales,
	|	Inventory.Department,
	|	Inventory.Responsible,
	|	Inventory.SalesDocument,
	|	Inventory.VATRate,
	|	Inventory.FixedCost,
	|	Inventory.ProductionExpenses,
	|	Inventory.Return,
	|	Inventory.ContentOfAccountingRecord,
	|	Inventory.RetailTransferAccrualAccounting
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Active,
	|	Inventory.RecordType,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.ProductsAndServices,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.CustomerOrder,
	|	Inventory.StructuralUnitCorr,
	|	Inventory.CorrGLAccount,
	|	Inventory.ProductsAndServicesCorr,
	|	Inventory.CharacteristicCorr,
	|	Inventory.BatchCorr,
	|	Inventory.CustomerCorrOrder,
	|	Inventory.Specification,
	|	Inventory.SpecificationCorr,
	|	Inventory.OrderSales,
	|	Inventory.Department,
	|	Inventory.Responsible,
	|	Inventory.SalesDocument,
	|	Inventory.VATRate,
	|	Inventory.FixedCost,
	|	Inventory.ProductionExpenses,
	|	Inventory.Return,
	|	Inventory.ContentOfAccountingRecord,
	|	Inventory.RetailTransferAccrualAccounting
	|
	|HAVING
	|	(SUM(Inventory.Quantity) <> 0
	|		OR SUM(Inventory.Amount) <> 0)";
	
	Query.SetParameter("Recorder", Ref);
	
	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister); 
	
EndProcedure // CollapseRecordsSetInventory()

// Collapses the records set Sales.
//
Procedure GroupRecordSetSales(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	Sales.Period,
	|	Sales.Active,
	|	Sales.ProductsAndServices,
	|	Sales.Characteristic,
	|	Sales.Batch,
	|	Sales.Document,
	|	Sales.VATRate,
	|	Sales.Company,
	|	Sales.CustomerOrder,
	|	Sales.Department,
	|	Sales.Responsible,
	|	SUM(Sales.Quantity) AS Quantity,
	|	SUM(Sales.Amount) AS Amount,
	|	SUM(Sales.VATAmount) AS VATAmount,
	|	SUM(Sales.Cost) AS Cost
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	Sales.Recorder = &Recorder
	|
	|GROUP BY
	|	Sales.Period,
	|	Sales.Active,
	|	Sales.ProductsAndServices,
	|	Sales.Characteristic,
	|	Sales.Batch,
	|	Sales.Document,
	|	Sales.VATRate,
	|	Sales.Company,
	|	Sales.CustomerOrder,
	|	Sales.Department,
	|	Sales.Responsible
	|
	|HAVING
	|	(SUM(Sales.Quantity) <> 0
	|		OR SUM(Sales.Amount) <> 0
	|		OR SUM(Sales.VATAmount) <> 0
	|		OR SUM(Sales.Cost) <> 0)";
	
	Query.SetParameter("Recorder", Ref);

	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);
	
EndProcedure // CollapseRecordsSetSales()

// Collapses the records set FinancialResult.
//
Procedure GroupRecordSetFinancialResult(RegisterRecordSet)
			
	Query = New Query();
	Query.Text = 
	"SELECT
	|	FinancialResult.Period,
	|	FinancialResult.Active,
	|	FinancialResult.Company,
	|	FinancialResult.StructuralUnit,
	|	FinancialResult.BusinessActivity,
	|	FinancialResult.CustomerOrder,
	|	FinancialResult.GLAccount,
	|	SUM(FinancialResult.AmountIncome) AS AmountIncome,
	|	SUM(FinancialResult.AmountExpense) AS AmountExpense,
	|	FinancialResult.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.FinancialResult AS FinancialResult
	|WHERE
	|	FinancialResult.Recorder = &Recorder
	|
	|GROUP BY
	|	FinancialResult.Period,
	|	FinancialResult.Active,
	|	FinancialResult.Company,
	|	FinancialResult.StructuralUnit,
	|	FinancialResult.BusinessActivity,
	|	FinancialResult.CustomerOrder,
	|	FinancialResult.GLAccount,
	|	FinancialResult.ContentOfAccountingRecord
	|
	|HAVING
	|	(SUM(FinancialResult.AmountIncome) <> 0
	|		OR SUM(FinancialResult.AmountExpense) <> 0)";

	Query.SetParameter("Recorder", Ref);

	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);

EndProcedure // CollapseRecordsSetFinancialResult()

// Collapses the records set Managerial.
//
Procedure GroupRecordSetManagerial(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	Managerial.Period,
	|	Managerial.Active,
	|	Managerial.AccountDr,
	|	Managerial.AccountCr,
	|	Managerial.Company,
	|	Managerial.PlanningPeriod,
	|	Managerial.CurrencyDr,
	|	Managerial.CurrencyCr,
	|	SUM(Managerial.Amount) AS Amount,
	|	SUM(Managerial.AmountCurDr) AS AmountCurDr,
	|	SUM(Managerial.AmountCurCr) AS AmountCurCr,
	|	Managerial.Content
	|FROM
	|	AccountingRegister.Managerial AS Managerial
	|WHERE
	|	Managerial.Recorder = &Recorder
	|
	|GROUP BY
	|	Managerial.Period,
	|	Managerial.Active,
	|	Managerial.AccountDr,
	|	Managerial.AccountCr,
	|	Managerial.Company,
	|	Managerial.PlanningPeriod,
	|	Managerial.CurrencyDr,
	|	Managerial.CurrencyCr,
	|	Managerial.Content
	|
	|HAVING
	|	(SUM(Managerial.Amount) <> 0
	|		OR SUM(Managerial.AmountCurDr) <> 0
	|		OR SUM(Managerial.AmountCurCr) <> 0)"; 

	Query.SetParameter("Recorder", Ref);

	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);
	
EndProcedure // CollapseRecordsSetManagerial()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler Posting(). Creates
// a document movement by accumulation registers and accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Allow to write record sets.
	SetPropertiesOfDocumentRecordSets(True);
	
	RecordSetMonthEndErrors = InformationRegisters.MonthEndErrors.CreateRecordSet();
	RecordSetMonthEndErrors.Filter.Recorder.Set(Ref);
	ErrorsTable = RecordSetMonthEndErrors.UnloadColumns();
	
	// Direct cost calculation
	If DirectCostCalculation Then
		CalculateCostOfReturns(); // refunds cost precalculation.
		CalculateActualOutputCostPrice(Cancel, "DirectCostCalculation", ErrorsTable);
		CalculateCostOfReturns(); // refunds cost final calculation.
	EndIf;
	
	// Costs allocation.
	If CostAllocation Then
		DistributeCosts(Cancel, ErrorsTable);
	EndIf;
	
	// Primecost calculation.
	If ActualCostCalculation Then
		CalculateCostOfReturns(); // refunds cost precalculation.
		CalculateActualOutputCostPrice(Cancel, "ActualCostCalculation", ErrorsTable);
		CalculateCostOfReturns(); // refunds cost final calculation.
	EndIf;
	
	// Primecost in retail calculation accrual accounting.
	If RetailCostCalculationAccrualAccounting Then
		CalculateCostPriceInRetailAccrualAccounting(Cancel, ErrorsTable);
	EndIf;
	
	// Exchange differences calculation.
	If ExchangeDifferencesCalculation Then
		CalculateExchangeDifferences(Cancel, ErrorsTable);
	EndIf;
	
	// Financial result calculation.
	If FinancialResultCalculation Then
		CalculateFinancialResult(Cancel, ErrorsTable);
	EndIf;
	
	If ErrorsTable.Count() > 0 Then
		MessageText = NStr("en='Warnings were generated on month-end closing. For more information, see the month-end closing report.';ru='При закрытии месяца были сформированы предупреждения! Подробнее см. в отчете о закрытии месяца.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	// Collapse register record sets.
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	GroupRecordSetInventory(RecordSetInventory);
	RecordSetInventory.Write(True);
	
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	GroupRecordSetIncomeAndExpenses(RecordSetIncomeAndExpenses);
	RecordSetIncomeAndExpenses.Write(True);
	
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	GroupRecordSetSales(RecordSetSales);
	RecordSetSales.Write(True);
	
	RecordSetFinancialResult = AccumulationRegisters.FinancialResult.CreateRecordSet();
	RecordSetFinancialResult.Filter.Recorder.Set(Ref);
	GroupRecordSetFinancialResult(RecordSetFinancialResult);
	RecordSetFinancialResult.Write(True);
	
	RecordSetManagerial = AccountingRegisters.Managerial.CreateRecordSet();
	RecordSetManagerial.Filter.Recorder.Set(Ref);
	GroupRecordSetManagerial(RecordSetManagerial);
	RecordSetManagerial.Write(True);
	
	ErrorsTable.GroupBy("Period, Recorder, Active, Company, OperationKind, ErrorDescription, Analytics");
	RecordSetMonthEndErrors.Load(ErrorsTable);
	RecordSetMonthEndErrors.Write(True);
	
	// Prohibit writing record sets.
	SetPropertiesOfDocumentRecordSets(False);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

#EndIf
