////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks the correctness of the form attribute filling.
//
&AtClient
Function CheckFillOfFormAttributes()
	
	CheckResultOk = True;
	
	// Attributes filling check.
	If Not ValueIsFilled(Object.Encoding) Then
		MessageText = NStr("en = 'Coding is not specified in the settings!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "Encoding", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.FormatVersion) Then
		MessageText = NStr("en = 'Exchange format version is not configured in the settings!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "FormatVersion", CheckResultOk);
	EndIf;
	
	Return CheckResultOk;
	
EndFunction // CheckFillFormAttributes()

// Procedure checks sets readiness.
//
&AtServer
Procedure SetReadiness(CurrentReadiness, NewReadiness)
	
	If ValueIsFilled(CurrentReadiness)
	   AND CurrentReadiness < NewReadiness Then
		CurrentReadiness = NewReadiness;
	ElsIf Not ValueIsFilled(CurrentReadiness) Then
		CurrentReadiness = NewReadiness;
	EndIf;
	
EndProcedure // SetReadiness()

// Procedure adds a comment.
//
&AtServer
Procedure AddComment(DocumentStructure, NewReadiness, NoticeText)
	
	SetReadiness(DocumentStructure.Readiness, NewReadiness);
	AddToString(DocumentStructure.ErrorsDescriptionFull, NoticeText);
	
EndProcedure // AddComment()

// Procedure adds a row.
//
&AtServer
Procedure AddToString(Buffer, NewRow)
	
	If IsBlankString(Buffer) Then
		Buffer = NewRow;
	Else
		Buffer = Buffer + Chars.LF + NewRow;
	EndIf;
	
EndProcedure // AddToString()

// Function creates a match from string.
//
&AtServer
Function CreateMapFromString(Val StringThroughComma)
	
	NewMap = New Map;
	SeparatorPosition = Find(StringThroughComma, ",");
	While SeparatorPosition > 0 Do
		NameItema = Left(StringThroughComma, SeparatorPosition - 1);
		NewMap.Insert(NameItema, True);
		StringThroughComma = Mid(StringThroughComma, SeparatorPosition + 1);
		SeparatorPosition = Find(StringThroughComma, ",");
	EndDo;
	If StrLen(StringThroughComma) > 0 Then
		NewMap.Insert(StringThroughComma, True);
	EndIf;
	
	Return NewMap;
	
EndFunction // CreateMatchFromString()

// Procedure imports data from a file.
//
&AtServer
Procedure DataLoadFromFile()
	
	//( elmi #17 (112-00003) 
	//FormAttributeToValue("Object").Load(ImportTitle);
	FormAttributeToValue("Object").Import(ImportTitle);
    //) elmi  
	
EndProcedure // DataLoadFromFile()

// Procedure sets flags.
//
&AtClient
Procedure SetFlags(Table, Field, ValueOfFlag, FillAmounts)
	
	For Each String IN Table Do
		String[Field] = ValueOfFlag;
		If FillAmounts Then
			FillAmount76AtClient(String)
		EndIf;
	EndDo;
	
EndProcedure // SetFlags()

// Function receives a date from string.
//
&AtServer
Function GetDateFromString(Receiver, Source)
	
	Buffer = Source;
	DotPosition = Find(Buffer, ".");
	If DotPosition = 0 Then
		Return NStr("en = 'The incorrect format of the date row'");
	EndIf;
	NumberDate = Left(Buffer, DotPosition - 1);
	Buffer = Mid(Buffer, DotPosition + 1);
	DotPosition = Find(Buffer, ".");
	If DotPosition = 0 Then
		Return NStr("en = 'The incorrect format of the date row'");
	EndIf;
	DateMonth = Left(Buffer, DotPosition - 1);
	DateYear = Mid(Buffer, DotPosition + 1);
	If StrLen(DateYear) = 2 Then
		If Number(DateYear) < 50 Then
			DateYear = "20" + DateYear;
		Else
			DateYear = "19" + DateYear ;
		EndIf;
	EndIf;
	Try
		Receiver = Date(Number(DateYear), Number(DateMonth), Number(NumberDate));
	Except
		Return NStr("en = 'Failed to convert string to date'");
	EndTry;
	
	Return Receiver;
	
EndFunction // GetDateFromString()

// Function defines whether the company is a payer.
//
&AtServer
Function CompanyPayer(DocumentKind)
	
	If DocumentKind = "PaymentReceipt" Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction // CompanyPayer()

// Function finds the counterparty contract.
//
&AtServer
Function FindContract(OwnerTreaty, CompanyContracts = Undefined, ContractKindsList = Undefined)
	
	NewContract = Catalogs.CounterpartyContracts.EmptyRef();
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED TOP 2
	|	CounterpartyContracts.Ref,
	|	CASE
	|		WHEN CatalogOwner.Ref IS Not NULL 
	|			THEN 1
	|		ELSE 2
	|	END AS Priority
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|		LEFT JOIN Catalog.Counterparties AS CatalogOwner
	|		ON CounterpartyContracts.Owner = CatalogOwner.Ref
	|			AND CounterpartyContracts.Ref = CatalogOwner.ContractByDefault
	|WHERE
	|	&TextFilter
	|
	|ORDER BY
	|	Priority";
	
	Query.SetParameter("OwnerTreaty", OwnerTreaty);
	Query.SetParameter("CompanyContracts", CompanyContracts);
	Query.SetParameter("ContractKindsList", ContractKindsList);
	
	TextFilter =
	"	CounterpartyContract.Owner = &ContractOwner"
  + ?(CompanyContracts <> Undefined, "
	|	And CounterpartyContracts.Company = &CompanyContract", "") 
  +	"	And CounterpartyContracts.DeletionMark = FALSE"
  + ?(ContractKindsList <> Undefined, "
	|	And CounterpartyContracts.ContractType IN (&ContractTypeList)", "");
	
	QueryText = StrReplace(QueryText, "&TextFilter", TextFilter);
	Query.Text = QueryText;
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	Else
		Return NStr("en = 'Not found'");
	EndIf;
	
EndFunction // FindContract()

// Function forms a match of imported items.
//
&AtServer
Function GenerateMapOfItemsBeingImported()
	
	ImportExportable = CreateMapFromString(
		Upper("Number,Date,Amount,PaymentKind,PayKind,StatementDate,StatementTime,StatementContent,DateCredited,Date_Received,"
		   + "PayerAccount,Payer,PayerTIN,Payer1,PayerBankAcc,PayerBank1,PayerBank2,PayerBIC,PayerBalancedAccount,Payer2,Payer3,Payer4,"
		   + "PayeeAccount,Recipient,PayeeTIN,Payee1,PayeeBankAcc,PayeeBank1,PayeeBank2,PayeeBIK,PayeeBalancedAccount,Payee2,Payee3,Payee4,"
		   + "AuthorStatus,PayerKPP,PayeeKPP,KBKIndicator,OKATO,BasisIndicator,PeriodIndicator,NumberIndicator,DateIndicator,TypeIndicator,"
		   + "PaymentDestination,PaymentDestination1,PaymentDestination2,PaymentDestination3,PaymentDestination4,PaymentDestination5,PaymentDestination6,"
		   + "OrderOfPriority,PaymentDueDate,PaymentCondition1,PaymentCondition2,PaymentCondition3,AcceptanceTerm,LetterOfCreditType,PaymentByRepr,AdditionalConditions,NumberVendorAccount,DocSendingDate,Code"
		)
	);
	
	Return ImportExportable;
	
EndFunction // GenerateImportedItemsMatch()

// Procedure forms a match of not empty items when importing.
//
&AtServer
Procedure GenerateMapsOFNotEmptyItemsOnImport(ImportIsNotEmpty, ImportBlankPaymentOrder, ImportBlankPaymentOrderBudget)
	
	ImportBlankPaymentOrder = CreateMapFromString(
		"Number,Date,Amount,PayerAccount,PayerTIN,PayeeAccount,PayeeTIN"
	);
	
	// According to issuer status it is defined that the payment is - tax.
	ImportBlankPaymentOrderBudget = CreateMapFromString(
		"Number,Date,Amount,PayerAccount,PayerTIN,PayeeAccount,PayeeTIN,"
	  + "AuthorStatus,PayerKPP,PayeeKPP,KBKIndicator,OKATO,BasisIndicator,"
	  + "PeriodIndicator,NumberIndicator,DateIndicator,TypeIndicator"
	);
	
	ImportIsNotEmpty = New Array;
	ImportIsNotEmpty.Add(ImportBlankPaymentOrder);
	ImportIsNotEmpty.Add(ImportBlankPaymentOrderBudget);
	
EndProcedure // GenerateNotEmptyItemsMatchOnImport()

// Function receives an import string.
//
&AtServer
Function GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing)
	
	Buffer = "";
	While IsBlankString(Buffer)
	 OR Left(Buffer, 2) = "//" Do
		If ImportCurrentRow > ImportLineCount Then
			Return "";
		EndIf;
		Buffer = TrimAll(StrGetLine(ImportTextForParsing, ImportCurrentRow));
		ImportCurrentRow = ImportCurrentRow + 1;
	EndDo;
	
	Return Buffer;
	
EndFunction // GetImportString()

// Function parses tag string.
//
&AtServer
Function ParseTagString(ParsingString, Tag, Value)
	
	AssignmentPosition = Find(ParsingString, "=");
	If AssignmentPosition = 0 Then
		Return False;
	EndIf;
	
	Tag = Upper(TrimAll(Left(ParsingString, AssignmentPosition - 1)));
	Value = TrimAll(Mid(ParsingString, AssignmentPosition + 1));
	
	Return Not IsBlankString(Tag);
	
EndFunction // ParseTagString()

// Function loads the document section
//
&AtServer
Function ImportDocumentSection(DocumentRow, ImportCurrentRow, ImportLineCount, ImportTextForParsing, ImportExportable)
	
	ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
	While Left(Upper(TrimAll(ParsingString)), 14) <> "EndDocument" Do
		Value = "";
		Tag = "";
		If ParseTagString(ParsingString, Tag, Value) Then
			If ImportExportable[Tag] = True Then
				DocumentRow[Tag] = Value;
			Else
				
				// Invalid title attribute.
				MessageText = NStr(
					"en = 'Invalid attribute of payment document, string %Import%: %ParseString%'"
				);
				MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
				MessageText = StrReplace(MessageText, "%ParsingString%", ParsingString);
				SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
				Return False;
				
			EndIf;
		Else
			
			// Invalid title attribute.
			MessageText = NStr(
				"en = 'Broken structure of payment document, string %Import%: %ParseString%'"
			);
			MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
			MessageText = StrReplace(MessageText, "%ParsingString%", ParsingString);
			SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
			Return False;
			
		EndIf;
		ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
	EndDo;
	
	Return True;
	
EndFunction // ImportDocumentSection()

// Function loads the settlement account sections.
//
&AtServer
Function ImportBankAccSection(SAAccountRow, ImportCurrentRow, ImportLineCount, ImportTextForParsing, SettlementsAccountsTags)
	
	ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
	Value = "";
	Tag = "";
	While ParseTagString(ParsingString, Tag, Value) Do
		If SettlementsAccountsTags[Tag] = True Then
			SAAccountRow[Tag] = Value;
		Else
			// Invalid title attribute.
			MessageText = NStr(
				"en = 'Invalid attribute of settlement account description section, string %Import%: %ParseString%'"
			);
			MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
			MessageText = StrReplace(MessageText, "%ParsingString%", ParsingString);
			SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
			Return False;
		EndIf;
		ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
		Value = "";
		Tag = "";
	EndDo;
	
	If UPPER(Left(TrimAll(ParsingString), 13)) = "ENDBANKACC" Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction // ImportBankAccSection()

// Procedure checks for an empty value while importing.
//
&AtServer
Procedure CheckForBlankImportValue(ImportRow, PropertyName, PresentationProperties, ImportIsNotEmpty)
	
	If ImportIsNotEmpty[0][PropertyName] = True Then
		If Not ValueIsFilled(ImportRow[PropertyName]) Then
			RowRemark = NStr("en = '""%PropertyName%"" is not filled!'");
			RowRemark = StrReplace(RowRemark, "%PropertyName%", PropertyName);
			AddComment(ImportRow, 3, RowRemark);
		EndIf;
	EndIf;
	
EndProcedure // CheckForEmptyImportValue()

// Function imports the exchange file title.
//
&AtServer
Function ImportHeaderString(HeaderRowText, TagsHeader, ImportTitle, ImportCurrentRow)
	
	Value = "";
	Tag = "";
	ParseTagString(HeaderRowText, Tag, Value);
	If TagsHeader[Tag] = True Then
		ImportTitle[Tag] = Value;
	Else
		
		// Invalid title attribute.
		MessageText = NStr("en = 'Invalid title attribute, string %Import%: %TitleStringText%'");
		MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
		MessageText = StrReplace(MessageText, "%TitleStringText%", HeaderRowText);
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
		
	EndIf;
	
EndFunction // ImportHeaderString()

// Function checks if a row has digits only.
//
// CheckString
//  Parameters - String for digit checking only
//
// Returns:
//   Boolean
//
&AtServer
Function AreNotDigits(Val CheckString)
	
	If TypeOf(CheckString) <> Type("String") Then
		Return True;
	EndIf;
	CheckString = TrimAll(CheckString);
	Length = StrLen(CheckString);
	For Ct = 1 To Length Do
		If Find("0123456789", Mid(CheckString, Ct, 1)) = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction // AreNotDigits()

// Procedure recognizes data in document row.
//
&AtServer
Procedure RecognizeDataInDocumentRow(DocumentRow)
	
	BlankDate = Date("00010101");
	
	// 1) We define the payment type — incoming or outgoing.
	PaymentOrder = Upper(StrReplace(TrimAll(DocumentRow.Operation), " ", "")) = "PaymentOrder";
	Outgoing = (DocumentRow.PayerAccount = Object.BankAccount.AccountNo);
	
	// 2) We define the document type in application.
	DocumentKind = ?(Outgoing, "PaymentExpense", "PaymentReceipt");
	DocumentName = ?(Outgoing, "Payment expense", "Payment receipt");
	
	DocumentRow.DocumentName = DocumentName;
	DocumentRow.DocumentKind = DocumentKind;
	AttributeAccounts = ?(Outgoing, "BankAccount", "CounterpartyAccount");
	
	// 3) We find previously imported (typed) document.
	// Attributes for search: Document Type, Date, Number, Account #
	
	// We recognize document date.
	DocDate = BlankDate;
	
	If Not IsBlankString(DocumentRow.DateCredited) Then
		Result = GetDateFromString(DocDate, DocumentRow.DateCredited);
	ElsIf Not IsBlankString(DocumentRow.Date_Received) Then
		Result = GetDateFromString(DocDate, DocumentRow.Date_Received);
	Else
		Result = GetDateFromString(DocDate, DocumentRow.Date);
	EndIf;
	
	If ValueIsFilled(Result) Then
		DocumentRow.DocDate = Result;
		NumberForDocSearch = DocumentRow.Number;
		AttributeOfDate = "IncomingDocumentDate";
		NumberAttribute = "IncomingDocumentNumber";
		AllAttributesSearchIs = True;
	EndIf;
	
	DocumentRow.DocNo = DocumentRow.Number;
	
	If AllAttributesSearchIs Then
		
		// If there are several items, the first
		// with matching account number is preferred.
		QuerySearchDocument = New Query;
		QuerySearchDocument.Text = 
		"SELECT ALLOWED
		|	PaymentDocuments.Ref,
		|	PaymentDocuments.Posted,
		|	PaymentDocuments." + NumberAttribute + " AS
		|	Number, PaymentDocuments." + AttributeOfDate + " AS Date,
		|	PaymentDocuments.CounterpartyAccount.AccountNo AS AccountNo,
		|	PaymentDocuments.Company
		|FROM
		|	Document." + DocumentRow.DocumentKind + " AS
		|PaymentDocuments
		|	WHERE BEGINOFPERIOD(PaymentDocuments." + AttributeOfDate + ", DAY)=
		|	&DateDoc And PaymentDocuments.BankAccount
		|	= &BankAccount And PaymentDocuments.Company = &Company";
		
		QuerySearchDocument.SetParameter("DocDate", DocDate);
		QuerySearchDocument.SetParameter("Company", Object.Company);
		QuerySearchDocument.SetParameter("BankAccount", Object.BankAccount);
		Result = QuerySearchDocument.Execute().Select();
		AccountForDocSearch = ?(Outgoing, DocumentRow.PayeeAccount, DocumentRow.PayerAccount);
		NumberLength = StrLen(NumberForDocSearch);
		QuantityDoc = 0;
		
		While Result.Next() Do
			SelectionNumber = Right(TrimAll(Result.Number), NumberLength);
			If SelectionNumber = NumberForDocSearch
			  AND (NOT ValueIsFilled(Result.AccountNo) OR Result.AccountNo = AccountForDocSearch) Then
				If QuantityDoc = 0 Then
					DocumentRow.Document = Result.Ref;
					DocumentRow.Posted = Result.Posted;
					DocumentRow.DocNo = Result.Number;
					DocumentRow.DocDate = Result.Date;
				EndIf;
				QuantityDoc = QuantityDoc + 1;
			EndIf;
		EndDo;
		
		If QuantityDoc > 1 Then
			RowRemark = NStr("en = 'Several (%QuantityDoc%) corresponding documents have been found in the infobase!'");
			RowRemark = StrReplace(RowRemark, "%QuantityDoc%", QuantityDoc);
			AddComment(DocumentRow, 1, RowRemark);
		EndIf;
		
		// If the document already is in the IB then we take all data from it.
		DocumentIsFound = ValueIsFilled(DocumentRow.Document);
		If DocumentIsFound Then
			Document = DocumentRow.Document; 
			DocumentRow.OperationKind = Document.OperationKind; 
			DocumentRow.CFItem = Document.Item; 
			DocumentRow.BankAccount = Object.BankAccount;
			DocumentRow.CounterpartyAccount = Document.CounterpartyAccount;
			DocumentRow.Counterparty = Document.Counterparty;
			If Document.PaymentDetails.Count() <> 0 Then
				DocumentRow.Contract = Document.PaymentDetails[0].Contract;
				DocumentRow.AdvanceFlag = Document.PaymentDetails[0].AdvanceFlag;
				DocumentRow.Order = Document.PaymentDetails[0].Order;
			EndIf;
		EndIf;
		
	EndIf;
	
	// 4) We define the document operation type.
	If Not ValueIsFilled(DocumentRow.OperationKind) Then
		If Outgoing Then
			If ValueIsFilled(DocumentRow.AuthorStatus) Then // tax payment 
				If DocumentRow.AuthorStatus = "06" OR DocumentRow.AuthorStatus = "08" 
				 OR ((Number(DocumentRow.AuthorStatus) >= 16) AND (Number(DocumentRow.AuthorStatus) <= 20)) Then
					OperationKindDocument = Enums.OperationKindsPaymentExpense.Other;
				Else
					OperationKindDocument = Enums.OperationKindsPaymentExpense.Taxes;
				EndIf;
			ElsIf Catalogs.BankAccounts.FindByAttribute("AccountNo", DocumentRow.PayeeAccount).Owner = Object.BankAccount.Owner Then // transfer to other account
				OperationKindDocument = Enums.OperationKindsPaymentExpense.Other;
			Else // Payment to vendor
				OperationKindDocument = Enums.OperationKindsPaymentExpense.Vendor;
			EndIf; 
		Else
			OperationKindDocument = Enums.OperationKindsPaymentReceipt.FromCustomer;
		EndIf;
		DocumentRow.OperationKind = OperationKindDocument;
	Else
		OperationKindDocument = DocumentRow.OperationKind;
	EndIf;
	
	// 5) We define the company bank account
	If Not ValueIsFilled(DocumentRow.BankAccount) Then
		DocumentRow.BankAccount = Object.BankAccount;
	EndIf;
	
	// 6) We define the counterparty bank account
	If Not ValueIsFilled(DocumentRow.CounterpartyAccount) Then
		AccountSearchQuery = New Query;
		If CompanyPayer(DocumentKind) Then
			CounterpartyAccount = DocumentRow.PayeeAccount;
			TINCounterparty = DocumentRow.PayeeTIN;
			CounterpartyCRR = DocumentRow.PayeeKPP;
			If ValueIsFilled(DocumentRow.Payee1) Then
				CounterpartyName = DocumentRow.Payee1;
			Else
				CounterpartyName = DocumentRow.Recipient;
			EndIf;
			AccountSearchQuery.SetParameter("AccountNo", DocumentRow.PayeeAccount);
		Else
			AccountSearchQuery.SetParameter("AccountNo", DocumentRow.PayerAccount);
			CounterpartyAccount = DocumentRow.PayerAccount;
			TINCounterparty = DocumentRow.PayerTIN;
			CounterpartyCRR = DocumentRow.PayerKPP;
			If DocumentRow.Payer1 <> "" Then
				CounterpartyName = DocumentRow.Payer1;
			Else
				CounterpartyName = DocumentRow.Payer;
			EndIf;
		EndIf;
		AccountSearchQuery.SetParameter("TINCounterparty", TINCounterparty);
		AccountSearchQuery.Text = 
		"SELECT ALLOWED
		|	BankAccounts.Owner,
		|	BankAccounts.Ref,
		|	BankAccounts.AccountNo
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|WHERE
		|	BankAccounts.Owner REFS Catalog.Counterparties 
		|	" + ?(NOT IsBlankString(TINCounterparty), "AND BankAccounts.Owner.TIN = &TINCounterparty", "") + "
		|	And BankAccount.AccountNumber = &AccountNumber";
		
		SearchSelection = AccountSearchQuery.Execute().Select();
		Counterparty = Catalogs.Counterparties.EmptyRef();
		
		If SearchSelection.Next() Then
			DocumentRow.CounterpartyAccount = SearchSelection.Ref;
			Counterparty = SearchSelection.Owner;
		Else
			RowRemark = NStr("en = 'Counterparty account is not found (%CounterpartyAccount%).'");
			RowRemark = StrReplace(RowRemark, "%CounterpartyAccount%", CounterpartyAccount);
			AddComment(DocumentRow, 2, RowRemark);
			StringGLCounterpartyAccount = NStr("en = 'Not found (%CounterpartyAccount%).'");
			StringGLCounterpartyAccount = StrReplace(RowRemark, "%CounterpartyAccount%", CounterpartyAccount);
			DocumentRow.CounterpartyAccount = StringGLCounterpartyAccount;
		EndIf;
		
		If SearchSelection.Count() > 1 Then
			RowRemark = NStr("en = 'The several (%Quantity%) same banking accounts have been found in the infobase!'");
			RowRemark = StrReplace(RowRemark, "%Quantity%", SearchSelection.Count());
			AddComment(DocumentRow, 1, RowRemark);
		EndIf;
	EndIf;
	
	// 7) We define counterparty.
	If Not ValueIsFilled(DocumentRow.Counterparty) Then
		If ValueIsFilled(Counterparty) Then
			DocumentRow.Counterparty = Counterparty;
		ElsIf Not IsBlankString(TINCounterparty) Then
			
			DocumentRow.Counterparty = Counterparty;
			QuerySearchCounterparty = New Query(
			"SELECT ALLOWED
			|	Counterparties.Ref,
			|	Counterparties.TIN,
			|	Counterparties.Description,
			|	Counterparties.KPP
			|FROM
			|	Catalog.Counterparties AS Counterparties
			|WHERE
			|	Counterparties.TIN = &CounterpartyTIN");
			
			QuerySearchCounterparty.SetParameter("CounterpartyTIN", TINCounterparty);
			SearchSelection = QuerySearchCounterparty.Execute().Unload();
			
			// We find counterparty by TIN if there is CRR then we use it while finding too.
			FilterParameters = New Structure;
			FilterParameters.Insert("TIN", TINCounterparty);
			If Not IsBlankString(CounterpartyCRR) Then
				FilterParameters.Insert("KPP", CounterpartyCRR);
			EndIf;
			FoundsCounterparties = SearchSelection.FindRows(FilterParameters);
			
			// If we did not find either by TIN or by CRR then we try to find by TIN only.
			If FoundsCounterparties.Count() = 0
			AND Not IsBlankString(CounterpartyCRR) Then
				FilterParameters = New Structure;
				FilterParameters.Insert("TIN", TINCounterparty);
				FoundsCounterparties = SearchSelection.FindRows(FilterParameters);
			EndIf;
			
			If FoundsCounterparties.Count() > 0 Then
				DocumentRow.Counterparty = FoundsCounterparties[0].Ref;
			EndIf;
			
			If FoundsCounterparties.Count() > 1 Then
				RowRemark = NStr("en = 'Several (%Quantity%) same TIN counterparties have been found in the infobase!'");
				RowRemark = StrReplace(RowRemark, "%Quantity%", FoundsCounterparties.Count());
				AddComment(DocumentRow, 2, RowRemark);
			ElsIf FoundsCounterparties.Count() = 0 Then
				RowRemark = NStr("en = 'Counterparty is not found (%CounterpartyName%,TIN %TINCounterparty%).'");
				RowRemark = StrReplace(RowRemark, "%CounterpartyName%", CounterpartyName);
				RowRemark = StrReplace(RowRemark, "%TINCounterparty%", TINCounterparty);
				AddComment(DocumentRow, 2, RowRemark);
				StringCounterparty = NStr("en = 'Not found (%CounterpartyName%, TIN, %TINCounterparty%).'");
				StringCounterparty = StrReplace(StringCounterparty, "%CounterpartyName%", CounterpartyName);
				StringCounterparty = StrReplace(StringCounterparty, "%TINCounterparty%", TINCounterparty);
				DocumentRow.Counterparty = StringGLCounterpartyAccount;
			EndIf;
			
		Else
			AddComment(DocumentRow, 2, NStr("en = 'The TIN of the counterparty is not specified. '"));
			StringCounterparty = NStr("en = 'Not found (%CounterpartyName%, TIN is not specified).'");
			StringCounterparty = StrReplace(StringCounterparty, "%CounterpartyName%", CounterpartyName);
			DocumentRow.Counterparty = StringCounterparty;
		EndIf;
	EndIf;
	
	// 8) We define the counterparty contract
	If DocumentRow.OperationKind <> Enums.OperationKindsPaymentExpense.Taxes
	AND Not ValueIsFilled(DocumentRow.Contract) Then
		DocumentRow.Contract = FindContract(DocumentRow.Counterparty, Object.Company);
		If DocumentRow.Contract = NStr("en = 'Not found'") Then
			DocumentRow.Contract = FindContract(DocumentRow.Counterparty);
		EndIf;
		If DocumentRow.Contract = NStr("en = 'Not found'") Then
			AddComment(DocumentRow, 2, NStr("en = 'The counterparty contract is not found. '"));
		EndIf;
	EndIf;
	
	// 9) We define the CF item by default.
	If Not ValueIsFilled(DocumentRow.CFItem) Then
		If Outgoing Then
			DocumentRow.CFItem = Object.CFItemOutgoing;
		Else
			DocumentRow.CFItem = Object.CFItemIncoming;
		EndIf;
	EndIf;
	
	// 10) We define amount.
	
	// Convert from string into number.
	Buffer = TrimAll(StrReplace(DocumentRow.Amount, " ", ""));
	
	If Not AreNotDigits(StrReplace(StrReplace(StrReplace(Buffer, ".", ""), "-", ""), ",", "")) Then
		Amount = Number(Buffer);
		If Amount < 0 Then
			Amount = - Amount;
		EndIf;
		DocumentRow.DocumentAmount = Amount;
		If Outgoing Then
			DocumentRow.AmountCredited = Amount;
		Else
			DocumentRow.AmountDebited = Amount;
		EndIf;
	Else
		RowRemark = NStr("en = 'Incorrect document amount (%Buffer%) is specified!'");
		RowRemark = StrReplace(RowRemark, "%Buffer%", Buffer);
		AddComment(DocumentRow, 4, RowRemark);
	EndIf;
	
	// 11) We define the payment priority.
	
	// Convert from string into number
	Buffer = TrimAll(DocumentRow.OrderOfPriority);
	If Buffer <> "" AND Not AreNotDigits(Buffer) Then
		DocumentRow.PaymentPriority = Number(Buffer);
	Else
		DocumentRow.PaymentPriority = 0;
	EndIf;
	
	// 12) We define DocDateIndicator (for Payment order
	// outgoing when paying taxes).
	
	// We convert to date from a string if it is not empty
	If Not IsBlankString(DocumentRow.DateIndicator) Then
		Result = GetDateFromString(DocumentRow.DocDateIndicator, DocumentRow.DateIndicator);
		If Not ValueIsFilled(Result) Then
			DocumentRow.DocDateIndicator = Undefined;
		EndIf;
	EndIf;
	
	// 13) DateCredited and DateRecieved, DatePosted.
	
	// We convert to date from a string if it is not empty
	If Not IsBlankString(DocumentRow.DateCredited) Then
		Result = GetDateFromString(DocumentRow.WrittenOff, DocumentRow.DateCredited);
		If Not ValueIsFilled(Result) Then
			DocumentRow.WrittenOff = BlankDate;
		Else
			DocumentRow.DatePosted = DocumentRow.WrittenOff;
		EndIf;
	Else
		DocumentRow.WrittenOff = BlankDate;
	EndIf;
	
	// We convert to date from a string if it is not empty.
	If Not IsBlankString(DocumentRow.Date_Received) Then
		Result = GetDateFromString(DocumentRow.Debited, DocumentRow.Date_Received);
		If Not ValueIsFilled(Result) Then
			DocumentRow.Debited = BlankDate;
		Else
			DocumentRow.DatePosted = DocumentRow.Debited;
		EndIf;
	Else
		DocumentRow.Debited = BlankDate;
	EndIf;
	
	// If PaymentDestination is empty then we form it from PaymentDestination1...PaymentDestination6.
	If IsBlankString(DocumentRow.PaymentDestination) Then
		DocumentRow.PaymentDestination = DocumentRow.PaymentDestination1;
		For Ct = 2 To 6 Do
			If Not ValueIsFilled(DocumentRow["PaymentDestination" + Ct]) Then
				Break;
			EndIf;
			DocumentRow.PaymentDestination = DocumentRow.PaymentDestination + Chars.LF + DocumentRow["PaymentDestination" + Ct];
		EndDo;
	EndIf;
	
EndProcedure // RecognizeDataInDocumentRow()

// Function returns the found tree item.
//
&AtServer
Function FindTreeItem(TreeItems, ColumnName, RequiredValue)
	
	For Num = 0 To TreeItems.Count() - 1 Do
		
		TreeItem = TreeItems.Get(Num);
		
		If TreeItem[ColumnName] = RequiredValue Then
			Return TreeItem;
		EndIf;
		
		If TreeItem.GetItems().Count() > 0 Then
			
			SearchResult = FindTreeItem(TreeItem.GetItems(), ColumnName, RequiredValue);
			
			If Not SearchResult = Undefined Then
				Return SearchResult;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction // FindTreeItem()

// Function adds and returns the new attribute description.
//
&AtServer
Function AddNewAttributeDescription(Presentation, Attribute, CounterpartyType, NewCounterparty, DocumentRow)
	
	AttributesOfNewCounterparty = NewCounterparty.Add();
	
	AttributesOfNewCounterparty.Presentation = Presentation;
	AttributesOfNewCounterparty.Value      = DocumentRow[CounterpartyType + Attribute];
	AttributesOfNewCounterparty.Attribute      = CounterpartyType + Attribute;
	
	Return AttributesOfNewCounterparty;
	
EndFunction // AddNewAttributeDescription()

// Procedure creates a list of not found counterparties.
//
&AtServer
Procedure ListOfNotFound(DocumentRow, BankAccount, CounterpartyTable)
	
	IsFoundCounterparty = TypeOf(DocumentRow.Counterparty) <> Type("String");
	IsFoundAccount       = TypeOf(DocumentRow.CounterpartyAccount) <> Type("String");
	
	CounterpartyType = ?(DocumentRow.PayerAccount = BankAccount.AccountNo, "RECIPIENT", "Payer");
	
	If ValueIsFilled(DocumentRow[CounterpartyType + "TIN"]) Then
		FoundRecordAboutCounterparty = FindTreeItem(CounterpartyTable.GetItems(), "Value", DocumentRow[CounterpartyType + "TIN"]);
	Else
		End = ?(DocumentRow[CounterpartyType + "1"] = "", "", "1");
		FoundRecordAboutCounterparty = FindTreeItem(CounterpartyTable.GetItems(), "Value", DocumentRow[CounterpartyType + End]);
	EndIf;
	
	// Counterparty
	If FoundRecordAboutCounterparty = Undefined Then
		
		NewCounterparty = CounterpartyTable.GetItems().Add();
		
		End = ?(DocumentRow[CounterpartyType + "1"] = "", "", "1");
		
		NewCounterparty.Presentation = DocumentRow[CounterpartyType + End];
		NewCounterparty.RowNum     = DocumentRow.LineNumber;
		NewCounterparty.Import     = True;
		NewCounterparty.IsCounterparty = True;
		
		AddNewAttributeDescription("Description", End, CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		AddNewAttributeDescription("TIN"		  , "TIN"	 , CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		AddNewAttributeDescription("KPP"		  , "KPP"	 , CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		
		If IsFoundCounterparty Then
			NewCounterparty.Attribute = DocumentRow.Counterparty;
		EndIf;
		
	Else
		
		NewCounterparty = FoundRecordAboutCounterparty.GetParent();
		
		If NewCounterparty = Undefined Then
			NewCounterparty = FoundRecordAboutCounterparty;
		EndIf;
		
	EndIf;
	
	FoundStrings = FindTreeItem(NewCounterparty.GetItems(), "Value", DocumentRow[CounterpartyType + "account"]);
	
	If Not IsFoundAccount AND FoundStrings = Undefined Then
		
		AttributesOfNewCounterparty = AddNewAttributeDescription("R/account", "account", CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		
		DirectSettlements = IsBlankString(DocumentRow[CounterpartyType + "2"]);
		
		If DirectSettlements Then
			
			AddNewAttributeDescription("Bank",            "BANK1",   CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("City of bank",    "BANK2",   CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			//( elmi #17 (112-00003) 
			//AddNewAttributeDescription("Bank code",     "BIN",     CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Bank code",       "BIC",     CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			//) elmi
			AddNewAttributeDescription("Corr. bank account", "BALANCEDACCOUNT", CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			
		Else
			
			AddNewAttributeDescription("Bank",                     "3",        CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("City of bank",              "4",        CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Corr. bank account",          "BANKACC", CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Bank's processing center",                 "BANK1",    CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Location of bank processing center", "BANK2",    CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Code of bank processing center",             "BIN",      CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Corr. account of bank processing center",       "BALANCEDACCOUNT",  CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotFoundList()

// Procedure fills the documents to be imported.
//
&AtServer
Function FillDocumentsForImport(ImportTextForParsing)
	
	CounterpartyTable.GetItems().Clear();
	
	// We prepare the data processing structures.
	DocumentsForImport = Object.Import.Unload();
	ImportExportable = GenerateMapOfItemsBeingImported();
	ImportIsNotEmpty = Undefined;
	ImportBlankPaymentOrder = Undefined;
	ImportBlankPaymentOrderBudget = Undefined;
	
	BankAccountsToImport = Object.ImportBankAccounts.Unload();
	
	GenerateMapsOFNotEmptyItemsOnImport(
		ImportIsNotEmpty,
		ImportBlankPaymentOrder,
		ImportBlankPaymentOrderBudget
	);
	SettlementsAccountsTags = CreateMapFromString(
		Upper("StartDate,EndDate,BankAcc,OpeningBalance,DebitedTotal,CreditedTotal,ClosingBalance,ENDBANKACC")
	);
	TagsHeader = CreateMapFromString(
		Upper("FormatVersion,Encoding,Sender,Recipient,CreationDate,CreationTime,StartDate,EndDate")
	);
	StructureTitle = New Structure(
		Upper("FormatVersion,Encoding,Sender,Recipient,CreationDate,CreationTime,StartDate,EndDate")
	);
	ImportTitle = StructureTitle;
	ImportExchangeSign = False;
	IsFoundEndFile = False;
	ImportDocumentsKinds = New Array;
	BankAccountsToImport.Clear();
	DocumentsForImport.Clear();
	
	// We fill the primary data structure.
	ImportLineCount = StrLineCount(ImportTextForParsing);
	ImportCurrentRow = 1;
	While ImportCurrentRow <= ImportLineCount Do
		Str = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
		
		// SECTIONDOCUMENT.
		If Left(Upper(TrimAll(Str)), 14) = "SectionDocument" Then
			Value = "";
			Tag = "";
			ParseTagString(Str, Tag, Value);
			If Tag = "SectionDocument" Then
				DocumentsNewRow = DocumentsForImport.Add();
				DocumentsNewRow.Operation = Value;
				If Not ImportDocumentSection(DocumentsNewRow, ImportCurrentRow, ImportLineCount, ImportTextForParsing, ImportExportable) Then
					Return "";
				EndIf;
			Else
				MessageText = NStr("en = 'Broken structure of import file, string %Import%: %Str%'");
				MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
				MessageText = StrReplace(MessageText, "%Str%", Str);
				Return MessageText;
			EndIf;
		
		// SECTIONBANKACC.
		ElsIf Left(Upper(TrimAll(Str)), 14) = "SECTIONBANKACC" Then
			
			StringBAAccounts = BankAccountsToImport.Add();
			If Not ImportBankAccSection(StringBAAccounts, ImportCurrentRow, ImportLineCount, ImportTextForParsing, SettlementsAccountsTags) Then
				MessageText = NStr("en = 'Import file structure is broken in the current account description section! String: %Import%'");
				MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
				Return MessageText;
			EndIf;
			If Object.BankAccount.AccountNo <> StringBAAccounts.BankAcc Then
				BankAccountsToImport.Delete(StringBAAccounts);
			EndIf;
			
		// BankAcc.
		ElsIf Left(Upper(TrimAll(Str)), 8) = "BANKACC" Then
			
			Value = "";
			Tag = "";
			ParseTagString(Str, Tag, Value);
			
			If Tag = "BANKACC" Then
				Query = New Query;
				Query.Text =
				"SELECT
				|	BankAccounts.Ref,
				|	BankAccounts.Owner
				|FROM
				|	Catalog.BankAccounts AS BankAccounts
				|WHERE
				|	VALUETYPE(BankAccounts.Owner) = Type(Catalog.Companies)
				|	AND BankAccounts.AccountNo = &AccountNo
				|	AND Not BankAccounts.DeletionMark";
				Query.SetParameter("AccountNo", Value);
				Selection = Query.Execute().Select();
				If Selection.Next() Then
					FoundBankAccount = Selection.Ref;
					If ValueIsFilled(Object.BankAccount)
					   AND FoundBankAccount <> Object.BankAccount Then
						If Object.BankAccount.AccountNo = Value Then
							MessageText = NStr("en = 'The account in the file title (%Value%) is different from the specified one!'");
						Else
							MessageText = NStr("en = 'There are several bank accounts of companies with the same number!'");
						EndIf;
						MessageText = StrReplace(MessageText, "%Value%", Value);
						Return MessageText;
					Else
						Object.Company = Selection.Owner;
						Object.BankAccount = FoundBankAccount;
						ThisForm.Title = "Importing account statements: " + FoundBankAccount.Description;
					EndIf;
					StringBAAccounts = BankAccountsToImport.Find(Value, "BankAcc");
					If StringBAAccounts = Undefined Then
						StringBAAccounts = BankAccountsToImport.Add();
						StringBAAccounts.BankAcc = Value;
					EndIf;
				Else
					MessageText = NStr("en = 'In the file title there is an account that does not belong to the Company: %Value%!'");
					MessageText = StrReplace(MessageText, "%Value%", Value);
					Return MessageText;
				EndIf;
			EndIf;
		
		// DOCUMENT.
		ElsIf Left(Upper(TrimAll(Str)), 8) = "DOCUMENT" Then
			ImportDocumentsKinds.Add(Value);
		
		// ENDFILE.
		ElsIf Left(Upper(TrimAll(Str)), 10) = "EndFile" Then
			If Not ImportExchangeSign Then
				MessageText = NStr("en = '""1CClientBankExchange"" is missing in the file of import!'");
				Return MessageText;
			EndIf;
			
			IsFoundEndFile = True;
			LineNumber = 0;
			
			// We sequentially process each imported string.
			For Each DocumentRow IN DocumentsForImport Do
				
				// We recognize attributes.
				// If in the file there are statements of payment documents of several
				// accounts, then we recognize and display only those that
				// were exported according to the specified bank account.
				If DocumentRow.PayerAccount = Object.BankAccount.AccountNo
				 OR DocumentRow.PayeeAccount = Object.BankAccount.AccountNo Then
					RecognizeDataInDocumentRow(DocumentRow);
					LineNumber = LineNumber + 1;
					DocumentRow.LineNumber = LineNumber;
					
					// Each attribute (= column) should be checked for empty value.
					For Each LoadColumn IN DocumentsForImport.Columns Do
						CheckForBlankImportValue(
							DocumentRow,
							LoadColumn.Name,
							LoadColumn.Title,
							ImportIsNotEmpty
						);
					EndDo;
					
					If TypeOf(DocumentRow.Counterparty) = Type("String")
					 OR TypeOf(DocumentRow.CounterpartyAccount) = Type("String") Then
						
						// We add attributes in tabular section for further use.
						ListOfNotFound(DocumentRow, Object.BankAccount, CounterpartyTable);
						
					EndIf;
					
				Else
					
					// We mark other items for further deletion.
					DocumentRow.LineNumber = 0;
					
				EndIf;
			EndDo;
			
			// We delete unnecessary rows from a table.
			Quantity = DocumentsForImport.Count() - 1;
			For Ct = 0 to Quantity Do
				If DocumentsForImport[Quantity - Ct].LineNumber = 0 Then
					DocumentsForImport.Delete(Quantity - Ct);
				EndIf;
			EndDo;
		
		// 1CCLIENTBANKEXCHANGE.
		ElsIf Left(Upper(TrimAll(Str)), 20) = "1CCLIENTBANKEXCHANGE" Then
			ImportExchangeSign = True;
		Else
			ImportHeaderString(
				Str,
				TagsHeader,
				ImportTitle,
				ImportCurrentRow
			);
		EndIf;
		
	EndDo;
	
	If Not IsFoundEndFile Then
		BankAccountsToImport.Clear();
		DocumentsForImport.Clear();
		MessageText = NStr("en = 'Invalid file format (EndFile section not found)!'");
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
	EndIf;
	
	For Each DocumentRow IN DocumentsForImport Do
		DocumentRow.Import = IsBlankString(DocumentRow.ErrorsDescriptionFull);
		DocumentRow.PaymentDestination = TrimAll(DocumentRow.PaymentDestination);
		DocumentRow.PictureNumber = ?(IsBlankString(DocumentRow.ErrorsDescriptionFull), 0, 1);
		DocumentRow.AdvanceFlag = True;
		FillAmountsAllocatedAtServer(DocumentRow);
	EndDo;
	
	Object.Import.Clear();
	Object.Import.Load(DocumentsForImport);
	
	Object.ImportBankAccounts.Clear();
	Object.ImportBankAccounts.Load(BankAccountsToImport);
	
	Return "";
	
EndFunction // FillDocumentsForImport()

// Function reads file.
//
&AtClient
Function ReadFile(PathToFileFromSetting)
	
	File = TrimAll(PathToFileFromSetting);
	
	If Object.Encoding = "DOS" Then
		Codin = TextEncoding.OEM;
	Else
		Codin = TextEncoding.ANSI;
	EndIf;
	
	Try
		ReadStream.Read(File, Codin);
	Except
		MessageText = NStr("en = 'An error occurred while reading file %File%.'");
		MessageText = StrReplace(MessageText, "%File%", File);
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
		Return Undefined;
	EndTry;
	
	If ReadStream.LineCount() < 1 Then
		MessageText = NStr("en = 'There is no data in the file!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
		Return Undefined;
	EndIf;
	
	If TrimAll(ReadStream.GetLine(1)) <> "1CClientBankExchange" Then
		MessageText = NStr("en = 'Specified file is not file of exchange or specified code is incorrect!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
		Return Undefined;
	EndIf;
	
	Return ReadStream.GetText();
	
EndFunction // ReadFile()

// Function reads an electronic bank statement and returns its contents in text format.
//
&AtServer
Function ReadElectronicBankStatementAtServer(AlertStack)
	
	FileURL = Undefined; // Temporary storage address
	BankAccounts = New Array;
	LocalCompany = Undefined;
	ElectronicDocumentsServiceCallServer.GetStatementData(BankElectronicStatement, FileURL, BankAccounts, LocalCompany);
	
	If FileURL = Undefined Then
		Return Undefined;
	EndIf;
	
	If Not FileOperationsExtensionConnected Then
		MessageText = NStr("en = 'For statement reading the file work extension must be installed.'");
		AlertStack.Add(New Structure("Text", MessageText));
		Return Undefined;
	EndIf;
	
	If Object.Encoding = "DOS" Then
		Codin = TextEncoding.OEM;
	Else
		Codin = TextEncoding.ANSI;
	EndIf;
	
	TempFileName  = GetTempFileName("txt");
	FileBinaryData = GetFromTempStorage(FileURL);
	FileBinaryData.Write(TempFileName);
	Try
		ReadStream.Read(TempFileName, Codin);
	Except
		MessageText = NStr("en = 'File is not read.'");
		AlertStack.Add(New Structure("Text", MessageText));
		Return Undefined;
	EndTry;
	
	If ReadStream.LineCount() < 1 Then
		MessageText = NStr("en = 'There is no data in the file!'");
		AlertStack.Add(New Structure("Text", MessageText));
		Return Undefined;
	EndIf;
	
	If TrimAll(ReadStream.GetLine(1)) <> "1CClientBankExchange" Then
		MessageText = NStr("en = 'Specified file is not file of exchange or specified code is incorrect!'");
		AlertStack.Add(New Structure("Text", MessageText));
		Return Undefined;
	EndIf;
	
	Return ReadStream.GetText();

EndFunction // ReadElectronicBankStatement()

// Function reads data from a file.
//
&AtClient
Procedure ReadDataFromFile()
	
	//( elmi #17 (112-00003) 
	ExternalDataProcessorRefs = GetExternalDataProcessor(Object.BankAccount);  
	//) elmi
	
	If ValueIsFilled(DirectExchangeWithBanksAgreement) Then
		
		If Not ValueIsFilled(BankElectronicStatement) Then
			SmallBusinessClient.ShowMessageAboutError(ThisForm,
			NStr("en = 'For getting electronic bank statement click ""Request a statement""'")
			,, "BankElectronicStatement");
			Return;
		EndIf;
		
		If ValueIsFilled(BankElectronicStatement) Then
			
			AlertStack = New Array;
			ImportTextForParsing = ReadElectronicBankStatementAtServer(AlertStack);
			
			For Each Message IN AlertStack Do
				SmallBusinessClient.ShowMessageAboutError(ThisForm, Message.Text);
			EndDo;
			
		EndIf;
		
	//( elmi #17 (112-00003) 
	ElsIf  ValueIsFilled(ExternalDataProcessorRefs) Then
		
		ParametersOfDataProcessor = New Structure("CommandID, AdditionalInformationProcessorRef, ArrayOfPurposes, PathToFile, ExecutionResult"); 
		ParametersOfDataProcessor.CommandID                           = "ImportFromClientBankExternalDP";
		ParametersOfDataProcessor.AdditionalInformationProcessorRef   = ExternalDataProcessorRefs;
		ParametersOfDataProcessor.ArrayOfPurposes                     = Object.BankAccount;
		ParametersOfDataProcessor.PathToFile                          = Object.ImportFile;
		ParametersOfDataProcessor.ExecutionResult                     = New Structure("ImportStream, WarningText, ListOfNotFound" );
		
		RunCommandOnServer( ParametersOfDataProcessor);
		
		Result = ParametersOfDataProcessor.ExecutionResult;
		
		If Result <> Undefined Then
			If Result.Property("WarningText") Then
				If ValueIsFilled(Result.WarningText) Then
					WarningText = Result.WarningText;
				EndIf;	   
			EndIf;	
			If Result.Property("ImportStream") AND Result.Property("ListOfNotFound") Then 
				FillTableFromExternalDataProcessor( Result.ImportStream, Result.ListOfNotFound );
				Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
			Else		
				WarningText = НСтр("en='The file of downloading contains no data!'");
			EndIf;	
			
		Else	  
			WarningText = НСтр("en='The file of downloading contains no data!'");
		EndIf;
	//) elmi
		
	Else
		
		// We get source data.
		ImportTextForParsing = ReadFile(Object.ImportFile);
		
		
		If ImportTextForParsing = Undefined Then
			MessageText = NStr("en = 'Import file does not contain data!'");
			SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
			Return;
		EndIf;
		
		WarningText = FillDocumentsForImport(ImportTextForParsing);
		
	EndIf;
	
	//If ImportTextForParsing = Undefined Then
	//	MessageText = NStr("en = 'Import file does not contain data!'");
	//	SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
	//	Return;
	//EndIf;
	//WarningText = FillDocumentsForImport(ImportTextForParsing);
	
	//) elmi
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(Undefined,WarningText);
	EndIf;
	
EndProcedure // ReadDataFromFile()

&AtServer
Procedure FormManagementOnServer()

	DirectExchangeWithBanks = ValueIsFilled(DirectExchangeWithBanksAgreement);
	
	Items.ImportRefresh.Visible = Not DirectExchangeWithBanks;
	Items.ImportCheckAll.Visible = Not DirectExchangeWithBanks;
	Items.ImportUnmarkAll.Visible = Not DirectExchangeWithBanks;
	Items.ImportUpdate1.Visible = DirectExchangeWithBanks;
	Items.ImportCancelAll1.Visible = DirectExchangeWithBanks;
	Items.ImportUnmarkAtAll1.Visible = DirectExchangeWithBanks;
	
	Items.QueryStatementGroup.Visible = DirectExchangeWithBanks;
	Items.BankElectronicStatement.Visible = DirectExchangeWithBanks;
	Items.StatementImportDescriptionGroupThroughED.Visible = DirectExchangeWithBanks;

EndProcedure // FormManagementOnServer()

&AtClient
Function PeriodFilledWith()
	
	PeriodFilledWith = True;
	
	If Not ValueIsFilled(Object.StartPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Start period date is not filled'")
			,, "Object.StartPeriod");
		PeriodFilledWith = False;
	EndIf;
	
	If Not ValueIsFilled(Object.EndPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'End period date is not filled'")
			,, "Object.EndPeriod");
		PeriodFilledWith = False;
	EndIf;
	
	Return PeriodFilledWith;
	
EndFunction

&AtServerNoContext
Function GetAccountNo(BankAccount)
	
	If ValueIsFilled(BankAccount) Then
		Return CommonUse.GetAttributeValue(BankAccount, "AccountNo");
	EndIf;
	
	Return "";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	If Parameters.Property("Company") Then
		Object.Company = Parameters.Company;
	EndIf;
	
	If Parameters.Property("BankAccountOfTheCompany")
		AND ValueIsFilled(Parameters.BankAccountOfTheCompany) Then
		Object.BankAccount = Parameters.BankAccountOfTheCompany;
		ThisForm.Title = "Importing account statements: " + Parameters.BankAccountOfTheCompany.Description;
	EndIf;
	
	If Parameters.Property("PathToFile") Then
		Object.ImportFile = Parameters.PathToFile;
	EndIf;
	
	If Parameters.Property("CFItemIncoming") Then
		Object.CFItemIncoming = Parameters.CFItemIncoming;
	EndIf;
	
	If Parameters.Property("CFItemOutgoing") Then
		Object.CFItemOutgoing = Parameters.CFItemOutgoing;
	EndIf;
	
	If Parameters.Property("PostImported") Then
		Object.PostImported = Parameters.PostImported;
	EndIf;
	
	If Parameters.Property("FillDebtsAutomatically") Then
		Object.FillDebtsAutomatically = Parameters.FillDebtsAutomatically;
	EndIf;
	
	If Parameters.Property("Application") Then
		Object.Application = Parameters.Application;
	EndIf;
	
	If Not ValueIsFilled(Object.StartPeriod) Then
		Object.StartPeriod = CurrentDate();
	EndIf;
	
	If Not ValueIsFilled(Object.EndPeriod) Then
		Object.EndPeriod = CurrentDate();
	EndIf;
	
	If Parameters.Property("Encoding") Then
		Object.Encoding = Parameters.Encoding;
	EndIf;
	
	If Not ValueIsFilled(Object.Encoding) Then
		Object.Encoding = "Windows";
	EndIf;
	
	If Parameters.Property("FormatVersion") Then
		Object.FormatVersion = Parameters.FormatVersion;
	EndIf;
	
	If Not ValueIsFilled(Object.FormatVersion) Then
		Object.FormatVersion = "1.02";
	EndIf;
	
	If Not ValueIsFilled(Object.CFItemIncoming) Then
		Object.CFItemIncoming = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	If Not ValueIsFilled(Object.CFItemOutgoing) Then
		Object.CFItemOutgoing = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	
	If Parameters.Property("AddressOfFileForProcessing") Then
		ImportFile = GetFromTempStorage(Parameters.AddressOfFileForProcessing);
		If TypeOf(ImportFile) = Type("BinaryData") Then
			Try
				TempFileName = GetTempFileName("txt");
				ImportFile.Write(TempFileName);
				TextDocument = New TextDocument();
				TextDocument.Read(TempFileName);
				ImportFile = TextDocument.GetText();
				DeleteFiles(TempFileName);
			Except
				WriteLogEvent(NStr("en = 'Exchange with bank. Temporary file'"), 
				EventLogLevel.Error,
				,
				,
				StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'The temporary file saving to the disk is failed by reason: %1'"),
				ErrorDescription()));
				Return;
			EndTry;
		EndIf;
		ImportFile = StrReplace(StrReplace(ImportFile, "e","e"), "E", "E");
		ReadStream.SetText(ImportFile);
		
		//( elmi #17 (112-00003) 
		//WarningText = FillDocumentsForImport(ImportFile);
		
		ExternalDataProcessorRefs = Object.BankAccount.ExternalDataProcessor;  
		
		If  ValueIsFilled(ExternalDataProcessorRefs) Then
			
			ParametersOfDataProcessor = New Structure("CommandID, AdditionalInformationProcessorRef, ArrayOfPurposes, PathToFile, ExecutionResult"); 
			ParametersOfDataProcessor.CommandID                           = "ImportFromClientBankExternalDP";
			ParametersOfDataProcessor.AdditionalInformationProcessorRef   = ExternalDataProcessorRefs;
			ParametersOfDataProcessor.ArrayOfPurposes                     = Object.BankAccount;
			ParametersOfDataProcessor.PathToFile                          = Object.ImportFile;
			ParametersOfDataProcessor.ExecutionResult                     = New Structure("ImportStream, WarningText, ListOfNotFound" );
			
			RunCommandOnServer( ParametersOfDataProcessor);
			
			Result = ParametersOfDataProcessor.ExecutionResult;
			
			If Result <> Undefined Then
				If Result.Property("WarningText") Then
					If ValueIsFilled(Result.WarningText) Then
						WarningText = Result.WarningText;
					EndIf;	   
				EndIf;	
				If Result.Property("ImportStream") AND Result.Property("ListOfNotFound") Then 
					FillTableFromExternalDataProcessor( Result.ImportStream, Result.ListOfNotFound );
					Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
				Else		
					WarningText = НСтр("en='The file of downloading contains no data!'");
				EndIf;	
				
			Else	  
				WarningText = НСтр("en='The file of downloading contains no data!'");
			EndIf;
			
			
		Else	 
			WarningText = FillDocumentsForImport(ImportFile);
		EndIf;	 
		//) elmi	 
		
		Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
		
	EndIf;
	
	If Parameters.Property("DirectExchangeWithBanksAgreement") Then
		DirectExchangeWithBanksAgreement = Parameters.DirectExchangeWithBanksAgreement;
		If ValueIsFilled(DirectExchangeWithBanksAgreement) Then
			TemplateText = NStr("en = 'The direct exchange agreement is effectife from %1: bank statement will be imported to 1C:Small Business directly from the bank'");
			LabelText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateText, CommonUse.GetAttributeValue(DirectExchangeWithBanksAgreement, "Counterparty"));
			DirectMessageExchange = LabelText;
		EndIf;
	EndIf;
	
	If Parameters.Property("BankElectronicStatement") Then
		BankElectronicStatement = Parameters.BankElectronicStatement;
	EndIf;
	
	FormManagementOnServer();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(Undefined,WarningText);
		Cancel = True;
	EndIf;
	
	ValidTypes = New TypeDescription("CatalogRef.Counterparties", ,);
	Items.ImportCounterparty.TypeRestriction = ValidTypes;
	
	ValidTypes = New TypeDescription("CatalogRef.CounterpartyContracts", ,);
	Items.ImportContract.TypeRestriction = ValidTypes;
	
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, New Structure("FormAttribute", "ImportFile"));
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure // OnOpen()

&AtClient
Procedure BeginEnableExtensionFileOperationsEnd(Attached, AdditionalParameters) Export
	
	ThisForm.FileOperationsExtensionConnected = Attached;
	If ThisForm.FileOperationsExtensionConnected Then
		If Not ValueIsFilled(Object.ImportFile) Then
			Object.ImportFile = "c:\kl_to_1c.txt";
		EndIf;
	Else
		Object.ImportFile = "";
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - The ImportCheckAll command handler.
//
&AtClient
Procedure ImportCancelAllExecute(Command)
	
	SetFlags(Object.Import, "Import", True, True);
	
EndProcedure // ImportCancelExecuteAll()

// Procedure - The ImportUnmarkAll command handler.
//
&AtClient
Procedure ImportUncheckAllExecute(Command)
	
	SetFlags(Object.Import, "Import", False, True);
	
EndProcedure // ImportUnmarkAllExecute()

// Procedure - The NotFoundAttributesImportMarkAll command handler.
//
&AtClient
Procedure NotFoundAttributesImportingMarkAll(Command)
	
	SetFlags(CounterpartyTable.GetItems(), "Import", True, False);
	
EndProcedure // NotFoundAttributesImportMarkAll()

// Procedure - The NotFoundUnmarkAllAttributes command handler.
//
&AtClient
Procedure NotFoundsUnmarkAllAttributes(Command)
	
	SetFlags(CounterpartyTable.GetItems(), "Import", False, False);
	
EndProcedure // NotFoundUnmarkAllAttributes()

// Procedure - The ImportRefresh command handler.
//
&AtClient
Procedure ImportUpdateExecute(Command)
	
	If Not CheckFillOfFormAttributes() Then
		
		Return;
		
	EndIf;
	
	ReadDataFromFile();
	Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
	
EndProcedure // ImportUpdateExecute()

// Procedure - Import command handler.
//
&AtClient
Procedure ImportExecute(Command)
	
	ClearMessages();
	
	If Not CheckFillOfFormAttributes() Then
		
		Return;
		
	EndIf;
	
	If Object.Import.Count() > 0 Then
		
		DataLoadFromFile();
		
		If FileOperationsExtensionConnected Then
			
			 //( elmi #17 (112-00003)   
			 ExternalDataProcessorRefs = GetExternalDataProcessor(Object.BankAccount);  
			 If  ValueIsFilled(ExternalDataProcessorRefs) Then
				 // table part  ImportBankAccounts isn't fill  till
			 Else	 
				 WarningText = FillDocumentsForImport(ReadStream.GetText()); // Table refresh.
				 If ValueIsFilled(WarningText) Then
					 ShowMessageBox(Undefined,WarningText);
				 EndIf;
			 EndIf;	 
			//) elmi
			
		EndIf;
		
		ShowMessageBox(Undefined,NStr("en = 'Importing of the payment documents has been completed'"));
		
	Else
		
		ShowMessageBox(Undefined,NStr("en = 'List of documents for loadings empty'"));
		
	EndIf;
	
EndProcedure // ImportExecute()

// Procedure - The CreateCounterparties command handler.
//
&AtClient
Procedure CreateCounterparties(Command)
	
	CreateNewCounterparty();
	
	ReadDataFromFile();
	
	Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
	
EndProcedure // CreateCounterparties()

&AtClient
Procedure RequestElectronicBankStatement(Command)
	
	If Not ValueIsFilled(DirectExchangeWithBanksAgreement) OR Not PeriodFilledWith() Then
		Return;
	EndIf;
	
	ElectronicDocumentsClient.GetBankStatement(
		DirectExchangeWithBanksAgreement, Object.StartPeriod, Object.EndPeriod, ThisObject, GetAccountNo(Object.BankAccount));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

&AtClient
Procedure BankElectronicStatementClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure("Key", BankElectronicStatement);
	OpenForm("Catalog.EDAttachedFiles.Form.EDViewForm", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

// Procedure - The Selection event handler of the Import tabular section.
//
&AtClient
Procedure ImportSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ImportExport" Then
		StandardProcessing = False;
		Items.ImportTable.CurrentData.Import = Not (Items.ImportTable.CurrentData.Import);
	ElsIf Field.Name = "ImportPictureNumber" Then 
		StandardProcessing = False;
		If ValueIsFilled(Items.ImportTable.CurrentData.ErrorsDescriptionFull) Then
			ShowMessageBox(Undefined,Items.ImportTable.CurrentData.ErrorsDescriptionFull);
		Else
			ShowMessageBox(Undefined,NStr("en = 'Document is ready for import!'"));
		EndIf;
	ElsIf Field.Name = "ImportPaymentDestination" Then
		StandardProcessing = False;
		ShowMessageBox(Undefined,Items.ImportTable.CurrentData.PaymentDestination);
	ElsIf ValueIsFilled(Items.ImportTable.CurrentData.Document)
		AND (Field.Name = "ImportDocumentName"
		OR Field.Name = "ImportDocDate"
		OR Field.Name = "ImportDocNumber"
		OR Field.Name = "ImportDocumentSum"
		OR Field.Name = "ImportAmountDebited"
		OR Field.Name = "ImportAmountWrittenOff") Then
		OpenForm("Document." + Items.ImportTable.CurrentData.DocumentKind + ".ObjectForm",
			New Structure("Key", Items.ImportTable.CurrentData.Document),
			Items.ImportTable.CurrentData.Document
		);
	EndIf;
	
EndProcedure // ImportSelection()

// Procedure creates a new counterparty.
//
&AtServer
Procedure CreateNewCounterparty()
	
	For Each Item IN CounterpartyTable.GetItems() Do
		
		If Item.Import Then
			FormAttributeToValue("Object").CreateCounterparty(Item).IsEmpty();
		EndIf;
		
	EndDo;
	
EndProcedure // CreateNewCounterparty()

// Procedure - The StartChoice event handler for the Order field of the Import list.
//
&AtClient
Procedure ImportOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRowOfTabularSection = Items.ImportTable.CurrentData;
	If TypeOf(CurrentRowOfTabularSection.Counterparty) = Type("String") Then
		
		StandardProcessing	= False;
		
		MessageText			= NStr("en = 'The counterparty has not been identified, the order selection is impossible.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure //ImportOrderStartChoice()

// Procedure - the OnChange event handler of the Import list.
//
&AtClient
Procedure ImportExportOnChange(Item)
	
	CurRow = Items.ImportTable.CurrentData;
	FillAmount76AtClient(CurRow)
	
EndProcedure // ImportingImportOnChange()

// Filling the amount of marked items.
//
&AtClient
Procedure FillAmount76AtClient(CurRow)
	
	CurRow.AmountReceiptAllocated = ?(CurRow.Import, CurRow.AmountDebited, 0);
	CurRow.AmountWriteOffAllocated = ?(CurRow.Import, CurRow.AmountCredited, 0);
	CurRow.DocumentAmountAllocated = ?(CurRow.Import, CurRow.DocumentAmount, 0);
	
EndProcedure

// Filling the amount of marked items.
//
&AtServer
Procedure FillAmountsAllocatedAtServer(CurRow)
	
	CurRow.AmountReceiptAllocated = ?(CurRow.Import, CurRow.AmountDebited, 0);
	CurRow.AmountWriteOffAllocated = ?(CurRow.Import, CurRow.AmountCredited, 0);
	CurRow.DocumentAmountAllocated = ?(CurRow.Import, CurRow.DocumentAmount, 0);
	
EndProcedure

// Procedure - the Setting command handler.
//
&AtClient
Procedure Setting(Command)
	
	OpenForm("DataProcessor.ClientBank.Form.FormSetting",
		New Structure(
			"Script, FormatVersion, Application, PostImported, FillDebtsAutomatically, DirectExchangeWithBanksAgreement, UUID",
			Object.Encoding, Object.FormatVersion, Object.Application, Object.PostImported, Object.FillDebtsAutomatically, DirectExchangeWithBanksAgreement, UUID
		)
	);
	
EndProcedure // Setting()

// Procedure - form alert processing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingsChange" + UUID Then
		Object.Encoding = Parameter.Encoding;
		Object.Application = Parameter.Application;
		Object.FormatVersion = Parameter.FormatVersion;
		Object.PostImported = Parameter.PostImported;
		Object.FillDebtsAutomatically = Parameter.FillDebtsAutomatically;
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.EDAttachedFiles")
		AND ValueIsFilled(DirectMessageExchange) Then
		BankElectronicStatement = ValueSelected;
		If ValueIsFilled(BankElectronicStatement) Then
			ReadDataFromFile();
			Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
		EndIf;
	EndIf;
	
EndProcedure


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


//( elmi #17 (112-00003) 
&AtServer
Function FillTableFromExternalDataProcessor(ImportStream, ListOfNotFound );

Object.Import.Clear();

For Each String IN ImportStream Do
    NewString = Object.Import.Add();
    FillPropertyValues(NewString, String);
EndDo;

Elements = CounterpartyTable.GetItems(); 
Elements.Clear();

For Each String IN ListOfNotFound Do
	ListOfNotFound(String, Object.BankAccount, CounterpartyTable);
КонецЦикла;

FormAttributeToValue("Object");

Return "";

EndFunction
//) elmi

//( elmi #17 (112-00003) 
&AtServer
Function  GetExternalDataProcessor(Account)
	
	    Return Account.ExternalDataProcessor;
	     
EndFunction
//) elmi

//( elmi #17 (112-00003)	
&AtServer
Procedure RunCommandOnServer(ParametersDataProcessors) Export
	
AdditionalReportsAndDataProcessors.RunCommand( ParametersDataProcessors );
	
EndProcedure	
//) elmi
