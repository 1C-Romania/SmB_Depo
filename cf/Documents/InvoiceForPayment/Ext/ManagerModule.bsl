#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.PayDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.Ref AS InvoiceForPayment,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.Ref.PettyCash
	|		WHEN DocumentTable.Ref.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.Ref.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN DocumentTable.Ref.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE DocumentTable.Ref.DocumentCurrency
	|	END AS Currency,
	|	CASE
	|		WHEN DocumentTable.Ref.Contract.SettlementsInStandardUnits
	|			THEN CAST(DocumentTable.PaymentAmount * CASE
	|						WHEN SettlementsCurrencyRates.ExchangeRate <> 0
	|								AND CurrencyRatesOfDocument.Multiplicity <> 0
	|							THEN CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity / (ISNULL(SettlementsCurrencyRates.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE DocumentTable.PaymentAmount
	|	END AS Amount
	|FROM
	|	Document.InvoiceForPayment.PaymentCalendar AS DocumentTable
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS SettlementsCurrencyRates
	|		ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfDocument
	|		ON DocumentTable.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure // GenerateTablePaymentCalendar()

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref AS InvoiceForPayment,
	|	DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.InvoiceForPayment AS DocumentTable
	|WHERE
	|	DocumentTable.Counterparty.TrackPaymentsByBills
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.DocumentAmount <> 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure // GenerateTableInvoicesAndOrdersPayment()

// Creates a document data table.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document StructureAdditionalProperties - AdditionalProperties - Additional properties of the document
//	
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRef, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

#EndRegion

#Region PrintInterface

// Document printing procedure
//
Function PrintProformaInvoice(ObjectsArray, PrintObjects, TemplateName, Signature = False) Export
	
	Var Errors;
	
	UseVAT	= GetFunctionalOption("UseVAT");
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	InvoiceForPayment.Ref AS Ref,
	|	InvoiceForPayment.AmountIncludesVAT AS AmountIncludesVAT,
	|	InvoiceForPayment.DocumentCurrency AS DocumentCurrency,
	|	InvoiceForPayment.Date AS DocumentDate,
	|	InvoiceForPayment.Number AS DocumentNumber,
	|	InvoiceForPayment.BankAccount AS BankAccount,
	|	InvoiceForPayment.Counterparty AS Counterparty,
	|	InvoiceForPayment.Company AS Company,
	|	InvoiceForPayment.Company.Prefix AS Prefix,
	|	InvoiceForPayment.Inventory.(
	|		CASE
	|			WHEN (CAST(InvoiceForPayment.Inventory.ProductsAndServices.DescriptionFull AS String(1000))) = """"
	|				THEN InvoiceForPayment.Inventory.ProductsAndServices.Description
	|			ELSE CAST(InvoiceForPayment.Inventory.ProductsAndServices.DescriptionFull AS String(1000))
	|		END AS InventoryItem,
	|		ProductsAndServices.SKU AS SKU,
	|		MeasurementUnit AS UnitOfMeasure,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATAmount AS VATAmount,
	|		Total AS Total,
	|		Quantity AS Quantity,
	|		Characteristic,
	|		Content,
	|		DiscountMarkupPercent,
	|		CASE
	|			WHEN InvoiceForPayment.Inventory.DiscountMarkupPercent <> 0
	|					OR InvoiceForPayment.Inventory.AutomaticDiscountAmount <> 0
	|				THEN 1
	|			ELSE 0
	|		END AS IsDiscount,
	|		LineNumber AS LineNumber,
	|		AutomaticDiscountAmount
	|	),
	|	InvoiceForPayment.PaymentCalendar.(
	|		PaymentPercentage,
	|		PaymentAmount,
	|		PayVATAmount
	|	)
	|FROM
	|	Document.InvoiceForPayment AS InvoiceForPayment
	|WHERE
	|	InvoiceForPayment.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	Ref,
	|	LineNumber";
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		LinesSelectionInventory = Header.Inventory.Select();
		PrepaymentTable = Header.PaymentCalendar.Unload(); 
				
		SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_" + TemplateName + "_" + TemplateName;
		
		Template = PrintManagement.PrintedFormsTemplate("Document.InvoiceForPayment.PF_MXL_" + TemplateName);
		
		InfoAboutCompany		= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,Header.BankAccount);
		InfoAboutCounterparty	= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		
		//If user template is used - there were no such sections
		If Template.Areas.Find("TitleWithLogo") <> Undefined
			AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
			
			If ValueIsFilled(Header.Company.LogoFile) Then
				
				TemplateArea = Template.GetArea("TitleWithLogo");
				TemplateArea.Parameters.Fill(Header);
				
				PictureData = AttachedFiles.GetFileBinaryData(Header.Company.LogoFile);
				If ValueIsFilled(PictureData) Then
					
					TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
					
				EndIf;
				
			Else // If images are not selected, print regular header
					
					TemplateArea = Template.GetArea("TitleWithoutLogo");
					TemplateArea.Parameters.Fill(Header);
					
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		Else
			
			MessageText = NStr("en='ATTENTION! Perhaps, user template is used default methods for the accounts printing may work incorrectly.';ru='ВНИМАНИЕ! Возможно используется пользовательский макет. Штатный механизм печати счетов может работать некоректно.'");
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
		
		TemplateArea.Parameters.CustomerPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");;
		TemplateArea.Parameters.CustomerAddress			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "LegalAddress");;
		TemplateArea.Parameters.CustomerPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "PhoneNumbers,Fax");;
		
		SpreadsheetDocument.Put(TemplateArea);

		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		If AreDiscounts Then
			
			TemplateArea = Template.GetArea("TableHeaderWithDiscount");
			TemplateArea.Parameters.Currency	= Header.DocumentCurrency;
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("TableRowWithDiscount");
			
		Else
			
			TemplateArea = Template.GetArea("TableHeader");
			TemplateArea.Parameters.Currency	= Header.DocumentCurrency;
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("TableRow");
			
		EndIf;
		
		Amount		= 0;
		VATAmount	= 0;
		Total		= 0;
		Quantity	= 0;

		While LinesSelectionInventory.Next() Do
			
			Quantity = Quantity + 1;
			TemplateArea.Parameters.Fill(LinesSelectionInventory);
			TemplateArea.Parameters.LineNumber = Quantity;
			
			If ValueIsFilled(LinesSelectionInventory.Content) Then
				TemplateArea.Parameters.ProductDescription = LinesSelectionInventory.Content;
			Else
				TemplateArea.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																	LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
			EndIf;
						
			If AreDiscounts Then
				If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
					Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
					TemplateArea.Parameters.Discount         = Discount;
					TemplateArea.Parameters.AmountWithoutDiscount = Discount;
				ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
					TemplateArea.Parameters.Discount         = 0;
					TemplateArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount;
				Else
					Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
					TemplateArea.Parameters.Discount         = Discount;
					TemplateArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount + Discount;
				EndIf;
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			Amount		= Amount		+ LinesSelectionInventory.Amount;
			VATAmount	= VATAmount	+ LinesSelectionInventory.VATAmount;
			Total		= Total 	+ LinesSelectionInventory.Total;
			
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total		= SmallBusinessServer.AmountsFormat(Amount);
		TemplateArea.Parameters.Currency	= Header.DocumentCurrency;
		SpreadsheetDocument.Put(TemplateArea);
	
		If UseVAT Then
			
			TemplateArea = Template.GetArea("TotalVAT");
			If VATAmount = 0 Then
				TemplateArea.Parameters.VAT = "Without tax (VAT)";
				TemplateArea.Parameters.TotalVAT = "-";
			Else
				TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:");
				TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
			EndIf; 
			SpreadsheetDocument.Put(TemplateArea);
		
		EndIf;
		
		If Signature Then
		
			If Template.Areas.Find("InvoiceFooterWithSignature") <> Undefined Then
				
				If ValueIsFilled(Header.Company.FileFacsimilePrinting) Then
					
					TemplateArea = Template.GetArea("InvoiceFooterWithSignature");
					
					PictureData = AttachedFiles.GetFileBinaryData(Header.Company.FileFacsimilePrinting);
					If ValueIsFilled(PictureData) Then
						
						TemplateArea.Drawings.FacsimilePrint.Picture = New Picture(PictureData);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en='Facsimile for company is not set. Facsimile is set in the company card, ""Printing setting"" section.';ru='Факсимиле для организации не установлена. Установка факсимиле выполняется в карточке организации, раздел ""Настройка печати"".'");
					CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
					
					TemplateArea = Template.GetArea("InvoiceFooter");
					
				EndIf;
				
			Else
				
				// You do not need to add the second warning as the warning is added while trying to output a title.
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
		
		EndIf;	
	
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction // PrintProformaInvoice()

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
	
	FillInParametersOfElectronicMail = True;
	
	// Proforma invoice
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ProformaInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ProformaInvoice", "Proforma invoice", PrintProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoice"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ProformaInvoiceWithSignature") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ProformaInvoiceWithSignature", "Proforma invoice", PrintProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoice", True));
		
	EndIf;
	
	// parameters of sending printing forms by email
	If FillInParametersOfElectronicMail Then
		
		SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
		
	EndIf;
	
EndProcedure

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Proforma invoice
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoice";
	PrintCommand.Presentation				= NStr("ru = 'Счет на оплату'; en = 'Proforma invoice'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	// Proforma invoice with signature
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoiceWithSignature";
	PrintCommand.Presentation				= NStr("ru = 'Счет на оплату (с подписями)'; en = 'Proforma invoice (with signature)'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

#EndRegion

#EndIf