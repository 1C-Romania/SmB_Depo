
Procedure SetExtDimension(Account, ExtDimensions, ExtDimensionName, ExtDimensionValue, DoMessages = False, MessageTextBegin = "", Title = "") Export
	
	If Account = Undefined Or Account.IsEmpty() Then
		Return;
	EndIf;
	
	If TypeOf(ExtDimensionName) = Type("Number") Then
		
		If ExtDimensionName > Account.ExtDimensionTypes.Count() Then
			Return;
		EndIf;
		
		ExtDimensionType = Account.ExtDimensionTypes[ExtDimensionName - 1].ExtDimensionType;
		
	Else
		
		ExtDimensionType = ChartsOfCharacteristicTypes.BookkeepingExtDimensions[ExtDimensionName];
		
		If Account.ExtDimensionTypes.Find(ExtDimensionType) = Undefined Then
			
			If DoMessages Then
				MessageText = NStr("en = 'Extra dimension type %P1 for account %P2 doesn''t define.'; pl = 'Typ analityki %P1 dla konta %P2 nie został zdefiniowany.'");
				MessageText = StrReplace(MessageText, "%P1", ExtDimensionType);
				MessageText = StrReplace(MessageText, "%P2", Account);
				Common.ErrorMessage(MessageTextBegin + " "  + MessageText,, Title);
				
			EndIf;
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ExtDimensionType.ValueType.ContainsType(TypeOf(ExtDimensionValue)) Then
		
		ExtDimensions.Insert(ExtDimensionType, ExtDimensionValue);
		
	ElsIf DoMessages Then
		
		MessageText = NStr("en = 'Not correct value %P1 extra dimension %P2.'; pl = 'Niepoprawna wartość %P1 analityki %P2.'");
		MessageText = StrReplace(MessageText, "%P1", ExtDimensionValue);
		MessageText = StrReplace(MessageText, "%P2", ExtDimensionType);
		Common.ErrorMessage(MessageTextBegin + " "  + MessageText,, Title);
		
	EndIf;
	
EndProcedure // SetExtDimension()

#If Client Then

// Function check if given account can be used in records
// Account - Account to check
// Notify - Boolean. If true then messages will be shown
// 
// Return value:
//  Boolena - If true then account can be used in records
Function AccountCanBeUsedInRecords(Account, Notify = True) Export

	If TypeOf(Account) <> Type("ChartOfAccountsRef.Bookkeeping") Then
		Return False; // Incorrect type
	EndIf;

	If Account.IsEmpty() Then
		Return True; // Empty ref can be used
	EndIf;

	If Account.ForbidToUseWhenPosting Then

		If Notify Then
			ShowMessageBox(, Alerts.ParametrizeString(Nstr("en = 'Account %P1 %P2 could not be used in records.'; pl = 'Konto %P1 %P2 nie może być użyte w zapisach.'"),New Structure("P1, P2",TrimAll(Account),Account.Description)));
		EndIf;

		Return False; // Account could not be used

	EndIf;

	Return True; // Account can be used 

EndFunction // AccountCanBeUsedInRecords()

Procedure HandleExtDimensionSelection(Control, StandartProcessing, Company, ParametersList = Undefined, TypeRestriction = Undefined) Export
	
	If Not TypeOf(TypeRestriction) = Type("TypeDescription") Then
		
		ControlValueType = TypeOf(Control.Value);
		If ControlValueType = Undefined Then
			Return;
		EndIf;
		TypeRestriction = Control.TypeRestriction;
		
	ElsIf TypeRestriction.Types().Count() > 0 Then
		
		ControlValueType = TypeRestriction.Types()[0];
		
	Else
		
		Return;
		
	EndIf;
	
	If ControlValueType = TypeOf(Catalogs.BankAccounts.EmptyRef()) Then
		
		StandartProcessing = False;
		ChoiceForm = Catalogs.BankAccounts.GetChoiceForm(,Control,);
		ChoiceForm.FilterByOwnerParameter = Company;
		ChoiceForm.Controls.CatalogList.FilterSettings.Owner.Enabled = False;
		
	EndIf;
	
	If Not StandartProcessing Then
		ChoiceForm.Open();
	EndIf;

EndProcedure 

#EndIf

// Return typeDescription object for given column given record template
//
// Parameters:
//  TableBox                  - ref on tablebox record's template
//  TableRow        - ref on tablebox row record's template
//  ColumnName           - String - Column name for tablebox record's template
//  ExtDimensionDescription - String - after function performing here will be stored ExtDimensiontype description corresponding to current field
//
// Return value:
//  Type description for given column
// 
Function GetAccountingRecordsColumnType(ObjectMetadata, TableBox, TableRow = "", ColumnName = "", ExtDimensionDescription = "") Export

	If TableBox.Value.Count() = 0 Then
		Return Undefined;
	EndIf;

	If ColumnName = "" Then
		ColumnName = TableBox.CurrentColumn.Name;
	EndIf;

	If TableRow = "" Then
		TableRow = TableBox.CurrentData;
	EndIf;

	If ColumnName = "LineNumber"
		Or ColumnName = "Icon"
		Or Find(ColumnName, "LabelExtDimension") > 0 Then
		Return Undefined;
	EndIf;

	If Find(ColumnName, "ExtDimension") > 0 Then

		Account = TableRow.Account;
		ExtDimensionNumber = Number(StrReplace(ColumnName, "ExtDimension", ""));

		If Account.Isempty() Then
			ColumnTypesDescription = Metadata.ChartsOfCharacteristicTypes.BookkeepingExtDimensions.Type;
		ElsIf ExtDimensionNumber <= Account.ExtDimensionTypes.Count() Then
			ExtDimKind = Account.ExtDimensionTypes[ExtDimensionNumber-1].ExtDimensionType;
			ColumnTypesDescription = ExtDimKind.ValueType;
			ExtDimensionDescription = StrReplace(ExtDimKind.Description, " ", "_");
		Else
			ColumnTypesDescription = Undefined;
		EndIf;

	ElsIf Find(ColumnName, "Quantity") > 0 Then

		Account = TableRow.Account;
		If Account.Isempty() Or Account.Quantity Then
			ColumnTypesDescription = ObjectMetadata.TabularSections[TableBox.Name].Attributes[ColumnName].Type;
		Else
			ColumnTypesDescription = Undefined;
		EndIf;

	ElsIf (Find(ColumnName, "Currency") > 0) Or (Find(ColumnName, "CurrencyAmount") > 0) Or (Find(ColumnName, "ExchangeRate") > 0) Then
		
		
		Account = TableRow.Account;
		If Account.Isempty() Or Account.Currency Then
			ColumnTypesDescription = ObjectMetadata.TabularSections[TableBox.Name].Attributes[ColumnName].Type;
		Else
			ColumnTypesDescription = Undefined;
		EndIf;
		
	Else
		
		ColumnTypesDescription = ObjectMetadata.TabularSections[TableBox.Name].Attributes[ColumnName].Type;
		
	EndIf;

	Return ColumnTypesDescription;

EndFunction // GetAccountingRecordsColumnType()

Procedure ExtDimensionStartChoice(Tab, Control, StandardProcessing,AccountName = "Account") Export

	ColumnName = Tab.CurrentColumn.Name;

	Account = Tab.CurrentData[AccountName];
	ExtDimensionNumber = Number(StrReplace(ColumnName, "ExtDimension", ""));

	If Account.Isempty() Then
		Return
	EndIf;

	If ExtDimensionNumber > Account.ExtDimensionTypes.Count() Then
		StandardProcessing = False;
		Return;
	EndIf;

	ExtDimensionType = Account.ExtDimensionTypes[ExtDimensionNumber-1].ExtDimensionType;
	ExtDimensionValueType = ExtDimensionType.ValueType;

	Control.ChooseType     = ExtDimensionValueType.Types().Count() > 1;
	Control.TypeRestriction = ExtDimensionValueType;

EndProcedure

// Function gets balance and document for specified account, partner, currency and date
Function GetBalanceForAccountsPayableAndReceivable(Ref = Undefined, Ordered = False, Account, Partner, Currency, Date, Company, SecondAccount = Undefined, SecondPartner = Undefined, ThirdAccount = Undefined )Export
	
	Query = New Query();
	Query.Text =
		"SELECT
		|	BookkeepingBalance.ExtDimension2 AS Document,
		|	BookkeepingBalance.ExtDimension1 AS BusinessPartner,
		|	BookkeepingBalance.AmountBalanceDr AS AmountCrNational,
		|	BookkeepingBalance.AmountBalanceCr AS AmountDrNational,
		|	BookkeepingBalance.AmountBalance AS AmountNational,
		|   BookkeepingBalance.Account AS Account,
		|	CASE
		|	WHEN BookkeepingBalance.Account.Currency
		|		THEN BookkeepingBalance.CurrencyAmountBalanceDr
		|		ELSE BookkeepingBalance.AmountBalanceDr
		|	END AS AmountCr,
		|	CASE
		|	WHEN BookkeepingBalance.Account.Currency
		|		THEN BookkeepingBalance.CurrencyAmountBalanceCr
		|		ELSE BookkeepingBalance.AmountBalanceCr
		|	END AS AmountDr,
		|	CASE
		|	WHEN BookkeepingBalance.Account.Currency
		|		THEN BookkeepingBalance.CurrencyAmountBalance
		|		ELSE BookkeepingBalance.AmountBalance
		|	END AS Amount
		|FROM
		|	AccountingRegister.Bookkeeping.Balance(
		|		&Date,
		|		Account IN HIERARCHY (&Account) ";
		If ValueIsFilled(SecondAccount) Then
			Query.Text = Query.Text + " OR Account IN HIERARCHY (&SecondAccount) ";
		EndIf;
		If ValueIsFilled(ThirdAccount) Then
			Query.Text = Query.Text + " OR Account IN HIERARCHY (&ThirdAccount) ";
		EndIf;
		Query.Text = Query.Text + ",, Company = &Company ";
		If Ref <> Undefined Then	
			Query.Text = Query.Text +	" AND ExtDimension2 = &Ref ";	
			Query.SetParameter("Ref",Ref);
		EndIf;
		If ValueIsFilled(SecondPartner) Then
			Query.Text = Query.Text +	" AND (ExtDimension1 = &Partner Or ExtDimension1 = &SecondPartner) ";
		Else
			Query.Text = Query.Text +	" AND ExtDimension1 = &Partner ";
		EndIf;
		Query.Text = Query.Text +	" ) AS BookkeepingBalance 
		|WHERE
		|	CASE
		|	WHEN BookkeepingBalance.Account.Currency
		|		THEN BookkeepingBalance.CurrencyAmountBalance <> 0
		|				AND BookkeepingBalance.AmountBalance <> 0
		|	ELSE TRUE
		|	END 
		|AND 
	    |	CASE
	    |	WHEN BookkeepingBalance.Account.Currency
	    |		THEN BookkeepingBalance.Currency = &Currency
	    |	ELSE TRUE
	    |	END";
	If Ordered Then
	Query.Text = Query.Text + " ORDER BY
		|	BookkeepingBalance.ExtDimension2.Date";		
	EndIf;
	
	Query.SetParameter("Date",EndOfDay(Date));
	Query.SetParameter("Account",Account);
	Query.SetParameter("SecondAccount",SecondAccount);
	Query.SetParameter("ThirdAccount",ThirdAccount);
	Query.SetParameter("Partner",Partner);
	Query.SetParameter("SecondPartner",SecondPartner);
	Query.SetParameter("Currency",Currency);
	Query.SetParameter("Company",Company);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return Undefined;
	ElsIf Ref <> Undefined Then
		Return QueryResult.Unload().Get(0);
	Else
		Return QueryResult.Unload();
	EndIf;

EndFunction	// GetBalanceForAccountsPayableAndReceivable

// procedure checks if the account is currency account
// and if true then filling goes like for currency account
// else filling goes normaly
// Amount - Amount wich should be posted
// RegisterRecord - Record, that was creating for movement
// in RegisterRecord - Value Account and Amount, should be filled before calling this procedure
Procedure CheckAndFillCurrencyAccount(RegisterRecord,  Currency = Undefined, ExchangeRate = 1, IsCurrencyAccount, NationalAmount = Undefined) Export
	
	If IsCurrencyAccount Then // currency
		
		RegisterRecord.Currency = Currency;
		RegisterRecord.CurrencyAmount = RegisterRecord.Amount;
		
		If NationalAmount = Undefined then
			RegisterRecord.Amount = RegisterRecord.Amount*ExchangeRate;
		Else
			RegisterRecord.Amount = NationalAmount;
		EndIf;
		
	Else // national
		
		If Currency <> Constants.NationalCurrency.Get() Then
			If NationalAmount = Undefined Then
				RegisterRecord.Amount = RegisterRecord.Amount*ExchangeRate;
			Else
				RegisterRecord.Amount = NationalAmount;
			EndIf;
		Endif;
		
	EndIf;
	
EndProcedure

Procedure ConvertReversingEntryToNormalRecordType(Record) Export
	
	If Record.Amount<0 Then
		If Record.RecordType = AccountingRecordType.Credit Then
			Record.RecordType = AccountingRecordType.Debit;
			Record.Amount = -Record.Amount;
			Record.CurrencyAmount = -Record.CurrencyAmount;
		ElsIf Record.RecordType = AccountingRecordType.Debit Then
			Record.RecordType = AccountingRecordType.Credit;
			Record.Amount = -Record.Amount;
			Record.CurrencyAmount = -Record.CurrencyAmount;
		EndIf;	
	EndIf;	
	
EndProcedure

Procedure CheckAndFillCurrencyAmount( RegisterRecord, AccountCurrency, Amount, Currency, CurrencyAmount ) Export
	
	If AccountCurrency Then // account is a currency one
		
		RegisterRecord.Currency = Currency;
		RegisterRecord.CurrencyAmount = CurrencyAmount;
		RegisterRecord.Amount = Amount; 
		
	Else // national
		
		RegisterRecord.Amount = ?(Currency = Constants.NationalCurrency.Get(), Amount, CurrencyAmount);
		
	EndIf;
	
EndProcedure

Function GetAccountingPolicy(Date, Company) Export
	
	Filter = New Structure;
	Filter.Insert("Company", Company);
	Return InformationRegisters.BookkeepingAccountingPolicyGeneral.GetLast(EndOfDay(Date), Filter);
	
EndFunction

Function GetGoodsInventoryAccountingPolicy(Date,Company) Export // Akulov
	Filter = New Structure;
	Filter.Insert("Company", Company);
	Return InformationRegisters.BookkeepingDefaultAccountGoodsInventoryMovements.GetLast(EndOfDay(Date),Filter);
EndFunction	

// Jack 27.06.2017
//Function GetSettlementAccounts(Date,PartnerAccountingGroup,ItemAccountingGroup) Export // Akulov
//	Filter = New Structure;
//	Filter.Insert("BusinessAccountingGroup", PartnerAccountingGroup);
//	Filter.Insert("ItemAccountingGroup", ItemAccountingGroup);
//	Return InformationRegisters._BookkeepingAccountingGroupsSettlementAccounts.GetLast(EndOfDay(Date),Filter);
//EndFunction	

// Jack 27.06.2017
// returns account for given cost of goods direction
//Function GetAccountingPolicyCostOfGoodsDirections(Date, Company, Direction,ItemAccountingGroup) Export
//	
//	Query = New Query();
//	Query.Text = "SELECT
//	             |	BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast.Account,
//	             |	BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast.ExtDimension1,
//	             |	BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast.ExtDimension2,
//	             |	BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast.ExtDimension3,
//	             |	BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast.ItemAccountingGroup AS ItemAccountingGroup
//	             |FROM
//	             |	InformationRegister.BookkeepingAccountingPolicyCostOfGoodsDirections.SliceLast(
//	             |			&Date,
//	             |			Company = &Company
//	             |				AND Direction = &Direction) AS BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast
//	             |WHERE
//	             |	(BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast.ItemAccountingGroup = &ItemAccountingGroup
//	             |			OR BookkeepingAccountingPolicyCostOfGoodsDirectionsSliceLast.ItemAccountingGroup = &EmptyItemAccountingGroup)";
//	Query.SetParameter("Date",Date);
//	Query.SetParameter("Company",Company);
//	Query.SetParameter("Direction", Direction);
//	Query.SetParameter("ItemAccountingGroup", ItemAccountingGroup);
//	Query.SetParameter("EmptyItemAccountingGroup", Catalogs.ItemAccountingGroups.EmptyRef());
//	ResultTable = Query.Execute().Unload();
//	ResRow = ResultTable.Find(ItemAccountingGroup,"ItemAccountingGroup");
//	If ResRow = Undefined Then
//		If ResultTable.Count()>0 Then
//			ResRow = ResultTable.Get(0);
//		Else
//			Return Undefined;
//		EndIf;	
//	EndIf;	
//	
//	RetStructure = New Structure("Account, ExtDimension1, ExtDimension2, ExtDimension3",ResRow.Account,ResRow.ExtDimension1,ResRow.ExtDimension2,ResRow.ExtDimension3);
//					 
//	Return RetStructure;
//	
//EndFunction

Function GetFinePercent(Customer , Date = Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	FinePercentagesSliceLast.FinePercent,
	             |	CASE
	             |		WHEN FinePercentagesSliceLast.BusinessPartner = VALUE(Catalog.Customers.EmptyRef)
	             |			THEN 0
	             |		ELSE 1
	             |	END AS Rank
	             |FROM
	             |	InformationRegister.FinePercentages.SliceLast(&Date, BusinessPartner IN (VALUE(Catalog.Customers.EmptyRef), &BusinessPartner)) AS FinePercentagesSliceLast
	             |
	             |ORDER BY
	             |	Rank DESC";
	Query.SetParameter("Date",Date);
	Query.SetParameter("BusinessPartner",Customer);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return 0;
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.FinePercent;
	EndIf;	
		
EndFunction	

Function GetFineAmount(Val Customer,Val Amount,Val PaymentDate,Val PaidDate,Val FinePercent = Undefined,Val Date = Undefined) Export
	
	If FinePercent = Undefined Then
		PaymentDate = Common.GetNearestWorkDayDate(PaymentDate);
		PaymentDate = (EndOfDay(PaymentDate)+1);
		Query = New Query;
		Query.Text = "SELECT DISTINCT
		             |	NestedSelect.Period AS Period
		             |FROM
		             |	(SELECT
		             |		DATEADD(FinePercentages.Period, SECOND, -1) AS Period
		             |	FROM
		             |		InformationRegister.FinePercentages AS FinePercentages
		             |	WHERE
		             |		FinePercentages.BusinessPartner IN (VALUE(Catalog.Customers.EmptyRef), &BusinessPartner)
		             |		AND FinePercentages.Period > &PaymentDate
		             |		AND FinePercentages.Period <= &PaidDate
		             |	
		             |	UNION ALL
		             |	
		             |	SELECT
		             |		&PaidDate) AS NestedSelect
		             |
		             |ORDER BY
		             |	Period";
		Query.SetParameter("PaymentDate",BegOfDay(PaymentDate));
		Query.SetParameter("PaidDate",BegOfDay(PaidDate));
		Query.SetParameter("BusinessPartner",Customer);
		QueryResult = Query.Execute();
		If NOT QueryResult.IsEmpty() Then
			Selection = Query.Execute().Select();
			FineAmount = 0;
			BeginOfPeriod = BegOfDay(PaymentDate);
			While Selection.Next() Do
				EndOfPeriod = Selection.Period;
				Days = Common.GetOverdueDaysCount(BeginOfPeriod,EndOfPeriod,False);
				FineAmount = FineAmount + Amount*Days*GetFinePercent(Customer,BeginOfPeriod)/100/Common.GetYearDays(EndOfPeriod);
				BeginOfPeriod = Selection.Period+1;
			EndDo;	
			Return FineAmount;
		EndIf;
		
	EndIf;
	
	Days = Common.GetOverdueDaysCount(PaymentDate,PaidDate);
	Return Amount*Days*?(FinePercent = Undefined,GetFinePercent(Customer,Date),FinePercent)/100/Common.GetYearDays(Date);
	
EndFunction	