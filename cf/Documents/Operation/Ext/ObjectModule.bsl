#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Not Constants.FunctionalCurrencyTransactionsAccounting.Get() Then
		For Each TabularSectionRow IN AccountingRecords Do
			If TabularSectionRow.AccountDr.Currency Then
				TabularSectionRow.CurrencyDr = Constants.NationalCurrency.Get();
				TabularSectionRow.AmountCurDr = TabularSectionRow.Amount;
			EndIf;
			If TabularSectionRow.AccountCr.Currency Then
				TabularSectionRow.CurrencyCr = Constants.NationalCurrency.Get();
				TabularSectionRow.AmountCurCr = TabularSectionRow.Amount;
			EndIf;
		EndDo;
	EndIf;
	
	DocumentAmount = AccountingRecords.Total("Amount");
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each TSRow IN AccountingRecords Do
		If TSRow.AccountDr.Currency
		AND Not ValueIsFilled(TSRow.CurrencyDr) Then
			MessageText = NStr("en='The ""Currency Dr"" column is not populated for the currency account in the %LineNumber% line of the ""Postings"" list.';ru='Не заполнена колонка ""Валюта Дт"" для валютного счета в строке %НомерСтроки% списка ""Проводки"".'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"CurrencyDr",
				Cancel
			);
		EndIf;
		If TSRow.AccountDr.Currency
		AND Not ValueIsFilled(TSRow.AmountCurDr) Then
			MessageText = NStr("en='The ""Amount (cur.) Dr"" column is not populated for currency account in the  %LineNumber% line of the ""Postings"" list.';ru='Не заполнена колонка ""Сумма (вал.) Дт"" для валютного счета в строке %НомерСтроки% списка ""Проводки"".'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"AmountCurDr",
				Cancel
			);
		EndIf;
		If TSRow.AccountCr.Currency
		AND Not ValueIsFilled(TSRow.CurrencyCr) Then
			MessageText = NStr("en='Column ""Currency Kt"" is not filled  for currency account in string %LineNumber% of list ""Posting"".';ru='Не заполнена колонка ""Валюта Кт"" для валютного счета в строке %НомерСтроки% списка ""Проводки"".'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"CurrencyCr",
				Cancel
			);
		EndIf;
		If TSRow.AccountCr.Currency
		AND Not ValueIsFilled(TSRow.AmountCurCr) Then
			MessageText = NStr("en='Column ""Amount"" is not filled (cur.) Kt"" for currency account in string %LineNumber% of list ""Posting"".';ru='Не заполнена колонка ""Валюта Кт"" для валютного счета в строке %НомерСтроки% списка ""Проводки"".'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"AmountCurCr",
				Cancel
			);
		EndIf;
	EndDo;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.Operation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf