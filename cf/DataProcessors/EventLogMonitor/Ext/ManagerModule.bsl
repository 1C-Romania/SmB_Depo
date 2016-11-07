#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Contains enumeration value that corresponds to the row name event status.
//
// Parameters:
// Name - String - record transaction status.
//
// Returns:
// EventLogEntryTransactionStatus - transaction status value.
//
Function EventLogEntryTransactionStatusValueByName(Name) Export
	
	EnumValue = Undefined;
	If Name = "Committed" Then
		EnumValue = EventLogEntryTransactionStatus.Committed;
	ElsIf Name = "Unfinished" Then
		EnumValue = EventLogEntryTransactionStatus.Unfinished;
	ElsIf Name = "NotApplicable" Then
		EnumValue = EventLogEntryTransactionStatus.NotApplicable;
	ElsIf Name = "RolledBack" Then
		EnumValue = EventLogEntryTransactionStatus.RolledBack;
	EndIf;
	Return EnumValue;
	
EndFunction

// Contains enumeration value that corresponds to the row level of the events log monitor.
//
// Parameters:
// Name - String - events log monitor level.
//
// Returns:
// EventLogLevel - events log monitor level value.
//
Function EventLogLevelValueByName(Name) Export
	
	EnumValue = Undefined;
	If Name = "Information" Then
		EnumValue = EventLogLevel.Information;
	ElsIf Name = "Error" Then
		EnumValue = EventLogLevel.Error;
	ElsIf Name = "Warning" Then
		EnumValue = EventLogLevel.Warning;
	ElsIf Name = "Note" Then
		EnumValue = EventLogLevel.Note;
	EndIf;
	Return EnumValue;
	
EndFunction

// Sets picture number to the row of events log monitor event.
//
// Parameters:
// LogEvent - values table row - events log monitor row.
//
Procedure SetPictureNumber(LogEvent) Export
	
	// Set the relative picture number.
	If LogEvent.Level = EventLogLevel.Information Then
		LogEvent.PictureNumber = 0;
	ElsIf LogEvent.Level = EventLogLevel.Warning Then
		LogEvent.PictureNumber = 1;
	ElsIf LogEvent.Level = EventLogLevel.Error Then
		LogEvent.PictureNumber = 2;
	Else
		LogEvent.PictureNumber = 3;
	EndIf;
	
	// Set the absolute picture number.
	If LogEvent.TransactionStatus = EventLogEntryTransactionStatus.Unfinished
	 OR LogEvent.TransactionStatus = EventLogEntryTransactionStatus.RolledBack Then
		LogEvent.PictureNumber = LogEvent.PictureNumber + 4;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf