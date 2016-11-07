#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

// Procedure generates document printing form by the specified layout.
//
Function PrintForm(ObjectsArray, PrintObjects, DocumentType)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PowerOfAttorney";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text = 
	"SELECT
	|	PowerOfAttorney.Ref AS Ref,
	|	PowerOfAttorney.Number AS Number,
	|	PowerOfAttorney.Date AS DocumentDate,
	|	PowerOfAttorney.Company AS Heads,
	|	PowerOfAttorney.Company,
	|	PowerOfAttorney.Ind,
	|	PowerOfAttorney.Ind.Description AS SurnameNamePatronymicTrusted,
	|	PowerOfAttorney.BankAccount AS BankAccount,
	|	PowerOfAttorney.Counterparty AS Vendor,
	|	PowerOfAttorney.ForReceiptFrom AS VendorPresentation,
	|	PowerOfAttorney.ActivityDate AS ValidityPeriod,
	|	PowerOfAttorney.ByDocument AS DocumentAttributesOnReception,
	|	PowerOfAttorney.Company.Prefix AS Prefix,
	|	PowerOfAttorney.Inventory.(
	|		LineNumber AS Number,
	|		ProductDescription AS Values,
	|		ProductDescription AS ValuesPresentation,
	|		MeasurementUnit AS MeasurementUnitPresentation,
	|		Quantity
	|	)
	|FROM
	|	Document.PowerOfAttorney AS PowerOfAttorney
	|WHERE
	|	PowerOfAttorney.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	Ref,
	|	Number";
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
	
		StringSelectionProducts = Header.Inventory.Select();
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_Attorney_PF_MXL_M2";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.PowerOfAttorney.PF_MXL_M2");
		
		DataAboutIndividual = SmallBusinessServer.IndData(Header.Company, Header.Ind, Header.DocumentDate);
		
		SurnameNamePatronymicTrusted = TrimAll(DataAboutIndividual.Surname) + " " + TrimAll(DataAboutIndividual.Name) + " " + TrimAll(DataAboutIndividual.Patronymic);
		Position                    = TrimAll(DataAboutIndividual.Position);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		If DocumentType = "M2" Then
			TemplateArea = Template.GetArea("pattern");
			TemplateArea.Parameters.Fill(Header);
			TemplateArea.Parameters.DocumentNumber = DocumentNumber;
			TemplateArea.Parameters.DescriptionFullTrusted = "" + ?(IsBlankString(Position), "", Position + ", " + Chars.LF) + (SurnameNamePatronymicTrusted);
			SpreadsheetDocument.Put(TemplateArea);
			NameOfForm = "Typical interindustry form No M-2";
			GCMDCode = "0315001";
		Else
			NameOfForm = "Typical interindustry form No M-2a";
			GCMDCode = "0315002";
		EndIf;
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate,, Header.BankAccount);
		
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.DocumentNumber               = DocumentNumber;
		TemplateArea.Parameters.NameOfForm                = NameOfForm;
		TemplateArea.Parameters.GCMDCode               	 = GCMDCode;
		TemplateArea.Parameters.CompanyPresentation     = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.AccountAttributes               = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "AccountNo,Bank,BIN,CorrAccount,");
		TemplateArea.Parameters.UserAttributes         = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.PayerAttributes         = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.CompanyRBCOCode         = InfoAboutCompany.CodeByOKPO;
		TemplateArea.Parameters.PassportSeries                 = DataAboutIndividual.DocumentSeries;
		TemplateArea.Parameters.PassportNumber                 = DataAboutIndividual.DocumentNumber;
		TemplateArea.Parameters.PassportIssued                 = DataAboutIndividual.DocumentWhoIssued;
		TemplateArea.Parameters.PassportIssueDate            = DataAboutIndividual.DocumentIssueDate;
		TemplateArea.Parameters.SurnameNamePatronymicTrusted = SurnameNamePatronymicTrusted;
		TemplateArea.Parameters.AppointmentOfTrusted         = Position;
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("TableTitle");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("String");
		
		While StringSelectionProducts.Next() Do
			TemplateArea.Parameters.Fill(StringSelectionProducts);
			TemplateArea.Parameters.QuantityInWords = ?(StringSelectionProducts.Quantity = 0,
														   "",
														   String(StringSelectionProducts.Quantity) + " (" + 
														   SmallBusinessServer.QuantityInWords(StringSelectionProducts.Quantity) + ")");
			SpreadsheetDocument.Put(TemplateArea);
		EndDo;
		
		TemplateArea = Template.GetArea("Footer");
		TemplateArea.Parameters.Fill(Header);
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Company, Header.DocumentDate);
		TemplateArea.Parameters.Fill(Heads);
		
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "M2") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "M2", "Typical interindustry form No M-2", PrintForm(ObjectsArray, PrintObjects, "M2"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "M2a") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "M2a", "Typical interindustry form No M-2a", PrintForm(ObjectsArray, PrintObjects, "M2-a"));
		
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
	
	// M2
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "M2";
	PrintCommand.Presentation = NStr("en='M-2';ru='М-2'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	// M2a
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "M2a";
	PrintCommand.Presentation = NStr("en='M-2a';ru='M-2a'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
EndProcedure

#EndRegion

#EndIf