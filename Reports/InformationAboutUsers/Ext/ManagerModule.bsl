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
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "InformationAboutUsersAndExternalUsers");
	VariantSettings.Description = 
		NStr("en='Displays detailed information"
"about all users, including settings for login (if specified).';ru='Выводит подробные"
"сведения о всех пользователях, включая настройки для входа (если указаны).'");
	VariantSettings.FunctionalOptions.Add("UseExternalUsers");
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "InformationAboutUsers");
	VariantSettings.Description = 
		NStr("en='Displays detailed information"
"about users, including settings for login (if specified).';ru='Выводит подробные"
"сведения о пользователях, включая настройки для входа (если указаны).'");
	
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, "ExternalUserData");
	VariantSettings.Description = 
		NStr("en='Displays detailed information about"
"external users, including settings for login (if specified).';ru='Выводит подробные сведения"
"о внешних пользователях, включая настройки для входа (если указаны).'");
	VariantSettings.FunctionalOptions.Add("UseExternalUsers");
EndProcedure

#EndRegion

#EndIf

#Region EventsHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If Not Parameters.Property("VariantKey") Then
		StandardProcessing = False;
		Parameters.Insert("VariantKey", "InformationAboutUsersAndExternalUsers");
		SelectedForm = "Report.InformationAboutUsers.Form";
	EndIf;
	
EndProcedure

#EndRegion
