////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors", procedures
// and functions that are specific for using the subsystem at offline workplace
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

#Region ServiceEventsHandlersDeclaration

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// BasicFunctionality
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToMaster"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToSubordinate"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	// AdditionalReportsAndDataProcessors
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingRightsAdd"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingPossibilityOfDataExportProcessorsFromFile"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingCapabilitiesOfDataProcessorsInExportingsFile"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingWhetherToDisplayExtendedInformation"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnFillingInaccessiblePublicationKinds"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\AdditionalProcessingBeforeWrite"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
	// InfobaseUpdate
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AdditionalReportsAndDataProcessorsOffline");
	
EndProcedure

#EndRegion

#Region ServiceEventHandlers

#Region StandardSubsystems

#Region BasicFunctionality

// The procedure is the handler of an event of the same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataMain() event handler in the syntax helper.
// 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	If ItemSend = DataItemSend.Ignore Then
		//
	ElsIf OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		If TypeOf(DataItem) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
			
			If Not ThisIsDataProcessorService(DataItem.Ref) Then
				ItemSend = DataItemSend.Ignore;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSendDataToSubordinate(DataItem, ItemSend, CreatingInitialImage, Recipient) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// Do not override standard DataProcessor.
		
	Else
		
		If TypeOf(DataItem) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
			
			If AdditionalReportsAndDataProcessorsSaaS.IsSuppliedDataProcessor(DataItem.Ref) Then
				
				DataProcessorLaunchParameters = AdditionalReportsAndDataProcessorsSaaS.UsedDataProcessorConnectionParameters(DataItem.Ref);
				FillPropertyValues(DataItem, DataProcessorLaunchParameters);
				
			EndIf;
			
		EndIf;
		
		If TypeOf(DataItem) = Type("ConstantValueManager.UseAdditionalReportsAndDataProcessors") Then
			
			If Not CreatingInitialImage Then
				ItemSend = DataItemSend.Ignore;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// Do not override standard DataProcessor.
		
	ElsIf OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		If TypeOf(DataItem) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
			
			If ValueIsFilled(DataItem.Ref) Then
				ProcessingRef = DataItem.Ref;
			Else
				ProcessingRef = DataItem.GetNewObjectRef();
			EndIf;
			
			RegisterServiceProcessing(ProcessingRef);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// Do not override standard DataProcessor.
		
	Else
		
		If TypeOf(DataItem) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
			
			If AdditionalReportsAndDataProcessorsSaaS.IsSuppliedDataProcessor(DataItem.Ref) Then
				
				DataProcessorLaunchParameters = AdditionalReportsAndDataProcessorsSaaS.UsedDataProcessorConnectionParameters(DataItem.Ref);
				FillPropertyValues(DataItem, DataProcessorLaunchParameters);
				DataItem.DataProcessorStorage = Undefined;
				
			Else
				
				If Not Constants.AdditionalReportsAndDataProcessorsIndependentUseSaaS.Get() Then
					ItemReceive = DataItemReceive.Ignore;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - it is required to receive the list of DIB exchange plan objects;
// False - it is required to receive the list of NOT DIB exchange plan.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Catalogs.AdditionalReportsAndDataProcessors);
		Objects.Add(Metadata.InformationRegisters.AdditionalInformationProcessorsFunctions);
		Objects.Add(Metadata.InformationRegisters.UserSettingsOfAccessToDataProcessors);
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should not be included into the exchange plan content.
// If the subsystem has metadata objects that should not be included in
// the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should not be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - it is required to receive the list of the exception objects of the DIB exchange plan;
// False - it is required to receive the list of NOT DIB exchange plan.
//
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.UseAdditionalReportsDirectoryAndDataprocessorsSaaS);
		Objects.Add(Metadata.Constants.AdditionalReportsAndDataProcessorsProceduralTasksMinIntervalSaaS);
		Objects.Add(Metadata.Constants.AdditionalReportsAndDataProcessorsIndependentUseSaaS);
		Objects.Add(Metadata.Constants.AllowAdditionalReportsAndDataProcessorsPerformByProceduralTasksSaaS);
		
		Objects.Add(Metadata.Catalogs.SuppliedAdditionalReportsAndDataProcessors);
		
		Objects.Add(Metadata.InformationRegisters.UseAdditionalReportsAndDataProcessorsServiceInAutonomousWorkplace);
		Objects.Add(Metadata.InformationRegisters.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas);
		Objects.Add(Metadata.InformationRegisters.SuppliedAdditionalReportsAndDataProcessorsInDataAreaSetupQueue);
		
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should be included in the
// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes registration for this plan.
// These metadata objects are used only at the time of creation
// of the initial image of the subnode and do not migrate during the exchange.
// If the subsystem has metadata objects that take part in creating an initial
// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects.
//
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.UseAdditionalReportsAndDataProcessors);
	
EndProcedure

#EndRegion

#Region AdditionalReportsAndDataProcessors

// It is called on determining if current user rights allow to add additional report or data processor into the data area.
//
// Parameters:
//  AdditionalInformationProcessor - CatalogObject.AdditionalReportsAndDataProcessors,
//    item handbook that is recorded by user.
//  Result - Boolean, in this procedure this parameter is used to set the flag showing that there is a right, StandardProcessing - Boolean, in this procedure this parameter is used to set the flag showing that the right is checked by standard processor
//
Procedure OnCheckingRightsAdd(Val AdditionalInformationProcessor, Result, StandardProcessing) Export
	
	If OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		Result = True;
		StandardProcessing = False;
		Return;
		
	EndIf;
	
EndProcedure

// It is called when verifying the option of importing an additional report or data processor from file
//
// Parameters:
//  AdditionalInformationProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean, in this procedure this parameter is used to set the flag showing the option to import an additional report or data processor from file, StandardProcessing - Boolean, in this procedure this parameter is used to set the flag showing the execution of the standard processing checking the option to import an additional report or data processor from file, StandardProcessing
//
Procedure OnCheckingPossibilityOfDataExportProcessorsFromFile(Val AdditionalInformationProcessor, Result, StandardProcessing) Export
	
	SetPrivilegedMode(True);
	
	If OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		Result = Not ThisIsDataProcessorService(AdditionalInformationProcessor);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Is called on checking possibility to export additional report or data processor in file
//
// Parameters:
//  AdditionalInformationProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean, in this parameter during this procedure sets
//    the flag of possibility of additional report
//  or data processor import from file, StandardProcessing - Boolean, in this parameter during this procedure
//    sets the flag of checking standard processing completion possibility of additional report or data processor import in file.
//
Procedure OnCheckingCapabilitiesOfDataProcessorsInExportingsFile(Val AdditionalInformationProcessor, Result, StandardProcessing) Export
	
	SetPrivilegedMode(True);
	
	If OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		Result = Not ThisIsDataProcessorService(AdditionalInformationProcessor);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// It is called when checking the necessity to show the detailed information on additional reports and data processors in user interface.
//
// Parameters:
//  AdditionalInformationProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean, in this procedure this parameter is used to set the flag showing the necessity to display detailed information on additional reports and data processors import in user interface.
//  StandardProcessing - Boolean, in this procedure this parameter is used to set the flag showing the execution of standard processing checking the necessity to display detailed information of additional reports and data processors in user interface.
//
Procedure OnCheckingWhetherToDisplayExtendedInformation(Val AdditionalInformationProcessor, Result, StandardProcessing) Export
	
	If OfflineWorkService.ThisIsOfflineWorkplace() Then
		Result = Not ThisIsDataProcessorService(AdditionalInformationProcessor);
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Fills the kinds of additional reports and data processors
// publication that are unavailable for use in current infobase model.
//
// Parameters:
//  UnavailablePublicationsKinds - Strings array
//
Procedure OnFillingInaccessiblePublicationKinds(Val UnavailablePublicationsKinds) Export
	
	If OfflineWorkService.ThisIsOfflineWorkplace() Then
		UnavailablePublicationsKinds.Add("DebugMode");
	EndIf;
	
EndProcedure

// Procedure should be called from
//  the event BeforeWrite of catalog AdditionalReportsAndDataProcessors,
//  it checks equality of changing item attributes of
//  this catalog for additional data processors, derived from additional data processors service manager directory.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
//  Denial - Boolean, flag showing that catalog item recording is rejected.
//
Procedure AdditionalProcessingBeforeWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If OfflineWorkService.ThisIsOfflineWorkplace() Then
		
		If (Source.DeletionMark OR Source.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled) AND ThisIsDataProcessorService(Source.Ref) Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Additional report or the %1 data processor was exported from the service and can not be disabled from the offline workplace!
                      |To delete an additional report or data processor, it is
                      |necessary to disable the service in application and synchronize data of the offline workplace with the service.'"),
				Source.Description);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Registers an additional report or data processor as
// a processor received at the offline workplace from service.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors.
//
Procedure RegisterServiceProcessing(Val Ref)
	
	Set = InformationRegisters.UseAdditionalReportsAndDataProcessorsServiceInAutonomousWorkplace.CreateRecordSet();
	Set.Filter.AdditionalReportOrDataProcessor.Set(Ref);
	Record = Set.Add();
	Record.AdditionalReportOrDataProcessor = Ref;
	Record.Supplied = True;
	Set.Write();
	
EndProcedure

// Function checks whether the additional data processor was received at the offline workplace from service.
//
// Parameters:
// Ref - CatalogRef.AdditionalReportsAndDataProcessors.
//
// Returns:
//  Boolean.
//
Function ThisIsDataProcessorService(Ref)
	
	Manager = InformationRegisters.UseAdditionalReportsAndDataProcessorsServiceInAutonomousWorkplace.CreateRecordManager();
	Manager.AdditionalReportOrDataProcessor = Ref;
	Manager.Read();
	
	If Manager.Selected() Then
		Return Manager.Supplied;
	Else
		Return False;
	EndIf;
	
EndFunction

#EndRegion
