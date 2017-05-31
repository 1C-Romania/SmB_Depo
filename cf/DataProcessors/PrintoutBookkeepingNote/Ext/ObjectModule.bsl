Var CustomerVATNumber;
Var CustomerName;

Var CompanyVATNumber;
Var CompanyName;

Var CompanyAddressRecord;
Var LanguageCode;

Function Print() Export
	
	Spreadsheet = New SpreadsheetDocument;
	
	If ObjectRef.IsEmpty() Then
		Return Spreadsheet;
	EndIf;
		
	ObjectRefCurrency = ObjectRef.Currency;
	
	// Setting printing parametrs
	Copies             = Printouts.GetPrintingParameter(Parameters, "Copies", 1);
	ItemsCodesPrinting = Printouts.GetPrintingParameter(Parameters, "ItemsCodesPrinting", "NotPrint");
	PrintItemsCodes    = ?(ItemsCodesPrinting = "NotPrint", False, True);
	DocumentPrintoutType = Printouts.GetPrintingParameter(Parameters, "PrintoutType", "Original");
	LanguageCode = Printouts.GetPrintingParameter(Parameters, "PrintoutLanguage", Common.GetDefaultLanguageCodeAndDescription().LanguageCode);
	ItemsNames = Printouts.GetPrintingParameter(Parameters, "ItemsNames", "Auto");
	
	CustomerVATNumber = Taxes.GetBusinessPartnerVATNumberDescription(ObjectRef.Date,ObjectRef.Customer,LanguageCode,ObjectRef.Customer.AccountingGroup.LocationType);
	CustomerName      = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(ObjectRef.Date, New Structure("BusinessPartner, Attribute", ObjectRef.Customer, Enums.BusinessPartnersAttributesTypes.LongDescription)).Description;
	
	CompanyVATNumber = Taxes.GetBusinessPartnerVATNumberDescription(ObjectRef.Date,ObjectRef.Company,LanguageCode,ObjectRef.Customer.AccountingGroup.LocationType);
	CompanyName      = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(ObjectRef.Date, New Structure("BusinessPartner, Attribute", ObjectRef.Company, Enums.BusinessPartnersAttributesTypes.LongDescription)).Description;
	
	CompanyAddressRecord = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(ObjectRef.Date, New Structure("BusinessPartner, Attribute", ObjectRef.Company, Enums.BusinessPartnersAttributesTypes.LegalAddress));
	
	// Getting templates
	Template = GetTemplate("Template");
	Template.TemplateLanguageCode = LanguageCode;
	
	Header     = Template.GetArea(?(ObjectRef.PaymentMethod.TransactionType = Enums.PaymentTransactionTypes.Factoring, "HeaderWithLiability", "Header"));
	Remarks    = Template.GetArea("Remarks");
	ItemHeader = Template.GetArea("ItemHeader");
	ItemRow    = Template.GetArea("ItemRow");
	ItemTotals = Template.GetArea("ItemTotals");
	Footer     = Template.GetArea("Footer");
	EmptyLine  = Template.GetArea("EmptyLine");
	LeftPartExpander = Template.GetArea("LeftPartExpander|Payment");
	
	PaymentHeader = Template.GetArea("PaymentHeader|Payment");
	OtherPaymentHeader = Template.GetArea("OtherPaymentsHeader|Payment");
	
	PaymentRow = Template.GetArea("PaymentRow|Payment");
	OtherPaymentRow = Template.GetArea("OtherPaymentRow|Payment");
	PaymentFooter = Template.GetArea("PaymentFooter|Payment");
	RemainToPayFooter = Template.GetArea("RemainToPayFooter");
	
	AmountToPay = Template.GetArea("AmountToPay|VAT");
	
	AdditionalInformationFooter = Template.GetArea("AdditionalInformation");
	
	// Filling document's header.
	EnumAddress = Enums.ContactInformationTypes.Address;
	EnumPhone   = Enums.ContactInformationTypes.Phone;
	
	// CompanyLogo and CompanyLogoLiability are the same picture but they have different names in alternative header versions depending on transaction type (factoring or not)
	If ObjectRef.PaymentMethod.TransactionType = Enums.PaymentTransactionTypes.Factoring Then
		Header.Drawings.CompanyLogoLiability.Picture = CommonAtServer.GetCompanyLogo(ObjectRef.Company);
	Else
		Header.Drawings.CompanyLogo.Picture = CommonAtServer.GetCompanyLogo(ObjectRef.Company);
	EndIf;
	
	Header.Parameters.Number       = ObjectRef.Number;
	Header.Parameters.City         = ?(CommonAtServer.IsDocumentAttribute("IssuePlace", ObjectRef.Metadata())AND ValueIsFilled(ObjectRef["IssuePlace"]), ObjectRef["IssuePlace"], CompanyAddressRecord.Field5);
	Header.Parameters.Date         = Format(ObjectRef.Date, "DLF=D");
	If Upper(DocumentPrintoutType) = Upper("Original") Then	
		Header.Parameters.OriginalCopy = Nstr("en='Original';pl='Oryginał';ru='Оригинал'",LanguageCode);
	ElsIf Upper(DocumentPrintoutType) = Upper("Copy") Then	
		Header.Parameters.OriginalCopy = Nstr("en='Copy';pl='Kopia';ru='Копия'",LanguageCode);
	ElsIf Upper(DocumentPrintoutType) = Upper("OriginalDuplicate") Then	
		Header.Parameters.OriginalCopy = Nstr("en='Original';pl='Oryginał';ru='Оригинал'",LanguageCode);
		Header.Parameters.InvoiceForDuplicate = Nstr("en='Duplicate issued';pl='Duplikat wystawiony dnia';ru='Дубликат от'",LanguageCode) + " " + Format(CurrentDate(), "DLF=D");
	ElsIf Upper(DocumentPrintoutType) = Upper("CopyDuplicate") Then	
		Header.Parameters.OriginalCopy = Nstr("en='Copy';pl='Kopia';ru='Копия'",LanguageCode);
		Header.Parameters.InvoiceForDuplicate = Nstr("en='Duplicate issued';pl='Duplikat wystawiony dnia';ru='Дубликат от'",LanguageCode) + " " + Format(CurrentDate(), "DLF=D");			
	EndIf;	
		
	CompanyCustomersCode = InformationRegisters.CustomersCompaniesCodes.Get(New Structure("Customer, Company", ObjectRef.Customer, ObjectRef.Company)).Code;
	
	PaymentMetodDetails = InformationRegisters.PaymentMetodDetails.Get(New Structure("Company, PaymentMetod", ObjectRef.Company, ObjectRef.PaymentMethod));
	BankAccount = PaymentMetodDetails.Account;
	
	Header.Parameters.CompanyCustomersCode = CompanyCustomersCode;
	Header.Parameters.CompanyName          = CompanyName;
	Header.Parameters.CompanyAddress       = CompanyAddressRecord.Description;
	Header.Parameters.CompanyPhone         = ContactInformationOrdinary.GetContactInformationDescription(ObjectRef.Company, EnumPhone, Catalogs.ContactInformationProfiles.CompanyPhone);
	Header.Parameters.CompanyVATNumber     = CompanyVATNumber;
	
	// Jack 29.05.2017
	//If Not BankAccount.IsEmpty() Then
	//	Header.Parameters.CompanyBankAccount   = BankCash.GetBankAccountPresentation(BankAccount,ObjectRef.Customer.AccountingGroup.LocationType,LanguageCode);
	//	If ObjectRef.PaymentMethod.TransactionType = Enums.PaymentTransactionTypes.Factoring Then
	//		Header.Parameters.LiabilityHolder      = BankAccount.Description;
	//	EndIf;
	//EndIf;
	
	Header.Parameters.CustomerName         = CustomerName;
	Header.Parameters.CustomerAddress      = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(ObjectRef.Date, New Structure("BusinessPartner, Attribute", ObjectRef.Customer, Enums.BusinessPartnersAttributesTypes.LegalAddress)).Description;
	Header.Parameters.CustomerPhone        = ContactInformationOrdinary.GetContactInformationDescription(ObjectRef.Customer, EnumPhone, Catalogs.ContactInformationProfiles.CustomerPhone);
	Header.Parameters.CustomerVATNumber    = CustomerVATNumber;
	
	DeliveryPointName = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(ObjectRef.Date, New Structure("BusinessPartner, Attribute", ObjectRef.DeliveryPoint, Enums.BusinessPartnersAttributesTypes.LongDescription)).Description;
	Header.Parameters.DeliveryPointName    = DeliveryPointName;
	Header.Parameters.DeliveryPointAddress = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(ObjectRef.Date, New Structure("BusinessPartner, Attribute", ObjectRef.DeliveryPoint, Enums.BusinessPartnersAttributesTypes.LegalAddress)).Description;;
	Header.Parameters.DeliveryPointPhone   = ContactInformationOrdinary.GetContactInformationDescription(ObjectRef.DeliveryPoint, EnumPhone, Catalogs.ContactInformationProfiles.CustomerPhone);
	Header.Parameters.PaymentDate   = Format(ObjectRef.PaymentDate, "DLF=D");
	Header.Parameters.PaymentMethod = LanguagesModulesServer.GetDescription(ObjectRef.PaymentMethod, LanguageCode); //ObjectRef.PaymentMethod.LongDescription;
	Header.Parameters.Currency      = ObjectRefCurrency;
	
	Spreadsheet.Put(Header);
	
	If ObjectRef.Remarks <> "" Then
		
		Remarks.Parameters.Remarks = ObjectRef.Remarks;
		Spreadsheet.Put(Remarks);
		
	EndIf;
	
	Spreadsheet.Put(ItemHeader);
	
	Spreadsheet.RepeatOnRowPrint = Spreadsheet.Area(Spreadsheet.TableHeight, , Spreadsheet.TableHeight);
	
	Query = New Query;
	Query.Text = "SELECT
	             |	BookkeepingNoteRecords.LineNumber AS LineNumber,
	             |	BookkeepingNoteRecords.Amount AS Amount,
	             |	BookkeepingNoteRecords.Description
	             |FROM
	             |	Document.BookkeepingNote.Records AS BookkeepingNoteRecords
	             |WHERE
	             |	BookkeepingNoteRecords.Ref = &Ref
	             |
	             |ORDER BY
	             |	LineNumber
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	SUM(PartnersSettlements.Amount) AS Amount,
	             |	PRESENTATION(PartnersSettlements.Document),
	             |	PartnersSettlements.Document,
	             |	PartnersSettlements.Document.Date AS DocumentDate,
	             |	PartnersSettlements.Document.Number
	             |FROM
	             |	AccumulationRegister.PartnersSettlements AS PartnersSettlements
	             |WHERE
	             |	PartnersSettlements.Recorder = &Ref
	             |	AND PartnersSettlements.SettlementType = VALUE(Enum.PartnerSettlementTypes.PrepaymentFromCustomer)
	             |	AND (NOT PartnersSettlements.Document REFS Document.SalesPrepaymentInvoice)
	             |
	             |GROUP BY
	             |	PartnersSettlements.Document,
	             |	PartnersSettlements.Document.Date,
	             |	PartnersSettlements.Document.Number
	             |
	             |ORDER BY
	             |	DocumentDate
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	PRESENTATION(BookkeepingNotePayments.PaymentMethod) AS PaymentMethod,
	             |	BookkeepingNotePayments.Amount
	             |FROM
	             |	Document.BookkeepingNote.Payments AS BookkeepingNotePayments
	             |WHERE
	             |	BookkeepingNotePayments.Ref = &Ref
	             |	AND BookkeepingNotePayments.PaymentMethod.TransactionType <> VALUE(Enum.PaymentTransactionTypes.Cash)";
	
	Query.SetParameter("Ref", ObjectRef);
	QueryResultArray = Query.ExecuteBatch();

	LineNumber = 0;
	Selection = QueryResultArray[0].Select();
	
	While Selection.Next() Do
		
		LineNumber = LineNumber + 1;
		
		ItemRow.Parameters.LineNumber    = LineNumber;
		ItemRow.Parameters.Description          = TrimAll(Selection.Description);
		
		ItemRow.Parameters.Amount        = FormatAmount(Selection.Amount,ObjectRefCurrency,,,False);
	
		Spreadsheet.Put(ItemRow);
		
	EndDo;
	
	Spreadsheet.Area(Spreadsheet.TableHeight, , Spreadsheet.TableHeight).StayWithNext = True;
	
	LeftPart = New SpreadsheetDocument();
	RightPart = New SpreadsheetDocument();
	
	PaymentsTable = QueryResultArray[1].Unload();
	
	If PaymentsTable.Count()>0 Then
		
		LeftPart.Put(PaymentHeader);
		For Each Row In PaymentsTable Do
			
			PaymentRow.Parameters.Document = Row.Document.Metadata().Synonym + " " + Row.DocumentNumber;
			PaymentRow.Parameters.Date = Format(Row.DocumentDate, "DLF=D");
			PaymentRow.Parameters.Amount = FormatAmount(Row.Amount,ObjectRefCurrency,,,False);
			
			LeftPart.Put(PaymentRow);
			
		EndDo;	
		
		PaymentFooter.Parameters.TotalAmount = FormatAmount(PaymentsTable.Total("Amount"),ObjectRefCurrency,,,False);
		PaymentFooter.Parameters.TotalAmountInWords = Common.AmountInWords(PaymentsTable.Total("Amount"), ObjectRefCurrency, LanguageCode);
		LeftPart.Put(PaymentFooter);
		
	EndIf;	
	
	OtherPaymentsTable = QueryResultArray[2].Unload();
	If OtherPaymentsTable.Count()>0 Then
		
		LeftPart.Put(OtherPaymentHeader);
		For Each Row In OtherPaymentsTable Do
			
			OtherPaymentRow.Parameters.PaymentMethod = Row.PaymentMethod;
			OtherPaymentRow.Parameters.Amount = FormatAmount(Row.Amount,ObjectRefCurrency,,,False);
			
			LeftPart.Put(OtherPaymentRow);
			
		EndDo;	
		
		PaymentFooter.Parameters.TotalAmount = FormatAmount(OtherPaymentsTable.Total("Amount"),ObjectRefCurrency,,,False);
		PaymentFooter.Parameters.TotalAmountInWords = Common.AmountInWords(OtherPaymentsTable.Total("Amount"), ObjectRefCurrency, LanguageCode);
		LeftPart.Put(PaymentFooter);
		
	EndIf;	
	
	DocGrossAmount = ObjectRef.Amount;
	RemainToPay = DocGrossAmount - PaymentsTable.Total("Amount")-OtherPaymentsTable.Total("Amount");
	If DocGrossAmount <> RemainToPay Then
		RemainToPayFooter.Parameters.RemainAmountToPay = FormatAmount(RemainToPay, ObjectRefCurrency);
		RemainToPayFooter.Parameters.RemainToPayInWords = Common.AmountInWords(RemainToPay, ObjectRefCurrency, LanguageCode);
		LeftPart.Put(RemainToPayFooter);
	EndIf;	
	
	AmountToPay.Parameters.GrossAmount        = FormatAmount(DocGrossAmount, ObjectRefCurrency);
	AmountToPay.Parameters.GrossAmountInWords = Common.AmountInWords(DocGrossAmount, ObjectRefCurrency, LanguageCode);

	RightPart.Put(AmountToPay);
	
	While LeftPart.TableHeight < RightPart.TableHeight Do
		LeftPart.Put(LeftPartExpander);
	EndDo;	
	
	Spreadsheet.Put(LeftPart.GetArea(1,1,LeftPart.TableHeight,4));
	Spreadsheet.Join(RightPart);
		
	Spreadsheet.Put(EmptyLine);
		
	If NOT IsBlankString(ObjectRef.AdditionalInformation) Then
		AdditionalInformationFooter.Parameters.AdditionalInformation = ObjectRef.AdditionalInformation;
		Spreadsheet.Put(AdditionalInformationFooter);
	EndIf;
	
	Footer.Parameters.Author             = ObjectRef.Author;
	Spreadsheet.Put(Footer);
	
	SetRegularSpreadsheetParameters(Spreadsheet, CompanyAddressRecord, LanguageCode);
	
	Return Spreadsheet
	
EndFunction // Print()

Function SetRegularSpreadsheetParameters(Spreadsheet, CompanyAddressRecord, LanguageCode)
	
	Spreadsheet.HeaderSize = 12;
	Spreadsheet.TopMargin  = 12;
	Spreadsheet.Header.Enabled   = True;
	Spreadsheet.Header.StartPage = 2;
	
	Spreadsheet.Header.LeftText  = Nstr("en='Seller';pl='Sprzedawca';ru='Продавец'",LanguageCode)+": " + CompanyName + " " + CompanyVATNumber + "
	                               |"+Nstr("en='Customer';pl='Nabywca';ru='Покупатель'",LanguageCode)+": " + CustomerName + " " + CustomerVATNumber;
	Spreadsheet.Header.RightText = Nstr("en='Bookkeeping note';pl='Nota księgowa';ru='Бухгалтерская нота'",LanguageCode)+" " + ObjectRef.Number + ", " + CompanyAddressRecord.Field5 + ", " + Format(ObjectRef.Date, "DLF=D") + Chars.LF + " ";
	
EndFunction // SetRegularSpreadsheetParameters()

Procedure FillParameters()
	
	ValueListPrintoutType = New ValueList;
	ValueListPrintoutType.Add("Original",          NStr("en='Original';pl='Oryginał';ru='Оригинал'"));
	ValueListPrintoutType.Add("OriginalDuplicate", NStr("en='Original of duplicate';pl='Oryginał duplikatu';ru='Оригинал дубликата'"));
	ValueListPrintoutType.Add("Copy",              NStr("en='Copy';pl='Kopia';ru='Копия'"));
	ValueListPrintoutType.Add("CopyDuplicate",     NStr("en='Copy of duplicate';pl='Kopia duplikatu';ru='Копия дубликата'"));
	
	ValueListLanguages = New ValueList;
	ValueListLanguages.Add("pl", NStr("en = 'Polish'; pl = 'Polski'; ru = 'Польский'"));
	ValueListLanguages.Add("en", NStr("en = 'English'; pl = 'Angielski'; ru = 'Английский'"));
	ValueListLanguages.Add("ru", NStr("en = 'Russian'; pl = 'Rosyjski'; ru = 'Русский'"));

	Printouts.AddPrintingParameter(Parameters, "PrintoutType", NStr("en='Document printout type';pl='Typ wydruku dokumentu';ru='Тип печатной формы'"), Common.GetStringTypeDescription(100), "Original", ValueListPrintoutType);
	Printouts.AddPrintingParameter(Parameters, "PrintoutLanguage", NStr("en='Printout language';pl='Język wydruku';ru='Язык печати'"), Common.GetStringTypeDescription(2), Common.GetDefaultLanguageCodeAndDescription().LanguageCode, ValueListLanguages);
		
EndProcedure // FillParameters()

FillParameters();
