#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DepreciationAccrual", NStr("en='Depriciation accrual';ru='Начисление амортизации'"));
	Query.SetParameter("OtherExpenses", NStr("en='Other expenses';ru='Прочих затраты (расходы)'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	TRUE AS FixedCost,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	&DepreciationAccrual AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("DepreciationAccrual", NStr("en='Depriciation accrual';ru='Начисление амортизации'"));
	Query.SetParameter("OtherExpenses", NStr("en='Other expenses';ru='Прочих затраты (расходы)'"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.BusinessActivity AS BusinessActivity,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	DocumentTable.MonthlyDepreciation AS AmountExpense,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	&DepreciationAccrual AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.DepreciationAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.BusinessActivities.Other),
	|	UNDEFINED,
	|	DocumentTable.GLAccountWriteOff,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	VALUE(AccountingRecordType.Debit),
	|	&OtherExpenses
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.AccountTypeWriteOff = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.AccountTypeWriteOff = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DepreciationAccrual", NStr("en='Depriciation accrual';ru='Начисление амортизации'"));
	Query.SetParameter("DepreciationDebiting", NStr("en='Depreciation  write-off';ru='Списание амортизации'"));
	Query.SetParameter("OtherExpenses", NStr("en='Other expenses';ru='Прочих затраты (расходы)'"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.AccountAccountingDepreciation AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.DepreciationAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	CAST(&DepreciationAccrual AS String(100)) AS Content
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.DepreciationAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	&DepreciationDebiting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountWriteOff,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	&OtherExpenses
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("DepreciationAccrual", NStr("en='Depriciation accrual';ru='Начисление амортизации'"));
	Query.SetParameter("DepreciationDebiting", NStr("en='Depreciation  write-off';ru='Списание амортизации'"));
	Query.SetParameter("WriteOffOfFixedAssetFromAccounting", NStr("en='Fixed assets write off';ru='Списание имущества с учета'"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.MonthlyDepreciation AS Depreciation,
	|	0 AS Cost,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	DocumentTable.DepreciationAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&DepreciationAccrual AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.FixedAsset,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	DocumentTable.DepreciationAccount,
	|	VALUE(AccountingRecordType.Debit),
	|	&DepreciationDebiting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.FixedAsset,
	|	0,
	|	DocumentTable.Cost,
	|	DocumentTable.Cost,
	|	DocumentTable.GLAccount,
	|	VALUE(AccountingRecordType.Credit),
	|	&WriteOffOfFixedAssetFromAccounting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost > 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure // GenerateTableFixedAssets()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssetStatuses(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.FixedAssetsStates.RemoveFromAccounting) AS Status,
	|	FALSE AS AccrueDepreciation,
	|	FALSE AS AccrueDepreciationInCurrentMonth
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsStates", QueryResult.Unload());
	
EndProcedure // GenerateTableFixedAssetsStates()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefFixedAssetsWriteOff);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	FixedAssetsParametersSliceLast.StructuralUnit AS StructuralUnit,
	|	FixedAssetsParametersSliceLast.GLExpenseAccount AS AccountAccountingDepreciation,
	|	FixedAssetsParametersSliceLast.GLExpenseAccount.TypeOfAccount AS DepreciationAccountType,
	|	FixedAssetsParametersSliceLast.BusinessActivity AS BusinessActivity,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.FixedAsset.GLAccount AS GLAccount,
	|	DocumentTable.FixedAsset.DepreciationAccount AS DepreciationAccount,
	|	DocumentTable.Ref.Correspondence AS GLAccountWriteOff,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount AS AccountTypeWriteOff,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.Depreciation AS Depreciation,
	|	DocumentTable.MonthlyDepreciation AS MonthlyDepreciation,
	|	DocumentTable.DepreciatedCost AS DepreciatedCost,
	|	TRUE AS FixedCost
	|INTO TemporaryTableFixedAssets
	|FROM
	|	Document.FixedAssetsWriteOff.FixedAssets AS DocumentTable
	|		LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(&PointInTime, ) AS FixedAssetsParametersSliceLast
	|		ON (&Company = FixedAssetsParametersSliceLast.Company)
	|			AND DocumentTable.FixedAsset = FixedAssetsParametersSliceLast.FixedAsset
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Query.Execute();
	
	GenerateTableInventory(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties);
	GenerateTableFixedAssets(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties);
	GenerateTableFixedAssetStatuses(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefFixedAssetsWriteOff, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefFixedAssetsWriteOff, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If there are records in temprorary tables,
	// it is necessary to control the occurrence of negative balances.	
	If StructureTemporaryTables.RegisterRecordsFixedAssetsChange  Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.FixedAsset) AS FixedAssetPresentation,
		|	ISNULL(FixedAssetsBalance.CostBalance, 0) AS CostBalance,
		|	ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS DepreciationBalance,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsFixedAssetsChange.CostChanging AS CostChanging,
		|	RegisterRecordsFixedAssetsChange.CostChanging + ISNULL(FixedAssetsBalance.CostBalance, 0) AS DepreciatedCost,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationOnWrite AS DepreciationOnWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate AS DepreciationUpdate,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate + ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS AccuredDepreciation
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|		LEFT JOIN AccumulationRegister.FixedAssets.Balance(
		|				&ControlTime,
		|				(Company, FixedAsset) In
		|					(SELECT
		|						RegisterRecordsFixedAssetsChange.Company AS Company,
		|						RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset
		|					FROM
		|						RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange)) AS FixedAssetsBalance
		|		ON (RegisterRecordsFixedAssetsChange.Company = RegisterRecordsFixedAssetsChange.Company)
		|			AND (RegisterRecordsFixedAssetsChange.FixedAsset = RegisterRecordsFixedAssetsChange.FixedAsset)
		|WHERE
		|	(ISNULL(FixedAssetsBalance.CostBalance, 0) < 0
		|			OR ISNULL(FixedAssetsBalance.DepreciationBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectFixedAssetsWriteOff = DocumentRefFixedAssetsWriteOff.GetObject()
		EndIf;
		
		// Negative balance of property depriciation.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocumentObjectFixedAssetsWriteOff, QueryResultSelection, Cancel);
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