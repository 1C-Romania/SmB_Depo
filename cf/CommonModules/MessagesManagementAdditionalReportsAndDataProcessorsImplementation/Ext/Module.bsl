////////////////////////////////////////////////////////////////////////////////
// A COMMON IMPLEMENTATION OF MESSAGE DATA PROCESSOR OF ADDITIONAL REPORTS AND DATA PROCESSOR MANAGEMENT
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Data processor of incoming messages with type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}InstallExtension
//
// Parameters:
//  InstallationDetails - Structure, keys:
//    ID - UUID, unique
//      identifier of catalog item ref SuppliedAdditionalReportsAndDataProcessors, 
//    Presentation - String, installation presentation of
//      supplied additional data processor (will be used as
//      the name of the catalog item AdditionalReportsAndDataProcessors),
//    Installation - UUID, unique
//      ID of additional supplied data processor installation
//      ( will be used as unique ID of catalog ref AdditionalReportsAndDataProcessors), 
//  CommandSettings - ValueTable containing command settings
//      for installation of supplied additional data processor, columns:
//    ID - String, command ID
//    QuickAccess - Array(UUID), 
//      an array of unique IDs which identify service users
//      for whom the command should be included to the quick access, 
//    Schedule - RegulatoryTaskSchedule,  
//      schedule for setting the command of the additional data processor
//      (if command execution is enabled as a scheduled job),
//   Sections - ValuesTable containing commands enabling
//      settings to install the supplied additional data processor to command interface processor, columns:
//    Section - CatalogRef.MetadataObjectsIDs,
//  CatalogsAndDocuments - ValuesTable containing commands enabling
//      settings to install the supplied additional data processor to forms interface list and items, columns:
//    ObjectDestination - CatalogRef.MetadataObjectsIDs,
//  AdditionalReportOptions - Array(String), array containing
//    report variant keys of additional report, 
//  ServiceUserID - UUID defining
//    service user who activated installation of supplied additional data processor.
//
Procedure SetAdditionalReportOrProcessing(Val InstallationDetails,
		Val CommandSettings, Val SettingsLocationOfCommands, Val Sections, Val CatalogsAndDocuments, Val AdditionalReportVariants,
		Val ServiceUserID) Export
	
	// Settings are filled by message data
	QuickAccess = New ValueTable();
	QuickAccess.Columns.Add("CommandID", New TypeDescription("String"));
	QuickAccess.Columns.Add("User", New TypeDescription("CatalogRef.Users"));
	
	Jobs = New ValueTable();
	Jobs.Columns.Add("ID", New TypeDescription("String"));
	Jobs.Columns.Add("ScheduledJobSchedule", New TypeDescription("ValueList"));
	Jobs.Columns.Add("ScheduledJobUse", New TypeDescription("Boolean"));
	
	For Each CommandSetting IN CommandSettings Do
		
		If ValueIsFilled(CommandSetting.QuickAccess) Then
			
			For Each UserID IN CommandSetting.QuickAccess Do
				
				QueryText = "SELECT
				               |	Users.Ref
				               |FROM
				               |	Catalog.Users AS Users
				               |WHERE
				               |	Users.ServiceUserID = &ServiceUserID";
				Query = New Query(QueryText);
				Query.SetParameter("ServiceUserID", UserID);
				Result = Query.Execute();
				If Result.IsEmpty() Then
					
					Continue;
					
				Else
					
					Selection = Result.Select();
					Selection.Next();
					ItemRapidAccess = QuickAccess.Add();
					ItemRapidAccess.CommandID = CommandSetting.ID;
					ItemRapidAccess.User = Selection.Ref;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If CommandSetting.Schedule <> Undefined Then
			
			Job = Jobs.Add();
			Job.ID = CommandSetting.ID;
			ScheduledJobSchedule = New ValueList();
			ScheduledJobSchedule.Add(CommandSetting.Schedule);
			Job.ScheduledJobSchedule= ScheduledJobSchedule;
			Job.ScheduledJobUse = True;
			
		EndIf;
		
	EndDo;
	
	AdditionalReportsAndDataProcessorsSaaS.SetIncludedProcessingInDataArea(
		InstallationDetails,
		QuickAccess,
		Jobs,
		Sections,
		CatalogsAndDocuments,
		SettingsLocationOfCommands,
		AdditionalReportVariants,
		GetAreaUserByServiceUserID(
			ServiceUserID));
	
EndProcedure

// Data processor of incoming messages with type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DeleteExtension
//
// Parameters:
//  IDSuppliedDataProcessors - UUID,
//    ref to the catalog item SuppliedAdditionalReportsAndDataProcessors;
//  IDOfUsedDataProcessor - UUID,
//    reference to the catalog item AdditionalReportsAndDataProcessors.
//
Procedure DeleteAdditionalReportOrProcessing(Val IDSuppliedDataProcessors, Val IDOfUsedDataProcessor) Export
	
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
			IDSuppliedDataProcessors);
	
	AdditionalReportsAndDataProcessorsSaaS.DeleteComesFromDataProcessingAreas(
		SuppliedDataProcessor,
		IDOfUsedDataProcessor);
	
EndProcedure

// Data processor of incoming messages with type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DisableExtension
//
// Parameters:
//  IDExpansion - UUID,
//    ref to the catalog item SuppliedAdditionalReportsAndDataProcessors,
//   DisconnectionCause - EnumRef.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.
//
Procedure DisableAdditionalReportOrProcessing(Val IDExpansion, Val ShutdownCause = Undefined) Export
	
	If ShutdownCause = Undefined Then
		ShutdownCause = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.BlockAdministratorService;
	EndIf;
	
	SetPrivilegedMode(True);
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		IDExpansion);
	
	If CommonUse.RefExists(SuppliedDataProcessor) Then
		
		Object = SuppliedDataProcessor.GetObject();
		
		Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
		Object.ShutdownCause = ShutdownCause;
		
		Object.Write();
		
	EndIf;
	
EndProcedure

// Data processor of incoming messages with type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}EnableExtension
//
// Parameters:
//  IDExpansion - UUID,
//  ref to the catalog item SuppliedAdditionalReportsAndDataProcessors
//
Procedure EnableAdditionalReportOrProcessing(Val IDExpansion) Export
	
	SetPrivilegedMode(True);
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		IDExpansion);
	
	If CommonUse.RefExists(SuppliedDataProcessor) Then
		
		Object = SuppliedDataProcessor.GetObject();
		
		Object.Publication =
			Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
		
		Object.Write();
	EndIf;
	
EndProcedure

// Data processor of incoming messages with type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DropExtension
//
// Parameters:
//  IDExpansion - UUID,
//  ref to the catalog item SuppliedAdditionalReportsAndDataProcessors
//
Procedure RecallAdditionalReportOrProcessing(Val IDSuppliedDataProcessors) Export
	
	SetPrivilegedMode(True);
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		IDSuppliedDataProcessors);
	
	If CommonUse.RefExists(SuppliedDataProcessor) Then
		AdditionalReportsAndDataProcessorsSaaS.RecallProvidedAdditionalInformationProcessor(
			SuppliedDataProcessor);
	EndIf;
	
EndProcedure

// Processing the incoming messages with type {http://www.1c.ru/1CFresh/ApplicationExtensions/Management/a.b.c.d}SetExtensionSecurityProfile
//
// Parameters:
//  IDSuppliedDataProcessors - UUID,
//    ref to the catalog item SuppliedAdditionalReportsAndDataProcessors;
//  IDOfUsedDataProcessor - UUID,
//    ref to the catalog item AdditionalReportsAndDataProcessors.
//
Procedure SetModeForAdditionalReportConnectionOrDataAreaProcessor(Val IDSuppliedDataProcessors, Val IDOfUsedDataProcessor, Val ConnectionMode) Export
	
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		IDSuppliedDataProcessors);
	
	UsingDataProcessor = Catalogs.AdditionalReportsAndDataProcessors.GetRef(
		IDOfUsedDataProcessor);
	
	If CommonUse.RefExists(UsingDataProcessor) Then
		
		Manager = InformationRegisters.ExternalModulesConnectionModesDataAreas.CreateRecordManager();
		Manager.ExternalModule = SuppliedDataProcessor;
		Manager.SafeMode = ConnectionMode;
		Manager.Write();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function GetAreaUserByServiceUserID(Val ServiceUserID)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.ServiceUserID = &ServiceUserID";
	Query.SetParameter("ServiceUserID", ServiceUserID);
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.Users");
	
	BeginTransaction();
	Try
		Block.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		MessagePattern = NStr("en='User with user identifier of service %1 is not found';ru='Не найден пользователь с идентификатором пользователя сервиса %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, ServiceUserID);
		Raise(MessageText);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction
