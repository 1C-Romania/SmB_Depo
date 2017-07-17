Var InitialDocumentBase Export;

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENTS PROCESSING OF THE Object

Procedure OnCopy(CopiedObject)
	
	DocumentBase = Undefined;
	
EndProcedure

Procedure Filling(Base)
	
	If Base = Undefined OR TypeOf(Base)=Type("Structure") Then
		// filling new		
		CommonAtServer.FillDocumentHeader(ThisObject);
		
		If Not ValueIsFilled(Currency) Then     
			Currency = DefaultValuesAtServer.GetNationalCurrency();
			ExchangeRate = DefaultValuesAtServer.GetExchangeRate(Currency, Date);
		EndIf;
		
		If ValueIsNotFilled(OperationType) Then
			OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.Any");
		EndIf;
		If OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument")
			OR OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.ClosePeriod") Then
			InitialDocumentDate = '00010101';
			InitialDocumentNumber = "";
		Else
			DocumentBase = Undefined;
		EndIf;			
	EndIf;
	
	If TypeOf(Base) = TypeOf(Catalogs.BookkeepingOperationsTemplates.EmptyRef()) Then
		// based on bookkeeping template
		BookkeepingOperationsTemplate = Base;
		BaseDocumentBase = Base.DocumentBase;
		If TypeOf(DocumentBase) = TypeOf(Base.DocumentBase) Then
			BaseDocumentBase = DocumentBase; 
		EndIf;	
		
	Else
		// Based on other document
		BaseDocumentBase = Base;

	EndIf;	
	
	If BaseDocumentBase <> Undefined Then
		DocumentBaseMetadata = BaseDocumentBase.Ref.Metadata();
		OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument;
		DocumentBase = BaseDocumentBase;
		
		If BaseDocumentBase = PredefinedValue("Document."+BaseDocumentBase.Ref.Metadata().Name+".EmptyRef") Then
			CommonAtServer.FillDocumentHeader(ThisObject);
			
			If Not ValueIsFilled(Currency) Then     
				Currency = DefaultValuesAtServer.GetNationalCurrency();
				ExchangeRate = DefaultValuesAtServer.GetExchangeRate(Currency, Date);
			EndIf;
			
			InitialDocumentDate = '00010101';
			InitialDocumentNumber = "";
		Else	
			Company = BaseDocumentBase.Company;
			Date = BaseDocumentBase.Date;
			If CommonAtServer.IsDocumentAttribute("Currency", DocumentBaseMetadata) Then
				Currency = BaseDocumentBase.Currency;
				ExchangeRate = DefaultValuesAtServer.GetExchangeRate(Currency, Date);		
			Else
				Currency = DefaultValuesAtServer.GetNationalCurrency();
				ExchangeRate = DefaultValuesAtServer.GetExchangeRate(Currency, Date);
			EndIf;		
		EndIf;
		
		InitialDocumentBase = BaseDocumentBase;		
		If ValueIsNotFilled(BookkeepingOperationsTemplate) Then
			Result = BookkeepingCommon.GetRecommendSchemaForDocument(BaseDocumentBase, BookkeepingOperationsTemplate, False);
		Else
			// document is filled based on schema, so there is no need for lookup and it's only one given through filling
			Result = 1;
		EndIf;	
		If Result = 1 Then
			Description = BookkeepingOperationsTemplate.DescriptionForBookkeepingOperation;
			PartialJournal = BookkeepingOperationsTemplate.PartialJournal;
			BookkeepingOperationsTemplateObject = BookkeepingOperationsTemplate.GetObject();
			BookkeepingOperationsTemplateObject.FillBookkeepingDocument(DocumentBase, ThisObject);
			Manual = False;
		Else
			Manual = True;
		EndIf;	
		
	Else
		CommonAtServer.FillDocumentHeader(ThisObject);
		
		If Not ValueIsFilled(Currency) Then     
			Currency = DefaultValuesAtServer.GetNationalCurrency();
			ExchangeRate = DefaultValuesAtServer.GetExchangeRate(Currency, Date);
		EndIf;
		
		OperationType = Enums.OperationTypesBookkeepingOperation.Any;
		Manual = True;
	
	EndIf;	
	
	If ValueIsNotFilled(BookkeepingOperationsTemplate) Then
		Return;
	EndIf;	

	#If Client Then

		BookkeepingOperationsTemplatessList = RestoreValue("BookkeepingOperationsTemplatessList");

		If BookkeepingOperationsTemplatessList = Undefined Then
			BookkeepingOperationsTemplatessList = New ValueList; 
		Else

			Control = BookkeepingOperationsTemplatessList.FindByValue(Base);
			If Control <> Undefined Then
				BookkeepingOperationsTemplatessList.Delete(Control);
			EndIf;

		EndIf;

		BookkeepingOperationsTemplatessList.Insert(0, Base, String(Base));
		SaveValue("BookkeepingOperationsTemplatessList", BookkeepingOperationsTemplatessList);

	#EndIf

	// Parameters initialization
	Parameters = New Structure();
	For each Par In BookkeepingOperationsTemplate.Parameters Do
		Parameters.Insert(Par.Name, Par.Value);
	EndDo;
	
	RequestedParameters.Clear();
	BookkeepingOperationsTemplates = BookkeepingOperationsTemplate.Ref;
	
	If OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument Then
		
		TabularPartRow               = RequestedParameters.Add();
		TabularPartRow.Name           = "DocumentBase";
		TabularPartRow.Presentation = Nstr("en='Basis document';pl='Dokument podstawa';ru='Документ-основание'");
		TabularPartRow.Value      = DocumentBase;	
			
	Else
		
		For each Par In BookkeepingOperationsTemplate.Parameters Do
			
			If Par.NotRequest Then
				Continue
			EndIf;
			
			ParameterTypeDescription = Par.Type.Get();
			
			TabularPartRow               = RequestedParameters.Add();
			
			TabularPartRow.Name           = Par.Name;
			TabularPartRow.Presentation = Par.Presentation;
			TabularPartRow.Value      = ?(TypeOf(ParameterTypeDescription) = Type("TypeDescription"), ParameterTypeDescription.AdjustValue(Parameters[Par.Name]), Parameters[Par.Name]);
			
		EndDo;
		
	EndIf;

EndProcedure // Filling()

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	CheckedAttributes.Clear();	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	// WARNING!!! Calling of this function should be on begin of BeforeWrite function
	// Please, don't remove this call - it may cause damage in logic of configuration
	Common.GetObjectModificationFlag(ThisObject);
	
	DocumentPresentation = "";
	
	If AdditionalProperties.WasNew Then
		If ValueIsFilled(DocumentBase) Then
			DocumentPresentation = Alerts.ParametrizeString(Nstr("en = 'Bookkeeping operation for document: %P1'; pl = 'Dowód księgowy dla dokumentu: %P1'"), New Structure("P1", DocumentBase));
		EndIf;
	Else
		DocumentPresentation = String(ThisObject);
	EndIf;
	
	DocumentPresentation = DocumentPresentation + "." + Chars.LF;
	
	AdditionalProperties.Insert("DocumentPresentation", DocumentPresentation);
	
	Amount = Records.Total("AmountDr");
	
	InitialDocumentBase = Ref.DocumentBase;
	
	If OperationType = Enums.OperationTypesBookkeepingOperation.ClosePeriod
		And (Hour(Date) <> 23 Or Minute(Date) <> 59 Or Second(Date) < 50) Then
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'An error occurred during posting Bookkeeping operation for document %P1. Document should have one record in register ''BookkeepingPostedDocuments'''; pl = 'Nieprawidłowa godzina. Dla dokumentu %P1 zamknięcia okresu godzina powinna mieścić się w przedziale 23:59:50 do 23:59:59.'"), New Structure("P1", DocumentBase)), Enums.AlertType.Error, Cancel, ThisObject);
		Return;
	EndIf;
	
	If OperationType <> Enums.OperationTypesBookkeepingOperation.ClosePeriod Then
		If Hour(Date) = 23 AND Minute(Date) = 59 AND Second(Date) > 49 Then
			Date = EndOfDay(Date)-10;
		EndIf;	
	EndIf;	
	
	If OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument Then
		Privileged.BookkeepingOperationOnWriteProcessing(Ref,DocumentBase,Cancel);
		If ValueIsFilled(DocumentBase) Then
			If EndOfDay(Date) <> EndOfDay(DocumentBase.Date) Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'An warning occurred during posting Bookkeeping operation for document %P1. Base document and Bookkeeping operiation document should have the same date.'; pl = 'Daty dokumenu podstawy oraz dokumentu %P1 nie są zgodne.'"), New Structure("P1", Ref)), Enums.AlertType.Warning, Cancel, ThisObject);
			EndIf;
		EndIf;
	Else
		DocumentBase = Undefined;
	EndIf;	
	
	If BookkeepingOperationsTemplate.AlgorithmType = Enums.BookkeepingOperationTemplateAlgorithmTypes.BeforeWrite Then
		Execute(BookkeepingOperationsTemplate.AlgorithmText);
	EndIf;	
	
EndProcedure // BeforeWrite()

Procedure Posting(Cancel, PostingMode)
	
	// Check documents attributes filling
	AllAttributesValueTable = Alerts.AlertsExpandAttributesValueTable(Alerts.AlertReturnPredefinedAttributesValueTableByObject(ThisObject),GetAttributesValueTableForValidation(PostingMode));
	
	AllTabularPartsAttributesStructure = GetAttributesStructureForTabularPartsValidation(PostingMode);	
	
	Alerts.AlertDoCommonCheck(ThisObject,AllAttributesValueTable,AllTabularPartsAttributesStructure,Cancel);
	
	If Cancel Then
		Return;
	EndIf;	
	
	IsAutoLock = Undefined;
	AdditionalProperties.Property("IsAutoLock",IsAutoLock);
	IsManagedLock = (IsAutoLock = False);

	PostingAtServer.ClearRegisterRecordsForObject(ThisObject);
	
	Query = New Query;
	
	Query.Text = "SELECT
	             |	BookkeepingOperationRecords.LineNumber AS LineNumber,
	             |	BookkeepingOperationRecords.Account,
	             |	BookkeepingOperationRecords.Account.Quantity,
	             |	BookkeepingOperationRecords.Account.Currency,
	             |	BookkeepingOperationRecords.Quantity,
	             |	BookkeepingOperationRecords.Currency,
	             |	BookkeepingOperationRecords.CurrencyAmount,
	             |	BookkeepingOperationRecords.AmountDr,
	             |	BookkeepingOperationRecords.AmountCr,
	             |	BookkeepingOperationRecords.ExtDimension1,
	             |	BookkeepingOperationRecords.ExtDimension2,
	             |	BookkeepingOperationRecords.ExtDimension3,
	             |	BookkeepingOperationRecords.Description
	             |FROM
	             |	Document.BookkeepingOperation.Records AS BookkeepingOperationRecords
	             |WHERE
	             |	BookkeepingOperationRecords.Ref = &Ref
	             |
	             |ORDER BY
	             |	LineNumber
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	BookkeepingOperationSalesVATRecords.NetAmount,
	             |	BookkeepingOperationSalesVATRecords.VAT,
	             |	BookkeepingOperationSalesVATRecords.VATRate,
	             |	BookkeepingOperationSalesVATRecords.LineNumber,
	             |	BookkeepingOperationSalesVATRecords.NetAmount + BookkeepingOperationSalesVATRecords.VAT AS AmountBrutto,
	             |	BookkeepingOperationSalesVATRecords.Partner,
	             |	BookkeepingOperationSalesVATRecords.Document,
	             |	BookkeepingOperationSalesVATRecords.Period
	             |FROM
	             |	Document.BookkeepingOperation.SalesVATRecords AS BookkeepingOperationSalesVATRecords
	             |WHERE
	             |	BookkeepingOperationSalesVATRecords.Ref = &Ref
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	BookkeepingOperationPurchaseVATRecords.NetAmount,
	             |	BookkeepingOperationPurchaseVATRecords.VAT,
	             |	BookkeepingOperationPurchaseVATRecords.VATRate,
	             |	BookkeepingOperationPurchaseVATRecords.LineNumber,
	             |	BookkeepingOperationPurchaseVATRecords.NetAmount + BookkeepingOperationPurchaseVATRecords.VAT AS AmountBrutto,
	             |	BookkeepingOperationPurchaseVATRecords.Partner,
	             |	BookkeepingOperationPurchaseVATRecords.Document,
	             |	BookkeepingOperationPurchaseVATRecords.Period
	             |FROM
	             |	Document.BookkeepingOperation.PurchaseVATRecords AS BookkeepingOperationPurchaseVATRecords
	             |WHERE
	             |	BookkeepingOperationPurchaseVATRecords.Ref = &Ref";
	
	Query.SetParameter("Ref", Ref);
	TabSectionQueryResultArray = Query.ExecuteBatch();
	
	Selection = TabSectionQueryResultArray[0].Choose();
	
	If OperationType = Enums.OperationTypesBookkeepingOperation.ClosePeriod Then 
		RegisterRecords.Bookkeeping.SetProgramBookkeepingPostingClosePeriodFlag();
	EndIf;
	
	While Selection.Next() Do
		
		MessageTextBegin = NStr("en=""Tabular part 'Records', line number "";pl=""Część tabelaryczna 'Zapisy', numer linii """) + TrimAll(Selection.LineNumber) + ". ";
	
		If Selection.AmountDr <> 0 And Selection.AmountCr <> 0 Then
			Alerts.AddAlert(MessageTextBegin + NStr("en='Please, input only one Amount: Debit or Credit!';pl='Wprowadź tylko jedną kwotę: po stronie Winien lub Ma!'"), Enums.AlertType.Error, Cancel,ThisObject);
		EndIf;
		
		If Selection.AccountCurrency Then
			If Not ValueIsFilled(Selection.Currency) Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Please, fill currency!'; pl = 'Wybierz walutę!'"), Enums.AlertType.Error, Cancel,ThisObject);
			ElsIf Selection.Currency <> Currency Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Currency in the line is differ from the document!'; pl = 'Waluta wierszy różni sie od waluty dokumentu'"), Enums.AlertType.Warning, Cancel,ThisObject);
			ElsIf ExchangeRate <> 0 And (Selection.AmountDr + Selection.AmountCr) <> Round(Selection.CurrencyAmount*ExchangeRate, 2) Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Line amount in national currency is difference from the value calculated according to the document exchange rate. Default value:'; pl = 'Kwota kajowa w wierszy różni się od wartości wyliczonej po kursie dokumentu. Wartość domyślna:'") + " " + FormatAmount(Round(Selection.CurrencyAmount*ExchangeRate, 2)), Enums.AlertType.Warning, Cancel,ThisObject);
			EndIf;
		EndIf;
		
		Record = RegisterRecords.Bookkeeping.Add();
		
		If Selection.AmountDr <> 0 Then
			Record.RecordType = AccountingRecordType.Debit;
		Else
			Record.RecordType = AccountingRecordType.Credit;
		EndIf;
		
		Record.Period         = Date;
		Record.Company        = Company;
		Record.PartialJournal = PartialJournal;
		Record.Account        = Selection.Account;
		
		If Selection.AccountQuantity Then
			Record.Quantity = Selection.Quantity;
		EndIf;
		
		If Selection.AccountCurrency Then
			Record.Currency       = Selection.Currency;
			Record.CurrencyAmount = Selection.CurrencyAmount;
		EndIf;
		
		Record.Amount         = ?(Selection.AmountDr <> 0, Selection.AmountDr, Selection.AmountCr);
		Record.Description    = Selection.Description;
		
		// by Jack 30.03.2017 add begin
		//Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 1, Selection.ExtDimension1, , MessageTextBegin, AdditionalProperties.MessageTitle);
		//Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 2, Selection.ExtDimension2, , MessageTextBegin, AdditionalProperties.MessageTitle);
		//Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 3, Selection.ExtDimension3, , MessageTextBegin, AdditionalProperties.MessageTitle);
		Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 1, Selection.ExtDimension1, , MessageTextBegin, "AdditionalProperties.MessageTitle");
		Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 2, Selection.ExtDimension2, , MessageTextBegin, "AdditionalProperties.MessageTitle");
		Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 3, Selection.ExtDimension3, , MessageTextBegin, "AdditionalProperties.MessageTitle");
		
		RegisterRecords.Bookkeeping.Write = True;
		RegisterRecords.Bookkeeping.LockForUpdate = True;
		
	EndDo;
	
	If GroupRecords Then
		TableToGroup = RegisterRecords.Bookkeeping.Unload();
		TableToGroup.GroupBy("Account, Active, Company, Currency, Description, ExtDimension1, ExtDimension2, ExtDimension3, ExtDimensionType1, ExtDimensionType2, ExtDimensionType3, Period, PointInTime, RecordType, Recorder","Amount, AmountCr, AmountDr, CurrencyAmount, Quantity");
		RegisterRecords.Bookkeeping.Load(TableToGroup);
	EndIf;	
	
	// VAT Records posting
	Selection = TabSectionQueryResultArray[1].Choose();
	If NOT TabSectionQueryResultArray[1].IsEmpty() Then
		
		While Selection.Next() Do
			
			MessageTextBegin = NStr("en=""Tabular part 'Sales VAT records', line number "";pl=""Część tabelaryczna 'Zapisy VAT sprzedaży', numer linii """) + TrimAll(Selection.LineNumber) + ". ";
			
			If Selection.AmountBrutto= 0 Then
				
				Alerts.AddAlert(MessageTextBegin + NStr("en='Amount brutto could not be zero!';pl='Kwota brutto nie może wynosić zero!'"), Enums.AlertType.Warning, Cancel,ThisObject);
				
			EndIf;
			
			Record = RegisterRecords.VATRegisterSales.Add();
			Record.Company = Company;
			Record.Period = Selection.Period;
			Record.Document = Selection.Document;
			Record.VATRate = Selection.VATRate;
			Record.Customer = Selection.Partner;
			
			Record.NetAmount = Selection.NetAmount;
			Record.VAT = Selection.VAT;
			
			RegisterRecords.VATRegisterSales.Write = True;
			RegisterRecords.VATRegisterSales.LockForUpdate = True;
	
		EndDo;	
		
	EndIf;
	
	// VAT Records posting
	Selection = TabSectionQueryResultArray[2].Choose();
	If NOT TabSectionQueryResultArray[2].IsEmpty() Then
		
		While Selection.Next() Do
			
			MessageTextBegin = NStr("en=""Tabular part 'Purchase VAT records', line number "";pl=""Część tabelaryczna 'Zapisy VAT zakupu', numer linii """) + TrimAll(Selection.LineNumber) + ". ";
			
			If Selection.AmountBrutto= 0 Then
				
				Alerts.AddAlert(MessageTextBegin + NStr("en='Amount brutto could not be zero!';pl='Kwota brutto nie może wynosić zero!'"), Enums.AlertType.Warning, Cancel,ThisObject);
				
			EndIf;
			
			Record = RegisterRecords.VATRegisterPurchase.Add();
			Record.Company = Company;
			Record.Period = Selection.Period;
			Record.Document = Selection.Document;
			Record.VATRate = Selection.VATRate;
			Record.Supplier = Selection.Partner;
			
			Record.NetAmount = Selection.NetAmount;
			Record.VAT = Selection.VAT;
			
			RegisterRecords.VATRegisterPurchase.Write = True;
			RegisterRecords.VATRegisterPurchase.LockForUpdate = True;
			
		EndDo;
		
	EndIf;
	
	
	// Clear old document base data
	If ValueIsFilled(InitialDocumentBase) And InitialDocumentBase <> DocumentBase Then
		
		If IsManagedLock Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("InformationRegister.BookkeepingPostedDocuments");
			DataLockItem.Mode = DataLockMode.Exclusive;
			DataLockItem.SetValue("Document",InitialDocumentBase);
			DataLock.Lock();
		EndIf;
		
		RecordSet = InformationRegisters.BookkeepingPostedDocuments.CreateRecordSet();
		RecordSet.Filter.Document.Set(InitialDocumentBase);
		RecordSet.Read();
		
		If RecordSet.Count() = 1 Then
			
			Record = RecordSet[0];
			
			Record.Status = Enums.DocumentBookkeepingStatus.NotBookkeepingPosted;
			Record.Author = Undefined;
			Record.Comment = Undefined;
			RecordSet.SetProgramBookkeepingPostingFlag();
			RecordSet.Write();
			
		Else
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='An error occurred during posting Bookkeeping operation for document %P1. Document should be posted first!';pl='Powstał błąd podczas księgowania dowodu księgowego dla dokumentu %P1. Najperw dokument musi być zatwierdzony!'"),New Structure("P1",InitialDocumentBase)),Enums.AlertType.Error,Cancel,ThisObject);
		EndIf;
		
	EndIf;
	
	// Update document base data
	If ValueIsFilled(DocumentBase) Then
		
		If IsManagedLock Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("InformationRegister.BookkeepingPostedDocuments");
			DataLockItem.Mode = DataLockMode.Exclusive;
			DataLockItem.SetValue("Document",DocumentBase);
			DataLock.Lock();
		EndIf;

		RecordSet = InformationRegisters.BookkeepingPostedDocuments.CreateRecordSet();
		RecordSet.Filter.Document.Set(DocumentBase);
		RecordSet.Read();
		
		If RecordSet.Count() = 1 Then
			
			Record = RecordSet[0];
			
			If Record.Status = Enums.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='An error occurred during posting Bookkeeping operation for document %P1. Bookkeeping posting is not allowed for this document!';pl='Powstał błąd podczas księgowania dowodu księgowego dla dokumentu %P1. Dokument został oznaczony jak taki który się nie księguje!'"),New Structure("P1",DocumentBase)),Enums.AlertType.Error,Cancel,ThisObject);
			Else
				
				Record.Status = Enums.DocumentBookkeepingStatus.BookkeepingPosted;
				Record.Author = Undefined;
				Record.Comment = Undefined;
				RecordSet.SetProgramBookkeepingPostingFlag();
				RecordSet.Write();
				
			EndIf;
			
		Else
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='An error occurred during posting Bookkeeping operation for document %P1. Document should be posted first!';pl='Powstał błąd podczas księgowania dowodu księgowego dla dokumentu %P1. Najperw dokument musi być zatwierdzony!'"),New Structure("P1",DocumentBase)),Enums.AlertType.Error,Cancel,ThisObject);
		EndIf;
		
	EndIf;
	
	If OperationType = Enums.OperationTypesBookkeepingOperation.AnyWithRecordsGeneration Then
		APAR.GenerateAPARRecordsOnBookkeepingRecords(ThisObject,Records,Cancel);
	EndIf;	
		
EndProcedure

Procedure UndoPosting(Cancel)
	
	IsAutoLock = Undefined;
	AdditionalProperties.Property("IsAutoLock",IsAutoLock);
	IsManagedLock = (IsAutoLock = False);
	If ValueIsFilled(InitialDocumentBase) Then
		
		If IsManagedLock Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("InformationRegister.BookkeepingPostedDocuments");
			DataLockItem.Mode = DataLockMode.Exclusive;
			DataLockItem.SetValue("Document",InitialDocumentBase);
			DataLock.Lock();
		EndIf;
		
		RecordSet = InformationRegisters.BookkeepingPostedDocuments.CreateRecordSet();
		RecordSet.Filter.Document.Set(InitialDocumentBase);
		RecordSet.Read();
		
		If RecordSet.Count() > 0 Then
			
			Record = RecordSet[0];
			
			Record.Status = Enums.DocumentBookkeepingStatus.NotBookkeepingPosted;
			Record.Author = Undefined;
			Record.Comment = Undefined;
			RecordSet.SetProgramBookkeepingPostingFlag();
			RecordSet.Write();
			
		Else
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en=""An error occurred during posting Bookkeeping operation for document %P1. Document should have one record in register 'BookkeepingPostedDocuments'"";pl=""Powstał błąd podczas księgowania dowodu księgowego dla dokumentu %P1. Dokument musi mieć jeden zapis w rejestrze 'Zaksięgowane dokumenty'"""),New Structure("P1", DocumentBase)), Enums.AlertType.Error, Cancel, ThisObject);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES AND FUNCTIONS

Function GetAttributesValueTableForValidation(PostingMode) Export
	
	AttributesStructure = New Structure("Company, OperationType,Currency, ExchangeRate");
	If OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument Then
		AttributesStructure.Insert("DocumentBase");
	EndIf;	
	
	AttributesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	
	Return AttributesValueTable;
	
EndFunction

Function GetAttributesStructureForTabularPartsValidation(PostingMode) Export
	
	TabularPartsStructure = New Structure();
	
	AttributesStructure = New Structure("Account");
	RecordsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	TabularPartsStructure.Insert("Records", RecordsValueTable);
	
	AttributesStructure = New Structure("VATRate,Document,Partner");
	SalesVATRecordsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	TabularPartsStructure.Insert("SalesVATRecords", SalesVATRecordsValueTable);
	
	AttributesStructure = New Structure("VATRate,Document,Partner");
	PurchaseVATRecordsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	TabularPartsStructure.Insert("PurchaseVATRecords", PurchaseVATRecordsValueTable);
	
	Return TabularPartsStructure;
		
EndFunction

Procedure DocumentChecks(Cancel = Undefined) Export 
	
	TotalAmountDr = 0;
	TotalAmountCr = 0;
	For Each Record In Records Do
		
		If NOT Record.Account.OffBalance Then
			
			TotalAmountDr = TotalAmountDr + Record.AmountDr;
			TotalAmountCr = TotalAmountCr + Record.AmountCr;
			
		EndIf;	
		
	EndDo;	
	
	If TotalAmountDr <> TotalAmountCr Then
		Alerts.AddAlert(Alerts.ParametrizeString(NStr("en='Total Debit and Credit amounts are not equal! Difference is: %P1';pl='Kwoty łączne po stronach Winien i Ma nie są sobie równe! Różnica wynosi: %P1'"),New Structure("P1",FormatAmount(TotalAmountDr - TotalAmountCr))), Enums.AlertType.Error,Cancel,ThisObject);
	EndIf;
	
	If Records.Count() = 0 AND SalesVATRecords.Count() = 0 AND PurchaseVATRecords.Count() = 0 Then
		Alerts.AddAlert(NStr("en='Please, input data to the table Records or Sales VAT records or Purchase VAT records!';pl='Wprowadź do tabeli Zapisy lub Zapisy VAT sprzedaży lub Zapisy VAT zakupu!'"), Enums.AlertType.Error, Cancel,ThisObject);
	EndIf;	
	
EndProcedure

Procedure DocumentChecksTabularPart(Cancel = Undefined) Export 
	
	
EndProcedure

Procedure FillingOnDocumentBaseAndTemplate(DocumentBaseRef, TemplateRef) Export
	
	If ValueIsFilled(TemplateRef) Then
		
		BookkeepingOperationsTemplate = TemplateRef;
		OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument;
		Description = BookkeepingOperationsTemplate.DescriptionForBookkeepingOperation;
		PartialJournal = BookkeepingOperationsTemplate.PartialJournal;
		Manual = False;
		
		// Parameters initialization
		Parameters = New Structure();
		For each Par In BookkeepingOperationsTemplate.Parameters Do
			Parameters.Insert(Par.Name, Par.Value);
		EndDo;
		
		RequestedParameters.Clear();
		BookkeepingOperationsTemplates = BookkeepingOperationsTemplate.Ref;
		
		If OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument Then
			
			TabularPartRow               = RequestedParameters.Add();
			TabularPartRow.Name           = "DocumentBase";
			TabularPartRow.Presentation = Nstr("en='Basis document';pl='Dokument podstawa';ru='Документ-основание'");
			TabularPartRow.Value      = DocumentBase;	
				
		Else
			
			For each Par In BookkeepingOperationsTemplate.Parameters Do
				
				If Par.NotRequest Then
					Continue
				EndIf;
				
				ParameterTypeDescription = Par.Type.Get();
				
				TabularPartRow               = RequestedParameters.Add();
				
				TabularPartRow.Name           = Par.Name;
				TabularPartRow.Presentation = Par.Presentation;
				TabularPartRow.Value      = ?(TypeOf(ParameterTypeDescription) = Type("TypeDescription"), ParameterTypeDescription.AdjustValue(Parameters[Par.Name]), Parameters[Par.Name]);
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(DocumentBaseRef) Then
		
		Date = DocumentBaseRef.Date;
		If Hour(Date) = 23 AND Minute(Date) = 59 AND Second(Date) > 49 Then
			Date = EndOfDay(Date)-10;
		EndIf;	
		Company = DocumentBaseRef.Company;
		DocumentBase = DocumentBaseRef;
		FillCurrencyAndExchangeRateOnDocumentBase();
		
	EndIf;	
	
EndProcedure

Procedure FillCurrencyAndExchangeRateOnDocumentBase() Export
	
	DocumentBaseMetadata = DocumentBase.Metadata();
	If CommonAtServer.IsDocumentAttribute("Currency",DocumentBaseMetadata) Then
		Currency = DocumentBase.Currency;
	// Jack 25.06.2017
	//ElsIf CommonAtServer.IsDocumentAttribute("SettlementCurrency",DocumentBaseMetadata) Then	
	//	Currency = DocumentBase.SettlementCurrency;
	//ElsIf CommonAtServer.IsDocumentAttribute("RecordsCurrency",DocumentBaseMetadata) Then		
	//	Currency = DocumentBase.RecordsCurrency;
	Else
		Currency = DefaultValuesAtServer.GetNationalCurrency();
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("ExchangeRate",DocumentBaseMetadata) Then
		ExchangeRate = DocumentBase.ExchangeRate;
	// Jack 25.06.2017
	//ElsIf CommonAtServer.IsDocumentAttribute("SettlementExchangeRate",DocumentBaseMetadata) Then	
	//	ExchangeRate = DocumentBase.SettlementExchangeRate;
	//ElsIf CommonAtServer.IsDocumentAttribute("RecordsExchangeRate",DocumentBaseMetadata) Then		
	//	ExchangeRate = DocumentBase.RecordsExchangeRate;
	Else
		ExchangeRate = DefaultValuesAtServer.GetExchangeRate(Currency,CurrentDate());
	EndIf;

EndProcedure	



