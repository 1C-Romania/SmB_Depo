////////////////////////////////////////////////////////////////////////////////
// Subsystem "Integration with 1C:Connect".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// It receives the path to the executable file from the data register.
// 		
// Parameters:
// 	ClientID	- UUID - ID of 1C client (software).
// 		
// ReturnValue:
// 		String   - Path to the executable file on the current user PC.
//
Function ExecutableFileLocation(ClientID) Export
	
	Return CommonSettingsStorage.Load("ExecuteFilesPaths1CConnect", ClientID);
	
EndFunction

// It receives parameters to start 1C-Connect application from the data register.
//
// Parameters:
// 	User  - UUID - Current infobase user.
//
// ReturnValue:
// 	Structure  - User settings to start 1C-Connect application.
//
Function UserAccountSettings() Export 
	
	SettingsUser = IntegrationWith1CConnect.SettingsUser();
	UserSettingsStorage = CommonSettingsStorage.Load("UserAccounts1CConnect", "CredentialsSettings");
	
	If Not UserSettingsStorage = Undefined Then
		SettingsUser.Login 					= UserSettingsStorage.Login;
		SettingsUser.Password 					= UserSettingsStorage.Password;
		SettingsUser.UseLP 			= UserSettingsStorage.UseLP;
		SettingsUser.ButtonVisibile1CConnect 	= UserSettingsStorage.ButtonVisibile1CConnect;	
	EndIf;
	
	Return SettingsUser;
	
EndFunction
	
#EndRegion