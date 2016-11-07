#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	&Ref AS InvoiceForPayment,
	|	DocumentTable.DocumentCurrency AS Currency,
	|	-DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.CashOutflowPlan AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure // GenerateTablePaymentCalendar()

// Creates a document data table.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document StructureAdditionalProperties - AdditionalProperties - Additional properties of the document
//	
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Procedure GenerateCashOutflowPlanning(SpreadsheetDocument, ObjectsArray, PrintObjects)
	
	FirstDocument = True;
	SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_CashOutflowPlan_CashOutflowPlanning";
	Template = PrintManagement.PrintedFormsTemplate("Document.CashOutflowPlan.PF_MXL_CashOutflowPlanning");
	
	FillStructureSection = New Structure;
	For Each CurrentDocument IN ObjectsArray Do
		
		If Not FirstDocument Then
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
		EndIf;
		
		FirstDocument = False;
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	CAOutflowPlan.Ref,
		|	CAOutflowPlan.Number AS Number,
		|	CAOutflowPlan.Date AS DocumentDate,
		|	CAOutflowPlan.Company AS Company,
		|	CAOutflowPlan.Company.Prefix AS Prefix,
		|	CAOutflowPlan.DocumentAmount AS Amount,
		|	CAOutflowPlan.DocumentCurrency AS Currency,
		|	PRESENTATION(CAOutflowPlan.CashFlowItem) AS CFItem,
		|	CAST(CAOutflowPlan.Comment AS String(1000)) AS Comment,
		|	CAOutflowPlan.CashAssetsType AS CAType,
		|	CAOutflowPlan.BankAccount.Code AS BANumber,
		|	CAOutflowPlan.PettyCash AS PettyCash,
		|	PRESENTATION(CAOutflowPlan.BasisDocument) AS DescriptionBases,
		|	CASE 
		|		WHEN CAOutflowPlan.Posted AND CAOutflowPlan.PaymentConfirmationStatus = Value(Enum.PaymentApprovalStatuses.Approved) THEN True
		|		ELSE False
		|	END AS ApplicationApproved,
		|	CAOutflowPlan.IncomingDocumentNumber,
		|	CAOutflowPlan.IncomingDocumentDate,
		|	CAOutflowPlan.Counterparty AS Counterparty,
		|	CAOutflowPlan.Contract AS Contract,
		|	CAOutflowPlan.Author
		|FROM
		|	Document.CashOutflowPlan AS CAOutflowPlan
		|WHERE
		|	CAOutflowPlan.Ref = &CurrentDocument";
		Query.SetParameter("CurrentDocument", CurrentDocument);
		DocumentData = Query.Execute().Select();
		DocumentData.Next();
		
		//:::Approved, indent
		TemplateArea = Template.GetArea(?(DocumentData.ApplicationApproved, "Approved", "Indent"));
		SpreadsheetDocument.Put(TemplateArea);
		
		//:::Header
		TemplateArea = Template.GetArea("Header");
		FillStructureSection.Clear();
		
		DocumentNumber = SmallBusinessServer.GetNumberForPrintingConsideringDocumentDate(DocumentData.DocumentDate, DocumentData.Number, DocumentData.Prefix);
		DocumentDate = Format(DocumentData.DocumentDate, "DF=dd MMMM yyyy'");
		Title = NStr("en='Planning of the cash assets outflow # ';ru='Планирование расхода денежных средств № '") + DocumentNumber + NStr("en=' dated ';ru=' от '") + DocumentDate;
		FillStructureSection.Insert("Title", Title);
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		//:::String
		TemplateArea = Template.GetArea("String");
		FillStructureSection.Clear();
		
		FillStructureSection.Insert("CFItem", DocumentData.CFItem);
		FillStructureSection.Insert("Comment", DocumentData.Comment);
		FillStructureSection.Insert("DescriptionAmount", Format(DocumentData.Amount, "ND=15; NFD=2; NDS=.") + ", " + DocumentData.Currency);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		//:::Footer
		TemplateArea = Template.GetArea("Footer");
		FillStructureSection.Clear();
		
		FillStructureSection.Insert("AmountInWords", WorkWithCurrencyRates.GenerateAmountInWords(DocumentData.Amount, DocumentData.Currency));
		FillStructureSection.Insert("DescriptionBases", DocumentData.DescriptionBases);
		FillStructureSection.Insert("CounterpartyDescription", DocumentData.Counterparty);
		
		FundingSourceDescription = "";
		If DocumentData.CAType = Enums.CashAssetTypes.Noncash Then
			
			FundingSourceDescription = NStr("en='company settlement account No. ';ru='расчетный счет организации № '") + DocumentData.BANumber;
			
		ElsIf DocumentData.CAType = Enums.CashAssetTypes.Noncash Then
			
			FundingSourceDescription = NStr("en=""Organisation's cash "";ru='касса организации '") + DocumentData.PettyCash;
			
		EndIf;
		FillStructureSection.Insert("FundingSourceDescription", FundingSourceDescription);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		//:::Signature
		TemplateArea = Template.GetArea("Signature");
		FillStructureSection.Clear();
		
		ResponsiblePersons = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(DocumentData.Company, DocumentData.DocumentDate);
		FillStructureSection.Insert("HeadPosition", ResponsiblePersons.HeadPosition);
		FillStructureSection.Insert("ChiefAccountantPosition", ResponsiblePersons.ChiefAccountantPosition);
		FillStructureSection.Insert("HeadNameAndSurname", ResponsiblePersons.HeadDescriptionFull);
		FillStructureSection.Insert("ChiefAccountantNameAndSurname", ResponsiblePersons.ChiefAccountantNameAndSurname);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
EndProcedure // GenerateCashOutflowPlanning()

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
	
	SpreadsheetDocument = New SpreadsheetDocument;
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CashOutflowPlanning") Then
		
		GenerateCashOutflowPlanning(SpreadsheetDocument, ObjectsArray, PrintObjects);
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CashOutflowPlanning", "Cash outflow planning", SpreadsheetDocument);
		
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
	PrintCommand.ID = "CashOutflowPlanning";
	PrintCommand.Presentation = NStr("en='Cash outflow planning';ru='Планирование расходов ДС'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf