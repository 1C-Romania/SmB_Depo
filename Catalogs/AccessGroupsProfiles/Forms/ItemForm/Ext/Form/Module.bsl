
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetInterfaceOfRolesOnFormCreating", ValueIsFilled(Object.Ref));
	
	// Auxiliary data preparation.
	AccessManagementService.OnCreateAtServerAllowedValuesEditingForms(ThisObject, True);
	
	// Setting constant property accessibility.
	
	// Defining the necessity to configure the settings of access limit.
	If Not AccessManagement.LimitAccessOnRecordsLevel() Then
		Items.AccessTypesAndValues.Visible = False;
	EndIf;
	
	// Definition of form item editing possibility (rewrite is available).
	WithoutEditingSuppliedValues = ReadOnly
		OR Not Object.Ref.IsEmpty() AND Catalogs.AccessGroupsProfiles.ProfileChangingProhibition(Object);
		
	If Object.Ref = Catalogs.AccessGroupsProfiles.Administrator
	   AND Not Users.InfobaseUserWithFullAccess(,CommonUseReUse.ApplicationRunningMode().Local) Then
		ReadOnly = True;
	EndIf;
	
	Items.Description.ReadOnly = WithoutEditingSuppliedValues;
	
	// Setting edit of access kinds.
	Items.AccessKinds.ReadOnly     = WithoutEditingSuppliedValues;
	Items.AccessValues.ReadOnly = WithoutEditingSuppliedValues;
	
	ProcessRolesInterface("SetReadOnlyOfRoles", WithoutEditingSuppliedValues);
	
	SetEnabledOfDescriptionAndRecoveryOfSuppliedProfile();
	
	CompletedProcedureOnCreateAtServer = True;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not CompletedProcedureOnCreateAtServer Then
		Return;
	EndIf;
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetInterfaceOfRolesOnFormCreating", True);
	
	AccessManagementService.OnRereadingOnFormServerAllowedValuesEditing(
		ThisObject, CurrentObject);
	
	RefreshProfileAccessGroups = False;
	
	SetEnabledOfDescriptionAndRecoveryOfSuppliedProfile(CurrentObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ProfileFillingCheckRequired = Not WriteParameters.Property(
		"ResponseByProfileAccessGroupsUpdateIsReceived");
	
	If ValueIsFilled(Object.Ref)
	   AND ProfileAccessGroupsUpdateRequired
	   AND Not WriteParameters.Property("ResponseByProfileAccessGroupsUpdateIsReceived") Then
		
		Cancel = True;
		If CheckFilling() Then
			ShowQueryBox(
				New NotifyDescription("BeforeWriteContinuation", ThisObject, WriteParameters),
				QuestionTextUpdateProfileAccessGroups(),
				QuestionDialogMode.YesNoCancel,
				,
				DialogReturnCode.No);
		EndIf;
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Filling object roles from collection.
	CurrentObject.Roles.Clear();
	For Each String IN CollectionOfRoles Do
		CurrentObject.Roles.Add().Role = CommonUse.MetadataObjectID(
			"Role." + String.Role);
	EndDo;
	
	If WriteParameters.Property("RefreshProfileAccessGroups") Then
		CurrentObject.AdditionalProperties.Insert("RefreshProfileAccessGroups");
	EndIf;
	
	AccessManagementService.BeforeWriteOnServerAllowedValuesEditingForms(
		ThisObject, CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.AdditionalProperties.Property(
	         "PersonalAccessGroupsWithRenewedDescription") Then
		
		WriteParameters.Insert(
			"PersonalAccessGroupsWithRenewedDescription",
			CurrentObject.AdditionalProperties.PersonalAccessGroupsWithRenewedDescription);
	EndIf;
	
	AccessManagementService.AfterWriteOnServerAllowedValuesEditingForms(
		ThisObject, CurrentObject, WriteParameters);
	
	SetEnabledOfDescriptionAndRecoveryOfSuppliedProfile(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	ObjectWasWritten = True;
	ProfileAccessGroupsUpdateRequired = False;
	
	Notify("Write_GroupsAccessProfiles", New Structure, Object.Ref);
	
	If WriteParameters.Property("PersonalAccessGroupsWithRenewedDescription") Then
		NotifyChanged(Type("CatalogRef.AccessGroups"));
		
		For Each PersonalAccessGroup IN WriteParameters.PersonalAccessGroupsWithRenewedDescription Do
			Notify("Record_AccessGroups", New Structure, PersonalAccessGroup);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not ProfileFillingCheckRequired Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Check whether there are roles in metadata.
	CheckedObjectAttributes.Add("Roles.Role");
	
	TreeItems = Roles.GetItems();
	For Each String IN TreeItems Do
		If String.Check AND Left(String.Synonym, 1) = "?" Then
			CommonUseClientServer.AddUserError(Errors,
				"Roles[%1].RolesSynonym",
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Role ""%1"" is not found in the metadata.'"),
					String.Synonym),
				"Roles",
				TreeItems.IndexOf(String),
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Role ""%2"" in row %1 is not found in the metadata.'"),
					"%1", String.Synonym));
		EndIf;
	EndDo;
	
	// Checking unfilled and repetitive kinds and values of access.
	AccessManagementServiceClientServer.AllowedValuesEditFormFillCheckProcessingAtServerProcessor(
		ThisObject, Cancel, CheckedObjectAttributes, Errors);
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	CheckedAttributes.Delete(CheckedAttributes.Find("Object"));
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert("CheckedObjectAttributes",
		CheckedObjectAttributes);
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("TuneRolesInterfaceOnSettingsImporting", Settings);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersAccessKinds

&AtClient
Procedure AccesKindsOnChange(Item)
	
	ProfileAccessGroupsUpdateRequired = True;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementServiceClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	AccessManagementServiceClient.AccessKindsBeforeAddRow(
		ThisObject, Item, Cancel, Copy, Parent, Group);
	
EndProcedure

&AtClient
Procedure AccessKindsBeforeDeleteRow(Item, Cancel)
	
	AccessManagementServiceClient.AccessKindsBeforeDeleteRow(
		ThisObject, Item, Cancel);
	
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
// Item event handlers AccessKindPresentation form table AccessKinds.

&AtClient
Procedure AccessKindsAccessKindPresentationOnChange(Item)
	
	AccessManagementServiceClient.AccessKindsAccessKindPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAccessKindPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementServiceClient.AccessKindsAccessKindPresentationChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
		
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

#Region FormTableItemEventHandlersRoles

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("RefreshContentOfRoles");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RestoreByInitialFilling(Command)
	
	If Modified OR ObjectWasWritten Then
		UnlockFormDataForEdit();
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("RestoreByInitialFillingContinuation", ThisObject),
		NStr("en = 'Do you want to restore the profile by the initial filling content?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ShowUnusedAccessKinds(Command)
	
	ShowUnusedAccessKindsAtServer();
	
EndProcedure

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

// Event handler continuation BeforeWrite.
&AtClient
Procedure BeforeWriteContinuation(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("RefreshProfileAccessGroups");
	EndIf;
	
	WriteParameters.Insert("ResponseByProfileAccessGroupsUpdateIsReceived");
	
	Write(WriteParameters);
	
EndProcedure

// Command handler continuation RestoreByInitialFilling.
&AtClient
Procedure RestoreByInitialFillingContinuation(Response, NotSpecified) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("RestoreByInitialFillingEnd", ThisObject),
		QuestionTextUpdateProfileAccessGroups(),
		QuestionDialogMode.YesNoCancel,
		,
		DialogReturnCode.No);
	
EndProcedure

// Command handler continuation RestoreByInitialFilling.
&AtClient
Procedure RestoreByInitialFillingEnd(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	UpdateAccessGroups = (Response = DialogReturnCode.Yes);
	
	InitialAccessGroupsProfileFilling(UpdateAccessGroups);
	
	Read();
	UsersServiceClient.ExpandRolesSubsystems(ThisObject);
	
	If UpdateAccessGroups Then
		Text = NStr("en = 'Profile ""%1%"" restored by start filling content, profile access groups updated'");
	Else
		Text = NStr("en = 'Profile ""%1%"" restored by start filling content, profile access groups not updated'");
	EndIf;
	
	ShowUserNotification(StringFunctionsClientServer.PlaceParametersIntoString(
		Text, Object.Description));
	
EndProcedure

&AtServer
Procedure ShowUnusedAccessKindsAtServer()
	
	AccessManagementService.RefreshUnusedAccessKindsDisplay(ThisObject);
	
EndProcedure

&AtServer
Procedure SetEnabledOfDescriptionAndRecoveryOfSuppliedProfile(CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = Object;
	EndIf;
	
	If Catalogs.AccessGroupsProfiles.IsInitialProfileFilling(CurrentObject.Ref) Then
		
		StandardProfileDescription =
			Catalogs.AccessGroupsProfiles.StandardProfileDescription(CurrentObject.Ref);
		
		If Catalogs.AccessGroupsProfiles.StandardProfileChanged(CurrentObject) Then
			// Definition of restoration rights by initial filling.
			Items.RestoreByInitialFilling.Visible =
				Users.InfobaseUserWithFullAccess(,, False);
			
			Items.StandardProfileChanged.Visible = True;
		Else
			Items.RestoreByInitialFilling.Visible = False;
			Items.StandardProfileChanged.Visible = False;
		EndIf;
	Else
		Items.RestoreByInitialFilling.Visible = False;
		Items.PageDescription.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Function QuestionTextUpdateProfileAccessGroups()
	
	Return
		NStr("en = 'Do you want to update access groups which use this profile?
		           |
		           |Excess access kinds with specified access values 		              |will be deleted, and missing access kinds will be added.'");
		
EndFunction

////////////////////////////////////////////////////////////////////////////////
// To provide operation of the roles interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionSettings = New Structure;
	ActionSettings.Insert("MainParameter",       MainParameter);
	ActionSettings.Insert("Form",                  ThisObject);
	ActionSettings.Insert("CollectionOfRoles",         CollectionOfRoles);
	
	ActionSettings.Insert("HideFullAccessRole",
		Object.Ref <> Catalogs.AccessGroupsProfiles.Administrator);
	
	UsersType = ?(CommonUseReUse.DataSeparationEnabled(), 
		Enums.UserTypes.DataAreaUser, 
		Enums.UserTypes.LocalApplicationUser);
	ActionSettings.Insert("UsersType", UsersType);
	
	UsersService.ProcessRolesInterface(Action, ActionSettings);
	
EndProcedure

&AtServer
Procedure InitialAccessGroupsProfileFilling(Val UpdateAccessGroups)
	
	Catalogs.AccessGroupsProfiles.FillStandardProfile(
		Object.Ref, UpdateAccessGroups);
	
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
