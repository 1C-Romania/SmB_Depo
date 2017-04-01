&AtClient
Var AdministrationParameters;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return; // Fail is set in OnOpen().
	EndIf;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
	WriteLogEvent(ConfigurationUpdate.EventLogMonitorEvent(), EventLogLevel.Information,,,
		NStr("en='Opening configuration update assistant...';ru='Открытие помощника обновления конфигурации...'"));
	ConfigurationUpdate.AbortExecuteIfExternalUserAuthorized();
	
	// Setting the update flag at the end of assistant work.
	ExecuteUpdate = False;
	
	// If it is the first start after the configuration update, we save and reset the status.
	Object.UpdateResult = ConfigurationUpdate.ConfigurationUpdateSuccessful();
	If Object.UpdateResult <> Undefined Then
		ConfigurationUpdate.ResetStatusOfConfigurationUpdate();
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
		Items.PanelMail.Visible = False;
	EndIf;
	
	// Check each time when opening the assistant.
	ConfigurationChanged = ConfigurationChanged();
	
	If Parameters.CompletingOfWorkSystem Then
		Items.SwitchFileUpdates.Visible = False;
		Items.RadioButtonUpdateServer.Visible = False;
		Items.UpdateDateGroup.Visible = False;
	EndIf;
	
	If Parameters.ConfigurationUpdateReceived Then
		
		Items.PagesUpdateMethodFile.CurrentPage = Items.PageReceivedUpdateFromFileApplications;
		
	EndIf;
	
	InformationOnAvailabilityOfConnections = InfobaseConnections.ConnectionInformation();
	ThereAreActiveSessions = Not InformationOnAvailabilityOfConnections.ActiveConnectionsExist;
	
	Items.LabelConfigurationUpdateInProgressWhenDataExchangeWithHost.Title = StringFunctionsClientServer.SubstituteParametersInString(
		Items.LabelConfigurationUpdateInProgressWhenDataExchangeWithHost.Title, ExchangePlans.MasterNode());
	
	AuthenticationParameters = StandardSubsystemsServer.AuthenticationParametersOnSite();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ItIsPossibleToStartUpdate() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	RestoreSettingsUpdateConfigurations();
	
	If Parameters.ExecuteUpdate Then
		If ThereAreActiveSessions Then
			GoToChoiceOfUpdateMode();
			Return;
		ElsIf CheckAccessToIB() Then
			ExecuteUpdate = True;
			ConfigurationUpdateClientOverridable.BeforeExit();
			ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
			Exit(False);
			Close();
		EndIf;
	EndIf;
	
	Pages = Items.AssistantPages.ChildItems;
	PageName = Pages.Welcome.Name;
	
	AvailableUpdate = ConfigurationUpdateClient.GetAvailableConfigurationUpdate();
	// If there is an update in the Internet network...
	If AvailableUpdate.UpdateSource = 0 AND AvailableUpdate.FlagOfAutoTransitionToPageWithUpdate Then
		TimeOfObtainingUpdate = AvailableUpdate.TimeOfObtainingUpdate;
		If TimeOfObtainingUpdate <> Undefined AND CommonUseClient.SessionDate() - TimeOfObtainingUpdate < 30 Then
			PageName = GetUpdateFilesViaInternet(True);
		EndIf;
	// If the configuration is changed, we will apply it to the data base.
	ElsIf AvailableUpdate.UpdateSource = 2 AND AvailableUpdate.NeedUpdateFile = 0 
		AND AvailableUpdate.FlagOfAutoTransitionToPageWithUpdate Then
		PageName = Pages.UpdateFile.Name;
	EndIf;
	
	If Object.SchedulerTaskCode <> 0 Then
		If GetSchedulerTask(Object.SchedulerTaskCode) = Undefined Then
			Object.SchedulerTaskCode = 0;
		EndIf;
	EndIf;
	
	// If the form opens at the application start after updating.
	If Object.UpdateResult <> Undefined Then	
		
		FileNameOrderUpdate = GetNameOfLocalFileOfUpdateOrder();
		If Not FileExistsAtClient(FileNameOrderUpdate) Then
			FileNameOrderUpdate = "";
		EndIf; 
		
		FileNameInformationAboutUpdate	= GetNameOfLocalFileOfUpdateDescription();
		If Not FileExistsAtClient(FileNameInformationAboutUpdate) Then
			FileNameInformationAboutUpdate = "";
		EndIf; 
		
		PageName = ? (Object.UpdateResult, Pages.SuccessfulRefresh.Name, Pages.FailureRefresh.Name);
		Object.UpdateResult = Undefined;
		
	Else
		
		ConfigurationIsReadyForUpgrade = ConfigurationUpdateClientOverridable.ReadinessForConfigurationUpdate(True);
		If ConfigurationIsReadyForUpgrade = Undefined Then
			ConfigurationIsReadyForUpgrade = True;
		EndIf;
		ConfigurationUpdateClientOverridable.WhenDeterminingConfigurationReadinessForUpdate(
			ConfigurationIsReadyForUpgrade);
		
		If Not ConfigurationIsReadyForUpgrade Then
			NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
			EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Information",
				NStr("en='Configuration can not be updated. Update verification completion.';ru='Конфигурация не может быть обновлена. Завершение проверки обновления.'"));
			Cancel = True;
			Return;
		EndIf; 
		
		If Object.SchedulerTaskCode <> 0 Then
			DenialParameter	= False; // It is not used in this case.
			PageName		= RestoreResultsOfPreviousStart(DenialParameter);
		ElsIf ConfigurationChanged AND
				Object.UpdateSource = 2 Then
			Object.NeedUpdateFile	= 0;
			PageName		= Pages.UpdateFile.Name;
		EndIf;
		
		If Not StandardSubsystemsClientReUse.ClientWorkParameters().IsMasterNode Then
			If ConfigurationChanged Then
				GoToChoiceOfUpdateMode();
				Return;
			Else
				PageName = Pages.UpdatesNotDetected.Name;
			EndIf;
		EndIf
		
	EndIf;
	
	If PageName = Undefined Then
		Return;
	EndIf;
	
	BeforePageOpen(Pages[PageName]);
	Items.AssistantPages.CurrentPage = Pages[PageName];
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.ConfigurationUpdate.Form.ScheduleSetup") Then
		
		If TypeOf(ValueSelected) = Type("Structure") Then
			FillPropertyValues(Object, ValueSelected);
		EndIf;
		
		BeforePageOpen();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.ActiveUsers.Form.ActiveUsersListForm") Then
		
		BeforePageOpen();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.ConfigurationUpdate.Form.BackupSetup") Then
		
		If TypeOf(ValueSelected) = Type("Structure") Then
			FillPropertyValues(Object, ValueSelected);
		EndIf;
		
		BeforePageOpen();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SoftwareUpdateLegality" AND Not Parameter Then
		
		ToWorkClickButtonsBack();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	AvailableUpdate = ConfigurationUpdateClient.GetAvailableConfigurationUpdate();
	If AvailableUpdate.UpdateSource <> -1 Then
		AvailableUpdate.FlagOfAutoTransitionToPageWithUpdate = False;
	EndIf;
	
	// Save update settings.
	SaveSettingsOfConfigurationUpdate();
	
	// Configuration update.
	If ExecuteUpdate Then
		RunConfigurationUpdate();
	EndIf;
	
	// event log record
	EventLogMonitorServerCall.WriteEventsToEventLogMonitor(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Welcome page

&AtClient
Procedure UpdateSourceOnChange(Item)
	BeforePageOpen();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// InternetConnection page

&AtClient
Procedure LabelGoToEventLogMonitorClick(Item)
	OpenForm("DataProcessor.EventLogMonitor.Form", New Structure("User", UserName()));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ConnectionToSite page

&AtClient
Procedure LabelInformationAboutObtainingAccessClick(Item)
	
	GotoURL(
		ConfigurationUpdateClient.GetUpdateParameters().InfoAboutObtainingAccessToUserSitePageAddress);
		
EndProcedure

&AtClient
Procedure LabelHowToSubscribeForITSClick(Item)
	ConfigurationUpdateClient.OpenWebPage("http://1c-dn.com/forum/?section=how");
EndProcedure

&AtClient
Procedure LabelOpenEventLogMonitorClick(Item)
	
	ApplicationsList = New Array;
	ApplicationsList.Add("COMConnection");
	ApplicationsList.Add("Designer");
	ApplicationsList.Add("1CV8");
	ApplicationsList.Add("1CV8C");
	
	EventLogMonitorFilter = New Structure;
	EventLogMonitorFilter.Insert("User", UserName());
	EventLogMonitorFilter.Insert("ApplicationName", ApplicationsList);
	
	OpenForm("DataProcessor.EventLogMonitor.Form", EventLogMonitorFilter);
	
EndProcedure

&AtClient
Procedure LabelMoreAboutTTINavigationRefDataProcessor(Item, URL, StandardProcessing)
	StandardProcessing = False;
	ConfigurationUpdateClient.OpenWebPage("http://1c-dn.com/forum/");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// UpdateFile page

&AtClient
Procedure RadioButtonNeedUpdateFileOnChange(Item)
	BeforePageOpen();
EndProcedure

&AtClient
Procedure FieldUpdateFileStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	Dialog				= New FileDialog(FileDialogMode.Open);
	Dialog.Directory		= ConfigurationUpdateClient.GetFileDir(Object.UpdateFileName);
	Dialog.CheckFileExist = True;
	Dialog.Filter		= NStr("en='All the files of supply (*.cf*;*.cfu)|*.cf*;*.cfu|Files of the configuration supply (*.cf)|*.cf|Files of the configuration update supply(*.cfu)|*.cfu';ru='Все файлы поставки (*.cf*;*.cfu)|*.cf*;*.cfu|Файлы поставки конфигурации (*.cf)|*.cf|Файлы поставки обновления конфигурации(*.cfu)|*.cfu'");
	Dialog.Title	= NStr("en='Choice of delivery update configuration';ru='Выбор поставки обновления конфигурации'");
	
	If Dialog.Choose() Then
		Object.UpdateFileName = Dialog.FullFileName;
	EndIf;
EndProcedure

&AtClient
Procedure DecorationUpdatePlatformNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("InstructionForNextEdition", True);
	OpenForm("DataProcessor.NotRecommendedPlatformVersion.Form.PlatformUpdateOrder", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AvailableUpdate page

&AtClient
Procedure DecorationUpdateOrderNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	DisplayUpdateOrder();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// UpdateModeSelectionFile page

&AtClient
Procedure LabelActionListClick(Item)
	FormParameters = New Structure;
	FormParameters.Insert("NoticeOfClosure", True);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm", , ThisObject);
EndProcedure

&AtClient
Procedure LabelActionList1Click(Item)
	FormParameters = New Structure;
	FormParameters.Insert("NoticeOfClosure", True);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm", , ThisObject);
EndProcedure

&AtClient
Procedure LabelActionList3Click(Item)
	FormParameters = New Structure;
	FormParameters.Insert("NoticeOfClosure", True);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm", , ThisObject);
EndProcedure

&AtClient
Procedure LabelBackupCopyClick(Item)
	FormParameters = New Structure;
	FormParameters.Insert("CreateBackup",           Object.CreateBackup);
	FormParameters.Insert("InfobaseBackupDirectoryName",       Object.InfobaseBackupDirectoryName);
	FormParameters.Insert("RestoreInfobase", Object.RestoreInfobase);
	OpenForm("DataProcessor.ConfigurationUpdate.Form.BackupSetup", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure LabelUpdateOrderFileNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	DisplayUpdateOrder();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// UpdateModeSelectionServer page

&AtClient
Procedure RadioButtonUpdatesOnChange(Item)
	BeforePageOpen();
EndProcedure

&AtClient
Procedure SendReportToEMailOnChange(Item)
	BeforePageOpen();
EndProcedure

&AtClient
Procedure LabelUpdateOrderServerNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	DisplayUpdateOrder();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ButtonBackClick(Command)
	
	ToWorkClickButtonsBack();
	
EndProcedure

&AtClient
Procedure ButtonNextClick(Command)
	FlagCompleteJobs = False;
	ProcessPressOfButtonNext(FlagCompleteJobs);
	If FlagCompleteJobs Then
		ConfigurationUpdateClientOverridable.BeforeExit();
		ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
		Exit(False);
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure ConfigureProxyServerParameters(Command)
	OpenForm("CommonForm.ProxyServerParameters", New Structure("ProxySettingAtClient", True), ThisObject);
EndProcedure

&AtClient
Procedure NewInVersion(Command)
	
	If Not IsBlankString(FileNameInformationAboutUpdate) Then
		ConfigurationUpdateClient.OpenWebPage(FileNameInformationAboutUpdate);
	Else
		ShowMessageBox(, NStr("en='Information about the update is missing.';ru='Информация об обновлении отсутствует.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Check active connections with the infobase.
//
// Returns:
//  Boolean       - True if there
//                 is a connection, False if there is no connection.
&AtServerNoContext
Function ActiveConnectionsExist(MessagesForEventLogMonitor = Undefined)
	// Write accumulated ELM events.
	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
	Return InfobaseConnections.InfobaseSessionCount(False, False) > 1;
EndFunction

&AtServer
Function GetTextsOfTemplates(TemplateNames, ParametersStructure, MessagesForEventLogMonitor)
	// Write accumulated ELM events.
	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
	Result = New Array();
	Result.Add(GetScriptText(ParametersStructure));

	TemplateNamesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TemplateNames);
	For Each TemplateName IN TemplateNamesArray Do
		Result.Add(DataProcessors.ConfigurationUpdate.GetTemplate(TemplateName).GetText());
	EndDo;
	Return Result;
EndFunction

&AtServer
Function GetScriptText(ParametersStructure)
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.ConfigurationUpdate.GetTemplate("TemplateOfConfigurationUpdateFile");
	
	Script = ScriptTemplate.GetArea("ParameterArea");
	Script.DeleteLine(1);
	Script.DeleteLine(Script.LineCount());
	
	Text = ScriptTemplate.GetArea("AreaUpdateConfiguration");
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount());
	
	Return InsertScriptParameters(Script.GetText(), ParametersStructure) + Text.GetText();
	
EndFunction

&AtServer
Function InsertScriptParameters(Val Text, Val ParametersStructure)
	
	Result = Text;
	
	If Object.CreateBackup = 2 Then
		Object.RestoreInfobase = True;
	ElsIf Object.CreateBackup = 0 Then
		Object.RestoreInfobase = False;
	EndIf;
	
	FileNamesUpdate = "";
	For Each Update IN Object.AvailableUpdates Do
		FileNamesUpdate = FileNamesUpdate + DoFormat(Update.PathToLocalUpdateFile) + ",";
	EndDo;
	If StrLen(FileNamesUpdate) > 0 Then
		FileNamesUpdate = Left(FileNamesUpdate, StrLen(FileNamesUpdate) - 1);
	EndIf;
	FileNamesUpdate = "[" + FileNamesUpdate + "]";
	
	InfobaseConnectionString = ParametersStructure.ScriptParameters.InfobaseConnectionString +
											ParametersStructure.ScriptParameters.ConnectionString;
	
	If Right(InfobaseConnectionString, 1) = ";" Then
		InfobaseConnectionString = Left(InfobaseConnectionString, StrLen(InfobaseConnectionString) - 1);
	EndIf;

	NameOfExecutableDesignerFile = ParametersStructure.BinDir + ParametersStructure.NameOfExecutableDesignerFile;
	NameOfExecutableFileOfClient       = ParametersStructure.BinDir + ParametersStructure.NameOfExecutableFileOfClient;
	
	// Define a path to infobase.
	FileModeFlag = Undefined;
	InformationBasePath = InfobaseConnectionsClientServer.InformationBasePath(FileModeFlag, ParametersStructure.AdministrationParameters.ClusterPort);
	
	ParameterOfPathToInformationBase = ?(FileModeFlag, "/F", "/S") + InformationBasePath; 
	InfobasePathString	= ?(FileModeFlag, InformationBasePath, "");
	BlockInfobaseConnections = Not ParametersStructure.FileInfobase OR SimulationModeOfClientServerIB();
	
	Result = StrReplace(Result, "[UpdateFilesNames]"				, FileNamesUpdate);
	Result = StrReplace(Result, "[ConfiguratorApplicationFileName]"	, DoFormat(NameOfExecutableDesignerFile));
	Result = StrReplace(Result, "[ClientApplicationFileName]"			, DoFormat(NameOfExecutableFileOfClient));
	Result = StrReplace(Result, "[PathToInfobaseParameter]"		, DoFormat(ParameterOfPathToInformationBase));
	Result = StrReplace(Result, "[RowPathToInfobaseFile]"	, DoFormat(ConfigurationUpdateClientServer.AddFinalPathSeparator(StrReplace(InfobasePathString, """", "")) + "1Cv8.1CD"));
	Result = StrReplace(Result, "[InfobaseConnectionRow]"	, DoFormat(InfobaseConnectionString));
	Result = StrReplace(Result, "[EventLogMonitorEvent]"			, DoFormat(ParametersStructure.EventLogMonitorEvent));
	Result = StrReplace(Result, "[EmailAddress]"				, DoFormat(?(Object.UpdateMode = 2 AND Object.SendReportToEMail, Object.EmailAddress, "")));
	Result = StrReplace(Result, "[UpdateAdministratorName]"			, DoFormat(UserName()));
	Result = StrReplace(Result, "[CreateBackup]"				, ?(FileModeFlag AND Object.CreateBackup <> 0, "true", "false"));
	Result = StrReplace(Result, "[BackupDirectory]"				, DoFormat(?(Object.CreateBackup = 2, ConfigurationUpdateClientServer.AddFinalPathSeparator(Object.InfobaseBackupDirectoryName), "")));
	Result = StrReplace(Result, "[RestoreInfobase]"	, ?(Object.RestoreInfobase, "true", "false"));
	Result = StrReplace(Result, "[LockIBConnection]"				, ?(BlockInfobaseConnections, "true", "false"));
	Result = StrReplace(Result, "[COMConnectorName]"					, DoFormat(ParametersStructure.COMConnectorName));
	Result = StrReplace(Result, "[UseCOMConnector]"			, ?(ParametersStructure.UseCOMConnector, "false", "true"));
	Result = StrReplace(Result, "[SessionStartAfterUpdate]"			, ?(Parameters.CompletingOfWorkSystem, "false", "true"));
	Result = StrReplace(Result, "[CompressIBTables]"				, ?(PerformIBTableCompression(), "true", "false"));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function DoFormat(Val Text)
	
	Text = StrReplace(Text, "\", "\\");
	Text = StrReplace(Text, """", "\""");
	Text = StrReplace(Text, "'", "\'");
	
	Return "'" + Text + "'";
	
EndFunction

&AtServerNoContext
Procedure ConfigurationUpdatesTableNewRow(TableConfigurationUpdates, Update)
	
	NewRow = TableConfigurationUpdates.Add();
	
	FillPropertyValues(NewRow, Update);
	VersionNumber = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Update.Version, ".");
	NewRow.Version1Digit = Number(VersionNumber[0]);
	NewRow.Version2Digit = Number(VersionNumber[1]);
	NewRow.Version3Digit = Number(VersionNumber[2]);
	NewRow.Version4Digit = Number(VersionNumber[3]);
	
	FilePath = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(StrReplace(Update.PathToUpdateFile, "\", "/"), "/");
	If FilePath.Count() > 0 Then
    	NewRow.UpdateFile = FilePath[FilePath.Count() - 1];
	EndIf;
	
EndProcedure

// Receive the list of all incremental updates using the layout list which sequential setting updates the VersionFrom version to VersionBefore version.
//
// Parameters:
//  VersionFrom    - String - initial version.
//  VersionBefore  - String - the last version to which
// 					          the configuration is updated from the source one.
//
// Returns:
//   Array   - ValueTable string array.
&AtServer
Procedure GetAvailableUpdatesInInterval(Val VersionFrom, Val VersionBefore, FileURLTempStorage, 
	MessagesForEventLogMonitor) 

	// Write accumulated ELM events.
	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
	TableUpdates = Undefined;
	RunImportOfListOfUpdates(FileURLTempStorage, TableUpdates);
	
	If TableUpdates = Undefined Then // errors at file reading
		Return;
	EndIf;
	
	TableConfigurationUpdates = Object.AvailableUpdates.Unload();
	TableConfigurationUpdates.Clear();
	
	TableOfAvailableUpdatesConfiguration = TableConfigurationUpdates.Copy();
	
	For Each Update IN TableUpdates Do
		ConfigurationUpdatesTableNewRow(TableConfigurationUpdates, Update);
	EndDo;
	
	TableConfigurationUpdates.Sort("Version1Digit
		|Desc, Version2Digit
		|Desc, Version3Digit
		|Desc, Version4Digit Desc");
	
	CurrentVersionFrom = VersionFrom;
	While CurrentVersionFrom <> VersionBefore Do
	
		Filter = New Structure("VersionForUpdate", CurrentVersionFrom);
		ArrayOfAvailableUpdates = TableConfigurationUpdates.FindRows(Filter);

		For Each Update IN ArrayOfAvailableUpdates Do
			ConfigurationUpdatesTableNewRow(TableOfAvailableUpdatesConfiguration, Update);
		EndDo;

		TableOfAvailableUpdatesConfiguration.Sort("Version1Digit
			|Desc, Version2Digit
			|Desc, Version3Digit
			|Desc, Version4Digit Desc");
														   
		If TableOfAvailableUpdatesConfiguration.Count() = 0 Then
			Break;
		EndIf;
		
		Filter							= New Structure("Version", TableOfAvailableUpdatesConfiguration[0].Version);
		ArrayAlreadyFoundUpdates	= Object.AvailableUpdates.FindRows(Filter);
		If ArrayAlreadyFoundUpdates.Count() = 0 Then
			// add new update
			NewAvailableUpdate	= Object.AvailableUpdates.Add();
			FillPropertyValues(NewAvailableUpdate, TableOfAvailableUpdatesConfiguration[0]);
		ElsIf IsBlankString(ArrayAlreadyFoundUpdates[0].PathToLocalUpdateFile) Then
			// Update the information in the already found update.
			FillPropertyValues(ArrayAlreadyFoundUpdates[0], TableOfAvailableUpdatesConfiguration[0]);
		EndIf;
		NewCurrentVersionFrom = TableOfAvailableUpdatesConfiguration[0].Version;
		If CurrentVersionFrom = NewCurrentVersionFrom AND NewCurrentVersionFrom <> VersionBefore Then
			TableOfAvailableUpdatesConfiguration.Clear();
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An update to the version of %1 from the current version of %2 is unavailable';ru='Недоступно обновление на версию %1 с текущей версии %2'"), VersionBefore, VersionFrom);
		EndIf;
		CurrentVersionFrom	= NewCurrentVersionFrom;
	
	EndDo;
	
EndProcedure 

// Update list importing from XML file.
&AtServerNoContext
Procedure RunImportOfListOfUpdates(Val ImportFileAddress, TableUpdates = Undefined)
	
	FullPathFileExport = ImportFileAddress;
	If IsTempStorageURL(ImportFileAddress) Then
		FullPathFileExport = StrReplace(GetTempFileName(), ".tmp", ".xml");
		FileData = GetFromTempStorage(ImportFileAddress);
		FileData.Write(FullPathFileExport);
	EndIf;
	
	ErrorInfo = NStr("en='Error when reading an updates list file';ru='Ошибка при чтении файла списка обновлений'") + " " + FullPathFileExport;
	If Not FileExistsAtServer(FullPathFileExport) Then
		Raise ErrorInfo;
	EndIf;
	
	TableUpdates = New ValueTable;
	// Main columns
	TableUpdates.Columns.Add("Configuration"			, CommonUse.TypeDescriptionRow(0));
	TableUpdates.Columns.Add("Vendor"				, CommonUse.TypeDescriptionRow(0));
	TableUpdates.Columns.Add("Version"					, CommonUse.TypeDescriptionRow(0));
	TableUpdates.Columns.Add("VersionForUpdate"	, CommonUse.TypeDescriptionRow(0));
	TableUpdates.Columns.Add("PathToUpdateFile"	, CommonUse.TypeDescriptionRow(0));
	TableUpdates.Columns.Add("ITSDiskNumber"			, CommonUse.TypeDescriptionRow(0));
	TableUpdates.Columns.Add("PlatformVersion"		, CommonUse.TypeDescriptionRow(0));
	TableUpdates.Columns.Add("UpdateFileSize"	, CommonUse.TypeDescriptionNumber(15, 0));
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FullPathFileExport);
	XMLReader.Read();  
	
	// File generation date.
	XMLReader.Read();
	XMLReader.Read();
	GeneratingDate = XMLReader.Value;
	XMLReader.Read();
	
	// Read the Update item beginning or the UpdateList item end.
	While XMLReader.Read() Do
		
		If XMLReader.Name = "v8u:updateList" Then
			Break;
		EndIf;
		Vendor				= "";
		Version					= "";
		PathToUpdateFile	= "";
		ITSDiskNumber			= "";
		UpdateFileSize	= 0;
		Configuration			= StringFunctionsClientServer.ContractDoubleQuotationMarks(TrimAll(XMLReader.GetAttribute("configuration")));
		PlatformVersion = Undefined;
		
		// Read update item content.
		VersionsArrayForUpdate = New Array;
		While XMLReader.Read() Do
			If XMLReader.Name = "v8u:update" Then
				Break;
			EndIf;
			If XMLReader.Name = "v8u:vendor" Then
				XMLReader.Read();
				Vendor = StringFunctionsClientServer.ContractDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:version" Then
				PlatformVersion = XMLReader.GetAttribute("platform");
				XMLReader.Read();
				Version = XMLReader.Value;
			ElsIf XMLReader.Name = "v8u:file" Then
				XMLReader.Read();
				PathToUpdateFile = StringFunctionsClientServer.ContractDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:size" Then
				XMLReader.Read();
				UpdateFileSize = StringFunctionsClientServer.ContractDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:its" Then
				XMLReader.Read();
				ITSDiskNumber = StringFunctionsClientServer.ContractDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:target" Then
				XMLReader.Read();
				VersionsArrayForUpdate.Add(XMLReader.Value);
			EndIf;
			
			XMLReader.Read();
		EndDo;
		
		// Create update table.
		For Each VersionForUpdate IN VersionsArrayForUpdate Do
			
			NewRow = TableUpdates.Add();
			NewRow.Configuration			= Configuration;
			NewRow.Vendor				= Vendor;
			NewRow.Version					= Version;
			NewRow.VersionForUpdate		= VersionForUpdate;
			NewRow.PathToUpdateFile	= PathToUpdateFile;
			NewRow.ITSDiskNumber			= ITSDiskNumber;
			NewRow.UpdateFileSize	= UpdateFileSize;
			NewRow.PlatformVersion			= PlatformVersion;

		EndDo;
		
	EndDo;
	XMLReader.Close();
	
	If TableUpdates = Undefined Then // errors at file reading
		Raise NStr("en='Error when reading the file';ru='Ошибка при чтении файла'") + " " + FullPathFileExport;
   	EndIf;
	
EndProcedure

&AtServerNoContext
Function FileExistsAtServer(Val PathToFile)
	File = New File(PathToFile);
	Return File.Exist();
EndFunction

&AtServerNoContext
Function ScriptDebugMode()
	Result = False;
	StructureSettings = CommonUse.CommonSettingsStorageImport(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions");
	If StructureSettings <> Undefined Then 
		StructureSettings.Property("ScriptDebugMode", Result);
	EndIf;
	Return Result = True;
EndFunction	

&AtServerNoContext
Function SimulationModeOfClientServerIB()
	Result = False;
	StructureSettings = CommonUse.CommonSettingsStorageImport(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions");
	If StructureSettings <> Undefined Then 
		StructureSettings.Property("SimulationModeOfClientServerIB", Result);
	EndIf;
	Return Result = True;
EndFunction	

&AtClient
Procedure SaveSettingsOfConfigurationUpdate()
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	
	ParameterName = "StandardSubsystems.ConfigurationUpdateOptions";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	Settings = ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(ApplicationParameters[ParameterName]);
	
	Settings.UpdateServerUserCode = Object.UpdateServerUserCode;
	Settings.UpdatesServerPassword = ?(Object.SaveUpdatesServerPassword, Object.UpdatesServerPassword, "");
	Settings.SaveUpdatesServerPassword = Object.SaveUpdatesServerPassword;
	
	Settings.CheckUpdateExistsOnStart = Object.CheckUpdateExistsOnStart;
	Settings.ScheduleOfUpdateExistsCheck = CommonUseClientServer.ScheduleIntoStructure(Object.ScheduleOfUpdateExistsCheck);
	Settings.UpdateSource = Object.UpdateSource;
	Settings.UpdateMode = Object.UpdateMode;
	Settings.UpdateDateTime = Object.UpdateDateTime;
	Settings.SendReportToEMail = Object.SendReportToEMail;
	Settings.EmailAddress = Object.EmailAddress;
	Settings.SchedulerTaskCode = Object.SchedulerTaskCode;
	Settings.SecondStart = Object.SecondStart;
	Settings.UpdateFileName = Object.UpdateFileName;
	Settings.NeedUpdateFile = Object.NeedUpdateFile;
	
	Settings.CreateBackup = Object.CreateBackup;
	Settings.RestoreInfobase = Object.RestoreInfobase;
	Settings.InfobaseBackupDirectoryName = Object.InfobaseBackupDirectoryName;
	
	Settings.ServerAddressForVerificationOfUpdateAvailability = ClientWorkParameters.UpdateSettings.ServerAddressForVerificationOfUpdateAvailability;
	Settings.UpdatesDirectory = ClientWorkParameters.UpdateSettings.UpdatesDirectory;
	Settings.ConfigurationShortName = ClientWorkParameters.UpdateSettings.ConfigurationShortName;
	Settings.AddressOfResourceForVerificationOfUpdateAvailability = ClientWorkParameters.UpdateSettings.AddressOfResourceForVerificationOfUpdateAvailability;
	
	ConfigurationUpdateServerCall.WriteStructureOfAssistantSettings(
		ApplicationParameters["StandardSubsystems.ConfigurationUpdateOptions"]);
	
EndProcedure

&AtClient
Procedure RestoreSettingsUpdateConfigurations()
	
	Object.RestoreInfobase = True;
	
	// Restoration settings
	ParameterName = "StandardSubsystems.ConfigurationUpdateOptions";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, ConfigurationUpdateServerCall.GetSettingsStructureOfAssistant());
		ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(ApplicationParameters[ParameterName]);
	EndIf;
	FillPropertyValues(Object, ApplicationParameters[ParameterName]);
	
	If AuthenticationParameters <> Undefined
		AND Not IsBlankString(AuthenticationParameters.Login)
		AND Not IsBlankString(AuthenticationParameters.Password) Then
		
		Object.UpdateServerUserCode = AuthenticationParameters.Login;
		Object.UpdatesServerPassword = AuthenticationParameters.Password;
		
	EndIf;
	
	Object.ScheduleOfUpdateExistsCheck = CommonUseClientServer.StructureIntoSchedule(Object.ScheduleOfUpdateExistsCheck);
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	If ClientWorkParameters.FileInfobase AND Object.UpdateMode > 1 Then
		Object.UpdateMode = 0;
	EndIf;
	
	If ConfigurationChanged Then
		UpdateParameters = ConfigurationUpdateClient.GetAvailableConfigurationUpdate();
		UpdateParameters.UpdateSource = 2;  // Local or network directory.
		UpdateParameters.NeedUpdateFile = False;
		UpdateParameters.FlagOfAutoTransitionToPageWithUpdate = True;
	EndIf;
	
	If Parameters.CompletingOfWorkSystem Then
		Object.UpdateMode = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforePageOpen(NewCurrentPage = Undefined)
	
	ParameterName = "StandardSubsystems.MessagesForEventLogMonitor";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	Pages = Items.AssistantPages.ChildItems;
	If NewCurrentPage = Undefined Then
		NewCurrentPage = Items.AssistantPages.CurrentPage;
	EndIf;
	
	ButtonBackAvailability		= True;
	EnabledButtonsNextStep		= True;
	EnabledButtonsClose	= True;
	NextButtonFunction			= True; // True = "GoToNext", False = "Done"
	
	If NewCurrentPage = Pages.Welcome Then
		ButtonBackAvailability = False;
	ElsIf NewCurrentPage = Pages.ConnectionToSite Then
		
		ErrorsPaneVisibleConnection = ? (ValueIsFilled(Object.UpdateServerUserCode) 
			OR ValueIsFilled(Object.UpdatesServerPassword), True, False);
														
		Items.PanelErrorConnection.Visible = ErrorsPaneVisibleConnection;
		Items.PanelEventLogMonitor.Visible = ErrorsPaneVisibleConnection;
		If StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
			Items.AccessGroupOnSite.CurrentPage = Items.AccessGroupOnSite.ChildItems.Basic;
		EndIf;
		
		If Not IsBlankString(Object.TechnicalErrorInfo) Then
			Object.TechnicalErrorInfo = NStr("en='Technical information about the error:';ru='Техническая информация об ошибке:'") + Chars.LF + Object.TechnicalErrorInfo;
		EndIf;
		
	ElsIf NewCurrentPage = Pages.AvailableUpdate Then
		
		AvailableUpdateStructure = GetAvailableUpdate(True);
		If AvailableUpdateStructure <> Undefined Then
			Items.NewInVersion.Visible = Not IsBlankString(FileNameInformationAboutUpdate);
			Items.LabelAvailableUpdate.Title = AvailableUpdateStructure.Version;
			Items.LabelSizeUpdates.Title = AvailableUpdateStructure.SizeUpdate;
			Items.DecorationUpdateOrder.Visible = Not IsBlankString(FileNameOrderUpdate);
			PlatformUpdateIsNeeded = PlatformUpdateIsNeeded(AvailableUpdateStructure.PlatformVersion);
			If AvailableUpdateForNextEdition Or PlatformUpdateIsNeeded Then
				
				PlatformVersion = ?(PlatformUpdateIsNeeded, AvailableUpdateStructure.PlatformVersion,
					ConfigurationUpdateClient.PlatformNextEdition());
				CaptionPattern = NStr("en='To update this version 1C:Enterprise platform
		|higher than <b>%1<b> version is required. It is required to <a href = ""HowToUpdatePlatform>update to a new platform version</a>, after that you can install this update.';ru='Для обновления на эту версию требуется платформа 1С:Предприятие
		|не ниже версии <b>%1</b>. Необходимо <a href = ""КакОбновитьПлатформу"">перейти на новую версию платформы</a>,
		|после чего можно будет установить это обновление.'");
				TitleString = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, AvailableUpdateStructure.PlatformVersion);
				Items.DecorationUpdatePlatform.Title = StringFunctionsClientServer.FormattedString(TitleString);
				
				Items.DecorationUpdatePlatform.Visible = True;
				EnabledButtonsNextStep = False;
				EnabledButtonsClose = True;
			Else
				Items.DecorationUpdatePlatform.Visible = False;
				Items.DecorationUpdateOrder.Height = 2;
			EndIf;
			
			If IsBlankString(FileNameOrderUpdate) AND Not (AvailableUpdateForNextEdition Or PlatformUpdateIsNeeded) Then
				Items.GroupAdditionalInformation.Visible = False;
			EndIf;
			
		EndIf;
		
	ElsIf NewCurrentPage = Pages.UpdatesNotDetected Then
		
		AvailableUpdateStructure	= GetAvailableUpdate();
		NextButtonFunction										= False;
		EnabledButtonsNextStep									= False;
		Items.LabelDetailsCurrentConfiguration.Title	= StandardSubsystemsClientReUse.ClientWorkParameters().ConfigurationSynonym;
		Items.LabelVersionCurrentConfiguration.Title		= StandardSubsystemsClientReUse.ClientWorkParameters().ConfigurationVersion;
		Items.InscriptionVersionForUpdate.Title			= ?(TypeOf(AvailableUpdateStructure) = Type("Structure"), NStr("en='Available version for update -';ru='Доступная версия для обновления -'") + " " + AvailableUpdateStructure.Version, "");
		Items.InscriptionVersionForUpdate.Visible			= Not IsBlankString(Items.InscriptionVersionForUpdate.Title);
		
		If CommonUseClientServer.CompareVersions(StandardSubsystemsClientReUse.ClientWorkParameters().ConfigurationVersion,
			LastConfigurationVersion) >= 0
			Or AvailableUpdateStructure <> Undefined
			Or (Object.UpdateSource = 0 AND Object.AvailableUpdates.Count() = 0) Then // this is the last version.
			
			Items.PanelInformationAboutUpdate.CurrentPage = Items.PanelInformationAboutUpdate.ChildItems.RefreshEnabledNotNeeded;
			Items.GroupUpdateIsNotDetected.Title = NStr("en='Update is not required';ru='Обновление не требуется'");
		ElsIf StandardSubsystemsClientReUse.ClientWorkParameters().MasterNode <> Undefined Then
			Items.PanelInformationAboutUpdate.CurrentPage = Items.UpdatePerformedAtMainNode;
			Items.GroupUpdateIsNotDetected.Title = NStr("en='Update is not required';ru='Обновление не требуется'");
		Else 
			Items.PanelInformationAboutUpdate.CurrentPage = Items.PanelInformationAboutUpdate.ChildItems.RefreshEnabledIsNotFound;
			Items.GroupUpdateIsNotDetected.Title = NStr("en='Update of configuration is not found';ru='Обновления конфигурации не обнаружено'");
		EndIf;
		
		If Not StandardSubsystemsClientReUse.ClientWorkParameters().IsMasterNode Then
			ButtonBackAvailability = False;
		EndIf;
		
	ElsIf NewCurrentPage = Pages.LongOperation Then
		
		EnabledButtonsNextStep = False;
		ButtonBackAvailability = False;
		EnabledButtonsClose = False;
		
	ElsIf NewCurrentPage = Pages.CaseUpdateFile Then
		
		NextButtonFunction = (Object.UpdateMode = 0);// If it is NOT updated now, then Finish.
		
		Items.UpdateOrderFile.Visible = Not IsBlankString(FileNameOrderUpdate);
		
		ConnectionsInfo = InfobaseConnectionsServerCall.ConnectionInformation(False, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
		Items.GroupConnections.Visible = ?(ConnectionsInfo.ActiveConnectionsExist, True, False);
			
		If ConnectionsInfo.ActiveConnectionsExist Then
			AllPages = Items.PanelActiveUsers.ChildItems;
			EnabledButtonsNextStep	= True;
			If ConnectionsInfo.COMConnectionsExist Then
				Items.PanelActiveUsers.CurrentPage = AllPages.ActiveConnection;
			ElsIf ConnectionsInfo.DesignerConnectionExists Then
				Items.PanelActiveUsers.CurrentPage = AllPages.ConnectionConfigurator;
			Else
				Items.PanelActiveUsers.CurrentPage = AllPages.ActiveUsers;
			EndIf;
		EndIf;
		
		Items.LabelBackupFile.Title = LabelTextInfobaseBackup();
		
		If Not StandardSubsystemsClientReUse.ClientWorkParameters().IsMasterNode Then
			ButtonBackAvailability = False;
		EndIf;
	ElsIf NewCurrentPage = Pages.UpdateModeChoiceServer Then

		If Object.SchedulerTaskCode = 0 AND Not UpdateDateTimeIsSet Then
			Object.UpdateDateTime		= ReturnDate(ConfigurationUpdateClientServer.AddDays(
				BegOfDay(CommonUseClient.SessionDate()), 1), Object.UpdateDateTime);
			UpdateDateTimeIsSet	= True;
		EndIf; 
		
		NextButtonFunction = (Object.UpdateMode = 0);// If it is NOT updated now, then Finish.
		
		Items.UpdateOrderServer.Visible = Not IsBlankString(FileNameOrderUpdate);
		
		PanelPagesInformationReboot1						= Items.PagesInformationReboot1.ChildItems;
		Items.PagesInformationReboot1.CurrentPage	= ?(Object.UpdateMode = 0,
			PanelPagesInformationReboot1.PageRebootNow1,
			PanelPagesInformationReboot1.ScheduledRebootPage);
		
		ConnectionsInfo = InfobaseConnectionsServerCall.ConnectionInformation(False, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
		AvailabilityOfConnections	= ConnectionsInfo.ActiveConnectionsExist AND NextButtonFunction; 
		Items.ConnectionsGroup1.Visible = AvailabilityOfConnections;
		If AvailabilityOfConnections Then
			AllPages = Items.PanelActiveUsers1.ChildItems;
			Items.PanelActiveUsers1.CurrentPage = ? (ConnectionsInfo.COMConnectionsExist, 
				AllPages.ActiveConnection1, AllPages.ActiveUsers1);
		EndIf;
			
		Items.FieldUpdateDateTime.Enabled = (Object.UpdateMode = 2);
		Items.EmailAddress.Enabled	= Object.SendReportToEMail;
		
		If Not StandardSubsystemsClientReUse.ClientWorkParameters().IsMasterNode Then
			ButtonBackAvailability = False;
		EndIf;
	ElsIf NewCurrentPage = Pages.SuccessfulRefresh Then
		
		GetToKnowAdditionalInstructions = Not IsBlankString(FileNameOrderUpdate);
		ShowNewInVersion = Not GetToKnowAdditionalInstructions;
		Items.GetToKnowAdditionalInstructions.Visible = GetToKnowAdditionalInstructions;
		NextButtonFunction = False;
		ButtonBackAvailability = False;
		EnabledButtonsClose = False;
		
	ElsIf NewCurrentPage = Pages.FailureRefresh Then
		
		NextButtonFunction = False;
		EnabledButtonsClose = False;
		
	ElsIf NewCurrentPage = Pages.UpdateFile Then
		
		If Object.NeedUpdateFile = 0 Then
			If ConfigurationChanged Then
				Items.PagesConfigurationChangedInscriptions.CurrentPage = Items.PagesConfigurationChangedInscriptions.ChildItems.HasChanges;
			Else
				Items.PagesConfigurationChangedInscriptions.CurrentPage = Items.PagesConfigurationChangedInscriptions.ChildItems.NoneChanges;
				EnabledButtonsNextStep = False;
			EndIf;
		EndIf;
		Items.PanelUpdateFromMainConfiguration.Visible	= Object.NeedUpdateFile = 0;
		Items.FieldUpdateFile.Enabled						= Object.NeedUpdateFile = 1;
		Items.FieldUpdateFile.AutoMarkIncomplete		= Object.NeedUpdateFile = 1;
		
	EndIf;
	
	If ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"].Count() > 0 Then
		// It is necessary to record the log on pages with errors.
		EventLogMonitorServerCall.WriteEventsToEventLogMonitor(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	EndIf;
	
	ButtonNext		= Items.ButtonNext;
	ButtonBack		= Items.ButtonBack;
	CloseButton	= Items.CloseButton;
	ButtonBack.Enabled		= ButtonBackAvailability;
	ButtonNext.Enabled		= EnabledButtonsNextStep;
	CloseButton.Enabled	= EnabledButtonsClose;
	If EnabledButtonsNextStep Then
		If Not ButtonNext.DefaultButton Then
			ButtonNext.DefaultButton = True;
		EndIf;
	ElsIf EnabledButtonsClose Then
		If Not CloseButton.DefaultButton Then
			CloseButton.DefaultButton = True;
		EndIf;
	EndIf;
	
	ButtonNext.Title = ?(NextButtonFunction, NStr("en='Next >';ru='Далее  >'"), NStr("en='Done';ru='Готово'"));
	
	If NewCurrentPage = Pages.LongOperation Then
		AttachIdleHandler("RunUpdateObtaining", 1, True);
	EndIf;

EndProcedure

&AtClient
Function RestoreResultsOfPreviousStart(Cancel = False)
	
	Pages	= Items.AssistantPages.ChildItems;
	RestorationOfPreLaunch = True;
	PageName	= ProcessPageWelcome(False);
	Processed	= 	PageName = Pages.AvailableUpdate.Name Or
				 	PageName = Pages.UpdateModeChoiceServer.Name Or
				 	PageName = Pages.CaseUpdateFile.Name;

	RestorationOfPreLaunch = False;
	If Not Processed Then
		Cancel = True;
		Return PageName;
	EndIf;

	If PageName = Pages.AvailableUpdate.Name Then
		FileListForObtaining = CreateFileListForObtaining();
		If CheckUpdateFilesReceived() Then
			NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
			
			EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Information",
				NStr("en='It is discovered that the update configuration files have already been received and saved locally.';ru='Обнаружено, что файлы обновления конфигурации уже были получены и сохранены локально.'"));
				
			GoToChoiceOfUpdateMode();
			Return Undefined;
		EndIf;
	EndIf;
	
	Return PageName;
	
EndFunction

&AtClient
Function ProcessPageWelcome(OutputMessages = True)
	ClearAvailableUpdates = True;
	If Object.UpdateSource = 0 Then
		Return CheckUpdateInternet(OutputMessages);
	ElsIf Object.UpdateSource = 2 Then
		Return CheckUpdateFile(OutputMessages);
	EndIf;
	Return Undefined;
EndFunction

&AtClient
Function ProcessPageConnectionToInternet(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Object.TechnicalErrorInfo = "";
	If FileListForObtaining.Count() > 0 Then
		Return Pages.LongActions.Name;
	ElsIf Object.AvailableUpdates.Count() > 0 Then
		Return Pages.AvailableUpdate.Name;
	EndIf;
		
	Return ?(Object.AvailableUpdates.Count() = 0, CheckUpdateInternet(OutputMessages), Pages.ConnectionToSite.Name);
EndFunction

&AtClient
Function ProcessPageConnectionToSite(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Object.TechnicalErrorInfo = "";
	If Not ValueIsFilled(Object.UpdateServerUserCode) Then
		If OutputMessages Then
			ShowMessageBox(, NStr("en='Specify the user code for update.';ru='Укажите код пользователя для обновления.'"));
		EndIf;
		CurrentItem = Items.UpdateServerUserCode;
		Return Pages.ConnectionToSite.Name;
	EndIf;
	
	If Not ValueIsFilled(Object.UpdatesServerPassword) Then
		If OutputMessages Then
			ShowMessageBox(, NStr("en='Specify the user password for updating.';ru='Укажите пароль пользователя для обновления.'"));
		EndIf;
		CurrentItem = Items.UpdatesServerPassword;
		Return Pages.ConnectionToSite.Name;
	EndIf;
	
	If FileListForObtaining.Count() > 0 Then
		Return Pages.LongActions.Name;
	ElsIf Object.AvailableUpdates.Count() > 0 Then
		Return Pages.AvailableUpdate.Name;
	EndIf;
	
	Return CheckUpdateInternet(OutputMessages);
EndFunction

&AtClient
Function ProcessPageLongOperation(OutputMessages = True)
	Return ResultGetFiles;
EndFunction

&AtClient
Function ProcessPageChoiceUpdateMode(OutputMessages = True, FlagCompleteJobs = False)
	CurrentPage = Items.AssistantPages.CurrentPage;
	
	FileInfobase = StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase;
	ExecuteUpdate = False;
	
	If FileInfobase AND Not SimulationModeOfClientServerIB() AND Object.CreateBackup = 2 Then
		
		File = New File(Object.InfobaseBackupDirectoryName);
		If Not File.Exist() Or Not File.IsDirectory() Then
			ShowMessageBox(, NStr("en='Specify existing directory for saving IB backup file.';ru='Укажите существующий каталог для сохранения резервной копии ИБ.'"));
		EndIf;
		
		Return CurrentPage.Name;
		
	EndIf;
	
	If Object.UpdateMode = 0 Then   // Update now
		If FileInfobase AND Not SimulationModeOfClientServerIB() Then
			AvailabilityOfConnections = ActiveConnectionsExist(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
			If AvailabilityOfConnections Then
				ShowMessageBox(, NStr("en='It is impossible to continue the configuration update because not all the connections with the infobase have been completed.';ru='Невозможно продолжить обновление конфигурации, так как не завершены все соединения с информационной базой.'"));
				Return CurrentPage.Name;
			EndIf; 
		EndIf;
		ExecuteUpdate		= True;
		FlagCompleteJobs	= True;
		Return CurrentPage.Name;
	ElsIf Object.UpdateMode = 1 Then  // On closing application
		
	ElsIf Object.UpdateMode = 2 Then  // Plan update
		If Not CheckValidUpdateDate(Object.UpdateDateTime, OutputMessages) Then
			CurrentItem = Items.FieldUpdateDateTime;
			Return CurrentPage.Name;
		EndIf;
		If Object.SendReportToEMail Then
			NameNewPages = CheckEMailSettings(CurrentPage.Name, OutputMessages);
			If Not IsBlankString(NameNewPages) Then
				Return NameNewPages;
			EndIf;
		EndIf;
		
		If Not WMIInstalled(OutputMessages) Then
			Return CurrentPage.Name;
		EndIf;
		
		If Not PlanConfigurationChange() Then
			ShowMessageBox(, NStr("en='It is impossible to schedule the configuration update. Error information is saved in the log.';ru='Невозможно запланировать обновление конфигурации. Сведения об ошибке сохранены в журнал регистрации.'"));
			Return CurrentPage.Name;
		EndIf;
		
	Else
		Return CurrentPage.Name;
	EndIf;
	
	ParameterName = "StandardSubsystems.OfferInfobaseUpdateOnSessionExit";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = Object.UpdateMode = 1;
	
	Message = NStr("en='Selected update mode:';ru='Выбран режим обновления:'") + " ";
	If Object.UpdateMode = 0 Then   // Update now
		Message = Message + NStr("en='now';ru='сейчас'");
	ElsIf Object.UpdateMode = 1 Then  // On closing application
		Message = Message + NStr("en='On closing application';ru='При завершении работы'");
	ElsIf Object.UpdateMode = 2 Then  // Plan update
		Message = Message + NStr("en='schedule';ru='график'");
	EndIf;
	Message = Message + ".";
	NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
	EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, 
		"Information", Message);

	Close();
	Return CurrentPage.Name;
	
EndFunction

&AtClient
Procedure ProcessPressOfButtonNext(FlagCompleteJobs = False)
	ClearMessages();
	CurrentPage			= Items.AssistantPages.CurrentPage;
	Pages				= Items.AssistantPages.ChildItems;
	NewCurrentPage	= CurrentPage;
	ButtonNext				= Items.ButtonNext;
	ButtonBack				= Items.ButtonBack;
	CloseButton			= Items.CloseButton;
	
	CurrentPage.Enabled	= False;
	ButtonNext.Enabled		= False;
	ButtonBack.Enabled		= False;
	CloseButton.Enabled	= False;
	
	If CurrentPage = Pages.Welcome Then
		NewPage = ProcessPageWelcome();
		If NewPage = Undefined Then
			Return;
		Else
			NewCurrentPage = Pages[NewPage];
		EndIf;
	ElsIf CurrentPage = Pages.InternetConnection Then
		NewCurrentPage = Pages[ProcessPageConnectionToInternet()];
	ElsIf CurrentPage = Pages.ConnectionToSite Then
		NewCurrentPage = Pages[ProcessPageConnectionToSite()];
	ElsIf CurrentPage = Pages.AvailableUpdate Then
		NewPage = ProcessPageAvailableUpdate();
		If NewPage = Undefined Then
			Return;
		Else
			NewCurrentPage = Pages[NewPage];
		EndIf;
	ElsIf CurrentPage = Pages.UpdatesNotDetected Then
		NewCurrentPage = Pages[ProcessPageUpdateNotDetected()];
	ElsIf CurrentPage = Pages.LongOperation Then
		NewCurrentPage = Pages[ProcessPageLongOperation()];
	ElsIf CurrentPage = Pages.CaseUpdateFile OR
		CurrentPage		= Pages.UpdateModeChoiceServer Then
		NewCurrentPage = Pages[ProcessPageChoiceUpdateMode(, FlagCompleteJobs)];
	ElsIf CurrentPage = Pages.SuccessfulRefresh Then
		NewCurrentPage = Pages[ProcessPageSuccessfulUpdate()];
	ElsIf CurrentPage = Pages.FailureRefresh Then
		NewCurrentPage = Pages[ProcessPageFailedUpdate()];
	ElsIf CurrentPage = Pages.UpdateFile Then
		NewPage = ProcessPageUpdateFile();
		If NewPage = Undefined Then
			Return;
		Else
			NewCurrentPage = Pages[NewPage];
		EndIf;
	EndIf;
	
	Cancel = False;
	
	OnTransitionToAssistantsPage(CurrentPage.Name, NewCurrentPage.Name, Cancel);
	
	CurrentPage.Enabled = True;
	
	// Check that the configuration update is available.
	If Not StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.IsAccessForUpdate
		AND (NewCurrentPage = Pages.ConnectionToSite OR
										NewCurrentPage = Pages.LongOperation OR
										NewCurrentPage = Pages.CaseUpdateFile OR
										NewCurrentPage = Pages.UpdateModeChoiceServer OR
										NewCurrentPage = Pages.UpdateFile) Then
		Cancel						= True;
		ButtonBack.Enabled		= True;
		ButtonNext.Enabled		= True;
		CloseButton.Enabled	= True;
		ShowMessageBox(, NStr("en='Insufficient rights to update the configuration.';ru='Недостаточно прав для выполнения обновления конфигурации.'"));
	EndIf;
	
	If Cancel Then
		ToWorkClickButtonsBack();
	Else
		BeforePageOpen(NewCurrentPage);
		Items.AssistantPages.CurrentPage = NewCurrentPage;
	EndIf;
EndProcedure

&AtClient
Procedure ToWorkClickButtonsBack()
	
	Pages             = Items.AssistantPages.ChildItems;
	CurrentPage      = Items.AssistantPages.CurrentPage;
	NewCurrentPage = CurrentPage;
	
	If CurrentPage = Pages.Welcome Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.InternetConnection Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.ConnectionToSite Then
		NewCurrentPage = Pages.AvailableUpdate;
	ElsIf CurrentPage = Pages.AvailableUpdate Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.UpdatesNotDetected Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.LongOperation Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.CaseUpdateFile OR 
		CurrentPage = Pages.UpdateModeChoiceServer Then
		If Object.UpdateSource = 0 Then // Internet
			NewCurrentPage = Pages.AvailableUpdate;
		Else // file
			NewCurrentPage = Pages.UpdateFile;
		EndIf;
	ElsIf CurrentPage = Pages.SuccessfulRefresh Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.FailureRefresh Then
		NewCurrentPage = Pages.Welcome;
		If Not StandardSubsystemsClientReUse.ClientWorkParameters().IsMasterNode Then
			GoToChoiceOfUpdateMode();
			Return;
		EndIf;
	ElsIf CurrentPage = Pages.UpdateFile Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.AvailableUpdate Then
		NewCurrentPage = Pages.Welcome;
	EndIf;
	
	BeforePageOpen(NewCurrentPage);
	
	Items.AssistantPages.CurrentPage = NewCurrentPage;
	
EndProcedure

&AtClient
Procedure OnTransitionToAssistantsPage(PreviousPage, NextPage, Cancel)
	
	If PreviousPage = "UpdateFile" AND NextPage <> "UpdateFile" Then
		
		Notification = New NotifyDescription("OnTransitionToAssistantPageEnd", ThisObject);
		ConfigurationUpdateClient.CheckSoftwareUpdateLegality(Notification);
		
	EndIf;
	
	ConfigurationUpdateClientOverridable.OnTransitionToAssistantsPage(PreviousPage, NextPage, Cancel);
	
EndProcedure

&AtClient
Procedure OnTransitionToAssistantPageEnd(RefreshReceivedLegally, AdditionalParameters) Export
	
	If RefreshReceivedLegally = False
		Or RefreshReceivedLegally = Undefined Then
		ToWorkClickButtonsBack();
	EndIf;
	
EndProcedure

&AtClient
Function ProcessPageAvailableUpdate(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	Object.TechnicalErrorInfo = "";
	
	If Not StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.IsAccessForUpdate Then
		ShowMessageBox(, NStr("en='Insufficient rights to update the configuration.';ru='Недостаточно прав для выполнения обновления конфигурации.'"));
		Return Pages.AvailableUpdate.Name;
	EndIf;
	
	FileListForObtaining.LoadValues(CreateFileListForObtaining());
	If CheckUpdateFilesReceived() Then
		NameLogEvents  = ConfigurationUpdateClient.EventLogMonitorEvent();
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Information",
			NStr("en='It is discovered that the update configuration files have already been received and saved locally.';ru='Обнаружено, что файлы обновления конфигурации уже были получены и сохранены локально.'"));
		GoToChoiceOfUpdateMode(True);
		Return Undefined;
	EndIf;
	
	Return Pages.LongActions.Name;
	
EndFunction

&AtClient
Function ProcessPageUpdateNotDetected(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Close();
	Return Pages.UpdatesNotDetected.Name;
EndFunction

&AtClient
Function ProcessPageSuccessfulUpdate(OutputMessages = True)
	
	If ShowNewInVersion Then
		OpenForm("CommonForm.SystemChangesDescription", New Structure("ShowOnlyChanges", True));
	EndIf;
	
	If GetToKnowAdditionalInstructions Then
		ConfigurationUpdateClient.OpenWebPage(FileNameOrderUpdate);
	EndIf;
	
	Close();
	Return Items.SuccessfulRefresh.Name;
	
EndFunction

&AtClient
Function ProcessPageFailedUpdate(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Close();
	Return Pages.FailureRefresh.Name;
EndFunction

&AtClient
Function ProcessPageUpdateFile(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	If Object.NeedUpdateFile = 1 Then
		
		If Not ValueIsFilled(Object.UpdateFileName) Then
			If OutputMessages Then
				CommonUseClientServer.MessageToUser(NStr("en='Specify the configuration update delivery file.';ru='Укажите файл поставки обновления конфигурации.'"),,"Object.UpdateFileName");
			EndIf;
			CurrentItem = Items.FieldUpdateFile;
			Return Pages.UpdateFile.Name;
		EndIf;
		
		File = New File(Object.UpdateFileName);
		If Not File.Exist() OR Not File.IsFile() Then
			If OutputMessages Then
				CommonUseClientServer.MessageToUser(NStr("en='Delivery update configuration File not found';ru='Файл поставки обновления конфигурации не найден.'"),,"Object.UpdateFileName");
			EndIf;
			CurrentItem = Items.FieldUpdateFile;
			Return Pages.UpdateFile.Name;
		EndIf;
		
	EndIf;
	
	UpdateFilesDir = ConfigurationUpdateClient.GetUpdateParameters().UpdateFilesDir; 
	If Not IsBlankString(UpdateFilesDir) Then
		Try
			DeleteFiles(UpdateFilesDir, "*");
		Except
			// Ignore the failed attempt of the temporary directory deletion.
		EndTry;
	EndIf;
	GetAvailableUpdateFromFile(?(Object.NeedUpdateFile = 1, Object.UpdateFileName, Undefined),True);
	GoToChoiceOfUpdateMode(True);
	Return Undefined;
	
EndFunction

&AtClient
Function CheckUpdateFilesReceived()
	
	FilesReceivedSuccessfully = True;
	For Each File IN FileListForObtaining Do
		If File.Value.IsRequired AND Not File.Value.Received Then
			FilesReceivedSuccessfully = False;
			Break;
		EndIf;
	EndDo;
	
	If FilesReceivedSuccessfully Then
		FilesReceivedSuccessfully = UnpackUpdateInstallationPackage();
	EndIf;
	
	Return FilesReceivedSuccessfully;
	
EndFunction

&AtClient
Function GetAvailableUpdate(GetUpdateSize = False)
	
	If Object.AvailableUpdates.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	UpdateString = Object.AvailableUpdates[Object.AvailableUpdates.Count()-1];
	
	UpdateStructure = New Structure;
	UpdateStructure.Insert("Version", UpdateString.Version);
	UpdateStructure.Insert("PlatformVersion", UpdateString.PlatformVersion);
	
	If GetUpdateSize = True Then
		UpdateStructure.Insert("SizeUpdate", FileSizeString(SizeOfUpdates()));
	EndIf;
	
	Return UpdateStructure;
	
EndFunction

// Calculate the total size of the update files.
//
// Parameters:
//  Object.AvailableUpdates  - array - list of updates.
//
// Returns:
//   Number   - update size in bytes.
&AtClient
Function SizeOfUpdates()
	SizeOfUpdates = 0;
	For Each Update IN Object.AvailableUpdates Do
		SizeOfUpdates = SizeOfUpdates + Update.UpdateFileSize;
	EndDo;
	Return SizeOfUpdates;
EndFunction

// Receive the string presentation of the file size.
//
// Parameters:
//  Size  - Number - size in bytes.
//
// Returns:
//   String   - String presentation of the file size, for example, "10.5 Mb".
&AtClient
Function FileSizeString(Val Size)

	If Size < 1024 Then
		Return Format(Size, "NFD=1") + " " + "byte";
	ElsIf Size < 1024 * 1024 Then	
		Return Format(Size / 1024, "NFD=1") + " " + "KB";
	ElsIf Size < 1024 * 1024 * 1024 Then	
		Return Format(Size / (1024 * 1024), "NFD=1") + " " + "MB";
	Else
		Return Format(Size / (1024 * 1024 * 1024), "NFD=1") + " " + "GB";
	EndIf; 

EndFunction

// Definition of the configuration and update layout directory on this computer.
&AtClient
Function TemplatesDirectory()
	
	Postfix = "1C\1Cv8\tmplts\";
	
	DirectoryDefault = DirectoryAppData() + Postfix;
	FileName = DirectoryAppData() + "1C\1CEStart\1CEStart.cfg";
	If Not FileExistsAtClient(FileName) Then 
		Return DirectoryDefault;
	EndIf;
	Text = New TextReader(FileName, TextEncoding.UTF16);
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
		FoundDirectory = ConfigurationUpdateClientServer.AddFinalPathSeparator(TrimAll(Mid(Str, SeparatorPosition + 1)));
		Return ?(FileExistsAtClient(FoundDirectory), FoundDirectory, DirectoryDefault);
	EndDo; 
	
	Return DirectoryDefault;

EndFunction 

// Define the My documents directory of the current Windows user.
//
&AtClient
Function DirectoryAppData() 
	
	App				= New COMObject("Shell.Application");
	Folder			= App.Namespace(26);
	Result		= Folder.Self.Path;
	Return ConfigurationUpdateClientServer.AddFinalPathSeparator(Result);
	
EndFunction 

// Check that the file is the update distribution.
//
// Parameter:
//  PathToFile   - String - file path.
//
// Returns:
//  Boolean - True if the file is the update distribution.
//
&AtClient
Function ThisIsUpdateInstallationPackage(Val PathToFile)
	File = New File(PathToFile);
	Return File.Exist() AND Lower(File.Extension) = ".zip";
EndFunction 

&AtClient
Function GoToChoiceOfUpdateMode(IsGoNext = False)
	
	If AdministrationParameters = Undefined Then
		
		ThisIsFileBase = StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase;
		
		NotifyDescription = New NotifyDescription("AfterAdministrationParametersReceiving", ThisObject, IsGoNext);
		FormTitle = NStr("en='Setting update';ru='Установка обновления'");
		If ThisIsFileBase Then
			ExplanatoryInscription = NStr("en='To set the update
		|it is necessary to enter the infobase administration parameters';ru='Для установки
		|обновления необходимо ввести параметры администрирования информационной базы'");
			QueryClusterAdministrationParameters = False;
		Else
			ExplanatoryInscription = NStr("en='To install the update it
		|is necessary to enter the administration parameters for the server and infobase cluster';ru='Для установки обновления
		|необходимо ввести параметры администрирования кластера серверов и информационной базы'");
			QueryClusterAdministrationParameters = True;
		EndIf;
		
		InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, True, QueryClusterAdministrationParameters,
			AdministrationParameters, FormTitle, ExplanatoryInscription);
		
	Else
		
		AfterAdministrationParametersReceiving(AdministrationParameters, IsGoNext);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure AfterAdministrationParametersReceiving(Result, IsGoNext) Export
	
	If Result <> Undefined Then
		
		AdministrationParameters = Result;
		Pages = Items.AssistantPages.ChildItems;
		ThisIsFileBase = StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase;
		NewCurrentPage = ?(ThisIsFileBase AND Not SimulationModeOfClientServerIB(), Pages.CaseUpdateFile, Pages.UpdateModeChoiceServer);
		SetAdministratorPassword(AdministrationParameters);
		
		If IsGoNext Then
			
			Items.AssistantPages.CurrentPage.Enabled = True;
			
			// Check that the configuration update is available.
			If Not StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.IsAccessForUpdate Then
				
				Items.ButtonBack.Enabled = True;
				Items.ButtonNext.Enabled = True;
				Items.CloseButton.Enabled = True;
				ShowMessageBox(, NStr("en='Insufficient rights to update the configuration.';ru='Недостаточно прав для выполнения обновления конфигурации.'"));
				ToWorkClickButtonsBack();
			EndIf;
			
		EndIf;
		
		BeforePageOpen(NewCurrentPage);
		Items.AssistantPages.CurrentPage = NewCurrentPage;
		
	Else
		
		If IsGoNext Then
			
			Items.AssistantPages.CurrentPage.Enabled = True;
			
		EndIf;
		
		WarningText = NStr("en='To set the update it is necessary to enter the administration parameters.';ru='Для установки обновления необходимо ввести параметры администрирования.'");
		ShowMessageBox(, WarningText);
		
		NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
		MessageText = NStr("en='Failed to install the application update, i.e. correct
		|infobase administration parameters were not entered.';ru='Не удалось установить обновление программы, т.к. не были введены
		|корректные параметры администрирования информационной базы.'");
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Error", MessageText);
		
		NewCurrentPage = Items.FailureRefresh;
		BeforePageOpen(NewCurrentPage);
		Items.AssistantPages.CurrentPage = NewCurrentPage;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAdministratorPassword(AdministrationParameters)
	
	InfobaseAdministrator = InfobaseUsers.FindByName(AdministrationParameters.NameAdministratorInfobase);
	
	If Not InfobaseAdministrator.StandardAuthentication Then
		
		InfobaseAdministrator.StandardAuthentication = True;
		InfobaseAdministrator.Password = AdministrationParameters.PasswordAdministratorInfobase;
		InfobaseAdministrator.Write();
		
	EndIf;
	
EndProcedure

// Receive the user authentication parameters for the update.
// Creates a virtual user if needed.
//
// Return
//  value Structure       - virtual user parameters.
//
&AtClient
Function GetAuthenticationParametersOfUpdateAdministrator()

	Result = New Structure("UserName,
								|UserPassword,
								|ConnectionString,
								|InfobaseConnectionString",
								Undefined, "", "", "", "", "");
								
	ClusterPort = AdministrationParameters.ClusterPort;
	CurrentConnections = InfobaseConnectionsServerCall.ConnectionInformation(True,
		ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"], ClusterPort);
	Result.InfobaseConnectionString = CurrentConnections.InfobaseConnectionString;
	// Diagnostics of the case when the role security is not provided in the system. 
	// It is a situation when any user "may" do everything in the system.
	If Not CurrentConnections.AreActiveUsers Then
		Return Result;
	EndIf;
	
	User = AdministrationParameters.NameAdministratorInfobase;
	Password = AdministrationParameters.PasswordAdministratorInfobase;
	
	Result.UserName			= User;
	Result.UserPassword		= Password;
	Result.ConnectionString			= "Usr=""{0}"";Pwd=""{1}""";
	Return Result;
	
EndFunction

&AtClient
Function CheckAccessToIB()
	
	NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
	Result = True;
	DetectedConnectionError = "";
	// IN basic versions the connection is not checked;
	// in case of incorrect name and password entry the update fails.
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	If ClientWorkParameters.ThisIsBasicConfigurationVersion Or ClientWorkParameters.IsEducationalPlatform Then
		Return Result;
	EndIf;
	
	// Check the connection to the infobase.
	Try
		ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,, False);
	Except
		Result = False;
		MessageText = NStr("en='Failed to connect to the infobase:';ru='Не удалось выполнить подключение к информационной базе:'") + Chars.LF;
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, 
			"Error", MessageText + DetailErrorDescription(ErrorInfo()));
		DetectedConnectionError = MessageText + BriefErrorDescription(ErrorInfo());
	EndTry;
	
	// Check connection to the cluster.
	If Result AND Not ClientWorkParameters.FileInfobase Then
		Try
			ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,, False);
		Except
			Result = False;
			MessageText = NStr("en='Failed to connect to the server cluster:';ru='Не удалось выполнить подключение к кластеру серверов:'") + Chars.LF;
			EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents,
				"Error", MessageText + DetailErrorDescription(ErrorInfo()));
			DetectedConnectionError = MessageText + BriefErrorDescription(ErrorInfo());
		EndTry;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function CheckEMailSettings(CurrentPageName, OutputMessages = True)
	If Not CommonUseClientServer.EmailAddressMeetsRequirements(Object.EmailAddress) Then
		If OutputMessages Then
			ShowMessageBox(, NStr("en='Specify valid email address';ru='Укажите допустимый адрес электронной почты.'"));
		EndIf;
		CurrentItem	= Items.FieldEmailAddress;
		Return CurrentPageName;
	EndIf;
	Return "";
EndFunction

&AtClient
Function DefineScriptName()
	App	= New COMObject("Shell.Application");
	Try
   		Folder = App.Namespace(41);
   		Return Folder.Self.Path + "\wscript.exe";
	Except
		Return "wscript.exe";
	EndTry;
EndFunction

&AtServer
Function AuthenticationParameters()
	
	CheckParameters = New Structure;
	
	SystemInfo = New SystemInfo;
	InfobaseIdentifier = StandardSubsystemsServer.InfobaseIdentifier();

	CheckParameters.Insert("login"               , Object.UpdateServerUserCode);
	CheckParameters.Insert("password"            , Object.UpdatesServerPassword);
	CheckParameters.Insert("variantBPED"         , "authorizationChecking");
	CheckParameters.Insert("versionConfiguration", TrimAll(Metadata.Version));
	CheckParameters.Insert("versionPlatform"     , String(SystemInfo.AppVersion));
	CheckParameters.Insert("nameConfiguration"   , Metadata.Name);
	CheckParameters.Insert("language"            , TrimAll(CurrentLocaleCode()));
	CheckParameters.Insert("enterPoint"          , "authorizationChecking");
	CheckParameters.Insert("InfobaseID"          , InfobaseIdentifier);
	
	Return CheckParameters;
	
EndFunction

// Plan the configuration update.
&AtClient
Function PlanConfigurationChange()
	If Not DeleteSchedulerTask(Object.SchedulerTaskCode) Then
		Return False;
	EndIf; 
	ScriptMainFileName = GenerateUpdateScriptFiles(False);
	
	NameOfScriptToRun = DefineScriptName();
	PathOfScriptToRun = StringFunctionsClientServer.SubstituteParametersInString("%1 %2 //nologo ""%3"" /p1:""%4"" /p2:""%5""",
		NameOfScriptToRun, ?(ScriptDebugMode(), "//X //D", ""), ScriptMainFileName,
		AdministrationParameters.PasswordAdministratorInfobase, AdministrationParameters.ClusterAdministratorPassword);
	
	Object.SchedulerTaskCode = CreateSchedulerTask(PathOfScriptToRun, Object.UpdateDateTime);
	WriteUpdateStatus(UserName(), Object.SchedulerTaskCode <> 0, False, False);
	Return Object.SchedulerTaskCode <> 0;
EndFunction

// Create Windows OS scheduler task.
//
// Parameters:
//  ApplicationFileName	- String	- path to the running application or file.
//  DateTime  			  - Date		- Start date and time. Date value may
// 							     	vary within [current date, current date + 30 days).
//
// Returns:
//   Number   - the code of the created scheduler task or Undefined in case of an error.
&AtClient
Function CreateSchedulerTask(Val ApplicationFileName, Val DateTime)
	NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
	Try
		Scheduler		= ObjectWMI().Get("Win32_ScheduledJob");
		CodeTasks		= 0;
		ErrorCode		= Scheduler.Create(ApplicationFileName, // Command
			ConvertTimeToCIMFormat(DateTime),	// StartTime
			False,		// RunRepeatedly
			,           // DaysOfWeek
			Pow(2, Day(DateTime) - 1),         // DaysOfMonth
			False, 		// InteractWithDesktop
			CodeTasks);// out JobId
		If ErrorCode <> 0 Then	// Error codes: http://msdn2.microsoft.com/en-us/library/aa389389(VS.85).aspx.
			EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, 
				"Error", NStr("en=""Error while creating scheduler's  task:"";ru='Ошибка при создании задачи планировщика:'")
					+ " " + ErrorCode);
			Return 0;
		EndIf;
		MessageText = NStr("en='The scheduler task has been successfully scheduled (command: %1; Date: %2; task code: %3).';ru='Задача планировщика успешно запланирована (команда: %1; дата: %2; код задачи: %3).'");
		
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents,
			"Information", 
			StringFunctionsClientServer.SubstituteParametersInString(MessageText, ApplicationFileName, DateTime, CodeTasks));
			
	Except
			
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Error",
			NStr("en=""Error while creating scheduler's  task:"";ru='Ошибка при создании задачи планировщика:'")
				+ " " + ErrorDescription());
		Return 0;
	EndTry;
	
	Return CodeTasks;

EndFunction

&AtClient
Function ConvertTimeToCIMFormat(DateTime)
	Locator			= New COMObject("WbemScripting.SWbemLocator");
	Service			= Locator.ConnectServer(".", "\root\cimv2");
	ComputerSystems	= Service.ExecQuery("Select * from Win32_ComputerSystem");
	For Each ComputerSystem IN ComputerSystems Do
		Difference	= ComputerSystem.CurrentTimeZone;
		Hour		= Format(DateTime,"DF=HH");
		Minute	= Format(DateTime,"DF=mm");
		Difference	= ?(Difference > 0, "+" + Format(Difference, "NG=0"), Format(Difference, "NG=0"));
		Return "********" + Hour + Minute + "00.000000" + Difference;
	EndDo;

	Return Undefined;
EndFunction

&AtClient
Function GenerateUpdateScriptFiles(Val InteractiveMode) 
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters();
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	CreateDirectory(UpdateParameters.UpdateTempFilesDir);
	
	// Structure of the parameters is required for defining them on client and passing to server.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("NameOfExecutableDesignerFile", UpdateParameters.NameOfExecutableDesignerFile);
	ParametersStructure.Insert("NameOfExecutableFileOfClient"		, StandardSubsystemsClient.ApplicationExecutedFileName());
	ParametersStructure.Insert("EventLogMonitorEvent"		, UpdateParameters.EventLogMonitorEvent);
	ParametersStructure.Insert("COMConnectorName"				, ClientWorkParameters.COMConnectorName);
	ParametersStructure.Insert("UseCOMConnector"		, ClientWorkParameters.ThisIsBasicConfigurationVersion Or ClientWorkParameters.IsEducationalPlatform);
	ParametersStructure.Insert("FileInfobase"		, ClientWorkParameters.FileInfobase);
	ParametersStructure.Insert("ScriptParameters"					, GetAuthenticationParametersOfUpdateAdministrator());
	ParametersStructure.Insert("AdministrationParameters"		, AdministrationParameters);
	
	// Add to the structure and the name of the running application.
	
	#If Not WebClient Then
		ParametersStructure.Insert("BinDir"			, BinDir());
	#Else
		ParametersStructure.Insert("BinDir"			, "");
	#EndIf
	
	TemplateNames = "AdditFileOfUpdateOfConfiguration";
	If InteractiveMode Then
		TemplateNames = TemplateNames + ",SplashOfConfigurationUpdate";
	Else
		TemplateNames = TemplateNames + ",OfflineConfigurationUpdate";
	EndIf;
	TemplateTexts = GetTextsOfTemplates(TemplateNames, ParametersStructure, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[0]);
	
	ScriptFileName = UpdateParameters.UpdateTempFilesDir + "main.js";
	ScriptFile.Write(ScriptFileName, TextEncoding.UTF16);
	
	// Helper file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[1]);
	ScriptFile.Write(UpdateParameters.UpdateTempFilesDir + "helpers.js", TextEncoding.UTF16);
	
	ScriptMainFileName = Undefined;
	If InteractiveMode Then
		// Helper file: splash.png.
		PictureLib.ExternalActionSplash.Write(UpdateParameters.UpdateTempFilesDir + "splash.png");
		// Helper file: splash.ico.
		PictureLib.ExternalActionSplashIcon.Write(UpdateParameters.UpdateTempFilesDir + "splash.ico");
		// Helper file: progress.gif.
		PictureLib.LongOperation48.Write(UpdateParameters.UpdateTempFilesDir + "progress.gif");
		// Main splash screen file: splash.hta.
		ScriptMainFileName = UpdateParameters.UpdateTempFilesDir + "splash.hta";
		ScriptFile = New TextDocument;
		ScriptFile.Output = UseOutput.Enable;
		ScriptFile.SetText(TemplateTexts[2]);
		ScriptFile.Write(ScriptMainFileName, TextEncoding.UTF16);
	Else
		ScriptMainFileName = UpdateParameters.UpdateTempFilesDir + "updater.js";
		ScriptFile = New TextDocument;
		ScriptFile.Output = UseOutput.Enable;
		ScriptFile.SetText(TemplateTexts[2]);
		ScriptFile.Write(ScriptMainFileName, TextEncoding.UTF16);
	EndIf;
	
	Return ScriptMainFileName;              
EndFunction

&AtClient
Function WMIInstalled(Val OutputMessages = True)
	Try
		Return ObjectWMI() <> Undefined;
	Except
		NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Error", ErrorDescription());
		Return False;
	EndTry;
EndFunction

&AtClient
Function CheckValidUpdateDate(DateTime, OutputMessages = True)
	MessageText = ValidateAcceptableDateUpdateAtServer(DateTime);
	Result = IsBlankString(MessageText);
	If Not Result AND OutputMessages Then
		ShowMessageBox(, MessageText);
	EndIf;
	Return Result;
EndFunction

&AtServerNoContext
Function ValidateAcceptableDateUpdateAtServer(DateTime)
	
	Now = CurrentSessionDate();
	If DateTime < Now Then
		Return NStr("en='Configuration updates can be planned only for future date and time.';ru='Обновление конфигурации может быть запланировано только на будущую дату и время.'");
	EndIf;
	If DateTime > AddMonth(Now, 1) Then
		Return NStr("en='Configuration update can be planned not later than in a month after the current date.';ru='Обновление конфигурации может быть запланировано не позднее, чем через месяц относительно текущей даты.'");
	EndIf;
	
	Return "";
	
EndFunction

&AtClient
Function DeleteSchedulerTask(CodeTasks)
	NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
	If CodeTasks = 0 Then
		Return True;
	EndIf; 
	
	Try
		Service = ObjectWMI();
		
		Task = GetSchedulerTask(CodeTasks);
		If Task = Undefined Then
			CodeTasks = 0;
			Return True;
		EndIf; 
		
		ErrorCode = Task.Delete();
		Result = ErrorCode = 0;
		If Not Result Then	// Error codes: http://msdn2.microsoft.com/en-us/library/aa389957(VS.85).aspx.
			EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Error",
				NStr("en='Error occurred while deleting the scheduler:';ru='Ошибка при удалении задачи планировщика:'")
					+ " " + ErrorCode);
			Return Result;
		EndIf;
		MessageText = NStr("en='The scheduler task has been successfully removed (task code: %1).';ru='Задача планировщика успешно удалена (код задачи: %1).'");
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Information",
			StringFunctionsClientServer.SubstituteParametersInString(MessageText, CodeTasks));
		CodeTasks = 0;
		
		Return Result;
	Except
		
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Error",
			NStr("en='Error occurred while deleting the scheduler:';ru='Ошибка при удалении задачи планировщика:'")
				+ " " + ErrorDescription());
		Return False;
	EndTry;

