////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Overrides the standard method of setting roles to IB users.
//
// Parameters:
//  Prohibition - Boolean - if you set True,
//           roles change is locked (for administrator as well).
//
Procedure ChangeRoleEditProhibition(Prohibition) Export
	
EndProcedure

// Overrides the behavior of user form
// and external user form, external users group.
//
// Parameters:
//  Refs - CatalogRef.Users,
//           CatalogRef.ExternalUsers,
//           CatalogRef.ExternalUsersGroups - ref
//           to user, external user or external users group when the form is created.
//
//  ActionsInForm - Structure - with properties:
//         * Roles                   - String - "", "view",     "Edit".
//         * ContactInformation   - String - "", "view",     "Edit".
//         * InfobaseUserProperties - String - "", "view",     "Edit".
//         * ItemProperties       - String - "", "View", "Edit".
//           
//           For external users group ContactInfo and InfobaseUserProperties do not exist.
//
Procedure ChangeActionsInForm(Val Refs, Val ActionsInForm) Export
	
EndProcedure

// Defines actions while writing infobase user.
//  Called from the WriteIBUser() procedure if user is really changed.
//
// Parameters:
//  OldProperties - Structure - see parameters returned by the Users.ReadIBUser() function.
//  NewProperties  - Structure - see parameters returned by the Users.WriteIBUser() function.
//
Procedure OnWriteOfInformationBaseUser(Val OldProperties, Val NewProperties) Export
	
EndProcedure

// Defines actions after deleting infobase user.
//  Called from the DeleteIBUser procedure if user is really changed.
//
// Parameters:
//  OldProperties - Structure - see parameters returned by the Users.ReadIBUser() function.
//
Procedure AfterInfobaseUserDelete(Val OldProperties) Export
	
EndProcedure

// Overrides interface settings set for new users.
//
// Parameters:
//  InitialSettings - Structure - settings by defauls:
//   * ClientSettings    - ClientSettings           - client application settings.
//   * InterfaceSettings - CommandInterfaceSettings            - command interface settings
//                                                                      (sections panels, navigation panels, actions panels).
//   * TaxiSettings      - ClientApplicationInterfaceSettings - client application interface
//                                                                      settings (panel content and location).
//
Procedure WithInstallationOfInitialSettings(InitialSettings) Export
	
	InitialSettings.InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.PictureAndText;
	InitialSettings.SettingsClient.ClientApplicationInterfaceVariant = ClientApplicationInterfaceVariant.Taxi;
	
	If InitialSettings.TaxiSettings <> Undefined Then
		ContentSettings = New ClientApplicationInterfaceContentSettings;
		GroupLeft = New ClientApplicationInterfaceContentSettingsGroup;
		GroupLeft.Add(New ClientApplicationInterfaceContentSettingsItem("ToolsPanel"));
		GroupLeft.Add(New ClientApplicationInterfaceContentSettingsItem("SectionsPanel"));
		ContentSettings.Top.Add(New ClientApplicationInterfaceContentSettingsItem("OpenItemsPanel"));
		ContentSettings.Left.Add(GroupLeft);
		InitialSettings.TaxiSettings.SetContent(ContentSettings);
	EndIf;
	
EndProcedure

// Expands the list of passed user settings on the "Other" tab of UsersSettings processor.
//
// Parameters:
//  UserInfo - Structure - String and reference presentation of a user.
//       * UserRef  - CatalogRef.Users - user
//                               whose settings should be received.
//       * InfobaseUserName - String - infobase user
//                                             whose settings need to be received.
//  Settings - Structure - other user settings.
//       * Key     - String - setting string ID used for
//                             copying and clearing this setting.
//       * Value - Structure - information about setting.
//              ** SettingName  - String - name that will be displayed in the settings tree.
//              ** SettingPicture  - Picture - picture that will be displayed in the settings tree.
//              ** SettingsList     - ValueList - list of received settings.
//
Procedure OnReceiveOtherSettings(UserInfo, Settings) Export
	
	// Receive AskConfirmationOnApplicationExit setting value.
	SettingValue = CommonUse.CommonSettingsStorageImport("UserCommonSettings", 
		"AskConfirmationOnExit",,, UserInfo.InfobaseUserName);
	If SettingValue <> Undefined Then
		
		ListSettingValues = New ValueList;
		ListSettingValues.Add(SettingValue);
		
		InformationAboutSetting    = New Structure;
		InformationAboutSetting.Insert("SettingName", NStr("en='Confirmation on closing the application';ru='Подтверждение при завершении программы'"));
		InformationAboutSetting.Insert("SettingPicture", "");
		InformationAboutSetting.Insert("SettingsList", ListSettingValues);
		
		Settings.Insert("AskConfirmationOnClose", InformationAboutSetting);
	EndIf;
	
EndProcedure

// Saves settings for the passed user.
//
// Parameters:
//  Settings             - ValueList - list of saved settings values.
//  UserInfo - Structure - String and reference presentation of a user.
//       * UserRef - CatalogRef.Users - user
//                              to whome you should copy setting.
//       * InfobaseUserName - String - infobase user
//                                             to whome a setting should be copied.
//
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	If Settings.SettingID = "AskConfirmationOnClose" Then
		SettingValue = Settings.SettingValue[0];
		CommonUse.CommonSettingsStorageSave(
			"UserCommonSettings", "AskConfirmationOnExit",
			SettingValue.Value,, UserInfo.InfobaseUserName);
	EndIf;
	
EndProcedure

// Clears settings for the passed user.
//
// Parameters:
//  Settings             - ValueList - cleared settings values.
//  UserInfo - Structure - String and reference presentation of a user.
//       * UserRef - CatalogRef.Users - user
//                              whose setting should be cleared.
//       * InfobaseUserName - String - infobase user
//                                             whose setting should be cleared.
//
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	If Settings.SettingID = "AskConfirmationOnClose" Then
		CommonUse.CommonSettingsStorageDelete(
			"UserCommonSettings", "AskConfirmationOnExit",
			UserInfo.InfobaseUserName);
	EndIf;
		
EndProcedure

#EndRegion

#Region ServiceInterfaceSB

Procedure LinkUserToEmployee(User) Export
	
	If User.NotValid 
		OR User.Service Then
		
		Return;
		
	EndIf;
	
	LinkedUsersTable = SmallBusinessServer.GetUserEmployees(User);
	
	If LinkedUsersTable.Count() = 0 Then
		
		FoundUser = Catalogs.Employees.FindByDescription(User.Description, True);
		If ValueIsFilled(FoundUser) Then
			
			Employee = FoundUser;
			
		Else
			
			NewEmployeeData = New Structure;
			NewEmployeeData.Insert("Description", User.Description);
			NewEmployeeData.Insert("OccupationType", Enums.OccupationTypes.MainWorkplace);
			NewEmployeeData.Insert("SettlementsHumanResourcesGLAccount", ChartsOfAccounts.Managerial.PayrollPaymentsOnPay);
			NewEmployeeData.Insert("AdvanceHoldersGLAccount", ChartsOfAccounts.Managerial.AdvanceHolderPayments);
			NewEmployeeData.Insert("OverrunGLAccount", ChartsOfAccounts.Managerial.OverrunOfAdvanceHolders);
			
			Employee = Catalogs.Employees.CreateNewEmployee(NewEmployeeData);
			
		EndIf;
		
		// If item is not written, Employee = Undefined;
		If ValueIsFilled(Employee) Then
		
			DataMap = New Map();
			DataMap.Insert(Employee, User);
			
			InformationRegisters.UserEmployees.AddUsersEmployees(DataMap);
			
		Else
			
			Return;
			
		EndIf;
		
	Else
		
		Employee = LinkedUsersTable[0].Employee;
		
	EndIf;
	
	Catalogs.Employees.SetMainResponsibleForUser(Employee, User);
	
EndProcedure

Procedure UserOnWrite(Source, Cancel) Export
	
	// It is required to create the link Employee
	// <-> User for all users This link is needed for filling the Responsible in documents field
	If Source.DataExchange.Load = True Then
		
		Return;
		
	EndIf;
	
	User = Source.Ref;
	If Not ValueIsFilled(User) Then
		
		Return;
		
	EndIf;
	
	LinkUserToEmployee(User);
	
EndProcedure

Function AllowInfobaseStartWithoutUsers() Export
	Return False;
EndFunction

Procedure SwitchAllInTaxiInterface() Export
	
	BeginTransaction();
	
	Try
		
		UserArray = InfobaseUsers.GetUsers();
		For Each IBUser IN UserArray Do
			
			UsersService.SetInitialSettings(IBUser.Name);
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent("SwitchUsersInterface", EventLogLevel.Error, , , ErrorDescription());
		
	EndTry;
	
EndProcedure

#EndRegion