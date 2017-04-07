
&AtClient
Var ExternalResourcesAllowed;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ExchangePlanName = Parameters.ExchangePlanName;
	
	If Not ValueIsFilled(ExchangePlanName) Then
		Return;
	EndIf;
	
	Title = StrReplace(Title, "%1", Metadata.ExchangePlans[ExchangePlanName].Synonym);
	
	RefreshRulesTemplateChoiceList();
	
	UpdateRuleInfo();
	
	Items.DebuggingGroup.Enabled = (RulesSource = "ExportedFromTheFile");
	Items.GroupSettingDebug.Enabled = DebugMode;
	Items.SourceFile.Enabled = (RulesSource = "ExportedFromTheFile");
	
	DataExchangeRuleImportingEventLogMonitorMessageText = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
	ApplicationName = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	LocationRulesSet = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
		"PathToRulesSetFileOnUsersWebsite, PathToRulesSetFileInTemplatesDirectory");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ToolTipTemplate = NStr("en='Rules set can be imported
		|from %1 or found in %2';ru='Комплект правил
		|можно скачать с %1 или найти в %2'");
	
	TemplateUpdatesDirectory = NStr("en='directory of the %1 application delivery';ru='каталоге поставки программы ""%1""'");
	TemplateUpdatesDirectory = StringFunctionsClientServer.SubstituteParametersInString(TemplateUpdatesDirectory, ApplicationName);
	
	TemplateUserWebsite = NStr("en='Users support website of 1C:Enterprise 8 system';ru='сайта поддержки пользователей системы ""1C:Предприятие 8""'");
	If Not IsBlankString(LocationRulesSet.PathToRulesSetFileOnUsersWebsite) Then
		TemplateUserWebsite = New FormattedString(TemplateUserWebsite,,,, LocationRulesSet.PathToRulesSetFileOnUsersWebsite);
	EndIf;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("ToolTipTemplate",            ToolTipTemplate);
	AdditionalParameters.Insert("TemplateUpdatesDirectory",    TemplateUpdatesDirectory);
	AdditionalParameters.Insert("TemplateUserWebsite", TemplateUserWebsite);
	
	If Not IsBlankString(LocationRulesSet.PathToRulesSetFileInTemplatesDirectory) Then
		
		AdditionalParameters.Insert("DirectoryDefault",                DirectoryAppData() + "1C\1Cv8\tmplts\");
		AdditionalParameters.Insert("TemplateUserSettings", DirectoryAppData() + "1C\1CEStart\1CEStart.cfg");
		AdditionalParameters.Insert("FileLocation",                 "");
		
		SuggestionText = NStr("en='To open a directory, you need to set an extension of working with files.';ru='Для открытия каталога необходимо необходимо установить расширение работы с файлами.'");
		Notification = New NotifyDescription("AfterWorksWithFilesExpansionCheck", ThisForm, AdditionalParameters);
		CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText);
		
	Else
		SetInformationTitleAboutReceipt(AdditionalParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterWorksWithFilesExpansionCheck(Result, AdditionalParameters) Export
	
	If Result Then
		File = New File();
		AdditionalParameters.Insert("NextAlert", New NotifyDescription("DetermineFileExistence", ThisForm, AdditionalParameters));
		Notification = New NotifyDescription("InitializeFile", ThisForm, AdditionalParameters);
		File.BeginInitialization(Notification, AdditionalParameters.TemplateUserSettings);
	Else
		SetInformationTitleAboutReceipt(AdditionalParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure InitializeFile(File, AdditionalParameters) Export
	File.StartExistenceCheck(AdditionalParameters.NextAlert);
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure DetermineFileExistence(Exists, AdditionalParameters) Export
	
	If Exists Then
		
		Text = New TextReader(AdditionalParameters.TemplateUserSettings, TextEncoding.UTF16);
		Str = "";
		
		While Str <> Undefined Do
			Str = Text.ReadLine();
			If Str = Undefined Then
				Break;
			EndIf;
			If Find(Upper(Str), Upper("ConfigurationTemplatesLocation")) = 0 Then
				Continue;
			EndIf;
			SeparatorPosition = Find(Str, "=");
			If SeparatorPosition = 0 Then
				Continue;
			EndIf;
			FoundDirectory = CommonUseClientServer.AddFinalPathSeparator(TrimAll(Mid(Str, SeparatorPosition + 1)));
			Break;
		EndDo;
		
		AdditionalParameters.FileLocation = FoundDirectory + LocationRulesSet.PathToRulesSetFileInTemplatesDirectory
		
	Else
		
		AdditionalParameters.FileLocation = AdditionalParameters.DirectoryDefault + LocationRulesSet.PathToRulesSetFileInTemplatesDirectory
		
	EndIf;
	
	File = New File();
	AdditionalParameters.NextAlert = New NotifyDescription("DetermineDirectoryExistence", ThisForm, AdditionalParameters);
	Notification = New NotifyDescription("InitializeFile", ThisForm, AdditionalParameters);
	File.BeginInitialization(Notification, AdditionalParameters.FileLocation);
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure DetermineDirectoryExistence(Exists, AdditionalParameters) Export
	
	If Exists Then
		AdditionalParameters.TemplateUpdatesDirectory = New FormattedString(AdditionalParameters.TemplateUpdatesDirectory,,,,
			AdditionalParameters.FileLocation);
	EndIf;
	
	SetInformationTitleAboutReceipt(AdditionalParameters);
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure SetInformationTitleAboutReceipt(AdditionalParameters)
	ToolTipText = SubstituteParametersForFormattedString(AdditionalParameters.ToolTipTemplate, 
		AdditionalParameters.TemplateUserWebsite,
		AdditionalParameters.TemplateUpdatesDirectory);
	Items.DecorationInformationAboutReceivingRules.Title = ToolTipText;
EndProcedure

&AtClient
Function CheckFillingOnClient()
	
	HasUnfilledFields = False;
	
	If DebugMode Then
		
		If ExportDebuggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(DataProcessorFileNameForExportDebugging);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en='External processing attachment file name is not specified.';ru='Не задано имя файла внешней обработки.'");
				CommonUseClientServer.MessageToUser(MessageString,, "DataProcessorFileNameForExportDebugging",, HasUnfilledFields);
				
			EndIf;
			
		EndIf;
		
		If ImportDebuggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(DataProcessorFileNameForImportDebugging);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en='External processing attachment file name is not specified.';ru='Не задано имя файла внешней обработки.'");
				CommonUseClientServer.MessageToUser(MessageString,, "DataProcessorFileNameForImportDebugging",, HasUnfilledFields);
				
			EndIf;
			
		EndIf;
		
		If DataExchangeLoggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(ExchangeProtocolFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en='Exchange protocol attachment file name is not specified.';ru='Не задано имя файла протокола обмена.'");
				CommonUseClientServer.MessageToUser(MessageString,, "ExchangeProtocolFileName",, HasUnfilledFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasUnfilledFields;
	
EndFunction

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure RulesSourceOnChange(Item)
	
	Items.DebuggingGroup.Enabled = (RulesSource = "ExportedFromTheFile");
	Items.SourceFile.Enabled = (RulesSource = "ExportedFromTheFile");
	
	If RulesSource = "StandardFromConfiguration" Then
		
		DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableDebuggingExportingsOnChange(Item)
	
	Items.ExternalDataProcessorForExportDebugging.Enabled = ExportDebuggingMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebuggingBeginChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en='External processor(*.epf)';ru='Внешняя обработка(*.epf)'") + "|*.epf" );
	
	DataExchangeClient.FileChoiceHandler(ThisObject, "DataProcessorFileNameForExportDebugging", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalProcessingForExportDebuggingBeginChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en='External processor(*.epf)';ru='Внешняя обработка(*.epf)'") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileChoiceHandler(ThisObject, "DataProcessorFileNameForImportDebugging", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForImportDebugging.Enabled = ImportDebuggingMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeLoggingOnChange(Item)
	
	Items.ProtocolExchangeFile.Enabled = DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ProtocolExchangeFileBeginChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en='Text document(*.txt)';ru='Текстовый документ(*.txt)'")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	DataExchangeClient.FileChoiceHandler(ThisObject, "ExchangeProtocolFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ProtocolExchangeFileOpen(Item, StandardProcessing)
	
	DataExchangeClient.HandlerOfOpeningOfFileOrDirectory(ThisObject, "ExchangeProtocolFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure EnableDebugModeOnChange(Item)
	
	Items.GroupSettingDebug.Enabled = DebugMode;
	
EndProcedure

&AtClient
Procedure DecorationInformationAboutGettingRulesDataProcessorNavigationRefs(Item, URL, StandardProcessing)
	
	If Find(URL, "http") = 0 Then
		
		StandardProcessing = False;
		
		Notification = New NotifyDescription("OpenDirectoryWithConfigurationsSupplies", ThisObject);
		BeginRunningApplication(Notification, URL);
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure OpenDirectoryWithConfigurationsSupplies(ReturnCode, AdditionalParameters) Export
	// No processing is required.
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportRules(Command)
	
	// From file from client
	NameParts = CommonUseClientServer.SplitFullFileName(RulesFilename);
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Title", NStr("en='Specify archive with exchange rules';ru='Укажите архив с правилами обмена'"));
	DialogueParameters.Insert("Filter", NStr("en='ZIP archives (*.zip)';ru='Архивы ZIP (*.zip)'") + "|*.zip");
	DialogueParameters.Insert("FullFileName", NameParts.DescriptionFull);
	
	Notification = New NotifyDescription("ImportRulesEnd", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogueParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonUseClientServer.SplitFullFileName(RulesFilename);

	// Export as an archive
	StorageAddress = GetRuleArchiveTempStorageAddressAtServer();
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en='Conversion rules';ru='Правила конвертации'");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Mode", FileDialogMode.Save);
	DialogueParameters.Insert("Title", NStr("en='Specify the file to which the rules should be exported';ru='Укажите в какой файл выгрузить правила'") );
	DialogueParameters.Insert("FullFileName", FullFileName);
	DialogueParameters.Insert("Filter", NStr("en='ZIP archives (*.zip)';ru='Архивы ZIP (*.zip)'") + "|*.zip");
	
	ReceivedFile = New Structure("Name, Storage", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileOnClient(ReceivedFile, DialogueParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
		
	If RulesSource = "StandardFromConfiguration" Then
		BeforeRulesImport(Undefined, "");
	Else
		If ConversionRulesSource = PredefinedValue("Enum.RuleSourcesForDataExchange.ConfigurationTemplate") Then
			
			ErrorDescription = NStr("en='Rules from file are not imported. Closure will result in using the typical conversion rules.
		|Use typical conversion rules?';ru='Правила из файла не загружены. Закрытие приведет к использованию типовых правил конвертации.
		|Использовать типовые правила конвертации?'");
			
			Notification = New NotifyDescription("CloseRulesImportForm", ThisObject);
			
			Buttons = New ValueList;
			Buttons.Add("Use", NStr("en='Use';ru='Использовать'"));
			Buttons.Add("Cancel", NStr("en='Cancel';ru='Отменить'"));
			
			FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
			FormParameters.DefaultButton = "Use";
			FormParameters.OfferDontAskAgain = False;
			
			StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription, Buttons, FormParameters);
		Else
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RefreshRulesTemplateChoiceList()
	
	Items.SourceConfigurationTemplate.CurrentPage = Items.PageOneTemplate;
	
EndProcedure

&AtClient
Procedure ImportRulesEnd(Val FilesPlacingResult, Val AdditionalParameters) Export
	
	PlacedFileAddress = FilesPlacingResult.Location;
	ErrorText           = FilesPlacingResult.ErrorDescription;
	
	If IsBlankString(ErrorText) AND IsBlankString(PlacedFileAddress) Then
		ErrorText = NStr("en='An error occurred during sending a settings file of data synchronization to server';ru='Ошибка передачи файла настроек синхронизации данных на сервер'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	// Sent file successfully, import on server.
	NameParts = CommonUseClientServer.SplitFullFileName(FilesPlacingResult.Name);
	
	If Lower(NameParts.Extension) <> ".zip" Then
		CommonUseClientServer.MessageToUser(NStr("en='Incorrect format of the rule set file. Awaiting zip archive containing
		|three files: ExchangeRules.xml - conversion rules for
		|the current application; CorrespondentExchangeRules.xml - conversion rules
		|for the application-correspondent; RegistrationRules.xml - rules of registration for the current application.';ru='Некорректный формат файла комплекта правил. Ожидается zip архив, содержащий три файла: ExchangeRules.xml - правила конвертации для текущей программы; CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента; RegistrationRules.xml - правила регистрации для текущей программы.'"));
	EndIf;
	
	BeforeRulesImport(PlacedFileAddress, NameParts.Name);
	
EndProcedure

&AtClient
Procedure ImportRulesExecute(Val PlacedFileAddress, Val FileName, ErrorDescription = Undefined)
	
	Cancel = False;
	
	Status(NStr("en='Importing rules to the infobase...';ru='Выполняется загрузка правил в информационную базу...'"));
	ImportRulesAtServer(Cancel, PlacedFileAddress, FileName, ErrorDescription);
	Status();
	
	If TypeOf(ErrorDescription) <> Type("Boolean") AND ErrorDescription <> Undefined Then
		
		Buttons = New ValueList;
		
		If ErrorDescription.ErrorKind = "IncorrectConfiguration" Then
			Buttons.Add("Cancel", NStr("en='Close';ru='Закрыть'"));
		Else
			Buttons.Add("Continue", NStr("en='Continue';ru='Продолжить'"));
			Buttons.Add("Cancel", NStr("en='Cancel';ru='Отменить'"));
		EndIf;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("PlacedFileAddress", PlacedFileAddress);
		AdditionalParameters.Insert("FileName", FileName);
		Notification = New NotifyDescription("AfterCheckConversionRulesForCompatibility", ThisObject, AdditionalParameters);
		
		FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		FormParameters.DefaultButton = "Cancel";
		FormParameters.Picture = ErrorDescription.Picture;
		FormParameters.OfferDontAskAgain = False;
		If ErrorDescription.ErrorKind = "IncorrectConfiguration" Then
			FormParameters.Title = NStr("en='Rules can not be imported';ru='Правила не могут быть загружены'");
		Else
			FormParameters.Title = NStr("en='Data synchronization may work incorrectly';ru='Синхронизация данных может работать некорректно'");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
		
	ElsIf Cancel Then
		ErrorText = NStr("en='Errors were found during the import.
		|Do you want to open the event log?';ru='При загрузке данных возникли ошибки.
		|Перейти в журнал регистрации?'");
		Notification = New NotifyDescription("ShowEventLogMonitorOnError", ThisObject);
		ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	Else
		ShowUserNotification(,, NStr("en='Rules have been successfully loaded to the infobase.';ru='Правила успешно загружены в информационную базу.'"));
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowEventLogMonitorOnError(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMonitorEvent", DataExchangeRuleImportingEventLogMonitorMessageText);
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportRulesAtServer(Cancel, TemporaryStorageAddress, RulesFilename, ErrorDescription)
	
	KitRulesSource = ?(RulesSource = "StandardFromConfiguration",
		Enums.RuleSourcesForDataExchange.ConfigurationTemplate, Enums.RuleSourcesForDataExchange.File);
	
	ConversionRulesRecord                               = InformationRegisters.DataExchangeRules.CreateRecordManager();
	ConversionRulesRecord.RuleKind                     = Enums.DataExchangeRuleKinds.ObjectConversionRules;
	ConversionRulesRecord.RulesTemplateName               = NameTemplateConversionRules;
	ConversionRulesRecord.RulesTemplateNameCorrespondent = RulesTemplateNameCorrespondent;
	ConversionRulesRecord.RulesInformation           = ConversionRulesInformation;
	
	FillPropertyValues(ConversionRulesRecord, ThisObject);
	ConversionRulesRecord.RulesSource = KitRulesSource;
	
	RegistrationRulesRecord                     = InformationRegisters.DataExchangeRules.CreateRecordManager();
	RegistrationRulesRecord.RuleKind           = Enums.DataExchangeRuleKinds.ObjectRegistrationRules;
	RegistrationRulesRecord.RulesTemplateName     = RulesTemplateNameRegistration;
	RegistrationRulesRecord.RulesInformation = RegistrationRulesInformation;
	RegistrationRulesRecord.RulesFilename      = RulesFilename;
	RegistrationRulesRecord.ExchangePlanName      = ExchangePlanName;
	RegistrationRulesRecord.RulesSource      = KitRulesSource;
	
	RegisterRecordsStructure = New Structure();
	RegisterRecordsStructure.Insert("ConversionRulesRecord", ConversionRulesRecord);
	RegisterRecordsStructure.Insert("RegistrationRulesRecord", RegistrationRulesRecord);
	
	InformationRegisters.DataExchangeRules.ImportRuleSet(Cancel, RegisterRecordsStructure,
		ErrorDescription, TemporaryStorageAddress, RulesFilename);
	
	If Not Cancel Then
		
		ConversionRulesRecord.Write();
		RegistrationRulesRecord.Write();
		
		Modified = False;
		
		// Cache of open sessions for the registration mechanism has become irrelevant.
		DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
		RefreshReusableValues();
		UpdateRuleInfo();
		
	EndIf;
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Create the temporary directory on server and generate paths to files and folders.
	TempFolderName = GetTempFileName("");
	CreateDirectory(TempFolderName);
	
	PathToFile               = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "ExchangeRules";
	PathToCorrespondentFile = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "CorrespondentExchangeRules";
	PathToRegistrationFile    = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "RegistrationRules";
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	DataExchangeRules.XML_Rules,
		|	DataExchangeRules.XMLRulesCorrespondent,
		|	DataExchangeRules.RuleKind
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		NString = NStr("en='Failed to receive exchange rules.';ru='Не удалось получить правила обмена.'");
		DataExchangeServer.ShowMessageAboutError(NString);
		Return "";
		
	Else
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			If Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
				
				// Receive, save and archive file of conversion rules in the temporary directory.
				RuleBinaryData = Selection.XML_Rules.Get();
				RuleBinaryData.Write(PathToFile + ".xml");
				
				// Receive, save and archive file of correspondent conversion rules in the temporary directory.
				CorrespondentRulesBinaryData = Selection.XMLRulesCorrespondent.Get();
				CorrespondentRulesBinaryData.Write(PathToCorrespondentFile + ".xml");
				
			Else
				// Receive, save and archive file of registration rules in the temporary directory.
				RegistrationRulesBinaryData = Selection.XML_Rules.Get();
				RegistrationRulesBinaryData.Write(PathToRegistrationFile + ".xml");
			EndIf;
			
		EndDo;
		
		FilePackingMask = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "*.xml";
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", FilePackingMask);
		
		// Place rules archive to the storage.
		RuleArchiveBinaryData = New BinaryData(PathToFile + ".zip");
		TemporaryStorageAddress = PutToTempStorage(RuleArchiveBinaryData);
		
		Return TemporaryStorageAddress;
		
	EndIf;
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	RulesInformation();
	
	RulesSource = ?(SourceRegistrationRules = Enums.RuleSourcesForDataExchange.File
		OR ConversionRulesSource = Enums.RuleSourcesForDataExchange.File,
		"ExportedFromTheFile", "StandardFromConfiguration");
	
	RulesInformationCommon = "[UsageInformation] [RegistrationRulesInformation] [ConversionRulesInformation]";
	
	If RulesSource = "ExportedFromTheFile" Then
		UsageInformation = NStr("en='Rights imported from file are used.';ru='Используются правила загруженные из файла.'");
	Else
		UsageInformation = NStr("en='Typical rules from the configuration content are used.';ru='Используются типовые правила из состава конфигурации.'");
	EndIf;
	
	RulesInformationCommon = StrReplace(RulesInformationCommon, "[InformationAboutUsage]", UsageInformation);
	RulesInformationCommon = StrReplace(RulesInformationCommon, "[ConversionRulesInformation]", ConversionRulesInformation);
	RulesInformationCommon = StrReplace(RulesInformationCommon, "[RegistrationRulesInformation]", RegistrationRulesInformation);
	
EndProcedure

&AtServer
Procedure RulesInformation()
	
	Query = New Query;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Query.Text = "SELECT
		|	DataExchangeRules.RulesTemplateName AS NameTemplateConversionRules,
		|	DataExchangeRules.RulesTemplateNameCorrespondent AS RulesTemplateNameCorrespondent,
		|	DataExchangeRules.DataProcessorFileNameForExportDebugging,
		|	DataExchangeRules.DataProcessorFileNameForImportDebugging,
		|	DataExchangeRules.RulesFilename AS FilenameConversionRules,
		|	DataExchangeRules.ExchangeProtocolFileName,
		|	DataExchangeRules.RulesInformation AS ConversionRulesInformation,
		|	DataExchangeRules.UseSelectiveObjectsRegistrationFilter,
		|	DataExchangeRules.RulesSource AS ConversionRulesSource,
		|	DataExchangeRules.DoNotStopOnError,
		|	DataExchangeRules.DebugMode,
		|	DataExchangeRules.ExportDebuggingMode,
		|	DataExchangeRules.ImportDebuggingMode,
		|	DataExchangeRules.DataExchangeLoggingMode
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)";
		
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
	Query.Text = "SELECT
		|	DataExchangeRules.RulesTemplateName AS RulesTemplateNameRegistration,
		|	DataExchangeRules.RulesFilename AS FilenameRulesRegistration,
		|	DataExchangeRules.RulesInformation AS RegistrationRulesInformation,
		|	DataExchangeRules.RulesSource AS SourceRegistrationRules
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectRegistrationRules)";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeRulesImport(Val PlacedFileAddress, Val FileName)
	
	If Not CheckFillingOnClient() Then
		Return;
	EndIf;
	
	If ExternalResourcesAllowed <> True Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("PlacedFileAddress", PlacedFileAddress);
		AdditionalParameters.Insert("FileName", FileName);
		ClosingAlert = New NotifyDescription("AllowExternalResourceEnd", ThisObject, AdditionalParameters);
		Queries = CreateQueryOnExternalResourcesUse();
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
		Return;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
	ImportRulesExecute(PlacedFileAddress, FileName);
	
EndProcedure

&AtClient
Procedure AllowExternalResourceEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		BeforeRulesImport(AdditionalParameters.PlacedFileAddress, AdditionalParameters.FileName);
	EndIf;
	
EndProcedure

&AtServer
Function CreateQueryOnExternalResourcesUse()
	
	PermissionsQueries = New Array;
	RegistrationFromFileRules = (RulesSource <> "StandardFromConfiguration");
	RecordStructure = New Structure;
	RecordStructure.Insert("ExchangePlanName", ExchangePlanName);
	RecordStructure.Insert("DebugMode", DebugMode);
	RecordStructure.Insert("ExportDebuggingMode", ExportDebuggingMode);
	RecordStructure.Insert("ImportDebuggingMode", ImportDebuggingMode);
	RecordStructure.Insert("DataExchangeLoggingMode", DataExchangeLoggingMode);
	RecordStructure.Insert("DataProcessorFileNameForExportDebugging", DataProcessorFileNameForExportDebugging);
	RecordStructure.Insert("DataProcessorFileNameForImportDebugging", DataProcessorFileNameForImportDebugging);
	RecordStructure.Insert("ExchangeProtocolFileName", ExchangeProtocolFileName);
	InformationRegisters.DataExchangeRules.QueryOnExternalResourcesUse(PermissionsQueries, RecordStructure, True, RegistrationFromFileRules);
	Return PermissionsQueries;
	
EndFunction

&AtClient
// Returns a formatted row built according to a template, for example, %1 went to %2.
//
// Parameters:
//     Pattern - String - preset for generation.
//     Row1 - String, FormattedString, Picture, Undefined - substitute value.
//     Row2 - String, FormattedString, Picture, Undefined - substitute value.
//
// Returns:
//     FormattedString - generated by the incoming parameters.
//
Function SubstituteParametersForFormattedString(Val Pattern,
	Val Row1 = Undefined, Val Row2 = Undefined)
	
	RowParts = New Array;
	ValidTypes = New TypeDescription("String, FormattedString, Picture");
	Begin = 1;
	
	While True Do
		
		Fragment = Mid(Pattern, Begin);
		
		Position = Find(Fragment, "%");
		
		If Position = 0 Then
			
			RowParts.Add(Fragment);
			
			Break;
			
		EndIf;
		
		Next = Mid(Fragment, Position + 1, 1);
		
		If Next = "1" Then
			
			Value = Row1;
			
		ElsIf Next = "2" Then
			
			Value = Row2;
			
		ElsIf Next = "%" Then
			
			Value = "%";
			
		Else
			
			Value = Undefined;
			
			Position  = Position - 1;
			
		EndIf;
		
		RowParts.Add(Left(Fragment, Position - 1));
		
		If Value <> Undefined Then
			
			Value = ValidTypes.AdjustValue(Value);
			
			If Value <> Undefined Then
				
				RowParts.Add( Value );
				
			EndIf;
			
		EndIf;
		
		Begin = Begin + Position + 1;
		
	EndDo;
	
	Return New FormattedString(RowParts);
	
EndFunction

// Define the My documents directory of the current Windows user.
//
&AtClient
Function DirectoryAppData()
	
	App = New COMObject("Shell.Application");
	Folder = App.Namespace(26);
	Result = Folder.Self.Path;
	Return CommonUseClientServer.AddFinalPathSeparator(Result);
	
EndFunction

&AtClient
Procedure AfterCheckConversionRulesForCompatibility(Result, AdditionalParameters) Export
	
	If Result <> Undefined AND Result.Value = "Continue" Then
		
		ErrorDescription = True;
		ImportRulesExecute(AdditionalParameters.PlacedFileAddress, AdditionalParameters.FileName, ErrorDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseRulesImportForm(Result, AdditionalParameters) Export
	If Result <> Undefined AND Result.Value = "Use" Then
		Close();
	EndIf;
EndProcedure

#EndRegion
