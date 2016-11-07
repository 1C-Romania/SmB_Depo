#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ObjectEventsHandlers

// Settings of common form for subsystem report "Reports options".
//
// Parameters:
//   Form - ManagedForm - Report form.
//   VariantKey - String - Name of predefined report option or unique custom identifier.
//   Settings - Structure - see return value ReportsClientServer.GetReportSettingsByDefault().
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	
	Settings.FormImmediately = True;
	Settings.OutputAmountSelectedCells = False;
	
EndProcedure

// Gets called when report is executed with method ComposeResult().
//
// Parameters:
//  ResultDocument - SpreadsheetDocument - document that
//  displays the result, DetailsData - Arbitrary - a variable into
//    which details
//  data should be placed, StandardDataProcessor - Boolean - A flag of standard (system)
//    event processing is passed to this parameter.
//
Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	ResultDocument.Clear();
	
	BeginTransaction();
	
	Constants.SecurityProfilesAreUsed.Set(True);
	Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(True);
	
	DataProcessors.PermissionSettingsForExternalResourcesUse.ClearGivenPermissions();
	
	PermissionsQueries = WorkInSafeModeService.ConfigurationPermissionsUpdateQueries();
	
	Manager = InformationRegisters.PermissionQueriesOnUseExternalResources.PermissionsApplicationManager(PermissionsQueries);
	
	RollbackTransaction();
	
	ResultDocument.Put(Manager.Presentation(True));
	
EndProcedure

#EndRegion

#EndIf
