// Confirmation check box used at closing.
&AtClient
Var ClosingFormConfirmation;

// Import parameters to transfer between the client calls.
&AtClient
Var ClassifierBackgroundClearingParameters;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ParametersOfLongOperation = New Structure("WaitInterval, Completed, ResultAddress, ID, Error", 5);
	
	// Receive already loaded states.
	StateTable = AddressClassifierService.InformationAboutRFTerritorialEntitiesImport();
	StateTable.Columns.Add("Clear", New TypeDescription("Boolean"));
	
	For Each Region IN StateTable Do
		Region.Presentation = Format(Region.RFTerritorialEntityCode, "ND=2; NZ=; NLZ=; NG=") + ", " + Region.Presentation;
	EndDo;
	
	ValueToFormAttribute(StateTable, "RFTerritorialEntities");
	
	// Settings auto save
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshInterfaceByCountCleaned();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Items.ClearingSteps.CurrentPage <> Items.WaitingForClearing 
		Or ClosingFormConfirmation = True Then
		Return;
	EndIf;		
	
	Notification = New NotifyDescription("CloseFormEnd", ThisObject);
	Cancel = True;
	
	Text = NStr("en='Stop clearing address classifier?';ru='Прервать очистку адресного классификатора?'");
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If ParametersOfLongOperation.ID <> Undefined Then
		CancelBackgroundJob(ParametersOfLongOperation.ID);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure RFTerritorialEntitiesSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Field = Items.RFTerritorialEntitiesRepresentation Then
		CurrentData = RFTerritorialEntities.FindByID(SelectedRow);
		If CurrentData <> Undefined Then
			CurrentData.Clear = Not CurrentData.Clear;
			RefreshInterfaceByCountCleaned();
		EndIf
	EndIf;
	
EndProcedure

&AtClient
Procedure RFTerritorialEntitiesClearOnChange(Item)
	
	RefreshInterfaceByCountCleaned();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CheckAll(Command)
	
	SetStateListMarks(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	SetStateListMarks(False);
	
EndProcedure

&AtClient
Procedure Clear(Command)
	
	ClearClassifier();
	
EndProcedure

&AtClient
Procedure BreakClearing(Command)
	
	ClosingFormConfirmation = Undefined;
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// End dialog of form closing.
&AtClient
Procedure CloseFormEnd(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ClosingFormConfirmation = True;
		Close();
	Else 
		ClosingFormConfirmation = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure PermissionSetCleaning(Val CleanedCount = Undefined)
	
	If CleanedCount = Undefined Then
		CleanedCount = RFTerritorialEntities.FindRows( New Structure("Clear", True) ).Count();
	EndIf;
	
	Items.Clear.Enabled = CleanedCount > 0
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	Fields = Item.Fields.Items;
	Fields.Add().Field = New DataCompositionField("RFTerritorialEntitiesRFEntityCode");
	Fields.Add().Field = New DataCompositionField("RFTerritorialEntitiesRepresentation");

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("RFTerritorialEntities.Exported");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Black);
EndProcedure

&AtClient
Procedure SetStateListMarks(Val Mark)
	
	// Set marks only for visible strings.
	TableElement = Items.RFTerritorialEntities;
	For Each StateRow IN RFTerritorialEntities Do
		If TableElement.RowData( StateRow.GetID() ) <> Undefined Then
			StateRow.Clear = Mark;
		EndIf;
	EndDo;
	
	RefreshInterfaceByCountCleaned();
EndProcedure

&AtClient
Procedure RefreshInterfaceByCountCleaned()
	
	// Choice page
	SelectedStatesToClear = RFTerritorialEntities.FindRows( New Structure("Clear", True) ).Count();
	
	// Import page
	ClearingDescriptionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Data of the selected regions is being cleared (%1)';ru='Очищаются данные выбранных регионов (%1)'"), SelectedStatesToClear
	);
	
	PermissionSetCleaning(SelectedStatesToClear);
EndProcedure

&AtClient
Procedure ClearClassifier()
	
	ClearMessages();
	
	// Switch mode - page.
	Items.ClearingSteps.CurrentPage = Items.WaitingForClearing;
	ClearingStatusText = NStr("en='Clearing the address classifier ...';ru='Очистка адресного классификатора ...'");
	
	Items.BreakClearing.Enabled = False;
	
	ClassifierBackgroundClearingParameters = New Structure;
	ClassifierBackgroundClearingParameters.Insert("CodesOfStates", StateCodesForCleaning() );
	
	AttachIdleHandler("ClearFIASClassifier", 0.1, True);
EndProcedure

&AtClient
Procedure ClearFIASClassifier()
	
	CodesOfStates = ClassifierBackgroundClearingParameters.CodesOfStates;
	ClassifierBackgroundClearingParameters= Undefined;
	
	RunBackgroundClearingAtServer(CodesOfStates);
	AttachIdleHandler("Attachable_WaitingLongOperation", 0.1, True);
	
EndProcedure

&AtServer
Procedure RunBackgroundClearingAtServer(Val CodesOfStates)
	MethodParameters = New Array;
	MethodParameters.Add(CodesOfStates);
	
	ParametersOfLongOperation.ID   = Undefined;
	ParametersOfLongOperation.Completed       = True;
	ParametersOfLongOperation.ResultAddress = Undefined;
	ParametersOfLongOperation.Error          = Undefined;
	
	Try
		StartResult = LongActions.ExecuteInBackground(
			UUID,
			"AddressClassifierService.BackgroundJobAddressesClassifierClear",
			MethodParameters,
			NStr("en='Address classifier cleanup';ru='Очистка адресного классификатора'"));
	Except
		ParametersOfLongOperation.Error = DetailErrorDescription( ErrorInfo() );
		Return;
		
	EndTry;
	
	ParametersOfLongOperation.ID   = StartResult.JobID;
	ParametersOfLongOperation.Completed       = StartResult.JobCompleted;
	ParametersOfLongOperation.ResultAddress = StartResult.StorageAddress;
	
	// Running 
	Items.BreakClearing.Enabled = True;
EndProcedure

&AtServer
Function BackgroundJobState()
	Result = New Structure("Progress, Completed, Error");
	
	Result.Error = "";
	If ParametersOfLongOperation.ID = Undefined Then
		Result.Completed = True;
		Result.Progress  = Undefined;
		Result.Error    = ParametersOfLongOperation.Error;
	Else
		Try
			Result.Completed = LongActions.JobCompleted(ParametersOfLongOperation.ID);
			Result.Progress  = LongActions.ReadProgress(ParametersOfLongOperation.ID);
		Except
			Result.Error = DetailErrorDescription( ErrorInfo() );
		EndTry
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure CancelBackgroundJob(Val ID)
	
	If ID <> Undefined Then
		Try
			LongActions.CancelJobExecution(ID);
		Except
			// Action is not required, the record is already in the log.
		EndTry
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_WaitingLongOperation()
	
	// Update the status
	Status = BackgroundJobState();
	If Not IsBlankString(Status.Error) Then
		// Completed with error, inform and go back to the first page.
		Items.ClearingSteps.CurrentPage = Items.StatesToClearSelection;
		CommonUseClientServer.MessageToUser(Status.Error);
		Return;
		
	ElsIf Status.Completed Then
		Items.ClearingSteps.CurrentPage = Items.SuccessfulCompletion;
		ClearingDescriptionText = NStr("en='Address classifier is successfully cleared.';ru='Адресный классификатор успешно очищен.'");
		
		Notify("ClearedAddressClassifier", , ThisObject);
		
		Items.Close.DefaultButton = True;
		CurrentItem = Items.Close;
		ClosingFormConfirmation = True;
		Return;
		
	EndIf;
	
	// Process continues
	If TypeOf(Status.Progress) = Type("Structure") Then
		ClearingStatusText = Status.Progress.Text;
	EndIf;
	AttachIdleHandler("Attachable_WaitingLongOperation", ParametersOfLongOperation.WaitInterval, True);
	
EndProcedure

&AtClient
Function StateCodesForCleaning()
	Result = New Array;
	
	For Each Region IN RFTerritorialEntities.FindRows( New Structure("Clear", True) ) Do
		Result.Add(Region.RFTerritorialEntityCode);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
