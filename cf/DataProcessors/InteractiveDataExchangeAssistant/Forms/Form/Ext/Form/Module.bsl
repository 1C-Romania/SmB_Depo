// Form is parameterized in two ways:
//
// Variant
//     1 Parameters: 
//         InfobaseNode             - ExchangePlanRef - exchange plan node for which handler is executed.
//         ExtendedModeAdditionsExportings - Boolean           - check box of enabling
//                                                                 mechanism of export expansion setting by the node script.
//
// Variant 2:
//     Parameters: 
//         InfobaseNode             - ExchangePlanRef - exchange plan for which handler is executed.
//         ExtendedModeAdditionsExportings - Boolean           - check box of enabling
//                                                                 mechanism of export expansion setting by the node script.
//         ExchangePlanName                     - String           - manager name exchange plan of
//                                                                 whom is used to search for exchange plan node
//                                                                 with the code specified in the InfobaseNodeCode parameter.
//

&AtClient
Var SkipCurrentPageFailureControl;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Var CodeOfInfobaseNode;
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Parameters.Property("ActivatedOnCloseDataExchangeCreationAssistant", ActivatedOnCloseDataExchangeCreationAssistant);
	
	IsStartedFromAnotherApplication = False;
	
	If Parameters.Property("InfobaseNode", Object.InfobaseNode) Then
		
		Object.ExchangePlanName = DataExchangeReUse.GetExchangePlanName(Object.InfobaseNode);
		
	ElsIf Parameters.Property("CodeOfInfobaseNode", CodeOfInfobaseNode) Then
		
		IsStartedFromAnotherApplication = True;
		
		Object.InfobaseNode = ExchangePlans[Parameters.ExchangePlanName].FindByCode(CodeOfInfobaseNode);
		
		If Object.InfobaseNode.IsEmpty() Then
			
			DataExchangeServer.ShowMessageAboutError(NStr("en='Data exchange setting is not found.';ru='Настройка обмена данными не найдена.'"), Cancel);
			Return;
			
		EndIf;
		
		Object.ExchangePlanName = Parameters.ExchangePlanName;
		
	Else
		
		DataExchangeServer.ShowMessageAboutError(NStr("en='Wizard cannot be opened.';ru='Непосредственное открытие помощника не предусмотрено.'"), Cancel);
		Return;
		
	EndIf;
	
	If Not DataExchangeReUse.IsUniversalDataExchangeNode(Object.InfobaseNode) Then
		
		// Interactive data exchange is supported only for universal exchanges
		// using objects conversion rules.
		DataExchangeServer.ShowMessageAboutError(
			NStr("en='Data exchange execution with the setting is not required for the selected node.';ru='Для выбранного узла выполнение обмена данными с настройкой не предусмотрено.'"), Cancel);
		Return;
		
	EndIf;
	
	NodesArray = DataExchangeReUse.GetExchangePlanNodesArray(Object.ExchangePlanName);
	
	// Check whether exchange setting matches filter.
	If NodesArray.Find(Object.InfobaseNode) = Undefined Then
		
		CommonUseClientServer.MessageToUser(NStr("en='Data mapping is not required for the selected node.';ru='Для выбранного узла сопоставление данных не предусмотрено.'"),,,, Cancel);
		Return;
		
	EndIf;
	
	Parameters.Property("ExchangeMessageTransportKind", Object.ExchangeMessageTransportKind);
	
	// Specify the exchange message transport kind if the value is not passed.
	If Not ValueIsFilled(Object.ExchangeMessageTransportKind) Then
		
		ExchangeTransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(Object.InfobaseNode);
		Object.ExchangeMessageTransportKind = ExchangeTransportSettings.ExchangeMessageTransportKindByDefault;
		If Not ValueIsFilled(Object.ExchangeMessageTransportKind) Then
			Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.FILE;
		EndIf;
		
	EndIf;
	
	ScriptJobsAssistantInteractiveExchange = ExchangePlans[Object.ExchangePlanName].InitializeScriptJobsAssistantInteractiveExchange(Object.InfobaseNode);
	
	GetData = True;
	SendData = True;
	CheckVersionDifference = True;
	
	If Parameters.Property("GetData") Then
		GetData = Parameters.GetData;
	EndIf;
	
	If Parameters.Property("SendData") Then
		SendData = Parameters.SendData;
	EndIf;
	
	DataExchangeServer.FillChoiceListByAvailableTransportKinds(Object.InfobaseNode, Items.ExchangeMessageTransportKind);
	Parameters.Property("ExecuteMappingOnOpen", ExecuteMappingOnOpen);
	AssistantOperationOption = "PerformMapping";
	
	DataImportEventLogMonitorMessage = DataExchangeServer.GetEventLogMonitorMessageKey(Object.InfobaseNode, Enums.ActionsAtExchange.DataImport);
	
	Title = StrReplace(Title, "%1", Object.InfobaseNode);
	
	// Export addition
	InitializeAttributesAdditionsExportings();
	
	// Check box of skipping transport page.
	SkipTransportPage = ExportAdditionExtendedMode Or CommonUseClientServer.ThisIsWebClient();
	
	RefreshTransportSettingsPages();
	
	// Interfaces difference
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		SetGroupTitleFont(Items.PageTitle);
		SetGroupTitleFont(Items.StatisticsPageTitle);
		SetGroupTitleFont(Items.MappingEndPageTitle);
		SetGroupTitleFont(Items.PageTitleAdditionsExportings);
		SetGroupTitleFont(Items.PageTitleDataAnalysisExpectations);
		SetGroupTitleFont(Items.PageTitleExpectationsDataSynchronization);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ForceCloseForm = False;
	
	GoToNumber = 1;
	SetGoToNumber(1);
	
	// Transport page analysis skip if it does not require settings.
	NextPage = False;
	ChangeTitle = Items.ExchangeMessageTransportKind.ChoiceList.Count()=1;
	
	If ExecuteMappingOnOpen Then
		NextPage = True;
	ElsIf SkipTransportPage Then
		// Go to the next page only if password is not required.
		If ExchangeOverWebService AND Not WSRememberPassword Then
			// Password is required, hide extra attributes.
			Items.GroupTransportKindChoiceFromAvailable.Visible = False;
			Items.Decoration3.Visible = False;
			Items.InformationExchangeDirectory.Visible = False;
			ChangeTitle = True;
		Else
			// Password is not required, skip it.
			NextPage = True;
		EndIf;
	EndIf;
	
	If ChangeTitle Then
		Items.PageTitle.Title = NStr("en='Connection parameters';ru='Параметры подключения'");
	EndIf;
	
	If NextPage AND ValueIsFilled(Object.ExchangeMessageTransportKind) Then
		// Go to the next page at once - information imports of - statistics.
		GoNextExecute();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CurrentPage = Items.MainPanel.CurrentPage;
	
	If CurrentPage = Items.BeginningPage Then
		ConfirmationText = NStr("en='Cancel data synchronization?';ru='Отменить синхронизацию данных?'");
		
	Else
		ConfirmationText = NStr("en='Stop data synchronization?';ru='Прервать синхронизацию данных?'");
		
	EndIf;
	
	CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, ConfirmationText,
		"ForceCloseForm");
EndProcedure

&AtClient
Procedure OnClose()
	
	// delete the temporary directory
	DeleteTemporaryDirectoryOfExchangeMessages(Object.TemporaryExchangeMessagesDirectoryName);
	
	Notify("ObjectMappingAssistantFormClosed");
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	RefreshFilter(ValueSelected);
	
	// Check for a export addition event. 
	If DataExchangeClient.ChoiceProcessingAdditionsExportings(ValueSelected, ChoiceSource, ExportAddition) Then
		// Event is processed, update the display of the typical
		SetSelectionAdditionsExportingsDescription();
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ClosingObjectMappingForm" Then
		
		Cancel = False;
		
		Status(NStr("en='Collecting mapping information...';ru='Выполняется сбор информации сопоставления...'"));
		
		RefreshDataOfMappingStatisticsAtServer(Cancel, Parameter);
		
		If Cancel Then
			ShowMessageBox(, NStr("en='Errors occurred when receiving statistics information.';ru='При получении информации статистики возникли ошибки.'"));
		Else
			
			ExpandTreeOfInformationStatistics(Parameter.UniqueKey);
			
			Status(NStr("en='Information collection is complete';ru='Сбор информации завершен'"));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Page StartPage

&AtClient
Procedure ExchangeMessageTransportKindOnChange(Item)
	
	ExchangeMessageTransportKindOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure InformationExchangeDirectoryClick(Item)
	
	OpenNodeInformationExchangeDirectory();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page PageQuestionAboutExportContent

&AtClient
Procedure ExportAdditionExportVariantOnChange(Item)
	ExportAdditionExportVariantSetVisible();
EndProcedure

&AtClient
Procedure ExportAdditionNodeScriptFilterPeriodOnChange(Item)
	ExportAdditionUpdatePeriodScriptNode();
EndProcedure

&AtClient
Procedure ExportAdditionCommonPeriodDocumentsClearing(Item, StandardProcessing)
	// Prohibit the period clearing
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ExportAdditionNodeScriptFilterPeriodClearing(Item, StandardProcessing)
	// Prohibit the period clearing
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersInformationStatisticsInformationTree

&AtClient
Procedure TreeOfInformationStatisticsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	// We refresh all open dynamic lists.
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

&AtClient
Procedure SchedulesOpenForm(Command)
	FormParameters = New Structure("InfobaseNode", Object.InfobaseNode);
	OpenForm("Catalog.DataExchangeScripts.ObjectForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure ContinueSynchronization(Command)
	
	GoToNumber = GoToNumber - 1;
	SetGoToNumber(GoToNumber + 1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page StartPage

&AtClient
Procedure GoNextExecute()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure OpenInformationExchangeDirectory(Command)
	
	OpenNodeInformationExchangeDirectory();
	
EndProcedure

&AtClient
Procedure ConfigureExchangeMessagesTransportParameters(Command)
	
	Filter              = New Structure("Node", Object.InfobaseNode);
	FillingValues = New Structure("Node", Object.InfobaseNode);
	
	Notification = New NotifyDescription("SetExchangeMessagesTransportParametersEnd", ThisObject);
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings", ThisObject,,, Notification);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page StatisticsInformationPage

&AtClient
Procedure RefreshInformationOfMappingFully(Command)
	
	CurrentData = Items.StatisticsInformationTree.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRowKey = CurrentData.Key;
		
	EndIf;
	
	Cancel = False;
	
	RowKeys = New Array;
	
	GetKeysOfAllRows(RowKeys, StatisticsInformationTree.GetItems());
	
	If RowKeys.Count() > 0 Then
		
		Status(NStr("en='Collecting mapping information...';ru='Выполняется сбор информации сопоставления...'"));
		
		RefreshInformationOfMappingByRowAtServer(Cancel, RowKeys);
		
	EndIf;
	
	If Cancel Then
		ShowMessageBox(, NStr("en='Errors occurred when receiving statistics information.';ru='При получении информации статистики возникли ошибки.'"));
	Else
		
		ExpandTreeOfInformationStatistics(CurrentRowKey);
		
		Status(NStr("en='Information collection is complete';ru='Сбор информации завершен'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataImportForRow(Command)
	
	Cancel = False;
	
	SelectedRows = Items.StatisticsInformationTree.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		NString = NStr("en='Select a table name in the statistical information field.';ru='Выберите имя таблицы в поле статистической информации.'");
		CommonUseClientServer.MessageToUser(NString,,"StatisticsInformationTree",, Cancel);
		Return;
	EndIf;
	
	HasUnmatchedObjects = False;
	For Each RowID IN SelectedRows Do
		TreeRow = StatisticsInformationTree.FindByID(RowID);
		
		If IsBlankString(TreeRow.Key) Then
			Continue;
		EndIf;
		
		If TreeRow.UnmappedObjectsCount <> 0 Then
			HasUnmatchedObjects = True;
			Break;
		EndIf;
	EndDo;
	
	If HasUnmatchedObjects Then
		NString = NStr("en='There are unmatched objects.
		|Unmatched object duplicates will be created while importing data. Continue?';ru='Имеются несопоставленные объекты.
		|При загрузке данных будут созданы дубли несопоставленных объектов. Продолжить?'");
		
		Notification = New NotifyDescription("ImportDataForStringQuestionUnmatched", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("SelectedRows", SelectedRows);
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	ImportDataForStringQuestionContinuation(SelectedRows);
EndProcedure

&AtClient
Procedure OpenMappingForm(Command)
	
	CurrentData = Items.StatisticsInformationTree.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("en='Cannot map objects for the data type.';ru='Для типа данных нельзя выполнить сопоставление объектов.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ReceiverTableName",            CurrentData.ReceiverTableName);
	FormParameters.Insert("TableSourceObjectTypeName", CurrentData.ObjectTypeAsString);
	FormParameters.Insert("ReceiverTableFields",           CurrentData.TableFields);
	FormParameters.Insert("SearchFieldsOfReceiverTable",     CurrentData.SearchFields);
	FormParameters.Insert("SourceTypeAsString",            CurrentData.SourceTypeAsString);
	FormParameters.Insert("ReceiverTypeAsString",            CurrentData.ReceiverTypeAsString);
	FormParameters.Insert("ThisIsObjectDeletion",             CurrentData.ThisIsObjectDeletion);
	FormParameters.Insert("DataSuccessfullyImported",         CurrentData.DataSuccessfullyImported);
	FormParameters.Insert("Key",                           CurrentData.Key);
	FormParameters.Insert("Synonym",                        CurrentData.Synonym);
	
	FormParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	FormParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	
	OpenForm("DataProcessor.InfobaseObjectsMapping.Form", FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page MatchEndPage

&AtClient
Procedure GoToDataImportEventsEventLogMonitor(Command)
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(Object.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventsEventLogMonitor(Command)
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(Object.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page PageQuestionAboutExportContent

&AtClient
Procedure ExportAdditionGeneralDocumentsFilter(Command)
	DataExchangeClient.OpenFormAdditionsExportingsAllDocuments(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilter(Command)
	DataExchangeClient.OpenFormAdditionsExportingsDetailedFilter(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionFilterOfScriptNode(Command)
	DataExchangeClient.OpenFormAdditionsExportingsScriptNode(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionExportVariant(Command)
	
	FillAdditionalRegistration();
	
	DataExchangeClient.OpenFormAdditionsExportingsContentData(ExportAddition, ThisObject);
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		DeleteProgramFilters();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearing(Command)
	
	HeaderText = NStr("en='Confirmation';ru='Подтверждение'");
	QuestionText   = NStr("en='Clear common filter?';ru='Очистить общий отбор?'");
	NotifyDescription = New NotifyDescription("ExportAdditionGeneralFilterClearingEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
	
EndProcedure

&AtClient
Procedure ExportAdditionCleaningDetailedFilter(Command)
	HeaderText = NStr("en='Confirmation';ru='Подтверждение'");
	QuestionText   = NStr("en='Clear detailed filter?';ru='Очистить детальный отбор?'");
	NotifyDescription = New NotifyDescription("ExportAdditionDetailedFilterClearingEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistory(Command)
	// Select from the menu list, all variants of the saved settings.
	VariantList = ExportAdditionHistorySettingsServer();
	
	// Add variant of saving the current ones.
	Text = NStr("en='Saving the current configuration...';ru='Сохранить текущую настройку...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistorySelectionFromMenu", ThisObject);
	ShowChooseFromMenu(NOTifyDescription, VariantList, Items.ExportAdditionFilterHistory);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetGroupTitleFont(Val GroupItem)
	
	GroupItem.TitleFont = New Font(StyleFonts.LargeTextFont, , , True);
	
EndProcedure

&AtClient
Procedure SetExchangeMessagesTransportParametersEnd(ClosingResult, AdditionalParameters) Export
	
	RefreshTransportSettingsPages();
	
EndProcedure
	
&AtClient
Procedure ExportAdditionFiltersHistoryEnd(Response, SettingRepresentation) Export
	
	If Response = DialogReturnCode.Yes Then
		ExportAdditionSetSettingsServer(SettingRepresentation);
		If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
			UpperLevelItems = FilterByDocumentKindsTree.GetItems();
			For Each UpperLevelRow IN UpperLevelItems Do
				Items.DocumentTypesFilter.Expand(UpperLevelRow.GetID(), True);
			EndDo;
		Else
			ExportAdditionExportVariantSetVisible();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearingEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ExportAdditionClearingGeneralFilterServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClearingEnd(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		ExportAdditionClearingDetailedFilterServer();
	EndIf;
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistorySelectionFromMenu(Val SelectedItem, Val AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingRepresentation = SelectedItem.Value;
	If TypeOf(SettingRepresentation)=Type("String") Then
		// Selected a variant - name of the previously saved setting.
		
		HeaderText = NStr("en='Confirmation';ru='Подтверждение'");
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Restore settings ""%1""?';ru='Восстановить настройки ""%1""?'"), SettingRepresentation);
		
		NotifyDescription = New NotifyDescription("ExportAdditionFiltersHistoryEnd", ThisObject, SettingRepresentation);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
		
	ElsIf SettingRepresentation=1 Then
		// Saving variant is selected, open form of all settings.
		DataExchangeClient.OpenFormAdditionsExportingsSaveSettings(ExportAddition, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDataForStringQuestionUnmatched(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ImportDataForStringQuestionContinuation(AdditionalParameters.SelectedRows);
EndProcedure

&AtClient
Procedure ImportDataForStringQuestionContinuation(Val SelectedRows) 

	RowKeys = GetKeysOfSelectedRows(SelectedRows);
	If RowKeys.Count() = 0 Then
		Return;
	EndIf;
	
	Status(NStr("en='Data import in progress...';ru='Выполняется загрузка данных...'"));
	
	Cancel = False;
	ExecuteDataImportAtServer(Cancel, RowKeys);
	
	If Cancel Then
		NString = NStr("en='Errors occurred while importing data.
		|Do you want to open the event log?';ru='При загрузке данных возникли ошибки.
		|Перейти в журнал регистрации?'");
		
		NotifyDescription = New NotifyDescription("GoToEventLogMonitor", ThisObject);
		ShowQueryBox(NOTifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
		
	ExpandTreeOfInformationStatistics(RowKeys[RowKeys.UBound()]);
	Status(NStr("en='Data import is complete.';ru='Загрузка данных завершена.'"));
EndProcedure

&AtClient
Procedure OpenNodeInformationExchangeDirectory()
	
	// Server call without context.
	DirectoryName = GetDirectoryNameAtServer(Object.ExchangeMessageTransportKind, Object.InfobaseNode);
	
	If IsBlankString(DirectoryName) Then
		ShowMessageBox(, NStr("en='Information exchange directory is not specified.';ru='Не задан каталог обмена информацией.'"));
		Return;
	EndIf;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("DirectoryName", DirectoryName);
	
	Notification = New NotifyDescription("AfterWorksWithFilesExpansionCheck", ThisForm, AdditionalParameters);
	
	SuggestionText = NStr("en='To open the directory, install the file operation extension.';ru='Для открытия каталога необходимо необходимо установить расширение работы с файлами.'");
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText);
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterWorksWithFilesExpansionCheck(Result, AdditionalParameters) Export
	
	If Result Then
	
		File = New File();
		NotifyDescription = New NotifyDescription("CheckFileExistence", ThisForm, AdditionalParameters);
		File.BeginInitialization(NOTifyDescription, AdditionalParameters.DirectoryName);
	
	Else
		WarningText = NStr("en='File operation extension is not installed. Directory cannot be opened.';ru='Расширение для работы с файлами не установлено, открытие каталога не возможно.'");
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure CheckFileExistence(File, AdditionalParameters) Export
	AdditionalParameters.Insert("File", File);
	NotifyDescription = New NotifyDescription("AfterFileExistenceCheck", ThisForm, AdditionalParameters);
	File.StartExistenceCheck(NOTifyDescription);
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterFileExistenceCheck(Exist, AdditionalParameters) Export
	
	If Exist Then
		File = AdditionalParameters.File;
		NotifyDescription = New NotifyDescription("DetermineIsDirectory", ThisForm, AdditionalParameters);
		File.StartCheckingIsDirectory(NOTifyDescription);
	Else
		WarningText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Directory ""%1"" does not exist or cannot be accessed.';ru='Каталог ""%1"" не существует или к нему нет доступа.'"),
			AdditionalParameters.DirectoryName
		);
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure DetermineIsDirectory(IsDirectory, AdditionalParameters) Export
	
	If IsDirectory Then
		NotifyDescription = New NotifyDescription("OpenDirectoryWithFile", ThisForm, AdditionalParameters);
		BeginRunningApplication(NOTifyDescription, AdditionalParameters.DirectoryName);
	Else
		WarningText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='""%1"" is a file, not a catalog.';ru='""%1"" является файлом, а не каталогом.'"),
			AdditionalParameters.DirectoryName
		);
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure OpenDirectoryWithFile(ReturnCode, AdditionalParameters) Export
	// No processing is required.
EndProcedure

&AtClient
Procedure GoToEventLogMonitor(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(Object.InfobaseNode, ThisObject, "DataImport");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshInformationOfMappingByRowAtServer(Cancel, RowKeys)
	
	RowIndexes = GetIndexesOfRowsOfInformationStatisticsTable(RowKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Receive statistic information about the match.
	DataProcessorObject.GetObjectMappingStatsByString(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	GetTreeOfInformationStatistics(DataProcessorObject.TableOfInformationStatistics());
	
	AllDataMapped = DataProcessors.InteractiveDataExchangeAssistant.AllDataMapped(DataProcessorObject.TableOfInformationStatistics());
	
	SetVisibleOfAdditionalInformationGroup();
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(Cancel, RowKeys)
	
	RowIndexes = GetIndexesOfRowsOfInformationStatisticsTable(RowKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// import data
	DataProcessorObject.ExecuteDataImport(Cancel, RowIndexes);
	
	// Receive statistic information about the match.
	DataProcessorObject.GetObjectMappingStatsByString(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	GetTreeOfInformationStatistics(DataProcessorObject.TableOfInformationStatistics());
	
	AllDataMapped = DataProcessors.InteractiveDataExchangeAssistant.AllDataMapped(DataProcessorObject.TableOfInformationStatistics());
	
	SetVisibleOfAdditionalInformationGroup();
	
EndProcedure

&AtServer
Procedure RefreshDataOfMappingStatisticsAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", NotificationParameters.UniqueKey));
	
	FillPropertyValues(TableRows[0], NotificationParameters, "DataSuccessfullyImported");
	
	RowKeys = New Array;
	RowKeys.Add(NotificationParameters.UniqueKey);
	
	RefreshInformationOfMappingByRowAtServer(Cancel, RowKeys);
	
EndProcedure

&AtServer
Procedure GetTreeOfInformationStatistics(StatisticsInformation)
	
	TreeItemCollection = StatisticsInformationTree.GetItems();
	TreeItemCollection.Clear();
	
	CommonUse.FillItemCollectionOfFormDataTree(TreeItemCollection,
		DataExchangeServer.GetTreeOfInformationStatistics(StatisticsInformation));
	
EndProcedure

&AtServer
Procedure SetVisibleOfAdditionalInformationGroup()
	
	Items.DataMappingStatePages.CurrentPage = ?(AllDataMapped,
		Items.MappingStateAllDataMapped,
		Items.MappingStateHasUnmappedData
	);
EndProcedure

&AtServer
Procedure ExchangeMessageTransportKindOnChangeAtServer()
	
	ExchangeOverExternalConnection = (Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.COM);
	ExchangeOverWebService         = (Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.WS);
	
	ExchangeOverConnectionToCorrespondent = ExchangeOverExternalConnection OR ExchangeOverWebService;
	
	ExternalConnectionParameterStructure = InformationRegisters.ExchangeTransportSettings.TransportSettings(Object.InfobaseNode);
	ExternalConnectionParameterStructure = DeletePrefixInCollectionKeys(ExternalConnectionParameterStructure, "COM");
	
	If IsStartedFromAnotherApplication Then
		
		Items.ScheduleSettingsInfoLabel.Visible = False;
		
		OpenDataExchangeScenarioCreationAssistant = False;
		
	Else
		
		NodeUsedInExchangeScenario = InfobaseNodeUsedInExchangeScript(Object.InfobaseNode);
		
		Items.ScheduleSettingsInfoLabel.Visible = Not NodeUsedInExchangeScenario AND Users.RolesAvailable("DataSynchronizationSetting");
		
		OpenDataExchangeScenarioCreationAssistant = Users.RolesAvailable("DataSynchronizationSetting");
        
        Items.ScheduleSettingsInfoLabel.Visible = OpenDataExchangeScenarioCreationAssistant;
	EndIf;
    
	// Set the current table of transitions
	InitializeScriptTransfer(ExchangeOverConnectionToCorrespondent);
	
	SetExchangeDirectoryOpeningButtonVisible();
	
	Items.WSPassword.Visible          = False;
	Items.LabelWSPassword.Title   = "";
	Items.WSRememberPassword.Visible = False;

	If ExchangeOverWebService Then
		
		// Receive settings of connection to the correspondent web service.
		// Settings are required, for example, to occasionally poll correspondent whether
		// long data export is complete.
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Object.InfobaseNode);
		FillPropertyValues(ThisObject, SettingsStructure, "WSURLWebService, WSUserName, WSPassword, WSRememberPassword");
		
        Items.WSPassword.Visible = Not WSRememberPassword;
        Items.WSRememberPassword.Visible = Not WSRememberPassword;		
	EndIf;
	
EndProcedure

// Deletes the specified literal (prefix) in the key names of the passed structure.
// Creates a new structure.
//
// Parameters:
//  Structure - Structure - Items structure based on which you should create a new
//                          structure with keys without a specified literal.
//  Literal - String - Characters string that should be excluded from the name of the passed structure keys.
//
// Returns:
//  Structure - it is generated based on the source structure copying.
//
&AtServer
Function DeletePrefixInCollectionKeys(Structure, Literal)
	
	Result = New Structure;
	
	For Each Item IN Structure Do
		
		Result.Insert(StrReplace(Item.Key, Literal, ""), Item.Value);
		
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function GetIndexesOfRowsOfInformationStatisticsTable(RowKeys)
	
	RowIndexes = New Array;
	
	For Each Key IN RowKeys Do
		
		TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", Key));
		
		RowIndex = Object.StatisticsInformation.IndexOf(TableRows[0]);
		
		RowIndexes.Add(RowIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServerNoContext
Procedure GetDataExchangeStatus(DataImportResult, DataExportResult, Val InfobaseNode)
	
	DataExchangeStatus = DataExchangeServer.ExchangeNodeDataExchangeStatus(InfobaseNode);
	
	DataImportResult = DataExchangeStatus["DataImportResult"];
	If IsBlankString(DataExportResult) Then
		DataExportResult = DataExchangeStatus["DataExportResult"];
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteTemporaryDirectoryOfExchangeMessages(TempDirectoryName)
	
	If Not IsBlankString(TempDirectoryName) Then
		
		Try
			DeleteFiles(TempDirectoryName);
			TempDirectoryName = "";
		Except
			WriteLogEvent(NStr("en='Data exchange.Temporary file deletion';ru='Обмен данными.Удаление временных файлов'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
			);
		EndTry;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorInEventLogMonitor(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServerNoContext
Function GetDirectoryNameAtServer(ExchangeMessageTransportKind, InfobaseNode)
	
	Return InformationRegisters.ExchangeTransportSettings.InformationExchangeDirectoryName(ExchangeMessageTransportKind, InfobaseNode);
	
EndFunction

&AtServerNoContext
Function InfobaseNodeUsedInExchangeScript(InfobaseNode)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	Catalog.DataExchangeScripts.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|		 DataExchangeScenarioExchangeSettings.InfobaseNode = &InfobaseNode
	|	AND Not DataExchangeScenarioExchangeSettings.Ref.DeletionMark
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure ExecuteDataExchangeForInfobaseNodeAtServer(Cancel)
	
	OperationStartDate = CurrentSessionDate();
	
	// Save export addition setting
	DataExchangeServer.InteractiveUpdateExportingsSaveSettings(ExportAddition, 
		DataExchangeServer.ExportAdditionNameAutoSaveSettings());
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		RegisterAdditionalModifications();
	Else
		// Additionally register data
		DataExchangeServer.InteractiveRegisterAdditionalExportingsDataUpdate(ExportAddition);
	EndIf;

	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
		Cancel,
		Object.InfobaseNode,
		False,
		True,
		Object.ExchangeMessageTransportKind,
		LongOperation,
		ActionID,
		FileID,
		True,
		WSPassword);
	
EndProcedure

&AtServer
Procedure RefreshTransportSettingsPages()
	
	IsInRoleAddChangeOfDataExchanges = Users.RolesAvailable("DataSynchronizationSetting");
	
	Items.ConfigureExchangeMessagesTransportParameters.Visible = IsInRoleAddChangeOfDataExchanges;
	
	ExchangeMessageTransportKindByDefault = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(Object.InfobaseNode);
	ConfiguredTransportTypes               = InformationRegisters.ExchangeTransportSettings.ConfiguredTransportTypes(Object.InfobaseNode);
	CurrentTransportKind                     = Object.ExchangeMessageTransportKind;
	
	DataExchangeServer.FillChoiceListByAvailableTransportKinds(Object.InfobaseNode, Items.ExchangeMessageTransportKind, ConfiguredTransportTypes);
	
	TransportChoiceList = Items.ExchangeMessageTransportKind.ChoiceList;
	
	Items.ExchangeMessageTransportKindString.TextColor = New Color;
	
	If TransportChoiceList.FindByValue(CurrentTransportKind)<>Undefined Then
		// Do not change
		
	ElsIf TransportChoiceList.FindByValue(ExchangeMessageTransportKindByDefault)<>Undefined Then
		
		Object.ExchangeMessageTransportKind = ExchangeMessageTransportKindByDefault;
		
	ElsIf TransportChoiceList.Count()>0 Then
		Object.ExchangeMessageTransportKind = TransportChoiceList[0].Value;
		
	Else
		// There is nothing
		Object.ExchangeMessageTransportKind = Undefined;
		
		TransportChoiceList.Clear();
		TransportChoiceList.Add(Undefined, NStr("en='Connection is not configured';ru='подключение не настроено'") );
		
		Items.ExchangeMessageTransportKindString.TextColor = StyleColors.ExplanationTextError
	EndIf;
	
	Items.ExchangeMessageTransportKindString.Title = TransportChoiceList[0].Presentation;
	Items.ExchangeMessageTransportKindString.Visible = TransportChoiceList.Count()=1;
	Items.ExchangeMessageTransportKind.Visible= Not Items.ExchangeMessageTransportKindString.Visible;
	
	ExchangeMessageTransportKindOnChangeAtServer();
EndProcedure

&AtServer
Procedure SetExchangeDirectoryOpeningButtonVisible()
	
	ButtonVisible = Object.ExchangeMessageTransportKind=Enums.ExchangeMessagesTransportKinds.FILE
	Or Object.ExchangeMessageTransportKind=Enums.ExchangeMessagesTransportKinds.FTP;
	
	Items.InformationExchangeDirectory.Visible = ButtonVisible;
	If ButtonVisible Then
		Items.InformationExchangeDirectory.Title = GetDirectoryNameAtServer(Object.ExchangeMessageTransportKind, Object.InfobaseNode);
	EndIf;
EndProcedure

&AtClient
Procedure HandleVersionDifferencesError()
	
	Items.MainPanel.CurrentPage = Items.PageErrorVersionDifferences;
	Items.NavigationPanel.CurrentPage = Items.NavigationPageErrorVersionDifferences;
	Items.ContinueSynchronization.DefaultButton = True;
	Items.DecorationErrorVersionDifferences.Title = VersionsDifferenceErrorOnReceivingData.ErrorText;
	VersionsDifferenceErrorOnReceivingData = Undefined;
	CheckVersionDifference = False;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	LongOperationCompletedWithError = False;
	LongOperationMessageStringAboutError = "";
	
	ActionState = DataExchangeServerCall.LongOperationState(ActionID,
																		WSURLWebService,
																		WSUserName,
																		WSPassword,
																		LongOperationMessageStringAboutError);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	Else
		
		If ActionState <> "Executed" Then
			
			LongOperationCompletedWithError = True;
			
		EndIf;
		
		LongOperation = False;
		LongOperationFinished = True;
		
		GoNextExecute();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobTimeoutHandler()
	
	LongOperationCompletedWithError = False;
	
	State = DataExchangeServerCall.JobState(JobID);
	
	If State = "Active" Then
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	Else // Completed, Failed
		
		If State <> "Completed" Then
			
			LongOperationCompletedWithError = True;
			
		EndIf;
		
		LongOperation = False;
		LongOperationFinished = True;
		
		GoNextExecute();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// Handler LongOperationProcessing.
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			If VersionsDifferenceErrorOnReceivingData <> Undefined
				AND VersionsDifferenceErrorOnReceivingData.IsError Then
				
				HandleVersionDifferencesError();
				Return;
				
			EndIf;
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Assistant procedures and functions.

&AtClient
Function GetKeysOfSelectedRows(SelectedRows)
	
	// Return value of the function.
	RowKeys = New Array;
	
	For Each RowID IN SelectedRows Do
		
		TreeRow = StatisticsInformationTree.FindByID(RowID);
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowKeys.Add(TreeRow.Key);
			
		EndIf;
		
	EndDo;
	
	Return RowKeys;
EndFunction

&AtClient
Procedure GetKeysOfAllRows(RowKeys, TreeItemCollection)
	
	For Each TreeRow IN TreeItemCollection Do
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowKeys.Add(TreeRow.Key);
			
		EndIf;
		
		ItemCollection = TreeRow.GetItems();
		
		If ItemCollection.Count() > 0 Then
			
			GetKeysOfAllRows(RowKeys, ItemCollection);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshRepresentationOfDataExchangeItemsState()
	
	Items.PagesOfDataImportStatus.CurrentPage = Items[DataExchangeClient.PagesOfDataImportStatus()[DataImportResult]];
	If Items.PagesOfDataImportStatus.CurrentPage=Items.ImportStateUndefined Then
		Items.GoToDataImportEventsEventLogMonitor.Title = NStr("en='Data has not been imported';ru='Загрузка данных не произведена'");
	Else
		Items.GoToDataImportEventsEventLogMonitor.Title = DataExchangeClient.HyperlinkHeadersOfDataImport()[DataImportResult];
	EndIf;
	
	Items.PagesOfDataDumpStatus.CurrentPage = Items[DataExchangeClient.PagesOfDataDumpStatus()[DataExportResult]];
	If Items.PagesOfDataDumpStatus.CurrentPage=Items.ExportStateUndefined Then
		Items.GoToDataExportEventsEventLogMonitor.Title = NStr("en='Data is not exported';ru='Выгрузка данных не произведена'");
	Else
		Items.GoToDataExportEventsEventLogMonitor.Title = DataExchangeClient.HyperlinkHeadersOfDataDump()[DataExportResult];
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandTreeOfInformationStatistics(RowKey = "")
	
	ItemCollection = StatisticsInformationTree.GetItems();
	
	For Each TreeRow IN ItemCollection Do
		
		Items.StatisticsInformationTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Cursor positioning in a value tree.
	If Not IsBlankString(RowKey) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsInformationTree.GetItems(), RowKey, False);
		
		Items.StatisticsInformationTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures and functions.

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Execute the transition event handlers.
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Set the display of pages.
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Setting the current button by default.
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Go to event handlers.
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
		GoToRow = GoToRows[0];
		
		// Handler OnSkipForward.
		If Not IsBlankString(GoToRow.GoNextHandlerName)
			AND Not GoToRow.LongOperation Then
			
			ProcedureName = "Attachable_[HandlerName](Cancel)";
			ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
			
			Cancel = False;
			
			A = Eval(ProcedureName);
			
			If Cancel Then
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongOperation AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									OnOpenHandlerName = "",
									GoNextHandlerName = "")
									
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongOperation = False;
	NewRow.LongOperationHandlerName = "";
	
EndProcedure

&AtServer
Procedure TransitionsTableNewStringLongOperation(GoToNumber,
									MainPageName,
									NavigationPageName,
									LongOperation = False,
									LongOperationHandlerName = "")
	
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = "";
	NewRow.OnOpenHandlerName      = "";
	
	NewRow.LongOperation = LongOperation;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item IN FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Item.CommandName = CommandName Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Go to event handlers.

&AtClient
Function Attachable_BeginningPage_OnGoingNext(Cancel)
	
	// Check whether form attributes are filled in.
	If Object.InfobaseNode.IsEmpty() Then
		
		NString = NStr("en='Specify an infobase node';ru='Укажите узел информационной базы'");
		CommonUseClientServer.MessageToUser(NString,, "Object.InfobaseNode",, Cancel);
		
	ElsIf Object.ExchangeMessageTransportKind.IsEmpty() Then
		
		NString = NStr("en='Specify connection option';ru='Укажите вариант подключения'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ExchangeMessageTransportKind",, Cancel);
		
	ElsIf ExchangeOverWebService AND IsBlankString(WSPassword) Then
		
		NString = NStr("en='Password is not specified.';ru='Не указан пароль.'");
		CommonUseClientServer.MessageToUser(NString,, "WSPassword",, Cancel);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckWaitingPage_LongOperationProcessing(Cancel, GoToNext)
	
	If ExchangeOverWebService Then
		
		CheckConnectionAndSaveSettings(Cancel);
		
		If Cancel Then
			
			ShowMessageBox(, NStr("en='Cannot execute the operation.';ru='Не удалось выполнить операцию.'"));
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure CheckConnectionAndSaveSettings(Cancel)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, ThisObject);
	
	UserMessage = "";
	WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters,, UserMessage);
	If WSProxy = Undefined Then
		CommonUseClientServer.MessageToUser(UserMessage,,"WSPassword",, Cancel);
		Return;
	EndIf;
	
	If WSRememberPassword Then
		
		Try
			
			SetPrivilegedMode(True);
			
			// update record in IR
			RecordStructure = New Structure;
			RecordStructure.Insert("Node", Object.InfobaseNode);
			RecordStructure.Insert("WSRememberPassword", True);
			RecordStructure.Insert("WSPassword", WSPassword);
			InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
			
		Except
			WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),,,, Cancel);
			Return;
		EndTry;
		
	EndIf;
	
EndProcedure

// Receive data (exchange message transport).

&AtClient
Function Attachable_DataAnalysisWaitPage_LongOperationProcessing(Cancel, GoToNext)
	
	TransportMessageExchange();
	
EndFunction

&AtServer
Procedure TransportMessageExchange()
	
	Try
		
		IgnoreDataGet = False;
		
		LongOperation = False;
		LongOperationFinished = False;
		LongOperationCompletedWithError = False;
		FileID = "";
		ActionID = "";
		
		DataProcessorObject = FormAttributeToValue("Object");
		
		Cancel = False;
		
		DataProcessorObject.GetExchangeMessageToTemporaryDirectory(
				Cancel,
				DataPackageFileID,
				FileID,
				LongOperation,
				ActionID,
				WSPassword
		);
		ValueToFormAttribute(DataProcessorObject, "Object");
		
		If Cancel Then
			IgnoreDataGet = True;
		EndIf;
		
	Except
		IgnoreDataGet = True;
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			NStr("en='Interactive data exchange wizard.Exchange message transport';ru='Помощник интерактивного обмена данными.Транспорт сообщения обмена'")
		);
		Return;
	EndTry;
	
EndProcedure

&AtClient
Function Attachable_DataAnalysisWaitingPageLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataAnalysisWaitingPageLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	If LongOperationFinished Then
		
		If LongOperationCompletedWithError Then
			
			IgnoreDataGet = True;
			
			WriteErrorInEventLogMonitor(LongOperationMessageStringAboutError, DataImportEventLogMonitorMessage);
			
		Else
			
			TransportMessageExchangeLongOperationEnd();
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure TransportMessageExchangeLongOperationEnd()
	
	Try
		DataProcessorObject = FormAttributeToValue("Object");
		
		Cancel = False;
		
		DataProcessorObject.GetExchangeMessageToTempDirectoryLongOperationEnd(
			Cancel,
			DataPackageFileID,
			FileID,
			WSPassword);
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
		If Cancel Then
			IgnoreDataGet = True;
		EndIf;
		
	Except
		IgnoreDataGet = True;
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			NStr("en='Interactive data exchange wizard.Exchange message transport';ru='Помощник интерактивного обмена данными.Транспорт сообщения обмена'")
		);
		Return;
	EndTry;
	
EndProcedure

// Data
// analysis Automatic data match.

&AtClient
Function Attachable_DataAnalysis_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	DataAnalysis();
	
	If VersionsDifferenceErrorOnReceivingData <> Undefined
		AND VersionsDifferenceErrorOnReceivingData.IsError Then
		Cancel = True;
	EndIf;
	
EndFunction

&AtServer
Procedure DataAnalysis()
	
	LongOperation = False;
	LongOperationFinished = False;
	JobID = Undefined;
	TemporaryStorageAddress = "";
	
	Try
		
		MethodParameters = New Structure;
		MethodParameters.Insert("InfobaseNode", Object.InfobaseNode);
		MethodParameters.Insert("ExchangeMessageFileName", Object.ExchangeMessageFileName);
		MethodParameters.Insert("TemporaryExchangeMessagesDirectoryName", Object.TemporaryExchangeMessagesDirectoryName);
		MethodParameters.Insert("CheckVersionDifference", CheckVersionDifference);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.InteractiveDataExchangeAssistant.RunAutomaticDataMapping",
			MethodParameters,
			NStr("en='Analysis of exchange message data';ru='Анализ данных сообщения обмена'")
		);
		
		If Result.JobCompleted Then
			AfterDataAnalysis(GetFromTempStorage(Result.StorageAddress));
		Else
			LongOperation = True;
			JobID = Result.JobID;
			TemporaryStorageAddress = Result.StorageAddress;
		EndIf;
		
	Except
		
		IgnoreDataGet = True;
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			NStr("en='Interactive data exchange wizard.Data analysis';ru='Помощник интерактивного обмена данными.Анализ данных'"));
		
	EndTry;
	
EndProcedure

&AtClient
Function Attachable_DataAnalysisLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataAnalysisLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	If LongOperationFinished Then
		
		If LongOperationCompletedWithError Then
			
			IgnoreDataGet = True;
			
		Else
			
			DataAnalysisLongOperationEnd();
			
		EndIf;
		
	EndIf;
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	ExpandTreeOfInformationStatistics();
	
EndFunction

&AtServer
Procedure DataAnalysisLongOperationEnd()
	
	Try
		AfterDataAnalysis(GetFromTempStorage(TemporaryStorageAddress));
	Except
		IgnoreDataGet = True;
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			NStr("en='Interactive data exchange wizard.Data analysis';ru='Помощник интерактивного обмена данными.Анализ данных'")
		);
		Return;
	EndTry;
	
EndProcedure

&AtServer
Procedure AfterDataAnalysis(Val ResultAnalysis)
	
	If ResultAnalysis.Property("ErrorText") Then
		VersionsDifferenceErrorOnReceivingData = ResultAnalysis;
	Else
		
		AllDataMapped = ResultAnalysis.AllDataMapped;
		StatisticsIsEmpty      = ResultAnalysis.StatisticsIsEmpty;
		Object.StatisticsInformation.Load(ResultAnalysis.StatisticsInformation);
		Object.StatisticsInformation.Sort("Presentation");
		
		GetTreeOfInformationStatistics(Object.StatisticsInformation.Unload());
		
		SetVisibleOfAdditionalInformationGroup();
		
	EndIf;
	
EndProcedure

// Data match by a user.

&AtClient
Function Attachable_StatisticsPage_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If StatisticsIsEmpty OR IgnoreDataGet Then
		SkipPage = True;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_StatisticsPage_OnGoingNext(Cancel)
	
	If StatisticsIsEmpty Or IgnoreDataGet Or AllDataMapped Then
		Return Undefined;
	EndIf;
	
	If True = SkipCurrentPageFailureControl Then
		SkipCurrentPageFailureControl = Undefined;
		Return Undefined;
	EndIf;
	
	// Move forward from the confirmation.
	Cancel = True;
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes,  NStr("en='Continue';ru='Продолжить'"));
	Buttons.Add(DialogReturnCode.No, NStr("en='Cancel';ru='Отменить'"));
	
	Message = NStr("en='Not all data was mapped. Existence of
		|unmapped data can lead to identical catalog items (duplicates).
		|Continue?';ru='Не все данные сопоставлены. Наличие
		|несопоставленных данных может привести к появлению одинаковых элементов справочников (дублей).
		|Продолжить?'");
	
	Notification = New NotifyDescription("StatisticsInformationPage_OnMovingFurtherQuestionEnd", ThisObject);
	
	ShowQueryBox(Notification, Message, Buttons,, DialogReturnCode.Yes);
EndFunction

&AtClient
Procedure StatisticsPage_OnMovingFurtherQuestionEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_SkipForwardByDeferredProcessing", 0.1, True);
EndProcedure

&AtClient
Procedure Attachable_StepForwardByDeferredProcessing()
	
	// Step forward forcefully.
	SkipCurrentPageFailureControl = True;
	ChangeGoToNumber( +1 );
	
EndProcedure
	
// Data Import

&AtClient
Function Attachable_DataImport_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	DataImport();
	
	// Go to the next page regardless of the data import result.
	
EndFunction

&AtServer
Procedure DataImport()
	
	LongOperation = False;
	LongOperationFinished = False;
	JobID = Undefined;
	
	Try
		
		MethodParameters = New Structure;
		MethodParameters.Insert("InfobaseNode", Object.InfobaseNode);
		MethodParameters.Insert("ExchangeMessageFileName", Object.ExchangeMessageFileName);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.InteractiveDataExchangeAssistant.ExecuteDataImport",
			MethodParameters,
			NStr("en='Import data from the exchange message';ru='Загрузка данных из сообщения обмена'"));
		
		If Result.JobCompleted Then
			
			DeleteTemporaryDirectoryOfExchangeMessages(Object.TemporaryExchangeMessagesDirectoryName);
			
		Else
			
			LongOperation = True;
			JobID = Result.JobID;
			
		EndIf;
		
	Except
		IgnoreDataGet = True;
		DeleteTemporaryDirectoryOfExchangeMessages(Object.TemporaryExchangeMessagesDirectoryName);
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			NStr("en='Interactive data exchange wizard.Data import';ru='Помощник интерактивного обмена данными.Загрузка данных'"));
		Return;
	EndTry;
	
EndProcedure

&AtClient
Function Attachable_DataImportLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImportLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If IgnoreDataGet Then
		Return Undefined;
	EndIf;
	
	If LongOperationFinished Then
		
		DeleteTemporaryDirectoryOfExchangeMessages(Object.TemporaryExchangeMessagesDirectoryName);
		
	EndIf;
	
EndFunction

// Additional export

&AtClient
Function Attachable_PageIsQuestionOfCompositionOfDischarge_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If ExportAddition.ExportVariant<0 Then
		// Export is not expended according to the node settings, go to the next page.
		SkipPage = True;
	EndIf;
	
EndFunction

// Data export

&AtClient
Function Attachable_DataExportIdlePage_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	LongOperationCompletedWithError = False;
	FileID = "";
	ActionID = "";
	
	// Go to the next page unconditionally.
	InterimDenial = False;
	ExecuteDataExchangeForInfobaseNodeAtServer(InterimDenial);
EndFunction

&AtClient
Function Attachable_DataExportIdlePageLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExportWaitingPageLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		If LongOperationCompletedWithError Then
			
			DataExchangeServerCall.FixExchangeFinishedWithError(
									Object.InfobaseNode,
									"DataExport",
									OperationStartDate,
									LongOperationMessageStringAboutError);
			
		Else
			
			DataExchangeServerCall.CommitDataExportExecutionInLongOperationMode(Object.InfobaseNode, OperationStartDate);
			
		EndIf;
		
	EndIf;
	
EndFunction

// Totals

&AtClient
Function Attachable_MappingCompletePage_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	GetDataExchangeStatus(DataImportResult, DataExportResult, Object.InfobaseNode);
	
	RefreshRepresentationOfDataExchangeItemsState();
	
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with the export addition.

&AtServer
Procedure InitializeAttributesAdditionsExportings()
	
	// Read parameter to the form attribute
	Parameters.Property("ExtendedModeAdditionsExportings", ExportAdditionExtendedMode);
	
	// Receive settings as a structure, settings will be saved implicitly to the form temporary storage
	SettingsAdditionsExportings = DataExchangeServer.InteractiveExportChange(
		Object.InfobaseNode, ThisObject.UUID, ExportAdditionExtendedMode);
		
	// Set form.
	// Convert to the form attribute of the DataProcessorObject type. Used to simplify data link with the form
	DataExchangeServer.InteractiveUpdateExportingsAttributeBySettings(ThisObject, SettingsAdditionsExportings, "ExportAddition");
	
	ScriptParametersAdditions = ExportAddition.ScriptParametersAdditions;
	
	// Reset interface by a specified script.
	
	// Special cases
	TypicalVariantsProhibited = Not ScriptParametersAdditions.VariantNoneAdds.Use
		AND Not ScriptParametersAdditions.VariantAllDocuments.Use
		AND Not ScriptParametersAdditions.VariantArbitraryFilter.Use;
		
	If TypicalVariantsProhibited Then
		If ScriptParametersAdditions.VariantAdditionally.Use Then
			// One variant by the node script is left
			Items.ExportAdditionExportVariantNodeString.Visible = True;
			Items.ExportAdditionExportVariantNode.Visible        = False;
			Items.IndentGroupsCustomDecoration.Visible           = False;
			ExportAddition.ExportVariant = 3;
		Else
			// There is no variant, select the check box of skipping page and exit
			ExportAddition.ExportVariant = -1;
			Items.VariantsAdditionsExportings.Visible = False;
			Return;
		EndIf;
	EndIf;
	
	// Set typical input fields
	Items.TypicalVariantAdditionsNone.Visible = ScriptParametersAdditions.VariantNoneAdds.Use;
	If Not IsBlankString(ScriptParametersAdditions.VariantNoneAdds.Title) Then
		Items.ExportAdditionExportVariant0.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantNoneAdds.Title;
	EndIf;
	Items.TypicalVariantAdditionsNoneExplanation.Title = ScriptParametersAdditions.VariantNoneAdds.Explanation;
	If IsBlankString(Items.TypicalVariantAdditionsNoneExplanation.Title) Then
		Items.TypicalVariantAdditionsNoneExplanation.Visible = False;
	EndIf;
	
	Items.TypicalVariantOfAdditionsDocuments.Visible = ScriptParametersAdditions.VariantAllDocuments.Use;
	If Not IsBlankString(ScriptParametersAdditions.VariantAllDocuments.Title) Then
		Items.ExportAdditionExportVariant1.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantAllDocuments.Title;
	EndIf;
	Items.TypicalVariantAdditionsDocumentsExplanation.Title = ScriptParametersAdditions.VariantAllDocuments.Explanation;
	If IsBlankString(Items.TypicalVariantAdditionsDocumentsExplanation.Title) Then
		Items.TypicalVariantAdditionsDocumentsExplanation.Visible = False;
	EndIf;
	
	Items.TypicalVariantAdditionsArbitrary.Visible = ScriptParametersAdditions.VariantArbitraryFilter.Use;
	If Not IsBlankString(ScriptParametersAdditions.VariantArbitraryFilter.Title) Then
		Items.ExportAdditionExportVariant2.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantArbitraryFilter.Title;
	EndIf;
	Items.TypicalVariantAdditionsArbitraryExplanation.Title = ScriptParametersAdditions.VariantArbitraryFilter.Explanation;
	If IsBlankString(Items.TypicalVariantAdditionsArbitraryExplanation.Title) Then
		Items.TypicalVariantAdditionsArbitraryExplanation.Visible = False;
	EndIf;
	
	Items.CustomVariantAdditions.Visible           = ScriptParametersAdditions.VariantAdditionally.Use;
	Items.PeriodGroupExportingsScriptNode.Visible         = ScriptParametersAdditions.VariantAdditionally.UsePeriodFilter;
	Items.ExportAdditionFilterOfScriptNode.Visible    = Not IsBlankString(ScriptParametersAdditions.VariantAdditionally.FormNameFilter);
	
	Items.ExportAdditionExportVariantNode.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantAdditionally.Title;
	Items.ExportAdditionExportVariantNodeString.Title              = ScriptParametersAdditions.VariantAdditionally.Title;
	
	Items.CustomVariantExplanationWithAdditions.Title = ScriptParametersAdditions.VariantAdditionally.Explanation;
	If IsBlankString(Items.CustomVariantExplanationWithAdditions.Title) Then
		Items.CustomVariantExplanationWithAdditions.Visible = False;
	EndIf;
	
	// Command titles
	If Not IsBlankString(ScriptParametersAdditions.VariantAdditionally.FormCommandTitle) Then
		Items.ExportAdditionFilterOfScriptNode.Title = ScriptParametersAdditions.VariantAdditionally.FormCommandTitle;
	EndIf;
	
	// Set the available ones in the right order
	OrderOfGroupsAdditions = New ValueList;
	If Items.TypicalVariantAdditionsNone.Visible Then
		OrderOfGroupsAdditions.Add(Items.TypicalVariantAdditionsNone, 
			Format(ScriptParametersAdditions.VariantNoneAdds.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.TypicalVariantOfAdditionsDocuments.Visible Then
		OrderOfGroupsAdditions.Add(Items.TypicalVariantOfAdditionsDocuments, 
			Format(ScriptParametersAdditions.VariantAllDocuments.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.TypicalVariantAdditionsArbitrary.Visible Then
		OrderOfGroupsAdditions.Add(Items.TypicalVariantAdditionsArbitrary, 
			Format(ScriptParametersAdditions.VariantArbitraryFilter.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.CustomVariantAdditions.Visible Then
		OrderOfGroupsAdditions.Add(Items.CustomVariantAdditions, 
			Format(ScriptParametersAdditions.VariantAdditionally.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	OrderOfGroupsAdditions.SortByPresentation();
	For Each GroupItemAdditions IN OrderOfGroupsAdditions Do
		Items.Move(GroupItemAdditions.Value, Items.VariantsAdditionsExportings);
	EndDo;
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		
		ExportAddition.ExportVariant = 2;
		
		FillTableCompanies();
		UpdateFilterByCompanies();
		
		GenerateTreeSpeciesDocuments();
		Items.DocumentTypesFilter.InitialTreeView = InitialTreeView.ExpandAllLevels;
		
		DeleteProgramFilters();
		
	Else
		
		// You can work with the settings only if there is a right
		IsRightOnSettings = AccessRight("SaveUserData", Metadata);
		Items.GroupImportModelOptionsSettings.Visible = IsRightOnSettings;
		If IsRightOnSettings Then
			// Restore predefined settings
			SetFirstItem = Not ExportAdditionSetSettingsServer(DataExchangeServer.ExportAdditionNameAutoSaveSettings());
			ExportAddition.ViewCurrentSettings = "";
		Else
			SetFirstItem = True;
		EndIf;
			
		SetFirstItem = SetFirstItem
			Or
			ExportAddition.ExportVariant<0 
			Or
			( (ExportAddition.ExportVariant=0) AND (NOT ScriptParametersAdditions.VariantNoneAdds.Use) )
			Or
			( (ExportAddition.ExportVariant=1) AND (NOT ScriptParametersAdditions.VariantAllDocuments.Use) )
			Or
			( (ExportAddition.ExportVariant=2) AND (NOT ScriptParametersAdditions.VariantArbitraryFilter.Use) )
			Or
			( (ExportAddition.ExportVariant=3) AND (NOT ScriptParametersAdditions.VariantAdditionally.Use) );
		
		If SetFirstItem Then
			For Each GroupItemAdditions IN OrderOfGroupsAdditions[0].Value.ChildItems Do
				If TypeOf(GroupItemAdditions)=Type("FormField") AND GroupItemAdditions.Type = FormFieldType.RadioButtonField Then
					ExportAddition.ExportVariant = GroupItemAdditions.ChoiceList[0].Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		// Initial display, analog of the client ExportAdditionVariantSetVisible
		Items.FilterGroupAllDocuments.Enabled  = ExportAddition.ExportVariant=1;
		Items.GroupDetailedSelection.Enabled     = ExportAddition.ExportVariant=2;
		Items.FilterGroupCustom.Enabled = ExportAddition.ExportVariant=3;
		
		// Initial filter types description
		SetSelectionAdditionsExportingsDescription();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionExportVariantSetVisible()
	Items.FilterGroupAllDocuments.Enabled  = ExportAddition.ExportVariant=1;
	Items.GroupDetailedSelection.Enabled     = ExportAddition.ExportVariant=2;
	Items.FilterGroupCustom.Enabled = ExportAddition.ExportVariant=3;
EndProcedure

&AtServer
Procedure ExportAdditionUpdatePeriodScriptNode()
	DataExchangeServer.InteractiveExportingsChangeSetScriptNodePeriod(ExportAddition);
EndProcedure

&AtServer
Procedure ExportAdditionClearingGeneralFilterServer()
	DataExchangeServer.InteractiveUpdateExportingsClearingGeneralFilter(ExportAddition);
	SetCommonFilterAdditionDescription();
EndProcedure

&AtServer
Procedure ExportAdditionClearingDetailedFilterServer()
	DataExchangeServer.InteractiveUpdateExportingsClearingInDetail(ExportAddition);
	SetAdditionDescriptionInDetails();
EndProcedure

&AtServer
Procedure SetSelectionAdditionsExportingsDescription()
	SetCommonFilterAdditionDescription();
	SetAdditionDescriptionInDetails();
EndProcedure

&AtServer
Procedure SetCommonFilterAdditionDescription()
	
	Text = DataExchangeServer.InteractiveChangeExportingDescriptionOfAdditionsOfCommonFilter(ExportAddition);
	FilterAbsent = IsBlankString(Text);
	If FilterAbsent Then
		Text = NStr("en='All documents';ru='Все документы'");
	EndIf;
	
	Items.ExportAdditionGeneralDocumentsFilter.Title = Text;
	Items.ExportAdditionGeneralFilterClearing.Visible = Not FilterAbsent;
EndProcedure

&AtServer
Procedure SetAdditionDescriptionInDetails()
	
	Text = DataExchangeServer.InteractiveChangeExportingDetailedFilterDescription(ExportAddition);
	FilterAbsent = IsBlankString(Text);
	If FilterAbsent Then
		Text = NStr("en='Additional data is not selected';ru='Дополнительные данные не выбраны'");
	EndIf;
	
	Items.ExportAdditionDetailedFilter.Title = Text;
	Items.ExportAdditionCleaningDetailedFilter.Visible = Not FilterAbsent;
EndProcedure

// Returns Boolean - successfully/unsuccessfully (setting is not found).
&AtServer 
Function ExportAdditionSetSettingsServer(SettingRepresentation)
	
	Result = DataExchangeServer.InteractiveUpdateExportingsResetSettings(ExportAddition, SettingRepresentation);
	SetSelectionAdditionsExportingsDescription();
	
	If Not ValueIsFilled(ExportAddition.InfobaseNode)
		OR Not CommonUse.RefExists(ExportAddition.InfobaseNode) Then
		
		ExportAddition.InfobaseNode = Object.InfobaseNode;
	EndIf;
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		DocumentKinds = New Array;
		GenerateTreeSpeciesDocuments(DocumentKinds);
		
		RecallFilterByCompanies();
		DeleteProgramFilters();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer 
Function ExportAdditionHistorySettingsServer() 
	Return DataExchangeServer.InteractiveUpdateExportingsHistorySettings(ExportAddition);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Initialization of the assistant's transitions.

&AtServer
Procedure GetDataThroughUsualChannelsLinks()
	
	GoToTable.Clear();
	
	// Begin
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",, "PageBegan_InGoingFurther");
	
	// Receive data (exchange message transport).
	TransitionsTableNewStringLongOperation(2, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(3, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(4, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data
	// analysis Automatic data match.
	TransitionsTableNewStringLongOperation(5, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(6, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisOfLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(7, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data match by a user.
	GoToTableNewRow(8, "StatisticsPage", "NavigationPageContinuation", "PageInformationStatistics_OnOpen", "InformationPageOfStatistics_InGoingFurther");
	
	// Data Import
	TransitionsTableNewStringLongOperation(9,  "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImport_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(10, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(11, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// Totals
	GoToTableNewRow(12, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

&AtServer
Procedure DataGetThroughExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	// Connection verification
	GoToTableNewRow(1, "BeginningPage",                "NavigationPageStart",, "PageBegan_InGoingFurther");
	TransitionsTableNewStringLongOperation(2, "DataAnalysisWaitPage", "NavigationPageWait", True, "PageOutCheckOfConnection_HandleLongRunningOperation");
	
	// Receive data (exchange message transport).
	TransitionsTableNewStringLongOperation(3, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(4, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(5, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data
	// analysis Automatic data match.
	TransitionsTableNewStringLongOperation(6, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(7, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisOfLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(8, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data match by a user.
	GoToTableNewRow(9, "StatisticsPage", "NavigationPageContinuation", "PageInformationStatistics_OnOpen", "InformationPageOfStatistics_InGoingFurther");
	
	// Data Import
	TransitionsTableNewStringLongOperation(10, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImport_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(11, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(12, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// Totals
	GoToTableNewRow(13, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

&AtServer
Procedure SendDataThroughUsualChannelsLinks()
	
	GoToTable.Clear();
	
	// Begin
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",, "PageBegan_InGoingFurther");
	
	// Data export setting
	DataExportResult = "";
	GoToTableNewRow(2, "PageIsQuestionOfCompositionOfDischarge", "NavigationPageContinuation", "PageIsQuestionOfCompositionOfDischarge_WhenOpening");
	
	// Data export
	TransitionsTableNewStringLongOperation(3, "WaitPageSynchronizationData", "NavigationPageWait", True, "WaitPageDataImport_ProcessingLongRunningOperation");
	TransitionsTableNewStringLongOperation(4, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageOutDataTimeConsumingOperation_ExportingOfMachiningOperation");
	TransitionsTableNewStringLongOperation(5, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageDataImportOperationLongWaitEnds_ProcessingLongRunningOperation");
	
	// Totals
	GoToTableNewRow(6, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

&AtServer
Procedure SendDataThroughExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	// Connection verification
	GoToTableNewRow(1, "BeginningPage",                      "NavigationPageStart",, "PageBegan_InGoingFurther");
	TransitionsTableNewStringLongOperation(2, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageOutCheckOfConnection_HandleLongRunningOperation");
	
	// Data export setting
	DataExportResult = "";
	GoToTableNewRow(3, "PageIsQuestionOfCompositionOfDischarge",  "NavigationPageContinuation", "PageIsQuestionOfCompositionOfDischarge_WhenOpening");
	
	// Data export
	TransitionsTableNewStringLongOperation(4, "WaitPageSynchronizationData", "NavigationPageWait", True, "WaitPageDataImport_ProcessingLongRunningOperation");
	TransitionsTableNewStringLongOperation(5, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageOutDataTimeConsumingOperation_ExportingOfMachiningOperation");
	TransitionsTableNewStringLongOperation(6, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageDataImportOperationLongWaitEnds_ProcessingLongRunningOperation");
	
	// Totals
	GoToTableNewRow(7, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

&AtServer
Procedure GetAndSendDataThroughUsualChannelsLinks()
	
	GoToTable.Clear();
	
	// Begin
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",, "PageBegan_InGoingFurther");
	
	// Receive data (exchange message transport).
	TransitionsTableNewStringLongOperation(2, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(3, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(4, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data
	// analysis Automatic data match.
	TransitionsTableNewStringLongOperation(5, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(6, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisOfLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(7, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data match by a user.
	GoToTableNewRow(8, "StatisticsPage", "NavigationPageContinuation", "PageInformationStatistics_OnOpen", "InformationPageOfStatistics_InGoingFurther");
	
	// Data Import
	TransitionsTableNewStringLongOperation(9,  "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImport_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(10, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(11, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// Data export setting
	DataExportResult = "";
	GoToTableNewRow(12, "PageIsQuestionOfCompositionOfDischarge",  "NavigationPageContinuation", "PageIsQuestionOfCompositionOfDischarge_WhenOpening");
	
	// Data export
	TransitionsTableNewStringLongOperation(13, "WaitPageSynchronizationData", "NavigationPageWait", True, "WaitPageDataImport_ProcessingLongRunningOperation");
	TransitionsTableNewStringLongOperation(14, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageOutDataTimeConsumingOperation_ExportingOfMachiningOperation");
	TransitionsTableNewStringLongOperation(15, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageDataImportOperationLongWaitEnds_ProcessingLongRunningOperation");
	
	// Totals
	GoToTableNewRow(16, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

&AtServer
Procedure GetAndSendDataThroughExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	// Connection verification
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",, "PageBegan_InGoingFurther");
	TransitionsTableNewStringLongOperation(2, "DataAnalysisWaitPage", "NavigationPageWait", True, "PageOutCheckOfConnection_HandleLongRunningOperation");
	
	// Receive data (exchange message transport).
	TransitionsTableNewStringLongOperation(3, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(4, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(5, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data
	// analysis Automatic data match.
	TransitionsTableNewStringLongOperation(6, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(7, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisOfLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(8, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data match by a user.
	GoToTableNewRow(9, "StatisticsPage", "NavigationPageContinuation", "PageInformationStatistics_OnOpen", "InformationPageOfStatistics_InGoingFurther");
	
	// Data Import
	TransitionsTableNewStringLongOperation(10, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImport_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(11, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(12, "WaitPageSynchronizationData", "NavigationPageWait", True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// Data export setting
	DataExportResult = "";
	GoToTableNewRow(13, "PageIsQuestionOfCompositionOfDischarge",  "NavigationPageContinuation", "PageIsQuestionOfCompositionOfDischarge_WhenOpening");
	
	// Data export
	TransitionsTableNewStringLongOperation(14, "WaitPageSynchronizationData", "NavigationPageWait", True, "WaitPageDataImport_ProcessingLongRunningOperation");
	TransitionsTableNewStringLongOperation(15, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageOutDataTimeConsumingOperation_ExportingOfMachiningOperation");
	TransitionsTableNewStringLongOperation(16, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageDataImportOperationLongWaitEnds_ProcessingLongRunningOperation");
	
	// Totals
	GoToTableNewRow(17, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsSB

#Region FormItemEventsHandlers

&AtClient
Procedure ExportAdditionSimplifiedCommonPeriodDocumentsClearing(Item, StandardProcessing)
	// Prohibit the period clearing
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure CompanyFilterClean(Command)
	
	HeaderText = NStr("en='Confirmation';ru='Подтверждение'");
	QuestionText   = NStr("en='Clear filter by companies?';ru='Очистить отбор по организациям?'");
	NotifyDescription = New NotifyDescription("ClearFilterByCompanyEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
	
EndProcedure

&AtClient
Procedure ClearFilterByCompanyEnd(Response, AdditionalParameters) Export
	
	If Response=DialogReturnCode.Yes Then
		CompaniesTable.Clear();
		UpdateFilterByCompanies();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionSaveSettings(Command)
	
	FillAdditionalRegistration();
	
	DataExchangeClient.OpenFormAdditionsExportingsSaveSettings(ExportAddition, ThisForm);
	
	DeleteProgramFilters();
	
EndProcedure

&AtClient
Procedure ExportAdditionLoadSettings(Command)
	
	// Arrange selection from the menu list, all variants of the saved settings
	VariantList = ExportAdditionHistorySettingsServer();
	
	// Add saving variant of the current
	Text = NStr("en='Saving the current configuration...';ru='Сохранить текущую настройку...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistorySelectionFromMenu", ThisObject);
	ShowChooseFromMenu(NOTifyDescription, VariantList, Items.ExportAdditionLoadSettings);
	
EndProcedure

&AtClient
Procedure IncludeAllDocumentKinds(Command)
	
	NoteDocumentKinds(True);
	
EndProcedure

&AtClient
Procedure DisableAllDocumentKinds(Command)
	
	NoteDocumentKinds(False);
	
EndProcedure

#EndRegion

#Region FormTableItemEventsHandlersFilterByDocumentTypes

&AtClient
Procedure DocumentTypesFilterCheckOnChange(Item)
	
	CurrentData = Items.DocumentTypesFilter.CurrentData;
	If CurrentData <> Undefined Then
		
		MarkValue = CurrentData.Check;
		If CurrentData.GetParent() = Undefined Then
			NoteDocumentKinds(MarkValue, CurrentData.GetID());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterByDocumentKindsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Field=Items.DocumentTypesFilterSelectionString Then
		StandardProcessing = False;
		CurrentData = Items.DocumentTypesFilter.CurrentData;
		If IsBlankString(CurrentData.FullMetadataName) Then
			Return;
		EndIf;
		
		OpenForm("DataProcessor.InteractiveExportChange.Form.PeriodAndFilterEditing",
			New Structure("Title, ActionSelect, PeriodSelection, SettingsComposer, DataPeriod",
				CurrentData.Presentation,
				-Items.DocumentTypesFilter.CurrentRow,
				False,
				SettingsComposerByTableName(CurrentData.FullMetadataName, CurrentData.Presentation, CurrentData.Filter),
				CurrentData.Period
			),
			Items.DocumentTypesFilter
		);
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentTypesFilterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		// Filter condition editing, negative string number
		Items.DocumentTypesFilter.CurrentRow = EditingRowFilterAdditionalListServer(ValueSelected);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure InitializeScriptTransfer(ExchangeOverConnectionToCorrespondent)
	
	// Set the current table of transitions
	If ExchangeOverConnectionToCorrespondent Then
		
		If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments"
			AND ExportAdditionExtendedMode Then
			
			ScriptExchangeOnlineSynchronisationThroughExternalConnectionOrWebService();
			
		ElsIf GetData AND SendData Then
			
			GetAndSendDataThroughExternalConnectionOrWebService();
			
		ElsIf GetData Then
			
			DataGetThroughExternalConnectionOrWebService();
			
		ElsIf SendData Then
			
			SendDataThroughExternalConnectionOrWebService();
			
		Else
			
			Raise NStr("en='This data synchronization scenario is not supported.';ru='Заданный сценарий синхронизации данных не поддерживается.'");
			
		EndIf;
		
	Else
		
		If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments"
			AND ExportAdditionExtendedMode Then
			
			ScriptExchangeOnlineSynchronisationThroughUsualChannelsLinks();
		
		ElsIf GetData AND SendData Then
			
			GetAndSendDataThroughUsualChannelsLinks();
			
		ElsIf GetData Then
			
			GetDataThroughUsualChannelsLinks();
			
		ElsIf SendData Then
			
			SendDataThroughUsualChannelsLinks();
			
		Else
			
			Raise NStr("en='This data synchronization scenario is not supported.';ru='Заданный сценарий синхронизации данных не поддерживается.'");
			
		EndIf;
		
	EndIf;

EndProcedure

&AtServer
Procedure ScriptExchangeOnlineSynchronisationThroughExternalConnectionOrWebService()
	
	GoToTable.Clear();
	
	// Connection verification
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",, "PageBegan_InGoingFurther");
	TransitionsTableNewStringLongOperation(2, "DataAnalysisWaitPage", "NavigationPageWait", True, "PageOutCheckOfConnection_HandleLongRunningOperation");
	
	// Data receipt (exchange message transport)
	TransitionsTableNewStringLongOperation(3, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(4, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(5, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data
	// analysis Automatic data match
	TransitionsTableNewStringLongOperation(6, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(7, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisOfLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(8, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data Import
	TransitionsTableNewStringLongOperation(9,  "DataExportWaitPageSimplified", "NavigationPageWait", True, "DataImport_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(10, "DataExportWaitPageSimplified", "NavigationPageWait", True, "DataImportLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(11, "DataExportWaitPageSimplified", "NavigationPageWait", True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// Data export setting
	DataExportResult = "";
	GoToTableNewRow(12, "PageIsQuestionOfCompositionOfExportSimplified", "NavigationPageContinuation");
	
	// Data export confirmation
	GoToTableNewRow(13, "PageConfirmationExportingsData", "NavigationPageConfirmation");
	
	// Data export
	TransitionsTableNewStringLongOperation(14, "WaitPageSynchronizationData", "NavigationPageWait", True, "WaitPageDataImport_ProcessingLongRunningOperation");
	TransitionsTableNewStringLongOperation(15, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageOutDataTimeConsumingOperation_ExportingOfMachiningOperation");
	TransitionsTableNewStringLongOperation(16, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageDataImportOperationLongWaitEnds_ProcessingLongRunningOperation");
	
	// Totals
	GoToTableNewRow(17, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

&AtServer
Procedure ScriptExchangeOnlineSynchronisationThroughUsualChannelsLinks()
	
	GoToTable.Clear();
	
	// Begin
	GoToTableNewRow(1, "BeginningPage", "NavigationPageStart",, "PageBegan_InGoingFurther");
	
	// Data receipt (exchange message transport)
	TransitionsTableNewStringLongOperation(2, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(3, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(4, "DataAnalysisWaitPage", "NavigationPageWait", True, "WaitPageDataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data
	// analysis Automatic data match
	TransitionsTableNewStringLongOperation(5, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysis_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(6, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisOfLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(7, "DataAnalysisWaitPage", "NavigationPageWait", True, "DataAnalysisEnd_LongOperationLongOperationProcessing");
	
	// Data Import
	TransitionsTableNewStringLongOperation(8, "DataExportWaitPageSimplified", "NavigationPageWait", True, "DataImport_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(9, "DataExportWaitPageSimplified", "NavigationPageWait", True, "DataImportLongOperation_LongOperationProcessing");
	TransitionsTableNewStringLongOperation(10, "DataExportWaitPageSimplified", "NavigationPageWait",True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// Data export setting
	DataExportResult = "";
	GoToTableNewRow(11, "PageIsQuestionOfCompositionOfExportSimplified", "NavigationPageContinuation");
	
	// Data export confirmation
	GoToTableNewRow(12, "PageConfirmationExportingsData", "NavigationPageConfirmation");
	
	// Data export
	TransitionsTableNewStringLongOperation(13, "WaitPageSynchronizationData", "NavigationPageWait", True, "WaitPageDataImport_ProcessingLongRunningOperation");
	TransitionsTableNewStringLongOperation(14, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageOutDataTimeConsumingOperation_ExportingOfMachiningOperation");
	TransitionsTableNewStringLongOperation(15, "WaitPageSynchronizationData", "NavigationPageWait", True, "PageDataImportOperationLongWaitEnds_ProcessingLongRunningOperation");
	
	// Totals
	GoToTableNewRow(16, "MappingCompletePage", "NavigationPageEnd", "FinishMapping_PageWhenYouOpen");
	
EndProcedure

&AtServer
Procedure FillAdditionalRegistration(AddAdditionalFilters = True)

	If Not ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		Return;
	EndIf;
	
	ExportAddition.AdditionalRegistration.Clear();
	
	FilterTree = FormAttributeToValue("FilterByDocumentKindsTree", Type("ValueTree"));
	For Each UpperLevelRow IN FilterTree.Rows Do
		For Each StringDetails IN UpperLevelRow.Rows Do
			If StringDetails.Check Then
				NewRow = ExportAddition.AdditionalRegistration.Add();
				FillPropertyValues(NewRow, StringDetails);
			EndIf;
		EndDo;
	EndDo;
	
	If Not AddAdditionalFilters Then
		Return;
	EndIf;
	
	ArraySelectedCompanies = GetArraySelectedCompanies();
	
	AddFilterByCompanies = ArraySelectedCompanies.Count() > 0;
	CompaniesList = New ValueList;
	CompaniesList.LoadValues(ArraySelectedCompanies);
	For Each TableRow IN ExportAddition.AdditionalRegistration Do
		
		TableRow.PeriodSelection	= True;
		TableRow.Period		= ExportAddition.AllDocumentsFilterPeriod;
		
		If AddFilterByCompanies Then
			NewItem = TableRow.Filter.Items.Add(Type("DataCompositionFilterItem"));
			NewItem.UserSettingID = "ProgramFilterByCompanies";
			NewItem.LeftValue =  New DataCompositionField("Ref.Company");
			NewItem.ComparisonType = DataCompositionComparisonType.InList;
			NewItem.RightValue = CompaniesList;
			NewItem.Use = True;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RegisterAdditionalModifications() Export
	
	FillAdditionalRegistration();
	
	ExportAdditionObject = FormAttributeToValue("ExportAddition");
	
	// Set in details, clear general
	ExportAdditionObject.ComposerAllDocumentsFilter = Undefined;
	ExportAdditionObject.AllDocumentsFilterPeriod      = Undefined;
	
	ChangesTree = ExportAdditionObject.GenerateValueTree();
	
	NodesForRegistration = New Array;
	NodesForRegistration.Add(Object.InfobaseNode);
	
	ExchangePlanName = Object.InfobaseNode.Metadata().Name;
	ArrayOfRegisteredDocuments = New Array;
	
	SetPrivilegedMode(True);
	For Each GroupRow IN ChangesTree.Rows Do
		For Each String IN GroupRow.Rows Do
			If String.CountForExport>0 Then
				
				RegistrationObject = String.RegistrationObject.GetObject();
				If RegistrationObject = Undefined Then
					Continue;
				EndIf;
				
				If Metadata.Documents.Contains(RegistrationObject.Metadata()) Then
					
					If ArrayOfRegisteredDocuments.Find(RegistrationObject.Ref) <> Undefined Then
						Continue;
					Else
						ArrayOfRegisteredDocuments.Add(RegistrationObject.Ref);
					EndIf;
					
					RegistrationObject.AdditionalProperties.Insert("NodesForRegistration", NodesForRegistration);
					RegistrationObject.AdditionalProperties.Insert("RegisteredDocuments", ArrayOfRegisteredDocuments);
					DataExchangeEvents.ExecuteRegistrationRulesForObject(RegistrationObject, ExchangePlanName, Undefined);
					
				Else
					
					DataExchangeEvents.RecordChangesData(Object.InfobaseNode, RegistrationObject, False);
					
				EndIf;
				
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Function EditingRowFilterAdditionalListServer(ChoiceStructure)
	
	CurrentData = FilterByDocumentKindsTree.FindByID(-ChoiceStructure.ActionSelect);
	If CurrentData=Undefined Then
		Return Undefined
	EndIf;
	
	CurrentData.Check 	   = True;
	CurrentData.Period       = ChoiceStructure.PeriodOfData;
	CurrentData.Filter        = ChoiceStructure.SettingsComposer.Settings.Filter;
	CurrentData.SelectionString = FilterPresentation(CurrentData.Period, CurrentData.Filter);
	
	Return ChoiceStructure.ActionSelect;
EndFunction

&AtServer
Function SettingsComposerByTableName(TableName, Presentation, Filter)
	
	ExportAdditionObject = FormAttributeToValue("ExportAddition");
	Return ExportAdditionObject.SettingsComposerByTableName(TableName, Presentation, Filter, UUID);
	
EndFunction

&AtClient
Procedure NoteDocumentKinds(MarkValue, ItemIdentificator = Undefined)
	
	If ItemIdentificator <> Undefined Then
		TreeItem = FilterByDocumentKindsTree.FindByID(ItemIdentificator);
		LowerLevelElements = TreeItem.GetItems();
		For Each LowerLevelElement IN LowerLevelElements Do
			LowerLevelElement.Check = MarkValue;
		EndDo;
	Else
		UpperLevelItems = FilterByDocumentKindsTree.GetItems();
		For Each TopLevelItem IN UpperLevelItems Do
			TopLevelItem.Check = MarkValue;
			LowerLevelElements = TopLevelItem.GetItems();
			For Each LowerLevelElement IN LowerLevelElements Do
				LowerLevelElement.Check = MarkValue;
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure RecallFilterByCompanies()

	CompaniesTable.Clear();
	
	AdditionalFilters = ExportAddition.AdditionalRegistration;
	If AdditionalFilters.Count() = 0 Then
		
		UpdateFilterByCompanies();
		Return;
		
	Else
		
		FilterByCompanies = "ProgramFilterByCompanies";
		FoundItem = Undefined;
		For Each TableRow IN AdditionalFilters Do
			DocumentFilter = TableRow.Filter;
			For Each FilterItem IN DocumentFilter.Items Do
				If FilterItem.UserSettingID = FilterByCompanies Then
					FoundItem = FilterItem;
					Break;
				EndIf;
			EndDo;
		EndDo;
		
		If FoundItem = Undefined
			OR Not FoundItem.Use
			OR Not ValueIsFilled(FoundItem.RightValue) Then
			
			UpdateFilterByCompanies();
			Return;
			
		Else
			
			If TypeOf(FoundItem.RightValue) = Type("ValueList") Then
				
				For Each ItemOfList IN FoundItem.RightValue Do
					
					NewRow = CompaniesTable.Add();
					NewRow.Company = ItemOfList.Value;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	UpdateFilterByCompanies();

EndProcedure

&AtServer
Procedure DeleteProgramFilters()

	FilterByCompanies = "ProgramFilterByCompanies";
	For Each TableRow IN ExportAddition.AdditionalRegistration Do
		
		DocumentFilter = TableRow.Filter;
		
		ArrayOfItemsForDeletion = New Array;
		For Each FilterItem IN DocumentFilter.Items Do
			If FilterItem.UserSettingID = FilterByCompanies Then
				ArrayOfItemsForDeletion.Add(FilterItem);
			EndIf;
		EndDo;
		
		For Each ArrayElement IN ArrayOfItemsForDeletion Do
			DocumentFilter.Items.Delete(ArrayElement);
		EndDo;
		
		TableRow.PeriodSelection	= False;
		TableRow.Period		= Undefined;
		
	EndDo;

EndProcedure

&AtServer
Procedure RefreshFilter(UpdateParameters)
	
	If TypeOf(UpdateParameters) = Type("Structure")
		AND UpdateParameters.Property("TableNameForFill")
		AND UpdateParameters.TableNameForFill = "Companies" Then
		
		If Not IsBlankString(UpdateParameters.AddressTableInTemporaryStorage) Then
			UpdateFilterByCompanies(UpdateParameters.AddressTableInTemporaryStorage);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateFilterByCompanies(AddressOfObject="")
	
	If Not IsBlankString(AddressOfObject) Then
		TableSelectedCompanies = GetFromTempStorage(AddressOfObject);
		CompaniesTable.Load(TableSelectedCompanies);
	EndIf;
	
	//Update the title of selected companies
	ArraySelectedCompanies = GetArraySelectedCompanies();
	CompaniesSelected = ArraySelectedCompanies.Count() > 0;
	If Not CompaniesSelected Then
		Text = NStr("en='Select companies ';ru='Выбрать организации '");
	Else
		Text = NStr("en='All companies ';ru='Все организации '");
	EndIf;
	
	Items.OpenFilterFormByCompanies.Title = Text;
	Items.CompanyFilterClean.Visible = CompaniesSelected;
	
EndProcedure

&AtServer
Procedure FillTableCompanies()

	CompaniesTable.Clear();
	CompaniesArray = GetArrayAllCompanies();
	
	For Each ArrayElement IN CompaniesArray Do
		
		NewRow = CompaniesTable.Add();
		NewRow.Company = ArrayElement;
		
	EndDo;

EndProcedure

&AtServer
Function GetArraySelectedCompanies()

	Return CompaniesTable.Unload().UnloadColumn("Company");

EndFunction

&AtServer
Function GetArrayAllCompanies()

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies";
	
	Result = Query.Execute();
	
	Return Result.Unload().UnloadColumn("Company");

EndFunction

&AtServer
Function SelectAllCompanies()

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Companies.Ref
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Not Companies.Ref IN (&SelectedCompanies)";
	
	Query.SetParameter("SelectedCompanies", GetArraySelectedCompanies());
	Result = Query.Execute();
	
	Return Result.IsEmpty();

EndFunction

&AtServer
Function FilterPresentation(Period, Filter)
	
	ExportAdditionObject = FormAttributeToValue("ExportAddition");
	DetailsOfEmptySelection = NStr("en='All documents';ru='Все документы'");
	Return ExportAdditionObject.FilterPresentation(Period, Filter, DetailsOfEmptySelection);
	
EndFunction

&AtServer
Procedure GenerateTreeSpeciesDocuments(ArraySelectedValues = Undefined)

	ProcessingOfAddition = FormAttributeToValue("ExportAddition");
	
	FilterTree = FormAttributeToValue("FilterByDocumentKindsTree", Type("ValueTree"));
	FilterTree.Rows.Clear();
	
	MetaDocuments = Metadata.Documents;
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Sales";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.AcceptanceCertificate, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CustomerInvoice, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InvoiceForPayment, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.AgentReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.RetailReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.RetailRevaluation, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Purchases";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.SupplierInvoice, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.AdditionalCosts, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.ReportToPrincipal, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.SubcontractorReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryReconciliation, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryWriteOff, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Service";
	
	StringDetails = UpperLevelRow.Rows.Add();
	StringDetails.MetadataObjectName = MetaDocuments.CustomerOrder.Name;
	StringDetails.FullMetadataName = MetaDocuments.CustomerOrder.FullName();
	StringDetails.Presentation = "Job-order";
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Production";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryAssembly, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.ProcessingReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CostAllocation, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Funds";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.ExpenseReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashPayment, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentExpense, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentOrder, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Other";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.Netting, UpperLevelRow);
	
	CheckAllItems = ArraySelectedValues = Undefined;
	
	For Each UpperLevelRow IN FilterTree.Rows Do
		AllItemsAreSelected = True;
		For Each StringDetails IN UpperLevelRow.Rows Do
			If Not CheckAllItems
				AND ArraySelectedValues.Find(StringDetails.MetadataObjectName) = Undefined Then
				AllItemsAreSelected = False;
			Else
				StringDetails.Check = True;
			EndIf;
			StringDetails.PictureIndex = -1;
			StringDetails.SelectionString  = FilterPresentation(StringDetails.Period, StringDetails.Filter);
		EndDo;
		If AllItemsAreSelected Then
			UpperLevelRow.Check = True;
		EndIf;
		UpperLevelRow.PictureIndex = 0;
	EndDo;
	
	For Each TabularSectionRow IN ExportAddition.AdditionalRegistration Do
		FoundString = FilterTree.Rows.Find(TabularSectionRow.FullMetadataName, "FullMetadataName", True);
		If FoundString <> Undefined Then
			FillPropertyValues(FoundString, TabularSectionRow);
			FoundString.Check = True;
		EndIf;
	EndDo;
	
	For Each UpperLevelRow IN FilterTree.Rows Do
		AllItemsAreSelected = True;
		For Each StringDetails IN UpperLevelRow.Rows Do
			If Not StringDetails.Check Then
				AllItemsAreSelected = False;
			EndIf;
		EndDo;
		UpperLevelRow.Check = AllItemsAreSelected;
	EndDo;
	
	ValueToFormAttribute(FilterTree, "FilterByDocumentKindsTree");
	
EndProcedure

&AtServer
Procedure AddLineTreeOfDocumentsKind(MetadataObject, UpperLevelRow)

	StringDetails = UpperLevelRow.Rows.Add();
	StringDetails.MetadataObjectName = MetadataObject.Name;
	StringDetails.FullMetadataName = MetadataObject.FullName();
	StringDetails.Presentation = MetadataObject.Synonym;

EndProcedure

#EndRegion

#EndRegion
