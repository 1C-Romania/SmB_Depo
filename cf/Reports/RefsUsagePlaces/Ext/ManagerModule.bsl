#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Placement settings in the report panel.
//
// Parameters:
//   Settings - Collection - Used for the description of report
//       settings and variants, see description to ReportsVariants.ConfigurationReportVariantsSettingTree().
//   ReportSettings - ValueTreeRow - Placement settings of all report variants.
//      See "Attributes for change" of the ReportsVariants function.ConfigurationReportVariantsSetupTree().
//
// Description:
//  See ReportsVariantsOverridable.SetReportsVariants().
//
// Auxiliary methods:
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   ReportsVariants.SetOutputModeInReportPanels
//   False (Settings, ReportSettings,True/False); Repor//t supports only this mode.
//
Procedure ConfigureReportsVariants(Settings, ReportSettings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "Default");
	VariantSettings.Enabled = False;
	VariantSettings.Description = NStr("en='Search for usage locations of application objects.';ru='Поиск мест использования объектов приложения.'");
EndProcedure

#EndRegion

#EndIf