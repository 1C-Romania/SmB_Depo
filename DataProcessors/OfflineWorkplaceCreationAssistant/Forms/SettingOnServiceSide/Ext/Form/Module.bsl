
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"ServiceTechnology.SaaS.DataExchangeSaaS\OnCreatingIndependentWorkingPlace");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnCreatingIndependentWorkingPlace();
	EndDo;
	
	ExchangePlanName = OfflineWorkService.OfflineWorkExchangePlan();
	
	// receive default values for the exchange plan.
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	FilterSsettingsAtNode = DataExchangeServer.FilterSsettingsAtNode(ExchangePlanName, "");
	
	Items.DataTransferRestrictionsDescriptionFull.Title = DataTransferRestrictionsDescriptionFull(ExchangePlanName, FilterSsettingsAtNode);
	
	InstructionForSettingOfflineWorkplace = OfflineWorkService.InstructionTextFromTemplate("InstructionForSettingOfflineWorkplace");
	
	ItemTitle = NStr("en = 'For an offline work on your computer the
							|platform ""1C: Enterprise 8.3"" version [PlatformVersion] should be installed'");
	ItemTitle = StrReplace(ItemTitle, "[PlatformVersion]", DataExchangeSaaS.RequiredPlatformVersion());
	Items.ExplanationalTitleAboutPlatformVersion.Title = ItemTitle;
	
	Object.OfflineWorkplaceDescription = OfflineWorkService.GenerateOfflineWorkplaceDescriptionByDefault();
	
	// Set the current table of transitions
	ScriptToCreateStandAloneWorkingPlace();
	
	ForceCloseForm = False;
	
	EventLogMonitorEventCreatingOfflineWorkplace = OfflineWorkService.EventLogMonitorEventCreatingOfflineWorkplace();
	
	SetupPackageFileName = OfflineWorkService.SetupPackageFileName();
	
	// User right settings for execution synchronization data
	
	Items.SettingRightUsers.Visible = False;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		SynchronizationUsers.Load(SynchronizationUsers());
		
		Items.SettingRightUsers.Visible = SynchronizationUsers.Count() > 1;
		
	EndIf;
	
	// ToolTip about the thin client
	InstructionAddressToSetThinClient = DataExchangeSaaS.InstructionAddressToSetThinClient();
	If IsBlankString(InstructionAddressToSetThinClient) Then
		Items.ImportInitialImageToComputerUser.ToolTipRepresentation = ToolTipRepresentation.None;
	EndIf;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Object.WSURLWebService = AddressOfApplicationOnWeb();
	
	// Position at the assistant's first step
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Items.MainPanel.CurrentPage = Items.End Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("CancelCreatingStandAloneWorkingPlace", ThisObject);
	
	WarningText = NStr("en = 'Do you want to cancel the offline workplace creating?'");
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, WarningText, "ForceCloseForm", NotifyDescription);
	
EndProcedure

// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	Try
		
		If JobCompleted(JobID) Then
			
			LongOperation = False;
			LongOperationFinished = True;
			GoToNext();
			
		Else
			AttachIdleHandler("LongOperationIdleHandler", 5, True);
		EndIf;
		
	Except
		LongOperation = False;
		SkipBack();
		ShowMessageBox(, NStr("en = 'Failed to execute the operation.'"));
		
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventCreatingOfflineWorkplace);
	EndTry;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure InstructionForSettingOfflineWorkplaceDocumentCreated(Item)
	
	// Print command visible
	If Not Item.Document.queryCommandSupported("Print") Then
		Items.InstructionBySettingOfflineWorkplacePrintInstructions.Visible = False;
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Supplied part

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	ChangeGoToNumber(-1);
	
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

// Overridable part

&AtClient
Procedure SetDataTransferRestriction(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.NodeConfigurationForm";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", ExchangePlanName);
	
	FormParameters = New Structure("FilterSsettingsOnNode, CorrespondentVersion", FilterSsettingsAtNode, "");
	Handler = New NotifyDescription("SetDataTransferRestrictionEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure SetDataTransferRestrictionEnd(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult <> Undefined Then
		
		For Each FilterSettings IN FilterSsettingsAtNode Do
			
			FilterSsettingsAtNode[FilterSettings.Key] = OpeningResult[FilterSettings.Key];
			
		EndDo;
		
		Items.DataTransferRestrictionsDescriptionFull.Title = DataTransferRestrictionsDescriptionFull(ExchangePlanName, FilterSsettingsAtNode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportInitialImageToComputerUser(Command)
	
	GetFile(InitialImageTemporaryStorageAddress, SetupPackageFileName);
	
EndProcedure

&AtClient
Procedure HowToInstallOrUpdate1CEnterprisePlatformVersion(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToInstallOrUpdate1CEnterprisePlatformVersion");
	FormParameters.Insert("Title", NStr("en = 'How to install or update the 1C:Enterprise platform version'"));
	
	OpenForm("DataProcessor.OfflineWorkplaceCreationAssistant.Form.AdditionalDetails", FormParameters, ThisObject, "HowToInstallOrUpdate1CEnterprisePlatformVersion");
	
EndProcedure

&AtClient
Procedure PrintInstructions(Command)
	
	Items.InstructionForSettingOfflineWorkplace.Document.execCommand("Print");
	
EndProcedure

&AtClient
Procedure SaveInstructionAs(Command)
	
	AddressInTemporaryStorage = GetTemplate();
	GetFile(AddressInTemporaryStorage, NStr("en = 'Instruction on setting the offline workplace.html'"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersAllowSynchronizationData.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("SynchronizationUsers.DataSynchronizationAllowed");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

&AtClient
Procedure ImportInitialImageToUserComputerExtendedTooltipNavigationRefsDataProcessor(Item, URL, StandardProcessing)
	
	If URL = "InstructionAddressToSetThinClient" Then
		StandardProcessing = False;
		GotoURL(InstructionAddressToSetThinClient);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
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
		
		AttachIdleHandler("ExecuteLongOperationHandler", 1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
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
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
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

&AtServer
Procedure GoToTableNewRow(GoToNumber,
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

&AtServer
Function GetTemplate()
	
	TempFileName = GetTempFileName();
	TextDocument = New TextDocument;
	TextDocument.SetText(InstructionForSettingOfflineWorkplace);
	TextDocument.Write(TempFileName);
	BinaryData = New BinaryData(TempFileName);
	DeleteFiles(TempFileName);
	
	Return PutToTempStorage(BinaryData, UUID);
	
EndFunction

&AtClient
Procedure CancelCreatingStandAloneWorkingPlace(Result, AdditionalParameters) Export
	
	If Object.OfflineWorkplace <> Undefined Then
		DataExchangeServerCall.DeleteSynchronizationSetting(Object.OfflineWorkplace);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part - SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure CreateInitialImageOfOfflineWorkspaceOnServer(Cancel)
	
	Try
		
		SelectedUsersSynchronization = SynchronizationUsers.Unload(
			New Structure("DataSynchronizationIsEnabled, AllowSynchronizationData", False, True), "User"
				).UnloadColumn("User");
		
		// Receive the assistant context in the form of structure
		ContextAssistant = New Structure;
		For Each Attribute IN Metadata.DataProcessors.OfflineWorkplaceCreationAssistant.Attributes Do
			ContextAssistant.Insert(Attribute.Name, Object[Attribute.Name]);
		EndDo;
		ContextAssistant.Insert("FilterSsettingsAtNode", FilterSsettingsAtNode);
		ContextAssistant.Insert("SelectedUsersSynchronization", SelectedUsersSynchronization);
		
		Result = LongActions.ExecuteInBackground(
						UUID,
						"OfflineWorkService.CreateOfflineWorkplaceInitialImage",
						ContextAssistant,
						NStr("en = 'Creating of an offline workplace initial image'"),
						True);
		
		InitialImageTemporaryStorageAddress           = Result.StorageAddress;
		InformationAboutSettingPackageTemporaryStorageAddress = Result.StorageAddressAdditional;
		
		If Result.JobCompleted Then
			
			InformationAboutSetupPackage = GetFromTempStorage(InformationAboutSettingPackageTemporaryStorageAddress);
			SetupPackageFileSize = InformationAboutSetupPackage.SetupPackageFileSize;
			
		Else
			
			LongOperation = True;
			JobID = Result.JobID;
			
		EndIf;
		
	Except
		Cancel = True;
		WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()), EventLogMonitorEventCreatingOfflineWorkplace);
		Return;
	EndTry;
	
EndProcedure

&AtServerNoContext
Function DataTransferRestrictionsDescriptionFull(Val ExchangePlanName, FilterSsettingsAtNode)
	
	Return DataExchangeServer.DataTransferRestrictionsDescriptionFull(ExchangePlanName, FilterSsettingsAtNode, "");
	
EndFunction

&AtClient
Function AddressOfApplicationOnWeb()
	
	ConnectionParameters = StringFunctionsClientServer.GetParametersFromString(InfobaseConnectionString());
	
	If Not ConnectionParameters.Property("ws") Then
		Raise NStr("en = 'You can create an offline workplace in the web client mode only.'");
	EndIf;
	
	Return ConnectionParameters.ws;
EndFunction

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure SkipBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorInEventLogMonitor(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtServer
Function SynchronizationUsers()
	
	Result = New ValueTable;
	Result.Columns.Add("User"); // Type: CatalogRef.Users
	Result.Columns.Add("DataSynchronizationIsEnabled", New TypeDescription("Boolean"));
	Result.Columns.Add("AllowSynchronizationData", New TypeDescription("Boolean"));
	
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.InfobaseUserID AS InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Not Users.DeletionMark
	|	AND Not Users.NotValid
	|	AND Not Users.Service
	|
	|ORDER BY
	|	Users.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.InfobaseUserID) Then
			
			IBUser = InfobaseUsers.FindByUUID(Selection.InfobaseUserID);
			
			If IBUser <> Undefined Then
				
				SettingsUser = Result.Add();
				SettingsUser.User = Selection.User;
				SettingsUser.DataSynchronizationIsEnabled = DataExchangeServer.DataSynchronizationIsEnabled(IBUser);
				SettingsUser.AllowSynchronizationData = SettingsUser.DataSynchronizationIsEnabled;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Transition events handlers

&AtClient
Function Attachable_SettingExportings_OnGoingNext(Cancel)
	
	If IsBlankString(Object.OfflineWorkplaceDescription) Then
		
		NString = NStr("en = 'Offline workplace name is not specified.'");
		CommonUseClientServer.MessageToUser(NString,,"Object.OfflineWorkplaceDescription",, Cancel);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_InitialImageCreationExpectation_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	JobID = Undefined;
	
	CreateInitialImageOfOfflineWorkspaceOnServer(Cancel);
	
	If Cancel Then
		
		//
		
	ElsIf Not LongOperation Then
		
		Notify("Create_StandAloneWorkingPlace");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_InitialImageCreationExpectationLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_InitialImageCreationExpectationLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		InformationAboutSetupPackage = GetFromTempStorage(InformationAboutSettingPackageTemporaryStorageAddress);
		SetupPackageFileSize = InformationAboutSetupPackage.SetupPackageFileSize;
		
		Notify("Create_StandAloneWorkingPlace");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_End_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ItemTitle = "[SetupPackageFileName] ([SetupPackageFileSize] [MeasurementUnit])";
	ItemTitle = StrReplace(ItemTitle, "[SetupPackageFileName]", SetupPackageFileName);
	ItemTitle = StrReplace(ItemTitle, "[SetupPackageFileSize]", Format(SetupPackageFileSize, "NFD=1; NG=3,0"));
	ItemTitle = StrReplace(ItemTitle, "[MeasurementUnit]", NStr("en = 'MB'"));
	
	Items.ImportInitialImageToComputerUser.Title = ItemTitle;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Initialize assistant's transitions

&AtServer
Procedure ScriptToCreateStandAloneWorkingPlace()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "Begin",                           "NavigationPageStart");
	GoToTableNewRow(2, "SettingExportings",                "NavigationPageContinuation",,, "ConfiguringExport_GoingFurther");
	GoToTableNewRow(3, "InitialImageCreationExpectation", "NavigationPageWait",,,,, True, "WaitingForInitialImage_ProcessingLongRunningOperation");
	GoToTableNewRow(4, "InitialImageCreationExpectation", "NavigationPageWait",,,,, True, "WaitingForInitialImageOfLongRunningOperation_LongTreatment");
	GoToTableNewRow(5, "InitialImageCreationExpectation", "NavigationPageWait",,,,, True, "WaitingForInitialImageOfLongRunningOperationEnding_ProcessingLongRunningOperation");
	GoToTableNewRow(6, "End",                        "NavigationPageEnd",, "End_WhenOpening");
	
EndProcedure

#EndRegion
