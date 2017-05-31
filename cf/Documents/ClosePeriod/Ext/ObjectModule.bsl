Procedure Filling(Base)
	
	If Base = Undefined Then 	
		CommonAtServer.FillDocumentHeader(ThisObject);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	CheckedAttributes.Clear();
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	// WARNING!!! Calling of this function should be on begin of BeforeWrite function
	// Please, don't remove this call - it may cause damage in logic of configuration
	Common.GetObjectModificationFlag(ThisObject);
	
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
	
	If BegOfDay(PostingDate)<BegOfDay(FinancialYear.DateFrom) OR EndOfDay(PostingDate)>EndOfDay(FinancialYear.DateTo) Then
		Alerts.AddAlert( NStr("en = ""Posting date is not valid with financial year""; pl = ""Data ksiegowania dokumentu nie mieści się w zakresie wybranego roku finansowego"""), Enums.AlertType.Error, Cancel, ThisObject);	
	EndIf;
	
	NextFinancialYear = BookkeepingCommon.GetFinancialYear(EndOfDay(PostingDate)+1);
	
	If NextFinancialYear=Catalogs.FinancialYears.EmptyRef() Then
		Alerts.AddAlert( NStr("en = ""The next financial year is not created.""; pl = ""Brak kolejnego roku finansowego dla przeksięgowania wyniku finansowego na rozliczenie wyniku finansowego"""), Enums.AlertType.Error, Cancel, ThisObject);	
	EndIf;

	If NextFinancialYear=FinancialYear Then
		Alerts.AddAlert( NStr("en = ""Posting open perid and close period in same financial year is blocked.""; pl = ""Nie można przeksięgować wyniku finansowego na rozliczenie wyniku finansowego w tym samym okresie co przeksięgowanie kont wynikowych na wynik finansowy"""), Enums.AlertType.Error, Cancel, ThisObject);	
		
	EndIf;

	If Cancel Then
		Return;
	EndIf;
	
	RegisterRecords.Bookkeeping.SetProgramBookkeepingPostingClosePeriodFlag();

	MessageTextBegin = "";
	
	ClosePeriodRecordsTotalAmountDr = ClosePeriodRecords.Total("AmountDr");
	ClosePeriodRecordsTotalAmountCr = ClosePeriodRecords.Total("AmountCr");
	TmpClosePeriodRecords = ClosePeriodRecords.Unload();
	TmpClosePeriodRecords.Columns.Add("Period");

	ClosingPeriod = Date(Year(PostingDate), Month(PostingDate), Day(PostingDate), 23, 59, 50);
	OpeningPeriod = Date(Year(EndOfDay(PostingDate)+1), Month(EndOfDay(PostingDate)+1), Day(EndOfDay(PostingDate)+1), 00, 00, 00);
	
	For Each TmpClosePeriodRecordsItem In TmpClosePeriodRecords Do
		TmpClosePeriodRecordsItem.Period = ClosingPeriod;
	EndDo;	
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	If ClosePeriodRecordsTotalAmountDr<>ClosePeriodRecordsTotalAmountCr Then
		
		ClosePeriodCompnesationRow = TmpClosePeriodRecords.Add();
		ClosePeriodCompnesationRow.Account = PeriodEndClosingAccount;
		ClosePeriodCompnesationRow.ExtDimension1 = PeriodEndClosingExtDimension1;
		ClosePeriodCompnesationRow.ExtDimension2 = PeriodEndClosingExtDimension2;
		ClosePeriodCompnesationRow.ExtDimension3 = PeriodEndClosingExtDimension3;
		If ClosePeriodRecordsTotalAmountDr>ClosePeriodRecordsTotalAmountCr Then
			ClosePeriodCompnesationRow.AmountCr = ClosePeriodRecordsTotalAmountDr - ClosePeriodRecordsTotalAmountCr;
		Else
			ClosePeriodCompnesationRow.AmountDr = ClosePeriodRecordsTotalAmountCr - ClosePeriodRecordsTotalAmountDr;
		EndIf;
		
		If ClosePeriodCompnesationRow.Account.Currency Then
			ClosePeriodCompnesationRow.Currency = NationalCurrency;
			ClosePeriodCompnesationRow.CurrencyAmount = ?(ClosePeriodCompnesationRow.AmountDr <> 0, ClosePeriodCompnesationRow.AmountDr, ClosePeriodCompnesationRow.AmountCr);
		EndIf;	
	
		ClosePeriodCompnesationRow.Period = ClosingPeriod;
		
		PeriodEndClosingAccountOpeningRow = TmpClosePeriodRecords.Add();
		FillPropertyValues(PeriodEndClosingAccountOpeningRow,ClosePeriodCompnesationRow);
		PeriodEndClosingAccountOpeningRow.AmountDr = ClosePeriodCompnesationRow.AmountCr;
		PeriodEndClosingAccountOpeningRow.AmountCr = ClosePeriodCompnesationRow.AmountDr;
		PeriodEndClosingAccountOpeningRow.Period = OpeningPeriod;
		
		RetainedEarningsAccountOpeningRow = TmpClosePeriodRecords.Add();
		RetainedEarningsAccountOpeningRow.Account = RetainedEarningsAccount;
		RetainedEarningsAccountOpeningRow.ExtDimension1 = RetainedEarningsExtDimension1;
		RetainedEarningsAccountOpeningRow.ExtDimension2 = RetainedEarningsExtDimension2;
		RetainedEarningsAccountOpeningRow.ExtDimension3 = RetainedEarningsExtDimension3;
		RetainedEarningsAccountOpeningRow.AmountCr = ClosePeriodCompnesationRow.AmountCr;
		RetainedEarningsAccountOpeningRow.AmountDr = ClosePeriodCompnesationRow.AmountDr;
		If RetainedEarningsAccountOpeningRow.Account.Currency Then
			RetainedEarningsAccountOpeningRow.Currency = NationalCurrency;
			RetainedEarningsAccountOpeningRow.CurrencyAmount = ?(RetainedEarningsAccountOpeningRow.AmountDr <> 0, RetainedEarningsAccountOpeningRow.AmountDr, RetainedEarningsAccountOpeningRow.AmountCr);
		EndIf;	
		RetainedEarningsAccountOpeningRow.Period = OpeningPeriod;
	EndIf;	
	For Each Selection In TmpClosePeriodRecords Do		
		
		MessageTextBegin = NStr("en=""Tabular part 'Close period records', line number "";pl=""Część tabelaryczna 'Zamknięcie okresu', numer linii """) + TrimAll(Selection.LineNumber) + ". ";
	
		If Selection.AmountDr <> 0 And Selection.AmountCr <> 0 Then
			Alerts.AddAlert(MessageTextBegin + NStr("en='Please, input only one Amount: Debit or Credit!';pl='Wprowadź tylko jedną kwotę: po stronie Winien lub Ma!'"), Enums.AlertType.Error, Cancel,ThisObject);
		EndIf;
		
		Record = RegisterRecords.Bookkeeping.Add();
		RegisterRecords.Bookkeeping.Write = True;
		RegisterRecords.Bookkeeping.LockForUpdate = True;
		
		If Selection.AmountDr <> 0 Then
			Record.RecordType = AccountingRecordType.Debit;
		Else
			Record.RecordType = AccountingRecordType.Credit;
		EndIf;
		
		Record.Period         = Selection.Period;
		Record.Company        = Company;
		Record.PartialJournal = PartialJournal;
		Record.Account        = Selection.Account;
		
		Record.Currency = Selection.Currency;
		Record.CurrencyAmount = Selection.CurrencyAmount;
		Record.Amount         = ?(Selection.AmountDr <> 0, Selection.AmountDr, Selection.AmountCr);
		Record.Description = NStr("en = 'Close financial year'; pl = 'Zamknięcie roku finansowego'") + " " + FinancialYear;
		
		Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 1, Selection.ExtDimension1, , MessageTextBegin, AdditionalProperties.MessageTitle);
		Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 2, Selection.ExtDimension2, , MessageTextBegin, AdditionalProperties.MessageTitle);
		Accounting.SetExtDimension(Record.Account, Record.ExtDimensions, 3, Selection.ExtDimension3, , MessageTextBegin, AdditionalProperties.MessageTitle);
		
	EndDo;
		
EndProcedure

Procedure UndoPosting(Cancel)
	
	DocumentsPostingAndNumbering.CheckUndoPostingPermission(ThisObject, Cancel, AdditionalProperties.MessageTitle);
	If Cancel Then
		Return;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES


Function GetAttributesValueTableForValidation(PostingMode) Export
	
	AttributesStructure = New Structure("Company,FinancialYear,PostingDate, PeriodEndClosingAccount, RetainedEarningsAccount");
	AttributesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	Return AttributesValueTable;

	
EndFunction	

Function GetAttributesStructureForTabularPartsValidation(PostingMode) Export
	
	TabularPartsStructure = New Structure();
	
	AttributesStructure = New Structure("");
	
	ItemsLinesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	ItemsLinesValueTable = Alerts.AddAttributesValueTableRow(ItemsLinesValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Error);

	TabularPartsStructure.Insert("ClosePeriodRecords",ItemsLinesValueTable);
	
	
	Return TabularPartsStructure;
	
EndFunction	


Function DocumentChecks(AlertsTable, Cancel = Undefined) Export 
	
	Return AlertsTable;
	
EndFunction

Function DocumentChecksTabularPart(AlertsTable, Cancel = Undefined) Export 
	
	Return AlertsTable;
	
EndFunction
