
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Access right check should be the first one.
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("en='The use of processing in the interactive mode is available only for administrator.';ru='Использование обработки в интерактивном режиме доступно только администратору.'");
	EndIf;
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ValidateVersionAndPlatformCompatibilityMode();
	
	Object.ThisIsInteractiveMode = True;
	
	FormTitle = NStr("en='Universal data exchange in the XML format (%VersionHandling%)';ru='Универсальный обмен данными в формате XML (%ВерсияОбработки%)'");
	FormTitle = StrReplace(FormTitle, "%VersionHandling%", ObjectVersioningAsStringAtServer());
	
	Title = FormTitle;
	
	If IsBlankString(TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump) Then
		Object.TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump = 0;
	Else
		Object.TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump = Number(TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump);
	EndIf;
		
	FillListOfTypesAvailableForDeletion();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.RulesFilename.ChoiceList.LoadValues(ExchangeRules.UnloadValues());
	Items.ExchangeFileName.ChoiceList.LoadValues(TheirFileDataImport.UnloadValues());
	Items.DataFileName.ChoiceList.LoadValues(DataExportToFile.UnloadValues());
	
	OnChangePeriod();
	
	ClearDataAboutFileForDataImport();
	
	DirectExporting = ?(Object.DirectReadInRecipientInfobase, 1, 0);
	
	StoredImportingMode = (Object.ExchangeMode = "Import");
	
	If StoredImportingMode Then
		
		// We set required page.
		Items.MainPanelForm.CurrentPage = Items.MainPanelForm.ChildItems.Import;
		
	EndIf;
	
	ProcessEnabledOfTransactionControls();
	
	ExpandTreeLine(DataToDelete, Items.DataToDelete, "Check");
	
	ArchiveFileOnValueChanging();
	DirectExportingOnValueChanging();
	
	ChangeModeDataProcessors(IsClient);
	
	#If WebClient Then
		Items.PagesExportDebuggings.CurrentPage = Items.PagesExportDebuggings.ChildItems.GroupExportWebClient;
		Items.PagesDebuggingExport.CurrentPage = Items.PagesDebuggingExport.ChildItems.GroupImportWebClient;
		Object.HandlersDebugModeFlag = False;
	#EndIf
	
	SetDebuggingCommandsEnabled();
	
	If StoredImportingMode
		AND Object.SettingAutomaticDataImport <> 0 Then
		
		If Object.SettingAutomaticDataImport = 1 Then
			
			NotifyDescription = New NotifyDescription("OnOpenEnd", ThisObject);
			ShowQueryBox(NOTifyDescription, NStr("en='Do you want to perform the data import out of the exchange file?';ru='Выполнить загрузку данных из файла обмена?'"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
			
		Else
			
			OnOpenEnd(DialogReturnCode.Yes, Undefined);
			
		EndIf;
		
	EndIf;
	
	If IsLinuxClient() Then
		Items.GroupOS.CurrentPage = Items.GroupOS.ChildItems.GroupLinux;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpenEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		RunImportFromForm();
		ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ArchiveFileOnChange(Item)
	
	ArchiveFileOnValueChanging();
	
EndProcedure

&AtClient
Procedure ExchangeRulesFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileChoice(Item, RulesFilename, True, , False, True);
	
EndProcedure

&AtClient
Procedure ExchangeRulesFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DirectExportOnChange(Item)
	
	DirectExportingOnValueChanging();
	
EndProcedure

&AtClient
Procedure MainFormPanelOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage.Name = "Export" Then
		
		Object.ExchangeMode = "Export";
		
	ElsIf CurrentPage.Name = "Import" Then
		
		Object.ExchangeMode = "Import";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DebugModeFlagOnChange(Item)
	
	If Object.DebugModeFlag Then
		
		Object.UseTransactions = False;
				
	EndIf;
	
	ProcessEnabledOfTransactionControls();

EndProcedure

&AtClient
Procedure ProcessedObjectsCountForStatusUpdateOnChange(Item)
	
	If Object.CountProcessedObjectsForRefreshStatus = 0 Then
		Object.CountProcessedObjectsForRefreshStatus = 100;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFilenameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileChoice(Item, ExchangeFileName, False, , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileChoice(Item, Object.ExchangeProtocolFileName, False, "txt", False);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameImportingStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileChoice(Item, Object.ExchangeProtocolFileNameImporting, False, "txt", False);
	
EndProcedure

&AtClient
Procedure DataFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileChoice(Item, DataFileName, False, , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure InfobaseForConnectionDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	
	FileDialog.Title = NStr("en='Select the infobase directory';ru='Выберите каталог информационной базы'");
	FileDialog.Directory = Object.InfobaseForConnectionDirectory;
	FileDialog.CheckFileExist = True;
	
	If FileDialog.Choose() Then
		
		Object.InfobaseForConnectionDirectory = FileDialog.Directory;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameImportingOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseForConnectionDirectoryOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseConnectionWindowsAuthenticationOnChange(Item)
	
	Items.InfobaseForConnectionUser.Enabled = Not Object.InfobaseConnectionWindowsAuthentication;
	Items.InfobaseForConnectionPassword.Enabled = Not Object.InfobaseConnectionWindowsAuthentication;
	
EndProcedure

&AtClient
Procedure RulesFilenameOnChange(Item)
	
	File = New File(RulesFilename);
	If IsBlankString(RulesFilename) Or Not File.Exist() Then
		MessageToUser(NStr("en='Exchange rule file is not found';ru='Не найден файл правил обмена'"), "RulesFilename");
		SetSignUnloadRules(False);
		Return;
	EndIf;
	
	If RulesOfExchangeAndFileNamesAreSame() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("RulesFilenameOnChangeEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, NStr("en='Do you want to import the data exchange rules?';ru='Загрузить правила обмена данными?'"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure RulesFilenameOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		RunExchangeRulesImport();
		
	Else
		
		SetSignUnloadRules(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExchangeFilenameOnChange(Item)
	
	ClearDataAboutFileForDataImport();
	
EndProcedure

&AtClient
Procedure UseTransactionsOnChange(Item)
	
	ProcessEnabledOfTransactionControls();
	
EndProcedure

&AtClient
Procedure HandlersDebugModeFlagImportsOnChange(Item)
	
	SetDebuggingCommandsEnabled();
	
EndProcedure

&AtClient
Procedure HandlersDebugModeFlagDumpsOnChange(Item)
	
	SetDebuggingCommandsEnabled();
	
EndProcedure

&AtClient
Procedure DataFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DataFileNameOnChange(Item)
	
	If AttributeEmptyValue(DataFileName, "DataFileName", Items.DataFileName.Title)
		Or RulesOfExchangeAndFileNamesAreSame() Then
		Return;
	EndIf;
	
	Object.ExchangeFileName = DataFileName;
	
	File = New File(Object.ExchangeFileName);
	ArchiveFile = (UPPER(File.Extension) = UPPER(".zip"));
	
EndProcedure

&AtClient
Procedure InfobaseTypeForConnectionOnChange(Item)
	
	InfobaseTypeForConnectionOnValueChange();
	
EndProcedure

&AtClient
Procedure InfobaseForConnectionPlatformVersionOnChange(Item)
	
	If IsBlankString(Object.InfobaseForConnectionPlatformVersion) Then
		
		Object.InfobaseForConnectionPlatformVersion = "V8";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TypeOfChangesRegistrationDeletionForExchangeNodesAfterDumpOnChange(Item)
	
	If IsBlankString(TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump) Then
		Object.TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump = 0;
	Else
		Object.TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump = Number(TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportPeriodOnChange(Item)
	
	OnChangePeriod();
	
EndProcedure

&AtClient
Procedure DeletionOnChangePeriod(Item)
	
	OnChangePeriod();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersUnloadRulesTable

&AtClient
Procedure UnloadRulesTableBeforeRowChange(Item, Cancel)
	
	If Item.CurrentItem.Name = "ExchangeNodeRef" Then
		
		If Item.CurrentData.IsFolder Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UnloadRulesTableOnChange(Item)
	
	If Item.CurrentItem.Name = "DDR" Then
		
		CurRow = Item.CurrentData;
		
		If CurRow.Enable = 2 Then
			CurRow.Enable = 0;
		EndIf;
		
		SetMarksOfSubordinateOnes(CurRow, "Enable");
		SetMarksOfParents(CurRow, "Enable");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersDataToDelete

&AtClient
Procedure DeletedDataOnChange(Item)
	
	CurRow = Item.CurrentData;
	
	SetMarksOfSubordinateOnes(CurRow, "Check");
	SetMarksOfParents(CurRow, "Check");

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ConnectionTest(Command)
	
	RunConnectionToIBReceiverAtServer();
	
EndProcedure

&AtClient
Procedure ReceiveInformationAboutExchangeFile(Command)
	
	FileURL = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ReceiveInformationAboutExchangeFileEnd", ThisObject);
		BeginPutFile(NOTifyDescription, FileURL,NStr("en='Exchange file';ru='Файл обмена'"),, UUID);
		
	Else
		
		ReceiveInformationAboutExchangeFileEnd(True, FileURL, "", Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReceiveInformationAboutExchangeFileEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Try
			
			OpenImportingFileAtServer(Address);
			ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
			
		Except
			
			MessageToUser(NStr("en='Failed to read the exchange file.';ru='Не удалось прочитать файл обмена.'"));
			ClearDataAboutFileForDataImport();
			
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeletionCheckAll(Command)
	
	For Each String IN DataToDelete.GetItems() Do
		
		String.Check = 1;
		SetMarksOfSubordinateOnes(String, "Check");
		
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionUncheckAll(Command)
	
	For Each String IN DataToDelete.GetItems() Do
		String.Check = 0;
		SetMarksOfSubordinateOnes(String, "Check");
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionDelete(Command)
	
	NotifyDescription = New NotifyDescription("DeletionDeleteEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, NStr("en='Do you want to delete the infobase data?';ru='Удалить выбранные данные в информационной базе?'"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure DeletionDeleteEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Status(NStr("en='Data deleting is in process. Please wait...';ru='Выполняется удаление данных. Пожалуйста, подождите..'"));
		DeleteAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportCheckAll(Command)
	
	For Each String IN Object.UnloadRulesTable.GetItems() Do
		String.Enable = 1;
		SetMarksOfSubordinateOnes(String, "Enable");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportCancelAll(Command)
	
	For Each String IN Object.UnloadRulesTable.GetItems() Do
		String.Enable = 0;
		SetMarksOfSubordinateOnes(String, "Enable");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportClearExchangeNodes(Command)
	
	SetTreeRowsExchangeNodeAtServer(Undefined);
	
EndProcedure

&AtClient
Procedure ExportSetExchangeNode(Command)
	
	If Items.UnloadRulesTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	SetTreeRowsExchangeNodeAtServer(Items.UnloadRulesTable.CurrentData.ExchangeNodeRef);
	
EndProcedure

&AtClient
Procedure SaveParameters(Command)
	
	SaveParametersAtServer();
	
EndProcedure

&AtClient
Procedure RestoreParameters(Command)
	
	RestoreParametersAtServer();
	
EndProcedure

&AtClient
Procedure ExportDebuggingSetting(Command)
	
	Object.ExchangeRulesFilename = FileNameAtServerOrClient(RulesFilename, RulesFileAddressInStorage);
	
	OpenSetupFormOfHandlersDebug(True);
	
EndProcedure

&AtClient
Procedure AtClient(Command)
	
	If Not IsClient Then
		
		IsClient = True;
		
		ChangeModeDataProcessors(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AtServer(Command)
	
	If IsClient Then
		
		IsClient = False;
		
		ChangeModeDataProcessors(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebuggingSetting(Command)
	
	ExchangeFileAddressInStorage = "";
	FilenameForExtension = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ImportDebuggingSettingEnd", ThisObject);
		BeginPutFile(NOTifyDescription, ExchangeFileAddressInStorage,NStr("en='Exchange file';ru='Файл обмена'"),, UUID);
		
	Else
		
		If AttributeEmptyValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		ImportDebuggingSettingEnd(True, ExchangeFileAddressInStorage, FilenameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebuggingSettingEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Object.ExchangeFileName = FileNameAtServerOrClient(ExchangeFileName ,Address, SelectedFileName);
		
		OpenSetupFormOfHandlersDebug(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RunExport(Command)
	
	RunDumpFromForm();
	
EndProcedure

&AtClient
Procedure RunImport(Command)
	
	RunImportFromForm();
	
EndProcedure

&AtClient
Procedure ReadExchangeRules(Command)
	
	If IsLinuxClient() AND DirectExporting = 1 Then
		ShowMessageBox(,NStr("en='Direct connection to infobase is not supported for a Linux client.';ru='Прямое подключение к информационной базе не поддерживается в клиенте под управлением ОС Linux.'"));
		Return;
	EndIf;
	
	FilenameForExtension = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ReadExchangeRulesEnd", ThisObject);
		BeginPutFile(NOTifyDescription, RulesFileAddressInStorage,NStr("en='Exchange rules file';ru='Файл правил обмена'"),, UUID);
		
	Else
		
		RulesFileAddressInStorage = "";
		If AttributeEmptyValue(RulesFilename, "RulesFilename", Items.RulesFilename.Title) Then
			Return;
		EndIf;
		
		ReadExchangeRulesEnd(True, RulesFileAddressInStorage, FilenameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReadExchangeRulesEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		RulesFileAddressInStorage = Address;
		
		Status(NStr("en='Exchange rules reading is in process. Please wait...';ru='Выполняется чтение правил обмена. Пожалуйста, подождите..'"));
		RunExchangeRulesImport(Address, SelectedFileName);
		
		If Object.ErrorFlag Then
			
			SetSignUnloadRules(False);
			
		Else
			
			SetSignUnloadRules(True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// It opens exchange file in external app.
//  
// Parameters:
//  
// 
&AtClient
Procedure OpenInApplication(FileName, StandardProcessing = False)
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("FileName", FileName);
	AdditionalParameters.Insert("NotifyDescription", New NotifyDescription("OpenDirectoryWithFile", ThisForm, AdditionalParameters));
	
	File = New File();
	File.BeginInitialization(New NotifyDescription("CheckFileExistence", ThisForm, AdditionalParameters), FileName);
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure CheckFileExistence(File, AdditionalParameters) Export
	NotifyDescription = New NotifyDescription("AfterFileExistenceCheck", ThisForm, AdditionalParameters);
	File.StartExistenceCheck(NOTifyDescription);
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterFileExistenceCheck(Exist, AdditionalParameters) Export
	
	If Exist Then
		BeginRunningApplication(AdditionalParameters.NotifyDescription, AdditionalParameters.FileName);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure OpenDirectoryWithFile(ReturnCode, AdditionalParameters) Export
	// No processing is required.
EndProcedure

&AtClient
Procedure ClearDataAboutFileForDataImport()
	
	Object.ExchangeRulesVersion = "";
	Object.DataExportDate = "";
	ExportPeriodPresentation = "";
	
EndProcedure

&AtClient
Procedure ProcessEnabledOfTransactionControls()
	
	Items.UseTransactions.Enabled = Not Object.DebugModeFlag;
	
	Items.ObjectsCountForTransactions.Enabled = Object.UseTransactions;
	
EndProcedure

&AtClient
Procedure ArchiveFileOnValueChanging()
	
	If Object.ArchiveFile Then
		DataFileName = StrReplace(DataFileName, ".xml", ".zip");
	Else
		DataFileName = StrReplace(DataFileName, ".zip", ".xml");
	EndIf;
	
	Items.ExchangeFileCompressionPassword.Enabled = Object.ArchiveFile;
	
EndProcedure

&AtServer
Procedure SetExchangeNodeForTreeRows(Tree, ExchangeNode)
	
	For Each String IN Tree Do
		
		If String.IsFolder Then
			
			SetExchangeNodeForTreeRows(String.GetItems(), ExchangeNode);
			
		Else
			
			String.ExchangeNodeRef = ExchangeNode;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function RulesOfExchangeAndFileNamesAreSame()
	
	If Upper(TrimAll(RulesFilename)) = Upper(TrimAll(DataFileName)) Then
		
		MessageToUser(NStr("en='Exchange rules file can not match with the data file."
"Select the other file for the data export.';ru='Файл правил обмена не может совпадать с файлом данных."
"Выберите другой файл для выгрузки данных.'"));
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// It fills out a tree of metadata available for deletion.
&AtServer
Procedure FillListOfTypesAvailableForDeletion()
	
	DataTree = FormAttributeToValue("DataToDelete");
	
	DataTree.Rows.Clear();
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en='Catalogs';ru='Справочники'");
	
	For Each MDObject IN Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "CatalogRef." + MDObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en='Charts of characteristics types';ru='Планы видов характеристик'");
	
	For Each MDObject IN Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "ChartOfCharacteristicTypesRef." + MDObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en='Documents';ru='Документы'");
	
	For Each MDObject IN Metadata.Documents Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "DocumentRef." + MDObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = "InformationRegisters";
	
	For Each MDObject IN Metadata.InformationRegisters Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		Subordinate = (MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MDObject.Name;
		MDRow.Metadata = "InformationRegisterRecord." + MDObject.Name;
		
	EndDo;
	
	ValueToFormAttribute(DataTree, "DataToDelete");
	
EndProcedure

// It returns the processing version.
&AtServer
Function ObjectVersioningAsStringAtServer()
	
	Return FormAttributeToValue("Object").ObjectVersioningAsString();
	
EndFunction

&AtClient
Procedure RunExchangeRulesImport(RulesFileAddressInStorage = "", FilenameForExtension = "")
	
	Object.ErrorFlag = False;
	
	ImportExchangeRulesAndParametersAtServer(RulesFileAddressInStorage, FilenameForExtension);
	
	If Object.ErrorFlag Then
		
		SetSignUnloadRules(False);
		
	Else
		
		SetSignUnloadRules(True);
		ExpandTreeLine(Object.UnloadRulesTable, Items.UnloadRulesTable, "Enable");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandTreeLine(DataTree, PresentationOnForm, FlagName)
	
	TreeRows = DataTree.GetItems();
	
	For Each String IN TreeRows Do
		
		RowID=String.GetID();
		PresentationOnForm.Expand(RowID, False);
		EnableParentIfIncludedSlave(String, FlagName);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure EnableParentIfIncludedSlave(TreeRow, FlagName)
	
	Enable = TreeRow[FlagName];
	
	For Each SubordinatedRow IN TreeRow.GetItems() Do
		
		If SubordinatedRow[FlagName] = 1 Then
			
			Enable = 1;
			
		EndIf;
		
		If SubordinatedRow.GetItems().Count() > 0 Then
			
			EnableParentIfIncludedSlave(SubordinatedRow, FlagName);
			
		EndIf;
		
	EndDo;
	
	TreeRow[FlagName] = Enable;
	
EndProcedure

&AtClient
Procedure OnChangePeriod()
	
	Object.StartDate = PeriodExportings.StartDate;
	Object.EndDate = PeriodExportings.EndDate;
	
EndProcedure

&AtServer
Procedure ImportExchangeRulesAndParametersAtServer(RulesFileAddressInStorage, FilenameForExtension)
	
	ExchangeRulesFilename = FileNameAtServerOrClient(RulesFilename ,RulesFileAddressInStorage, FilenameForExtension);
	
	If ExchangeRulesFilename = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeRulesFilename = ExchangeRulesFilename;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	ObjectForServer.UnloadRulesTable = FormAttributeToValue("Object.UnloadRulesTable");
	ObjectForServer.ParametersSettingsTable = FormAttributeToValue("Object.ParametersSettingsTable");
	
	ObjectForServer.ImportExchangeRules();
	ObjectForServer.InitializeInitialParameterValues();
	ObjectForServer.Parameters.Clear();
	Object.ErrorFlag = ObjectForServer.ErrorFlag;
	
	If IsClient Then
		
		DeleteFiles(Object.ExchangeRulesFilename);
		
	EndIf;
	
	ValueToFormAttribute(ObjectForServer.UnloadRulesTable, "Object.UnloadRulesTable");
	ValueToFormAttribute(ObjectForServer.ParametersSettingsTable, "Object.ParametersSettingsTable");
	
EndProcedure

// It opens the dialog of file selection.
//
// Parameters:
//  Item                - Management item for which a file is selected.
//  CheckFileExistence - If it is True, then selection is cancelled if the file does not exist.
// 
&AtClient
Procedure FileChoice(Item, PropertyName, CheckFileExistence, Val DefaultExtension = "xml",
	DataFileArchiving = True, RulesFileChoice = False)
	
	FileDialog = New FileDialog(FileDialogMode.Open);

	If DefaultExtension = "txt" Then
		
		FileDialog.Filter = "Exchange protocol file (*.txt)|*.txt";
		FileDialog.Extension = "txt";
		
	ElsIf Object.ExchangeMode = "Export" Then
		
		If DataFileArchiving Then
			
			FileDialog.Filter = "Archive data file (*.zip)|*.zip";
			FileDialog.Extension = "zip";
			
		ElsIf RulesFileChoice Then
			
			FileDialog.Filter = "File data (*.xml)|*.xml|Archive data file (*.zip)|*.zip";
			FileDialog.Extension = "xml";
			
		Else
			
			FileDialog.Filter = "File data (*.xml)|*.xml";
			FileDialog.Extension = "xml";
			
		EndIf; 
		
	Else
		
		FileDialog.Filter = "File data (*.xml)|*.xml|Archive data file (*.zip)|*.zip";
		FileDialog.Extension = "xml";
		
	EndIf;
	
	FileDialog.Title = NStr("en='Select the file';ru='Выберите файл'");
	FileDialog.Preview = False;
	FileDialog.FilterIndex = 0;
	FileDialog.FullFileName = Item.EditText;
	FileDialog.CheckFileExist = CheckFileExistence;
	
	If FileDialog.Choose() Then
		
		PropertyName = FileDialog.FullFileName;
		
		If Item = Items.RulesFilename Then
			RulesFilenameOnChange(Item);
			
		ElsIf Item = Items.ExchangeFileName Then
			ExchangeFilenameOnChange(Item);
			
		ElsIf Item = Items.DataFileName Then
			DataFileNameOnChange(Item);
	
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function RunConnectionToIBReceiverAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ConnectionResult = ObjectForServer.RunConnectionToReceiverIB();
	
	If ConnectionResult <> Undefined Then
		
		MessageToUser(NStr("en='Connection has been successfully installed.';ru='Подключение успешно установлено.'"));
		
	EndIf;
	
EndFunction

// Sets mark state of the subordinate strings of
// the values tree string depending on the current string mark.
//
// Parameters:
//  CurRow      - Values tree string.
// 
&AtClient
Procedure SetMarksOfSubordinateOnes(CurRow, FlagName)
	
	Subordinate = CurRow.GetItems();
	
	If Subordinate.Count() = 0 Then
		Return;
	EndIf;
	
	For Each String IN Subordinate Do
		
		String[FlagName] = CurRow[FlagName];
		
		SetMarksOfSubordinateOnes(String, FlagName);
		
	EndDo;
		
EndProcedure

// Sets mark state in the parent strings of
// the values tree string depending on the current string mark.
//
// Parameters:
//  CurRow      - Values tree string.
// 
&AtClient
Procedure SetMarksOfParents(CurRow, FlagName)
	
	Parent = CurRow.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf; 
	
	CurState = Parent[FlagName];
	
	EnabledItemsFound  = False;
	DisabledItemsFound = False;
	
	For Each String IN Parent.GetItems() Do
		If String[FlagName] = 0 Then
			DisabledItemsFound = True;
		ElsIf String[FlagName] = 1
			OR String[FlagName] = 2 Then
			EnabledItemsFound  = True;
		EndIf; 
		If EnabledItemsFound AND DisabledItemsFound Then
			Break;
		EndIf; 
	EndDo;
	
	If EnabledItemsFound AND DisabledItemsFound Then
		Enable = 2;
	ElsIf EnabledItemsFound AND (NOT DisabledItemsFound) Then
		Enable = 1;
	ElsIf (NOT EnabledItemsFound) AND DisabledItemsFound Then
		Enable = 0;
	ElsIf (NOT EnabledItemsFound) AND (NOT DisabledItemsFound) Then
		Enable = 2;
	EndIf;
	
	If Enable = CurState Then
		Return;
	Else
		Parent[FlagName] = Enable;
		SetMarksOfParents(Parent, FlagName);
	EndIf; 
	
EndProcedure

&AtServer
Procedure OpenImportingFileAtServer(FileURL)
	
	If IsClient Then
		
		BinaryData = GetFromTempStorage (FileURL);
		AddressAtServer = GetTempFileName(".xml");
		BinaryData.Write(AddressAtServer);
		Object.ExchangeFileName = AddressAtServer;
		
	Else
		
		FileAtServer = New File(ExchangeFileName);
		
		If Not FileAtServer.Exist() Then
			
			MessageToUser(NStr("en='Exchange file is not found on the server.';ru='Не найден файл обмена на сервере.'"), "ExchangeFileName");
			Return;
			
		EndIf;
		
		Object.ExchangeFileName = ExchangeFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	
	ObjectForServer.OpenImportFile(True);
	
	Object.StartDate = ObjectForServer.StartDate;
	Object.EndDate = ObjectForServer.EndDate;
	Object.DataExportDate = ObjectForServer.DataExportDate;
	Object.ExchangeRulesVersion = ObjectForServer.ExchangeRulesVersion;
	Object.Comment = ObjectForServer.Comment;
	
EndProcedure

// It deletes the marked rows of metadata tree.
//
&AtServer
Procedure DeleteAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	DeletedDataTree = FormAttributeToValue("DataToDelete");
	
	ObjectForServer.InitializeManagersAndMessages();
	
	For Each TreeRow IN DeletedDataTree.Rows Do
		
		For Each MDRow IN TreeRow.Rows Do
			
			If Not MDRow.Check Then
				Continue;
			EndIf;
			
			TypeAsString = MDRow.Metadata;
			ObjectForServer.DeleteTypeObjects(TypeAsString);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// It sets exchange node near tree rows.
//
&AtServer
Procedure SetTreeRowsExchangeNodeAtServer(ExchangeNode)
	
	SetExchangeNodeForTreeRows(Object.UnloadRulesTable.GetItems(), ExchangeNode);
	
EndProcedure

// It saves the parameter values.
//
&AtServer
Procedure SaveParametersAtServer()
	
	ParameterTable = FormAttributeToValue("Object.ParametersSettingsTable");
	
	SavedParameters = New Structure;
	
	For Each TableRow IN ParameterTable Do
		SavedParameters.Insert(TableRow.Description, TableRow.Value);
	EndDo;
	
	SystemSettingsStorage.Save("UniversalXMLDataExchange", "Parameters", SavedParameters);
	
EndProcedure

// It restores the parameter values.
//
&AtServer
Procedure RestoreParametersAtServer()
	
	ParameterTable = FormAttributeToValue("Object.ParametersSettingsTable");
	RestoredParameters = SystemSettingsStorage.Load("UniversalXMLDataExchange", "Parameters");
	
	If TypeOf(RestoredParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	If RestoredParameters.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Param IN RestoredParameters Do
		
		ParameterName = Param.Key;
		
		TableRow = ParameterTable.Find(Param.Key, "Description");
		
		If TableRow <> Undefined Then
			
			TableRow.Value = Param.Value;
			
		EndIf;
		
	EndDo;
	
	ValueToFormAttribute(ParameterTable, "Object.ParametersSettingsTable");
	
EndProcedure

// Interactive data export.
//
&AtClient
Procedure RunImportFromForm()
	
	FileURL = "";
	FilenameForExtension = "";
	
	AddRowToChoiceList(Items.ExchangeFileName.ChoiceList, ExchangeFileName, TheirFileDataImport);
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("RunImportFromFormEnd", ThisObject);
		BeginPutFile(NOTifyDescription, FileURL,NStr("en='Exchange file';ru='Файл обмена'"),, UUID);
		
	Else
		
		If AttributeEmptyValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		RunImportFromFormEnd(True, FileURL, FilenameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RunImportFromFormEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Status(NStr("en='Data import in progress. Please wait...';ru='Выполняется загрузка данных. Пожалуйста, подождите..'"));
		ImportExecuteAtServer(Address, SelectedFileName);
		
		OpenDataOfExchangeProtocolsIfNeeded();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportExecuteAtServer(FileURL, FilenameForExtension)
	
	ImportedFileName = FileNameAtServerOrClient(ExchangeFileName ,FileURL, FilenameForExtension);
	
	If ImportedFileName = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeFileName = ImportedFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.RunImport();
	
	Try
		
		If Not IsBlankString(FileURL) Then
			DeleteFiles(ImportedFileName);
		EndIf;
		
	Except
		
	EndTry;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	RulesImported = False;
	Items.FormExecuteExport.Enabled = False;
	Items.InscriptionExportExplanation.Visible = True;
	Items.GroupExportDebuggingAvailable.Enabled = False;
	
EndProcedure

&AtServer
Function FileNameAtServerOrClient(AttributeName ,Val FileURL, Val FilenameForExtension = ".xml",
	CreateNew = False, CheckFileExistence = True)
	
	FileName = Undefined;
	
	If IsClient Then
		
		If CreateNew Then
			
			Extension = ? (Object.ArchiveFile, ".zip", ".xml");
			
			FileName = GetTempFileName(Extension);
			
			File = New File(FileName);
			
		Else
			
			Extension = FileExtension(FilenameForExtension);
			BinaryData = GetFromTempStorage(FileURL);
			AddressAtServer = GetTempFileName(Extension);
			BinaryData.Write(AddressAtServer);
			FileName = AddressAtServer;
			
		EndIf;
		
	Else
		
		FileAtServer = New File(AttributeName);
		
		If Not FileAtServer.Exist() AND CheckFileExistence Then
			
			MessageToUser(NStr("en='Specified file does not exist.';ru='Указанный файл не существует.'"));
			
		Else
			
			FileName = AttributeName;
			
		EndIf;
		
	EndIf;
	
	Return FileName;
	
EndFunction

&AtServer
Function FileExtension(Val FileName)
	
	DotPosition = LastSeparator(FileName);
	
	Extension = Right(FileName,StrLen(FileName) - DotPosition + 1);
	
	Return Extension;
	
EndFunction

&AtServer
Function LastSeparator(StringWithSeparator, Delimiter = ".")
	
	StringLength = StrLen(StringWithSeparator);
	
	While StringLength > 0 Do
		
		If Mid(StringWithSeparator, StringLength, 1) = Delimiter Then
			
			Return StringLength; 
			
		EndIf;
		
		StringLength = StringLength - 1;
		
	EndDo;

EndFunction

&AtClient
Procedure RunDumpFromForm()
	
	// We will remember the rules file and export file.
	AddRowToChoiceList(Items.RulesFilename.ChoiceList, RulesFilename, ExchangeRules);
	
	If Not Object.DirectReadInRecipientInfobase AND Not IsClient Then
		
		If RulesOfExchangeAndFileNamesAreSame() Then
			Return;
		EndIf;
		
		AddRowToChoiceList(Items.DataFileName.ChoiceList, DataFileName, DataExportToFile);
		
	EndIf;
	
	Status(NStr("en='The data is being exported. Please wait...';ru='Выполняется выгрузка данных. Пожалуйста, подождите..'"));
	DataFileAddressInStorage = PerformExportAtServer();
	
	If DataFileAddressInStorage = Undefined Then
		Return;
	EndIf;
	
	ExpandTreeLine(Object.UnloadRulesTable, Items.UnloadRulesTable, "Enable");
	
	If IsClient AND Not DirectExporting AND Not Object.ErrorFlag Then
		
		StoredFileName = ?(Object.ArchiveFile, NStr("en='Export file.zip';ru='Файл выгрузки.zip'"),NStr("en='Export file.xml';ru='Файл выгрузки.xml'"));
		
		GetFile(DataFileAddressInStorage, StoredFileName)
		
	EndIf;
	
	OpenDataOfExchangeProtocolsIfNeeded();
	
EndProcedure

&AtServer
Function PerformExportAtServer()
	
	Object.ExchangeRulesFilename = FileNameAtServerOrClient(RulesFilename, RulesFileAddressInStorage);
	
	If Not DirectExporting Then
		
		TempFileNameData = FileNameAtServerOrClient(DataFileName, "",,True, False);
		
		If TempFileNameData = Undefined Then
			
			Return Undefined;
			MessageToUser(NStr("en='Data file is not defined';ru='Не определен файл данных'"));
			
		Else
			
			Object.ExchangeFileName = TempFileNameData;
			
		EndIf;
		
	EndIf;
	
	UnloadRulesTable = FormAttributeToValue("Object.UnloadRulesTable");
	ParametersSettingsTable = FormAttributeToValue("Object.ParametersSettingsTable");
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	
	If ObjectForServer.HandlersDebugModeFlag Then
		
		Cancel = False;
		
		File = New File(ObjectForServer.EventHandlersExternalDataProcessorFileName);
		
		If Not File.Exist() Then
			
			MessageToUser(NStr("en='File of external processing of the events debuggers does not exist on the server';ru='Файл внешней обработки отладчиков событий не существует на сервере'"));
			Return Undefined;
			
		EndIf;
		
		ObjectForServer.ExportEventHandlers(Cancel);
		
		If Cancel Then
			
			MessageToUser(NStr("en='Failed to export the event handlers';ru='Не удалось выгрузить обработчики событий'"));
			Return "";
			
		EndIf;
		
	Else
		
		ObjectForServer.ImportExchangeRules();
		ObjectForServer.InitializeInitialParameterValues();
		
	EndIf;
	
	ChangesTreeRulesExportings(ObjectForServer.UnloadRulesTable.Rows, UnloadRulesTable.Rows);
	ChangeParametersTable(ObjectForServer.ParametersSettingsTable, ParametersSettingsTable);
	
	ObjectForServer.RunExport();
	ObjectForServer.UnloadRulesTable = FormAttributeToValue("Object.UnloadRulesTable");
	
	If IsClient AND Not DirectExporting Then
		
		DataFileAddress = PutToTempStorage(New BinaryData(Object.ExchangeFileName), UUID);
		DeleteFiles(Object.ExchangeFileName);
		
	Else
		
		DataFileAddress = "";
		
	EndIf;
	
	If IsClient Then
		
		DeleteFiles(ObjectForServer.ExchangeRulesFilename);
		
	EndIf;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	Return DataFileAddress;
	
EndFunction

&AtClient
Procedure SetDebuggingCommandsEnabled();
	
	Items.ImportDebuggingSetting.Enabled = Object.HandlersDebugModeFlag;
	Items.ExportDebuggingSetting.Enabled = Object.HandlersDebugModeFlag;
	
EndProcedure

// It changes DDR tree according to tree on a form.
//
&AtServer
Procedure ChangesTreeRulesExportings(SourceTreeRows, ReplacedTreeRows)
	
	ColumnEnable = ReplacedTreeRows.UnloadColumn("Enable");
	SourceTreeRows.LoadColumn(ColumnEnable, "Enable");
	ColumnNode = ReplacedTreeRows.UnloadColumn("ExchangeNodeRef");
	SourceTreeRows.LoadColumn(ColumnNode, "ExchangeNodeRef");
	
	For Each SourceTreeRow IN SourceTreeRows Do
		
		RowIndex = SourceTreeRows.IndexOf(SourceTreeRow);
		ModifiedTreeRow = ReplacedTreeRows.Get(RowIndex);
		
		ChangesTreeRulesExportings(SourceTreeRow.Rows, ModifiedTreeRow.Rows);
		
	EndDo;
	
EndProcedure

// It changes parameter table according to table on a form.
//
&AtServer
Procedure ChangeParametersTable(BaseTable, FormTable)
	
	ColumnDescription = FormTable.UnloadColumn("Description");
	BaseTable.LoadColumn(ColumnDescription, "Description");
	Column_Value = FormTable.UnloadColumn("Value");
	BaseTable.LoadColumn(Column_Value, "Value");
	
EndProcedure

&AtClient
Procedure DirectExportingOnValueChanging()
	
	ExportParameters = Items.ExportParameters;
	
	ExportParameters.CurrentPage = ?(DirectExporting = 0,
										  ExportParameters.ChildItems.ExportingToFile,
										  ExportParameters.ChildItems.ExportToTargetIB);
	
	Object.DirectReadInRecipientInfobase = (DirectExporting = 1);
	
	InfobaseTypeForConnectionOnValueChange();
	
EndProcedure

Procedure InfobaseTypeForConnectionOnValueChange()
	
	BaseType = Items.BaseType;
	BaseType.CurrentPage = ?(Object.InfobaseTypeForConnection,
								BaseType.ChildItems.FileInfobase,
								BaseType.ChildItems.BaseAtServer);
	
EndProcedure

&AtClient
Procedure AddRowToChoiceList(SavedValuesList, ValueOfSaving, ParameterNameForSaving)
	
	If IsBlankString(ValueOfSaving) Then
		Return;
	EndIf;
	
	FoundItem = SavedValuesList.FindByValue(ValueOfSaving);
	If FoundItem <> Undefined Then
		SavedValuesList.Delete(FoundItem);
	EndIf;
	
	SavedValuesList.Insert(0, ValueOfSaving);
	
	While SavedValuesList.Count() > 10 Do
		SavedValuesList.Delete(SavedValuesList.Count() - 1);
	EndDo;
	
	ParameterNameForSaving = SavedValuesList;
	
EndProcedure

&AtClient
Procedure OpenSetupFormOfHandlersDebug(EventHandlersFromRuleFile)
	
	DataProcessorName = Left(FormName, LastSeparator(FormName));
	CalledFormName = DataProcessorName + "ManagedFormHandlersDebuggingSetting";
	
	FormParameters = New Structure;
	FormParameters.Insert("EventHandlersExternalDataProcessorFileName", Object.EventHandlersExternalDataProcessorFileName);
	FormParameters.Insert("AlgorithmsDebugMode", Object.AlgorithmsDebugMode);
	FormParameters.Insert("ExchangeRulesFilename", Object.ExchangeRulesFilename);
	FormParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	FormParameters.Insert("EventHandlersReadFromFileOfExchangeRules", EventHandlersFromRuleFile);
	FormParameters.Insert("DataProcessorName", DataProcessorName);
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	Handler = New NotifyDescription("OpenSetupFormOfHandlersDebugEnd", ThisObject, EventHandlersFromRuleFile);
	DebuggingParameters = OpenForm(CalledFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenSetupFormOfHandlersDebugEnd(DebuggingParameters, EventHandlersFromRuleFile) Export
	
	If DebuggingParameters <> Undefined Then
		
		FillPropertyValues(Object, DebuggingParameters);
		
		If IsClient Then
			
			If EventHandlersFromRuleFile Then
				
				FileName = Object.ExchangeRulesFilename;
				
			Else
				
				FileName = Object.ExchangeFileName;
				
			EndIf;
			
			DeleteFiles(FileName);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeFileLocation()
	
	Items.RulesFilename.Visible = Not IsClient;
	Items.DataFileName.Visible = Not IsClient;
	Items.ExchangeFileName.Visible = Not IsClient;
	
	SetSignUnloadRules(False);
	
EndProcedure

&AtClient
Procedure ChangeModeDataProcessors(RunMode)
	
	ModeGroup = CommandBar.ChildItems.ProcessingMode.ChildItems;
	
	ModeGroup.FormAtClient.Check = RunMode;
	ModeGroup.FormAtServer.Check = Not RunMode;
	
	CommandBar.ChildItems.ProcessingMode.Title = 
	?(RunMode, NStr("en='Operating mode (at client)';ru='Режим работы (на клиенте)'"), NStr("en='Operating mode (at server)';ru='Режим работы (на сервере)'"));
	
	Object.UnloadRulesTable.GetItems().Clear();
	Object.ParametersSettingsTable.Clear();
	
	ChangeFileLocation();
	
EndProcedure

&AtClient
Procedure OpenDataOfExchangeProtocolsIfNeeded()
	
	If Not Object.OpenExchangeProtocolAfterOperationsComplete Then
		Return;
	EndIf;
	
	#If Not WebClient  Then
		
		If Not IsBlankString(Object.ExchangeProtocolFileName) Then
			OpenInApplication(Object.ExchangeProtocolFileName);
		EndIf;
		
		If Object.DirectReadInRecipientInfobase Then
			
			Object.ExchangeProtocolFileNameImporting = GetProtocolNameForComConnectionSecondInfobaseAtServer();
			
			If Not IsBlankString(Object.ExchangeProtocolFileNameImporting) Then
				OpenInApplication(Object.ImportLogName);
			EndIf;
			
		EndIf;
		
	#EndIf
	
EndProcedure

&AtServer
Function GetProtocolNameForComConnectionSecondInfobaseAtServer()
	
	Return FormAttributeToValue("Object").GetProtocolNameForSecondInformationBaseOfCOMConnection();
	
EndFunction

&AtClient
Function AttributeEmptyValue(Attribute, DataPath, Title)
	
	If IsBlankString(Attribute) Then
		
		MessageText = NStr("en='Field ""%1"" is not filled';ru='Поле ""%1"" не заполнено'");
		MessageText = StrReplace(MessageText, "%1", Title);
		
		MessageToUser(MessageText, DataPath);
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

&AtClient
Procedure SetSignUnloadRules(SignOf)
	
	RulesImported = SignOf;
	Items.FormExecuteExport.Enabled = SignOf;
	Items.InscriptionExportExplanation.Visible = Not SignOf;
	Items.GroupExportDebugging.Enabled = SignOf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

// Returns True if the client application is started managed by Linux OS.
//
// Returns:
//  Boolean. If there is no client application, it returns False.
//
&AtClient
Function IsLinuxClient()
	
	SystemInfo = New SystemInfo;
	
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
				 OR SystemInfo.PlatformType = PlatformType.Linux_x86_64;
	
	Return IsLinuxClient;
	
EndFunction

&AtServer
Function ValidateVersionAndPlatformCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		AND (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("en='DataProcessor is used to start"
"on 1C:Enterprise 8.3 platform version with compatibility mode off or above';ru='Обработка предназначена"
"для запуска на версии платформы 1С:Предприятие 8.3 с отключенным режимом совместимости или выше'");
		
	EndIf;
	
EndFunction

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
