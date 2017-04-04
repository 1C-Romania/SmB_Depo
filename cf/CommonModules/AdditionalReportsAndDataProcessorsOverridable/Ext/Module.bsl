////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Identifies sections in which the additional processors call command is available.
//
// Parameters:
//   Sections - Array - Sections containing additional processors call commands.
//       * MetadataObject: Subsystem - Section metadata (subsystem).
//       * String - For desktop.
//
// Definition:
//   The metadata of those sections which
//   contain the call commands should be placed in the Sections.
//
//   For desktop, the AdditionalReportsAndDataProcessorsClientServer.DesktopID()
//   should be added instead of Metadata.
//
Procedure GetSectionsWithAdditionalInformationProcessors(Sections) Export
	
	Sections.Add(Metadata.Subsystems.MarketingAndSales);
	Sections.Add(Metadata.Subsystems.InventoryAndPurchasing);
	Sections.Add(Metadata.Subsystems.Services);
	Sections.Add(Metadata.Subsystems.KittingAndProduction);
	Sections.Add(Metadata.Subsystems.Finances);
	Sections.Add(Metadata.Subsystems.PayrollAndHumanResources);
	Sections.Add(Metadata.Subsystems.Enterprise);
	Sections.Add(Metadata.Subsystems.Analysis);
	Sections.Add(Metadata.Subsystems.SetupAndAdministration);
	
EndProcedure

// Identifies sections in which the additional reports call command is available.
//
// Parameters:
//   Sections - Array - Sections containing additional reports call commands.
//       * MetadataObject: Subsystem - Section metadata (subsystem).
//       * String - For desktop.
//
// Definition:
//   The metadata of those sections which contain
//   the call commands should be placed in the Sections.
//
//   For desktop instead of Metadata it is required to add.
//   AdditionalReportsAndDataProcessorsClientServer.DesktopID().
//
Procedure GetSectionsWithAdditionalReports(Sections) Export
	
	Sections.Add(Metadata.Subsystems.MarketingAndSales);
	Sections.Add(Metadata.Subsystems.InventoryAndPurchasing);
	Sections.Add(Metadata.Subsystems.Services);
	Sections.Add(Metadata.Subsystems.KittingAndProduction);
	Sections.Add(Metadata.Subsystems.Finances);
	Sections.Add(Metadata.Subsystems.PayrollAndHumanResources);
	Sections.Add(Metadata.Subsystems.Enterprise);
	Sections.Add(Metadata.Subsystems.Analysis);
	Sections.Add(Metadata.Subsystems.SetupAndAdministration);
	
EndProcedure

#EndRegion