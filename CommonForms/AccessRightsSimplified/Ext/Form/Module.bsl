
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.User) Then
		Cancel = True;
		Return;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess() Then
		// View and edit of profile structure and access limits.
		FilterProfilesOnlyCurrentUser = False;
		
	ElsIf Parameters.User = Users.AuthorizedUser() Then
		// View of their profiles and report about access rights.
		FilterProfilesOnlyCurrentUser = True;
		// Hiding of spare information.
		Items.Profiles.ReadOnly = True;
		Items.ProfilesCheck.Visible = False;
		Items.Access.Visible = False;
		Items.FormWrite.Visible = False;
	Else
		Items.FormWrite.Visible = False;
		Items.FormReportAccessRights.Visible = False;
		Items.RightsAndRestrictions.Visible = False;
		Items.NotEnoughRightsToView.Visible = True;
		Return;
	EndIf;
	
	If TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		Items.Profiles.Title = NStr("en = 'External user profiles'");
	Else
		Items.Profiles.Title = NStr("en = 'User profiles'");
	EndIf;
	
	ImportData(FilterProfilesOnlyCurrentUser);
	
	// Supportive data preparation.
	AccessManagementService.OnCreateAtServerAllowedValuesEditingForms(ThisObject, , "");
	
	For Each ProfileProperties IN Profiles Do
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementServiceClientServer.FillAccessKindsPropertiesInForm(ThisObject);
	EndDo;
	CurrentAccessGroup = "";
	
	ProfileAdministrator = Catalogs.AccessGroupsProfiles.Administrator;
	
	// Necessity definition of access limit setting.
	If Not AccessManagement.LimitAccessOnRecordsLevel() Then
		Items.Access.Visible = False;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		ActionsWithServiceUser = Undefined;
		AccessManagementService.WhenUserActionService(
			ActionsWithServiceUser, Parameters.User);
		PreventChangesToAdministrativeAccess = Not ActionsWithServiceUser.ChangeAdmininstrativeAccess;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// Check of unfilled and repetitive access values.
	Errors = Undefined;
	
	For Each ProfileProperties IN Profiles Do
		
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementServiceClientServer.AllowedValuesEditFormFillCheckProcessingAtServerProcessor(
			ThisObject, Cancel, New Array, Errors);
		
		If Cancel Then
			Break;
		EndIf;
		
	EndDo;
	
	If Cancel Then
		CurrentLineAccessKinds = Items.AccessKinds.CurrentRow;
		CurrentRowAccessValuesOnError = Items.AccessValues.CurrentRow;
		
		Items.Profiles.CurrentRow = ProfileProperties.GetID();
		OnChangeCurrentProfile(ThisObject);
		
		Items.AccessKinds.CurrentRow = CurrentLineAccessKinds;
		AccessManagementServiceClientServer.OnChangeCurrentAccessKind(ThisObject);
		
		CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	Else
		CurrentAccessGroup = CurrentProfile;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrentAccessValueStringThroughError()
	
	If CurrentRowAccessValuesOnError <> Undefined Then
		Items.AccessValues.CurrentRow = CurrentRowAccessValuesOnError;
		CurrentRowAccessValuesOnError = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersProfiles

&AtClient
Procedure ProfilesOnActivateRow(Item)
	
	OnChangeCurrentProfile(ThisObject);
	
EndProcedure

&AtClient
Procedure ProfilesCheckOnChange(Item)
	
	Cancel = False;
	CurrentData = Items.Profiles.CurrentData;
	
	If CurrentData <> Undefined
	   AND Not CurrentData.Check Then
		// Check of unfilled and repetitive
		// access values before disconnecting of profile and setting availability.
		ClearMessages();
		Errors = Undefined;
		AccessManagementServiceClientServer.AllowedValuesEditFormFillCheckProcessingAtServerProcessor(
			ThisObject, Cancel, New Array, Errors);
		CurrentRowAccessValuesOnError = Items.AccessValues.CurrentRow;
		CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
		AttachIdleHandler("SetCurrentAccessValueStringThroughError", True, 0.1);
	EndIf;
	
	If Cancel Then
		CurrentData.Check = True;
	Else
		OnChangeCurrentProfile(ThisObject);
	EndIf;
	
	If CurrentData <> Undefined
		AND CurrentData.Profile = PredefinedValue("Catalog.AccessGroupsProfiles.Administrator") Then
		
		NeededSynchronizationWithService = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersAccessKinds

&AtClient
Procedure AccessKindSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If EditingCurrentLimitations Then
		Items.AccessKinds.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementServiceClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateCell(Item)
	
	AccessManagementServiceClient.AccessKindsOnActivateCell(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnStartEdit(Item, NewRow, Copy)
	
	AccessManagementServiceClient.AccessKindsOnStartEdit(
		ThisObject, Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure AccessKindsOnEditEnd(Item, NewRow, CancelEdit)
	
	AccessManagementServiceClient.AccessKindsOnEditEnd(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of form table item AllAllowedPresentation AccessKinds.

&AtClient
Procedure AccessKindsAllAllowedPresentationOnChange(Item)
	
	AccessManagementServiceClient.AccessKindsAllAllowedPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementServiceClient.AccessKindsAllAllowedPresentationChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersAccessValues

&AtClient
Procedure AccessValuesOnChange(Item)
	
	AccessManagementServiceClient.AccessValuesOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessValuesOnStartEdit(Item, NewRow, Copy)
	
	AccessManagementServiceClient.AccessValuesOnStartEdit(
		ThisObject, Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure AccessValuesOnEditEnd(Item, NewRow, CancelEdit)
	
	AccessManagementServiceClient.AccessValuesOnEditEnd(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

&AtClient
Procedure AccessValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueStartChoice(
		ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueClearing(Item, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueClearing(
		ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueAutoComplete(
		ThisObject, Item, Text, ChoiceData, Wait, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueTextEditEnd(
		ThisObject, Item, Text, ChoiceData, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Write(Command)
	
	WriteChanges();
	
EndProcedure

&AtClient
Procedure ReportAboutAccessRights(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("User", Parameters.User);
	
	OpenForm("Report.AccessRights.Form", FormParameters);
	
EndProcedure

&AtClient
Procedure ShowUnusedAccessKinds(Command)
	
	ShowUnusedAccessKindsAtServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("PreventChangesToAdministrativeAccess");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Profiles.Profile");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Catalogs.AccessGroupsProfiles.Administrator;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesProfilePresentation.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("PreventChangesToAdministrativeAccess");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Profiles.Profile");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Catalogs.AccessGroupsProfiles.Administrator;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleDataColor);

EndProcedure

// Continuation of event handler BeforeClose.
&AtClient
Procedure WriteAndCloseNotification(Result, NotSpecified) Export
	
	WriteChanges(New NotifyDescription("WriteAndCloseEnd", ThisObject));
	
EndProcedure

// Continuation of event handler BeforeClose.
&AtClient
Procedure WriteAndCloseEnd(Cancel, NotSpecified) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure WriteChanges(ContinuationProcessor = Undefined)
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled
	   AND NeededSynchronizationWithService Then
		
		StandardSubsystemsClient.WhenPromptedForPasswordForAuthenticationToService(
			New NotifyDescription("WriteChangesEnd", ThisObject, ContinuationProcessor),
			ThisObject,
			ServiceUserPassword);
	Else
		WriteChangesEnd("", ContinuationProcessor);
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteChangesEnd(NewServiceUserPassword, ContinuationProcessor) Export
	
	If NewServiceUserPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = NewServiceUserPassword;
	
	ClearMessages();
	
	Cancel = False;
	WriteChangesAtServer(Cancel);
	
	AttachIdleHandler("SetCurrentAccessValueStringThroughError", True, 0.1);
	
	If ContinuationProcessor = Undefined Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(ContinuationProcessor, Cancel);
	
EndProcedure

&AtServer
Procedure ShowUnusedAccessKindsAtServer()
	
	AccessManagementService.RefreshUnusedAccessKindsDisplay(ThisObject);
	
EndProcedure

&AtServer
Procedure ImportData(FilterProfilesOnlyCurrentUser)
	
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	Query.SetParameter("FilterProfilesOnlyCurrentUser",
	                           FilterProfilesOnlyCurrentUser);
	Query.SetParameter("ProfileIDDocumentsPricesEdit", New UUID("76337579-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDProductsAndServicesEdit" , New UUID("76337580-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDReturnsFromCustomers" 	   , New UUID("76337581-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDReturnsToSuppliers" 	   , New UUID("76337582-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDDataSynchronization" 	   , New UUID("04937803-5dba-11df-a1d4-005056c00008"));
	
	Query.Text =
	"SELECT DISTINCT
	|	Profiles.Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroupsUsers.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO Profiles
	|FROM
	|	Catalog.AccessGroupsProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (AccessGroups.User = &User
	|				OR Profiles.Ref IN (VALUE(Catalog.AccessGroupsProfiles.Administrator)))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (AccessGroups.Ref = AccessGroupsUsers.Ref)
	|			AND (AccessGroupsUsers.User = &User)
	|WHERE
	|	Not Profiles.DeletionMark
	|	AND Not(&FilterProfilesOnlyCurrentUser = TRUE
	|				AND AccessGroupsUsers.Ref IS NULL )
	|	AND Not Profiles.IDSuppliedData = &ProfileIDDocumentsPricesEdit
	|	AND Not Profiles.IDSuppliedData = &ProfileIDProductsAndServicesEdit
	|	AND Not Profiles.IDSuppliedData = &ProfileIDReturnsFromCustomers
	|	AND Not Profiles.IDSuppliedData = &ProfileIDReturnsToSuppliers
	|	AND Not Profiles.IDSuppliedData = &ProfileIDDataSynchronization
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	Profiles.Ref.Description AS ProfilePresentation,
	|	Profiles.Check,
	|	Profiles.PersonalAccessGroup AS AccessGroup,
	|	"""" AS ProfileLongDesc,
	|	CASE
	|		WHEN Profiles.Ref.Description = ""Sales""
	|			THEN 100
	|		WHEN Profiles.Ref.Description = ""Purchases""
	|			THEN 99
	|		WHEN Profiles.Ref.Description = ""Production""
	|			THEN 98
	|		WHEN Profiles.Ref.Description = ""Funds""
	|			THEN 97
	|		WHEN Profiles.Ref.Description = ""Salary""
	|			THEN 96
	|		WHEN Profiles.Ref.Description = ""Administrator""
	|			THEN 95
	|		ELSE 0
	|	END AS Priority
	|FROM
	|	Profiles AS Profiles
	|
	|ORDER BY
	|	Priority DESC,
	|	ProfilePresentation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds.AccessKind,
	|	ISNULL(AccessGroupsAccessKinds.AllAllowed, ProfilesAccessKinds.AllAllowed) AS AllAllowed,
	|	"""" AS AccessKindPresentation,
	|	"""" AS AllAllowedPresentation
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON Profiles.Ref = ProfilesAccessKinds.Ref
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessKinds.Ref
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|WHERE
	|	Not ProfilesAccessKinds.Preset
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds.AccessKind,
	|	0 AS LineNumberByKind,
	|	AccessGroupsAccessValues.AccessValue
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON Profiles.Ref = ProfilesAccessKinds.Ref
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessValues.AccessKind)
	|WHERE
	|	Not ProfilesAccessKinds.Preset";
	
	SetPrivilegedMode(True);
	ResultsOfQuery = Query.ExecuteBatch();
	SetPrivilegedMode(False);
	
	ValueToFormAttribute(ResultsOfQuery[1].Unload(), "Profiles");
	ValueToFormAttribute(ResultsOfQuery[2].Unload(), "AccessKinds");
	ValueToFormAttribute(ResultsOfQuery[3].Unload(), "AccessValues");
	
	// SB
	AllowEditPricesInDocuments = AllowEditPricesInDocuments(Parameters.User);
	AllowEditProductsAndServices   = AllowEditProductsAndServices(Parameters.User);
			
	SetPrivilegedMode(True);
	For Each ProfileProperties IN Profiles Do
		
		ProfileProperties.ProfileLongDesc = Catalogs.AccessGroupsProfiles.StandardProfileDescription(ProfileProperties.Profile);
		
	EndDo;
	SetPrivilegedMode(False);
	// SB End
	
EndProcedure

&AtServer
Procedure WriteChangesAtServer(Cancel)
	
	If Not CheckFilling() Then
		Cancel = True;
		Return;
	EndIf;
	
	Users.FindAmbiguousInfobaseUsers(,);
	
	SelectedProfiles = Profiles.Unload(, "Profile, Check");
	
	// SB
	AddAdditionalProfiles(SelectedProfiles);
	// SB End
	
	// Receiving change list.
	Query = New Query;
	
	Query.SetParameter("User", Parameters.User);
	
	Query.SetParameter(
		"Profiles", SelectedProfiles);
	
	Query.SetParameter(
		"AccessKinds", AccessKinds.Unload(, "AccessGroup, AccessKind, AllAllowed"));
	
	Query.SetParameter(
		"AccessValues", AccessValues.Unload(, "AccessGroup, AccessKind, AccessValue"));
	
	Query.Text =
	"SELECT
	|	Profiles.Profile AS Ref,
	|	Profiles.Check
	|INTO Profiles
	|FROM
	|	&Profiles AS Profiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKinds.AccessGroup AS Profile,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|INTO AccessKinds
	|FROM
	|	&AccessKinds AS AccessKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessValues.AccessGroup AS Profile,
	|	AccessValues.AccessKind,
	|	AccessValues.AccessValue
	|INTO AccessValues
	|FROM
	|	&AccessValues AS AccessValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Profiles.Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroupsUsers.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO CurrentProfiles
	|FROM
	|	Catalog.AccessGroupsProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (AccessGroups.User = &User
	|				OR Profiles.Ref IN (VALUE(Catalog.AccessGroupsProfiles.Administrator)))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (AccessGroups.Ref = AccessGroupsUsers.Ref)
	|			AND (AccessGroupsUsers.User = &User)
	|WHERE
	|	Not Profiles.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsAccessKinds.AccessKind,
	|	AccessGroupsAccessKinds.AllAllowed
	|INTO CurrentAccessKinds
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessKinds.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsAccessValues.AccessKind,
	|	AccessGroupsAccessValues.AccessValue
	|INTO CurrentAccessValues
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfilesOfChangedGroups.Profile
	|INTO ProfilesOfChangedGroups
	|FROM
	|	(SELECT
	|		Profiles.Ref AS Profile
	|	FROM
	|		Profiles AS Profiles
	|			INNER JOIN CurrentProfiles AS CurrentProfiles
	|			ON Profiles.Ref = CurrentProfiles.Ref
	|	WHERE
	|		Profiles.Check <> CurrentProfiles.Check
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessKinds.Profile
	|	FROM
	|		AccessKinds AS AccessKinds
	|			LEFT JOIN CurrentAccessKinds AS CurrentAccessKinds
	|			ON AccessKinds.Profile = CurrentAccessKinds.Profile
	|				AND AccessKinds.AccessKind = CurrentAccessKinds.AccessKind
	|				AND AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed
	|	WHERE
	|		CurrentAccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessKinds.Profile
	|	FROM
	|		CurrentAccessKinds AS CurrentAccessKinds
	|			LEFT JOIN AccessKinds AS AccessKinds
	|			ON (AccessKinds.Profile = CurrentAccessKinds.Profile)
	|				AND (AccessKinds.AccessKind = CurrentAccessKinds.AccessKind)
	|				AND (AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed)
	|	WHERE
	|		AccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValues.Profile
	|	FROM
	|		AccessValues AS AccessValues
	|			LEFT JOIN CurrentAccessValues AS CurrentAccessValues
	|			ON AccessValues.Profile = CurrentAccessValues.Profile
	|				AND AccessValues.AccessKind = CurrentAccessValues.AccessKind
	|				AND AccessValues.AccessValue = CurrentAccessValues.AccessValue
	|	WHERE
	|		CurrentAccessValues.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessValues.Profile
	|	FROM
	|		CurrentAccessValues AS CurrentAccessValues
	|			LEFT JOIN AccessValues AS AccessValues
	|			ON (AccessValues.Profile = CurrentAccessValues.Profile)
	|				AND (AccessValues.AccessKind = CurrentAccessValues.AccessKind)
	|				AND (AccessValues.AccessValue = CurrentAccessValues.AccessValue)
	|	WHERE
	|		AccessValues.AccessKind IS NULL ) AS ProfilesOfChangedGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	CatalogProfiles.Description AS ProfileDescription,
	|	Profiles.Check,
	|	CurrentProfiles.PersonalAccessGroup
	|FROM
	|	ProfilesOfChangedGroups AS ProfilesOfChangedGroups
	|		INNER JOIN Profiles AS Profiles
	|		ON ProfilesOfChangedGroups.Profile = Profiles.Ref
	|		INNER JOIN CurrentProfiles AS CurrentProfiles
	|		ON ProfilesOfChangedGroups.Profile = CurrentProfiles.Ref
	|		INNER JOIN Catalog.AccessGroupsProfiles AS CatalogProfiles
	|		ON (CatalogProfiles.Ref = ProfilesOfChangedGroups.Profile)";
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			If ValueIsFilled(Selection.PersonalAccessGroup) Then
				LockDataForEdit(Selection.PersonalAccessGroup);
				AccessGroupObject = Selection.PersonalAccessGroup.GetObject();
			Else
				// Creating of personal access group.
				AccessGroupObject = Catalogs.AccessGroups.CreateItem();
				AccessGroupObject.Parent     = Catalogs.AccessGroups.ParentOfPersonalAccessGroups();
				AccessGroupObject.Description = Selection.ProfileDescription;
				AccessGroupObject.User = Parameters.User;
				AccessGroupObject.Profile      = Selection.Profile;
			EndIf;
			
			If Selection.Profile = Catalogs.AccessGroupsProfiles.Administrator Then
				
				If NeededSynchronizationWithService Then
					AccessGroupObject.AdditionalProperties.Insert("ServiceUserPassword", ServiceUserPassword);
				EndIf;
				
				If Selection.Check Then
					If AccessGroupObject.Users.Find(
							Parameters.User, "User") = Undefined Then
						
						AccessGroupObject.Users.Add().User = Parameters.User;
					EndIf;
				Else
					UserDetails =  AccessGroupObject.Users.Find(
						Parameters.User, "User");
					
					If UserDetails <> Undefined Then
						AccessGroupObject.Users.Delete(UserDetails);
						
						If Not CommonUseReUse.DataSeparationEnabled() Then
							// Checking empty list of IB users in access group of Administrators.
							ErrorDescription = "";
							AccessManagementService.CheckEnabledOfUserAccessAdministratorsGroupIB(
								AccessGroupObject.Users, ErrorDescription);
							
							If ValueIsFilled(ErrorDescription) Then
								Raise
									NStr("en = 'At least one user must have the Administrator profile
									           |to log on to the application.'");
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			ElsIf Selection.Profile.IDSuppliedData = New UUID("76337581-bff4-11df-9174-e0cb4ed5f4c3") Then // SB - ReturnsFromCustomers
				
				AccessGroupObject.Users.Clear();
				If Selection.Check Then
					AccessGroupObject.Users.Add().User = Parameters.User;
				EndIf;
				
				IDSuppliedData = New UUID("76337576-bff4-11df-9174-e0cb4ed5f4c3");
				SaleProfile = Catalogs.AccessGroupsProfiles.FindByAttribute("IDSuppliedData", IDSuppliedData);
				
				Filter = New Structure("AccessGroup, AccessKind", SaleProfile, Catalogs.Counterparties.EmptyRef());
				
				AccessGroupObject.AccessKinds.Load(
					AccessKinds.Unload(Filter, "AccessKind, AllAllowed"));
				
				AccessGroupObject.AccessValues.Load(
					AccessValues.Unload(Filter, "AccessKind, AccessValue"));
			Else
				AccessGroupObject.Users.Clear();
				If Selection.Check Then
					AccessGroupObject.Users.Add().User = Parameters.User;
				EndIf;
				
				Filter = New Structure("AccessGroup", Selection.Profile);
				
				AccessGroupObject.AccessKinds.Load(
					AccessKinds.Unload(Filter, "AccessKind, AllAllowed"));
				
				AccessGroupObject.AccessValues.Load(
					AccessValues.Unload(Filter, "AccessKind, AccessValue"));
			EndIf;
			
			Try
				AccessGroupObject.Write();
			Except
				ServiceUserPassword = Undefined;
				Raise;
			EndTry;
			
			If ValueIsFilled(Selection.PersonalAccessGroup) Then
				UnlockDataForEdit(Selection.PersonalAccessGroup);
			EndIf;
			
		EndDo;
		CommitTransaction();
		Modified = False;
		NeededSynchronizationWithService = False;
	Except
		RollbackTransaction();
		CommonUseClientServer.MessageToUser(
			BriefErrorDescription(ErrorInfo()), , , , Cancel);
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Procedure OnChangeCurrentProfile(Val Form)
	
	Items    = Form.Items;
	Profiles     = Form.Profiles;
	AccessKinds = Form.AccessKinds;
	
	#If Client Then
		CurrentData = Items.Profiles.CurrentData;
	#Else
		CurrentData = Profiles.FindByID(?(Items.Profiles.CurrentRow = Undefined, -1, Items.Profiles.CurrentRow));
	#EndIf
	
	Form.CurrentProfile = Undefined;
	EditingCurrentLimitations = False;
	
	If CurrentData <> Undefined Then
		Form.CurrentProfile = CurrentData.Profile;
		EditingCurrentLimitations = CurrentData.Check
		                                   AND Form.CurrentProfile <> Form.ProfileAdministrator
		                                   AND Not Form.ReadOnly;
	EndIf;
	
	// SB
	If CurrentData <> Undefined Then
		CurrentProfileName = CurrentProfileName(CurrentData.Profile);
		If CurrentProfileName = "Sales" Then
			Items.AllowEditPricesInDocuments.Visible = True;
			Items.AllowEditProductsAndServices.Visible 	 = True;
		Else
			Items.AllowEditPricesInDocuments.Visible = False;
			Items.AllowEditProductsAndServices.Visible 	 = False;
		EndIf;
		Items.AllowEditPricesInDocuments.Enabled = CurrentData.Check;
		Items.AllowEditProductsAndServices.Enabled   = CurrentData.Check;
		
		ShowAccessKinds = AccessKindsSettingIsAvailableForProfile(AccessKinds, CurrentData.Profile);
		
		Items.DecorationSplitter.Visible = ShowAccessKinds;
		Items.Access.Visible = ShowAccessKinds;
	EndIf;
	// SB End
	
	Items.LabelProfile.Enabled                      =    CurrentData <> Undefined AND CurrentData.Check;
	Items.AccessKinds.ReadOnly                      = Not EditingCurrentLimitations;
	Items.AccessTypeLabel.Enabled                   =    CurrentData <> Undefined AND CurrentData.Check;
	Items.AccessValues.ReadOnly                  = Not EditingCurrentLimitations;
	Items.AccessTypesChange.Enabled                 =    EditingCurrentLimitations;
	Items.AccessKindsContextMenuChange.Enabled  =    EditingCurrentLimitations;
	
	If Form.CurrentProfile = Undefined Then
		Form.CurrentAccessGroup = "";
	Else
		Form.CurrentAccessGroup = Form.CurrentProfile;
	EndIf;
	
	If Items.AccessKinds.RowFilter = Undefined
	 OR Items.AccessKinds.RowFilter.AccessGroup <> Form.CurrentAccessGroup Then
		
		Items.AccessKinds.RowFilter = New FixedStructure("AccessGroup", Form.CurrentAccessGroup);
		CurrentAccessKinds = AccessKinds.FindRows(New Structure("AccessGroup", Form.CurrentAccessGroup));
		If CurrentAccessKinds.Count() = 0 Then
			Items.AccessValues.RowFilter = New FixedStructure("AccessGroup, AccessKind", Form.CurrentAccessGroup, "");
			AccessManagementServiceClientServer.OnChangeCurrentAccessKind(Form);
		Else
			Items.AccessKinds.CurrentRow = CurrentAccessKinds[0].GetID();
		EndIf;
	EndIf;
	
EndProcedure

// SB
&AtServerNoContext
Function CurrentProfileName(Profile)
	
	Return CommonUse.ObjectAttributeValue(Profile, "Description");
	        
EndFunction

&AtServerNoContext
Function AllowEditPricesInDocuments(User)

	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroupsUsers.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref.Profile.IDSuppliedData = &ProfileIDDocumentsPricesEdit
	|	AND AccessGroupsUsers.User = &User";
	
	Query.SetParameter("User", User);
	Query.SetParameter("ProfileIDDocumentsPricesEdit", New UUID("76337579-bff4-11df-9174-e0cb4ed5f4c3"));
	
	Result = Query.Execute();
	Return Not Result.IsEmpty();

EndFunction

&AtServerNoContext
Function AllowEditProductsAndServices(User)

	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroupsUsers.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref.Profile.IDSuppliedData = &ProfileIDProductsAndServicesEdit
	|	AND AccessGroupsUsers.User = &User";
	
	Query.SetParameter("User", User);
	Query.SetParameter("ProfileIDProductsAndServicesEdit" , New UUID("76337580-bff4-11df-9174-e0cb4ed5f4c3"));
	
	Result = Query.Execute();
	Return Not Result.IsEmpty();

EndFunction

&AtServerNoContext
Function AccessKindsSettingIsAvailableForProfile(AccessKinds, Profile)
	
	If Not GetFunctionalOption("LimitAccessOnRecordsLevel") Then
		Return False;
	EndIf;
	
	AvailableAccessKinds = AccessKinds.FindRows(New Structure("AccessGroup", Profile));
	Return AvailableAccessKinds.Count() > 0;
	
EndFunction

&AtServer
Function AddAdditionalProfiles(SelectedProfiles)

	HasSaleProfile = False;
	NeedAccessToReturnsFromCustomers = False;
	NeedAccessToReturnsToSuppliers   = False;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SelectedProfiles.Profile,
	|	SelectedProfiles.Check
	|INTO Tu_SelectedProfiles
	|FROM
	|	&SelectedProfiles AS SelectedProfiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Tu_SelectedProfiles.Check AS HasProfileAdministrator,
	|	Tu_SelectedSaleProfiles.Check AS HasSaleProfile,
	|	Tu_SelectedPurchaseProfiles.Check AS HasPurchaseProfile
	|FROM
	|	Tu_SelectedProfiles AS Tu_SelectedProfiles,
	|	Tu_SelectedProfiles AS Tu_SelectedPurchaseProfiles,
	|	Tu_SelectedProfiles AS Tu_SelectedSaleProfiles
	|WHERE
	|	Tu_SelectedProfiles.Profile.IDSuppliedData = &ProfileIdAdministrator
	|	AND Tu_SelectedSaleProfiles.Profile.IDSuppliedData = &SaleProfileID
	|	AND Tu_SelectedPurchaseProfiles.Profile.IDSuppliedData = &PurchaseProfileID";
	
	Query.SetParameter("SelectedProfiles", SelectedProfiles);
	Query.SetParameter("ProfileIdAdministrator", New UUID("6c4b0307-43a4-4141-9c35-3dd7e9586d41"));
	Query.SetParameter("SaleProfileID", New UUID("76337576-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("PurchaseProfileID", New UUID("76337577-bff4-11df-9174-e0cb4ed5f4c3"));
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		HasSaleProfile = Selection.HasSaleProfile;
		
		If Not Selection.HasProfileAdministrator
			AND Not (Selection.HasSaleProfile AND Selection.HasPurchaseProfile) Then
			
			NeedAccessToReturnsFromCustomers = Selection.HasSaleProfile;
			NeedAccessToReturnsToSuppliers   = Selection.HasPurchaseProfile;
			
		EndIf;
		
	EndIf;
	
	IDSuppliedData = New UUID("76337579-bff4-11df-9174-e0cb4ed5f4c3");
	ProfileDocumentPricesEdit = Catalogs.AccessGroupsProfiles.FindByAttribute("IDSuppliedData", IDSuppliedData);
	If ValueIsFilled(ProfileDocumentPricesEdit) Then
		NewRow = SelectedProfiles.Add();
		NewRow.Profile = ProfileDocumentPricesEdit;
		NewRow.Check = HasSaleProfile AND AllowEditPricesInDocuments;
	EndIf;
	
	IDSuppliedData = New UUID("76337580-bff4-11df-9174-e0cb4ed5f4c3");
	ProfileProductsAndServicesEdit = Catalogs.AccessGroupsProfiles.FindByAttribute("IDSuppliedData", IDSuppliedData);
	If ValueIsFilled(ProfileProductsAndServicesEdit) Then
		NewRow = SelectedProfiles.Add();
		NewRow.Profile = ProfileProductsAndServicesEdit;
		NewRow.Check = HasSaleProfile AND AllowEditProductsAndServices;
	EndIf;
	
	IDSuppliedData = New UUID("76337581-bff4-11df-9174-e0cb4ed5f4c3");
	ProfileReturnsFromCustomers = Catalogs.AccessGroupsProfiles.FindByAttribute("IDSuppliedData", IDSuppliedData);
	If ValueIsFilled(ProfileReturnsFromCustomers) Then
		NewRow = SelectedProfiles.Add();
		NewRow.Profile = ProfileReturnsFromCustomers;
		NewRow.Check = NeedAccessToReturnsFromCustomers;
	EndIf;
	
	IDSuppliedData = New UUID("76337582-bff4-11df-9174-e0cb4ed5f4c3");
	ProfileReturnsToSuppliers = Catalogs.AccessGroupsProfiles.FindByAttribute("IDSuppliedData", IDSuppliedData);
	If ValueIsFilled(ProfileReturnsToSuppliers) Then
		NewRow = SelectedProfiles.Add();
		NewRow.Profile = ProfileReturnsToSuppliers;
		NewRow.Check = NeedAccessToReturnsToSuppliers;
	EndIf;
	
EndFunction
// SB End

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
