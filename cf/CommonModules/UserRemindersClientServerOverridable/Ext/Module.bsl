////////////////////////////////////////////////////////////////////////////////
// Subsystem "User reminders".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Overrides the array of object attributes for which the time of reminder is allowed to be set.
// For example, you can hide those attributes with dates that are service attributes or
// there is no sense to set a reminder for them: date of a document or job, and others.
//
// Parameters:
//  Source - AnyRef - ref to the object for which the array of attributes with dates is formed;
//  AttributeArray - Array - names of attributes (from metadata) containing dates.
//
Procedure OnFillSourceAttributeListWithReminderDates(Source, AttributeArray) Export
	
EndProcedure

// Overrides the schedules variants for user selection.
//
// Parameters:
//  Schedule - Map:
//    * Key     - String - schedule presentation;
//    * Value   - JobSchedule - schedule variant.
Procedure OnGettingStandardSchedulesToRemind(Schedule) Export
	
EndProcedure

// Overrides the array of text representations of the standard time intervals.
//
// Parameters:
//  StandardIntervals - Array - contains the string presentations of time intervals.
//
Procedure WhenReceivingStandardNotificationsIntervals(StandardIntervals) Export
	
EndProcedure

#EndRegion
