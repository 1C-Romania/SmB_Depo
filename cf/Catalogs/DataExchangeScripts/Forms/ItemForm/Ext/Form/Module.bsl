&AtClient
Var CurrentlyProcessedLineNumber;

&AtClient
Var LineCount;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	IsNew = (Object.Ref.IsEmpty());
	
	InfobaseNode = Undefined;
	
	If IsNew
		AND Parameters.Property("InfobaseNode", InfobaseNode)
		AND InfobaseNode <> Undefined Then
		
		Catalogs.DataExchangeScripts.AddImportingToDataExchangeScripts(Object, InfobaseNode);
		Catalogs.DataExchangeScripts.AddDumpToDataExchangeScripts(Object, InfobaseNode);
		
		Description = NStr("en='Synchronization scenario for %1';ru='Сценарий синхронизации для %1'");
		Object.Description = StringFunctionsClientServer.SubstituteParametersInString(Description, String(InfobaseNode));
		
		JobSchedule = Catalogs.DataExchangeScripts.ScheduledJobDefaultSchedule();
		
		Object.UseScheduledJob = True;
		
	Else
		
		// Get the schedule from the
		// scheduled job if RH isn't set then schedule = Undefined and will be created on client at the time of schedule editing.
		JobSchedule = Catalogs.DataExchangeScripts.GetDataExchangeSchedule(Object.Ref);
		
	EndIf;
	
	If Not IsNew Then
		
		RefreshDataExchangeStatus();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshSchedulePresentation();
	
	SetScheduleSettingHyperlinkAvailable();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	Catalogs.DataExchangeScripts.RefreshScheduledJobData(Cancel, JobSchedule, CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_DataExchangeScripts", WriteParameters, Object.Ref);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UseScheduledJobOnChange(Item)
	
	SetScheduleSettingHyperlinkAvailable();
	
EndProcedure

&AtClient
Procedure ScheduleContentOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillListOfExchangeTransportKindSelection(Item.ChildItems.ExchangeSettingsExchangeTransportKind.ChoiceList, Item.CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfobaseNodeOnChange(Item)
	
	Items.ScheduleContent.CurrentData.ExchangeTransportKind = Undefined;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(Item.EditText, 
		ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersExchangeSettings

&AtClient
Procedure ExchangeSettingsExchangeTransportKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData <> Undefined Then
		
		FillListOfExchangeTransportKindSelection(Item.ChoiceList, CurrentData.InfobaseNode);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RunExchange(Command)
	
	IsNew = (Object.Ref.IsEmpty());
	
	If Modified OR IsNew Then
		
		Write();
		
	EndIf;
	
	CurrentlyProcessedLineNumber     = 1;
	LineCount = Object.ExchangeSettings.Count();
	
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtClient
Procedure ConfigureScheduleJobSchedule(Command)
	
	ScheduledJobScheduleEdit();
	
	RefreshSchedulePresentation();
	
EndProcedure

&AtClient
Procedure TransportSettings(Command)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	ElsIf Not ValueIsFilled(CurrentData.InfobaseNode) Then
		Return;
	EndIf;
	
	Filter              = New Structure("Node", CurrentData.InfobaseNode);
	FillingValues = New Structure("Node", CurrentData.InfobaseNode);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings", ThisObject);
	
EndProcedure

&AtClient
Procedure GoToEventLogMonitor(Command)
	
	CurrentData = Items.ScheduleContent.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(CurrentData.InfobaseNode,
																	ThisObject,
																	CurrentData.RunningAction);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ScheduledJobScheduleEdit()
	
	// If the schedule isn't initialized in form on the server then create new.
	If JobSchedule = Undefined Then
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	
	// Open dialog for editing Schedule.
	NotifyDescription = New NotifyDescription("ScheduleScheduledJobs1EditCompletion", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure ScheduleScheduledJobs1EditCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		JobSchedule = Schedule;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshSchedulePresentation()
	
	SchedulePresentation = String(JobSchedule);
	
	If SchedulePresentation = String(New JobSchedule) Then
		
		SchedulePresentation = NStr("en='Schedule is not set';ru='Расписание не задано'");
		
	EndIf;
	
	Items.ConfigureScheduleJobSchedule.Title = SchedulePresentation;
	
EndProcedure

&AtClient
Procedure SetScheduleSettingHyperlinkAvailable()
	
	Items.ConfigureScheduleJobSchedule.Enabled = Object.UseScheduledJob;
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAtClient()
	
	If CurrentlyProcessedLineNumber > LineCount Then // exit from recursion
		OutputState = (LineCount > 1);
		Status(NStr("en='Data is synchronized.';ru='Данные синхронизированы.'"), ?(OutputState, 100, Undefined));
		Return; // exit
	EndIf;
	
	CurrentData = Object.ExchangeSettings[CurrentlyProcessedLineNumber - 1];
	
	OutputState = (LineCount > 1);
	
	MessageString = NStr("en='%1 is executed for %2';ru='Выполняется %1 для %2'");
	MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, 
							String(CurrentData.RunningAction),
							String(CurrentData.InfobaseNode));
	//
	Progress = Round(100 * (CurrentlyProcessedLineNumber -1) / ?(LineCount = 0, 1, LineCount));
	Status(MessageString, ?(OutputState, Progress, Undefined));
	
	// Run the exchange according to the settings string.
	ExecuteDataExchangeBySettingsString(CurrentlyProcessedLineNumber);
	
	UserInterruptProcessing();
	
	CurrentlyProcessedLineNumber = CurrentlyProcessedLineNumber + 1;
	
	// Recursively call this procedure.
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtServer
Procedure RefreshDataExchangeStatus()
	
	QueryText = "
	|SELECT
	|	DataExchangeScenarioExchangeSettings.InfobaseNode,
	|	DataExchangeScenarioExchangeSettings.ExchangeTransportKind,
	|	DataExchangeScenarioExchangeSettings.RunningAction,
	|	CASE
	|	WHEN DataExchangeStatus.ExchangeProcessResult IS NULL
	|	THEN 0
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived)
	|	THEN 2
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.CompletedWithWarnings)
	|	THEN 2
	|	WHEN DataExchangeStatus.ExchangeProcessResult = VALUE(Enum.ExchangeExecutionResult.Completed)
	|	THEN 0
	|	ELSE 1
	|	END AS ExchangeProcessResult
	|FROM
	|	Catalog.DataExchangeScripts.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|LEFT JOIN InformationRegister.DataExchangeStatus AS DataExchangeStatus
	|	ON DataExchangeStatus.InfobaseNode = DataExchangeScenarioExchangeSettings.InfobaseNode
	|	 AND DataExchangeStatus.ActionOnExchange      = DataExchangeScenarioExchangeSettings.RunningAction
	|WHERE
	|	DataExchangeScenarioExchangeSettings.Ref = &Ref
	|ORDER BY
	|	DataExchangeScenarioExchangeSettings.LineNumber ASC
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Object.ExchangeSettings.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeBySettingsString(Val IndexOf)
	
	Cancel = False;
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeByScenarioOfExchangeData(Cancel, Object.Ref, IndexOf);
	
	// Update tabular section data of exchange scenario.
	RefreshDataExchangeStatus();
	
EndProcedure

&AtClient
Procedure FillListOfExchangeTransportKindSelection(ChoiceList, InfobaseNode)
	
	ChoiceList.Clear();
	
	If ValueIsFilled(InfobaseNode) Then
		
		For Each Item IN UsedTransportsOfExchangeMessages(InfobaseNode) Do
			
			ChoiceList.Add(Item, String(Item));
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function UsedTransportsOfExchangeMessages(Val InfobaseNode)
	
	Return DataExchangeReUse.UsedTransportsOfExchangeMessages(InfobaseNode);
	
EndFunction

#EndRegion
