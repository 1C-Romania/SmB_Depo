////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Adds currencies from the classifier to the currencies catalog.
//
// Parameters:
//   Codes - Array - digit codes of the added currencies.
//
// Returns:
//   Array, CatalogRef.Currencies - created currencies refs.
//
Function AddCurrenciesByCode(Val Codes) Export
	Var XMLClassifier, ClassifierTable, WriteOKV, NewRow, Result;
	XMLClassifier = Catalogs.Currencies.GetTemplate("CurrencyClassifier").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(XMLClassifier).Data;
	
	Result = New Array();
	
	For Each Code IN Codes Do
		WriteOKV = ClassifierTable.Find(Code, "Code"); 
		If WriteOKV = Undefined Then
			Continue;
		EndIf;
		
		CurrencyRef = Catalogs.Currencies.FindByCode(WriteOKV.Code);
		If CurrencyRef.IsEmpty() Then
			NewRow 						  = Catalogs.Currencies.CreateItem();
			NewRow.Code         			  = WriteOKV.Code;
			NewRow.Description        	  = WriteOKV.CodeSymbol;
			NewRow.DescriptionFull        = WriteOKV.Name;
			If WriteOKV.RBCLoading Then
				NewRow.SetRateMethod = Enums.CurrencyRateSetMethods.ExportFromInternet;
			Else
				NewRow.SetRateMethod = Enums.CurrencyRateSetMethods.ManualInput;
			EndIf;
			NewRow.InWordParametersInHomeLanguage = WriteOKV.NumerationItemOptions;
			NewRow.Write();
			Result.Add(NewRow.Ref);
		Else
			Result.Add(CurrencyRef);
		EndIf
	EndDo; 
	
	Return	Result;
	
EndFunction

// Returns exchange rate for a date.
//
// Parameters:
//   Currency    - CatalogRef.Currencies - Currency for which currency rate is composed.
//   ExchangeRateDate - Date - Date for which currency rate is composed.
//
// Returns: 
//   Structure - Exchange rate parameters.
//       * ExchangeRate      - Number - Exchange rate for the specified date.
//       * Multiplicity - Number - Currency multiplicity for the specified date.
//       * Currency    - CatalogRef.Currencies - Ref currency.
//       * ExchangeRateDate - Date - Currency rate receipt date.
//
Function GetCurrencyRate(Currency, ExchangeRateDate) Export
	
	Result = InformationRegisters.CurrencyRates.GetLast(ExchangeRateDate, New Structure("Currency", Currency));
	
	Result.Insert("Currency",    Currency);
	Result.Insert("ExchangeRateDate", ExchangeRateDate);
	
	Return Result;
	
EndFunction

// Generates amount presentation in writing in the specified currency.
//
// Parameters:
//   AmountAsNumber - Number - amount that should be in writing.
//   Currency - CatalogRef.Currencies - currency in which amount should be presented.
//   DisplayAmountWithoutCents - Boolean - shows that amount is presented without kopeks.
//
// Returns:
//   String - amount in writing.
//
Function GenerateAmountInWords(AmountAsNumber, Currency, DisplayAmountWithoutCents = False) Export
	
	Amount				= ?(AmountAsNumber < 0, -AmountAsNumber, AmountAsNumber);
	SubjectParameters	= CommonUse.ObjectAttributesValues(Currency, "InWordParametersInEnglish");
	
	Result = NumberInWords(Amount, "L=en_US;FS=False", SubjectParameters.InWordParametersInEnglish);
	
	If DisplayAmountWithoutCents AND Int(Amount) = Amount Then
		Result = Left(Result, Find(Result, "0") - 1);
	EndIf;
	
	Return Result;
	
EndFunction

