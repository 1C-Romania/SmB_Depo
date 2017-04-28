////////////////////////////////////////////////////////////////////////////////
// Update of infobase of library StandardSubsystems (SSL).
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Information about library (or configuration).

// Fills out basic information about the library or default configuration.
// Library which name matches configuration name in metadata is defined as default configuration.
// 
// Parameters:
//  Description - Structure - information about the library:
//
//   * Name                 - String - name of the library, for example, "StandardSubsystems".
//   * Version              - String - version in the format of 4 digits, for example, "2.1.3.1".
//
//   * RequiredSubsystems - Array - names of other libraries (String) on which this library depends.
//                                    Update handlers of such libraries should
//                                    be called before update handlers of this library.
//                                    IN case of circular dependencies or, on
//                                    the contrary, absence of any dependencies, call out
//                                    procedure of update handlers is
//                                    defined by the order of modules addition in procedure WhenAddingSubsystems of common module ConfigurationSubsystemsOverridable.
//
Procedure OnAddSubsystem(Description) Export
	
	Description.Name    = "StandardSubsystems";
	Description.Version = "2.2.5.19";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of infobase update.

// Adds to the list of
// procedures (IB data update handlers) for all supported versions of the library or configuration.
// Appears before the start of IB data update to build up the update plan.
//
//  Handlers - ValueTable - see description of the fields in the procedure.
//                InfobaseUpdate.UpdateHandlersNewTable.
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.Version              = "1.1.0.0";
//  Handler.Procedure           = "IBUpdate.SwitchToVersion_1_1_0_0";
//  Handler.ExecutionMode     = "Exclusive";
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// Handlers of this event for SSL subsystems are added through the subscription to service event:
	// StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers.
	//
	// Handler procedures of this event of all SSL subsystems have the same name
	// as this procedure but they are placed in their own subsystems.
	// To find procedures you can use global search by procedure name.
	// To find modules in which the procedures are located, you can search by event name.
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers");
	
	For Each Handler IN EventHandlers Do
		If Handler.Subsystem <> "StandardSubsystems" Then
			Continue;
		EndIf;
		Handler.Module.OnAddUpdateHandlers(Handlers);
	EndDo;
	
EndProcedure

// Called before the procedures-handlers of IB data update.
//
Procedure BeforeInformationBaseUpdating() Export
	
	// Handlers of this event for SSL subsystems are added through the subscription to service event:
	// StandardSubsystems.IBVersionUpdate\BeforeInformationBaseUpdate
	//
	// Handler procedures of this event of all SSL subsystems have the same name
	// as this procedure but they are placed in their own subsystems.
	// To find procedures you can use global search by procedure name.
	// To find modules in which the procedures are located, you can search by event name.
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.InfobaseVersionUpdate\BeforeInformationBaseUpdating");
	
	For Each Handler IN EventHandlers Do
		If Handler.Subsystem <> "StandardSubsystems" Then
			Continue;
		EndIf;
		Handler.Module.BeforeInformationBaseUpdating();
	EndDo;
	
EndProcedure

// Called after the completion of IB data update.
//		
// Parameters:
//   PreviousVersion       - String - version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion          - String - version after update.
//   ExecutedHandlers - ValueTree - list of completed
//                                             update procedures-handlers grouped by version number.
//   PutSystemChangesDescription - Boolean - If you set True, then the
//                                form with updates description will be displayed. By default True.
//                                Return value.
//   ExclusiveMode           - Boolean - True if the update was executed in the exclusive mode.
//		
// Example of bypass of executed update handlers:
//		
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version =
// 		 * Then Ha//ndler that can be run every time the version changes.
// 	Otherwise, Handler runs for a definite version.
// 	EndIf;
//		
// 	For Each Handler From Version.Rows
// 		Cycle ...
// 	EndDo;
//		
// EndDo;
//
Procedure AfterInformationBaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
	// Call procedures-handlers of service event "AfterInformationBaseUpdate".
	// (For fast transition to procedures-handlers use global search by event name.).
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.InfobaseVersionUpdate\AfterInformationBaseUpdate");
	
	For Each Handler IN EventHandlers Do
		If Handler.Subsystem <> "StandardSubsystems" Then
			Continue;
		EndIf;
		Handler.Module.AfterInformationBaseUpdate(PreviousVersion, CurrentVersion,
			ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode);
	EndDo;
	
EndProcedure

// Called when you prepare a tabular document with description of changes in the application.
//
// Parameters:
//   Template - SpreadsheetDocument - description of update of all libraries and the configuration.
//           You can append or replace the template.
//          See also common template SystemChangesDescription.
//
Procedure OnPreparationOfUpdatesDescriptionTemplate(Val Template) Export
	
EndProcedure

#EndRegion
