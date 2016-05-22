#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DepreciationAccrual", NStr("en = 'Depriciation accrual'"));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	DocumentTable.ProductsAndServices AS ProductsAndServices,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.Batch AS Batch,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.Depreciation AS Amount,
	|	TRUE AS FixedCost,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	&DepreciationAccrual AS ContentOfAccountingRecord
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		&Company AS Company,
	|		FixedAssetsParametersSliceLast.StructuralUnit AS StructuralUnit,
	|		FixedAssetsParametersSliceLast.GLExpenseAccount AS AccountAccountingDepreciation,
	|		FixedAssetsParametersSliceLast.BusinessActivity AS BusinessActivity,
	|		DocumentTable.FixedAsset AS FixedAsset,
	|		DocumentTable.FixedAsset.GLAccount AS GLAccount,
	|		DocumentTable.FixedAsset.DepreciationAccount AS DepreciationAccount,
	|		VALUE(Catalog.ProductsAndServices.EmptyRef) AS ProductsAndServices,
	|		VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|		VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	|		UNDEFINED AS Order,
	|		DocumentTable.Cost AS Cost,
	|		DocumentTable.Depreciation AS Depreciation
	|	FROM
	|		TableDepreciationCalculation AS DocumentTable
	|			LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(&PointInTime, ) AS FixedAssetsParametersSliceLast
	|			ON (&Company = FixedAssetsParametersSliceLast.Company)
	|				AND DocumentTable.FixedAsset = FixedAssetsParametersSliceLast.FixedAsset
	|	WHERE
	|		DocumentTable.Continue
	|		AND DocumentTable.Depreciation <> 0
	|		AND DocumentTable.MessageAboutDepreciationAccrualError = UNDEFINED
	|		AND (FixedAssetsParametersSliceLast.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|				OR FixedAssetsParametersSliceLast.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))) AS DocumentTable";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
			
EndProcedure // GenerateTableInventory()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("DepreciationAccrual", NStr("en = 'Depriciation accrual'"));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	FixedAssetsParametersSliceLast.BusinessActivity AS BusinessActivity,
	|	FixedAssetsParametersSliceLast.StructuralUnit AS StructuralUnit,
	|	FixedAssetsParametersSliceLast.GLExpenseAccount AS GLAccount,
	|	UNDEFINED AS Order,
	|	DocumentTable.Depreciation AS AmountExpense,
	|	DocumentTable.Depreciation AS Amount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	&DepreciationAccrual AS ContentOfAccountingRecord
	|FROM
	|	TableDepreciationCalculation AS DocumentTable
	|		LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(&PointInTime, ) AS FixedAssetsParametersSliceLast
	|		ON (&Company = FixedAssetsParametersSliceLast.Company)
	|			AND DocumentTable.FixedAsset = FixedAssetsParametersSliceLast.FixedAsset
	|WHERE
	|	DocumentTable.Continue
	|	AND DocumentTable.Depreciation <> 0
	|	AND DocumentTable.MessageAboutDepreciationAccrualError = UNDEFINED
	|	AND (FixedAssetsParametersSliceLast.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR FixedAssetsParametersSliceLast.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses))";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("DepreciationAccrual", NStr("en = 'Depriciation accrual'"));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.Depreciation AS Depreciation,
	|	DocumentTable.Depreciation AS Amount,
	|	DocumentTable.FixedAsset.DepreciationAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&DepreciationAccrual AS ContentOfAccountingRecord
	|FROM
	|	TableDepreciationCalculation AS DocumentTable
	|WHERE
	|	DocumentTable.Continue
	|	AND DocumentTable.MessageAboutDepreciationAccrualError = UNDEFINED
	|	AND DocumentTable.Depreciation > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure // GenerateTableFixedAssets()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableMonthEndErrors(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("DepreciationAccrual", NStr("en = 'Depriciation accrual'"));
	Query.SetParameter("DepreciationEqualsZero", NStr("en = 'calculated depriciation is equal to 0!'"));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&Period AS Period,
	|	TableOfDepreciationAccrualMessages.FixedAssetPresentation AS FixedAssetPresentation,
	|	TableOfDepreciationAccrualMessages.Code AS Code,
	|	TableOfDepreciationAccrualMessages.MessageAboutDepreciationAccrualError AS MessageAboutDepreciationAccrualError,
	|	CAST("""" AS String(255)) AS ErrorDescription,
	|	""DepreciationAccrual"" AS OperationKind
	|FROM
	|	TableDepreciationCalculation AS TableOfDepreciationAccrualMessages
	|WHERE
	|	TableOfDepreciationAccrualMessages.Continue
	|	AND TableOfDepreciationAccrualMessages.MessageAboutDepreciationAccrualError <> UNDEFINED
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&Period,
	|	TableOfDepreciationAccrualMessages.FixedAssetPresentation,
	|	TableOfDepreciationAccrualMessages.Code,
	|	&DepreciationEqualsZero,
	|	CAST("""" AS String(255)),
	|	""DepreciationAccrual""
	|FROM
	|	TableDepreciationCalculation AS TableOfDepreciationAccrualMessages
	|WHERE
	|	TableOfDepreciationAccrualMessages.Continue
	|	AND TableOfDepreciationAccrualMessages.MessageAboutDepreciationAccrualError = UNDEFINED
	|	AND TableOfDepreciationAccrualMessages.Depreciation = 0
	|	AND TableOfDepreciationAccrualMessages.TotalLeftToWriteOff <> 0";
	
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.Date);
	
	ResultTable = Query.Execute().Unload();
	
	For Each CurRow IN ResultTable Do
		ErrorText = NStr("en = 'For the %FixedAssetPresentation% (%Code%) fixed assets %MessageAboutDepreciationAccrualError%.'");
		ErrorText = StrReplace(ErrorText, "%FixedAssetPresentation%", TrimAll(CurRow.FixedAssetPresentation));
		ErrorText = StrReplace(ErrorText, "%Code%", TrimAll(CurRow.Code));
		ErrorText = StrReplace(ErrorText, "%MessageAboutDepreciationAccrualError%", TrimAll(CurRow.MessageAboutDepreciationAccrualError));
		CurRow.ErrorDescription = ErrorText;
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMonthEndErrors", ResultTable);
	
