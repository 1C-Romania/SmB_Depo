////////////////////////////////////////////////////////////////////////////////
// Subsystem "Integration with 1C:Buhphone".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Procedure specifies item button properties when embedding to other subsystems.
//
Procedure OnCreateAtServer(Item) Export
	
	SettingsUser = IntegrationWith1CBuhphoneServerCall.UserAccountSettings();
	Item.Visible = SettingsUser.ButtonVisibile1CBuhphone;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2  Then
		Item.Width = 20;
		Item.Height = 3;
	Else
		Item.Width = 16;
		Item.Height = 3;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
//
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
	"IntegrationWith1CBuhphone");
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "IntegrationWith1CBuhphone.InitialFilling";		
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// It writes the 1C-Buhphone executable file path to the data register. 
// Storage of paths to executable files is for each PC, client ID
// is used to define PC as you can not use the ComputerName function in the web client.
//
// Parameters:
// 	ClientID	- UUID - ID of 1C client (software).
//	 NewFileLocation - String - Path to the executable file on the PC on which 1C client is running.
Procedure Save1CBuhphoneExecutableFileLocation(ClientID, NewFileLocation) Export 
	
	CurrentFileLocation = IntegrationWith1CBuhphoneServerCall.ExecutableFileLocation(ClientID);

	If CurrentFileLocation = NewFileLocation Then
		Return;	
	EndIf;

	CommonSettingsStorage.Save("ExecuteFilesPaths1CBuhphone", ClientID, NewFileLocation);
	
EndProcedure

// It writes settings of user accounts to the data register to start 1C-Buhphone application.
//
// Parameters:
// 		User      - UUID   - Current infobase user.
// 		Login			- String - Data of 1C-Buhphone application account.
// 		Password	- String - Data of 1C-Buhphone application account.
// 	UseLP  		- Boolean - If the value is False, Parameters Login Password are not available.
// 	ButtonVisibile1CBuhphone - Boolean - Showing 1C-Buhphone start button on the home page.
//
Procedure SaveUserSettingsToStorage(Login, 
										 Password, 
										 UseLP, 
										 ButtonVisibile1CBuhphone) Export
		
	SettingsUser = SettingsUser();
	SettingsUser.Login 					= Login;
	SettingsUser.Password 					= Password;
	SettingsUser.UseLP 			= UseLP;
	SettingsUser.ButtonVisibile1CBuhphone 	= ButtonVisibile1CBuhphone;		
	
	CommonSettingsStorage.Save("UserAccounts1CBuhphone", "CredentialsSettings", SettingsUser);
	
EndProcedure

Function SettingsUser() Export
	
	SettingsUser = New Structure();
	SettingsUser.Insert("Login", "");
	SettingsUser.Insert("Password","");
	SettingsUser.Insert("UseLP",False);
	SettingsUser.Insert("ButtonVisibile1CBuhphone",False);	
	
	Return SettingsUser;
	
EndFunction

Procedure InitialFilling() Export
	Constants.UseIntegrationWith1CBuhphone.Set(True);	
EndProcedure
	
#EndRegion