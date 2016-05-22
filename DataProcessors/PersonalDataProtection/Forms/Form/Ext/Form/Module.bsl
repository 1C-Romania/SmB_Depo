
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillEventLogMonitorFilterByDefault();
	EventLogMonitorFilter = CommonUseClientServer.CopyStructure(EventLogMonitorFilterByDefault);
	
	EventCountLimit = 200;
	
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

////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure JournalSelection(Item, SelectedRow, Field, StandardProcessing)
	
	EventLogMonitorClient.EventSelection(Items.Journal.CurrentData, Field, DateInterval, EventLogMonitorFilter);
	
EndProcedure

&AtClient
Procedure NumberOfEventsDisplayedOnChange(Item)
	
#If WebClient Then
	EventCountLimit = ?(EventCountLimit > 1000, 1000, EventCountLimit);
#EndIf
	
	RefreshCurrentList();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RefreshCurrentList() 
	 	
	Items.Pages.CurrentPage = Items.LongOperationIndicator;
	
	ExecutionResult = ReadJournal(EventLogMonitorFilter);
	
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
	
	EventLogMonitorFilter = CommonUseClientServer.CopyStructure(EventLogMonitorFilterByDefault);
	RefreshCurrentList();
	
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
Procedure SetFilterByValueInCurrentColumn()
	
	// To set the filter by value in the current column, first, the filter is disabled by default, and then it is enabled.
	
	DeleteDefaultValuesFromFilter();
	
	ExcludeColumns = New Array;
	ExcludeColumns.Add("Date");
	ExcludeColumns.Add("EventInfo");
	
	UpdateList = EventLogMonitorClient.SetFilterByValueInCurrentColumn(Items.Journal.CurrentData, Items.Journal.CurrentItem, EventLogMonitorFilter, ExcludeColumns);
	
	AddDefaultValuesToFilter();
	
	If UpdateList Then
		RefreshCurrentList();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Journal.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Journal.Event");
	FilterElement.ComparisonType = DataCompositionComparisonType.InList;
	ValueList = New ValueList;
	ValueList.Add(NStr("en = '_$Session$_.AuthenticationError'"));
	ValueList.Add(NStr("en = '_$Access$_.AccessDenied'"));
	FilterElement.RightValue = ValueList;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.EventRefusal);

EndProcedure

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
Function ReportParameters(EventLogMonitorFilterAtClient)
	ReportParameters = New Structure;
	ReportParameters.Insert("Journal", FormAttributeToValue("Journal"));
	ReportParameters.Insert("EventLogMonitorFilter", EventLogMonitorFilterAtClient);
	ReportParameters.Insert("EventCountLimit", EventCountLimit);
	ReportParameters.Insert("UUID", UUID);
	ReportParameters.Insert("OwnerManager", DataProcessors.PersonalDataProtection);
	ReportParameters.Insert("AddAdditionalColumns", True);
	
	Return ReportParameters;
EndFunction

&AtServer
Function FillEventLogMonitorFilterByDefault()
	
	EventLogMonitorFilterByDefault = New Structure;
	EventLogMonitorFilterByDefault.Insert("Event",			PersonalDataProtectionReUse.ListOfControlledEvents152FL());
	EventLogMonitorFilterByDefault.Insert("ApplicationName", 	PersonalDataProtectionReUse.ControlledApplicationsList152FL());
	
EndFunction

&AtServer
Function ReadJournal(EventLogMonitorFilterAtClient)
	
	ReportParameters = ReportParameters(EventLogMonitorFilterAtClient);
	
	If Not CheckFilling() Then 
		Return New Structure("JobCompleted", True);
	EndIf;
	
	LongActions.CancelJobExecution(JobID);
	
	JobID = Undefined;
	
	CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.LongOperationIndicatorField, "DontUse");
	
	ExecutionResult = LongActions.ExecuteInBackground(
		UUID, 
		"EventLogMonitor.ReadEventLogMonitorEvents", 
		ReportParameters, 
		NStr("en = 'Personal data protection'"));
					
	StorageAddress       = ExecutionResult.StorageAddress;
	JobID = ExecutionResult.JobID;
	
	If ExecutionResult.JobCompleted Then
		ImportPreparedData();
	EndIf;
	
	EventLogMonitor.GenerateFilterPresentation(FilterPresentation, EventLogMonitorFilterAtClient, EventLogMonitorFilterByDefault);
	
	Return ExecutionResult;
EndFunction

&AtClient
Procedure AddDefaultValuesToFilter()
	
	For Each FilterItem IN EventLogMonitorFilterByDefault Do
		FilterValueByDefault = FilterItem.Value;
		If Not EventLogMonitorFilter.Property(FilterItem.Key) Then
			// Filter wasn't set
			If TypeOf(FilterValueByDefault) = Type("ValueList") Then
				EventLogMonitorFilter.Insert(FilterItem.Key, FilterValueByDefault.Copy());
			Else
				EventLogMonitorFilter.Insert(FilterItem.Key, FilterValueByDefault);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure DeleteDefaultValuesFromFilter()
	
	For Each FilterItemByDefault IN EventLogMonitorFilterByDefault Do
		FilterValue = "";
		If EventLogMonitorFilter.Property(FilterItemByDefault.Key, FilterValue) Then
			// Filter is deleted only in case if it exactly matches the default filter value.
			If TypeOf(FilterValue) = Type("ValueList") Then
				DeleteFilter = CommonUseClientServer.ValueListsIdentical(FilterValue, FilterItemByDefault.Value);
			Else	
				DeleteFilter = FilterItemByDefault.Value = FilterValue;
			EndIf;
			If DeleteFilter Then
				EventLogMonitorFilter.Delete(FilterItemByDefault.Key);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure ImportPreparedData()
	ExecutionResult = GetFromTempStorage(StorageAddress);
	LogEvents       = ExecutionResult.LogEvents;
	
	EventLogMonitor.PutDataToTempStorage(LogEvents, UUID);
	
	ValueToFormData(LogEvents, Journal);
	JobID = Undefined;
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

&AtClient
Procedure MoveToListEnd()
	If Journal.Count() > 0 Then
		Items.Journal.CurrentRow = Journal[Journal.Count() - 1].GetID();
	EndIf;
EndProcedure 

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

#EndRegion
