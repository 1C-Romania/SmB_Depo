#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PaymentOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text = 
	"SELECT
	|	PaymentOrder.Ref AS Ref,
	|	PaymentOrder.Number AS Number,
	|	PaymentOrder.Date AS DocumentDate,
	|	PaymentOrder.PaymentKind AS PaymentKind,
	|	PaymentOrder.PayerTIN AS PayerTIN,
	|	PaymentOrder.PayeeTIN AS PayeeTIN,
	|	PaymentOrder.BKCode AS BKCode,
	|	PaymentOrder.OKATOCode AS OKATOCode,
	|	PaymentOrder.PayerKPP AS PayerKPP,
	|	PaymentOrder.PayeeKPP AS PayeeKPP,
	|	PaymentOrder.PaymentDestination AS PaymentDestination,
	|	PaymentOrder.TransferToBudgetKind AS TransferToBudgetKind,
	|	PaymentOrder.PaymentPriority AS OrderOfPriority,
	|	PaymentOrder.DateIndicator AS DateIndicator,
	|	PaymentOrder.NumberIndicator AS NumberIndicator,
	|	PaymentOrder.BasisIndicator AS BasisIndicator,
	|	PaymentOrder.PeriodIndicator AS PeriodIndicator,
	|	PaymentOrder.TypeIndicator AS TypeIndicator,
	|	PaymentOrder.AuthorStatus AS AuthorStatus,
	|	PaymentOrder.DocumentAmount AS DocumentAmount,
	|	PaymentOrder.CounterpartyAccount.AccountNo AS RecipientAccountNumber,
	|	PaymentOrder.CounterpartyAccount.Bank.CorrAccount AS RecipientAccountNumberBankAccounts,
	|	PRESENTATION(PaymentOrder.CounterpartyAccount.Bank) AS PayeeBankDescription,
	|	PRESENTATION(PaymentOrder.CounterpartyAccount.AccountsBank) AS DescriptionOfSettlementsBankRecipient,
	|	PaymentOrder.CounterpartyAccount.AccountsBank AS SettlementsBankOfRecipients,
	|	PaymentOrder.CounterpartyAccount.Bank.City AS CityOfBeneficiarysBank,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.City AS CitySettlementsBankRecipient,
	|	PaymentOrder.CounterpartyAccount.Bank.Code AS RecipientBankBIC,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.Code AS RecipientSettlementsBankBIC,
	|	PaymentOrder.CounterpartyAccount.Bank.CorrAccount AS PayeeBankAcc,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.CorrAccount AS AccountBankRecipient,
	|	PaymentOrder.BankAccount.AmountWithoutCents AS AmountWithoutCents,
	|	PaymentOrder.BankAccount.CashCurrency AS CashCurrency,
	|	PaymentOrder.BankAccount.AccountNo AS PayerAccountNumber,
	|	PaymentOrder.BankAccount.Bank.CorrAccount AS PayerAccountNumberBankAccounts,
	|	PRESENTATION(PaymentOrder.BankAccount.Bank) AS PayerBankDescription,
	|	PRESENTATION(PaymentOrder.BankAccount.AccountsBank) AS DescriptionOfSettlementsBankOfPayer,
	|	PaymentOrder.BankAccount.AccountsBank AS SettlementsBankOfPayer,
	|	PaymentOrder.BankAccount.Bank.City AS SettlementPayerBank,
	|	PaymentOrder.BankAccount.AccountsBank.City AS CitySettlementsBankPayer,
	|	PaymentOrder.BankAccount.Bank.Code AS PayerBankBIC,
	|	PaymentOrder.BankAccount.AccountsBank.Code AS PayerSettlementsBankBIC,
	|	PaymentOrder.BankAccount.Bank.CorrAccount AS PayerBankAcc,
	|	PaymentOrder.BankAccount.AccountsBank.CorrAccount AS BankAccountOfPayer,
	|	PaymentOrder.PayerText AS PayerText,
	|	PaymentOrder.PayeeText AS PayeeText,
	|	PaymentOrder.BankAccount.MonthOutputOption AS MonthOutputOption,
	|	PaymentOrder.OperationKind AS OperationKind,
	|	PaymentOrder.PaymentIdentifier AS PaymentIdentifier,
	|	PaymentOrder.Company.Prefix AS Prefix
	|FROM
	|	Document.PaymentOrder AS PaymentOrder
	|WHERE
	|	PaymentOrder.Ref IN(&ObjectsArray)";
	
	SelectionForPrinting = Query.Execute().Select();
	
	FirstDocument = True;
	
	While SelectionForPrinting.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
	
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_PaymentOrder_PaymentOrder";
		
		Template = PrintManagement.GetTemplate("Document.PaymentOrder.PF_MXL_PaymentOrder");
		
		TemplateArea = Template.GetArea("TableTitle");
		TemplateArea.Parameters.Fill(SelectionForPrinting);
		
		If ValueIsFilled(SelectionForPrinting.SettlementsBankOfPayer) Then
			TemplateArea.Parameters.PayerAccountNumber = SelectionForPrinting.PayerAccountNumberBankAccounts;
		EndIf;
		If ValueIsFilled(SelectionForPrinting.SettlementsBankOfRecipients) Then
			TemplateArea.Parameters.RecipientAccountNumber = SelectionForPrinting.RecipientAccountNumberBankAccounts;
		EndIf;
		
		If ValueIsFilled(SelectionForPrinting.SettlementsBankOfPayer) Then
			TemplateArea.Parameters.PayerBankBIC = SelectionForPrinting.PayerSettlementsBankBIC;
		EndIf;
		If ValueIsFilled(SelectionForPrinting.SettlementsBankOfRecipients) Then
			TemplateArea.Parameters.RecipientBankBIC = SelectionForPrinting.RecipientSettlementsBankBIC;
		EndIf;
		
		If ValueIsFilled(SelectionForPrinting.SettlementsBankOfPayer) Then
			TemplateArea.Parameters.PayerBankAcc = SelectionForPrinting.BankAccountOfPayer;
		EndIf;
		If ValueIsFilled(SelectionForPrinting.SettlementsBankOfRecipients) Then
			TemplateArea.Parameters.PayeeBankAcc = SelectionForPrinting.AccountBankRecipient;
		EndIf;
		
		If SelectionForPrinting.DocumentDate < Date('20110101') Then
			DocumentNumberForPrinting = SmallBusinessServer.GetNumberForPrinting(SelectionForPrinting.Number, SelectionForPrinting.Prefix);
		Else
			DocumentNumberForPrinting = ObjectPrefixationClientServer.GetNumberForPrinting(SelectionForPrinting.Number, True, True);
		EndIf;
		
		TemplateArea.Parameters.DescriptionNumber = "PAYMENT ORDER No " + DocumentNumberForPrinting;
		
		MonthInWords = SelectionForPrinting.MonthOutputOption = Enums.MonthOutputTypesInDocumentDate.InWords;
		DateFormat    = "DF=" + ?(MonthInWords, "'dd MMMM yyyy'", "'dd.MM.yyyy'");
		
		TemplateArea.Parameters.DocumentDate = Format(SelectionForPrinting.DocumentDate, DateFormat);
		
		TemplateArea.Parameters.AmountAsNumber = SmallBusinessServer.FormatPaymentDocumentSUM(
			SelectionForPrinting.DocumentAmount,
			SelectionForPrinting.AmountWithoutCents
		);
		
		TemplateArea.Parameters.AmountInWords = SmallBusinessServer.FormatPaymentDocumentAmountInWords(
			SelectionForPrinting.DocumentAmount,
			SelectionForPrinting.CashCurrency,
			SelectionForPrinting.AmountWithoutCents
		);
		
		TemplateArea.Parameters.PayerTIN = "TIN " + TemplateArea.Parameters.PayerTIN;
		TemplateArea.Parameters.PayerKPP = "KPP " + TemplateArea.Parameters.PayerKPP;
		TemplateArea.Parameters.PayeeTIN  = "TIN " + TemplateArea.Parameters.PayeeTIN;
		TemplateArea.Parameters.PayeeKPP  = "KPP " + TemplateArea.Parameters.PayeeKPP;
		
		PayersBank = ?(
			ValueIsFilled(SelectionForPrinting.SettlementsBankOfPayer), 
			SelectionForPrinting.DescriptionOfSettlementsBankOfPayer,
			SelectionForPrinting.PayerBankDescription
		);
		
		SettlementPayerBank = ?(
			ValueIsFilled(SelectionForPrinting.SettlementsBankOfPayer), 
			SelectionForPrinting.CitySettlementsBankPayer,
			SelectionForPrinting.SettlementPayerBank
		);
		
		TemplateArea.Parameters.PayerBankDescription = "" + PayersBank + " " + SettlementPayerBank;
		
		RecipientBank = ?(
			ValueIsFilled(SelectionForPrinting.SettlementsBankOfRecipients), 
			SelectionForPrinting.DescriptionOfSettlementsBankRecipient,
			SelectionForPrinting.PayeeBankDescription
		);
		
		CityOfBeneficiarysBank = ?(
			ValueIsFilled(SelectionForPrinting.SettlementsBankOfRecipients), 
			SelectionForPrinting.CitySettlementsBankRecipient,
			SelectionForPrinting.CityOfBeneficiarysBank
		);
		
		TemplateArea.Parameters.PayeeBankDescription = "" + RecipientBank + " " + CityOfBeneficiarysBank;
		
		If SelectionForPrinting.OperationKind = Enums.OperationKindsPaymentOrder.TaxTransfer Then
			
			TemplateArea.Parameters.AuthorStatus = ?(IsBlankString(SelectionForPrinting.AuthorStatus), "0", TrimAll(SelectionForPrinting.AuthorStatus));
			TemplateArea.Parameters.BKCode = ?(IsBlankString(SelectionForPrinting.BKCode), "", TrimAll(SelectionForPrinting.BKCode));
			TemplateArea.Parameters.OKATOCode = ?(IsBlankString(SelectionForPrinting.OKATOCode),
				?(SelectionForPrinting.TransferToBudgetKind = Enums.BudgetTransferKinds.CustomsPayment, "0", ""),
				TrimAll(SelectionForPrinting.OKATOCode));
			TemplateArea.Parameters.BasisIndicator = TrimAll(SelectionForPrinting.BasisIndicator);
			TemplateArea.Parameters.NumberIndicator = ?(SelectionForPrinting.NumberIndicator = "", "0",  TrimAll(SelectionForPrinting.NumberIndicator));
			TemplateArea.Parameters.DateIndicator = ?(SelectionForPrinting.DateIndicator = '00010101000000', "0", Format(SelectionForPrinting.DateIndicator, "DF='dd.MM.yyyy'"));
			TemplateArea.Parameters.TypeIndicator = TrimAll(SelectionForPrinting.TypeIndicator);
			If SelectionForPrinting.DocumentDate >= '20150101' Then
				// According to the Order of the Ministry of Finance from 10/30/2014 No.126n since 01/01/2015 the indicator of the (field "110") type is not filled.
				// But according to the CENTRAL BANK OF RUSSIAN
				// FEDERATION Regulation from 19.06.2012 No 383-P "Orders in which 101 attribute has the value subject to attribute value existence control 102 - 110".
				// So always specify in the field "110" - "0".
				TemplateArea.Parameters.TypeIndicator = "0";
			EndIf;
			
			TemplateArea.Parameters.PeriodIndicator = TrimAll(SelectionForPrinting.PeriodIndicator);
		
		EndIf;
		
		If SelectionForPrinting.DocumentDate < '20140331' Then
			// Identifier can be specified in printed form of payment orders since 03/31/2014
			TemplateArea.Parameters.PaymentIdentifier = "";
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, SelectionForPrinting.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PaymentOrder") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PaymentOrder", "Invoice note", PrintForm(ObjectsArray, PrintObjects));
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
	PrintCommand.ID = "PaymentOrder";
	PrintCommand.Presentation = NStr("en='Payment order';ru='Порядок платежа'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf