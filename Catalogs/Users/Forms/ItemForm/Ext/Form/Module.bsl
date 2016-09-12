
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		CanChangeUsers = Undefined;
		UsersService.OnDeterminingAvailabilityChangesUsers(CanChangeUsers);
		
		If Not CanChangeUsers Then
			If Object.Ref.IsEmpty() Then
				Raise
					NStr("en='Creation of new users"
"is not supported in the demo mode.';ru='В демонстрационном режиме не поддерживается создание новых пользователей.'");
			EndIf;
			ReadOnly = True;
		EndIf;
		
		Items.IBUserShowInList.Visible   = False;
		Items.IBUserOpenIDAuthentication.Visible      = False;
		Items.IBUserStandardAuthentication.Visible = False;
		Items.IBUserCannotChangePassword.Visible = False;
		Items.OSAuthenticationProperties.Visible  = False;
		Items.IBUserRunMode.Visible = False;
	EndIf;
	
	If StandardSubsystemsServer.IsEducationalPlatform() Then
		Items.OSAuthenticationProperties.ReadOnly = True;
	EndIf;
	
	// Filling out auxiliary data.
	
	// Filling out a list of launch mode selection.
	For Each RunMode IN ClientRunMode Do
		ValueFullName = GetPredefinedValueFullName(RunMode);
		EnumValueName = Mid(ValueFullName, Find(ValueFullName, ".") + 1);
		Items.IBUserRunMode.ChoiceList.Add(EnumValueName, String(RunMode));
	EndDo;
	Items.IBUserRunMode.ChoiceList.SortByPresentation();
	
	// Filling in a language selection list.
	If Metadata.Languages.Count() < 2 Then
		Items.IBUserLanguage.Visible = False;
	Else
		For Each LanguageMetadata IN Metadata.Languages Do
			Items.IBUserLanguage.ChoiceList.Add(
				LanguageMetadata.Name, LanguageMetadata.Synonym);
		EndDo;
	EndIf;
	
	AccessLevel = UsersService.AccessLevelToUserProperties(Object);
	
	// Preparing for interactive actions considering scenarios of opening the form.
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Object.Ref) Then
		// Creating a new item.
		If Parameters.NewUserGroup <> Catalogs.UsersGroups.AllUsers Then
			NewUserGroup = Parameters.NewUserGroup;
		EndIf;
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Copying an item.
			CopyingValue = Parameters.CopyingValue;
			Object.Description = "";
			
			If Users.InfobaseUserWithFullAccess(CopyingValue, True, False) Then
				AllowedCopyIBUser = AccessLevel.SystemAdministrator;
			ElsIf Users.InfobaseUserWithFullAccess(CopyingValue, False, False) Then
				AllowedCopyIBUser = AccessLevel.FullRights;
			Else
				AllowedCopyIBUser = True;
			EndIf;
			
			If AllowedCopyIBUser Then
				ReadIBUser(
					ValueIsFilled(CopyingValue.InfobaseUserID));
			Else
				ReadIBUser();
			EndIf;
			
			If Not AccessLevel.FullRights Then
				CanLogOnToApplication = False;
				CanLogOnToApplicationDirectChangeValue = False;
			EndIf;
		Else
			// Adding an item.
			
			// Read initial values of Infobase user properties.
			ReadIBUser();
			
			If Not ValueIsFilled(Parameters.InfobaseUserID) Then
				IBUserStandardAuthentication = True;
				
				If CommonUseReUse.DataSeparationEnabled() Then
					IBUserShowInList = False;
					IBUserOpenIDAuthentication = True;
				EndIf;
				
				If AccessLevel.FullRights Then
					CanLogOnToApplication = True;
					CanLogOnToApplicationDirectChangeValue = True;
				EndIf;
			EndIf;
		EndIf;
	Else
		// Open an existing item.
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	ProcessRolesInterface("SetInterfaceOfRolesOnFormCreating", IBUserExists);
	InitialInfobaseUserDetails = InitialInfobaseUserDetails();
	NeededSynchronizationWithService = Object.Ref.IsEmpty();
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
		ModuleContactInformationManagement.OnCreateAtServer(ThisObject, Object, "ContactInformation");
		OverrideContactInformationEditingInService();
	EndIf;
	
	CommonSettingForms(True);
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemNameForPlacement", "AdditionalAttributesPage");
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
	Items.IBUserOSUser.ChoiceButton = False;
	#EndIf
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModuleClient = CommonUseClient.CommonModule("PropertiesManagementClient");
		If PropertiesManagementModuleClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
		ModuleContactInformationManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
	CommonSettingForms();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	
	If CanLogOnToApplication Then
		QuestionsTitle = NStr("en='Record of the infobase user';ru='Запись пользователя информационной базы'");
		
		If ActionsInForm.Roles = "Edit"
		   AND IBUserRoles.Count() = 0 Then
			
			If Not WriteParameters.Property("WithEmptyListOfRoles") Then
				Cancel = True;
				ShowQueryBox(
					New NotifyDescription("AfterAnswerToQuestionAboutRecordWithEmptyRoleList", ThisObject, WriteParameters),
					NStr("en='A role was not assigned to the Infobase user. Continue?';ru='Пользователю информационной базы не установлено ни одной роли. Продолжить?'"),
					QuestionDialogMode.YesNo,
					,
					,
					QuestionsTitle);
				Return;
			EndIf;
		EndIf;
		
		// Data processor of record of the first administrator.
		If Not WriteParameters.Property("WithCreationOfFirstAdmin") Then
			QuestionText = "";
			If NeedToCreateFirstAdministrator(QuestionText) Then
				Cancel = True;
				ShowQueryBox(
					New NotifyDescription("AfterConfirmingFirstAdministratorCreation", ThisObject, WriteParameters),
					QuestionText, QuestionDialogMode.YesNo, , , QuestionsTitle);
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled
		AND NeededSynchronizationWithService
		AND ServiceUserPassword = Undefined Then
		
		Cancel = True;
		StandardSubsystemsClient.WhenPromptedForPasswordForAuthenticationToService(
			New NotifyDescription("AfterPasswordRequestForAuthenticationInServiceBeforeWrite", ThisObject, WriteParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.AdditionalProperties.Insert("CopyingValue", CopyingValue);
	
	CurrentObject.AdditionalProperties.Insert("ServiceUserPassword", ServiceUserPassword);
	CurrentObject.AdditionalProperties.Insert("SynchronizeWithService", NeededSynchronizationWithService);
	
	If RequiredUserRecordIB(ThisObject) Then
		IBUserDescription = IBUserDescription();
		IBUserDescription.Delete("PasswordConfirmation");
		
		If ValueIsFilled(Object.InfobaseUserID) Then
			IBUserDescription.Insert("UUID", Object.InfobaseUserID);
		EndIf;
		IBUserDescription.Insert("Action", "Write");
		
		CurrentObject.AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
	EndIf;
	
	If ActionsInForm.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, CommonUse.ObjectAttributesValues(
			CurrentObject.Ref, "Name, DeletionMark"));
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("NewUserGroup", NewUserGroup);
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
		If Not Cancel AND ActionsInForm.ContactInformation = "Edit" Then
			ModuleContactInformationManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	NeededSynchronizationWithService = False;
	
	If RequiredUserRecordIB(ThisObject) Then
		WriteParameters.Insert(
			CurrentObject.AdditionalProperties.IBUserDescription.ActionResult);
	EndIf;
	
	CommonSettingForms(, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_Users", New Structure, Object.Ref);
	
	If WriteParameters.Property("InfobaseUserAdded") Then
		Notify("InfobaseUserAdded", WriteParameters.InfobaseUserAdded, ThisObject);
		
	ElsIf WriteParameters.Property("InfobaseUserChanged") Then
		Notify("InfobaseUserChanged", WriteParameters.InfobaseUserChanged, ThisObject);
		
	ElsIf WriteParameters.Property("InfobaseUserDeleted") Then
		Notify("InfobaseUserDeleted", WriteParameters.InfobaseUserDeleted, ThisObject);
		
	ElsIf WriteParameters.Property("MatchToNonExistentIBUserCleared") Then
		Notify(
			"MatchToNonExistentIBUserCleared",
			WriteParameters.MatchToNonExistentIBUserCleared,
			ThisObject);
	EndIf;
	
	If ValueIsFilled(NewUserGroup) Then
		
		NotifyChanged(NewUserGroup);
		Notify("Write_UsersGroups", New Structure, NewUserGroup);
		NewUserGroup = Undefined;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If RequiredUserRecordIB(ThisObject) Then
		IBUserDescription = IBUserDescription();
		IBUserDescription.Insert("InfobaseUserID", Object.InfobaseUserID);
		UsersService.CheckIBUserFullName(IBUserDescription, Cancel);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactInformationManagement = CommonUse.CommonModule("ContactInformationManagement");
		ModuleContactInformationManagement.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("TuneRolesInterfaceOnSettingsImporting", Settings);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FillFromInfobaseUser(Command)
	
	FillFieldsByUserIBAtServer();
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	
	RefreshNameForEntering(ThisObject, True);
	
	SetNecessitySynchronizationService(ThisObject);
	
EndProcedure

&AtClient
Procedure NotValidOnChange(Item)
	
	If Object.NotValid Then
		CanLogOnToApplication = False;
	Else
		CanLogOnToApplication = CanLogOnToApplicationDirectChangeValue
			AND (IBUserOpenIDAuthentication
			   Or IBUserStandardAuthentication
			   Or IBUserOSAuthentication);
	EndIf;
	
	SetEnabledOfProperties(ThisObject);
	
	SetNecessitySynchronizationService(ThisObject);
	
EndProcedure

&AtClient
Procedure CanLogOnToApplicationOnChange(Item)
	
	If Object.DeletionMark AND CanLogOnToApplication Then
		CanLogOnToApplication = False;
		ShowMessageBox(,
			NStr("en='To allow access to the"
"application remove the mark for deletion of this user.';ru='Чтобы разрешить вход"
"в программу, требуется снять пометку на удаление с этого пользователя.'"));
		Return;
	EndIf;
	
	RefreshNameForEntering(ThisObject);
	
	If CanLogOnToApplication
	   AND Not IBUserOpenIDAuthentication
	   AND Not IBUserStandardAuthentication
	   AND Not IBUserOSAuthentication Then
	
		IBUserStandardAuthentication = True;
	EndIf;
	
	SetEnabledOfProperties(ThisObject);
	
	SetNecessitySynchronizationService(ThisObject);
	
	If Not AccessLevel.FullRights
	   AND AccessLevel.ListManagement
	   AND Not CanLogOnToApplication Then
		
		ShowMessageBox(,
			NStr("en='After saving, only administrator can allow log on.';ru='После записи вход в программу сможет разрешить только администратор.'"));
	EndIf;
	
	CanLogOnToApplicationDirectChangeValue = CanLogOnToApplication;
	
EndProcedure

&AtClient
Procedure IBUserStandardAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	IBUserPassword = Password;
	
	SetEnabledOfProperties(ThisObject);
	
	SetNecessitySynchronizationService(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserShowInChoiceListOnChange(Item)
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserCannotChangePasswordOnChange(Item)
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserOpenIDAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure IBUserOSAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure IBUserOSUserOnChange(Item)
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserOSUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	#If Not WebClient Then
		OpenForm("Catalog.Users.Form.OSUserChoiceForm", , Item);
	#EndIf
	
EndProcedure

&AtClient
Procedure IBUserNameOnChange(Item)
	
	SetEnabledOfProperties(ThisObject);
	
	SetNecessitySynchronizationService(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserLanguageOnChange(Item)
	
	SetEnabledOfProperties(ThisObject);
	
	SetNecessitySynchronizationService(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserRunModeOnChange(Item)
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserRunModeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Support contact information.

&AtClient
Procedure Attachable_EMailOnChange(Item)
	
	ModuleContactInformationManagementClient =
		CommonUseClient.CommonModule("ContactInformationManagementClient");
		
	ModuleContactInformationManagementClient.PresentationOnChange(ThisObject, Item);
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;
	
	CITable = ThisObject.ContactInformationAdditionalAttributeInfo;
	
	StringEMail = CITable.FindRows(New Structure("Kind",
		ContactInformationKindUserEmail()))[0];
	
	If ValueIsFilled(ThisObject[StringEMail.AttributeName]) Then
		Password = "" + New UUID + "qQ";
		PasswordConfirmation = Password;
		IBUserPassword = Password;
	EndIf;
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_PhoneOnChange(Item)
	
	ModuleContactInformationManagementClient =
		CommonUseClient.CommonModule("ContactInformationManagementClient");
	
	ModuleContactInformationManagementClient.PresentationOnChange(ThisObject, Item);
	
	SetNecessitySynchronizationService(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_EMailStartChoice(Item)
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled
	   AND ServiceUserPassword = Undefined Then
	
		StandardSubsystemsClient.WhenPromptedForPasswordForAuthenticationToService(
			New NotifyDescription("Attachable_EMailStartChoiceEnd", ThisObject),
			ThisObject,
			ServiceUserPassword);
	Else
		Attachable_EMailStartChoiceEnd("", Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_EMailStartChoiceEnd(NewServiceUserPassword, NotSpecified) Export
	
	If NewServiceUserPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = NewServiceUserPassword;
	
	CITable = ThisObject.ContactInformationAdditionalAttributeInfo;
	
	Filter = New Structure("Kind", ContactInformationKindUserEmail());
	
	StringEMail = CITable.FindRows(Filter)[0];
	
	FormParameters = New Structure;
	FormParameters.Insert("ServiceUserPassword", ServiceUserPassword);
	FormParameters.Insert("OldEmail",  ThisObject[StringEMail.AttributeName]);
	FormParameters.Insert("User", Object.Ref);
	
	Try
		
		OpenForm("Catalog.Users.Form.EmailAddressChange", FormParameters, ThisObject);
		
	Except
		
		ServiceUserPassword = Undefined;
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ModuleContactInformationManagementClient =
		CommonUseClient.CommonModule("ContactInformationManagementClient");
	
	ModuleContactInformationManagementClient.PresentationOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ModuleContactInformationManagementClient =
		CommonUseClient.CommonModule("ContactInformationManagementClient");
	
	Result = ModuleContactInformationManagementClient.PresentationStartChoice(
		ThisObject, Item, , StandardProcessing);
	
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	
	ModuleContactInformationManagementClient =
		CommonUseClient.CommonModule("ContactInformationManagementClient");
	
	Result = ModuleContactInformationManagementClient.ClearingPresentation(
		ThisObject, Item.Name);
	
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	ModuleContactInformationManagementClient =
		CommonUseClient.CommonModule("ContactInformationManagementClient");
	
	Result = ModuleContactInformationManagementClient.LinkCommand(
		ThisObject, Command.Name);
	
	RefreshContactInformation(Result);
	
	ModuleContactInformationManagementClient.OpenAddressEntryForm(ThisObject, Result);
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersRoles

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("RefreshContentOfRoles");
		
		If Items.Roles.CurrentData.Name = "FullRights" Then
			SetNecessitySynchronizationService(ThisObject);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtClient
Procedure ShowOnlySelectedRoles(Command)
	
	ProcessRolesInterface("SelectedRolesOnly");
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure GroupRoleBySubsystems(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure EnableRoles(Command)
	
	ProcessRolesInterface("RefreshContentOfRoles", "IncludeAll");
	
	UsersServiceClient.ExpandRolesSubsystems(ThisObject, False);
	
EndProcedure

&AtClient
Procedure ExcludeRoles(Command)
	
	ProcessRolesInterface("RefreshContentOfRoles", "ExcludeAll");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Support additional attributes.

&AtClient
Procedure Attachable_EditContentOfProperties()
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModuleClient = CommonUseClient.CommonModule("PropertiesManagementClient");
		PropertiesManagementModuleClient.EditContentOfProperties(ThisObject, Object.Ref);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesCheck.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Roles.Name");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='FullRights';ru='ПолныеПрава'");

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("PreventChangesToAdministrativeAccess");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesCheck.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesSynonym.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Roles.Name");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='FullRights';ru='ПолныеПрава'");

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("PreventChangesToAdministrativeAccess");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleDataColor);

EndProcedure

&AtServer
Procedure CommonSettingForms(OnCreateAtServer = False, WriteParameters = Undefined)
	
	If InitialInfobaseUserDetails = Undefined Then
		Return; // Call OnReadAtServer before call OnCreateAtServer.
	EndIf;
	
	If Not OnCreateAtServer Then
		ReadIBUser();
	EndIf;
	
	AccessLevel = UsersService.AccessLevelToUserProperties(Object);
	
	DefineActionsInForm();
	
	DefineUserInconsistenciesWithUserIB(WriteParameters);
	
	ProcessRolesInterface(
		"SetReadOnlyOfRoles",
		    UsersService.BanEditOfRoles()
		Or ActionsInForm.Roles <> "Edit"
		Or Not AccessLevel.SettingsForLogin);
	
	If CommonUseReUse.DataSeparationEnabled() Then
		ActionsWithServiceUser = Undefined;
		UsersService.WhenUserActionService(
			ActionsWithServiceUser, Object.Ref);
	EndIf;
	
	// Setting view possibility.
	Items.ContactInformation.Visible   = ValueIsFilled(ActionsInForm.ContactInformation);
	Items.InfobaseUserProperties.Visible = ValueIsFilled(ActionsInForm.InfobaseUserProperties);
	
	OutputRoleList = ValueIsFilled(ActionsInForm.Roles);
	Items.RoleRepresentation.Visible = OutputRoleList;
	Items.PlatformAuthenticationProperties.Representation =
		?(OutputRoleList, UsualGroupRepresentation.None, UsualGroupRepresentation.NormalSeparation);
	
	Items.CheckSettingsAfterLogOnRecommendation.Visible =
		AccessLevel.FullRights AND Object.Prepared AND Not CanLogOnToApplicationOnRead;
	
	// Setting change possibility.
	If Object.Service Then
		ReadOnly = True;
	EndIf;
	
	ReadOnly = ReadOnly
		OR ActionsInForm.Roles                   <> "Edit"
		  AND ActionsInForm.ItemProperties       <> "Edit"
		  AND ActionsInForm.ContactInformation   <> "Edit"
		  AND ActionsInForm.InfobaseUserProperties <> "Edit";
	
	Items.Description.ReadOnly =
		Not (ActionsInForm.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
	Items.NotValid.ReadOnly = Items.Description.ReadOnly;
	
	Items.MainProperties.ReadOnly =
		Not (  ActionsInForm.InfobaseUserProperties = "Edit"
		    AND (AccessLevel.ListManagement Or AccessLevel.ChangeCurrent));
	
	Items.IBUserName1.ReadOnly                      = Not AccessLevel.SettingsForLogin;
	Items.IBUserName2.ReadOnly                      = Not AccessLevel.SettingsForLogin;
	Items.IBUserStandardAuthentication.ReadOnly = Not AccessLevel.SettingsForLogin;
	Items.IBUserOpenIDAuthentication.ReadOnly      = Not AccessLevel.SettingsForLogin;
	Items.IBUserOSAuthentication.ReadOnly          = Not AccessLevel.SettingsForLogin;
	Items.IBUserOSUser.ReadOnly            = Not AccessLevel.SettingsForLogin;
	
	Items.IBUserShowInList.ReadOnly = Not AccessLevel.ListManagement;
	Items.IBUserCannotChangePassword.ReadOnly = Not AccessLevel.ListManagement;
	Items.IBUserRunMode.ReadOnly            = Not AccessLevel.ListManagement;
	
	Items.Comment.ReadOnly =
		Not (ActionsInForm.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
	SetEnabledOfProperties(ThisObject);
	
EndProcedure

// Event handler continuation BeforeWrite.
&AtClient
Procedure AfterPasswordRequestForAuthenticationInServiceBeforeWrite(NewServiceUserPassword, WriteParameters) Export
	
	If NewServiceUserPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = NewServiceUserPassword;
	
	Try
		
		Write(WriteParameters);
		
	Except
		
		ServiceUserPassword = Undefined;
		Raise;
		
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshNameForEntering(Form, OnNameChange = False)
	
	Items = Form.Items;
	Object   = Form.Object;
	
	If Form.IBUserExists Then
		Return;
	EndIf;
	
	ShortName = UsersServiceClientServer.GetShortNameOfIBUser(Form.Object.Description);
	
	If Items.NameMarkIncompleteSwitch.CurrentPage = Items.NameWithoutMarkIncomplete Then
		If Form.IBUserName = ShortName Then
			Form.IBUserName = "";
		EndIf;
	Else
		
		If OnNameChange
		 Or Not ValueIsFilled(Form.IBUserName) Then
			
			Form.IBUserName = ShortName;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AuthenticationOnChange()
	
	SetEnabledOfProperties(ThisObject);
	
	If Not IBUserOpenIDAuthentication
	   AND Not IBUserStandardAuthentication
	   AND Not IBUserOSAuthentication Then
	
		CanLogOnToApplication = False;
		
	ElsIf Not CanLogOnToApplication Then
		CanLogOnToApplication = CanLogOnToApplicationDirectChangeValue;
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineActionsInForm()
	
	ActionsInForm = New Structure;
	
	// "", "View", "Edit".
	ActionsInForm.Insert("Roles", "");
	
	// "", "View", "Edit".
	ActionsInForm.Insert("ContactInformation", "view");
	
	// "", "ViewAll", "Edit".
	ActionsInForm.Insert("InfobaseUserProperties", "");
	
	// "", "View", "Edit".
	ActionsInForm.Insert("ItemProperties", "view");
	
	If Not AccessLevel.SystemAdministrator
	   AND AccessLevel.FullRights
	   AND Users.InfobaseUserWithFullAccess(Object.Ref, True) Then
		
		// System administrator is available only for viewing.
		ActionsInForm.Roles                   = "view";
		ActionsInForm.InfobaseUserProperties = "view";
	
	ElsIf AccessLevel.SystemAdministrator
	      OR AccessLevel.FullRights Then
		
		ActionsInForm.Roles                   = "Edit";
		ActionsInForm.ContactInformation   = "Edit";
		ActionsInForm.InfobaseUserProperties = "Edit";
		ActionsInForm.ItemProperties       = "Edit";
	Else
		If AccessLevel.ChangeCurrent Then
			ActionsInForm.InfobaseUserProperties = "Edit";
			ActionsInForm.ContactInformation   = "Edit";
		EndIf;
		
		If AccessLevel.ListManagement Then
			// Responsible for the list of users and user groups.
			// (in charge of the orders on hiring,
			//  transferring, reappointment, creation of departments, divisions and work groups).
			ActionsInForm.InfobaseUserProperties = "Edit";
			ActionsInForm.ContactInformation   = "Edit";
			ActionsInForm.ItemProperties       = "Edit";
			
			If AccessLevel.SettingsForLogin Then
				ActionsInForm.Roles = "Edit";
			EndIf;
			If Users.InfobaseUserWithFullAccess(Object.Ref) Then
				ActionsInForm.Roles = "view";
			EndIf;
		EndIf;
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.Users\OnDeterminingFormAction");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingFormAction(Object.Ref, ActionsInForm);
	EndDo;
	
	UsersOverridable.ChangeActionsInForm(Object.Ref, ActionsInForm);
	
	// Checking action names in the form.
	If Find(", View, Edit,", ", " + ActionsInForm.Roles + ",") = 0 Then
		ActionsInForm.Roles = "";
		
	ElsIf ActionsInForm.Roles = "Edit"
	        AND UsersService.BanEditOfRoles() Then
		
		ActionsInForm.Roles = "view";
	EndIf;
	
	If Find(", View, Edit,", ", " + ActionsInForm.ContactInformation + ",") = 0 Then
		ActionsInForm.ContactInformation = "";
	EndIf;
	
	If Find(", View, ViewAll, Edit, EditOwn, EditAll,",
	           ", " + ActionsInForm.InfobaseUserProperties + ",") = 0 Then
		
		ActionsInForm.InfobaseUserProperties = "";
		
	Else // Backward compatibility support.
		If Find(ActionsInForm.InfobaseUserProperties, "view") Then
			ActionsInForm.InfobaseUserProperties = "view";
			
		ElsIf Find(ActionsInForm.InfobaseUserProperties, "Edit") Then
			ActionsInForm.InfobaseUserProperties = "Edit";
		EndIf;
	EndIf;
	
	If Find(", View, Edit,", ", " + ActionsInForm.ItemProperties + ",") = 0 Then
		ActionsInForm.ItemProperties = "";
	EndIf;
	
	If Object.Service Then
		If ActionsInForm.Roles = "Edit" Then
			ActionsInForm.Roles = "view";
		EndIf;
		
		If ActionsInForm.ContactInformation = "Edit" Then
			ActionsInForm.ContactInformation = "view";
		EndIf;
		
		If ActionsInForm.InfobaseUserProperties = "Edit" Then
			ActionsInForm.InfobaseUserProperties = "view";
		EndIf;
		
		If ActionsInForm.ItemProperties = "Edit" Then
			ActionsInForm.ItemProperties = "view";
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function IBUserDescription(ForCheckFirstAdmin = False)
	
	If AccessLevel.ListManagement
	   AND ActionsInForm.ItemProperties = "Edit" Then
		
		IBUserFullName = Object.Description;
	EndIf;
	
	If AccessLevel.SystemAdministrator
	 Or AccessLevel.FullRights Then
		
		Result = Users.NewInfobaseUserInfo();
		Users.CopyInfobaseUserProperties(
			Result,
			ThisObject,
			,
			"UUID,
			|Roles",
			"IBUser");
		
		Result.Insert("CanLogOnToApplication", CanLogOnToApplication);
	Else
		Result = New Structure;
		
		If AccessLevel.ChangeCurrent Then
			Result.Insert("Password", IBUserPassword);
			Result.Insert("Language",   IBUserLanguage);
		EndIf;
		
		If AccessLevel.ListManagement Then
			Result.Insert("CanLogOnToApplication",  CanLogOnToApplication);
			Result.Insert("ShowInList", IBUserShowInList);
			Result.Insert("CannotChangePassword", IBUserCannotChangePassword);
			Result.Insert("Language",                    IBUserLanguage);
			Result.Insert("RunMode",            IBUserRunMode);
			
			If ActionsInForm.ItemProperties = "Edit" Then
				Result.Insert("FullName", IBUserFullName);
			EndIf;
		EndIf;
		
		If AccessLevel.SettingsForLogin Then
			Result.Insert("StandardAuthentication", IBUserStandardAuthentication);
			Result.Insert("Name",                       IBUserName);
			Result.Insert("Password",                    IBUserPassword);
			Result.Insert("OpenIDAuthentication",      IBUserOpenIDAuthentication);
			Result.Insert("OSAuthentication",          IBUserOSAuthentication);
			Result.Insert("OSUser",            IBUserOSUser);
		EndIf;
	EndIf;
	Result.Insert("PasswordConfirmation", PasswordConfirmation);
	
	If Not ForCheckFirstAdmin
	   AND UsersService.NeedToCreateFirstAdministrator(Result) Then
		
		AdministratorRoles = New Array;
		AdministratorRoles.Add("FullRights");
		
		SystemAdministratorRoleName = Users.SystemAdministratorRole().Name;
		If AdministratorRoles.Find(SystemAdministratorRoleName) = Undefined Then
			AdministratorRoles.Add(SystemAdministratorRoleName);
		EndIf;
		Result.Insert("Roles", AdministratorRoles);
	
	ElsIf AccessLevel.SettingsForLogin
	        AND Not UsersService.BanEditOfRoles() Then
		
		CurrentRoles = IBUserRoles.Unload(, "Role").UnloadColumn("Role");
		Result.Insert("Roles", CurrentRoles);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function NeedToCreateFirstAdministrator(QuestionText = Undefined)
	
	Return UsersService.NeedToCreateFirstAdministrator(
		IBUserDescription(True),
		QuestionText);
	
EndFunction

&AtClientAtServerNoContext
Procedure SetNecessitySynchronizationService(Form)
	
	Form.NeededSynchronizationWithService = True;
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutRecordWithEmptyRoleList(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("WithEmptyListOfRoles");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterConfirmingFirstAdministratorCreation(Response, WriteParameters) Export
	
	If Response <> DialogReturnCode.No Then
		WriteParameters.Insert("WithCreationOfFirstAdmin");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Support contact information.

&AtServer
Function RefreshContactInformation(Result = Undefined)
	
	ModuleContactInformationManagementServer =
		CommonUse.CommonModule("ContactInformationManagement");
	
	Return ModuleContactInformationManagementServer.RefreshContactInformation(
		ThisObject, Object, Result);
	
EndFunction

&AtServer
Procedure OverrideContactInformationEditingInService()
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ContactInformation = ThisObject.ContactInformationAdditionalAttributeInfo;
	
	StringEMail = ContactInformation.FindRows(New Structure("Kind", Catalogs["ContactInformationTypes"].UserEmail))[0];
	ItemsEMail = Items[StringEMail.AttributeName];
	ItemsEMail.SetAction("OnChange", "Attachable_OnEEmailAddressChange");
	
	ItemsEMail.ChoiceButton = True;
	ItemsEMail.SetAction("StartChoice", "Attachable_EMailStartChoice");
	
	StringPhone = ContactInformation.FindRows(New Structure("Kind", Catalogs["ContactInformationTypes"].UserPhone))[0];
	ItemPhone = Items[StringPhone.AttributeName];
	ItemPhone.SetAction("OnChange", "Attachable_OnPhoneChange");
	
EndProcedure

&AtClientAtServerNoContext
Function ContactInformationKindUserEmail()
	
	PredefinedValueName = "Catalog." + "ContactInformationTypes" + ".UserEmail";
	
	Return PredefinedValue(PredefinedValueName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Support additional attributes.

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processing an infobase user

&AtServer
Function InitialInfobaseUserDetails()
	
	SetPrivilegedMode(True);
	
	IBUserDescription = Users.NewInfobaseUserInfo();
	
	If Not ValueIsFilled(Object.Ref) Then
		If CommonUseReUse.DataSeparationEnabled() Then
			IBUserDescription.ShowInList = False;
		Else
			IBUserDescription.ShowInList =
				Not Constants.UseExternalUsers.Get();
		EndIf;
		IBUserDescription.StandardAuthentication = True;
	EndIf;
	IBUserDescription.Roles = New Array;
	
	Return IBUserDescription;
	
EndFunction

&AtServer
Procedure ReadIBUser(OnItemCopy = False)
	
	SetPrivilegedMode(True);
	
	Password              = "";
	PasswordConfirmation = "";
	ReadProperties      = Undefined;
	IBUserDescription   = InitialInfobaseUserDetails();
	IBUserExists = False;
	IBUserDefault   = False;
	CanLogOnToApplication   = False;
	CanLogOnToApplicationDirectChangeValue = False;
	
	If OnItemCopy Then
		
		If Users.ReadIBUser(
		         Parameters.CopyingValue.InfobaseUserID,
		         ReadProperties) Then
			
			// Map an Infobase user with a user in the catalog.
			If Users.CanLogOnToApplication(ReadProperties) Then
				CanLogOnToApplication = True;
				CanLogOnToApplicationDirectChangeValue = True;
			EndIf;
			
			// Copy Infobase user roles and properties.
			FillPropertyValues(
				IBUserDescription,
				ReadProperties,
				"CannotChangePassword,
				|ShowInList,
				|RunMode,
				|RunMode" + ?(NOT Items.IBUserLanguage.Visible, "", ", Language") + ?(UsersService.BanEditOfRoles(), "", ", Roles"));
		EndIf;
		Object.InfobaseUserID = Undefined;
	Else
		If Users.ReadIBUser(
		       Object.InfobaseUserID, ReadProperties) Then
		
			IBUserExists = True;
			IBUserDefault = True;
		
		ElsIf Parameters.Property("InfobaseUserID")
		        AND ValueIsFilled(Parameters.InfobaseUserID) Then
			
			Object.InfobaseUserID = Parameters.InfobaseUserID;
			
			If Users.ReadIBUser(
			       Object.InfobaseUserID, ReadProperties) Then
				
				IBUserExists = True;
				If Object.Description <> ReadProperties.FullName Then
					Object.Description = ReadProperties.FullName;
					Modified = True;
				EndIf;
			EndIf;
		EndIf;
		
		If IBUserExists Then
			
			If Users.CanLogOnToApplication(ReadProperties) Then
				CanLogOnToApplication = True;
				CanLogOnToApplicationDirectChangeValue = True;
			EndIf;
			
			FillPropertyValues(
				IBUserDescription,
				ReadProperties,
				"Name,
				|FullName,
				|OpenIDAuthentication,
				|StandardAuthentication,
				|ShowInList,
				|CannotChangePassword,
				|OSAuthentication,
				|OSUser,
				|RunMode" + ?(NOT Items.IBUserLanguage.Visible, "", ", Language") + ?(UsersService.BanEditOfRoles(), "", ", Roles"));
			
			If ReadProperties.PasswordIsSet Then
				Password              = "**********";
				PasswordConfirmation = "**********";
			EndIf;
		EndIf;
	EndIf;
	
	Users.CopyInfobaseUserProperties(
		ThisObject,
		IBUserDescription,
		,
		"UUID,
		|Roles",
		"IBUser");
	
	If IBUserDefault AND Not CanLogOnToApplication Then
		StoredProperties = UsersService.StoredInfobaseUserProperties(Object.Ref);
		IBUserOpenIDAuthentication      = StoredProperties.OpenIDAuthentication;
		IBUserStandardAuthentication = StoredProperties.StandardAuthentication;
		IBUserOSAuthentication          = StoredProperties.OSAuthentication;
	EndIf;
	
	ProcessRolesInterface("FillRoles", IBUserDescription.Roles);
	
	CanLogOnToApplicationOnRead = CanLogOnToApplication;
	
EndProcedure

&AtServer
Procedure DefineUserInconsistenciesWithUserIB(WriteParameters = Undefined)
	
	// Checking the correspondence between property
	// Infobase user FullName and attribute User name.
	
	ShowMismatch = True;
	ShowCommandsDifferences = False;
	
	If Not IBUserExists Then
		ShowMismatch = False;
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		Object.Description = IBUserFullName;
		ShowMismatch = False;
		
	ElsIf AccessLevel.ListManagement Then
		
		PropertiesAdjustment = New Array;
		
		If IBUserFullName <> Object.Description Then
			ShowCommandsDifferences =
				    ShowCommandsDifferences
				Or ActionsInForm.ItemProperties = "Edit";
			
			PropertiesAdjustment.Insert(0, StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Full name ""%1""';ru='Полное имя ""%1""'"), IBUserFullName));
		EndIf;
		
		If PropertiesAdjustment.Count() > 0 Then
			StringPropertyClarification = "";
			CurrentRow = "";
			For Each AdjustmentProperties IN PropertiesAdjustment Do
				If StrLen(CurrentRow + AdjustmentProperties) > 90 Then
					StringPropertyClarification = StringPropertyClarification + TrimR(CurrentRow) + ", " + Chars.LF;
					CurrentRow = "";
				EndIf;
				CurrentRow = CurrentRow + ?(ValueIsFilled(CurrentRow), ", ", "") + AdjustmentProperties;
			EndDo;
			If ValueIsFilled(CurrentRow) Then
				StringPropertyClarification = StringPropertyClarification + CurrentRow;
			EndIf;
			Items.PropertiesMismatchNote.Title =
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='The following infobase user properties differ from those specified"
"in this form: %1.';ru='Следующие свойства пользователя информационной базы отличаются"
"от указанных в этой форме: %1.'"), StringPropertyClarification)
				+ Chars.LF
				+ ?(ShowCommandsDifferences,
					NStr("en='Click ""Write"" to resolve the differences and not to show this warning message.';ru='Нажмите ""Записать"", чтобы устранить различия и не выводить это предупреждение.'"),
					NStr("en='To resolve the differences, contact your administrator.';ru='Обратитесь к администратору, чтобы устранить различия.'"));
		Else
			ShowMismatch = False;
		EndIf;
	Else
		ShowMismatch = False;
	EndIf;
	
	Items.PropertiesMismatchProcessing.Visible   = ShowMismatch;
	Items.ResolveDifferencesCommandProperties.Visible = ShowCommandsDifferences;
	
	// Definition mapping of a nonexistent IB user with a user in the catalog.
	NewMappingWithNonExistentInfobaseUser
		= Not IBUserExists
		AND ValueIsFilled(Object.InfobaseUserID);
	
	If WriteParameters <> Undefined
	   AND HasMappingToNonexistentInfobaseUser
	   AND Not NewMappingWithNonExistentInfobaseUser Then
		
		WriteParameters.Insert("MatchToNonExistentIBUserCleared", Object.Ref);
	EndIf;
	HasMappingToNonexistentInfobaseUser = NewMappingWithNonExistentInfobaseUser;
	
	If AccessLevel.ListManagement Then
		Items.MappingMismatchProcessing.Visible = HasMappingToNonexistentInfobaseUser;
	Else
		// Mapping can not be changed.
		Items.MappingMismatchProcessing.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillFieldsByUserIBAtServer()
	
	If AccessLevel.ListManagement
	   AND ActionsInForm.ItemProperties = "Edit" Then
		
		Object.Description = IBUserFullName;
	EndIf;
	
	DefineUserInconsistenciesWithUserIB();
	
	SetEnabledOfProperties(ThisObject);
	
	SetNecessitySynchronizationService(ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial filling, check for filling, properties availability.

&AtClientAtServerNoContext
Procedure SetEnabledOfProperties(Form)
	
	Items       = Form.Items;
	Object         = Form.Object;
	ActionsInForm = Form.ActionsInForm;
	AccessLevel = Form.AccessLevel;
	ActionsWithServiceUser = Form.ActionsWithServiceUser;
	
	// Setting change possibility.
	Items.CanLogOnToApplication.ReadOnly =
		Not (  Items.MainProperties.ReadOnly = False
		    AND (    AccessLevel.FullRights
		       Or AccessLevel.ListManagement AND Form.CanLogOnToApplicationOnRead));
	
	Items.Password.ReadOnly =
		Not (    AccessLevel.SettingsForLogin
		    Or AccessLevel.ChangeCurrent
		      AND Not Form.IBUserCannotChangePassword);
	
	Items.PasswordConfirmation.ReadOnly = Items.Password.ReadOnly;
	
	// Setting of required filling.
	If RequiredUserRecordIB(Form, False) Then
		NewPage = Items.NameWithMarkIncomplete;
	Else
		NewPage = Items.NameWithoutMarkIncomplete;
	EndIf;
	
	If Items.NameMarkIncompleteSwitch.CurrentPage <> NewPage Then
		Items.NameMarkIncompleteSwitch.CurrentPage = NewPage;
	EndIf;
	RefreshNameForEntering(Form);
	
	// Setting of associated items availability.
	Items.CanLogOnToApplication.Enabled = Not Object.NotValid;
	Items.MainProperties.Enabled       = Not Object.NotValid;
	
	Items.Password.Enabled              = Form.IBUserStandardAuthentication;
	Items.PasswordConfirmation.Enabled = Form.IBUserStandardAuthentication;
	
	Items.IBUserCannotChangePassword.Enabled
		= Form.IBUserStandardAuthentication;
	
	Items.IBUserShowInList.Enabled
		= Form.IBUserStandardAuthentication;
	
	Items.IBUserOSUser.Enabled = Form.IBUserOSAuthentication;
	
	// Adjustment of settings in the service model.
	If ActionsWithServiceUser <> Undefined Then
		
		// CI editing availability.
		ActionsCI = ActionsWithServiceUser.ContactInformation;
		
		For Each CIRow IN Form.ContactInformationAdditionalAttributeInfo Do
			ActionsKindCI = ActionsCI.Get(CIRow.Type);
			If ActionsKindCI = Undefined Then
				// Possibility to edit this kind of CI is not managed by the service manager.
				Continue;
			EndIf;
			
			ItemCI = Items[CIRow.AttributeName];
			
			If CIRow.Type = ContactInformationKindUserEmail() Then
				
				ItemCI.ReadOnly = Not Object.Ref.IsEmpty();
				
				ItemCI.ChoiceButton = Not Object.Ref.IsEmpty()
					AND ActionsKindCI.Update;
					
				FillEMail = ValueIsFilled(Form[CIRow.AttributeName]);
			Else
				ItemCI.ReadOnly = ItemCI.ReadOnly
					OR Not ActionsKindCI.Update;
			EndIf;
		EndDo;
		
		If Object.Ref.IsEmpty() AND FillEMail Then
			CanChangePassword = False;
		Else
			CanChangePassword = ActionsWithServiceUser.ChangePassword;
		EndIf;
		
		Items.Password.ReadOnly = Items.Password.ReadOnly
			OR Not CanChangePassword;
			
		Items.PasswordConfirmation.ReadOnly = Items.PasswordConfirmation.ReadOnly
			OR Not CanChangePassword;
		
		Items.IBUserName1.ReadOnly = Items.IBUserName1.ReadOnly
			OR Not ActionsWithServiceUser.ChangeName;
			
		Items.IBUserName2.ReadOnly = Items.IBUserName2.ReadOnly
			OR Not ActionsWithServiceUser.ChangeName;
			
		Items.Description.ReadOnly = Items.Description.ReadOnly 
			OR Not ActionsWithServiceUser.ChangeDescriptionFull;
			
		Items.CanLogOnToApplication.Enabled = Items.CanLogOnToApplication.Enabled
			AND ActionsWithServiceUser.ChangeAccess;
			
		Items.NotValid.Enabled = Items.NotValid.Enabled
			AND ActionsWithServiceUser.ChangeAccess;
			
		Form.PreventChangesToAdministrativeAccess =
			Not ActionsWithServiceUser.ChangeAdmininstrativeAccess;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function RequiredUserRecordIB(Form, ConsiderStandardName = True)
	
	If Form.ActionsInForm.InfobaseUserProperties <> "Edit" Then
		Return False;
	EndIf;
	
	Pattern = Form.InitialInfobaseUserDetails;
	
	CurrentName = "";
	If Not ConsiderStandardName Then
		ShortName = UsersServiceClientServer.GetShortNameOfIBUser(
			Form.Object.Description);
		
		If Form.IBUserName = ShortName Then
			CurrentName = ShortName;
		EndIf;
	EndIf;
	
	If Form.IBUserExists
	 OR Form.CanLogOnToApplication
	 OR Form.IBUserName                       <> CurrentName
	 OR Form.IBUserStandardAuthentication <> Pattern.StandardAuthentication
	 OR Form.IBUserShowInList   <> Pattern.ShowInList
	 OR Form.IBUserCannotChangePassword   <> Pattern.CannotChangePassword
	 OR Form.Password <> ""
	 OR Form.PasswordConfirmation <> ""
	 OR Form.IBUserOSAuthentication     <> Pattern.OSAuthentication
	 OR Form.IBUserOSUser       <> ""
	 OR Form.IBUserOpenIDAuthentication <> Pattern.OpenIDAuthentication
	 OR Form.IBUserRunMode         <> Pattern.RunMode
	 OR Form.IBUserLanguage                 <> Pattern.Language
	 OR Form.IBUserRoles.Count() <> 0 Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionSettings = New Structure;
	ActionSettings.Insert("MainParameter", MainParameter);
	ActionSettings.Insert("Form",            ThisObject);
	ActionSettings.Insert("CollectionOfRoles",   IBUserRoles);
	ActionSettings.Insert("PreventChangesToAdministrativeAccess",
		PreventChangesToAdministrativeAccess);
	
	UsersType = ?(CommonUseReUse.DataSeparationEnabled(),
		Enums.UserTypes.DataAreaUser,
		Enums.UserTypes.LocalApplicationUser);
	ActionSettings.Insert("UsersType", UsersType);
	
	AdministrativeAccessWasSet = IBUserRoles.FindRows(
		New Structure("Role", "FullRights")).Count() > 0;
	
	UsersService.ProcessRolesInterface(Action, ActionSettings);
	
	AdministrativeAccessIsSet = IBUserRoles.FindRows(
		New Structure("Role", "FullRights")).Count() > 0;
	
	If AdministrativeAccessIsSet <> AdministrativeAccessWasSet Then
		SetNecessitySynchronizationService(ThisObject);
	EndIf;
	
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
