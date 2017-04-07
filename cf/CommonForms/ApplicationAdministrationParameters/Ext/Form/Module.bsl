
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUse.FileInfobase() AND Parameters.QueryClusterAdministrationParameters Then
		Raise NStr("en='Setting of the servers cluster parameters is available only in the client server mode.';ru='Настройка параметров кластера серверов доступна только в клиент-серверном режиме работы.'");
	EndIf;
	
	CanUseSeparatedData = CommonUseReUse.CanUseSeparatedData();
	
	If Parameters.AdministrationParameters = Undefined Then
		AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	Else
		AdministrationParameters = Parameters.AdministrationParameters;
	EndIf;
	
	CheckNeedForAdministrationParametersEnter();
	
	If CanUseSeparatedData Then
		
		IBUser = InfobaseUsers.FindByName(
		AdministrationParameters.NameAdministratorInfobase);
		If IBUser <> Undefined Then
			IBAdministratorID = IBUser.UUID;
		EndIf;
		Users.FindAmbiguousInfobaseUsers(, IBAdministratorID);
		InfobaseAdministrator = Catalogs.Users.FindByAttribute("InfobaseUserID", IBAdministratorID);
		
	EndIf;
	
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
	EndIf;
	
	If IsBlankString(Parameters.ExplanatoryInscription) Then
		Items.ExplanatoryInscription.Visible = False;
	Else
		Items.ExplanatoryInscription.Title = Parameters.ExplanatoryInscription;
	EndIf;
	
	FillPropertyValues(ThisObject, AdministrationParameters);
	
	Items.RunMode.CurrentPage = ?(CanUseSeparatedData, Items.SplitMode, Items.UndividedMode);
	Items.GroupAdministrationIB.Visible = Parameters.RequestInfobaseAdministrationParameters;
	Items.GroupClusterAdministration.Visible = Parameters.QueryClusterAdministrationParameters;
	
	If CommonUseClientServer.IsLinuxClient() Then
		
		ConnectionType = "RAS";
		Items.ConnectionType.Visible = False;
		Items.GroupManagementParameters.ShowTitle = True;
		Items.GroupManagementParameters.Representation = UsualGroupRepresentation.WeakSeparation;
		
	EndIf;
	
	Items.GroupConnectionType.CurrentPage = ?(ConnectionType = "COM", Items.GroupCOM, Items.GroupRAS);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not RequireEnterAdministrationSettings Then
		Try
			CheckAdministrationParameters(AdministrationParameters);
		Except
			Return; // No processing is required. The form will be opened in the normal mode.
		EndTry;
		Close(AdministrationParameters);
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not Parameters.RequestInfobaseAdministrationParameters Then
		Return;
	EndIf;
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		If Not ValueIsFilled(InfobaseAdministrator) Then
			Return;
		EndIf;
		
		FieldName = "InfobaseAdministrator";
		
		IBUser = Undefined;
		GetInfobaseAdministrator(IBUser);
		If IBUser = Undefined Then
			CommonUseClientServer.MessageToUser(NStr("en='Specified user does not have access to the infobase.';ru='Указанный пользователь не имеет доступа к информационной базе.'"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
		If Not Users.InfobaseUserWithFullAccess(IBUser, True) Then
			CommonUseClientServer.MessageToUser(NStr("en='User has no administrative rights.';ru='У пользователя нет административных прав.'"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ConnectionTypeOnChange(Item)
	
	Items.GroupConnectionType.CurrentPage = ?(ConnectionType = "COM", Items.GroupCOM, Items.GroupRAS);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Write(Command)
	
	ClearMessages();
	
	If Not CheckFillingAtServer() Then
		Return;
	EndIf;
	
	// Fill the settings structure.
	FillPropertyValues(AdministrationParameters, ThisObject);
	
	CheckAdministrationParameters(AdministrationParameters);
	
	SaveConnectionParameters();
	
	// Recover password values.
	FillPropertyValues(AdministrationParameters, ThisObject);
	
	Close(AdministrationParameters);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function CheckFillingAtServer()
	
	Return CheckFilling();
	
EndFunction

&AtServer
Procedure SaveConnectionParameters()
	
	// Save the parameters to constant, clear passwords.
	StandardSubsystemsServer.SetAdministrationParameters(AdministrationParameters);
	
EndProcedure

&AtServer
Procedure GetInfobaseAdministrator(IBUser = Undefined)
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		If ValueIsFilled(InfobaseAdministrator) Then
			
			IBUser = InfobaseUsers.FindByUUID(
				InfobaseAdministrator.InfobaseUserID);
			
		Else
			
			IBUser = Undefined;
			
		EndIf;
		
		NameAdministratorInfobase = ?(IBUser = Undefined, "", IBUser.Name);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckAdministrationParameters(AdministrationParameters)
	
	If ConnectionType = "COM" Then
		CommonUseClient.RegisterCOMConnector(False);
	EndIf;
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase Then
		
		CheckFileBaseAdministrationParameters();
		
	Else
		
		If CommonUseClient.ClientConnectedViaWebServer() Then
			
			CheckAdministrationParametersAtServer();
			
		Else
			ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,
				Parameters.QueryClusterAdministrationParameters, Parameters.RequestInfobaseAdministrationParameters);
		EndIf;
			
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckAdministrationParametersAtServer()
	
	ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,
		Parameters.QueryClusterAdministrationParameters, Parameters.RequestInfobaseAdministrationParameters);
	
EndProcedure

&AtServer
Procedure CheckNeedForAdministrationParametersEnter()
	
	RequireEnterAdministrationSettings = True;
	
	If Parameters.RequestInfobaseAdministrationParameters AND Not Parameters.QueryClusterAdministrationParameters Then
		
		UserCount = InfobaseUsers.GetUsers().Count();
		
		If UserCount > 0 Then
			
			// Calculate the actual name of the user even if it was previously changed in the current session;
			// For example, to connect to the current IB through the external connection from this session;
			// IN all other cases it is enough to get InfobaseUsers.CurrentUser().
			CurrentUser = InfobaseUsers.FindByUUID(
				InfobaseUsers.CurrentUser().UUID);
			
			If CurrentUser = Undefined Then
				CurrentUser = InfobaseUsers.CurrentUser();
			EndIf;
			
			If CurrentUser.StandardAuthentication AND Not CurrentUser.PasswordIsSet 
				AND Users.InfobaseUserWithFullAccess(CurrentUser, True) Then
				
				AdministrationParameters.NameAdministratorInfobase = CurrentUser.Name;
				AdministrationParameters.PasswordAdministratorInfobase = "";
				
				RequireEnterAdministrationSettings = False;
				
			EndIf;
			
		ElsIf UserCount = 0 Then
			
			AdministrationParameters.NameAdministratorInfobase = "";
			AdministrationParameters.PasswordAdministratorInfobase = "";
			
			RequireEnterAdministrationSettings = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFileBaseAdministrationParameters()
	
	If Parameters.RequestInfobaseAdministrationParameters Then
		
		// IN the basic versions, do not check connection.
		ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
		
		If ClientWorkParameters.ThisIsBasicConfigurationVersion
			Or ClientWorkParameters.IsEducationalPlatform Then
			Return;
		EndIf;
		
		ConnectionParameters = CommonUseClientServer.ExternalConnectionParameterStructure();
		ConnectionParameters.InfobaseDirectory = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(InfobaseConnectionString(), """")[1];
		ConnectionParameters.UserName = NameAdministratorInfobase;
		ConnectionParameters.UserPassword = PasswordAdministratorInfobase;
		
		Result = CommonUseClientServer.InstallOuterDatabaseJoin(ConnectionParameters);
		
		If Result.Connection = Undefined Then
			
			Raise Result.ErrorShortInfo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion