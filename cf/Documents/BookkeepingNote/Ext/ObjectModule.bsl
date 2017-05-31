////////////////////////////////////////////////////////////////////////////////
// VARIABLES OF THE OBJECT MODULE
Var IsNationalCurrency;

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENTS PROCESSING OF THE OBJECT

Procedure OnCopy(CopiedObject)
	
	For Each Row In Payments Do
		
		Row.Document = Undefined;
		
	EndDo;	

EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	// WARNING!!! Calling of this function should be on begin of BeforeWrite function
	// Please, don't remove this call - it may cause damage in logic of configuration
	Common.GetObjectModificationFlag(ThisObject);
	
	If OperationType = Enums.OperationTypesBookkeepingNote.Positive Then
		Query = New Query();
		Query.Text = "SELECT
		|	SalesInvoicePayments.Document AS Document,
		|	SalesInvoicePayments.Document.Posted AS Posted
		|FROM
		|	Document.SalesInvoice.Payments AS SalesInvoicePayments
		|WHERE
		|	SalesInvoicePayments.Ref = &Ref";
		Query.SetParameter("Ref",Ref);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			If ValueIsFilled(Selection.Document) AND Selection.Posted = TRUE Then
				
				Try
					Object = Selection.Document.GetObject();
					Object.Write(DocumentWriteMode.UndoPosting);
				Except
					
					Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='This document could not be unposted while document %P1 is posted!';pl='Nie można wykonać anulowania zatwierdzenia dokumentu dopóki jest zatwierdzony dokument %P1!';ru='Нельзя отменить проведение документа, пока существует проведенный документ %P1!'"),New Structure("P1",Selection.Document)),Enums.AlertType.Error,Cancel,ThisObject);
					
				EndTry;
				
			EndIf;	
			
		EndDo;	
	Else
		Payments.Clear();
	EndIF;
	
	AmountsStructure = GetDocumentTotalAmounts();
	Amount = AmountsStructure.RecordsAmount;
	
	AmountNational = Amount*ExchangeRate;
	
	For Each PaymentRow In Payments Do
		
		MessageTextBegin = NStr("en=""Tabular part 'Payments', line number "";pl=""Część tabelaryczna 'Zapłaty', numer linii "";ru=""Табличная часть 'Оплата', номер строки""") + TrimAll(PaymentRow.LineNumber) + ". ";
		
		If PaymentRow.PaymentMethod.TransactionType = Enums.PaymentTransactionTypes.Cash Then
			
			If ValueIsNotFilled(PaymentRow.Document) Then
				Object = Undefined;
			Else
				
				Try
					Object = PaymentRow.Document.GetObject();
				Except
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(Nstr("en='Could not get object from reference %P1!';pl='Nie udało się pobrać obiektu z referencji %P1!';ru='Не удалось выбрать объект со ссылкой %P1!'"),New Structure("P1",PaymentRow.Document)),Enums.AlertType.Error,Cancel,ThisObject);
					Break;
				EndTry;
				
			EndIf;
			
			
			If Object = Undefined Then
				
				Object = Documents.CashIncomingFromPartner.CreateDocument();
				
			Else
				
				Try
					Object = PaymentRow.Document.GetObject();
				Except
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(Nstr("en='Could not get object from reference %P1!';pl='Nie udało się pobrać obiektu z referencji %P1!';ru='Не удалось выбрать объект со ссылкой %P1!'"),New Structure("P1",PaymentRow.Document)),Enums.AlertType.Error,Cancel,ThisObject);
					Break;
				EndTry;
				
			EndIf;	
			
			If Object <> Undefined Then
				
				Object = FillPaymentDocument(Object,PaymentRow.CashDesk, PaymentRow.Amount);
				Try
					Object.Write(WriteMode,PostingMode);
				Except
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(Nstr("en='Could not post document object from reference %P1!';pl='Nie udało się zaksięgować dokumentu z referencji %P1!';ru='Не удалось провести документ со ссылкой %P1!'"),New Structure("P1",Object.Ref)),Enums.AlertType.Error,Cancel,ThisObject);
					Break;
				EndTry;	
				
				PaymentRow.Document = Object.Ref;
				
			EndIf;
			
		EndIf;
		
	EndDo;
		
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	IsNationalCurrency = (Currency = Constants.NationalCurrency.Get());
	
	AllAttributesValueTable = Alerts.AlertsExpandAttributesValueTable(Alerts.AlertReturnPredefinedAttributesValueTableByObject(ThisObject),GetAttributesValueTableForValidation(PostingMode));
	AllTabularPartsAttributesStructure = GetAttributesStructureForTabularPartsValidation(PostingMode);	
	
	Alerts.AlertDoCommonCheck(ThisObject,AllAttributesValueTable,AllTabularPartsAttributesStructure,Cancel);
				
	If Cancel Then
		Return;
	EndIf;
										
	PaymentsLinesQuery = New Query("SELECT
	                               |	BookkeepingNotePayments.LineNumber,
	                               |	BookkeepingNotePayments.Amount,
	                               |	BookkeepingNotePayments.Document,
	                               |	BookkeepingNotePayments.PaymentMethod,
	                               |	BookkeepingNotePayments.PaymentMethod.TransactionType AS TransactionType,
	                               |	BookkeepingNotePayments.PaymentMethod.Partner AS Partner
	                               |FROM
	                               |	Document.BookkeepingNote.Payments AS BookkeepingNotePayments
	                               |WHERE
	                               |	BookkeepingNotePayments.Ref = &Ref");
	
									 
	BatchQueryParameters = New Structure("Ref",Ref);
	BatchQuery = BatchQueries.CreateBatchQuery();
	BatchQueries.AddQuery(BatchQuery,"PaymentsLinesQuery",PaymentsLinesQuery);	
	
	QueryResultStructure = BatchQueries.ExecuteBatchQuery(BatchQuery, BatchQueryParameters);
	
	PayedStructure = PostingPayments(QueryResultStructure.PaymentsLinesQuery.Select(), Cancel, PostingMode);

	APAR.PostAccountPayableReceivable(ABS(Amount - PayedStructure.TotalPayedAmount),
									ABS(AmountNational - PayedStructure.TotalPayedAmountNational),
									APAR.GetPartnerForPaymentMethod(PaymentMethod,Customer),
									?(OperationType = Enums.OperationTypesBookkeepingNote.Positive,AccumulationRecordType.Receipt,AccumulationRecordType.Expense),
									Enums.PartnerSettlementTypes.CustomerSettlement,
									Currency,
									,
									Ref,
									ThisObject,
									Cancel);

	
	CheckOverdueDues(Cancel);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ADDITIONAL POSTING PROCEDURES

Function PostingPayments(Selection, Cancel, PostingMode)
	
	TotalAmount = 0;
	TotalAmountNational = 0;
	While Selection.Next() Do
		
		MessageTextBegin = Alerts.ParametrizeString(NStr("en=""Tabular part 'Payments', line number %P1."";pl=""Część tabelaryczna 'Zapłaty', numer linii %P1."";ru=""Табличная часть 'Оплаты', номер строки %P1."""),New Structure("P1",TrimAll(Selection.LineNumber)));
		CurrentNationalAmount = CommonAtServer.GetNationalAmount(Selection.Amount,Currency,ExchangeRate);
		APAR.PostAccountPayableReceivable(Selection.Amount,
											CurrentNationalAmount,
											APAR.GetPartnerForPaymentMethod(Selection.PaymentMethod,Customer),
											AccumulationRecordType.Receipt,
											?(APAR.IsPaymentTransactionTypeWithPartner(Selection.TransactionType),Enums.PartnerSettlementTypes.CustomerSettlement,Enums.PartnerSettlementTypes.PrepaymentFromCustomer),
											Currency,
											Undefined,
											?(ValueIsFilled(Selection.Document),Selection.Document,Ref),
											ThisObject,
											Cancel);
											
		
		TotalAmount = TotalAmount + Selection.Amount;
		TotalAmountNational = TotalAmountNational + CurrentNationalAmount;	
		
	EndDo;
	
	Return New Structure("TotalPayedAmount,TotalPayedAmountNational",TotalAmount,TotalAmountNational);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES

Procedure CheckOverdueDues(Cancel)
	
	If Customer.BlockOnOverdueDue Then
		
		Due = APAR.GetCustomerOverdueDue(Company,Customer);
		If Due>0 AND Due>Customer.MaxOverdueDueAmount Then
			
			NationalCurrency = Constants.NationalCurrency.Get();
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='Delivery can not be created. Customer has overdrawn the limit of overdue dues! Overdrawing: %P1; Limit: %P2!';pl='Wydanie nie może być stworzone. Klient przekroczil limit przeterminowanych należności! Przeterminowane należności: %P1; Dopuszczalny limit: %P2!';ru='Документ отгрузки товаров покупателю нельзя создать. Покупатель превысил лимит кредиторской задолженности! Кредиторская задолженность: %P1; Установленный лимит: %P2!'"),New Structure("P1, P2",FormatAmount(Due,NationalCurrency),FormatAmount(Customer.MaxOverdueDueAmount,NationalCurrency))),Enums.AlertType.Error,Cancel,ThisObject);
			
		EndIf;	
	EndIf;	
	
EndProcedure	

Function FillPaymentDocument(Object,CashDesk,Amount) Export
	
	If ValueIsFilled(CashDesk) Then
		
		Object.Company = Company;
		Object.Partner = Customer;
		Object.CashDesk = CashDesk;
		Object.Author = Author;
		Object.OperationType = Enums.OperationTypesAccountsIncoming.FromCustomer;
		Object.SettlementCurrency = Currency;
		Object.SettlementExchangeRate = ExchangeRate;
		Object.ExchangeRate = CommonAtServer.GetExchangeRate(CashDesk.Currency, Date);
		Object.SettlementAmount = Amount;
		Object.SettlementPrepaymentAmount = Object.SettlementAmount;
		Object.Amount = Object.SettlementAmount*Object.SettlementExchangeRate/Object.ExchangeRate;
		Object.AutoNationalAmountsCalculation = True;	
		If Object.Date = '00010101000000' Then
			Object.Number = "";
		EndIf;	
		Object.Date = Date;
		Object.Comment = "Dokument został stworzony automatycznie dla faktury " + Ref + ". Ręczne zmiany będą ignorowane!";	
		Object.ReservedPrepayments.Clear();
		Object.SettlementDocuments.Clear();
		
	EndIf;
	
	Return Object;
	
EndFunction	

Function GetAvailablePaymentTransactionTypes() Export
	
	ValueList = New ValueList();
	ValueList.Add(Enums.PaymentTransactionTypes.Cash);
	ValueList.Add(Enums.PaymentTransactionTypes.PaymentCard);
	ValueList.Add(Enums.PaymentTransactionTypes.PaymentOnDelivery);
	ValueList.Add(Enums.PaymentTransactionTypes.BankCredit);
	Return ValueList;
	
EndFunction	

Function IsInAvailablePaymentTransactionType(TransactionType) Export
	
	Return (TransactionType = Enums.PaymentTransactionTypes.Cash 
		OR TransactionType = Enums.PaymentTransactionTypes.PaymentCard 
		OR TransactionType = Enums.PaymentTransactionTypes.PaymentOnDelivery 
		OR TransactionType = Enums.PaymentTransactionTypes.BankCredit);
	
EndFunction	

Function GetDocumentTotalAmounts() Export
		
	AmountsStructure = New Structure();
	RecordsAmount = Records.Total("Amount");
	AmountsStructure.Insert("RecordsAmount",RecordsAmount);
	PaymentsAmount = Payments.Total("Amount");
	AmountsStructure.Insert("PaymentsAmount",PaymentsAmount);
	
	Return AmountsStructure;
	
EndFunction	

Procedure CheckRecordAmount(Record,RecordMessage = "",Cancel = False, ThisForm = Undefined) Export
	
	If Record.Amount > 0 AND OperationType = Enums.OperationTypesBookkeepingNote.Negative Then
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = '%P0 Only negative amount is allowed when %P1 operation type is selected!'; pl = '%P0 Dozwolone są tylko ujemne kwoty o ile został wybrany typ operacji %P1!'"),New Structure("P0, P1",RecordMessage,OperationType)),Enums.AlertType.Error,Cancel,ThisObject,ThisForm);
	ElsIf Record.Amount < 0 AND OperationType = Enums.OperationTypesBookkeepingNote.Positive Then	
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = '%P0 Only positive amount is allowed when %P1 operation type is selected!'; pl = '%P0 Dozwolone są tylko dodatnie kwoty o ile został wybrany typ operacji %P1!'"),New Structure("P0, P1",RecordMessage,OperationType)),Enums.AlertType.Error,Cancel,ThisObject,ThisForm);
	EndIf;	
	
EndProcedure	

Function GetAttributesValueTableForValidation(PostingMode) Export
	
	
	AttributesStructure = New Structure("Company, DeliveryPoint, Customer, Currency, ExchangeRate, PaymentDate, PaymentMethod, OperationType");		
	AttributesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	
	Return AttributesValueTable;
	
EndFunction

Function GetAttributesStructureForTabularPartsValidation(PostingMode) Export
	
	
	TabularPartsStructure = New Structure();
	
	AttributesStructure = New Structure("Account, Description, Amount");
	RecordsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	RecordsValueTable = Alerts.AddAttributesValueTableRow(RecordsValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Error);
	
	TabularPartsStructure.Insert("Records",RecordsValueTable);
	
	AttributesStructure = New Structure("PaymentMethod, Amount");
	PaymentsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	PaymentsValueTable = Alerts.AddAttributesValueTableRow(PaymentsValueTable, "PaymentMethod, Document,CashDesk",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
	
	TabularPartsStructure.Insert("Payments",PaymentsValueTable);
	
		
	Return TabularPartsStructure;
	
EndFunction	

Function DocumentChecks(Cancel = Undefined) Export 
	
	If Customer.CustomerType <> Enums.CustomerTypes.Independent And ValueIsFilled(Customer) Then
		Alerts.AddAlert(NStr("en=""Choosen customer could not be used as customer. Please, check attribute 'Customer type'. It should be set to 'Independent'"";pl=""Nie można używać wybranego nabywcy. Sprawdź czy klient ma ustawiony atrubyt 'Typ klientu' o wartości 'Niezależny'"";ru=""Нельзя выбрать данного покупателя. Проверьте, если у покупателя значение поля 'Тип покупателя' установлено как 'Головная организация'"""),Enums.AlertType.Error,Cancel,ThisObject);
	EndIf;
	
	If ValueIsFilled(Customer) Then
		
		// There is no base for this document
		If Alerts.IsNotEqualValue(Currency, Customer.Currency) Then
			Alerts.AddAlert(NStr("en='Currency in the document is not equal to the customer!';pl='Waluta w dokumencie różni się od wartości nabywcy!';ru='Валюта, указанная в документе, не соответствует значению по умолчанию для покупателя!'") + " " + String(Customer.Currency) + " " + NStr("en='in the customer!';pl='u nabywcy!';ru='у покупателя!'"),Enums.AlertType.Warning,Cancel,ThisObject);
		EndIf;
		
		If Alerts.IsNotEqualValue(PaymentMethod, Customer.PaymentMethod) Then
			Alerts.AddAlert(NStr("en='Payment method in the document is not equal to the customer!';pl='Sposób płatności w dokumencie różni się od wartości u nabywcy!';ru='Способ оплаты, указанный в документе, не соответствует значению по умолчанию для покупателя!'") + " " + String(Customer.PaymentMethod) + " " + NStr("en='in the customer!';pl='u nabywcy!';ru='у покупателя!'"),Enums.AlertType.Warning,Cancel,ThisObject);
		EndIf;
		
		If Alerts.IsNotEqualValue(PaymentTerms, Customer.PaymentTerms) Then
			Alerts.AddAlert(NStr("en='Payment terms in the document is not equal to the customer!';pl='Termin płatności w dokumencie różni się od wartości u nabywcy!';ru='Срок оплаты в документе и основной срок оплаты на карточке покупателя не совпадают!'") + " " + String(Customer.PaymentTerms) + " " + NStr("en='in the customer!';pl='u nabywcy!';ru='у покупателя!'"),Enums.AlertType.Warning,Cancel, ThisObject);
		EndIf;	
		
		If Alerts.IsNotEqualValue(ExchangeRate, CommonAtServer.GetExchangeRate(Currency, Date)) Then
			Alerts.AddAlert(NStr("en='Exchange rate in the document is not equal to the default value:';pl='Kurs w dokumencie różni się od wartości domyślnej:';ru='Обменный курс, указанный в документе, не соответствует значению по умолчанию:'") + " " + String(CommonAtServer.GetExchangeRate(Currency, Date)),Enums.AlertType.Warning,Cancel,ThisObject);
		EndIf;
		
		If Alerts.IsNotEqualValue(PaymentDate, CommonAtServer.GetPaymentDate(Date, PaymentTerms)) Then
			Alerts.AddAlert(NStr("en='Payment date in the document is not equal to the default value:';pl='Data zapłaty w dokumencie różni się od wartości domyślnej:';ru='Дата оплаты, указанная в документе, не соответствует значению по умолчанию:'") + " " + String(CommonAtServer.GetPaymentDate(Date, PaymentTerms)),Enums.AlertType.Warning,Cancel,ThisObject);
		EndIf;
		
		DefaultDeliveryPoint = Catalogs.Customers.GetCustomerDeliveryPoint(Customer, Catalogs.Customers.EmptyRef());
		If (DefaultDeliveryPoint.IsEmpty() And DeliveryPoint.HeadOffice <> Customer)
			Or (Not DefaultDeliveryPoint.IsEmpty() And DeliveryPoint <> DefaultDeliveryPoint) Then
			Alerts.AddAlert(NStr("en='Head office of choosen delivery point is not equal to customer choosen in document!';pl='Centrala wybranego odbiorcy w dokumencie różni się od nabywcy!';ru='Головные организации, к которым относятся указанный покупатель и получатель не совпадают!'") ,Enums.AlertType.Warning,Cancel,ThisObject);
		EndIf;
		
	EndIf;
	
	If OperationType = Enums.OperationTypesBookkeepingNote.Positive Then
		PaymentsTotal = Payments.Total("Amount");
	
		If PaymentsTotal > Records.Total("Amount") Then
			Alerts.AddAlert( NStr("en = 'Total amount of payments is greater than amount of document! Total amount of payments:'; pl = 'Lączna kwota zapłat jest większa niż kwota dokumentu! Lączna kwota zapłat:'") + " " + FormatAmount(PaymentsTotal), Enums.AlertType.Error, Cancel, ThisObject);
		EndIf;
	EndIf;	
	
EndFunction	

Function DocumentChecksTabularPart(Cancel = Undefined) Export 
	
	If OperationType = Enums.OperationTypesBookkeepingNote.Positive Then
		TabularPartPresentation = ThisObject.Metadata().TabularSections.Payments.Presentation();
		
		Query = New Query();
		
		Query.Text = "SELECT
		|	SalesInvoicePayments.PaymentMethod.TransactionType AS TransactionType,
		|	SalesInvoicePayments.LineNumber,
		|	SalesInvoicePayments.CashDesk AS CashDesk
		|FROM
		|	Document.SalesInvoice.Payments AS SalesInvoicePayments
		|WHERE
		|	SalesInvoicePayments.Ref = &Ref";
		Query.SetParameter("Ref",Ref);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do	
			
			MessageTextBegin = NStr("en=""Tabular part '"";pl=""Część tabelaryczna '"";ru=""Табличная часть '""") + TabularPartPresentation + NStr("en=""', line number "";pl=""', numer wiersza "";ru=""', номер строки """) + TrimAll(Selection.LineNumber) + ". ";
			If Selection.TransactionType = Enums.PaymentTransactionTypes.Cash 
				AND ValueIsNotFilled(Selection.CashDesk) Then
				
				Alerts.AddAlert(MessageTextBegin + NStr("en=""For payment method with transaction type 'Cash' Cashdesk should be selected!"";pl=""Dla sposóbu płatności z typem transakcji 'Kasa'  Kasa powinna być wybrana!"";ru=""Необходимо указать кассу для выбранного типа оплаты 'Наличный расчет'!"""),Enums.AlertType.Error,Cancel,ThisObject);
				
			EndIf;	
			
			If NOT IsInAvailablePaymentTransactionType(Selection.TransactionType) Then
				Alerts.AddAlert(MessageTextBegin + NStr("en='Current payment method could not be selected, because transaction type of this payment method is not supported!';pl='Bieżący sposób płatności nie może być wybrany, dlatego że typ transakcji sposobu płatności nie jest wspierany!';ru='Для данного типа транзакции текущий способ оплаты не поддерживается и не может быть использован!'"),Enums.AlertType.Error,Cancel,ThisObject);
			EndIf;	
			
		EndDo;	
	EndIf;
	
	TabularPartPresentation = ThisObject.Metadata().TabularSections.Records.Presentation();
	For Each Record In Records Do
		
		MessageTextBegin = NStr("en=""Tabular part '"";pl=""Część tabelaryczna '"";ru=""Табличная часть '""") + TabularPartPresentation + NStr("en=""', line number "";pl=""', numer wiersza "";ru=""', номер строки """) + TrimAll(Record.LineNumber) + ". ";
		CheckRecordAmount(Record,MessageTextBegin,Cancel,ThisObject);
		
	EndDo;	
	
EndFunction	

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	CheckedAttributes.Clear();
EndProcedure

Procedure Filling(Base)
	
	If Base = Undefined Then 
		CommonAtServer.FillDocumentHeader(ThisObject);
		OperationType = Enums.OperationTypesBookkeepingNote.Positive;
		If Not ValueIsFilled(Currency) Then
			Currency = Constants.NationalCurrency.Get();
			ExchangeRate = CommonAtServer.GetExchangeRate(Currency, Date);
		EndIf;
	EndIf;
EndProcedure

