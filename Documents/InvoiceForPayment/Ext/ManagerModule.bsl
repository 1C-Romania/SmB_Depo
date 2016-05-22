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
Function PrintInvoiceForPayment(ObjectsArray, PrintObjects, TemplateName) Export
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	InvoiceForPayment.Ref AS Ref,
	|	InvoiceForPayment.AmountIncludesVAT AS AmountIncludesVAT,
	|	InvoiceForPayment.DocumentCurrency AS DocumentCurrency,
	|	InvoiceForPayment.Date AS DocumentDate,
	|	InvoiceForPayment.Number AS Number,
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
	|		MeasurementUnit AS MeasurementUnit,
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
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,Header.BankAccount);
		InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		
		//If user template is used - there were no such sections
		If Template.Areas.Find("TitleWithLogo") <> Undefined
			AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
			
			If ValueIsFilled(Header.Company.LogoFile) Then
				
				TemplateArea = Template.GetArea("TitleWithLogo");
				
				PictureData = AttachedFiles.GetFileBinaryData(Header.Company.LogoFile);
				If ValueIsFilled(PictureData) Then
					
					TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
					
				EndIf;
				
			Else // If images are not selected, print regular header
					
					TemplateArea = Template.GetArea("TitleWithoutLogo");
					
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		Else
			
			MessageText = NStr("en ='ATTENTION! Perhaps, user template is used Staff mechanism for the accounts printing may work incorrectly.'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		EndIf;
		
		TemplateArea = Template.GetArea("InvoiceHeader");
		If ValueIsFilled(InfoAboutCompany.Bank) Then
			TemplateArea.Parameters.RecipientBankPresentation = InfoAboutCompany.Bank.Description + " " + InfoAboutCompany.Bank.City;
		EndIf; 
		TemplateArea.Parameters.TIN = InfoAboutCompany.TIN;
		TemplateArea.Parameters.KPP = InfoAboutCompany.KPP;
		TemplateArea.Parameters.VendorPresentation = ?(IsBlankString(InfoAboutCompany.CorrespondentText), InfoAboutCompany.FullDescr, InfoAboutCompany.CorrespondentText);
		TemplateArea.Parameters.RecipientBankBIC = InfoAboutCompany.BIN;
		TemplateArea.Parameters.RecipientBankAccountPresentation = InfoAboutCompany.CorrAccount;
		TemplateArea.Parameters.RecipientAccountPresentation = InfoAboutCompany.AccountNo;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Invoice for payment # "
												+ DocumentNumber
												+ " from "
												+ Format(Header.DocumentDate, "DLF=DD");
												
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		TemplateArea.Parameters.VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.RecipientPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);

		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		If AreDiscounts Then
			
			TemplateArea = Template.GetArea("TableWithDiscountHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("RowWithDiscount");
			
		Else
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
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
				TemplateArea.Parameters.InventoryItem = LinesSelectionInventory.Content;
			Else
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
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
		TemplateArea.Parameters.Total = SmallBusinessServer.AmountsFormat(Amount);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("TotalVAT");
		If VATAmount = 0 Then
			
			TemplateArea.Parameters.VAT = "Without tax (VAT)";
			TemplateArea.Parameters.TotalVAT = "-";
			
		Else
			
			TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:");
			TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
			
		EndIf; 
		
		If TemplateName = "InvoiceForPartialPayment" Then
			
			If VATAmount = 0 Then
				TemplateArea.Parameters.VATToPay = "Without tax (VAT)";
				TemplateArea.Parameters.TotalVATToPay = "-";
			Else
				TemplateArea.Parameters.VATToPay = ?(Header.AmountIncludesVAT, "Including payment VAT:", "VAT amount of payment:");
				If PrepaymentTable.Total("PaymentPercentage") > 0 Then
					TemplateArea.Parameters.TotalVATToPay = SmallBusinessServer.AmountsFormat(PrepaymentTable.Total("PayVATAmount"));
				Else
					TemplateArea.Parameters.TotalVATToPay = "-";
				EndIf;
			EndIf; 
			
			If PrepaymentTable.Total("PaymentPercentage") > 0 Then
				TemplateArea.Parameters.TotalToPay = SmallBusinessServer.AmountsFormat(PrepaymentTable.Total("PaymentAmount"));
				TemplateArea.Parameters.PaymentPercentage = PrepaymentTable.Total("PaymentPercentage");
			Else
				TemplateArea.Parameters.TotalToPay = "-";
				TemplateArea.Parameters.PaymentPercentage = "-";
			EndIf;
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		If Template.Areas.Find("TotalToPay") = Undefined Then
			
			MessageText = NStr("en ='ATTENTION! Template area ""Total for payment"" is not found. Perhaps, user template is used'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		Else
			
			TemplateArea = Template.GetArea("TotalToPay");
			TemplateArea.Parameters.Fill(New Structure("TotalToPay", SmallBusinessServer.AmountsFormat(Total)));
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
												+ String(Quantity)
												+ ", in the amount of "
												+ SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		TemplateArea.Parameters.AmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("AccountFooter");
		
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Company, Header.DocumentDate);
		
		TemplateArea.Parameters.HeadDescriptionFull = Heads.HeadDescriptionFull;
		TemplateArea.Parameters.AccountantDescriptionFull   = Heads.ChiefAccountantNameAndSurname;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction // PrintInvoiceForPayment()

// Document printing procedure
//
Function PrintInvoiceWithFacsimileSignature(ObjectsArray, PrintObjects, TemplateName) Export
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	InvoiceForPayment.Ref AS Ref,
	|	InvoiceForPayment.AmountIncludesVAT AS AmountIncludesVAT,
	|	InvoiceForPayment.DocumentCurrency AS DocumentCurrency,
	|	InvoiceForPayment.Date AS DocumentDate,
	|	InvoiceForPayment.Number AS Number,
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
	|		MeasurementUnit AS MeasurementUnit,
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
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,Header.BankAccount);
		InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		
		//If user template is used - there were no such sections
		If Template.Areas.Find("TitleWithLogo") <> Undefined
			AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
			
			If ValueIsFilled(Header.Company.LogoFile) Then
				
				TemplateArea = Template.GetArea("TitleWithLogo");
				
				PictureData = AttachedFiles.GetFileBinaryData(Header.Company.LogoFile);
				If ValueIsFilled(PictureData) Then
					
					TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
					
				EndIf;
				
			Else // If images are not selected, print regular header
				
				TemplateArea = Template.GetArea("TitleWithoutLogo");
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		Else
			
			MessageText = NStr("en ='ATTENTION! Perhaps, user template is used Staff mechanism for the accounts printing may work incorrectly.'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		EndIf;
		
		TemplateArea = Template.GetArea("InvoiceHeader");
		If ValueIsFilled(InfoAboutCompany.Bank) Then
			TemplateArea.Parameters.RecipientBankPresentation = InfoAboutCompany.Bank.Description + " " + InfoAboutCompany.Bank.City;
		EndIf; 
		TemplateArea.Parameters.TIN = InfoAboutCompany.TIN;
		TemplateArea.Parameters.KPP = InfoAboutCompany.KPP;
		TemplateArea.Parameters.VendorPresentation = ?(IsBlankString(InfoAboutCompany.CorrespondentText), InfoAboutCompany.FullDescr, InfoAboutCompany.CorrespondentText);
		TemplateArea.Parameters.RecipientBankBIC = InfoAboutCompany.BIN;
		TemplateArea.Parameters.RecipientBankAccountPresentation = InfoAboutCompany.CorrAccount;
		TemplateArea.Parameters.RecipientAccountPresentation = InfoAboutCompany.AccountNo;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Invoice for payment # "
												+ DocumentNumber
												+ " from "
												+ Format(Header.DocumentDate, "DLF=DD");
												
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		TemplateArea.Parameters.VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.RecipientPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);

		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		If AreDiscounts Then
			
			TemplateArea = Template.GetArea("TableWithDiscountHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("RowWithDiscount");
			
		Else
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
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
				TemplateArea.Parameters.InventoryItem = LinesSelectionInventory.Content;
			Else
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
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
			Total		= Total		+ LinesSelectionInventory.Total;
		
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total = SmallBusinessServer.AmountsFormat(Amount);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("TotalVAT");
		If VATAmount = 0 Then
			
			TemplateArea.Parameters.VAT = "Without tax (VAT)";
			TemplateArea.Parameters.TotalVAT = "-";
			
		Else
			
			TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:");
			TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
			
		EndIf; 
		
		If TemplateName = "InvoiceForPartialPayment" Then
			
			If VATAmount = 0 Then
				TemplateArea.Parameters.VATToPay = "Without tax (VAT)";
				TemplateArea.Parameters.TotalVATToPay = "-";
			Else
				TemplateArea.Parameters.VATToPay = ?(Header.AmountIncludesVAT, "Including payment VAT:", "VAT amount of payment:");
				If PrepaymentTable.Total("PaymentPercentage") > 0 Then
					TemplateArea.Parameters.TotalVATToPay = SmallBusinessServer.AmountsFormat(PrepaymentTable.Total("PayVATAmount"));
				Else
					TemplateArea.Parameters.TotalVATToPay = "-";
				EndIf;
			EndIf; 
			
			If PrepaymentTable.Total("PaymentPercentage") > 0 Then
				TemplateArea.Parameters.TotalToPay = SmallBusinessServer.AmountsFormat(PrepaymentTable.Total("PaymentAmount"));
				TemplateArea.Parameters.PaymentPercentage = PrepaymentTable.Total("PaymentPercentage");
			Else
				TemplateArea.Parameters.TotalToPay = "-";
				TemplateArea.Parameters.PaymentPercentage = "-";
			EndIf;
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		If Template.Areas.Find("TotalToPay") = Undefined Then
			
			MessageText = NStr("en ='ATTENTION! Template area ""Total for payment"" is not found. Perhaps, user template is used'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		Else
			
			TemplateArea = Template.GetArea("TotalToPay");
			TemplateArea.Parameters.Fill(New Structure("TotalToPay", SmallBusinessServer.AmountsFormat(Total)));
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
												+ String(Quantity)
												+ ", in the amount of "
												+ SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		TemplateArea.Parameters.AmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		SpreadsheetDocument.Put(TemplateArea);
		
		If Template.Areas.Find("InvoiceFooterWithFaxPrint") <> Undefined Then
			
			If ValueIsFilled(Header.Company.FileFacsimilePrinting) Then
				
				TemplateArea = Template.GetArea("InvoiceFooterWithFaxPrint");
				
				PictureData = AttachedFiles.GetFileBinaryData(Header.Company.FileFacsimilePrinting);
				If ValueIsFilled(PictureData) Then
					
					TemplateArea.Drawings.FacsimilePrint.Picture = New Picture(PictureData);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en ='Facsimile for company is not set. Facsimile is set in the company card, ""Printing setting"" section.'");
				CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
				
				TemplateArea = Template.GetArea("AccountFooter");
				
				Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Company, Header.DocumentDate);
				
				TemplateArea.Parameters.HeadDescriptionFull = Heads.HeadDescriptionFull;
				TemplateArea.Parameters.AccountantDescriptionFull   = Heads.ChiefAccountantNameAndSurname;
				
			EndIf;
			
		Else
			
			// You do not need to add the second warning as the warning is added while trying to output a title.
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction // PrintInvoiceForPaymentWithFacsimileSignature()

// Procedure of printing application to contract
//
Function PrintAppendixToContract(ObjectsArray, PrintObjects, TemplateName)
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	InvoiceForPayment.Ref AS Ref,
	|	InvoiceForPayment.AmountIncludesVAT AS AmountIncludesVAT,
	|	InvoiceForPayment.DocumentCurrency AS DocumentCurrency,
	|	InvoiceForPayment.Date AS DocumentDate,
	|	InvoiceForPayment.Number AS Number,
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
	|		MeasurementUnit AS MeasurementUnit,
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
	|	),
	|	CounterpartyContracts.Ref AS RefTreaty,
	|	CounterpartyContracts.ContractDate AS ContractDate,
	|	CounterpartyContracts.ContractNo AS ContractNo
	|FROM
	|	Document.InvoiceForPayment AS InvoiceForPayment
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON InvoiceForPayment.Contract = CounterpartyContracts.Ref
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
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
		InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate);
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "to contract No "
												+ Header.ContractNo
												+ " from "
												+ Format(Header.ContractDate, "DLF=DD");
												
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		TemplateArea.Parameters.VendorPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.RecipientPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,KPP,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);

		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		If AreDiscounts Then
			
			TemplateArea = Template.GetArea("TableWithDiscountHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("RowWithDiscount");
			
		Else
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
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
				TemplateArea.Parameters.InventoryItem = LinesSelectionInventory.Content;
			Else
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
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
		TemplateArea.Parameters.Total = SmallBusinessServer.AmountsFormat(Amount);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("TotalVAT");
		If VATAmount = 0 Then
			
			TemplateArea.Parameters.VAT = "Without tax (VAT)";
			TemplateArea.Parameters.TotalVAT = "-";
			
		Else
			
			TemplateArea.Parameters.VAT = ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:");
			TemplateArea.Parameters.TotalVAT = SmallBusinessServer.AmountsFormat(VATAmount);
			
		EndIf; 
		
		If TemplateName = "InvoiceForPartialPayment" Then
			
			If VATAmount = 0 Then
				TemplateArea.Parameters.VATToPay = "Without tax (VAT)";
				TemplateArea.Parameters.TotalVATToPay = "-";
			Else
				TemplateArea.Parameters.VATToPay = ?(Header.AmountIncludesVAT, "Including payment VAT:", "VAT amount of payment:");
				If PrepaymentTable.Total("PaymentPercentage") > 0 Then
					TemplateArea.Parameters.TotalVATToPay = SmallBusinessServer.AmountsFormat(PrepaymentTable.Total("PayVATAmount"));
				Else
					TemplateArea.Parameters.TotalVATToPay = "-";
				EndIf;
			EndIf; 
			
			If PrepaymentTable.Total("PaymentPercentage") > 0 Then
				TemplateArea.Parameters.TotalToPay = SmallBusinessServer.AmountsFormat(PrepaymentTable.Total("PaymentAmount"));
				TemplateArea.Parameters.PaymentPercentage = PrepaymentTable.Total("PaymentPercentage");
			Else
				TemplateArea.Parameters.TotalToPay = "-";
				TemplateArea.Parameters.PaymentPercentage = "-";
			EndIf;
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		If Template.Areas.Find("TotalToPay") = Undefined Then
			
			MessageText = NStr("en ='ATTENTION! Template area ""Total for payment"" is not found. Perhaps, user template is used'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		Else
			
			TemplateArea = Template.GetArea("TotalToPay");
			TemplateArea.Parameters.Fill(New Structure("TotalToPay", SmallBusinessServer.AmountsFormat(Total)));
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
												+ String(Quantity)
												+ ", in the amount of "
												+ SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		TemplateArea.Parameters.AmountInWords = WorkWithCurrencyRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.DocumentCurrency);
		
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction // PrintInvoiceForPayment()

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
	
	// Invoice for payment
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "InvoiceForPayment") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "InvoiceForPayment", "Invoice for payment", PrintInvoiceForPayment(ObjectsArray, PrintObjects, "InvoiceForPayment"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "InvoiceForPaymentWithFacsimileSignature") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "InvoiceForPaymentWithFacsimileSignature", "Invoice for payment", PrintInvoiceWithFacsimileSignature(ObjectsArray, PrintObjects, "InvoiceForPayment"));
		
	EndIf;
	
	// Invoice for partial payment
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "InvoiceForPartialPayment") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "InvoiceForPartialPayment", "Invoice for Payment (Partial Payment)", PrintInvoiceForPayment(ObjectsArray, PrintObjects, "InvoiceForPartialPayment"));
	
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "InvoiceForPartialPaymentWithFacsimileSignature") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "InvoiceForPartialPaymentWithFacsimileSignature", "Invoice for Payment (Partial Payment)", PrintInvoiceWithFacsimileSignature(ObjectsArray, PrintObjects, "InvoiceForPartialPayment"));
	
	EndIf;
	
	// parameters of sending printing forms by email
	If FillInParametersOfElectronicMail Then
		
		SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
		
	EndIf;
	
	// Appendix to contract
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "AppendixToContract") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "AppendixToContract", "Appendix to contract", PrintAppendixToContract(ObjectsArray, PrintObjects, "AppendixToContract"));
		
	EndIf;
	
