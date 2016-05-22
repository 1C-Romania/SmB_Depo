&AtClient
Var CheckIteration;
&AtClient
Var StorageAddress;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	StorageAddressAtServer = Parameters.StorageAddress;
	RequestProcessorResults = GetFromTempStorage(StorageAddressAtServer);
	
	If GetFunctionalOption("SecurityProfilesAreUsed") AND Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get() Then
		If Parameters.CheckMode Then
			Items.PagesHeader.CurrentPage = Items.PageHeaderRequiredCancelOutofdateClusterPermissions;
		ElsIf Parameters.RecoveryMode Then
			Items.PagesHeader.CurrentPage = Items.PageHeaderOnRestoringFollowingSettingsWillBeInstalledInCluster;
		Else
			Items.PagesHeader.CurrentPage = Items.PageHeaderToMakeRequiredChangesInCluster;
		EndIf;
	Else
		Items.PagesHeader.CurrentPage = Items.PageHeaderOnSwitchingFollowingSettingsWillBeInstalledInCluster;
	EndIf;
	
	RequestsUsageScenario = RequestProcessorResults.Script;
	
	If RequestsUsageScenario.Count() = 0 Then
		RequiredChangesInSecurityProfiles = False;
		Return;
	EndIf;
	
	PermissionPresentation = RequestProcessorResults.Presentation;
	
	RequiredChangesInSecurityProfiles = True;
	RequiredInfobaseAdministrationParameters = False;
	For Each ScriptStep IN RequestsUsageScenario Do
		If ScriptStep.Operation = Enums.OperationsAdministrationSecurityProfiles.Purpose
				Or ScriptStep.Operation = Enums.OperationsAdministrationSecurityProfiles.DeleteDestination Then
			RequiredInfobaseAdministrationParameters = True;
			Break;
		EndIf;
	EndDo;
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		IBUser = InfobaseUsers.FindByName(AdministrationParameters.NameAdministratorInfobase);
		If IBUser <> Undefined Then
			IBAdministratorID = IBUser.UUID;
		EndIf;
		
	EndIf;
	
	ConnectionType = AdministrationParameters.ConnectionType;
	ServerClusterPort = AdministrationParameters.ClusterPort;
	
	ServerAgentAddress = AdministrationParameters.ServerAgentAddress;
	ServerAgentPort = AdministrationParameters.ServerAgentPort;
	
	AdministrationServerAddress = AdministrationParameters.AdministrationServerAddress;
	AdministrationServerPort = AdministrationParameters.AdministrationServerPort;
	
	NameInCluster = AdministrationParameters.NameInCluster;
	ClusterAdministratorName = AdministrationParameters.ClusterAdministratorName;
	
	IBUser = InfobaseUsers.FindByName(AdministrationParameters.NameAdministratorInfobase);
	If IBUser <> Undefined Then
		IBAdministratorID = IBUser.UUID;
	EndIf;
	
	Users.FindAmbiguousInfobaseUsers(, IBAdministratorID);
	InfobaseAdministrator = Catalogs.Users.FindByAttribute("InfobaseUserID", IBAdministratorID);
	
	Items.AdministrationGroup.Visible = RequiredInfobaseAdministrationParameters;
	Items.WarningGroupOnNeedToRestart.Visible = RequiredInfobaseAdministrationParameters;
	
	Items.FormAllow.Title = NStr("en = 'Next >'");
	Items.FormBack.Visible = False;
	
	VisibleManagement();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
		ShowErrorOperationNotSupportedInWebClient();
		Return;
	#EndIf
	
	If RequiredChangesInSecurityProfiles Then
		
		StorageAddress = StorageAddressAtServer;
		
	Else
		
		Close(DialogReturnCode.Ignore);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If RequiredInfobaseAdministrationParameters Then
		
		If Not ValueIsFilled(InfobaseAdministrator) Then
			Return;
		EndIf;
		
		FieldName = "InfobaseAdministrator";
		IBUser = GetInfobaseAdministrator();
		If IBUser = Undefined Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Specified user does not have access to the infobase.'"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
		If Not Users.InfobaseUserWithFullAccess(IBUser, True) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'User has no administrative rights.'"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ConnectionTypeOnChange(Item)
	
	VisibleManagement();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Next(Command)
	
	If Items.GroupPages.CurrentPage = Items.PermissionPage Then
		
		ErrorText = "";
		Items.ErrorGroup.Visible = False;
		Items.FormAllow.Title = NStr("en = 'Configure permissions in the server cluster'");
		Items.GroupPages.CurrentPage = Items.PageConnection;
		Items.FormBack.Visible = True;
		
	ElsIf Items.GroupPages.CurrentPage = Items.PageConnection Then
		
		ErrorText = "";
		Try
			
			ApplyPermissions();
			EndRequestsUsage(StorageAddress);
			ExpectToApplySettingsInCluster();
			
		Except
			ErrorText = BriefErrorDescription(ErrorInfo()); 
			Items.ErrorGroup.Visible = True;
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	If Items.GroupPages.CurrentPage = Items.PageConnection Then
		Items.GroupPages.CurrentPage = Items.PermissionPage;
		Items.FormBack.Visible = False;
		Items.FormAllow.Title = NStr("en = 'Next >'");
	EndIf;
	
EndProcedure

&AtClient
Procedure ReregisterCOMConnector(Command)
	
	CommonUseClient.RegisterCOMConnector();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure VisibleManagement()
	
	If ConnectionType = "COM" Then
		Items.ConnectionParametersToClusterVia.CurrentPage = Items.PageConnectionParametersToCOMCluster;
		GroupVisibleCOMConnectorVersionErrors = True;
	Else
		Items.ConnectionParametersToClusterVia.CurrentPage = Items.PageConnectionParametersToClusterRAS;
		GroupVisibleCOMConnectorVersionErrors = False;
	EndIf;
	
	Items.ErrorGroupCOMConnectorVersions.Visible = GroupVisibleCOMConnectorVersionErrors;
	
EndProcedure

&AtServer
Procedure ShowErrorOperationNotSupportedInWebClient()
	
	Items.PagesGlobal.CurrentPage = Items.PageOperationNotSupportedInWebClient;
	
EndProcedure

&AtServer
Function GetInfobaseAdministrator()
	
	If Not ValueIsFilled(InfobaseAdministrator) Then
		Return Undefined;
	EndIf;
	
	Return InfobaseUsers.FindByUUID(
		InfobaseAdministrator.InfobaseUserID);
	
EndFunction

&AtServerNoContext
Function InfobaseUserName(Val User)
	
	If ValueIsFilled(User) Then
		
		InfobaseUserID = CommonUse.ObjectAttributeValue(User, "InfobaseUserID");
		IBUser = InfobaseUsers.FindByUUID(InfobaseUserID);
		Return IBUser.Name;
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

&AtClient
Procedure ApplyPermissions()
	
	UsageParameters = StartRequestsUsage(StorageAddress);
	
	OperationKinds = UsageParameters.OperationKinds;
	Script = UsageParameters.RequestsUsageScenario;
	InfobaseAdministrationParametersRequired = UsageParameters.RequiredInfobaseAdministrationParameters;
	
	ClusterAdministrationParameters = ClusterAdministrationClientServer.ClusterAdministrationParameters();
	ClusterAdministrationParameters.ConnectionType = ConnectionType;
	ClusterAdministrationParameters.ServerAgentAddress = ServerAgentAddress;
	ClusterAdministrationParameters.ServerAgentPort = ServerAgentPort;
	ClusterAdministrationParameters.AdministrationServerAddress = AdministrationServerAddress;
	ClusterAdministrationParameters.AdministrationServerPort = AdministrationServerPort;
	ClusterAdministrationParameters.ClusterPort = ServerClusterPort;
	ClusterAdministrationParameters.ClusterAdministratorName = ClusterAdministratorName;
	ClusterAdministrationParameters.ClusterAdministratorPassword = ClusterAdministratorPassword;
	
	If InfobaseAdministrationParametersRequired Then
		InfobaseAdministrationParameters = ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters();
		InfobaseAdministrationParameters.NameInCluster = NameInCluster;
		InfobaseAdministrationParameters.NameAdministratorInfobase = InfobaseUserName(InfobaseAdministrator);
		InfobaseAdministrationParameters.PasswordAdministratorInfobase = IBAdministratorPassword;
	Else
		InfobaseAdministrationParameters = Undefined;
	EndIf;
	
	PermissionSettingOnExternalResourcesUsageClient.ApplyChangesPermissionsInSecurityProfilesOnServerCluster(
		OperationKinds, Script, ClusterAdministrationParameters, InfobaseAdministrationParameters);
	
EndProcedure

&AtServer
Function StartRequestsUsage(Val StorageAddress)
	
	Result = GetFromTempStorage(StorageAddress);
	RequestsUsageScenario = Result.Script;
	
	OperationKinds = New Structure();
	For Each EnumValue IN Metadata.Enums.OperationsAdministrationSecurityProfiles.EnumValues Do
		OperationKinds.Insert(EnumValue.Name, Enums.OperationsAdministrationSecurityProfiles[EnumValue.Name]);
	EndDo;
	
	Return New Structure("OperationKinds, RequestsUsageScenario, RequiredInfobaseAdministrationParameters",
		OperationKinds, RequestsUsageScenario, RequiredInfobaseAdministrationParameters);
	
EndFunction

&AtServer
Procedure EndRequestsUsage(Val StorageAddress)
	
	DataProcessors.PermissionSettingsForExternalResourcesUse.RecordRequestsUse(GetFromTempStorage(StorageAddress).Status);
	SaveAdministrationParameters();
	
EndProcedure

&AtServer
Procedure SaveAdministrationParameters()
	
	SavedAdministrationParameters = New Structure();
	
	// Cluster administration parameters.
	SavedAdministrationParameters.Insert("ConnectionType", ConnectionType);
	SavedAdministrationParameters.Insert("ServerAgentAddress", ServerAgentAddress);
	SavedAdministrationParameters.Insert("ServerAgentPort", ServerAgentPort);
	SavedAdministrationParameters.Insert("AdministrationServerAddress", AdministrationServerAddress);
	SavedAdministrationParameters.Insert("AdministrationServerPort", AdministrationServerPort);
	SavedAdministrationParameters.Insert("ClusterPort", ServerClusterPort);
	SavedAdministrationParameters.Insert("ClusterAdministratorName", ClusterAdministratorName);
	SavedAdministrationParameters.Insert("ClusterAdministratorPassword", "");
	
	// Info base administration parameters.
	SavedAdministrationParameters.Insert("NameInCluster", NameInCluster);
	SavedAdministrationParameters.Insert("NameAdministratorInfobase", InfobaseUserName(InfobaseAdministrator));
	SavedAdministrationParameters.Insert("PasswordAdministratorInfobase", "");
	
	StandardSubsystemsServer.SetAdministrationParameters(SavedAdministrationParameters);
	
EndProcedure

&AtClient
Procedure ExpectToApplySettingsInCluster()
	
	Close(DialogReturnCode.OK);
	
EndProcedure

#EndRegion