#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Import

// Function checks the document for import.
//
Function CheckDocumentForImport(DocumentStructure)
	
	Result = "";
	
	If DocumentStructure.Readiness > 3 Then
		Result = DocumentStructure.ErrorsDescriptionFull;
	EndIf;
	
	Return Result;
	
EndFunction // CheckDocumentForImport()

// Procedure sets a property.
//
Procedure SetProperty(Object, PropertyName, PropertyValue, RequiredReplacementOfOldValues = False, IsNewDocument)
	
	If PropertyValue <> Undefined
	   AND Object[PropertyName] <> PropertyValue Then
		If IsNewDocument
		 OR (NOT ValueIsFilled(Object[PropertyName])
		 OR RequiredReplacementOfOldValues)
		 OR TypeOf(Object[PropertyName]) = Type("Boolean")
		 OR TypeOf(Object[PropertyName]) = Type("Date") Then
			Object[PropertyName] = PropertyValue;
		EndIf
	EndIf;
	
EndProcedure // SetProperty()

// Procedure calculates the rate and amount of document.
//
Procedure CalculateRateAndAmountOfAccounts(StringPayment, SettlementsCurrency, ExchangeRateDate, ObjectOfDocument, IsNewDocument)
	
	StructureRateCalculations = GetCurrencyRate(SettlementsCurrency, ExchangeRateDate);
	StructureRateCalculations.ExchangeRate = ?(StructureRateCalculations.ExchangeRate = 0, 1, StructureRateCalculations.ExchangeRate);
	StructureRateCalculations.Multiplicity = ?(StructureRateCalculations.Multiplicity = 0, 1, StructureRateCalculations.Multiplicity);
	
	SetProperty(
		StringPayment,
		"ExchangeRate",
		StructureRateCalculations.ExchangeRate,
		,
		IsNewDocument
	);
	SetProperty(
		StringPayment,
		"Multiplicity",
		StructureRateCalculations.Multiplicity,
		,
		IsNewDocument
	);
	DocumentRateStructure = GetCurrencyRate(ObjectOfDocument.CashCurrency, ExchangeRateDate);
	
	SettlementsAmount = RecalculateFromCurrencyToCurrency(
		StringPayment.PaymentAmount,
		DocumentRateStructure.ExchangeRate,
		StructureRateCalculations.ExchangeRate,
		DocumentRateStructure.Multiplicity,
		StructureRateCalculations.Multiplicity
	);
	
	SetProperty(
		StringPayment,
		"SettlementsAmount",
		SettlementsAmount,
		True,
		IsNewDocument
	);
	
EndProcedure // CalculateSettlementsRateAndAmount()

// Function gets the object presentation.
//
Function GetObjectPresentation(Object)
	
	If TypeOf(Object) = Type("DocumentObject.PaymentReceipt") Then
		NameObject = NStr("en='The ""Payment receipt"" document # %Number% dated %Date%';ru='документ ""Расход со счета"" № %Номер% от %Дата%'"
		);
		NameObject = StrReplace(NameObject, "%Number%", String(TrimAll(Object.Number)));
		NameObject = StrReplace(NameObject, "%Date%", String(Object.Date));
	ElsIf TypeOf(Object) = Type("DocumentObject.PaymentExpense") Then
		NameObject = NStr("en='The ""Payment expense"" document # %Number% dated %Date%';ru='документ ""Поступление на счет"" № %Номер% от %Дата%'"
		);
		NameObject = StrReplace(NameObject, "%Number%", String(TrimAll(Object.Number)));
		NameObject = StrReplace(NameObject, "%Date%", String(Object.Date));
	Else
		NameObject = NStr("en='object';ru='объект'");
	EndIf;
	
	Return NameObject;
	
EndFunction // GetObjectPresentation()

// Procedure fills the PaymentExpense document attributes.
//
Procedure FillAttributesPaymentExpense(ObjectOfDocument, SourceData, IsNewDocument)
	
	// Filling out a document header.
	SetProperty(
		ObjectOfDocument,
		"Date",
		SourceData.DocDate,
		,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"OperationKind",
		SourceData.OperationKind,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"Company",
		Company,
		,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"BankAccount",
		SourceData.BankAccount,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"CashCurrency",
		SourceData.BankAccount.CashCurrency,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"Item",
		SourceData.CFItem,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"DocumentAmount",
		SourceData.DocumentAmount,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"IncomingDocumentNumber",
		SourceData.DocNo,
		,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"IncomingDocumentDate",
		SourceData.DocDate,
		,
		IsNewDocument
	);
	
	If IsNewDocument Then
		ObjectOfDocument.SetNewNumber();
		If SourceData.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer Then
			ObjectOfDocument.VATTaxation = SmallBusinessServer.VATTaxation(Company, , SourceData.DocDate);
		Else
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		EndIf;
	EndIf;
	
	// Filling document tabular section.
	If SourceData.OperationKind = Enums.OperationKindsPaymentExpense.Vendor
	 OR SourceData.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer Then
		
		If TypeOf(SourceData.CounterpartyAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyAccount,
				,
				IsNewDocument
			);
		EndIf;
			
		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			,
			IsNewDocument
		);
		
		If ObjectOfDocument.PaymentDetails.Count() = 0 Then
			RowOfDetails = ObjectOfDocument.PaymentDetails.Add();
		Else
			RowOfDetails = ObjectOfDocument.PaymentDetails[0];
		EndIf;
		
		OneRowInDecipheringPayment = ObjectOfDocument.PaymentDetails.Count() = 1;
		
		SetProperty(
			RowOfDetails,
			"Contract",
			?(SourceData.Contract = "Not found", Undefined, SourceData.Contract),
			,
			IsNewDocument
		);
		
		SetProperty(
			RowOfDetails,
			"AdvanceFlag",
			SourceData.AdvanceFlag,
			True,
			IsNewDocument
		);
	
		If IsNewDocument
		 OR OneRowInDecipheringPayment
		   AND RowOfDetails.PaymentAmount <> ObjectOfDocument.DocumentAmount Then
		
			RowOfDetails.PaymentAmount = ObjectOfDocument.DocumentAmount;
			DateOfFilling = ObjectOfDocument.Date;
			SettlementsCurrency = RowOfDetails.Contract.SettlementsCurrency;
			
			CalculateRateAndAmountOfAccounts(
				RowOfDetails,
				SettlementsCurrency,
				DateOfFilling,
				ObjectOfDocument,
				IsNewDocument
			);
			
			If RowOfDetails.ExchangeRate = 0 Then
				
				SetProperty(
					RowOfDetails,
					"ExchangeRate",
					1,
					,
					IsNewDocument
				);
				
				SetProperty(
					RowOfDetails,
					"Multiplicity",
					1,
					,
					IsNewDocument
				);
				
				SetProperty(
					RowOfDetails,
					"SettlementsAmount",
					RowOfDetails.PaymentAmount,
					,
					IsNewDocument
				);
				
			EndIf;
			
			If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
				
				DefaultVATRate = ObjectOfDocument.Company.DefaultVATRate;
				VATRateValue = SmallBusinessReUse.GetVATRateValue(DefaultVATRate);
				
				RowOfDetails.VATRate = DefaultVATRate;
				RowOfDetails.VATAmount = RowOfDetails.PaymentAmount
					- (RowOfDetails.PaymentAmount)
					/ ((VATRateValue + 100) / 100);
				
			Else
				
				If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
					DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
				Else
					DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
				EndIf;
				
				RowOfDetails.VATRate = DefaultVATRate;
				RowOfDetails.VATAmount = 0;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillAttributesPaymentExpense()

