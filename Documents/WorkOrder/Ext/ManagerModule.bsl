#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefWorkOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	&Company AS Company,
	|	JobOrderWorks.Day AS Period,
	|	CASE
	|		WHEN JobOrderWorks.Customer REFS Catalog.Counterparties
	|			THEN JobOrderWorks.Customer
	|		WHEN JobOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN JobOrderWorks.Customer.Owner
	|		WHEN JobOrderWorks.Customer REFS Document.CustomerOrder
	|			THEN JobOrderWorks.Customer.Counterparty
	|	END AS Counterparty,
	|	CASE
	|		WHEN JobOrderWorks.Customer REFS Catalog.Counterparties
	|			THEN VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|		WHEN JobOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN JobOrderWorks.Customer
	|		WHEN JobOrderWorks.Customer REFS Document.CustomerOrder
	|			THEN JobOrderWorks.Customer.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN JobOrderWorks.Customer REFS Catalog.Counterparties
	|				OR JobOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN JobOrderWorks.Customer REFS Document.CustomerOrder
	|			THEN JobOrderWorks.Customer
	|	END AS CustomerOrder,
	|	JobOrderWorks.Ref.Employee,
	|	JobOrderWorks.ProductsAndServices,
	|	JobOrderWorks.Characteristic,
	|	JobOrderWorks.WorkKind,
	|	JobOrderWorks.DurationInHours AS ImportPlan,
	|	JobOrderWorks.Amount AS AmountPlan,
	|	JobOrderWorks.Ref.StructuralUnit,
	|	DATEADD(JobOrderWorks.Day, MINUTE, hour(JobOrderWorks.BeginTime) * 60 + MINUTE(JobOrderWorks.BeginTime)) AS BeginTime,
	|	DATEADD(JobOrderWorks.Day, MINUTE, hour(JobOrderWorks.EndTime) * 60 + MINUTE(JobOrderWorks.EndTime)) AS EndTime,
	|	JobOrderWorks.Comment
	|FROM
	|	Document.WorkOrder.Works AS JobOrderWorks
	|WHERE
	|	JobOrderWorks.Ref = &Ref
	|	AND JobOrderWorks.DurationInHours > 0";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);
    Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);

	Result = Query.Execute();
	TableWorkOrders = Result.Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", TableWorkOrders);
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName = "")
	
	SpreadsheetDocument 	= New SpreadsheetDocument;
	FirstDocument 		= True;
	
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
		|	WorkOrder.Ref,
		|	WorkOrder.DataVersion,
		|	WorkOrder.DeletionMark,
		|	WorkOrder.Number,
		|	WorkOrder.Date,
		|	WorkOrder.Posted,
		|	WorkOrder.Company,
		|	WorkOrder.OperationKind,
		|	WorkOrder.WorkKind AS WorkKind,
		|	WorkOrder.PriceKind,
		|	WorkOrder.Employee AS Employee,
		|	WorkOrder.Employee.Code AS EmployeeCode,
		|	WorkOrder.StructuralUnit AS Division,
		|	EmployeesSliceLast.Position AS Position,
		|	WorkOrder.DocumentAmount,
		|	WorkOrder.WorkKindPosition,
		|	WorkOrder.Event,
		|	WorkOrder.Comment,
		|	WorkOrder.Author
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|		LEFT JOIN InformationRegister.Employees.SliceLast(, ) AS EmployeesSliceLast
		|		ON WorkOrder.Employee = EmployeesSliceLast.Employee
		|			AND (&Company = EmployeesSliceLast.Company)
		|WHERE
		|	WorkOrder.Ref = &CurrentDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	JobOrderWorks.Ref,
		|	JobOrderWorks.LineNumber,
		|	JobOrderWorks.WorkKind,
		|	JobOrderWorks.Customer,
		|	JobOrderWorks.ProductsAndServices,
		|	JobOrderWorks.Characteristic,
		|	JobOrderWorks.Day AS Day,
		|	JobOrderWorks.BeginTime AS BeginTime,
		|	JobOrderWorks.EndTime,
		|	JobOrderWorks.Duration,
		|	JobOrderWorks.DurationInHours AS DurationInHours,
		|	JobOrderWorks.Price,
		|	JobOrderWorks.Amount AS Amount,
		|	JobOrderWorks.Comment AS TaskDescription
		|FROM
		|	Document.WorkOrder.Works AS JobOrderWorks
		|WHERE
		|	JobOrderWorks.Ref = &CurrentDocument
		|
		|ORDER BY
		|	BeginTime
		|TOTALS
		|	SUM(DurationInHours),
		|	SUM(Amount)
		|BY
		|	Day";
		
		QueryResult	= Query.ExecuteBatch();
		Header 				= QueryResult[0].Select();
		Header.Next();
		
		DaysSelection			= QueryResult[1].Select(QueryResultIteration.ByGroups);
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_WorkOrder_UnifiedForm";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.WorkOrder.PF_MXL_Task");
		
		AreaHeader		= Template.GetArea("Header");
		TableHeaderArea	= Template.GetArea("TableHeader");
		AreaDay			= Template.GetArea("Day");
		AreaDetails		= Template.GetArea("Details");
		AreaTotalAmount		= Template.GetArea("Total");
		FooterArea		= Template.GetArea("Footer");
		
		AreaHeader.Parameters.Fill(Header);
		
		AreaHeader.Parameters.NumberDate = "#" + Header.Number + " dated " + Format(Header.Date, "DLF=DD");
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date, ,);
		AreaHeader.Parameters.CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,ActualAddress,PhoneNumbers,AccountNo,Bank,BIN,CorrAccount");
		
		SpreadsheetDocument.Put(AreaHeader);
		
		TableHeaderArea.Parameters.TaskKindText = "Task is" + ?(Header.OperationKind = Enums.OperationKindsWorkOrder.External, " external", " internal");
		SpreadsheetDocument.Put(TableHeaderArea);
		
		TotalDurationInHours = 0;
		
		While DaysSelection.Next() Do
			
			AreaDay.Parameters.Fill(DaysSelection);
			SpreadsheetDocument.Put(AreaDay);
			
			SelectionDayJobs	= DaysSelection.Select();
			While SelectionDayJobs.Next() Do
				
				TotalDurationInHours = TotalDurationInHours + SelectionDayJobs.DurationInHours;
				AreaDetails.Parameters.Fill(SelectionDayJobs);
				
				// If kind of work is shown in TS, then generate the description 
				If Header.WorkKindPosition = Enums.AttributePositionOnForm.InTabularSection Then
					
					AreaDetails.Parameters.TaskDescription = "[" + SelectionDayJobs.WorkKind + "] " + SelectionDayJobs.TaskDescription;
					
				EndIf;
				
				
				SpreadsheetDocument.Put(AreaDetails);
				
			EndDo;
			
		EndDo;
	
		AreaTotalAmount.Parameters.Fill(Header);
		AreaTotalAmount.Parameters.DurationInHours = TotalDurationInHours;
		SpreadsheetDocument.Put(AreaTotalAmount);
		
		FooterArea.Parameters.DetailsOfResponsible = "" + Header.Employee + ?(ValueIsFilled(Header.Position), ", " + Header.Position, "");
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
		SpreadsheetDocument.Put(FooterArea);
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated by commas
//   ObjectsArray     - Array     - Array of refs to objects that need to be printed
//   PrintParameters  - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated table documents 
//   OutputParameters     - Structure    - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "WorkOrders") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "WorkOrders", "Work order", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure  //Print()

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "WorkOrders";
	PrintCommand.Presentation = NStr("en = 'Work order'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf