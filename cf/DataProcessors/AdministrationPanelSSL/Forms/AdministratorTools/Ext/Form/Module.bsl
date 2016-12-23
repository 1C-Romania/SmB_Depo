
&AtClient
Var RefreshInterface;

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator Then
		
		// StandardSubsystems.PerformanceEstimation
		If AttributePathToData = "ConstantsSet.ExecutePerformanceMeasurements"
			Or AttributePathToData = "" Then
			Items.ProcessingProductivityRating.Enabled = ConstantsSet.ExecutePerformanceMeasurements;
		EndIf;
		// End StandardSubsystems.PerformanceEstimation
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 14)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 15);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure VisibleManagementElements(AttributePathToData = "")
	
	If AttributePathToData = "GroupDataProcessorGroupObjectsChange" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "GroupDataProcessorGroupObjectsChange", "Visible", RunMode.IsApplicationAdministrator);
		
	EndIf;
	
	If AttributePathToData = "ImportDataFromService" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ImportDataFromService", "Visible", IsInRole("SystemAdministrator") AND RunMode.Local);
		
	EndIf;
	
	// Data
	// export From the local version export for the service, from the service for the local version
	If AttributePathToData = "DataExportIntoLocalVersion" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "DataExportIntoLocalVersion", "Visible", IsInRole("FullRights") AND RunMode.SaaS);
		
	EndIf;
	
	If AttributePathToData = "DataExportForGoToService" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "DataExportForGoToService", "Visible", IsInRole("SystemAdministrator") AND RunMode.Local);
		
	EndIf;
	// Data export end
	
	If AttributePathToData = "AutomaticTextsExtraction" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationAutomaticTextExtraction", "Visible", GetFunctionalOption("StandardSubsystemsLocalMode"));
		
	EndIf;
	
	If AttributePathToData = "AdministratorReports" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationReportsAdministrator", "Visible", GetFunctionalOption("StandardSubsystemsLocalMode"));
		
	EndIf;
	
	If AttributePathToData = "DataAreaInput" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "DataAreaInput", "Visible", IsInRole("SystemAdministrator") AND CommonUseReUse.DataSeparationEnabled());
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationDataAreaInput", "Visible", IsInRole("SystemAdministrator") AND CommonUseReUse.DataSeparationEnabled());
		
	EndIf;
	
	If AttributePathToData = "ScheduledAndBackgroundJobs" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ScheduledAndBackgroundJobs", "Visible", IsInRole("SystemAdministrator"));
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationScheduledAndBackgroundTasks", "Visible", IsInRole("SystemAdministrator"));
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler DocumentRegistersCorrection
//
&AtClient
Procedure EventsLogAnalysis(Command)
	
	OpenForm("Report.EventsLogAnalysis.ObjectForm");
	
EndProcedure // EventsLogAnalysis()

// Procedure - command handler DocumentRegistersCorrection
//
&AtClient
Procedure AutomaticTextsExtraction(Command)
	
	OpenForm("DataProcessor.AutomaticTextsExtraction.Form");
	
EndProcedure // AutomaticTextsExtraction()

// Procedure - command handler GroupDocumentsReposting
//
&AtClient
Procedure GroupDocumentsReposting(Command)
	
	OpenForm("DataProcessor.GroupDocumentsReposting.Form");
	
EndProcedure // GroupDocumentsReposting()

// Procedure - command handler DocumentRegistersCorrection
//
&AtClient
Procedure DocumentRegistersCorrection(Command)
	
	OpenForm("Document.RegistersCorrection.ListForm");
	
EndProcedure // DocumentRegistersCorrection()

// Procedure - command handler DataExportForGoToService
//
&AtClient
Procedure DataExportForGoToServiceClick(Item)
	
	OpenForm("CommonForm.DataExport", , ThisForm, , );
	
EndProcedure // DataExportForGoToServiceClick()

// Procedure - command handler DataExportIntoLocalVersion
//
&AtClient
Procedure DataExportIntoLocalVersionClick(Item)
	
	OpenForm("CommonForm.DataExport", , ThisForm, , );
	
EndProcedure // DataExportIntoLocalVersionClick()

// Procedure - command handler ImportDataFromService
//
&AtClient
Procedure ImportDataFromServiceClick(Item)
	
	OpenForm("CommonForm.ImportDataFromService", , ThisForm, , );
	
EndProcedure // ImportDataFromService()

// Procedure - command handler DataImportFromTM103
//
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	OpenForm("DataProcessor.DataImportFromExternalSources.Form.ShortDescription");
	
EndProcedure // DataImportFromExternalSources()

// StandardSubsystems.BasicFunctionality
&AtClient
Procedure SearchAndDeleteDuplicates(Command)
	
	OpenForm("DataProcessor.SearchAndDeleteDuplicates.Form.SearchDuplicates");
	
EndProcedure
// End of StandardSubsystems BasicFunctionality

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure AdditionalAdministrativeDataProcessors(Command)
	
	ParametersForm = New Structure;
	ParametersForm.Insert("SectionName", "SetupAndAdministration");
	ParametersForm.Insert("DestinationObjects", New ValueList);
	ParametersForm.Insert("Kind", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor());
	ParametersForm.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ParametersForm.Insert("Title", NStr("en='Additional administrative data processors';ru='Дополнительные обработки по администрированию'"));
	OpenForm("CommonForm.AdditionalReportsAndDataProcessors", ParametersForm, ThisObject);
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure AdditionalReportsOnAdministration(Command)
	ParametersForm = New Structure;
	ParametersForm.Insert("SectionName", "SetupAndAdministration");
	ParametersForm.Insert("DestinationObjects", New ValueList);
	ParametersForm.Insert("Kind", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport());
	ParametersForm.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ParametersForm.Insert("Title", NStr("en='Additional reports on administration';ru='Дополнительные отчеты по администрированию'"));
	OpenForm("CommonForm.AdditionalReportsAndDataProcessors", ParametersForm, ThisObject);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.PerformanceEstimation
&AtClient
Procedure ExecutePerformanceMeasurementsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.PerformanceEstimation

// Procedure - command handler AdministratorReports
//
&AtClient
Procedure AdministratorReports(Command)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("Source", ThisForm.Window);
	ExecuteParameters.Insert("Uniqueness", "SetupAndAdministration");
	ExecuteParameters.Insert("Window", ThisForm.Window);
	
	ReportsVariantsClient.ShowReportsPanel("SetupAndAdministration", ExecuteParameters);
	
EndProcedure // AdministratorReports()

// Procedure - command handler DataAreaInput
//
&AtClient
Procedure DataAreaInput(Command)
	
	OpenForm("CommonForm.DataAreaInput");
	
EndProcedure // DataAreaInput()

// Procedure - command handler ScheduledAndBackgroundTasksClick
//
&AtClient
Procedure ScheduledAndBackgroundJobsClick(Item)
	
	OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form", , ThisForm, , );
	
EndProcedure // ScheduledAndBackgroundTasksClick()

// Procedure - command handler StandardODataInterfaceSetupClick
//
&AtClient
Procedure StandardODataInterfaceSetupClick(Item)
	
	OpenForm("DataProcessor.StandardODataInterfaceSetup.Form");
	
EndProcedure // StandardODataInterfaceSetupClick()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// StandardSubsystems.PerformanceEstimation
	Items.GroupPerformanceEstimation.Visible = RunMode.ThisIsSystemAdministrator;
	If RunMode.ThisIsSystemAdministrator Then
		ConstantsSet.ExecutePerformanceMeasurements = Constants.ExecutePerformanceMeasurements.Get();
	EndIf;
	// End StandardSubsystems.PerformanceEstimation
	
	// ServiceTechnology.SaaS.StandardODataInterfaceSetup
	If Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "Group6", "Visible", RunMode.SaaS AND RunMode.IsApplicationAdministrator);
		
	EndIf;
	// End ServiceTechnology.SaaS.StandardODataInterfaceSetup
	
	VisibleManagementElements();
	
	SetEnabled();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose()
	
	RefreshApplicationInterface();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES




















