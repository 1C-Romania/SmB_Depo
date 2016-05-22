#Region FormEventsHandlers

// Overridable part

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If IsBlankString(Parameters.ExchangePlanName) Then
		Raise NStr("en='Data processor is not aimed for being used directly'");
	EndIf;
	
	// Data synchronization can be enabled by the exchange administrator only (for the subscriber).
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	If Not DataExchangeSaaSReUse.DataSynchronizationSupported() Then
		
		Raise NStr("en = 'Data synchronization is not supported for configuration!'");
		
	EndIf;
	
	ExchangePlanName              = Parameters.ExchangePlanName;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	CorrespondentDescription  = Parameters.CorrespondentDescription;
	CorrespondentEndPoint = Parameters.CorrespondentEndPoint;
	Prefix                     = Parameters.Prefix;
	CorrespondentPrefix       = Parameters.CorrespondentPrefix;
	CorrespondentVersion        = Parameters.CorrespondentVersion;
	
	ThisApplicationName = DataExchangeSaaS.GeneratePredefinedNodeDescription();
	
	// Receive correspondent node, create if necessary.
	CorrespondentCode = DataExchangeSaaS.ExchangePlanNodeCodeInService(CorrespondentDataArea);
	
	Correspondent = Undefined;
	
	// receive default values for the exchange plan.
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	If Parameters.Property("AdditionalSetting") Then
		ExchangeSettingsVariant = Parameters.AdditionalSetting;
	EndIf;
	
	RefToDetailedDescription = ExchangePlanManager.DetailedInformationAboutExchange(ExchangeSettingsVariant);
	
	NodesSettingForm = "";
	DefaultValuesConfigurationForm = "";
	CorrespondentInfobaseDefaultValueSetupForm = "";
	
	FilterSsettingsAtNode = DataExchangeServer.FilterSsettingsAtNode(ExchangePlanName, CorrespondentVersion);
	DefaultValuesAtNode = DataExchangeServer.DefaultValuesAtNode(ExchangePlanName, CorrespondentVersion, DefaultValuesConfigurationForm);
	CorrespondentInfobaseNodeDefaultValues = DataExchangeServer.CorrespondentInfobaseNodeDefaultValues(ExchangePlanName, CorrespondentVersion, CorrespondentInfobaseDefaultValueSetupForm);
	DataExchangeServer.CommonNodeData(ExchangePlanName, CorrespondentVersion, NodesSettingForm);
	
	NodeFiltersSettingsAvailable = FilterSsettingsAtNode.Count() > 0;
	NodeDefaultValuesAvailable = DefaultValuesAtNode.Count() > 0;
	CorrespondentInfobaseNodeDefaultValuesAvailable = CorrespondentInfobaseNodeDefaultValues.Count() > 0;
	
	Items.GroupDescriptionValuesByDefault.Visible = NodeDefaultValuesAvailable;
	Items.DetailsGroupValuesDefaultCorrespondent.Visible = CorrespondentInfobaseNodeDefaultValuesAvailable;
	Items.GroupDescriptionSettingsDataExport.Visible = NodeFiltersSettingsAvailable;
	
	ValuesDescriptionFullByDefault = ValuesDescriptionFullByDefault(ExchangePlanName, DefaultValuesAtNode, CorrespondentVersion);
	DescriptionValuesByDefaultCorrespondent = DescriptionValuesByDefaultCorrespondent(ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, CorrespondentVersion);
	
	AccountParametersExplainingTitle = ExchangePlanManager.AccountingSettingsSetupComment();
	AccountCorrespondentParametersExplainingTitle = DataExchangeServer.CorrespondentInfobaseAccountingSettingsSetupComment(ExchangePlanName, CorrespondentVersion);
	
	CorrespondentTables = DataExchangeServer.CorrespondentTablesForValuesByDefault(ExchangePlanName, CorrespondentVersion);
	
	// Set the assistant title
	Title = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'Setting the data synchronization with ""%1""'"), CorrespondentDescription);
	Items.DataSynchronizationDescription.Title = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'Description of data synchronization with ""%1""'"), CorrespondentDescription);
	
	EventLogMonitorEventDataSyncronizationSetting = DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting();
	
	NodesSettingFormContext = New Structure;
	
	GetStatsComparison = False;
	StatisticsIsEmpty = False;
	
	// Set the current table of transitions
	ScriptDataSynchronizationSettings();
	
	Modified = True;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClient.OfferToCreateBackups() Then
		
		Text = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Before you configure the synchronization it is recommended to <a href=""%1"">back up<a>.'"),
			"CreateBackup");
		
		Items.BackupLabel.Title = StringFunctionsClientServer.FormattedString(Text);
		
	EndIf;
	
	UserRepliedYesToMapping = False;
	
	// Get context description of the node setting form
	If NodeFiltersSettingsAvailable Then
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("GetDefaultValues");
		FormParameters.Insert("Settings", NodesSettingFormContext);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSettingForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[NodesSetupForm]", NodesSettingForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		NodesSettingFormContext    = SettingsForm.Context;
		DataExportSettingsDescription = SettingsForm.ContextDetails;
		
	EndIf;
	
	// Position at the assistant's first step
	GoToNumber = 0;
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	WarningText = NStr("en = 'Do you want to cancel the data synchronization setup?'");
	If Items.MainPanel.CurrentPage <> Items.Begin Then
		NotifyDescription = New NotifyDescription("SynchronizationSettingCancel", ThisObject);
	Else
		NotifyDescription = Undefined;
	EndIf;
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, WarningText, "ForceCloseForm", NotifyDescription);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DataContributor" Then
		
		DataStorageAddressCorrespondent = Parameter;
		
		OpenSettingFormValuesDefaultCorrespondent(Parameter);
		
	ElsIf EventName = "CorrespondentNodeDataReceived" Then
		
		OpenSettingFormDataExporting(Parameter);
		
	ElsIf EventName = "ClosingObjectMappingForm" Then
		
		StatisticsInformation_Key                   = Parameter.UniqueKey;
		StatisticsInformation_DataSuccessfullyImported = Parameter.DataSuccessfullyImported;
		
		GetStatsComparison = True;
		
		GoToNumber = 0;
		SetGoToNumber( PageNumber_ComparisonStatisticReceiving() );
		
	EndIf;
	
EndProcedure

// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	Try
		StatusOfSession = StatusOfSession(Session);
	Except
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventDataSyncronizationSetting);
		SkipBack();
		ShowMessageBox(, NStr("en = 'Failed to execute the operation.'"));
		Return;
	EndTry;
	
	If StatusOfSession = "Successfully" Then
		
		GoToNext();
		
	ElsIf StatusOfSession = "Error" Then
		
		SkipBack();
		
		ShowMessageBox(, NStr("en = 'Failed to execute the operation.'"));
		
	Else
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobTimeoutHandler()
	
	Try
		
		If JobCompleted(JobID) Then
			
			GoToNext();
			
		Else
			AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		EndIf;
		
	Except
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventDataSyncronizationSetting);
		SkipBack();
		ShowMessageBox(, NStr("en = 'Failed to execute the operation.'"));
	EndTry;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Supplied part

&AtClient
Procedure CommandNext(Command)
	
	GoToNext();
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	SkipBack();
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	
	ForceCloseForm = True;
	
	Close();
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure DataSynchronizationDescription(Command)
	
	DataExchangeClient.OpenDetailedDescriptionOfSynchronization(RefToDetailedDescription);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part

&AtClient
Procedure SetupDataExport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	FormParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
	FormParameters.Insert("Mode", "GetCorrespondentNodesCommonData");
	FormParameters.Insert("OwnerUuid", ThisObject.UUID);
	
	OpenForm("DataProcessor.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.Form.ReceiveCorrespondentData",
		FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure ExecuteValuesByDefaultCorrespondentSetting(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	FormParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
	FormParameters.Insert("Mode", "GetCorrespondentData");
	FormParameters.Insert("OwnerUuid", ThisObject.UUID);
	FormParameters.Insert("CorrespondentTables", CorrespondentTables);
	
	OpenForm("DataProcessor.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.Form.ReceiveCorrespondentData",
		FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure ExecuteSettingValuesDefault(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[DefaultValuesConfigurationForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[DefaultValuesSetupForm]", DefaultValuesConfigurationForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
	FormParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
	
	Handler = New NotifyDescription("SetDefaultValuesEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure SetDefaultValuesEnd(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		For Each Setting IN DefaultValuesAtNode Do
			
			DefaultValuesAtNode[Setting.Key] = OpeningResult[Setting.Key];
			
		EndDo;
		
		ValuesDescriptionFullByDefault = ValuesDescriptionFullByDefault(ExchangePlanName, DefaultValuesAtNode, CorrespondentVersion);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MapData(Command)
	
	OpenMappingForm();
	
EndProcedure

&AtClient
Procedure StatisticsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Supplied part

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
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visible
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying has not been defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingNext
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
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				AND Not GoToRow.LongOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying has not been defined.'");
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
		Raise NStr("en = 'Page for displaying has not been defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// handler LongOperationHandling
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
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

// Adds new row to the end of current transitions table
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Sequence number of transition that corresponds to the current transition step
//  MainPageName  (mandatory) - String. Name of the MainPanel panel page that corresponds to the current number of the transition 
//  NavigationPageName (mandatory) - String. Page name of the NavigationPanel panel, which corresponds to the current number of transition
//  DecorationPageName (optional) - String. Page name of the DecorationPanel panel, which corresponds to the current number of transition
//  DeveloperNameOnOpening (optional) - String. Name of the function-processor of the assistant current page open event
//  HandlerNameOnGoingNext (optional) - String. Name of the function-processor of the transition to the next assistant page event 
//  HandlerNameOnGoingBack (optional) - String. Name of the function-processor of the transition to assistant previous page event 
//  LongOperation (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default - False.
// 
&AtServer
Function GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongOperation = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongOperation = LongOperation;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
	Return NewRow;
EndFunction

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

&AtClient
Procedure SynchronizationSettingCancel(Result, AdditionalParameters) Export
	
	DeleteSynchronizationSettingAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Service procedures and functions

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure SkipBack()
	
	UserRepliedYesToMapping = False;
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServerNoContext
Function StatusOfSession(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessagesExchangeSessions.StatusOfSession(Session);
	
EndFunction

&AtServerNoContext
Procedure WriteErrorInEventLogMonitor(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServerNoContext
Function JobCompleted(Val JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure OpenSettingFormDataExporting(Val TempDataStorageAddressCorrespondent)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSettingForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[NodesSetupForm]", NodesSettingForm);
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("ConnectionType", "TempStorage");
	ConnectionParameters.Insert("TemporaryStorageAddress", TempDataStorageAddressCorrespondent);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
	FormParameters.Insert("ConnectionParameters", ConnectionParameters);
	FormParameters.Insert("Settings", NodesSettingFormContext);
	
	Handler = New NotifyDescription("OpenDataExportSettingFormEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenDataExportSettingFormEnd(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		NodesSettingFormContext = OpeningResult;
		
		DataExportSettingsDescription = OpeningResult.ContextDetails;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenSettingFormValuesDefaultCorrespondent(Val TempDataStorageAddressCorrespondent)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseDefaultValueSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[CorrespondentBaseDefaultValuesSetupForm]", CorrespondentInfobaseDefaultValueSetupForm);
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("ConnectionType", "TempStorage");
	ConnectionParameters.Insert("TemporaryStorageAddress", TempDataStorageAddressCorrespondent);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
	FormParameters.Insert("ExternalConnectionParameters", ConnectionParameters);
	FormParameters.Insert("DefaultValuesAtNode", CorrespondentInfobaseNodeDefaultValues);
	
	Handler = New NotifyDescription("OpenCorrespondentDefaultValuesSettingFormEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenCorrespondentDefaultValuesSettingFormEnd(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		For Each Setting IN CorrespondentInfobaseNodeDefaultValues Do
			
			CorrespondentInfobaseNodeDefaultValues[Setting.Key] = OpeningResult[Setting.Key];
			
		EndDo;
		
		DescriptionValuesByDefaultCorrespondent = DescriptionValuesByDefaultCorrespondent(ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, CorrespondentVersion);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ValuesDescriptionFullByDefault(Val ExchangePlanName, Val Settings, Val CorrespondentVersion)
	
	Return DataExchangeServer.ValuesDescriptionFullByDefault(ExchangePlanName, Settings, CorrespondentVersion);
	
EndFunction

&AtServerNoContext
Function DescriptionValuesByDefaultCorrespondent(Val ExchangePlanName, Val Settings, Val CorrespondentVersion)
	
	Return DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(ExchangePlanName, Settings, CorrespondentVersion);
	
EndFunction

&AtServer
Procedure ShowMessageAboutError(Cancel)
	
	CommonUseClientServer.MessageToUser(NStr("en = 'Failed to execute the operation.'"),,,, Cancel);
	
EndProcedure

&AtServer
Procedure DeleteSynchronizationSettingAtServer()
	
	DataExchangeSaaS.DeleteSettingExchange(ExchangePlanName, CorrespondentDataArea);
	
EndProcedure

//

&AtClient
Procedure OpenMappingForm()
	
	CurrentData = Items.StatisticsInformation.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("en = 'Impossible to perform matching for these data.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ReceiverTableName",            CurrentData.ReceiverTableName);
	FormParameters.Insert("TableSourceObjectTypeName", CurrentData.ObjectTypeAsString);
	FormParameters.Insert("ReceiverTableFields",           CurrentData.TableFields);
	FormParameters.Insert("SearchFieldsOfReceiverTable",     CurrentData.SearchFields);
	FormParameters.Insert("SourceTypeAsString",            CurrentData.SourceTypeAsString);
	FormParameters.Insert("ReceiverTypeAsString",            CurrentData.ReceiverTypeAsString);
	FormParameters.Insert("ThisIsObjectDeletion",             CurrentData.ThisIsObjectDeletion);
	FormParameters.Insert("DataSuccessfullyImported",         CurrentData.DataSuccessfullyImported);
	FormParameters.Insert("Key",                           CurrentData.Key);
	FormParameters.Insert("Synonym",                        CurrentData.Synonym);
	
	FormParameters.Insert("InfobaseNode",  Correspondent);
	FormParameters.Insert("ExchangeMessageFileName", ExchangeMessageFileName);
	
	FormParameters.Insert("PerformDataImport", False);
	
	OpenForm("DataProcessor.InfobaseObjectsMapping.Form", FormParameters, ThisObject, , , , ,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function TableRowID(Val FieldName, Val Key, FormDataCollection)
	
	CollectionItems = FormDataCollection.FindRows(New Structure(FieldName, Key));
	
	If CollectionItems.Count() > 0 Then
		
		Return CollectionItems[0].GetID();
		
	EndIf;
	
	Return Undefined;
EndFunction

&AtServer
Function GetIndexesOfRowsOfInformationStatisticsTable(RowKeys)
	
	RowIndexes = New Array;
	
	For Each Key IN RowKeys Do
		
		TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", Key));
		
		RowIndex = Object.StatisticsInformation.IndexOf(TableRows[0]);
		
		RowIndexes.Add(RowIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtClient
Procedure BackupLabelDataProcessorNavigationRefs(Item, URL, StandardProcessing)
	
	If URL = "CreateBackup" Then
		
		StandardProcessing = False;
		
		CommonUseClient.OfferUserToBackup();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Transition events handlers

// Page 1 (Start):
// Check filling of export settings
//
&AtClient
Function Attachable_Begin_OnGoingNext(Cancel)
	
	// Check attribute filling in form
	If NodeFiltersSettingsAvailable Then
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("Settings", NodesSettingFormContext);
		FormParameters.Insert("FillChecking");
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSettingForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[NodesSetupForm]", NodesSettingForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		If Not SettingsForm.CheckFilling() Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'It is necessary to specify the obligatory settings.'"),,, "DataExportSettingsDescription", Cancel);
			
		EndIf;
		
	EndIf;
	
EndFunction

//

// Page 2 (waiting):
// Create exchange setting
// in this base Record catalogs to export
// in this base Send message to correspondent:
//   Create exchange setting
//   in correspondent Record catalogs to export
//   in correspondent Downdload data in
//   correspondent Send current IB message about successful or unsuccessful
// operation After correspondent response receiving:
// Execute automatic data mapping, received from
// the correspondent Get mapping statistics
//
&AtClient
Function Attachable_DataAnalysisExpectation_LongOperationProcessing(Cancel, GoToNext)
	
	DataAnalysisExpectation_LongOperationProcessing(Cancel);
	
EndFunction

// Page 2 (waiting):
// Create exchange setting
// in this base Record catalogs to export
// in this base Send message to correspondent
&AtServer
Procedure DataAnalysisExpectation_LongOperationProcessing(Cancel)
	
	Try
		MethodParameters = New Structure;
		MethodParameters.Insert("ExchangePlanName", ExchangePlanName);
		MethodParameters.Insert("CorrespondentCode", CorrespondentCode);
		MethodParameters.Insert("CorrespondentDescription", CorrespondentDescription);
		MethodParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
		MethodParameters.Insert("CorrespondentEndPoint", CorrespondentEndPoint);
		MethodParameters.Insert("FilterSsettingsAtNode", NodesSettingFormContext);
		MethodParameters.Insert("Prefix", Prefix);
		MethodParameters.Insert("CorrespondentPrefix", CorrespondentPrefix);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.SetExchangeStep1",
			MethodParameters,
			NStr("en = 'Data synchronization setup between the applications in the Internet (step 1)'"));
		
		JobID = Result.JobID;
		TemporaryStorageAddress = Result.StorageAddress;
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 2 (wait): Wait for completion of background job
//
&AtClient
Function Attachable_DataAnalysisWaitBackgroundTask_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
	
EndFunction

// Page 2 (wait): Wait for response from correspondent
//
&AtClient
Function Attachable_DataAnalysisWaitLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	Output_Parameters = GetFromTempStorage(TemporaryStorageAddress);
	Correspondent = Output_Parameters.Correspondent;
	Session        = Output_Parameters.Session;
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

// Page 2 (waiting):
// After receiving the answer from correspondent:
// Execute automatic data mapping, received from
// the correspondent Get mapping statistics
//
&AtClient
Function Attachable_DataAnalysisWaitLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	RunAutomaticDataMapping(Cancel);
	
EndFunction

// Page 2 (waiting):
// Execute automatic data mapping, received from
// the correspondent Get mapping statistics
//
&AtServer
Procedure RunAutomaticDataMapping(Cancel)
	
	Try
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.RunAutomaticDataMapping",
			MethodParameters,
			NStr("en = 'Setting the data synchronization between the applications in the Internet (automatic data mapping)'"));
		
		JobID = Result.JobID;
		TemporaryStorageAddress = Result.StorageAddress;
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 2 (wait): Wait for completion of background job
//
&AtClient
Function Attachable_DataComparisonWaitBackgroundTask_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
	
EndFunction

// Page 2 (waiting):
//
&AtClient
Function Attachable_DataComparisonWaitBackgroundTaskEnd_LongOperationProcessing(Cancel, GoToNext)
	
	ImportComparisonStatistic_21(Cancel);
	
EndFunction

// Page 2 (waiting):
//
&AtServer
Procedure ImportComparisonStatistic_21(Cancel)
	
	Try
		
		Output_Parameters = GetFromTempStorage(TemporaryStorageAddress);
		
		AllDataMapped = Output_Parameters.AllDataMapped;
		ExchangeMessageFileName = Output_Parameters.ExchangeMessageFileName;
		StatisticsIsEmpty = Output_Parameters.StatisticsIsEmpty;
		
		Object.StatisticsInformation.Load(Output_Parameters.StatisticsInformation);
		Object.StatisticsInformation.Sort("Presentation");
		
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

//

// Page 2 (wait): Getting the mapping statistics (optionally)
//
&AtClient
Function Attachable_ComparisonStatisticReceivingWait_LongOperationProcessing(Cancel, GoToNext)
	
	If GetStatsComparison Then
		
		GetStatsComparison(Cancel);
		
	EndIf;
	
EndFunction

// Page 2 (wait): Getting the mapping statistics (optionally)
//
&AtClient
Function Attachable_ComparisonStatisticReceivingWaitBackgroundTask_LongOperationProcessing(Cancel, GoToNext)
	
	If GetStatsComparison Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	EndIf;
	
EndFunction

// Page 2 (wait): Getting the mapping statistics (optionally)
//
&AtClient
Function Attachable_ComparisonStatisticReceivingWaitBackgroundTaskEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If GetStatsComparison Then
		
		ImportComparisonStatistic_22(Cancel);
		
	EndIf;
	
EndFunction

// Page 2 (wait): Getting the mapping statistics (optionally)
//
&AtServer
Procedure GetStatsComparison(Cancel)
	
	Try
		
		TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", StatisticsInformation_Key));
		TableRows[0].DataSuccessfullyImported = StatisticsInformation_DataSuccessfullyImported;
		
		RowKeys = New Array;
		RowKeys.Add(StatisticsInformation_Key);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		MethodParameters.Insert("ExchangeMessageFileName", ExchangeMessageFileName);
		MethodParameters.Insert("StatisticsInformation", Object.StatisticsInformation.Unload());
		MethodParameters.Insert("RowIndexes", GetIndexesOfRowsOfInformationStatisticsTable(RowKeys));
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.GetStatsComparison",
			MethodParameters,
			NStr("en = 'Setting the data synchronization between the applications in the Internet (getting the mapping statistics)'"));
		
		JobID = Result.JobID;
		TemporaryStorageAddress = Result.StorageAddress;
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 2 (wait): Getting the mapping statistics (optionally)
//
&AtServer
Procedure ImportComparisonStatistic_22(Cancel)
	
	Try
		
		GetStatsComparison = False;
		
		Output_Parameters = GetFromTempStorage(TemporaryStorageAddress);
		
		AllDataMapped = Output_Parameters.AllDataMapped;
		
		Object.StatisticsInformation.Load(Output_Parameters.StatisticsInformation);
		Object.StatisticsInformation.Sort("Presentation");
		
		// Location on current list string
		Items.StatisticsInformation.CurrentRow = TableRowID("Key", StatisticsInformation_Key, Object.StatisticsInformation);
		
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

//

// Page 3: Data mapping by user
//
&AtClient
Function Attachable_DataMapping_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If StatisticsIsEmpty Then
		SkipPage = True;
	EndIf;
	
	Items.DataMappingStatePages.CurrentPage = ?(AllDataMapped,
		Items.MappingStateAllDataMapped,
		Items.MappingStateHasUnmappedData);
EndFunction

// Page 3: Data mapping by user
//
&AtClient
Function Attachable_DataMapping_OnGoingNext(Cancel)
	
	If Not AllDataMapped AND Not UserRepliedYesToMapping Then
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, "Continue");
		Buttons.Add(DialogReturnCode.No, "Cancel");
		
		Message = NStr("en = 'Not all data was mapped. Existence of
		                       |unmapped data can lead to identical catalog items (duplicates).
		                       |Continue?'");
		
		NotifyDescription = New NotifyDescription("HandleUserResponseWhenCompared", ThisObject);
		ShowQueryBox(NOTifyDescription, Message, Buttons,, DialogReturnCode.No);
		Cancel = True;
	EndIf;
	
EndFunction

&AtClient
Procedure HandleUserResponseWhenCompared(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		UserRepliedYesToMapping = True;
		GoToNext();
		
	EndIf;
	
EndProcedure

//

// Page 4 (wait):
// Data synchronization Import correspondent exchange
// message Export exchange message to correspondent (only
// catalogs) Send message to correspondent:
//   Import the exchange
//   message in correspondent Send current IB message about successful or unsuccessful import operation.
&AtClient
Function Attachable_DataSynchronizationExpectation_LongOperationProcessing(Cancel, GoToNext)
	
	DataSynchronizationExpectation_LongOperationProcessing(Cancel);
	
EndFunction

// Page 4 (wait):
// Data synchronization Import correspondent exchange
// message Export exchange message to correspondent (only
// catalogs) Send message to correspondent
//
&AtServer
Procedure DataSynchronizationExpectation_LongOperationProcessing(Cancel)
	
	Try
		
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		MethodParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.SynchronizeCatalogs",
			MethodParameters,
			NStr("en = 'Data synchronization setup between the applications in the Internet (catalogs synchronization)'"));
		
		JobID = Result.JobID;
		TemporaryStorageAddress = Result.StorageAddress;
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 4 (wait): Wait for completion of background job
//
&AtClient
Function Attachable_DataSynchronizationWaitBackgroundTask_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
	
EndFunction

// Page 4 (wait): Wait for correspondent response
//
&AtClient
Function Attachable_DataSynchronizationWaitLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	Session = GetFromTempStorage(TemporaryStorageAddress).Session;
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

//

// Page 4 (wait): Getting default values from correspondent
//
&AtClient
Function Attachable_DefaultValuesCheckForCorrespondent_LongOperationProcessing(Cancel, GoToNext)
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		GetCorrespondentData(Cancel);
		
	EndIf;
	
EndFunction

// Page 4 (wait): Getting default values from correspondent
//
&AtClient
Function Attachable_DefaultValuesCheckForCorrespondentLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

// Page 4 (wait): Getting default values from correspondent
//
&AtClient
Function Attachable_DefaultValuesCheckForCorrespondentLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		ImportCorrespondentDataInStorage(Cancel);
		
	EndIf;
	
EndFunction

// Page 4 (wait)
//
&AtServer
Procedure GetCorrespondentData(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Send a message to the correspondent
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeManagementInterface.MessageGetCorrespondentData());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.Tables = XDTOSerializer.WriteXDTO(CorrespondentTables);
		Message.Body.ExchangePlan = ExchangePlanName;
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

// Page 4 (wait)
//
&AtServer
Procedure ImportCorrespondentDataInStorage(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		CorrespondentData = InformationRegisters.SystemMessagesExchangeSessions.GetSessionData(Session);
		
		DataStorageAddressCorrespondent = PutToTempStorage(CorrespondentData, ThisObject.UUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

//

// Page 4, 6 (wait): Check of the correspondent accounting parameters
//
&AtClient
Function Attachable_CorrespondentAccountingParametersCheck_LongOperationProcessing(Cancel, GoToNext)
	
	GetCorrespondentAccountingParameters(Cancel);
	
EndFunction

// Page 4, 6 (wait): Check of the correspondent accounting parameters
//
&AtClient
Function Attachable_CorrespondentAccountingParametersCheckLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

// Page 4 (wait): Check of the correspondent accounting parameters
//
&AtClient
Function Attachable_CorrespondentAccountingParametersCheckLongOperationEnd4_LongOperationProcessing(Cancel, GoToNext)
	
	ErrorInfo = "";
	CorrespondentErrorMessage = "";
	
	ImportParametersAccountingCorrespondent(Cancel, ErrorInfo, CorrespondentErrorMessage);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If Not AccountingParametersSpecified Then
		LabelAccountingSettings = ErrorInfo;
	EndIf;
	
	If Not AccountCorrespondentParametersSet Then
		LabelCorrespondentAccountingSettings = CorrespondentErrorMessage;
	EndIf;
	
EndFunction

// Page 6 (wait): Check of the correspondent accounting parameters
//
&AtClient
Function Attachable_CorrespondentAccountingParametersCheckLongOperationEnd6_LongOperationProcessing(Cancel, GoToNext)
	
	ErrorInfo = "";
	CorrespondentErrorMessage = "";
	
	ImportParametersAccountingCorrespondent(Cancel, ErrorInfo, CorrespondentErrorMessage);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If Not AccountingParametersSpecified Then
		LabelAccountingSettings = ErrorInfo;
		Cancel = True;
	EndIf;
	
	If Not AccountCorrespondentParametersSet Then
		LabelCorrespondentAccountingSettings = CorrespondentErrorMessage;
		Cancel = True;
	EndIf;
	
EndFunction

// Page 4, 6 (wait)
//
&AtServer
Procedure GetCorrespondentAccountingParameters(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Send a message to the correspondent
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeManagementInterface.MessageGetCorrespondentAccountingParameters());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		Message.Body.CorrespondentCode = DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

// Page 4, 6 (wait)
//
&AtServer
Procedure ImportParametersAccountingCorrespondent(Cancel, ErrorInfo = "", CorrespondentErrorMessage = "")
	
	SetPrivilegedMode(True);
	
	Try
		
		// Correspondent account parameters
		CorrespondentData = InformationRegisters.SystemMessagesExchangeSessions.GetSessionData(Session).Get();
		
		AccountCorrespondentParametersSet = CorrespondentData.AccountingParametersSpecified;
		CorrespondentErrorMessage    = CorrespondentData.ErrorPresentation;
		
		If IsBlankString(CorrespondentErrorMessage) Then
			CorrespondentErrorMessage = NStr("en = 'Accounting parameters are not set in application ""%1"".'");
			CorrespondentErrorMessage = StringFunctionsClientServer.PlaceParametersIntoString(CorrespondentErrorMessage, CorrespondentDescription);
		EndIf;
		
		// Accounting parameters of this application
		AccountingParametersSpecified = DataExchangeServer.SystemAccountingSettingsAreSet(ExchangePlanName, Correspondent, ErrorInfo);
		
		If IsBlankString(ErrorInfo) Then
			ErrorInfo = NStr("en = 'Accounting parameters in this application are not specified.'");
		EndIf;
		
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
	Items.AccountingParameters.Visible = Not AccountingParametersSpecified;
	Items.AccountParametersCorrespondent.Visible = Not AccountCorrespondentParametersSet;
	
EndProcedure

//

// Page 5 (Rules of data receipt):
// If default values are not required and all accounting parameters are set then skip step.
//
&AtClient
Function Attachable_DataReceivingRules_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not NodeDefaultValuesAvailable
		AND Not CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		SkipPage = True;
		
	EndIf;
	
	Items.ThisApplicationNameRules.Visible = Items.GroupDescriptionValuesByDefault.Visible;
	Items.CorrespondentNameRules.Visible = Items.DetailsGroupValuesDefaultCorrespondent.Visible;
	
EndFunction

// Page 5 (Rules of data receipt):
// Set default values
//
&AtClient
Function Attachable_DataReceivingRules_OnGoingNext(Cancel)
	
	// Check attribute filling in the additional setting form
	If NodeDefaultValuesAvailable Then
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[DefaultValuesConfigurationForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[DefaultValuesSetupForm]", DefaultValuesConfigurationForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		If Not SettingsForm.CheckFilling() Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'It is necessary to specify the obligatory settings.'"),,, "ValuesDescriptionFullByDefault", Cancel);
			
		EndIf;
		
	EndIf;
	
	// Check attribute filling in the additional setting form
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		ConnectionParameters = New Structure;
		ConnectionParameters.Insert("ConnectionType", "TempStorage");
		ConnectionParameters.Insert("TemporaryStorageAddress", DataStorageAddressCorrespondent);
		
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", CorrespondentVersion);
		FormParameters.Insert("ExternalConnectionParameters", ConnectionParameters);
		FormParameters.Insert("DefaultValuesAtNode", CorrespondentInfobaseNodeDefaultValues);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseDefaultValueSetupForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[CorrespondentBaseDefaultValuesSetupForm]", CorrespondentInfobaseDefaultValueSetupForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		If Not SettingsForm.CheckFilling() Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'It is necessary to specify the obligatory settings for the second application.'")
				,,, "DescriptionValuesByDefaultCorrespondent", Cancel);
		EndIf;
		
	EndIf;
	
EndFunction

//

// Page 6 (Setting the accounting parameters):
// If default values are not required and all accounting parameters are set then skip step.
//
&AtClient
Function Attachable_ParametersSettingAccounting_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If AccountingParametersSpecified
		AND AccountCorrespondentParametersSet Then
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

//

// Page 7 (wait):
// Save user settings
// Record all data to export except
// catalogs Send message to correspondent:
//   Save user settings
//   Record all data to export except catalogs
//   Send current IB message about successful or unsuccessful operation
// Fill exchange in background from current IB.
//
&AtClient
Function Attachable_SettingsSaveExpected_LongOperationProcessing(Cancel, GoToNext)
	
	SettingsSaveExpected_LongOperationProcessing(Cancel);
	
EndFunction

// Page 7 (wait):
// Save user settings
// Record all data to export except
// catalogs Send message to correspondent
//
&AtServer
Procedure SettingsSaveExpected_LongOperationProcessing(Cancel)
	
	Try
		MethodParameters = New Structure;
		MethodParameters.Insert("Correspondent", Correspondent);
		MethodParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
		MethodParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
		MethodParameters.Insert("CorrespondentInfobaseNodeDefaultValues", CorrespondentInfobaseNodeDefaultValues);
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.DataSynchronizationSettingsBetweenApplicationsOnInternetSetupAssistant.SetExchangeStep2",
			MethodParameters,
			NStr("en = 'Data synchronization setup between the applications in the Internet (step 2)'"));
		
		JobID = Result.JobID;
		TemporaryStorageAddress = Result.StorageAddress;
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
EndProcedure

// Page 7 (wait): Wait for completion of background job
//
&AtClient
Function Attachable_SettingsSaveWaitBackgroundTask_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
	
EndFunction

// Page 7 (wait): Wait for correspondent response
//
&AtClient
Function Attachable_SettingsSaveWaitLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	Session = GetFromTempStorage(TemporaryStorageAddress).Session;
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

//

// Page 7 (wait): Fixing the creation of exchange setting in SM
//
&AtClient
Function Attachable_ExchangeSettingCreationFixing_LongOperationProcessing(Cancel, GoToNext)
	
	FixCreatingExchangeSettingsInServiceManager(Cancel);
	
EndFunction

// Page 7 (wait): Fixing the creation of exchange setting in SM
//
&AtClient
Function Attachable_ExchangeSettingCreationFixingLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	AttachIdleHandler("LongOperationIdleHandler", 5, True);
	
EndFunction

// Page 7 (wait): Fixing the creation of exchange setting in SM
//
&AtClient
Function Attachable_ExchangeSettingCreationFixingLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	Notify("Creating_DataSynchronization");
	
EndFunction

// Page 7 (wait): Fixing the creation of exchange setting in SM
//
&AtServer
Procedure FixCreatingExchangeSettingsInServiceManager(Cancel)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Send message to the service manager - include synchronization
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.MessageEnableSynchronization());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		// Send message to the service manager - request for synchronization between two applications
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.MessagePushTwoApplicationsSynchronization());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()),
			EventLogMonitorEventDataSyncronizationSetting);
		ShowMessageAboutError(Cancel);
		Return;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part: Initialization of assistant transitions

&AtServer
Procedure ScriptDataSynchronizationSettings()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Begin",                      "NavigationPageStart",,, "Start_WhenNext");
	
	// Receiving of the correspondent default values
	GoToTableNewRow(2, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "DefaultValuesForCheckupCorrespondent_LongOperationProcessing");
	GoToTableNewRow(3, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "CheckupDefaultValuesForCorrespondentLongOperation_LongOperationProcessing");
	GoToTableNewRow(4, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "DefaultValuesCheckupForCorrespondentLongOperationEnd_ProcessingLongOperation");
	GoToTableNewRow(5, "DataReceivingRules",    "NavigationPageContinuation",, "DataReceivingRules_AtOpening", "DataReceivingRules_OnGoingNext");
	
	// Creating the setting and automatic data mapping
	GoToTableNewRow(6, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "DataAnalysisWaiting_LongOperationProcessing");
	GoToTableNewRow(7, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "DataAnalysisBackgroundJobWait_LongOperationProcessing");
	GoToTableNewRow(8, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "DataAnalysisLongWaitAction_LongOperationProcessing");
	GoToTableNewRow(9, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "DataAnalysisWaitLongOperationEnd_LongOperationProcessing");
	GoToTableNewRow(10, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "WaitDataMappingOfBackgroundJob_LongOperationProcessing");
	GoToTableNewRow(11, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "DataMappingOfBackgroundJobWaitEnd_LongOperationProcessing");
	
	// Receiving the mapping statistics (optional)
	GoToTableNewRow(12, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "GetMappingStatisticsWaiting_LongOperationProcessing").Mark = "StatisticPage";
	
	GoToTableNewRow(13,  "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "WaitingGetStatisticsBackgroundJob_MappingLongOperationProcessing");
	GoToTableNewRow(14, "DataAnalysisExpectation",       "NavigationPageWait",,,,, True, "WaitGetStatisticsComparingBackgroundJobEnd_LongOperationProcessing");
	
	// Data mapping by user
	GoToTableNewRow(15, "DataMapping",         "NavigationPageContinuation",, "MappingData_OnOpen", "MappingData_WhenGoNext");
	
	// Catalog synchronization
	GoToTableNewRow(16, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "WaitSynchronizationData_LongOperationProcessing");
	GoToTableNewRow(17, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "WaitSynchronizationDataBackgroundJob_LongOperationProcessing");
	GoToTableNewRow(18, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "WaitSynchronizationDataLongOperation_LongOperationProcessing");
	
	// Correspondent accounting parameters check
	GoToTableNewRow(19, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "CheckupParametersAccountingCorrespondent_LongOperationProcessing");
	GoToTableNewRow(20, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "CheckupParametersAccountingCorrespondentLongOperation_LongOperationProcessing");
	GoToTableNewRow(21, "DataSynchronizationExpectation", "NavigationPageWait",,,,, True, "CheckOfAccountingParametersCorrespondentLongOperationEnd4_LongOperationProcessing");
	
	GoToTableNewRow(22, "ParametersSettingAccounting",    "NavigationPageContinuation",, "ParametersSettingAccounting_OnOpen");
	
	// Correspondent accounting parameters check
	GoToTableNewRow(23, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "CheckupParametersAccountingCorrespondent_LongOperationProcessing");
	GoToTableNewRow(24, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "CheckupParametersAccountingCorrespondentLongOperation_LongOperationProcessing");
	GoToTableNewRow(25, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "CheckupParametersAccountingCorrespondentLongOperationEnd6_ProcessingLongOperation");
	
	// Updating the setting and data registration for synchronization
	GoToTableNewRow(26, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "WaitSaveSettings_LongOperationProcessing");
	GoToTableNewRow(27, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "SettingsSaveBackgroundJob_LongOperationProcessing");
	GoToTableNewRow(28, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "WaitSaveSettingsLongOperationLongOperation_Processing");
	
	// Message sending to service manager for fixing of exchange setting fact
	GoToTableNewRow(29, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "FixingExchangeSettingsCreation_LongOperationProcessing");
	GoToTableNewRow(30, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "FixingExchangeSettingsLongOperation_LongOperationProcessing");
	GoToTableNewRow(31, "SettingsSaveExpected", "NavigationPageWait",,,,, True, "FixingCreationExchangeSettingsLongOperationEnd_ProcessingLongOperation");
	
	GoToTableNewRow(32, "End",                  "NavigationPageEnd");
	
EndProcedure

&AtServer
Function PageNumber_ComparisonStatisticReceiving()
	
	Rows = GoToTable.FindRows( New Structure("Mark", "StatisticPage") );
	If Rows.Count() > 0 Then
		Return Rows[0].GoToNumber;
	EndIf;
	
	Return 0;
EndFunction

#EndRegion
