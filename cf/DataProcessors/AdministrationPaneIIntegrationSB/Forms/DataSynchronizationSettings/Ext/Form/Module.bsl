&AtClient
Var RefreshInterface;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// SB
	DoNotPostDocumentsWithIncorrectContracts = ?(ConstantsSet.DoNotPostDocumentsWithIncorrectContracts,
		Enums.YesNo.Yes,
		Enums.YesNo.No);
	
	// Settings of visible on launch
	Items.GroupTemporaryDirectoriesServersCluster.Visible = RunMode.ClientServer AND RunMode.ThisIsSystemAdministrator;
	Items.AdditionalInformation.Visible = RunMode.SaaS;
	
	If RunMode.SaaS Then
		
		Items.GroupUseDataSynchronization.Visible = False;
		Items.GroupDistributedInfobaseNodePrefix.Visible = False;
		Items.GroupTemporaryDirectoriesServersCluster.Visible = False;
		
	EndIf;
	
	// Update items states
	SetEnabled();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	AlertsHandler(EventName, Parameter, Source);
	
EndProcedure

&AtClient
Procedure OnClose()
	#If Not WebClient Then
	RefreshApplicationInterface();
	#EndIf
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure HowToApplySettingsNavigationRefProcessing(Item, URL, StandardProcessing)
	StandardProcessing = False;
	RefreshInterface = True;
	AttachIdleHandler("RefreshApplicationInterface", 0.1, True);
EndProcedure

&AtClient
Procedure UseDataSynchronizationOnChange(Item)
	
	UpdateSecurityProfilesPermissions(Item);
	
EndProcedure

&AtClient
Procedure DistributedInformationBaseNodePrefixOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForWindowsOnChange(Item)
	
	UpdateSecurityProfilesPermissions(Item);
	
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForLinuxOnChange(Item)
	
	UpdateSecurityProfilesPermissions(Item);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AlertsHandler(EventName, Parameter, Source)
	
	// Data processor of alerts from other open forms.
	//
	// Example:
	//   If EventName =
	//     "ConstantsSet.DistributedInformationBaseNodePrefix" Then ConstantsSet.DistributedInformationBaseNodePrefix = Parameter;
	//   EndIf;
	
	
	
EndProcedure

&AtClient
Procedure DataSynchronizationSettings(Command)
	
	If RunMode.SaaS Then
		
		OpenableFormName = "CommonForm.DataSynchronizationSaaS";
		
	Else
		OpenableFormName = "CommonForm.DataExchanges";
		
	EndIf;
	
	OpenForm(OpenableFormName);
	
EndProcedure

&AtClient
Procedure InformationRegisterDataImportProhibitionDates(Command)
	OpenForm(
		"InformationRegister.ChangeProhibitionDates.Form.ChangeProhibitionDates",
		New Structure("DataImportingProhibitionDates", True),
		ThisObject);
EndProcedure

&AtClient
Procedure ResultsSynchronizationData(Command)
	OpenForm("InformationRegister.DataExchangeResults.Form.Form");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		RefreshInterface = True;
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		#EndIf
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonUseClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateSecurityProfilesPermissions(Item)
	
	ClosingAlert = New NotifyDescription("UpdateSecurityProfilesPermissionsEnd", ThisObject, Item);
	
	ArrayOfQueries = CreateQueryOnExternalResourcesUse(Item.Name);
	
	If ArrayOfQueries = Undefined Then
		Return;
	EndIf;
	
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
		ArrayOfQueries, ThisObject, ClosingAlert);
	
EndProcedure

&AtServer
Function CreateQueryOnExternalResourcesUse(ConstantName)
	
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() = ConstantValue Then
		Return Undefined;
	EndIf;
	
	If ConstantName = "UseDataSynchronization" Then
		
		If ConstantValue Then
			
			Query = DataExchangeServer.QueryOnExternalResourcesUseWhenSharingEnabled();
			
		Else
			
			Query = DataExchangeServer.QueryOnClearPermissionToUseExternalResources();
			
		EndIf;
		
		Return Query;
		
	Else
		
		ValueManager = ConstantManager.CreateValueManager();
		ConstantIdentifier = CommonUse.MetadataObjectID(ValueManager.Metadata());
		
		If IsBlankString(ConstantValue) Then
			
			Query = WorkInSafeMode.QueryOnClearPermissionToUseExternalResources(ConstantIdentifier);
			
		Else
			
			permissions = CommonUseClientServer.ValueInArray(
				WorkInSafeMode.PermissionToUseFileSystemDirectory(ConstantValue, True, True));
			Query = WorkInSafeMode.QueryOnExternalResourcesUse(permissions, ConstantIdentifier);
			
		EndIf;
		
		Return CommonUseClientServer.ValueInArray(Query);
		
	EndIf;
	
EndFunction

&AtClient
Procedure UpdateSecurityProfilesPermissionsEnd(Result, Item) Export
	
	If Result = DialogReturnCode.OK Then
	
		Attachable_OnAttributeChange(Item);
		
	Else
		
		ThisObject.Read();
	
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
	If AttributePathToData = "DoNotPostDocumentsWithIncorrectContracts" Then
		
		ConstantValue = (DoNotPostDocumentsWithIncorrectContracts = Enums.YesNo.Yes);
		Constants.DoNotPostDocumentsWithIncorrectContracts.Set(ConstantValue);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseDataSynchronization" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ResultsSynchronizationData", 					"Enabled", ConstantsSet.UseDataSynchronization);
		CommonUseClientServer.SetFormItemProperty(Items, "GroupDistributedInfobaseNodePrefix",	"Enabled", ConstantsSet.UseDataSynchronization);
		CommonUseClientServer.SetFormItemProperty(Items, "DataSynchronizationSettings",						"Enabled", ConstantsSet.UseDataSynchronization);
		CommonUseClientServer.SetFormItemProperty(Items, "ResultsSynchronizationData",						"Enabled", ConstantsSet.UseDataSynchronization);
		CommonUseClientServer.SetFormItemProperty(Items, "GroupTemporaryDirectoriesServersCluster",			"Enabled", ConstantsSet.UseDataSynchronization);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
Procedure ControlContractsOnDocumentsPostingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure DecorationInformationAboutSynchronizationWithPSUClick(Item)
	GotoURL("");
EndProcedure

&AtClient
Procedure DecorationInformationAboutSynchronizationWithERClick(Item)
	GotoURL("");
EndProcedure

#EndRegion
