Var mProgramBookkeepingPostingClosePeriodFlag;

Procedure BeforeWrite(Cancel, WriteMode)
	//TableValue = ThisObject.Unload();
	//
	//Query = New Query;
	//Query.TempTablesManager = New TempTablesManager;
	//Query.SetParameter("TableValue",TableValue);
	//
	//Query.Text = "SELECT
	//|	Table.Period,
	//|	Table.Account
	//|INTO TableAccount
	//|FROM
	//|	&TableValue AS Table
	//|;
	//|SELECT
	//|	TableAccount.Period,
	//|	TableAccount.Account,
	//|	TableAccount.Account.FinancialYearsBegin.DateFrom AS DateStartYearValidity,
	//|	TableAccount.Account.FinancialYearsEnd.DateTo AS DateEndYearValidity,
	//|	TableAccount.Account.Code AS AccountCode
	//|FROM
	//|	TableAccount AS TableAccount
	//|WHERE
	//|	(CASE
	//|				WHEN TableAccount.Account.FinancialYearsBegin = VALUE(ChartOfAccounts.Bookkeeping.EmptyRef)
	//|					THEN False
	//|				ELSE TableAccount.Account.FinancialYearsBegin.DateFrom > TableAccount.Period
	//|			END
	//|			Or CASE
	//|				WHEN TableAccount.Account.FinancialYearsEnd = VALUE(ChartOfAccounts.Bookkeeping.EmptyRef)
	//|					THEN False
	//|				ELSE TableAccount.Account.FinancialYearsEnd.DateTo < TableAccount.Period
	//|			END)";
	//
	//Result = Query.Execute();
	//Selection = Result.Select();
	//
	//While Selection.Next() Do
	//	
	//	ErrorText = Alerts.ParametrizeString(NStr("en = 'Account %P1 not valid for period %P2'; pl = 'Konto %P1 nie ważne w okresie %P2'"), New Structure("P1, P2", Selection.AccountCode,  Format(Selection.Period,"DF=dd.MM.yyyy")));
	//	Common.ErrorMessage(ErrorText, Cancel);
	//	
	//EndDo;
	
	If ThisObject.Count()>0 Then
		
		DocDate = ThisObject[0].Period;
		
		If (mProgramBookkeepingPostingClosePeriodFlag and (Hour(DocDate)<>23 or Minute(DocDate)<>59 or Second(DocDate)<=49)) Then		
			
			ErrorText = NStr("en = 'Date is not valid for any financial year!'; pl = 'Nieprawidłowa godzina. Dla dokumentu godzina powinna mieścić się w przedziale 00:00:00 do 23:59:49.'");
			Common.ErrorMessage(ErrorText, Cancel);
			
		ElsIf (NOT mProgramBookkeepingPostingClosePeriodFlag and (Hour(DocDate)=23 and Minute(DocDate)=59 and Second(DocDate)>49)) Then
			
			ErrorText = NStr("en = 'Date is not valid for any financial year!'; pl = 'Nieprawidłowa godzina. Dla dokumentu zamknięcia okresu godzina powinna mieścić się w przedziale 23:59:50 do 23:59:59.'");
			Common.ErrorMessage(ErrorText, Cancel);
			
		EndIf;
		
		FinancialYear = BookkeepingCommon.GetFinancialYear(DocDate); 
		If ValueIsNotFilled(FinancialYear) Then
			Cancel = True;
			ErrorText = NStr("en = 'Date is not valid for any financial year!'; pl = 'Data dokumenu nie mieści się w zakresie żadnego roku finansowego!'");
			Common.ErrorMessage(ErrorText, Cancel);
		ElsIf FinancialYear.Closed Then
			Cancel = True;
			ErrorText = NStr("en = 'Financial year is closed!'; pl = 'Rok finansowy jest zamknięty!'");
			Common.ErrorMessage(ErrorText, Cancel);
		EndIf;
		
	EndIf;
	
	For Each AccountRecord In ThisObject Do
		
		// Check filling of mandatory ext dimensions.
		MandatoryFieldsDescription = "";
		For Each ExtDimensionType In AccountRecord.Account.ExtDimensionTypes Do
			
			ExtDimension = AccountRecord.ExtDimensions.Get(ExtDimensionType.ExtDimensionType);
			If Not ValueIsFilled(ExtDimension) And ExtDimensionType.Mandatory Then
				MandatoryFieldsDescription = MandatoryFieldsDescription + ", " + String(ExtDimensionType.LineNumber) + ". " + String(ExtDimensionType.ExtDimensionType);
			EndIf;
			
		EndDo;
		
		If MandatoryFieldsDescription <> "" Then
			
			MandatoryFieldsDescription = Right(MandatoryFieldsDescription, StrLen(MandatoryFieldsDescription) - 2);
			
			ErrorText = NStr("en = 'Account %1 has not set all required analitycs: %2!'; pl = 'Dla konta %1 nie podano wymaganej analityki: %2!'");
			ErrorText = StrReplace(ErrorText, "%1", String(AccountRecord.Account));
			ErrorText = StrReplace(ErrorText, "%2", MandatoryFieldsDescription);
			Common.ErrorMessage(ErrorText, Cancel);
			
		EndIf;
		
		// In currency account has to have filled the field of currency.
		If AccountRecord.Account.Currency And Not ValueIsFilled(AccountRecord.Currency) Then
			
			ErrorText = NStr("en = 'For a currency account %1 currency is not specified!'; pl = 'Dla konta walutowego %1 nie podano waluty!'");
			ErrorText = StrReplace(ErrorText, "%1", String(AccountRecord.Account));
			Common.ErrorMessage(ErrorText, Cancel);
			
		EndIf;
		
		// In resultant account, that fill financial year.
		//If AccountRecord.Account.Resultant Then
		//	AccountRecord.FinancialYear = FinancialYear;
		//EndIf;
		
		If AccountRecord.Amount = 0 Then
			
			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'One of amounts (Amount Dr or Amount Cr) should be filled in record for account %P1!'; pl = 'Kwota Wn lub Kwota Ma powinna być wybrana dla zapisu dla konta %P1!'"),New Structure("P1",AccountRecord.Account)),Enums.AlertType.Error,Cancel);
			
		EndIf;	
		
		If AccountRecord.RecordType = AccountingRecordType.Credit Then
			AccountRecord.AmountCr = AccountRecord.Amount;
		ElsIf AccountRecord.RecordType = AccountingRecordType.Debit Then
			AccountRecord.AmountDr = AccountRecord.Amount;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SetProgramBookkeepingPostingClosePeriodFlag() Export
	
	mProgramBookkeepingPostingClosePeriodFlag = True;	
	
EndProcedure	

mProgramBookkeepingPostingClosePeriodFlag = False;
