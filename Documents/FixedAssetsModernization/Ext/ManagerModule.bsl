#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefFixedAssetsModernization, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("FixedAssetAcceptanceForAccounting", "Change parameters");
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS Cost,
	|	0 AS Depreciation,
	|	&FixedAssetAcceptanceForAccounting AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssetsModernization AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure // GenerateTableFixedAssets()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefFixedAssetsModernization, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeReflection", NStr("en='Income accounting';ru='Отражение доходов'"));
	Query.SetParameter("CostsReflection", NStr("en='Costs reflection';ru='Отражение расходов'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS Order,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	DocumentTable.RevaluationAccount AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN &IncomeReflection
	|		ELSE &CostsReflection
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN 0
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS AmountExpense
	|FROM
	|	TemporaryTableFixedAssetsModernization AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure // GenerateTableIncomeAndExpenses()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableManagerial(DocumentRefFixedAssetsModernization, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeReflection", NStr("en='Income accounting';ru='Отражение доходов'"));
	Query.SetParameter("CostsReflection", NStr("en='Costs reflection';ru='Отражение расходов'"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE DocumentTable.RevaluationAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.RevaluationAccount
	|		ELSE DocumentTable.GLAccount
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyDr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS Amount,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN &IncomeReflection
	|		ELSE &CostsReflection
	|	END AS Content
	|FROM
	|	TemporaryTableFixedAssetsModernization AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // GenerateTableManagerial()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssetsParameters(DocumentRefFixedAssetsModernization, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefFixedAssetsModernization);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DocumentTable.ApplyInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessActivity AS BusinessActivity
	|FROM
	|	TemporaryTableFixedAssetsModernization AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsParameters", QueryResult.Unload());
	
EndProcedure // GenerateTableFixedAssetsParameters()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefFixedAssetsModernization, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefFixedAssetsModernization);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.FixedAsset.GLAccount AS GLAccount,
	|	&Company AS Company,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging AS CostForDepreciationCalculationBeforeChanging,
	|	DocumentTable.RevaluationAccount AS RevaluationAccount,
	|	DocumentTable.ApplyInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessActivity AS BusinessActivity
	|INTO TemporaryTableFixedAssetsModernization
	|FROM
	|	Document.FixedAssetsModernization.FixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	GenerateTableFixedAssetsParameters(DocumentRefFixedAssetsModernization, StructureAdditionalProperties);
	GenerateTableFixedAssets(DocumentRefFixedAssetsModernization, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefFixedAssetsModernization, StructureAdditionalProperties);
	GenerateTableManagerial(DocumentRefFixedAssetsModernization, StructureAdditionalProperties);
	
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