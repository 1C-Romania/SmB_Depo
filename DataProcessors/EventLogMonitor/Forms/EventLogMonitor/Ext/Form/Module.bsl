
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	EventLogMonitorFilter = New Structure;
	EventLogMonitorFilterByDefault = New Structure;
	FilterValues = GetEventLogFilterValues("Event").Event;
	
	If Not IsBlankString(Parameters.User) Then
		If TypeOf(Parameters.User) = Type("ValueList") Then
			FilterByUser = Parameters.User;
		Else
			UserName = Parameters.User;
			FilterByUser = New ValueList;
			ByUser = FilterByUser.Add(UserName, UserName);
		EndIf;
		EventLogMonitorFilter.Insert("User", FilterByUser);
	EndIf;
	
	If ValueIsFilled(Parameters.EventLogMonitorEvent) Then
		FilterByEvent = New ValueList;
		If TypeOf(Parameters.EventLogMonitorEvent) = Type("Array") Then
			For Each Event In Parameters.EventLogMonitorEvent Do
				EventPresentation = FilterValues[Event];
				FilterByEvent.Add(Event, EventPresentation);
			EndDo;
		Else
			FilterByEvent.Add(Parameters.EventLogMonitorEvent, Parameters.EventLogMonitorEvent);
		EndIf;
		EventLogMonitorFilter.Insert("Event", FilterByEvent);
	EndIf;
	
	If ValueIsFilled(Parameters.StartDate) Then
		EventLogMonitorFilter.Insert("StartDate", Parameters.StartDate);
	EndIf;
	
	If ValueIsFilled(Parameters.EndDate) Then
		EventLogMonitorFilter.Insert("EndDate", Parameters.EndDate + 1);
	EndIf;
	
	If Parameters.Data <> Undefined Then
		EventLogMonitorFilter.Insert("Data", Parameters.Data);
	EndIf;
	
	If Parameters.Session <> Undefined Then
		EventLogMonitorFilter.Insert("Session", Parameters.Session);
	EndIf;
	
	// Level - values list.
	If Parameters.Level <> Undefined Then
		EventLogMonitorFilter.Insert("Level", Parameters.Level);
	EndIf;
	
	// ApplicationName - values list.
	If Parameters.ApplicationName <> Undefined Then
		ApplicationsList = New ValueList;
		For Each Application In Parameters.ApplicationName Do
			ApplicationsList.Add(Application, ApplicationPresentation(Application));
		EndDo;
		EventLogMonitorFilter.Insert("ApplicationName", ApplicationsList);
	EndIf;
	
	EventCountLimit = 200;
	
	DefaultFilter = DefaultFilter(FilterValues);
	If Not EventLogMonitorFilter.Property("Event") Then
		EventLogMonitorFilter.Insert("Event", DefaultFilter);
	EndIf;
	EventLogMonitorFilterByDefault.Insert("Event", DefaultFilter);
	Items.SessionDataSeparationPresentation.Visible = Not CommonUseReUse.CanUseSeparatedData();
	
	Criticality = "AllEvents";
	
	// Set to the True value if needed to generate events log monitor not in the background.
	RunNotInBackground = Parameters.RunNotInBackground;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If JobID <> New UUID("00000000-0000-0000-0000-000000000000") Then
		OnCloseAtServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure NumberOfEventsDisplayedOnChange(Item)
	
#If WebClient Then
	EventCountLimit = ?(EventCountLimit > 1000, 1000, EventCountLimit);
#EndIf
	
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure CriticalityOnChange(Item)
	
	If Criticality = "AllEvents" Then
		EventLogMonitorFilter.Delete("Level");
		RefreshCurrentList();
	ElsIf Criticality = "Errors" Then
		FilterByLevel = New ValueList;
		FilterByLevel.Add("Error", "Error");
		EventLogMonitorFilter.Delete("Level");
		EventLogMonitorFilter.Insert("Level", FilterByLevel);
		RefreshCurrentList();
	ElsIf Criticality = "Warnings" Then
		FilterByLevel = New ValueList;
		FilterByLevel.Add("Warning", "Warning");
		EventLogMonitorFilter.Delete("Level");
		EventLogMonitorFilter.Insert("Level", FilterByLevel);
		RefreshCurrentList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersLog

&AtClient
Procedure JournalSelection(Item, SelectedRow, Field, StandardProcessing)
	
	EventLogMonitorClient.EventSelection(
		Items.Journal.CurrentData, 
		Field, 
		DateInterval, 
		EventLogMonitorFilter);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Structure") AND ValueSelected.Property("Event") Then
		
		If ValueSelected.Event = "EventLogMonitorFilterSet" Then
			
			EventLogMonitorFilter.Clear();
			For Each ItemOfList In ValueSelected.Filter Do
				EventLogMonitorFilter.Insert(ItemOfList.Presentation, ItemOfList.Value);
			EndDo;
			
			If EventLogMonitorFilter.Property("Level")
				AND EventLogMonitorFilter.Level.Count() > 1 Then
				Criticality = "";
			EndIf;
			
			RefreshCurrentList();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RefreshCurrentList()
	
	Items.Pages.CurrentPage = Items.LongOperationIndicator;
	
	ExecutionResult = ReadJournal();
	
	IdleHandlerParameters = New Structure;
	
	If Not ExecutionResult.JobCompleted Then
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongOperationIndicatorField, "ReportCreation");
	Else
		Items.Pages.CurrentPage = Items.EventLogMonitor;
		MoveToListEnd();
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearFilter()
	
	EventLogMonitorFilter = EventLogMonitorFilterByDefault;
	Criticality = "AllEvents";
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure OpenDataForViewing()
	
	EventLogMonitorClient.OpenDataForViewing(Items.Journal.CurrentData);
	
EndProcedure

&AtClient
Procedure ViewCurrentEventInSeparateWindow()
	
	EventLogMonitorClient.ViewCurrentEventInSeparateWindow(Items.Journal.CurrentData);
	
EndProcedure

&AtClient
Procedure SetIntervalForViewing()
	
	Notification = New NotifyDescription("SetDatesIntervalForViewingEnd", ThisObject);
	EventLogMonitorClient.SetIntervalForViewing(DateInterval, EventLogMonitorFilter, Notification)
	
EndProcedure

&AtClient
Procedure SetFilter()
	
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure FilterPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure SetFilterByValueInCurrentColumn()
	
	ExcludeColumns = New Array;
	ExcludeColumns.Add("Date");
	
	If EventLogMonitorClient.SetFilterByValueInCurrentColumn(
			Items.Journal.CurrentData, 
			Items.Journal.CurrentItem, 
			EventLogMonitorFilter, 
			ExcludeColumns
		) Then
		
		RefreshCurrentList();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetDatesIntervalForViewingEnd(IntervalSet, AdditionalParameters) Export
	
	If IntervalSet Then
		RefreshCurrentList();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	
	LongActions.CancelJobExecution(JobID);
	
EndProcedure

&AtServer
Function DefaultFilter(EventsList)
	
	DefaultFilter = New ValueList;
	
	For Each LogEvent In EventsList Do
		
		If LogEvent.Key = "_$Transaction$_.Commit"
			Or LogEvent.Key = "_$Transaction$_.Begin"
			Or LogEvent.Key = "_$Transaction$_.Rollback" Then
			Continue;
		EndIf;
		
		DefaultFilter.Add(LogEvent.Key, LogEvent.Value);
		
	EndDo;
	
	Return DefaultFilter;
EndFunction

&AtServer
Function ReadJournal()
	
	ReportParameters = ReportParameters();
	
	If Not CheckFilling() Then 
		Return New Structure("JobCompleted", True);
	EndIf;
	
	LongActions.CancelJobExecution(JobID);
	
	JobID = Undefined;
	
	CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongOperationIndicatorField, "DontUse");
	
	If RunNotInBackground Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		EventLogMonitor.ReadEventLogMonitorEvents(ReportParameters, StorageAddress);
		ExecutionResult = New Structure("JobCompleted", True);
	Else
		ExecutionResult = LongActions.ExecuteInBackground(
			UUID, 
			"EventLogMonitor.ReadEventLogMonitorEvents", 
			ReportParameters, 
			NStr("en = 'Event log updating'"));
						
		StorageAddress       = ExecutionResult.StorageAddress;
		JobID = ExecutionResult.JobID;		
	EndIf;
	
	If ExecutionResult.JobCompleted Then
		ImportPreparedData();
	EndIf;
	
	EventLogMonitor.GenerateFilterPresentation(FilterPresentation, EventLogMonitorFilter, EventLogMonitorFilterByDefault);
	
	Return ExecutionResult;
	
EndFunction

&AtServer
Function ReportParameters()
	ReportParameters = New Structure;
	ReportParameters.Insert("EventLogMonitorFilter", EventLogMonitorFilter);
	ReportParameters.Insert("EventCountLimit", EventCountLimit);
	ReportParameters.Insert("UUID", UUID);
	ReportParameters.Insert("OwnerManager", DataProcessors.EventLogMonitor);
	ReportParameters.Insert("AddAdditionalColumns", False);
	ReportParameters.Insert("Journal", FormAttributeToValue("Journal"));

	Return ReportParameters;
EndFunction

&AtServer
Procedure ImportPreparedData()
	ExecutionResult = GetFromTempStorage(StorageAddress);
	LogEvents       = ExecutionResult.LogEvents;
	
	EventLogMonitor.PutDataToTempStorage(LogEvents, UUID);
	
	ValueToFormData(LogEvents, Journal);
	JobID = Undefined;
EndProcedure

&AtClient
Procedure MoveToListEnd()
	If Journal.Count() > 0 Then
		Items.Journal.CurrentRow = Journal[Journal.Count() - 1].GetID();
	EndIf;
EndProcedure 

&AtClient
Procedure Attachable_CheckJobExecution()  
	
	Try
		If JobCompleted(JobID) Then 
			ImportPreparedData();
			CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongOperationIndicatorField, "DontUse");
			Items.Pages.CurrentPage = Items.EventLogMonitor;
			MoveToListEnd();
		Else
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution", 
				IdleHandlerParameters.CurrentInterval, 
				True);
		EndIf;
	Except
		CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongOperationIndicatorField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLogMonitor;
		MoveToListEnd();
		Raise;
	EndTry;	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure SetFilterOnClient()
	
	FormFilter = New ValueList;
	For Each KeyAndValue In EventLogMonitorFilter Do
		FormFilter.Add(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	OpenForm(
		"DataProcessor.EventLogMonitor.Form.EventLogMonitorFilter", 
		New Structure("Filter, EventsByDefault", FormFilter, EventLogMonitorFilterByDefault.Event), 
		ThisObject);
	
EndProcedure

#EndRegion