// Recalculates amount from one currency to another.
//
// Parameters:
//  Amount          - Number - amount that should be recalculated;
//  SourceCurrency - CatalogRef.Currencies - recalculated currency;
//  NewCurrency    - CatalogRef.Currencies - currency to which you should recalculate;
//  Date           - Date - exchange rates date.
//
// Returns:
//  Number - recalculated amount.
//
Function RecalculateToCurrency(Amount, SourceCurrency, NewCurrency, Date) Export
	
	Return WorkWithCurrencyRatesClientServer.RecalculateByRate(Amount,
		GetCurrencyRate(SourceCurrency, Date),
		GetCurrencyRate(NewCurrency, Date));
		
EndFunction

// Imports exchange rates for the current date.
//
// Parameters:
//  ExportParameters - Structure - import details:
//   * BeginOfPeriod - Date - import period start;
//   * EndOfPeriod - Date - import period end;
//   * CurrenciesList - ValueTable - imported currencies:
//     ** Currency - CatalogRef.Currencies;
//     ** CurrencyCode - String.
//  ResultAddress - String - address in the temporary storage to place import results there.
//
Procedure ImportActualRate(ExportParameters = Undefined, ResultAddress = Undefined) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Raise NStr("en='Invalid call of the ""ImportRelevantCurrencyRate"" procedure.';ru='Недопустимый вызов процедуры ""ЗагрузитьАктуальныйКурс"".'");
	EndIf;
	
	CommonUse.OnStartExecutingScheduledJob();
	
	EventName = NStr("en='Currency.Exchange rates import';ru='Валюты.Загрузка курсов валют'",
		CommonUseClientServer.MainLanguageCode());
	
	WriteLogEvent(EventName, EventLogLevel.Information, , ,
		NStr("en='Scheduled import of exchange rates is started';ru='Начата регламентная загрузка курсов валют'"));
	
	CurrentDate = CurrentSessionDate();
	
	ImportStatus = Undefined;
	ErrorsOccuredOnImport = False;
	
	If ExportParameters = Undefined Then
		QueryText = 
		"SELECT
		|	CurrencyRates.Currency AS Currency,
		|	CurrencyRates.Currency.Code AS CurrencyCode,
		|	MAX(CurrencyRates.Period) AS ExchangeRateDate
		|FROM
		|	InformationRegister.CurrencyRates AS CurrencyRates
		|WHERE
		|	CurrencyRates.Currency.SetRateMethod = VALUE(Enum.CurrencyRateSetMethods.ExportFromInternet)
		|	AND Not CurrencyRates.Currency.DeletionMark
		|
		|GROUP BY
		|	CurrencyRates.Currency,
		|	CurrencyRates.Currency.Code";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		
		EndOfPeriod = CurrentDate;
		While Selection.Next() Do
			BeginOfPeriod = ?(Selection.ExchangeRateDate = '198001010000', BegOfYear(CurrentDate), Selection.ExchangeRateDate + 60*60*24);
			CurrenciesList = CommonUseClientServer.ValueInArray(Selection);
			
			CurrencyRatesImportByParameters(
				CurrenciesList, BeginOfPeriod, EndOfPeriod, ErrorsOccuredOnImport);
		EndDo;
	Else
		Result = CurrencyRatesImportByParameters(ExportParameters.CurrenciesList,
			ExportParameters.BeginOfPeriod, ExportParameters.EndOfPeriod, ErrorsOccuredOnImport);
	EndIf;
		
	If ResultAddress <> Undefined Then
		PutToTempStorage(Result, ResultAddress);
	EndIf;

	If ErrorsOccuredOnImport Then
		WriteLogEvent(
			EventName,
			EventLogLevel.Error,
			, 
			,
			NStr("en='Errors occurred during the scheduled job of the exchange rate import';ru='Во время регламентного задания загрузки курсов валют возникли ошибки'"));
	Else
		WriteLogEvent(
			EventName,
			EventLogLevel.Information,
			,
			,
			NStr("en='Scheduled download of exchange rates is completed.';ru='Завершена регламентная загрузка курсов валют.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
		"WorkWithCurrencyRatesClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"WorkWithCurrencyRates");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"WorkWithCurrencyRates");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddWorkParametersClientOnStart"].Add(
		"WorkWithCurrencyRates");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
			"WorkWithCurrencyRates");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"WorkWithCurrencyRates");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"WorkWithCurrencyRates");
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		Or Not AccessRight("Update", Metadata.InformationRegisters.CurrencyRates)
		Or ModuleCurrentWorksService.WorkDisabled("CurrencyClassifier") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	ExchangeRatesAreRelevant = ExchangeRatesAreRelevant();
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.Catalogs.Currencies.FullName());
	
	If Sections = Undefined Then
		Return; // Interface of work with currencies is not in the user command interface.
	EndIf;
	
	For Each Section IN Sections Do
		
		CurrencyID = "CurrencyClassifier" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID  = CurrencyID;
		Work.ThereIsWork       = Not ExchangeRatesAreRelevant;
		Work.Presentation  = NStr("en='Exchange rates are outdated';ru='Курсы валют устарели'");
		Work.Important         = True;
		Work.Form          = "DataProcessor.CurrencyRatesImportProcess.Form";
		Work.FormParameters = New Structure("OpenFromList", True);
		Work.Owner       = Section;
		
	EndDo;
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  Handlers - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Cannot import to the currency classifier.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.Currencies.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.Currencies.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Fills out parameters that are used by the client code when launching the configuration.
//
// Parameters:
//   Parameters - Structure - Launch parameters.
//
Procedure OnAddWorkParametersClientOnStart(Parameters) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		ExchangeRatesAreRelevantUpdatedByResponsible = False; // Updated automatically in the service model.
	ElsIf Not AccessRight("Update", Metadata.InformationRegisters.CurrencyRates) Then
		ExchangeRatesAreRelevantUpdatedByResponsible = False; // User can not update exchange rates.
	Else
		ExchangeRatesAreRelevantUpdatedByResponsible = CurrencyRatesExportedFromInternet(); // There are currencies for which currency rates can be imported.
	EndIf;
	
	EnableAlert = Not CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks");
	WorkWithCurrencyRatesOverridable.OnDeterminingOfWarningsShowAboutOutDatedCurrencyRates(EnableAlert);
	
	Parameters.Insert("Currencies", New FixedStructure("ExchangeRatesAreRelevantUpdatedByResponsible", (ExchangeRatesAreRelevantUpdatedByResponsible AND EnableAlert)));
	
EndProcedure

// Fills the array with the list of metadata objects names that might include
// references to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.CurrencyRates.FullName());
	
EndProcedure

// Adds information about subsystem scheduled jobs for the service model to the table.
//
// Parameters:
//   UsageTable - ValueTable - Scheduled jobs table.
//      * ScheduledJob - String - Predefined scheduled job name.
//      * Use       - Boolean - True if scheduled job
//          should be executed in the service model.
//
Procedure OnDefenitionOfUsageOfScheduledJobs(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "CurrencyRatesImportProcess";
	NewRow.Use       = False;
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(permissions()));
	
EndProcedure

// Returns list of permissions for exchange rates import from RBC website.
//
// Returns:
//  Array.
//
Function permissions()
	
	Protocol = "HTTP";
	Address = "cbrates.rbc.ru";
	Port = Undefined;
	Definition = NStr("en='Import exchange rates from the Internet.';ru='Загрузка курсов валют из Интернета.'");
	
	permissions = New Array;
	permissions.Add( 
		WorkInSafeMode.PermissionForWebsiteUse(Protocol, Address, Port, Definition));
	
	Return permissions;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Checks whether there is fixed exchange rate and currency multiplicity on January 1, 1980.
// IN case of absence, sets currency rate and multiplicity equal to one.
//
// Parameters:
//  Currency - ref to the Currencies catalog item.
//
Procedure CheckRateOn01Correctness_01_1980(Currency) Export
	
	ExchangeRateDate = Date("19800101");
	StructureRate = InformationRegisters.CurrencyRates.GetLast(ExchangeRateDate, New Structure("Currency", Currency));
	
	If (StructureRate.ExchangeRate = 0) Or (StructureRate.Multiplicity = 0) Then
		RecordSet = InformationRegisters.CurrencyRates.CreateRecordSet();
		RecordSet.Filter.Currency.Set(Currency);
		Record = RecordSet.Add();
		Record.Currency = Currency;
		Record.Period = ExchangeRateDate;
		Record.ExchangeRate = 1;
		Record.Multiplicity = 1;
		RecordSet.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
		RecordSet.Write();
	EndIf;
	
EndProcedure

// Imports information about the Currency exchange rate from the
// PathToFile file to exchange rates information register. The file with the currency rate
// is parsed and only data that meets the period is written (ImportPeriodBegin, ImportPeriodEnd).
//
Function ImportCurrencyRateFromFile(Val Currency, Val PathToFile, Val ImportBeginOfPeriod, Val ImportEndOfPeriod) Export
	
	StatusExport = 1;
	
	NumberOfDaysExportTotal = 1 + (ImportEndOfPeriod - ImportBeginOfPeriod) / ( 24 * 60 * 60);
	
	NumberOfImportedDays = 0;
	
	If IsTempStorageURL(PathToFile) Then
		FileName = GetTempFileName();
		BinaryData = GetFromTempStorage(PathToFile);
		BinaryData.Write(FileName);
	Else
		FileName = PathToFile;
	EndIf;
	
	Text = New TextDocument();
	
	TableCurrencyRates = InformationRegisters.CurrencyRates;
	
	Text.Read(FileName, TextEncoding.ANSI);
	LineNumbers = Text.LineCount();
	
	For Ind = 1 To LineNumbers Do
		
		Str = Text.GetLine(Ind);
		If (Str = "") OR (Find(Str,Chars.Tab) = 0) Then
			Continue;
		EndIf;
		
		If ImportBeginOfPeriod = ImportEndOfPeriod Then
			ExchangeRateDate = ImportEndOfPeriod;
		Else
			RateDateStr = SelectSubString(Str);
			ExchangeRateDate    = Date(Left(RateDateStr,4), Mid(RateDateStr,5,2), Mid(RateDateStr,7,2));
		EndIf;
		
		Multiplicity = Number(SelectSubString(Str));
		ExchangeRate      = Number(SelectSubString(Str));
		
		If ExchangeRateDate > ImportEndOfPeriod Then
			Break;
		EndIf;
		
		If ExchangeRateDate < ImportBeginOfPeriod Then 
			Continue;
		EndIf;
		
		WriteCoursesOfCurrency = TableCurrencyRates.CreateRecordManager();
		
		WriteCoursesOfCurrency.Currency    = Currency;
		WriteCoursesOfCurrency.Period    = ExchangeRateDate;
		WriteCoursesOfCurrency.ExchangeRate      = ExchangeRate;
		WriteCoursesOfCurrency.Multiplicity = Multiplicity;
		WriteCoursesOfCurrency.Write();
		
		NumberOfImportedDays = NumberOfImportedDays + 1;
	EndDo;
	
	If IsTempStorageURL(PathToFile) Then
		DeleteFiles(FileName);
		DeleteFromTempStorage(PathToFile);
	EndIf;
	
	If NumberOfDaysExportTotal = NumberOfImportedDays Then
		ExplanationAboutExporting = "";
	ElsIf NumberOfImportedDays = 0 Then
		ExplanationAboutExporting = NStr("en='Exchange rates %1 - %2 are not imported. No data available.';ru='Курсы валюты %1 - %2 не загружены. Нет данных.'");
	Else
		ExplanationAboutExporting = NStr("en='Not all exchange rates for currency %1 are imported - %2.';ru='Загружены не все курсы по валюте %1 - %2.'");
	EndIf;
	
	ExplanationAboutExporting = StringFunctionsClientServer.SubstituteParametersInString(
									ExplanationAboutExporting,
									Currency.Code,
									Currency.Description);
	
	UserMessages = GetUserMessages(True);
	ErrorList = New Array;
	For Each UserMessage IN UserMessages Do
		ErrorList.Add(UserMessage.Text);
	EndDo;
	ErrorList = CommonUseClientServer.CollapseArray(ErrorList);
	ExplanationAboutExporting = ?(IsBlankString(ExplanationAboutExporting), "", Chars.LF) + StringFunctionsClientServer.RowFromArraySubrows(ErrorList, Chars.LF);
	
	Return ExplanationAboutExporting;
	
