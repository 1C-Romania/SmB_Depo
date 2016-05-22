////////////////////////////////////////////////////////////////////////////////
// Subsystem "The analysis of the events log".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddMetadataObjectsRenaming"].Add(
		"EventLogMonitorAnalysisService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ServerHandlers["StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports"].Add(
			"EventLogMonitorAnalysisService");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills those metadata objects renaming that can not be automatically found by type, but the references to which are to be stored in the database (for example, subsystems, roles).
//
// For more see: CommonUse.AddRenaming().
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	CommonUse.AddRenaming(Total,
		"2.1.0.1",
		"Subsystem.StandardSubsystems.Subsystem.EventLogMonitorControl",
		"Subsystem.StandardSubsystems.Subsystem.EventsLogAnalysis",
		Library);
	
EndProcedure

// Contains the settings of reports variants placement in reports panel.
//
// Parameters:
//   Settings - Collection - Used for the description of reports
//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
//
// Description:
//  See ReportsVariantsOverride.SetupReportsVariants().
//
Procedure OnConfiguringOptionsReports(Settings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.EventsLogAnalysis);
EndProcedure

#EndRegion
