////////////////////////////////////////////////////////////////////////////////////////////////////
// Form parameters:
//
//     InfobaseNode  - ExchangePlanRef - Ref on node of exchange plan which
// the assistant is executed for (exchange correspondent)
//
//     ProhibitExportOnlyChanged - Boolean - If it is true then only changed sending variant is not available
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ErrorText = Undefined;
	
	If Not DataExchangeSaaSReUse.DataSynchronizationSupported() Then
		ErrorText = NStr("en='Data synchronization is not supported for configuration!'");
		
	ElsIf Not Parameters.Property("InfobaseNode", Object.InfobaseNode) Then
		ErrorText = NStr("en='Data processor is not aimed for being used directly'");
		
	ElsIf Object.InfobaseNode.IsEmpty() Then
		ErrorText = NStr("en='Data exchange setup is not found.'");
		
	EndIf;
	
	If ErrorText<>Undefined Then
		Raise ErrorText;
	EndIf;
	
	// Set headers that depend on the node
	SetCorrespondentToTitle(ThisObject);
	
	ExchangePlanName = Object.InfobaseNode.Metadata().Name;
	ScriptJobsAssistantInteractiveExchange = ExchangePlans[ExchangePlanName].InitializeScriptJobsAssistantInteractiveExchange(Object.InfobaseNode);
	
	// Export addition
	InitializeAttributesAdditionsExportings();
	
	// We set a transition table depending on parameters
	GoToNumber = 0;
	
	If ExportAddition.ExportVariant = -1 Then
		ScriptWithoutAdding();
	Else
		FullScriptManually();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ForceCloseForm = False;
	
	// On the first step
	SetGoToNumber(1);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	ConfirmationText = NStr("en='Do you want to terminate data synchronization?'");
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, ConfirmationText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If LongOperationState <> Undefined Then
		CompleteBackgroundTasks(LongOperationState.ID);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	// Check for a export addition event. 
	If DataExchangeClient.ChoiceProcessingAdditionsExportings(ValueSelected, ChoiceSource, ExportAddition) Then
		// Event is processed, update the display of the typical
		SetSelectionAdditionsExportingsDescription();
	EndIf;
	
	RefreshFilter(ValueSelected);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

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
Procedure ExportAdditionExportVariant(Command)
	
	FillAdditionalRegistration();
	
	DataExchangeClient.OpenFormAdditionsExportingsContentData(ExportAddition, ThisObject);
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		DeleteProgramFilters();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearing(Command)
	
	HeaderText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Clear common filter?'");
	
	Notification = New NotifyDescription("ExportAdditionGeneralFilterClearingEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , ,HeaderText);
EndProcedure

&AtClient
Procedure ExportAdditionCleaningDetailedFilter(Command)
	
	HeaderText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Clear detailed filter?'");
	
	Notification = New NotifyDescription("ExportAdditionDetailedFilterClearingEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , ,HeaderText);
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistory(Command)
	
	// Arrange selection from the menu list, all variants of the saved settings
	VariantList = ExportAdditionHistorySettingsServer();
	
	// Add saving variant of the current
	Text = NStr("en='Save the current setting...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistorySelectionFromMenu", ThisObject);
	ShowChooseFromMenu(NOTifyDescription, VariantList, Items.ExportAdditionFilterHistory);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// The ChangeExportContent Page

&AtClient
Procedure ExportAdditionExportVariantOnChange(Item)
	
	ExportAdditionExportVariantSetVisible();
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralDocumentsFilterClick(Item)
	
	DataExchangeClient.OpenFormAdditionsExportingsAllDocuments(ExportAddition, ThisObject);
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClick(Item)
	
	DataExchangeClient.OpenFormAdditionsExportingsDetailedFilter(ExportAddition, ThisObject);
	
EndProcedure

&AtClient
Procedure ExportAdditionFilterByScriptNodeClick(Item)
	
	DataExchangeClient.OpenFormAdditionsExportingsScriptNode(ExportAddition, ThisObject);
	
EndProcedure

&AtClient
Procedure ExportAdditionNodeScriptFilterPeriodOnChange(Item)
	
	ExportAdditionUpdatePeriodScriptNode();
	
EndProcedure

&AtClient
Procedure ExportAdditionNodeScriptFilterPeriodClearing(Item, StandardProcessing)
	
	// Prohibit the period clearing
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ExportAdditionGeneralFilterClearingEnd(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	ExportAdditionClearingGeneralFilterServer();
EndProcedure

&AtServer
Procedure ExportAdditionClearingGeneralFilterServer()
	
	DataExchangeServer.InteractiveUpdateExportingsClearingGeneralFilter(ExportAddition);
	SetCommonFilterAdditionDescription();
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClearingEnd(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	ExportAdditionClearingDetailedFilterServer();
EndProcedure

&AtServer
Procedure ExportAdditionClearingDetailedFilterServer()
	DataExchangeServer.InteractiveUpdateExportingsClearingInDetail(ExportAddition);
	SetAdditionDescriptionInDetails();
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistorySelectionFromMenu(Val SelectedItem, Val AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingRepresentation = SelectedItem.Value;
	If TypeOf(SettingRepresentation)=Type("String") Then
		// Selected a variant - name of the previously saved setting.
		
		HeaderText = NStr("en='Confirmation'");
		QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Restore settings ""%1""?'"), SettingRepresentation
		);
		
		NotifyDescription = New NotifyDescription("ExportAdditionFiltersHistoryEnd", ThisObject, SettingRepresentation);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
		
	ElsIf SettingRepresentation = 1 Then
		// Saving variant is chosen, we open form of all settings
		DataExchangeClient.OpenFormAdditionsExportingsSaveSettings(ExportAddition, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionFiltersHistoryEnd(Response, SettingRepresentation) Export
	
	If Response = DialogReturnCode.Yes Then
		ExportAdditionSetSettingsServer(SettingRepresentation);
		ExportAdditionExportVariantSetVisible();
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportAdditionUpdatePeriodScriptNode()
	
	DataExchangeServer.InteractiveExportingsChangeSetScriptNodePeriod(ExportAddition);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

&AtServer
Procedure SetCorrespondentToTitle(TitleOwner)
	
	TitleOwner.Title = StringFunctionsClientServer.PlaceParametersIntoString(TitleOwner.Title, String(Object.InfobaseNode));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

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
	GoToRowsCurrent = GoToTable.FindRows(New Structure(
        "GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying has not been defined.'");
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
		GoToRows = GoToTable.FindRows( New Structure(
            "GoToNumber", GoToNumber - 1));
		If GoToRows.Count() > 0 Then
			GoToRow = GoToRows[0];
			// handler OnGoingNext
			If Not IsBlankString(GoToRow.GoNextHandlerName) AND Not GoToRow.LongOperation Then
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
		GoToRows = GoToTable.FindRows(New Structure(
			"GoToNumber", GoToNumber + 1));
		If GoToRows.Count() > 0 Then
			GoToRow = GoToRows[0];
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName) AND Not GoToRow.LongOperation Then
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
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure(
        "GoToNumber", GoToNumber));
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying has not been defined.'");
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
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure(
        "GoToNumber", GoToNumber));
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying has not been defined.'");
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

//
//  Adds new row to the end of current transitions table
//
//  Parameters:
//      GoToNumber             - Number  - Go serial number, that matches to the
//      current step of the MainPageName go                 - String - The MainPanel panel page name that matches to
//      the current number of the NavigationPageName step                - String - The NavigationPanel panel page name that matches
//      to the current number of the DecorationPageName step                - String - The DecorationPanel panel page name that matches
//      to the current number of the OnOpenHandlerName step           - String - Function handler name of the opening
//      event of the GoNextHandlerName current assistant page      - String - Function handler name of the going event
//      to the GoBackHandlerName next assistant page      - String - Function handler name of the going event
//      to previous page of the LongOperation assistant                  - Boolean - Shows displayed long operation page. False - show normal page.
//      LongOperationHandlerName    - String - Name of the long operation function handler
//
&AtServer
Procedure GoToTableNewRow(GoToNumber, MainPageName, NavigationPageName, 
    DecorationPageName = "",
    OnOpenHandlerName = "", GoNextHandlerName = "", GoBackHandlerName = "",
	LongOperation = False, LongOperationHandlerName = "")

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
		
		If TypeOf(Item)=Type("FormGroup") Then
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			If FormItemByCommandName<>Undefined Then
				Return FormItemByCommandName;
			EndIf;
			
		ElsIf TypeOf(Item)=Type("FormButton") AND Find(Item.CommandName, CommandName)>0 Then
			Return Item;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
EndFunction

&AtClient
Procedure GoToNext()
	ChangeGoToNumber(+1);
EndProcedure

&AtClient
Procedure SkipBack()
	ChangeGoToNumber(-1);
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
//  Export addition
//

&AtServer
Procedure InitializeAttributesAdditionsExportings()
	
	// Receive settings as a structure, settings will be saved implicitly to the form temporary storage
	SettingsAdditionsExportings = DataExchangeServer.InteractiveExportChange(
		Object.InfobaseNode, ThisObject.UUID, True
	);
		
	// Set form.
	// Convert to the form attribute of the DataProcessorObject type. Used to simplify data link with the form
	DataExchangeServer.InteractiveUpdateExportingsAttributeBySettings(ThisObject, SettingsAdditionsExportings, "ExportAddition");
	
	ScriptParametersAdditions = ExportAddition.ScriptParametersAdditions;
	
	// Reset interface by a specified script.
	
	// Special cases
	TypicalVariantsProhibited = Not ScriptParametersAdditions.VariantNoneAdds.Use
		AND Not ScriptParametersAdditions.VariantAllDocuments.Use
		AND Not ScriptParametersAdditions.VariantArbitraryFilter.Use;
		
	If TypicalVariantsProhibited Then
		If ScriptParametersAdditions.VariantAdditionally.Use Then
			// One variant by the node script is left
			Items.ExportAdditionExportVariantNodeString.Visible = True;
			Items.ExportAdditionExportVariantNode.Visible        = False;
			Items.IndentGroupsCustomDecoration.Visible           = False;
			ExportAddition.ExportVariant = 3;
		Else
			// There is no variant, select the check box of skipping page and exit
			ExportAddition.ExportVariant = -1;
			Items.VariantsAdditionsExportings.Visible = False;
			Return;
		EndIf;
	EndIf;
	
	// Set typical input fields
	Items.TypicalVariantAdditionsNone.Visible = ScriptParametersAdditions.VariantNoneAdds.Use;
	If Not IsBlankString(ScriptParametersAdditions.VariantNoneAdds.Title) Then
		Items.ExportAdditionExportVariant0.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantNoneAdds.Title;
	EndIf;
	Items.TypicalVariantAdditionsNoneExplanation.Title = ScriptParametersAdditions.VariantNoneAdds.Explanation;
	If IsBlankString(Items.TypicalVariantAdditionsNoneExplanation.Title) Then
		Items.TypicalVariantAdditionsNoneExplanation.Visible = False;
	EndIf;
	
	Items.TypicalVariantOfAdditionsDocuments.Visible = ScriptParametersAdditions.VariantAllDocuments.Use;
	If Not IsBlankString(ScriptParametersAdditions.VariantAllDocuments.Title) Then
		Items.ExportAdditionExportVariant1.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantAllDocuments.Title;
	EndIf;
	Items.TypicalVariantAdditionsDocumentsExplanation.Title = ScriptParametersAdditions.VariantAllDocuments.Explanation;
	If IsBlankString(Items.TypicalVariantAdditionsDocumentsExplanation.Title) Then
		Items.TypicalVariantAdditionsDocumentsExplanation.Visible = False;
	EndIf;
	
	Items.TypicalVariantAdditionsArbitrary.Visible = ScriptParametersAdditions.VariantArbitraryFilter.Use;
	If Not IsBlankString(ScriptParametersAdditions.VariantArbitraryFilter.Title) Then
		Items.ExportAdditionExportVariant2.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantArbitraryFilter.Title;
	EndIf;
	Items.TypicalVariantAdditionsArbitraryExplanation.Title = ScriptParametersAdditions.VariantArbitraryFilter.Explanation;
	If IsBlankString(Items.TypicalVariantAdditionsArbitraryExplanation.Title) Then
		Items.TypicalVariantAdditionsArbitraryExplanation.Visible = False;
	EndIf;
	
	Items.CustomVariantAdditions.Visible           = ScriptParametersAdditions.VariantAdditionally.Use;
	Items.PeriodGroupExportingsScriptNode.Visible         = ScriptParametersAdditions.VariantAdditionally.UsePeriodFilter;
	Items.ExportAdditionFilterOfScriptNode.Visible    = Not IsBlankString(ScriptParametersAdditions.VariantAdditionally.FormNameFilter);
	
	Items.ExportAdditionExportVariantNode.ChoiceList[0].Presentation = ScriptParametersAdditions.VariantAdditionally.Title;
	Items.ExportAdditionExportVariantNodeString.Title              = ScriptParametersAdditions.VariantAdditionally.Title;
	
	Items.CustomVariantExplanationWithAdditions.Title = ScriptParametersAdditions.VariantAdditionally.Explanation;
	If IsBlankString(Items.CustomVariantExplanationWithAdditions.Title) Then
		Items.CustomVariantExplanationWithAdditions.Visible = False;
	EndIf;
	
	// Command titles
	If Not IsBlankString(ScriptParametersAdditions.VariantAdditionally.FormCommandTitle) Then
		Items.ExportAdditionFilterOfScriptNode.Title = ScriptParametersAdditions.VariantAdditionally.FormCommandTitle;
	EndIf;
	
	// Set the available ones in the right order
	OrderOfGroupsAdditions = New ValueList;
	If Items.TypicalVariantAdditionsNone.Visible Then
		OrderOfGroupsAdditions.Add(Items.TypicalVariantAdditionsNone, 
			Format(ScriptParametersAdditions.VariantNoneAdds.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.TypicalVariantOfAdditionsDocuments.Visible Then
		OrderOfGroupsAdditions.Add(Items.TypicalVariantOfAdditionsDocuments, 
			Format(ScriptParametersAdditions.VariantAllDocuments.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.TypicalVariantAdditionsArbitrary.Visible Then
		OrderOfGroupsAdditions.Add(Items.TypicalVariantAdditionsArbitrary, 
			Format(ScriptParametersAdditions.VariantArbitraryFilter.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.CustomVariantAdditions.Visible Then
		OrderOfGroupsAdditions.Add(Items.CustomVariantAdditions, 
			Format(ScriptParametersAdditions.VariantAdditionally.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	OrderOfGroupsAdditions.SortByPresentation();
	For Each GroupItemAdditions IN OrderOfGroupsAdditions Do
		Items.Move(GroupItemAdditions.Value, Items.VariantsAdditionsExportings);
	EndDo;
	
	// You can work with the settings only if there is a right
	IsRightOnSettings = AccessRight("SaveUserData", Metadata);
	Items.GroupImportModelOptionsSettings.Visible = IsRightOnSettings;
	If IsRightOnSettings Then
		// Restore predefined settings
		SetFirstItem = Not ExportAdditionSetSettingsServer(DataExchangeServer.ExportAdditionNameAutoSaveSettings());
		ExportAddition.ViewCurrentSettings = "";
	Else
		SetFirstItem = True;
	EndIf;
		
	SetFirstItem = SetFirstItem
		Or
		ExportAddition.ExportVariant<0 
		Or
		( (ExportAddition.ExportVariant=0) AND (NOT ScriptParametersAdditions.VariantNoneAdds.Use) )
		Or
		( (ExportAddition.ExportVariant=1) AND (NOT ScriptParametersAdditions.VariantAllDocuments.Use) )
		Or
		( (ExportAddition.ExportVariant=2) AND (NOT ScriptParametersAdditions.VariantArbitraryFilter.Use) )
		Or
		( (ExportAddition.ExportVariant=3) AND (NOT ScriptParametersAdditions.VariantAdditionally.Use) );
	
	If SetFirstItem Then
		For Each GroupItemAdditions IN OrderOfGroupsAdditions[0].Value.ChildItems Do
			If TypeOf(GroupItemAdditions)=Type("FormField") AND GroupItemAdditions.Type = FormFieldType.RadioButtonField Then
				ExportAddition.ExportVariant = GroupItemAdditions.ChoiceList[0].Value;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	// Initial display, analog of the client ExportAdditionVariantSetVisible
	Items.FilterGroupAllDocuments.Enabled  = ExportAddition.ExportVariant=1;
	Items.GroupDetailedSelection.Enabled     = ExportAddition.ExportVariant=2;
	Items.FilterGroupCustom.Enabled = ExportAddition.ExportVariant=3;
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		
		ExportAddition.ExportVariant = 2;
		
		FillTableCompanies();
		UpdateFilterByCompanies();
		
		GenerateTreeSpeciesDocuments();
		Items.DocumentTypesFilter.InitialTreeView = InitialTreeView.ExpandAllLevels;
		
		DeleteProgramFilters();
		
		ViewCurrentSettings = "";
	EndIf;
	
	// Initial filter types description
	SetSelectionAdditionsExportingsDescription();
EndProcedure

&AtServer
Procedure SetSelectionAdditionsExportingsDescription()
	
	SetCommonFilterAdditionDescription();
	SetAdditionDescriptionInDetails();
	
EndProcedure

&AtServer
Procedure SetCommonFilterAdditionDescription()
	
	Text = DataExchangeServer.InteractiveChangeExportingDescriptionOfAdditionsOfCommonFilter(ExportAddition);
	FilterAbsent = IsBlankString(Text);
	If FilterAbsent Then
		Text = NStr("en='All documents'");
	EndIf;
	
	Items.ExportAdditionGeneralDocumentsFilter.Title = Text;
	Items.ExportAdditionGeneralFilterClearing.Visible = Not FilterAbsent;
EndProcedure

&AtServer
Procedure SetAdditionDescriptionInDetails()
	
	Text = DataExchangeServer.InteractiveChangeExportingDetailedFilterDescription(ExportAddition);
	FilterAbsent = IsBlankString(Text);
	If FilterAbsent Then
		Text = NStr("en='Additional data have not been selected'");
	EndIf;
	
	Items.ExportAdditionDetailedFilter.Title = Text;
	Items.ExportAdditionCleaningDetailedFilter.Visible = Not FilterAbsent;
EndProcedure

// Returns Boolean - successfully/unsuccessfully (setting is not found)
&AtServer 
Function ExportAdditionSetSettingsServer(SettingRepresentation)
	
	If Not ValueIsFilled(ExportAddition.InfobaseNode)
		Or Not CommonUse.RefExists(ExportAddition.InfobaseNode) Then
		
		ExportAddition.InfobaseNode = Object.InfobaseNode;
	EndIf;
	
	Result = DataExchangeServer.InteractiveUpdateExportingsResetSettings(ExportAddition, SettingRepresentation);
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		DocumentKinds = New Array;
		GenerateTreeSpeciesDocuments(DocumentKinds);
		
		RecallFilterByCompanies();
		DeleteProgramFilters();
	EndIf;
	
	SetSelectionAdditionsExportingsDescription();
	
	Return Result;
EndFunction

&AtServer 
Function ExportAdditionHistorySettingsServer()
	
	Return DataExchangeServer.InteractiveUpdateExportingsHistorySettings(ExportAddition);
	
EndFunction

&AtServer
Procedure ExportAdditionExportVariantSetVisible()
	
	Items.FilterGroupAllDocuments.Enabled  = ExportAddition.ExportVariant=1;
	Items.GroupDetailedSelection.Enabled     = ExportAddition.ExportVariant=2;
	Items.FilterGroupCustom.Enabled = ExportAddition.ExportVariant=3;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// Transition event handler and helper
//

&AtClient
Function Attachable_WaitDumps_OnOpen(Cancel, SkipPage, IsGoNext)
	
	// Long operation starting
	BackgroundJob = BackgroundJobDumpsAtServer();
	
	LongOperationState = NewLongOperationState();
	LongOperationState.ID   = BackgroundJob.ID;
	LongOperationState.ResultAddress = BackgroundJob.ResultAddress;
	
	AttachIdleHandler("RegistrationAndDumpIdleHandler", 0.1, True);
EndFunction

&AtClient
Function Attachable_End_OnOpen(Cancel, SkipPage, IsGoNext)
	
	SuccessfulCompletion = LongOperationState.ErrorInfo = Undefined;
	
	Items.GroupCompletedSuccessfully.Visible = SuccessfulCompletion;
	Items.GroupCompletedWithErrors.Visible = Not SuccessfulCompletion;
EndFunction

// Periodic idle handler of the first phase - background registration
&AtClient
Procedure RegistrationAndDumpIdleHandler()
	
	ExchangeState = BackgroundJobStateAtServer(LongOperationState.ID);
	
	If Not ExchangeState.Completed Then
		AttachIdleHandler("RegistrationAndDumpIdleHandler", LongOperationState.WaitInterval, True);
		Return;
	EndIf;
	
	LongOperationState.ErrorInfo = ExchangeState.ErrorInfo;
	If LongOperationState.ErrorInfo <> Undefined Then
		// It is completed with error, we go to complete page
		GoToNext();
		Return;
	EndIf;
	
	// Export is completed we will expect session complete
	Session = GetFromTempStorage(LongOperationState.ResultAddress);
	
	LongOperationState = NewLongOperationState();
	LongOperationState.ID  = Session.Session;
	
	AttachIdleHandler("CorrespondentIdleHandler", LongOperationState.WaitInterval, True);
EndProcedure

// Periodic idle handler of the second phase - Background export
&AtClient
Procedure CorrespondentIdleHandler()
	
	Status = StatusOfMessageSession(LongOperationState.ID);
	
	If Status = "Running" Then
		AttachIdleHandler("CorrespondentIdleHandler", LongOperationState.WaitInterval, True);
		
	ElsIf Status = "Successfully" Then
		GoToNext();
		
	Else
		LongOperationState.ErrorInfo = NStr("en = 'Message error to correspondent'");
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions
// 

&AtClientAtServerNoContext
Function NewLongOperationState()
	
	LongOperationState = New Structure("ErrorInfo, Identifier, ResultAddress");
	LongOperationState.Insert("WaitInterval", ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 5, 3) );
	
	Return LongOperationState;
EndFunction

&AtServerNoContext
Function BackgroundJobStateAtServer(Val BackgroundJobID)
	
	Result = New Structure("Completed, ErrorInfo", True);
	
	Task = BackgroundJobs.FindByUUID(BackgroundJobID);
	If Task <> Undefined Then
		// All cryptic - it is completed
		Result.Completed = Task.State <> BackgroundJobState.Active;
		If Result.Completed AND Task.ErrorInfo <> Undefined Then
			Result.ErrorInfo = DetailErrorDescription(Task.ErrorInfo);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Function StatusOfMessageSession(Val ID)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessagesExchangeSessions.StatusOfSession(ID);
	
EndFunction

&AtServerNoContext
Procedure CompleteBackgroundTasks(Val ID)
	
	Task = BackgroundJobs.FindByUUID(ID);
	If Task <> Undefined Then
		Task.Cancel();
	EndIf;
	
EndProcedure

&AtServer
Function BackgroundJobDumpsAtServer()
	
	FillAdditionalRegistration();
	
	Result = New Structure("ResultAddress", PutToTempStorage(Undefined, UUID) );
	
	BackgroundExecutionParameters = New Array;
	
	ExportParameters = New Structure;
	MetaDataProcessing = Metadata.DataProcessors.InteractiveExportChange;
	For Each MetaAttribute IN MetaDataProcessing.Attributes Do
		AttributeName = MetaAttribute.Name;
		ExportParameters.Insert(AttributeName, ExportAddition[AttributeName]);
	EndDo;
	ExportParameters.Insert("AdditionalRegistrationScriptSite", ExportAddition.AdditionalRegistrationScriptSite.Unload() );
	ExportParameters.Insert("AdditionalRegistration",             ExportAddition.AdditionalRegistration.Unload() );
	
	BackgroundExecutionParameters.Add( ExportParameters );
	BackgroundExecutionParameters.Add( Result.ResultAddress );
	
	Task = BackgroundJobs.Execute("DataExchangeSaaS.ExchangeOnDemand", 
		BackgroundExecutionParameters, , NStr("en = 'Interactive exchange on demand.'"));
		
	Result.Insert("ID", Task.UUID);
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////
// OVERRIDABLE PART: Initialization of assistant transitions
//

&AtServer
Procedure FullScriptManually()
	
	GoToTable.Clear();
	
	If ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		GoToTableNewRow(1, "UpdateCompositionExportingsSimplified", "NavigationPageStart");
		GoToTableNewRow(2, "ConfirmationExportingData", "NavigationPageConfirmation");
		GoToTableNewRow(3, "WaitDumps",         "NavigationPageWait" , , "WaitDumps_OnOpen");
		GoToTableNewRow(4, "End", "NavigationPageEnd",,"End_WhenOpening",);
	Else
		GoToTableNewRow(1, "ChangeExportContent", "NavigationPageStart");
		GoToTableNewRow(2, "WaitDumps",         "NavigationPageWait" , , "WaitDumps_OnOpen");
		GoToTableNewRow(3, "End",                "NavigationPageEnd", , "End_WhenOpening");
	EndIf;
	
EndProcedure

&AtServer
Procedure ScriptWithoutAdding()
	GoToTable.Clear();
	
	GoToTableNewRow(1, "WaitDumps", "NavigationPageWait" , , "WaitDumps_OnOpen");
	GoToTableNewRow(2, "End",        "NavigationPageEnd", , "End_WhenOpening");
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsSB

#Region FormItemEventsHandlers

&AtClient
Procedure ExportAdditionSimplifiedDocumentsOnChangeGeneralPriod(Item)
	
	ExportAdditionUpdatePeriodScriptNode();
	
EndProcedure

&AtClient
Procedure ExportAdditionSimplifiedCommonPeriodDocumentsClearing(Item, StandardProcessing)
	// Prohibit the period clearing
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure OpenFilterFormByCompanies(Command)
	
	FormParameters = New Structure();
	FormParameters.Insert("CompaniesArray", GetArraySelectedCompanies());
	
	OpenForm("ExchangePlan.ExchangeSmallBusinessAccounting30.Form.ChoiceFormCompanies",
		FormParameters,
		ThisForm);
		
EndProcedure

&AtClient
Procedure CompanyFilterClean(Command)
	
	HeaderText = NStr("en='Confirmation'");
	QuestionText   = NStr("en='Do you want to clear the filter by companies?'");
	NotifyDescription = New NotifyDescription("ClearFilterByCompanyEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,,,HeaderText);
	
EndProcedure

&AtClient
Procedure ClearFilterByCompanyEnd(Response, AdditionalParameters) Export
	
	If Response=DialogReturnCode.Yes Then
		CompaniesTable.Clear();
		UpdateFilterByCompanies();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionSaveSettings(Command)
	
	FillAdditionalRegistration();
	
	DataExchangeClient.OpenFormAdditionsExportingsSaveSettings(ExportAddition, ThisForm);
	
	DeleteProgramFilters();
	
EndProcedure

&AtClient
Procedure ExportAdditionLoadSettings(Command)
	
	// Arrange selection from the menu list, all variants of the saved settings
	VariantList = ExportAdditionHistorySettingsServer();
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistorySelectionFromMenu", ThisObject);
	ShowChooseFromMenu(NOTifyDescription, VariantList, Items.ExportAdditionLoadSettings);
	
EndProcedure

&AtClient
Procedure IncludeAllDocumentKinds(Command)
	
	NoteDocumentKinds(True);
	
EndProcedure

&AtClient
Procedure DisableAllDocumentKinds(Command)
	
	NoteDocumentKinds(False);
	
EndProcedure

#EndRegion

#Region FormTableItemEventsHandlersFilterByDocumentTypes

&AtClient
Procedure DocumentTypesFilterCheckOnChange(Item)
	
	CurrentData = Items.DocumentTypesFilter.CurrentData;
	If CurrentData <> Undefined Then
		
		MarkValue = CurrentData.Check;
		If CurrentData.GetParent() = Undefined Then
			NoteDocumentKinds(MarkValue, CurrentData.GetID());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterByDocumentKindsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Field=Items.DocumentTypesFilterSelectionString Then
		StandardProcessing = False;
		CurrentData = Items.DocumentTypesFilter.CurrentData;
		If IsBlankString(CurrentData.FullMetadataName) Then
			Return;
		EndIf;
		
		OpenForm("DataProcessor.InteractiveExportChange.Form.PeriodAndFilterEditing",
			New Structure("Title, ActionSelect, PeriodSelection, SettingsComposer, DataPeriod",
				CurrentData.Presentation,
				-Items.DocumentTypesFilter.CurrentRow,
				CurrentData.PeriodSelection,
				SettingsComposerByTableName(CurrentData.FullMetadataName, CurrentData.Presentation, CurrentData.Filter),
				CurrentData.Period
			),
			Items.DocumentTypesFilter
		);
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentTypesFilterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		// Filter condition editing, negative string number
		Items.DocumentTypesFilter.CurrentRow = EditingRowFilterAdditionalListServer(ValueSelected);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillAdditionalRegistration(AddAdditionalFilters = True)

	If Not ScriptJobsAssistantInteractiveExchange = "OnlineSynchronizationDocuments" Then
		Return;
	EndIf;
	
	ExportAddition.AdditionalRegistration.Clear();
	
	FilterTree = FormAttributeToValue("FilterByDocumentKindsTree", Type("ValueTree"));
	For Each UpperLevelRow IN FilterTree.Rows Do
		For Each StringDetails IN UpperLevelRow.Rows Do
			If StringDetails.Check Then
				NewRow = ExportAddition.AdditionalRegistration.Add();
				FillPropertyValues(NewRow, StringDetails);
			EndIf;
		EndDo;
	EndDo;
	
	If Not AddAdditionalFilters Then
		Return;
	EndIf;
	
	ArraySelectedCompanies = GetArraySelectedCompanies();
	
	AddFilterByCompanies = ArraySelectedCompanies.Count() > 0;
	CompaniesList = New ValueList;
	CompaniesList.LoadValues(ArraySelectedCompanies);
	For Each TableRow IN ExportAddition.AdditionalRegistration Do
		
		TableRow.PeriodSelection	= True;
		TableRow.Period		= ExportAddition.AllDocumentsFilterPeriod;
		
		If AddFilterByCompanies Then
			NewItem = TableRow.Filter.Items.Add(Type("DataCompositionFilterItem"));
			NewItem.UserSettingID = "ProgramFilterByCompanies";
			NewItem.LeftValue =  New DataCompositionField("Ref.Company");
			NewItem.ComparisonType = DataCompositionComparisonType.InList;
			NewItem.RightValue = CompaniesList;
			NewItem.Use = True;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function EditingRowFilterAdditionalListServer(ChoiceStructure)
	
	CurrentData = FilterByDocumentKindsTree.FindByID(-ChoiceStructure.ActionSelect);
	If CurrentData=Undefined Then
		Return Undefined
	EndIf;
	
	CurrentData.Check 	   = True;
	CurrentData.Period       = ChoiceStructure.PeriodOfData;
	CurrentData.Filter        = ChoiceStructure.SettingsComposer.Settings.Filter;
	CurrentData.SelectionString = FilterPresentation(CurrentData.Period, CurrentData.Filter);
	
	Return ChoiceStructure.ActionSelect;
	
EndFunction

&AtServer
Function SettingsComposerByTableName(TableName, Presentation, Filter)
	
	ExportAdditionObject = FormAttributeToValue("ExportAddition");
	Return ExportAdditionObject.SettingsComposerByTableName(TableName, Presentation, Filter, UUID);
	
EndFunction

&AtClient
Procedure NoteDocumentKinds(MarkValue, ItemIdentificator = Undefined)
	
	If ItemIdentificator <> Undefined Then
		TreeItem = FilterByDocumentKindsTree.FindByID(ItemIdentificator);
		LowerLevelElements = TreeItem.GetItems();
		For Each LowerLevelElement IN LowerLevelElements Do
			LowerLevelElement.Check = MarkValue;
		EndDo;
	Else
		UpperLevelItems = FilterByDocumentKindsTree.GetItems();
		For Each TopLevelItem IN UpperLevelItems Do
			TopLevelItem.Check = MarkValue;
			LowerLevelElements = TopLevelItem.GetItems();
			For Each LowerLevelElement IN LowerLevelElements Do
				LowerLevelElement.Check = MarkValue;
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure RecallFilterByCompanies()

	CompaniesTable.Clear();
	
	AdditionalFilters = ExportAddition.AdditionalRegistration;
	If AdditionalFilters.Count() = 0 Then
		
		UpdateFilterByCompanies();
		Return;
		
	Else
		
		FilterByCompanies = "ProgramFilterByCompanies";
		FoundItem = Undefined;
		For Each TableRow IN AdditionalFilters Do
			DocumentFilter = TableRow.Filter;
			For Each FilterItem IN DocumentFilter.Items Do
				If FilterItem.UserSettingID = FilterByCompanies Then
					FoundItem = FilterItem;
					Break;
				EndIf;
			EndDo;
		EndDo;
		
		If FoundItem = Undefined
			OR Not FoundItem.Use
			OR Not ValueIsFilled(FoundItem.RightValue) Then
			
			UpdateFilterByCompanies();
			Return;
			
		Else
			
			If TypeOf(FoundItem.RightValue) = Type("ValueList") Then
				
				For Each ItemOfList IN FoundItem.RightValue Do
					
					NewRow = CompaniesTable.Add();
					NewRow.Company = ItemOfList.Value;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	UpdateFilterByCompanies();

EndProcedure

&AtServer
Procedure DeleteProgramFilters()

	FilterByCompanies = "ProgramFilterByCompanies";
	For Each TableRow IN ExportAddition.AdditionalRegistration Do
		
		DocumentFilter = TableRow.Filter;
		
		ArrayOfItemsForDeletion = New Array;
		For Each FilterItem IN DocumentFilter.Items Do
			If FilterItem.UserSettingID = FilterByCompanies Then
				ArrayOfItemsForDeletion.Add(FilterItem);
			EndIf;
		EndDo;
		
		For Each ArrayElement IN ArrayOfItemsForDeletion Do
			DocumentFilter.Items.Delete(ArrayElement);
		EndDo;
		
		TableRow.PeriodSelection	= False;
		TableRow.Period		= Undefined;
		
	EndDo;

EndProcedure

&AtServer
Procedure RefreshFilter(UpdateParameters)
	
	If TypeOf(UpdateParameters) = Type("Structure")
		AND UpdateParameters.Property("TableNameForFill")
		AND UpdateParameters.TableNameForFill = "Companies" Then
		
		If Not IsBlankString(UpdateParameters.AddressTableInTemporaryStorage) Then
			UpdateFilterByCompanies(UpdateParameters.AddressTableInTemporaryStorage);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateFilterByCompanies(AddressOfObject="")
	
	If Not IsBlankString(AddressOfObject) Then
		TableSelectedCompanies = GetFromTempStorage(AddressOfObject);
		CompaniesTable.Load(TableSelectedCompanies);
	EndIf;
	
	//Update the title of selected companies
	ArraySelectedCompanies = GetArraySelectedCompanies();
	CompaniesSelected = ArraySelectedCompanies.Count() > 0;
	If Not CompaniesSelected Then
		Text = NStr("en = 'Select companies '");
	ElsIf SelectAllCompanies() Then
		Text = NStr("en = 'All companies '");
	Else
		Text = ExchangePlans.ExchangeSmallBusinessAccounting30.ShortPresentationOfCollectionsOfValues(ArraySelectedCompanies);
	EndIf;
	
	Items.OpenFilterFormByCompanies.Title = Text;
	Items.CompanyFilterClean.Visible = CompaniesSelected;
	
EndProcedure

&AtServer
Procedure FillTableCompanies()

	CompaniesTable.Clear();
	CompaniesArray = GetArrayAllCompanies();
	
	For Each ArrayElement IN CompaniesArray Do
		
		NewRow = CompaniesTable.Add();
		NewRow.Company = ArrayElement;
		
	EndDo;

EndProcedure

&AtServer
Function GetArraySelectedCompanies()

	Return CompaniesTable.Unload().UnloadColumn("Company");

EndFunction

&AtServer
Function GetArrayAllCompanies()

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies";
	
	Result = Query.Execute();
	
	Return Result.Unload().UnloadColumn("Company");

EndFunction

&AtServer
Function SelectAllCompanies()

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Companies.Ref
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Not Companies.Ref IN (&SelectedCompanies)";
	
	Query.SetParameter("SelectedCompanies", GetArraySelectedCompanies());
	Result = Query.Execute();
	
	Return Result.IsEmpty();

EndFunction

&AtServer
Function FilterPresentation(Period, Filter)
	
	ExportAdditionObject = FormAttributeToValue("ExportAddition");
	DetailsOfEmptySelection = NStr("en='All documents'");
	Return ExportAdditionObject.FilterPresentation(Period, Filter, DetailsOfEmptySelection);
	
EndFunction

&AtServer
Procedure GenerateTreeSpeciesDocuments(ArraySelectedValues = Undefined)

	ProcessingOfAddition = FormAttributeToValue("ExportAddition");
	
	FilterTree = FormAttributeToValue("FilterByDocumentKindsTree", Type("ValueTree"));
	FilterTree.Rows.Clear();
	
	MetaDocuments = Metadata.Documents;
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Sales";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.AcceptanceCertificate, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CustomerInvoice, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InvoiceForPayment, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CustomerInvoiceNote, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.AgentReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.RetailReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.RetailRevaluation, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Purchases";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.SupplierInvoice, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.AdditionalCosts, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.ReportToPrincipal, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.SubcontractorReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryReconciliation, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryWriteOff, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.SupplierInvoiceNote, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Service";
	
	StringDetails = UpperLevelRow.Rows.Add();
	StringDetails.MetadataObjectName = MetaDocuments.CustomerOrder.Name;
	StringDetails.FullMetadataName = MetaDocuments.CustomerOrder.FullName();
	StringDetails.Presentation = "Job-order";
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Production";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryAssembly, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.ProcessingReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CostAllocation, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Funds";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.ExpenseReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashPayment, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentExpense, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentOrder, UpperLevelRow);
	
	CheckAllItems = ArraySelectedValues = Undefined;
	
	For Each UpperLevelRow IN FilterTree.Rows Do
		AllItemsAreSelected = True;
		For Each StringDetails IN UpperLevelRow.Rows Do
			If Not CheckAllItems
				AND ArraySelectedValues.Find(StringDetails.MetadataObjectName) = Undefined Then
				AllItemsAreSelected = False;
			Else
				StringDetails.Check = True;
			EndIf;
			StringDetails.PictureIndex = -1;
			StringDetails.SelectionString  = FilterPresentation(StringDetails.Period, StringDetails.Filter);
		EndDo;
		If AllItemsAreSelected Then
			UpperLevelRow.Check = True;
		EndIf;
		UpperLevelRow.PictureIndex = 0;
	EndDo;
	
	For Each TabularSectionRow IN ExportAddition.AdditionalRegistration Do
		FoundString = FilterTree.Rows.Find(TabularSectionRow.FullMetadataName, "FullMetadataName", True);
		If FoundString <> Undefined Then
			FillPropertyValues(FoundString, TabularSectionRow);
			FoundString.Check = True;
		EndIf;
	EndDo;
	
	For Each UpperLevelRow IN FilterTree.Rows Do
		AllItemsAreSelected = True;
		For Each StringDetails IN UpperLevelRow.Rows Do
			If Not StringDetails.Check Then
				AllItemsAreSelected = False;
			EndIf;
		EndDo;
		UpperLevelRow.Check = AllItemsAreSelected;
	EndDo;
	
	ValueToFormAttribute(FilterTree, "FilterByDocumentKindsTree");
	
EndProcedure

&AtServer
Procedure AddLineTreeOfDocumentsKind(MetadataObject, UpperLevelRow)

	StringDetails = UpperLevelRow.Rows.Add();
	StringDetails.MetadataObjectName = MetadataObject.Name;
	StringDetails.FullMetadataName = MetadataObject.FullName();
	StringDetails.Presentation = MetadataObject.Synonym;

EndProcedure

#EndRegion

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