// Procedure fills the PaymentReceipt document attributes.
//
Procedure FillAttributesPaymentReceipt(ObjectOfDocument, SourceData, IsNewDocument)
	
	SetProperty(
		ObjectOfDocument,
		"Date",
		SourceData.DocDate,
		,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"OperationKind",
		SourceData.OperationKind,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"Company",
		Company,
		,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"BankAccount",
		SourceData.BankAccount,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"CashCurrency",
		SourceData.BankAccount.CashCurrency,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"Item",
		SourceData.CFItem,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"DocumentAmount",
		SourceData.DocumentAmount,
		True,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"IncomingDocumentNumber",
		SourceData.DocNo,
		,
		IsNewDocument
	);
	
	SetProperty(
		ObjectOfDocument,
		"IncomingDocumentDate",
		SourceData.DocDate,
		,
		IsNewDocument
	);
	
	If IsNewDocument Then
		ObjectOfDocument.SetNewNumber();
		If ObjectOfDocument.OperationKind = Enums.OperationKindsPaymentReceipt.FromCustomer Then
			ObjectOfDocument.VATTaxation = SmallBusinessServer.VATTaxation(Company, , SourceData.DocDate);
		Else
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		EndIf;
	EndIf;
	
	// Filling document tabular section.
	If SourceData.OperationKind = Enums.OperationKindsPaymentReceipt.FromCustomer
	 OR SourceData.OperationKind = Enums.OperationKindsPaymentReceipt.FromVendor Then
	 
		If TypeOf(SourceData.CounterpartyAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyAccount,
				,
				IsNewDocument
			);
		EndIf;
		
		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			,
			IsNewDocument
		);
		
		If ObjectOfDocument.PaymentDetails.Count() = 0 Then
			RowOfDetails = ObjectOfDocument.PaymentDetails.Add();
		Else
			RowOfDetails = ObjectOfDocument.PaymentDetails[0];
		EndIf;
		
		OneRowInDecipheringPayment = ObjectOfDocument.PaymentDetails.Count() = 1;
		
		SetProperty(
			RowOfDetails,
			"Contract",
			?(SourceData.Contract = "Not found", Undefined, SourceData.Contract),
			,
			IsNewDocument
		);
		
		SetProperty(
			RowOfDetails,
			"AdvanceFlag",
			SourceData.AdvanceFlag,
			True,
			IsNewDocument
		);
		
		// Filling document tabular section.
		If IsNewDocument
		 OR OneRowInDecipheringPayment
		   AND RowOfDetails.PaymentAmount <> ObjectOfDocument.DocumentAmount Then
			
			RowOfDetails.PaymentAmount = ObjectOfDocument.DocumentAmount;
			DateOfFilling = ObjectOfDocument.Date;
			SettlementsCurrency = RowOfDetails.Contract.SettlementsCurrency;
			
			CalculateRateAndAmountOfAccounts(
				RowOfDetails,
				SettlementsCurrency,
				DateOfFilling,
				ObjectOfDocument,
				IsNewDocument
			);
			
			If RowOfDetails.ExchangeRate = 0 Then
				
				SetProperty(
					RowOfDetails,
					"ExchangeRate",
					1,
					,
					IsNewDocument
				);
				
				SetProperty(
					RowOfDetails,
					"Multiplicity",
					1,
					,
					IsNewDocument
				);
				
				SetProperty(
					RowOfDetails,
					"SettlementsAmount",
					RowOfDetails.PaymentAmount,
					,
					IsNewDocument
				);
				
			EndIf;
			
			If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
				
				DefaultVATRate = ObjectOfDocument.Company.DefaultVATRate;
				VATRateValue = SmallBusinessReUse.GetVATRateValue(DefaultVATRate);
				
				RowOfDetails.VATRate = DefaultVATRate;
				RowOfDetails.VATAmount = RowOfDetails.PaymentAmount
					- (RowOfDetails.PaymentAmount)
					/ ((VATRateValue + 100) / 100);
				
			Else
				
				If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
					DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
				Else
					DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
				EndIf;
				
				RowOfDetails.VATRate = DefaultVATRate;
				RowOfDetails.VATAmount = 0;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillAttributesPaymentReceipt()

// Procedure sets the deletion mark.
//
Procedure SetMarkToDelete(ObjectForMark, Check)
	
	NameObject = GetObjectPresentation(ObjectForMark);
	NameOfAction = ?(Check, NStr("en=' Marked for deletion';ru=' помечен на удаление'"), NStr("en=' deletion mark was cleared';ru=' отменена пометка на удаление'"));
	Try
		ObjectForMark.Write(DocumentWriteMode.Write);
		ObjectForMark.SetDeletionMark(Check);
		MessageText = NStr("en='%ObjectNameLeft% %NameObjectMid%: %NameOfAction%.';ru='%НазваниеОбъектаЛев% %НазваниеОбъектаСред%: %НазваниеДействия%.'");
		MessageText = StrReplace(MessageText, "%ObjectNameLeft%", Upper(Left(NameObject, 1)));
		MessageText = StrReplace(MessageText, "%NameObjectMid%", Mid(NameObject, 2));
		MessageText = StrReplace(MessageText, "%NameOfAction%", NameOfAction);		
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);		
	Except
		MessageText = NStr("en='%ObjectNameLeft% %NameObjectMid%: not %NameOfAction%! Errors occurred while writing!';ru='%НазваниеОбъектаЛев% %НазваниеОбъектаСред%: не %НазваниеДействия%! Произошли ошибки при записи!'");
		MessageText = StrReplace(MessageText, "%ObjectNameLeft%", Upper(Left(NameObject, 1)));
		MessageText = StrReplace(MessageText, "%NameObjectMid%", Mid(NameObject, 2));
		MessageText = StrReplace(MessageText, "%NameOfAction%", NameOfAction);
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
	EndTry
	
EndProcedure // SetMarkToDelete()

// Procedure writes the object.
//
Procedure WriteObject(ObjectToWrite, SectionRow, IsNewDocument)
	
	DocumentType = ObjectToWrite.Metadata().Name;
	If DocumentType = "PaymentExpense" Then
		DocumentName = "Payment expense";
		If FillDebtsAutomatically AND SectionRow.OperationKind = Enums.OperationKindsPaymentExpense.Vendor Then
			SmallBusinessServer.FillPaymentDetailsExpense(ObjectToWrite,,,,, SectionRow.Contract);
		EndIf;
	ElsIf DocumentType = "PaymentReceipt" Then
		DocumentName = "Payment receipt";
		If FillDebtsAutomatically AND SectionRow.OperationKind = Enums.OperationKindsPaymentReceipt.FromCustomer Then
			SmallBusinessServer.FillPaymentDetailsReceipt(ObjectToWrite,,,,, SectionRow.Contract);
		EndIf;
	EndIf;
	SetProperty(
		ObjectToWrite,
		"PaymentDestination",
		SectionRow.PaymentDestination,
		,
		IsNewDocument
	);
	SetProperty(
		ObjectToWrite,
		"Author",
		Users.CurrentUser(),
		True,
		IsNewDocument
	);
	ObjectModified = ObjectToWrite.Modified();
	ObjectPosted = ObjectToWrite.Posted;
	NameObject = GetObjectPresentation(ObjectToWrite);
	
	If ObjectModified Then
		Try
			If ObjectPosted Then
				ObjectToWrite.Write(DocumentWriteMode.UndoPosting);
				SectionRow.Posted = ObjectToWrite.Posted;
			Else
				ObjectToWrite.Write(DocumentWriteMode.Write);
			EndIf;
			//( elmi Lost in translation
			//MessageText = NStr("en='%Status% %ObjectName%.';ru='%Статус% %НазваниеОбъекта%.'");
			MessageText = NStr("en='%Status% %NameObject%.';ru='%Status% %NameObject%.'");
			//) elmi
			MessageText = StrReplace(MessageText, "%Status%" , ?(IsNewDocument, NStr("en='Created ';ru='Создан '"), NStr("en='Overwritten ';ru='Перезаписан '")));
			MessageText = StrReplace(MessageText, "%NameObject%", NameObject);
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
		Except
			//( elmi Lost in translation
			//MessageText = NStr("en='%ObjectNameLeft% %NameObjectMid% %Status%! Errors occurred while writing!';ru='%НазваниеОбъектаЛев% %НазваниеОбъектаСред% %Статус%! Произошли ошибки при записи!'");
			MessageText = NStr("en='%ObjectNameLeft% %NameObjectMid% %Status%! Errors occurred while writing!';ru='%ObjectNameLeft% %NameObjectMid% %Status%! Произошли ошибки при записи!'");
			//) elmi
			MessageText = StrReplace(MessageText, "%ObjectNameLeft%", Upper(Left(NameObject, 1)));
			MessageText = StrReplace(MessageText, "%NameObjectMid%", Mid(NameObject, 2));
			MessageText = StrReplace(MessageText, "%Status%", ?(ObjectToWrite.IsNew(), NStr("en=' not created';ru=' не создан'"), NStr("en=' not written';ru=' не записан'")));
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
			Return;
		EndTry;
	Else
		//( elmi Lost in translation
		//MessageText = NStr("en='%NameObject% already exists. Perhaps, import has been previously performed.';ru='Уже существует %НазваниеОбъекта%. Возможно загрузка производилась ранее.'");
		MessageText = NStr("en='%NameObject% already exists. Perhaps, import has been previously performed.';ru='Уже существует %NameObject%. Возможно загрузка производилась ранее.'");
		//) elmi
		MessageText = StrReplace(MessageText, "%NameObject%", NameObject);
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
	EndIf;
	
	If PostImported AND (ObjectModified OR Not ObjectPosted) Then
		Try
			ObjectToWrite.Write(DocumentWriteMode.Posting);
			//( elmi Lost in translation
			//MessageText = NStr("en='%Status% %ObjectName% %Status%';ru='%Статус% %НазваниеОбъекта% %Статус%'");
			MessageText = NStr("en='%Status% %NameObject% %Status%';ru='%Status% %NameObject% %Status%'");
			//) elmi
			MessageText = StrReplace(MessageText, "%Status%", ?(ObjectPosted, NStr("en='Reposted ';ru='Перепроведен '"), NStr("en='Posted ';ru='Posted '")));
			MessageText = StrReplace(MessageText, "%NameObject%", NameObject);
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
			SectionRow.Posted = ObjectToWrite.Posted;
		Except
			//( elmi Lost in translation
			//MessageText = NStr("en='%ObjectNameLeft% %NameObjectMid% is failed! Errors occurred while posting!';ru='%НазваниеОбъектаЛев% %НазваниеОбъектаСред% не проведен! Произошли ошибки при проведении!'");
			MessageText = NStr("en='%ObjectNameLeft% %NameObjectMid% is failed! Errors occurred while posting!';ru='%ObjectNameLeft% %NameObjectMid% не проведен! Произошли ошибки при проведении!'");
			//) elmi
			MessageText = StrReplace(MessageText, "%ObjectNameLeft%", Upper(Left(NameObject, 1)));
			MessageText = StrReplace(MessageText, "%NameObjectMid%", Mid(NameObject, 2));
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
		EndTry
	EndIf;
	
EndProcedure // WriteObject()

// Procedure synchronizes documents by accounts.
//
Procedure SynchronizeDocumentsByAccounts(DocumentsForImport, KindDocumentsSent, KindDocumentsInbox, IntervalBeginExport, ExportIntervalEnd, ImportBankAccounts)
	
	// We make an account list.
	ListAccounts = New ValueList;
	For Each AccountString IN ImportBankAccounts Do
		ListAccounts.Add(TrimAll(AccountString.BankAcc));
	EndDo;
	
	DocumentsOnDelete = New Query(
	"SELECT ALLOWED
	|	" + KindDocumentsSent + ".Ref,
	|	" + KindDocumentsSent + ".Date,
	|	" + KindDocumentsSent + ".BankAccount.AccountNo
	|FROM
	|	Document." + KindDocumentsSent + " AS " + KindDocumentsSent + "
	|WHERE
	|	" + KindDocumentsSent + ".Date >= &DateBeg AND " + KindDocumentsSent + ".Date <= &DateEnd AND " + KindDocumentsSent + ".BankAccount.AccountNo IN(&NumbersOfAccounts)");
	
	DocumentsOnDelete.SetParameter("DateBeg", IntervalBeginExport);
	DocumentsOnDelete.SetParameter("DateEnd", ExportIntervalEnd);
	DocumentsOnDelete.SetParameter("NumbersOfAccounts", ListAccounts);
	DocumentsSelection = DocumentsOnDelete.Execute().Select();
	
	While DocumentsSelection.Next() Do
		RowInImportTable = DocumentsForImport.Find(DocumentsSelection.Ref, "Document"); 		
		If RowInImportTable = Undefined Then
			DocumentObjectToDeletion = DocumentsSelection.Ref.GetObject();
			If UseDataProcessorBoundary Then
				If ValueIsFilled(DataProcessorBoundaryDate) Then
					If BegOfDay(DocumentObjectToDeletion.Date) <= BegOfDay(DataProcessorBoundaryDate) Then
						MessageText = NStr("en='The %DocumentObjectToDeletion% payment document is not marked for deletion as its date is equal or less than processor limits!';ru='Платежный документ ""%ОбъектДокументаКУдаление%"" не помечен на удаление, так как имеет дату равной или меньшей границы обработки!'");
						MessageText = StrReplace(MessageText, "%DocumentObjectToDeletion%", DocumentObjectToDeletion);
						SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
						Continue;
					EndIf;
				EndIf;
			EndIf;
			SetMarkToDelete(DocumentObjectToDeletion, True);
		EndIf;
	EndDo;
	
	// Receipts to the account which are
	// not in imported list we mark for deletion.
	DocumentsOnDelete = New Query(
	"SELECT ALLOWED
	|	" + KindDocumentsInbox + ".Ref,
	|	" + KindDocumentsInbox + ".IncomingDocumentDate,
	|	" + KindDocumentsInbox + ".BankAccount.AccountNo
	|FROM
	|	Document." + KindDocumentsInbox + " AS " + KindDocumentsInbox + "
	|WHERE
	|	" + KindDocumentsInbox + ".IncomingDocumentDate
	| >= &DateBeg AND " + KindDocumentsInbox + ".IncomingDocumentDate
	| <= &DateEnd AND " + KindDocumentsInbox + ".BankAccount.AccountNo IN(&NumbersOfAccounts)");
	
	DocumentsOnDelete.SetParameter("DateBeg", IntervalBeginExport);
	DocumentsOnDelete.SetParameter("DateEnd", ExportIntervalEnd);
	DocumentsOnDelete.SetParameter("NumbersOfAccounts", ListAccounts);
	DocumentsSelection = DocumentsOnDelete.Execute().Select();
	
	While DocumentsSelection.Next() Do
		RowInImportTable = DocumentsForImport.Find(DocumentsSelection.Ref, "Document");
		If RowInImportTable = Undefined Then
			DocumentObjectToDeletion = DocumentsSelection.Ref.GetObject();
			If UseDataProcessorBoundary Then
				If ValueIsFilled(DataProcessorBoundaryDate) Then
					If BegOfDay(DocumentObjectToDeletion.Date) <= BegOfDay(DataProcessorBoundaryDate) Then
						MessageText = NStr("en='The %DocumentObjectToDeletion% payment document is not marked for deletion as its date is equal or less than processor limits!';ru='Платежный документ ""%ОбъектДокументаКУдаление%"" не помечен на удаление, так как имеет дату равной или меньшей границы обработки!'");
						MessageText = StrReplace(MessageText, "%DocumentObjectToDeletion%", DocumentObjectToDeletion);
						SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
						Continue;
					EndIf;
				EndIf;
			EndIf;
			SetMarkToDelete(DocumentObjectToDeletion, True);
		EndIf;
	EndDo;
	
EndProcedure // SynchronizeDocumentsByAccounts()

// Function returns the found tree item.
//
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

// Function searches the bank by BIC or Corr. account and returns the found value.
//
Function FindBankByBIKAndCorrAccount(BIN, CorrAccount)
	
	FoundBank = Catalogs.Banks.EmptyRef();
	
	If Not IsBlankString(BIN) Then
		FoundBank = Catalogs.Banks.FindByCode(BIN);
	EndIf;
	
	If FoundBank = Catalogs.Banks.EmptyRef() Then
		FoundBank = Catalogs.Banks.FindByAttribute("CorrAccount", CorrAccount);
	EndIf;

	Return FoundBank;

EndFunction // FindBankByBICAndCorrAccount()

// Function creates a counterparty.
//
Function CreateCounterparty(StringCounterparty = Undefined) Export
	
	ReportAboutGeneratedCounterparty	  = False;
	ReportCreatedBankAccount = False;
	
	// These items are in all catalogs.
	If Not TypeOf(StringCounterparty.Attribute) = Type("CatalogRef.Counterparties") Then
		
		NewItem = Catalogs.Counterparties.CreateItem();
		
		NewItem.Description = StringCounterparty.Presentation;
		NewItem.DescriptionFull = StringCounterparty.Presentation;
		NewItem.TIN = StringCounterparty.GetItems()[1].Value;
		NewItem.KPP = StringCounterparty.GetItems()[2].Value;
		
		
		//( elmi #17 (112-00003) 
		//If StrLen(NewItem.TIN) = 12 Then
		//	NewItem.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind;
		//Else
			NewItem.LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
		//EndIf;
		//) elmi #17 (112-00003) 
		
		NewItem.GLAccountCustomerSettlements = ChartsOfAccounts.Managerial.AccountsReceivable;
		NewItem.CustomerAdvancesGLAccount = ChartsOfAccounts.Managerial.AccountsByAdvancesReceived;
		NewItem.GLAccountVendorSettlements = ChartsOfAccounts.Managerial.AccountsPayable;
		NewItem.VendorAdvancesGLAccount = ChartsOfAccounts.Managerial.SettlementsByAdvancesIssued;
		NewItem.DoOperationsByContracts = True;
		NewItem.DoOperationsByDocuments = True;
		NewItem.DoOperationsByOrders = True;
		NewItem.TrackPaymentsByBills = True;
		
		NewItem.Write();
		
		ReportAboutGeneratedCounterparty = True;
		
	Else
		
		NewItem = StringCounterparty.Attribute.GetObject();
		
	EndIf;
	
	If ReportAboutGeneratedCounterparty Then
		
		Message = New UserMessage;
		
		Message.Text = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Counterparty (%1) is created.';ru='Контрагент (%1) создан.'"), StringCounterparty.Presentation);
		
		Message.Message();
		
		PresentationOfCounterparty = "" + Chars.Tab + "- ";
		
	Else
		
		PresentationOfCounterparty = "To counterparty (" + StringCounterparty.Presentation + ")";
		
	EndIf;

	For Each String IN StringCounterparty.GetItems() Do
		
		ReportCreatedBankAccount = False;
		
		If String.Presentation = "R/account" Then
			
			Try
				
				AccountNo = String.Value;
				
				NewAccount = Catalogs.BankAccounts.CreateItem();
				
				NewAccount.AccountNo = AccountNo;
				NewAccount.Owner   = NewItem.Ref;
				
				SAAccount = String.GetItems();
				
				If Not FindTreeItem(SAAccount, "Presentation", "Bank's processing center") = Undefined Then
					
					// Counterparty's bank.
					If Not IsBlankString(SAAccount[0].Value) Then
						
						NewBank = FindBankByBIKAndCorrAccount("", SAAccount[2].Value);
						
						If NewBank = Catalogs.Banks.EmptyRef() Then
							
							NewBank = Catalogs.Banks.CreateItem();
							
							NewBank.Description = SAAccount[0].Value;
							NewBank.City        = SAAccount[1].Value;
							NewBank.CorrAccount     = SAAccount[2].Value;
							
							NewBank.Write();
							
						EndIf;
						
						NewAccount.Bank = NewBank.Ref;
						
					EndIf;
					
					// Processing center of counterparty's bank.
					If Not IsBlankString(SAAccount[3].Value) Then
						
						NewBankCorr = FindBankByBIKAndCorrAccount(SAAccount[5].Value, SAAccount[6].Value);
						
						If NewBankCorr = Catalogs.Banks.EmptyRef() Then
							
							NewBankCorr = Catalogs.Banks.CreateItem();
							
							NewBankCorr.Description = SAAccount[3].Value;
							NewBankCorr.City        = SAAccount[4].Value;
							NewBankCorr.Code          = SAAccount[5].Value;
							NewBankCorr.CorrAccount     = SAAccount[6].Value;
							
							NewBankCorr.Write();
							
						EndIf;
						
						NewAccount.AccountsBank = NewBankCorr.Ref;
						
					EndIf;
					
				Else
					
					// Counterparty's bank.
					NewBank = FindBankByBIKAndCorrAccount(SAAccount[2].Value, SAAccount[3].Value);
					
					If NewBank = Catalogs.Banks.EmptyRef() Then
						
						NewBank = Catalogs.Banks.CreateItem();
						
						NewBank.Description = SAAccount[0].Value;
						NewBank.City        = SAAccount[1].Value;
						NewBank.Code          = SAAccount[2].Value;
						NewBank.CorrAccount     = SAAccount[3].Value;
						
						NewBank.Write();
						
					EndIf;
					
					NewAccount.Bank = NewBank.Ref;
					
				EndIf;
				
				NewAccount.AccountType = "Transactional";
				NewAccount.CashCurrency = BankAccount.CashCurrency;
				DescriptionString = TrimAll(NewAccount.AccountNo) + ?(ValueIsFilled(NewAccount.Bank), ", in " + String(NewAccount.Bank), "");
				DescriptionString = Left(DescriptionString, 100);
				NewAccount.Description = DescriptionString;
				
				NewAccount.Write();
				
				ReportCreatedBankAccount = True;
				
				NewItem.BankAccountByDefault = NewAccount.Ref;
				NewItem.Write();
				
			Except
				
				Message = New UserMessage;
				
				Message.Text = NStr("en=""Failed to create company's banking account!"";ru='Не удалось создать банковский счет контрагента!'");
				
				Message.Message();
				
			EndTry;
			
		EndIf;
		
		If ReportCreatedBankAccount Then
			
			Message = New UserMessage;
			
			Message.Text = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1 bank account added (%2).';ru='%1 добавлен банковский счет (%2).'"), PresentationOfCounterparty, AccountNo);
			
			Message.Message();
			
		EndIf;
		
	EndDo;
	
	NewItem.Write();
	
	Return NewItem.Ref;
	
EndFunction // CreateCounterparty()

// Procedure imports the bank statements.
//
Procedure Import(ImportTitle) Export
	
	DocumentsForImport = Import.Unload();
	IntervalBeginExport = Date("00010101");
	ExportIntervalEnd  = Date("00010101");
	DocumentsForImport.Indexes.Add("Document");
	
	//( elmi  #17 (112-00003) (
	If ImportTitle <> Undefined Then
	//) elmi 	
		
		Result = GetDateFromString(IntervalBeginExport, ImportTitle.StartDate);
		If Not ValueIsFilled(Result) Then
			MessageText  = NStr("en='In the import file title there is invalid date of the period beginning! File can not be imported!';ru='В заголовке файла загрузки неверно указана дата начала интервала! Файл не может быть загружен!'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
			Return;
		EndIf;
		Result = GetDateFromString(ExportIntervalEnd, ImportTitle.EndDate);
		If Not ValueIsFilled(Result) Then
			MessageText = NStr("en='The header of the imported file has a wrong date of the beginning of the period!';ru='В заголовке файла импорта неверно указана дата окончания интервала!'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
		EndIf;
	
	//( elmi  #17 (112-00003) 
	EndIf;
	//) elmi 
	
	// We import the marked document sections.
	For Each SectionRow IN DocumentsForImport Do
		If SectionRow.Import Then
			CheckResult = CheckDocumentForImport(SectionRow);
			If IsBlankString(CheckResult) Then
				If Not ValueIsFilled(SectionRow.Document) Then
					
					// IN the IB the document is not found, it is required to create the new one.
					ObjectOfDocument = Documents[SectionRow.DocumentKind].CreateDocument();
					IsNewDocument = True;
					
				Else
					
					// IN the IB the document is found, it is required to get its object.
					ObjectOfDocument = SectionRow.Document.GetObject();
					IsNewDocument = False;
					
				EndIf;
				
				// We fill all document attributes.
				DocumentType = ObjectOfDocument.Metadata().Name;
				If DocumentType = "PaymentExpense" Then
					FillAttributesPaymentExpense(ObjectOfDocument, SectionRow, IsNewDocument);
				ElsIf DocumentType = "PaymentReceipt" Then
					FillAttributesPaymentReceipt(ObjectOfDocument, SectionRow, IsNewDocument);
				EndIf;
				
				If ObjectOfDocument.DeletionMark Then
					SetMarkToDelete(ObjectOfDocument, False);
				EndIf;
				
				WriteObject(ObjectOfDocument, SectionRow, IsNewDocument);
				
				If Not ObjectOfDocument.IsNew() Then
					If Not ValueIsFilled(SectionRow.Document) Then
						SectionRow.Document = ObjectOfDocument.Ref;
						If SectionRow.DocumentKind = "PaymentExpense" Then
							AttributeOfDate = "PayDate";
							NumberAttribute = "Number";
						Else
							AttributeOfDate = "IncomingDocumentDate";
							NumberAttribute = "IncomingDocumentNumber";
						EndIf;
						SectionRow.DocNo = ObjectOfDocument[NumberAttribute];
					EndIf;
				EndIf; 
			Else
				MessageText = NStr("en='The %Operation% payment document No. %Number% from %Date%
		|can not be imported: %CheckResult%!';ru='Платежный документ ""%Операция%"" №%Номер% от %Дата%
		|не может быть загружен: %РезультатПроверки%!'"
				);
				MessageText = StrReplace(MessageText, "%Operation%", SectionRow.Operation);
				MessageText = StrReplace(MessageText, "%Number%", SectionRow.Number);
				MessageText = StrReplace(MessageText, "%Date%", SectionRow.Date);
				MessageText = StrReplace(MessageText, "%CheckResult%", CheckResult);
				SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
			EndIf;
		EndIf;
	EndDo;
	
	// Outgoing payment orders which are not in
	// the imported list we mark for deletion.
	SynchronizeDocumentsByAccounts(
		DocumentsForImport,
		"PaymentExpense",
		"PaymentReceipt",
		IntervalBeginExport,
		ExportIntervalEnd,
		ImportBankAccounts
	);
	
EndProcedure // Import()

#EndRegion

#Region Exporting

// Procedure fills the table values for export.
//
Procedure FillExportValue(RowExporting, SelectionForExport)
	
	Payer = "Company";
	Recipient = "Counterparty";
	
	If SelectionForExport.Date < Date('20110101') Then
		RowExporting.Number = SmallBusinessServer.GetNumberForPrinting(SelectionForExport.Number, Company.Prefix);
	Else
		RowExporting.Number = ObjectPrefixationClientServer.GetNumberForPrinting(SelectionForExport.Number, True, True);
	EndIf;
	
	RowExporting.Date = SelectionForExport.Date;
	RowExporting.Amount = Format(SelectionForExport.DocumentAmount, "ND=15; NFD=2; NDS=.; NGS=' '; NG=0");
	RowExporting.PayerAccount = SelectionForExport[Payer + "AccountNo"];
	RowExporting.PayeeAccount = SelectionForExport[Recipient + "AccountNo"];
	RowExporting.PaymentKind = SelectionForExport.PaymentKind;
	PayerIndirectPayments = ValueIsFilled(SelectionForExport[Payer + "SettlementsBank"]);
	RecipientIndirectSettlements  = ValueIsFilled(SelectionForExport[Recipient + "SettlementsBank"]);
	
	// PayType.
	RowExporting.PayKind = "01";
	
	// Payer1.
	PayerText = "";
	If PayerIndirectPayments Then
		PositionOfRS = Find(SelectionForExport["PayerText"], "r/From"); 
		If PositionOfRS = 0 Then
			PayerText = SelectionForExport["PayerText"];
		Else
			PayerText = TrimAll((Left(SelectionForExport["PayerText"], PositionOfRS - 1)));
		EndIf;
	Else
		PayerText = SelectionForExport["PayerText"];
	EndIf;
	RowExporting.Payer1 = PayerText;
	
	// Payer, PayerTIN.
	Value = SelectionForExport.PayerTIN;
	If IsBlankString(Value) Then
		Value = SelectionForExport[Payer + "TIN"];
	EndIf;
	RowExporting.PayerTIN = Value;
	RowExporting.Payer = "TIN " + Value + " " + RowExporting.Payer1;
	
	// PayerBankAcc, PayerBank1,
	// PayerBank2, PayerBIC, PayerBalancedAccount, Payer2, Payer3, Payer4.
	If PayerIndirectPayments Then
		RowExporting.Payer2 		  = SelectionForExport[Payer + "AccountNo"];
		RowExporting.Payer3 		  = SelectionForExport[Payer + "Bank"];
		RowExporting.Payer4 		  = SelectionForExport[Payer + "BankCity"];
		RowExporting.Payer 		  = RowExporting.Payer + " r/From " + RowExporting.Payer2 + " in " + RowExporting.Payer3 + " " + RowExporting.Payer4;
		RowExporting.PayerBankAcc = SelectionForExport[Payer + "BankAcc"];
		RowExporting.PayerBank1    = SelectionForExport[Payer + "SettlementBank"];
		RowExporting.PayerBank2    = SelectionForExport[Payer + "BankPCCity"];
		RowExporting.PayerBIC      = SelectionForExport[Payer + "BankPCBIC"];
		RowExporting.PayerBalancedAccount  = SelectionForExport[Payer + "CorrAccountRCBank"];
	Else
		RowExporting.PayerBankAcc = SelectionForExport[Payer + "AccountNo"];
		RowExporting.PayerBank1    = SelectionForExport[Payer + "Bank"];
		RowExporting.PayerBank2    = SelectionForExport[Payer + "BankCity"];
		RowExporting.PayerBIC      = SelectionForExport[Payer + "BankBIC"];
		RowExporting.PayerBalancedAccount  = SelectionForExport[Payer + "BankAcc"];
	EndIf;
	
	// Payee1.
	PayeeText = "";
	If RecipientIndirectSettlements Then
		PositionOfRS = Find(SelectionForExport["PayeeText"], "r/From");
		If PositionOfRS = 0 Then
			PayeeText = SelectionForExport["PayeeText"];
		Else
			PayeeText = TrimAll((Left(SelectionForExport["PayeeText"], PositionOfRS-1)));
		EndIf;
	Else
		PayeeText = SelectionForExport["PayeeText"];
	EndIf;
	RowExporting.Payee1 = PayeeText;
	
	// Payee, PayeeTIN.
	Value = SelectionForExport.PayeeTIN;
	If IsBlankString(Value) Then
		Value = SelectionForExport[Recipient + "TIN"];
	EndIf;
	RowExporting.PayeeTIN = Value;
	RowExporting.Recipient = "TIN " + Value + " " + RowExporting.Payee1;
	
	// PayeeBankAcc, PayeeBank1,
	// PayeeBank2, PayeeBIK, PayeeBalancedAccount, Payee2, Payee3, Payee4.
	If RecipientIndirectSettlements Then
		RowExporting.Payee2 		  = SelectionForExport[Recipient + "AccountNo"];
		RowExporting.Payee3 		  = SelectionForExport[Recipient + "Bank"];
		RowExporting.Payee4 		  = SelectionForExport[Recipient + "BankCity"];
		RowExporting.Recipient 		  = RowExporting.Recipient	  + " r/From " + RowExporting.Payee2 + " in " + RowExporting.Payee3 + " " + RowExporting.Payee4;
		RowExporting.PayeeBankAcc = SelectionForExport[Recipient + "BankAcc"];
		RowExporting.PayeeBank1    = SelectionForExport[Recipient + "SettlementBank"];
		RowExporting.PayeeBank2    = SelectionForExport[Recipient + "BankPCCity"];
		RowExporting.PayeeBIK      = SelectionForExport[Recipient + "BankPCBIC"];
		RowExporting.PayeeBalancedAccount  = SelectionForExport[Recipient + "CorrAccountRCBank"];
	Else
		RowExporting.PayeeBankAcc = SelectionForExport[Recipient + "AccountNo"];
		RowExporting.PayeeBank1    = SelectionForExport[Recipient + "Bank"];
		RowExporting.PayeeBank2    = SelectionForExport[Recipient + "BankCity"];
		RowExporting.PayeeBIK      = SelectionForExport[Recipient + "BankBIC"];
		RowExporting.PayeeBalancedAccount  = SelectionForExport[Recipient + "BankAcc"];
	EndIf;
	
	// PayerKPP.
	If Not ValueIsFilled(RowExporting.PayerKPP) Then
		RowExporting.PayerKPP = SelectionForExport.PayerKPP;
	EndIf;
	
	// PayeeKPP.
	If Not ValueIsFilled(RowExporting.PayeeKPP) Then
		RowExporting.PayeeKPP = SelectionForExport.PayeeKPP;
	EndIf;
	
	// AuthorStatus, PayerKPP, PayeeKPP,
	// KBKIndicator, OKATO, BasisIndicator, PeriodIndicator,
	// NumberIndicator, DateIndicator, TypeIndicator.
	If SelectionForExport.OperationKind = Enums.OperationKindsPaymentOrder.TaxTransfer Then
		RowExporting.AuthorStatus = SelectionForExport.AuthorStatus;
		If IsBlankString(RowExporting.AuthorStatus) Then
			RowExporting.AuthorStatus = "0";
		EndIf;
		If Not ValueIsFilled(RowExporting.PayerKPP) Then
			RowExporting.PayerKPP = SelectionForExport.PayerKPP;
		EndIf;
		If Not ValueIsFilled(RowExporting.PayerKPP) Then
			RowExporting.PayerKPP = "0";
		EndIf;
		If Not ValueIsFilled(RowExporting.PayeeKPP) Then
			RowExporting.PayeeKPP = SelectionForExport.PayeeKPP;
		EndIf;
		If Not ValueIsFilled(RowExporting.PayeeKPP) Then
			RowExporting.PayeeKPP = "0";
		EndIf;
		RowExporting.KBKIndicator = SelectionForExport.BKCode;
		RowExporting.OKATO         = SelectionForExport.OKATOCode;
		If IsBlankString(SelectionForExport.BasisIndicator) Then
			RowExporting.BasisIndicator = "0";
		Else
			RowExporting.BasisIndicator = SelectionForExport.BasisIndicator;
		EndIf;
		If IsBlankString(SelectionForExport.PeriodIndicator) OR (SelectionForExport.PeriodIndicator = "  . .    ") Then
			RowExporting.PeriodIndicator = "0";
		Else
			RowExporting.PeriodIndicator = SelectionForExport.PeriodIndicator;
		EndIf;
		If IsBlankString(SelectionForExport.NumberIndicator) Then
			RowExporting.NumberIndicator = "0";
		Else
			RowExporting.NumberIndicator = SelectionForExport.NumberIndicator;
		EndIf;
		If Not ValueIsFilled(SelectionForExport.DateIndicator) Then
			RowExporting.DateIndicator = "0";
		Else
			RowExporting.DateIndicator = Format(SelectionForExport.DateIndicator,"DLF=D");
		EndIf;
		TypeIndicatorIsProvidedByExchangeStandards = RowExporting.Property("TypeIndicator");
		TypeIndicatorIsNotExported = SelectionForExport.Date >= '20150101'; // Ministry of Finance order No 126n from 30.10.2014.
		If TypeIndicatorIsProvidedByExchangeStandards Then
			If TypeIndicatorIsNotExported OR IsBlankString(SelectionForExport.TypeIndicator) Then
				RowExporting.TypeIndicator = "0";
			Else
				RowExporting.TypeIndicator = SelectionForExport.TypeIndicator;
			EndIf;
		EndIf;
	EndIf;
	
	CodeIsProvidedByExchangeStandards = RowExporting.Property("Code");
	CodeIsExportedInSeparateField = (SelectionForExport.Date >= '20140331');
	If CodeIsExportedInSeparateField AND CodeIsProvidedByExchangeStandards Then
		
		If SelectionForExport.OperationKind = Enums.OperationKindsPaymentOrder.TaxTransfer
			AND IsBlankString(SelectionForExport.PaymentIdentifier) Then
			RowExporting.Code = "0"; // requirements 107n
		Else
			RowExporting.Code = SelectionForExport.PaymentIdentifier; // only requirements 383-P
		EndIf;
		
	EndIf;
	
	// OrderOfPriority.
	RowExporting.OrderOfPriority = "" + SelectionForExport.PaymentPriority;
	
	// PaymentDestination, PaymentDestination1, PaymentDestination2,
	// PaymentDestination3, PaymentDestination4, PaymentDestination5, PaymentDestination6.
	RowExporting.PaymentDestination = StrReplace(
		StrReplace(
			StrReplace(
				SelectionForExport.PaymentDestination,
				Chars.LF,
				" "),
			Chars.CR,
			""),
		Chars.FF,
		""
	);
	RowsCountNP = StrLineCount(SelectionForExport.PaymentDestination);
	If RowsCountNP > 6 Then
		RowsCountNP = 6;
	EndIf;
	For Ct = 1 To RowsCountNP Do
		RowExporting["PaymentDestination" + Ct] = StrGetLine(SelectionForExport.PaymentDestination, Ct);
	EndDo;
	For Ct = (RowsCountNP + 1) To 6 Do
		RowExporting["PaymentDestination" + Ct] = "";
	EndDo;
	
EndProcedure // FillExportValue()

// Function gets the document section.
//
Function GetSectionDocument(DocumentStructure, CollectionDetails)
	
	Buffer = "";
	Attribute = "";
	StructureForRecord = GenerateExportStructure();
	FillExportValue(StructureForRecord, DocumentStructure);
	AddToString(Buffer, "SectionDocument=" + DocumentStructure.DocumentKind);
	For Each PagedAttribute IN StructureForRecord Do
		Value = AdjustValue(PagedAttribute.Value);
		If Not IsBlankString(Value) Then
			AddToString(Buffer, PagedAttribute.Key + "=" + Value);
		EndIf;
	EndDo;
	AddToString(Buffer, "EndDocument");
	
	Return Buffer;
	
EndFunction // GetSectionDocument()

// Procedure exports the payment orders.
//
Function Unload(FileOperationsExtensionConnected, UniqueKey) Export
	
	DocumentsForExport = Exporting.Unload();
	DumpStream = New TextDocument();
	
	If Encoding = "DOS" Then
		DumpStream.SetFileType(TextEncoding.OEM);
	Else
		DumpStream.SetFileType(TextEncoding.ANSI);
	EndIf;
	
	// We form a title.
	DumpStream.AddLine("1CClientBankExchange");
	DumpStream.AddLine("FormatVersion=" + FormatVersion); // Supported versions are "1.01" and "1.02"
	DumpStream.AddLine("Encoding=" + Encoding);
	DumpStream.AddLine("Sender=" + Metadata.Synonym);
	DumpStream.AddLine("Recipient=" + Application);
	DumpStream.AddLine("CreationDate=" + Format(CurrentDate(), "DLF=D"));
	DumpStream.AddLine("CreationTime=" + Format(CurrentDate(), "DLF=In"));
	DumpStream.AddLine("StartDate=" + Format(StartPeriod, "DLF=D"));
	DumpStream.AddLine("EndDate=" + Format(EndPeriod, "DLF=D"));
	DumpStream.AddLine("BankAcc=" + BankAccount.AccountNo);
	DumpStream.AddLine("Document = Payment Order");
	
	// We display the marked document sections.
	For Each SectionRow IN DocumentsForExport Do
		If Not(SectionRow.Exporting)Then
			Continue;
		EndIf;
		Buffer = GetSectionDocument(SectionRow, DocumentsForExport.Columns);
		CountTermSection = StrLineCount(Buffer);
		For Ct = 1 To CountTermSection Do
			DumpStream.AddLine(StrGetLine(Buffer, Ct));
		EndDo;
		SectionRow.Readiness = - 2;
	EndDo;
	
	DumpStream.AddLine("EndFile");
	
	//If FileOperationsExtensionConnected
	//	Then DumpStream Return;
	//Else
		TempFileName = GetTempFileName("txt");
		If Encoding = "DOS" Then
			DumpStream.Write(TempFileName, TextEncoding.OEM);
		Else
			DumpStream.Write(TempFileName, TextEncoding.ANSI);
		EndIf;
		Address = PutToTempStorage(New BinaryData(TempFileName), UniqueKey);
		Return Address;
	//EndIf;
	
EndFunction // Export()

#EndRegion

#Region ServiceProceduresAndFunctions

// Function recalculates the amount from one currency to another
//
// Parameters:      
// Amount         - Number - amount that should be recalculated.
// 	InitRate       - Number - currency rate from which you should recalculate.
// 	FinRate       - Number - currency rate to which you should recalculate.
// 	RepetitionBeg  - Number - multiplicity from which you
// should recalculate (by default = 1).
// 	RepetitionEnd  - Number - multiplicity in which
// it is required to recalculate (by default =1)
//
// Returns: 
//  Number - amount recalculated to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, InitRate, FinRate,	RepetitionBeg = 1, RepetitionEnd = 1) Export
	
	If (InitRate = FinRate) AND (RepetitionBeg = RepetitionEnd) Then
		Return Amount;
	EndIf;
	
	If InitRate = 0
	 OR FinRate = 0
	 OR RepetitionBeg = 0
	 OR RepetitionEnd = 0 Then
		MessageText = NStr("en='Null exchange rate has been found. Recalculation is not executed.';ru='Обнаружен нулевой курс валюты. Пересчет не выполнен.'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText);
		Return Amount;
	EndIf;
	
	RecalculatedSumm = Round((Amount * InitRate * RepetitionEnd) / (FinRate * RepetitionBeg), 2);
	
	Return RecalculatedSumm;
	
EndFunction // RecalculateFromCurrencyToCurrency()

// Returns exchange rate for a date.
//
Function GetCurrencyRate(Currency, ExchangeRateDate)
	
	Structure = InformationRegisters.CurrencyRates.GetLast(ExchangeRateDate, New Structure("Currency", Currency));
	
	Return Structure;
	
EndFunction // GetCurrencyRate()

// Function forms a structure of export.
//
Function GenerateExportStructure()
	
	StructureOfExports = New structure;
	StructureOfExports.Insert( "Exporting",             ""); // "_",
	StructureOfExports.Insert( "Readiness",            ""); // "Readiness",
	StructureOfExports.Insert( "DocNo",              ""); // "Document No",
	StructureOfExports.Insert( "Number",                 ""); // "Number",
	StructureOfExports.Insert( "Date",                  ""); // "Date",
	StructureOfExports.Insert( "Operation",              ""); // "Operation",
	StructureOfExports.Insert( "BankAccount",        ""); // "Item. Company's bank account",
	StructureOfExports.Insert( "AccountNumberOrganization", ""); // "Company's bank account",
	StructureOfExports.Insert( "Amount",                 ""); // "Amount",
	StructureOfExports.Insert( "Counterparty",            ""); // "Counterparty",
	StructureOfExports.Insert( "CounterpartyAccount",       ""); // "Counterparty's bank account",
	StructureOfExports.Insert( "CounterpartyAccountNumber", ""); // "Item. Counterparty's bank account",
	StructureOfExports.Insert( "StatementDate",         ""); // "Date of receipt",
	StructureOfExports.Insert( "StatementTime",        ""); // "Time of receipt",
	StructureOfExports.Insert( "StatementContent",   ""); // "Receipt content",
	StructureOfExports.Insert( "PayerAccount",        ""); // "Payer settlement account",
	StructureOfExports.Insert( "Payer",            ""); // "Payer",
	StructureOfExports.Insert( "PayerTIN",         ""); // "Payer TIN",
	StructureOfExports.Insert( "Payer1",           ""); // "Payer name",
	StructureOfExports.Insert( "Payer2",           ""); // "Payer settlement account",
	StructureOfExports.Insert( "Payer3",           ""); // "Payer bank",
	StructureOfExports.Insert( "Payer4",           ""); // "City of payer's bank",
	StructureOfExports.Insert( "PayerBankAcc",    ""); // "Correspondent account of payer bank",
	StructureOfExports.Insert( "PayerBank1",       ""); // "Payer bank processing center",
	StructureOfExports.Insert( "PayerBank2",       ""); // "City of the payer bank processing center",
	StructureOfExports.Insert( "PayerBIC",         ""); // "BIC of payer bank processing center",
	StructureOfExports.Insert( "PayerBalancedAccount",     ""); // "Correspondent account of payer bank processing center",
	StructureOfExports.Insert( "PayeeAccount",        ""); // "Recipient bank account",
	StructureOfExports.Insert( "Recipient",            ""); // "Recipient",
	StructureOfExports.Insert( "PayeeTIN",         ""); // "Payee TIN",
	StructureOfExports.Insert( "Payee1",           ""); // "Payee name",
	StructureOfExports.Insert( "Payee2",           ""); // "Recipient bank account",
	StructureOfExports.Insert( "Payee3",           ""); // "Recipient bank",
	StructureOfExports.Insert( "Payee4",           ""); // "City of payee's bank",
	StructureOfExports.Insert( "PayeeBankAcc",    ""); // "Correspondent account of payee bank",
	StructureOfExports.Insert( "PayeeBank1",       ""); // "Payee's bank processing center",
	StructureOfExports.Insert( "PayeeBank2",       ""); // "City of the payee's bank processing center",
	StructureOfExports.Insert( "PayeeBIK",         ""); // "BIC of the payee's bank processing center",
	StructureOfExports.Insert( "PayeeBalancedAccount",     ""); // "Correspondent account of payee's bank processing center",
	StructureOfExports.Insert( "PaymentKind",            ""); // "Payment type",
	StructureOfExports.Insert( "PayKind",             ""); // "Pay type",
	StructureOfExports.Insert( "AuthorStatus",     ""); // "Author Status",
	StructureOfExports.Insert( "PayerKPP",         ""); // "Payer KPP",
	StructureOfExports.Insert( "PayeeKPP",         ""); // "Payee KPP",
	StructureOfExports.Insert( "KBKIndicator",         ""); // "Indicator KBK",
	StructureOfExports.Insert( "OKATO",                 ""); // "OKATO",
	StructureOfExports.Insert( "BasisIndicator",   ""); // "Basis indicator",
	StructureOfExports.Insert( "PeriodIndicator",     ""); // "Indicator of beg. period",
	StructureOfExports.Insert( "NumberIndicator",      ""); // "Document number indicator",
	StructureOfExports.Insert( "DateIndicator",        ""); // "Document date indicator",
	
	If FormatVersion < "1.03" Then // From 01.01.2015 is not used
		StructureOfExports.Insert("TypeIndicator",     ""); // "Indicator of payment type"
	EndIf;
	
	StructureOfExports.Insert( "OrderOfPriority",           ""); // "Payment priority",
	StructureOfExports.Insert( "PaymentDestination",     ""); // "Payment purpose",
	StructureOfExports.Insert( "PaymentDestination1",    ""); // "Payment purpose, page 1",
	StructureOfExports.Insert( "PaymentDestination2",    ""); // "Payment purpose, page 2",
	StructureOfExports.Insert( "PaymentDestination3",    ""); // "Payment purpose, page 3",
	StructureOfExports.Insert( "PaymentDestination4",    ""); // "Payment purpose, page 4",
	StructureOfExports.Insert( "PaymentDestination5",    ""); // "Payment purpose, page 5",
	StructureOfExports.Insert( "PaymentDestination6",    ""); // "Payment purpose, page 6",
	StructureOfExports.Insert( "Document",              ""); // "Source",
	StructureOfExports.Insert( "SectionDocument",        ""); // "Export",
	StructureOfExports.Insert( "ErrorsDescriptionFull",        ""); // "Comments",
	StructureOfExports.Insert( "DocumentType",          ""); // "Type of payment document"
	
	If FormatVersion >= "1.02" Then
		StructureOfExports.Insert("Code", ""); // "Unique identifier of payment"
	EndIf;
	
	Return StructureOfExports;
	
EndFunction // GenerateExportStructure()

// Procedure  adds a string into string.
//
Procedure AddToString(Buffer, NewRow)
	
	If IsBlankString(Buffer) Then
		Buffer = NewRow;
	Else
		Buffer = Buffer + Chars.LF + NewRow;
	EndIf;
	
EndProcedure // AddToString()

// Function adjusts values.
//
Function AdjustValue(Value)
	
	If TypeOf(Value) = Type("String") Then
		Return TrimAll(Value);		
	ElsIf TypeOf(Value) = Type("Number") Then
		Return Format(Value, "NDS=.; NGS=' '; NG=0");
	ElsIf TypeOf(Value) = Type("Date") Then
		Return Format(Value, "DF=dd.MM.yyyy");
	Else
		Return "";
	EndIf;
	
EndFunction // AdjustValue()

// Function receives a date from string.
//
Function GetDateFromString(Receiver, Source)
	
	Buffer = Source;
	DotPosition = Find(Buffer, ".");
	If DotPosition = 0 Then
		Return NStr("en='The incorrect format of the date row';ru='Неверный формат строки с датой'");
	EndIf;
	NumberDate = Left(Buffer, DotPosition - 1);
	Buffer = Mid(Buffer, DotPosition + 1);
	DotPosition = Find(Buffer, ".");
	If DotPosition = 0 Then
		Return NStr("en='The incorrect format of the date row';ru='Неверный формат строки с датой'");
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
		Return NStr("en='Failed to convert string to date';ru='Не удалось преобразовать строку в дату'");
	EndTry;
	
	Return Receiver;
	
EndFunction // GetDateFromString()

// Function defines non-digits in a string.
//
Function AreNotDigits(Val CheckString) Export
	
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

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	// Вставить содержимое обработчика.
EndProcedure

#EndRegion

#EndIf
