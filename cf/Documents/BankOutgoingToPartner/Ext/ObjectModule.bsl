// Jack 29.05.2017
//Var CurrencyBankAccount;

//////////////////////////////////////////////////////////////////////////////////
//// PROCEDURES - EVENTS PROCESSING OF THE OBJECT

//Procedure Filling(Base)
//	FillAsUndefined	= False;
//	
//	If TypeOf(Base) = Type("Structure") Then
//		DocumentBase = Undefined;
//		If Base.Property("Base", DocumentBase) Then
//			Base = DocumentBase;
//		EndIf;
//		
//		FillAsUndefined	= True;		
//	EndIf;
//	If TypeOf(Base) = Type("DocumentRef.PurchaseInvoice") Then
//		
//		Company = Base.Company;
//		OperationType = Enums.OperationTypesAccountsOutgoing.ForSupplier;
//		Date = Max(GetServerDate() - 24*60*60, Base.Date);
//		
//		Partner = Base.Supplier;
//		SettlementCurrency = Base.Currency;
//		SettlementExchangeRate = CommonAtServer.GetExchangeRate(SettlementCurrency, Date);
//		
//		BankAccount = Company.DefaultBankAccount;
//		ExchangeRate = CommonAtServer.GetExchangeRate(BankAccount.Currency, Date);
//		
//		
//		SettlementDocumentsRow = SettlementDocuments.Add();
//		SettlementDocumentsRow.Partner = Base.Supplier;
//		SettlementDocumentsRow.Document = Base;
//		SettlementDocumentsRow.PrepaymentSettlement = Enums.PrepaymentSettlement.Settlement;
//		
//		Structure = APAR.GetDocumentAmountsStructureForPartner(SettlementDocumentsRow.Partner, SettlementDocumentsRow.Document, , SettlementCurrency, , Company);
//		
//		SettlementDocumentsRow.AmountDr = Structure.AmountDr;
//		SettlementDocumentsRow.AmountDrNational = Structure.AmountDrNational;
//		SettlementDocumentsRow.AmountCr = Structure.AmountCr;
//		SettlementDocumentsRow.AmountCrNational = Structure.AmountCrNational;
//		
//		SettlementAmount = SettlementDocumentsRow.AmountDr;
//		
//		If ExchangeRate <> 0 Then
//			Amount = SettlementAmount*SettlementExchangeRate/ExchangeRate;
//		EndIf;
//		
//	ElsIf TypeOf(Base) = Type("DocumentRef.PurchaseOrder") Then	
//		PurchaseOrderRef = Base;

//		FillPropertyValues(ThisObject, PurchaseOrderRef,,"Number, ExchangeRate");
//		Date = Max(GetServerDate() - 24*60*60, PurchaseOrderRef.Date);

//		Query = New Query;
//		Query.Text = "SELECT
//		             |	PaymentMetodDetails.Account
//		             |FROM
//		             |	InformationRegister.PaymentMetodDetails AS PaymentMetodDetails
//		             |WHERE
//		             |	PaymentMetodDetails.PaymentMetod = &PaymentMethod
//		             |	AND PaymentMetodDetails.Company = &Company";
//		
//		Query.SetParameter("PaymentMethod", PurchaseOrderRef.PaymentMethod);
//		Query.SetParameter("Company", Company);
//		
//		Result = Query.Execute();
//		SelectionBank = Result.Select();
//		
//		If SelectionBank.Next() Then
//			BankAccount = SelectionBank.Account;
//			ExchangeRate = CommonAtServer.GetExchangeRate(BankAccount.Currency, Date);
//		EndIf;
//		
//		SettlementCurrency = PurchaseOrderRef.Currency;
//		SettlementExchangeRate = CommonAtServer.GetExchangeRate(SettlementCurrency, Date);
//		Partner = PurchaseOrderRef.Supplier;
//		OperationType = Enums.OperationTypesAccountsOutgoing.ForSupplier;
//		SettlementPrepaymentAmount = PurchaseOrderRef.Amount;
//		Amount = ?(ExchangeRate = 0, 0, PurchaseOrderRef.Amount * SettlementExchangeRate / ExchangeRate);
//		SettlementAmount = PurchaseOrderRef.Amount;
//		
//		NewRowDoc = ReservedPrepayments.Add();
//		NewRowDoc.ReservationDocument = PurchaseOrderRef;
//		NewRowDoc.AmountDr = SettlementAmount;
//		NewRowDoc.AmountDrNational = ?(ExchangeRate = 0, 0, SettlementAmount * SettlementExchangeRate / ExchangeRate);
//	ElsIf TypeOf(Base) = Type("DocumentRef.PreStatementBank") Then		
//		ManagedBankAtClientAtServer.FillingBankOutgoing(ThisObject, Base);	
//	ElsIf Base = Undefined OR FillAsUndefined Then
//		CommonAtServer.FillDocumentHeader(ThisObject);
//		OperationType = Enums.OperationTypesAccountsOutgoing.ForSupplier;
//		If ValueIsFilled(Company) Then
//			BankAccount = Company.DefaultBankAccount;
//			If ValueIsFilled(BankAccount) Then
//				ExchangeRate = CommonAtServer.GetExchangeRate(BankAccount.Currency, Date);
//				SettlementCurrency = BankAccount.Currency;
//				SettlementExchangeRate = ExchangeRate;
//			EndIf;
//		EndIf;
//		
//		If TypeOf(Base) = Type("Structure") Then
//			
//			if Base.Property("BankAccount") Then
//				
//				BankAccount = Base.BankAccount;
//				
//			EndIf;
//			
//		EndIf;
//		
//	EndIf;
//	
//EndProcedure

//Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
//	
//	// WARNING!!! Calling of this function should be on begin of BeforeWrite function
//	// Please, don't remove this call - it may cause damage in logic of configuration
//	Common.GetObjectModificationFlag(ThisObject);
//	
//	NationalCurrency = Constants.NationalCurrency.Get();
//	
//	If ValueIsNotFilled(InitialDocumentDate) Then
//		InitialDocumentDate = Date;
//	EndIf;
//	
//	If SettlementCurrency = NationalCurrency Then
//		AutoNationalAmountsCalculation = True;
//	EndIf;
//	
//	If OperationType <> Enums.OperationTypesAccountsOutgoing.ForSupplier 
//		AND OperationType <> Enums.OperationTypesAccountsOutgoing.ForEmployee
//		AND ReservedPrepayments.Count()>0 Then
//		
//		ReservedPrepayments.Clear();
//		
//	EndIf;
//	
//	If OperationType = Enums.OperationTypesAccountsOutgoing.Other Then
//		SettlementPrepaymentAmount = 0;
//		For Each Record In Records Do
//			Record.AmountCrNational = Record.AmountCr * SettlementExchangeRate;
//			Record.AmountDrNational = Record.AmountDr * SettlementExchangeRate;
//		EndDo;
//		SettlementDocuments.Clear();
//		ReservedPrepayments.Clear();
//		SettlementAmount = Records.Total("AmountDr") - Records.Total("AmountCr");
//	ElsIf OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
//		
//	Else
//		Records.Clear();
//	EndIf;
//	
//	If WriteMode = DocumentWriteMode.Posting Then
//		
//		If ManualExchangeRate Then
//			AmountNational = Amount*ExchangeRate;
//		Else	
//			If PostingMode = DocumentPostingMode.Regular Then
//				ExchangeRateDate = Date;
//			Else	
//				ExchangeRateDate = CurrentDate();
//			EndIf;
//			CostingMethod = BankCash.GetCostingMethodOnDate(Date, Company);
//			If CostingMethod = Enums.GoodsCostingMethods.FIFO Or CostingMethod = Enums.GoodsCostingMethods.LIFO Then
//				ExchangeRate = CommonAtServer.GetExchangeRate(BankAccount.Currency, BegOfDay(Date) - 1);
//				AmountNational = ExchangeRate * Amount;
//			Else
//				AmountNational = BankCash.GetBankNationalAmountAccordingToAverageExchangeRate(Amount, BankAccount.Currency, ExchangeRateDate, BankAccount, Company);
//				If ValueIsNotFilled(AmountNational) Then
//					Alerts.AddAlert(NStr("en=""Can't calculate national amount according to the average exchange rate. Set exchange rate manually or check bank operation sequence!"";pl='Nie można wyliczyć kwotę w walucie krajowej wg kursu średniego. Ustaw kurs ręcznie albo sprawdź sekwencje operacji bankowych.';ru='Невозможно рассчитать сумму в национальной валюте по среднему курсу. Укажите обменный курс вручную или проверьте последовательность банковских операций.'"), Enums.AlertType.Error, Cancel,ThisObject);
//					Return;
//				EndIf;
//				ExchangeRate = AmountNational/Amount;
//			EndIf;
//			
//			If BankAccount.Currency = SettlementCurrency Then
//				SettlementExchangeRate = ExchangeRate;
//			EndIf;	
//			
//		EndIf;
//		
//		If AutoNationalAmountsCalculation Then
//			APAR.AutoNationalAmountsRecalculate(ThisObject, "SettlementDocuments");
//			APAR.AutoNationalAmountsRecalculate(ThisObject, "ReservedPrepayments");
//		EndIf;	
//			
//	EndIf;
//	
//EndProcedure

//Procedure Posting(Cancel, PostingMode)
//	
//	/// Check documents attributes filling
//	AllAttributesValueTable = Alerts.AlertsExpandAttributesValueTable(Alerts.AlertReturnPredefinedAttributesValueTableByObject(ThisObject),GetAttributesValueTableForValidation(PostingMode));
//	AllTabularPartsAttributesStructure = GetAttributesStructureForTabularPartsValidation(PostingMode);	
//	
//	Alerts.AlertDoCommonCheck(ThisObject,AllAttributesValueTable,AllTabularPartsAttributesStructure,Cancel);
//		
//	If Cancel Then
//		Return;
//	EndIf;
//	
//	BankAmount = BankCash.CheckBankOrCashAmount(Company, BankAccount, BankAccount.Currency);
//	If BankAmount <= 0 Then
//		Alerts.AddAlert(NStr("en='Insufficient funds on the bank account in order to make payment. Current amount of the bank account: ';pl='Brak środków na koncie bankowym aby dokonać wypłatę. Bieżąca kwota konta bankowego: ';ru='Недостаточное количество денежных средств на банковском счете для проведения оплаты. Текущий остаток денежных средств на банковском счете: '") + " " + Format(BankAmount, "ND=15; NFD=2"), Enums.AlertType.Warning, Cancel,ThisObject);
//	ElsIf BankAmount < Amount Then
//		Alerts.AddAlert(NStr("en='The amount in the bank account is insufficient for covering the payment. Available amount: ';pl='Kwota na rachunku bankowym kasie jest niewystarczająca do pokrycia wypłaty. Dostępna kwota: ';ru='Суммы денежных средств на банковском счете недостаточно для проведения оплаты. Доступная сумма: '") + " " + Format(BankAmount, "ND=15; NFD=2"), Enums.AlertType.Warning, Cancel,ThisObject);
//	EndIf;	
//	
//	BankCash.PostBank(ThisObject,Cancel,BankAccount,Amount,AmountNational,AccumulationRecordType.Expense);
//	If Not OperationType = Enums.OperationTypesAccountsOutgoing.Other Then
//		SettlementPrepaymentAmountToPost = SettlementPrepaymentAmount - ReservedPrepayments.Total("AmountDr");
//		If SettlementPrepaymentAmountToPost > 0 Then
//			SettlementPrepaymentAmountNationalToPost = 0;
//			SettlementPrepaymentAmountNationalToPost = CommonAtServer.GetNationalAmount(SettlementPrepaymentAmountToPost,SettlementCurrency,SettlementExchangeRate);
//			If OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
//				APAR.PostAccountPayableReceivable(SettlementPrepaymentAmountToPost,
//												SettlementPrepaymentAmountNationalToPost,
//												Partner,
//												AccumulationRecordType.Receipt,
//												Enums.EmployeeSettlementTypes.PrepaymentToEmployee,
//												SettlementCurrency,
//												,
//												Ref,
//												ThisObject,
//												Cancel,
//												PaymentMethod);
//			Else
//				APAR.PostAccountPayableReceivable(SettlementPrepaymentAmountToPost,
//												SettlementPrepaymentAmountNationalToPost,
//												Partner,
//												AccumulationRecordType.Receipt,
//												?(OperationType = Enums.OperationTypesAccountsOutgoing.ForCustomer,Enums.PartnerSettlementTypes.PrepaymentFromCustomer,Enums.PartnerSettlementTypes.PrepaymentToSupplier),
//												SettlementCurrency,
//												,
//												Ref,
//												ThisObject,
//												Cancel);
//			EndIf;
//		EndIf;	
//		
//		If OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
//			APAR.PostSettlementEmployeeDocuments(ThisObject,Cancel,PostingMode);
//			APAR.PostEmployeeReservedPrepayments(ThisObject,Cancel,PostingMode);
//		Else
//			APAR.PostSettlementDocuments(ThisObject,Cancel,PostingMode);
//			APAR.PostReservedPrepayments(ThisObject,Cancel,PostingMode);
//		EndIf;
//	EndIf;	
//	APAR.PostCashFlowTurnovers(Amount, AmountNational, BankAccount.Currency, ThisObject, AccumulationRecordType.Expense, Cancel);
//	
//EndProcedure

//////////////////////////////////////////////////////////////////////////////////
//// OTHER PROCEDURES

//Function GetAttributesValueTableForValidation(PostingMode) Export
//	
//	If OperationType = Enums.OperationTypesAccountsOutgoing.Other Then
//		AttributesStructure = New Structure("Company, OperationType, BankAccount, Amount, AmountNational, ExchangeRate, SettlementCurrency, SettlementExchangeRate, SettlementAmount");
//	Else
//		AttributesStructure = New Structure("Company, OperationType, Partner, BankAccount, Amount, AmountNational, ExchangeRate, SettlementCurrency, SettlementExchangeRate, SettlementAmount");
//	EndIf;
//	AttributesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
//	
//	Return AttributesValueTable;
//	
//EndFunction

//Function GetAttributesStructureForTabularPartsValidation(PostingMode) Export
//	
//	TabularPartsStructure = New Structure();
//	
//	AttributesStructure = New Structure("Partner, Document,PrepaymentSettlement");
//	
//	SettlementDocumentsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
//	SettlementDocumentsValueTable = Alerts.AddAttributesValueTableRow(SettlementDocumentsValueTable,"Partner, Document,PrepaymentSettlement,ReservationDocument",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
//	
//	TabularPartsStructure.Insert("SettlementDocuments",SettlementDocumentsValueTable);

//	AttributesStructure = New Structure("ReservationDocument,AmountDr");
//	If NOT AutoNationalAmountsCalculation Then
//		AttributesStructure.Insert("AmountDrNational");
//	EndIf;	
//	
//	ReservedPrepaymentsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
//	ReservedPrepaymentsValueTable = Alerts.AddAttributesValueTableRow(ReservedPrepaymentsValueTable,"ReservationDocument",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
//	
//	TabularPartsStructure.Insert("ReservedPrepayments",ReservedPrepaymentsValueTable);
//	
//	Return TabularPartsStructure;
//	
//EndFunction

//Function DocumentChecks(Cancel = Undefined) Export 
//	
//	If BankAccount.Currency = SettlementCurrency
//		AND Amount <> SettlementAmount AND OperationType <> Enums.OperationTypesAccountsOutgoing.Other Then
//		Alerts.AddAlert(Nstr("en=""Amount and settlement amount should be the same when bank account currency and settlement's currency are the same."";pl='Kwota oraz kwota rozrachunków powinne być takie same o ile takie same są waluta rachunku bankowego oraz waluta rozrachunków';ru='Сумма и сумма взаиморасчетов должны быть одинаковые, в случае, если валюта банковского счета и валюта взаиморасчетов совпадают'"),Enums.AlertType.Error,Cancel,ThisObject);
//	Else
//		TmpSettlementAmount = Round(Amount*ExchangeRate/SettlementExchangeRate,2);
//		If ABS(SettlementAmount - TmpSettlementAmount)>0.05 Then
//			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='Awaited settlement amount is %P1 calculated due to entered exchange rates.';pl='Oczekiwana kwota rozrachunków to %P1 wg wyliczeń na podstawie podanych kursów wymiany.';ru='Ожидаемая сумма взаиморасчетов %P1 была рассчитана на основании указанных обменных курсов.'"),New Structure("P1",TmpSettlementAmount)),Enums.AlertType.Warning,Cancel,ThisObject);	
//		EndIf;	
//	EndIf;	

//	// RED ALERTS
//	
//	If (Not (OperationType = Enums.OperationTypesAccountsOutgoing.ForSupplier 
//		Or OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee))
//		AND ValueIsFilled(SettlementPrepaymentAmount) Then
//		
//		//Alerts.AddAlert(NStr("en=""Prepayment can be done only for operation type 'For supplier'"";pl=""Zaliczka może być zrobiona jedynie dla typu operacji 'Dla dostawcy'"";ru=""Аванс можно оформить только с указанным типом операции 'Поставщику'"""),Enums.AlertType.Error,Cancel,ThisObject);
//		
//	EndIf;	
//	
//	If TypeOf(Partner) = TypeOf(Catalogs.Customers.EmptyRef()) 
//		AND Partner.CustomerType <> Enums.CustomerTypes.Independent
//		AND ValueIsFilled(Partner) Then
//		Alerts.AddAlert(NStr("en=""Choosen customer could not be used as partner. Please, check attribute 'Customer type'. It should be set to 'Independent'"";pl=""Nie można używać wybranego klienta jako kontrahent. Sprawdź czy klient ma ustawiony atrubyt 'Typ klienta' o wartości 'Niezależny'"";ru=""Нельзя указать выбранного покупателя в качестве контрагента. Проверьте, если у покупателя значение поля 'Тип покупателя' установлено как 'Головная организация'"""),Enums.AlertType.Error,Cancel,ThisObject);
//	EndIf;
//	
//	If SettlementAmount  - SettlementPrepaymentAmount<> SettlementDocuments.Total("AmountDr") - SettlementDocuments.Total("AmountCr") And OperationType <> Enums.OperationTypesAccountsOutgoing.Other Then
//		Alerts.AddAlert(NStr("en='Differences between ""Settlement amount"" and ""Prepayment amount"" should be equal to differences between ""Amount Dr"" and ""Amount Cr"" of the tabular section!';pl='Różnica pomiędzy ""Kwotą rozrachunków"" a ""Kwotą zaliczki"" powinna być równa różnicy pomiędzy ""Kwotą Wn"" a ""Kwotą Ma"" w części tabelarycznej!';ru='Разница между ""Сумма взаиморасчетов"" и ""Сумма аванса"" должна соответствовать разнице между ""Сумма Дт"" и ""Сумма Кт"" в табличной части!'"), Enums.AlertType.Error, Cancel,ThisObject);
//	EndIf;
//	
//	If SettlementPrepaymentAmount< ReservedPrepayments.Total("AmountDr") And OperationType <> Enums.OperationTypesAccountsOutgoing.Other Then
//		Alerts.AddAlert(Alerts.ParametrizeString(NStr("en='Amount of reserved prepayments could not be greater than prepayment amount. Prepayment amount: %P1!';pl='Kwota zarezerwowanych zaliczek nie może być większa od kwoty zaliczek. Kwota zaliczek: %P1!';ru='Сумма зарезервированных авансов не может превышать сумму авансов. Сумма авансов: %P1!'"),New Structure("P1",FormatAmount(SettlementPrepaymentAmount,SettlementCurrency))), Enums.AlertType.Error, Cancel,ThisObject);
//	EndIf;
//	
//	// YELLOW ALERTS
//	TempSettlementExchangeRate = CommonAtServer.GetExchangeRate(SettlementCurrency, Date);
//	If Alerts.IsNotEqualValue(SettlementExchangeRate, TempSettlementExchangeRate) 
//		AND (ManualExchangeRate OR (BankAccount.Currency = SettlementCurrency 
//		AND Alerts.IsNotEqualValue(ExchangeRate, SettlementExchangeRate))) Then
//		Alerts.AddAlert(NStr("en='Settlement exchange rate in the document is not equal to the default value:';pl='Kurs rozrachunków w dokumencie różni się od wartości domyślnej:';ru='Курс валюты взаиморасчетов, указанный в документе, не соответствует значению по умолчанию:'") + " " + Format(TempSettlementExchangeRate, "NFD=9"), Enums.AlertType.Warning, Cancel,ThisObject);
//	EndIf;
//	
//	TempExchangeRate = CommonAtServer.GetExchangeRate(BankAccount.Currency, Date);
//	If Alerts.IsNotEqualValue(ExchangeRate, TempExchangeRate) 
//		AND ManualExchangeRate Then
//		Alerts.AddAlert(NStr("en='Payment exchange rate in the document is not equal to the default value:';pl='Kurs waluty rachunku w dokumencie różni się od wartości domyślnej:';ru='Курс валюты оплаты, указанный в документе, не соответствует значению по умолчанию:'") + " " + Format(TempExchangeRate, "NFD=9"), Enums.AlertType.Warning, Cancel,ThisObject);
//	EndIf;
//	
//EndFunction

//Function DocumentChecksTabularPart(Cancel = Undefined) Export 

//EndFunction

//Procedure SetCurrencyBankAccount(BankAccountCurrency) Export
//	CurrencyBankAccount = BankAccountCurrency;
//EndProcedure

//Procedure FillCheckProcessing(Cancel, CheckedAttributes)
//	CheckedAttributes.Clear();
//EndProcedure
