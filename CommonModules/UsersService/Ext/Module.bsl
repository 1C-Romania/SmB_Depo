////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Declare service events to which SSL handlers can be attached.

// Declares service events of the Users subsystem:
//
// Server events:
//   OnDefineQuestionTextBeforeWriteFirstAdministrator,
//   OnAdministratorWrite.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Overrides the standard method of setting roles to IB users.
	//
	// Parameters:
	//  Prohibition - Boolean. If you set True,
	//           roles change is locked (for administrator as well).
	//
	// Syntax:
	// Procedure OnDefineRolesEditBan (Ban) Export
	//
	// (The same as UsersOverridable.ChangeRolesEditProhibition).
	ServerEvents.Add("StandardSubsystems.Users\WhenDefiningEditingRolesProhibition");
	
	// Overrides behavior of user form, external
	// user form and external users group form.
	//
	// Parameters:
	//  Ref - CatalogRef.Users,
	//           CatalogRef.ExternalUsers,
	//           CatalogRef.ExternalUsersGroups
	//           ref to the user, external user or
	//           external users group when the form is being created.
	//
	//  ActionsInForm - Structure (with properties of the Row type):
	//           Roles                   = "", "View", "Editing"
	//           ContactInformation= "", "View", "Editing" InfobaseUserProperties
	//           = "", "ViewAll", "EditAll", "EditOwn" ItemProperties
	//           = "", "View", "Editing"
	//           
	//           For external users group ContactInfo and InfobaseUserProperties do not exist.
	//
	// Syntax:
	// Procedure OnDefineActionsInForm (Ref, ActionsInForm) Export
	//
	// (The same as UsersOverridable.ChangeActionsInForm).
	ServerEvents.Add("StandardSubsystems.Users\OnDeterminingFormAction");
	
	// Overrides the question text before the first administrator write.
	//  Called from BeforeWrite handler of user form.
	//  Called if RolesEditingBan() is
	// set and IB users quantity equals to one.
	// 
	// Syntax:
	// Procedure OnDefineQuestionTextBeforeWriteFirstAdministrator (QuestionText) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.Users\OnDeterminingIssueBeforeWriteTextOfFirstAdministrator");
	
	// Defines actions during the user writing
	// when it is written together with IB user that has the FullRights role.
	// 
	// Parameters:
	//  User - CatalogRef.Users (it is prohibited to change object).
	//
	// Syntax:
	// Procedure OnWriteAdministrator (User) Export
	//
	ServerEvents.Add("StandardSubsystems.Users\OnAdministratorWrite");
	
	// Called while creating "Users" catalog item during the interactive user login.
	//
	// Parameters:
	//  NewUser - CatalogObject.Users,
	//
	// Syntax:
	// Procedure OnCreateUserDuringLogin (NewUser) Export
	ServerEvents.Add("StandardSubsystems.Users\OnCreateUserAtEntryTime");
	
	// Called on new infobase user authorization.
	//
	// Parameters:
	//  IBUser - IBUser, current IB
	//  user, StandardProcessor - Boolean, value can be set inside the handler,
	//    in this case, the standard authorization processing of new IB user will not be executed.
	//
	// Syntax:
	// Procedure OnAuthorizationNewIBUser (IBUser, StandardProcessor) Export
	ServerEvents.Add("StandardSubsystems.Users\OnNewIBUserAuthorization");
	
	// Called on the infobase user processing begin.
	//
	// Parameters:
	//  ProcessingParameters - Structure, for the comment to the procedure, see StartIBUserProcessor().
	//  IBUserDescription - Structure, for the comment to the procedure, see StartIBUserProcessor().
	//
	// Syntax:
	// Procedure OnStartIBUserProcessor (ProcessorParameters, IBUserDescription);
	ServerEvents.Add("StandardSubsystems.Users\OnBeginIBUserDataProcessing");
	
	// Called before writing the infobase user.
	//
	// Parameters:
	//  InfobaseUserID - UUID
	//
	// Syntax:
	// Procedure BeforeInfobaseUsersWrite (IBUserIdentifier) Export
	ServerEvents.Add("StandardSubsystems.Users\BeforeWriteIBUser");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddSessionSettingsSetupHandler"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WorkClientParametersOnAdd"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToSubordinate"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToMaster"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\AfterDataReceivingFromSubordinated"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\AfterDataReceivingFromMain"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"UsersService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
		"UsersService");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"UsersService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillingKindsOfRestrictionsRightsOfMetadataObjects"].Add(
			"UsersService");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ServerHandlers["StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports"].Add(
			"UsersService");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"UsersService");
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Main  procedures and functions.

// Fills in the CurrentUser or
// CurrentExternalUser session parameter with user value found
// by the infobase user  under which the session is started.
//  If user is not found, then a new
// user is created in catalog if there are administrative rights, otherwise, exception is called.
// 
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	
	If ParameterName <> "CurrentUser"
	   AND ParameterName <> "CurrentExternalUser"
	   AND ParameterName <> "AuthorizedUser" Then
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Raise
			NStr("en='Invalid CurrentUser session
		|parameter receipt is session without specifying all separators.';ru='Недопустимое получение
		|параметра сеанса ТекущийПользователь в сеансе без указания всех разделителей.'");
	EndIf;
	
	BeginTransaction();
	Try
		UserNotFound = False;
		CreateUser  = False;
		RefNew         = Undefined;
		Service            = False;
		
		CurrentUser        = Undefined;
		CurrentExternalUser = Undefined;
		
		CurrentInfobaseUser = InfobaseUsers.CurrentUser();
		
		If IsBlankString(CurrentInfobaseUser.Name) Then
			
			CurrentExternalUser = Catalogs.ExternalUsers.EmptyRef();
			
			UnspecifiedUserProperties = UnspecifiedUserProperties();
			
			UserName       = UnspecifiedUserProperties.FullName;
			UserFullName = UnspecifiedUserProperties.FullName;
			RefNew          = UnspecifiedUserProperties.StandardRef;
			
			If UnspecifiedUserProperties.Ref = Undefined Then
				UserNotFound = True;
				CreateUser  = True;
				Service = True;
				InfobaseUserID = "";
			Else
				CurrentUser = UnspecifiedUserProperties.Ref;
			EndIf;
		Else
			UserName             = CurrentInfobaseUser.Name;
			InfobaseUserID = CurrentInfobaseUser.UUID;
			
			Users.FindAmbiguousInfobaseUsers(, InfobaseUserID);
			
			Query = New Query;
			Query.Parameters.Insert("InfobaseUserID", InfobaseUserID);
			
			Query.Text =
			"SELECT TOP 1
			|	Users.Ref AS Ref
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.InfobaseUserID = &InfobaseUserID";
			UsersResult = Query.Execute();
			
			Query.Text =
			"SELECT TOP 1
			|	ExternalUsers.Ref AS Ref
			|FROM
			|	Catalog.ExternalUsers AS ExternalUsers
			|WHERE
			|	ExternalUsers.InfobaseUserID = &InfobaseUserID";
			ResultExternalUsers = Query.Execute();
			
			If Not ResultExternalUsers.IsEmpty() Then
				
				Selection = ResultExternalUsers.Select();
				Selection.Next();
				CurrentUser        = Catalogs.Users.EmptyRef();
				CurrentExternalUser = Selection.Ref;
				
				If Not ExternalUsers.UseExternalUsers() Then
				
					ErrorMessageText = NStr("en='External users are disabled.';ru='Внешние пользователи отключены.'");
					Raise ErrorMessageText;
				EndIf;
			Else
				CurrentExternalUser = Catalogs.ExternalUsers.EmptyRef();
				
				If UsersResult.IsEmpty() Then
					If Users.InfobaseUserWithFullAccess( , CommonUseReUse.ApplicationRunningMode().Local, False) Then
						
						InfobaseUserID = CurrentInfobaseUser.UUID;
						
						UserFullName       = CurrentInfobaseUser.FullName;
						UserByDescription  = UserRefByFullDescr(UserFullName);
						
						If UserByDescription = Undefined Then
							UserNotFound = True;
							CreateUser  = True;
						Else
							CurrentUser = UserByDescription;
						EndIf;
					Else
						UserNotFound = True;
					EndIf;
				Else
					Selection = UsersResult.Select();
					Selection.Next();
					CurrentUser = Selection.Ref;
				EndIf;
			EndIf;
		EndIf;
		
		If CreateUser Then
			
			BeginTransaction();
			Try
				
				If RefNew = Undefined Then
					RefNew = Catalogs.Users.GetRef();
				EndIf;
				
				CurrentUser = RefNew;
				
				NewUser = Catalogs.Users.CreateItem();
				NewUser.Service = Service;
				NewUser.Description = UserFullName;
				NewUser.SetNewObjectRef(RefNew);
				
				If ValueIsFilled(InfobaseUserID) Then
					
					IBUserDescription = New Structure;
					IBUserDescription.Insert("Action", "Write");
					IBUserDescription.Insert("UUID", InfobaseUserID);
					
					NewUser.AdditionalProperties.Insert(
						"IBUserDescription", IBUserDescription);
				EndIf;
				
				Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.Users\OnCreateUserAtEntryTime");
				For Each Handler IN Handlers Do
					Handler.Module.OnCreateUserAtEntryTime(NewUser);
				EndDo;
				
				NewUser.Write();
				
				CommitTransaction();
			Except
				RollbackTransaction();
				
				ErrorMessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Authorization not executed. System work will be complete.
		|User: %1 is not found in the ""Users"" catalog.
		|
		|An error occurred while adding user to
		|catalog: %2.
		|
		|Contact your administrator.';ru='Авторизация не выполнена. Работа системы будет завершена.
		|Пользователь: %1 не найден в справочнике ""Пользователи"".
		|
		|При попытке добавления пользователя в справочник
		|возникла ошибка: ""%2"".
		|
		|Обратитесь к администратору.'"),
					UserName,
					BriefErrorDescription(ErrorInfo()) );
				
				Raise ErrorMessageText;
			EndTry;
			
		ElsIf UserNotFound Then
			Raise MessageTextUserNotFoundInCatalog(UserName);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If CurrentUser = Undefined
	 OR CurrentExternalUser = Undefined Then
		
		ErrorMessageText = MessageTextUserNotFoundInCatalog(UserName) +
			NStr("en='
		|When searching the user an internal error has occurred.';ru='
		|Возникла внутренняя ошибка при поиске пользователя.'");
		Raise ErrorMessageText;
	EndIf;
	
	SessionParameters.CurrentUser        = CurrentUser;
	SessionParameters.CurrentExternalUser = CurrentExternalUser;
	
	SessionParameters.AuthorizedUser = ?(ValueIsFilled(CurrentUser),
		CurrentUser, CurrentExternalUser);
	
	SpecifiedParameters.Add("CurrentUser");
	SpecifiedParameters.Add("CurrentExternalUser");
	SpecifiedParameters.Add("AuthorizedUser");
	
EndProcedure

// Called during the system start to check whether it
// is possible to execute authorization and call filling of the session parameters values CurrentUser and CurrentExternalUser.
// Also called during login to data area.
//
// Returns:
//  String - empty string   - authorization is complete successfully.
//           String is not empty - error description.
//                             On system start you
//                             should shut down 1C:Enterprise.
//
Function AuthenticateCurrentUser(OnStart = False) Export
	
	If Not OnStart Then
		RefreshReusableValues();
	EndIf;
	
	SetPrivilegedMode(True);
	
	CurrentInfobaseUser = InfobaseUsers.CurrentUser();
	CheckUserRights(CurrentInfobaseUser, "OnLaunch");
	
	If IsBlankString(CurrentInfobaseUser.Name) Then
		// Default user is authorized.
		Return "";
	EndIf;
	
	Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.Users\OnNewIBUserAuthorization");
	StandardProcessing = True;
	For Each Handler IN Handlers Do
		Handler.Module.OnNewIBUserAuthorization(CurrentInfobaseUser, StandardProcessing);
	EndDo;
	
	If Not StandardProcessing Then
		Return "";
	EndIf;
	
	FoundUser = Undefined;
	If UserByIDExists(
	       CurrentInfobaseUser.UUID, , FoundUser) Then
		// IBUser is found in catalog.
		
		If OnStart
		   AND Users.InfobaseUserWithFullAccess(CurrentInfobaseUser, CommonUseReUse.ApplicationRunningMode().Local, False) Then
			
			OnAuthorizationAdministratorOnStart(FoundUser);
		EndIf;
		
		Return "";
	EndIf;
	
	// It is required to create administrator or report about authorization denial.
	ErrorMessageText = "";
	CreateAdministratorRequired = False;
	
	IBUsers = InfobaseUsers.GetUsers();
	
	If IBUsers.Count() = 1 Or Users.InfobaseUserWithFullAccess(, True, False) Then
		// Administrator is authorized created in configurator.
		CreateAdministratorRequired = True;
	Else
		// Normal user created in the configurator is authorized.
		ErrorMessageText = MessageTextUserNotFoundInCatalog(CurrentInfobaseUser.Name);
	EndIf;
	
	If CreateAdministratorRequired Then
		
		If IsInRole(Metadata.Roles.FullRights) // Do not replace with RolesAvailable.
			AND (IsInRole(Users.SystemAdministratorRole(True)) // Do not replace with RolesAvailable.
			   OR CommonUseReUse.DataSeparationEnabled() ) Then
			
			User = Users.CreateAdministrator(CurrentInfobaseUser);
			
			Comment =
				NStr("en='Start on behalf of the user with
		|the ""Full rights"" role that is not registered in users list.
		|Auto registration in users list is executed.
		|
		|To maintain a list and users rights setting,
		|use the Users list, 1C:Enterprise configuration mode should not be used.';ru='Выполняется запуск от имени пользователя с ролью ""Полные права"",
		|который не зарегистрирован в списке пользователей.
		|Выполнена автоматическая регистрация в списке пользователей.
		|
		|Для ведения списка и настройки прав пользователей предназначен список Пользователи,
		|режим конфигурирования 1С:Предприятия для этого использовать не следует.'");
			
			AfterWriteAdministratorOnAuthorization(Comment);
			
			WriteLogEvent(
				NStr("en='Users.Administrator is registered in the Users catalog';ru='Пользователи.Администратор зарегистрирован в справочнике Пользователи'",
				     CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Warning,
				Metadata.Catalogs.Users,
				User,
				Comment);
		Else
			ErrorMessageText =
				NStr("en='Unable to start as user with
		|the Administration right as they are not registered in the users list.
		|
		|To maintain a list and users rights setting,
		|use the Users list, 1C:Enterprise configuration mode should not be used.';ru='Запуск от имени пользователя с правом Администрирование невозможен,
		|так как он не зарегистрирован в списке пользователей.
		|
		|Для ведения списка и настройки прав пользователей предназначен список Пользователи,
		|режим конфигурирования 1С:Предприятия для этого использовать не следует.'");
		EndIf;
	EndIf;
	
	Return ErrorMessageText;
	
EndFunction

// Defines that a nonstandard method of roles setting by IB user is used.
Function BanEditOfRoles() Export
	
	Prohibition = False;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.Users\WhenDefiningEditingRolesProhibition");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenDefiningEditingRolesProhibition(Prohibition);
	EndDo;
	
	UsersOverridable.ChangeRoleEditProhibition(Prohibition);
	
	Return Prohibition = True;
	
EndFunction

// Sets the initial settings for the infobase user.
//
// Parameters:
//  UserName - String, IB user name for which settings are saved.
//
Procedure SetInitialSettings(Val UserName) Export
	
	SystemInfo = New SystemInfo;
	
	CurrentMode = Metadata.InterfaceCompatibilityMode;
	Taxi = (CurrentMode = Metadata.ObjectProperties.InterfaceCompatibilityMode.Taxi
		OR CurrentMode = Metadata.ObjectProperties.InterfaceCompatibilityMode.TaxiEnableVersion8_2);
	
	SettingsClient = New ClientSettings;
	SettingsClient.ShowNavigationAndActionsPanels = False;
	SettingsClient.ShowSectionsPanel = True;
	SettingsClient.ApplicationFormsOpenningMode = ApplicationFormsOpenningMode.Tabs;
	
	TaxiSettings = Undefined;
	InterfaceSettings = New CommandInterfaceSettings;
	
	If Taxi Then
		SettingsClient.ClientApplicationInterfaceVariant = ClientApplicationInterfaceVariant.Taxi;
		
		InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.PictureAndText;
		
		TaxiSettings = New ClientApplicationInterfaceSettings;
		ContentSettings = New ClientApplicationInterfaceContentSettings;
		GroupLeft = New ClientApplicationInterfaceContentSettingsGroup;
		GroupLeft.Add(New ClientApplicationInterfaceContentSettingsItem("ToolsPanel"));
		GroupLeft.Add(New ClientApplicationInterfaceContentSettingsItem("SectionsPanel"));
		ContentSettings.Left.Add(GroupLeft);
		TaxiSettings.SetContent(ContentSettings);
	Else
		InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.Text;
	EndIf;
	
	InitialSettings = New Structure("SettingsClient,InterfaceSettings,TaxiSettings", 
		SettingsClient, InterfaceSettings, TaxiSettings);
	UsersOverridable.WithInstallationOfInitialSettings(InitialSettings);
	
	If InitialSettings.SettingsClient <> Undefined Then
		SystemSettingsStorage.Save("Common/ClientApplicationSettings", "",
			InitialSettings.SettingsClient, , UserName);
	EndIf;
	
	If InitialSettings.InterfaceSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/SectionsPanel/CommandInterfaceSettings", "",
			InitialSettings.InterfaceSettings, , UserName);
	EndIf;
		
	If InitialSettings.TaxiSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/ClientApplicationInterfaceSettings", "",
			InitialSettings.TaxiSettings, , UserName);
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For role interface work in managed form.

// Only for internal use.
//
Procedure ProcessRolesInterface(Action, Parameters) Export
	
	If Action = "SetReadOnlyOfRoles" Then
		SetReadOnlyOfRoles(Parameters);
		
	ElsIf Action = "TuneRolesInterfaceOnSettingsImporting" Then
		TuneRolesInterfaceOnSettingsImporting(Parameters);
		
	ElsIf Action = "SetInterfaceOfRolesOnFormCreating" Then
		SetInterfaceOfRolesOnFormCreating(Parameters);
		
	ElsIf Action = "SelectedRolesOnly" Then
		SelectedRolesOnly(Parameters);
		
	ElsIf Action = "GroupBySubsystems" Then
		GroupBySubsystems(Parameters);
		
	ElsIf Action = "RefreshRolesTree" Then
		RefreshRolesTree(Parameters);
		
	ElsIf Action = "RefreshContentOfRoles" Then
		RefreshContentOfRoles(Parameters);
		
	ElsIf Action = "FillRoles" Then
		FillRoles(Parameters);
	Else
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Error in the UsersService procedure.RolesInterfaceProcessor()
		|Incorrect value of the Action parameter: %1.';ru='Ошибка в процедуре ПользователиСлужебный.ОбработатьИнтерфейсРолей() Неверное значение параметра Действие: ""%1"".'"),
			Action);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// General purpose procedures and functions.

// Returns values table of all configuration roles names.
// 
// Parameters:
// 
// Returns:
//  FixedStructure with properties:
//      Array          - FixedArray of roles names.
//      Map    - FixedMatch of roles names with the True value.
//      ValueTable - ValuesTable with columns:
//                        Name - String - role name.
//
Function AllRoles() Export
	
	Return UsersServiceReUse.Parameters().AllRoles;
	
EndFunction

// Returns unavailable roles for the specified users type.
//
// Parameters:
//  UsersType - EnumRef.UsersTypes.
//
// Returns:
//  FixedMatch where key - role name, and Value - True.
//
Function InaccessibleRolesByUserTypes(UsersType) Export
	
	// During work in the local mode by the system administrator - no restrictions.
	If UsersType = Enums.UserTypes.LocalApplicationUser 
		AND Users.InfobaseUserWithFullAccess(, True, False) Then
		Return New FixedMap(New Map());
	EndIf;
	
	InaccessibleRoles = UsersServiceReUse.Parameters().UnavailableRolesByUserTypes;
	Return InaccessibleRoles.Get(UsersType);
	
EndFunction

// During the first subordinate node start
// clears IB users identifiers copied while creating the initial image.
//
Procedure ClearNonExistentInfobaseUserIDs() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	EmptyUUID = New UUID("00000000-0000-0000-0000-000000000000");
	
	Query = New Query;
	Query.SetParameter("EmptyUUID", EmptyUUID);
	
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID <> &EmptyUUID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.InfobaseUserID
	|FROM
	|	Catalog.Users AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfobaseUserID <> &EmptyUUID";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		IBUser = InfobaseUsers.FindByUUID(
			Selection.InfobaseUserID);
		
		If IBUser <> Undefined Then
			Continue;
		EndIf;
		
		CurrentObject = Selection.Ref.GetObject();
		CurrentObject.InfobaseUserID = EmptyUUID;
		InfobaseUpdate.WriteData(CurrentObject);
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return; // IN models service case is not displayed.
	EndIf;
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not Users.InfobaseUserWithFullAccess(, True)
		Or ModuleCurrentWorksService.WorkDisabled("IncorrectInformationAboutUsers") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	IncorrectUsers = UsersAddedUsingConfigurator();
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.Catalogs.Users.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	For Each Section IN Sections Do
		
		UsersID = "IncorrectInformationAboutUsers" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID  = UsersID;
		Work.ThereIsWork       = IncorrectUsers > 0;
		Work.Quantity     = IncorrectUsers;
		Work.Presentation  = NStr("en='Incorrect information about users';ru='Некорректные сведения о пользователях'");
		Work.Form          = "Catalog.Users.Form.IBUsers";
		Work.Owner       = Section;
		
	EndDo;
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to catalog ExternalUsers is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.ExternalUsers.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
	// Import to the Users catalog is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.Users.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;

	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2";
	Handler.Procedure = "UsersService.FillUsersIDs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.15";
	Handler.Procedure = "InformationRegisters.UsersGroupsContents.RefreshDataRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.5";
	Handler.Procedure = "InformationRegisters.UsersGroupsContents.RefreshDataRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "Users.OnUsersGroupsExistanceSetUsage";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "UsersService.ConvertRolesNamesToIdentifiers";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "InformationRegisters.UsersGroupsContents.RefreshDataRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.16";
	Handler.InitialFilling = True;
	Handler.Procedure = "UsersService.UpdateUsersPredefinedContactInformationTypes";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.4.19";
	Handler.Procedure = "UsersService.MoveExternalUsersGroupsToRoot";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.3";
	Handler.Procedure = "UsersService.FillUsersAuthenticationProperties";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.42";
	Handler.Procedure = "UsersService.AddToFullrightUsersRoleSystemAdministrator";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.16";
	Handler.SharedData = True;
	Handler.Procedure = "UsersService.DeleteCacheUndividedDataAvailableForChange";
	
EndProcedure

// Returns a match of session parameters and handlers parameters to initialize them.
//
Procedure OnAddSessionSettingsSetupHandler(Handlers) Export
	
	Handlers.Insert("CurrentUser",        "UsersService.SessionParametersSetting");
	Handlers.Insert("CurrentExternalUser", "UsersService.SessionParametersSetting");
	
EndProcedure

// Defines the structure of parameters required for
// the work of the configuration client code.
//
// Parameters:
//   Parameters - Structure to which you can insert the client work parameters during the start.
//                 Key     - parameter
//                 name, Value - value of the parameter.
//
// Useful example:
//   Parameters.Insert(<ParameterName>, <Code of receiving the parameter value>);
//
Procedure WorkClientParametersOnAdd(Parameters) Export
	
	Parameters.Insert("InfobaseUserWithFullAccess", Users.InfobaseUserWithFullAccess());
	Parameters.Insert("IsEducationalPlatform", StandardSubsystemsServer.IsEducationalPlatform());
	
EndProcedure

// Fills the array with the list of metadata objects names that might include
// references to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array       - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.UsersGroupsContents.FullName());
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSendDataToSubordinate(DataItem, ItemSend, CreatingInitialImage, Recipient) Export
	
	OnDataSending(DataItem, ItemSend, True);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataMain() event handler in the syntax helper.
// 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	OnDataSending(DataItem, ItemSend, False);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnReceiveData(DataItem, ItemReceive, SendBack, True);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnReceiveData(DataItem, ItemReceive, SendBack, False);
	
EndProcedure

// Procedure-handler of the event after receiving data in the main node from the subordinate node of distributed IB.
// Called when exchange message reading is complete when all data from the exchange message
// are successfully read and written to IB.
// 
//  Parameters:
// Sender - ExchangePlanObject. Exchange plan node from which the data is received.
// Cancel - Boolean. Cancelation flag. If you set the True
// value for this parameter, the message will not be considered to be received. Data import transaction will be
// canceled if all data is imported in one transaction or last data import transaction
// will be canceled if data is imported batchwise.
//
Procedure AfterDataReceivingFromSubordinated(Sender, Cancel) Export
	
	AfterDataGetting(Sender, Cancel, True);
	
EndProcedure

// Procedure-handler of the event after receiving data in the subordinate node from the main node of distributed IB.
// Called when exchange message reading is complete when all data from the exchange message
// are successfully read and written to IB.
// 
//  Parameters:
// Sender - ExchangePlanObject. Exchange plan node from which the data is received.
// Cancel - Boolean. Cancelation flag. If you set the True
// value for this parameter, the message will not be considered to be received. Data import transaction will be
// canceled if all data is imported in one transaction or last data import transaction
// will be canceled if data is imported batchwise.
//
Procedure AfterDataReceivingFromMain(Sender, Cancel) Export
	
	AfterDataGetting(Sender, Cancel, False);
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - need to receive a list of RIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.UsersWorkParameters);
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should not be included into the exchange plan content.
// If the subsystem has metadata objects that should not be included in
// the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should not be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - required to get the list of the exception objects of the DIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
EndProcedure

// Used to receive metadata objects that should be included in the
// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes registration for this plan.
// These metadata objects are used only at the time of creation
// of the initial image of the subnode and do not migrate during the exchange.
// If the subsystem has metadata objects that take part in creating an initial
// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects.
//
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.UsersWorkParameters);
	
EndProcedure

// Events handlers of the Access management subsystem.

// Fills the content of access kinds used when metadata objects rights are restricted.
// If the content of access kinds is not filled, "Access rights" report will show incorrect information.
//
// Only the access types clearly used
// in access restriction templates must be filled, while
// the access types used in access values sets may be
// received from the current data register AccessValueSets.
//
//  To prepare the procedure content
// automatically, you should use the developer tools for subsystem.
// Access management.
//
// Parameters:
//  Definition     - String, multiline string in format <Table>.<Right>.<AccessKind>[.Object table].
//                 For
//                           example,
//                           Document.SupplierInvoice.Read.Company
//                           Document.SupplierInvoice.Read.Counterparties
//                           Document.SupplierInvoice.Change.Companies
//                           Document.SupplierInvoice.Change.Counterparties
//                           Document.EMails.Read.Object.Document.EMails
//                           Document.EMails.Change.Object.Document.EMails
//                           Document.Files.Read.Object.Catalog.FileFolders
//                           Document.Files.Read.Object.Document.EMail
//                 Document.Files.Change.Object.Catalog.FileFolders Document.Files.Change.Object.Document.EMail Access kind Object predefined as literal. This access kind is
//                 used in the access limitations templates as "ref" to another
//                 object according to which the current table object is restricted.
//                 When the Object access kind is specified, you should
//                 also specify tables types that are used for this
//                 access kind. I.e. enumerate types that correspond to
//                 the field used in the access limitation template in the pair with the Object access kind. While enumerating types by the "Object"
//                 access kind, you need to list only those field types that the field has.
//                 InformationRegisters.AccessValueSets.Object, the rest types are extra.
// 
Procedure OnFillingKindsOfRestrictionsRightsOfMetadataObjects(Definition) Export
	
	Definition = Definition + 
	"
	|Catalog.ExternalUsers.Read.ExternalUsers Catalog.ExternalUsers.Change.ExternalUsers Catalog.ExternalUsersGroups.Read.ExternalUsers Catalog.UsersGroups.Read.Users Catalog.Users.Read.Users Catalog.Users.Change.Users InformationRegister.UsersGroupsContents.Read.ExternalUsers InformationRegister.UsersGroupsContents.Read.Users
	|";
	
EndProcedure

// ReportsVariants subsystem events handlers.

// Contains the settings of reports variants placement in reports panel.
//   
// Parameters:
//   Settings - Collection - Used for the description of reports
//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
//   
// Definition:
//   IN this procedure it is required to specify how the
//   reports predefined variants will be registered in application and shown in the reports panel.
//   
// Auxiliary methods:
//   ReportSettings   = ReportsVariants.ReportDescription(Settings, Metadata.Reports.<ReportName>);
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   
//   These functions receive respectively report settings and report variant settings of the next structure:
//       * Enabled - Boolean -
//           If False then the report variant is not registered in the subsystem.
//           Used to delete technical and contextual report variants from all interfaces.
//           These report variants can still be opened applicationmatically as report
//           using opening parameters (see help on "Managed form extension for the VariantKeys" report).
//       * VisibleByDefault - Boolean -
//           If False then the report variant is hidden by default in the reports panel.
//           User can "enable" it in the reports
//           panel setting mode or open via the "All reports" form.
//       *Description - String - Additional information on the report variant.
//           It is displayed as a tooltip in the reports panel.
//           Must decrypt for user the report
//           variant content and should not duplicate the report variant name.
//       * Placement - Map - Settings for report variant location in sections.
//           ** Key     - MetadataObject: Subsystem - Subsystem that hosts the report or the report variant.
//           ** Value - String - Optional. Settings for location in the subsystem.
//               ""        - Output report in its group in regular font.
//               "Important"  - Output report in its group in bold.
//               "SeeAlso" - Output report in the group "See also".
//       * FunctionalOptions - Array from String -
//            Names of the functional report variant options.
//   
// ForExample:
//   
//  (1) Add a report variant to the subsystem.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (2) Disable report variant.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Enabled = False;
//   
//  (3) Disable all report variants except for the required one.
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Report.Enabled = False;
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName");
// Variant.Enabled = True;
//   
//  (4) Completion result  4.1 and 4.2 will be the same:
//  (4.1)
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName1");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName2");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName3");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (4.2)
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Report.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// ReportsVariants.VariantDesc(Settings, Report, "VariantName1");
// ReportsVariants.VariantDesc(Settings, Report, "VariantName2");
// ReportsVariants.VariantDesc(Settings, Report, "VariantName3");
// Report.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
// IMPORTANT:
//   Report serves as variants container.
//     By modifying the report settings you can change the settings of all its variants at the same time.
//     However if you receive report variant settings directly, they
//     will become the self-service ones, i.e. will not inherit settings changes from the report.See examples 3 and 4.
//   
//   Initial setting of reports locating by the subsystems
//     is read from metadata and it is not required to duplicate it in the code.
//   
//   Functional variants options unite with functional reports options by the following rules:
//     (ReportFunctionalOption1 OR ReportFunctionalOption2) And
//     (VariantFunctionalOption3 OR VariantFunctionalOption4).
//   Reports functional options are
//     not read from the metadata, they are applied when the user uses the subsystem.
//   You can add functional options via ReportDescription that will be connected by
//     the rules specified above. But remember that these functional options will be valid only
//     for predefined variants of this report.
//   For user report variants only functional report variants are valid.
//     - they are disabled only along with total report disabling.
//
Procedure OnConfiguringOptionsReports(Settings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.InformationAboutUsers);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// Calls the update of external user
// presentation while changing its authorization object presentation.
//
//  IN subscription content you should include authorization objects types:
// Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.
// For example: Catalog.Individuals, Catalog.Counterparies
//
Procedure UpdateExternalUserRepresentationOnWrite(Val Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	If TypeOf(Object.Ref) = Type("CatalogRef.ExternalUsers") Then
		Return;
	EndIf;
	
	UpdateExternalUserPresentation(Object.Ref);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of work with users.

// Returns the password value to be saved for the specified password.
//
// Parameters:
//  Password                      - String - the password, for which it is required to get the value to be saved.
//
//  InfobaseUserID - UUID - IB user for which
//                                it is required to compare the saved value
//                                with the received one and put the result in the next parameter Matches.
//
//  Matches                   - Boolean (return value) - see comment to the parameter.
//                                InfobaseUserID.
// Returns:
//  String - the password value to be saved.
//
Function PasswordStringStoredValue(Val Password,
                                        Val InfobaseUserID = Undefined,
                                        Matches = False) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		TempInfobaseUser = InfobaseUsers.CreateUser();
		TempInfobaseUser.StandardAuthentication = True;
		TempInfobaseUser.Password = Password;
		
		TempInfobaseUser.Name = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Temporary user (%1)';ru='Временный пользователь (%1)'"),
			New UUID);
		
		TempInfobaseUser.Write();
		
		TempInfobaseUser = InfobaseUsers.FindByUUID(
			TempInfobaseUser.UUID);
		
		StoredPasswordValue = TempInfobaseUser.StoredPasswordValue;
		RollbackTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If TypeOf(InfobaseUserID) = Type("UUID") Then
		
		IBUser = InfobaseUsers.FindByUUID(
			InfobaseUserID);
		
		If TypeOf(IBUser) = Type("InfobaseUser") Then
			Matches = (StoredPasswordValue = IBUser.StoredPasswordValue);
		EndIf;
	EndIf;
	
	Return StoredPasswordValue;
	
EndFunction

// Returns the current access level for IB user properties change.
// 
// Parameters:
//  ObjectDescription - CatalogObject.Users
//                  - CatalogObject.ExternalUsers
//                  - FormDataStructure - created from the objects specified above.
//
//  ProcessingParameters - Undefined - receive data from
//                       object description, otherwise, take ready data from the processor parameters.
//
// Returns:
//  Structure - contains properties:
//   - SystemAdministrator    - Boolean - any actions with any user and their IB user.
//   - FullRights             - Boolean - the same, SystemAdministrator, excluding system administrators.
//   - ListManagement       - add new users and change the existing ones:
//                              - for users that are not allowed to log in
//                                application (new ones) you can set any properties, except of enabling application login,
//                              - for users that are allowed to log
//                                in the application you can set any properties except
//                                of enabling application login and authentication settings (see below).
//   - SettingsForLogin        - Boolean - change IB user properties: Name, OSUser
//                               and AuthenticationOpenID catalog item properties,
//                               AuthenticationStandard, OSAuthentication and Roles (if there is no editing prohibition during embedding).
//   - ChangeCurrent      - change properties of the current user Password and Language.
//   - AccessDenied             - no access level specified above.
//
Function AccessLevelToUserProperties(ObjectDescription, ProcessingParameters = Undefined) Export
	
	AccessLevel = New Structure;
	
	// System administrator (system data).
	AccessLevel.Insert("SystemAdministrator", Users.InfobaseUserWithFullAccess(, True));
	
	// Full user (main data).
	AccessLevel.Insert("FullRights", Users.InfobaseUserWithFullAccess());
	
	If TypeOf(ObjectDescription.Ref) = Type("CatalogRef.Users") Then
		// Responsible for users list.
		AccessLevel.Insert("ListManagement",
			AccessRight("Insert", Metadata.Catalogs.Users)
			AND (AccessLevel.FullRights
			   Or Not Users.InfobaseUserWithFullAccess(ObjectDescription.Ref)));
		// User of the current IB user.
		AccessLevel.Insert("ChangeCurrent",
			AccessLevel.FullRights
			Or AccessRight("Update", Metadata.Catalogs.Users)
			  AND ObjectDescription.Ref = Users.AuthorizedUser());
		
	ElsIf TypeOf(ObjectDescription.Ref) = Type("CatalogRef.ExternalUsers") Then
		// Responsible for external users list.
		AccessLevel.Insert("ListManagement",
			AccessRight("Insert", Metadata.Catalogs.ExternalUsers)
			AND (AccessLevel.FullRights
			   Or Not Users.InfobaseUserWithFullAccess(ObjectDescription.Ref)));
		// External user of the current IB user.
		AccessLevel.Insert("ChangeCurrent",
			AccessLevel.FullRights
			Or AccessRight("Update", Metadata.Catalogs.ExternalUsers)
			  AND ObjectDescription.Ref = Users.AuthorizedUser());
	EndIf;
	
	If ProcessingParameters = Undefined Then
		SetPrivilegedMode(True);
		If ValueIsFilled(ObjectDescription.InfobaseUserID) Then
			IBUser = InfobaseUsers.FindByUUID(
				ObjectDescription.InfobaseUserID);
		Else
			IBUser = Undefined;
		EndIf;
		UserWithoutSettingsForLoginOrPrepared =
			    IBUser = Undefined
			Or ObjectDescription.Prepared
			    AND Not Users.CanLogOnToApplication(IBUser);
		SetPrivilegedMode(False);
	Else
		UserWithoutSettingsForLoginOrPrepared =
			    Not ProcessingParameters.OldIBUserExist
			Or ProcessingParameters.OldUser.Prepared
			    AND Not Users.CanLogOnToApplication(ProcessingParameters.OldIBUserFullName);
	EndIf;
	
	// Full user (main data).
	AccessLevel.Insert("SettingsForLogin",
		    AccessLevel.SystemAdministrator
		Or AccessLevel.FullRights
		Or AccessLevel.ListManagement
		  AND UserWithoutSettingsForLoginOrPrepared);
	
	AccessLevel.Insert("AccessDenied",
		  Not AccessLevel.SystemAdministrator
		AND Not AccessLevel.FullRights
		AND Not AccessLevel.ListManagement
		AND Not AccessLevel.ChangeCurrent
		AND Not AccessLevel.SettingsForLogin);
	
	Return AccessLevel;
	
EndFunction

// Called BeforeWrite of User or External user.
Procedure BeginOfDBUserProcessing(UserObject,
                                        ProcessingParameters,
                                        UserDeletingFromCatalog = False) Export
	
	ProcessingParameters = New Structure;
	AdditionalProperties = UserObject.AdditionalProperties;
	
	ProcessingParameters.Insert("UserDeletingFromCatalog", UserDeletingFromCatalog);
	ProcessingParameters.Insert("MessageTextNotEnoughRights",
		NStr("en='Insufficient rights to change the infobase user.';ru='Недостаточно прав для изменения пользователя информационной базы.'"));
	
	If AdditionalProperties.Property("CopyingValue")
	   AND ValueIsFilled(AdditionalProperties.CopyingValue)
	   AND TypeOf(AdditionalProperties.CopyingValue) = TypeOf(UserObject.Ref) Then
		
		ProcessingParameters.Insert("CopyingValue", AdditionalProperties.CopyingValue);
	EndIf;
	
	// Catalog attributes that are set automatically (check for immutability).
	AutoAttributes = New Structure;
	AutoAttributes.Insert("InfobaseUserID");
	AutoAttributes.Insert("InfobaseUserProperties");
	ProcessingParameters.Insert("AutoAttributes", AutoAttributes);
	
	// Catalogs attributes that can not be changed in subscriptions to events (check initial values).
	AttributesToLock = New Structure;
	AttributesToLock.Insert("Service", False); // Value for the external user.
	AttributesToLock.Insert("DeletionMark");
	AttributesToLock.Insert("NotValid");
	AttributesToLock.Insert("Prepared");
	ProcessingParameters.Insert("AttributesToLock", AttributesToLock);
	
	RememberUserProperties(UserObject, ProcessingParameters);
	
	AccessLevel = AccessLevelToUserProperties(UserObject, ProcessingParameters);
	ProcessingParameters.Insert("AccessLevel", AccessLevel);
	
	// BeforeStartIBUserProcessor - service model support.
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		ModuleUsersServiceSaaS.BeforeStartIBUserProcessor(UserObject, ProcessingParameters);
	EndIf;
	
	If ProcessingParameters.OldUser.Prepared <> UserObject.Prepared
	   AND Not AccessLevel.FullRights Then
		
		Raise ProcessingParameters.MessageTextNotEnoughRights;
	EndIf;
	
	// Support interactive markup for deletion and group change of the DeletionMarkup, Invalid attributes.
	If ProcessingParameters.OldIBUserExist
	   AND Users.CanLogOnToApplication(ProcessingParameters.OldIBUserFullName)
	   AND Not AdditionalProperties.Property("IBUserDescription")
	   AND (  ProcessingParameters.OldUser.DeletionMark = False
	      AND UserObject.DeletionMark = True
	    Or ProcessingParameters.OldUser.NotValid = False
	      AND UserObject.NotValid  = True) Then
		
		AdditionalProperties.Insert("IBUserDescription", New Structure);
		AdditionalProperties.IBUserDescription.Insert("Action", "Write");
		AdditionalProperties.IBUserDescription.Insert("CanLogOnToApplication", False);
	EndIf;
	
	If Not AdditionalProperties.Property("IBUserDescription") Then
		If AccessLevel.ListManagement
		   AND Not ProcessingParameters.OldIBUserExist
		   AND ValueIsFilled(UserObject.InfobaseUserID) Then
			// Clear IB user identifier.
			UserObject.InfobaseUserID = Undefined;
			ProcessingParameters.AutoAttributes.InfobaseUserID =
				UserObject.InfobaseUserID;
		EndIf;
		Return;
	EndIf;
	IBUserDescription = AdditionalProperties.IBUserDescription;
	
	If Not IBUserDescription.Property("Action") Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|In the IBUserDescription parameter the Action property is not specified.';ru='Ошибка при записи пользователя ""%1"".
		|В параметре ОписаниеПользователяИБ не указано свойство Действие.'"),
			UserObject.Ref);
	EndIf;
	
	If IBUserDescription.Action <> "Write"
	   AND IBUserDescription.Action <> "Delete" Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|In the IBUserDescription
		|parameter incorrect value is specified %2 of the Action property.';ru='Ошибка при записи пользователя ""%1"".
		|В параметре ОписаниеПользователяИБ указано
		|неверное значение ""%2"" свойства Действие.'"),
			UserObject.Ref,
			IBUserDescription.Action);
	EndIf;
	ProcessingParameters.Insert("Action", IBUserDescription.Action);
	
	Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.Users\OnBeginIBUserDataProcessing");
	For Each Handler IN Handlers Do
		Handler.Module.OnBeginIBUserDataProcessing(ProcessingParameters, IBUserDescription);
	EndDo;
	
	If Not ProcessingParameters.Property("Action") Then
		Return;
	EndIf;
	
	If AccessLevel.AccessDenied Then
		Raise ProcessingParameters.MessageTextNotEnoughRights;
	EndIf;
	
	If IBUserDescription.Action = "Delete" Then
		
		If    ProcessingParameters.OldIBUserExist AND Not AccessLevel.SystemAdministrator
		 Or Not ProcessingParameters.OldIBUserExist AND Not AccessLevel.FullRights Then
			
			Raise ProcessingParameters.MessageTextNotEnoughRights;
		EndIf;
		
	ElsIf Not AccessLevel.ListManagement Then // Action = Write
		
		If Not AccessLevel.ChangeCurrent
		 Or Not ProcessingParameters.CurrentIBOldUser Then
			
			Raise ProcessingParameters.MessageTextNotEnoughRights;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If IBUserDescription.Action = "Write"
	   AND IBUserDescription.Property("UUID")
	   AND ValueIsFilled(IBUserDescription.UUID)
	   AND IBUserDescription.UUID
	     <> ProcessingParameters.OldUser.InfobaseUserID Then
		
		ProcessingParameters.Insert("IBUserSetting");
		
		If ProcessingParameters.OldIBUserExist Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while writing user %1.
		|You can not match IB user with to
		|user in the directory with which another IB user is already matched.';ru='Ошибка при записи пользователя ""%1"".
		|Нельзя сопоставить пользователя
		|ИБ с пользователем в справочнике, с которым уже сопоставлен другой пользователем ИБ.'"),
				UserObject.Description);
		EndIf;
		
		FoundUser = Undefined;
		
		If UserByIDExists(
			IBUserDescription.UUID,
			UserObject.Ref,
			FoundUser) Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while writing user %1.
		|You can not match IB user to this user
		|in the directory as it is already matched to another
		|user in the directory %2.';ru='Ошибка при записи пользователя ""%1"".
		|Нельзя сопоставить пользователя ИБ
		|с этим пользователем в справочнике, так как он уже
		|сопоставлен с другим пользователем в справочнике ""%2"".'"),
				FoundUser,
				UserObject.Description);
		EndIf;
		
		If Not AccessLevel.FullRights Then
			Raise ProcessingParameters.MessageTextNotEnoughRights;
		EndIf;
	EndIf;
	
	If IBUserDescription.Action = "Write" Then
		
		// Check rights for users with wide access change.
		If ProcessingParameters.OldIBUserExist Then
			
			If Not ProcessingParameters.OldIBUserFullName.Roles.Find("SystemAdministrator") = Undefined
			   AND Not AccessLevel.SystemAdministrator
			 OR Not ProcessingParameters.OldIBUserFullName.Roles.Find("FullRights") = Undefined
			   AND Not AccessLevel.FullRights Then
				
				Raise ProcessingParameters.MessageTextNotEnoughRights;
			EndIf;
		EndIf;
		
		// Check attempt of changing unavailable properties.
		ValidProperties = New Structure;
		ValidProperties.Insert("UUID"); // Checked above.
		
		If AccessLevel.ChangeCurrent Then
			ValidProperties.Insert("Password");
			ValidProperties.Insert("Language");
		EndIf;
		
		If AccessLevel.ListManagement Then
			ValidProperties.Insert("FullName");
			ValidProperties.Insert("ShowInList");
			ValidProperties.Insert("CannotChangePassword");
			ValidProperties.Insert("Language");
			ValidProperties.Insert("RunMode");
		EndIf;
		
		If AccessLevel.SettingsForLogin Then
			ValidProperties.Insert("Name");
			ValidProperties.Insert("StandardAuthentication");
			ValidProperties.Insert("Password");
			ValidProperties.Insert("OSAuthentication");
			ValidProperties.Insert("OSUser");
			ValidProperties.Insert("OpenIDAuthentication");
			ValidProperties.Insert("Roles");
		EndIf;
		
		If Not AccessLevel.FullRights Then
			AllProperties = Users.NewInfobaseUserInfo();
			
			For Each KeyAndValue IN IBUserDescription Do
				
				If AllProperties.Property(KeyAndValue.Key)
				   AND Not ValidProperties.Property(KeyAndValue.Key) Then
					
					Raise ProcessingParameters.MessageTextNotEnoughRights;
				EndIf;
			EndDo;
		EndIf;
		
		WriteIBUser(UserObject, ProcessingParameters);
	Else
		DeleteInfobaseUsers(UserObject, ProcessingParameters);
	EndIf;
	
	// Update attribute value controlled during the record.
	ProcessingParameters.AutoAttributes.InfobaseUserID =
		UserObject.InfobaseUserID;
	
	NewDBUserDescription = Undefined;
	If Users.ReadIBUser(
	         UserObject.InfobaseUserID,
	         NewDBUserDescription) Then
		
		ProcessingParameters.Insert("NewIBUserExist", True);
		ProcessingParameters.Insert("NewDBUserDescription", NewDBUserDescription);
		
		// Check rights for users with wide access change.
		If ProcessingParameters.OldIBUserExist Then
			
			If Not ProcessingParameters.NewDBUserDescription.Roles.Find("SystemAdministrator") = Undefined
			   AND Not AccessLevel.SystemAdministrator
			 OR Not ProcessingParameters.NewDBUserDescription.Roles.Find("FullRights") = Undefined
			   AND Not AccessLevel.FullRights Then
				
				Raise ProcessingParameters.MessageTextNotEnoughRights;
			EndIf;
		EndIf;
	Else
		ProcessingParameters.Insert("NewIBUserExist", False);
	EndIf;
	
	// AfterStartIBUserProcessor - service model support.
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		ModuleUsersServiceSaaS.AfterStartIBUserProcessor(UserObject, ProcessingParameters);
	EndIf;
	
EndProcedure

// Called OnWrite User or External user.
Procedure EndOfIBUserProcessing(UserObject, ProcessingParameters) Export
	
	CheckUserAttributesChanges(UserObject, ProcessingParameters);
	
	// BeforeEndUserIBUserProcessor - service model support.
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		ModuleUsersServiceSaaS.BeforeEndUserIBUserProcessor(UserObject, ProcessingParameters);
	EndIf;
	
	If Not ProcessingParameters.Property("Action") Then
		Return;
	EndIf;
	
	If ProcessingParameters.Property("AdministratorRecord") Then
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.Users\OnAdministratorWrite");
		
		SetPrivilegedMode(True);
		For Each Handler IN EventHandlers Do
			Handler.Module.OnAdministratorWrite(UserObject.Ref);
		EndDo;
		SetPrivilegedMode(False);
	EndIf;
	
	UpdateRoles = True;
	
	// OnCompleteIBUserProcessor - service model support.
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		ModuleUsersServiceSaaS.OnCompleteIBUserProcessor(
			UserObject, ProcessingParameters, UpdateRoles);
	EndIf;
	
	If ProcessingParameters.Property("IBUserSetting") AND UpdateRoles Then
		ServiceUserPassword = Undefined;
		If UserObject.AdditionalProperties.Property("ServiceUserPassword") Then
			ServiceUserPassword = UserObject.AdditionalProperties.ServiceUserPassword;
		EndIf;
		
		AfterIBUserSetting(UserObject.Ref, ServiceUserPassword);
	EndIf;
	
	CopyIBUserSettings(UserObject, ProcessingParameters);
	
EndProcedure

// Called during processor of  InfobaseUserProperties property in catalog.
// 
// Parameters:
//  UserDetails   - CatalogObject.Users,
//                           CatalogObject.ExternalUsers contains FormDataStructure property InfobaseUserProperties.
//                         - CatalogRef.Users, CatalogRef.ExternalUsers -
//                           from object of which it is required to read the InfobaseUserProperties property.
//  CanLogOnToApplication - Boolean - if False is specified but True is
//                           saved, then authentication properties are unconditionally False as were cleared in the configurator.
//
// Returns:
//  Structure.
//
Function StoredInfobaseUserProperties(UserDetails, CanLogOnToApplication = False) Export
	
	Properties = New Structure;
	Properties.Insert("CanLogOnToApplication",    False);
	Properties.Insert("StandardAuthentication", False);
	Properties.Insert("OpenIDAuthentication",      False);
	Properties.Insert("OSAuthentication",          False);
	
	If TypeOf(UserDetails) = Type("CatalogRef.Users")
	 Or TypeOf(UserDetails) = Type("CatalogRef.ExternalUsers") Then
		
		StorageProperties = CommonUse.ObjectAttributeValue(
			UserDetails, "InfobaseUserProperties");
	Else
		StorageProperties = UserDetails.InfobaseUserProperties;
	EndIf;
	
	If TypeOf(StorageProperties) <> Type("ValueStorage") Then
		Return Properties;
	EndIf;
	
	SavedProperties = StorageProperties.Get();
	
	If TypeOf(SavedProperties) <> Type("Structure") Then
		Return Properties;
	EndIf;
	
	For Each KeyAndValue IN Properties Do
		If SavedProperties.Property(KeyAndValue.Key)
		   AND TypeOf(SavedProperties[KeyAndValue.Key]) = Type("Boolean") Then
			
			Properties[KeyAndValue.Key] = SavedProperties[KeyAndValue.Key];
		EndIf;
	EndDo;
	
	If Properties.CanLogOnToApplication AND Not CanLogOnToApplication Then
		Properties.Insert("StandardAuthentication", False);
		Properties.Insert("OpenIDAuthentication",      False);
		Properties.Insert("OSAuthentication",          False);
	EndIf;
	
	Return Properties;
	
EndFunction

// You can not call from background jobs with empty user.
Function NeedToCreateFirstAdministrator(Val IBUserDescription,
                                              Text = Undefined) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	CurrentInfobaseUser = InfobaseUsers.CurrentUser();
	
	If Not ValueIsFilled(CurrentInfobaseUser.Name)
	   AND InfobaseUsers.GetUsers().Count() = 0 Then
		
		If TypeOf(IBUserDescription) = Type("Structure") Then
			// Check before writing a normal user or IB user.
			
			If IBUserDescription.Property("Roles") Then
				Roles = IBUserDescription.Roles;
			Else
				Roles = New Array;
			EndIf;
			
			If BanEditOfRoles()
				OR Roles.Find("FullRights") = Undefined
				OR Roles.Find(Users.SystemAdministratorRole().Name) = Undefined Then
				
				// Prepare the question text during the first administrator record.
				Text = NStr("en='The first user is added to
		|the application user list, that is why it will be automatically assigned with the Full rights role.
		|Continue?';ru='В список пользователей
		|программы добавляется первый пользователь, поэтому ему автоматически будет назначена роль ""Полные права"".
		|Продолжить?'");
				
				If Not BanEditOfRoles() Then
					Return True;
				EndIf;
				
				EventHandlers = CommonUse.ServiceEventProcessor(
					"StandardSubsystems.Users\OnDeterminingIssueBeforeWriteTextOfFirstAdministrator");
				
				For Each Handler IN EventHandlers Do
					Handler.Module.OnDeterminingIssueBeforeWriteTextOfFirstAdministrator(Text);
				EndDo;
				
				Return True;
			EndIf;
		Else
			// Check before writing an external user.
			Text = NStr("en='First infobase user must have full rights.
		|External user can not be full.
		|First, create administrator in the Users catalog.';ru='Первый пользователь информационной базы должен иметь полные права.
		|Внешний пользователь не может быть полноправным.
		|Сначала создайте администратора в справочнике Пользователи.'");
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Returns user properties for IB user with empty name.
Function UnspecifiedUserProperties() Export
	
	SetPrivilegedMode(True);
	
	Properties = New Structure;
	
	// Ref to found
	// catalog item corresponding to unspecified user.
	Properties.Insert("Ref", Undefined);
	
	// Link used for search and
	// creation of an unspecified user in Users catalog.
	Properties.Insert("StandardRef", Catalogs.Users.GetRef(
		New UUID("aa00559e-ad84-4494-88fd-f0826edc46f0")));
	
	// Full name that is set to the
	// item of the Users catalog during creating the nonexistent unspecified user.
	Properties.Insert("FullName", Users.UnspecifiedUserFullName());
	
	// Full name which is used for search
	// for the unspecified user using old method
	// required for support of unspecified user old versions. You do not need to change this name.
	Properties.Insert("FullNameForSearch", NStr("en='<Not specified>';ru='<Не указан>'"));
	
	// Search by the unique identifier.
	Query = New Query;
	Query.SetParameter("Ref", Properties.StandardRef);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref = &Ref";
	
	BeginTransaction();
	Try
		If Query.Execute().IsEmpty() Then
			Query.SetParameter("FullName", Properties.FullNameForSearch);
			Query.Text =
			"SELECT TOP 1
			|	Users.Ref
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.Description = &FullName";
			Result = Query.Execute();
			
			If Not Result.IsEmpty() Then
				Selection = Result.Select();
				Selection.Next();
				Properties.Ref = Selection.Ref;
			EndIf;
		Else
			Properties.Ref = Properties.StandardRef;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Properties;
	
EndFunction

// It creates user<Not specified>.
//
// Returns:
//  CatalogRef.Users
// 
Function CreateUnspecifiedUser() Export
	
	UnspecifiedUserProperties = UnspecifiedUserProperties();
	
	If CommonUse.RefExists(UnspecifiedUserProperties.StandardRef) Then
		
		Return UnspecifiedUserProperties.StandardRef;
		
	Else
		
		NewUser = Catalogs.Users.CreateItem();
		NewUser.Service = True;
		NewUser.Description = UnspecifiedUserProperties.FullName;
		NewUser.SetNewObjectRef(UnspecifiedUserProperties.StandardRef);
		NewUser.DataExchange.Load = True;
		NewUser.Write();
		
		Return NewUser.Ref;
		
	EndIf;
	
EndFunction

// Checks if the IB user description structure is filled in correctly.
// If there are errors, it sets the Denial parameter
// to True and sends errors message.
//
// Parameters:
//  IBUserDescription - Structure - IB user
//                 description that needs to be filled in again.
//
//  Cancel        - Boolean - check box of canceling operation execution.
//                 Set in case an error occurs.
//
// Returns:
//  Boolean - if True, errors are not found.
//
Function CheckIBUserFullName(Val IBUserDescription, Cancel) Export
	
	If IBUserDescription.Property("Name") Then
		Name = IBUserDescription.Name;
		
		If IsBlankString(Name) Then
			// Settings storage uses only first 64 name characters of IB user.
			CommonUseClientServer.MessageToUser(
				NStr("en='Name is not filled (to enter).';ru='Не заполнено Имя (для входа).'"),
				,
				"Name",
				,
				Cancel);
			
		ElsIf StrLen(Name) > 64 Then
			// Authentication via web
			// uses : character as a separator of name and user’s password.
			CommonUseClientServer.MessageToUser(
				NStr("en='Name (for entrance) exceeds 64 symbols.';ru='Имя (для входа) превышает 64 символа.'"),
				,
				"Name",
				,
				Cancel);
			
		ElsIf Find(Name, ":") > 0 Then
			CommonUseClientServer.MessageToUser(
				NStr("en='Name (for login) contains prohibited character :.';ru='Имя (для входа) содержит запрещенный символ "":"".'"),
				,
				"Name",
				,
				Cancel);
				
		Else
			SetPrivilegedMode(True);
			IBUser = InfobaseUsers.FindByName(Name);
			SetPrivilegedMode(False);
			
			If IBUser <> Undefined
			   AND IBUser.UUID
			     <> IBUserDescription.InfobaseUserID Then
				
				FoundUser = Undefined;
				UserByIDExists(
					IBUser.UUID, , FoundUser);
				
				If FoundUser = Undefined
				 OR Not Users.InfobaseUserWithFullAccess() Then
					
					ErrorText = NStr("en='Name (for login) is already occupied.';ru='Имя (для входа) уже занято.'");
				Else
					ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Name (for login) is not available %1.';ru='Имя (для входа) уже занято для пользователя ""%1"".'"),
						String(FoundUser));
				EndIf;
				
				CommonUseClientServer.MessageToUser(
					ErrorText, , "Name", , Cancel);
			EndIf;
		EndIf;
	EndIf;
	
	If IBUserDescription.Property("Password") Then
		
		If IBUserDescription.Password <> Undefined
			AND IBUserDescription.Password
			  <> IBUserDescription.PasswordConfirmation Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en='Password and password confirmation do not match';ru='Пароль и подтверждение пароля не совпадают.'"),
				,
				"Password",
				,
				Cancel);
		EndIf;
		
	EndIf;
	
	If IBUserDescription.Property("OSUser") Then
		
		If Not IsBlankString(IBUserDescription.OSUser)
		   AND Not StandardSubsystemsServer.IsEducationalPlatform() Then
			
			SetPrivilegedMode(True);
			Try
				IBUser = InfobaseUsers.CreateUser();
				IBUser.OSUser = IBUserDescription.OSUser;
			Except
				CommonUseClientServer.MessageToUser(
					NStr("en='OS user must have
		|format ""\\DomainName\UserName"".';ru='OS user must have
		|format ""\\DomainName\UserName"".'"),
					,
					"OSUser",
					,
					Cancel);
			EndTry;
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
	Return Not Cancel;
	
EndFunction

// Writes the specified IB user considering data separation mode.
//  If the data separation mode is enabled, then
// the rights of written user are checked before write.
//
// Parameters:
//  IBUser - InfobaseUser - an object that required record.
//
Procedure WriteInfobaseUser(IBUser) Export
	
	Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.Users\BeforeWriteIBUser");
	For Each Handler IN Handlers Do
		Handler.Module.BeforeWriteIBUser(IBUser.UUID);
	EndDo;
	
	CheckUserRights(IBUser, "OnWrite");
	
	InfobaseUpdateService.SetFlagDisplayDescriptionsForNewUser(IBUser.Name);
	
	IBUser.Write();

EndProcedure

// Checks if IB user exists.
//
// Parameters:
//  ID  - String - IB user
//                   name, UUID - ID of the infobase user.
//
// Returns:
//  Boolean.
//
Function IBUserExists(Val ID) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(ID) = Type("UUID") Then
		IBUser = InfobaseUsers.FindByUUID(ID);
	Else
		IBUser = InfobaseUsers.FindByName(ID);
	EndIf;
	
	If IBUser = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Defines whether there is
// an item in the Users catalog
// or in the ExternalUsers catalog by the unique identifier of the infobase user.
//  Function is used to to check whether
// there is IB user match only with one Users and ExternalUsers catalogs item.
//
// Parameters:
//  UUID - ID of the infobase user.
//
//  RefToCurrent - CatalogRef.Users,
//                     CatalogRef.ExternalUsers - delete
//                       the specified reference from the search.
//                     Undefined - search among all catalogs items.
//
//  FoundUser (Return value):
//                     Undefined - user does not exist.
//                     CatalogRef.Users,
//                     CatalogRef.ExternalUsers if found.
//
//  ServiceUserID - Boolean.
//                     False   - check InfobaseUserID.
//                     True - check ServiceUserID.
//
// Returns:
//  Boolean.
//
Function UserByIDExists(UUID,
                                               RefToCurrent = Undefined,
                                               FoundUser = Undefined,
                                               ServiceUserID = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("RefToCurrent", RefToCurrent);
	Query.SetParameter("UUID", UUID);
	Query.Text = 
	"SELECT
	|	Users.Ref AS User
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID = &UUID
	|	AND Users.Ref <> &RefToCurrent
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfobaseUserID = &UUID
	|	AND ExternalUsers.Ref <> &RefToCurrent";
	
	Result = False;
	FoundUser = Undefined;
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			Selection = QueryResult.Select();
			Selection.Next();
			FoundUser = Selection.User;
			Result = True;
			Users.FindAmbiguousInfobaseUsers(, UUID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
	
EndFunction

// Updates the users contents in users groups considering
// hierarchy in the “Users group contents” information register.
//  Register data is used as list and as users selection.
//  Register data can be used to increase
// queries productivity as no need to work with hierarchy.
//
// Parameters:
//  UsersGroup - CatalogRef.UsersGroups.
//
//  User - Undefined                                  - for all users.
//               - Values array CatalogRef.Users - for the specified users.
//               - CatalogRef.Users                 - for the specified user.
//
//  ParticipantsOfChange - Undefined - no actions.
//                     - Array (return value) - fills in
//                       the array with users for which there are changes.
//
//  ChangedGroups   - Undefined - no actions.
//                     - Array (return value) - fills in the
//                       array with users groups for which there are changes.
//
Procedure UpdateUsersGroupsContents(Val UsersGroup,
                                            Val User       = Undefined,
                                            Val ParticipantsOfChange = Undefined,
                                            Val ChangedGroups   = Undefined) Export
	
	If Not ValueIsFilled(UsersGroup) Then
		Return;
	EndIf;
	
	If TypeOf(User) = Type("Array") AND User.Count() = 0 Then
		Return;
	EndIf;
	
	If ParticipantsOfChange = Undefined Then
		CurrentChangeParticipants = New Map;
	Else
		CurrentChangeParticipants = ParticipantsOfChange;
	EndIf;
	
	If ChangedGroups = Undefined Then
		CurrentChangedGroups = New Map;
	Else
		CurrentChangedGroups = ChangedGroups;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If UsersGroup = Catalogs.UsersGroups.AllUsers Then
			
			UpdateAllUsersGroupContent(
				User, , CurrentChangeParticipants, CurrentChangedGroups);
		Else
			UpdateHierarhicalUsersGroupsContents(
				UsersGroup,
				User,
				CurrentChangeParticipants,
				CurrentChangedGroups);
		EndIf;
		
		If ParticipantsOfChange = Undefined
		   AND ChangedGroups   = Undefined Then
			
			AfterUserGroupStavesUpdating(
				CurrentChangeParticipants, CurrentChangedGroups);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Update resource Used on attributes change DeletionMarkup, NotValid.
//
// Parameters:
//  UserOrGroup - CatalogRef.Users,
//                        - CatalogRef.ExternalUser,
//                        - CatalogRef.UsersGroups,
//                        - CatalogRef.ExternalUsersGroups.
//
//  ParticipantsOfChange - Array (return value) - fills in array
//                       with users or external users for which there are changes.
//
//  ChangedGroups   - Array (return value) - fills in the array
//                       with users group or external users group for which there are changes.
//
Procedure RefreshUsabilityRateOfUsersGroups(Val UserOrGroup,
                                                           Val ParticipantsOfChange,
                                                           Val ChangedGroups) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("UserOrGroup", UserOrGroup);
	Query.Text =
	"SELECT
	|	UsersGroupsContents.UsersGroup,
	|	UsersGroupsContents.User,
	|	CASE
	|		WHEN UsersGroupsContents.UsersGroup.DeletionMark
	|			THEN FALSE
	|		WHEN UsersGroupsContents.User.DeletionMark
	|			THEN FALSE
	|		WHEN UsersGroupsContents.User.NotValid
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Used
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	&Filter
	|	AND CASE
	|			WHEN UsersGroupsContents.UsersGroup.DeletionMark
	|				THEN FALSE
	|			WHEN UsersGroupsContents.User.DeletionMark
	|				THEN FALSE
	|			WHEN UsersGroupsContents.User.NotValid
	|				THEN FALSE
	|			ELSE TRUE
	|		END <> UsersGroupsContents.Used";
	
	If TypeOf(UserOrGroup) = Type("CatalogRef.Users")
	 OR TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
		
		Query.Text = StrReplace(Query.Text, "&Filter",
			"UsersGroupsContents.User = &UserOrGroup");
	Else
		Query.Text = StrReplace(Query.Text, "&Filter",
			"UsersGroupsContents.UsersGroup = &UserOrGroup");
	EndIf;
	
	RecordSet = InformationRegisters.UsersGroupsContents.CreateRecordSet();
	Record = RecordSet.Add();
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			RecordSet.Filter.UsersGroups.Set(Selection.UsersGroup);
			RecordSet.Filter.User.Set(Selection.User);
			
			Record.UsersGroup = Selection.UsersGroup;
			Record.User        = Selection.User;
			Record.Used        = Selection.Used;
			
			RecordSet.Write();
			
			ChangedGroups.Insert(Selection.UsersGroup);
			ParticipantsOfChange.Insert(Selection.User);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure AfterUserGroupStavesUpdating(ParticipantsOfChange, ChangedGroups) Export
	
	If ParticipantsOfChange.Count() = 0 Then
		Return;
	EndIf;
	
	ChangesParticipantsArray = New Array;
	
	For Each KeyAndValue IN ParticipantsOfChange Do
		ChangesParticipantsArray.Add(KeyAndValue.Key);
	EndDo;
	
	ChangedGroupsArray = New Array;
	For Each KeyAndValue IN ChangedGroups Do
		ChangedGroupsArray.Add(KeyAndValue.Key);
	EndDo;
	
	AfterUpdateCompositionsOfGroupsUsersOverridable(ChangesParticipantsArray, ChangedGroupsArray);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of work with external users.

// Updates the external users contents in the
// external users groups considering the hierarchy in the "Users group contents" information register.
//  Data is used as list and as external users selection.
//  Data can be used to increase productivity
// as it is not required to work with hierarchy using the queries language.
//
// Parameters:
//  ExternalUserGroup - CatalogRef.ExternalUsersGroups
//                        When AllExternalUsers group is specified, all
//                        automatic groups of external users by the authorization objects types are also updated.
//
//  ExternalUser - Undefined                         - for all external users.
//                      - Array of CatalogRef.ExternalUsers values
//                                                             - for external users specified above.
//                      - CatalogRef.ExternalUsers - for the specified external user.
//
//  ParticipantsOfChange  - Undefined - no actions.
//                      - Array (return value) - fills in
//                        the array with external users for which there are changes.
//
//  ChangedGroups   - Undefined - no actions.
//                     - Array (return value) - fills in array
//                       with external users groups for which there are changes.
//
Procedure UpdateExternalUsersGroupsStaves(Val ExternalUserGroup,
                                                   Val ExternalUser = Undefined,
                                                   Val ParticipantsOfChange  = Undefined,
                                                   Val ChangedGroups    = Undefined) Export
	
	If Not ValueIsFilled(ExternalUserGroup) Then
		Return;
	EndIf;
	
	If TypeOf(ExternalUser) = Type("Array") AND ExternalUser.Count() = 0 Then
		Return;
	EndIf;
	
	If ParticipantsOfChange = Undefined Then
		CurrentChangeParticipants = New Map;
	Else
		CurrentChangeParticipants = ParticipantsOfChange;
	EndIf;
	
	If ChangedGroups = Undefined Then
		CurrentChangedGroups = New Map;
	Else
		CurrentChangedGroups = ChangedGroups;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If ExternalUserGroup = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			UpdateAllUsersGroupContent(
				ExternalUser, True, CurrentChangeParticipants, CurrentChangedGroups);
			
			UpdateGroupsContentByAuthorizationObjectTypes(
				, ExternalUser, CurrentChangeParticipants, CurrentChangedGroups);
			
		ElsIf CommonUse.ObjectAttributeValue(
		            ExternalUserGroup, "AllAuthorizationObjects") = True Then
			
			UpdateGroupsContentByAuthorizationObjectTypes(
				ExternalUserGroup,
				ExternalUser,
				CurrentChangeParticipants,
				CurrentChangedGroups);
		Else
			UpdateHierarhicalUsersGroupsContents(
				ExternalUserGroup,
				ExternalUser,
				CurrentChangeParticipants,
				CurrentChangedGroups);
		EndIf;
		
		If ParticipantsOfChange = Undefined
		   AND ChangedGroups    = Undefined Then
			
			AfterExternalUsersGroupsStavesUpdating(
				CurrentChangeParticipants, CurrentChangedGroups);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure AfterExternalUsersGroupsStavesUpdating(ParticipantsOfChange, ChangedGroups) Export
	
	If ParticipantsOfChange.Count() = 0 Then
		Return;
	EndIf;
	
	ChangesParticipantsArray = New Array;
	For Each KeyAndValue IN ParticipantsOfChange Do
		ChangesParticipantsArray.Add(KeyAndValue.Key);
	EndDo;
	
	RefreshRolesOfExternalUsers(ChangesParticipantsArray);
	
	ChangedGroupsArray = New Array;
	For Each KeyAndValue IN ChangedGroups Do
		ChangedGroupsArray.Add(KeyAndValue.Key);
	EndDo;
	
	AfterUpdateCompositionsOfGroupsUsersOverridable(ChangesParticipantsArray, ChangedGroupsArray);
	
EndProcedure

// Updates IB users roles list
// that match external users. Roles content is calculated based
// on the occurrence of external users to external users
// groups in addition to those external users for which roles are set directly.
//  It is required only if it is
// allowed to edit roles, for example if the Access management subsystem is embedded, then this procedure is not required.
// 
// Parameters:
//  ExternalUserArray - Undefined - all external users.
//                               CatalogRef.ExternalUsersGroup,
//                               Array of CatalogRef.ExternalUsers items.
//
Procedure RefreshRolesOfExternalUsers(Val ExternalUserArray = Undefined) Export
	
	If BanEditOfRoles() Then
		// Roles are set by another mechanism, for example, AccessManagement subsystem mechanism.
		Return;
	EndIf;
	
	If TypeOf(ExternalUserArray) = Type("Array")
	   AND ExternalUserArray.Count() = 0 Then
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If TypeOf(ExternalUserArray) <> Type("Array") Then
			
			If ExternalUserArray = Undefined Then
				ExternalUserGroup = Catalogs.ExternalUsersGroups.AllExternalUsers;
			Else
				ExternalUserGroup = ExternalUserArray;
			EndIf;
			
			Query = New Query;
			Query.SetParameter("ExternalUserGroup", ExternalUserGroup);
			Query.Text =
			"SELECT
			|	UsersGroupsContents.User
			|FROM
			|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
			|WHERE
			|	UsersGroupsContents.UsersGroup = &ExternalUserGroup";
			
			ExternalUserArray = Query.Execute().Unload().UnloadColumn("User");
		EndIf;
		
		Users.FindAmbiguousInfobaseUsers(,);
		
		InfobaseUserIDs = New Map;
		
		Query = New Query;
		Query.SetParameter("ExternalUsers", ExternalUserArray);
		Query.Text =
		"SELECT
		|	ExternalUsers.Ref AS ExternalUser,
		|	ExternalUsers.InfobaseUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.Ref IN(&ExternalUsers)
		|	AND (NOT ExternalUsers.SetRolesDirectly)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			InfobaseUserIDs.Insert(
				Selection.ExternalUser, Selection.InfobaseUserID);
		EndDo;
		
		// Prepare table of external users old roles.
		OldExternalUserRoles = New ValueTable;
		
		OldExternalUserRoles.Columns.Add(
			"ExternalUser", New TypeDescription("CatalogRef.ExternalUsers"));
		
		OldExternalUserRoles.Columns.Add(
			"Role", New TypeDescription("String", , New StringQualifiers(200)));
		
		CurrentNumber = ExternalUserArray.Count() - 1;
		While CurrentNumber >= 0 Do
			
			// Check if it is necessary to process user.
			IBUser = Undefined;
			InfobaseUserID = InfobaseUserIDs[ExternalUserArray[CurrentNumber]];
			If InfobaseUserID <> Undefined Then
				
				IBUser = InfobaseUsers.FindByUUID(
					InfobaseUserID);
			EndIf;
			
			If IBUser = Undefined
			 OR IsBlankString(IBUser.Name) Then
				
				ExternalUserArray.Delete(CurrentNumber);
			Else
				For Each Role IN IBUser.Roles Do
					OldExternalUserRole = OldExternalUserRoles.Add();
					OldExternalUserRole.ExternalUser = ExternalUserArray[CurrentNumber];
					OldExternalUserRole.Role = Role.Name;
				EndDo;
			EndIf;
			CurrentNumber = CurrentNumber - 1;
		EndDo;
		
		// Prepare the list of roles missing in metadata and that need to be reset.
		Query = New Query;
		Query.TempTablesManager = New TempTablesManager;
		Query.SetParameter("ExternalUsers", ExternalUserArray);
		Query.SetParameter("AllRoles", AllRoles().Table);
		Query.SetParameter("OldExternalUserRoles", OldExternalUserRoles);
		Query.SetParameter("UseExternalUsers",
			GetFunctionalOption("UseExternalUsers"));
		Query.Text =
		"SELECT
		|	OldExternalUserRoles.ExternalUser,
		|	OldExternalUserRoles.Role
		|INTO OldExternalUserRoles
		|FROM
		|	&OldExternalUserRoles AS OldExternalUserRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllRoles.Name
		|INTO AllRoles
		|FROM
		|	&AllRoles AS AllRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	UsersGroupsContents.UsersGroup AS ExternalUserGroup,
		|	UsersGroupsContents.User AS ExternalUser,
		|	Roles.Role.Name AS Role
		|INTO AllNewExternalUserRoles
		|FROM
		|	Catalog.ExternalUsersGroups.Roles AS Roles
		|		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
		|		ON (UsersGroupsContents.User IN (&ExternalUsers))
		|			AND (UsersGroupsContents.UsersGroup = Roles.Ref)
		|			AND (&UseExternalUsers = TRUE)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	AllNewExternalUserRoles.ExternalUser,
		|	AllNewExternalUserRoles.Role
		|INTO NewExternalUserRoles
		|FROM
		|	AllNewExternalUserRoles AS AllNewExternalUserRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OldExternalUserRoles.ExternalUser
		|INTO ModifiedExternalUsers
		|FROM
		|	OldExternalUserRoles AS OldExternalUserRoles
		|		LEFT JOIN NewExternalUserRoles AS NewExternalUserRoles
		|		ON (NewExternalUserRoles.ExternalUser = OldExternalUserRoles.ExternalUser)
		|			AND (NewExternalUserRoles.Role = OldExternalUserRoles.Role)
		|WHERE
		|	NewExternalUserRoles.Role IS NULL 
		|
		|UNION
		|
		|SELECT
		|	NewExternalUserRoles.ExternalUser
		|FROM
		|	NewExternalUserRoles AS NewExternalUserRoles
		|		LEFT JOIN OldExternalUserRoles AS OldExternalUserRoles
		|		ON NewExternalUserRoles.ExternalUser = OldExternalUserRoles.ExternalUser
		|			AND NewExternalUserRoles.Role = OldExternalUserRoles.Role
		|WHERE
		|	OldExternalUserRoles.Role IS NULL 
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllNewExternalUserRoles.ExternalUserGroup,
		|	AllNewExternalUserRoles.ExternalUser,
		|	AllNewExternalUserRoles.Role
		|FROM
		|	AllNewExternalUserRoles AS AllNewExternalUserRoles
		|WHERE
		|	Not TRUE In
		|				(SELECT TOP 1
		|					TRUE AS TrueValue
		|				FROM
		|					AllRoles AS AllRoles
		|				WHERE
		|					AllRoles.Name = AllNewExternalUserRoles.Role)";
		
		// Registration of roles names errors in access group profiles.
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='While updating external
		|user
		|roles %1
		|role %2 of external
		|users group %3 is not found in metadata.';ru='При обновлении
		|ролей
		|внешнего пользователя
		|""%1"" роль
		|""%2"" группы внешних пользователей ""%3"" не найдена в метаданных.'"),
				TrimAll(Selection.ExternalUser.Description),
				Selection.Role,
				String(Selection.ExternalUserGroup));
			
			WriteLogEvent(
				NStr("en='Users.Role is not found in the metadata';ru='Пользователи.Роль не найдена в метаданных'",
				     CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				MessageText,
				EventLogEntryTransactionMode.Transactional);
		EndDo;
		
		// Update IB users roles.
		Query.Text =
		"SELECT
		|	ChangedExternalUsersAndRoles.ExternalUser,
		|	ChangedExternalUsersAndRoles.Role
		|FROM
		|	(SELECT
		|		NewExternalUserRoles.ExternalUser AS ExternalUser,
		|		NewExternalUserRoles.Role AS Role
		|	FROM
		|		NewExternalUserRoles AS NewExternalUserRoles
		|	WHERE
		|		NewExternalUserRoles.ExternalUser In
		|				(SELECT
		|					ModifiedExternalUsers.ExternalUser
		|				FROM
		|					ModifiedExternalUsers AS ModifiedExternalUsers)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ExternalUsers.Ref,
		|		""""
		|	FROM
		|		Catalog.ExternalUsers AS ExternalUsers
		|	WHERE
		|		ExternalUsers.Ref In
		|				(SELECT
		|					ModifiedExternalUsers.ExternalUser
		|				FROM
		|					ModifiedExternalUsers AS ModifiedExternalUsers)) AS ChangedExternalUsersAndRoles
		|
		|ORDER BY
		|	ChangedExternalUsersAndRoles.ExternalUser,
		|	ChangedExternalUsersAndRoles.Role";
		Selection = Query.Execute().Select();
		
		IBUser = Undefined;
		While Selection.Next() Do
			If ValueIsFilled(Selection.Role) Then
				IBUser.Roles.Add(Metadata.Roles[Selection.Role]);
				Continue;
			EndIf;
			If IBUser <> Undefined Then
				IBUser.Write();
			EndIf;
			
			IBUser = InfobaseUsers.FindByUUID(
				InfobaseUserIDs[Selection.ExternalUser]);
			
			IBUser.Roles.Clear();
		EndDo;
		If IBUser <> Undefined Then
			IBUser.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks if the infobase object is used as
// the authorization object of any external user except the specified external user (if any).
//
Function AuthorizationObjectInUse(Val AuthorizationObjectRef,
                                      Val CurrentExternalUserRef,
                                      FoundExternalUser = Undefined,
                                      CanAddExternalUser = False,
                                      ErrorText = "") Export
	
	CanAddExternalUser = AccessRight(
		"Insert", Metadata.Catalogs.ExternalUsers);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.AuthorizationObject = &AuthorizationObjectRef
	|	AND ExternalUsers.Ref <> &CurrentExternalUserRef";
	Query.SetParameter("CurrentExternalUserRef", CurrentExternalUserRef);
	Query.SetParameter("AuthorizationObjectRef", AuthorizationObjectRef);
	
	BeginTransaction();
	Try
		Table = Query.Execute().Unload();
		If Table.Count() > 0 Then
			FoundExternalUser = Table[0].Ref;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Result = Table.Count() > 0;
	If Result Then
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='External user connected to object %1 already exists.';ru='Уже существует внешний пользователь, связанный с объектом ""%1"".'"),
			AuthorizationObjectRef);
		EndIf;
	Return Result;
	
EndFunction

// Updates presentation of external user while changing authorization object changing.
Procedure UpdateExternalUserPresentation(AuthorizationObjectRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT TOP 1
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.AuthorizationObject = &AuthorizationObjectRef
	|	AND ExternalUsers.Description <> &NewAuthorizationObjectPresentation");
	Query.SetParameter("AuthorizationObjectRef", AuthorizationObjectRef);
	Query.SetParameter("NewAuthorizationObjectPresentation", String(AuthorizationObjectRef));
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			Selection = QueryResult.Select();
			Selection.Next();
			
			ExternalUserObject = Selection.Ref.GetObject();
			ExternalUserObject.Description = String(AuthorizationObjectRef);
			ExternalUserObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with infobase user settings.

// Copies settings from the source user to the user receiver. When
// the parameter value Move = True source user settings are removed.
//
// Parameters:
// UserNameSource - String - Name of IB user from which the settings will be copied.
//
// UserNameRecipient - String - Name of IB user to which settings will be written.
//
// Wrap              - Boolean - If True - settings are transferred from
//                           one user to another if False - are copied to a new one.
//
Procedure CopyUserSettings(UserNameSource, UserNameRecipient, Wrap = False) Export
	
	// Move reports user settings.
	CopySettings(ReportsUserSettingsStorage, UserNameSource, UserNameRecipient, Wrap);
	// Transfer appearance settings.
	CopySettings(SystemSettingsStorage,UserNameSource, UserNameRecipient, Wrap);
	// Move custom user settings.
	CopySettings(CommonSettingsStorage, UserNameSource, UserNameRecipient, Wrap);
	// Forms data settings transfer.
	CopySettings(FormDataSettingsStorage, UserNameSource, UserNameRecipient, Wrap);
	// Transfer fast access settings of additional reports and processors.
	If Not Wrap Then
		CopyOtherUserSettings(UserNameSource, UserNameRecipient);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to transfer users between groups.

// Moves user from one group to another.
//
// Parameters:
//  UserArray - Array - users that should be transferred to a new group.
//  GroupSource      - CatalogRef.UsersGroups - group from
//                        which users are transferred.
//  GroupReceiver      - CatalogRef.UsersGroups - group to
//                        which users are transferred.
//  Move         - Boolean - if true, then the user is removed from the old group.
//
// ReturnValue:
//  String - Message on the transfer result.
//
Function UserTransferToNewGroup(UserArray, GroupSource,
												GroupReceiver, Move) Export
	
	If GroupReceiver = Undefined
		Or GroupReceiver = GroupSource Then
		Return Undefined;
	EndIf;
	DisplacedUsersArray = New Array;
	ArrayIsNotDisplacedUsers = New Array;
	
	For Each UserRef IN UserArray Do
		
		If TypeOf(UserRef) <> Type("CatalogRef.Users")
			AND TypeOf(UserRef) <> Type("CatalogRef.ExternalUsers") Then
			Continue;
		EndIf;
		
		If Not PossibleUsersMove(GroupReceiver, UserRef) Then
			ArrayIsNotDisplacedUsers.Add(UserRef);
			Continue;
		EndIf;
		
		If TypeOf(UserRef) = Type("CatalogRef.Users") Then
			ContentColumnName = "User";
		Else
			ContentColumnName = "ExternalUser";
		EndIf;
		
		// If transferred user is not included in a new group, then transfer.
		If GroupReceiver = Catalogs.UsersGroups.AllUsers
			Or GroupReceiver = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			If Move Then
				DeleteUserFromGroup(GroupSource, UserRef, ContentColumnName);
			EndIf;
			DisplacedUsersArray.Add(UserRef);
			
		ElsIf GroupReceiver.Content.Find(UserRef, ContentColumnName) = Undefined Then
			
			AddUserToGroup(GroupReceiver, UserRef, ContentColumnName);
			
			// Delete user from the old group.
			If Move Then
				DeleteUserFromGroup(GroupSource, UserRef, ContentColumnName);
			EndIf;
			
			DisplacedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	UserMessage = GeneratingMessageToUser(
		DisplacedUsersArray, GroupReceiver, Move, ArrayIsNotDisplacedUsers, GroupSource);
	
	If DisplacedUsersArray.Count() = 0 AND ArrayIsNotDisplacedUsers.Count() = 0 Then
		If UserArray.Count() = 1 Then
			MessageText = NStr("en='User %1 is included in the group %2.';ru='Пользователь ""%1"" уже включен в группу ""%2"".'");
			NameRoamingUser = CommonUse.ObjectAttributeValue(UserArray[0], "Description");
		Else
			MessageText = NStr("en='All selected users are already included in group %2.';ru='Все выбранные пользователи уже включены в группу ""%2"".'");
			NameRoamingUser = "";
		EndIf;
		GroupDescription = CommonUse.ObjectAttributeValue(GroupReceiver, "Description");
		UserMessage.Message = StringFunctionsClientServer.PlaceParametersIntoString(
			MessageText, NameRoamingUser, GroupDescription);
		UserMessage.HasErrors = True;
		Return UserMessage;
	EndIf;
	
	Return UserMessage;
	
EndFunction

// Checks if it is possibile to include external user in group.
//
// Parameters:
//  GroupsReceiver     - CatalogRef.UsersGroup,
//                       group to which user is added.
//  UserRef - CatalogRef.User - user that
//                       should be added to group.
//
// Returns:
//  Boolean             - False if a user can not be added to group.
//
Function PossibleUsersMove(GroupReceiver, UserRef) Export
	
	If TypeOf(UserRef) = Type("CatalogRef.ExternalUsers") Then
		
		If TypeOf(GroupReceiver.TypeOfAuthorizationObjects) <> Type("Undefined")
			AND TypeOf(UserRef.AuthorizationObject) <> TypeOf(GroupReceiver.TypeOfAuthorizationObjects)
			Or GroupReceiver.AllAuthorizationObjects Then
			Return False;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

// Adds user to a group.
//
// Parameters:
//  GroupReceiver     - CatalogRef.UsersGroups - group to
//                       which a user is transferred.
//  UserRef - CatalogRef.User - user that
//                       should be added to group.
//  UserType    - String - ExternalUser or User.
//
Procedure AddUserToGroup(GroupReceiver, UserRef, UserType) Export
	
	BeginTransaction();
	Try
		
		GroupReceiverObject = GroupReceiver.GetObject();
		ContentRow = GroupReceiverObject.Content.Add();
		If UserType = "ExternalUser" Then
			ContentRow.ExternalUser = UserRef;
		Else
			ContentRow.User = UserRef;
		EndIf;
		
		GroupReceiverObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Deletes user from group.
//
// Parameters:
//  GroupReceiver     - CatalogRef.UsersGroups - group from
//                       which user is deleted.
//  UserRef - CatalogRef.User - user that
//                       should be added to group.
//  UserType    - String - ExternalUser or User.
//
Procedure DeleteUserFromGroup(GroupOwner, UserRef, UserType) Export
	
	BeginTransaction();
	Try
		
		GroupOwnerObject = GroupOwner.GetObject();
		If GroupOwnerObject.Content.Count() <> 0 Then
			GroupOwnerObject.Content.Delete(GroupOwnerObject.Content.Find(UserRef, UserType));
			GroupOwnerObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Generates the calculation subject end.
//
// Parameters:
//  ConvertedNumber          - Number - number for which you
//                                need to receive the calculation subject end.
//
Function WordEndingGenerating(ConvertedNumber, MeasurementUnitInWordParameters = Undefined) Export
	
	If MeasurementUnitInWordParameters = Undefined Then
		MeasurementUnitInWordParameters = NStr("en='user,of user,users,,,,,,0';ru='user,of user,users,,,,,,0'");
	EndIf;
	
	NumberInWords = NumberInWords(
		ConvertedNumber,
		"L=en_US",
		NStr("en=',,,,,,,,0';ru=',,,,,,,,0'"));
	SubjectAndNumberInWords = NumberInWords(
		ConvertedNumber,
		"L=en_US",
		MeasurementUnitInWordParameters);
	SubjectInWords = StrReplace(
		SubjectAndNumberInWords,
		NumberInWords,
		Format(ConvertedNumber, "NFD=0") + " ");
		
	Return SubjectInWords;
EndFunction

// Generates message about user transfer result.
//
// Parameters:
//  UserArray - Array - users that should be transferred to a new group.
//  GroupSource      - CatalogRef.UsersGroups - group from
//                        which users are transferred.
//  GroupReceiver      - CatalogRef.UsersGroups - group to
//                        which users are transferred.
//  Move         - Boolean - if true, then the user is removed from the old group.
//
// ReturnValue:
//  String - Message to user.
//
Function GeneratingMessageToUser(UserArray, GroupReceiver,
											Move, ArrayIsNotDisplacedUsers, GroupSource = Undefined) Export
	
	UserCount = UserArray.Count();
	GroupDescription = CommonUse.ObjectAttributeValue(GroupReceiver, "Description");
	UserMessage = Undefined;
	QuantityNotDisplacedUsers = ArrayIsNotDisplacedUsers.Count();
	
	UserNotification = New Structure;
	UserNotification.Insert("Message");
	UserNotification.Insert("HasErrors");
	UserNotification.Insert("Users");
	
	If QuantityNotDisplacedUsers > 0 Then
		
		If QuantityNotDisplacedUsers = 1 Then
			Subject = CommonUse.ObjectAttributeValue(ArrayIsNotDisplacedUsers[0], "Description");
			UserTypeIsSameAsWithGroup = (TypeOf(ArrayIsNotDisplacedUsers[0].AuthorizationObject) = 
												TypeOf(GroupReceiver.TypeOfAuthorizationObjects));
			UserNotification.Users = Undefined;
			UserMessage = NStr("en='User %1 can not be included in group %2,';ru='Пользователь ""%1"" не может быть включен в группу ""%2"",'");
			UserMessage = UserMessage + Chars.LF + 
									?(NOT UserTypeIsSameAsWithGroup, 
									NStr("en='T.k. its participants structure includes only %3.';ru='Т.к. в состав ее участников входят только %3.'"),
									NStr("en='T.k. group has ""All users of the specified type"" flag.';ru='Т.к. у группы стоит признак ""Все пользователи заданного типа"".'"));
		Else
			Subject = "";
			UserNotification.Users = StringFunctionsClientServer.RowFromArraySubrows(ArrayIsNotDisplacedUsers, Chars.LF);
			UserMessage = NStr("en='Not all users can be included in
		|group %2 as only %3 are included in the
		|content of its participants or the group has a flag ""All users of the specified type"".';ru='Не все пользователи могут быть включены в группу ""%2"",
		|т.к. в состав ее участников входят только %3
		|или у группы стоит признак ""Все пользователи заданного типа"".'");
		EndIf;
		
		AuthorizationObjectTypePresentationItem = Metadata.FindByType(TypeOf(GroupReceiver.TypeOfAuthorizationObjects)).Synonym;
		
		GroupDescription = CommonUse.ObjectAttributeValue(GroupReceiver, "Description");
		UserMessage = StringFunctionsClientServer.PlaceParametersIntoString(
			UserMessage, Subject, GroupDescription, Lower(AuthorizationObjectTypePresentationItem));
		
		UserNotification.Message = UserMessage;
		UserNotification.HasErrors = True;
		
		Return UserNotification;
		
	ElsIf UserCount = 1 Then
		
		RowObject = CommonUse.ObjectAttributeValue(UserArray[0], "Description");
		If GroupReceiver = Catalogs.UsersGroups.AllUsers
			Or GroupReceiver = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			StringAction = NStr("en='excluded from group';ru='исключен из группы'");
			GroupDescription = CommonUse.ObjectAttributeValue(GroupSource, "Description");
		ElsIf Move Then
			StringAction = NStr("en='moved to group';ru='перемещен в группу'");
		Else
			StringAction = NStr("en='included in group';ru='включен в группу'");
		EndIf;
		
		UserMessage = NStr("en='""%1"" %2 ""%3""';ru='""%1"" %2 ""%3""'");
	ElsIf UserCount > 1 Then
		
		RowObject = WordEndingGenerating(UserCount);
		If GroupReceiver = Catalogs.UsersGroups.AllUsers Then
			StringAction = NStr("en='Excluded from group';ru='исключены из группы'");
			GroupDescription = CommonUse.ObjectAttributeValue(GroupSource, "Description");
		ElsIf Move Then
			StringAction = NStr("en='are moved to group';ru='перемещены в группу'");
		Else
			StringAction = NStr("en='include in goup';ru='включены в группу'");
		EndIf;
		UserMessage = NStr("en='%1 %2 ""%3""';ru='%1 %2 ""%3""'");
	EndIf;
	
	If UserMessage <> Undefined Then
		UserMessage = StringFunctionsClientServer.PlaceParametersIntoString(
			UserMessage, RowObject, StringAction, GroupDescription);
	EndIf;
	
	UserNotification.Message = UserMessage;
	UserNotification.HasErrors = False;
	
	Return UserNotification;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Generic procedures and functions.

// Returns nonmatching values in the values tables column.
//
// Parameters:
//  ColumnName - String - name of the compared column.
//  Table1   - ValuesTable.
//  Table2   - ValuesTable.
//
// Returns:
//  Array of values that present only in column of one of the tables.
// 
Function ColumnValuesDifferences(ColumnName, Table1, Table2) Export
	
	If TypeOf(Table1) <> Type("ValueTable")
	   AND TypeOf(Table2) <> Type("ValueTable") Then
		
		Return New Array;
	EndIf;
	
	If TypeOf(Table1) <> Type("ValueTable") Then
		Return Table2.UnloadColumn(ColumnName);
	EndIf;
	
	If TypeOf(Table2) <> Type("ValueTable") Then
		Return Table1.UnloadColumn(ColumnName);
	EndIf;
	
	Table11 = Table1.Copy(, ColumnName);
	Table11.GroupBy(ColumnName);
	
	Table22 = Table2.Copy(, ColumnName);
	Table22.GroupBy(ColumnName);
	
	For Each String IN Table22 Do
		NewRow = Table11.Add();
		NewRow[ColumnName] = String[ColumnName];
	EndDo;
	
	Table11.Columns.Add("SignOf");
	Table11.FillValues(1, "SignOf");
	
	Table11.GroupBy(ColumnName, "SignOf");
	
	Filter = New Structure("SignOf", 1);
	Table = Table11.Copy(Table11.FindRows(Filter));
	
	Return Table.UnloadColumn(ColumnName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Updates helper data that depend
// only on configuration.
// Writes changes of this data
// by the configuration versions (if there are
// changes) to use these changes when
// you update the rest of helper data, for example, in the UpdateAuxiliaryDataOnIBUpdate handler.
//
Procedure UpdateUsersWorkParameters(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.UsersWorkParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Constants.UsersWorkParameters.CreateValueManager().RefreshGeneralParameters(HasChanges, CheckOnly);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

// Called during the configuration update up to version 1.0.5.2.
// Attempts to match / fill
// in attribute "InfobaseUserID" for each item of the Users catalog.
//
Procedure FillUserIDs() Export
	
	SetPrivilegedMode(True);
	
	Users.FindAmbiguousInfobaseUsers(,);
	
	IBUsers = InfobaseUsers.GetUsers();
	
	Query = New Query;
	
	Query.SetParameter("EmptyID",
		New UUID("00000000-0000-0000-0000-000000000000") );
	
	Query.SetParameter("UnspecifiedUser",
		UnspecifiedUserProperties().Ref);
	
	Query.Text =
	"SELECT
	|	Users.InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|
	|UNION
	|
	|SELECT
	|	ExternalUsers.InfobaseUserID
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Users.Ref AS Ref,
	|	Users.Description AS Description
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref <> &UnspecifiedUser
	|	AND Users.InfobaseUserID = &EmptyID";
	
	ResultsOfQuery = Query.ExecuteBatch();
	
	If ResultsOfQuery[1].IsEmpty() Then
		Return;
	EndIf;
	
	HeldByIdentifiers = ResultsOfQuery[0].Unload();
	HeldByIdentifiers.Indexes.Add("InfobaseUserID");
	
	LengthOfName = Metadata.Catalogs.Users.DescriptionLength;
	FreeUsers = ResultsOfQuery[1].Unload();
	FreeUsers.Indexes.Add("Description");
	
	For Each String IN FreeUsers Do
		String.Description = Upper(TrimAll(String.Description));
	EndDo;
	
	For Each IBUser IN IBUsers Do
		
		If HeldByIdentifiers.Find(
		      IBUser.UUID,
		      "InfobaseUserID") <> Undefined Then
			
			Continue;
		EndIf;
		
		UserFullName = Upper(TrimAll(Left(IBUser.FullName, LengthOfName)));
		
		UserDetails = FreeUsers.Find(UserFullName, "Description");
		If UserDetails <> Undefined Then
			UserObject = UserDetails.Ref.GetObject();
			UserObject.InfobaseUserID = IBUser.UUID;
			InfobaseUpdate.WriteData(UserObject);
		EndIf;
	EndDo;
	
EndProcedure

// Converts the DeleteRole attribute to the Role role attribute in
// the Role tabular section of the External users catalog catalog.
//
Procedure ConvertRolesNamesToIdentifiers() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Roles.Ref AS Ref
	|FROM
	|	Catalog.ExternalUsersGroups.Roles AS Roles
	|WHERE
	|	Not(Roles.Role <> VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|				AND Roles.DeleteRole = """")";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		IndexOf = Object.Roles.Count()-1;
		While IndexOf >= 0 Do
			String = Object.Roles[IndexOf];
			If ValueIsFilled(String.Role) Then
				String.DeleteRole = "";
			ElsIf ValueIsFilled(String.DeleteRole) Then
				RoleMetadata = Metadata.Roles.Find(String.DeleteRole);
				If RoleMetadata <> Undefined Then
					String.DeleteRole = "";
					String.Role = CommonUse.MetadataObjectID(
						RoleMetadata);
				Else
					Object.Roles.Delete(IndexOf);
				EndIf;
			Else
				Object.Roles.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf-1;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Called during transition to configuration 2 version.1.3.16.
Procedure UpdateUsersPredefinedContactInformationTypes() Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return;
	EndIf;
	
	ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
	
	ParametersKind = ModuleContactInformationManagement.ParametersKindContactInformation("EmailAddress");
	ParametersKind.Kind = "UserEmail";
	ParametersKind.ToolTip = NStr("en='User email address';ru='Адрес электронной почты пользователя'");
	ParametersKind.EditMethodEditable = True;
	ParametersKind.AllowInputOfMultipleValues = True;
	ParametersKind.Order = 1;
	ModuleContactInformationManagement.SetPropertiesContactInformationKind(ParametersKind);
	
	ParametersKind = ModuleContactInformationManagement.ParametersKindContactInformation("Phone");
	ParametersKind.Kind = "UserPhone";
	ParametersKind.ToolTip = NStr("en='Use contact phone number';ru='Контактный телефон пользователя'");
	ParametersKind.EditMethodEditable = True;
	ParametersKind.AllowInputOfMultipleValues = True;
	ParametersKind.Order = 2;
	ModuleContactInformationManagement.SetPropertiesContactInformationKind(ParametersKind);
	
EndProcedure

// Called during transition to configuration 2 version.1.4.19.
Procedure MoveExternalUsersGroupsInRoot() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ExternalUsersGroups.Ref
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	ExternalUsersGroups.Parent.AllAuthorizationObjects = TRUE";
	
	Result = Query.Execute().Unload();
	
	For Each RowUsersGroup IN Result Do
		UsersGroup = RowUsersGroup.Ref.GetObject();
		UsersGroup.Parent = Catalogs.ExternalUsersGroups.EmptyRef();
		InfobaseUpdate.WriteData(UsersGroup);
	EndDo;
	
EndProcedure

// Called during the transition to the new configuration 2 version.2.2.3.
Procedure FillUsersAuthenticationProperties() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("EmptyInfobaseUserID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfobaseUserID,
	|	Users.InfobaseUserProperties
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID <> &EmptyInfobaseUserID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.InfobaseUserID,
	|	ExternalUsers.InfobaseUserProperties
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfobaseUserID <> &EmptyInfobaseUserID";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		IBUser = InfobaseUsers.FindByUUID(
			Selection.InfobaseUserID);
		
		If IBUser = Undefined
		 Or Not Users.CanLogOnToApplication(IBUser) Then
			
			Continue;
		EndIf;
		
		UserObject = Selection.Ref.GetObject();
		StoredProperties = StoredInfobaseUserProperties(UserObject);
		StoredProperties.CanLogOnToApplication    = True;
		StoredProperties.StandardAuthentication = IBUser.StandardAuthentication;
		StoredProperties.OpenIDAuthentication      = IBUser.OpenIDAuthentication;
		StoredProperties.OSAuthentication          = IBUser.OSAuthentication;
		
		AreNew = New ValueStorage(StoredProperties);
		If Not CommonUse.DataMatch(UserObject.InfobaseUserProperties, AreNew) Then
			UserObject.InfobaseUserProperties = AreNew;
			InfobaseUpdate.WriteData(UserObject);
		EndIf;
	EndDo;
	
EndProcedure

// Called during the transition to the new configuration 2 version.2.2.42.
Procedure AddToFullUsersRoleSystemAdministrator() Export
	
	If Not AccessRight("Administration", Metadata, Metadata.Roles.FullRights) Then
		Return;
	EndIf;
	
	If Not StandardSubsystemsServer.ThisIsBasicConfigurationVersion() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	AllIBUsers = InfobaseUsers.GetUsers();
	
	For Each IBUser IN AllIBUsers Do
		If Not IBUser.Roles.Contains(Metadata.Roles.FullRights) Then
			Continue;
		EndIf;
		If IBUser.Roles.Contains(Metadata.Roles.SystemAdministrator) Then
			Continue;
		EndIf;
		
		IBUser.Roles.Add(Metadata.Roles.SystemAdministrator);
		IBUser.Write();
	EndDo;
	
EndProcedure

// Called during the transition to the new configuration 2 version.2.3.16.
Procedure DeleteCacheUnseparatedDataAvailableForChange() Export
	
	StandardSubsystemsServer.DeleteApplicationWorkParameter(
		"UsersWorkParameters", "UnseparatedDataAvailableForChange");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Overrides comment text while authorizing
// IB user created in the configurator with administrative rights.
//  Called from Users.AuthorizeCurrentUser().
//  Comment is written to the events log monitor.
// 
// Parameters:
//  Comment  - String - initial value is set.
//
Procedure AfterWriteAdministratorOnAuthorization(Comment) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.AfterWriteAdministratorOnAuthorization(Comment);
	EndIf;
	
EndProcedure

// Overrides action during local IB
// administrator authorization or data field administrator.
//
Procedure OnAuthorizationAdministratorOnStart(Administrator) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.OnAuthorizationAdministratorOnStart(Administrator);
	EndIf;
	
EndProcedure

// Generates a query on change email address of the service user.
//
// Parameters:
//  NewEmail                - String - user’s new email address.
//  User              - CatalogRef.Users - user which email
//                                                              address should be changed.
//  ServiceUserPassword - String - current user password for access to service manager.
//
Procedure WhenYouCreateQueryByMail(Val NewEmail, Val User, Val ServiceUserPassword) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		ModuleUsersServiceSaaS.CreateRequestToChangeEmail(NewEmail, User, ServiceUserPassword);
	EndIf;
	
EndProcedure

// Returns actions available to the current user with the specified service user.
//
// Parameters:
//  User - CatalogRef.Users - user
//   available actions with which are required to be received. If parameter is not
//   specified, available actions with the current user are checked.
//  ServiceUserPassword - String - current user password
//   for access the service.
//  
Procedure WhenUserActionService(AvailableActions, Val User = Undefined) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		AvailableActions = ModuleUsersServiceSaaS.GetActionsWithServiceUser(User);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls from other subsystems.

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ExternalUsers.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.ExternalUsersGroups.FullName(), "NotEditableInGroupProcessingAttributes");
	Objects.Insert(Metadata.Catalogs.Users.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

// Handlers of the users record and users groups.

// Defines actions required after
// completing links update in the UsersGroupsContents register.
//
// Parameters:
//  ParticipantsOfChange - Array of types values:
//                       - CatalogRef.Users.
//                       - CatalogRef.ExternalUsers.
//                       Users that took part in groups content change.
//
//  ChangedGroups   - Array of types values:
//                       - CatalogRef.UsersGroups.
//                       - CatalogRef.ExternalUsersGroups.
//                       Group content of which was changed.
//
Procedure AfterUpdateCompositionsOfGroupsUsersOverridable(ParticipantsOfChange, ChangedGroups) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.AfterUserGroupStavesUpdating(ParticipantsOfChange, ChangedGroups);
		
		AccessControlModule = CommonUse.CommonModule("AccessManagement");
		AccessControlModule.UpdateUsersRoles(ParticipantsOfChange);
	EndIf;
	
EndProcedure

// Defines actions required after changing authorization object of the external user.
// 
// Parameters:
//  ExternalUser     - CatalogRef.ExternalUsers.
//  OldAuthorizationObject - NULL - during adding an external user.
//                            For example, CatalogRef.Individuals.
//  NewAuthorizationObject  - For example, CatalogRef.Individuals.
//
Procedure AfterExternalUserAuthorizationObjectChange(ExternalUser,
                                                               OldAuthorizationObject,
                                                               NewAuthorizationObject) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.AfterExternalUserAuthorizationObjectChange(
			ExternalUser, OldAuthorizationObject, NewAuthorizationObject);
	EndIf;
	
EndProcedure

// Defines actions required after adding
// or changing user, users group, external user, external users group.
//
// Parameters:
//  Ref     - CatalogRef.Users.
//             - CatalogRef.UsersGroups.
//             - CatalogRef.ExternalUsers.
//             - CatalogRef.ExternalUsersGroups.
//
//  IsNew   - Boolean if True, the object is added, otherwise, it is changed.
//
Procedure AfterUserOrGroupChangeAdding(Ref, IsNew) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
		ModuleAccessManagementService.AfterUserOrGroupChangeAdding(Ref, IsNew);
	EndIf;
	
EndProcedure

// Defines actions required after
// setting the infobase user by a user
// or an external user i.e. while changing the IBUserIdentifier attribute for not empty one.
// 
// For example, you can update roles.
// 
// Parameters:
//  Ref - CatalogRef.Users.
//         - CatalogRef.ExternalUsers.
//
Procedure AfterIBUserSetting(Ref, ServiceUserPassword) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		AccessControlModule = CommonUse.CommonModule("AccessManagement");
		AccessControlModule.UpdateUsersRoles(Ref, ServiceUserPassword);
	EndIf;
	
EndProcedure

// For work support in service model.

// Returns check box of users actions availability.
//
// Returns:
// Boolean - True if users change is available, otherwise, False.
//
Procedure OnDeterminingAvailabilityChangesUsers(CanChangeUsers) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersServiceSaaS = CommonUse.CommonModule("UsersServiceSaaS");
		CanChangeUsers = ModuleUsersServiceSaaS.CanChangeUsers();
	Else
		CanChangeUsers = True;
	EndIf;
	
EndProcedure

// User settings of reports variants.

// Receives passed report variants and their presentations.
//
// Parameters:
//  ReportMetadata                - Metadata object - report for which report variants are received.
//  InfobaseUser - String - infobase user name.
//  InfoAboutReportVariants      - ValueTable - table to which information about report variant is saved.
//       * ObjectKey          - String - report key of the "Report.ReportName" kind.
//       * VariantKey         - String - key of a report variant.
//       * Presentation        - String - report variant presentation.
//       * StandartProcessor - Boolean - if True - report variant is saved to the standard storage.
//  StandardProcessing           - Boolean - if True - report variant is saved to the standard storage.
//
Procedure OnObtainingCustomOptionsReports(ReportMetadata, InfobaseUser, InfoAboutReportVariants, StandardProcessing) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
		ModuleReportsVariants.UserReportsVariants(ReportMetadata, InfobaseUser,
			InfoAboutReportVariants, StandardProcessing);
	EndIf;
	
EndProcedure

// Deletes the passed report variant from reports variants storage.
//
// Parameters:
//  InfoAboutReportVariants      - ValueTable - table where report variant info is saved.
//       * ObjectKey          - String - report key of the "Report.ReportName" kind.
//       * VariantKey         - String - key of a report variant.
//       * Presentation        - String - report variant presentation.
//       * StandartProcessor - Boolean - if True - report variant is saved to the standard storage.
//  InfobaseUser - String - infobase user name in which report variant is cleared.
//  StandardProcessing           - Boolean - if True - report variant is saved to the standard storage.
//
Procedure WhenYouDeleteCustomReportVariants(InfoAboutReportOption, InfobaseUser, StandardProcessing) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
		ModuleReportsVariants.DeleteUserReportVariant(InfoAboutReportOption,
			InfobaseUser, StandardProcessing);
	EndIf;
	
EndProcedure

// Other users settings.

// Expands the list of passed user settings on the "Other" tab of UsersSettings processor.
//
// Parameters:
//  UserInfo - Structure - String and reference user presentation.
//       * UserRef - CatalogRef.Users - user whose settings should be received.
//       * InfobaseUserName - String - infobase user
//                                                   whose settings need to be received.
//  Settings - Structure - other user settings.
//       * Key     - String - setting string ID used for
//                             copying and clearing this setting.
//       * Value - Structure - information about setting.
//              ** SettingName  - String - name that will be displayed in the settings tree.
//              ** SettingPicture  - Picture - picture that will be displayed in the settings tree.
//              ** SettingsList     - ValueList - list of received settings.
//
Procedure OnReceiveOtherSettings(UserInfo, OtherSettings) Export
	
	// Add settings of additional reports and processors.
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Settings = Undefined;
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.ReceiveAdditionalReportsAndDataProcessorsSettings(UserInfo.UserRef, Settings);
		
		If Settings <> Undefined Then
			OtherSettings.Insert("QuickAccessSetup", Settings);
		EndIf;
	EndIf;
	
	UsersOverridable.OnReceiveOtherSettings(UserInfo, OtherSettings);
	
EndProcedure

// Saves settings for the passed user.
//
// Parameters:
//  Settings              - ValueList - list of saved settings values.
//  UserInfo - Structure - String and reference user presentation.
//       * UserRef - CatalogRef.Users - user to whom you should copy setting.
//       * InfobaseUserName - String - infobase user
//                                                   to whome a setting should be copied.
//
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	If Settings.SettingID = "QuickAccessSetup" Then
		If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.AddCommandsInQuickAccessList(Settings.SettingValue, UserInfo.UserRef);
		EndIf;
	EndIf;
	
	UsersOverridable.OnSaveOtherSetings(UserInfo, Settings);
	
EndProcedure

// Clears settings for the passed user.
//
// Parameters:
//  Settings              - ValueList - cleared settings values.
//  UserInfo - Structure - String and reference user presentation.
//       * UserRef - CatalogRef.Users - user whose setting should be cleared.
//       * InfobaseUserName - String - infobase user
//                                                   whose setting should be cleared.
//
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	If Settings.SettingID = "QuickAccessSetup" Then
		If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.DeleteCommandsFromQuickAccessList(Settings.SettingValue, UserInfo.UserRef);
		EndIf;
	EndIf;
	
	UsersOverridable.OnDeleteOtherSettings(UserInfo, Settings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Function MessageTextUserNotFoundInCatalog(UserName)
	
	If ExternalUsers.UseExternalUsers() Then
		ErrorMessageText = NStr("en='Authorization not executed. System work will be complete.
		|
		|User %1 is not
		|found in catalogs ""Users"" and ""External users"".
		|
		|Contact your administrator.';ru='Авторизация не выполнена. Работа системы будет завершена.
		|
		|Пользователь
		|""%1"" не найден в справочниках ""Пользователи"" и ""Внешние пользователи"".
		|
		|Обратитесь к администратору.'");
	Else
		ErrorMessageText = NStr("en='Authorization not executed. System work will be complete.
		|
		|User %1 is not found in the ""Users"" catalog.
		|
		|Contact your administrator.';ru='Авторизация не выполнена. Работа системы будет завершена.
		|
		|Пользователь ""%1"" не найден в справочнике ""Пользователи"".
		|
		|Обратитесь к администратору.'");
	EndIf;
	
	ErrorMessageText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorMessageText, UserName);
	
	Return ErrorMessageText;
	
EndFunction

Function UserRefByFullDescr(FullName)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Description = &FullName";
	
	Query.SetParameter("FullName", FullName);
	
	Result = Undefined;
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			Selection.Next();
			
			If Not Users.IBUserIsLocked(Selection.InfobaseUserID) Then
				Result = Selection.Ref;
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Undefined;
	
EndFunction

// Used in
// the UpdateUsersGroupsContents, UpdateExternalUsersGroupsContents procedures.
//
// Parameters:
//  Table      - Full metadata object name.
//
// Returns:
//  ValuesTable (Ref, Parent)
//
Function RefsInParentsHierarchy(Table)
	
	// Preparation of parents groups content.
	Query = New Query(
	"SELECT
	|	ParentRefs.Ref AS Ref,
	|	ParentRefs.Parent AS Parent
	|FROM
	|	" + Table + " AS ParentRefs");
	ParentRefs = Query.Execute().Unload();
	ParentRefs.Indexes.Add("Parent");
	RefsInParentsHierarchy = ParentRefs.Copy(New Array);
	
	For Each ReferenceDetails IN ParentRefs Do
		NewRow = RefsInParentsHierarchy.Add();
		NewRow.Parent = ReferenceDetails.Ref;
		NewRow.Ref   = ReferenceDetails.Ref;
		
		FillRefsInParentHierarchy(ReferenceDetails.Ref, ReferenceDetails.Ref, ParentRefs, RefsInParentsHierarchy);
	EndDo;
	
	Return RefsInParentsHierarchy;
	
EndFunction

Procedure FillRefsInParentHierarchy(Val Parent, Val CurrentParent, Val ParentRefs, Val RefsInParentsHierarchy)
	
	RefsOfParent = ParentRefs.FindRows(New Structure("Parent", CurrentParent));
	
	For Each ReferenceDetails IN RefsOfParent Do
		NewRow = RefsInParentsHierarchy.Add();
		NewRow.Parent = Parent;
		NewRow.Ref   = ReferenceDetails.Ref;
		
		FillRefsInParentHierarchy(Parent, ReferenceDetails.Ref, ParentRefs, RefsInParentsHierarchy);
	EndDo;
	
EndProcedure

// Used in
// the UpdateUsersGroupsContents, UpdateExternalUsersGroupsContents procedures.
//
Procedure UpdateAllUsersGroupContent(User,
                                              UpdateExternalUsersGroup = False,
                                              ParticipantsOfChange = Undefined,
                                              ChangedGroups   = Undefined)
	
	If UpdateExternalUsersGroup Then
		GroupAllUsers = Catalogs.ExternalUsersGroups.AllExternalUsers;
	Else
		GroupAllUsers = Catalogs.UsersGroups.AllUsers;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("GroupAllUsers", GroupAllUsers);
	
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	CASE
	|		WHEN Users.DeletionMark
	|			THEN FALSE
	|		WHEN Users.NotValid
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Used
	|INTO Users
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	&UserFilter
	|
	|INDEX BY
	|	Users.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&GroupAllUsers AS UsersGroup,
	|	Users.Ref AS User,
	|	Users.Used
	|FROM
	|	Users AS Users
	|		LEFT JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON (UsersGroupsContents.UsersGroup = &GroupAllUsers)
	|			AND (UsersGroupsContents.User = Users.Ref)
	|			AND (UsersGroupsContents.Used = Users.Used)
	|WHERE
	|	UsersGroupsContents.User IS NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Users.Ref,
	|	Users.Ref,
	|	Users.Used
	|FROM
	|	Users AS Users
	|		LEFT JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON (UsersGroupsContents.UsersGroup = Users.Ref)
	|			AND (UsersGroupsContents.User = Users.Ref)
	|			AND (UsersGroupsContents.Used = Users.Used)
	|WHERE
	|	UsersGroupsContents.User IS NULL ";
	
	If UpdateExternalUsersGroup Then
		Query.Text = StrReplace(Query.Text, "Catalog.Users", "Catalog.ExternalUsers");
	EndIf;
	
	If User = Undefined Then
		Query.Text = StrReplace(Query.Text, "&UserFilter", "TRUE");
	Else
		Query.SetParameter("User", User);
		Query.Text = StrReplace(
			Query.Text, "&UserFilter", "Users.Ref IN (&User)");
	EndIf;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		RecordSet = InformationRegisters.UsersGroupsContents.CreateRecordSet();
		Record = RecordSet.Add();
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			RecordSet.Filter.UsersGroup.Set(Selection.UsersGroup);
			RecordSet.Filter.User.Set(Selection.User);
			FillPropertyValues(Record, Selection);
			RecordSet.Write(); // Add missing records about links.
			
			If ParticipantsOfChange <> Undefined Then
				ParticipantsOfChange.Insert(Selection.User);
			EndIf;
		EndDo;
		
		If ChangedGroups <> Undefined Then
			ChangedGroups.Insert(GroupAllUsers);
		EndIf;
	EndIf;
	
EndProcedure

// Used in the UpdateExternalUsersGroupsContents procedure.
Procedure UpdateGroupsContentByAuthorizationObjectTypes(ExternalUserGroup,
		ExternalUser, ParticipantsOfChange, ChangedGroups)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExternalUsersGroups.Ref AS UsersGroup,
	|	ExternalUsers.Ref AS User,
	|	CASE
	|		WHEN ExternalUsersGroups.DeletionMark
	|			THEN FALSE
	|		WHEN ExternalUsers.DeletionMark
	|			THEN FALSE
	|		WHEN ExternalUsers.NotValid
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Used
	|INTO NewComplements
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|		INNER JOIN Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|		ON (ExternalUsersGroups.AllAuthorizationObjects = TRUE)
	|			AND (&ExternalUsersGroupFilter1)
	|			AND (VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(ExternalUsersGroups.TypeOfAuthorizationObjects))
	|			AND (&ExternalUserFilter1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsersGroupsContents.UsersGroup,
	|	UsersGroupsContents.User
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		LEFT JOIN NewComplements AS NewComplements
	|		ON UsersGroupsContents.UsersGroup = NewComplements.UsersGroup
	|			AND UsersGroupsContents.User = NewComplements.User
	|WHERE
	|	VALUETYPE(UsersGroupsContents.UsersGroup) = Type(Catalog.ExternalUsersGroups)
	|	AND CAST(UsersGroupsContents.UsersGroup AS Catalog.ExternalUsersGroups).AllAuthorizationObjects = TRUE
	|	AND &ExternalUsersGroupFilter2
	|	AND &ExternalUserFilter2
	|	AND NewComplements.User IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewComplements.UsersGroup,
	|	NewComplements.User,
	|	NewComplements.Used
	|FROM
	|	NewComplements AS NewComplements
	|		LEFT JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON (UsersGroupsContents.UsersGroup = NewComplements.UsersGroup)
	|			AND (UsersGroupsContents.User = NewComplements.User)
	|			AND (UsersGroupsContents.Used = NewComplements.Used)
	|WHERE
	|	UsersGroupsContents.User IS NULL ";
	
	If ExternalUserGroup = Undefined Then
		Query.Text = StrReplace(Query.Text, "&ExternalUsersGroupFilter1", "TRUE");
		Query.Text = StrReplace(Query.Text, "&ExternalUsersGroupFilter2", "TRUE");
	Else
		Query.SetParameter("ExternalUserGroup", ExternalUserGroup);
		Query.Text = StrReplace(
			Query.Text,
			"&ExternalUsersGroupFilter1",
			"ExternalUsersGroups.Ref IN (&ExternalUsersGroups)");
		Query.Text = StrReplace(
			Query.Text,
			"&ExternalUsersGroupFilter2",
			"UsersGroupsContents.UsersGroup IN (&ExternalUsersGroup)");
	EndIf;
	
	If ExternalUser = Undefined Then
		Query.Text = StrReplace(Query.Text, "&ExternalUserFilter1", "TRUE");
		Query.Text = StrReplace(Query.Text, "&ExternalUserFilter2", "TRUE");
	Else
		Query.SetParameter("ExternalUser", ExternalUser);
		Query.Text = StrReplace(
			Query.Text,
			"&ExternalUserFilter1",
			"ExternalUsers.Ref IN (&ExternalUser)");
		Query.Text = StrReplace(
			Query.Text,
			"&ExternalUserFilter2",
			"UsersGroupsContents.User IN (&ExternalUser)");
	EndIf;
	
	QueryResults = Query.ExecuteBatch();
	
	If Not QueryResults[1].IsEmpty() Then
		RecordSet = InformationRegisters.UsersGroupsContents.CreateRecordSet();
		Selection = QueryResults[1].Select();
		
		While Selection.Next() Do
			RecordSet.Filter.UsersGroups.Set(Selection.UsersGroup);
			RecordSet.Filter.User.Set(Selection.User);
			RecordSet.Write(); // Delete extra records about links.
			
			If ParticipantsOfChange <> Undefined Then
				ParticipantsOfChange.Insert(Selection.User);
			EndIf;
			
			If ChangedGroups <> Undefined
			   AND TypeOf(Selection.UsersGroup)
			     = Type("CatalogRef.ExternalUsersGroups") Then
				
				ChangedGroups.Insert(Selection.UsersGroup);
			EndIf;
		EndDo;
	EndIf;
	
	If Not QueryResults[2].IsEmpty() Then
		RecordSet = InformationRegisters.UsersGroupsContents.CreateRecordSet();
		Record = RecordSet.Add();
		Selection = QueryResults[2].Select();
		
		While Selection.Next() Do
			RecordSet.Filter.UsersGroups.Set(Selection.UsersGroup);
			RecordSet.Filter.User.Set(Selection.User);
			FillPropertyValues(Record, Selection);
			RecordSet.Write(); // Add missing records about links.
			
			If ParticipantsOfChange <> Undefined Then
				ParticipantsOfChange.Insert(Selection.User);
			EndIf;
			
			If ChangedGroups <> Undefined
			   AND TypeOf(Selection.UsersGroup)
			     = Type("CatalogRef.ExternalUsersGroups") Then
				
				ChangedGroups.Insert(Selection.UsersGroup);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Used in
// the UpdateUsersGroupsContents, UpdateExternalUsersGroupsContents procedures.
//
Procedure UpdateHierarhicalUsersGroupsContents(UsersGroup,
                                                         User,
                                                         ParticipantsOfChange = Undefined,
                                                         ChangedGroups   = Undefined)
	
	UpdateExternalUsersGroups =
		TypeOf(UsersGroup) <> Type("CatalogRef.UsersGroups");
	
	// Preparation of users group in the hierarchy of their parents.
	Query = New Query;
	Query.Text =
	"SELECT
	|	RefsInParentsHierarchy.Parent,
	|	RefsInParentsHierarchy.Ref
	|INTO RefsInParentsHierarchy
	|FROM
	|	&RefsInParentsHierarchy AS RefsInParentsHierarchy";
	
	Query.SetParameter("RefsInParentsHierarchy", RefsInParentsHierarchy(
		?(UpdateExternalUsersGroups,
		  "Catalog.ExternalUsersGroups",
		  "Catalog.UsersGroups") ));
	
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	// Query preparation for cycle.
	Query.Text =
	"SELECT
	|	UsersGroupsContents.User,
	|	UsersGroupsContents.Used
	|INTO UsersGroupsContents
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	&UserInRegisterFilter
	|	AND UsersGroupsContents.UsersGroup = &UsersGroup
	|
	|INDEX BY
	|	UsersGroupsContents.User,
	|	UsersGroupsContents.Used
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UsersGroupsContents.User AS User,
	|	CASE
	|		WHEN UsersGroupsContents.Ref.DeletionMark
	|			THEN FALSE
	|		WHEN UsersGroupsContents.User.DeletionMark
	|			THEN FALSE
	|		WHEN UsersGroupsContents.User.NotValid
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Used
	|INTO NewUsersGroupsContents
	|FROM
	|	Catalog.UsersGroups.Content AS UsersGroupsContents
	|		INNER JOIN RefsInParentsHierarchy AS RefsInParentsHierarchy
	|		ON (RefsInParentsHierarchy.Ref = UsersGroupsContents.Ref)
	|			AND (RefsInParentsHierarchy.Parent = &UsersGroup)
	|			AND (&UserInCatalogFilter)
	|
	|INDEX BY
	|	User,
	|	Used
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UsersGroupsContents.User
	|FROM
	|	UsersGroupsContents AS UsersGroupsContents
	|		LEFT JOIN NewUsersGroupsContents AS NewUsersGroupsContents
	|		ON UsersGroupsContents.User = NewUsersGroupsContents.User
	|WHERE
	|	NewUsersGroupsContents.User IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	&UsersGroup AS UsersGroup,
	|	NewUsersGroupsContents.User,
	|	NewUsersGroupsContents.Used
	|FROM
	|	NewUsersGroupsContents AS NewUsersGroupsContents
	|		LEFT JOIN UsersGroupsContents AS UsersGroupsContents
	|		ON (UsersGroupsContents.User = NewUsersGroupsContents.User)
	|			AND (UsersGroupsContents.Used = NewUsersGroupsContents.Used)
	|WHERE
	|	UsersGroupsContents.User IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsersGroups.Parent AS Parent
	|FROM
	|	Catalog.UsersGroups AS UsersGroups
	|WHERE
	|	UsersGroups.Ref = &UsersGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP UsersGroupsContents
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP NewUsersGroupsContents";
	
	If User = Undefined Then
		UserInRegisterFilter    = "TRUE";
		UserInCatalogFilter = "TRUE";
	Else
		Query.SetParameter("User", User);
		UserInRegisterFilter    = "UsersGroupsContents.User IN (&User)";
		UserInCatalogFilter = "UsersGroupsContents.User IN (&User)";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&UserFilterInRegister",    UserInRegisterFilter);
	Query.Text = StrReplace(Query.Text, "&UserFilterInCatalog", UserInCatalogFilter);
	
	If UpdateExternalUsersGroups Then
		
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.UsersGroups",
			"Catalog.ExternalUsersGroups");
		
		Query.Text = StrReplace(
			Query.Text,
			"UsersGroupsContents.User",
			"UsersGroupsContents.ExternalUser");
	EndIf;
	
	// Execution for the current user group and each group-parent.
	While ValueIsFilled(UsersGroup) Do
		
		Query.SetParameter("UsersGroup", UsersGroup);
		
		ResultsOfQuery = Query.ExecuteBatch();
		
		If Not ResultsOfQuery[2].IsEmpty() Then
			RecordSet = InformationRegisters.UsersGroupsContents.CreateRecordSet();
			Selection = ResultsOfQuery[2].Select();
			
			While Selection.Next() Do
				RecordSet.Filter.User.Set(Selection.User);
				RecordSet.Filter.UsersGroups.Set(UsersGroup);
				RecordSet.Write(); // Delete extra records about links.
				
				If ParticipantsOfChange <> Undefined Then
					ParticipantsOfChange.Insert(Selection.User);
				EndIf;
				
				If ChangedGroups <> Undefined Then
					ChangedGroups.Insert(UsersGroup);
				EndIf;
			EndDo;
		EndIf;
		
		If Not ResultsOfQuery[3].IsEmpty() Then
			RecordSet = InformationRegisters.UsersGroupsContents.CreateRecordSet();
			Record = RecordSet.Add();
			Selection = ResultsOfQuery[3].Select();
			
			While Selection.Next() Do
				RecordSet.Filter.User.Set(Selection.User);
				RecordSet.Filter.UsersGroups.Set(Selection.UsersGroup);
				FillPropertyValues(Record, Selection);
				RecordSet.Write(); // Add missing records about links.
				
				If ParticipantsOfChange <> Undefined Then
					ParticipantsOfChange.Insert(Selection.User);
				EndIf;
				
				If ChangedGroups <> Undefined Then
					ChangedGroups.Insert(Selection.UsersGroup);
				EndIf;
			EndDo;
		EndIf;
		
		If Not ResultsOfQuery[4].IsEmpty() Then
			Selection = ResultsOfQuery[4].Select();
			Selection.Next();
			UsersGroup = Selection.Parent;
		Else
			UsersGroup = Undefined;
		EndIf;
	EndDo;
	
EndProcedure

// Checks rights of the specified IB user.
//
// Parameters:
//  IBUser - InfobaseUser.
//  CheckMode - String - OnWrite or OnStart.
//
Procedure CheckUserRights(IBUser, CheckMode)
	
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	If DataSeparationEnabled AND IBUser.DataSeparation.Count() = 0 Then
		Return; // Not need to check undivided users in service model.
	EndIf;
	
	If Not DataSeparationEnabled AND CheckMode = "OnLaunch" Then
		Return; // You do not need to check the users rights during start in the local mode.
	EndIf;
	
	UserTypes = ?(DataSeparationEnabled,
		Enums.UserTypes.DataAreaUser,
		Enums.UserTypes.LocalApplicationUser);
		
	InaccessibleRoles = InaccessibleRolesByUserTypes(UserTypes);
	If InaccessibleRoles.Count() = 0 Then
		Return;
	EndIf;
	
	RolesForCheck = New ValueTable;
	RolesForCheck.Columns.Add("Role", New TypeDescription("MetadataObject"));
	RolesForCheck.Columns.Add("IsDeletedRole", New TypeDescription("Boolean"));
	For Each Role IN IBUser.Roles Do
		RolesForCheck.Add().Role = Role;
	EndDo;
	RolesForCheck.Indexes.Add("Role");
	
	If CheckMode = "OnWrite" AND Not DataSeparationEnabled Then
		FormerIBUser = InfobaseUsers.FindByUUID(
			IBUser.UUID);
		
		If FormerIBUser <> Undefined Then
			For Each Role IN FormerIBUser.Roles Do
				String = RolesForCheck.Find(Role, "Role");
				If String <> Undefined Then
					RolesForCheck.Delete(String);
				ElsIf DataSeparationEnabled Then
					NewRow = RolesForCheck.Add();
					NewRow.Role = Role;
					NewRow.IsDeletedRole = True;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	FoundUnavailableRoles = New ValueTable;
	FoundUnavailableRoles.Columns.Add("Role", New TypeDescription("MetadataObject"));
	FoundUnavailableRoles.Columns.Add("IsDeletedRole", New TypeDescription("Boolean"));
	
	For Each RoleDescription IN RolesForCheck Do
		Role = RoleDescription.Role;
		RoleName = Role.Name;
		
		UnavailableRoleProperty = InaccessibleRoles.Get(RoleName);
		If UnavailableRoleProperty = Undefined Then
			Continue;
		EndIf;
		FillPropertyValues(FoundUnavailableRoles.Add(), RoleDescription);
		
		If UnavailableRoleProperty.Property("NonseparatedVariableData") Then
			Record = New XMLWriter;
			Record.SetString();
			XDTOSerializer.WriteXML(Record, UnavailableRoleProperty.NonseparatedVariableData);
			TableString = Record.Close();
			
			If RoleDescription.IsDeletedRole Then
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Attempt to change roles content in user
		|%1
		|with role %2 providing rights on
		|changing general data: %3.';ru='Попытка изменить состав ролей у
		|пользователя
		|%1 с ролью ""%2"", предоставляющей
		|права на изменение общих данных: ""%3"".'"),
					IBUser.FullName,
					Role.Presentation(),
					TableString);
			Else
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Attempt to assign to user
		|%1
		|invalid role %2 providing rights on
		|changing general data: %3';ru='Попытка назначить
		|пользователю
		|%1 недопустимую роль ""%2"", предоставляющую
		|права на изменение общих данных: ""%3"".'"),
					IBUser.FullName,
					Role.Presentation(),
					TableString);
			EndIf;
			
			EventName = NStr("en='Users. Error when installing the roles for the IB users';ru='Пользователи.Ошибка при установке ролей пользователю ИБ'",
			     CommonUseClientServer.MainLanguageCode());
			WriteLogEvent(EventName, EventLogLevel.Error,, IBUser, MessageText);
		EndIf;
		
		If UnavailableRoleProperty.Property("Rights") Then
			
			EventName = NStr("en='Users. Error when installing the roles for the IB users';ru='Пользователи.Ошибка при установке ролей пользователю ИБ'",
			     CommonUseClientServer.MainLanguageCode());
			
			For Each Right IN UnavailableRoleProperty.Rights Do
				
				If RoleDescription.IsDeletedRole Then
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Attempt to change roles content in user
		|%1
		|with role %2 providing right %3.';ru='Попытка изменить состав ролей у
		|пользователя
		|""%1"" с ролью ""%2"", предоставляющей право ""%3"".'"),
						String(IBUser),
						Role.Presentation(),
						Right);
				Else
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Attempt to assign to user
		|%1
		|invalid role %2 providing right %3.';ru='Попытка назначить пользователю
		|""%1""
		|недопустимую роль ""%2"", предоставляющую право ""%3"".'"),
						String(IBUser),
						Role.Presentation(),
						Right);
				EndIf;
				WriteLogEvent(EventName, EventLogLevel.Error,, IBUser, MessageText);
				
			EndDo;
		EndIf;
	EndDo;
	
	If FoundUnavailableRoles.Count() = 0 Then
		Return;
	EndIf;
	
	Filter = New Structure("IsDeletedRole", True);
	DeletedRoles = FoundUnavailableRoles.FindRows(Filter);
	
	Filter = New Structure("IsDeletedRole", False);
	AddedRoles = FoundUnavailableRoles.FindRows(Filter);
	
	If DeletedRoles.Count() = 1 Then
		RemovalMessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Unable to delete unavailable user role %1.';ru='Невозможно удалить недоступную роль у пользователя ""%1"".'"),
			IBUser.FullName);
	ElsIf DeletedRoles.Count() > 1 Then
		RemovalMessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Unable to delete unavailable user roles  %1.';ru='Невозможно удалить недоступные роли у пользователя ""%1"".'"),
			IBUser.FullName);
	EndIf;
	
	If AddedRoles.Count() = 1 Then
		AddingMessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Role %2 can not be
		|added to user %1.';ru='Пользователю ""%1""
		|не может быть добавлена роль ""%2"".'"),
			IBUser.FullName,
			AddedRoles[0].Role.Presentation());
		
	ElsIf AddedRoles.Count() > 1 Then
		Roles = "";
		For Each RoleDescription IN AddedRoles Do
			Roles = Roles + "
			|" + RoleDescription.Role.Presentation();
		EndDo;
		AddingMessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Roles can not be added to user %1: %2.';ru='Пользователю ""%1"" не могут быть добавлены роли:%2.'"), 
			IBUser.FullName,
			Roles);
	EndIf;
	
	If ValueIsFilled(RemovalMessageText) Then
		MessageText = RemovalMessageText + Chars.LF + AddingMessageText;
	Else
		MessageText = AddingMessageText;
	EndIf;
	
	Raise MessageText;
	
EndProcedure

Function SettingsList(IBUserName, SettingsManager)
	
	SettingsTable = New ValueTable;
	SettingsTable.Columns.Add("ObjectKey");
	SettingsTable.Columns.Add("SettingsKey");
	
	Filter = New Structure;
	Filter.Insert("User", IBUserName);
	
	SelectionSettings = SettingsManager.Select(Filter);
	Skip = False;
	While NextSetting(SelectionSettings, Skip) Do
		
		If Skip Then
			Continue;
		EndIf;
		
		NewRow = SettingsTable.Add();
		NewRow.ObjectKey = SelectionSettings.ObjectKey;
		NewRow.SettingsKey = SelectionSettings.SettingsKey;
	EndDo;
	
	Return SettingsTable;
	
EndFunction

Function NextSetting(SelectionSettings, Skip) 
	
	Try 
		Skip = False;
		Return SelectionSettings.Next();
	Except
		Skip = True;
		Return True;
	EndTry;
	
EndFunction

Procedure CopySettings(SettingsManager, UserNameSource, UserNameRecipient, Wrap)
	
	SettingsTable = SettingsList(UserNameSource, SettingsManager);
	
	For Each Setting IN SettingsTable Do
		ObjectKey = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		Value = SettingsManager.Load(ObjectKey, SettingsKey, , UserNameSource);
		SettingsDescription = SettingsManager.GetDescription(ObjectKey, SettingsKey, UserNameSource);
		SettingsManager.Save(ObjectKey, SettingsKey, Value,
			SettingsDescription, UserNameRecipient);
		If Wrap Then
			SettingsManager.Delete(ObjectKey, SettingsKey, UserNameSource);
		EndIf;
	EndDo;
	
