////////////////////////////////////////////////////////////////////////////////
// Subsystem "Integration with 1C:Connect".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Procedure specifies item button properties when embedding to other subsystems.
//
Procedure NotificationProcessing(EventName, Item) Export
	
	If EventName = "Save1CConnectSettings" Then
		SettingsUser = IntegrationWith1CConnectServerCall.UserAccountSettings();
		Item.Visible = SettingsUser.ButtonVisibile1CConnect;
	EndIf;
	
EndProcedure

#EndRegion 

#Region ServiceProceduresAndFunctions

// It returns the unique identifier of the 1C client (annex).
Function ClientID() Export
	
	SystemInfo = New SystemInfo;
	ClientID = SystemInfo.ClientID;
	Return ClientID;
	
EndFunction

// It returns 1C-Connect file path in the Windows register.
// 
Function PathToExecutableFileFromWindowsRegistry() Export
	
	Value = "";
	
	If Not IsWindowsClient() Then
		Return Value;
	EndIf;
	
#If WebClient Then
	ValueFromRegister = "";
#Else
	RegProv = GetCOMObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv");
	RegProv.GetStringValue("2147483649","Software\Connect","ApplicationPath",Value);
	
	If Value = "" Or  Value = NULL Then
		ValueFromRegister = "";
	Else
		ValueFromRegister = Value;
	EndIf;
	
	Return ValueFromRegister;
#EndIf
	
EndFunction

// It returns True if the client application is running under Windows OS.
//
// Returns:
//  Boolean. If there is no client application, it returns False.
//
Function IsWindowsClient() Export
	
	SystemInfo = New SystemInfo;
	
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
	OR SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
	Return IsWindowsClient;
	
EndFunction

// Popup window to select the file.
//
// Returns:
//		String  - Path to the executable file.
Procedure Select1CConnectFile(ClosingAlert, PathToFile = "") Export
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ClosingAlert", ClosingAlert);
	AdditionalParameters.Insert("PathToFile", PathToFile);
	
	SuggestionText = NStr("en='To select 1C-Connect application you shall install the file work extension.';ru='Для выбора приложения 1С-Коннект необходимо установить расширение работы с файлами.'");
	Notification = New NotifyDescription("Select1CConnectFileAfterExtensionInstallation", ThisObject, AdditionalParameters);
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
EndProcedure

// Procedure continued (see above).
Procedure Select1CConnectFileAfterExtensionInstallation(Attached, AdditionalParameters) Export
	
	If Not Attached Then
		ExecuteNotifyProcessing(AdditionalParameters.ClosingAlert, "");
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Title = NStr("en='Select the executable 1C-Connect file';ru='Выберите исполняемый файл 1С-Коннект'");
	Dialog.FullFileName = AdditionalParameters.PathToFile;
	Folder = CommonUseClientServer.SplitFullFileName(AdditionalParameters.PathToFile);
	Dialog.Directory = Folder.Path;
	Filter = NStr("en='connect.exe (*.exe)|*.exe';ru='сonnect.exe (*.exe)|*.exe'");
	Dialog.Filter = Filter;
	Dialog.Multiselect = False;
	
	Notification = New NotifyDescription("Select1CConnectFileEnd", ThisObject, AdditionalParameters);
	Dialog.Show(Notification);
	
EndProcedure

// Procedure continued (see above).
Procedure Select1CConnectFileEnd(SelectedFiles, AdditionalParameters) Export
	If SelectedFiles <> Undefined AND SelectedFiles.Count() > 0 Then
		ExecuteNotifyProcessing(AdditionalParameters.ClosingAlert, SelectedFiles[0]);
	Else
		ExecuteNotifyProcessing(AdditionalParameters.ClosingAlert, "");
	EndIf;
EndProcedure

// It checks the availability of executable file by specified path.
//
// Returns:
// 		Boolean  - If True, the file will run based on specified path.
//
Procedure FilePresence1CConnect(ClosingAlert, Path)
	Notification = New NotifyDescription("FilePresence1CConnectAfterFileInitialization", ThisObject, ClosingAlert);
	CheckedFile = New File();
	CheckedFile.BeginInitialization(Notification, Path);
EndProcedure

// Procedure continued (see above).
Procedure FilePresence1CConnectAfterFileInitialization(File, ClosingAlert) Export
	Notification = New NotifyDescription("FilePresence1CConnectAfterCheckingExistence", ThisObject, ClosingAlert);
	File.StartExistenceCheck(Notification);
EndProcedure

// Procedure continued (see above).
Procedure FilePresence1CConnectAfterCheckingExistence(Exists, ClosingAlert) Export
	ExecuteNotifyProcessing(ClosingAlert, Exists);
EndProcedure

// Procedure runs 1C-Connect executable file.
// If 1C-Connect file is absent, it opens the form of searching path to the executable file.
//
Procedure Run1CConnect() Export
	
	If Not IsWindowsClient() Then
		ShowMessageBox(,NStr("en='To work with the 1C-Connect application, you need to have Microsoft Windows operating system.';ru='Для работы с приложением 1С-Коннект необходима операционная система Microsoft Windows.'"));
		Return
	EndIf;
	
	Notification = New NotifyDescription("Run1CConnectAfterExtensionInstallation", ThisObject);
	MessageText = NStr("en='To start 1C-Connect, you shall install the file work extension.';ru='Для запуска 1С-Коннект необходимо установить расширение работы с файлами.'");
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, MessageText, False);
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CConnectAfterExtensionInstallation(ExtensionAttached, AdditionalParameters) Export
	
	If Not ExtensionAttached Then
		Return;
	EndIf;
	
	// Define start parameters.
	ClientID = ClientID();
	PathFromRegister = PathToExecutableFileFromWindowsRegistry();
	PathFromStorage = IntegrationWith1CConnectServerCall.ExecutableFileLocation(ClientID);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("PathFromRegister", PathFromRegister);
	AdditionalParameters.Insert("PathFromStorage", PathFromStorage);
	
	Notification = New NotifyDescription("Run1CConnectAfterCheckingPathFromRegister", ThisObject, AdditionalParameters);
	FilePresence1CConnect(Notification, PathFromRegister);
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CConnectAfterCheckingPathFromRegister(PathFromRegisterIsCorrect, AdditionalParameters) Export
	
	AdditionalParameters.Insert("PathFromRegisterIsCorrect", PathFromRegisterIsCorrect);
	Notification = New NotifyDescription("Run1CConnectAfterCheckingPathFromStorage", ThisObject, AdditionalParameters);
	FilePresence1CConnect(Notification, AdditionalParameters.PathFromStorage);
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CConnectAfterCheckingPathFromStorage(PathFromStorageIsCorrect, AdditionalParameters) Export
	
	UserAccount = IntegrationWith1CConnectServerCall.UserAccountSettings();
	StartParameters1CConnect = " /StartedFrom1CConf";
	
	Notification = New NotifyDescription("Run1CConnectAfterApplicationStart", ThisObject);
	If UserAccount.UseLP Then
		
		If UserAccount.Login <> "" AND UserAccount.Password <> "" Then
			StartParameters1CConnect = StartParameters1CConnect + " /login:" + UserAccount.Login + " /password:" + UserAccount.Password;
		EndIf;
		
		If PathFromStorageIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromStorage + StartParameters1CConnect);
			Return;
		EndIf;
		
		If AdditionalParameters.PathFromRegisterIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromRegister + StartParameters1CConnect);
			Return;
		EndIf;
		
	Else
		
		If PathFromStorageIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromStorage + StartParameters1CConnect);
			Return;
		EndIf;
		
		If AdditionalParameters.PathFromRegisterIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromRegister + StartParameters1CConnect);
			Return;
		EndIf;
		
	EndIf;
	
	OpenForm("CommonForm.SearchExecutableFile1CConnect");
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CConnectAfterApplicationStart(ReturnCode, AdditionalParameters) Export
	// No processing is required.
EndProcedure

#EndRegion