EndFunction

&AtClient
Function CreateFileListForObtaining() 
	
	FileList = New Array;
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters();
	DirectoryUpdateInSource = UpdateParameters.TemplatesDirectoryAddressAtUpdatesServer;
	
	For Each Update IN Object.AvailableUpdates Do
		If Not IsBlankString(Update.PathToUpdateFile) AND IsBlankString(Update.PathToLocalUpdateFile) Then
			StructureInformationFile	= New Structure("Address, LocalPath, Obligatory, Received");
			
			FileDirectoryUpdate						= GetUpdateFileDir(Update);
			Update.LocalRelativeDirectory	= FileDirectoryUpdate;
			Update.PathToLocalFile				= UpdateParameters.UpdateFilesDir +
				FileDirectoryUpdate + Update.UpdateFile;
			// Update attachment description.
			StructureInformationFile.Clear();
			StructureInformationFile.Insert("Address"					, DirectoryUpdateInSource + Update.PathToUpdateFile);
			StructureInformationFile.Insert("LocalPath"			, Update.PathToLocalFile);
			StructureInformationFile.Insert("IsRequired"			, True);
			StructureInformationFile.Insert("Received"				, DefineFileReceived(StructureInformationFile,
																								Update.UpdateFileSize));
			FileList.Add(StructureInformationFile);
		EndIf;
	EndDo;
	
	Return FileList;
	
