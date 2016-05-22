#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefTimeTracking, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	WeekDays = New Map;
	WeekDays.Insert(0, "Mo");
	WeekDays.Insert(1, "Tu");
	WeekDays.Insert(2, "We");
	WeekDays.Insert(3, "Th");
	WeekDays.Insert(4, "Fr");
	WeekDays.Insert(5, "Sa");
	WeekDays.Insert(6, "Su");		
			
	QueryText = "";
	
	For Counter = 0 To 6 Do
		
		Prefix = WeekDays.Get(Counter);
		                                                              
		QueryText = 	QueryText + ?(Counter > 0, "	
		|UNION ALL
		| 
		|", "") + 
		"SELECT
		|	TimeTrackingOperations.LineNumber,
		|	DATEADD(TimeTrackingOperations.Ref.DateFrom, Day, " + Counter + ") AS Period,
		|	CASE
		|		WHEN TimeTrackingOperations.Customer REFS Catalog.Counterparties
		|			THEN TimeTrackingOperations.Customer
		|		WHEN TimeTrackingOperations.Customer REFS Catalog.CounterpartyContracts
		|			THEN TimeTrackingOperations.Customer.Owner
		|		WHEN TimeTrackingOperations.Customer REFS Document.CustomerOrder
		|			THEN TimeTrackingOperations.Customer.Counterparty
		|	END AS Counterparty,
		|	CASE
		|		WHEN TimeTrackingOperations.Customer REFS Catalog.Counterparties
		|			THEN VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|		WHEN TimeTrackingOperations.Customer REFS Catalog.CounterpartyContracts
		|			THEN TimeTrackingOperations.Customer
		|		WHEN TimeTrackingOperations.Customer REFS Document.CustomerOrder
		|			THEN TimeTrackingOperations.Customer.Contract
		|	END AS Contract,
		|	CASE
		|		WHEN TimeTrackingOperations.Customer REFS Catalog.Counterparties
		|				OR TimeTrackingOperations.Customer REFS Catalog.CounterpartyContracts
		|			THEN VALUE(Document.CustomerOrder.EmptyRef)
		|		WHEN TimeTrackingOperations.Customer REFS Document.CustomerOrder
		|			THEN TimeTrackingOperations.Customer
		|	END AS CustomerOrder,
		|	TimeTrackingOperations.Ref.Employee,
		|	TimeTrackingOperations.ProductsAndServices AS ProductsAndServices,
		|	TimeTrackingOperations.Characteristic AS Characteristic,
		|	TimeTrackingOperations.WorkKind AS WorkKind,
		|	TimeTrackingOperations." + Prefix + "Duration AS ImportFact,
		|	TimeTrackingOperations." + Prefix + "Duration * TimeTrackingOperations.Tariff AS AmountFact,
  |TimeTrackingOperations.Ref.StructuralUnit,
|&Company AS Company, 
|DATEADD(TimeTrackingOperations.Ref.DateFrom, MINUTE, Hour(TimeTrackingOperations." + Prefix + "BeginTime) * 60 + MINUTE (TimeTrackingOperations." + Prefix + "BeginTime) + 1440 * " + Counter + ") AS BegintTime, 
|DATEADD(TimeTrackingOperations.Ref.DateFrom, MINUTE, HOUR(TimeTrackingOperations." + Prefix + "EndTime) * 60 + MINUTE (TimeTrackingOperations." + Prefix + "EndTime) + 1440 * " + Counter + ") AS EndTime,
		|	TimeTrackingOperations.Comment
		|FROM
		|	Document.TimeTracking.Operations AS TimeTrackingOperations
		|WHERE
		|	TimeTrackingOperations.Ref = &Ref
		|	AND TimeTrackingOperations." + Prefix + "Duration > 0";
	
	EndDo; 
	
	Query.Text = QueryText;	
	
	Query.SetParameter("Ref", DocumentRefTimeTracking);
    Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);

	Result = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", Result.Unload());
	
EndProcedure // DocumentDataInitialization()

#EndRegion

