////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Internal procedures and functions for work with the events log monitor.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// The procedure of messages packet writing to event log.
// 
// Parameters:
//  EventsForEventLogMonitor - ValueList - client global variable.
//     After writing the variable is cleared.
Procedure WriteEventsToEventLogMonitor(EventsForEventLogMonitor) Export
	
	If TypeOf(EventsForEventLogMonitor) <> Type("ValueList") Then
		Return;
	EndIf;	
	
	If EventsForEventLogMonitor.Count() = 0 Then
		Return;
	EndIf;
	
	For Each LogMessage IN EventsForEventLogMonitor Do
		MessageValue = LogMessage.Value;
		EventName = MessageValue.EventName;
		EventLevel = EventLevelByPresentation(MessageValue.LevelPresentation);
		EventDate = CurrentSessionDate();
		If MessageValue.Property("EventDate") AND ValueIsFilled(MessageValue.EventDate) Then
			EventDate = MessageValue.EventDate;
		EndIf;
		Comment = String(EventDate) + " " + MessageValue.Comment;
		WriteLogEvent(EventName, EventLevel,,, Comment);
	EndDo;
	EventsForEventLogMonitor.Clear();
	
EndProcedure

#EndRegion

#Region ServiceApplicationInterface

// Reads events log monitor events according to the set filter.
//
// Parameters:
//
//     ReportParameters - Structure - Contains parameters for reading events log monitor records. Contains fields:
//         Journal                  - ValueTable         - Contains records of events log monitor.
//         EventLogMonitorFilterAtClient   - Structure               - Filter settings for reading events log monitor records.
//         EventsCount       - Number                   - Restrict the quantity of read log events.
//         UUID - UUID - Unique form ID.
//         OwnerManager       - Arbitrary            - Object manager in which form
//                                                             events log monitor is displayed is
//                                                             required for the design functions call.
//         AddAdditionalColumns - Boolean           - Defines whether it is required
//                                                             to execute a reverse call for adding additional columns.
//     StorageAddress - String, UUID - Temporary storage address for result.
//
// Result is a structure with fields:
//     LogEvents - ValueTable - Selected events.
//
Procedure ReadEventLogMonitorEvents(ReportParameters, StorageAddress) Export
	
	Journal                         = ReportParameters.Journal;
	EventLogMonitorFilterAtClient          = ReportParameters.EventLogMonitorFilter;
	EventsCount              = ReportParameters.EventCountLimit;
	UUID        = ReportParameters.UUID;
	OwnerManager              = ReportParameters.OwnerManager;
	AddAdditionalColumns = ReportParameters.AddAdditionalColumns;
	
	// Check if parameters are correct.
	StartDate    = Undefined;
	EndDate = Undefined;
	FilterDatesSpecified= EventLogMonitorFilterAtClient.Property("StartDate", StartDate) AND EventLogMonitorFilterAtClient.Property("EndDate", EndDate)
		AND ValueIsFilled(StartDate) AND ValueIsFilled(EventLogMonitorFilterAtClient.EndDate);
		
	If FilterDatesSpecified AND StartDate > EndDate Then
		Raise NStr("en='Filter conditions of the event log are incorrect. Start date is greater than end date.';ru='Некорректно заданы условия отбора журнала регистрации. Дата начала больше даты окончания.'");
	EndIf;
	
	// Filter preparation
	Filter = New Structure;
	For Each FilterItem IN EventLogMonitorFilterAtClient Do
		Filter.Insert(FilterItem.Key, FilterItem.Value);
	EndDo;
	FilterTransformation(Filter);
	
	// Export selected events and generate table structure.
	LogEvents = New ValueTable;
	UnloadEventLog(LogEvents, Filter, , , EventsCount);
	
	LogEvents.Columns.Add("PictureNumber", New TypeDescription("Number"));
	LogEvents.Columns.Add("DataAddress",  New TypeDescription("String"));
	
	If CommonUseReUse.CanUseSeparatedData() Then
		LogEvents.Columns.Add("SessionDataSeparation", New TypeDescription("String"));
		LogEvents.Columns.Add("SessionDataSeparationPresentation", New TypeDescription("String"));
	EndIf;
	
	If AddAdditionalColumns Then
		OwnerManager.AddAdditionalEventColumns(LogEvents);
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData()
	   AND CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		UserAliases    = New Map();
	Else
		ModuleSaaSOperations = Undefined;
		UserAliases    = Undefined;
	EndIf;
	
	For Each LogEvent IN LogEvents Do
		// Fill in strings pictures numbers.
		OwnerManager.SetPictureNumber(LogEvent);
		
		If AddAdditionalColumns Then
			// Fill in additional fields that are defined only in owner.
			OwnerManager.FillAdditionalEventColumns(LogEvent);
		EndIf;
		
		// Convert metadata array to values list.
		MetadataPresentationsList = New ValueList;
		If TypeOf(LogEvent.MetadataPresentation) = Type("Array") Then
			MetadataPresentationsList.LoadValues(LogEvent.MetadataPresentation);
			LogEvent.MetadataPresentation = MetadataPresentationsList;
		Else
			LogEvent.MetadataPresentation = String(LogEvent.MetadataPresentation);
		EndIf;
		
		// Convert array "SessionDataSeparationPresentation" to the values list.
		If CommonUseReUse.DataSeparationEnabled()
			AND Not CommonUseReUse.CanUseSeparatedData() Then
			FullSessionDataSeparationPresentation = "";
			
			SessionDataSeparation = LogEvent.SessionDataSeparation;
			DataSeparationAttributesList = New ValueList;
			For Each SessionDelimiter IN SessionDataSeparation Do
				SeparatorPresentation = Metadata.CommonAttributes.Find(SessionDelimiter.Key).Synonym;
				SeparatorPresentation = SeparatorPresentation + " = " + SessionDelimiter.Value;
				SeparatorValue = SessionDelimiter.Key + "=" + SessionDelimiter.Value;
				DataSeparationAttributesList.Add(SeparatorValue, SeparatorPresentation);
				FullSessionDataSeparationPresentation = ?(NOT IsBlankString(FullSessionDataSeparationPresentation),
				                                            FullSessionDataSeparationPresentation + "; ", "") +
				                                            SeparatorPresentation;
			EndDo;
			LogEvent.SessionDataSeparation = DataSeparationAttributesList;
			LogEvent.SessionDataSeparationPresentation = FullSessionDataSeparationPresentation;
		EndIf;
		
		// Process special events data.
		If LogEvent.Event = "_$Access$_.Access" Then
			SetDataAddressString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				LogEvent.Data = ?(LogEvent.Data.Data = Undefined, "", "...");
			EndIf;
			
		ElsIf LogEvent.Event = "_$Access$_.AccessDenied" Then
			SetDataAddressString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				If LogEvent.Data.Property("Right") Then
					LogEvent.Data = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Right: %1';ru='Право: %1'"), 
						LogEvent.Data.Right);
				Else
					LogEvent.Data = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Action: %1%2';ru='Действие: %1%2'"), 
						LogEvent.Data.Action, ?(LogEvent.Data.Data = Undefined, "", ", ...") );
				EndIf;
			EndIf;
			
		ElsIf LogEvent.Event = "_$Session$_.Authentication"
		      Or LogEvent.Event = "_$Session$_.AuthenticationError" Then
			
			SetDataAddressString(LogEvent);
			
			LogEventData = "";
			If LogEvent.Data <> Undefined Then
				For Each KeyAndValue IN LogEvent.Data Do
					If ValueIsFilled(LogEventData) Then
						LogEventData = LogEventData + ", ...";
						Break;
					EndIf;
					LogEventData = KeyAndValue.Key + ": " + KeyAndValue.Value;
				EndDo;
			EndIf;
			LogEvent.Data = LogEventData;
			
		ElsIf LogEvent.Event = "_$User$_.Delete" Then
			SetDataAddressString(LogEvent);
			
			LogEventData = "";
			If LogEvent.Data <> Undefined Then
				For Each KeyAndValue IN LogEvent.Data Do
					LogEventData = KeyAndValue.Key + ": " + KeyAndValue.Value;
					Break;
				EndDo;
			EndIf;
			LogEvent.Data = LogEventData;
			
		ElsIf LogEvent.Event = "_$User$_.New"
		      OR LogEvent.Event = "_$User$_.Update" Then
			SetDataAddressString(LogEvent);
			
			IBUserName = "";
			If LogEvent.Data <> Undefined Then
				LogEvent.Data.Property("Name", IBUserName);
			EndIf;
			LogEvent.Data = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Name: %1, ...';ru='Имя: %1, ...'"),
				IBUserName);
			
		EndIf;
		
		SetPrivilegedMode(True);
		// User name refinement.
		If LogEvent.User = New UUID("00000000-0000-0000-0000-000000000000") Then
			LogEvent.UserName = NStr("en='<Undefined>';ru='<Неопределен>'");
			
		ElsIf LogEvent.UserName = "" Then
			LogEvent.UserName = Users.UnspecifiedUserFullName();
			
		ElsIf InfobaseUsers.FindByUUID(LogEvent.User) = Undefined Then
			LogEvent.UserName = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 <Removed>';ru='%1 <Удален>'"),
				LogEvent.UserName);
		EndIf;
		
		If ModuleSaaSOperations <> Undefined Then
			If UserAliases.Get(LogEvent.User) = Undefined Then
				UserAlias = ModuleSaaSOperations.InfobaseUserAlias(LogEvent.User);
				UserAliases.Insert(LogEvent.User, UserAlias);
			Else
				UserAlias = UserAliases.Get(LogEvent.User);
			EndIf;
			
			If ValueIsFilled(UserAlias) Then
				LogEvent.UserName = UserAlias;
			EndIf;
		EndIf;
		
		// Convert identifier to name for use during filter setting.
		LogEvent.User = InfobaseUsers.FindByUUID(LogEvent.User);
		SetPrivilegedMode(False);
	EndDo;
	
	// Successful completion
	Result = New Structure;
	Result.Insert("LogEvents", LogEvents);
	
	PutToTempStorage(Result, StorageAddress);
