#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Service event handlers with basic functionality.

// Fills those metadata objects renaming that can not be automatically found by type, but the references to which are to be stored in the database (for example, subsystems, roles).
//
// For more see: CommonUse.AddRenaming().
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	CommonUse.AddRenaming(Total,
		"2.2.1.12",
		"Subsystem.SetupAndAdministration",
		"Subsystem.Administration",
		Library);
	
	CommonUse.AddRenaming(Total,
		"2.2.1.12",
		"Subsystem.Administration",
		"Subsystem.SetupAndAdministration",
		Library);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Conditional call handlers.

// Identifies the sections in which reports panel is available.
//   Details - see Description of
//   the UsedSections procedure of the common module ReportsVariants.
//
Procedure OnDefiningSectionsWithSectionOptions(Sections) Export
	
	Sections.Add(Metadata.Subsystems.SetupAndAdministration, NStr("en = 'Administrator reports'"));
	
EndProcedure

// Identifies sections in which the additional reports call command is available.
//   Details - see AdditionalReportSections
//   function description of the common module AdditionalReportsAndDataProcessors.
//
Procedure OnDeterminingSectionsWithAdditionalReports(Sections) Export
	
	Sections.Add(Metadata.Subsystems.SetupAndAdministration);
	
EndProcedure

// Identifies sections in which the additional processors call command is available.
//   Details - see AdditionalInformationProcessorSections
//   function description of the common module AdditionalReportsAndDataProcessors.
//
Procedure OnDeterminingSectionsWithAdditionalProcessors(Sections) Export
	
	Sections.Add(Metadata.Subsystems.SetupAndAdministration);
	
EndProcedure

#EndRegion

#EndIf
