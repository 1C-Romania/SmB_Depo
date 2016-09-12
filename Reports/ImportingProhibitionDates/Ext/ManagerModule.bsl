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
	ReportSettings.Enabled = False;
	
	Properties = ChangeProhibitionDatesServiceReUse.SectionsProperties();
	If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportingProhibitionDatesBySectionsObjectsForUsers";
		VariantDesc =
			NStr("en='Displays no-import dates"
"for users grouped by sections with objects.';ru='Выводит даты"
"запрета загрузки для пользователей, сгруппированные по разделам с объектами.'");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportingProhibitionDatesBySectionsForUsers";
		VariantDesc =
			NStr("en='Displays no-import dates"
"for users grouped by sections.';ru='Выводит даты"
"запрета загрузки для пользователей, сгруппированные по разделам.'");
	Else
		VariantName = "ImportingProhibitionDatesByObjectsForUsers";
		VariantDesc =
			NStr("en='Displays no-import dates"
"for users grouped by objects.';ru='Выводит даты"
"запрета загрузки для пользователей, сгруппированные по объектам.'");
	EndIf;
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, VariantName);
	VariantSettings.Enabled  = True;
	VariantSettings.Description = VariantDesc;
	
	If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportingProhibitionDatesByUsers";
		VariantDesc =
			NStr("en='Displays no-import dates for sections"
"with objects grouped by users.';ru='Выводит даты запрета загрузки"
"для разделов с объектами, сгруппированные по пользователям.'");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportingProhibitionDatesByUsersWithoutObjects";
		VariantDesc =
			NStr("en='Displays no-import dates"
"for sections grouped by users.';ru='Выводит даты"
"запрета загрузки для разделов, сгруппированные по пользователям.'");
	Else
		VariantName = "ImportingProhibitionDatesByUsersWithoutSections";
		VariantDesc =
			NStr("en='Displays no-import dates"
"for objects grouped by users.';ru='Выводит даты"
"запрета загрузки для объектов, сгруппированные по пользователям.'");
	EndIf;
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, VariantName);
	VariantSettings.Enabled  = True;
	VariantSettings.Description = VariantDesc;
EndProcedure

#EndRegion

#EndIf
