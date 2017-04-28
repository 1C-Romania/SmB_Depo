////////////////////////////////////////////////////////////////////////////////
// IB version update subsystem
// Server procedures and functions of
// the infobase update on configuration version change.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Check if it is required to update infobase during the configuration version change.
//
// Returns:
//   Boolean
//
Function InfobaseUpdateRequired() Export
	
	Return InfobaseUpdateServiceReUse.InfobaseUpdateRequired();
	
EndFunction

// Returns True if IB update is being executed now.
//
// Returns:
//   Boolean
//
Function InfobaseUpdateInProgress() Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND Not CommonUseReUse.CanUseSeparatedData() Then
		Return InfobaseUpdateRequired();
	EndIf;
	
	Return SessionParameters.InfobaseUpdateIsExecute;
	
EndFunction

// Returns an empty update handlers table and IB initial filling.
//
// Returns:
//   ValueTable   - table with columns:
//     * InitialFilling - Boolean - if True, then handler should work during the start on an “empty” base.
//     * Version              - String - for example, "2.1.3.39". Configuration version number
//                                      during transition to which the update procedure-handler should be executed.
//                                      If an empty row is specified, then this handler is
//                                      only for an initial filling (the InitialFilling property should be specified).
//     * Procedure           - String - full name of update/initial filling procedure-handler. 
//                                      ForExample, UpdatedERPInfobase.FillInNewAttribute
//                                      Must be the export one.
//
//     * ExecuteInMandatoryGroup - Boolean - you should specify if
//                                      it is required to execute handler in the group with handlers on version *.
//                                      You can change handler execution order
//                                      relatively to other by changing the priority.
//     * Priority           - Number  - for an internal use.
//
//     * CommonData         - Boolean - If True, then the handler should
//                                      work before any handlers execution that use separated data.
//     * HandlersManagement - Boolean - if True, then the handler should have the parameter of
//                                          the structure type that has property.
//                                      SeparatedHandlers - values table with structure
//                                                               return by this function.
//                                      The Version column is ignored. If it is
//                                      necessary to execute the separated handler, a row with
//                                      the handler procedure description should be added to this table
//                                      Makes sense only for the mandatory (Version=*) update handlers
// with the selected CommonData check box.
//     * Comment         - String - description of actions executed by the update handler.
//     * ExecutionMode     - String - update handler execution mode. Possible values:
//                                      Exclusively, Delayed, Promptly. If value is not
//                                      filled in, the handler is exclusive.
//     * ExclusiveMode    - Undefined, Boolean - if Undefined is specified, then
// handler should be executed unconditionally in the exclusive mode.
//                                      For handlers of transfer to the specified version (version <> *):
//                                        False   - handler does not require exclusive mode for execution.
//                                        True - handler requires the exclusive mode for execution.
//                                      For mandatory update handlers  (Version = *):
//                                        False   - handler does not require the exclusive mode.
//                                        True - handler may need the exclusive mode to be executed.
//                                                 Parameter of the structure type
//                                                 with the ExclusiveMode property is passed to such handlers (Boolean type).
//                                                 The True value is passed in
//                                                 the exclusive mode during the handler start. IN this case, the handler
//                                                 should execute required actions for the update. Parameter
//                                                 change in the handler body is ignored.
//                                                 The False value is passed in
//                                                 the non-exclusive mode during the handler start. IN this case, the handler should not
//                                                 make any changes in IB.
//                                                 If in the analysis result it
//                                                 turns out that handler should change IB data,
//                                                 you should set parameter value to True and stop the handler execution.
//                                                 IN this case, operational (non-exclusive IB update)
//                                                 will be canceled and an error will occur stating
//                                                 that it is required to execute an update in the exclusive mode.
//
Function NewUpdateHandlersTable() Export
	
	Handlers = New ValueTable;
	// Main properties.
	Handlers.Columns.Add("InitialFilling", New TypeDescription("Boolean"));
	Handlers.Columns.Add("Version",    New TypeDescription("String", New StringQualifiers(0)));
	Handlers.Columns.Add("Procedure", New TypeDescription("String", New StringQualifiers(0)));
	Handlers.Columns.Add("Comment", New TypeDescription("String", New StringQualifiers(0)));
	Handlers.Columns.Add("PerformModes", New TypeDescription("String"));
	// Additional properties (for libraries).
	Handlers.Columns.Add("ExecuteUnderMandatory", New TypeDescription("Boolean"));
	Handlers.Columns.Add("Priority", New TypeDescription("Number", New NumberQualifiers(2)));
	// Service model support.
	Handlers.Columns.Add("SharedData",             New TypeDescription("Boolean"));
	Handlers.Columns.Add("HandlersManagement", New TypeDescription("Boolean"));
	Handlers.Columns.Add("ExclusiveMode");
	
	// Outdated. Backward match up to edition 2.2
	Handlers.Columns.Add("Optional");
	
	Return Handlers;
	
EndFunction

// Execute update handlers from the UpdateHandlers list for the LibraryID library up to the IBMetadataVersion version.
//
// Parameters:
//   LibraryID  - String       - configuration name and library identifier.
//   MetadataIBVersion       - String       - metadata version up to which it should be updated.
//   UpdateHandlers    - Map - update handlers list.
//
// Returns:
//   ValueTree   - executed update handlers.
//
Function RunUpdateIteration(Val LibraryID, Val MetadataIBVersion, 
	Val UpdateHandlers, Val HandlersExecutionProcess, Val OperationalUpdate = False) Export
	
	IterationUpdate = InfobaseUpdateService.IterationUpdate(LibraryID, 
		MetadataIBVersion, UpdateHandlers);
		
	Parameters = New Structure;
	Parameters.Insert("HandlersExecutionProcess", HandlersExecutionProcess);
	Parameters.Insert("OperationalUpdate", OperationalUpdate);
	Parameters.Insert("InBackground", False);
	
	Return InfobaseUpdateService.RunUpdateIteration(IterationUpdate, Parameters);
	
EndFunction

// Execute a non-interactive update of IB data .
// For call via the external connection.
// 
// To use in other libraries and configurations.
//
// Returns:
//  String -  shows that the update handlers are in progress:
//           Successfully, NotRequired, ExclusiveModeSettingError
//
Function RunInfobaseUpdate() Export
	
	Return InfobaseUpdateServiceServerCall.RunInfobaseUpdate();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for use in the update handlers.
//

// Records changes in transmitted object.
// For update counters.
//
// Parameters:
//   Data                            - Arbitrary - object, set of entries or
//                                                      constant manager to record.
//   RegisterOnNodesExchangePlans - Boolean       - enables registration on the exchange plans nodes when recording the object.
//   EnableBusinessLogic              - Boolean       - activates business logic when recording the object.
//
Procedure WriteData(Val Data, Val RegisterOnNodesExchangePlans = False, 
	Val EnableBusinessLogic = False) Export 

  Data.DataExchange.Load = Not EnableBusinessLogic;
	If Not RegisterOnNodesExchangePlans Then
		Data.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		Data.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Data.Write();
	
EndProcedure

// Deletes the passed object.
// For update counters.
//
// Parameters:
//  Data                            - Arbitrary - object that should be removed.
//  RegisterOnNodesExchangePlans - Boolean       - enables registration on the exchange plans nodes when recording the object.
//  EnableBusinessLogic              - Boolean       - activates business logic when recording the object.
//
Procedure DeleteData(Val Data, Val RegisterOnNodesExchangePlans = False, 
	Val EnableBusinessLogic = False) Export 

  Data.DataExchange.Load = Not EnableBusinessLogic;
	If Not RegisterOnNodesExchangePlans Then
		Data.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		Data.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Data.Delete();
	
EndProcedure

// Writes changes in the passed object of the reference type.
// For update counters.
//
// Parameters:
//   Object                            - Arbitrary - written object of the reference type. For example, CatalogObject.
//   RegisterOnNodesExchangePlans - Boolean       - enables registration on the exchange plans nodes when recording the object.
//   EnableBusinessLogic              - Boolean       - activates business logic when recording the object.
//
Procedure WriteObject(Val Object, Val RegisterOnNodesExchangePlans = Undefined, 
	Val EnableBusinessLogic = False) Export
	
	If RegisterOnNodesExchangePlans = Undefined AND Object.IsNew() Then
		RegisterOnNodesExchangePlans = True;
	Else
		RegisterOnNodesExchangePlans = False;
	EndIf;
	
	Object.DataExchange.Load = Not EnableBusinessLogic;
	If Not RegisterOnNodesExchangePlans Then
		Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		Object.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Object.Write();
	
EndProcedure

// Returns a string constant to form the events log messages.
//
// Returns:
//   String
//
Function EventLogMonitorEvent() Export
	
	Return InfobaseUpdateService.EventLogMonitorEvent();
	
EndFunction

// Get the version of configuration or
// parent configuration (library) that is stored in the infobase.
//
// Parameters:
//  LibraryID   - String - configuration name and library identifier.
//
// Returns:
//   String   - version.
//
// Useful example:
//   IBConfigurationVersion = IBVersion(Metadata.Name);
//
Function IBVersion(Val LibraryID) Export
	
	Return InfobaseUpdateService.IBVersion(LibraryID);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedure and function.
//

// Deletes the postponed handler from queue of executed handlers to a new version.
//
// Parameters:
//  HandlerName - String - full name of the postponed handler procedure.
//
Procedure DeletePostponedQueueHandler(HandlerName) Export 

  DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
	
	SelectedHandler = DataAboutUpdate.HandlerTree.Rows.FindRows(New Structure("HandlerName", HandlerName), True);
	If SelectedHandler <> Undefined AND SelectedHandler.Count() > 0 Then
		
		For Each RowHandler IN SelectedHandler Do
			RowHandler.Parent.Rows.Delete(RowHandler);
		EndDo;
		
	EndIf;
	
	InfobaseUpdateService.WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
EndProcedure

// Returns table with the configuration subsystems versions.
// For the batch information export-import about the subsystems versions.
//
// Returns:
//   ValueTable - table with columns:
//     * SubsystemName - String - subsystem name.
//     * Version        - String - subsystem version.
//
Function SubsystemVersions() Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	SubsystemVersions.SubsystemName AS SubsystemName,
	|	SubsystemVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemVersions AS SubsystemVersions";
	
	Return Query.Execute().Unload();

EndFunction 

// Sets versions of all subsystems.
// For the batch information export-import about the subsystems versions.
//
// Parameters:
//   SubsystemVersions - ValueTable - table with columns:
//     * SubsystemName - String - subsystem name.
//     * Version        - String - subsystem version.
//
Procedure SetSubsystemVersions(SubsystemVersions) Export

	RecordSet = InformationRegisters.SubsystemVersions.CreateRecordSet();
	
	For Each Version In SubsystemVersions Do
		NewRecord = RecordSet.Add();
		NewRecord.SubsystemName = Version.SubsystemName;
		NewRecord.Version = Version.Version;
		NewRecord.ThisMainConfiguration = (Version.SubsystemName = Metadata.Name);
	EndDo;
	
	RecordSet.Write();

EndProcedure

#EndRegion