EndProcedure // GenerateMessagesTableDepriciationAccruals()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("DepreciationAccrual", NStr("en = 'Depriciation accrual'"));
		
	Query.Text =
	"SELECT
	|	DocumentTable.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	FixedAssetsParametersSliceLast.GLExpenseAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.FixedAsset.DepreciationAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.Depreciation AS Amount,
	|	CAST(&DepreciationAccrual AS String(100)) AS Content
	|FROM
	|	TableDepreciationCalculation AS DocumentTable
	|		LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(&PointInTime, ) AS FixedAssetsParametersSliceLast
	|		ON (&Company = FixedAssetsParametersSliceLast.Company)
	|			AND DocumentTable.FixedAsset = FixedAssetsParametersSliceLast.FixedAsset
	|WHERE
	|	DocumentTable.Continue
	|	AND DocumentTable.MessageAboutDepreciationAccrualError = UNDEFINED
	|	AND DocumentTable.Depreciation > 0";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Period",		   StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",   StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("BegOfYear",	   BegOfYear(StructureAdditionalProperties.ForPosting.Date));
	Query.SetParameter("BeginOfPeriod", BegOfMonth(StructureAdditionalProperties.ForPosting.Date));
	Query.SetParameter("EndOfPeriod",  EndOfMonth(StructureAdditionalProperties.ForPosting.Date));
	Query.SetParameter("Message1",	   NStr("en = 'depriciation has been already accrued in this month!'"));
	Query.SetParameter("Message2",	   NStr("en = 'depriciation accrual method is not specified!'"));
	Query.SetParameter("Message3",	   NStr("en = 'cost is 0!'"));
	Query.SetParameter("Message4",	   NStr("en = 'the useful life is 0!'"));
	Query.SetParameter("Message5",	   NStr("en = 'the scope of work for depricication accrual is not specified!'"));
	Query.SetParameter("Message6",	   NStr("en = 'the initial cost is 0!'"));
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	&Company AS Company";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	
	LockItem = Block.Add("AccumulationRegister.FixedAssets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	
	LockItem = Block.Add("AccumulationRegister.FixedAssetsOutput");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	
	LockItem = Block.Add("InformationRegister.FixedAssetsParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	
	LockItem = Block.Add("InformationRegister.FixedAssetsStates");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	ListOfAmortizableFA.FixedAsset AS FixedAsset,
	|	PRESENTATION(ListOfAmortizableFA.FixedAsset) AS FixedAssetPresentation,
	|	ListOfAmortizableFA.FixedAsset.Code AS Code,
	|	ListOfAmortizableFA.BeginAccrueDepriciation AS BeginAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepriciation AS EndAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|	ISNULL(FACost.DepreciationClosingBalance, 0) AS DepreciationClosingBalance,
	|	ISNULL(FACost.DepreciationTurnover, 0) AS DepreciationTurnover,
	|	ISNULL(FACost.CostClosingBalance, 0) AS BalanceCost,
	|	ISNULL(FACost.CostOpeningBalance, 0) AS CostOpeningBalance,
	|	ISNULL(DepreciationBalancesAndTurnovers.CostOpeningBalance, 0) - ISNULL(DepreciationBalancesAndTurnovers.DepreciationOpeningBalance, 0) AS CostAtBegOfYear,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.DepreciationMethod, 0) AS DepreciationAccrualMethod,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.InitialCost, 0) AS OriginalCost,
	|	ISNULL(DepreciationParametersSliceLast.ApplyInCurrentMonth, 0) AS ApplyInCurrentMonth,
	|	DepreciationParametersSliceLast.Period AS Period,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.UsagePeriodForDepreciationCalculation, 0)
	|	END AS UsagePeriodForDepreciationCalculation,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.CostForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.CostForDepreciationCalculation, 0)
	|	END AS CostForDepreciationCalculation,
	|	ISNULL(DepreciationSignChange.UpdateAmortAccrued, FALSE) AS UpdateAmortAccrued,
	|	ISNULL(DepreciationSignChange.AccrueInCurMonth, FALSE) AS AccrueInCurMonth,
	|	ISNULL(FixedAssetOutputTurnovers.QuantityTurnover, 0) AS OutputVolume,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.AmountOfProductsServicesForDepreciationCalculation, 0)
	|	END AS AmountOfProductsServicesForDepreciationCalculation
	|INTO TemporaryTableForDepreciationCalculation
	|FROM
	|	(SELECT
	|		SliceFirst.AccrueDepreciation AS BeginAccrueDepriciation,
	|		SliceLast.AccrueDepreciation AS EndAccrueDepriciation,
	|		SliceLast.AccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|		SliceLast.FixedAsset AS FixedAsset
	|	FROM
	|		(SELECT
	|			FixedAssetStateSliceFirst.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceFirst.AccrueDepreciation AS AccrueDepreciation,
	|			FixedAssetStateSliceFirst.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|			FixedAssetStateSliceFirst.Period AS Period
	|		FROM
	|			InformationRegister.FixedAssetsStates.SliceLast(&BeginOfPeriod, Company = &Company) AS FixedAssetStateSliceFirst) AS SliceFirst
	|			Full JOIN (SELECT
	|				FixedAssetStateSliceLast.FixedAsset AS FixedAsset,
	|				FixedAssetStateSliceLast.AccrueDepreciation AS AccrueDepreciation,
	|				FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|				FixedAssetStateSliceLast.Period AS Period
	|			FROM
	|				InformationRegister.FixedAssetsStates.SliceLast(&EndOfPeriod, Company = &Company) AS FixedAssetStateSliceLast) AS SliceLast
	|			ON SliceFirst.FixedAsset = SliceLast.FixedAsset) AS ListOfAmortizableFA
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(&BegOfYear, , , , Company = &Company) AS DepreciationBalancesAndTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationBalancesAndTurnovers.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(&BeginOfPeriod, &EndOfPeriod, , , Company = &Company) AS FACost
	|		ON ListOfAmortizableFA.FixedAsset = FACost.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(&EndOfPeriod, Company = &Company) AS DepreciationParametersSliceLast
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLast.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(&BeginOfPeriod, Company = &Company) AS DepreciationParametersSliceLastBegOfMonth
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLastBegOfMonth.FixedAsset
	|		LEFT JOIN (SELECT
	|			COUNT(DISTINCT TRUE) AS UpdateAmortAccrued,
	|			FixedAssetState.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueInCurMonth
	|		FROM
	|			InformationRegister.FixedAssetsStates AS FixedAssetState
	|				INNER JOIN InformationRegister.FixedAssetsStates.SliceLast(&EndOfPeriod, Company = &Company) AS FixedAssetStateSliceLast
	|				ON FixedAssetState.FixedAsset = FixedAssetStateSliceLast.FixedAsset
	|		WHERE
	|			FixedAssetState.Period between &BeginOfPeriod AND &EndOfPeriod
	|			AND FixedAssetState.Company = &Company
	|		
	|		GROUP BY
	|			FixedAssetState.FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth) AS DepreciationSignChange
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationSignChange.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssetsOutput.Turnovers(&BeginOfPeriod, &EndOfPeriod, , Company = &Company) AS FixedAssetOutputTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = FixedAssetOutputTurnovers.FixedAsset
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&Period AS Period,
	|	Table.Continue AS Continue,
	|	Table.MessageAboutDepreciationAccrualError AS MessageAboutDepreciationAccrualError,
	|	Table.FixedAsset AS FixedAsset,
	|	Table.FixedAssetPresentation AS FixedAssetPresentation,
	|	Table.Code AS Code,
	|	Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|	Table.BalanceCost AS BalanceCost,
	|	Table.TotalLeftToWriteOff AS TotalLeftToWriteOff,
	|	0 AS Cost,
	|	CASE
	|		WHEN CASE
	|				WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|					THEN Table.DepreciationAmount
	|				ELSE Table.TotalLeftToWriteOff
	|			END > 0
	|			THEN CASE
	|					WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|						THEN Table.DepreciationAmount
	|					ELSE Table.TotalLeftToWriteOff
	|				END
	|		ELSE 0
	|	END AS Depreciation
	|INTO TableDepreciationCalculation
	|FROM
	|	(SELECT
	|		CASE
	|			WHEN Table.UpdateAmortAccrued <> FALSE
	|						AND Table.AccrueInCurMonth = FALSE
	|					OR Table.EndAccrueDepriciation = FALSE
	|					OR Table.EndAccrueDepreciationInCurrentMonth = FALSE
	|						AND Table.BeginAccrueDepriciation = FALSE
	|				THEN FALSE
	|			ELSE TRUE
	|		END AS Continue,
	|		CASE
	|			WHEN Table.DepreciationTurnover <> 0
	|				THEN &Message1
	|			WHEN Table.DepreciationAccrualMethod = 0
	|				THEN &Message2
	|			WHEN Table.CostForDepreciationCalculation = 0
	|				THEN &Message3
	|			WHEN Table.UsagePeriodForDepreciationCalculation = 0
	|					AND Table.DepreciationAccrualMethod <> VALUE(Enum.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume)
	|				THEN &Message4
	|			WHEN Table.DepreciationAccrualMethod = VALUE(Enum.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume)
	|					AND Table.AmountOfProductsServicesForDepreciationCalculation = 0
	|				THEN &Message5
	|			WHEN Table.OriginalCost = 0
	|				THEN &Message6
	|			ELSE UNDEFINED
	|		END AS MessageAboutDepreciationAccrualError,
	|		CASE
	|			WHEN Table.DepreciationAccrualMethod = VALUE(Enum.FixedAssetsDepreciationMethods.Linear)
	|				THEN Table.CostForDepreciationCalculation / CASE
	|						WHEN Table.UsagePeriodForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.UsagePeriodForDepreciationCalculation
	|					END
	|			WHEN Table.DepreciationAccrualMethod = VALUE(Enum.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume)
	|				THEN Table.CostForDepreciationCalculation * Table.OutputVolume / CASE
	|						WHEN Table.AmountOfProductsServicesForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.AmountOfProductsServicesForDepreciationCalculation
	|					END
	|			ELSE 0
	|		END AS DepreciationAmount,
	|		Table.FixedAsset AS FixedAsset,
	|		Table.FixedAssetPresentation AS FixedAssetPresentation,
	|		Table.Code AS Code,
	|		Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|		Table.BalanceCost AS BalanceCost,
	|		Table.BalanceCost - Table.DepreciationClosingBalance AS TotalLeftToWriteOff
	|	FROM
	|		TemporaryTableForDepreciationCalculation AS Table) AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableForDepreciationCalculation";
	
	Query.ExecuteBatch();
	
	GenerateTableFixedAssets(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties);
	GenerateTableMonthEndErrors(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefFixedAssetsDepreciation, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

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