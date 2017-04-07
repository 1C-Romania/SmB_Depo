// Form is parameterized. Optional parameters:
//
//     StateCodeForImport  - Number, String, Array - The code of the RF constituent entity
//                           (or the array) offered to be imported.
//     StateNameForImporting - String                - The name of the RF constituent entity offered to be imported.
//     Mode                 - String                - Form working mode.
//
//   If the StateCodeForImport or RegionNameForImport parameter is specified, the offered
// region or regions will be marked for importing and the first is selected as the current one.
//   If the Mode parameter is CheckingUpdate, the update checking on the site will be started and offered to import the updated ones.
//

&AtClient
Var ClosingFormConfirmation;

// Import parameters to transfer between the client calls.
&AtClient
Var ClassifierBackgroundImportParameters;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ParametersOfLongOperation = New Structure("Completed, ResultAddress, ID, Error, DetailErrorDescription");
	ParametersOfLongOperation.Insert("WaitInterval", 5);
	
	FillPropertyValues(AvailableImportingSources.Add(), Items.AvailableImportingSources.ChoiceList[0]);
	FillPropertyValues(AvailableImportingSources.Add(), Items.AvailableImportingSources.ChoiceList[1]);
	
	// It is possible that the default value will be overridden at the setting recovery.
	ImportingSourceCode = "DIRECTORY";
	
	// Receive already loaded states.
	StateTable = AddressClassifierService.InformationAboutRFTerritorialEntitiesImport();
	StateTable.Columns.Add("Import", New TypeDescription("Boolean"));
	
	For Each Region IN StateTable Do
		Region.Presentation = " " + Format(Region.RFTerritorialEntityCode, "ND=2; NZ=; NLZ=; NG=") + ", " + Region.Presentation;
	EndDo;
	
	CurrentStateCode = Undefined;
	Parameters.Property("StateCodeForImport", CurrentStateCode);
	
	// Analyze work variants - we can be called to check the update.
	IdsForUpdates = New Array;
	If Parameters.Property("Mode") AND Parameters.Mode = "CheckUpdate" Then
		AvailableVersions = AddressClassifierService.AddressInformationAvailableVersions();
		
		Filter = New Structure("Imported, UpdateAvailable", True, True);
		UpdatedData = AvailableVersions.Copy(Filter);
		NumberOfUpdates = UpdatedData.Count();
		
		If NumberOfUpdates > 0 Then
			Title = NStr("en='Address classifier update is available.';ru='Доступно обновление адресного классификатора.'");
			ImportingSourceCode = "Site";
			// Import only the updated and perhaps added RF constituent entities!
			IdsForUpdates = UpdatedData.UnloadColumn("ID");
		Else
			WarningOnOpening = NStr("en='Address classifier update is not required.
		|Actual address information is already imported to the application.';ru='Обновление адресного классификатора не требуется.
		|В программу уже загружены актуальные адресные сведения.'");
			Return;
			
		EndIf;
		
	Else
		// Import all already imported ones.
		StateTable.LoadColumn(StateTable.UnloadColumn("Exported"), "Import");
	EndIf;
	
	// Add the mark for the loaded parameter-state and make it current string.
	TypeCurrentStateCode = TypeOf(CurrentStateCode);
	NumberType               = New TypeDescription("Number");
	
	If IdsForUpdates.Count() > 0 Then
		// Update strictly specified ones.
		Filter = New Structure("ID");
		For Each ID IN IdsForUpdates Do 
			Filter.ID = ID;
			Candidates = StateTable.FindRows(Filter); 
			If Candidates.Count() > 0 Then
				Candidates[0].Import = True;
			EndIf;
		EndDo;
		
	ElsIf TypeCurrentStateCode = Type("Array") AND CurrentStateCode.Count() > 0 Then
		// The array for importing is specified
		Filter = New Structure("RFTerritorialEntityCode");
		For Each StateCode IN CurrentStateCode Do 
			Filter.RFTerritorialEntityCode = NumberType.AdjustValue(StateCode);
			Candidates = StateTable.FindRows(Filter); 
			If Candidates.Count() > 0 Then
				Candidates[0].Import = True;
			EndIf;
		EndDo;
		CurrentStateCode = CurrentStateCode[0];
		
	ElsIf TypeCurrentStateCode = Type("String") Then
		// As the code
		CurrentStateCode = NumberType.AdjustValue(CurrentStateCode);
		
	ElsIf Parameters.Property("StateNameForImporting") Then
		// As the name
		CurrentStateCode = AddressClassifier.StateCodeByName(Parameters.StateNameForImporting);
		
	EndIf;
	
	ValueToFormAttribute(StateTable, "RFTerritorialEntities");
	
	// Current string setting by the code.
	If CurrentStateCode <> Undefined Then
		Candidates = RFTerritorialEntities.FindRows(New Structure("RFTerritorialEntityCode",  CurrentStateCode)); 
		If Candidates.Count() > 0 Then
			CurrentRow = Candidates[0];
			CurrentRow.Import = True;
			Items.RFTerritorialEntities.CurrentRow = CurrentRow.GetID();
		EndIf;
	EndIf;
	
	// If the current string is not specified by the parameter, try to place it on the first marked.
	If Items.RFTerritorialEntities.CurrentRow = Undefined Then
		Candidates = RFTerritorialEntities.FindRows(New Structure("Import", True)); 
		If Candidates.Count() > 0 Then
			Items.RFTerritorialEntities.CurrentRow = Candidates[0].GetID();
		EndIf;
	EndIf;
	
	// Dependencies on the interface
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.ImportAddress.SelectionButtonImage = New Picture;
	EndIf;
	
	Authentication = SavedSiteAuthenticationData();
	Items.AuthorizationOnUsersSupportSite.Visible = IsBlankString(Authentication.Password);

	// Settings auto save
	SavedInSettingsDataModified = True;
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	// Control the correctness of the data source code for importing.
	SourceCode = Settings["ImportingSourceCode"];
	If AvailableImportingSources.FindByValue(SourceCode) = Undefined Then
		// Leave the defaults
		Settings.Delete("ImportingSourceCode");
		Settings.Delete("ImportAddress");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If WarningOnOpening <> "" Then
		ShowMessageBox(, WarningOnOpening);
		Cancel = True;
		Return;
	EndIf;
	
	If NumberOfUpdates > 0 Then
		ImportingSourceCode = "Site";
	EndIf;
	
	RefreshInterfaceByCountImported();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Items.ImportSteps.CurrentPage <> Items.ImportingWait 
		Or ClosingFormConfirmation = True Then
		Return;
	EndIf;		
	
	Notification = New NotifyDescription("CloseFormEnd", ThisObject);
	Cancel = True;
	
	Text = NStr("en='Interrupt the address classifier loading?';ru='Прервать загрузку адресного классификатора?'");
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If ParametersOfLongOperation.ID <> Undefined Then
		CancelBackgroundJob(ParametersOfLongOperation.ID);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure RFTerritorialEntitiesSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Field = Items.RFTerritorialEntitiesRepresentation Then
		CurrentData = RFTerritorialEntities.FindByID(SelectedRow);
		If CurrentData <> Undefined Then
			CurrentData.Import = Not CurrentData.Import;
			RefreshInterfaceByCountImported();
		EndIf
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportingAddressStartChoice(Item, ChoiceData, StandardProcessing)
	
	AddressClassifierClient.ChooseDirectory(ThisObject, "ImportAddress", 
		NStr("en='Directory with the address classifier files';ru='Каталог с файлами адресного классификатора'"),
		StandardProcessing,
		New NotifyDescription("EndImportingAddressDirectorySelection", ThisObject)
	);
	
EndProcedure

&AtClient
Procedure ImportRFTerritorialEntitiesOnChange(Item)
	
	RefreshInterfaceByCountImported();
	
EndProcedure

&AtClient
Procedure ImportingAvailableSourcesOnChange(Item)
	
	SetImportingSourceEnabled();
	
EndProcedure

&AtClient
Procedure ImportingAddressOnChange(Item)
	
	SetDirectoryAsImportingSource();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CheckAll(Command)
	
	SetStateListMarks(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	SetStateListMarks(False);
	
EndProcedure

&AtClient
Procedure Import(Command)
	
	If ImportingSourceCode = "DIRECTORY" Then
		Text = NStr("en='To import address classifier from
		|the folder it is neseccary to set the extension for work with files.';ru='Для загрузки адресного классификатора
		|из папки необходимо установить расширение для работы с файлами.'");
		ExtensionControlWorksWithFile(Text, ImportingSourceCode, ImportAddress);
		
	ElsIf ImportingSourceCode = "Site" Then
		ImportClassifierFromSite();
		
	Else
		CommonUseClientServer.MessageToUser( NStr("en='Classifier import variant is not specified.';ru='Не указан вариант загрузки классификатора.'") );
	EndIf;
		
EndProcedure

&AtClient
Procedure BreakImport(Command)
	
	ClosingFormConfirmation = Undefined;
	Close();
	
EndProcedure

&AtClient
Procedure AuthorizationOnUsersSupportSite(Command)
	
	StandardSubsystemsClient.AuthorizeOnUserSupportSite(ThisObject);
	
EndProcedure

&AtClient
Procedure CloseWithoutConfirmation(Command)
	
	ClosingFormConfirmation = True;
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ExtensionControlWorksWithFile(Val SuggestionText, Val SourceCode, Val SourceAddress)
	
	Notification = New NotifyDescription("WorksWithFilesExtensionControlEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("ImportingSourceCode", SourceCode);
	Notification.AdditionalParameters.Insert("ImportAddress",        SourceAddress);
	
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
EndProcedure

// End of the dialog offering the extension to work with files.
//
&AtClient
Procedure WorksWithFilesExtensionControlEnd(Val Result, Val AdditionalParameters) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	ImportClassifierFromDirectory(AdditionalParameters.ImportAddress);
	
EndProcedure

// End dialog of form closing.
&AtClient
Procedure CloseFormEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult = DialogReturnCode.Yes Then
		ClosingFormConfirmation = True;
		Close();
	Else 
		ClosingFormConfirmation = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure SetImportingPermission(Val CountImporting = Undefined)
	
	If CountImporting = Undefined Then
		Filter = New Structure("Import", True);
		CountImporting = RFTerritorialEntities.FindRows(Filter).Count();
	EndIf;
	
	Items.Import.Enabled = (CountImporting > 0)
		AND AvailableImportingSources.FindByValue(ImportingSourceCode) <> Undefined;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	Fields = Item.Fields.Items;
	Fields.Add().Field = New DataCompositionField("RFTerritorialEntitiesRFEntityCode");
	Fields.Add().Field = New DataCompositionField("RFTerritorialEntitiesRepresentation");

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("RFTerritorialEntities.Exported");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Black);
EndProcedure

&AtClient
Procedure SetStateListMarks(Val Check)
	
	// Set marks only for visible strings.
	TableElement = Items.RFTerritorialEntities;
	For Each StateRow IN RFTerritorialEntities Do
		If TableElement.RowData( StateRow.GetID() ) <> Undefined Then
			StateRow.Import = Check;
		EndIf;
	EndDo;
	
	RefreshInterfaceByCountImported();
EndProcedure

&AtClient
Procedure RefreshInterfaceByCountImported()
	
	// Choice page
	ChosenStatesForExport = RFTerritorialEntities.FindRows( New Structure("Import", True) ).Count();
	
	// Import page
	ImportingDescriptionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Data of the selected states (%1) is loaded.';ru='Загружаются данные по выбранным регионам (%1)'"), ChosenStatesForExport 
	);
	
	SetImportingPermission(ChosenStatesForExport);
EndProcedure

&AtClient
Procedure ImportClassifierFromDirectory(Val DataDirectory)
	
	CodesOfStates = StateCodesForImporting();
	
	// Check files for accessibility and availability.
	ImportParameters = New Structure("ImportingSourceCode, ErrorField", ImportingSourceCode, "ImportAddress");
	NotifyDescription = New NotifyDescription("ImportClassifierFromEndDirectory", ThisObject);
	AddressClassifierClient.AnalysisClassifierFilesAvailabilityInDirectory(NOTifyDescription, CodesOfStates, DataDirectory, ImportParameters);
	
EndProcedure

&AtClient
Procedure ImportClassifierFromEndDirectory(ResultAnalysis, AdditionalParameters) Export
	
	If ResultAnalysis.Errors <> Undefined Then
		// The files are not enough for importing based on the specified modes.
		ClearMessages();
		CommonUseClientServer.ShowErrorsToUser(ResultAnalysis.Errors);
		Return;
	EndIf;
	
	// Import in the background
	DeleteAfterTransferToServer = New Array;
	ResultAnalysis.Insert("DeleteAfterTransferToServer", DeleteAfterTransferToServer);
	
	RunBackgroundImportingFromClientDirectory(ResultAnalysis);
	
EndProcedure

&AtClient
Procedure ImportClassifierFromSite(Val Authentication = Undefined)
	
	CodesOfStates = StateCodesForImporting();
	
	If Authentication = Undefined Then
		Authentication = SavedSiteAuthenticationData();
	EndIf;
	
	If IsBlankString(Authentication.Password) Then
		// We authorize forcefully.
		Notification = New NotifyDescription("ImportClassifierFromAuthenticationQuerySite", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("CodesOfStates", CodesOfStates);
		StandardSubsystemsClient.AuthorizeOnUserSupportSite(ThisObject, Notification);
		Return;
	EndIf;
	
	ImportClassifierFromAuthenticationSite(Authentication, CodesOfStates);
EndProcedure

// Authorization dialog end.
//
&AtClient
Procedure ImportClassifierFromAuthenticationQuerySite(Val Authentication, Val AdditionalParameters) Export
	
	If TypeOf(Authentication) <> Type("Structure") Then
		// Back to the selection page.
		Items.ImportSteps.CurrentPage = Items.ImportingStatesChoice;
		Return;
		
	ElsIf IsBlankString(Authentication.Login) Or IsBlankString(Authentication.Password) Then
		// for the repeated password entry
		ImportClassifierFromSite(Authentication);
		Return;
		
	EndIf;
	
	ImportClassifierFromAuthenticationSite(Authentication, AdditionalParameters.CodesOfStates);
EndProcedure

&AtClient
Procedure ImportClassifierFromAuthenticationSite(Val Authentication, Val CodesOfStates)
	
	ClearMessages();
	
	// Switch mode - page.
	Items.ImportSteps.CurrentPage = Items.ImportingWait;
	ImportingStatusText = NStr("en='File loading from the user support site...';ru='Загрузка файлов с сайта поддержки пользователей...'");
	
	Items.BreakImport.Enabled = False;
	
	ClassifierBackgroundImportParameters = New Structure;
	ClassifierBackgroundImportParameters.Insert("Authentication", Authentication);
	ClassifierBackgroundImportParameters.Insert("CodesOfStates",   CodesOfStates);
	
	AttachIdleHandler("ImportClassifierFromFIASSite", 0.1, True);
EndProcedure

&AtClient
Procedure ImportClassifierFromFIASSite()
	CodesOfStates   = ClassifierBackgroundImportParameters.CodesOfStates;
	Authentication = ClassifierBackgroundImportParameters.Authentication;
	
	ClassifierBackgroundImportParameters = Undefined;
	
	RunBackgroundImportingFromServerSite(CodesOfStates, Authentication);
	AttachIdleHandler("Attachable_WaitingLongOperation", 0.1, True);
EndProcedure

&AtServer
Procedure RunBackgroundImportingFromServerSite(CodesOfStates, Authentication)
	
	MethodParameters = New Array;
	MethodParameters.Add(CodesOfStates);
	MethodParameters.Add(Authentication);
	
	ParametersOfLongOperation.ID   = Undefined;
	ParametersOfLongOperation.Completed       = True;
	ParametersOfLongOperation.ResultAddress = Undefined;
	ParametersOfLongOperation.DetailErrorDescription = Undefined;
	ParametersOfLongOperation.Error                       = Undefined;
	
	Try
		StartResult = LongActions.ExecuteInBackground(
			UUID,
			"AddressClassifierService.BackgroundTaskAddressesClassifierImportingFromSite",
			MethodParameters,
			NStr("en='Address classifier importing from the website';ru='Загрузка адресного классификатора с сайта'")
		);
	Except
		Information = ErrorInfo();
		BriefErrorDescription = BriefErrorDescription(Information);
		If Find(BriefErrorDescription , "404 Not Found") > 0 OR Find(BriefErrorDescription , "401 Unauthorized") > 0 Then
			ErrorText = NStr("en='Failed to import the address data.';ru='Не удается загрузить адресные сведения.'");
			ErrorText = ErrorText + NStr("en='Possible errors:';ru='Возможные причины:'") + Chars.LF;
			ErrorText = ErrorText + NStr("en='• Login and password are not entered correctly or not entered;';ru='• Некорректно введен или не введен логин и пароль;'") + Chars.LF;
			ErrorText = ErrorText + NStr("en='• No connection to the Internet;';ru='• Нет подключения к Интернету;'") + Chars.LF;
			ErrorText = ErrorText + NStr("en='• The website is under maintenance. Try to repeat the import later.';ru='• На сайте ведутся технические работы. Попробуйте повторить загрузку позднее.'") + Chars.LF;
			ErrorText = ErrorText + NStr("en='• Firewall or other middleware (antivirused, etc.) blocks the application attempts to connect to the Internet;';ru='• Брандмауэр или другое промежуточное ПО (антивирусы и т.п.) блокируют попытки программы подключиться к Интернету;'") + Chars.LF;
			ErrorText = ErrorText + NStr("en='• Connection to the Internet is performed through the proxy server but its parameters are nor specified in the application.';ru='• Подключение к Интернету выполняется через прокси-сервер, но его параметры не заданы в программе.'") + Chars.LF;
			ErrorText = ErrorText + NStr("en='Technical information:';ru='Техническая информация:'") + " " + Chars.LF;
			ErrorText = ErrorText + StrGetLine(BriefErrorDescription(Information), 1);
		Else
			ErrorText = NStr("en='Probably the site in under maintenance at this moment. Try to repeat the import later.';ru='Вероятно в данный момент на сайте ведутся технические работы. Попробуйте повторить загрузку позднее.'") + Chars.LF;
			ErrorText = ErrorText + NStr("en='Technical information:';ru='Техническая информация:'") + " " + Chars.LF;
			ErrorText = ErrorText + BriefErrorDescription(Information);
		EndIf;
		ParametersOfLongOperation.Error = ErrorText;
		ParametersOfLongOperation.DetailErrorDescription = DetailErrorDescription(Information);
		Items.AuthorizationOnUsersSupportSite.Visible = True;

		Return;
	EndTry;
	
	ParametersOfLongOperation.ID   = StartResult.JobID;
	ParametersOfLongOperation.Completed       = StartResult.JobCompleted;
	ParametersOfLongOperation.ResultAddress = StartResult.StorageAddress;
	
	// Running 
	Items.BreakImport.Enabled = True;
EndProcedure

&AtClient
Procedure RunBackgroundImportingFromClientDirectory(Val ImportParameters)
	// Switch mode - page.
	Items.ImportSteps.CurrentPage = Items.ImportingWait;
	ImportingStatusText = NStr("en='File transfer to the application server...';ru='Передача файлов на сервер приложения...'");
	
	Items.BreakImport.Enabled = False;
	ClassifierBackgroundImportParameters = ImportParameters;
	AttachIdleHandler("RunBackgroundImportingFromClientDirectoryContinued", 0.1, True);
EndProcedure

&AtClient
Procedure RunBackgroundImportingFromClientDirectoryContinued()
	ImportParameters = ClassifierBackgroundImportParameters;
	ClassifierBackgroundImportParameters = Undefined;
	
	If ImportParameters = Undefined Then
		// Back to the selection page.
		Items.ImportSteps.CurrentPage = Items.ImportingStatesChoice;
		Return;
	EndIf;
		
	// List of files sent to the server.
	FilesToPlace = New Array;
	For Each KeyValue IN ImportParameters.FilesByStates Do
		If TypeOf(KeyValue.Value) = Type("Array") Then
			For Each FileName IN KeyValue.Value Do
				FilesToPlace.Add(New TransferableFileDescription(FileName));
			EndDo;
		Else
			FilesToPlace.Add(New TransferableFileDescription(KeyValue.Value));
		EndIf;
	EndDo;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ImportParameters", ImportParameters);
	AdditionalParameters.Insert("Position", 0);
	NotifyDescription = New NotifyDescription("RunBackgroundImportingFromClientDirectoryAfterFilesPlacing",
		ThisObject, AdditionalParameters);
	BeginPuttingFiles(NOTifyDescription, FilesToPlace,, False, UUID);
	
EndProcedure

&AtClient
Procedure RunBackgroundImportingFromClientDirectoryAfterFilesPlacing(PlacedFiles, AdditionalParameters) Export
	
	Position = AdditionalParameters.Position;
	If Position <= PlacedFiles.UBound() Then
		
		// Save change time - version.
		Definition = PlacedFiles[Position];
		
		FileData = New Structure("Name, Location");
		FillPropertyValues(FileData, Definition);
		
		AdditionalParameters.Insert("FileData", FileData);
		AdditionalParameters.Insert("PlacedFiles", PlacedFiles);
		NotifyDescription = New NotifyDescription("RunBackgroundImportingFromClientDirectoryAfterInitialization", ThisObject, AdditionalParameters);
		
		File = New File();
		File.BeginInitialization(NOTifyDescription, Definition.Name);
		
	Else // Cycle exit
		
		// Start the background job for importing from the transferred files.
		If IsTempStorageURL(ParametersOfLongOperation.ResultAddress) Then
			DeleteFromTempStorage(ParametersOfLongOperation.ResultAddress);
		EndIf;
		ParametersOfLongOperation.ResultAddress = Undefined;
		
		Mode = Undefined;
		AdditionalParameters.ImportParameters.Property("Mode", Mode);
		
		RunBackgroundImportingAtServer(AdditionalParameters.ImportParameters.CodesOfStates, PlacedFiles, Mode);
		AttachIdleHandler("Attachable_WaitingLongOperation", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RunBackgroundImportingFromClientDirectoryAfterInitialization(File, AdditionalParameters) Export
	
	NotifyDescription = New NotifyDescription("RunBackgroundImportingFromClientDirectoryAfterReceivingChangeTime",
		ThisObject, AdditionalParameters);
	File.BeginGettingModificationUniversalTime(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure RunBackgroundImportingFromClientDirectoryAfterReceivingChangeTime(ModifiedAt, AdditionalParameters) Export
	
	AdditionalParameters.FileData.Insert("ModifiedAt", ModifiedAt);
	AdditionalParameters.PlacedFiles[AdditionalParameters.Position] = AdditionalParameters.FileData;
	AdditionalParameters.Position = AdditionalParameters.Position + 1;
	RunBackgroundImportingFromClientDirectoryAfterFilesPlacing(AdditionalParameters.PlacedFiles, AdditionalParameters);
	
EndProcedure

&AtServer
Procedure RunBackgroundImportingAtServer(Val CodesOfStates, Val ImportingFilesDescription, Val Mode)
	MethodParameters = New Array;
	MethodParameters.Add(CodesOfStates);
	
	// Convert files to binary data - the storage can not be separated with the background job session.
	FilesDescription = New Array;
	For Each Definition IN ImportingFilesDescription Do
		
		FileData = New Structure("Name, ModifiedAt");
		FillPropertyValues(FileData, Definition);
		FileData.Insert("Location", GetFromTempStorage(Definition.Location));
		
		FilesDescription.Add(FileData);
	EndDo;
	MethodParameters.Add(FilesDescription);
	
	MethodParameters.Add(Mode);
	
	ParametersOfLongOperation.ID   = Undefined;
	ParametersOfLongOperation.Completed       = True;
	ParametersOfLongOperation.ResultAddress = Undefined;
	ParametersOfLongOperation.Error          = Undefined;
	
	Try
		StartResult = LongActions.ExecuteInBackground(
			UUID,
			"AddressClassifierService.AddressesClassifierImportBackgroundJob",
			MethodParameters,
			NStr("en='Importing address classifier';ru='Загрузка адресного классификатора'")
		);
	Except
		ErrorText = NStr("en='Failed to import the address data from the files.';ru='Не удается загрузить адресные сведения из файлов.'");
		ErrorText = ErrorText + NStr("en='It is necessary to save files from the 1C site http://its.1c.en/export/fias to the disk and then export to the application.';ru='Необходимо сохранить файлы с сайта «1С» http://its.1c.ru/download/fias на диск, а затем загрузить в программу.'") + Chars.LF;
		ErrorText = ErrorText + NStr("en='Technical information:';ru='Техническая информация:'") + Chars.LF + BriefErrorDescription(ErrorInfo());
		ParametersOfLongOperation.Error = ErrorText;
		Return;
	EndTry;
	
	ParametersOfLongOperation.ID   = StartResult.JobID;
	ParametersOfLongOperation.Completed       = StartResult.JobCompleted;
	ParametersOfLongOperation.ResultAddress = StartResult.StorageAddress;
	
	// Running 
	Items.BreakImport.Enabled = True;
EndProcedure

&AtServer
Function BackgroundJobState()
	Result = New Structure("Progress, Completed, Error, DetailErrorDescription");
	
	Result.Error = "";
	If ParametersOfLongOperation.ID = Undefined Then
		Result.Completed = True;
		Result.Progress  = Undefined;
		Result.DetailErrorDescription = ParametersOfLongOperation.DetailErrorDescription;
		Result.Error                       = ParametersOfLongOperation.Error;
	Else
		Try
			Result.Completed = LongActions.JobCompleted(ParametersOfLongOperation.ID);
			Result.Progress  = LongActions.ReadProgress(ParametersOfLongOperation.ID);
		Except
			Information = ErrorInfo();
			Result.DetailErrorDescription = DetailErrorDescription(Information);
			Result.Error                       = BriefErrorDescription(Information);
		EndTry
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure CancelBackgroundJob(Val ID)
	
	If ID <> Undefined Then
		Try
			LongActions.CancelJobExecution(ID);
		Except
			// Action is not required, the record is already in the log.
		EndTry
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_WaitingLongOperation()
	
	// Update the status
	State = BackgroundJobState();
	If Not IsBlankString(State.Error) Then
		// Completed with error, inform and go back to the first page.
		Items.ImportSteps.CurrentPage = Items.ImportingStatesChoice;
		Items.AuthorizationOnUsersSupportSite.Visible = True;
		CommonUseClientServer.MessageToUser(State.Error);
		Return;
		
	ElsIf State.Completed Then
		Items.ImportSteps.CurrentPage = Items.SuccessfulCompletion;
		ImportingDescriptionText = NStr("en='Address classifier is successfully imported.';ru='Адресный классификатор успешно загружен.'");
		
		Notify("AddressClassifierIsImported", , ThisObject);
		
		Items.Close.DefaultButton = True;
		CurrentItem = Items.Close;
		ClosingFormConfirmation = True;
		// To clear AddressClassifierOutdated check box in the client work settings.
		RefreshReusableValues();
		Return;
		
	EndIf;
	
	// Process continues
	If TypeOf(State.Progress) = Type("Structure") Then
		ImportingStatusText = State.Progress.Text;
	EndIf;
	AttachIdleHandler("Attachable_WaitingLongOperation", ParametersOfLongOperation.WaitInterval, True);
	
EndProcedure

&AtClient
Function StateCodesForImporting()
	Result = New Array;
	
	For Each Region IN RFTerritorialEntities.FindRows( New Structure("Import", True) ) Do
		Result.Add(Region.RFTerritorialEntityCode);
	EndDo;
	
	Return Result;
EndFunction

&AtServerNoContext
Function SavedSiteAuthenticationData()
	
	Result = StandardSubsystemsServer.AuthenticationParametersOnSite();
	Return ?(Result <> Undefined, Result, New Structure("Login,Password"));
	
EndFunction

&AtClient
Procedure EndImportingAddressDirectorySelection(Directory, AdditionalParameters) Export
	
	SetDirectoryAsImportingSource();
	
EndProcedure

&AtClient
Procedure SetDirectoryAsImportingSource()
	
	ImportingSourceCode = "DIRECTORY";

EndProcedure

&AtClient
Procedure SetImportingSourceEnabled()
	
	Items.ImportAddress.Enabled = ImportingSourceCode = "DIRECTORY";
	
EndProcedure

#EndRegion
