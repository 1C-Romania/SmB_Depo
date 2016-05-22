////////////////////////////////////////////////////////////////////////////////
// Subsystem "Integration with 1C:Buhphone".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Procedure specifies item button properties when embedding to other subsystems.
//
Procedure NotificationProcessing(EventName, Item) Export
	
	If EventName = "Save1CBuhphoneSettings" Then
		SettingsUser = IntegrationWith1CBuhphoneServerCall.UserAccountSettings();
		Item.Visible = SettingsUser.ButtonVisibile1CBuhphone;
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

// It returns 1C-Buhphone file path in the Windows register.
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
	RegProv.GetStringValue("2147483649","Software\Buhphone","ApplicationPath",Value);
	
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
Procedure Select1CBuhphoneFile(ClosingAlert, PathToFile = "") Export
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ClosingAlert", ClosingAlert);
	AdditionalParameters.Insert("PathToFile", PathToFile);
	
	SuggestionText = NStr("en = 'To select 1C-Buhphone application you shall install the file work extension.'");
	Notification = New NotifyDescription("Select1CBuhphoneFileAfterExtensionInstallation", ThisObject, AdditionalParameters);
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(Notification, SuggestionText, False);
EndProcedure

// Procedure continued (see above).
Procedure Select1CBuhphoneFileAfterExtensionInstallation(Attached, AdditionalParameters) Export
	
	If Not Attached Then
		ExecuteNotifyProcessing(AdditionalParameters.ClosingAlert, "");
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Title = NStr("en = 'Select the executable 1C-Buhphone file'");
	Dialog.FullFileName = AdditionalParameters.PathToFile;
	Folder = CommonUseClientServer.SplitFullFileName(AdditionalParameters.PathToFile);
	Dialog.Directory = Folder.Path;
	Filter = NStr("en = 'buhphone.exe (*.exe)|*.exe'");
	Dialog.Filter = Filter;
	Dialog.Multiselect = False;
	
	Notification = New NotifyDescription("Select1CBuhphoneFileEnd", ThisObject, AdditionalParameters);
	Dialog.Show(Notification);
	
EndProcedure

// Procedure continued (see above).
Procedure Select1CBuhphoneFileEnd(SelectedFiles, AdditionalParameters) Export
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
Procedure FilePresence1CBuhphone(ClosingAlert, Path)
	Notification = New NotifyDescription("FilePresence1CBuhphoneAfterFileInitialization", ThisObject, ClosingAlert);
	CheckedFile = New File();
	CheckedFile.BeginInitialization(Notification, Path);
EndProcedure

// Procedure continued (see above).
Procedure FilePresence1CBuhphoneAfterFileInitialization(File, ClosingAlert) Export
	Notification = New NotifyDescription("FilePresence1CBuhphoneAfterCheckingExistence", ThisObject, ClosingAlert);
	File.StartExistenceCheck(Notification);
EndProcedure

// Procedure continued (see above).
Procedure FilePresence1CBuhphoneAfterCheckingExistence(Exists, ClosingAlert) Export
	ExecuteNotifyProcessing(ClosingAlert, Exists);
EndProcedure

// Procedure runs 1C-Buhphone executable file.
// If 1C-Buhphone file is absent, it opens the form of searching path to the executable file.
//
Procedure Run1CBuhphone() Export
	
	If Not IsWindowsClient() Then
		ShowMessageBox(,NStr("en = 'To work with the 1C-Buhphon application, you need to have Microsoft Windows operating system.'"));
		Return
	EndIf;
	
	Notification = New NotifyDescription("Run1CBuhphoneAfterExtensionInstallation", ThisObject);
	MessageText = NStr("en = 'To start 1C-Buhphone, you shall install the file work extension.'");
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(Notification, MessageText, False);
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CBuhphoneAfterExtensionInstallation(ExtensionAttached, AdditionalParameters) Export
	
	If Not ExtensionAttached Then
		Return;
	EndIf;
	
	// Define start parameters.
	ClientID = ClientID();
	PathFromRegister = PathToExecutableFileFromWindowsRegistry();
	PathFromStorage = IntegrationWith1CBuhphoneServerCall.ExecutableFileLocation(ClientID);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("PathFromRegister", PathFromRegister);
	AdditionalParameters.Insert("PathFromStorage", PathFromStorage);
	
	Notification = New NotifyDescription("Run1CBuhphoneAfterCheckingPathFromRegister", ThisObject, AdditionalParameters);
	FilePresence1CBuhphone(Notification, PathFromRegister);
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CBuhphoneAfterCheckingPathFromRegister(PathFromRegisterIsCorrect, AdditionalParameters) Export
	
	AdditionalParameters.Insert("PathFromRegisterIsCorrect", PathFromRegisterIsCorrect);
	Notification = New NotifyDescription("Run1CBuhphoneAfterCheckingPathFromStorage", ThisObject, AdditionalParameters);
	FilePresence1CBuhphone(Notification, AdditionalParameters.PathFromStorage);
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CBuhphoneAfterCheckingPathFromStorage(PathFromStorageIsCorrect, AdditionalParameters) Export
	
	UserAccount = IntegrationWith1CBuhphoneServerCall.UserAccountSettings();
	StartParameters1CBuhphone = " /StartedFrom1CConf";
	
	Notification = New NotifyDescription("Run1CBuhphoneAfterApplicationStart", ThisObject);
	If UserAccount.UseLP Then
		
		If UserAccount.Login <> "" AND UserAccount.Password <> "" Then
			StartParameters1CBuhphone = StartParameters1CBuhphone + " /login:" + UserAccount.Login + " /password:" + UserAccount.Password;
		EndIf;
		
		If PathFromStorageIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromStorage + StartParameters1CBuhphone);
			Return;
		EndIf;
		
		If AdditionalParameters.PathFromRegisterIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromRegister + StartParameters1CBuhphone);
			Return;
		EndIf;
		
	Else
		
		If PathFromStorageIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromStorage + StartParameters1CBuhphone);
			Return;
		EndIf;
		
		If AdditionalParameters.PathFromRegisterIsCorrect Then
			BeginRunningApplication(Notification, AdditionalParameters.PathFromRegister + StartParameters1CBuhphone);
			Return;
		EndIf;
		
	EndIf;
	
	OpenForm("CommonForm.SearchExecutableFile1CBuhfon");
	
EndProcedure

// Procedure continued (see above).
Procedure Run1CBuhphoneAfterApplicationStart(ReturnCode, AdditionalParameters) Export
	// No processing is required.
EndProcedure

#EndRegion