////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Internal procedures and functions for work with the events log monitor.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Writes message to the events log monitor. 
// If parameter WriteEvents = True, then record is executed at once (call server). 
// If WriteEvents = Flase (by default), then message is put to
// queue that can be written later during the next call of this
// or another procedure to which the MessagesForEventLogMonitor queue is passed as a parameter.
//
//  Parameters: 
//   EventName          - String - event name for the events log monitor;
//   LevelPresentation - String - event level description according to which event level will be
//                                  determined during writing on server;
//                                  For example: "Error", "Alert".
//                                  Corresponds to the EventLogMonitorLevel enumeration items names.
//   Comment         - String - comment for log events;
//   EventDate         - Date   - exact date of the event described in message. It will be
//                                  added to the beginning of a comment;
//   WriteEvents     - Boolean - write all previously accumulated messages to the events
//                                  log monitor (call server).
//
// Example:
//  EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Warning",
//     NStr("en='It is impossible to connect to the Internet to check for updates';ru='Невозможно подключиться к сети Интернет для проверки обновлений.'"));
//
Procedure AddMessageForEventLogMonitor(Val EventName, Val LevelPresentation = "Information", 
	Val Comment = "", Val EventDate = "", Val WriteEvents = False) Export
	
	ParameterName = "StandardSubsystems.MessagesForEventLogMonitor";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	If TypeOf(EventDate) = Type("Date") Then
		EventDate = Format(EventDate, "DLF=DT");
	EndIf;
	
	MessageStructure = New Structure("EventName, LevelPresentation, Comment, EventDate", 
		EventName, LevelPresentation, Comment, EventDate);
		
	ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"].Add(MessageStructure);
	
	If WriteEvents Then
		EventLogMonitorServerCall.WriteEventsToEventLogMonitor(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Opens form of the events log monitor with the set filter.
//
// Parameters:
//  Filter - Structure - fields and values according to which it is required to filter log.
//  Owner - ManagedForm - form from which events log monitor is opened.
//
Procedure OpenEventLogMonitor(Val Filter = Undefined, Owner = Undefined) Export
	
	OpenForm("DataProcessor.EventLogMonitor.Form", Filter, Owner);
	
EndProcedure

// Opens form to view event additional data.
//
// Parameters:
//  CurrentData - Values table row - events log monitor row.
//
Procedure OpenDataForViewing(CurrentData) Export
	
	If CurrentData = Undefined Or CurrentData.Data = Undefined Then
		ShowMessageBox(, NStr("en='There is no data associated with this event log record (see ""Data"" column)';ru='Эта запись журнала регистрации не связана с данными (см. колонку ""Данные"")'"));
		Return;
	EndIf;
	
	Try
		ShowValue(, CurrentData.Data);
	Except
		WarningText = NStr("en='This events log monitor record is connected to the data but they can not be displayed.
		|%1';ru='Эта запись журнала регистрации связана с данными, но отобразить их невозможно.
		|%1'");
		If CurrentData.Event = "_$Data$_.Delete" Then 
			// this - deletion event
			WarningText =
					StringFunctionsClientServer.SubstituteParametersInString(
						WarningText,
						NStr("en='Data is deleted from IB';ru='Данные удалены из информационной базы'"));
		Else
			WarningText =
				StringFunctionsClientServer.SubstituteParametersInString(
						WarningText,
						NStr("en='Maybe, data was deleted from info base';ru='Возможно, данные удалены из информационной базы'"));
		EndIf;
		ShowMessageBox(, WarningText);
	EndTry;
	
EndProcedure

// Opens the "Events log monitor" processor
// event view form to display detailed data of the selected property in it.
//
// Parameters:
//  Data  - Values table row - events log monitor row.
//
Procedure ViewCurrentEventInSeparateWindow(Data) Export
	
	If Data = Undefined Then
		Return;
	EndIf;
	
	FormUniquenessKey = Data.DataAddress;
	OpenForm("DataProcessor.EventLogMonitor.Form.EventForm", EventLogMonitorMessageTextInStructure(Data),, FormUniquenessKey);
	
EndProcedure

// Requests period limitation from a user and includes them to the events log monitor filter.
//
// Parameters:
//  DateInterval - StandardPeriod, filter dates interval.
//  EventLogMonitorFilter - Structure, events log monitor filter.
//
Procedure SetIntervalForViewing(DateInterval, EventLogMonitorFilter, NotificationHandler = Undefined) Export
	
	// Get current period
	StartDate    = Undefined;
	EndDate = Undefined;
	EventLogMonitorFilter.Property("StartDate", StartDate);
	EventLogMonitorFilter.Property("EndDate", EndDate);
	StartDate    = ?(TypeOf(StartDate)    = Type("Date"), StartDate, '00010101000000');
	EndDate = ?(TypeOf(EndDate) = Type("Date"), EndDate, '00010101000000');
	
	If DateInterval.StartDate <> StartDate Then
		DateInterval.StartDate = StartDate;
	EndIf;
	
	If DateInterval.EndDate <> EndDate Then
		DateInterval.EndDate = EndDate;
	EndIf;
	
	// Edit the current period.
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = DateInterval;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("EventLogMonitorFilter", EventLogMonitorFilter);
	AdditionalParameters.Insert("DateInterval", DateInterval);
	AdditionalParameters.Insert("NotificationHandler", NotificationHandler);
	
	Notification = New NotifyDescription("SetDatesIntervalForViewingEnd", ThisObject, AdditionalParameters);
	Dialog.Show(Notification);
	
EndProcedure

// Processes selection of the separate event in the events table.
//
// Parameters:
//  CurrentData - Values table row - events log monitor row.
//  Field - Values table field - filed.
//  DateInterval - interval.
//  EventLogMonitorFilter - Filter - events log monitor filter.
//
Procedure EventSelection(CurrentData, Field, DateInterval, EventLogMonitorFilter) Export
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Field.Name = "Data" Or Field.Name = "DataPresentation" Then
		If CurrentData.Data <> Undefined
			AND Not ValueIsFilled(CurrentData.Comment)
			AND (TypeOf(CurrentData.Data) <> Type("String")
			AND ValueIsFilled(CurrentData.Data)) Then
			
			OpenDataForViewing(CurrentData);
			Return;
		EndIf;
	EndIf;
	
	If Field.Name = "Date" Then
		SetIntervalForViewing(DateInterval, EventLogMonitorFilter);
		Return;
	EndIf;
	
	ViewCurrentEventInSeparateWindow(CurrentData);
	
EndProcedure

// Fills in filter according to value in the current events column.
//
// Parameters:
//  CurrentData - Value table row.
//  CurrentItem - Current item of values table string.
//  EventLogMonitorFilter - Filter - events log monitor filter.
//  ExcludeColumns - Values list - exception columns.
//
// Returns:
//  Boolean - True if filter is set, False - Else.
//
Function SetFilterByValueInCurrentColumn(CurrentData, CurrentItem, EventLogMonitorFilter, ExcludeColumns) Export
	
	If CurrentData = Undefined Then
		Return False;
	EndIf;
	
	PresentationColumnName = CurrentItem.Name;
	
	If PresentationColumnName = "SessionDataSeparationPresentation" Then
		EventLogMonitorFilter.Delete("SessionDataSeparationPresentation");
		EventLogMonitorFilter.Insert("SessionDataSeparation", CurrentData.SessionDataSeparation);
		PresentationColumnName = "SessionDataSeparation";
	EndIf;
	
	If ExcludeColumns.Find(PresentationColumnName) <> Undefined Then
		Return False;
	EndIf;
	FilterValue = CurrentData[PresentationColumnName];
	Presentation  = CurrentData[PresentationColumnName];
	
	FilterItemName = PresentationColumnName;
	If PresentationColumnName = "UserName" Then 
		FilterItemName = "User";
		FilterValue = CurrentData["User"];
	ElsIf PresentationColumnName = "ApplicationPresentation" Then
		FilterItemName = "ApplicationName";
		FilterValue = CurrentData["ApplicationName"];
	ElsIf PresentationColumnName = "EventPresentation" Then
		FilterItemName = "Event";
		FilterValue = CurrentData["Event"];
	EndIf;
	
	// Do not filter by empty strings.
	If TypeOf(FilterValue) = Type("String") AND IsBlankString(FilterValue) Then
		// Name is empty by default for a user, allow to filter.
		If PresentationColumnName <> "UserName" Then 
			Return False;
		EndIf;
	EndIf;
	
	CurrentValue = Undefined;
	If EventLogMonitorFilter.Property(FilterItemName, CurrentValue) Then
		// Filter is already set
		EventLogMonitorFilter.Delete(FilterItemName);
	EndIf;
	
	If FilterItemName = "Data" Or          // Not list filters, only 1 value.
		FilterItemName = "Comment" Or
		FilterItemName = "TransactionID" Or
		FilterItemName = "DataPresentation" Then 
		EventLogMonitorFilter.Insert(FilterItemName, FilterValue);
	Else
		
		If FilterItemName = "SessionDataSeparation" Then
			FilterList = FilterValue.Copy();
		Else
			FilterList = New ValueList;
			FilterList.Add(FilterValue, Presentation);
		EndIf;
		
		EventLogMonitorFilter.Insert(FilterItemName, FilterList);
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
//
Function EventLogMonitorMessageTextInStructure(Data) Export
	
	If TypeOf(Data) = Type("Structure") Then
		Return Data;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Date",                    Data.Date);
	FormParameters.Insert("UserName",         Data.UserName);
	FormParameters.Insert("ApplicationPresentation", Data.ApplicationPresentation);
	FormParameters.Insert("Computer",               Data.Computer);
	FormParameters.Insert("Event",                 Data.Event);
	FormParameters.Insert("EventPresentation",    Data.EventPresentation);
	FormParameters.Insert("Comment",             Data.Comment);
	FormParameters.Insert("MetadataPresentation", Data.MetadataPresentation);
	FormParameters.Insert("Data",                  Data.Data);
	FormParameters.Insert("DataPresentation",     Data.DataPresentation);
	FormParameters.Insert("TransactionID",              Data.TransactionID);
	FormParameters.Insert("TransactionStatus",        Data.TransactionStatus);
	FormParameters.Insert("Session",                   Data.Session);
	FormParameters.Insert("ServerName",           Data.ServerName);
	FormParameters.Insert("Port",          Data.Port);
	FormParameters.Insert("SyncPort",   Data.SyncPort);
	
	If Data.Property("SessionDataSeparation") Then
		FormParameters.Insert("SessionDataSeparation", Data.SessionDataSeparation);
	EndIf;
	
	If ValueIsFilled(Data.DataAddress) Then
		FormParameters.Insert("DataAddress", Data.DataAddress);
	EndIf;
	
	Return FormParameters;
EndFunction

// Only for internal use.
//
Procedure SetDatesIntervalForViewingEnd(Result, AdditionalParameters) Export
	
	EventLogMonitorFilter = AdditionalParameters.EventLogMonitorFilter;
	IntervalSet = False;
	
	If Result <> Undefined Then
		
		// Update current period.
		DateInterval = Result;
		If DateInterval.StartDate = '00010101000000' Then
			EventLogMonitorFilter.Delete("StartDate");
		Else
			EventLogMonitorFilter.Insert("StartDate", DateInterval.StartDate);
		EndIf;
		
		If DateInterval.EndDate = '00010101000000' Then
			EventLogMonitorFilter.Delete("EndDate");
		Else
			EventLogMonitorFilter.Insert("EndDate", DateInterval.EndDate);
		EndIf;
		IntervalSet = True;
		
	EndIf;
	
	If AdditionalParameters.NotificationHandler <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.NotificationHandler, IntervalSet);
	EndIf;
	
EndProcedure

#EndRegion