EndProcedure

Procedure CopyOtherUserSettings(UserNameSource, UserNameRecipient)
	
	UserSourceRef = Users.FindByName(UserNameSource);
	UserRecipientRef = Users.FindByName(UserNameRecipient);
	UserSourceInfo = New Structure;
	UserSourceInfo.Insert("UserRef", UserSourceRef);
	UserSourceInfo.Insert("InfobaseUserName", UserNameSource);
	
	UserReceiverInfo = New Structure;
	UserReceiverInfo.Insert("UserRef", UserRecipientRef);
	UserReceiverInfo.Insert("InfobaseUserName", UserNameRecipient);
	
	// Receive other settings.
	OtherUsersSettings = New Structure;
	OnReceiveOtherSettings(UserSourceInfo, OtherUsersSettings);
	Keys = New ValueList;
	ArrayOtherSettings = New Array;
	If OtherUsersSettings.Count() <> 0 Then
		
		For Each OtherSetting IN OtherUsersSettings Do
			OtherSettingsStructure = New Structure;
			If OtherSetting.Key = "QuickAccessSetup" Then
				SettingsList = OtherSetting.Value.SettingsList;
				For Each Item IN SettingsList Do
					Keys.Add(Item.Object, Item.ID);
				EndDo;
				OtherSettingsStructure.Insert("SettingID", "QuickAccessSetup");
				OtherSettingsStructure.Insert("SettingValue", Keys);
			Else
				OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
				OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
			EndIf;
			OnSaveOtherSetings(UserReceiverInfo, OtherSettingsStructure);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure CopyIBUserSettings(UserObject, ProcessingParameters)
	
	If Not ProcessingParameters.Property("CopyingValue")
	 OR Not ProcessingParameters.NewIBUserExist Then
		
		Return;
	EndIf;
	
	NewIBUserName = ProcessingParameters.NewDBUserDescription.Name;
	
	CopiedIBUserIdentifier = CommonUse.ObjectAttributeValue(
		ProcessingParameters.CopyingValue, "InfobaseUserID");
	
	If Not ValueIsFilled(CopiedIBUserIdentifier) Then
		Return;
	EndIf;
	
	CopiedIBUserFullName = Undefined;
	SetPrivilegedMode(True);
	If Not Users.ReadIBUser(
	         CopiedIBUserIdentifier,
	         CopiedIBUserFullName) Then
		Return;
	EndIf;
	SetPrivilegedMode(False);
	
	NameOfCopiedUserIB = CopiedIBUserFullName.Name;
	
	// Copying settings.
	CopyUserSettings(NameOfCopiedUserIB, NewIBUserName, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures used during the data exchange.

// Overrides the standard behavior during data export.
// InfobaseUserID attribute is not transferred.
//
Procedure OnDataSending(DataItem, ItemSend, ToSubordinate)
	
	If ItemSend = DataItemSend.Delete
	 OR ItemSend = DataItemSend.Ignore Then
		
		// Standard processor is not overridden.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.Users")
	      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsers") Then
		
		DataItem.InfobaseUserID =
			New UUID("00000000-0000-0000-0000-000000000000");
		
		DataItem.Prepared = False;
		DataItem.InfobaseUserProperties = New ValueStorage(Undefined);
	EndIf;
	
EndProcedure

// Overrides the standard behavior during data import.
// Attribute InfobaseUserID is not transferred as always
// relates to the current infobase user or not filled in.
//
Procedure OnReceiveData(DataItem, ItemReceive, SendBack, FromSubordinated)
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// Standard processor is not overridden.
		
	ElsIf TypeOf(DataItem) = Type("ConstantValueManager.UseUsersGroups")
	      OR TypeOf(DataItem) = Type("ConstantValueManager.UseExternalUsers")
	      OR TypeOf(DataItem) = Type("CatalogObject.Users")
	      OR TypeOf(DataItem) = Type("CatalogObject.UsersGroups")
	      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsers")
	      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsersGroups")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.UsersGroupsContents") Then
		
		If FromSubordinated AND CommonUseReUse.DataSeparationEnabled() Then
			
			// Data receipt from the autonomous work place is
			// skipped and for data match in nodes the current data is sent back to the autonomous work place.
			SendBack = True;
			ItemReceive = DataItemReceive.Ignore;
			
		ElsIf TypeOf(DataItem) = Type("CatalogObject.Users")
		      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsers") Then
			
			PropertyList =
			"InfobaseUserID,
			|Prepared,
			|InfobaseUserProperties";
			
			FillPropertyValues(DataItem, CommonUse.ObjectAttributesValues(
				DataItem.Ref, PropertyList));
			
		ElsIf TypeOf(DataItem) = Type("ObjectDeletion") Then
			
			If TypeOf(DataItem.Ref) = Type("CatalogRef.Users")
			 OR TypeOf(DataItem.Ref) = Type("CatalogRef.ExternalUsers") Then
				
				ObjectReceived = False;
				Try
					Object = DataItem.Ref.GetObject();
				Except
					ObjectReceived = True;
				EndTry;
				
				If ObjectReceived Then
					Object.GeneralActionsBeforeDeletionInNormalModeAndOnDataExchange();
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Overrides the behavior after receiving data in distributed IB.
Procedure AfterDataGetting(Sender, Cancel, FromSubordinated)
	
	RefreshRolesOfExternalUsers();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For the StartIBUserProcessor procedure.

Procedure RememberUserProperties(UserObject, ProcessingParameters)
	
	Fields =
	"Ref,
	|InfobaseUserID,
	|ServiceUserID,
	|InfobaseUserProperties,
	|Prepared,
	|DeletionMark,
	|NotValid";
	
	If TypeOf(UserObject) = Type("CatalogObject.Users") Then
		Fields = Fields + ", Service";
	EndIf;
	
	OldUser = CommonUse.ObjectAttributesValues(UserObject.Ref, Fields);
	
	If TypeOf(UserObject) <> Type("CatalogObject.Users") Then
		OldUser.Insert("Service", False);
	EndIf;
	
	If UserObject.IsNew() Or UserObject.Ref <> OldUser.Ref Then
		OldUser.InfobaseUserID =
			New UUID("00000000-0000-0000-0000-000000000000");
		OldUser.ServiceUserID =
			New UUID("00000000-0000-0000-0000-000000000000");
		OldUser.InfobaseUserProperties    = New ValueStorage(Undefined);
		OldUser.Prepared               = False;
		OldUser.DeletionMark           = False;
		OldUser.NotValid            = False;
	EndIf;
	ProcessingParameters.Insert("OldUser", OldUser);
	
	// Properties of an old IB user (if any).
	SetPrivilegedMode(True);
	
	OldIBUserFullName = Undefined;
	ProcessingParameters.Insert("OldIBUserExist", Users.ReadIBUser(
		OldUser.InfobaseUserID, OldIBUserFullName));
	
	ProcessingParameters.Insert("CurrentIBOldUser", False);
	
	If ProcessingParameters.OldIBUserExist Then
		ProcessingParameters.Insert("OldIBUserFullName", OldIBUserFullName);
		
		If OldIBUserFullName.UUID =
				InfobaseUsers.CurrentUser().UUID Then
		
			ProcessingParameters.Insert("CurrentIBOldUser", True);
		EndIf;
	EndIf;
	SetPrivilegedMode(False);
	
	// Initial filling of auto attributes fields values with old user values.
	FillPropertyValues(ProcessingParameters.AutoAttributes, OldUser);
	
	// Initial filling of lock attributes fields values with new user values attributes.
	FillPropertyValues(ProcessingParameters.AttributesToLock, UserObject);
	
EndProcedure

Procedure WriteIBUser(UserObject, ProcessingParameters)
	
	AdditionalProperties = UserObject.AdditionalProperties;
	IBUserDescription = AdditionalProperties.IBUserDescription;
	OldUser     = ProcessingParameters.OldUser;
	AutoAttributes          = ProcessingParameters.AutoAttributes;
	
	If IBUserDescription.Count() = 0 Then
		Return;
	EndIf;
	
	CreateNewIBUser = False;
	
	If IBUserDescription.Property("UUID")
	   AND ValueIsFilled(IBUserDescription.UUID)
	   AND IBUserDescription.UUID
	     <> ProcessingParameters.OldUser.InfobaseUserID Then
		
		InfobaseUserID = IBUserDescription.UUID;
		
	ElsIf ValueIsFilled(OldUser.InfobaseUserID) Then
		InfobaseUserID = OldUser.InfobaseUserID;
		CreateNewIBUser = Not ProcessingParameters.OldIBUserExist;
	Else
		InfobaseUserID = Undefined;
		CreateNewIBUser = True;
	EndIf;
	
	// Filling of IB user auto properties.
	If IBUserDescription.Property("FullName") Then
		IBUserDescription.Insert("FullName", UserObject.Description);
	EndIf;
	
	StoredProperties = StoredInfobaseUserProperties(UserObject);
	If ProcessingParameters.OldIBUserExist Then
		OldAuthentication = ProcessingParameters.OldIBUserFullName;
		If Users.CanLogOnToApplication(OldAuthentication) Then
			StoredProperties.StandardAuthentication = OldAuthentication.StandardAuthentication;
			StoredProperties.OpenIDAuthentication      = OldAuthentication.OpenIDAuthentication;
			StoredProperties.OSAuthentication          = OldAuthentication.OSAuthentication;
			UserObject.InfobaseUserProperties = New ValueStorage(StoredProperties);
			AutoAttributes.InfobaseUserProperties = UserObject.InfobaseUserProperties;
		EndIf;
	Else
		OldAuthentication = New Structure;
		OldAuthentication.Insert("StandardAuthentication", False);
		OldAuthentication.Insert("OSAuthentication",          False);
		OldAuthentication.Insert("OpenIDAuthentication",      False);
		StoredProperties.StandardAuthentication = False;
		StoredProperties.OpenIDAuthentication      = False;
		StoredProperties.OSAuthentication          = False;
		UserObject.InfobaseUserProperties = New ValueStorage(StoredProperties);
		AutoAttributes.InfobaseUserProperties = UserObject.InfobaseUserProperties;
	EndIf;
	
	If IBUserDescription.Property("StandardAuthentication") Then
		StoredProperties.StandardAuthentication = IBUserDescription.StandardAuthentication;
		UserObject.InfobaseUserProperties = New ValueStorage(StoredProperties);
		AutoAttributes.InfobaseUserProperties = UserObject.InfobaseUserProperties;
	EndIf;
	
	If IBUserDescription.Property("OSAuthentication") Then
		StoredProperties.OSAuthentication = IBUserDescription.OSAuthentication;
		UserObject.InfobaseUserProperties = New ValueStorage(StoredProperties);
		AutoAttributes.InfobaseUserProperties = UserObject.InfobaseUserProperties;
	EndIf;
	
	If IBUserDescription.Property("OpenIDAuthentication") Then
		StoredProperties.OpenIDAuthentication = IBUserDescription.OpenIDAuthentication;
		UserObject.InfobaseUserProperties = New ValueStorage(StoredProperties);
		AutoAttributes.InfobaseUserProperties = UserObject.InfobaseUserProperties;
	EndIf;
	
	SetStoredAuthentication = Undefined;
	If IBUserDescription.Property("CanLogOnToApplication") Then
		SetStoredAuthentication = IBUserDescription.CanLogOnToApplication = True;
	
	ElsIf IBUserDescription.Property("StandardAuthentication")
	        AND IBUserDescription.StandardAuthentication = True
	      OR IBUserDescription.Property("OSAuthentication")
	        AND IBUserDescription.OSAuthentication = True
	      OR IBUserDescription.Property("OpenIDAuthentication")
	        AND IBUserDescription.OpenIDAuthentication = True Then
		
		SetStoredAuthentication = True;
	EndIf;
	
	If SetStoredAuthentication = Undefined Then
		NewAuthentication = OldAuthentication;
	Else
		If SetStoredAuthentication Then
			IBUserDescription.Insert("StandardAuthentication", StoredProperties.StandardAuthentication);
			IBUserDescription.Insert("OpenIDAuthentication",      StoredProperties.OpenIDAuthentication);
			IBUserDescription.Insert("OSAuthentication",          StoredProperties.OSAuthentication);
		Else
			IBUserDescription.Insert("StandardAuthentication", False);
			IBUserDescription.Insert("OSAuthentication",          False);
			IBUserDescription.Insert("OpenIDAuthentication",      False);
		EndIf;
		NewAuthentication = IBUserDescription;
	EndIf;
	
	If StoredProperties.CanLogOnToApplication <> Users.CanLogOnToApplication(NewAuthentication) Then
		StoredProperties.CanLogOnToApplication = Users.CanLogOnToApplication(NewAuthentication);
		UserObject.InfobaseUserProperties = New ValueStorage(StoredProperties);
		AutoAttributes.InfobaseUserProperties = UserObject.InfobaseUserProperties;
	EndIf;
	
	// Check rights for login permission change.
	If Not ProcessingParameters.AccessLevel.FullRights
	   AND (Users.CanLogOnToApplication(OldAuthentication)
	      <> Users.CanLogOnToApplication(NewAuthentication)
	      OR Users.CanLogOnToApplication(OldAuthentication)
	        AND OldAuthentication.StandardAuthentication <> NewAuthentication.StandardAuthentication
	        AND OldAuthentication.OSAuthentication          <> NewAuthentication.OSAuthentication
	        AND OldAuthentication.OpenIDAuthentication      <> NewAuthentication.OpenIDAuthentication)
	   AND Not (ProcessingParameters.AccessLevel.ListManagement
	         AND Users.CanLogOnToApplication(NewAuthentication) = False) Then
		
		Raise ProcessingParameters.MessageTextNotEnoughRights;
	EndIf;
	
	// Attempt of writing IB user.
	ErrorDescription = "";
	IBUser = Undefined;
	If Not Users.WriteIBUser(
	         InfobaseUserID,
	         IBUserDescription,
	         CreateNewIBUser,
	         ErrorDescription,
	         IBUser) Then
		
		Raise ErrorDescription;
	EndIf;
	
	If IBUser.Roles.Contains(Metadata.Roles.FullRights) Then
		ProcessingParameters.Insert("AdministratorRecord");
	EndIf;
	
	If CreateNewIBUser Then
		IBUserDescription.Insert("ActionResult", "InfobaseUserAdded");
		InfobaseUserID = IBUserDescription.UUID;
		ProcessingParameters.Insert("IBUserSetting");
		
		If ProcessingParameters.AccessLevel.ListManagement
		   AND Not Users.CanLogOnToApplication(IBUser) Then
			
			UserObject.Prepared = True;
			ProcessingParameters.AttributesToLock.Prepared = True;
		EndIf;
	Else
		IBUserDescription.Insert("ActionResult", "InfobaseUserChanged");
		
		If Users.CanLogOnToApplication(IBUser) Then
			UserObject.Prepared = False;
			ProcessingParameters.AttributesToLock.Prepared = False;
		EndIf;
	EndIf;
	
	UserObject.InfobaseUserID = InfobaseUserID;
	
	IBUserDescription.Insert("UUID", InfobaseUserID);
	
EndProcedure

Function DeleteInfobaseUsers(UserObject, ProcessingParameters)
	
	IBUserDescription = UserObject.AdditionalProperties.IBUserDescription;
	OldUser     = ProcessingParameters.OldUser;
	
	// Clear IB user identifier.
	UserObject.InfobaseUserID = Undefined;
	
	If ProcessingParameters.OldIBUserExist Then
		
		SetPrivilegedMode(True);
		
		ErrorDescription = "";
		IBUser = Undefined;
		If Users.DeleteInfobaseUsers(
		         OldUser.InfobaseUserID,
		         ErrorDescription,
		         IBUser) Then
			
			// Set identifier of deleted IB user as the result of the Delete action.
			IBUserDescription.Insert("UUID",
				OldUser.InfobaseUserID);
			
			IBUserDescription.Insert("ActionResult", "InfobaseUserDeleted");
		Else
			Raise ErrorDescription;
		EndIf;
		
	ElsIf ValueIsFilled(OldUser.InfobaseUserID) Then
		
		IBUserDescription.Insert(
			"ActionResult", "MatchToNonExistentIBUserCleared");
	Else
		IBUserDescription.Insert(
			"ActionResult", "DeletionDoesnotNeededDBUser");
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For the EndIBUserProcessor procedure.

Procedure CheckUserAttributesChanges(UserObject, ProcessingParameters)
	
	OldUser   = ProcessingParameters.OldUser;
	AutoAttributes        = ProcessingParameters.AutoAttributes;
	AttributesToLock = ProcessingParameters.AttributesToLock;
	
	If TypeOf(UserObject) = Type("CatalogObject.Users")
	   AND AttributesToLock.Service <> UserObject.Service Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|Service attribute is not allowed to change in the subscriptions on the events.';ru='Ошибка при записи пользователя ""%1"".
		|Реквизит Служебный не допускается изменять в подписках на события.'"),
			UserObject.Ref);
	EndIf;
	
	If AttributesToLock.Prepared <> UserObject.Prepared Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|Prepared attribute can not be changed in the events subscriptions.';ru='Ошибка при записи пользователя ""%1"".
		|Реквизит Подготовлен не допускается изменять в подписках на события.'"),
			UserObject.Ref);
	EndIf;
	
	If AutoAttributes.InfobaseUserID <> UserObject.InfobaseUserID Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|Attribute InfobaseUserID can not be changed.
		|Attribute update is performed automatically.';ru='Ошибка при записи пользователя ""%1"".
		|Реквизит ИдентификаторПользователяИБ не допускается изменять.
		|Обновление реквизита выполняется автоматически.'"),
			UserObject.Ref);
	EndIf;
	
	If Not CommonUse.DataMatch(AutoAttributes.InfobaseUserProperties,
				UserObject.InfobaseUserProperties) Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|Attribute InfobaseUserProperties can not be changed.
		|Attribute update is performed automatically.';ru='Ошибка при записи пользователя ""%1"".
		|Реквизит СвойстваПользователяИБ не допускается изменять.
		|Обновление реквизита выполняется автоматически.'"),
			UserObject.Ref);
	EndIf;
	
	SetPrivilegedMode(True);
	
	If OldUser.DeletionMark = False
	   AND UserObject.DeletionMark = True
	   AND Users.CanLogOnToApplication(UserObject.InfobaseUserID) Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|You can not mark for deletion a user who is allowed to log in the application.';ru='Ошибка при записи пользователя ""%1"".
		|Нельзя помечать на удаление пользователя, которому разрешен вход в программу.'"),
			UserObject.Ref);
	EndIf;
	
	If OldUser.NotValid = False
	   AND UserObject.NotValid = True
	   AND Users.CanLogOnToApplication(UserObject.InfobaseUserID) Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|Unable to mark user who is allowed to log in application as invalid.';ru='Ошибка при записи пользователя ""%1"".
		|Нельзя пометить недействительным пользователя, которому разрешен вход в программу.'"),
			UserObject.Ref);
	EndIf;
	
	If OldUser.Prepared = False
	   AND UserObject.Prepared = True
	   AND Users.CanLogOnToApplication(UserObject.InfobaseUserID) Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while writing user %1.
		|Unable to mark as ready a user who is allowed to log in the application.';ru='Ошибка при записи пользователя ""%1"".
		|Нельзя пометить подготовленным пользователя, которому разрешен вход в программу.'"),
			UserObject.Ref);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For the ProcessRolesInterface procedure.

Procedure FillRoles(Parameters)
	
	ReadRoles = Parameters.MainParameter;
	CollectionOfRoles  = Parameters.CollectionOfRoles;
	
	CollectionOfRoles.Clear();
	
	If TypeOf(ReadRoles) = Type("Array") Then
		For Each Role IN ReadRoles Do
			If TypeOf(Role) = Type("CatalogRef.MetadataObjectIDs") Then
				If ValueIsFilled(Role) Then
					RoleName = CommonUse.ObjectAttributeValue(Role, "Name");
					CollectionOfRoles.Add().Role = TrimAll(
						?(Left(RoleName, 1) = "?", Mid(RoleName, 2), RoleName));
				EndIf;
			Else
				CollectionOfRoles.Add().Role = Role;
			EndIf;
		EndDo;
	Else
		For Each String IN ReadRoles Do
			If TypeOf(String.Role) = Type("CatalogRef.MetadataObjectIDs") Then
				If ValueIsFilled(String.Role) Then
					RoleName = CommonUse.ObjectAttributeValue(String.Role, "Name");
					CollectionOfRoles.Add().Role = TrimAll(
						?(Left(RoleName, 1) = "?", Mid(RoleName, 2), RoleName));
				EndIf;
			Else
				CollectionOfRoles.Add().Role = String.Role;
			EndIf;
		EndDo;
	EndIf;
	
	RefreshRolesTree(Parameters);
	
EndProcedure

Procedure SetInterfaceOfRolesOnFormCreating(Parameters)
	
	Form    = Parameters.Form;
	Items = Form.Items;
	
	// Set initial values before the data import from settings
	// on service when data are not written and are not imported.
	Form.ShowRolesSubsystems = False;
	Items.RolesShowRoleSubsystems.Check = False;
	
	// Show all roles for a new item, for an existing one - only selected roles.
	If Items.Find("RolesShowSelectedRolesOnly") <> Undefined Then
		Items.RolesShowSelectedRolesOnly.Check = Parameters.MainParameter;
	EndIf;
	
	RefreshRolesTree(Parameters);
	
EndProcedure

Procedure TuneRolesInterfaceOnSettingsImporting(Parameters)
	
	Settings = Parameters.MainParameter;
	Form     = Parameters.Form;
	Items  = Form.Items;
	
	ShowRolesSubsystems = Form.ShowRolesSubsystems;
	
	If Settings["ShowRolesSubsystems"] = False Then
		Form.ShowRolesSubsystems = False;
		Items.RolesShowRoleSubsystems.Check = False;
	Else
		Form.ShowRolesSubsystems = True;
		Items.RolesShowRoleSubsystems.Check = True;
	EndIf;
	
	If ShowRolesSubsystems <> Form.ShowRolesSubsystems Then
		RefreshRolesTree(Parameters);
	EndIf;
	
EndProcedure

Procedure SetReadOnlyOfRoles(Parameters)
	
	Items               = Parameters.Form.Items;
	RolesReadOnly    = Parameters.MainParameter;
	
	If RolesReadOnly <> Undefined Then
		
		Items.Roles.ReadOnly              =    RolesReadOnly;
		
		If Items.Find("RolesCheckAll") <> Undefined Then
			Items.RolesCheckAll.Enabled = Not RolesReadOnly;
		EndIf;
		If Items.Find("RolesUncheckAll") <> Undefined Then
			Items.RolesUncheckAll.Enabled = Not RolesReadOnly;
		EndIf;
	EndIf;
	
EndProcedure

Procedure SelectedRolesOnly(Parameters)
	
	Parameters.Form.Items.RolesShowSelectedRolesOnly.Check =
		Not Parameters.Form.Items.RolesShowSelectedRolesOnly.Check;
	
	RefreshRolesTree(Parameters);
	
EndProcedure

Procedure GroupBySubsystems(Parameters)
	
	Parameters.Form.ShowRolesSubsystems = Not Parameters.Form.ShowRolesSubsystems;
	Parameters.Form.Items.RolesShowRoleSubsystems.Check = Parameters.Form.ShowRolesSubsystems;
	
	RefreshRolesTree(Parameters);
	
EndProcedure

Procedure RefreshRolesTree(Parameters)
	
	Form            = Parameters.Form;
	Items         = Form.Items;
	Roles             = Form.Roles;
	UsersType = Parameters.UsersType;
	CollectionOfRoles   = Parameters.CollectionOfRoles;
	
	HideFullAccessRole = Parameters.Property("HideFullAccessRole")
	                      AND Parameters.HideFullAccessRole = True;
	
	If Items.Find("RolesShowSelectedRolesOnly") <> Undefined Then
		If Not Items.RolesShowSelectedRolesOnly.Enabled Then
			Items.RolesShowSelectedRolesOnly.Check = True;
		EndIf;
		ShowOnlySelectedRoles = Items.RolesShowSelectedRolesOnly.Check;
	Else
		ShowOnlySelectedRoles = True;
	EndIf;
	
	ShowRolesSubsystems = Parameters.Form.ShowRolesSubsystems;
	
	// Remembering of the current row.
	CurrentSubsystem = "";
	CurrentRole       = "";
	
	If Items.Roles.CurrentRow <> Undefined Then
		CurrentData = Roles.FindByID(Items.Roles.CurrentRow);
		
		If CurrentData = Undefined Then
			Items.Roles.CurrentRow = Undefined;
			
		ElsIf CurrentData.IsRole Then
			CurrentSubsystem = ?(CurrentData.GetParent() = Undefined, "", CurrentData.GetParent().Name);
			CurrentRole       = CurrentData.Name;
		Else
			CurrentSubsystem = CurrentData.Name;
			CurrentRole       = "";
		EndIf;
	EndIf;
	
	RolesTree = UsersServiceReUse.RolesTree(
		ShowRolesSubsystems, UsersType).Copy();
	
	AddNonexistentRoleNames(Parameters, RolesTree);
	
	RolesTree.Columns.Add("Check",       New TypeDescription("Boolean"));
	RolesTree.Columns.Add("PictureNumber", New TypeDescription("Number"));
	PrepareRolesTree(RolesTree.Rows, HideFullAccessRole, ShowOnlySelectedRoles, Parameters.CollectionOfRoles);
	
	Parameters.Form.ValueToFormAttribute(RolesTree, "Roles");
	
	Items.Roles.Representation = ?(RolesTree.Rows.Find(False, "IsRole") = Undefined, TableRepresentation.List, TableRepresentation.Tree);
	
	// Restore the current row.
	FoundStrings = RolesTree.Rows.FindRows(New Structure("IsRole, Name", False, CurrentSubsystem), True);
	If FoundStrings.Count() <> 0 Then
		SubsystemDescription = FoundStrings[0];
		SubsystemIndex = ?(SubsystemDescription.Parent = Undefined, RolesTree.Rows, SubsystemDescription.Parent.Rows).IndexOf(SubsystemDescription);
		SubsystemRow = FormDataTreeItemCollection(Roles, SubsystemDescription).Get(SubsystemIndex);
		If ValueIsFilled(CurrentRole) Then
			FoundStrings = SubsystemDescription.Rows.FindRows(New Structure("IsRole, Name", True, CurrentRole));
			If FoundStrings.Count() <> 0 Then
				RoleDescription = FoundStrings[0];
				Items.Roles.CurrentRow = SubsystemRow.GetItems().Get(SubsystemDescription.Rows.IndexOf(RoleDescription)).GetID();
			Else
				Items.Roles.CurrentRow = SubsystemRow.GetID();
			EndIf;
		Else
			Items.Roles.CurrentRow = SubsystemRow.GetID();
		EndIf;
	Else
		FoundStrings = RolesTree.Rows.FindRows(New Structure("IsRole, Name", True, CurrentRole), True);
		If FoundStrings.Count() <> 0 Then
			RoleDescription = FoundStrings[0];
			RoleIndex = ?(RoleDescription.Parent = Undefined, RolesTree.Rows, RoleDescription.Parent.Rows).IndexOf(RoleDescription);
			RoleRow = FormDataTreeItemCollection(Roles, RoleDescription).Get(RoleIndex);
			Items.Roles.CurrentRow = RoleRow.GetID();
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddNonexistentRoleNames(Parameters, RolesTree)
	
	CollectionOfRoles  = Parameters.CollectionOfRoles;
	
	// Add nonexistent roles.
	For Each String IN CollectionOfRoles Do
		Filter = New Structure("IsRole, Name", True, String.Role);
		If RolesTree.Rows.FindRows(Filter, True).Count() = 0 Then
			TreeRow = RolesTree.Rows.Insert(0);
			TreeRow.IsRole       = True;
			TreeRow.Name           = String.Role;
			TreeRow.Synonym       = "? " + String.Role;
		EndIf;
	EndDo;
	
EndProcedure

Procedure PrepareRolesTree(Val Collection, Val HideFullAccessRole, Val ShowOnlySelectedRoles, CollectionOfRoles)
	
	IndexOf = Collection.Count()-1;
	
	While IndexOf >= 0 Do
		String = Collection[IndexOf];
		
		PrepareRolesTree(String.Rows, HideFullAccessRole, ShowOnlySelectedRoles, CollectionOfRoles);
		
		If String.IsRole Then
			If HideFullAccessRole
			   AND (    Upper(String.Name) = Upper("FullRights")
			      OR Upper(String.Name) = Upper("SystemAdministrator")) Then
				Collection.Delete(IndexOf);
			Else
				String.PictureNumber = 7;
				String.Check = CollectionOfRoles.FindRows(
					New Structure("Role", String.Name)).Count() > 0;
				
				If ShowOnlySelectedRoles AND Not String.Check Then
					Collection.Delete(IndexOf);
				EndIf;
			EndIf;
		Else
			If String.Rows.Count() = 0 Then
				Collection.Delete(IndexOf);
			Else
				String.PictureNumber = 6;
				String.Check = String.Rows.FindRows(
					New Structure("Check", False)).Count() = 0;
			EndIf;
		EndIf;
		
		IndexOf = IndexOf-1;
	EndDo;
	
EndProcedure

Function FormDataTreeItemCollection(Val FormDataTree, Val ValueTreeRow)
	
	If ValueTreeRow.Parent = Undefined Then
		FormDataTreeItemCollection = FormDataTree.GetItems();
	Else
		ParentIndex = ?(ValueTreeRow.Parent.Parent = Undefined, ValueTreeRow.Owner().Rows, ValueTreeRow.Parent.Parent.Rows).IndexOf(ValueTreeRow.Parent);
		FormDataTreeItemCollection = FormDataTreeItemCollection(FormDataTree, ValueTreeRow.Parent).Get(ParentIndex).GetItems();
	EndIf;
	
	Return FormDataTreeItemCollection;
	
EndFunction

Procedure RefreshContentOfRoles(Parameters)
	
	Roles                        = Parameters.Form.Roles;
	ShowOnlySelectedRoles = Parameters.Form.Items.RolesShowSelectedRolesOnly.Check;
	UsersType            = Parameters.UsersType;
	
	AllRoles         = AllRoles().Array;
	InaccessibleRoles = InaccessibleRolesByUserTypes(UsersType);
	
	If Parameters.MainParameter = "IncludeAll" Then
		RowID = Undefined;
		Add            = True;
		
	ElsIf Parameters.MainParameter = "ExcludeAll" Then
		RowID = Undefined;
		Add            = False;
	Else
		RowID = Parameters.Form.Items.Roles.CurrentRow;
	EndIf;
	
	If RowID = Undefined Then
		
		AdministrativeAccessWasSet = Parameters.CollectionOfRoles.FindRows(
			New Structure("Role", "FullRights")).Count() > 0;
		
		// Process all.
		CollectionOfRoles = Parameters.CollectionOfRoles;
		CollectionOfRoles.Clear();
		If Add Then
			For Each Role IN AllRoles Do
				
				If InaccessibleRoles.Get(Role) = Undefined
				   AND Upper(Left(Role, StrLen("Delete"))) <> Upper("Delete")
				   AND Role <> "FullRights"
				   AND Role <> "SystemAdministrator" Then
					
					CollectionOfRoles.Add().Role = Role;
				EndIf;
			EndDo;
		EndIf;
		
		If Parameters.Property("PreventChangesToAdministrativeAccess")
			AND Parameters.PreventChangesToAdministrativeAccess Then
			
			AdministrativeAccessIsSet = Parameters.CollectionOfRoles.FindRows(
				New Structure("Role", "FullRights")).Count() > 0;
			
			If AdministrativeAccessIsSet AND Not AdministrativeAccessWasSet Then
				Parameters.CollectionOfRoles.FindRows(New Structure("Role", "FullRights")).Delete(0);
			ElsIf AdministrativeAccessWasSet AND Not AdministrativeAccessIsSet Then
				CollectionOfRoles.Add().Role = "FullRights";
			EndIf;
		EndIf;
		
		If ShowOnlySelectedRoles Then
			If CollectionOfRoles.Count() > 0 Then
				RefreshRolesTree(Parameters);
			Else
				Roles.GetItems().Clear();
			EndIf;
			// Return
			Return;
			// Return
		EndIf;
	Else
		CurrentData = Roles.FindByID(RowID);
		If CurrentData.IsRole Then
			AddDeleteRole(Parameters, CurrentData.Name, CurrentData.Check);
		Else
			AddDeleteSubsystemRoles(Parameters, CurrentData.GetItems(), CurrentData.Check);
		EndIf;
	EndIf;
	
	RefreshCheckOfSelectedRoles(Parameters, Roles.GetItems());
	
	Modified = True;
	
EndProcedure

Procedure AddDeleteRole(Parameters, Val Role, Val Add)
	
	FoundRoles = Parameters.CollectionOfRoles.FindRows(New Structure("Role", Role));
	
	If Add Then
		If FoundRoles.Count() = 0 Then
			Parameters.CollectionOfRoles.Add().Role = Role;
		EndIf;
	Else
		If FoundRoles.Count() > 0 Then
			Parameters.CollectionOfRoles.Delete(FoundRoles[0]);
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddDeleteSubsystemRoles(Parameters, Val Collection, Val Add)
	
	For Each String IN Collection Do
		If String.IsRole Then
			AddDeleteRole(Parameters, String.Name, Add);
		Else
			AddDeleteSubsystemRoles(Parameters, String.GetItems(), Add);
		EndIf;
	EndDo;
	
EndProcedure

Procedure RefreshCheckOfSelectedRoles(Parameters, Val Collection)
	
	ShowOnlySelectedRoles = Parameters.Form.Items.RolesShowSelectedRolesOnly.Check;
	
	IndexOf = Collection.Count()-1;
	
	While IndexOf >= 0 Do
		String = Collection[IndexOf];
		
		If String.IsRole Then
			String.Check = Parameters.CollectionOfRoles.FindRows(New Structure("Role", String.Name)).Count() > 0;
			If ShowOnlySelectedRoles AND Not String.Check Then
				Collection.Delete(IndexOf);
			EndIf;
		Else
			RefreshCheckOfSelectedRoles(Parameters, String.GetItems());
			If String.GetItems().Count() = 0 Then
				Collection.Delete(IndexOf);
			Else
				String.Check = True;
				For Each Item IN String.GetItems() Do
					If Not Item.Check Then
						String.Check = False;
						Break;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
		IndexOf = IndexOf-1;
	EndDo;
	
EndProcedure

Function UsersAddedUsingConfigurator()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.Description AS FullName,
	|	Users.InfobaseUserID,
	|	FALSE AS IsExternalUser
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID <> &EmptyUUID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.Description,
	|	ExternalUsers.InfobaseUserID,
	|	TRUE
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfobaseUserID <> &EmptyUUID";
	
	Query.SetParameter("EmptyUUID", New UUID);
	
	Exporting = Query.Execute().Unload();
	
	IBUsers = InfobaseUsers.GetUsers();
	UsersAddedInConfigurator = 0;
	
	For Each IBUser IN IBUsers Do
		
		PropertiesIBUser = Users.NewInfobaseUserInfo();
		Users.ReadIBUser(IBUser.UUID, PropertiesIBUser);
		
		String = Exporting.Find(PropertiesIBUser.UUID, "InfobaseUserID");
		
		If String = Undefined Then
			UsersAddedInConfigurator = UsersAddedInConfigurator + 1;
		EndIf;
		
	EndDo;
	
	Return UsersAddedInConfigurator;
	
EndFunction

#EndRegion
