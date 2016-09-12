
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseClientServer.ThisIsWebClient() Then
		Raise NStr("en='Backing up is not available in web-client.';ru='Резервное копирование недоступно в веб-клиенте.'");
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return; // Fail is set in OnOpen().
	EndIf;
	
	BackupParameters = InfobaseBackupServer.BackupParameters();
	DisableReminders = BackupParameters.BackupIsConfigured;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClientServer.IsLinuxClient() Then
		Cancel = True;
		MessageText = NStr("en='Backup is not supported in the client under Linux OS.';ru='Резервное копирование не поддерживается в клиенте под управлением ОС Linux.'");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ApplicationParameters["StandardSubsystems.IBBackupParameters"].NotificationParameter =
		?(DisableReminders, "DoNotNotify", "YetNotConfigured");
	
	If DisableReminders Then
		InfobaseBackupClient.DisableBackupWaitHandler();
	Else
		InfobaseBackupClient.EnableBackupWaitHandler();
	EndIf;
	
	OKOnServer();
	Notify("BackupSettingsSessionFormClosed");
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OKOnServer()
	
	BackupParameters = InfobaseBackupServer.BackupParameters();
	
	BackupParameters.BackupIsConfigured = DisableReminders;
	BackupParameters.ExecuteAutomaticBackup = False;
	
	InfobaseBackupServer.SetBackupParameters(BackupParameters);
	
EndProcedure

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