EndFunction

&AtClient
Function DefineFileReceived(FileDescription, Size)
	File = New File(FileDescription.LocalPath);
	Return File.Exist() AND File.Size() = Size;
EndFunction

// Receiving the update description file from the server.
&AtClient
Function GetFileOfUpdateDescription()
	
	UpdateSettings = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings;
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters();
	FileName	= GetNameOfLocalFileOfUpdateDescription();
	Result	= GetFilesFromInternetClient.ExportFileAtClient(UpdateSettings.ServerAddressForVerificationOfUpdateAvailability +
		UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability +	UpdateParameters.UpdateDescriptionFileName,
		New Structure("PathForSave", ? (IsBlankString(FileName), Undefined, FileName)));
	If Result.Status Then
		Return FileName;
	EndIf;
	
	Try
		DeleteFiles(FileName);
	Except
		MessageText = NStr("en='Error while deleting the
		|temporary file %1 %2';ru='Ошибка при удалении временного файла %1 %2'");
		NameLogEvents =	ConfigurationUpdateClient.EventLogMonitorEvent();
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents,
			"Error", StringFunctionsClientServer.SubstituteParametersInString(MessageText, FileName,
			DetailErrorDescription(ErrorInfo())));
	EndTry;
	Return Undefined;
	
EndFunction

&AtClient
Function GetNameOfLocalFileOfUpdateOrder()
	
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters();
	Return UpdateParameters.UpdateFilesDir + UpdateParameters.UpdateOrderFileName;
	
EndFunction

&AtClient
Function GetNameOfLocalFileOfUpdateDescription()
	
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters();
	Return UpdateParameters.UpdateFilesDir + UpdateParameters.UpdateDescriptionFileName;
			
EndFunction

// Receiving the update order file from the server.
&AtClient
Function GetFileOfUpdateOrder()
	
	UpdateSettings = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings;
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters();
	FileName = GetNameOfLocalFileOfUpdateOrder();
	Result	= GetFilesFromInternetClient.ExportFileAtClient(UpdateSettings.ServerAddressForVerificationOfUpdateAvailability +
		UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability +	UpdateParameters.UpdateOrderFileName,
		New Structure("PathForSave", ? (IsBlankString(FileName), Undefined, FileName)), False);
	If Result.Status Then
		Return FileName;
	EndIf;
	Try
		DeleteFiles(FileName);
	Except
		MessageText = NStr("en='Error while deleting the
		|temporary file %1 %2';ru='Ошибка при удалении временного файла %1 %2'");
			
		NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
		EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents,
			"Error", StringFunctionsClientServer.SubstituteParametersInString(MessageText, FileName,
			DetailErrorDescription(ErrorInfo())));
	EndTry;
	Return Undefined;
	
EndFunction 

&AtClient
Procedure GetAvailableUpdateFromFile(Val FileName, FileVariant = False)
	If ValueIsFilled(FileName) Then
		If FileVariant Then
			Object.AvailableUpdates.Clear();
		EndIf;
		NewAvailableUpdate								= Object.AvailableUpdates.Add();
		NewAvailableUpdate.PathToLocalFile			= FileName;
		NewAvailableUpdate.PathToLocalUpdateFile	= FileName;
	EndIf;
EndProcedure

// Receiving the update file directory. 
// 
// Parameter:
//  AvailableUpdate - Value table string containing information
//                        of the available update.
// 
// Returns:
//  String - update file directory.
//
&AtClient
Function GetUpdateFileDir(AvailableUpdate)
	
	If AvailableUpdate = Undefined Then
		Return Undefined;
	EndIf;
	
	ConfigurationShortName = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.ConfigurationShortName;
	ConfigurationShortName = StrReplace(ConfigurationShortName, "/", "\");
	ConfigurationShortName = ConfigurationUpdateClientServer.AddFinalPathSeparator(ConfigurationShortName);
	Result = StrReplace(AvailableUpdate.PathToUpdateFile, "/", "\");
	Result = ConfigurationUpdateClient.GetFileDir(Result);
	Result = StrReplace(Result, "_", ".");
	Result = ConfigurationUpdateClientServer.AddFinalPathSeparator(Result);
	Return Result;
	
EndFunction

// Update distribution unpacking.
&AtClient
Function UnpackUpdateInstallationPackage()
	#If Not WebClient Then
	NameLogEvents = ConfigurationUpdateClient.EventLogMonitorEvent();
	EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, 
		"Information", NStr("en='Unpack the update distribution...';ru='Выполняется распаковка дистрибутива обновления...'"));
		
	For Each Update IN Object.AvailableUpdates Do
	
		If Not ThisIsUpdateInstallationPackage(Update.PathToLocalFile) Then
			Update.PathToLocalUpdateFile = ?(IsBlankString(Update.PathToLocalUpdateFile), 
				Update.PathToLocalFile, Update.PathToLocalUpdateFile);
			Continue;
		EndIf;
		
		Try 
			
			ZipReader			= New ZipFileReader(Update.PathToLocalFile);
			DestinationDirectory	= TemplatesDirectory() + Update.LocalRelativeDirectory;
			ZipReader.ExtractAll(DestinationDirectory, ZIPRestoreFilePathsMode.Restore);
			UpdateFileName	= DestinationDirectory + "1cv8.cfu";
			If Not FileExistsAtClient(UpdateFileName) Then
				EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Error",
					NStr("en='Update installation package does not contain 1cv8.cfu:';ru='Дистрибутив обновления не содержит 1cv8.cfu:'")
						+ " " + Update.PathToLocalFile);
				Return False;
			EndIf;
			Update.PathToLocalUpdateFile = UpdateFileName;
			
			EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Information",
				NStr("en='Update files successfully unpacked:';ru='Файлы дистрибутива обновления успешно распакованы:'")
					+ " " + UpdateFileName);
		Except
			EventLogMonitorClient.AddMessageForEventLogMonitor(NameLogEvents, "Error",
				NStr("en='Error while unzipping the updates distribution';ru='Ошибка при распаковке дистрибутива обновления:'")
					+ " " + ErrorDescription());
			Return False;
		EndTry;
		
		Try
			ZipReader			= New ZipFileReader(Update.PathToLocalFile);
			DestinationDirectory	= ConfigurationUpdateClient.GetUpdateParameters().UpdateFilesDir + Update.LocalRelativeDirectory;
			ZipReader.ExtractAll(DestinationDirectory, ZIPRestoreFilePathsMode.Restore);
			UpdateFileName	= DestinationDirectory + "1cv8.cfu";
			If Not FileExistsAtClient(UpdateFileName) Then
				EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
					"Error", NStr("en='Update installation package does not contain 1cv8.cfu:';ru='Дистрибутив обновления не содержит 1cv8.cfu:'")
						+ " " + Update.PathToLocalFile);
				Return False;
			EndIf;
			Update.PathToLocalUpdateFile = UpdateFileName;
			EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
				"Information", NStr("en='Update files successfully unpacked:';ru='Файлы дистрибутива обновления успешно распакованы:'")
					+ " " + UpdateFileName);
			ZipReader.Close();
		Except
			EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
				"Error",  NStr("en='Error while unzipping the update distribution:';ru='Ошибка при распаковке дистрибутива обновления:'")
					+ " " + ErrorDescription());
			Return False;
		EndTry;
	EndDo;
	Return True;
	#EndIf
EndFunction

&AtClient
Procedure GetAvailableUpdates(UpdateParameters, ConfigurationVersion, OutputMessages, AvailableUpdateForNextEdition = False)
	
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters(AvailableUpdateForNextEdition);
	PathToUpdateListFile = UpdateParameters.UpdateFilesDir +
		UpdateParameters.ListTemplatesFileName;
	FileURLTempStorage = PutToTempStorage(New BinaryData(PathToUpdateListFile));
	Try
		GetAvailableUpdatesInInterval(StandardSubsystemsClientReUse.ClientWorkParameters().ConfigurationVersion,
			ConfigurationVersion, FileURLTempStorage, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	Except
		If OutputMessages Then
			ShowMessageBox(, BriefErrorDescription(ErrorInfo()));
		EndIf;
	EndTry;
	
EndProcedure

// Receiving the layout list file from the server.
&AtClient
Function GetFileOfTemplatesList(Val OutputMessages = True, AvailableUpdateForNextEdition = False)
    #If Not WebClient Then
	UpdateParameters = ConfigurationUpdateClient.GetUpdateParameters(AvailableUpdateForNextEdition);
	UpdateSettings = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings;
	PathToTemplatesListFile = UpdateParameters.UpdateFilesDir + UpdateParameters.ZIPFileNameOfListOfTemplates;
	
	Result = GetFilesFromInternetClient.ExportFileAtClient(UpdateSettings.ServerAddressForVerificationOfUpdateAvailability +
		UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability +	UpdateParameters.ZIPFileNameOfListOfTemplates,
		New Structure("PathForSave", ? (IsBlankString(PathToTemplatesListFile), Undefined, PathToTemplatesListFile)));
	If Result.Status <> True Then
		Try
			DeleteFiles(PathToTemplatesListFile);
		Except
			EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(),
				"Error", 
				NStr("en='Error while deleting temporary file';ru='Ошибка при удалении временного файла'") + " " + PathToTemplatesListFile + Chars.LF +
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		ErrorText = NStr("en='Error while receiving file of the templates list:';ru='Ошибка при получении файла списка шаблонов:'") + " " + Result.ErrorInfo;
		If OutputMessages Then
			ShowMessageBox(, ErrorText);
		EndIf; 
		Return ErrorText;
	EndIf;
	
	If Not FileExistsAtClient(PathToTemplatesListFile) Then
		Return NStr("en='File does not exist:';ru='Файл не существует:'") + " " + PathToTemplatesListFile;
	EndIf;
	
	Try 
		ZipReader = New ZipFileReader(PathToTemplatesListFile);
		ZipReader.ExtractAll(UpdateParameters.UpdateFilesDir, ZIPRestoreFilePathsMode.DontRestore);
	Except
		ErrorText	= NStr("en='Error when unpacking the file with the list of available updates:';ru='Ошибка при распаковке файла со списком доступных обновлений:'") + " ";
		InfoErrors	= ErrorInfo();
		EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
			"Error", ErrorText + DetailErrorDescription(InfoErrors));
		ErrorText	= ErrorText + BriefErrorDescription(InfoErrors);
		Return ErrorText;
	EndTry;
	DeleteFiles(UpdateParameters.UpdateFilesDir, UpdateParameters.ZIPFileNameOfListOfTemplates);
	Return "";
	#EndIf
EndFunction

// Check the existence of the file or directory.
//
// Parameter:
//  PathToFile   - String - path to the file or
//                 directory which existence shall be checked.
//
// Returns:
//  Boolean - flag showing the existence of file or directory.
&AtClient
Function FileExistsAtClient(Val PathToFile)
	File = New File(PathToFile);
	Return File.Exist();
EndFunction

&AtClient
Function GetUpdate(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	Message = "";
	If Object.UpdateSource = 0 Then
		Message = Message + NStr("en='Receiving the files from the Internet...';ru='Получение файлов из Интернета...'");
	Else
		Message = Message + NStr("en='Receiving the update file from the specified source...';ru='Получение файла обновления из указанного источника...'");
	EndIf;
	EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
		"Information", Message);
	
	Object.TechnicalErrorInfo = "";
	FileNumber = 1;
	For Each File IN FileListForObtaining Do
		
		If File.Value <> Undefined AND File.Value.Received <> True Then	// It can also be Undefined.
			If Object.UpdateSource = 0 Then
				
				AuthenticationResult = ConfigurationUpdateClient.CheckUpdateImportLegality(
					AuthenticationParameters());
				
				If Not AuthenticationResult.ResultValue Then
					
					Items.AccessGroupOnSite.CurrentPage = Items.AccessGroupOnSite.ChildItems.LegalityCheckError;
					ErrorText = NStr("en='Failed to confirm the update authentication through the Internet
		|due to: %1';ru='Не удалось подтвердить легальность получения обновления через
		|Интернет по причине: %1'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, AuthenticationResult.ErrorText);
					Items.LegalityCheckErrorText.Title = ErrorText;
					Return Pages.ConnectionToSite.Name;
					
				EndIf;
				
				// Display the message of the file exporting to the log.
				Message = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en=' Get file %1 to %2';ru=' Получаем файл %1 в %2'"),
						ConfigurationUpdateClient.GetUpdateParameters().AddressOfUpdatesServer + File.Value.Address,
						? (IsBlankString(File.Value.LocalPath), Undefined, File.Value.LocalPath));
				Items.LabelProgres.Title = Message;
				EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), , Message);
				
				CreateDirectory(ConfigurationUpdateClient.GetFileDir(File.Value.LocalPath));
				Result	= GetFilesFromInternetClient.ExportFileAtClient(
					ConfigurationUpdateClient.GetUpdateParameters().AddressOfUpdatesServer + File.Value.Address,
					New Structure("PathForSave, User, Password",
						? (IsBlankString(File.Value.LocalPath), Undefined, File.Value.LocalPath),
						Object.UpdateServerUserCode,
						Object.UpdatesServerPassword));
				ErrorText = "";
				If Result.Status <> True Then
					ErrorText = Result.ErrorInfo;
					Try
						DeleteFiles(File.Value.LocalPath);
					Except
						EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
							"Error", NStr("en='Error while deleting temporary file';ru='Ошибка при удалении временного файла'") + " " +
							File.Value.LocalPath + Chars.LF + DetailErrorDescription(ErrorInfo()));
					EndTry;
					If Not IsBlankString(ErrorText) Then
						If File.Value.IsRequired AND OutputMessages Then
							ShowMessageBox(, ErrorText);
							Return Pages.ConnectionToSite.Name;
						EndIf; 
					EndIf;
				EndIf;
				
				File.Value.Received = IsBlankString(ErrorText);
				
				If Not File.Value.Received AND File.Value.IsRequired Then
					Return Pages.ConnectionToSite.Name;
				EndIf;
			Else
				// Moving the message of the file copying to the log.
				Message = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en=' Get file %1 to %2';ru=' Получаем файл %1 в %2'"), File.Value.Address, File.Value.LocalPath);
				Items.LabelProgres.Title = Message;
				EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), , Message);
				
				File.Value.Received = CopyFile(File.Value.Address, File.Value.LocalPath, File.Value.IsRequired AND OutputMessages);
			EndIf;
		EndIf;
		FileNumber = FileNumber + 1;
	EndDo;
	
	PageName = "";
	If CheckUpdateFilesReceived() Then
		EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
			"Information", NStr("en='Update Files received successfully.';ru='Файлы обновления успешно получены.'"));
		GoToChoiceOfUpdateMode(True);
		Return Undefined;
	Else
		Message = NStr("en='Error at receiving the update files.';ru='Ошибка при получении файлов обновления.'");
		EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
			"Error", Message);
		PageName = Pages.FailureRefresh.Name;
	EndIf;
	Return PageName;
	
EndFunction

// The function that copyies the specified file to another one.
//
// Parameters:
// SourceFileName: string, path to the file to be copied.
// DestinationFileName: string, path to the file where the source shall be copied.
// DisplayMessage: Boolean, flag of the error message output.
//
&AtClient
Function CopyFile(FileNameSource, FileNamePurpose, OutputMessages = False)
	Try
		CreateDirectory(ConfigurationUpdateClient.GetFileDir(FileNamePurpose));
		FileCopy(FileNameSource, FileNamePurpose);
	Except
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error while
		|copying: %1 (source:% 2; receiver: 3%)';ru='Ошибка
		|при копировании: %1 (источник: %2; приемник: %3)'"), 
				DetailErrorDescription(ErrorInfo()),
				FileNameSource, FileNamePurpose);
		EventLogMonitorClient.AddMessageForEventLogMonitor(
			ConfigurationUpdateClient.EventLogMonitorEvent(), "Warning", Message);
		Return False;
	EndTry;
	Return True;
EndFunction

&AtClient
Function GetUpdateFilesViaInternet(OutputMessages, AvailableUpdateForNextEdition = False)
	
	Pages = Items.AssistantPages.ChildItems;
	AvailableUpdate = ConfigurationUpdateClient.GetAvailableConfigurationUpdate();
	If AvailableUpdate.PageName = Pages.AvailableUpdate.Name Then
		
		ErrorText = GetFileOfTemplatesList(OutputMessages, AvailableUpdateForNextEdition);
		If Not IsBlankString(ErrorText) Then
			Return Pages.InternetConnection.Name;
		EndIf;
		
		FileNameInformationAboutUpdate	= GetFileOfUpdateDescription();
		FileNameOrderUpdate		= GetFileOfUpdateOrder();
		
		GetAvailableUpdates(AvailableUpdate.FileParametersUpdateChecks,
			AvailableUpdate.LastConfigurationVersion, OutputMessages, AvailableUpdateForNextEdition);
		LastConfigurationVersion = AvailableUpdate.LastConfigurationVersion;
		If Object.AvailableUpdates.Count() = 0 Then
			EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
				"Information", NStr("en='It is impossible to continue receiving updates: there are no updates available.';ru='Невозможно продолжить обновление: нет доступных обновлений.'"));
			Return Pages.UpdatesNotDetected.Name;
		EndIf;
		
	EndIf;
	
	Return AvailableUpdate.PageName;
	
EndFunction

&AtClient
Function CheckUpdateInternet(OutputMessages = True) 
	Pages		= Items.AssistantPages.ChildItems;
	EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
		"Information", NStr("en='Check update in Internet...';ru='Проверка обновления в Интернете...'"));
	AvailableUpdate = Undefined;
	Object.AvailableUpdates.Clear();
	
	ConfigurationUpdateClient.CheckUpdateExistsViaInternet(OutputMessages, AvailableUpdateForNextEdition);
	
	Return GetUpdateFilesViaInternet(OutputMessages, AvailableUpdateForNextEdition);
EndFunction

&AtClient
Procedure RunUpdateObtaining()
	CurrentPage = Items.AssistantPages.CurrentPage;
	ResultGetFiles = GetUpdate();
	If ResultGetFiles = Undefined Then
		Return;
	EndIf;
	Items.AssistantPages.CurrentPage = CurrentPage;
	ProcessPressOfButtonNext();
EndProcedure

&AtClient
Function ReturnDate(Date, Time)
	Return Date(Year(Date), Month(Date), Day(Date), Hour(Time), Minute(Time), Second(Time));
EndFunction	

&AtClient
Function CheckUpdateFile(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	
	EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), 
		"Information",  NStr("en='Check update in Internet...';ru='Проверка обновления в Интернете...'"));
		
	Object.AvailableUpdates.Clear();
	
	If RestorationOfPreLaunch <> True Then
		Return Pages.UpdateFile.Name;
	EndIf;
	
	If Object.NeedUpdateFile = 1 Then
		File = New File(Object.UpdateFileName);
		If Not File.Exist() OR Not File.IsFile() Then
			
			EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), "Information",
				NStr("en='It is impossible to continue installing updates: configuration updates delivery file not found.';ru='Невозможно продолжить обновление: файл поставки обновления конфигурации не найден.'"));
				
			Return Pages.UpdateFile.Name;
		EndIf;
	EndIf;
	
	GetAvailableUpdateFromFile(?(Object.NeedUpdateFile = 1, Object.UpdateFileName, Undefined));
	GoToChoiceOfUpdateMode(True);
	Return Undefined;
	
EndFunction

&AtClient
Function LabelTextInfobaseBackup()
	
	Result = NStr("en='Do not create the backup copy';ru='Не создавать резервную копию ИБ'");
	
	If Object.CreateBackup = 1 Then
		Result = NStr("en='Create the temporary IB backup';ru='Создавать временную резервную копию ИБ'");
	ElsIf Object.CreateBackup = 2 Then
		Result = NStr("en='Create IB backup copy';ru='Создавать резервную копию ИБ'");
	EndIf; 
	
	If Object.RestoreInfobase Then
		Result = Result + " " + NStr("en='and perform rollback in case of abnormal situation';ru='и выполнять откат при нештатной ситуации'");
	Else
		Result = Result + " " + NStr("en='and do not perform the rollback in case of abnormal situation';ru='и не выполнять откат при нештатной ситуации'");
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure RunConfigurationUpdate()
	
	DeleteSchedulerTask(Object.SchedulerTaskCode);
	ScriptMainFileName = GenerateUpdateScriptFiles(True);
	EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(), "Information",
		NStr("en='Installing configuration updates:';ru='Выполняется процедура обновления конфигурации:'")
			+ " " + ScriptMainFileName);
	WriteUpdateStatus(UserName(), True, False, False, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
	LaunchString = "cmd /c """"%1"""" [p1]%2[/p1][p2]%3[/p2]";
	LaunchString = StringFunctionsClientServer.SubstituteParametersInString(LaunchString, ScriptMainFileName,
		AdministrationParameters.PasswordAdministratorInfobase, AdministrationParameters.ClusterAdministratorPassword);
	Shell = New COMObject("Wscript.Shell");
	Shell.RegWrite("HKCU\Software\Microsoft\Internet Explorer\Styles\MaxScriptStatements", 1107296255, "REG_DWORD");
	Shell.Run(LaunchString, 0);
	
EndProcedure

&AtServerNoContext
Procedure WriteUpdateStatus(UpdateAdministratorName, RefreshEnabledPlanned, RefreshCompleted, UpdateResult,
	MessagesForEventLogMonitor = Undefined)
	
	ConfigurationUpdate.WriteUpdateStatus(
		UpdateAdministratorName,
		RefreshEnabledPlanned,
		RefreshCompleted,
		UpdateResult,
		MessagesForEventLogMonitor);
	
EndProcedure 

&AtClient
Function ObjectWMI()
	// WMI: http://www.microsoft.com/technet/scriptcenter/resources/wmifaq.mspx.
	Locator = New COMObject("WbemScripting.SWbemLocator");
	Return Locator.ConnectServer(".", "\root\cimv2");
EndFunction

&AtClient
Function GetSchedulerTask(Val CodeTasks)
	If CodeTasks = 0 Then
		Return Undefined;
	EndIf; 
	
	Try
		Return ObjectWMI().Get("Win32_ScheduledJob.JobID=" + CodeTasks);
	Except
		Return Undefined;
	EndTry; 
EndFunction

&AtClient
Function ItIsPossibleToStartUpdate()
	
	ItIsPossibleToStartUpdate = True;
	
	#If WebClient Then
		ItIsPossibleToStartUpdate = False;
		MessageText = NStr("en='Application update is unavailable in the web client.';ru='Обновление программы недоступно в веб-клиенте.'");
	#EndIf
	
	If CommonUseClientServer.IsLinuxClient() Then
		ItIsPossibleToStartUpdate = False;
		MessageText = NStr("en='Application update is unavailable in the client under Linux OS.';ru='Обновление программы недоступно в клиенте под управлением ОС Linux.'");
	EndIf;
	
	If CommonUseClient.ClientConnectedViaWebServer() Then
		ItIsPossibleToStartUpdate = False;
		MessageText = NStr("en='Application update is not available when connecting using the web server.';ru='Обновление программы недоступно при подключении через веб-сервер.'");
	EndIf;
	
	If Not ItIsPossibleToStartUpdate Then
		
		ShowMessageBox(, MessageText);
		EventLogMonitorClient.AddMessageForEventLogMonitor(ConfigurationUpdateClient.EventLogMonitorEvent(),,
			MessageText,,True);
		
	EndIf;
		
	Return ItIsPossibleToStartUpdate;
	
EndFunction

&AtClient
Procedure DisplayUpdateOrder()
	
	If Not IsBlankString(FileNameOrderUpdate) Then
		ConfigurationUpdateClient.OpenWebPage(FileNameOrderUpdate);
	Else
		ShowMessageBox(, NStr("en='Update order description missing.';ru='Описание порядка обновления отсутствует.'"));
	EndIf;
	
EndProcedure

&AtServer
Function PerformIBTableCompression()
	
	If Object.AvailableUpdates.Count() = 0 Then
		Return False;
	EndIf;
	
	AvailableVersion = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(Object.AvailableUpdates[Object.AvailableUpdates.Count()-1].Version);
	
	If IsBlankString(AvailableVersion) Then
		Return False;
	EndIf;
	
	CurrentVersion = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(Metadata.Version);
	
	Return CommonUseClientServer.CompareVersionsWithoutBatchNumber(AvailableVersion, CurrentVersion) > 0;
	
EndFunction

&AtServer
Function PlatformUpdateIsNeeded(RequiredVersion)
	
	If Not ValueIsFilled(RequiredVersion) Then
		Return False;
	EndIf;
	
	SystemInfo = New SystemInfo;
	CurrentPlatformVersion = SystemInfo.AppVersion;
	
	Return CommonUseClientServer.CompareVersions(RequiredVersion, CurrentPlatformVersion) > 0;
	
EndFunction

#EndRegion














