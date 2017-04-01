
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenFromList") Then
		If WorkWithCurrencyRates.ExchangeRatesAreRelevant() Then
			NotifyThatRatesAreActual = True;
			Return;
		EndIf;
	EndIf;
	
	FillCurrencies();
	
	// Start and end of the exchange rates importing period.
	Object.ImportEndOfPeriod = BegOfDay(CurrentSessionDate());
	Object.ImportBeginOfPeriod = Object.ImportEndOfPeriod;
	MinimumDate = BegOfYear(Object.ImportEndOfPeriod);
	For Each Currency IN Object.CurrenciesList Do
		If ValueIsFilled(Currency.ExchangeRateDate) AND Currency.ExchangeRateDate < Object.ImportBeginOfPeriod Then
			If Currency.ExchangeRateDate < MinimumDate Then
				Object.ImportBeginOfPeriod = MinimumDate;
				Break;
			EndIf;
			Object.ImportBeginOfPeriod = Currency.ExchangeRateDate;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If NotifyThatRatesAreActual Then
		WorkWithCurrencyRatesClient.NotifyCoursesAreActual();
		Cancel = True;
		Return;
	EndIf;
	
	AttachIdleHandler("ValidateListOfExportableOfCurrency", 0.1, True);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersCurrencyList

&AtClient
Procedure CurrencyListSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	SwitchExport();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CurrencyRatesImport()
	
	ClearMessages();
	
	If Not ValueIsFilled(Object.ImportBeginOfPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Beginning date of loading period has not been defined';ru='Не задана дата начала периода загрузки.'"),
			,
			"Object.ImportBeginOfPeriod");
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.ImportEndOfPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='End date of loading period has not been defined';ru='Не задана дата окончания периода загрузки.'"),
			,
			"Object.ImportEndOfPeriod");
		Return;
	EndIf;
	
	ExecuteExchangeRatesImport();
	AttachIdleHandler("Attachable_CheckExecutionExchangeRatesImporting", 1, True);
	Items.Pages.CurrentPage = Items.CurrencyRatesImportProcessInProgress;
	Items.CommandBar.Enabled = False;
	
EndProcedure

&AtClient
Procedure SelectAllCurrencies(Command)
	SetChoice(True);
	SetEnabledOfItems();
EndProcedure

&AtClient
Procedure ClearChoice(Command)
	SetChoice(False);
	SetEnabledOfItems();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeRateDate.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.CurrenciesList.ExchangeRateDate");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = New StandardBeginningDate(Date('19800101000000'));

	Item.Appearance.SetParameterValue("Text", "");

EndProcedure

&AtClient
Procedure SetChoice(Selection)
	For Each Currency IN Object.CurrenciesList Do
		Currency.Import = Selection;
	EndDo;
EndProcedure

&AtServer
Procedure FillCurrencies()
	
	// Filling the tabular section with the list of currencies, the exchange rate of which is not dependent on the exchange rates of other currencies.
	ImportEndOfPeriod = Object.ImportEndOfPeriod;
	CurrenciesList = Object.CurrenciesList;
	CurrenciesList.Clear();
	
	ExportableCurrencies = WorkWithCurrencyRates.GetImportCurrenciesArray();
	
	For Each CurrencyItem IN ExportableCurrencies Do
		AddCurrencyToList(CurrencyItem);
	EndDo;
	
EndProcedure

&AtServer
Procedure AddCurrencyToList(Currency)
	
	// Adding a record in the currencies list.
	NewRow = Object.CurrenciesList.Add();
	
	// Filling the information about the exchange rate on the basis of the currency reference.
	FillTableRowDataBasedOnCurrency(NewRow, Currency);
	
	NewRow.Import = True;
	
EndProcedure

&AtServer
Procedure RefreshInfoInCurrenciesList()
	
	// Records update on the currencies exchange rates in the list.
	
	For Each DataRow IN Object.CurrenciesList Do
		CurrencyReferences = DataRow.Currency;
		FillTableRowDataBasedOnCurrency(DataRow, CurrencyReferences);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillTableRowDataBasedOnCurrency(TableRow, Currency);
	
	AdditionalInformationOnCurrency = CommonUse.ObjectAttributesValues(Currency, "DescriptionFull,Code,Description");
	
	TableRow.Currency = Currency;
	TableRow.CurrencyCode = AdditionalInformationOnCurrency.Code;
	TableRow.SymbolicCode = AdditionalInformationOnCurrency.Description;
	TableRow.Presentation = AdditionalInformationOnCurrency.DescriptionFull;
	
	ExchangeRateData = WorkWithCurrencyRates.FillRateDataForCurrencies(Currency);
	
	If TypeOf(ExchangeRateData) = Type ("Structure") Then
		TableRow.ExchangeRateDate = ExchangeRateData.ExchangeRateDate;
		TableRow.ExchangeRate      = ExchangeRateData.ExchangeRate;
		TableRow.Multiplicity = ExchangeRateData.Multiplicity;
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidateListOfExportableOfCurrency()
	If Object.CurrenciesList.Count() = 0 Then
		NotifyDescription = New NotifyDescription("CheckListImportableCurrenciesEnd", ThisObject);
		WarningText = NStr("en='In the currencies catalog there are no currencies the exchange rates of which is possible to export from the Internet.';ru='В справочнике валют отсутствуют валюты, курсы которых можно загружать из сети Интернет.'");
		ShowMessageBox(NOTifyDescription, WarningText);
	EndIf;
EndProcedure

&AtClient
Procedure CheckListImportableCurrenciesEnd(AdditionalParameters) Export
	Close();
EndProcedure

&AtClient
Procedure SetEnabledOfItems()
	
	AreSelectedCurrencies = Object.CurrenciesList.FindRows(New Structure("Import", True)).Count() > 0;
	Items.CurrencyRatesImportForm.Enabled = AreSelectedCurrencies;
	
EndProcedure

&AtClient
Procedure DisconnectExportRateOfSelectedCurrenciesFromInternet(Command)
	CurrentData = Items.CurrenciesList.CurrentData;
	ToRemoveExportFromInternetSignUp(CurrentData.Currency);
	Object.CurrenciesList.Delete(CurrentData);
EndProcedure

&AtServer
Procedure ToRemoveExportFromInternetSignUp(CurrencyRef)
	CurrencyObject = CurrencyRef.GetObject();
	CurrencyObject.SetRateMethod = Enums.CurrencyRateSetMethods.ManualInput;
	CurrencyObject.Write();
EndProcedure

&AtClient
Procedure SwitchExport()
	Items.CurrenciesList.CurrentData.Import = Not Items.CurrenciesList.CurrentData.Import;
	SetEnabledOfItems();
EndProcedure

&AtServer
Procedure ExecuteExchangeRatesImport()
	
	SetPrivilegedMode(True);
	
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.CurrencyRatesImportProcess);
	
	Filter = New Structure;
	Filter.Insert("ScheduledJob", ScheduledJob);
	Filter.Insert("State", BackgroundJobState.Active);
	BackgroundJobsCleanup = BackgroundJobs.GetBackgroundJobs(Filter);
	If BackgroundJobsCleanup.Count() > 0 Then
		BackgroundJobID = BackgroundJobsCleanup[0].UUID;
	Else
		ResultAddress = PutToTempStorage(Undefined, UUID);
		BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Launch manually: %1';ru='Запуск вручную: %1'"), ScheduledJob.Metadata.Synonym);
		
		ImportParameters = New Structure;
		ImportParameters.Insert("BeginOfPeriod", Object.ImportBeginOfPeriod);
		ImportParameters.Insert("EndOfPeriod", Object.ImportEndOfPeriod);
		ImportParameters.Insert("CurrenciesList", CommonUse.ValueTableToArray(Object.CurrenciesList.Unload(
			Object.CurrenciesList.FindRows(New Structure("Import", True)), "CurrencyCode,Currency")));
		
		JobParameters = New Array;
		JobParameters.Add(ImportParameters);
		JobParameters.Add(ResultAddress);
		
		BackgroundJob = BackgroundJobs.Execute(
			ScheduledJob.Metadata.MethodName,
			JobParameters,
			String(ScheduledJob.UUID),
			BackgroundJobDescription);
			
		BackgroundJobID = BackgroundJob.UUID;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckExecutionExchangeRatesImporting()
	
	Try
		JobCompleted = JobCompleted(BackgroundJobID);
	Except
		Items.Pages.CurrentPage = Items.PageCurrenciesList;
		Items.CommandBar.Enabled = True;
		Raise;
	EndTry;
	
	If JobCompleted(BackgroundJobID) Then
		Items.Pages.CurrentPage = Items.PageCurrenciesList;
		Items.CommandBar.Enabled = True;
		ImportResultProcessing();
	Else
		AttachIdleHandler("Attachable_CheckExecutionExchangeRatesImporting", 2, True);
	EndIf;
EndProcedure

&AtClient
Procedure ImportResultProcessing()
	
	ImportResult = GetFromTempStorage(ResultAddress);
	
	IsSuccessfullyImportedCurrencyRates = False;
	WithoutErrors = True;
	
	ErrorsCount = 0;
	
	ErrorList = New TextDocument;
	For Each ImportStatus IN ImportResult Do
		If ImportStatus.OperationStatus Then
			IsSuccessfullyImportedCurrencyRates = True;
		Else
			WithoutErrors = False;
			ErrorsCount = ErrorsCount + 1;
			ErrorList.AddLine(ImportStatus.Message + Chars.LF);
		EndIf;
	EndDo;
	
	If IsSuccessfullyImportedCurrencyRates Then
		RefreshInfoInCurrenciesList();
		WriteParameters = Undefined;
		UpdatedCurrenciesArray = New Array;
		For Each TableRow IN Object.CurrenciesList Do
			UpdatedCurrenciesArray.Add(TableRow.Currency);
		EndDo;
		Notify("Write_CurrencyRatesImportProcess", WriteParameters, UpdatedCurrenciesArray);
		WorkWithCurrencyRatesClient.NotifyCurrencyRatesSuccessfullyUpdated();
	EndIf;
	
	If WithoutErrors Then
		Close();
	Else
		ErrorPresentation = TrimAll(ErrorList.GetText());
		If ErrorsCount > 1 Then
			Buttons = New ValueList;
			Buttons.Add("Details", NStr("en='Details...';ru='Подробнее...'"));
			Buttons.Add("Continue", NStr("en='Continue';ru='Продолжить'"));
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Failed to import exchange rates  (%1).';ru='Не удалось загрузить курсы валют (%1).'"), ErrorsCount);
			NotifyDescription = New NotifyDescription("ImportResultProcessingWhenAnsweringQuestion", ThisObject, ErrorPresentation);
			ShowQueryBox(NOTifyDescription, QuestionText, Buttons);
		Else
			ShowMessageBox(, ErrorPresentation);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportResultProcessingWhenAnsweringQuestion(QuestionResult, ErrorPresentation) Export
	If QuestionResult <> "Details" Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.CurrencyRatesImportProcess.Form.ErrorMessages", New Structure("Text", ErrorPresentation));	
EndProcedure

&AtServerNoContext
Function JobCompleted(BackgroundJobID)
	Return LongActions.JobCompleted(BackgroundJobID);
EndFunction

&AtClient
Procedure ImportOnChange(Item)
	SetEnabledOfItems();
EndProcedure

#EndRegion














