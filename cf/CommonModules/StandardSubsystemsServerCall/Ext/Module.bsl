////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// Write the application logout confirmation
// setting for the current user.
// 
// Parameters:
//   Value - Boolean   - setting value.
// 
Procedure SaveExitConfirmationSettings(Value) Export
	
	CommonUse.CommonSettingsStorageSave("UserCommonSettings", "AskConfirmationOnExit", Value);
	
EndProcedure

// It returns the structure of the parameters
// necessary for the work of client code when launching the configuration, i.e. in the event handlers.
// - BeforeSystemWorkStart,
// - OnStart
//
Function ClientWorkParametersOnStart(Parameters) Export
	
	RememberTemporaryParameters(Parameters);
	
	If Parameters.ReceivedClientParameters <> Undefined Then
		If Not Parameters.Property("SkipClearingDesktopHide") Then
			HideDesktopOnStart(False);
		EndIf;
	EndIf;
	
	PrivilegedModeInstalledOnLaunch = PrivilegedMode();
	
	SetPrivilegedMode(True);
	If SessionParameters.ClientParametersOnServer.Count() = 0 Then
		// First server call from client on start.
		ClientParameters = New Map;
		ClientParameters.Insert("LaunchParameter", Parameters.LaunchParameter);
		ClientParameters.Insert("InfobaseConnectionString", Parameters.InfobaseConnectionString);
		ClientParameters.Insert("PrivilegedModeInstalledOnLaunch", PrivilegedModeInstalledOnLaunch);
		ClientParameters.Insert("ThisIsWebClient",         Parameters.ThisIsWebClient);
		ClientParameters.Insert("ThisIsMacOSWebClient", Parameters.ThisIsMacOSWebClient);
		ClientParameters.Insert("IsLinuxClient",       Parameters.IsLinuxClient);
		SessionParameters.ClientParametersOnServer = New FixedMap(ClientParameters);
		
		If Not CommonUseReUse.DataSeparationEnabled() Then
			If ExchangePlans.MasterNode() <> Undefined
			 Or ValueIsFilled(Constants.MasterNode.Get()) Then
				// Prevention of accidental update for the predefined data in the RIB subordinate node.:
				// - on start with temporarily cancelled host node;
				// - when restructuring data in the node recovery process.
				If GetInfobasePredefinedData()
				     <> PredefinedDataUpdate.DontAutoUpdate Then
					SetInfobasePredefinedDataUpdate(
						PredefinedDataUpdate.DontAutoUpdate);
				EndIf;
				If ExchangePlans.MasterNode() <> Undefined
				   AND Not ValueIsFilled(Constants.MasterNode.Get()) Then
				   // Save the host node to be restored.
					StandardSubsystemsServer.SaveMasterNode();
					
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	SetPrivilegedMode(False);
	
	If Not StandardSubsystemsServer.AddClientWorkParametersOnStart(Parameters) Then
		FixedParameters = ClientFixedParametersWithoutTemporaryParameters(Parameters);
		Return FixedParameters;
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning");
	For Each Handler IN EventHandlers Do
		Handler.Module.OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters);
	EndDo;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnAddWorkParametersClientOnStart");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnAddWorkParametersClientOnStart(Parameters);
	EndDo;
	
	AppliedParameters = New Structure;
	CommonUseOverridable.ClientWorkParametersOnStart(AppliedParameters);
	
	For Each Parameter IN AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	FixedParameters = ClientFixedParametersWithoutTemporaryParameters(Parameters);
	Return FixedParameters;
	
EndFunction

// It returns the structure of the parameters
// required for the client configuration code working. 
//
Function ClientWorkParameters() Export
	
	Parameters = New Structure;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnAddParametersJobsClientLogicStandardSubsystems(Parameters);
	EndDo;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WorkClientParametersOnAdd");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WorkClientParametersOnAdd(Parameters);
	EndDo;
	
	AppliedParameters = New Structure;
	CommonUseOverridable.ClientWorkParameters(AppliedParameters);
	
	For Each Parameter IN AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	Return CommonUse.FixedData(Parameters);
	
EndFunction

// It returns the platform type in the string.
Function ServerPlatformTypeAsString() Export
	
	SystemInfo = New SystemInfo;
	
	If SystemInfo.PlatformType = PlatformType.Linux_x86 Then
		Return "Linux_x86";
		
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		Return "Linux_x86_64";
		
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86 Then
		Return "Windows_x86";
		
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
		Return "Windows_x86_64";
		
	ElsIf SystemInfo.PlatformType = Undefined Then
		Return Undefined;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Unknown platform type  ""%1""';ru='Неизвестный тип платформы ""%1""'"),
		String(SystemInfo.PlatformType));
	
EndFunction

// It returns the array of the client module names.
Function ArrayOfNamesOfClientModules() Export
	
	ClientModules = New Array;
	
	For Each CommonModule IN Metadata.CommonModules Do
		If CommonModule.Global Then
			Continue;
		EndIf;
		If CommonModule.ClientManagedApplication Then
			ClientModules.Add(CommonModule.Name);
		EndIf;
	EndDo;
	
	Return ClientModules;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// It sets the cancel state when creating desktop forms.
// It is required if it is
// necessary to interact with the user when launching the application (interactive processor).
//
// It is used from the similarly-named procedure in StandardSubsystemsClient module.
// Direct server call is useful for reducing server
// calls if it is known at preparing client parameters
// using ReUse module that interactive processing is not required.
//
// If direct call is made from the procedure
// of the client parameters receiving, then the client state will
// be updated automatically, otherwise you should do it
// manually on the client using the procedure with the similar name in the StandardSubsystemsClient module.
//
// Parameters:
//  Hide - Boolean. If it is True, the
//           state will be set if it is False,
//           the state will be cleared (after this
//           you can run the RefreshInterface method and desktop forms will be recreated).
//
Procedure HideDesktopOnStart(Hide = True) Export
	
	SetPrivilegedMode(True);
	
	CurrentParameters = New Map(SessionParameters.ClientParametersOnServer);
	
	If Hide = True Then
		CurrentParameters.Insert("HideDesktopOnStart", True);
		
	ElsIf CurrentParameters.Get("HideDesktopOnStart") <> Undefined Then
		CurrentParameters.Delete("HideDesktopOnStart");
	EndIf;
	
	SessionParameters.ClientParametersOnServer = New FixedMap(CurrentParameters);
	
EndProcedure

// It returns the structure of the parameters
// required for the client configuration code working at logout.
//
Function ClientWorkParametersOnComplete() Export
	
	Parameters = New Structure();
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsOnComplete");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnAddParametersJobsClientLogicStandardSubsystemsOnComplete(Parameters);
	EndDo;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WorkClientParametersOnAddOnComplete");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WorkClientParametersOnAddOnComplete(Parameters);
	EndDo;
	
	AppliedParameters = New Structure;
	CommonUseOverridable.ClientWorkParametersOnComplete(AppliedParameters);
	
	For Each Parameter IN AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	Return CommonUse.FixedData(Parameters);
	
EndFunction

// Only for internal use.
Procedure OnGettingErrorHandlersEvents() Export
	
	If Not ExclusiveMode() AND TransactionActive() Then
		Return;
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled()
	 OR Not CommonUseReUse.CanUseSeparatedData() Then
		// Cache autoupdate. Update reused values is required.
		
		If Not ExclusiveMode() Then
			Try
				SetExclusiveMode(True);
			Except
				Return;
			EndTry;
		EndIf;
		
		Try
			Constants.ServiceEventsParameters.CreateValueManager().Refresh();
		Except
			SetExclusiveMode(False);
			RefreshReusableValues();
			Raise;
		EndTry;
		
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// It returns False if there is no option to set exclusive mode.
Function ExclusiveModeSetupError() Export
	
	SetPrivilegedMode(True);
	
	Cancel = False;
	Try
		SetExclusiveMode(True);
		SetExclusiveMode(False);
	Except
		Cancel = True
	EndTry;
	
	Return Cancel;
	
EndFunction

// Only for internal use.
Function WriteErrorToEventLogMonitorAtStartOrExit(StopWork, Val Event, Val ErrorText) Export
	
	If Event = "Start" Then
		EventName = NStr("en='Application start';ru='Запуск программы'", CommonUseClientServer.MainLanguageCode());
		If StopWork Then
			ErrorDescriptionBegin = NStr("en='An exception case occurred when starting the application. Application start is aborted.';ru='Возникла исключительная ситуация при запуске программы. Запуск программы аварийно завершен.'");
		Else
			ErrorDescriptionBegin = NStr("en='An exception case occurred when starting the application.';ru='Возникла исключительная ситуация при запуске программы.'");
		EndIf;
	Else
		EventName = NStr("en='Application end';ru='Завершение программы'", CommonUseClientServer.MainLanguageCode());
		ErrorDescriptionBegin = NStr("en='An exception case occurred at the application exit.';ru='Возникла исключительная ситуация при завершении программы.'");
	EndIf;
	
	ErrorDescription = ErrorDescriptionBegin
		+ Chars.LF + Chars.LF
		+ ErrorText;
	WriteLogEvent(EventName, EventLogLevel.Error,,, ErrorText);
	Return ErrorDescriptionBegin;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with predefined data.

// It receives the predefined item reference by its full name.
//  Details - see CommonUseClientServer.PredefinedItem();
//
Function PredefinedItem(Val FullPredefinedName) Export
	
	Return StandardSubsystemsReUse.PredefinedItem(FullPredefinedName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Procedure RememberTemporaryParameters(Parameters)
	
	Parameters.Insert("TemporaryParameterNames", New Array);
	
	For Each KeyAndValue IN Parameters Do
		Parameters.TemporaryParameterNames.Add(KeyAndValue.Key);
	EndDo;
	
EndProcedure

Function ClientFixedParametersWithoutTemporaryParameters(Parameters)
	
	ClientParameters = Parameters;
	Parameters = New Structure;
	
	For Each TemporaryParameterName IN ClientParameters.TemporaryParameterNames Do
		Parameters.Insert(TemporaryParameterName, ClientParameters[TemporaryParameterName]);
		ClientParameters.Delete(TemporaryParameterName);
	EndDo;
	Parameters.Delete("TemporaryParameterNames");
	
	SetPrivilegedMode(True);
	
	Parameters.HideDesktopOnStart =
		SessionParameters.ClientParametersOnServer.Get(
			"HideDesktopOnStart") <> Undefined;
	
	SetPrivilegedMode(False);
	
	Return CommonUse.FixedData(ClientParameters);
	
EndFunction

#EndRegion
