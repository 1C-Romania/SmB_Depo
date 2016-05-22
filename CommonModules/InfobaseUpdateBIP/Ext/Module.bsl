
////////////////////////////////////////////////////////////////////////////////
// Infobase update of the
// online support library (OSL) configuration
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Information about library (or configuration).

// See description in the general module UpdateSSLInfobase.
Procedure OnAddSubsystem(Description) Export
	
	Description.Name = "OnlineUserSupport";
	Description.Version = OnlineUserSupportClientServer.LibraryVersion();
	
	// Library of the standard subsystems is required.
	Description.RequiredSubsystems.Add("StandardSubsystems");
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure OnAddUpdateHandlers(Handlers) Export
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure BeforeInformationBaseUpdating() Export
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure AfterInformationBaseUpdate(Val PreviousInfobaseVersion, Val CurrentIBVersion,
		Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure OnPreparationOfUpdatesDescriptionTemplate(Val Template) Export
	
EndProcedure

// Helps to override mode of the infobase data update.
// To use in rare (emergency) cases of transition that do not happen in a standard procedure of the update mode.
//
// Parameters:
//   DataUpdateMode - String - you can set one of the values in the handler:
//              InitialFilling     - if it is the first launch of an empty base (data field);
//              VersionUpdate        - if it is the first launch after the update of the data base configuration;
//              TransitionFromAnotherApplication - if first launch is run after the update of
// the data base configuration with changed name of the main configuration.
//
//   StandardProcessing  - Boolean - if you set False, then a standard procedure of the update mode fails and the DataUpdateMode value is used.
//
Procedure OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing) Export
	
EndProcedure

// Adds procedure-processors of transition from another application to the list (with another configuration name).
// For example, for the transition between different but related configurations: base -> prof -> corp.
// Called before the beginning of the IB data update.
//
// Parameters:
//  Handlers - ValueTable - with columns:
//    * PreviousConfigurationName - String - name of the configuration, with which the transition is run;
//                                           or "*" if need perform when transition From any configuration.
//    * Procedure                 - String - full name of the procedure-processor of the transition from the PreviousConfigurationName application. 
//                                  ForExample, UpdatedERPInfobase.FillExportPolicy
//                                  is required to be export.
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.PreviousConfigurationName  = TradeManagement;
//  Handler.Procedure                  = ERPInfobaseUpdate.FillAccountingPolicy;
//
Procedure OnAddTransitionFromAnotherApplicationHandlers(Handlers) Export
	
EndProcedure

// Called after all procedures-processors of transfer from another application (with another
// configuration name) and before beginning of the IB data update.
//
// Parameters:
//  PreviousConfigurationName    - String - name of configuration before transition.
//  PreviousConfigurationVersion - String - name of the previous configuration (before transition).
//  Parameters                    - Structure - 
//    * UpdateFromVersion   - Boolean - True by default. If you set
// False, only the mandatory handlers of the update will be run (with the * version).
//    * ConfigurationVersion           - String - version No after transition. 
//        By default, it equals to the value of configuration version in metadata properties.
//        To run, for example, all update handlers from the PreviousConfigurationVersion version,
// you should set parameter value in PreviousConfigurationVersion.
//        To process all updates, set the 0.0.0.1 value.
//    * ClearInformationAboutPreviousConfiguration - Boolean - True by default. 
//        For cases when the previous configuration matches by name with the subsystem of the current configuration, set False.
//
Procedure OnEndTransitionFromAnotherApplication(Val PreviousConfigurationName, 
	Val PreviousConfigurationVersion, Parameters) Export
	
EndProcedure

#EndRegion
