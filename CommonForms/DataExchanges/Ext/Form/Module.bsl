
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	If Not Users.RolesAvailable("DataSynchronizationSetting") Then
		Items.NodeStateListChangeInfobaseNode.Visible = False;
	EndIf;
	
	If Not Users.RolesAvailable("SystemAdministrator") Then
		Items.SentDataContent.Visible = False;
		Items.NodeStateListSentDataContent.Visible = False;
		Items.ListOfNodesStateContextMenuCompositionOfDataSent.Visible = False;
		Items.DeleteSynchronizationSetting.Visible = False;
		Items.ListOfNodesStateDeleteSynchronizationSetup.Visible = False;
	EndIf;
	
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	If ExchangePlanList.Count() = 0 Then
		MessageText = NStr("en = 'Possibility to configure the data synchronization is not provided.'");
		CommonUseClientServer.MessageToUser(MessageText,,,, Cancel);
		Return;
	EndIf;
	
	IsInRoleAddChangeOfDataExchanges = Users.RolesAvailable("DataSynchronizationSetting");
	If IsInRoleAddChangeOfDataExchanges Then
		AddCreateNewExchangeCommands();
	Else
		Items.GroupSynchronizationSetting.Visible = False;
		Items.InformationLabel.CurrentPage = Items.NoRightsForSynchronization;
		Items.GroupScriptsSynchronization.Visible = False;
		Items.GroupSynchronizationSettings.Visible = False;
	EndIf;
	
	RefreshNodeStateList();
	
	If Not IsInRoleAddChangeOfDataExchanges Or CommonUseReUse.DataSeparationEnabled() Then
		
		Items.PrefixSynchronizationIsNotCustomized.Visible = False;
		Items.PrefixOneSynchronization.Visible = False;
		Items.IBPrefix.Visible = False;
		
	Else
		
		IBPrefix = DataExchangeServer.InfobasePrefix();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshMonitorData", 60);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = "DataExchangeCompleted"
		OR EventName = "Write_DataExchangeScripts"
		OR EventName = "Write_ExchangePlanNode"
		OR EventName = "ObjectMappingAssistantFormClosed"
		OR EventName = "DataExchangeCreationAssistantFormClosed"
		OR EventName = "ClosedFormDataExchangeResults" Then
		
		// update monitor data
		RefreshMonitorData();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ConfigureDataSynchronization(Item)
	
	If AdjustableSynchronizations.Count() > 1 Then
		NotifyDescription = New NotifyDescription("SetDataSynchronizationEnd", ThisObject);
		ShowChooseFromMenu(NOTifyDescription, AdjustableSynchronizations, Item);
	Else
		SetDataSynchronizationEnd(AdjustableSynchronizations.Get(0), Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDataSynchronizationEnd(SelectedSynchronisation, AdditionalParameters) Export
	
	If SelectedSynchronisation <> Undefined Then
		
		DataExchangeClient.OpenDataExchangeSettingAssistant(SelectedSynchronisation.Value);
		
	EndIf;
	
EndProcedure


#EndRegion

#Region FormTableItemsEventsHandlersNodesStatusList

&AtClient
Procedure ListOfNodesStatusSelection(Item, SelectedRow, Field, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("NodesStatusListSelectionEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, NStr("en = 'Do you want to perform data synchronization?'"), QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure NodesStatusListSelectionEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		AutomaticSynchronization = (Items.NodeStateList.CurrentData.VariantExchangeData = "Synchronization");
		
		Recipient = Items.NodeStateList.CurrentData.InfobaseNode;
		
		DataExchangeClient.ExecuteDataExchangeCommandProcessing(Recipient, ThisObject,, AutomaticSynchronization);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NodeStateListOnActivateRow(Item)
	
	CurrentDataSet = Items.NodeStateList.CurrentData <> Undefined;
	
	Items.Setting.Enabled = CurrentDataSet;
	Items.NodeStateListChangeInfobaseNode.Enabled = CurrentDataSet;
	
	Items.DataExchangeExecutionButtonGroup.Enabled = CurrentDataSet;
	Items.ContextMenuStateListDiagnostics.Enabled = CurrentDataSet;
	Items.ScheduleSettingsButtonGroup.Enabled = CurrentDataSet;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ExecuteDataExchange(Command)
	
	RefreshMonitorData();
	
	CurrentData = ?(SynchronizationsAmount = 1, NodeStateList[0], Items.NodeStateList.CurrentData);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExchangeNode = CurrentData.InfobaseNode;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeNode", ExchangeNode);
	AdditionalParameters.Insert("AutomaticSynchronization", (CurrentData.VariantExchangeData = "Synchronization"));
	AdditionalParameters.Insert("InteractiveSending", False);
	
	ContinuationDescription = New NotifyDescription("ContinueSynchronizationExecution", ThisObject, AdditionalParameters);
	CheckConversionRulesCompatibility(ExchangeNode, ContinuationDescription);
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeInteractively(Command)
	
	CurrentData = ?(SynchronizationsAmount = 1, NodeStateList[0], Items.NodeStateList.CurrentData);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExchangeNode = CurrentData.InfobaseNode;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeNode", ExchangeNode);
	AdditionalParameters.Insert("InteractiveSending", True);
	
	ContinuationDescription = New NotifyDescription("ContinueSynchronizationExecution", ThisObject, AdditionalParameters);
	
	CheckConversionRulesCompatibility(ExchangeNode, ContinuationDescription);
	
EndProcedure

&AtClient
Procedure SetUpDataExchangeScripts(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	DataExchangeClient.CommandProcessingConfigureExchangeProcessingSchedule(CurrentData.InfobaseNode, ThisObject);
	
EndProcedure

&AtClient
Procedure RefreshMonitor(Command)
	
	RefreshMonitorData();
	
EndProcedure

&AtClient
Procedure ChangeInfobaseNode(Command)
	
	If SynchronizationsAmount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	ShowValue(, ExchangeNode);
	
EndProcedure

&AtClient
Procedure GoToDataImportEventsEventLogMonitor(Command)
	
	If SynchronizationsAmount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(ExchangeNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventsEventLogMonitor(Command)
	
	If SynchronizationsAmount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(ExchangeNode, ThisObject, "DataExport");
	
EndProcedure

&AtClient
Procedure OpenDataExchangeSettingAssistant(Command)
	
	DataExchangeClient.OpenDataExchangeSettingAssistant(Command.Name);
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	DataExchangeClient.SetConfigurationUpdate();
EndProcedure

&AtClient
Procedure CustomizeDataSynchronizationOne(Command)
	
	ConfigureDataSynchronization(Items.CustomizeDataSynchronizationOne);
	
EndProcedure

&AtClient
Procedure CustomizeDataSynchronizationNotCustomized(Command)
	
	ConfigureDataSynchronization(Items.CustomizeDataSynchronizationNotCustomized);
	
EndProcedure

&AtClient
Procedure CustomizeDataExchangeScriptsOne(Command)
	
	ExchangeNode = NodeStateList[0].InfobaseNode;
	
	SynchronizationScript = SynchronizationScriptByNode(ExchangeNode);
	FormParameters = New Structure;
	
	If SynchronizationScript = Undefined Then
		
		FormParameters.Insert("InfobaseNode", ExchangeNode);
		
	Else
		
		FormParameters.Insert("Key", SynchronizationScript);
		
	EndIf;
	
	OpenForm("Catalog.DataExchangeScripts.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure HideSuccessful(Command)
	
	HideSuccessfull = Not HideSuccessfull;
	
	Items.NodesStatusesListHideSuccessfull.Check = HideSuccessfull;
	
	RefreshNodeStateList(True);
	
EndProcedure

&AtClient
Procedure ExchangeInfo(Command)
	
	If SynchronizationsAmount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	RefToDetailedDescription = DetailedInformationAtServer(ExchangeNode);
	
	DataExchangeClient.OpenDetailedDescriptionOfSynchronization(RefToDetailedDescription);
	
EndProcedure

&AtClient
Procedure OpenResultsOneSynchronization(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNodes", UsedNodesArray(NodeStateList));
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", FormParameters);
	
EndProcedure

&AtClient
Procedure SentDataContent(Command)
	
	If SynchronizationsAmount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		
		If CurrentData = Undefined Then
			
			Return;
			
		EndIf;
		
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.OpenSentDataContent(ExchangeNode);
	
EndProcedure

&AtClient
Procedure DeleteSynchronizationSetting(Command)
	
	If SynchronizationsAmount = 1 Then
		
		ExchangeNode = NodeStateList[0].InfobaseNode;
		
	Else
		
		CurrentData = Items.NodeStateList.CurrentData;
		
		If CurrentData = Undefined Then
			
			Return;
			
		EndIf;
		
		ExchangeNode = CurrentData.InfobaseNode;
		
	EndIf;
	
	DataExchangeClient.DeleteSynchronizationSetting(ExchangeNode);
	
EndProcedure

&AtClient
Procedure ImportDataSynchronizationRules(Command)
	
	CurrentData = ?(SynchronizationsAmount = 1, NodeStateList[0], Items.NodeStateList.CurrentData);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExchangeNode = CurrentData.InfobaseNode;
	
	InformationAboutExchange = InformationAboutExchange(ExchangeNode);
	
	If InformationAboutExchange.UsedConversionRules Then
		DataExchangeClient.ImportDataSynchronizationRules(InformationAboutExchange.ExchangePlanName);
	Else
		RuleKind = PredefinedValue("Enum.DataExchangeRuleKinds.ObjectRegistrationRules");
		
		Filter              = New Structure("ExchangePlanName, RuleKind", InformationAboutExchange.ExchangePlanName, RuleKind);
		FillingValues = New Structure("ExchangePlanName, RuleKind", InformationAboutExchange.ExchangePlanName, RuleKind);
		DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "DataExchangeRules", 
			ExchangeNode, "ObjectRegistrationRules");
		
	EndIf;
	
EndProcedure
#EndRegion

#Region ServiceProceduresAndFunctions
&AtServer
Function InformationAboutExchange(Val InfobaseNode)
	
	Result = New Structure("ExchangePlanName,UsedConversionRules");
	Result.ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	Result.UsedConversionRules = DataExchangeReUse.IsTemplateOfExchangePlan(Result.ExchangePlanName, "ExchangeRules");
	Return Result;
	
EndFunction

&AtClient
Procedure RefreshMonitorData()
	
	NodeStateListRowIndex = GetRowCurrentIndex("NodeStateList");
	
	// Update the monitor tables at the server.
	RefreshNodeStateList();
	
	// Positioning the cursor.
	RunCursorPositioning("NodeStateList", NodeStateListRowIndex);
	
EndProcedure

&AtServer
Procedure RefreshNodeStateList(OnlyListRefresh = False)
	
	SSLExchangePlans = DataExchangeReUse.SSLExchangePlans();
	
	// Update data in nodes state list.
	NodeStateList.Load(DataExchangeServer.DataExchangeMonitorTable(SSLExchangePlans, "Code", HideSuccessfull));
	
	SetExchangesQuantity = DataExchangeServer.SetExchangesQuantity(SSLExchangePlans);
	
	If Not OnlyListRefresh Then
		
		CheckStateExchangeWithMainNode();
		
		If SynchronizationsAmount <> SetExchangesQuantity Then
			
			UpdateSynchronizationsCount(SetExchangesQuantity);
			
		ElsIf SynchronizationsAmount = 1 Then
			
			SetOneSynchronizationItems();
			
		EndIf;
		
		UpdateSynchronizationResultsCommands();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSynchronizationsCount(SetExchangesQuantity)
	
	SynchronizationsAmount = SetExchangesQuantity;
	SynchronizationPanel = Items.DataSynchronization;
	IsUpdateRight = AccessRight("UpdateDataBaseConfiguration", Metadata);
	
	If SynchronizationsAmount = 0 Then
		
		SynchronizationPanel.CurrentPage = SynchronizationPanel.ChildItems.SynchronizationIsNotCustomized;
		Title = NStr("en = 'Data synchronization'");
		
		If IsInRoleAddChangeOfDataExchanges Then
			Items.Move(Items.PopupCreate, Items.PanelCreateSynchronizationIsNotCustomized);
		EndIf;
		
	ElsIf SynchronizationsAmount = 1 Then
		
		Items.PageRefreshingRight.CurrentPage = ?(IsUpdateRight, 
			Items.PageRefreshingRight.ChildItems.InformationDataExchangePausedWithUpdateRight1,
			Items.PageRefreshingRight.ChildItems.InformationDataExchangePausedNoRefreshingRight1);
			
		SetOneSynchronizationItems();
		
		If IsInRoleAddChangeOfDataExchanges Then
			Items.Move(Items.PopupCreate, Items.BarCreateSynchronizationOne, Items.DeleteSynchronizationSetting);
		EndIf;
		
		SynchronizationPanel.CurrentPage = SynchronizationPanel.ChildItems.OneSynchronization;
		
	Else
		
		SynchronizationPanel.CurrentPage = SynchronizationPanel.ChildItems.FewSynchronizations;
		Title = NStr("en = 'List of configured data synchronizations'");
		
		Items.NodeStateListChangeInfobaseNode.Visible = IsInRoleAddChangeOfDataExchanges;
		Items.ConfigureExchangeProcessingSchedule.Visible = IsInRoleAddChangeOfDataExchanges;
		Items.ConfigureExchangeExecutionSchedule1.Visible = IsInRoleAddChangeOfDataExchanges;
		
		Items.InformationDataExchangePausedWithUpdateRight.Visible = IsUpdateRight;
		Items.InformationDataExchangePausedNoRefreshingRight.Visible = Not IsUpdateRight;
		
		TitleDataExchangePaused = ?(IsUpdateRight,
		Items.TitleDataExchangePausedWithUpdateRight,
		Items.TitleDataExchangePausedNoRefreshingRight);
		
		TitleDataExchangePaused.Title = StringFunctionsClientServer.PlaceParametersIntoString(TitleDataExchangePaused.Title, DataExchangeServer.MasterNode());
		
		If IsInRoleAddChangeOfDataExchanges Then
			Items.Move(Items.PopupCreate, Items.CommandBar, Items.ListOfNodesStateGroupOfButtonsRunningDataExchange);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSynchronizationResultsCommands()
	
	If SynchronizationsAmount <> 0 Then
		
		HeaderStructure = DataExchangeServer.HeaderStructureHyperlinkMonitorProblems(UsedNodesArray(NodeStateList));
		
		If SynchronizationsAmount = 1 Then
			
			FillPropertyValues(Items.OpenResultsOneSynchronization, HeaderStructure);
			
		ElsIf SynchronizationsAmount > 1 Then
			
			FillPropertyValues(Items.OpenDataSynchronizationResults, HeaderStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function UsedNodesArray(NodeStateList)
	
	ExchangeNodes = New Array;
	
	For Each NodeString IN NodeStateList Do
		ExchangeNodes.Add(NodeString.InfobaseNode);
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

&AtServer
Procedure SetOneSynchronizationItems()
	
	ConfiguredSynchronization = NodeStateList[0];
	
	If ConfiguredSynchronization.InfobaseNode = Undefined Then
		
		Raise NStr("en = 'Work of the data synchronization monitor in the undivided session is not supported'");
		
	EndIf;
	
	Items.SchedulePage.Picture = ?(ConfiguredSynchronization.ScheduleIsCustomized,
		PictureLib.ScheduledJob, New Picture);
	
	Title = DataExchangeServer.OverridableExchangePlanNodeName(ConfiguredSynchronization.InfobaseNode, "ExchangePlanNodeTitle");
	
	HaveRightToViewJournalRegistration = Users.RolesAvailable("ViewEventLogMonitor");
	
	If HaveRightToViewJournalRegistration Then
		
		Items.SuccessfulImportDate.Visible = True;
		Items.SuccessfulExportDate.Visible = True;
		Items.LabelDateReceived.Visible = False;
		Items.ShipmentDateLabel.Visible = False;
		
		Items.SuccessfulImportDate.Title = ConfiguredSynchronization.LastSuccessfulImportDatePresentation;
		Items.SuccessfulExportDate.Title = ConfiguredSynchronization.LastSuccessfulExportDatePresentation;
		
	Else
		
		Items.SuccessfulImportDate.Visible = False;
		Items.SuccessfulExportDate.Visible = False;
		Items.LabelDateReceived.Visible = True;
		Items.ShipmentDateLabel.Visible = True;
		
		Items.LabelDateReceived.Title = ConfiguredSynchronization.LastSuccessfulImportDatePresentation;
		Items.ShipmentDateLabel.Title = ConfiguredSynchronization.LastSuccessfulExportDatePresentation;
		
	EndIf;
	
	BlankDate = Date(1, 1, 1);
	
	If ConfiguredSynchronization.LastSuccessfulExportDate <> ConfiguredSynchronization.LastExportDate
		Or ConfiguredSynchronization.LastExportDate <> BlankDate
		Or ConfiguredSynchronization.LastDataExportResult <> 0 Then
		
		HintOfExport = NStr("en = 'Data is
										|sent: %SendingDate% The last attempt: %AttemptData%'");
		HintOfExport = StrReplace(HintOfExport, "%SendingDate%", ConfiguredSynchronization.LastSuccessfulExportDatePresentation);
		HintOfExport = StrReplace(HintOfExport, "%TryDate%", ConfiguredSynchronization.LastImportDatePresentation);
		
	Else
		
		HintOfExport = "";
		
	EndIf;
	
	If ConfiguredSynchronization.LastSuccessfulImportDate <> ConfiguredSynchronization.LastImportDate
		Or ConfiguredSynchronization.LastImportDate <> BlankDate
		Or ConfiguredSynchronization.LastDataImportResult <> 0 Then
		
		HintOfImport = NStr("en = 'Data is
										|received: %DateReveiced% The last attempt: %AttemptDate%'");
		HintOfImport = StrReplace(HintOfImport, "%DateReceived%", ConfiguredSynchronization.LastSuccessfulImportDatePresentation);
		HintOfImport = StrReplace(HintOfImport, "%TryDate%", ConfiguredSynchronization.LastExportDatePresentation);
		
	Else
		
		HintOfImport = "";
		
	EndIf;
	
	If ConfiguredSynchronization.LastDataImportResult =2 Then
		ConfiguredSynchronization.LastDataImportResult = ?(DataExchangeServer.DataExchangeIsExecutedWithWarnings(ConfiguredSynchronization.InfobaseNode), 2, 0);
	EndIf;
	
	StatusPicture(Items.DecorationImportStatus, ConfiguredSynchronization.LastDataImportResult, HintOfImport);
	StatusPicture(Items.DecorationExportStatus, ConfiguredSynchronization.LastDataExportResult, HintOfExport);
	
	Items.DecorationStatusEmpty.Visible = True;
	If ConfiguredSynchronization.LastDataImportResult <> 0
		Or (ConfiguredSynchronization.LastDataImportResult = 0
		AND ConfiguredSynchronization.LastDataExportResult = 0) Then
		
		Items.DecorationStatusEmpty.Visible = False;
		
	EndIf;
	
	Items.DecorationSuccessfullImporting.ToolTip = Items.DecorationImportStatus.ToolTip;
	Items.DecorationSuccessfulExport.ToolTip = Items.DecorationExportStatus.ToolTip;
	
	
	
	If DataExchangeReUse.ThisIsDistributedInformationBaseNode(ConfiguredSynchronization.InfobaseNode) Then
		
		Items.ExecuteDataExchangeInteractively2.Visible = False;
		
	EndIf;
	
	DataSynchronizationRulesDescription = DataExchangeServer.DataSynchronizationRulesDescription(ConfiguredSynchronization.InfobaseNode);
	Items.DataSynchronizationRulesDescription.Height = StrLineCount(DataSynchronizationRulesDescription);
	
	InfobaseNodeSchedule = InfobaseNodeSchedule(ConfiguredSynchronization.InfobaseNode);
	
	If InfobaseNodeSchedule <> Undefined Then
		
		DataSynchronizationSchedule = InfobaseNodeSchedule;
		
	Else
		
		DataSynchronizationSchedule = NStr("en = 'Synchronization schedule is not configured'");;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AddCreateNewExchangeCommands()
	
	IsRightForDataAdministration = AccessRight("DataAdministration", Metadata);
	
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	
	For Each Item IN ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		ThisIsExchangePlanXDTO = DataExchangeReUse.ThisIsExchangePlanXDTO(ExchangePlanName);
		
		If Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase Then
			ParentGroup = Items.DIBPopup;
		ElsIf ThisIsExchangePlanXDTO Then
			ParentGroup = Items.XDTOPopup;
		Else
			ParentGroup = Items.PopupOther;
		EndIf;
		
		If ExchangePlanManager.UseDataExchangeCreationAssistant() 
			AND DataExchangeReUse.CanUseExchangePlan(ExchangePlanName) Then
			
			PossibleExchangeSettingsList = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "ExchangeSettingsVariants");
			
			If PossibleExchangeSettingsList.Count() > 0 Then
				
				SummingGroup = ParentGroup;
				
				If PossibleExchangeSettingsList.Count() > 1 Then 
					
					SummingGroup = Items.Add(ExchangePlanName, Type("FormGroup"), ParentGroup);
					
					SummingGroup.Type       = FormGroupType.ButtonGroup;
					SummingGroup.Title = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "CorrespondentConfigurationName");
					
					If ExchangePlanList.Count() > 1 Then
						SummingGroup.Type = FormGroupType.Popup;
					EndIf;
					
				EndIf;
				
				For Each PredefinedSetting IN PossibleExchangeSettingsList Do
					
					CommandName = ExchangePlanName + "SettingID" + PredefinedSetting;
					CommandTitle    = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, 
					                                                                      "CommandTitleForCreationOfNewDataExchange",
					                                                                      PredefinedSetting);
					
					CreateCommandAndFormItem(CommandName, CommandTitle, SummingGroup);
					
				EndDo;
				
				If ExchangePlanManager.CorrespondentSaaS() Then
					
					For Each PredefinedSetting IN PossibleExchangeSettingsList Do
						
						CommandName = ExchangePlanName + "SettingID" + PredefinedSetting + "CorrespondentSaaS";
						CommandTitle    = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, 
						                                                                      "CommandTitleForCreationOfNewDataExchange",
						                                                                      PredefinedSetting);
						
						CreateCommandAndFormItem(CommandName, CommandTitle + NStr("en = ' (in service)'"), SummingGroup);
						
					EndDo;
					
				EndIf;
				
			Else
				
				CommandName = ExchangePlanName + "SettingID";
				CommandTitle    = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, 
				                                                                      "CommandTitleForCreationOfNewDataExchange");
				CreateCommandAndFormItem(CommandName, CommandTitle, ParentGroup);
				
				If ExchangePlanManager.CorrespondentSaaS() Then
					CreateCommandAndFormItem(CommandName + "CorrespondentSaaS", 
					                            CommandTitle + NStr("en = ' (in service)'"),
					                            ParentGroup);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function GetRowCurrentIndex(TableName)
	
	// Return value of the function.
	RowIndex = Undefined;
	
	// Determining the cursor position during the monitor update.
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure RunCursorPositioning(TableName, RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the cursor position after the receipt of new data.
		If ThisObject[TableName].Count() <> 0 Then
			
			If RowIndex > ThisObject[TableName].Count() - 1 Then
				
				RowIndex = ThisObject[TableName].Count() - 1;
				
			EndIf;
			
			// Determining the cursor position
			Items[TableName].CurrentRow = ThisObject[TableName][RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
	// If string did not located set first string as current.
	If Items[TableName].CurrentRow = Undefined
		AND ThisObject[TableName].Count() <> 0 Then
		
		Items[TableName].CurrentRow = ThisObject[TableName][0].GetID();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckStateExchangeWithMainNode()
	
	UpdateNeeded = DataExchangeServerCall.UpdateSettingRequired();
	
	Items.InformationPanelNeededUpdate1.Visible = UpdateNeeded;
	Items.InformationPanelNeededUpdate.Visible = UpdateNeeded;
	
	Items.ExecuteDataExchange2.Visible = Not UpdateNeeded;
	
EndProcedure

&AtServer
Function SynchronizationScriptByNode (InfobaseNode)
	
	ConfiguredScript = Undefined;
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	DataExchangeScripts.Ref
	|FROM
	|	Catalog.DataExchangeScripts AS DataExchangeScripts
	|WHERE
	|	DataExchangeScripts.ExchangeSettings.InfobaseNode = &InfobaseNode
	|	AND DataExchangeScripts.DeletionMark = FALSE";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		ConfiguredScript = Selection.Ref;
		
	EndIf;
	
	Return ConfiguredScript;
	
EndFunction

&AtServer
Function InfobaseNodeSchedule(InfobaseNode)
	
	JobSchedule = Undefined;
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	DataExchangeScripts.ScheduledJobGUID
	|FROM
	|	Catalog.DataExchangeScripts AS DataExchangeScripts
	|WHERE
	|	DataExchangeScripts.UseScheduledJob = TRUE
	|	AND DataExchangeScripts.ExchangeSettings.InfobaseNode = &InfobaseNode
	|	AND DataExchangeScripts.DeletionMark = FALSE";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		Selection.Next();
		
		ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(Selection.ScheduledJobGUID);
		If ScheduledJobObject <> Undefined Then
			JobSchedule = ScheduledJobObject.Schedule;
		EndIf;
		
	EndIf;
	
	Return JobSchedule;
	
EndFunction

&AtServer
Procedure StatusPicture(control, EventKind, ToolTip)

	If EventKind = 1 Then
		control.Picture = PictureLib.DataExchangeStatusError;
		control.Visible = True;
	ElsIf EventKind = 2 Then
		control.Picture = PictureLib.Warning;
		control.Visible = True;
	Else
		control.Visible = False;
	EndIf;
	
	control.ToolTip = ToolTip;
	
EndProcedure

&AtServer
Function DetailedInformationAtServer(ExchangeNode)
	
	ExchangePlanManager = ExchangePlans[ExchangeNode.Metadata().Name];
	
	ExchangeSettingsVariant = DataExchangeServer.SavedExchangePlanNodeSettingsVariant(ExchangeNode);
	RefToDetailedDescription = ExchangePlanManager.DetailedInformationAboutExchange(ExchangeSettingsVariant);
	
	Return RefToDetailedDescription;
	
EndFunction

&AtClient
Procedure ContinueSynchronizationExecution(Result, AdditionalParameters) Export
	
	If AdditionalParameters.InteractiveSending Then
		
		DataExchangeClient.OpenObjectMappingAssistantCommandProcessing(AdditionalParameters.ExchangeNode, ThisObject);
		
	Else
		
		DataExchangeClient.ExecuteDataExchangeCommandProcessing(AdditionalParameters.ExchangeNode,
			ThisObject,, AdditionalParameters.AutomaticSynchronization);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckConversionRulesCompatibility(Val ExchangePlanName, ContinuationProcessor)
	
	ErrorDescription = Undefined;
	If ConversionRulesAreCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription) Then
		
		ExecuteNotifyProcessing(ContinuationProcessor);
		
	Else
		
		Buttons = New ValueList;
		Buttons.Add("GoToRulesImport", NStr("en = 'Import rules'"));
		If ErrorDescription.ErrorKind <> "IncorrectConfiguration" Then
			Buttons.Add("Continue", NStr("en = 'Continue'"));
		EndIf;
		Buttons.Add("Cancel", NStr("en = 'Cancel'"));
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ContinuationProcessor", ContinuationProcessor);
		AdditionalParameters.Insert("ExchangePlanName", ExchangePlanName);
		Notification = New NotifyDescription("AfterCheckConversionRulesForCompatibility", ThisObject, AdditionalParameters);
		
		FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		FormParameters.Picture = ErrorDescription.Picture;
		FormParameters.OfferDontAskAgain = False;
		If ErrorDescription.ErrorKind = "IncorrectConfiguration" Then
			FormParameters.Title = NStr("en = 'Data can not be synchronized'");
		Else
			FormParameters.Title = NStr("en = 'Data can be synchronized incorrectly'");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCheckConversionRulesForCompatibility(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		If Result.Value = "Continue" Then
			
			ExecuteNotifyProcessing(AdditionalParameters.ContinuationProcessor);
			
		ElsIf Result.Value = "GoToRulesImport" Then
			
			DataExchangeClient.ImportDataSynchronizationRules(AdditionalParameters.ExchangePlanName);
			
		EndIf; // When "Cancel" do nothing.
		
	EndIf;
	
EndProcedure

&AtServer
Function ConversionRulesAreCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription)
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(ExchangePlanName);
	RulesInformation = Undefined;
	
	If DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRulesVersionsMismatch")
		AND ConversionRulesImportedFromFile(ExchangePlanName, RulesInformation) Then
		
	ConfigurationNameFromRules = Upper(RulesInformation.ConfigurationName);
	InfobaseConfigurationName = StrReplace(Upper(Metadata.Name), "BASE", "");
	If ConfigurationNameFromRules <> InfobaseConfigurationName Then
			
			ErrorDescription = New Structure;
			ErrorDescription.Insert("ErrorText", NStr("en = 'Data can not be synchronized because of using rules for the %1 applicatione. You should use rules from configuration or import correct rules set from file.'"));
			ErrorDescription.ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorDescription.ErrorText,
				RulesInformation.ConfigurationSynonymInRules);
			ErrorDescription.Insert("ErrorKind", "IncorrectConfiguration");
			ErrorDescription.Insert("Picture", PictureLib.Error32);
			Return False;
			
		EndIf;
		
		VersionInRulesWithoutAssembly    = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(RulesInformation.ConfigurationVersion);
		ConfigurationVersionWithoutAssembly = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(Metadata.Version);
		ComparisonResult          = CommonUseClientServer.CompareVersionsWithoutBatchNumber(VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
		
		If ComparisonResult <> 0 Then
			
			If ComparisonResult < 0 Then
				
				ErrorText = NStr("en = 'Data can be synchronized incorrectly because of using rules for the previous version of %1 applicatione (%2). It is recommended to use rules from configuration or import rules set designed for the current application version (%3).'");
				ErrorKind = "OutdatedConfigurationVersion";
				
			Else
				
				ErrorText = NStr("en = 'Data can be synchronized incorrectly because of using rules for newer version of the %1 applicatione (%2). It is recommended to update application version or use rules set designed for the current application version (%3).'");
				ErrorKind = "OutdatedRules";
				
			EndIf;
			
			ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorText, Metadata.Synonym,
					VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
			
			ErrorDescription = New Structure;
			ErrorDescription.Insert("ErrorText", ErrorText);
			ErrorDescription.Insert("ErrorKind", ErrorKind);
			ErrorDescription.Insert("Picture", PictureLib.Warning32);
			Return False;
			
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function ConversionRulesImportedFromFile(ExchangePlanName, RulesInformation)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ReadOutRules,
	|	DataExchangeRules.RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.RuleSourcesForDataExchange.File)
	|	AND DataExchangeRules.RulesImported = TRUE
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		RuleStructure = Selection.ReadOutRules.Get().Conversion;
		
		RulesInformation = New Structure;
		RulesInformation.Insert("ConfigurationName", RuleStructure.Source);
		RulesInformation.Insert("ConfigurationVersion", RuleStructure.SourceConfigurationVersion);
		RulesInformation.Insert("ConfigurationSynonymInRules", RuleStructure.SourceConfigurationSynonym);
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Procedure CreateCommandAndFormItem(CommandName, Title, Popup)
	
	Commands.Add(CommandName);
	Commands[CommandName].Title = Title + "...";
	Commands[CommandName].Action  = "OpenDataExchangeSettingAssistant";
	
	Items.Add(CommandName, Type("FormButton"), Popup);
	Items[CommandName].CommandName = CommandName;
	
EndProcedure

#EndRegion
