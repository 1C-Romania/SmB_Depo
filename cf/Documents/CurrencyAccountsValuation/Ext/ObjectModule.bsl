
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENTS PROCESSING OF THE OBJECT

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	// WARNING!!! Calling of this function should be on begin of BeforeWrite function
	// Please, don't remove this call - it may cause damage in logic of configuration
	Common.GetObjectModificationFlag(ThisObject);
		
	Amount = Valuation.Total("ValuationAmount");
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DocumentsPostingAndNumbering.CheckPostingPermission(ThisObject, Cancel, AdditionalProperties.MessageTitle);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Check documents attributes filling
	AllAttributesValueTable = Alerts.AlertsExpandAttributesValueTable(Alerts.AlertReturnPredefinedAttributesValueTableByObject(ThisObject),GetAttributesValueTableForValidation(PostingMode));
	AllTabularPartsAttributesStructure = GetAttributesStructureForTabularPartsValidation(PostingMode);
	
	Alerts.AlertDoCommonCheck(ThisObject,AllAttributesValueTable,AllTabularPartsAttributesStructure,Cancel);

	
	If Cancel Then
		Return;
	EndIf;
	
	PostingAtServer.ClearRegisterRecordsForObject(ThisObject);
	
	DayOfNextMonth = EndOfMonth(Date) + 1;
	
	// Accounting policy
	AccountingPolicy = New Structure();
	AccountingPolicy.Insert("NegativeInGroup", CommonAtServer.GetExchangeRateDifferencePolicy(Date, Company, -1, False, True) );
	AccountingPolicy.Insert("NegativeOutsideGroup", CommonAtServer.GetExchangeRateDifferencePolicy(Date, Company, -1, False, False) );
	AccountingPolicy.Insert("PositiveInGroup", CommonAtServer.GetExchangeRateDifferencePolicy(Date, Company, 1, False, True) );
	AccountingPolicy.Insert("PositiveOutsideGroup", CommonAtServer.GetExchangeRateDifferencePolicy(Date, Company, 1, False, False) );
	
	// go on with posting
	Query = New Query("SELECT
	                  |	CASE
	                  |		WHEN AmountDuesValuationAccounts.Account_Valuation = &EmptyAccount
	                  |			THEN AmountDuesValuationValuation.Account_AmountDue
	                  |		ELSE AmountDuesValuationAccounts.Account_Valuation
	                  |	END AS Account_Valuation,
	                  |	AmountDuesValuationValuation.ExtDimension1,
	                  |	AmountDuesValuationValuation.ExtDimension2,
	                  |	AmountDuesValuationValuation.ExtDimension3,
	                  |	AmountDuesValuationValuation.ValuationAmount,
	                  |	AmountDuesValuationValuation.IsDocument,
	                  |	AmountDuesValuationValuation.Currency
	                  |FROM
	                  |	Document.CurrencyAccountsValuation.Valuation AS AmountDuesValuationValuation
	                  |		LEFT JOIN Document.CurrencyAccountsValuation.Accounts AS AmountDuesValuationAccounts
	                  |		ON AmountDuesValuationValuation.Account_AmountDue = AmountDuesValuationAccounts.Account_AmountDue
	                  |WHERE
	                  |	AmountDuesValuationAccounts.Ref = &Ref
	                  |	AND AmountDuesValuationValuation.Ref = &Ref");
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("EmptyAccount", ChartsOfAccounts.Bookkeeping.EmptyRef());
	QueryResult = Query.Execute().Select();
	
	While QueryResult.Next() Do
		// Jack 25.06.2017
		// to do
		PartnerInGroup = False;
		//If TypeOf(QueryResult.ExtDimension1) = TypeOf(Catalogs.Employees.EmptyRef()) Then
		//	PartnerInGroup = True;
		//ElsIf TypeOf(QueryResult.ExtDimension1) = TypeOf(Catalogs.Customers.EmptyRef()) Or
		//	TypeOf(QueryResult.ExtDimension1) = TypeOf(Catalogs.Suppliers.EmptyRef()) Then
		//	PartnerInGroup = QueryResult.ExtDimension1.AccountingGroup.Affiliate;
		//Else
		//	PartnerInGroup = False;
		//EndIf;

		PostItem(Date, PartnerInGroup, AccountingPolicy, QueryResult, Cancel);
		PostItem(DayOfNextMonth, PartnerInGroup, AccountingPolicy, QueryResult, Cancel);
		
		If Cancel Then
			Return;
		EndIf;
	EndDo;
	

EndProcedure

Procedure UndoPosting(Cancel)
	
	
	DocumentsPostingAndNumbering.CheckUndoPostingPermission(ThisObject, Cancel, AdditionalProperties.MessageTitle);
	If Cancel Then
		Return;
	EndIf;
	
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)  	
		
	CommonAtServer.FillDocumentHeader(ThisObject);
	
	Date = BegOfDay(BegOfMonth(CurrentDate()) - 1);
	
	FillAccounts();
	FillExchangeRates();



EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	CheckedAttributes.Clear();    
EndProcedure 
////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES

Function GetAttributesValueTableForValidation(PostingMode) Export
	
	AttributesStructure = New Structure("Company, Amount");
	AttributesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	Return AttributesValueTable;
	
EndFunction	

Function GetAttributesStructureForTabularPartsValidation(PostingMode) Export
	
	TabularPartsStructure = New Structure();
	
	// Accounts
	AttributesStructure = New Structure("Account_AmountDue");
	ItemsLinesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	ItemsLinesValueTable = Alerts.AddAttributesValueTableRow(ItemsLinesValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Error);
	ItemsLinesValueTable = Alerts.AddAttributesValueTableRow(ItemsLinesValueTable,"Account_AmountDue",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
	TabularPartsStructure.Insert("Accounts",ItemsLinesValueTable);
	
	// ExchangeRates
	AttributesStructure = New Structure("Currency, ExchangeRate");
	ItemsLinesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	ItemsLinesValueTable = Alerts.AddAttributesValueTableRow(ItemsLinesValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Error);
	ItemsLinesValueTable = Alerts.AddAttributesValueTableRow(ItemsLinesValueTable,"Currency",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
	TabularPartsStructure.Insert("ExchangeRates",ItemsLinesValueTable);
	
	// Valuation
	AttributesStructure = New Structure("Account_AmountDue,Currency,ExchangeRate,Amount,AmountNational,ValuationAmount");
	ItemsLinesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,,Enums.AlertType.Error);
	ItemsLinesValueTable = Alerts.AddAttributesValueTableRow(ItemsLinesValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Error);
	ItemsLinesValueTable = Alerts.AddAttributesValueTableRow(ItemsLinesValueTable,"Account_AmountDue, ExtDimension1, ExtDimension2, ExtDimension3, Currency",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
	TabularPartsStructure.Insert("Valuation",ItemsLinesValueTable);
	
	Return TabularPartsStructure;
	
EndFunction	

Function DocumentChecks(AlertsTable, Cancel = Undefined) Export 
	
	If Day(Date) <> Day(EndOfMonth(Date)) Then
		Alerts.AddAlert( NStr("en = 'Amount dues valuation document shall be posted in last day of month!'; pl = 'Dokument wyceny należności powinien być księgowany ostatniego dnia miesiąca!'"), Enums.AlertType.Warning,Cancel, ThisObject);
	EndIf;
	
	Return AlertsTable;
	
EndFunction

Function DocumentChecksTabularPart(AlertsTable, Cancel = Undefined) Export 
	
	Return AlertsTable;
	
EndFunction


Procedure FillValuation() Export
	Valuation.Clear();
	
	Query = New Query("SELECT
	                  |	BookkeepingBalance.Account AS Account,
	                  |	BookkeepingBalance.ExtDimension1 AS ExtDimension1,
	                  |	BookkeepingBalance.ExtDimension2 AS ExtDimension2,
	                  |	BookkeepingBalance.ExtDimension3 AS ExtDimension3,
	                  |	BookkeepingBalance.Currency AS Currency,
	                  |	BookkeepingBalance.AmountBalance AS AmountBalance,
	                  |	BookkeepingBalance.CurrencyAmountBalance AS CurrencyAmountBalance,
	                  |	BookkeepingBalance.ExtDimension1.ExchangeRate AS Extension1ExchangeRate,
	                  |	BookkeepingBalance.ExtDimension2.ExchangeRate AS Extension2ExchangeRate,
	                  |	BookkeepingBalance.ExtDimension3.ExchangeRate AS Extension3ExchangeRate,
	                  |	BookkeepingBalance.ExtDimension1.Date AS Extension1PostingDate,
	                  |	BookkeepingBalance.ExtDimension2.Date AS Extension2PostingDate,
	                  |	BookkeepingBalance.ExtDimension3.Date AS Extension3PostingDate,
	                  |	BookkeepingBalance.AmountBalance / BookkeepingBalance.CurrencyAmountBalance AS AverageExchangeRate,
	                  |	AmountDuesValuationExchangeRates.ExchangeRate AS ExchangeRate,
	                  |	(BookkeepingBalance.CurrencyAmountBalance * AmountDuesValuationExchangeRates.ExchangeRate) - BookkeepingBalance.AmountBalance AS Valuation
	                  |FROM
	                  |	AccountingRegister.Bookkeeping.Balance(
	                  |			&Date,
	                  |			Account IN
	                  |				(SELECT
	                  |					AmountDuesValuationAccounts.Account_AmountDue
	                  |				FROM
	                  |					Document.CurrencyAccountsValuation.Accounts AS AmountDuesValuationAccounts
	                  |				WHERE
	                  |					AmountDuesValuationAccounts.Ref = &Ref
	                  |					AND AmountDuesValuationAccounts.UseAccount),
	                  |			,
	                  |			Company = &Company
	                  |				AND Currency <> &NationalCurrency) AS BookkeepingBalance
	                  |		FULL JOIN Document.CurrencyAccountsValuation.ExchangeRates AS AmountDuesValuationExchangeRates
	                  |		ON BookkeepingBalance.Currency = AmountDuesValuationExchangeRates.Currency
	                  |WHERE
	                  |	BookkeepingBalance.AmountBalance <> 0
	                  |	AND BookkeepingBalance.CurrencyAmountBalance <> 0
	                  |	AND AmountDuesValuationExchangeRates.Ref = &Ref
	                  |	AND BookkeepingBalance.AmountBalance <> BookkeepingBalance.CurrencyAmountBalance * AmountDuesValuationExchangeRates.ExchangeRate
	                  |
	                  |ORDER BY
	                  |	Account,
	                  |	ExtDimension1,
	                  |	ExtDimension2,
	                  |	ExtDimension3");

	Query.SetParameter("Date", New Boundary(Date, BoundaryType.Including));
	Query.SetParameter("Company", Company);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("NationalCurrency", Constants.NationalCurrency.Get());
	
	QueryResult = Query.Execute().Select();
	While QueryResult.Next() Do
		NewItem = Valuation.Add();
		NewItem.Account_AmountDue = QueryResult.Account;
		NewItem.Amount = QueryResult.CurrencyAmountBalance;
		NewItem.AmountNational = QueryResult.AmountBalance;
		NewItem.ExtDimension1 = QueryResult.ExtDimension1;
		NewItem.ExtDimension2 = QueryResult.ExtDimension2;
		NewItem.ExtDimension3 = QueryResult.ExtDimension3;
		NewItem.Currency = QueryResult.Currency;
		NewItem.ValuationAmount = Round(QueryResult.Valuation,2);
		
		// is it a document? get exchange rate
		If ValueIsFilled(QueryResult.Extension1ExchangeRate) Then
			NewItem.IsDocument = True;
			NewItem.ExchangeRate = QueryResult.Extension1ExchangeRate;
			NewItem.PostingDate = QueryResult.Extension1PostingDate;
		ElsIf ValueIsFilled(QueryResult.Extension2ExchangeRate) Then
			NewItem.IsDocument = True;
			NewItem.ExchangeRate = QueryResult.Extension2ExchangeRate;
			NewItem.PostingDate = QueryResult.Extension2PostingDate;
		ElsIf ValueIsFilled(QueryResult.Extension3ExchangeRate) Then
			NewItem.IsDocument = True;
			NewItem.ExchangeRate = QueryResult.Extension3ExchangeRate;
			NewItem.PostingDate = QueryResult.Extension3PostingDate;
		Else
			NewItem.IsDocument = False;
			NewItem.ExchangeRate = Round(QueryResult.AverageExchangeRate,9);
		EndIf;
		
		// find posting date
		If NewItem.IsDocument And Not ValueIsFilled(NewItem.PostingDate) Then
			SubQuery = New Query("SELECT
			                     |	BookkeepingRecordsWithExtDimensions.Period AS Period
			                     |FROM
			                     |	AccountingRegister.Bookkeeping.RecordsWithExtDimensions(
			                     |			,
			                     |			&Date,
			                     |			Account = &Account
			                     |				AND Company = &Company
			                     |				AND ExtDimension1 = &ExtDimension1
			                     |				AND ExtDimension2 = &ExtDimension2) AS BookkeepingRecordsWithExtDimensions
			                     |
			                     |ORDER BY
			                     |	Period DESC");
			SubQuery.SetParameter("Date",Date);
			SubQuery.SetParameter("Account",QueryResult.Account);
			SubQuery.SetParameter("Company",Company);
			SubQuery.SetParameter("ExtDimension1",QueryResult.ExtDimension1);
			SubQuery.SetParameter("ExtDimension2",QueryResult.ExtDimension2);
			SubQueryResult = SubQuery.Execute().Select();
			If SubQueryResult.Next() Then
				NewItem.PostingDate = SubQueryResult.Period;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

Procedure FillExchangeRates() Export
	ExchangeRates.Clear();
	
	Query = New Query("SELECT
	                  |	CurrencyExchangeRatesSliceLast.Currency,
	                  |	CurrencyExchangeRatesSliceLast.ExchangeRate
	                  |FROM
	                  |	InformationRegister.CurrencyExchangeRates.SliceLast(&Date, ) AS CurrencyExchangeRatesSliceLast");
	Query.SetParameter("Date", Date);
	
	QueryResult = Query.Execute().Select();
	While QueryResult.Next() Do
		NewItem = ExchangeRates.Add();
		NewItem.Currency = QueryResult.Currency;
		NewItem.ExchangeRate = QueryResult.ExchangeRate;
	EndDo;
EndProcedure

Procedure FillAccounts() Export
	Accounts.Clear();
	
	Query = New Query("SELECT
	                  |	BookkeepingAccountingPolicyValuationOfAmountDuesSliceLast.Account_AmountDue AS Account_AmountDue,
	                  |	BookkeepingAccountingPolicyValuationOfAmountDuesSliceLast.Account_Valuation AS Account_Valuation,
	                  |	BookkeepingAccountingPolicyValuationOfAmountDuesSliceLast.UseAccount AS UseAccount,
	                  |	BookkeepingAccountingPolicyValuationOfAmountDuesSliceLast.Account_AmountDue.Code AS Account_AmountDueCode
	                  |FROM
	                  |	InformationRegister.BookkeepingAccountingPolicyValuationOfAmountDues.SliceLast(&Date, Company = &Company) AS BookkeepingAccountingPolicyValuationOfAmountDuesSliceLast
	                  |
	                  |ORDER BY
	                  |	Account_AmountDueCode");
	Query.SetParameter("Date", Date);
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute().Select();
	While QueryResult.Next() Do
		NewItem = Accounts.Add();
		NewItem.UseAccount = QueryResult.UseAccount;
		NewItem.Account_AmountDue = QueryResult.Account_AmountDue;
		NewItem.Account_Valuation = QueryResult.Account_Valuation;
	EndDo;
EndProcedure


Procedure PostItem( PostDate, PartnerInGroup, AccountingPolicy, QueryResult, Cancel )
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	// exchange rate difference
	MessageTextBegin = NStr("en="" Account 'Exchange rate differences' "";pl="" Konto 'Rozliczenie różnic kursowych'""");
	Record = RegisterRecords.Bookkeeping.Add();
	RegisterRecords.Bookkeeping.Write = True;
	RegisterRecords.Bookkeeping.LockForUpdate = True;

	If QueryResult.ValuationAmount < 0 Then
		Record.RecordType = AccountingRecordType.Debit;
		SelAccountingPolicy = ?(PartnerInGroup, AccountingPolicy.NegativeInGroup, AccountingPolicy.NegativeOutsideGroup);
	Else 
		Record.RecordType = AccountingRecordType.Credit;
		SelAccountingPolicy = ?(PartnerInGroup, AccountingPolicy.PositiveInGroup, AccountingPolicy.PositiveOutsideGroup);
	EndIf;	
	
	If SelAccountingPolicy = Undefined Then
		TmpStr = NStr("en='Accounting policy for posting exchange rate differences was not found! (Not carried out, %1, %2)';pl='Nie znaleziono polityki rachunkowości dla zaksięgowania różnicy kursowej! (Niezrealizowana, %1, %2)'");
		TmpStr = StrReplace(TmpStr, "%1", ?(QueryResult.ValuationAmount < 0, NStr("en='Negative';pl='Ujemna';ru='Отрицательная'"), NStr("en='Positive';pl='Dodatnia';ru='Положительная'")) );
		TmpStr = StrReplace(TmpStr, "%2", ?(PartnerInGroup, NStr("en = 'In group'; pl = 'W grupie'"), NStr("en = 'Outside group'; pl = 'Poza grupą'")) );
		Common.ErrorMessage(TmpStr, Cancel);
		Return;
	EndIf;
	
	Record.Account = SelAccountingPolicy.Account;
	Record.Period = PostDate;
	Record.Company = Company;
	Record.PartialJournal = PartialJournal;
	Record.Amount = ?(Month(PostDate) = Month(Date), ABS(QueryResult.ValuationAmount), -ABS(QueryResult.ValuationAmount));
	Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 1, SelAccountingPolicy.ExtDimension1, , MessageTextBegin, AdditionalProperties.MessageTitle);
	Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 2, SelAccountingPolicy.ExtDimension2, , MessageTextBegin, AdditionalProperties.MessageTitle);
	Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 3, SelAccountingPolicy.ExtDimension3, , MessageTextBegin, AdditionalProperties.MessageTitle);
	If Record.Account.Currency Then
		Record.Currency = NationalCurrency;
		Record.CurrencyAmount = Record.Amount;
	EndIf;	
	
	// valuation
	MessageTextBegin = NStr("en="" Account of valuation "";pl="" Konto wyceny""");
	Record = RegisterRecords.Bookkeeping.Add();
	Record.RecordType = ?(QueryResult.ValuationAmount < 0, AccountingRecordType.Credit, AccountingRecordType.Debit);
	Record.Account = QueryResult.Account_Valuation;
	Record.Period = PostDate;
	Record.Company = Company;
	Record.PartialJournal = PartialJournal;
	Record.Amount = ?(Month(PostDate) = Month(Date), ABS(QueryResult.ValuationAmount), -ABS(QueryResult.ValuationAmount));
	If Record.Account.Currency Then
		Record.Currency = QueryResult.Currency;
	EndIf;
	Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 1, QueryResult.ExtDimension1, , MessageTextBegin, AdditionalProperties.MessageTitle);
	Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 2, QueryResult.ExtDimension2, , MessageTextBegin, AdditionalProperties.MessageTitle);
	Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 3, QueryResult.ExtDimension3, , MessageTextBegin, AdditionalProperties.MessageTitle);
	
EndProcedure