#Region PrintInterface

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_TimeTracking";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text = 
	"SELECT
	|	TimeTracking.Ref,
	|	TimeTracking.Date AS DocumentDate,
	|	TimeTracking.Company.DescriptionFull AS Company,
	|	TimeTracking.Number AS Number,
	|	TimeTracking.Company.Prefix AS Prefix,
	|	TimeTracking.StructuralUnit,
	|	TimeTracking.Employee,
	|	TimeTracking.Employee.Code AS TabNumber,
	|	TimeTracking.DateFrom,
	|	TimeTracking.DateTo,
	|	TimeTracking.Operations.(
	|		LineNumber AS LineNumber,
	|		Customer,
	|		CASE
	|			WHEN (CAST(TimeTracking.Operations.WorkKind.DescriptionFull AS String(1000))) = """"
	|				THEN TimeTracking.Operations.WorkKind.Description
	|			ELSE CAST(TimeTracking.Operations.WorkKind.DescriptionFull AS String(1000))
	|		END AS WorkKind,
	|		CASE
	|			WHEN (CAST(TimeTracking.Operations.ProductsAndServices.DescriptionFull AS String(1000))) = """"
	|				THEN TimeTracking.Operations.ProductsAndServices.Description
	|			ELSE CAST(TimeTracking.Operations.ProductsAndServices.DescriptionFull AS String(1000))
	|		END AS ProductsAndServices,
	|		Characteristic,
	|		Tariff,
	|		Total,
	|		Amount AS Amount,
	|		Comment,
	|		MoDuration AS Mo,
	|		TuDuration AS Tu,
	|		WeDuration AS We,
	|		ThDuration AS Th,
	|		FrDuration AS Fr,
	|		SaDuration AS Sa,
	|		SuDuration AS Su,
	|		MoBeginTime AS MoFrom,
	|		MoEndTime AS MoTo,
	|		TuBeginTime AS TuFrom,
	|		TuEndTime AS TuTo,
	|		WeEndTime AS WeTo,
	|		WeBeginTime AS WeFrom,
	|		ThBeginTime AS ThFrom,
	|		ThEndTime AS ThOn,
	|		FrBeginTime AS FrFr,
	|		FrEndTime AS FrTo,
	|		SaBeginTime AS SbS,
	|		SaEndTime AS SaTo,
	|		SuBeginTime AS VsS,
	|		SuEndTime AS SuOn,
	|		ProductsAndServices.SKU AS SKU
	|	)
	|FROM
	|	Document.TimeTracking AS TimeTracking
	|WHERE
	|	TimeTracking.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	LineNumber";
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_Template_TimeTracking";
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		Template = PrintManagement.PrintedFormsTemplate("Document.TimeTracking.PF_MXL_Template");
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Time tracking No "
												+ DocumentNumber
												+ " from "
												+ Format(Header.DocumentDate, "DLF=DD");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Employee");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.DateFrom = Format(Header.DateFrom, "DF=dd.MM.yy");
		TemplateArea.Parameters.DateTo = Format(Header.DateTo, "DF=dd.MM.yy");
		SpreadsheetDocument.Put(TemplateArea);
		
		LinesSelectionOperations = Header.Operations.Select();
		
		TemplateArea = Template.GetArea("TableHeader");
				
		TemplateArea.Parameters.Mo = Format(Header.DateFrom, "DF=dd.MM");
		TemplateArea.Parameters.Tu = Format(Header.DateFrom + 86400, "DF=dd.MM");
		TemplateArea.Parameters.We = Format(Header.DateFrom + 86400*2, "DF=dd.MM");
		TemplateArea.Parameters.Th = Format(Header.DateFrom + 86400*3, "DF=dd.MM");
		TemplateArea.Parameters.Fr = Format(Header.DateFrom + 86400*4, "DF=dd.MM");
		TemplateArea.Parameters.Sa = Format(Header.DateFrom + 86400*5, "DF=dd.MM");
		TemplateArea.Parameters.Su = Format(Header.DateFrom + 86400*6, "DF=dd.MM");	
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("String");
		
		Amount   = 0;
		TotalAmount   = 0;
		
		While LinesSelectionOperations.Next() Do
			
			TemplateArea.Parameters.Fill(LinesSelectionOperations);
			
	        If ValueIsFilled(LinesSelectionOperations.MoFrom) OR ValueIsFilled(LinesSelectionOperations.MoTo) Then
				TemplateArea.Parameters.MoTime = Format(LinesSelectionOperations.MoFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.MoTo, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.MoTime = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.TuFrom) OR ValueIsFilled(LinesSelectionOperations.TuTo) Then
				TemplateArea.Parameters.TuTime = Format(LinesSelectionOperations.TuFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.TuTo, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.TuTime = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.WeFrom) OR ValueIsFilled(LinesSelectionOperations.WeTo) Then
				TemplateArea.Parameters.WeTime = Format(LinesSelectionOperations.WeFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.WeTo, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.WeTime = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.ThFrom) OR ValueIsFilled(LinesSelectionOperations.ThOn) Then
				TemplateArea.Parameters.ThTime = Format(LinesSelectionOperations.ThFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.ThOn, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.ThTime = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.FrFr) OR ValueIsFilled(LinesSelectionOperations.FrTo) Then
				TemplateArea.Parameters.FrTime = Format(LinesSelectionOperations.FrFr, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.FrTo, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.FrTime = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.SbS) OR ValueIsFilled(LinesSelectionOperations.SaTo) Then
				TemplateArea.Parameters.SaTime = Format(LinesSelectionOperations.SbS, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.SaTo, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.SaTime = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.VsS) OR ValueIsFilled(LinesSelectionOperations.SuOn) Then
				TemplateArea.Parameters.SunTime = Format(LinesSelectionOperations.VsS, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.SuOn, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.SunTime = "";
			EndIf;
			
			TemplateArea.Parameters.WorkPresentation = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionOperations.ProductsAndServices, 
																		LinesSelectionOperations.Characteristic, LinesSelectionOperations.SKU);
												
			SpreadsheetDocument.Put(TemplateArea);
			
			Amount = Amount + LinesSelectionOperations.Amount;
			TotalAmount = TotalAmount + LinesSelectionOperations.Total;
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total = TotalAmount;
		TemplateArea.Parameters.Amount = SmallBusinessServer.AmountsFormat(Amount);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
	EndDo;
	
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "TimeTracking") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "TimeTracking", "Time tracking", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "TimeTracking";
	PrintCommand.Presentation = NStr("en = 'Time tracking'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf