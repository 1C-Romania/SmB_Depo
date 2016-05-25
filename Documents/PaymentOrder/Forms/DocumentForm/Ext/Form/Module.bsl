&AtClientAtServerNoContext
Procedure SetChoiceList(Item, DataList, EditingLimited = False, Warning = "")
	
	Item.ChoiceList.Clear();
	
	Item.ListChoiceMode = True;
	Item.ClearButton       = False;
	For Each DataItem IN DataList Do
		Item.ChoiceList.Add(DataItem.Value, DataItem.Presentation);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFormFrom2014Year()
	
	If Not ValueIsFilled(Object.Date)
	    OR Object.Date >= '20140101' Then // OKTMO acts in any case from 01/01/2014
		Items.OKATOCode.Title = "OKTMO code";
		Items.OKATOCode.ToolTip = "OKTMO code - territories (settlement) on which funds are raised";
	Else
		Items.OKATOCode.Title = "OKATO Code";
		Items.OKATOCode.ToolTip = "Payments collector OKATO code";
	EndIf;
	
	If (ValueIsFilled(Object.Date) AND Object.Date >= SmallBusinessClientServer.StartApplyPaymetID())
	 OR (NOT ValueIsFilled(Object.Date) AND CurrentDate() >= SmallBusinessClientServer.StartApplyPaymetID()) Then
		Items.PaymentIdentifier.WarningOnEditRepresentation = WarningOnEditRepresentation.Auto;
		Items.PaymentIdentifier.WarningOnEdit = "";
	ElsIf Object.OperationKind = Enums.OperationKindsPaymentOrder.Payment Then
		Items.PaymentIdentifier.WarningOnEditRepresentation = WarningOnEditRepresentation.Show;
		Items.PaymentIdentifier.WarningOnEdit = NStr("en = 'Payment ID is used only for payment into the budget until 03/31/2014'");
	EndIf;
	
	If Object.OperationKind = Enums.OperationKindsPaymentOrder.Payment Then
		
		Items.PaymentIdentifier.Title = "UIP";
	Else
		Items.PaymentIdentifier.Title = "WIN";
	EndIf;
	
	SetChoiceList(
		Items.AuthorStatus,
		SmallBusinessClientServer.PayerStatuses(Object.Date));
	
	SetChoiceList(
		Items.BasisIndicator,
		SmallBusinessClientServer.PaymentBases(Object.TransferToBudgetKind, Object.Date));
		
	SetChoiceList(
		Items.TypeIndicator,
		SmallBusinessClientServer.PaymentTypes(Object.TransferToBudgetKind, Object.Date));
	
EndProcedure

&AtServer
Procedure SetFormFrom2015Year()
	
	If DocumentDate >= '20150101'
		OR Object.Date >= '20150101' Then // Ministry of Finance order No 126n from 30.10.2014.
		Items.TypeIndicator.Visible = False;
		Object.TypeIndicator = "";
	Else
		Items.TypeIndicator.Visible = True;
		Object.TypeIndicator = "0";
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// The procedure fills in the payer text.
//
Procedure FillPayerText(StructureData)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")
		AND ValueIsFilled(StructureData.PayerDescriptionOnTaxTransfer) Then
		
		Object.PayerText = StructureData.PayerDescriptionOnTaxTransfer;
		
	ElsIf IsBlankString(StructureData.CorrespondentText) Then
		
		Object.PayerText = StructureData.DescriptionFull;
		If ValueIsFilled(StructureData.TextBankForSettlements) Then
			Object.PayerText = Object.PayerText + StructureData.TextBankForSettlements;
		EndIf;
		
	Else
		
		Object.PayerText = StructureData.CorrespondentText;
		
	EndIf;
	
EndProcedure // FillPayerText()

// The procedure fills in the recipient text.
//
Procedure FillTextRecipient(StructureData)
	
	If IsBlankString(StructureData.CorrespondentText) Then
		
		Object.PayeeText = StructureData.DescriptionFull;
		If ValueIsFilled(StructureData.TextBankForSettlements) Then
			Object.PayeeText = Object.PayeeText + StructureData.TextBankForSettlements;
		EndIf;
		
	Else
		
		Object.PayeeText = StructureData.CorrespondentText;
		
	EndIf;
	
EndProcedure // FillTextRecipient()

// The function fills in a bank text for settlements.
//
&AtServerNoContext
Function GetTextBankForSettlement(BankAccount)
	
	If ValueIsFilled(BankAccount.AccountsBank) Then
		TextBankForSettlements =
			" r/From "
			+ BankAccount.AccountNo
			+ " in "
			+ BankAccount.Bank
			+ " "
			+ BankAccount.Bank.City
	Else
		TextBankForSettlements = "";
	EndIf;
	
	Return TextBankForSettlements;
	
EndFunction // FillTextBankForSettlement()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	OperationKind = Object.OperationKind;
	
EndProcedure // FillByDocument()

// The procedure calls the document filling procedure by the basis.
// and sets the attributes availability after filling
//
&AtClient
Procedure FillByDocumentAndSetEnabled()
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillInByDocumentAndSetAvailableEnd", ThisObject), NStr("en = 'The document will be cleared and filled in by the ""Basis"". Continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillInByDocumentAndSetAvailableEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.BasisDocument);
        SetVisibleEnabled();
        SetTaxesTransferAttributesEnabled();
    EndIf;

EndProcedure // FillByDocumentAndSetEnabled()

// The procedure executes all required actions
// of the payment details text generation.
//
&AtClient
Procedure GeneratePaymentDestination(UpdateAmount = False)
	
	If UpdateAmount Then
		PositionAmount = Find(Object.PaymentDestination, "Amount ");
		If PositionAmount = 0
		   AND ValueIsFilled(Object.PaymentDestination) Then
			TextDestination = Object.PaymentDestination;
		Else
			TextDestination = Left(Object.PaymentDestination, PositionAmount - 1);
		EndIf;
		If Right(TextDestination, 1) = Chars.LF Then
			TextDestination = Left(TextDestination, StrLen(TextDestination) - 1);
		EndIf;
		If Not ValueIsFilled(TextDestination) Then
			TextDestination = PaymentDestination;
		EndIf;
	Else
		If IsBlankString(PaymentDestination)
			AND ValueIsFilled(Object.BasisDocument)
			AND TypeOf(Object.BasisDocument) = Type("DocumentRef.SupplierInvoiceForPayment")
			AND ValueIsFilled(IncomingDocumentNumber) Then
			PaymentDestination = NStr("en='Payment against the invoice for payment No.%AccountNumber%'");
			PaymentDestination = StrReplace(PaymentDestination, "%AccountNo%", TrimAll(String(IncomingDocumentNumber)));
			If ValueIsFilled(IncomingDocumentDate) Then
				PaymentDestination = PaymentDestination + " dated " + TrimAll(String(Format(IncomingDocumentDate, "DF=dd MMMM yyyy'"))) + " g.";
			EndIf;
		EndIf;
		TextDestination = PaymentDestination;
	EndIf;
	
	TextAmount = String(Format(Object.DocumentAmount, "ND=15; NFD=2; NDS=-; NZ=0-00; NG="));
	
	TextVAT = "";
	
	If ValueIsFilled(Object.VATRate)
	AND Not WithoutTaxVAT Then
		TextVAT = NStr("en = 'VAT(%VATRate%) %VATAmount%'");
		TextVAT = StrReplace(TextVAT, "%VATRate%", String(Object.VATRate));
		TextVAT = StrReplace(TextVAT, "%VATAmount%", String(Format(Object.VATAmount, "ND=15; NFD=2; NDS=-; NZ=0-00; NG=")));
	EndIf;
	
	If ValueIsFilled(Object.VATAmount)
	AND Not ValueIsFilled(Object.VATRate) Then
		TextVAT = NStr("en = 'VAT %VATAmount%'");
		TextVAT = StrReplace(TextVAT, "%VATAmount%", String(Format(Object.VATAmount, "ND=15; NFD=2; NDS=-; NZ=0-00; NG=")));
	EndIf;
	
	TextPaymentDestination = NStr(
		"en = '%TextDestination% Amount %TextAmount% %VATRateValue% %TextVAT%'"
	);
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%TextDestination%", TextDestination);
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%TextAmount%", TextAmount);
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%VATRateValue%", ?(WithoutTaxVAT OR (NOT ValueIsFilled(Object.VATAmount) AND Not ValueIsFilled(Object.VATRate)), NStr("en = 'Without tax (VAT)'"), NStr("en = 'including'")));
	TextPaymentDestination = StrReplace(TextPaymentDestination, "%TextVAT%", TextVAT);
	
	Object.PaymentDestination = TextPaymentDestination;
	
	// Replace (add) UIN (unique accrual
	// identifier) From January 1, 2014 to March 30, 2014 it is specified in the payment purpose
	SmallBusinessClientServer.ReplaceInUINPaymentDestination(
		Object.PaymentDestination,
		Object.PaymentIdentifier,
		Object.Date,
		Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")
	);
	
EndProcedure // GeneratePaymentDestination()

// The procedure executes all required actions
// to generate the PeriodFlag attribute.
//
&AtClient
Procedure SetPeriodIndicator()
	
	If Object.TransferToBudgetKind = PredefinedValue("Enum.BudgetTransferKinds.CustomsPayment") Then
		Object.PeriodIndicator = "";
	ElsIf PaymentPeriod = "0" Then
		Object.PeriodIndicator = "0";
	ElsIf PaymentPeriod = "-" Then
		Object.PeriodIndicator = Format(PaymentDate, "DF=dd.MM.yyyy");
	Else
		Object.PeriodIndicator = Left(PaymentPeriod, 2)
								 + "."
								 + Format(PeriodOfPayment, "ND=2; NZ=; NLZ=")
								 + "."
								 + Format(PaymentYear, "ND=4; NG=");
	EndIf;
	
EndProcedure // SetPeriodIndicator()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataBasisDocumentOnChange(BasisDocument)
	
	StructureData = New Structure();
	
	StructureData.Insert("IncomingDocumentDate",  BasisDocument.IncomingDocumentDate);
	StructureData.Insert("IncomingDocumentNumber", BasisDocument.IncomingDocumentNumber);
	
	Return StructureData;
	
EndFunction // GetDataBasisDocumentOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company, BankAccount, Counterparty, CounterpartyAccount, OperationKind, Period)
	
	StructureData = New Structure();
	
	StructureData.Insert("Counterparty", 				SmallBusinessServer.GetCompany(Company));
	StructureData.Insert("DescriptionFull",		Company.DescriptionFull);
	StructureData.Insert("PayerDescriptionOnTaxTransfer", Company.PayerDescriptionOnTaxTransfer);
	If Period >= '20140101' Then // OKTMO acts in any case from 01/01/2014
		StructureData.Insert("OKATOCode", 			Company.CodebyOKTMO);
	Else
		StructureData.Insert("OKATOCode", 			Company.CodeByOKATO);
	EndIf;
	
	//  Company bank account
	ValueForStructure	= ?(BankAccount.Owner = Company, BankAccount, Company.BankAccountByDefault);
	StructureData.Insert("BankAccount", 			ValueForStructure);
	NeedInstructionsCustomerCPP = GetNeedToIndicateKPP(ValueForStructure, OperationKind);
	
	//  Currency
	ValueForStructure	= ?(ValueIsFilled(ValueForStructure), ValueForStructure.CashCurrency, Constants.NationalCurrency.Get());
	StructureData.Insert("DocumentCurrency", 		ValueForStructure);
	
	//  Counterparty bank account
	ValueForStructure	= ?(ValueIsFilled(CounterpartyAccount) AND ValueForStructure = CounterpartyAccount.CashCurrency, CounterpartyAccount, Catalogs.BankAccounts.EmptyRef());
	StructureData.Insert("CounterpartyAccount", 		ValueForStructure);
	NecessityInstructionsCRRRecipient = GetNeedToIndicateKPP(ValueForStructure, OperationKind);
	
	StructureData.Insert("CorrespondentText", 	Company.BankAccountByDefault.CorrespondentText);
	StructureData.Insert("PayerTIN", 			Company.TIN);
	StructureData.Insert("PayerKPP", 			?(NeedInstructionsCustomerCPP, Company.KPP, ""));
	StructureData.Insert("ThisIsInd", 				Company.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind);
	
	StructureData.Insert("PayeeKPP",			?(NecessityInstructionsCRRRecipient, Counterparty.KPP, ""));
	
	StructureData.Insert("TextBankForSettlements", GetTextBankForSettlement(StructureData.BankAccount));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Receives the data set from server for the CompanyAccountOnChange procedure.
//
&AtServerNoContext
Function GetDataCompanyAccountOnChange(Company, AccountOfCompany, CurrencyBeforeChange, Date, OperationKind)
	
	NeedInstructionsKPP = GetNeedToIndicateKPP(AccountOfCompany, OperationKind);
	
	StructureData = New Structure();
	StructureData.Insert("CorrespondentText", AccountOfCompany.CorrespondentText);
	StructureData.Insert("DescriptionFull", ?(ValueIsFilled(AccountOfCompany), AccountOfCompany.Owner.DescriptionFull, ""));
	StructureData.Insert("PayerDescriptionOnTaxTransfer", ?(ValueIsFilled(AccountOfCompany), AccountOfCompany.Owner.PayerDescriptionOnTaxTransfer, ""));
	StructureData.Insert("CashCurrency", AccountOfCompany.CashCurrency);
	StructureData.Insert("PayerKPP", ?(NeedInstructionsKPP, Company.KPP, ""));
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", AccountOfCompany.CashCurrency)
		)
	);
	
	StructureData.Insert(
		"CurrencyRateMultiplicityBeforeChange",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", CurrencyBeforeChange)
		)
	);
	
	StructureData.Insert("TextBankForSettlements", GetTextBankForSettlement(AccountOfCompany));
	
	Return StructureData;
	
EndFunction // GetDataCompanyAccountOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
		
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", DATEDIFF);
		
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Receives the need for KPP specification.
//
&AtServerNoContext
Function GetNeedToIndicateKPP(CounterpartyAccount, OperationKind)
	
	If OperationKind = Enums.OperationKindsPaymentOrder.Payment Then
		If CounterpartyAccount.KPPIndicationVersion = Enums.KPPIndicationVariants.InAllPaymentOrders Then
			NeedInstructionsKPP = True;
		Else
			NeedInstructionsKPP = False;
		EndIf;
	ElsIf OperationKind = Enums.OperationKindsPaymentOrder.TaxTransfer Then
		NeedInstructionsKPP = True;
	Else
		NeedInstructionsKPP = False;
	EndIf;
	
	Return NeedInstructionsKPP;

EndFunction // GetNeedToIndicateKPP()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataCounterpartyOnChange(Counterparty, DocumentCurrency, OperationKind)
	
	CounterpartyAccount = ?(
		Counterparty.BankAccountByDefault.CashCurrency = DocumentCurrency,
		Counterparty.BankAccountByDefault,
		Catalogs.BankAccounts.EmptyRef()
	);
	
	NeedInstructionsKPP = GetNeedToIndicateKPP(CounterpartyAccount, OperationKind);
	
	StructureData = New Structure();
	StructureData.Insert("DescriptionFull", 	Counterparty.DescriptionFull);
	StructureData.Insert("CounterpartyAccount", 	CounterpartyAccount);
	StructureData.Insert("PayeeTIN", 		Counterparty.TIN);
	StructureData.Insert("PayeeKPP", 		?(NeedInstructionsKPP, Counterparty.KPP, ""));
	StructureData.Insert("PaymentDestination",	Counterparty.BankAccountByDefault.DestinationText);
	StructureData.Insert("CorrespondentText",	Counterparty.BankAccountByDefault.CorrespondentText);
	
	StructureData.Insert("TextBankForSettlements",  GetTextBankForSettlement(CounterpartyAccount));
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataCounterpartyAccountOnChange(Counterparty, CounterpartyAccount, OperationKind)
	
	NeedInstructionsKPP = GetNeedToIndicateKPP(CounterpartyAccount, OperationKind);
	
	StructureData = New Structure();
	StructureData.Insert("PaymentDestination", CounterpartyAccount.DestinationText);
	StructureData.Insert("CorrespondentText", CounterpartyAccount.CorrespondentText);
	StructureData.Insert("PayeeKPP", ?(NeedInstructionsKPP, Counterparty.KPP, ""));
	If ValueIsFilled(CounterpartyAccount.Owner) Then
		StructureData.Insert("DescriptionFull", CounterpartyAccount.Owner.DescriptionFull);
	Else
		StructureData.Insert("DescriptionFull", Counterparty.DescriptionFull);
	EndIf;
	StructureData.Insert("TextBankForSettlements",  GetTextBankForSettlement(CounterpartyAccount));
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyAccountOnChange()

// Receives the data set from server for the VATRateOnChange procedure.
//
&AtServerNoContext
Function GetDataVATRateOnChange(VATRate)
	
	StructureData = New Structure();
	
	StructureData.Insert("NotTaxable", VATRate.NotTaxable);
	StructureData.Insert("Rate", VATRate.Rate);	
		
	Return StructureData;
	
EndFunction // GetDataVATRateOnChange()

// Fills in the attribute of the default payment into budget.
//
&AtClient
Procedure FillPaymentToBudgetByDefaultAttributes()
	
	If Object.TransferToBudgetKind = PredefinedValue("Enum.BudgetTransferKinds.TaxPayment") Then
		Object.AuthorStatus = "01";
		Object.BasisIndicator = Items.BasisIndicator.ChoiceList[0].Value;
		Object.PeriodIndicator   = "MS." + Format(Month(Object.Date), "ND=2; NLZ=") + "." + Format(Year(Object.Date), "NG=");
		PaymentPeriod = "MS";
		PaymentYear = Year(Object.Date);
		PeriodOfPayment = Month(Object.Date);
		Object.NumberIndicator = "";
		Object.DateIndicator = "";
	ElsIf Object.TransferToBudgetKind = PredefinedValue("Enum.BudgetTransferKinds.CustomsPayment") Then
		Object.AuthorStatus   = "06";
		Object.BasisIndicator = Items.BasisIndicator.ChoiceList[0].Value;
		Object.PeriodIndicator   = "";
		Object.NumberIndicator    = "";
		Object.DateIndicator = "";
		PaymentPeriod = "0";
		PaymentYear = 0;
	Else
		Object.AuthorStatus   = "08";
		Object.BasisIndicator = "0";
		Object.PeriodIndicator   = "0";
		Object.NumberIndicator    = "";
		Object.DateIndicator = "";
		PaymentPeriod = "0";
		PaymentYear = 0;
	EndIf;
	
	If DocumentDate >= '20150101'
	 OR Object.Date >= '20150101' Then // Ministry of Finance order No 126n from 30.10.2014.
		Object.TypeIndicator = "";
	Else
		Object.TypeIndicator = "0";
	EndIf;
	
	SetPeriodIndicator();
	SetTaxesTransferAttributesEnabled();
	
EndProcedure // FillPaymentToBudgetByDefaultAttributes()

// Sets the current page depending on the kind of transfer into budget.
//
&AtServer
Procedure SetVisibleDependendingOnTransferIntoBudgetKind()
	
	Items.TaxPayment.Visible = False;
	Items.CustomsPayment.Visible = False;
	Items.OtherPayment.Visible = False;
	
	If Object.TransferToBudgetKind = PredefinedValue("Enum.BudgetTransferKinds.TaxPayment") Then
		Items.TaxPayment.Visible = True;
	ElsIf Object.TransferToBudgetKind = PredefinedValue("Enum.BudgetTransferKinds.CustomsPayment") Then
		Items.CustomsPayment.Visible = True;
	Else
		Items.OtherPayment.Visible = True;
	EndIf;
	
EndProcedure // SetCurrentPageDependingOnPaymentKindToBudget()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// The procedure sets the availability of the tax remission attributes.
//
&AtClient
Procedure SetTaxesTransferAttributesEnabled()
	
	If PaymentPeriod = "0" Then
		Items.YearPeriod.Visible = False;
		Items.PaymentDate.Visible = False;
	Else
		If PaymentPeriod = "-" Then
			Items.YearPeriod.Visible = False;
			Items.PaymentDate.Visible = True;
		Else
			Items.YearPeriod.Visible = True;
			Items.PaymentDate.Visible = False;
			Items.PeriodOfPayment.Visible = PaymentPeriod <> "GD";
			If PaymentPeriod = "MS" Then
				Items.PeriodOfPayment.MinValue = 1;
				Items.PeriodOfPayment.MaxValue = 12;
				Items.PeriodOfPayment.Title = "Month";
			ElsIf PaymentPeriod = "KV" Then
				Items.PeriodOfPayment.MinValue = 1;
				Items.PeriodOfPayment.MaxValue = 4;
				Items.PeriodOfPayment.Title = "Quarter";
			ElsIf PaymentPeriod = "PL" Then
				Items.PeriodOfPayment.MinValue = 1;
				Items.PeriodOfPayment.MaxValue = 2;
				Items.PeriodOfPayment.Title = "HalfYear";
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure // SetTaxesTransferAttributesEnabled()

// The procedure sets the availability of the form attributes depending on the operation kind.
// 
&AtClient
Procedure SetVisibleEnabled()
	
	Items.AttributeForEnumerationTax.Visible = Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer");
	Items.VATRate.Visible = Object.OperationKind <> PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer");
	Items.VATAmount.Visible = Object.OperationKind <> PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer");
	
EndProcedure // SetEnabled()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	ThisIsInd = Object.Company.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind;
	WithoutTaxVAT = Object.VATRate.NotTaxable;
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.BankAccount)
			AND ValueIsFilled(Object.BasisDocument)
			AND Object.BasisDocument.DocumentCurrency = Object.Company.BankAccountByDefault.CashCurrency Then
				Object.BankAccount = Object.Company.BankAccountByDefault;
		EndIf;
		If Not ValueIsFilled(Object.BankAccount)
			AND Not ValueIsFilled(Object.BasisDocument) Then
				Object.BankAccount = Object.Company.BankAccountByDefault;
		EndIf;
		If Not ValueIsFilled(Object.PayerTIN) Then
			Object.PayerTIN = Object.Company.TIN;
		EndIf;
		If Not ValueIsFilled(Object.PayerKPP) Then
			NeedInstructionsCustomerCPP = GetNeedToIndicateKPP(Object.BankAccount, Object.OperationKind);
			Object.PayerKPP = ?(NeedInstructionsCustomerCPP, Object.Company.KPP, "");
		EndIf;
		If Not ValueIsFilled(Object.PayerText) Then
			StructureData = New Structure(
				"PayerDescriptionOnTaxTransfer, CorrespondentText, DescriptionFull, TextBankForSettlements",
				Object.Company.PayerDescriptionOnTaxTransfer, Object.BankAccount.CorrespondentText,
				Object.Company.DescriptionFull, GetTextBankForSettlement(Object.BankAccount)
			);
			FillPayerText(StructureData);
		EndIf;
		If ValueIsFilled(Object.Counterparty) Then
			If Not ValueIsFilled(Object.CounterpartyAccount)
				AND ValueIsFilled(Object.BasisDocument)
				AND Object.BasisDocument.DocumentCurrency = Object.Counterparty.BankAccountByDefault.CashCurrency Then
					Object.CounterpartyAccount = Object.Counterparty.BankAccountByDefault;
			EndIf;
			Object.PayeeTIN = Object.Counterparty.TIN;
			Object.PayeeKPP = Object.Counterparty.KPP;
			Object.PayeeText = ?(
				ValueIsFilled(Object.CounterpartyAccount.CorrespondentText),
				Object.CounterpartyAccount.CorrespondentText,
				Object.Counterparty.DescriptionFull);
			StructureData = New Structure(
				"CorrespondentText, DescriptionFull, TextBankForSettlements",
				Object.CounterpartyAccount.CorrespondentText, Object.Counterparty.DescriptionFull, GetTextBankForSettlement(Object.CounterpartyAccount)
			);
			FillTextRecipient(StructureData);
			If IsBlankString(StructureData.CorrespondentText) Then
				
				Object.PayeeText = StructureData.DescriptionFull;
				If ValueIsFilled(StructureData.TextBankForSettlements) Then
					Object.PayeeText = Object.PayeeText + StructureData.TextBankForSettlements;
				EndIf;
				
			Else
				
				Object.PayeeText = StructureData.CorrespondentText;
				
			EndIf;
			
			PaymentDestination = Object.CounterpartyAccount.DestinationText;
		EndIf; 
	EndIf;
	
	If ValueIsFilled(Object.CounterpartyAccount) Then
		PaymentDestination = Object.CounterpartyAccount.DestinationText;
	EndIf;
	
	OperationKind = Object.OperationKind;
	
	If Object.PeriodIndicator = "0"
	 OR IsBlankString(Object.PeriodIndicator)
	 OR IsBlankString(StrReplace(Object.PeriodIndicator, ".", "")) Then
		PaymentPeriod = "0";
	Else
		RowTypeOfPeriod = Left(Object.PeriodIndicator, 2);
		RowPeriod     = Mid(Object.PeriodIndicator, 4, 2);
		RowOfYear        = Mid(Object.PeriodIndicator, 7);
		If RowTypeOfPeriod = "GD" Then
			PaymentPeriod = "GD";
		ElsIf RowTypeOfPeriod = "PL" Then
			PaymentPeriod = "PL";
		ElsIf RowTypeOfPeriod = "KV" Then
			PaymentPeriod = "KV";
		ElsIf RowTypeOfPeriod = "MS" Then
			PaymentPeriod = "MS";
		Else
			PaymentPeriod = "-";
		EndIf;
		Try
			YearByNumber    = Number(RowOfYear);
			PeriodByNumber = Number(RowPeriod);
			If PaymentPeriod = "-" Then
				DayByNumber  = Number(RowTypeOfPeriod);
				PaymentDate = Date(YearByNumber, PeriodByNumber, DayByNumber);
			Else
				PaymentYear    = YearByNumber;
				PeriodOfPayment = PeriodByNumber;
			EndIf;
		Except
			PeriodIndicator   = "0";
			PaymentPeriod = "0";
		EndTry;
	EndIf;

	If PaymentPeriod = "0" Then
		Items.YearPeriod.Visible = False;
		Items.PaymentDate.Visible = False;
	Else
		If PaymentPeriod = "-" Then
			Items.YearPeriod.Visible = False;
			Items.PaymentDate.Visible = True;
		Else
			Items.YearPeriod.Visible = True;
			Items.PaymentDate.Visible = False;
			Items.PeriodOfPayment.Visible = PaymentPeriod <> "GD";
			If PaymentPeriod = "MS" Then
				Items.PeriodOfPayment.MinValue = 1;
				Items.PeriodOfPayment.MaxValue = 12;
				Items.PeriodOfPayment.Title = "Month";
			ElsIf PaymentPeriod = "KV" Then
				Items.PeriodOfPayment.MinValue = 1;
				Items.PeriodOfPayment.MaxValue = 4;
				Items.PeriodOfPayment.Title = "Quarter";
			ElsIf PaymentPeriod = "PL" Then
				Items.PeriodOfPayment.MinValue = 1;
				Items.PeriodOfPayment.MaxValue = 2;
				Items.PeriodOfPayment.Title = "HalfYear";
			EndIf;
		EndIf;
	EndIf;
	
	If TypeOf(Object.BasisDocument) = Type("DocumentRef.SupplierInvoiceForPayment") Then
		StructureData = GetDataBasisDocumentOnChange(Object.BasisDocument);
		IncomingDocumentNumber = StructureData.IncomingDocumentNumber;
		IncomingDocumentDate = StructureData.IncomingDocumentDate;
	EndIf;

	Items.AttributeForEnumerationTax.Visible = Object.OperationKind = Enums.OperationKindsPaymentOrder.TaxTransfer;
	Items.VATRate.Visible = Object.OperationKind <> Enums.OperationKindsPaymentOrder.TaxTransfer;
	Items.VATAmount.Visible = Object.OperationKind <> Enums.OperationKindsPaymentOrder.TaxTransfer;
	SetFormFrom2014Year();
	SetFormFrom2015Year();
	
	SetVisibleDependendingOnTransferIntoBudgetKind();
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - OnChange event handler of the PaymentPeriodicity attribute.
// IN the procedure, the min PaymentPeriod attribute
// value is set depending on the PaymentPeriodicity attribute.
//
&AtClient
Procedure PaymentPeriodicityOnChange(Item)
	
	If Not ValueIsFilled(TrimAll(PaymentPeriod)) Then
		PaymentPeriod= "0";
	EndIf;

	Modified = True;
	
	If PaymentPeriod <> "0"
	   AND PaymentPeriod <> "-" Then
		If PaymentYear = 0 Then
			PaymentYear = Year(Object.Date);
		EndIf;
		If PaymentPeriod = "GD" Then
			PeriodOfPayment = 0;
		Else
			If PaymentPeriod = "MS" Then
				PeriodOfPayment = min(PeriodOfPayment, 12);
			ElsIf PaymentPeriod = "KV" Then
				PeriodOfPayment = min(PeriodOfPayment, 4);
			ElsIf PaymentPeriod = "PL" Then
				PeriodOfPayment = min(PeriodOfPayment, 2);
			EndIf;
			PeriodOfPayment = Max(1, PeriodOfPayment);
		EndIf;
	Else
		PaymentYear = 0;
	EndIf;
	
	SetPeriodIndicator();
	SetTaxesTransferAttributesEnabled();
	
EndProcedure // PaymentPeriodicityOnChange()

// Procedure - OnChange event handler of the PaymentYear attribute.
// The Period flag attribute is set to the procedure.
//
&AtClient
Procedure PaymentOnChangeYear(Item)
	
	Modified = True;
	SetPeriodIndicator();
	
EndProcedure // PaymentOnChangeYear()

// Procedure - OnChange event handler of the PaymentPeriod attribute.
// The Period flag attribute is set to the procedure.
//
&AtClient
Procedure PaymentPeriodOnChange(Item)
	
	Modified = True;
	SetPeriodIndicator();
	
EndProcedure // PaymentPeriodOnChange()

// Procedure - OnChange event handler of the PaymentDate attribute.
// The Period flag attribute is set to the procedure.
//
&AtClient
Procedure PaymentDateOnChange(Item)
	
	Modified = True;
	SetPeriodIndicator();
	
EndProcedure // PaymentDateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number 			= "";
	StructureData 		= GetCompanyDataOnChange(Object.Company, Object.BankAccount, Object.Counterparty, Object.CounterpartyAccount, Object.OperationKind, Object.Date);
	Counterparty 				= StructureData.Counterparty;
	Object.BankAccount	= StructureData.BankAccount;
	Object.DocumentCurrency	= StructureData.DocumentCurrency;
	Object.CounterpartyAccount	= StructureData.CounterpartyAccount;
	Object.PayerTIN	= StructureData.PayerTIN;
	Object.PayerKPP	= StructureData.PayerKPP;
	
	FillPayerText(StructureData);
	
	ThisIsInd = StructureData.ThisIsInd;
	
	If ValueIsFilled(Object.Company) Then
		If String(Object.OperationKind) = "Tax payment" Then
			Object.OKATOCode = StructureData.OKATOCode;
			If ThisIsInd Then
				Object.PayerKPP = 0;
			EndIf;
		Else
			Object.OKATOCode = "";
			If ThisIsInd Then
				Object.PayerKPP = "";
			EndIf;
		EndIf;
	Else
		Object.BankAccount = "";
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the CompanyAccount attribute.
//
&AtClient
Procedure CompanyAccountOnChange(Item)
	
	StructureData = GetDataCompanyAccountOnChange(Object.Company, Object.BankAccount, Object.DocumentCurrency, Object.Date, Object.OperationKind);
	Object.PayerKPP = StructureData.PayerKPP;
	
	If Not Object.DocumentCurrency = StructureData.CashCurrency Then
		
		Object.CounterpartyAccount = Undefined;
		Object.DocumentCurrency = StructureData.CashCurrency;
		
		If Object.DocumentAmount <> 0 Then
			MessageText = NStr("en = 'Currency of the bank account has been changed. Recalculate the document amount?'");
			
			Mode = QuestionDialogMode.YesNo;
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("CompanyAccountOnChangeEnd", ThisObject, New Structure("StructureData", StructureData)), MessageText, Mode, 0);
            Return;
		EndIf;
		
	EndIf;
	
	CompanyAccountOnChangeFragment(StructureData);
EndProcedure

&AtClient
Procedure CompanyAccountOnChangeEnd(Result, AdditionalParameters) Export
    
    StructureData = AdditionalParameters.StructureData;
    
    
    Response = Result;
    
    If Response = DialogReturnCode.Yes Then
        Object.DocumentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
        Object.DocumentAmount,
        StructureData.CurrencyRateMultiplicityBeforeChange.ExchangeRate,
        StructureData.CurrencyRateRepetition.ExchangeRate,
        StructureData.CurrencyRateMultiplicityBeforeChange.Multiplicity,
        StructureData.CurrencyRateRepetition.Multiplicity
        );
        Object.VATAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
        Object.VATAmount,
        StructureData.CurrencyRateMultiplicityBeforeChange.ExchangeRate,
        StructureData.CurrencyRateRepetition.ExchangeRate,
        StructureData.CurrencyRateMultiplicityBeforeChange.Multiplicity,
        StructureData.CurrencyRateRepetition.Multiplicity
        );
    EndIf;
    
    CompanyAccountOnChangeFragment(StructureData);

EndProcedure

&AtClient
Procedure CompanyAccountOnChangeFragment(Val StructureData)
    
    FillPayerText(StructureData);

EndProcedure // CompanyAccountOnChange()

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
	SetFormFrom2014Year();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")
	   AND ((SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(Object.Date)
	   AND Not SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(DateBeforeChange))
	   OR (NOT SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(Object.Date)
	   AND SmallBusinessClientServer.PaymentToBudgetAttributesNewRulesApplied(DateBeforeChange))) Then
		FillPaymentToBudgetByDefaultAttributes();
	EndIf;
	
	SetFormFrom2015Year();
	
	// Replace (add) UIN (unique accrual
	// identifier) From January 1, 2014 to March 30, 2014 it is specified in the payment purpose
	SmallBusinessClientServer.ReplaceInUINPaymentDestination(
		Object.PaymentDestination,
		Object.PaymentIdentifier,
		Object.Date,
		Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")
	);
	
EndProcedure // DateOnChange()

// Procedure - OnChange event handler of the OperationKind attribute.
// IN the procedure, the form attributes availability is
// set depending on the operation kind.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	If Object.OperationKind = OperationKind Then
		Return;
	EndIf;
	OperationKind = Object.OperationKind;
	
	SetVisibleEnabled();
	StructureData = GetCompanyDataOnChange(Object.Company, Object.BankAccount, Object.Counterparty, Object.CounterpartyAccount, Object.OperationKind, Object.Date);
	
	Object.PayerKPP = StructureData.PayerKPP;
	Object.PayeeKPP = StructureData.PayeeKPP;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer") Then
		Object.BKCode = "";
		Object.OKATOCode = StructureData.OKATOCode;
		Object.TransferToBudgetKind = PredefinedValue("Enum.BudgetTransferKinds.TaxPayment");
		Object.VATRate = Undefined;
		Object.VATAmount = Undefined;
		If ThisIsInd Then
			Object.PayerKPP = 0;
		EndIf;
		FillPaymentToBudgetByDefaultAttributes();
		Object.PaymentIdentifier = "";
		Items.PaymentIdentifier.Title = "WIN";
	Else
		Object.BKCode  = "";
		Object.OKATOCode = "";
		Object.AuthorStatus = "";
		Object.BasisIndicator = "";
		Object.TypeIndicator = "";
		Object.PeriodIndicator = "";
		Object.NumberIndicator = "";
		Object.DateIndicator = "";
		PaymentPeriod = "";
		PaymentYear = "";
		PeriodOfPayment = "";
		Object.TransferToBudgetKind = Undefined;
		If ThisIsInd Then
			Object.PayerKPP = "";
		EndIf;
		Object.PaymentIdentifier = "";
		Items.PaymentIdentifier.Title = "UIP";
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")
	   AND ValueIsFilled(StructureData.PayerDescriptionOnTaxTransfer) Then
		Object.PayerText = StructureData.PayerDescriptionOnTaxTransfer;
	Else
		Object.PayerText = ?(
			ValueIsFilled(StructureData.CorrespondentText),
			StructureData.CorrespondentText,
			StructureData.DescriptionFull
		);
	EndIf;
	
	If (ValueIsFilled(Object.Date) AND Object.Date >= SmallBusinessClientServer.StartApplyPaymetID())
	 OR (NOT ValueIsFilled(Object.Date) AND CurrentDate() >= SmallBusinessClientServer.StartApplyPaymetID())
	 OR (Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")) Then
		Items.PaymentIdentifier.WarningOnEditRepresentation = WarningOnEditRepresentation.Auto;
		Items.PaymentIdentifier.WarningOnEdit = "";
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.Payment") Then
		Items.PaymentIdentifier.WarningOnEditRepresentation = WarningOnEditRepresentation.Show;
		Items.PaymentIdentifier.WarningOnEdit = NStr("en = 'Payment ID is used only for payment into the budget until 03/31/2014'");
	EndIf;
	
	GeneratePaymentDestination();
	
	// Replace (add) UIN (unique accrual
	// identifier) From January 1, 2014 to March 30, 2014 it is specified in the payment purpose
	SmallBusinessClientServer.ReplaceInUINPaymentDestination(
		Object.PaymentDestination,
		Object.PaymentIdentifier,
		Object.Date,
		Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentOrder.TaxTransfer")
	);
	
EndProcedure // OperationKindOnChange()

// Procedure - event handler OnChange of attribute Counterparty.
// IN the procedure, the form attributes are related to the counterparty.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.DocumentCurrency, Object.OperationKind);
	
	Object.CounterpartyAccount 	= StructureData.CounterpartyAccount;
	Object.PayeeTIN	= StructureData.PayeeTIN;
	Object.PayeeKPP	= StructureData.PayeeKPP;
	FillTextRecipient(StructureData);
	
	PaymentDestination 		= StructureData.PaymentDestination;
	
	GeneratePaymentDestination();
	
EndProcedure // CounterpartyOnChange()

// Procedure - OnChange event handler of the CounterpartyAccount attribute.
// IN the procedure, the form attributes are set related to the counterparty account.
//
&AtClient
Procedure CounterpartyAccountOnChange(Item)
	
	StructureData = GetDataCounterpartyAccountOnChange(Object.Counterparty, Object.CounterpartyAccount, Object.OperationKind);
	
	Object.PayeeKPP = StructureData.PayeeKPP;
	FillTextRecipient(StructureData);
	
	PaymentDestination = StructureData.PaymentDestination;
	GeneratePaymentDestination();
	
EndProcedure // BankAccountCounterpartyOnChange()

// Procedure - OnChange event handler of the PayerKPP attribute.
//
&AtClient
Procedure PayerKPPOnChange(Item)
	
	If ValueIsFilled(Object.Company)
	AND Not ValueIsFilled(Object.PayerKPP)
	AND String(Object.OperationKind) = "Tax payment"
	AND ThisIsInd Then
		Object.PayerKPP = 0;
	EndIf;

EndProcedure // PayerKPPOnChange()

// Procedure - OnChange event handler of the DocumentAmount attribute.
// IN the procedure, the PaymentDestination attribute is generated.
//
&AtClient
Procedure DocumentAmountOnChange(Item)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(Object.VATRate);
	
	Object.VATAmount = Object.DocumentAmount - (Object.DocumentAmount) / ((VATRate + 100) / 100);
	
	GeneratePaymentDestination(True);
	
EndProcedure // DocumentAmountOnChange()

// Procedure - OnChange event handler of the VATRate attribute.
// IN the procedure, VAT amount is calculated and the PaymentDestination attribute is generated.
//
&AtClient
Procedure VATRateOnChange(Item)
	
	StructureData = GetDataVATRateOnChange(Object.VATRate);
	
	VATRate = StructureData.Rate;
	WithoutTaxVAT = StructureData.NotTaxable;
	
	Object.VATAmount = Object.DocumentAmount - (Object.DocumentAmount) / ((VATRate + 100) / 100);
	
	GeneratePaymentDestination(True);
	
EndProcedure // VATRateOnChange()

// Procedure - OnChange event handler of the VATAmount attribute.
// IN the procedure, the PaymentDestination attribute is generated.
//
&AtClient
Procedure VATAmountOnChange(Item)
	
	GeneratePaymentDestination(True);
	
EndProcedure // VATAmountOnChange()

// Procedure - OnChange event handler of the TransferToBudgetKind attribute.
//
&AtClient
Procedure TransferToBudgetKindOnChange(Item)
	
	SetChoiceList(
		Items.BasisIndicator,
		SmallBusinessClientServer.PaymentBases(Object.TransferToBudgetKind, Object.Date)
	);
	
	SetChoiceList(
		Items.TypeIndicator,
		SmallBusinessClientServer.PaymentTypes(Object.TransferToBudgetKind, Object.Date)
	);
	
	FillPaymentToBudgetByDefaultAttributes();
	SetVisibleDependendingOnTransferIntoBudgetKind();
	
EndProcedure // TransferToBudgetKindOnChange()

// Procedure - OnChange event handler of the ComposerStatus attribute.
//
&AtClient
Procedure CompilerStatusOnChange(Item)
	
	If Not ValueIsFilled(TrimAll(Object.AuthorStatus)) Then
		Object.AuthorStatus = "01";
	EndIf;
		
EndProcedure // CompilerStatusOnChange()

// Procedure - OnChange event handler of the BaseFlag attribute.
//
&AtClient
Procedure BasisIndicatorOnChange(Item)
	
	If Not ValueIsFilled(TrimAll(Object.BasisIndicator)) Then
		Object.BasisIndicator = "0";
	EndIf;

EndProcedure // BasisIndicatorOnChange()

// Procedure - OnChange event handler of the TypeFlag attribute.
//
&AtClient
Procedure TypeIndicatorOnChange(Item)
	
	If Not ValueIsFilled(TrimAll(Object.TypeIndicator)) Then
		Object.TypeIndicator = "0";
	EndIf;
	
EndProcedure // TypeIndicatorOnChange()

// Procedure - OnChange event handler of the PeriodFlagCustomsPayment attribute.
//
&AtClient
Procedure PeriodIndicatorCustomsPaymentOnChange(Item)
	
	If Object.TransferToBudgetKind <> PredefinedValue("Enum.BudgetTransferKinds.CustomsPayment")
	   AND Not ValueIsFilled(TrimAll(Object.PeriodIndicator)) Then
		Object.PeriodIndicator = "0";
	EndIf;
	
EndProcedure // PeriodIndicatorCustomsPaymentOnChange()

// Procedure - OnChange event handler of the PeriodFlagOtherPayment attribute.
//
&AtClient
Procedure PeriodIndicatorOtherPaymentOnChange(Item)
	
	If Not ValueIsFilled(TrimAll(Object.PeriodIndicator)) Then
		Object.PeriodIndicator = "0";
	EndIf;

EndProcedure // PeriodIndicatorOtherPaymentOnChange()

// Procedure - OnChange event handler of the DocumentBase attribute.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	If TypeOf(Object.BasisDocument) = Type("DocumentRef.SupplierInvoiceForPayment") Then
		StructureData = GetDataBasisDocumentOnChange(Object.BasisDocument);
		IncomingDocumentNumber = StructureData.IncomingDocumentNumber;
		IncomingDocumentDate = StructureData.IncomingDocumentDate;
	Else
		IncomingDocumentNumber = "";
		IncomingDocumentDate = '00010101';
	EndIf;
	
EndProcedure // BasisDocumentOnChange()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