EndFunction

// Returns currencies array currency rates of which are imported from the RBC website.
//
Function GetImportCurrenciesArray() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.CurrencyRateSetMethods.ExportFromInternet)
	|	AND Not Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.DescriptionFull";

	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns information about the exchange rate by reference to the currency.
// Data is returned as a structure.
//
// Parameters:
// SelectedCurrency - Catalog.Currencies / Ref - ref to the
//                  currency, currency rate information of which should be received.
//
// Returns:
// ExchangeRateData   - structure containing information about the
// latest available currency rate record.
//
Function FillRateDataForCurrencies(SelectedCurrency) Export
	
	ExchangeRateData = New Structure("ExchangeRateDate, ExchangeRate, Multiplicity");
	
	Query = New Query;
	
	Query.Text = "SELECT RegCurrencyRates.Period, RegCurrencyRates.ExchangeRate, RegCurrencyRates.Multiplicity
	              | FROM InformationRegister.CurrencyRates.SliceLast(&ImportEndOfPeriod, Currency = &SelectedCurrency) AS RegCurrencyRates";
	Query.SetParameter("SelectedCurrency", SelectedCurrency);
	Query.SetParameter("ImportEndOfPeriod", CurrentSessionDate());
	
	SelectionExchangeRate = Query.Execute().Select();
	SelectionExchangeRate.Next();
	
	ExchangeRateData.ExchangeRateDate = SelectionExchangeRate.Period;
	ExchangeRateData.ExchangeRate      = SelectionExchangeRate.ExchangeRate;
	ExchangeRateData.Multiplicity = SelectionExchangeRate.Multiplicity;
	
	Return ExchangeRateData;
	
EndFunction

// Returns values table - currencies that
// depend on the passed as a parameter.
// Return
// value
// ValuesTable column "Ref". - CatalogRef.Currencies
// "Markup" column - Number
//
Function DependentCurrenciesList(CurrencyBasic, AdditionalProperties = Undefined) Export
	
	Cached = (TypeOf(AdditionalProperties) = Type("Structure"));
	
	If Cached Then
		
		DependentCurrencies = AdditionalProperties.DependentCurrencies.Get(CurrencyBasic);
		
		If TypeOf(DependentCurrencies) = Type("ValueTable") Then
			Return DependentCurrencies;
		EndIf;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CatCurrencies.Ref,
	|	CatCurrencies.Markup,
	|	CatCurrencies.SetRateMethod,
	|	CatCurrencies.RateCalculationFormula
	|FROM
	|	Catalog.Currencies AS CatCurrencies
	|WHERE
	|	(CatCurrencies.MainCurrency = &CurrencyBasic
	|			OR CatCurrencies.RateCalculationFormula LIKE &SymbolicCode)";
	
	Query.SetParameter("CurrencyBasic", CurrencyBasic);
	Query.SetParameter("SymbolicCode", "%" + CommonUse.ObjectAttributeValue(CurrencyBasic, "Description") + "%");
	
	DependentCurrencies = Query.Execute().Unload();
	
	If Cached Then
		
		AdditionalProperties.DependentCurrencies.Insert(CurrencyBasic, DependentCurrencies);
		
	EndIf;
	
	Return DependentCurrencies;
	
EndFunction

// Procedure for exchange rates import by a certain period.
//
// Parameters:
// Currencies		- Any collection - with the following fields:
// 				CurrencyCode - currency numeric code.
// 				Currency - ref on currency.
// ImportBeginOfPeriod	- Date - start of the currency rates import period.
// ImportEndOfPeriod	- Date - end of currency rates import period.
//
// Returns:
// Import state array  - each item - structure with fields.
// 	Currency - imported currency.
// 	OperationStatus - if the import is complete successfully.
// 	Message - import explanation (error message text or an explanatory message).
//
Function CurrencyRatesImportByParameters(Val Currencies, Val ImportBeginOfPeriod, Val ImportEndOfPeriod, 
	ErrorsOccuredOnImport = False) Export
	
	ImportStatus = New Array;
	
	ErrorsOccuredOnImport = False;
	
	ServerSource = "cbrates.rbc.ru";
	
	If ImportBeginOfPeriod = ImportEndOfPeriod Then
		Address = "tsv/";
		Tmp   = Format(ImportEndOfPeriod, "DF=/yyyy/MM/dd"); // Not localized - path to file on server.
	Else
		Address = "tsv/cb/";
		Tmp   = "";
	EndIf;
	
	For Each Currency IN Currencies Do
		FileOnWebServer = "http://" + ServerSource + "/" + Address + Right(Currency.CurrencyCode, 3) + Tmp + ".tsv";
		
		#If Client Then
			Result = GetFilesFromInternetClient.ExportFileAtClient(FileOnWebServer);
		#Else
			Result = GetFilesFromInternet.ExportFileAtServer(FileOnWebServer);
		#EndIf
		
		If Result.Status Then
			#If Client Then
				BinaryData = New BinaryData(Result.Path);
				AddressInTemporaryStorage = PutToTempStorage(BinaryData);
				ExplainingMessage = WorkWithCurrencyRatesServerCall.ImportCurrencyRateFromFile(Currency.Currency, AddressInTemporaryStorage, ImportBeginOfPeriod, ImportEndOfPeriod) + Chars.LF;
			#Else
				ExplainingMessage = ImportCurrencyRateFromFile(Currency.Currency, Result.Path, ImportBeginOfPeriod, ImportEndOfPeriod) + Chars.LF;
			#EndIf
			DeleteFiles(Result.Path);
			OperationStatus = IsBlankString(ExplainingMessage);
		Else
			ExplainingMessage = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Unable to receive data file with exchange rates
		|%1
		|- %2): %3 There may not be an access to website with exchange rates or non-existent currency is specified.';ru='Невозможно получить файл данных с
		|курсами
		|валюты (%1 - %2): %3 Возможно, нет доступа к веб сайту с курсами валют, либо указана несуществующая валюта.'"),
				Currency.CurrencyCode,
				Currency.Currency,
				Result.ErrorInfo);
			OperationStatus = False;
			ErrorsOccuredOnImport = True;
		EndIf;
		
		ImportStatus.Add(New Structure("Currency,OperationStatus,Message", Currency.Currency, OperationStatus, ExplainingMessage));
		
	EndDo;
	
	Return ImportStatus;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.9";
	Handler.Procedure = "WorkWithCurrencyRates.UpdateSignatureStorageFormatInEnglish";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.4.4";
	Handler.Procedure = "WorkWithCurrencyRates.UpdateCurrency937Information";
	Handler.PerformModes = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.10";
	Handler.Procedure = "WorkWithCurrencyRates.FillExchangeRateSettingMethod";
	Handler.PerformModes = "Exclusive";
	
EndProcedure

// Handler of the signatures storage format update while transitioning to the latest SSL version.
//
Procedure UpdateHandwritingStorageFormatInRussian() Export
	
	SelectionOfCurrency = Catalogs.Currencies.Select();
	
	While SelectionOfCurrency.Next() Do
		Object = SelectionOfCurrency.GetObject();
		ParameterString = StrReplace(Object.InWordParametersInHomeLanguage, ",", Chars.LF);
		Par1 = Lower(Left(TrimAll(StrGetLine(ParameterString, 4)), 1));
		Gender2 = Lower(Left(TrimAll(StrGetLine(ParameterString, 8)), 1));
		Object.InWordParametersInHomeLanguage = 
					  TrimAll(StrGetLine(ParameterString, 1)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 2)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 3)) + ", "
					+ Par1 + ", "
					+ TrimAll(StrGetLine(ParameterString, 5)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 6)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 7)) + ", "
					+ Gender2 + ", "
					+ TrimAll(StrGetLine(ParameterString, 9));
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Updates information about currency according to the document "Change 33/2012 RCC Russian Classification of Currencies.
// OK (MK (ISO 4217) 003-97) 014-2000" (adopted and put into action by Rosstandard Order dated December 12, 2012 No 1883-art).
//
Procedure RefreshDataOnAdditionalCurrency937() Export
	Currency = Catalogs.Currencies.FindByCode("937");
	If Not Currency.IsEmpty() Then
		Currency = Currency.GetObject();
		Currency.Description = "VEF";
		Currency.DescriptionFull = NStr("en='Bolivar';ru='Боливар'");
		InfobaseUpdate.WriteData(Currency);
	EndIf;
EndProcedure

// FIlls in the CurrencyRateSettingMethod attribute in the Currencies catalog items.
Procedure FillExchangeRatesSettingMethod() Export
	Selection = Catalogs.Currencies.Select();
	While Selection.Next() Do
		Currency = Selection.Ref.GetObject();
		If Currency.ExportingFromInternet Then
			Currency.SetRateMethod = Enums.CurrencyRateSetMethods.ExportFromInternet;
		ElsIf Not Currency.MainCurrency.IsEmpty() Then
			Currency.SetRateMethod = Enums.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies;
		Else
			Currency.SetRateMethod = Enums.CurrencyRateSetMethods.ManualInput;
		EndIf;
		Currency.Write();
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Update of the currency exchange rates

// Checks the exchange rates relevance of all the currencies.
//
Function ExchangeRatesAreRelevant() Export
	QueryText =
	"SELECT
	|	Currencies.Ref AS Ref
	|INTO TTCurrencies
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.CurrencyRateSetMethods.ExportFromInternet)
	|	AND Currencies.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	TTCurrencies AS Currencies
	|		LEFT JOIN InformationRegister.CurrencyRates AS CurrencyRates
	|		ON Currencies.Ref = CurrencyRates.Currency
	|			AND (CurrencyRates.Period = &CurrentDate)
	|WHERE
	|	CurrencyRates.Currency IS NULL ";
	
	Query = New Query;
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	Query.Text = QueryText;
	
	Return Query.Execute().IsEmpty();
EndFunction

// Determines whether there is at least one currency, currency rate of which is imported from the Internet.
//
Function CurrencyRatesExportedFromInternet()
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.CurrencyRateSetMethods.ExportFromInternet)
	|	AND Currencies.DeletionMark = FALSE";
	Return Not Query.Execute().IsEmpty();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// Highlights from the passed
//  string the first value up to the "TAB" character.
//
// Parameters: 
//  SourceLine - String - String for parsing.
//
// Returns:
//  subrow up to the "TAB" character
//
Function SelectSubString(SourceLine)
	
	Var Substring;
	
	Pos = Find(SourceLine,Chars.Tab);
	If Pos > 0 Then
		Substring = Left(SourceLine,Pos-1);
		SourceLine = Mid(SourceLine,Pos + 1);
	Else
		Substring = SourceLine;
		SourceLine = "";
	EndIf;
	
	Return Substring;
	
EndFunction

// Returns currencies list currency rates of which are imported from the Internet.
Function CurrenciesImportedFromInternet() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Currency,
	|	Currencies.Code AS CurrencyCode
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.CurrencyRateSetMethods.ExportFromInternet)
	|	AND Not Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.DescriptionFull";

	Return Query.Execute().Unload();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Updates links between currencies catalog and supplied
// currency rates file depending on the currencies setting method.
//
// Parameters:
//   Currency - CatalogObject.Currencies
//
Function OnUpdatingCurrencyRatesSaaS(Currency) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.CurrenciesSaaS") Then
		ModuleCurrencyRatesServiceSaaS = CommonUse.CommonModule("CurrencyRatesServiceSaaS");
		ModuleCurrencyRatesServiceSaaS.PlanCopyingRatesOfCurrency(Currency);
	EndIf;
	
EndFunction

#EndRegion
