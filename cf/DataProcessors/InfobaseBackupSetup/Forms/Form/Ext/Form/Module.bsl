&AtClient
Var WriteSettings, MinimumDateOfNextAutomaticBackup;

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
		Raise NStr("en='Backup is not available in web client.';ru='Резервное копирование недоступно в веб-клиенте.'");
	EndIf;
	
	BackupSettings = InfobaseBackupServer.BackupSettings();
	
	Object.ExecutionVariant = BackupSettings.ExecutionVariant;
	Object.ExecuteAutomaticBackup = BackupSettings.ExecuteAutomaticBackup;
	Object.BackupIsConfigured = BackupSettings.BackupIsConfigured;
	
	If Not Object.BackupIsConfigured Then
		
		Object.ExecuteAutomaticBackup = True;
		
	EndIf;
	
	IBAdministratorPassword = BackupSettings.IBAdministratorPassword;
	Schedule = CommonUseClientServer.StructureIntoSchedule(BackupSettings.CopyingSchedule);
	Items.ChangeSchedule.Title = String(Schedule);
	Object.BackupDirectory = BackupSettings.DirectoryStorageOfBackupCopies;
	
	// Filling of settings for old copies storage.
	
	FillPropertyValues(Object, BackupSettings.DeletionParameters);
	
	UpdateBackupsDirectoryLimitationType(ThisObject);
	
	// First part of the check on server - if there are users in the infobase.
	PasswordEnterIsRequired = (InfobaseUsers.GetUsers().Count() > 0);
	
	Items.ChangeSchedule.Enabled = (Object.ExecutionVariant = "OnSchedule");
	Items.ParametersGroup.Enabled = Object.ExecuteAutomaticBackup;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClientServer.IsLinuxClient() Then
		Cancel = True;
		MessageText = NStr("en='Backup is not supported on the client running Linux OS.';ru='Резервное копирование не поддерживается в клиенте под управлением ОС Linux.'");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
	InfobaseBackupParameters = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	
	MinimumDateOfNextAutomaticBackup = InfobaseBackupParameters.MinimumDateOfNextAutomaticBackup;
	InfobaseBackupParameters.MinimumDateOfNextAutomaticBackup = '29990101';
	WriteSettings = False;
	
	UserInfo = StandardSubsystemsClientReUse.ClientWorkParameters().UserInfo;
	
	// Second part of the check on client - if current user
	// (administrator) uses standard authentication and the password is set.
	PasswordEnterIsRequired = PasswordEnterIsRequired AND UserInfo.StandardAuthentication AND UserInfo.PasswordIsSet;
	
	If PasswordEnterIsRequired Then
		InfobaseAdministrator = UserInfo.Name;
	Else
		Items.GroupAuthorization.Visible = False;
		Items.InfobaseAdministratorAuthorization.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not WriteSettings Then
		ParameterName = "StandardSubsystems.IBBackupParameters";
		ApplicationParameters[ParameterName].MinimumDateOfNextAutomaticBackup
			= MinimumDateOfNextAutomaticBackup;
	EndIf;
	
	Notify("BackupSettingsSessionFormClosed");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DirectoryLimitationTypeWithBackupsOnChange(Item)
	
	
	UpdateBackupsDirectoryLimitationType(ThisObject);
	
EndProcedure

&AtClient
Procedure PathToArchivesDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectedPath = GetPath(FileDialogMode.ChooseDirectory);
	If Not IsBlankString(SelectedPath) Then 
		Object.BackupDirectory = SelectedPath;
	EndIf;
	
EndProcedure

// Handler of transition to events log monitor.
&AtClient
Procedure LabelGoToEventLogMonitorClick(Item)
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", , ThisObject);
EndProcedure

&AtClient
Procedure BackupExecutionOptionOnChange(Item)
	
	Items.ChangeSchedule.Enabled = (Object.ExecutionVariant = "OnSchedule");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	
	WriteSettings = True;
	GoFromSetupPages();
	
EndProcedure

// Invokes standard form of scheduled job settings by filling it with current settings of back up schedule.
&AtClient
Procedure ChangeSchedule(Command)
	
	ScheduleDialog = New ScheduledJobDialog(Schedule);
	NotifyDescription = New NotifyDescription("ChangeScheduleEnd", ThisObject);
	ScheduleDialog.Show(NOTifyDescription);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure GoFromSetupPages()
	
	InfobaseBackupParameters = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	CurrentUser = UsersClientServer.CurrentUser();
	
	If Object.ExecuteAutomaticBackup Then
		
		If Not CheckDirectoryWithBackups() Then
			Return;
		EndIf;
		
		If Not InfobaseBackupClient.ValidateAccessToInformationBase(IBAdministratorPassword) Then
			Items.AssistantPages.CurrentPage = Items.AdditionalSettings;
			Return;
		EndIf;
		
		WriteSettings(CurrentUser);
		
		If Object.ExecutionVariant = "OnSchedule" Then
			CurrentDate = CommonUseClient.SessionDate();
			InfobaseBackupParameters.MinimumDateOfNextAutomaticBackup = CurrentDate;
			InfobaseBackupParameters.DateOfLastBackup = CurrentDate;
			InfobaseBackupParameters.ScheduleValue = Schedule;
		ElsIf Object.ExecutionVariant = "OnWorkCompletion" Then
			InfobaseBackupParameters.MinimumDateOfNextAutomaticBackup = '29990101';
		EndIf;
		
		InfobaseBackupClient.EnableBackupWaitHandler();
		
		SettingsFormName = "e1cib/app/%1";
		SettingsFormName = StringFunctionsClientServer.SubstituteParametersInString(SettingsFormName,
		InfobaseBackupClient.BackupSettingsFormName());
		
		ShowUserNotification(NStr("en='Backup';ru='Резервное копирование'"), SettingsFormName,
			NStr("en='Backup is set up.';ru='Резервное копирование настроено.'"));
		
	Else
		
		StopNotificationService(CurrentUser);
		InfobaseBackupClient.DisableBackupWaitHandler();
		InfobaseBackupParameters.MinimumDateOfNextAutomaticBackup = '29990101';
		
	EndIf;
	
	InfobaseBackupParameters.NotificationParameter = "DoNotNotify";
	
	RefreshReusableValues();
	Close();
	
EndProcedure

&AtClient
Function CheckDirectoryWithBackups()
	
	AttributesFilled = True;
	
	If IsBlankString(Object.BackupDirectory) Then
		
		MessageText = NStr("en='Backup directory is not selected.';ru='Не выбран каталог для резервной копии.'");
		CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
		
	ElsIf FindFiles(Object.BackupDirectory).Count() = 0 Then
		
		MessageText = NStr("en='Non-existing directory is specified.';ru='Указан несуществующий каталог.'");
		CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
		
	Else
		
		Try
			TestFile = New XMLWriter;
			TestFile.OpenFile(Object.BackupDirectory + "/test.Test1C");
			TestFile.WriteXMLDeclaration();
			TestFile.Close();
		Except
			MessageText = NStr("en='Cannot access directory with backups.';ru='Нет доступа к каталогу с резервными копиями.'");
			CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupDirectory");
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
		CommonUseClientServer.MessageToUser(MessageText,, "IBAdministratorPassword");
		AttributesFilled = False;
		
	EndIf;
	
	Return AttributesFilled;
	
EndFunction

// Asks the user the path to a file or a directory.
&AtClient
Function GetPath(DialogMode)
	
	Mode = DialogMode;
	FileOpeningDialog= New FileDialog(Mode);
	
	If Mode = FileDialogMode.ChooseDirectory Then
		FileOpeningDialog.Title= NStr("en='Select directory';ru='Выберите каталог'");
	Else
		FileOpeningDialog.Title= NStr("en='Select file';ru='Выберите файл'");
	EndIf;	
		
	If FileOpeningDialog.Choose() Then
		If DialogMode = FileDialogMode.ChooseDirectory Then
			Return FileOpeningDialog.Directory;
		Else
			Return FileOpeningDialog.FullFileName;
		EndIf;
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure StopNotificationService(CurrentUser)
	// Stops notifications about back up.
	BackupSettings = InfobaseBackupServer.BackupSettings();
	BackupSettings.ExecuteAutomaticBackup = False;
	BackupSettings.BackupIsConfigured = True;
	BackupSettings.MinimumDateOfNextAutomaticBackup = '29990101';
	InfobaseBackupServer.SetBackupParameters(BackupSettings, CurrentUser);
EndProcedure

&AtServer
Procedure WriteSettings(CurrentUser)
	
	BackupParameters = InfobaseBackupServer.BackupParameters();
	
	BackupParameters.Insert("InfobaseAdministrator", InfobaseAdministrator);
	BackupParameters.Insert("IBAdministratorPassword", ?(PasswordEnterIsRequired, IBAdministratorPassword, ""));
	BackupParameters.LastNotificationDate = Date('29990101');
	BackupParameters.DirectoryStorageOfBackupCopies = Object.BackupDirectory;
	BackupParameters.ExecutionVariant = Object.ExecutionVariant;
	BackupParameters.ExecuteAutomaticBackup = Object.ExecuteAutomaticBackup;
	BackupParameters.BackupIsConfigured = True;
	
	FillPropertyValues(BackupParameters.DeletionParameters, Object);
	
	If Object.ExecutionVariant = "OnSchedule" Then
		
		ScheduleStructure = CommonUseClientServer.ScheduleIntoStructure(Schedule);
		BackupParameters.CopyingSchedule = ScheduleStructure;
		
	ElsIf Object.ExecutionVariant = "OnWorkCompletion" Then
		
		BackupParameters.MinimumDateOfNextAutomaticBackup = '29990101';
		
	EndIf;
	
	InfobaseBackupServer.SetBackupParameters(BackupParameters, CurrentUser);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateBackupsDirectoryLimitationType(Form)
	
	Form.Items.SelectGroupTypeTreatment.Enabled = (Form.Object.RestrictionType <> "StoreAll");
	Form.Items.GroupStoreLastForPeriod.Enabled = (Form.Object.RestrictionType = "ByPeriod");
	Form.Items.GroupCopiesCountInDirectory.Enabled = (Form.Object.RestrictionType = "ByAmount");
	
EndProcedure

&AtClient
Procedure ChangeScheduleEnd(ScheduleResult, AdditionalParameters) Export
	
	If ScheduleResult = Undefined Then
		Return;
	EndIf;
	
	Schedule = ScheduleResult;
	Items.ChangeSchedule.Title = String(Schedule);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of backup.

&AtClient
Procedure ExecuteAutomaticBackupOnChange(Item)
	
	Items.ParametersGroup.Enabled = Object.ExecuteAutomaticBackup;
	
EndProcedure

#EndRegion