EndProcedure

// Creates user presentation of the events log monitor filter.
//
// Parameters:
//  FilterPresentation - String - String containing filter user presentation.
//  EventLogMonitorFilter - Structure - values of events log monitor filter.
//  EventLogMonitorFilterByDefault - Structure - filter value of the default events
// log monitor (it is not included in user presentations).
//
Procedure GenerateFilterPresentation(FilterPresentation, EventLogMonitorFilter, 
		EventLogMonitorFilterByDefault = Undefined) Export
	
	FilterPresentation = "";
	// Period
	IntervalStartDate    = Undefined;
	IntervalEndDate = Undefined;
	If Not EventLogMonitorFilter.Property("StartDate", IntervalStartDate)
		Or IntervalStartDate = Undefined Then
		IntervalStartDate    = '00010101000000';
	EndIf;
	
	If Not EventLogMonitorFilter.Property("EndDate", IntervalEndDate)
		Or IntervalEndDate = Undefined Then
		IntervalEndDate = '00010101000000';
	EndIf;
	
	If Not (IntervalStartDate = '00010101000000' AND IntervalEndDate = '00010101000000') Then
		FilterPresentation = PeriodPresentation(IntervalStartDate, IntervalEndDate);
	EndIf;
	
	AddRestrictionToFilterPresentation(EventLogMonitorFilter, FilterPresentation, "User");
	AddRestrictionToFilterPresentation(EventLogMonitorFilter, FilterPresentation,
		"Event", EventLogMonitorFilterByDefault);
	AddRestrictionToFilterPresentation(EventLogMonitorFilter, FilterPresentation,
		"ApplicationName", EventLogMonitorFilterByDefault);
	AddRestrictionToFilterPresentation(EventLogMonitorFilter, FilterPresentation, "Session");
	AddRestrictionToFilterPresentation(EventLogMonitorFilter, FilterPresentation, "Level");
	
	// Specify the remaining restrictions only by presentations without specifying restriction values.
	For Each FilterItem IN EventLogMonitorFilter Do
		RestrictionName = FilterItem.Key;
		If Upper(RestrictionName) = Upper("StartDate")
			Or Upper(RestrictionName) = Upper("EndDate")
			Or Upper(RestrictionName) = Upper("Event")
			Or Upper(RestrictionName) = Upper("ApplicationName")
			Or Upper(RestrictionName) = Upper("User")
			Or Upper(RestrictionName) = Upper("Session")
			Or Upper(RestrictionName) = Upper("Level") Then
			Continue; // Interval and special restrictions are already output.
		EndIf;
		
		// Change presentation for some restrictions.
		If Upper(RestrictionName) = Upper("ApplicationName") Then
			RestrictionName = NStr("en='Application';ru='Приложение'");
		ElsIf Upper(RestrictionName) = Upper("TransactionStatus") Then
			RestrictionName = NStr("en='Transaction status';ru='Статус транзакции'");
		ElsIf Upper(RestrictionName) = Upper("DataPresentation") Then
			RestrictionName = NStr("en='Data presentations';ru='Представления данных'");
		ElsIf Upper(RestrictionName) = Upper("ServerName") Then
			RestrictionName = NStr("en='Working server';ru='Рабочий сервер'");
		ElsIf Upper(RestrictionName) = Upper("Port") Then
			RestrictionName = NStr("en='Main IP port';ru='Основной IP порт'");
		ElsIf Upper(RestrictionName) = Upper("SyncPort") Then
			RestrictionName = NStr("en='Sync port';ru='Вспомогательный IP порт'");
		ElsIf Upper(RestrictionName) = Upper("SessionDataSeparation") Then
			RestrictionName = NStr("en='Session data separation';ru='Разделение данных сеанса'");
		EndIf;
		
		If Not IsBlankString(FilterPresentation) Then 
			FilterPresentation = FilterPresentation + "; ";
		EndIf;
		FilterPresentation = FilterPresentation + RestrictionName;
		
	EndDo;
	
	If IsBlankString(FilterPresentation) Then
		FilterPresentation = NStr("en='Not set';ru='Не установлен'");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Filter conversion.
//
// Parameters:
//  Filter - filter - passed filter.
//
Procedure FilterTransformation(Filter)
	
	For Each FilterItem IN Filter Do
		If TypeOf(FilterItem.Value) = Type("ValueList") Then
			FilterItemTransformation(Filter, FilterItem);
		ElsIf Upper(FilterItem.Key) = Upper("TransactionID") Then
			If Find(FilterItem.Value, "(") = 0 Then
				Filter.Insert(FilterItem.Key, "(" + FilterItem.Value);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Convert filter item.
//
// Parameters:
//  Filter - filter - passed filter.
//  Filter - Filter item: - passed filter item.
//
Procedure FilterItemTransformation(Filter, FilterItem)
	
	FilterStructureKey = FilterItem.Key;
	// This procedure is called if filter item is
	// a values list, and there should be values array in the filter. Convert a list to an array.
	If Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
		NewValue = New Structure;
	Else
		NewValue = New Array;
	EndIf;
	
	FilterStructureKey = FilterItem.Key;
	
	For Each ValueFromList IN FilterItem.Value Do
		If Upper(FilterStructureKey) = Upper("Level") Then
			// Messages levels are presented as a string, conversion to enumeration value is required.
			NewValue.Add(DataProcessors.EventLogMonitor.EventLogLevelValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("TransactionStatus") Then
			// Transaction statuses are presented as a string, conversion to enumeration value is required.
			NewValue.Add(DataProcessors.EventLogMonitor.EventLogEntryTransactionStatusValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
			SeparatorsValuesArray = New Array;
			FilterStructureKey = "SessionDataSeparation";
			DataSeparationArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ValueFromList.Value, "=");
			
			SeparatorValues = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DataSeparationArray[1], ",");
			For Each SeparatorValue IN SeparatorValues Do
				FilterItemBySeparator = New Structure("Value, Using", Number(SeparatorValue), True);
				SeparatorsValuesArray.Add(FilterItemBySeparator);
			EndDo;
			
			NewValue.Insert(DataSeparationArray[0], SeparatorsValuesArray);
			
		Else
			FilterValues = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ValueFromList.Value, Chars.LF);
			For Each FilterValue IN FilterValues Do
				NewValue.Add(FilterValue);
			EndDo;
		EndIf;
	EndDo;
	
	Filter.Insert(FilterItem.Key, NewValue);
	
EndProcedure

// Add restriction to the filter presentation.
//
// Parameters:
//  EventLogMonitorFilter - Filter - events log monitor filter.
//  FilterPresentation - String - filter presentation.
//  RestrictionName - String - restriction name.
//  EventLogMonitorFilterByDefault - Filter - default events log monitor filter.
//
Procedure AddRestrictionToFilterPresentation(EventLogMonitorFilter, FilterPresentation, RestrictionName,
	EventLogMonitorFilterByDefault = Undefined)
	
	RestrictionsList = "";
	Restriction = "";
	
	If EventLogMonitorFilter.Property(RestrictionName, RestrictionsList) Then
		
		// Do not generate filter presentation if its value corresponds to the default filter value.
		If EventLogMonitorFilterByDefault <> Undefined Then
			RestrictionsListByDefault = "";
			If EventLogMonitorFilterByDefault.Property(RestrictionName, RestrictionsListByDefault) 
				AND CommonUseClientServer.ValueListsIdentical(RestrictionsListByDefault, RestrictionsList) Then
				Return;
			EndIf;
		EndIf;
		
		If RestrictionName = "Event" AND RestrictionsList.Count() > 5 Then
			
			Restriction = FilterPresentation + StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Events (%1)';ru='События (%1)'"), RestrictionsList.Count());
			
		ElsIf RestrictionName = "Session" AND RestrictionsList.Count() > 3 Then
			
			Restriction = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Sessions (%1)';ru='Сеансы (%1)'"), RestrictionsList.Count());
			
		Else
			
			For Each ItemOfList IN RestrictionsList Do
				
				If Not IsBlankString(Restriction) Then
					Restriction = Restriction + ", ";
				EndIf;
				
				If (Upper(RestrictionName) = Upper("Session")
				OR Upper(RestrictionName) = Upper("Level"))
				AND IsBlankString(Restriction) Then
				
					Restriction = NStr("en='[RestrictionName]: [Value]]';ru='[ИмяОграничения]: [Значение]'");
					Restriction = StrReplace(Restriction, "[Value]", ItemOfList.Value);
					Restriction = StrReplace(Restriction, "[RestrictionName]", RestrictionName);
					
				ElsIf Upper(RestrictionName) = Upper("Session")
				OR Upper(RestrictionName) = Upper("Level")Then
					Restriction = Restriction + ItemOfList.Value;
				Else
					Restriction = Restriction + ItemOfList.Presentation;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If Not IsBlankString(FilterPresentation) Then 
			FilterPresentation = FilterPresentation + "; ";
		EndIf;
		
		FilterPresentation = FilterPresentation + Restriction;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Only for internal use.
//
Procedure PutDataToTempStorage(LogEvents, UUID) Export
	
	For Each RowEvent IN LogEvents Do
		If IsBlankString(RowEvent.DataAddress) Then
			DataAddress = "";
		Else
			XMLReader = New XMLReader();
			XMLReader.SetString(RowEvent.DataAddress);
			DataAddress = XDTOSerializer.ReadXML(XMLReader);
		EndIf;
		RowEvent.DataAddress = PutToTempStorage(DataAddress, UUID);
	EndDo;
	
EndProcedure

// Only for internal use.
//
Procedure SetDataAddressString(LogEvent)
	
	XMLWriter = New XMLWriter();
	XMLWriter.SetString();
	XDTOSerializer.WriteXML(XMLWriter, LogEvent.Data); 
	LogEvent.DataAddress = XMLWriter.Close();
	
EndProcedure

Function EventLevelByPresentation(LevelPresentation)
	If LevelPresentation = "Information" Then
		Return EventLogLevel.Information;
	ElsIf LevelPresentation = "Error" Then
		Return EventLogLevel.Error;
	ElsIf LevelPresentation = "Warning" Then
		Return EventLogLevel.Warning; 
	ElsIf LevelPresentation = "Note" Then
		Return EventLogLevel.Note;
	EndIf;	
EndFunction

#EndRegion
