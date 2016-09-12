#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOtherExpenses, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	OtherExpensesCosts.Ref.StructuralUnit AS StructuralUnit,
	|	OtherExpensesCosts.GLExpenseAccount AS GLAccount,
	|	OtherExpensesCosts.CustomerOrder AS CustomerOrder,
	|	OtherExpensesCosts.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND (OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN VALUE(Catalog.BusinessActivities.Other)
	|		ELSE OtherExpensesCosts.BusinessActivity
	|	END AS BusinessActivity,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE OtherExpensesCosts.Ref.StructuralUnit
	|	END AS StructuralUnit,
	|	OtherExpensesCosts.GLExpenseAccount AS GLAccount,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates)
	|			THEN UNDEFINED
	|		ELSE OtherExpensesCosts.CustomerOrder
	|	END AS CustomerOrder,
	|	0 AS AmountIncome,
	|	OtherExpensesCosts.Amount AS AmountExpense,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND (OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CreditInterestRates))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	SUM(OtherExpensesCosts.Amount) AS AmountIncome,
	|	SUM(OtherExpensesCosts.Amount) AS Amount,
	|	OtherExpensesCosts.Ref.Correspondence AS GLAccount,
	|	&RevenueIncomes AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|	AND OtherExpensesCosts.Amount > 0
	|
	|GROUP BY
	|	OtherExpensesCosts.Ref,
	|	OtherExpensesCosts.Ref.Date,
	|	OtherExpensesCosts.Ref.Correspondence
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	OtherExpensesCosts.GLExpenseAccount AS AccountDr,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurDr,
	|	OtherExpensesCosts.Ref.Correspondence AS AccountCr,
	|	CASE
	|		WHEN OtherExpensesCosts.Ref.Correspondence.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN OtherExpensesCosts.Ref.Correspondence.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurCr,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherIncome AS Content
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.Amount > 0");
	
	Query.SetParameter("Ref", DocumentRefOtherExpenses);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("OtherExpenses", NStr("en='Expenses reflection';ru='Отражение затрат'"));
	Query.SetParameter("RevenueIncomes", NStr("en='Other income';ru='Прочие доходы'"));
	Query.SetParameter("OtherIncome", NStr("en='Other expenses';ru='Прочих затраты (расходы)'"));
	
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[1].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[2].Unload());
	Else
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[3].Unload());
	
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