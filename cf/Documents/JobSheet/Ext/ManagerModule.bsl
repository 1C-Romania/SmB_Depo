#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefJobSheet, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	("SELECT
	 |	JobSheetTeamMembers.Employee,
	 |	CASE
	 |		WHEN TableAmountCWP.AmountLPF = 0
	 |			THEN 0
	 |		ELSE JobSheetTeamMembers.LPF / TableAmountCWP.AmountLPF
	 |	END AS Factor
	 |INTO TableEmployees
	 |FROM
	 |	Document.JobSheet.TeamMembers AS JobSheetTeamMembers
	 |		LEFT JOIN (SELECT
	 |			SUM(JobSheetTeamMembers.LPF) AS AmountLPF,
	 |			JobSheetTeamMembers.Ref AS Ref
	 |		FROM
	 |			Document.JobSheet.TeamMembers AS JobSheetTeamMembers
	 |		WHERE
	 |			JobSheetTeamMembers.Ref = &Ref
	 |		
	 |		GROUP BY
	 |			JobSheetTeamMembers.Ref) AS TableAmountCWP
	 |		ON JobSheetTeamMembers.Ref = TableAmountCWP.Ref
	 |WHERE
	 |	JobSheetTeamMembers.Ref = &Ref
	 |	AND NOT JobSheetTeamMembers.Ref.Performer REFS Catalog.Employees
	 |
	 |UNION ALL
	 |
	 |SELECT
	 |	JobSheet.Performer,
	 |	1
	 |FROM
	 |	Document.JobSheet AS JobSheet
	 |WHERE
	 |	JobSheet.Ref = &Ref
	 |	AND JobSheet.Performer REFS Catalog.Employees
	 |;
	 |
	 |////////////////////////////////////////////////////////////////////////////////
	 |SELECT
	 |	JobSheetOperations.LineNumber AS LineNumber,
	 |	JobSheetOperations.Period AS Period,
	 |	JobSheetOperations.Ref.DocumentCurrency AS AccountingCurrency,
	 |	&Company AS Company,
	 |	JobSheetOperations.Ref.StructuralUnit AS StructuralUnit,
	 |	JobSheetOperations.Operation.ExpensesGLAccount AS GLAccount,
	 |	JobSheetOperations.ProductsAndServices.ExpensesGLAccount AS CorrGLAccount,
	 |	JobSheetOperations.ProductsAndServices AS ProductsAndServicesCorr,
	 |	JobSheetOperations.Characteristic AS CharacteristicCorr,
	 |	JobSheetOperations.Batch AS BatchCorr,
	 |	JobSheetOperations.Specification AS SpecificationCorr,
	 |	JobSheetOperations.CustomerOrder AS CustomerOrder,
	 |	JobSheetOperations.Cost * SettlementsCurrencyRates.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS Cost,
	 |	JobSheetOperations.Cost AS CostCur,
	 |	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	 |	&Payroll AS ContentOfAccountingRecord,
	 |	JobSheetOperations.StandardHours AS StandardHours,
	 |	JobSheetOperations.Tariff AS Tariff,
	 |	TRUE AS FixedCost,
	 |	CASE
	 |		WHEN &UseSubsystemPayroll
	 |			THEN JobSheetOperations.Ref.Closed
	 |		ELSE FALSE
	 |	END AS Closed,
	 |	JobSheetOperations.Ref.ClosingDate
	 |INTO TableJobSheetOperations
	 |FROM
	 |	Document.JobSheet.Operations AS JobSheetOperations
	 |		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	 |				&PointInTime,
	 |				Currency IN
	 |					(SELECT
	 |						Constants.AccountingCurrency
	 |					FROM
	 |						Constants AS Constants)) AS AccountingCurrencyRates
	 |		ON (TRUE)
	 |		LEFT JOIN Constants AS Constants
	 |		ON (TRUE)
	 |		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	 |		ON JobSheetOperations.Ref.DocumentCurrency = SettlementsCurrencyRates.Currency
	 |WHERE
	 |	JobSheetOperations.Ref = &Ref
	 |	AND (JobSheetOperations.ProductsAndServices.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	 |			OR JobSheetOperations.ProductsAndServices.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	 |;
	 |
	 |////////////////////////////////////////////////////////////////////////////////
	 |SELECT
	 |	&Company AS Company,
	 |	JobSheetOperations.Period AS Period,
	 |	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	 |	BEGINOFPERIOD(JobSheetOperations.ClosingDate, MONTH) AS RegistrationPeriod,
	 |	JobSheetOperations.AccountingCurrency AS Currency,
	 |	JobSheetOperations.StructuralUnit AS StructuralUnit,
	 |	TableEmployees.Employee AS Employee,
	 |	JobSheetOperations.Period AS StartDate,
	 |	JobSheetOperations.Period AS EndDate,
	 |	0 AS DaysWorked,
	 |	JobSheetOperations.StandardHours AS HoursWorked,
	 |	JobSheetOperations.Tariff AS Size,
	 |	VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment) AS AccrualDeductionKind,
	 |	TableEmployees.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	 |	JobSheetOperations.LineNumber AS LineNumber,
	 |	JobSheetOperations.GLAccount AS InventoryGLAccount,
	 |	JobSheetOperations.CorrGLAccount AS CorrespondentAccountAccountingInventory,
	 |	JobSheetOperations.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	 |	JobSheetOperations.CharacteristicCorr AS CharacteristicCorr,
	 |	JobSheetOperations.BatchCorr AS BatchCorr,
	 |	JobSheetOperations.SpecificationCorr,
	 |	JobSheetOperations.CustomerOrder AS CustomerOrder,
	 |	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	 |	&Payroll AS ContentOfAccountingRecord,
	 |	CAST(JobSheetOperations.CostCur * TableEmployees.Factor AS NUMBER(15, 2)) AS AmountCur,
	 |	CAST(JobSheetOperations.Cost * TableEmployees.Factor AS NUMBER(15, 2)) AS Amount,
	 |	TRUE AS FixedCost,
	 |	CASE
	 |		WHEN &UseSubsystemPayroll
	 |			THEN JobSheetOperations.Closed
	 |		ELSE FALSE
	 |	END AS Closed,
	 |	JobSheetOperations.ClosingDate
	 |INTO TableOfOperations
	 |FROM
	 |	TableEmployees AS TableEmployees
	 |		INNER JOIN TableJobSheetOperations AS JobSheetOperations
	 |		ON (TRUE)
	 |;
	 |
	 |////////////////////////////////////////////////////////////////////////////////
	 |SELECT
	 |	TableOfOperations.Company AS Company,
	 |	TableOfOperations.ClosingDate AS Period,
	 |	TableOfOperations.RegistrationPeriod AS RegistrationPeriod,
	 |	TableOfOperations.Currency AS Currency,
	 |	TableOfOperations.StructuralUnit AS StructuralUnit,
	 |	TableOfOperations.Employee AS Employee,
	 |	TableOfOperations.Period AS StartDate,
	 |	TableOfOperations.Period AS EndDate,
	 |	TableOfOperations.DaysWorked AS DaysWorked,
	 |	TableOfOperations.HoursWorked AS HoursWorked,
	 |	TableOfOperations.Size AS Size,
	 |	TableOfOperations.AccrualDeductionKind AS AccrualDeductionKind,
	 |	TableOfOperations.AmountCur AS AmountCur,
	 |	TableOfOperations.Amount AS Amount
	 |FROM
	 |	TableOfOperations AS TableOfOperations
	 |WHERE
	 |	TableOfOperations.Closed
	 |;
	 |
	 |////////////////////////////////////////////////////////////////////////////////
	 |SELECT
	 |	TableOfOperations.Company AS Company,
	 |	TableOfOperations.ClosingDate AS Period,
	 |	TableOfOperations.RecordType AS RecordType,
	 |	TableOfOperations.RegistrationPeriod AS RegistrationPeriod,
	 |	TableOfOperations.Currency AS Currency,
	 |	TableOfOperations.StructuralUnit AS StructuralUnit,
	 |	TableOfOperations.Employee AS Employee,
	 |	TableOfOperations.Amount AS Amount,
	 |	TableOfOperations.AmountCur AS AmountCur,
	 |	TableOfOperations.GLAccount AS GLAccount,
	 |	TableOfOperations.RecordKindManagerial AS RecordKindManagerial,
	 |	TableOfOperations.ContentOfAccountingRecord AS ContentOfAccountingRecord
	 |FROM
	 |	TableOfOperations AS TableOfOperations
	 |WHERE
	 |	TableOfOperations.Closed
	 |;
	 |
	 |////////////////////////////////////////////////////////////////////////////////
	 |SELECT
	 |	JobSheetOperations.Period,
	 |	&Company AS Company,
	 |	JobSheetOperations.Ref.StructuralUnit AS StructuralUnit,
	 |	JobSheetOperations.Ref.Performer,
	 |	JobSheetOperations.Operation,
	 |	JobSheetOperations.ProductsAndServices,
	 |	JobSheetOperations.Characteristic,
	 |	JobSheetOperations.CustomerOrder,
	 |	JobSheetOperations.StandardHours AS StandardHours,
	 |	CASE
	 |		WHEN VALUETYPE(JobSheetOperations.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	 |			THEN JobSheetOperations.QuantityPlan
	 |		ELSE JobSheetOperations.QuantityPlan * JobSheetOperations.MeasurementUnit.Factor
	 |	END AS QuantityPlan,
	 |	CASE
	 |		WHEN VALUETYPE(JobSheetOperations.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	 |			THEN JobSheetOperations.QuantityFact
	 |		ELSE JobSheetOperations.QuantityFact * JobSheetOperations.MeasurementUnit.Factor
	 |	END AS QuantityFact
	 |FROM
	 |	Document.JobSheet.Operations AS JobSheetOperations
	 |WHERE
	 |	JobSheetOperations.Ref = &Ref
	 |;
	 |
	 |////////////////////////////////////////////////////////////////////////////////
	 |SELECT
	 |	MIN(TableOfOperations.LineNumber) AS LineNumber,
	 |	TableOfOperations.RecordType AS RecordType,
	 |	TableOfOperations.ClosingDate AS Period,
	 |	TableOfOperations.Company AS Company,
	 |	TableOfOperations.StructuralUnit AS StructuralUnit,
	 |	TableOfOperations.StructuralUnit AS StructuralUnitCorr,
	 |	TableOfOperations.InventoryGLAccount AS GLAccount,
	 |	TableOfOperations.CorrespondentAccountAccountingInventory AS CorrGLAccount,
	 |	TableOfOperations.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	 |	TableOfOperations.CharacteristicCorr AS CharacteristicCorr,
	 |	TableOfOperations.BatchCorr AS BatchCorr,
	 |	TableOfOperations.SpecificationCorr,
	 |	VALUE(Catalog.ProductsAndServices.EmptyRef) AS ProductsAndServices,
	 |	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	 |	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	 |	VALUE(Catalog.Specifications.EmptyRef) AS Specification,
	 |	TableOfOperations.CustomerOrder AS CustomerOrder,
	 |	TableOfOperations.CustomerOrder AS CustomerCorrOrder,
	 |	SUM(TableOfOperations.Amount) AS Amount,
	 |	TRUE AS FixedCost,
	 |	FALSE AS ProductionExpenses,
	 |	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	 |	TableOfOperations.ContentOfAccountingRecord AS ContentOfAccountingRecord
	 |FROM
	 |	TableOfOperations AS TableOfOperations
	 |WHERE
	 |	TableOfOperations.Closed
	 |
	 |GROUP BY
	 |	TableOfOperations.InventoryGLAccount,
	 |	TableOfOperations.CorrespondentAccountAccountingInventory,
	 |	TableOfOperations.ProductsAndServicesCorr,
	 |	TableOfOperations.CharacteristicCorr,
	 |	TableOfOperations.BatchCorr,
	 |	TableOfOperations.ContentOfAccountingRecord,
	 |	TableOfOperations.Company,
	 |	TableOfOperations.StructuralUnit,
	 |	TableOfOperations.CustomerOrder,
	 |	TableOfOperations.SpecificationCorr,
	 |	TableOfOperations.ClosingDate,
	 |	TableOfOperations.RecordType,
	 |	TableOfOperations.StructuralUnit,
	 |	TableOfOperations.CustomerOrder
	 |;
	 |
	 |////////////////////////////////////////////////////////////////////////////////
	 |SELECT
	 |	TableOfOperations.LineNumber AS LineNumber,
	 |	TableOfOperations.ClosingDate AS Period,
	 |	&Company AS Company,
	 |	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	 |	TableOfOperations.InventoryGLAccount AS AccountDr,
	 |	CASE
	 |		WHEN TableOfOperations.InventoryGLAccount.Currency
	 |			THEN TableOfOperations.Currency
	 |		ELSE UNDEFINED
	 |	END AS CurrencyDr,
	 |	CASE
	 |		WHEN TableOfOperations.InventoryGLAccount.Currency
	 |			THEN TableOfOperations.AmountCur
	 |		ELSE 0
	 |	END AS AmountCurDr,
	 |	TableOfOperations.GLAccount AS AccountCr,
	 |	CASE
	 |		WHEN TableOfOperations.GLAccount.Currency
	 |			THEN TableOfOperations.Currency
	 |		ELSE UNDEFINED
	 |	END AS CurrencyCr,
	 |	CASE
	 |		WHEN TableOfOperations.GLAccount.Currency
	 |			THEN TableOfOperations.AmountCur
	 |		ELSE 0
	 |	END AS AmountCurCr,
	 |	TableOfOperations.Amount AS Amount,
	 |	&Payroll AS Content
	 |FROM
	 |	TableOfOperations AS TableOfOperations
	 |WHERE
	 |	TableOfOperations.Amount > 0
	 |	AND TableOfOperations.Closed
	 |
	 |UNION ALL
	 |
	 |SELECT
	 |	TableOfOperations.LineNumber,
	 |	TableOfOperations.ClosingDate,
	 |	&Company,
	 |	VALUE(Catalog.PlanningPeriods.Actual),
	 |	TableOfOperations.CorrespondentAccountAccountingInventory,
	 |	CASE
	 |		WHEN TableOfOperations.CorrespondentAccountAccountingInventory.Currency
	 |			THEN TableOfOperations.Currency
	 |		ELSE UNDEFINED
	 |	END,
	 |	CASE
	 |		WHEN TableOfOperations.CorrespondentAccountAccountingInventory.Currency
	 |			THEN TableOfOperations.AmountCur
	 |		ELSE 0
	 |	END,
	 |	TableOfOperations.InventoryGLAccount,
	 |	CASE
	 |		WHEN TableOfOperations.InventoryGLAccount.Currency
	 |			THEN TableOfOperations.Currency
	 |		ELSE UNDEFINED
	 |	END,
	 |	CASE
	 |		WHEN TableOfOperations.InventoryGLAccount.Currency
	 |			THEN TableOfOperations.AmountCur
	 |		ELSE 0
	 |	END,
	 |	TableOfOperations.Amount,
	 |	&SalaryDistribution
	 |FROM
	 |	TableOfOperations AS TableOfOperations
	 |WHERE
	 |	TableOfOperations.Amount > 0
	 |	AND TableOfOperations.Closed");
	
	Query.SetParameter("Ref",					DocumentRefJobSheet);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",			StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Payroll",		NStr("en = 'Payroll'"));
	Query.SetParameter("SalaryDistribution",		NStr("en='Cost application on finished goods';ru='Отнесение затрат на продукцию'"));
	
	// FO Use Payroll subsystem.
	Query.SetParameter("UseSubsystemPayroll", Constants.FunctionalOptionUseSubsystemPayroll.Get());
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccrualsAndDeductions", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayrollPayments", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("jobSheetTable", ResultsArray[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryOperations", ResultsArray[6].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryOperations.CopyColumns());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[7].Unload());
	
	IsEmptyStructuralUnit = Catalogs.StructuralUnits.EmptyRef();
	EmptyAccount = ChartsOfAccounts.Managerial.EmptyRef();
	EmptyProductsAndServices = Catalogs.ProductsAndServices.EmptyRef();
	EmptyCharacteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
	EmptyBatch = Catalogs.ProductsAndServicesBatches.EmptyRef();
	EmptyCustomerOrder = Documents.CustomerOrder.EmptyRef();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryOperations.Count() - 1 Do
		
		RowTableInventoryOperations = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryOperations[n];
		
		// Credit payroll costs in the UFP.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryOperations);
		
		TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
		TableRowReceipt.CorrGLAccount = EmptyAccount;
		TableRowReceipt.ProductsAndServicesCorr = EmptyProductsAndServices;
		TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
		TableRowReceipt.BatchCorr = EmptyBatch;
		TableRowReceipt.CustomerCorrOrder = EmptyCustomerOrder;
		
		// We will write off them on production.
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, RowTableInventoryOperations);
		TableRowExpense.RecordType = AccumulationRecordType.Expense;
		TableRowExpense.RecordKindManagerial = AccountingRecordType.Credit;
		TableRowExpense.FixedCost = False;
		TableRowExpense.ProductionExpenses = True;
		
		// Include in the product cost.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryOperations);
		
		TableRowReceipt.StructuralUnit = RowTableInventoryOperations.StructuralUnitCorr;
		TableRowReceipt.GLAccount = RowTableInventoryOperations.CorrGLAccount;
		TableRowReceipt.ProductsAndServices = RowTableInventoryOperations.ProductsAndServicesCorr;
		TableRowReceipt.Characteristic = RowTableInventoryOperations.CharacteristicCorr;
		TableRowReceipt.Batch = RowTableInventoryOperations.BatchCorr;
		TableRowReceipt.CustomerOrder = RowTableInventoryOperations.CustomerCorrOrder;
		
		TableRowReceipt.StructuralUnitCorr = RowTableInventoryOperations.StructuralUnit;
		TableRowReceipt.CorrGLAccount = RowTableInventoryOperations.GLAccount;
		TableRowReceipt.ProductsAndServicesCorr = RowTableInventoryOperations.ProductsAndServices;
		TableRowReceipt.CharacteristicCorr = RowTableInventoryOperations.Characteristic;
		TableRowReceipt.BatchCorr = RowTableInventoryOperations.Batch;
		TableRowReceipt.CustomerCorrOrder = RowTableInventoryOperations.CustomerOrder;
		
		TableRowReceipt.FixedCost = False;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryOperations");
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		
		Query.SetParameter("Company", 		SmallBusinessServer.GetCompany(CurrentDocument.Company));
		Query.SetParameter("CurrentDocument", 	CurrentDocument);
		
		Query.Text = 
		"SELECT
		|	JobSheet.Ref AS Ref,
		|	JobSheet.DataVersion,
		|	JobSheet.DeletionMark,
		|	JobSheet.Number,
		|	JobSheet.Date AS DocumentDate,
		|	JobSheet.Posted,
		|	JobSheet.Company,
		|	JobSheet.StructuralUnit,
		|	JobSheet.Performer,
		|	JobSheet.Comment,
		|	JobSheet.DocumentCurrency,
		|	JobSheet.DocumentAmount,
		|	JobSheet.Author,
		|	JobSheet.Closed,
		|	JobSheet.ClosingDate
		|FROM
		|	Document.JobSheet AS JobSheet
		|WHERE
		|	JobSheet.Ref = &CurrentDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	JobSheetOperations.Ref,
		|	JobSheetOperations.LineNumber,
		|	JobSheetOperations.Period AS Day,
		|	JobSheetOperations.CustomerOrder,
		|	JobSheetOperations.ProductsAndServices,
		|	JobSheetOperations.ProductsAndServices.Code AS Code,
		|	JobSheetOperations.ProductsAndServices.SKU AS SKU,
		|	JobSheetOperations.Characteristic,
		|	JobSheetOperations.Operation,
		|	JobSheetOperations.MeasurementUnit,
		|	JobSheetOperations.QuantityPlan AS QuantityPlan,
		|	JobSheetOperations.QuantityFact AS QuantityFact,
		|	JobSheetOperations.TimeNorm,
		|	JobSheetOperations.Tariff,
		|	JobSheetOperations.StandardHours AS StandardHours,
		|	JobSheetOperations.Cost AS Cost,
		|	JobSheetOperations.Batch,
		|	JobSheetOperations.Specification
		|FROM
		|	Document.JobSheet.Operations AS JobSheetOperations
		|WHERE
		|	JobSheetOperations.Ref = &CurrentDocument
		|
		|ORDER BY
		|	JobSheetOperations.Period
		|TOTALS
		|	SUM(QuantityPlan),
		|	SUM(QuantityFact),
		|	SUM(StandardHours),
		|	SUM(Cost)
		|BY
		|	Day";
		
		QueryResult	= Query.ExecuteBatch();
		Header 				= QueryResult[0].Select();
		Header.Next();
		
		SelectionDays			=QueryResult[1].Select(QueryResultIteration.ByGroups);
		
		Template = PrintManagement.PrintedFormsTemplate("Document.JobSheet.Template");
		
		RegHeader		= Template.GetArea("Header");
		OblTableHeader	= Template.GetArea("TableHeader");
		AreDey			= Template.GetArea("Day");
		RegionDetails		= Template.GetArea("Details");
		RegionFooter		= Template.GetArea("Footer");
		
		RegHeader.Parameters.Fill(Header);
		RegHeader.Parameters.DocumentTitle = "Job sheet # " + Header.Number + " dated " + Format(Header.DocumentDate, "DLF=DD");
		SpreadsheetDocument.Put(RegHeader);
		
		OblTableHeader.Parameters.Cost = "Cost (" + Header.DocumentCurrency + ")";
		SpreadsheetDocument.Put(OblTableHeader);
		
		NPP = 0;
		
		While SelectionDays.Next() Do
			
			AreDey.Parameters.Fill(SelectionDays);
			SpreadsheetDocument.Put(AreDey);
			
			SelectionOperations = SelectionDays.Select();
			While SelectionOperations.Next() Do
				
				NPP = NPP + 1;
				
				RegionDetails.Parameters.Fill(SelectionOperations);
				RegionDetails.Parameters.NPP = NPP;
				
				SpreadsheetDocument.Put(RegionDetails);
				
			EndDo;
			
		EndDo;
		
		RegionFooter.Parameters.Cost = Header.DocumentAmount;
		SpreadsheetDocument.Put(RegionFooter);
		
	EndDo;
	
	SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "JobSheet") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "JobSheet", "Job sheet", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "JobSheet";
	PrintCommand.Presentation = NStr("en='Job sheet';ru='Сдельный  наряд'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf