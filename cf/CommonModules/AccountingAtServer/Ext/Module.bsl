Function GetLastFinancialYear() Export
	
	Query = New Query;
	
	Query.Text = "SELECT
	|	FinancialYears.DateFrom AS DateFrom,
	|	FinancialYears.Ref,
	|	CASE
	|		WHEN FinancialYears.DateFrom > &CurrentYear
	|			THEN 0
	|		ELSE 1
	|	END AS Field1
	|FROM
	|	Catalog.FinancialYears AS FinancialYears
	|
	|ORDER BY
	|	Field1 DESC,
	|	DateFrom DESC";
	
	Query.SetParameter("CurrentYear", BegOfYear(CurrentDate()));
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Return '00010101';
	EndIf;
	
EndFunction

Function GetFinePercent(Customer , Date = Undefined) Export
	
	Return Accounting.GetFinePercent(Customer,Date);
		
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH CURRENCIES 

// Return currency exchange rate on date
//
// Parameters:
//  Currency     - Currency (catalog "Currencies" item)
//  RateDate  - Date, on which will be get following exchange rate
//
// Return value: 
// 	Exchange rate record with exchange rate, table number
//
Function GetExchangeRateRecord(Currency, RateDate) Export 
	
	Query = New Query;
	Query.Text = "SELECT
	             |	CurrencyExchangeRatesSliceLast.Period,
	             |	CurrencyExchangeRatesSliceLast.ExchangeRate,
	             |	CurrencyExchangeRatesSliceLast.NBPTableNumber
	             |FROM
	             |	InformationRegister.CurrencyExchangeRates.SliceLast(&RateDate, Currency = &Currency) AS CurrencyExchangeRatesSliceLast";
	Query.SetParameter("Currency",Currency);
	Query.SetParameter("RateDate",RateDate);
	QueryResult = Query.Execute();
	
	ReturnStructure = New Structure("Period, ExchangeRate, NBPTableNumber");
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		ReturnStructure.Period = Selection.Period;
		ReturnStructure.ExchangeRate = Selection.ExchangeRate;
		ReturnStructure.NBPTableNumber = Selection.NBPTableNumber;
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction // AccountingAtServer.GetExchangeRate()

// Return currency exchange rate on date
//
// Parameters:
//  Currency     - Currency (catalog "Currencies" item)
//  RateDate  - Date, on which will be get following exchange rate
//
// Return value: 
// 	Exchange rate
//
Function GetExchangeRate(Currency, RateDate) Export 
	
	Return AccountingAtServer.GetExchangeRateRecord(Currency, RateDate).ExchangeRate;
	
EndFunction // AccountingAtServer.GetExchangeRate()

Function GetDocumentExchangeRateDate(DocumentObject, UseAccountingPolicyExchangeRateDateForCalculatingSalesAndPurchase = False,AlternateDate = Undefined) Export
	
	If AlternateDate <> Undefined AND AlternateDate <> '00010101' Then
		InitialDate = AlternateDate;
	Else	
		InitialDate = ?(DocumentObject.Date = '00010101', CurrentDate(), DocumentObject.Date);
	EndIf;	
	
	// Jack 27.06.2017
	// to do 
	//If UseAccountingPolicyExchangeRateDateForCalculatingSalesAndPurchase Then
	//	
	//	ExchangeRateDatePolicy = InformationRegisters.AccountingPolicyGeneral.GetLast(InitialDate, New Structure("Company", DocumentObject.Company)).ExchangeRateForCalculatingSalesAndPurchase;
	//	
	//	If ExchangeRateDatePolicy = Enums.AccountingPolicy_ExchangeRateForCalculatingSalesAndPurchase.DayBeforeDocumentsDate Then
	//		InitialDate = EndOfDay(InitialDate - 60*60*24);
	//	Else
	//		// In all other cases leave initial date as is.
	//	EndIf;
	//	
	//EndIf;
		
	Return InitialDate;
	
EndFunction // AccountingAtServer.GetDocumentExchangeRateDate()

Function GetExchangeRateDifferencePolicy( Date, Company, Sign, CarriedOut, Group ) Export
	
	SignForFilter = ?(Sign < 0, Enums.ExchangeRateDifferenceSign.Negative, Enums.ExchangeRateDifferenceSign.Positive);
	GroupForFilter = ?(Group, Enums.ExchangeRateDifferenceGroup.InGroup, Enums.ExchangeRateDifferenceGroup.OutsideGroup);
	TmpFilter = New Structure("Company, Sign, CarriedOut, GroupKind", Company, SignForFilter, CarriedOut, GroupForFilter );
	AccountingPolicy = InformationRegisters.BookkeepingAccountingPolicyExchangeRateDifference.SliceLast(Date, TmpFilter);
	
	// no group
	If AccountingPolicy.Count() = 0 And Group <> Enums.ExchangeRateDifferenceGroup.NoConcern Then
		TmpFilter.GroupKind = Enums.ExchangeRateDifferenceGroup.NoConcern;
		AccountingPolicy = InformationRegisters.BookkeepingAccountingPolicyExchangeRateDifference.SliceLast(Date, TmpFilter);
	EndIf;
	
	// fetch first row
	If AccountingPolicy.Count() > 0 Then
		Return AccountingPolicy.Get(0);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

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
			Message(Alerts.ParametrizeString(Nstr("en = 'Account %P1 %P2 could not be used in records.'; pl = 'Konto %P1 %P2 nie może być użyte w zapisach.'"),New Structure("P1, P2",TrimAll(Account),Account.Description)));
		EndIf;

		Return False; // Account could not be used

	EndIf;

	Return True; // Account can be used 

EndFunction // AccountCanBeUsedInRecords()

Function GetExtDimensionTypeMandatory(Account, ExtDimensionTypeCounter) Export 
	Return Account.ExtDimensionTypes[ExtDimensionTypeCounter].Mandatory;		
EndFunction // GetExtDimensionTypeMandatory()

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
Function GetAccountingRecordsColumnType(ObjectRef, TableBoxName, TableRow = "", ColumnName = "", ExtDimensionDescription = "") Export

	ObjectMetadata = ObjectRef.Metadata();
	
	If ObjectRef[TableBoxName].Count() = 0 Then
		Return Undefined;
	EndIf;

	//If ColumnName = "" Then
	//	ColumnName = TableBox.CurrentItem.Name;
	//EndIf;

	//If TableRow = "" Then
	//	TableRow = TableBox.CurrentData;
	//EndIf;

	If ColumnName = "LineNumber"
		Or ColumnName = "Icon"
		Or Find(ColumnName, "LabelExtDimension") > 0 Then
		Return Undefined;
	EndIf;

	If Find(ColumnName, "ExtDimension") > 0 Then

		Account = TableRow.Account;
		ExtDimensionNumber = Number(StrReplace(ColumnName, "ExtDimension", ""));

		If Account.IsEmpty() Then
			ColumnTypesDescription = Metadata.ChartsOfCharacteristicTypes.BookkeepingExtDimensions.Type;
		ElsIf ExtDimensionNumber <= Account.ExtDimensionTypes.Count() Then
			ExtDimKind = Account.ExtDimensionTypes[ExtDimensionNumber - 1].ExtDimensionType;
			ColumnTypesDescription = ExtDimKind.ValueType;
			ExtDimensionDescription = StrReplace(ExtDimKind.Description, " ", "_");
		Else
			ColumnTypesDescription = Undefined;
		EndIf;

	ElsIf Find(ColumnName, "Quantity") > 0 Then

		Account = TableRow.Account;
		If Account.Isempty() Or Account.Quantity Then
			ColumnTypesDescription = ObjectMetadata.TabularSections[TableBoxName].Attributes[ColumnName].Type;
		Else
			ColumnTypesDescription = Undefined;
		EndIf;

	ElsIf (Find(ColumnName, "Currency") > 0) Or (Find(ColumnName, "CurrencyAmount") > 0) Or (Find(ColumnName, "ExchangeRate") > 0) Then
		
		
		Account = TableRow.Account;
		If Account.IsEmpty() Or Account.Currency Then
			ColumnTypesDescription = ObjectMetadata.TabularSections[TableBoxName].Attributes[ColumnName].Type;
		Else
			ColumnTypesDescription = Undefined;
		EndIf;
		
	Else
		
		ColumnTypesDescription = ObjectMetadata.TabularSections[TableBoxName].Attributes[ColumnName].Type;
		
	EndIf;

	Return ColumnTypesDescription;

EndFunction // GetAccountingRecordsColumnType()