EndProcedure

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Invoice for payment
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "InvoiceForPayment";
	PrintCommand.Presentation = NStr("en = 'Invoice for payment'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	// Invoice for Payment (Partial Payment)
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "InvoiceForPartialPayment";
	PrintCommand.Presentation = NStr("en = 'Invoice for partial payment'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.FunctionalOptions = "PaymentCalendar";
	PrintCommand.Order = 4;
	
	// Printing commands visible with facsimile will not be throttled
	// by a flag of Companies field fullness for users to know about this opportunity
	
	// The invoice for payment with facsimile
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "InvoiceForPaymentWithFacsimileSignature";
	PrintCommand.Presentation = NStr("en = 'Invoice for payment (with facsimile)'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
	// Invoice for payment with facsimile (partial payment)
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "InvoiceForPartialPaymentWithFacsimileSignature";
	PrintCommand.Presentation = NStr("en = 'Invoice for partial payment (with facsimile)'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.FunctionalOptions = "PaymentCalendar";
	PrintCommand.Order = 10;
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler = "SmallBusinessClient.GenerateContractForms";
	PrintCommand.ID = "ContractForm";
	PrintCommand.Presentation = NStr("en = 'Contract form'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 14;
	
	// Appendix to contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "AppendixToContract";
	PrintCommand.Presentation = NStr("en = 'Appendix to contract'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 17;
	
EndProcedure

#EndRegion

#EndIf