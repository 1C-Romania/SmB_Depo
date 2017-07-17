
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	AddressForAccountPasswordRecovery = Parameters.AddressForAccountPasswordRecovery;
	CloseIfSuccessfulSynchronization           = Parameters.CloseIfSuccessfulSynchronization;
	InfobaseNode                    = Parameters.InfobaseNode;
	CompletingOfWorkSystem                   = Parameters.CompletingOfWorkSystem;
	
	If Not ValueIsFilled(InfobaseNode) Then
		
		If DataExchangeServer.IsSubordinateDIBNode() Then
			InfobaseNode = DataExchangeServer.MasterNode();
		Else
			DataExchangeServer.ShowMessageAboutError(NStr("en='Form parameters are not specified. Cannot open the form.';ru='Не заданы параметры формы. Форма не может быть открыта.'"), Cancel);
			Return;
		EndIf;
		
	EndIf;
	
	HasErrors = ((DataExchangeServer.MasterNode() = InfobaseNode) AND ConfigurationChanged());
	
	// We set form title.
	Title = NStr("en='Data synchronization with %1';ru='Синхронизация данных с ""%1""'");
	Title = StringFunctionsClientServer.SubstituteParametersInString(Title, String(InfobaseNode));
	
	IsInRoleAddChangeOfDataExchanges = Users.RolesAvailable("DataSynchronizationSetting");
	IsInRoleFullAccess = Users.InfobaseUserWithFullAccess();
	
	Items.PanelUpdateNeeded.CurrentPage           = ?(IsInRoleFullAccess, Items.NeededFullRightsUpdate, Items.LimitedRightsUpdateNeeded);
	Items.TextNeededUpdateFullRights.Title       = StringFunctionsClientServer.SubstituteParametersInString(Items.TextNeededUpdateFullRights.Title, InfobaseNode);
	Items.TextUpdateNeededLimitedRights.Title = StringFunctionsClientServer.SubstituteParametersInString(Items.TextUpdateNeededLimitedRights.Title, InfobaseNode);
	
	Items.PasswordForgotten.Visible = Not IsBlankString(AddressForAccountPasswordRecovery);
	
	DataSynchronizationDisabled = False;
	PerformDataSending      = False;
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS")
		AND DataExchangeReUse.ThisIsOfflineWorkplace() Then
		
		ModuleOfflineWorkService = CommonUse.CommonModule("OfflineWorkService");
		DontRecallOnLongSynchronization = Not ModuleOfflineWorkService.QuestionAboutLongSynchronizationSettingCheckBox();
		
	Else
		DontRecallOnLongSynchronization = True;
	EndIf;
	
	ExchangeMessageTransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
	
	// When exchanging in distributed infobase by web service we
	// always override the authentication parameters (user and password) saved in the infobase.
	// When exchanging by web service for nonRIB exchanges the authentication
	// parameters (password) are overrided (asked) only if the password is not saved in the infobase.
	
	UseCurrentUserForAuthentication = False;
	UseSavedAuthenticationParameters    = False;
	PasswordSynchronizationIsSetTo                          = False;
	WSPassword                                          = "";
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.WS Then
		
		If DataExchangeReUse.ThisIsDistributedInformationBaseNode(InfobaseNode) Then
			// This is RIB and exchange by WS, we use the current user and password from session.
			UseCurrentUserForAuthentication = True;
			PasswordSynchronizationIsSetTo = DataExchangeServer.PasswordSynchronizationDataSet(InfobaseNode);
			If PasswordSynchronizationIsSetTo Then
				WSPassword = DataExchangeServer.PasswordSynchronizationData(InfobaseNode);
			EndIf;
			
		Else
			// This is not a RIB, we read data from transport settings.
			TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
			PasswordSynchronizationIsSetTo = TransportSettings.WSRememberPassword;
			If PasswordSynchronizationIsSetTo Then
				UseSavedAuthenticationParameters = True;
				WSPassword = TransportSettings.WSPassword;
			Else
				// Use data from the session only if it is not in the register.
				PasswordSynchronizationIsSetTo = DataExchangeServer.PasswordSynchronizationDataSet(InfobaseNode);
				If PasswordSynchronizationIsSetTo Then
					UseSavedAuthenticationParameters = True;
					WSPassword = DataExchangeServer.PasswordSynchronizationData(InfobaseNode);
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;

	// We set the current script of exchange work.
	If HasErrors Then
		ScenarioWhenThereAreErrorsOnStartup();
		
	ElsIf ExchangeMessageTransportKind <> Enums.ExchangeMessagesTransportKinds.WS Then
		// Means of transport - is not web
		DataExchangeScenarioNormal();
		
	Else
		
		PerformDataSending = InformationRegisters.InfobasesNodesCommonSettings.PerformDataSending(InfobaseNode);
		
		Items.GroupWarningsOnLongSynchronization.Visible = Not DontRecallOnLongSynchronization;
		Items.GroupPasswordRequest.Visible                     = Not PasswordSynchronizationIsSetTo;
		
		If PasswordSynchronizationIsSetTo AND DontRecallOnLongSynchronization Then
			// Immediately on exchange execution
			If PerformDataSending Then
				ExchangeScenarioOverWebService_SendingGettingSending();
			Else
				ExchangeScenarioOverWebService();
			EndIf;
			
		Else
			If PerformDataSending Then
				ScriptSharingViaWebServiceRequestingPassword_SendingGettingSending();
			Else
				ScriptSharingViaWebServiceRequestingPassword();
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not DataExchangeReUse.ThisIsOfflineWorkplace() Then
		CheckVersionDifference = True;
	EndIf;
	
	WindowOptionsKey = ?(PasswordSynchronizationIsSetTo AND DontRecallOnLongSynchronization, "PasswordSynchronizationIsSetTo", "") + "/" + ?(DontRecallOnLongSynchronization, "DontRecallOnLongSynchronization", "");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	SaveFlagQuestionAboutLongSynchronization();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoToEventLogMonitor(Command)
	
	FormParameters = GetEventLogMonitorDataFilterStructureData(InfobaseNode);
	OpenForm("DataProcessor.EventLogMonitor.Form", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	Close();
	DataExchangeClient.SetConfigurationUpdate(CompletingOfWorkSystem);
EndProcedure

&AtClient
Procedure PasswordForgotten(Command)
	
	DataExchangeClient.OnInstructionOpenHowToChangeDataSynchronizationPassword(AddressForAccountPasswordRecovery);
	
EndProcedure

&AtClient
Procedure RunExchange(Command)
	
	GoNextExecute();
	
EndProcedure

&AtClient
Procedure ContinueSynchronization(Command)
	
	GoToNumber = GoToNumber - 1;
	SetGoToNumber(GoToNumber + 1);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SUPPLIED PART
////////////////////////////////////////////////////////////////////////////////

&AtClient
Procedure GoNextExecute()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Execute the transition event handlers.
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Set the display of pages.
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.DataExchangeExecution.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Go to event handlers.
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// Handler OnSkipForward.
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				AND Not GoToRow.LongOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongOperation AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// Handler LongOperationProcessing.
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			If VersionsDifferenceErrorOnReceivingData.IsError Then
				
				HandleVersionDifferencesError();
				Return;
				
			EndIf;
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

// Adds new row to the end of the current step table.
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Step serial number that matches
//  to the current step.
//  MainPageName (mandatory) - String. The "MainPanel" panel page name
//  that matches to the current number of step.
//  HandlerNameOnOpen (optional) - String. Function handler name of the
//  current assistant page opening event.
//  LongOperation (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default -
//           False.
// 
&AtServer
Procedure GoToTableNewRow(
									GoToNumber,
									MainPageName,
									OnOpenHandlerName = "",
									LongOperation = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	
	NewRow.GoNextHandlerName = "";
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongOperation = LongOperation;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

// Adds new row to the end of the current step table with going to next.
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Step serial number that matches
//  to the current step.
//  MainPageName (mandatory) - String. The "MainPanel" panel page name
//  that matches to the current number of step.
//  HandlerNameOnOpen (optional) - String. Function handler name of the
//  current assistant page opening event.
//  HandlerNameOnGoNext (optional) - String. Handler function name of the
//  going to the next assistant page event.
//  LongOperation (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default -
//           False.
// 
&AtServer
Procedure StepTableNewRowGoToNext(
									GoToNumber,
									MainPageName,
									OnOpenHandlerName = "",
									GoNextHandlerName = "")
	
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongOperation = False;
	NewRow.LongOperationHandlerName = "";
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item IN FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PREDEFINED PART
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS

&AtClient
Procedure LongOperationIdleHandler()
	
	LongOperationCompletedWithError = False;
	ErrorInfo = "";
	
	AuthenticationParameters = ?(UseSavedAuthenticationParameters,
		Undefined,
		New Structure("UseCurrentUser", UseCurrentUserForAuthentication));
	
	ActionState = DataExchangeServerCall.LongOperationStateForInfobaseNode(
		LongOperationID,
		InfobaseNode,
		AuthenticationParameters,
		ErrorInfo);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	Else
		
		If ActionState <> "Executed" Then
			
			LongOperationCompletedWithError = True;
			
			HasErrors = True;
			
		EndIf;
		
		LongOperation = False;
		LongOperationFinished = True;
		
		GoNextExecute();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetEventLogMonitorDataFilterStructureData(InfobaseNode)
	
	SelectedEvents = New Array;
	SelectedEvents.Add(DataExchangeServer.GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataImport));
	SelectedEvents.Add(DataExchangeServer.GetEventLogMonitorMessageKey(InfobaseNode, Enums.ActionsAtExchange.DataExport));
	
	DataExchangeStatusImport = DataExchangeServer.DataExchangeStatus(InfobaseNode, Enums.ActionsAtExchange.DataImport);
	DataExchangeStatusExport = DataExchangeServer.DataExchangeStatus(InfobaseNode, Enums.ActionsAtExchange.DataExport);
	
	Result = New Structure;
	Result.Insert("EventLogMonitorEvent", SelectedEvents);
	Result.Insert("StartDate",    min(DataExchangeStatusImport.StartDate, DataExchangeStatusExport.StartDate));
	Result.Insert("EndDate", Max(DataExchangeStatusImport.EndDate, DataExchangeStatusExport.EndDate));
	
	Return Result;
EndFunction

&AtClient
Procedure SaveFlagQuestionAboutLongSynchronization()
	
	Settings = Undefined;
	If SaveFlagQuestionAboutLongSynchronizationServer(NOT DontRecallOnLongSynchronization, Settings) Then
		ChangedSettings = New Array;
		ChangedSettings.Add(Settings);
		Notify("UserSettingsChanged", ChangedSettings, ThisObject);
	EndIf;
	
EndProcedure
	
&AtServerNoContext
Function SaveFlagQuestionAboutLongSynchronizationServer(Val Flag, Settings = Undefined)
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS")
		AND DataExchangeReUse.ThisIsOfflineWorkplace() Then
		
		ModuleOfflineWorkService = CommonUse.CommonModule("OfflineWorkService");
		WeMustSave = Flag <> ModuleOfflineWorkService.QuestionAboutLongSynchronizationSettingCheckBox();
		
		If WeMustSave Then
			ModuleOfflineWorkService.QuestionAboutLongSynchronizationSettingCheckBox(Flag, Settings);
		EndIf;
		
	Else
		WeMustSave = False;
	EndIf;
	
	Return WeMustSave;
EndFunction

&AtClient
Procedure HandleVersionDifferencesError()
	
	Items.DataExchangeExecution.CurrentPage = Items.ExchangeEnd;
	Items.ExchangeCompletionState.CurrentPage = Items.ErrorVersionDifferences;
	Items.ActionsPanel.CurrentPage = Items.ActionsContinueCancel;
	Items.ContinueSynchronization.DefaultButton = True;
	Items.DecorationErrorVersionDifferences.Title = VersionsDifferenceErrorOnReceivingData.ErrorText;
	CheckVersionDifference = False;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SECTION OF THE STEP EVENT HANDLERS

// Exchange via normal connection channels.

&AtClient
Function Attachable_OrdinaryDataImport_LongOperationProcessing(Cancel, GoToNext)
	
	OrdinaryDataImport_LongOperationProcessing(Cancel, InfobaseNode,
		ExchangeMessageTransportKind, VersionsDifferenceErrorOnReceivingData, CheckVersionDifference);
	
	If VersionsDifferenceErrorOnReceivingData.IsError Then
		
		Cancel = True;
		
	Else
		
		HasErrors = HasErrors OR Cancel;
		Cancel = False;
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure OrdinaryDataImport_LongOperationProcessing(Cancel, Val InfobaseNode,
	Val ExchangeMessageTransportKind, VersionsDifferenceErrorOnReceivingData, CheckVersionDifference)
	
	DataExchangeServer.InitializeVersionDifferencesCheckParameters(CheckVersionDifference);
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											True,
											False,
											ExchangeMessageTransportKind);
											
	VersionsDifferenceErrorOnReceivingData = DataExchangeServer.VersionsDifferenceErrorOnReceivingData();
	
EndProcedure

&AtClient
Function Attachable_OrdinaryDataExport_LongOperationProcessing(Cancel, GoToNext)
	
	OrdinaryDataExport_LongOperationProcessing(Cancel, InfobaseNode, ExchangeMessageTransportKind);
	
	HasErrors = HasErrors OR Cancel;
	Cancel = False;
	
EndFunction

&AtServerNoContext
Procedure OrdinaryDataExport_LongOperationProcessing(Cancel, Val InfobaseNode, Val ExchangeMessageTransportKind)
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											ExchangeMessageTransportKind);
	
EndProcedure

// Exchange via Web-service

&AtClient
Function Attachable_QueryUserPassword_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.RunExchange.DefaultButton = True;
	
EndFunction

&AtClient
Function Attachable_QueryUserPassword_OnGoingNext(Cancel)
	
	If IsBlankString(WSPassword) Then
		NString = NStr("en='Password is not specified.';ru='Не указан пароль.'");
		CommonUseClientServer.MessageToUser(NString,, "WSPassword",, Cancel);
		Return Undefined;
	EndIf;
	
	SaveFlagQuestionAboutLongSynchronization();
EndFunction

&AtClient
Function Attachable_ConnectionCheckExpectation_LongOperationProcessing(Cancel, GoToNext)
	
	CheckConnection();
	
EndFunction

&AtServer
Procedure CheckConnection()
	
	SetPrivilegedMode(True);
	
	AuthenticationParameters = ?(UseSavedAuthenticationParameters,
		Undefined,
		New Structure("UseCurrentUser, Password",
			UseCurrentUserForAuthentication, ?(PasswordSynchronizationIsSetTo, Undefined, WSPassword)));
	
	ConnectionParameters = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	
	If Not DataExchangeServer.IsConnectionToCorrespondent(InfobaseNode, ConnectionParameters, UserMessageAboutError) Then
		DataSynchronizationDisabled = True;
	EndIf;
	
	// We reset the password after connection checking.
	WSPassword = "";
EndProcedure

&AtClient
Function Attachable_DataImport_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	MessageFileIDInService = "";
	LongOperationID = "";
	
	ThereIsVersionDifferencesError = False;
	
	If Not DataSynchronizationDisabled Then
		
		AuthenticationParameters = ?(UseSavedAuthenticationParameters, Undefined,
			New Structure("UseCurrentUser", UseCurrentUserForAuthentication)
		);
		
		DataImport_LongOperationProcessing(
			Cancel,
			AuthenticationParameters);
		
		If VersionsDifferenceErrorOnReceivingData.IsError Then
			ThereIsVersionDifferencesError = True;
		EndIf;
		
	EndIf;
	
	If ThereIsVersionDifferencesError Then
		Cancel = True;
		
	Else
		HasErrors = HasErrors Or Cancel;
		Cancel = False;
		
	EndIf;
	
EndFunction

&AtServer
Procedure DataImport_LongOperationProcessing(
											Cancel,
											Val AuthenticationParameters)
	
	OperationStartDate = CurrentSessionDate();
	
	DataExchangeServer.InitializeVersionDifferencesCheckParameters(CheckVersionDifference);
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											True,
											False,
											Enums.ExchangeMessagesTransportKinds.WS,
											LongOperation,
											LongOperationID,
											MessageFileIDInService,
											True,
											AuthenticationParameters);
	
	VersionsDifferenceErrorOnReceivingData = DataExchangeServer.VersionsDifferenceErrorOnReceivingData();
	
EndProcedure

&AtClient
Function Attachable_DataImportLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImportLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		If LongOperationCompletedWithError Then
			
			DataExchangeServerCall.FixExchangeFinishedWithError(
											InfobaseNode,
											"DataImport",
											OperationStartDate,
											ErrorInfo);
			
		Else
			
			AuthenticationParameters = ?(UseSavedAuthenticationParameters,
				Undefined,
				New Structure("UseCurrentUser", UseCurrentUserForAuthentication));
			
			DataExchangeServerCall.ExecuteDataExchangeForInfobaseNodeFinishLongOperation(
											False,
											InfobaseNode,
											MessageFileIDInService,
											OperationStartDate,
											AuthenticationParameters);
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExport_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	MessageFileIDInService = "";
	LongOperationID = "";
	
	If Not DataSynchronizationDisabled Then
		
		AuthenticationParameters = ?(UseSavedAuthenticationParameters,
			Undefined,
			New Structure("UseCurrentUser", UseCurrentUserForAuthentication));
		
		DataExport_LongOperationProcessing(
												Cancel,
												InfobaseNode,
												LongOperation,
												LongOperationID,
												MessageFileIDInService,
												OperationStartDate,
												AuthenticationParameters);
		
	EndIf;
	
	HasErrors = HasErrors OR Cancel;
	
	Cancel = False;
	
EndFunction

&AtServerNoContext
Procedure DataExport_LongOperationProcessing(
											Cancel,
											Val InfobaseNode,
											LongOperation,
											ActionID,
											FileID,
											OperationStartDate,
											Val AuthenticationParameters)
	
	OperationStartDate = CurrentSessionDate();
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											Enums.ExchangeMessagesTransportKinds.WS,
											LongOperation,
											ActionID,
											FileID,
											True,
											AuthenticationParameters);
	
EndProcedure

&AtClient
Function Attachable_DataExportLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExportLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		If LongOperationCompletedWithError Then
			
			DataExchangeServerCall.FixExchangeFinishedWithError(
											InfobaseNode,
											"DataExport",
											OperationStartDate,
											ErrorInfo);
			
		Else
			
			DataExchangeServerCall.CommitDataExportExecutionInLongOperationMode(
											InfobaseNode,
											OperationStartDate);
			
		EndIf;
		
	EndIf;
	
EndFunction

//

&AtClient
Function Attachable_ExchangeEnd_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.ActionsPanel.CurrentPage = Items.ActionsClose;
	Items.FormClose.DefaultButton = True;
	
	ExchangeCompletedWithErrorPage = ?(IsInRoleAddChangeOfDataExchanges,
				Items.ExchangeCompletedWithErrorForAdministrator,
				Items.ExchangeCompletedWithError);
	
	If DataSynchronizationDisabled Then
		
		Items.ExchangeCompletionState.CurrentPage = Items.ExchangeEndWithConnectionError;
		
	ElsIf HasErrors Then
		
		If UpdateNeeded Or DataExchangeServerCall.UpdateSettingRequired() Then
			If IsInRoleFullAccess Then 
				Items.ActionsPanel.CurrentPage = Items.ActionsInstallClose;
				Items.InstallUpdate.DefaultButton = True;
			EndIf;
			Items.ExchangeCompletionState.CurrentPage = Items.UpdateNeeded;
		Else
			Items.ExchangeCompletionState.CurrentPage = ExchangeCompletedWithErrorPage;
		EndIf;
		
	Else
		
		Items.ExchangeCompletionState.CurrentPage = Items.ExchangeCompletedSuccessfully;
		
	EndIf;
	
	// We refresh all open dynamic lists.
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
EndFunction

&AtClient
Function Attachable_ExchangeEnd_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	Notify("DataExchangeCompleted");
	
	If CloseIfSuccessfulSynchronization
		AND Not DataSynchronizationDisabled
		AND Not HasErrors Then
		
		Close();
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SECTION OF STEP INITIALIZATION

&AtServer
Procedure DataExchangeScenarioNormal()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataSynchronizationExpectation",, True, "OrdinaryDataImport_LongOperationProcessing");
	GoToTableNewRow(2, "DataSynchronizationExpectation",, True, "OrdinaryDataExport_LongOperationProcessing");
	GoToTableNewRow(3, "ExchangeEnd", "ExchangeEnd_OnOpen", True, "ExchangeEnd_LongOperationProcessing");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverWebService()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataSynchronizationExpectation",, True, "WaitingForCheckOfConnection_HandleLongRunningOperation");
	GoToTableNewRow(2, "DataSynchronizationExpectation",, True, "DataImport_LongOperationProcessing");
	GoToTableNewRow(3, "DataSynchronizationExpectation",, True, "DataImportLongOperation_LongOperationProcessing");
	GoToTableNewRow(4, "DataSynchronizationExpectation",, True, "DataImportLongOperationFinish_LongOperationProcessing");
	GoToTableNewRow(5, "DataSynchronizationExpectation",, True, "DataExport_LongOperationProcessing");
	GoToTableNewRow(6, "DataSynchronizationExpectation",, True, "DataExportLongOperation_LongOperationProcessing");
	GoToTableNewRow(7, "DataSynchronizationExpectation",, True, "DataExportLongOperationFinish_LongOperationProcessing");
	GoToTableNewRow(8, "ExchangeEnd", "ExchangeEnd_OnOpen", True, "ExchangeEnd_LongOperationProcessing");
	
EndProcedure

&AtServer
Procedure ExchangeScenarioOverWebService_SendingGettingSending()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "DataSynchronizationExpectation",, True, "WaitingForCheckOfConnection_HandleLongRunningOperation");
	
	// sending
	GoToTableNewRow(2, "DataSynchronizationExpectation",, True, "DataExport_LongOperationProcessing");
	GoToTableNewRow(3, "DataSynchronizationExpectation",, True, "DataExportLongOperation_LongOperationProcessing");
	GoToTableNewRow(4, "DataSynchronizationExpectation",, True, "DataExportLongOperationFinish_LongOperationProcessing");
	
	// Get
	GoToTableNewRow(5, "DataSynchronizationExpectation",, True, "DataImport_LongOperationProcessing");
	GoToTableNewRow(6, "DataSynchronizationExpectation",, True, "DataImportLongOperation_LongOperationProcessing");
	GoToTableNewRow(7, "DataSynchronizationExpectation",, True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// sending
	GoToTableNewRow(8,  "DataSynchronizationExpectation",, True, "DataExport_LongOperationProcessing");
	GoToTableNewRow(9,  "DataSynchronizationExpectation",, True, "DataExportLongOperation_LongOperationProcessing");
	GoToTableNewRow(10, "DataSynchronizationExpectation",, True, "DataExportLongOperationFinish_LongOperationProcessing");
	
	GoToTableNewRow(11, "ExchangeEnd", "ExchangeEnd_OnOpen", True, "ExchangeEnd_LongOperationProcessing");
	
EndProcedure

&AtServer
Procedure ScriptSharingViaWebServiceRequestingPassword()
	
	GoToTable.Clear();
	
	StepTableNewRowGoToNext(1, "QueryUserPassword", "RequestUserPassword_WhenOpening", "RequestUserPassword_GoingFurther");
	GoToTableNewRow(2, "DataSynchronizationExpectation",, True, "WaitingForCheckOfConnection_HandleLongRunningOperation");
	GoToTableNewRow(3, "DataSynchronizationExpectation",, True, "DataImport_LongOperationProcessing");
	GoToTableNewRow(4, "DataSynchronizationExpectation",, True, "DataImportLongOperation_LongOperationProcessing");
	GoToTableNewRow(5, "DataSynchronizationExpectation",, True, "DataImportLongOperationFinish_LongOperationProcessing");
	GoToTableNewRow(6, "DataSynchronizationExpectation",, True, "DataExport_LongOperationProcessing");
	GoToTableNewRow(7, "DataSynchronizationExpectation",, True, "DataExportLongOperation_LongOperationProcessing");
	GoToTableNewRow(8, "DataSynchronizationExpectation",, True, "DataExportLongOperationFinish_LongOperationProcessing");
	GoToTableNewRow(9, "ExchangeEnd", "ExchangeEnd_OnOpen", True, "ExchangeEnd_LongOperationProcessing");
	
EndProcedure

&AtServer
Procedure ScriptSharingViaWebServiceRequestingPassword_SendingGettingSending()
	
	GoToTable.Clear();
	
	StepTableNewRowGoToNext(1, "QueryUserPassword", "RequestUserPassword_WhenOpening", "RequestUserPassword_GoingFurther");
	GoToTableNewRow(2, "DataSynchronizationExpectation",, True, "WaitingForCheckOfConnection_HandleLongRunningOperation");
	
	// sending
	GoToTableNewRow(3, "DataSynchronizationExpectation",, True, "DataExport_LongOperationProcessing");
	GoToTableNewRow(4, "DataSynchronizationExpectation",, True, "DataExportLongOperation_LongOperationProcessing");
	GoToTableNewRow(5, "DataSynchronizationExpectation",, True, "DataExportLongOperationFinish_LongOperationProcessing");
	
	// Get
	GoToTableNewRow(6, "DataSynchronizationExpectation",, True, "DataImport_LongOperationProcessing");
	GoToTableNewRow(7, "DataSynchronizationExpectation",, True, "DataImportLongOperation_LongOperationProcessing");
	GoToTableNewRow(8, "DataSynchronizationExpectation",, True, "DataImportLongOperationFinish_LongOperationProcessing");
	
	// sending
	GoToTableNewRow(9,  "DataSynchronizationExpectation",, True, "DataExport_LongOperationProcessing");
	GoToTableNewRow(10, "DataSynchronizationExpectation",, True, "DataExportLongOperation_LongOperationProcessing");
	GoToTableNewRow(11, "DataSynchronizationExpectation",, True, "DataExportLongOperationFinish_LongOperationProcessing");
	
	GoToTableNewRow(12, "ExchangeEnd", "ExchangeEnd_OnOpen", True, "ExchangeEnd_LongOperationProcessing");
	
EndProcedure

&AtServer
Procedure ScenarioWhenThereAreErrorsOnStartup()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "ExchangeEnd", "ExchangeEnd_OnOpen");
	
EndProcedure

#EndRegion
