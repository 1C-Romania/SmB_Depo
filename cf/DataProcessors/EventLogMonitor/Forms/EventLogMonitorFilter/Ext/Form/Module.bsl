
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillImportanceAndStatus();
	FillFilterParameters();
	
	DefaultEvents = Parameters.DefaultEvents;
	If Not CommonUseClientServer.ValueListsIdentical(DefaultEvents, Events) Then
		EventsDisplayed = Events.Copy();
	EndIf;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject, "DataGroup, TransactionGroup, OthersGroup");
	
	Items.SessionDataSeparation.Visible = Not CommonUseReUse.CanUseSeparatedData();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	Var ListToEdit, ParametersToSelect, StandardProcessing;
	
	If EventName = "EventLogMonitorFilterItemValueChoice"
	   AND Source = ThisObject Then
		If PropertyContentEditorItemName = Items.Users.Name Then
			UsersList = Parameter;
		ElsIf PropertyContentEditorItemName = Items.Events.Name Then
			Events = Parameter;
		ElsIf PropertyContentEditorItemName = Items.Computers.Name Then
			Computers = Parameter;
		ElsIf PropertyContentEditorItemName = Items.Applications.Name Then
			Applications = Parameter;
		ElsIf PropertyContentEditorItemName = Items.Metadata.Name Then
			Metadata = Parameter;
		ElsIf PropertyContentEditorItemName = Items.WorkingServers.Name Then
			WorkingServers = Parameter;
		ElsIf PropertyContentEditorItemName = Items.Ports.Name Then
			Ports = Parameter;
		ElsIf PropertyContentEditorItemName = Items.SyncPorts.Name Then
			SyncPorts = Parameter;
		ElsIf PropertyContentEditorItemName = Items.SessionDataSeparation.Name Then
			SessionDataSeparation = Parameter;
		EndIf;
	EndIf;
	
	EventsDisplayed.Clear();
	
	If Events.Count() = 0 Then
		Events = DefaultEvents;
		Return;
	EndIf;
	
	If Not CommonUseClientServer.ValueListsIdentical(DefaultEvents, Events) Then
		EventsDisplayed = Events.Copy();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ChoiceExecution(Item, ChoiceData, StandardProcessing)
	
	Var ListToEdit, ParametersToSelect;
	
	StandardProcessing = False;
	
	PropertyContentEditorItemName = Item.Name;
	
	If PropertyContentEditorItemName = Items.Users.Name Then
		ListToEdit = UsersList;
		ParametersToSelect = "User";
	ElsIf PropertyContentEditorItemName = Items.Events.Name Then
		ListToEdit = Events;
		ParametersToSelect = "Event";
	ElsIf PropertyContentEditorItemName = Items.Computers.Name Then
		ListToEdit = Computers;
		ParametersToSelect = "Computer";
	ElsIf PropertyContentEditorItemName = Items.Applications.Name Then
		ListToEdit = Applications;
		ParametersToSelect = "ApplicationName";
	ElsIf PropertyContentEditorItemName = Items.Metadata.Name Then
		ListToEdit = Metadata;
		ParametersToSelect = "Metadata";
	ElsIf PropertyContentEditorItemName = Items.WorkingServers.Name Then
		ListToEdit = WorkingServers;
		ParametersToSelect = "ServerName";
	ElsIf PropertyContentEditorItemName = Items.Ports.Name Then
		ListToEdit = Ports;
		ParametersToSelect = "Port";
	ElsIf PropertyContentEditorItemName = Items.SyncPorts.Name Then
		ListToEdit = SyncPorts;
		ParametersToSelect = "SyncPort";
	ElsIf PropertyContentEditorItemName = Items.SessionDataSeparation.Name Then
		FormParameters = New Structure;
		FormParameters.Insert("SetFilter", SessionDataSeparation);
		OpenForm("DataProcessor.EventLogMonitor.Form.SessionDataSeparation", FormParameters, ThisObject);
		Return;
	Else
		StandardProcessing = True;
		Return;
	EndIf;
	
	FormParameters = New Structure;
	
	FormParameters.Insert("ListToEdit", ListToEdit);
	FormParameters.Insert("ParametersToSelect", ParametersToSelect);
	
	// Opening the editor of the property.
	OpenForm("DataProcessor.EventLogMonitor.Form.PropertyContentEditor",
	             FormParameters,
	             ThisObject);
	
EndProcedure

&AtClient
Procedure EventsClearing(Item, StandardProcessing)
	
	Events = DefaultEvents;
	
EndProcedure

&AtClient
Procedure FilterIntervalOnChange(Item)
	
	FilterIntervalStartDate    = FilterInterval.StartDate;
	FilterIntervalEndDate = FilterInterval.EndDate;
	
EndProcedure

&AtClient
Procedure FilterIntervalDateOnChange(Item)
	
	FilterInterval.Variant       = StandardPeriodVariant.Custom;
	FilterInterval.StartDate    = FilterIntervalStartDate;
	FilterInterval.EndDate = FilterIntervalEndDate;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SetFilterAndCloseForm(Command)
	
	NotifyChoice(
		New Structure("Event, Filter", 
			"EventLogMonitorFilterSet", 
			GetEventLogMonitorFilter()));
	
EndProcedure

&AtClient
Procedure EnableAllImportanceCheckBoxes(Command)
	For Each ItemOfList IN Importance Do
		ItemOfList.Check = True;
	EndDo;
EndProcedure

&AtClient
Procedure DisableAllImportanceCheckBoxes(Command)
	For Each ItemOfList IN Importance Do
		ItemOfList.Check = False;
	EndDo;
EndProcedure

&AtClient
Procedure SetTransactionStatuses(Command)
	For Each ItemOfList IN TransactionStatus Do
		ItemOfList.Check = True;
	EndDo;
EndProcedure

&AtClient
Procedure RemoveTransactionStatuses(Command)
	For Each ItemOfList IN TransactionStatus Do
		ItemOfList.Check = False;
	EndDo;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillImportanceAndStatus()
	// Filling EC Importance
	Importance.Add("Error",         String(EventLogLevel.Error));
	Importance.Add("Warning", String(EventLogLevel.Warning));
	Importance.Add("Information",     String(EventLogLevel.Information));
	Importance.Add("Note",     String(EventLogLevel.Note));
	
	// Filling EC TransactionStatus
	TransactionStatus.Add("NotApplicable", String(EventLogEntryTransactionStatus.NotApplicable));
	TransactionStatus.Add("Committed", String(EventLogEntryTransactionStatus.Committed));
	TransactionStatus.Add("Unfinished",   String(EventLogEntryTransactionStatus.Unfinished));
	TransactionStatus.Add("RolledBack",      String(EventLogEntryTransactionStatus.RolledBack));
	
EndProcedure

&AtServer
Procedure FillFilterParameters()
	
	FilterParameterList = Parameters.Filter;
	HasFilterByLevel  = False;
	HasFilterByStatus = False;
	
	For Each FilterParameter IN FilterParameterList Do
		ParameterName = FilterParameter.Presentation;
		Value     = FilterParameter.Value;
		
		If Upper(ParameterName) = Upper("StartDate") Then
			// StartDate/StartDate
			FilterInterval.StartDate = Value;
			FilterIntervalStartDate  = Value;
			
		ElsIf Upper(ParameterName) = Upper("EndDate") Then
			// EndDate/EndDate
			FilterInterval.EndDate = Value;
			FilterIntervalEndDate  = Value;
			
		ElsIf Upper(ParameterName) = Upper("User") Then
			// User/User
			UsersList = Value;
			
		ElsIf Upper(ParameterName) = Upper("Event") Then
			// Event/Event
			Events = Value;
			
		ElsIf Upper(ParameterName) = Upper("Computer") Then
			// Computer/Computer
			Computers = Value;
			
		ElsIf Upper(ParameterName) = Upper("ApplicationName") Then
			// ApplicationName/ApplicationName
			Applications = Value;
			
		ElsIf Upper(ParameterName) = Upper("Comment") Then
			// Comment/Comment
			Comment = Value;
		 	
		ElsIf Upper(ParameterName) = Upper("Metadata") Then
			// Metadata/Metadata
			Metadata = Value;
			
		ElsIf Upper(ParameterName) = Upper("Data") Then
			// Data/Data 
			Data = Value;
			
		ElsIf Upper(ParameterName) = Upper("DataPresentation") Then
			// DataPresentation/DataPresentation
			DataPresentation = Value;
			
		ElsIf Upper(ParameterName) = Upper("TransactionID") Then
			// Transaction/TransactionID
			TransactionID = Value;
			
		ElsIf Upper(ParameterName) = Upper("ServerName") Then
			// ServerName/ServerName
			WorkingServers = Value;
			
		ElsIf Upper(ParameterName) = Upper("Session") Then
			// Session/Seance
			Sessions = Value;
			SessionsString = "";
			For Each SessionNumber IN Sessions Do
				SessionsString = SessionsString + ?(SessionsString = "", "", "; ") + SessionNumber;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("Port") Then
			// Port/Port
			Ports = Value;
			
		ElsIf Upper(ParameterName) = Upper("SyncPort") Then
			// SyncPort/SyncPort
			SyncPorts = Value;
			
		ElsIf Upper(ParameterName) = Upper("Level") Then
			// Level/Level
			HasFilterByLevel = True;
			For Each ValueListItem IN Importance Do
				If Value.FindByValue(ValueListItem.Value) <> Undefined Then
					ValueListItem.Check = True;
				EndIf;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("TransactionStatus") Then
			// TransactionStatus/TransactionStatus
			HasFilterByStatus = True;
			For Each ValueListItem IN TransactionStatus Do
				If Value.FindByValue(ValueListItem.Value) <> Undefined Then
					ValueListItem.Check = True;
				EndIf;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("SessionDataSeparation") Then
			
			If TypeOf(Value) = Type("ValueList") Then
				SessionDataSeparation = Value.Copy();
			EndIf;
			
			
		EndIf;
		
	EndDo;
	
	If Not HasFilterByLevel Then
		For Each ValueListItem IN Importance Do
			ValueListItem.Check = True;
		EndDo;
	EndIf;
	
	If Not HasFilterByStatus Then
		For Each ValueListItem IN TransactionStatus Do
			ValueListItem.Check = True;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Function GetEventLogMonitorFilter()
	
	Sessions.Clear();
	Str = SessionsString;
	Str = StrReplace(Str, ";", " ");
	Str = StrReplace(Str, ",", " ");
	Str = TrimAll(Str);
	CWT = New TypeDescription("Number");
	
	While Not IsBlankString(Str) Do
		Pos = Find(Str, " ");
		
		If Pos = 0 Then
			Value = CWT.AdjustValue(Str);
			Str = "";
		Else
			Value = CWT.AdjustValue(Left(Str, Pos-1));
			Str = TrimAll(Mid(Str, Pos+1));
		EndIf;
		
		If Value <> 0 Then
			Sessions.Add(Value);
		EndIf;
	EndDo;
	
	Filter = New ValueList;
	
	// End, start date
	If FilterIntervalStartDate <> '00010101000000' Then 
		Filter.Add(FilterIntervalStartDate, "StartDate");
	EndIf;
	If FilterIntervalEndDate <> '00010101000000' Then
		Filter.Add(FilterIntervalEndDate, "EndDate");
	EndIf;
	
	// User/User
	If UsersList.Count() > 0 Then 
		Filter.Add(UsersList, "User");
	EndIf;
	
	// Event/Event
	If Events.Count() > 0 Then 
		Filter.Add(Events, "Event");
	EndIf;
	
	// Computer/Computer
	If Computers.Count() > 0 Then 
		Filter.Add(Computers, "Computer");
	EndIf;
	
	// ApplicationName/ApplicationName
	If Applications.Count() > 0 Then 
		Filter.Add(Applications, "ApplicationName");
	EndIf;
	
	// Comment/Comment
	If Not IsBlankString(Comment) Then 
		Filter.Add(Comment, "Comment");
	EndIf;
	
	// Metadata/Metadata
	If Metadata.Count() > 0 Then 
		Filter.Add(Metadata, "Metadata");
	EndIf;
	
	// Data/Data 
	If (Data <> Undefined) AND (NOT Data.IsEmpty()) Then
		Filter.Add(Data, "Data");
	EndIf;
	
	// DataPresentation/DataPresentation
	If Not IsBlankString(DataPresentation) Then 
		Filter.Add(DataPresentation, "DataPresentation");
	EndIf;
	
	// Transaction/TransactionID
	If Not IsBlankString(TransactionID) Then 
		Filter.Add(TransactionID, "TransactionID");
	EndIf;
	
	// ServerName/ServerName
	If WorkingServers.Count() > 0 Then 
		Filter.Add(WorkingServers, "ServerName");
	EndIf;
	
	// Session/Seance
	If Sessions.Count() > 0 Then 
		Filter.Add(Sessions, "Session");
	EndIf;
	
	// Port/Port
	If Ports.Count() > 0 Then 
		Filter.Add(Ports, "Port");
	EndIf;
	
	// SyncPort/SyncPort
	If SyncPorts.Count() > 0 Then 
		Filter.Add(SyncPorts, "SyncPort");
	EndIf;
	
	// SessionDataSeparation
	If SessionDataSeparation.Count() > 0 Then 
		Filter.Add(SessionDataSeparation, "SessionDataSeparation");
	EndIf;
	
	// Level/Level
	LevelList = New ValueList;
	For Each ValueListItem IN Importance Do
		If ValueListItem.Check Then 
			LevelList.Add(ValueListItem.Value, ValueListItem.Presentation);
		EndIf;
	EndDo;
	If LevelList.Count() > 0 AND LevelList.Count() <> Importance.Count() Then
		Filter.Add(LevelList, "Level");
	EndIf;
	
	// TransactionStatus/TransactionStatus
	StatusList = New ValueList;
	For Each ValueListItem IN TransactionStatus Do
		If ValueListItem.Check Then 
			StatusList.Add(ValueListItem.Value, ValueListItem.Presentation);
		EndIf;
	EndDo;
	If StatusList.Count() > 0 AND StatusList.Count() <> TransactionStatus.Count() Then
		Filter.Add(StatusList, "TransactionStatus");
	EndIf;
	
	Return Filter;
	
EndFunction

#EndRegion














