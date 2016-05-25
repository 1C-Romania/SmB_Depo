
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Filling out auxiliary data.
	
	BanEditOfRoles = UsersService.BanEditOfRoles();
	
	// Filling in a language selection list.
	If Metadata.Languages.Count() < 2 Then
		Items.IBUserLanguage.Visible = False;
	Else
		For Each LanguageMetadata IN Metadata.Languages Do
			Items.IBUserLanguage.ChoiceList.Add(
				LanguageMetadata.Name, LanguageMetadata.Synonym);
		EndDo;
	EndIf;
	
	// Preparing for interactive actions considering scenarios of opening the form.
	AccessLevel = UsersService.AccessLevelToUserProperties(Object);
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		// Creating a new item.
		If Parameters.NewExternalUserGroup
		         <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			NewExternalUserGroup = Parameters.NewExternalUserGroup;
		EndIf;
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Copying an item.
			CopyingValue = Parameters.CopyingValue;
			Object.AuthorizationObject = Undefined;
			Object.Description      = "";
			Object.DeletePassword     = "";
			
			If Users.InfobaseUserWithFullAccess(CopyingValue, True, False) Then
				AllowedCopyIBUser = AccessLevel.SystemAdministrator;
			ElsIf Users.InfobaseUserWithFullAccess(CopyingValue, False, False) Then
				AllowedCopyIBUser = AccessLevel.FullRights;
			Else
				AllowedCopyIBUser = True;
			EndIf;
			
			If AllowedCopyIBUser Then
				ReadIBUser(ValueIsFilled(
					Parameters.CopyingValue.InfobaseUserID));
			Else
				ReadIBUser();
			EndIf;
			If Not AccessLevel.FullRights Then
				CanLogOnToApplication = False;
				CanLogOnToApplicationDirectChangeValue = False;
			EndIf;
		Else
			// Adding an item.
			If Parameters.Property("NewExternalUserAuthorizationObject") Then
				
				Object.AuthorizationObject = Parameters.NewExternalUserAuthorizationObject;
				IsAuthorizationObjectSetOnOpen = ValueIsFilled(Object.AuthorizationObject);
				AuthorizationObjectOnChangeAtClientAtServer(ThisObject, Object);
				
			ElsIf ValueIsFilled(NewExternalUserGroup) Then
				
				TypeOfAuthorizationObjects = CommonUse.ObjectAttributeValue(
					NewExternalUserGroup, "TypeOfAuthorizationObjects");
				
				Object.AuthorizationObject = TypeOfAuthorizationObjects;
				Items.AuthorizationObject.ChooseType = TypeOfAuthorizationObjects = Undefined;
			EndIf;
			
			// Read initial values of Infobase user properties.
			ReadIBUser();
			
			If Not ValueIsFilled(Parameters.InfobaseUserID) Then
				IBUserStandardAuthentication = True;
				
				If AccessLevel.FullRights Then
					CanLogOnToApplication = True;
					CanLogOnToApplicationDirectChangeValue = True;
				EndIf;
			EndIf;
		EndIf;
		
		If AccessLevel.FullRights
		   AND Object.AuthorizationObject <> Undefined Then
			
			IBUserName = UsersServiceClientServer.GetShortNameOfIBUser(
				CurrentAuthorizationObjectPresentation);
			
			IBUserFullName = Object.Description;
		EndIf;
	Else
		// Open an existing item.
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	ProcessRolesInterface("SetInterfaceOfRolesOnFormCreating", True);
	InitialInfobaseUserDetails = InitialInfobaseUserDetails();
	
	CommonSettingForms(True);
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemNameForPlacement", "AdditionalAttributesPage");
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	
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
	
	CommonSettingForms();
	
	CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
	
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
	
	// Setting constant property accessibility.
	Items.InfobaseUserProperties.Visible =
		ValueIsFilled(ActionsInForm.InfobaseUserProperties);
	
	Items.RoleRepresentation.Visible =
		ValueIsFilled(ActionsInForm.Roles);
	
	Items.SetRolesDirectly.Visible =
		ValueIsFilled(ActionsInForm.Roles) AND Not UsersService.BanEditOfRoles();
	
	RefreshDisplayTypeOfUser();
	
	ReadOnly = ReadOnly
		OR ActionsInForm.Roles                   <> "Edit"
		  AND ActionsInForm.ItemProperties       <> "Edit"
		  AND ActionsInForm.InfobaseUserProperties <> "Edit";
	
	Items.CheckSettingsAfterLogOnRecommendation.Visible =
		AccessLevel.FullRights AND Object.Prepared AND Not CanLogOnToApplicationOnRead;
	
	SetEnabledOfProperties();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	
	If ActionsInForm.Roles = "Edit"
	   AND Object.SetRolesDirectly
	   AND IBUserRoles.Count() = 0 Then
		
		If Not WriteParameters.Property("WithEmptyListOfRoles") Then
			Cancel = True;
			ShowQueryBox(
				New NotifyDescription("AfterAnswerToQuestionAboutRecordWithEmptyRoleList", ThisObject, WriteParameters),
				NStr("en = 'A role was not assigned to the Infobase user. Continue?'"),
				QuestionDialogMode.YesNo,
				,
				,
				NStr("en = 'Record of the infobase user'"));
			Return;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.AdditionalProperties.Insert("CopyingValue", CopyingValue);
	
	RefreshDisplayTypeOfUser();
	// Auto update external user description.
	SetPrivilegedMode(True);
	CurrentAuthorizationObjectPresentation = String(CurrentObject.AuthorizationObject);
	SetPrivilegedMode(False);
	Object.Description        = CurrentAuthorizationObjectPresentation;
	CurrentObject.Description = CurrentAuthorizationObjectPresentation;
	
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
			CurrentObject.Ref, "DeletionMark"));
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert(
		"NewExternalUserGroup", NewExternalUserGroup);
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If RequiredUserRecordIB(ThisObject) Then
		WriteParameters.Insert(
			CurrentObject.AdditionalProperties.IBUserDescription.ActionResult);
	EndIf;
	
	CommonSettingForms(, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExternalUsers", New Structure, Object.Ref);
	
	If WriteParameters.Property("InfobaseUserAdded") Then
		Notify("InfobaseUserAdded", WriteParameters.InfobaseUserAdded, ThisObject);
		
	ElsIf WriteParameters.Property("InfobaseUserChanged") Then
		Notify("InfobaseUserChanged", WriteParameters.InfobaseUserChanged, ThisObject);
		
	ElsIf WriteParameters.Property("InfobaseUserDeleted") Then
		Notify("InfobaseUserDeleted", WriteParameters.InfobaseUserDeleted, ThisObject);
		
	ElsIf WriteParameters.Property("MatchToNonExistentIBUserCleared") Then
		
		Notify(
			"MatchToNonExistentIBUserCleared",
			WriteParameters.MatchToNonExistentIBUserCleared, ThisObject);
	EndIf;
	
	If ValueIsFilled(NewExternalUserGroup) Then
		NotifyChanged(NewExternalUserGroup);
		
		Notify(
			"Write_ExternalUsersGroups",
			New Structure,
			NewExternalUserGroup);
		
		NewExternalUserGroup = Undefined;
	EndIf;
	
	SetEnabledOfProperties();
	
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ErrorText = "";
	If UsersService.AuthorizationObjectInUse(
	         Object.AuthorizationObject, Object.Ref, , , ErrorText) Then
		
		CommonUseClientServer.MessageToUser(
			ErrorText, , "Object.AuthorizationObject", , Cancel);
	EndIf;
	
	If RequiredUserRecordIB(ThisObject) Then
		IBUserDescription = IBUserDescription();
		IBUserDescription.Insert("InfobaseUserID", Object.InfobaseUserID);
		UsersService.CheckIBUserFullName(IBUserDescription, Cancel);
		
		MessageText = "";
		If UsersService.NeedToCreateFirstAdministrator(, MessageText) Then
			CommonUseClientServer.MessageToUser(
				MessageText, , "CanLogOnToApplication", , Cancel);
		EndIf;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonUse.CommonModule("PropertiesManagement");
		PropertiesManagementModule.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("TuneRolesInterfaceOnSettingsImporting", Settings);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure AuthorizationObjectOnChange(Item)
	
	AuthorizationObjectOnChangeAtClientAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure NotValidOnChange(Item)
	
	If Object.NotValid Then
		CanLogOnToApplication = False;
	Else
		CanLogOnToApplication = CanLogOnToApplicationDirectChangeValue
			AND (IBUserOpenIDAuthentication
			   Or IBUserStandardAuthentication);
	EndIf;
	
	SetEnabledOfProperties();
	
EndProcedure

&AtClient
Procedure CanLogOnToApplicationOnChange(Item)
	
	If Object.DeletionMark AND CanLogOnToApplication Then
		CanLogOnToApplication = False;
		ShowMessageBox(,
			NStr("en = 'To allow logging on, clear
			           |the deletion mark for the external user.'"));
		Return;
	EndIf;
	
	RefreshNameForEntering(ThisObject);
	
	If CanLogOnToApplication
	   AND Not IBUserOpenIDAuthentication
	   AND Not IBUserStandardAuthentication Then
	
		IBUserStandardAuthentication = True;
	EndIf;
	
	SetEnabledOfProperties();
	
	If Not AccessLevel.FullRights
	   AND AccessLevel.ListManagement
	   AND Not CanLogOnToApplication Then
		
		ShowMessageBox(,
			NStr("en = 'After saving, only administrator can allow to log on.'"));
	EndIf;
	
	CanLogOnToApplicationDirectChangeValue = CanLogOnToApplication;
	
EndProcedure

&AtClient
Procedure IBUserNameOnChange(Item)
	
	SetEnabledOfProperties();
	
EndProcedure

&AtClient
Procedure IBUserStandardAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	SetEnabledOfProperties();
	
	IBUserPassword = Password;
	
EndProcedure

&AtClient
Procedure IBUserCannotChangePasswordOnChange(Item)
	
	SetEnabledOfProperties();
	
EndProcedure

&AtClient
Procedure IBUserOpenIDAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure SetRolesDirectlyOnChange(Item)
	
	If Not Object.SetRolesDirectly Then
		ReadIBUserRoles();
		UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	EndIf;
	
	SetEnabledOfProperties();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersRoles

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("RefreshContentOfRoles");
	EndIf;
	
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

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure RefreshNameForEntering(Form, OnNameChange = False)
	
	Items = Form.Items;
	Object   = Form.Object;
	
	If Form.IBUserExists Then
		Return;
	EndIf;
	
	ShortName = UsersServiceClientServer.GetShortNameOfIBUser(
		Form.CurrentAuthorizationObjectPresentation);
	
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
	
	SetEnabledOfProperties();
	
	If Not IBUserOpenIDAuthentication
	   AND Not IBUserStandardAuthentication Then
	
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
	ActionsInForm.Insert("InfobaseUserProperties", "");
	
	// "", "View", "Edit".
	ActionsInForm.Insert("ItemProperties", "view");
	
	If AccessLevel.ChangeCurrent Or AccessLevel.ListManagement Then
		ActionsInForm.InfobaseUserProperties = "Edit";
	EndIf;
	
	If AccessLevel.ListManagement Then
		ActionsInForm.ItemProperties = "Edit";
	EndIf;
	
	If AccessLevel.FullRights Then
		ActionsInForm.Roles = "Edit";
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Object.AuthorizationObject) Then
		
		ActionsInForm.ItemProperties = "Edit";
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
	
EndProcedure

&AtServer
Function IBUserDescription()
	
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
			Result.Insert("CannotChangePassword", IBUserCannotChangePassword);
			Result.Insert("Language",                    IBUserLanguage);
			Result.Insert("FullName",               IBUserFullName);
		EndIf;
		
		If AccessLevel.SettingsForLogin Then
			Result.Insert("StandardAuthentication", IBUserStandardAuthentication);
			Result.Insert("Name",                       IBUserName);
			Result.Insert("Password",                    IBUserPassword);
			Result.Insert("OpenIDAuthentication",      IBUserOpenIDAuthentication);
		EndIf;
	EndIf;
	Result.Insert("PasswordConfirmation", PasswordConfirmation);
	
	If AccessLevel.SettingsForLogin
	   AND Not UsersService.BanEditOfRoles()
	   AND Object.SetRolesDirectly Then
		
		CurrentRoles = IBUserRoles.Unload(, "Role").UnloadColumn("Role");
		Result.Insert("Roles", CurrentRoles);
	EndIf;
	
	If AccessLevel.ListManagement Then
		Result.Insert("ShowInList", False);
		Result.Insert("RunMode", "Auto");
	EndIf;
	
	If AccessLevel.FullRights Then
		Result.Insert("OSAuthentication", False);
		Result.Insert("OSUser", "");
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Procedure AuthorizationObjectOnChangeAtClientAtServer(Form, Object)
	
	If Object.AuthorizationObject = Undefined Then
		Object.AuthorizationObject = Form.TypeOfAuthorizationObjects;
	EndIf;
	
	If Form.CurrentAuthorizationObjectPresentation <> String(Object.AuthorizationObject) Then
		Form.CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
		RefreshNameForEntering(Form, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshDisplayTypeOfUser()
	
	If Object.AuthorizationObject <> Undefined Then
		Items.AuthorizationObject.Title = Metadata.FindByType(TypeOf(Object.AuthorizationObject)).ObjectPresentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutRecordWithEmptyRoleList(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("WithEmptyListOfRoles");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

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
Procedure ReadIBUserRoles()
	
	InfobaseUserProperties = Undefined;
	
	Users.ReadIBUser(
		Object.InfobaseUserID, InfobaseUserProperties);
	
	ProcessRolesInterface("FillRoles", InfobaseUserProperties.Roles);
	
EndProcedure

&AtServer
Function InitialInfobaseUserDetails()
	
	IBUserDescription = Users.NewInfobaseUserInfo();
	
	If Not ValueIsFilled(Object.Ref) Then
		IBUserDescription.ShowInList = False;
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
					ReadProperties.FullName = Object.Description;
					Modified = True;
				EndIf;
				If ReadProperties.OSAuthentication Then
					ReadProperties.OSAuthentication = False;
					Modified = True;
				EndIf;
				If ValueIsFilled(ReadProperties.OSUser) Then
					ReadProperties.OSUser = "";
					Modified = True;
				EndIf;
			EndIf;
		EndIf;
		
		If IBUserExists Then
			
			If Not Items.IBUserLanguage.Visible Then
				ReadProperties.Language = IBUserDescription.Language;
			EndIf;
			
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
				|RunMode,
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
	EndIf;
	
	ProcessRolesInterface("FillRoles", IBUserDescription.Roles);
	
	CanLogOnToApplicationOnRead = CanLogOnToApplication;
	
EndProcedure

&AtServer
Procedure DefineUserInconsistenciesWithUserIB(WriteParameters = Undefined)
	
	// Check match between the "FullName"
	// Infobase user property and the "External user description" attribute. Also default property values are compared.
	
	ShowMismatch = True;
	ShowCommandsDifferences = False;
	
	If Not IBUserExists Then
		ShowMismatch = False;
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		IBUserFullName = Object.Description;
		ShowMismatch = False;
		
	ElsIf AccessLevel.ListManagement Then
		
		PropertiesAdjustment = New Array;
		FoundDifferencesCanBeResolvedWithoutAdministrator = False;
		
		If IBUserOSAuthentication <> False Then
			PropertiesAdjustment.Add(NStr("en = 'OS authentication (enabled)'"));
		EndIf;
		
		If ValueIsFilled(PropertiesAdjustment) Then
			ShowCommandsDifferences =
				  AccessLevel.SettingsForLogin
				AND ActionsInForm.InfobaseUserProperties = "Edit";
		EndIf;
		
		If IBUserFullName <> Object.Description Then
			FoundDifferencesCanBeResolvedWithoutAdministrator = True;
			
			RefineFullName = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Full name ""%1""'"), IBUserFullName);
			
			PropertiesAdjustment.Insert(0, StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Full name ""%1""'"), IBUserFullName));
		EndIf;
		
		If IBUserOSUser <> "" Then
			PropertiesAdjustment.Add(NStr("en = 'OS user (specified)'"));
		EndIf;
		
		If IBUserShowInList Then
			FoundDifferencesCanBeResolvedWithoutAdministrator = True;
			PropertiesAdjustment.Add(NStr("en = 'Show in choice list (enabled)'"));
		EndIf;
		
		If IBUserRunMode <> "Auto" Then
			FoundDifferencesCanBeResolvedWithoutAdministrator = True;
			PropertiesAdjustment.Add(NStr("en = 'Launch mode (not Auto)'"));
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
					NStr("en = 'The following infobase user properties differ from those specified
					           |in this form: %1.'"), StringPropertyClarification)
				+ Chars.LF
				+ ?(ShowCommandsDifferences Or FoundDifferencesCanBeResolvedWithoutAdministrator,
					NStr("en = 'Click ""Write"" to resolve the differences and not to show this warning message.'"),
					NStr("en = 'To resolve the differences, contact your administrator.'"));
		Else
			ShowMismatch = False;
		EndIf;
	Else
		ShowMismatch = False;
	EndIf;
	
	Items.PropertiesMismatchProcessing.Visible = ShowMismatch;
	
	// Check if a non-existent Infobase user is associated with a catalog user.
	NewMappingWithNonExistentInfobaseUser =
		Not IBUserExists AND ValueIsFilled(Object.InfobaseUserID);
	
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

////////////////////////////////////////////////////////////////////////////////
// Initial filling, check for filling, properties availability.

&AtServer
Procedure SetEnabledOfProperties()
	
	// Setting change possibility.
	Items.AuthorizationObject.ReadOnly
		=   ActionsInForm.ItemProperties <> "Edit"
		OR IsAuthorizationObjectSetOnOpen
		OR   ValueIsFilled(Object.Ref)
		    AND ValueIsFilled(Object.AuthorizationObject);
	
	Items.NotValid.ReadOnly =
		Not (ActionsInForm.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
	Items.MainProperties.ReadOnly =
		Not (  ActionsInForm.InfobaseUserProperties = "Edit"
		    AND (AccessLevel.ListManagement Or AccessLevel.ChangeCurrent));
	
	Items.CanLogOnToApplication.ReadOnly =
		Not (  Items.MainProperties.ReadOnly = False
		    AND (    AccessLevel.FullRights
		       Or AccessLevel.ListManagement AND CanLogOnToApplicationOnRead));
	
	Items.IBUserName1.ReadOnly                      = Not AccessLevel.SettingsForLogin;
	Items.IBUserName2.ReadOnly                      = Not AccessLevel.SettingsForLogin;
	Items.IBUserStandardAuthentication.ReadOnly = Not AccessLevel.SettingsForLogin;
	Items.IBUserOpenIDAuthentication.ReadOnly      = Not AccessLevel.SettingsForLogin;
	Items.SetRolesDirectly.ReadOnly           = Not AccessLevel.SettingsForLogin;
	
	Items.IBUserCannotChangePassword.ReadOnly = Not AccessLevel.ListManagement;
	
	Items.Password.ReadOnly =
		Not (    AccessLevel.SettingsForLogin
		    Or AccessLevel.ChangeCurrent
		      AND Not IBUserCannotChangePassword);
	
	Items.PasswordConfirmation.ReadOnly = Items.Password.ReadOnly;
	
	ProcessRolesInterface(
		"SetReadOnlyOfRoles",
		    BanEditOfRoles
		Or ActionsInForm.Roles <> "Edit"
		Or Not Object.SetRolesDirectly
		Or Not AccessLevel.SettingsForLogin);
	
	Items.Comment.ReadOnly =
		Not (ActionsInForm.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
	// Setting of required filling.
	If RequiredUserRecordIB(ThisObject, False) Then
		NewPage = Items.NameWithMarkIncomplete;
	Else
		NewPage = Items.NameWithoutMarkIncomplete;
	EndIf;
	
	If Items.NameMarkIncompleteSwitch.CurrentPage <> NewPage Then
		Items.NameMarkIncompleteSwitch.CurrentPage = NewPage;
	EndIf;
	RefreshNameForEntering(ThisObject);
	
	// Setting of associated items availability.
	Items.CanLogOnToApplication.Enabled         = Not Object.NotValid;
	Items.MainProperties.Enabled               = Not Object.NotValid;
	Items.EditOrViewRoles.Enabled = Not Object.NotValid;
	
	Items.Password.Enabled              = IBUserStandardAuthentication;
	Items.PasswordConfirmation.Enabled = IBUserStandardAuthentication;
	
	Items.IBUserCannotChangePassword.Enabled
		= IBUserStandardAuthentication;
	
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
			Form.CurrentAuthorizationObjectPresentation);
		
		If Form.IBUserName = ShortName Then
			CurrentName = ShortName;
		EndIf;
	EndIf;
	
	If Form.IBUserExists
	 OR Form.CanLogOnToApplication
	 OR Form.IBUserName                       <> CurrentName
	 OR Form.IBUserStandardAuthentication <> Pattern.StandardAuthentication
	 OR Form.IBUserCannotChangePassword   <> Pattern.CannotChangePassword
	 OR Form.Password <> ""
	 OR Form.PasswordConfirmation <> ""
	 OR Form.IBUserOpenIDAuthentication <> Pattern.OpenIDAuthentication
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
	ActionSettings.Insert("MainParameter",      MainParameter);
	ActionSettings.Insert("Form",                 ThisObject);
	ActionSettings.Insert("CollectionOfRoles",        IBUserRoles);
	ActionSettings.Insert("UsersType",      Enums.UserTypes.ExternalUser);
	ActionSettings.Insert("HideFullAccessRole", True);
	
	UsersService.ProcessRolesInterface(Action, ActionSettings);
	
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
