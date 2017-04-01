&AtClient
Var BackupExecuted;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return; // Fail is set in OnOpen().
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		Raise NStr("en='Backing up is not available in web-client.';ru='Резервное копирование недоступно в веб-клиенте.'");
	EndIf;
	
	If Not CommonUse.FileInfobase() Then
		Raise NStr("en='Backup in client-server work variant should be performed by outside agents (means DBMS)';ru='В клиент-серверном варианте работы резервное копирование следует выполнять сторонними средствами (средствами СУБД).'");
	EndIf;
	
	BackupSettings = InfobaseBackupServer.BackupSettings();
	IBAdministratorPassword = BackupSettings.IBAdministratorPassword;
	
	If Parameters.RunMode = "ExecuteNow" Then
		Items.AssistantPages.CurrentPage = Items.InformationAndBackupPerformingPage;
		If Not IsBlankString(Parameters.Explanation) Then
			Items.GroupWait.CurrentPage = Items.StartTimeWaitPage;
			Items.LabelBackupTimeout.Title = Parameters.Explanation;
		EndIf;
	ElsIf Parameters.RunMode = "ExecuteOnExit" Then
		Items.AssistantPages.CurrentPage = Items.InformationAndBackupPerformingPage;
	ElsIf Parameters.RunMode = "ExecutedSuccessfully" Then
		Items.AssistantPages.CurrentPage = Items.PageOfSucessfulCopyingCompletion;
		BackupFileName = Parameters.BackupFileName;
	ElsIf Parameters.RunMode = "NotCompleted" Then
		Items.AssistantPages.CurrentPage = Items.PageOfErrorsOnCopying;
	EndIf;
	
	AutoExecution = (Parameters.RunMode = "ExecuteNow" Or Parameters.RunMode = "ExecuteOnExit");
	
	If BackupSettings.Property("BackupStorageDirectoryOnManualLaunch")
		AND Not IsBlankString(BackupSettings.BackupStorageDirectoryOnManualLaunch)
		AND Not AutoExecution Then
		Object.BackupDirectory = BackupSettings.BackupStorageDirectoryOnManualLaunch;
	Else
		Object.BackupDirectory = BackupSettings.DirectoryStorageOfBackupCopies;
	EndIf;
	
	If BackupSettings.DateOfLastBackup = Date(1, 1, 1) Then
		HeaderText = NStr("en='Backup has never conducted';ru='Резервное копирование еще ни разу не проводилось'");
	Else
		HeaderText = NStr("en='Last time the backup was executed: %1';ru='В последний раз резервное копирование проводилось: %1'");
		LastCopyDate = Format(BackupSettings.DateOfLastBackup, "DLF=DDT");
		HeaderText = StringFunctionsClientServer.SubstituteParametersInString(HeaderText, LastCopyDate);
	EndIf;
	Items.LabelLastBackupExecutionDate.Title = HeaderText;
	
	Items.AutomaticBackupGroup.Visible = Not BackupSettings.ExecuteAutomaticBackup;
	
	// First part of the check on server - if there are users in the infobase.
	PasswordEnterIsRequired = (InfobaseUsers.GetUsers().Count() > 0);
	
	ManualStart = (Items.AssistantPages.CurrentPage = Items.BackupExecutionPage);
	
	If ManualStart Then
		
		If InfobaseSessionCount() > 1 Then
			
			Items.CopyStatusPages.CurrentPage = Items.ActiveUsersPage;
			
		EndIf;
		
		Items.Next.Title = NStr("en='Save backup';ru='Сохранить резервную копию'");
		
	EndIf;
	
	InfobaseBackupServer.SetSettingValue("LastBackupManualLaunch", ManualStart);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClientServer.IsLinuxClient() Then
		Cancel = True;
		MessageText = NStr("en='Backup is unavailable in the client managed by OC Linux.';ru='Резервное копирование недоступно в клиенте под управлением ОС Linux.'");
		ShowMessageBox(,MessageText);
		Return;
	EndIf;
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	UserInfo = ClientWorkParameters.UserInfo;
	
	// Second part of the check on client - if current user
	// (administrator) uses standard authentication and the password is set.
	PasswordEnterIsRequired = PasswordEnterIsRequired AND UserInfo.StandardAuthentication AND UserInfo.PasswordIsSet;
	
	If PasswordEnterIsRequired Then
		InfobaseAdministrator = UserInfo.Name;
	Else
		Items.GroupAuthorization.Visible = False;
	EndIf;
	
	GoToPage(Items.AssistantPages.CurrentPage);
	
#If WebClient Then
	Items.UpdateComponentVersionLabel.Visible = False;
#EndIf
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	CurrentPage = Items.AssistantPages.CurrentPage;
	If CurrentPage = Items.AssistantPages.ChildItems.InformationAndBackupPerformingPage Then
		
		WarningText = NStr("en='Cancel backup preparation?';ru='Прервать подготовку к резервному копированию данных?'");
		CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject,
			Cancel, WarningText, "ForceCloseForm");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	DetachIdleHandler("TimeOutLapse");
	DetachIdleHandler("CheckThatConnectionIsSingle");
	DetachIdleHandler("TerminateUserSessions");
	
	If BackupExecuted = True Then
		Return;
	EndIf;
	
	InfobaseConnectionsClient.SetCompleteSignAllSessionsExceptCurrent(False);
	InfobaseConnectionsServerCall.AllowUsersWork();
	
	ParameterName = "StandardSubsystems.IBBackupParameters";
	If ApplicationParameters[ParameterName].ProcessIsRunning Then
		ApplicationParameters[ParameterName].ProcessIsRunning = False;
		InfobaseBackupServerCall.SetSettingValue("ProcessIsRunning", False);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "UserSessions" AND Parameter.NumberOfSessions <= 1
		AND ApplicationParameters["StandardSubsystems.IBBackupParameters"].ProcessIsRunning Then
			StartBackup();
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UsersListClick(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure PathToArchivesDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectedPath = GetPath(FileDialogMode.ChooseDirectory);
	If Not IsBlankString(SelectedPath) Then 
		Object.BackupDirectory = SelectedPath;
	EndIf;

EndProcedure

&AtClient
Procedure BackupFileNameOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	RunApp(BackupFileName);
	
EndProcedure

&AtClient
Procedure AutomaticBackupDecorationNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm(InfobaseBackupClient.BackupSettingsFormName());
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Next(Command)
	
	ClearMessages();
	
	If Not CheckAttributesFilling() Then
		Return;
	EndIf;
	
	AssistantCurrentPage = Items.AssistantPages.CurrentPage;
	If AssistantCurrentPage = Items.AssistantPages.ChildItems.BackupExecutionPage Then
		
		GoToPage(Items.InformationAndBackupPerformingPage);
		SetupArchiveWithBackupsPath(Object.BackupDirectory);
		
	Else
		
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure GoToEventLogMonitor(Command)
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", , ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure GoToPage(NewPage)
	
	SubordinatePages = Items.AssistantPages.ChildItems;
	If NewPage = SubordinatePages.InformationAndBackupPerformingPage Then
		GoToBackupInformationAndExecutionPage();
	ElsIf NewPage = SubordinatePages.PageOfErrorsOnCopying 
		OR NewPage = SubordinatePages.PageOfSucessfulCopyingCompletion Then
		GoToBackupResultsPage();
	EndIf;
		
	If NewPage <> Undefined Then
		Items.AssistantPages.CurrentPage = NewPage;
	Else
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToBackupInformationAndExecutionPage()
	
	ApplicationParameters["StandardSubsystems.IBBackupParameters"].ProcessIsRunning = True;
	InfobaseBackupServerCall.SetSettingValue("ProcessIsRunning", True);
	
	Items.Cancel.Enabled = True;
	Items.ActiveUserCount.Title = InfobaseSessionCount();
	SetTitleForButtonNext(True);
	Items.Next.Enabled = False;
	
	If Not CheckAttributesFilling(False) Then
		Items.AssistantPages.CurrentPage = Items.PageOfErrorsOnCopying;
		Return;
	EndIf;
	
	If InfobaseBackupClient.ValidateAccessToInformationBase(IBAdministratorPassword) Then
		SetBackupParameters();
	Else
		Items.AssistantPages.CurrentPage = Items.PageOfErrorsOnCopying;
		Return;
	EndIf;
	
	If InfobaseSessionCount() = 1 Then
		
		InfobaseConnectionsServerCall.SetConnectionLock(NStr("en='For a backup.';ru='Для выполнения резервного копирования.'"), "Backup");
		InfobaseConnectionsClient.SetCompleteSignAllSessionsExceptCurrent(True);
		InfobaseConnectionsClient.SetUserTerminationInProgressFlag(True);
		InfobaseConnectionsClient.TerminateThisSession(False);
		
		StartBackup();
		
	Else
		
		ClearMessages();
		
		CheckLockingSessionsPresence();
		
		InfobaseConnectionsServerCall.SetConnectionLock(NStr("en='For a backup.';ru='Для выполнения резервного копирования.'"), "Backup");
		InfobaseConnectionsClient.SetIdleHandlerOfUserSessionsTermination(True);
		SetBackupBeginIdleHandler();
		SetBackupTimeoutLapseIdleHandler();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckLockingSessionsPresence()
	
	InformationAboutLockingSessions = InfobaseConnections.InformationAboutLockingSessions("");
	LockSessionsPresent = InformationAboutLockingSessions.LockSessionsPresent;
	
	If LockSessionsPresent Then
		Items.ActiveSessionsDecoration.Title = InformationAboutLockingSessions.MessageText;
	EndIf;
	
	Items.ActiveSessionsDecoration.Visible = LockSessionsPresent;
	
EndProcedure

&AtClient
Procedure GoToBackupResultsPage()
	
	Items.Next.Visible= False;
	Items.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	Items.Cancel.DefaultButton = True;
	BackupParameters = BackupSettings();
	InfobaseBackupClient.FillInValuesOfGlobalVariables(BackupParameters);
	SetBackupResult();
	
EndProcedure

&AtServerNoContext
Procedure SetBackupResult()
	
	InfobaseBackupServer.SetBackupResult();
	
EndProcedure

&AtServer
Procedure SetBackupParameters()
	
	BackupParameters = InfobaseBackupServer.BackupSettings();
	
	BackupParameters.Insert("InfobaseAdministrator", InfobaseAdministrator);
	BackupParameters.Insert("IBAdministratorPassword", ?(PasswordEnterIsRequired, IBAdministratorPassword, ""));
	
	InfobaseBackupServer.SetBackupParameters(BackupParameters);
	
EndProcedure

&AtServerNoContext
Function BackupSettings()
	
	Return InfobaseBackupServer.BackupSettings();
	
EndFunction

&AtClient
Function CheckAttributesFilling(ShowError = True)
	
	AttributesFilled = True;
	
	If IsBlankString(Object.BackupDirectory) Then
		
		MessageText = NStr("en='Directory to backup copy is not chosen.';ru='Не выбран каталог для резервной копии.'");
		WriteAttributesCheckError(MessageText, "Object.BackupDirectory", ShowError);
		AttributesFilled = False;
		
	ElsIf FindFiles(Object.BackupDirectory).Count() = 0 Then
		
		MessageText = NStr("en='Non-existent directory is specified.';ru='Указан несуществующий каталог.'");
		WriteAttributesCheckError(MessageText, "Object.BackupDirectory", ShowError);
		AttributesFilled = False;
		
	Else
		
		Try
			TestFile = New XMLWriter;
			TestFile.OpenFile(Object.BackupDirectory + "/test.Test1C");
			TestFile.WriteXMLDeclaration();
			TestFile.Close();
		Except
			MessageText = NStr("en='No access to the backup directory';ru='Нет доступа к каталогу с резервными копиями.'");
			WriteAttributesCheckError(MessageText, "Object.BackupDirectory", ShowError);
			AttributesFilled = False;
		EndTry;
		
		If AttributesFilled Then
			
			Try
				DeleteFiles(Object.BackupDirectory, "*.Test1C");
			Except
				// Exception is not processed due to files are not deleted at this step.
			EndTry;
			
		EndIf;
		
	EndIf;
	
	If PasswordEnterIsRequired AND IsBlankString(IBAdministratorPassword) Then
		
		MessageText = NStr("en='Administrator password is not specified.';ru='Не задан пароль администратора.'");
		WriteAttributesCheckError(MessageText, "IBAdministratorPassword", ShowError);
		AttributesFilled = False;
		
	EndIf;
	
	Return AttributesFilled;
	
EndFunction

&AtClient
Procedure WriteAttributesCheckError(ErrorText, PathToAttribute, ShowError)
	
	If ShowError Then
		CommonUseClientServer.MessageToUser(ErrorText,, PathToAttribute);
	Else
		EventLogMonitorClient.AddMessageForEventLogMonitor(InfobaseBackupClient.EventLogMonitorEvent(),
			"Error", ErrorText, , True);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetBackupTimeoutLapseIdleHandler()
	
	AttachIdleHandler("TimeOutLapse", 300, True);
	
EndProcedure

&AtClient
Procedure TimeOutLapse()
	
	DetachIdleHandler("CheckThatConnectionIsSingle");
	QuestionText = NStr("en='Unable to disconnect all users from the base. Do you want to perform the backup? (errors are possible at the archivation)';ru='Не удалось отключить всех пользователей от базы. Провести резервное копирование? (возможны ошибки при архивации)'");
	ExplanationText = NStr("en='Failed to disable the user';ru='Не удалось отключить пользователя.'");
	NotifyDescription = New NotifyDescription("TimeOutWaitingEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, 30, DialogReturnCode.No, ExplanationText, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure TimeOutWaitingEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		StartBackup();
	Else
		ClearMessages();
		InfobaseConnectionsClient.SetCompleteSignAllSessionsExceptCurrent(False);
		CancelPreparation();
EndIf;
	
EndProcedure

&AtServer
Procedure CancelPreparation()
	
	Items.LabelItWasNotPossible.Title = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1.
		|Preparation for a backup is canceled. Infobase is locked.';ru='%1.
		|Подготовка к резервному копированию отменена. Информационная база разблокирована.'"),
		InfobaseConnections.EnabledSessionsMessage());
	Items.AssistantPages.CurrentPage = Items.PageOfErrorsOnCopying;
	Items.GoToEventLogMonitor1.Visible = False;
	Items.Next.Visible = False;
	Items.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	Items.Cancel.DefaultButton = True;
	
	InfobaseConnections.AllowUsersWork();
	
EndProcedure

&AtClient
Procedure SetBackupBeginIdleHandler()
	
	AttachIdleHandler("CheckThatConnectionIsSingle", 30);
	
EndProcedure

&AtClient
Procedure CheckThatConnectionIsSingle()
	
	UserCount = InfobaseSessionCount();
	Items.ActiveUserCount.Title = String(UserCount);
	If UserCount = 1 Then
		StartBackup();
	Else
		CheckLockingSessionsPresence();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetTitleForButtonNext(IsNextButton)
	
	Items.Next.Title = ?(IsNextButton, NStr("en='Next >';ru='Далее  >'"), NStr("en='Done';ru='Готово'"));
	
EndProcedure

&AtClient
Function GetPath(DialogMode)
	
	Mode = DialogMode;
	FileOpeningDialog = New FileDialog(Mode);
	If Mode = FileDialogMode.ChooseDirectory Then
		FileOpeningDialog.Title= NStr("en='Select the folder';ru='Выберите каталог'");
	Else
		FileOpeningDialog.Title= NStr("en='Select the file';ru='Выберите файл'");
	EndIf;	
		
	If FileOpeningDialog.Choose() Then
		If DialogMode = FileDialogMode.ChooseDirectory Then
			Return FileOpeningDialog.Directory;
		Else
			Return FileOpeningDialog.FullFileName;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Procedure StartBackup()
	
	ScriptMainFileName = GenerateUpdateScriptFiles();
	
	EventLogMonitorClient.AddMessageForEventLogMonitor(InfobaseBackupClient.EventLogMonitorEvent(),
		"Information",  NStr("en='Backup of infobase is carried out:';ru='Выполняется резервное копирование информационной базы:'") + " " + ScriptMainFileName);
		
	If Parameters.RunMode = "ExecuteNow" Or Parameters.RunMode = "ExecuteOnExit" Then
		InfobaseBackupClient.DeleteBackupsBySetting();
	EndIf;
	
	BackupExecuted = True;
	ForceCloseForm = True;
	Close();
	
	ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
	
	Exit(False);
	RunApp("""" + ScriptMainFileName + """",	InfobaseBackupClient.GetFileDir(ScriptMainFileName));
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Handlers of the form events on server and backup settings change.

&AtServerNoContext
Procedure SetupArchiveWithBackupsPath(Path)
	
	SettingsPath = InfobaseBackupServer.BackupSettings();
	SettingsPath.Insert("BackupStorageDirectoryOnManualLaunch", Path);
	InfobaseBackupServer.SetBackupParameters(SettingsPath);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of preparing the backup.

&AtClient
Function GenerateUpdateScriptFiles()
	
	BackupParameters = InfobaseBackupClient.ClientParametersOfBackup();
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	CreateDirectory(BackupParameters.UpdateTempFilesDir);
	
	// Structure of the parameters is required for defining them on client and passing to server.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ApplicationFileName"			, BackupParameters.ApplicationFileName);
	ParametersStructure.Insert("EventLogMonitorEvent"	, BackupParameters.EventLogMonitorEvent);
	ParametersStructure.Insert("COMConnectorName"			, ClientWorkParameters.COMConnectorName);
	ParametersStructure.Insert("ThisIsBasicConfigurationVersion"	, ClientWorkParameters.ThisIsBasicConfigurationVersion);
	ParametersStructure.Insert("FileInfobase"	, ClientWorkParameters.FileInfobase);
	ParametersStructure.Insert("ScriptParameters"				, InfobaseBackupClient.AdministratorAuthenticationParametersUpdate(IBAdministratorPassword));
	
	TemplateNames = "AdditionalBackupFile";
	TemplateNames = TemplateNames + ",BackupSplashScreen";
	TemplateTexts = GetTextsOfTemplates(TemplateNames, ParametersStructure, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[0]);
	
	ScriptFileName = BackupParameters.UpdateTempFilesDir + "main.js";
	ScriptFile.Write(ScriptFileName, TextEncoding.UTF16);
	
	// Helper file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[1]);
	ScriptFile.Write(BackupParameters.UpdateTempFilesDir + "helpers.js", TextEncoding.UTF16);
	
	ScriptMainFileName = Undefined;
	// Helper file: splash.png.
	PictureLib.ExternalActionSplash.Write(BackupParameters.UpdateTempFilesDir + "splash.png");
	// Helper file: splash.ico.
	PictureLib.ExternalActionSplashIcon.Write(BackupParameters.UpdateTempFilesDir + "splash.ico");
	// Helper file: progress.gif.
	PictureLib.LongOperation48.Write(BackupParameters.UpdateTempFilesDir + "progress.gif");
	// Main splash screen file: splash.hta.
	ScriptMainFileName = BackupParameters.UpdateTempFilesDir + "splash.hta";
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[2]);
	ScriptFile.Write(ScriptMainFileName, TextEncoding.UTF16);
	
	Return ScriptMainFileName;	
	
EndFunction

&AtServer
Function GetTextsOfTemplates(TemplateNames, ParametersStructure, MessagesForEventLogMonitor)
	
	// Write accumulated ELM events.
	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
		
	Result = New Array();
	Result.Add(GetScriptText(ParametersStructure));
	
	TemplateNamesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TemplateNames);
	
	For Each TemplateName IN TemplateNamesArray Do
		Result.Add(DataProcessors.InfobaseBackup.GetTemplate(TemplateName).GetText());
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function GetScriptText(ParametersStructure)
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.InfobaseBackup.GetTemplate("BackupFileTemplate");
	
	Script = ScriptTemplate.GetArea("ParameterArea");
	Script.DeleteLine(1);
	Script.DeleteLine(Script.LineCount());
	
	Text = ScriptTemplate.GetArea("BackupArea");
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount());
	
	Return InsertScriptParameters(Script.GetText(), ParametersStructure) + Text.GetText();
	
EndFunction

&AtServer
Function InsertScriptParameters(Val Text, Val ParametersStructure)
	
	Result = Text;
	FileNamesUpdate = "";
	FileNamesUpdate = "[" + "" + "]";
	
	InfobaseConnectionString = ParametersStructure.ScriptParameters.InfobaseConnectionString +
	ParametersStructure.ScriptParameters.ConnectionString; 
	
	ApplicationExecutableFileName = BinDir() + ParametersStructure.ApplicationFileName;
	
	// Define a path to infobase.
	FileModeFlag = Undefined;
	InformationBasePath = InfobaseConnectionsClientServer.InformationBasePath(FileModeFlag, 0);
	
	ParameterOfPathToInformationBase = ?(FileModeFlag, "/F", "/S") + InformationBasePath; 
	InfobasePathString	= ?(FileModeFlag, InformationBasePath, "");
	
	Result = StrReplace(Result, "[UpdateFilesNames]"				, FileNamesUpdate);
	Result = StrReplace(Result, "[ExecutedApplicationFileName]"		, PrepareText(ApplicationExecutableFileName));
	Result = StrReplace(Result, "[PathToInfobaseParameter]"		, PrepareText(ParameterOfPathToInformationBase));
	Result = StrReplace(Result, "[RowPathToInfobaseFile]"	, PrepareText(CommonUseClientServer.AddFinalPathSeparator(StrReplace(InfobasePathString, """", ""))));
	Result = StrReplace(Result, "[InfobaseConnectionString]"	, PrepareText(InfobaseConnectionString));
	Result = StrReplace(Result, "[UserAuthenticationParameters]"	, PrepareText(ParametersStructure.ScriptParameters.AuthenticationParameters));
	Result = StrReplace(Result, "[EventLogMonitorEvent]"			, PrepareText(ParametersStructure.EventLogMonitorEvent));
	Result = StrReplace(Result, "[EmailAddress]", "");
	Result = StrReplace(Result, "[CreateBackup]"				,"true");
	DirectoryRow = CheckDirectoryOnRootItemSpecifying(Object.BackupDirectory);
	
	Result = StrReplace(Result, "[DirectoryBackupCopies]"				,PrepareText(DirectoryRow+"\backup"+DirectoryRowFromDate()));
	Result = StrReplace(Result, "[RestoreInfobase]"	, "false");
	Result = StrReplace(Result, "[COMConnectorName]"					, PrepareText(ParametersStructure.COMConnectorName));
	Result = StrReplace(Result, "[UseCOMConnector]"			, ?(ParametersStructure.ThisIsBasicConfigurationVersion, "false", "true"));
	Result = StrReplace(Result, "[ExecuteOnExit]"			, ?(Parameters.RunMode = "ExecuteOnExit", "true", "false"));
	
	Return Result;
	
EndFunction

&AtServer
Function CheckDirectoryOnRootItemSpecifying(DirectoryRow)
	
	If Right(DirectoryRow, 2) = ":\" Then
		Return Left(DirectoryRow, StrLen(DirectoryRow) - 1) ;
	Else
		Return DirectoryRow;
	EndIf;
	
EndFunction

&AtServer
Function DirectoryRowFromDate()
	
	ReturnString = "";
	DateNow = CurrentSessionDate();
	ReturnString = Format(DateNow, "DF = yyyy_MM_dd_HH_mm_ss");
	Return ReturnString;
	
EndFunction

&AtServerNoContext
Function PrepareText(Val Text)
	
	Return "'" + StrReplace(Text, "\", "\\") + "'";
	
EndFunction

&AtClient
Procedure UpdateVersionLabelComponentsNavigationRefDataProcessor(Item, URL, StandardProcessing)
	StandardProcessing = False;
	CommonUseClient.RegisterCOMConnector();
EndProcedure

&AtServer
Function InfobaseSessionCount()
	
	Return InfobaseConnections.InfobaseSessionCount(False, False);
	
EndFunction

#EndRegion
