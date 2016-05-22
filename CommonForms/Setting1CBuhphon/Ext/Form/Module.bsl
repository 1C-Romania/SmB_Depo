#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
   	
	// Filling of the form items according to previous settings of the current user.
	Result = IntegrationWith1CBuhphoneServerCall.UserAccountSettings();
	ButtonVisible = Result.ButtonVisibile1CBuhphone;
	SaveLoginPassword = Result.UseLP;	
	Items.Login.Enabled = Result.UseLP;
	Items.Password.Enabled = Result.UseLP;
	Login = Result.Login;
	Password = Result.Password;
	SystemInfo = New SystemInfo;
	ClientID = SystemInfo.ClientID;
	PathToFile = IntegrationWith1CBuhphoneServerCall.ExecutableFileLocation(ClientID);
	
	InitFormItems(ThisForm);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IntegrationWith1CBuhphoneClient.IsWindowsClient() Then
		ShowMessageBox(,NStr("en = 'To work with the 1C-Buhphon application, you need to have Microsoft Windows operating system.'"));
		Cancel = True;		
	EndIf;
	If PathToFile="" Then
		PathToFile = IntegrationWith1CBuhphoneClient.PathToExecutableFileFromWindowsRegistry();
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SaveLoginPasswordOnChange(Item)
	 
	Access = SaveLoginPassword;
	Items.Login.Enabled = Access;
	Items.Password.Enabled = Access;
	
EndProcedure

&AtClient
Procedure ButtonVisibleOnChange(Item)
	InitFormItems(ThisForm);		
EndProcedure

&AtClient
Procedure FilePathStartChoice(Item, ChoiceData, StandardProcessing)
	Notification = New NotifyDescription("PathToFileStartChoiceEnd", ThisObject);
	IntegrationWith1CBuhphoneClient.Select1CBuhphoneFile(Notification, PathToFile);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Save(Command)
	
	ClientID = IntegrationWith1CBuhphoneClient.ClientID();	
	SaveUserSettingsToStorage(Login, Password, SaveLoginPassword, ButtonVisible);
	NewPathToExecutableFile(ClientID, PathToFile);
	// Inform the button form to manage button visible.
	Notify("Save1CBuhphoneSettings");
    OnSettingsChange();
	RefreshInterface();
	Close();
	
EndProcedure

&AtClient
Procedure Get1CBuhfonAccount(Command)
	
	GotoURL("");
	
EndProcedure

&AtClient
Procedure TechnicalRequirements(Command)
	
	GotoURL("");
	
EndProcedure

&AtClient
Procedure ExportApplication(Command)
	
	GotoURL("");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure NewPathToExecutableFile(ClientID, PathToFile)
	IntegrationWith1CBuhphone.Save1CBuhphoneExecutableFileLocation(ClientID, PathToFile);
EndProcedure 

&AtServerNoContext
Procedure SaveUserSettingsToStorage(Login, 
										 Password, 
										 SaveLoginPassword,
										 ButtonVisible)
																
	IntegrationWith1CBuhphone.SaveUserSettingsToStorage(Login, Password, SaveLoginPassword, ButtonVisible);

EndProcedure 

&AtServerNoContext
Procedure OnSettingsChange()
	IntegrationWith1CBuhphoneOverridable.OnSettingsChange();
EndProcedure

// Initializes form items according to
// 1C Buhphone settings.
//
&AtClientAtServerNoContext
Procedure InitFormItems(Form)
	
	Form.Items.GroupLaunchParameters.Enabled = Form.ButtonVisible;
	
EndProcedure

&AtClient
Procedure PathToFileStartChoiceEnd(NewPathToFile, AdditionalParameters) Export
	If NewPathToFile <> "" Then
		PathToFile = NewPathToFile;
	EndIf;
EndProcedure

#EndRegion



