////////////////////////////////////////////////////////////////////////////////
// Subsystem "Calendar schedules".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It is called when the production calendars data is changed.
//
// Parameters:
// - UpdateConditions - Value table with columns.
// 	- BusinessCalendarCode - production calendar code which data has been changed,
// 	- Year - the year during which the data has changed.
//
Procedure OnUpdateBusinessCalendars(UpdateConditions) Export
	
EndProcedure

#EndRegion
