#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	
	Result.Add("Prefix");
	Result.Add("ContactInformation.*");
	
	Return Result
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Use several companies.

// Returns company by default.
// If there is only one company in the IB which is not marked for
// deletion and is not predetermined, then a ref to this company will be returned, otherwise an empty ref will be returned.
//
// Returns:
//     CatalogRef.Companies - ref to the company.
//
Function CompanyByDefault() Export
	
	Company = Catalogs.Companies.EmptyRef();
	
	SubsidaryCompany = Constants.SubsidiaryCompany.Get();
	MainCompanyUserSetting = SmallBusinessReUse.GetValueByDefaultUser(Users.AuthorizedUser(), "MainCompany");
	If ValueIsFilled(SubsidaryCompany) Then
		
		Company = SubsidaryCompany;
		
	ElsIf ValueIsFilled(MainCompanyUserSetting) Then
		
		Company = MainCompanyUserSetting;
		
	Else
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 2
		|	Companies.Ref AS Company
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Not Companies.DeletionMark";
		
		Selection = Query.Execute().Select();
		If Selection.Next() AND Selection.Count() = 1 Then
			Company = Selection.Company;
		EndIf;
		
	EndIf;
	
	Return Company;

EndFunction

// Returns quantity of the Companies catalog items.
// Does not consider items that are predefined and marked for deletion.
//
// Returns:
//     Number - companies quantity.
//
Function CompaniesCount() Export
	
	SetPrivilegedMode(True);
	
	Quantity = 0;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Not Companies.Predefined";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Quantity = Selection.Quantity;
	EndIf;
	
	SetPrivilegedMode(False);
	
	Return Quantity;
	
EndFunction

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID				= "CompanyAttributes";
	PrintCommand.Presentation	= NStr("ru = 'Реквизиты'; en = 'Attributes'");
	PrintCommand.FormsList		= "ItemForm,ListForm";
	PrintCommand.FormTitle		= NStr("ru = 'Печать реквизитов организации'; en = 'Print company attributes'");
	PrintCommand.Order			= 1;
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// It is called while transferring to SSL version 2.2.1.12.
//
Procedure FillConstantUseSeveralCompanies() Export
	
	If GetFunctionalOption("UseSeveralCompanies") =
			GetFunctionalOption("DoNotUseSeveralCompanies") Then
		// Options should have the opposite values.
		// If it is not true, then there were no such options in IB - initialize their values.
		Constants.UseSeveralCompanies.Set(CompaniesCount() > 1);
	EndIf;
	
EndProcedure

#EndRegion

#Region SB

// Printing template generation procedure
//
Function GenerateFaxPrintJobAssistant(CompaniesArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument	= New SpreadsheetDocument;
	Template				= PrintManagement.GetTemplate("Catalog.Companies." + TemplateName);
	
	For Each Company In CompaniesArray Do 
	
		SpreadsheetDocument.Put(Template.GetArea("FieldsRequired"));
		SpreadsheetDocument.Put(Template.GetArea("Line"));
		SpreadsheetDocument.Put(Template.GetArea("Schema"));
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, 1, PrintObjects, Company);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction // GenerateFaxPrintWorkAssistant()

// Procedure of generating preliminary document printing form (sample)
//
// It is called from the "Company" card to view logos placing
//
Function PreviewPrintedFormProformaInvoice(ObjectsArray, PrintObjects, TemplateName) Export
	
	Var Errors;
	
	UseVAT	= GetFunctionalOption("UseVAT");
	
	Company = ObjectsArray[0];
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	DateValue = CurrentSessionDate();
	
	Header = New Structure;
	Header.Insert("AmountIncludesVAT",		False);
	Header.Insert("DocumentCurrency",		Constants.NationalCurrency.Get());
	Header.Insert("Currency",				Constants.NationalCurrency.Get());
	Header.Insert("DocumentDate",			DateValue);
	Header.Insert("DocumentNumber",			"00000000001");
	Header.Insert("Company",				Company);
	Header.Insert("BankAccount",			Company.BankAccountByDefault);
	Header.Insert("Prefix",					Company.Prefix);
	Header.Insert("CustomerPresentation",	NStr("ru = 'Поле содержит информацию покупателя: полное наименование, ИНН, юридический адрес, телефоны.'; en = 'Field contains customer information: legal name, TIN, legal address, phones.'"));
	
	Inventory = New Structure;
	Inventory.Insert("LineNumber",				1);
	Inventory.Insert("ProductDescription",		NStr("ru = 'Запас для предварительного просмотра'; en = 'Inventory for preview'"));
	Inventory.Insert("SKU",						NStr("ru = 'АРТ-0000001'; en = 'SKU-0000001'"));
	Inventory.Insert("UnitOfMeasure",			Catalogs.UOMClassifier.pcs);
	Inventory.Insert("Quantity",				1);
	Inventory.Insert("Price",					100);
	Inventory.Insert("Amount",					100);
	Inventory.Insert("TotalVAT",				18);
	Inventory.Insert("Total",					118);
	Inventory.Insert("VATAmount",				NStr("en='VAT amount';ru='Сумма НДС'"));
	Inventory.Insert("Characteristic",			Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
	Inventory.Insert("DiscountMarkupPercent",	0);
	
	FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
	
	SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_" + TemplateName + "_" + TemplateName;
	
	Template = PrintManagement.PrintedFormsTemplate("Document.InvoiceForPayment.PF_MXL_" + TemplateName);
	
	InfoAboutCompany	= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, , ?(ValueIsFilled(Header.BankAccount), Header.BankAccount, Undefined));
	
	//If user template is used - there were no such sections
	If Template.Areas.Find("TitleWithLogo") <> Undefined
		AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
		
		If ValueIsFilled(Company.LogoFile) Then
			
			TemplateArea = Template.GetArea("TitleWithLogo");
			TemplateArea.Parameters.Fill(Header);
			
			PictureData = AttachedFiles.GetFileBinaryData(Company.LogoFile);
			If ValueIsFilled(PictureData) Then
				
				TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else // If images are not selected, print regular header
			
			TemplateArea = Template.GetArea("TitleWithoutLogo");
			TemplateArea.Parameters.Fill(Header);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
	Else
		
		MessageText = NStr("en='ATTENTION! Maybe, custom template is being used. Default procedures of account printing may work incorrectly.';ru='ВНИМАНИЕ! Возможно используется пользовательский макет. Штатный механизм печати счетов может работать некоректно.'");
		CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
		
	EndIf;
	
	TemplateArea = Template.GetArea("InvoiceHeaderVendor");
	
	TemplateArea.Parameters.Fill(Header);
	
	VendorPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
	
	TemplateArea.Parameters.VendorPresentation	= VendorPresentation;
	TemplateArea.Parameters.VendorAddress		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
	TemplateArea.Parameters.VendorPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
	TemplateArea.Parameters.VendorEmail			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
	
	TemplateArea.Parameters.BankPresentation	=  SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "Bank", False);
	TemplateArea.Parameters.BankAccountNumber	=  SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "AccountNo", False);
	TemplateArea.Parameters.BankSWIFT			=  SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "SWIFT", False);
	
	CorrespondentText	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "CorrespondentText", False);
	TemplateArea.Parameters.BankBeneficiary		=  ?(ValueIsFilled(CorrespondentText), CorrespondentText, VendorPresentation);
	
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("InvoiceHeaderCustomer");
	TemplateArea.Parameters.Fill(Header);
	SpreadsheetDocument.Put(TemplateArea);

	TemplateArea = Template.GetArea("TableHeader");
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("TableRow");
	TemplateArea.Parameters.Fill(Inventory);
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("Subtotal");
	TemplateArea.Parameters.Fill(Header);
	TemplateArea.Parameters.TitleSubtotal	= ?(UseVAT, NStr("ru = 'СУММА'; en = 'SUBTOTAL'"), NStr("ru = 'ИТОГО'; en = 'TOTAL'"));
	TemplateArea.Parameters.Amount			= SmallBusinessServer.AmountsFormat(Inventory.Amount);
	SpreadsheetDocument.Put(TemplateArea);
	
	If UseVAT Then
		
		TemplateArea = Template.GetArea("TotalVAT");
		TemplateArea.Parameters.VAT				= Inventory.VATAmount;
		TemplateArea.Parameters.TotalVAT		= SmallBusinessServer.AmountsFormat(Inventory.TotalVAT);;
		TemplateArea.Parameters.Currency		= Header.DocumentCurrency;
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total			= SmallBusinessServer.AmountsFormat(Inventory.Total);
		TemplateArea.Parameters.Currency		= Header.DocumentCurrency;
		SpreadsheetDocument.Put(TemplateArea);
		
	EndIf;
	
	If Template.Areas.Find("InvoiceFooterWithSignature") <> Undefined Then
		
		If ValueIsFilled(Company.FileFacsimilePrinting) Then
			
			TemplateArea = Template.GetArea("InvoiceFooterWithSignature");
			
			PictureData = AttachedFiles.GetFileBinaryData(Company.FileFacsimilePrinting);
			If ValueIsFilled(PictureData) Then
				
				TemplateArea.Drawings.FacsimilePrint.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TemplateArea = Template.GetArea("InvoiceFooter");
			TemplateArea.Parameters.Fill(Header);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
	Else
		
		// You do not need to add the second warning as the warning is added while trying to output a title.
		
	EndIf;
	
	PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Company);
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction //PrintPreviewInvoicesForPayment()

// The procedure for the formation of a spreadsheet document with details of companies
//
Function PrintCompanyCard(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	Template = PrintManagement.PrintedFormsTemplate("Catalog.Companies.CompanyAttributes");
	Separator = Template.GetArea("Separator");
	
	CurrentDate		= CurrentSessionDate();
	FirstDocument	= True;
	
	For Each Company In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.Put(Separator);
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument	= False;
		RowNumberBegin	= SpreadsheetDocument.TableHeight + 1;
		IsLegalEntity	= Company.LegalEntityIndividual = Enums.CounterpartyKinds.LegalEntity;
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Company, CurrentDate);
		
		Area = Template.GetArea("Description");
		Area.Parameters.DescriptionFull = InfoAboutCompany.FullDescr;
		SpreadsheetDocument.Put(Area);
		
		If ValueIsFilled(InfoAboutCompany.TIN) Then
			Area = Template.GetArea("TIN");
			Area.Parameters.TIN = InfoAboutCompany.TIN;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.RegistrationNumber) Then
			Area = Template.GetArea("RegistrationNumber");
			Area.Parameters.RegistrationNumber = InfoAboutCompany.RegistrationNumber;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.AccountNo) 
			And ValueIsFilled(InfoAboutCompany.SWIFT) 
			And ValueIsFilled(InfoAboutCompany.Bank) Then
			
			Area = Template.GetArea("BankAccount");
			Area.Parameters.AccountNo	= InfoAboutCompany.AccountNo;
			Area.Parameters.SWIFT		= InfoAboutCompany.SWIFT;
			Area.Parameters.CorrAccount	= InfoAboutCompany.CorrAccount;
			Area.Parameters.Bank		= InfoAboutCompany.Bank;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.LegalAddress) 
			Or ValueIsFilled(InfoAboutCompany.PhoneNumbers) Then
			SpreadsheetDocument.Put(Separator);
		EndIf;
		
		If IsLegalEntity And ValueIsFilled(InfoAboutCompany.LegalAddress) Then
			Area = Template.GetArea("LegalAddress");
			Area.Parameters.LegalAddress	= InfoAboutCompany.LegalAddress;
			SpreadsheetDocument.Put(Area);
		EndIf;
			
		If Not IsLegalEntity And ValueIsFilled(InfoAboutCompany.LegalAddress) Then
			Area = Template.GetArea("IndividualAddress");
			Area.Parameters.IndividualAddress	= InfoAboutCompany.LegalAddress;
			SpreadsheetDocument.Put(Area);
		EndIf;
			
		If ValueIsFilled(InfoAboutCompany.PhoneNumbers) Then
			Area = Template.GetArea("Phone");
			Area.Parameters.Phone = InfoAboutCompany.PhoneNumbers;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, RowNumberBegin, PrintObjects, Company);
		
	EndDo;
	
	SpreadsheetDocument.TopMargin		= 20;
	SpreadsheetDocument.BottomMargin	= 20;
	SpreadsheetDocument.LeftMargin		= 20;
	SpreadsheetDocument.RightMargin		= 20;
	
	SpreadsheetDocument.PageOrientation	= PageOrientation.Portrait;
	SpreadsheetDocument.FitToPage		= True;
	
	SpreadsheetDocument.PrintParametersKey = "PrintParameters__Company_CompanyCard";
	
	Return SpreadsheetDocument;

EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of templates separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray,
				 PrintParameters,
				 PrintFormsCollection,
				 PrintObjects,
				 OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CompanyAttributes") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"CompanyAttributes",
			NStr("en='Company details';ru='Реквизиты организации'"),
			PrintCompanyCard(ObjectsArray, PrintObjects));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PrintFaxPrintWorkAssistant") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PrintFaxPrintWorkAssistant", "How can I quickly and easily create fax signature and printing?", GenerateFaxPrintJobAssistant(ObjectsArray, PrintObjects, "AssistantWorkFaxPrint"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PreviewPrintedFormProformaInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PreviewPrintedFormProformaInvoice", "Proforma invoice", PreviewPrintedFormProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoice"));
		
	EndIf;
	
	
EndProcedure //Print()

#EndRegion

#EndIf
