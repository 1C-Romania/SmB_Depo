////////////////////////////////////////////////////////////////////////////////
// STLInformationBaseUpdate: Library of service technology (STL).
// Procedures and functions of STL.
//
////////////////////////////////////////////////////////////////////////////////


#Region ProgramInterface

// See description in the general module UpdateSSLInfobase.
//
Procedure OnAddSubsystem(Description) Export
	
	Description.Name    = "LibraryServiceTechnology";
	Description.Version = ServiceTechnology.LibraryVersion();
	
	// Service events and handlers of service events are used
	Description.AddInternalEvents            = True;
	Description.AdditHandlersOfficeEvents = True;
	
	// Library of the standard subsystems is required.
	Description.RequiredSubsystems.Add("StandardSubsystems");
	
EndProcedure

// Appends the events to which you
// can add handlers through procedure WhenAddingServiceEventsHandlers.
//
// Parameters:
//  ClientEvents – Array where values of type Row - full name of event.
//  ServerEvents  - Array where values of type Row - full name of event.
//
// To simplify the support it is recommended
// to call the same procedure as in common library module.
//
// Example of use in general module of the library:
//
// // Overrides the standard warning by opening of arbitrary form of active users.
//
//  Parameters:
// //  FormName - String (return value).
//
//  Syntax//:
// // Procedure OnOpenActiveUsersForm(FormName)
//
// Export
// 	ServerEvents.Add(StandardSubsystems.BasicFunctionality\OnDefineActiveUsersForm);
//
// You can copy the comment while creating a new handler.
// The Syntax section: used to create a new handler procedure.
//
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// Mandatory subsystems
	ServiceTechnology.OnAddOfficeEvent(ClientEvents, ServerEvents);
	DataExportImportServiceEvents.OnAddOfficeEvent(ClientEvents, ServerEvents);
	OfflineWorkService.OnAddOfficeEvent(ClientEvents, ServerEvents);
	
	// Optional subsystems
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.FileFunctionsSaaS") Then
		ModuleFileFunctionsServiceInSTLServiceModel = ServiceTechnologyIntegrationWithSSL.CommonModule("FileFunctionsServiceSaaSSTL");
		ModuleFileFunctionsServiceInSTLServiceModel.OnAddOfficeEvent(ClientEvents, ServerEvents);
	EndIf;
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServiceTechnology.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.InformationCenter") Then
		
		ModuleInformationCenterService = ServiceTechnologyIntegrationWithSSL.CommonModule("InformationCenterService");
		ModuleInformationCenterService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.BasicFunctionalitySaaS") Then
		
		ModuleSaaSSTL = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSSTL");
		ModuleSaaSSTL.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
		ModuleWorkInSafeModeServiceSaaS = ServiceTechnologyIntegrationWithSSL.CommonModule("WorkInSafeModeServiceSaaS");
		ModuleWorkInSafeModeServiceSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		
		ModuleAdditionalReportsAndDataProcessorsSaaS = ServiceTechnologyIntegrationWithSSL.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
		ModuleAdditionalReportsAndDataProcessorsOffline = ServiceTechnologyIntegrationWithSSL.CommonModule("AdditionalReportsAndDataProcessorsOffline");
		ModuleAdditionalReportsAndDataProcessorsOffline.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		
		ModuleDataExchangeSaaS = ServiceTechnologyIntegrationWithSSL.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.InfobaseVersionUpdateSaaS") Then
		
		ModuleInformationBaseUpdateServiceSaaSSTL = ServiceTechnologyIntegrationWithSSL.CommonModule("InfobaseUpdateServiceSaaSSTL");
		ModuleInformationBaseUpdateServiceSaaSSTL.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.UsersSaaS") Then
		
		ModuleUsersServiceSaaSSTL = ServiceTechnologyIntegrationWithSSL.CommonModule("UsersServiceSaaSSTL");
		ModuleUsersServiceSaaSSTL.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.RemoteAdministrationSaaS") Then
		
		ModuleSTLRemoteAdministrationService= ServiceTechnologyIntegrationWithSSL.CommonModule("RemoteAdministrationSTLService");
		ModuleSTLRemoteAdministrationService.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.AccessManagementSaaS") Then
		
		ModuleAccessControlServiceSaaSSTL = ServiceTechnologyIntegrationWithSSL.CommonModule("AccessManagementServiceSaaSSTL");
		ModuleAccessControlServiceSaaSSTL.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.FileFunctionsSaaS") Then
		
		ModuleFileFunctionsServiceInSTLServiceModel = ServiceTechnologyIntegrationWithSSL.CommonModule("FileFunctionsServiceSaaSSTL");
		ModuleFileFunctionsServiceInSTLServiceModel.OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers);
		
	EndIf;
	
EndProcedure

// Adds to the list of
// procedures (IB data update handlers) for all supported versions of the library or configuration.
// Appears before the start of IB data update to build up the update plan.
//
// Parameters:
//  Handlers - ValueTable - See description
// of the fields in the procedure InfobaseUpdate.UpdateHandlersNewTable
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.Version              = "1.0.0.0";
//  Handler.Procedure           = "IBUpdate.SwitchToVersion_1_0_0_0";
//  Handler.ExclusiveMode    = False;
//  Handler.Optional        = True;
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// Mandatory subsystems
	ServiceTechnology.RegisterUpdateHandlers(Handlers);
	
	// Optional subsystems
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ModuleDataExportImportService = ServiceTechnologyIntegrationWithSSL.CommonModule("DataExportImportService");
		ModuleDataExportImportService.RegisterUpdateHandlers(Handlers);
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.InformationCenter") Then
		ModuleInformationCenterService = ServiceTechnologyIntegrationWithSSL.CommonModule("InformationCenterService");
		ModuleInformationCenterService.RegisterUpdateHandlers(Handlers);
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.BasicFunctionalitySaaS") Then
		ModuleSaaSSTL = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSSTL");
		ModuleSaaSSTL.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = ServiceTechnologyIntegrationWithSSL.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.UsersSaaS") Then
		ModuleUsersServiceSaaSSTL = ServiceTechnologyIntegrationWithSSL.CommonModule("UsersServiceSaaSSTL");
		ModuleUsersServiceSaaSSTL.RegisterUpdateHandlers(Handlers);
	EndIf;
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.StandardODataInterfaceSetup") Then
		DataProcessors["StandardODataInterfaceSetup"].RegisterUpdateHandlers(Handlers);
	EndIf;
	
EndProcedure

// Called before the procedures-handlers of IB data update.
//
Procedure BeforeInformationBaseUpdating() Export
	
	
	
EndProcedure

// Called after the completion of IB data update.
//		
// Parameters:
//   PreviousVersion       - String - version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion          - String - version after update.
//   ExecutedHandlers - ValueTree - list of completed
//                                             update procedures-handlers grouped by version number.
//   PutSystemChangesDescription - Boolean - (return value) if you
//                                set True, then the form with updates description will be displayed. By default True.
//   ExclusiveMode           - Boolean - True if the update was executed in the exclusive mode.
//		
// Example of bypass of executed update handlers:
//		
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version =
// 		 * Then Handler that can be run every time the version changes.
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

// Adds procedure-processors of transition from another application to the list (with another configuration name).
// For example, for the transition between different but related configurations: base -> prof -> corp.
// Called before the beginning of the IB data update.
//
// Parameters:
//  Handlers - ValueTable - with columns:
//    * PreviousConfigurationName - String - name of the configuration, with which the transition is run;
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

#EndRegion
