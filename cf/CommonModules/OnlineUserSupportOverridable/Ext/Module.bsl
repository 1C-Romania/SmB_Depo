
////////////////////////////////////////////////////////////////////////////////
// The "Online User Support" subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Overridable procedures and general functions

// Overrides the possibility of using mechanism of Online support:
// monitor of Online support,
// authorization/registration in Online support service,
// receipt of unique identifier of electronic document flow
// subscriber, entry to personal account of electronic document flow subscriber.
//
// Use of Online support is prohibited when working in service model.
// Procedure is called for additional permissions check when
// working in local mode.
//
// To prohibit the use of Online
// support functions, it is required to set value Truth for parameter Denial.
// 
// Parameters:
// Cancel - Boolean - True, use of online support is prohibited;
// 	False - otherwise;
// 	Value by default - False;
//
// Example:
// If <Expression>
// 	Then Cancel = True;
// EndIf;
//
Procedure UseOnlineSupport(Cancel) Export
	
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for handling User online support events

// Gets called before authorization
// of the user in Online support for
// defining the current user data if login and password are not specified.
// Procedure is used ONLY if it is required
// to redefine login and password of an unauthorized
// user, for example, on the basis of login and password of update server user or otherwise.
//
// Parameters:
// UserData - Structure - output parameter - structure
// 	filled with data about the user of Online support:
// * Login - String - user's login;
// * Password - String - user's password;
//
// Example:
// Receipt of login and
// password of Online support user from user settings of
// update server for configurations with a builtin library "Library of standard subsystems" (LSS):
//
// Settings
// 	= GeneralUse.GeneralSettingsStorageImport
// 	("ConfigurationUpdate",
// "ConfigurationUpdateSettings" );
//
// If Settings =
// 	Undefined Then Return;
// Otherwise,
// 	UserData.Insert ("Login" , Settings.UpdateServerUserCode);
// 	UserData.Insert("Password", Settings.UpdatesServerPassword);
// EndIf;
//
Procedure OnDefineOnlineSupportUserData(UserData) Export
	
	Settings = CommonUse.CommonSettingsStorageImport(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions"
	);
	
	If Settings = Undefined Then
		Return;
	Else
		UserData.Insert("Login" , Settings.UpdateServerUserCode);
		UserData.Insert("Password", Settings.UpdatesServerPassword);
	EndIf;
	
EndProcedure

// Gets called at successful authorization
// of user in Online support after user enters correct login and password.
// When necessary the procedure can be used to save
// login and password of user in related mechanisms.
// Procedure completion is required ONLY
// when necessary to override processing of user login to Online support.
//
// Parameters:
// UserData - Structure - structure with fields:
// * Login - String - user's login;
// * Password - String - user's password;
//
// Example:
// Save user login and
// password of Online support in user settings of update
// server for configurations with a builtin library "Library of standard subsystems" (LSS):
//
// ConfigurationUpdateOptions
// 	=
// 	GeneralUse.GeneralSettingsStorageImport
// ("ConfigurationUpdate", "ConfigurationUpdateSettings" );
//
// If ConfigurationUpdateOptions =
// 	Undefined Then ConfigurationUpdateOptions = ConfigurationUpdateClientServer.NewConfigurationUpdateOptions();
// Otherwise,
// 	ConfigurationUpdateSettings.Insert ("UpdateServerUserCode" , UserData.Login);
// 	ConfigurationUpdateOptions.Insert("UpdatesServerPassword"          , UserData.Password);
// EndIf;
//
// CommonUse.GeneralSettingsStorageSave(
// 	"ConfigurationUpdate", 
// 	"ConfigurationUpdateSettings",
// 	ConfigurationUpdateSettings);
//
Procedure OnUserAuthorizationInInternetSupport(UserData) Export
	
	ConfigurationUpdateOptions = CommonUse.CommonSettingsStorageImport(
		"ConfigurationUpdate",
		"ConfigurationUpdateOptions"
	);
	
	If ConfigurationUpdateOptions = Undefined Then
		ConfigurationUpdateOptions = ConfigurationUpdateClientServer.NewConfigurationUpdateOptions();
	Else
		ConfigurationUpdateOptions.Insert("UpdateServerUserCode" , UserData.Login);
		ConfigurationUpdateOptions.Insert("UpdatesServerPassword"          , UserData.Password);
	EndIf;
	
	CommonUse.CommonSettingsStorageSave(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions",
		ConfigurationUpdateOptions);
	
EndProcedure

// Gets called when the
// user exits Online support (when user clicks "Exit" on the form of Online support).
//
// Procedure completion is required ONLY
// when necessary to override processing of user exit from Online support.
// When necessary it may be used to update
// user data in related mechanisms.
//
// Example:
// Clearance of login
// and password of Online support user in user settings
// of update server for configurations with a builtin library "Library of standard subsystems" (LSS):
//
// ConfigurationUpdateOptions
// 	=
// 	GeneralUse.GeneralSettingsStorageImport
// ("ConfigurationUpdate", "ConfigurationUpdateSettings" );
//
// If ConfigurationUpdateSettings <>
// 	Undefined Then ConfigurationUpdateSettings.Insert ("UpdateServerUserCode" , "");
// 	ConfigurationUpdateOptions.Insert("UpdatesServerPassword"          , "");
// 	CommonUse.GeneralSettingsStorageSave(
// 		"ConfigurationUpdate", 
// 		"ConfigurationUpdateSettings",
// 		ConfigurationUpdateSettings);
// EndIf;
//
Procedure WhenUserExitsOnlineSupport() Export
	
	ConfigurationUpdateOptions = CommonUse.CommonSettingsStorageImport(
		"ConfigurationUpdate",
		"ConfigurationUpdateOptions"
	);
	
	If ConfigurationUpdateOptions <> Undefined Then
		ConfigurationUpdateOptions.Insert("UpdateServerUserCode" , "");
		ConfigurationUpdateOptions.Insert("UpdatesServerPassword"          , "");
		CommonUse.CommonSettingsStorageSave(
			"ConfigurationUpdate", 
			"ConfigurationUpdateOptions",
			ConfigurationUpdateOptions);
	EndIf;
	
EndProcedure

#EndRegion
