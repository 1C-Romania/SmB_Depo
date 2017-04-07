#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PayrollSheet";
	
	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		Query.Text = 
		"SELECT
		|	PayrollSheet.Date AS DocumentDate,
		|	PayrollSheet.StructuralUnit AS StructuralUnit,
		|	PayrollSheet.RegistrationPeriod AS RegistrationPeriod,
		|	PayrollSheet.Number,
		|	PayrollSheet.Company.Prefix AS Prefix,
		|	PayrollSheet.DocumentCurrency,
		|	PayrollSheet.Company.DescriptionFull,
		|	PayrollSheet.Company
		|FROM
		|	Document.PayrollSheet AS PayrollSheet
		|WHERE
		|	PayrollSheet.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		Query = New Query;
		Query.SetParameter("CurrentDocument",   CurrentDocument);
		Query.SetParameter("RegistrationPeriod", EndOfMonth(CurrentDocument.RegistrationPeriod));
		Query.SetParameter("Bas", NStr("en='Bas.';ru='Осн.'"));
		Query.SetParameter("comb", NStr("en='comb.';ru='Совм.'"));
		Query.Text =
		"SELECT
		|	PayrollSheetEmployees.Employee.Code AS EmployeeCode,
		|	CASE
		|		WHEN PayrollSheetEmployees.Employee.OccupationType = VALUE(Enum.OccupationTypes.MainWorkplace)
		|			THEN &Bas
		|		ELSE &comb
		|	END AS TypeOfWork,
		|	SUM(PayrollSheetEmployees.PaymentAmount) AS Amount,
		|	IndividualsDescriptionFullSliceLast.Surname,
		|	IndividualsDescriptionFullSliceLast.Name,
		|	IndividualsDescriptionFullSliceLast.Patronymic,
		|	IndividualsDescriptionFullSliceLast.Period,
		|	PayrollSheetEmployees.Employee AS Ind,
		|	CASE
		|		WHEN ISNULL(IndividualsDescriptionFullSliceLast.Surname, """") <> """"
		|			THEN IndividualsDescriptionFullSliceLast.Surname + "" "" + IndividualsDescriptionFullSliceLast.Name + "" "" + IndividualsDescriptionFullSliceLast.Patronymic
		|		ELSE PayrollSheetEmployees.Employee.Description
		|	END AS EmployeePresentation
		|FROM
		|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
		|		LEFT JOIN InformationRegister.IndividualsDescriptionFull.SliceLast(&RegistrationPeriod, ) AS IndividualsDescriptionFullSliceLast
		|		ON PayrollSheetEmployees.Employee.Ind = IndividualsDescriptionFullSliceLast.Ind
		|WHERE
		|	PayrollSheetEmployees.Ref = &CurrentDocument
		|
		|GROUP BY
		|	IndividualsDescriptionFullSliceLast.Name,
		|	IndividualsDescriptionFullSliceLast.Patronymic,
		|	CASE
		|		WHEN PayrollSheetEmployees.Employee.OccupationType = VALUE(Enum.OccupationTypes.MainWorkplace)
		|			THEN &Bas
		|		ELSE &comb
		|	END,
		|	IndividualsDescriptionFullSliceLast.Surname,
		|	PayrollSheetEmployees.Employee,
		|	IndividualsDescriptionFullSliceLast.Period,
		|	PayrollSheetEmployees.Employee.Code,
		|	CASE
		|		WHEN ISNULL(IndividualsDescriptionFullSliceLast.Surname, """") <> """"
		|			THEN IndividualsDescriptionFullSliceLast.Surname + "" "" + IndividualsDescriptionFullSliceLast.Name + "" "" + IndividualsDescriptionFullSliceLast.Patronymic
		|		ELSE PayrollSheetEmployees.Employee.Description
		|	END
		|
		|ORDER BY
		|	EmployeePresentation";
		
		Selection = Query.Execute().Select();

		SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_PayrollSheet_Template";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.PayrollSheet.PF_MXL_Template");
		
		AreaDocumentHeader = Template.GetArea("DocumentHeader");
		AreaHeader          = Template.GetArea("Header");
		AreaDetails         = Template.GetArea("Details");
		FooterArea         = Template.GetArea("Footer");
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		AreaDocumentHeader.Parameters.CompanyName = Header.CompanyDescriptionFull;
		AreaDocumentHeader.Parameters.Department = Header.StructuralUnit;
		AreaDocumentHeader.Parameters.DocAmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(CurrentDocument.Employees.Total("PaymentAmount"), Header.DocumentCurrency);
		AreaDocumentHeader.Parameters.DocAmount = CurrentDocument.Employees.Total("PaymentAmount");
		AreaDocumentHeader.Parameters.Currency = Header.DocumentCurrency;
		AreaDocumentHeader.Parameters.DocNo = DocumentNumber;
		AreaDocumentHeader.Parameters.DocDate = Header.DocumentDate;
		AreaDocumentHeader.Parameters.FinancialPeriodFrom = Header.RegistrationPeriod;
		AreaDocumentHeader.Parameters.FinancialPeriodTo = EndOfMonth(Header.RegistrationPeriod);
		
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Company, Header.DocumentDate);
		AreaDocumentHeader.Parameters.Fill(Heads);
		
		SpreadsheetDocument.Put(AreaDocumentHeader);
		
		AreaHeader.Parameters.LabelAmount = "Amount, " + (Header.DocumentCurrency);
		SpreadsheetDocument.Put(AreaHeader);
			
		NPP = 0;
		While Selection.Next() Do
			NPP = NPP + 1;
			AreaDetails.Parameters.LineNumber = NPP;
			AreaDetails.Parameters.Fill(Selection);
			If ValueIsFilled(Selection.Surname) Then
				Initials = SmallBusinessServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic, True);
				AreaDetails.Parameters.Ind = ?(ValueIsFilled(Initials), Initials, Selection.Ind);
			EndIf; 
			SpreadsheetDocument.Put(AreaDetails);
		EndDo;
		
		SpreadsheetDocument.Put(FooterArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
	
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PayrollSheet") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PayrollSheet", "Payroll sheet", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure // Print()

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "PayrollSheet";
	PrintCommand.Presentation = NStr("en='Payroll sheet';ru='ПЛАТЕЖНАЯ ВЕДОМОСТЬ'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf