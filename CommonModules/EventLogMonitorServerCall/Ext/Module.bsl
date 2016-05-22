////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Procedures and functions for working with event log.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// The procedure of messages packet writing to event log.
// 
// Parameters:
//  EventsForEventLogMonitor - ValuesList, the global variable of clients.
//     After writing the variable is cleared.
Procedure WriteEventsToEventLogMonitor(EventsForEventLogMonitor) Export
	
	EventLogMonitor.WriteEventsToEventLogMonitor(EventsForEventLogMonitor);
	
EndProcedure

#EndRegion
