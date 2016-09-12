////////////////////////////////////////////////////////////////////////////////
// "Additional reports and data processors in the service model" subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Function checks whether the passed additional
//  data processor is supplied additional data processor instance.
//
// Parameters:
// UsingDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors.
//
// Returns:
//  Boolean.
//
Function IsSuppliedDataProcessor(UsingDataProcessor) Export
	
	SuppliedDataProcessor = SuppliedDataProcessor(UsingDataProcessor);
	Return ValueIsFilled(SuppliedDataProcessor);
	
EndFunction

// Function returns supplied data processor corresponding to the used data processor.
//
// Parameters:
// UsingDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors.
//
// Returns:
//  CatalogRef.SuppliedAdditionalReportsAndDataProcessors.
//
Function SuppliedDataProcessor(UsingDataProcessor) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		
		Raise NStr("en='AdditionalReportsAndDataProcessorsSaaS.SuppliedDataProcessor()"
"function usage is only available in sessions with the specified data separation.';ru='Использование"
"функции ДополнительныеОтчетыИОбработкиВМоделиСервиса.ПоставляемаяОбработка() доступно только сеансов с установленным разделением данных!'");
		
	EndIf;
	
	QueryText = "SELECT TOP 1
	               |	Installations.SuppliedDataProcessor AS SuppliedDataProcessor
	               |FROM
	               |	InformationRegister.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas AS Installations
	               |WHERE
	               |	Installations.UsingDataProcessor = &UsingDataProcessor";
	Query = New Query(QueryText);
	Query.SetParameter("UsingDataProcessor", UsingDataProcessor);
	SetPrivilegedMode(True);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		Return Selection.SuppliedDataProcessor;
	EndIf;
	
EndFunction

// Function returns the used processor corresponding to the supplied data processor for the DataArea separator current value.
//
// Parameters:
//  SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors.
//
// Returns:
//  CatalogRef.AdditionalReportsAndDataProcessors.
//
Function UsingDataProcessor(SuppliedDataProcessor) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		
		Raise NStr("en='AdditionalReportsAndDataProcessorsSaaS.UsedDataProcessor()"
"function usage is only available in sessions with the specified data separation.';ru='Использование"
"функции ДополнительныеОтчетыИОбработкиВМоделиСервиса.ИспользуемаяОбработка() доступно только сеансов с установленным разделением данных!'");
		
	EndIf;
	
	QueryText = "SELECT
	               |	Installations.UsingDataProcessor AS UsingDataProcessor
	               |FROM
	               |	InformationRegister.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas AS Installations
	               |WHERE
	               |	Installations.SuppliedDataProcessor = &SuppliedDataProcessor";
	Query = New Query(QueryText);
	Query.SetParameter("DataArea", CommonUse.SessionSeparatorValue());
	Query.SetParameter("SuppliedDataProcessor", SuppliedDataProcessor);
	SetPrivilegedMode(True);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		Return Selection.UsingDataProcessor;
	EndIf;
	
EndFunction

// Function returns installations listing of supplied additional data processor in the data area.
//
// Parameters:
//  SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors.
//
// Returns:
//  ValueTable, columns:
//    DataArea - number(7,0),
//    UsedDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors.
//
Function ListOfInstallations(Val SuppliedDataProcessor) Export
	
	QueryText =
		"SELECT
		|	Installations.DataAreaAuxiliaryData AS DataArea,
		|	Installations.UsingDataProcessor AS UsingDataProcessor
		|FROM
		|	InformationRegister.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas AS Installations
		|WHERE
		|	Installations.SuppliedDataProcessor = &SuppliedDataProcessor";
	Query = New Query(QueryText);
	Query.SetParameter("SuppliedDataProcessor", SuppliedDataProcessor);
	Return Query.Execute().Unload();
	
EndFunction

// Function returns installations queue of supplied additional data processor in the data area.
//
// Parameters:
//  SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors.
//
// Returns:
//  ValueTable, columns:
//    DataArea - number(7,0),
//    SettingParameters - ValueStorage.
//
Function InstallationsQueue(Val SuppliedDataProcessor) Export
	
	QueryText =
		"SELECT
		|	Queue.DataAreaAuxiliaryData AS DataArea,
		|	Queue.InstallationParameters AS InstallationParameters
		|FROM
		|	InformationRegister.SuppliedAdditionalReportsAndDataProcessorsInDataAreaSetupQueue AS Queue
		|WHERE
		|	Queue.SuppliedDataProcessor = &SuppliedDataProcessor";
	Query = New Query(QueryText);
	Query.SetParameter("SuppliedDataProcessor", SuppliedDataProcessor);
	Return Query.Execute().Unload();
	
EndFunction

// Sets supplied additional data processor to the current data area after receiving
// supplied data and informs MS in case of a failure
//
// See description of the parameters SetSuppliedDataProcessorToDataArea
// 
Procedure SetIncludedProcessingOnReceiving(Val InstallationDetails, Val QuickAccess, Val Tasks, Val Sections, 
	Val CatalogsAndDocuments, Val SettingsLocationOfCommands, Val AdditionalReportVariants, Val Responsible) Export
	
	Try
		SetIncludedProcessingInDataArea(InstallationDetails, QuickAccess, 
			Tasks, Sections, CatalogsAndDocuments, SettingsLocationOfCommands, AdditionalReportVariants, Responsible);
	Except
		
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(InstallationDetails.ID);
		ProcessAdditionalInformationProcessorSettingToDataAreaError(
			SuppliedDataProcessor, InstallationDetails.Installation, ErrorMessage);
			
	EndTry;
	
EndProcedure

// Sets supplied additional data processor to the current data area.
//
// Parameters:
//  InstallationDetails - Structure, keys:
//    ID - UUID, unique
//      identifier of catalog
//    item ref SuppliedAdditionalReportsAndDataProcessors, Presentation - String, installation presentation of
//      supplied additional data processor (will be used as
//      the
//    name of the catalog item AdditionalReportsAndDataProcessors), Installation - UUID, a
//      unique identifier of additional data processor supplied
//      installation (will be used as
//  a unique identifier of catalog ref AdditionalProcessorsAndReports), QuickAccess - ValuesTable containing settings of
//     additional data processor commands enabling to the quick search of application users, columns:
//    CommandID - String, command
//    ID, User - CatalogRef.User,
//  Jobs - ValuesTable containing settings of additional
//      data processor commands enabling as scheduled jobs, columns:
//    ID - String, command
//    ID, ScheduledJobSchedule - ValuesList containing
//       one
//    item of the ScheduledJobSchedule type, ScheduledJobUse - Boolean, shows that
//      command is executed as
//  the scheduled job, Sections - ValuesTable containing commands enabling
//      settings to install the supplied additional data processor to command interface processor, columns:
//    Section - CatalogRef.MetadataObjectsIDs,
//  CatalogsAndDocuments - ValuesTable containing commands enabling
//      settings to install the supplied additional data processor to forms interface list and items, columns:
//    ObjectDestination - CatalogRef.MetadataObjectsIDs,
//  AdditionalReportOptions - Array(String), array containing reports
//    options keys
//  of the additional report, Responsible - CatalogRef.Users.
//
Procedure SetIncludedProcessingInDataArea(Val InstallationDetails, Val QuickAccess, Val Tasks, Val Sections, Val CatalogsAndDocuments, Val SettingsLocationOfCommands, Val AdditionalReportVariants, Val Responsible) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	WriteLogEvent(
		NStr("en='Supplied additional reports and processings.Installation of the supplied processing to the data area is initiated';ru='Поставляемые дополнительные отчеты и обработки.Инициирована установка поставляемой обработки в область данных'",
		CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Information,
		,
		String(InstallationDetails.ID),
		String(InstallationDetails.Installation));
	
	Try
		
		SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(InstallationDetails.ID);
		
		Set = InformationRegisters.SuppliedAdditionalReportsAndDataProcessorsInDataAreaSetupQueue.CreateRecordSet();
		Set.Filter.SuppliedDataProcessor.Set(SuppliedDataProcessor);
		Set.Write();
		
		If CommonUse.RefExists(SuppliedDataProcessor) Then
			
			ActualCommands = SuppliedDataProcessor.Commands.Unload();
			ActualCommands.Columns.Add("ScheduledJobSchedule", New TypeDescription("ValueList"));
			ActualCommands.Columns.Add("ScheduledJobUse", New TypeDescription("Boolean"));
			ActualCommands.Columns.Add("ScheduledJobGUID", New TypeDescription("UUID"));
			
			For Each ActualCommand IN ActualCommands Do
				
				TaskSetting = Tasks.Find(ActualCommand.ID, "ID");
				If TaskSetting <> Undefined Then
					FillPropertyValues(ActualCommand, TaskSetting, "ScheduledJobSchedule, ScheduledJobUse");
				EndIf;
				
			EndDo;
			
			// Generating the AdditionalReportsAndDataProcessors catalog item acting as a used data processor
			UsedDataProcessorRef = UsingDataProcessor(SuppliedDataProcessor);
			If ValueIsFilled(UsedDataProcessorRef) Then
				UsingDataProcessor = UsedDataProcessorRef.GetObject();
			Else
				UsingDataProcessor = Catalogs.AdditionalReportsAndDataProcessors.CreateItem();
			EndIf;
			
			FillUsedDataProcessorSettings(
				UsingDataProcessor, SuppliedDataProcessor);
			
			If ValueIsFilled(Sections) AND Sections.Count() > 0 Then
				UsingDataProcessor.Sections.Load(Sections);
			EndIf;
			
			If ValueIsFilled(CatalogsAndDocuments) AND CatalogsAndDocuments.Count() > 0 Then
				
				UsingDataProcessor.Purpose.Load(CatalogsAndDocuments);
				UsingDataProcessor.UseForListForm = SettingsLocationOfCommands.UseForListForm;
				UsingDataProcessor.UseForObjectForm = SettingsLocationOfCommands.UseForObjectForm;
				
			EndIf;
			
			UsingDataProcessor.Description = InstallationDetails.Presentation;
			UsingDataProcessor.Responsible = Responsible;
			
			UsingDataProcessor.AdditionalProperties.Insert("QuickAccess", QuickAccess);
			UsingDataProcessor.AdditionalProperties.Insert("ActualCommands", ActualCommands);
			
			If UsingDataProcessor.IsNew() Then
				UsingDataProcessor.SetNewObjectRef(
					Catalogs.AdditionalReportsAndDataProcessors.GetRef(
						InstallationDetails.Installation));
			EndIf;
			
			// Supplied and used data processor is set
			RecordSet = InformationRegisters.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas.CreateRecordSet();
			RecordSet.Filter.SuppliedDataProcessor.Set(SuppliedDataProcessor);
			Record = RecordSet.Add();
			Record.SuppliedDataProcessor = SuppliedDataProcessor;
			If UsingDataProcessor.IsNew() Then
				Record.UsingDataProcessor = UsingDataProcessor.GetNewObjectRef();
			Else
				Record.UsingDataProcessor = UsingDataProcessor.Ref;
			EndIf;
			RecordSet.Write();
			
			UsingDataProcessor.Write();
			
			// Place options of additional report to sections that
			// are selected by user during instalation (or developer during creating
			// manifest if user does not change the default settings.
			If CommonUseClientServer.SubsystemExists("StandardSubsystems.ReportsVariants") Then
				ModuleReportsVariants = CommonUseClientServer.CommonModule("ReportsVariants");
				
				For Each VariantAdditionalReport IN AdditionalReportVariants Do
					
					VariantRef = ModuleReportsVariants.GetRef(UsingDataProcessor.Ref, VariantAdditionalReport.Key);
					If VariantRef <> Undefined Then
						
						Variant = VariantRef.GetObject();
						Variant.Placement.Clear();
						
						For Each PlacingItem IN VariantAdditionalReport.Placement Do
							
							OptionPlacement = Variant.Placement.Add();
							OptionPlacement.Use = True;
							If CommonUseClientServer.CompareVersions(StandardSubsystemsServer.LibraryVersion(), "2.2.3.1") >= 0 Then
								OptionPlacement.Subsystem = PlacingItem.Section;
							Else
								OptionPlacement.SectionOrGroup = PlacingItem.Section;
							EndIf;
							OptionPlacement.Important = PlacingItem.Important;
							OptionPlacement.SeeAlso = PlacingItem.SeeAlso;
							
						EndDo;
						
						Variant.Write();
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
			
			
			
			// Send to MS a message about successful data processor installation in the data area
			Message = MessagesSaaS.NewMessage(
				MessageControlAdditionalReportsAndDataprocessorsInterface.MessageAdditionalReportOrDataProcessorInstalled());
			
			Message.Body.Zone = CommonUse.SessionSeparatorValue();
			Message.Body.Extension = SuppliedDataProcessor.UUID();
			Message.Body.Installation = InstallationDetails.Installation;
			
			MessagesSaaS.SendMessage(
				Message,
				SaaSReUse.ServiceManagerEndPoint(),
				True);
			
			WriteLogEvent(NStr("en='Supplied additional reports and processings. Setup to the data area';ru='Поставляемые дополнительные отчеты и обработки.Установка в область данных'",
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				SuppliedDataProcessor,
				String(InstallationDetails.Installation));
				
		Else
			
			// Supplied data processor has not been synchronized via the supplied data.
			// It will be written to the installation queue and processed
			// after supplied data synchronization is complete.
			
			Context = New Structure(
				"QuickAccess,Tasks,Sections,CatalogsAndDocuments,SettingsLocationOfCommands,AdditionalReportVariants,Responsible,Presentation,Installation",
				QuickAccess,
				Tasks,
				Sections,
				CatalogsAndDocuments,
				SettingsLocationOfCommands,
				AdditionalReportVariants,
				Responsible,
				InstallationDetails.Presentation,
				InstallationDetails.Installation);
			
			Manager = InformationRegisters.SuppliedAdditionalReportsAndDataProcessorsInDataAreaSetupQueue.CreateRecordManager();
			Manager.SuppliedDataProcessor = SuppliedDataProcessor;
			Manager.InstallationParameters = New ValueStorage(Context);
			Manager.Write();
			
			WriteLogEvent(NStr("en='Supplied addittional reports and processings. Installation to the data area is delayed';ru='Поставляемые дополнительные отчеты и обработки.Установка в область данных отложена'",
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				String(InstallationDetails.ID),
				String(InstallationDetails.Installation));
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	MessageExchange.DeliverMessages();

EndProcedure

// Deletes supplied additional data processor from the current data area.
//
// Parameters:
//  SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors,
//  UsedDataProcessorID - UUID, GUID of
//    the AdditionalReportsAndDataProcessors catalog item located in the dara area.
//
Procedure DeleteComesFromDataProcessingAreas(Val SuppliedDataProcessor, Val IDOfUsedDataProcessor) Export
	
	BeginTransaction();
	
	Try
		
		SetPrivilegedMode(True);
		
		Try
			
			UsingDataProcessor = Catalogs.AdditionalReportsAndDataProcessors.GetRef(
				IDOfUsedDataProcessor);
			
			// Clear link between the supplied data processor and used one
			RecordSet = InformationRegisters.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas.CreateRecordSet();
			RecordSet.Filter.SuppliedDataProcessor.Set(SuppliedDataProcessor);
			
			// Delete used data processor
			DataProcessorObject = UsingDataProcessor.GetObject();
			If DataProcessorObject <> Undefined Then
				DataProcessorObject.DataExchange.Load = True;
				DataProcessorObject.Delete();
			EndIf;
			
			RecordSet.Write();
			
			WriteLogEvent(NStr("en='Supplied additional reports and processings. Deletion out of the data area';ru='Поставляемые дополнительные отчеты и обработки.Удаление из области данных'",
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				SuppliedDataProcessor,
				String(IDOfUsedDataProcessor));
			
		Except
			
			ErrorMessage = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(NStr("en='Supplied additional reports and processings. Error of deletion out of the data area';ru='Поставляемые дополнительные отчеты и обработки.Ошибка удаления из область данных'",
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				SuppliedDataProcessor,
				String(IDOfUsedDataProcessor) + Chars.LF + Chars.CR + ErrorMessage);
			
			// Send to MS a message about failed data processor installation in the data area
			Message = MessagesSaaS.NewMessage(
				MessageControlAdditionalReportsAndDataprocessorsInterface.ErrorMessageRemoveAdditionalReportOrDataProcessors());
			
			Message.Body.Zone = CommonUse.SessionSeparatorValue();
			Message.Body.Extension = SuppliedDataProcessor.UUID();
			Message.Body.Installation = IDOfUsedDataProcessor;
			Message.Body.ErrorDescription = ErrorMessage;
			
			MessagesSaaS.SendMessage(
				Message,
				SaaSReUse.ServiceManagerEndPoint());
			
		EndTry;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Deletes supplied additional processor from all
//  data areas of the current infobase.
//
// Parameters:
//  SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors.
//
Procedure RecallProvidedAdditionalInformationProcessor(Val SuppliedDataProcessor) Export
	
	BeginTransaction();
	
	Try
		
		Installations = ListOfInstallations(SuppliedDataProcessor);
		For Each Installation IN Installations Do
			
			MethodParameters = New Array;
			MethodParameters.Add(SuppliedDataProcessor);
			MethodParameters.Add(Installation.UsingDataProcessor.UUID());
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName"    , "AdditionalReportsAndDataProcessorsSaaS.DeleteSuppliedDataProcessorFromDataArea");
			JobParameters.Insert("Parameters"    , MethodParameters);
			JobParameters.Insert("RestartCountOnFailure", 3);
			JobParameters.Insert("DataArea", Installation.DataArea);
			
			JobQueue.AddJob(JobParameters);
			
		EndDo;
		
		DataProcessorObject = SuppliedDataProcessor.GetObject();
		DataProcessorObject.DataExchange.Load = True;
		DataProcessorObject.Delete();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Processes error while setting additional data processor to the data area.
//
// Parameters:
//  SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors,
//  InstallationID - UUID,
//  ExceptionText - String, exception text.
//
Procedure ProcessAdditionalInformationProcessorSettingToDataAreaError(Val SuppliedDataProcessor, Val InstallationID, Val ErrorMessage) Export
	
	WriteLogEvent(NStr("en='Supplied additional reports and processings. Error of installation to the data area';ru='Поставляемые дополнительные отчеты и обработки.Ошибка установки в область данных'",
		CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Error,
		,
		SuppliedDataProcessor,
		String(InstallationID) + Chars.LF + Chars.CR + ErrorMessage);
	
	BeginTransaction();		
	Try
		
		// Send to MS a message about failed data processor installation in the data area
		Message = MessagesSaaS.NewMessage(
			MessageControlAdditionalReportsAndDataprocessorsInterface.ErrorMessageInstallingAdditionalReportOrDataProcessors());
		
		Message.Body.Zone = CommonUse.SessionSeparatorValue();
		Message.Body.Extension = SuppliedDataProcessor.UUID();
		Message.Body.Installation = InstallationID;
		Message.Body.ErrorDescription = ErrorMessage;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaSReUse.ServiceManagerEndPoint(),
			True);
	
		CommitTransaction();

	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	MessageExchange.DeliverMessages();
	
EndProcedure

// Returns connection parameters of the supplied additional data processor.
//
// Parameters:
//  UsingDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors.
//
// Returns - Structure:
//  * DataProcessorStorage - ValueStorage containing BinaryData
//      of the
//  additional repot or data processor, * SafeMode - Boolean, check box of data processor connection in the safe mode.
//
Function UsedDataProcessorConnectionParameters(Val UsingDataProcessor) Export
	
	SetPrivilegedMode(True);
	
	SuppliedDataProcessor = SuppliedDataProcessor(UsingDataProcessor);
	If ValueIsFilled(SuppliedDataProcessor) Then
		
		Properties = "SafeMode, ProcessorStorage";
		Result = New Structure(Properties);
		FillPropertyValues(Result, CommonUse.ObjectAttributesValues(SuppliedDataProcessor, Properties));
		Return Result;
		
	EndIf;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

#Region ServiceEventsHandlersDeclaration

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	// BasicFunctionality
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	// AdditionalReportsAndDataProcessors
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingRightsAdd"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingPossibilityOfDataExportProcessorsFromFile"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingCapabilitiesOfDataProcessorsInExportingsFile"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingWhetherToDisplayExtendedInformation"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnFillingInaccessiblePublicationKinds"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\AdditionalProcessingBeforeWrite"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\BeforeAdditionalInformationProcessorDeletion"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnGetOfRegistrationData"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnEnableExternalProcessor"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnCreateExternalDataProcessor"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.AdditionalReportsAndDataProcessors\OnGetSafeModeSessionsPermissions"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	// InfobaseUpdate
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	// SaaS
	
	ServerHandlers["StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationSendingMessageInterfaces"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\OnDeterminingVersionOfCorrespondingInterface"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
	// DataAreasExportImport
	
	ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
		"AdditionalReportsAndDataProcessorsSaaS");
	
EndProcedure

#EndRegion

#Region ServiceEventHandlers

#Region StandardSubsystems

#Region BasicFunctionality

// Fills the array with the list of metadata objects names that might include references
// to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array       - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(
		Metadata.InformationRegisters.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas.FullName());
	
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
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If Not Constants.AdditionalReportsAndDataProcessorsIndependentUseSaaS.Get() Then
			
			If AdditionalInformationProcessor <> Undefined Then
				
				If AdditionalInformationProcessor.IsNew() Then
					ProcessingRef = AdditionalInformationProcessor.GetNewObjectRef();
				Else
					ProcessingRef = AdditionalInformationProcessor.Ref;
				EndIf;
				
				Result = IsSuppliedDataProcessor(ProcessingRef);
				StandardProcessing = False;
				
			Else
				
				Result = False;
				StandardProcessing = False;
				
			EndIf;
			
		EndIf;
		
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
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Result = (Constants.AdditionalReportsAndDataProcessorsIndependentUseSaaS.Get()) 
			AND (NOT IsSuppliedDataProcessor(AdditionalInformationProcessor));
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
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Result = Not IsSuppliedDataProcessor(AdditionalInformationProcessor);
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
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Result = Not IsSuppliedDataProcessor(AdditionalInformationProcessor);
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
	
	If CommonUseReUse.DataSeparationEnabled() Then
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
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If CommonUseReUse.SessionWithoutSeparator() Then
		Return;
	EndIf;
	
	If IsSuppliedDataProcessor(Source.Ref) Then
		
		ControlledAttributes = AdditionalReportsAndDataProcessorsSaaSReUse.ControlledAttributes();
		OldValues = CommonUse.ObjectAttributesValues(Source.Ref, ControlledAttributes);
		
		For Each ControlledAttribute IN ControlledAttributes Do
			
			SourceProp = Undefined;
			ResultAttribute = Undefined;
			
			If TypeOf(Source[ControlledAttribute]) = Type("ValueStorage") Then
				SourceProp = Source[ControlledAttribute].Get();
			Else
				SourceProp = Source[ControlledAttribute];
			EndIf;
			
			If TypeOf(OldValues[ControlledAttribute]) = Type("ValueStorage") Then
				ResultAttribute = OldValues[ControlledAttribute].Get();
			Else
				ResultAttribute = OldValues[ControlledAttribute];
			EndIf;
			
			If SourceProp <> ResultAttribute Then
				
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Invalid attempt of the %1 attribute value modification for the %2 additional processing received from the directory of the service manager additional processings!';ru='Недопустимая попытка изменения значения реквизита %1 для дополнительной обработки %2, полученной из каталога дополнительных обработок менеджера сервиса!'"), 
					ControlledAttribute, Source.Description);
				
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure should be called from
//  the BeforeDeletion event of the AdditionalReportsAndDataProcessors catalog.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
//  Denial - Boolean, check box of refusal to delete catalog item from infobase.
//
Procedure BeforeAdditionalInformationProcessorDeletion(Source, Cancel) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		// Determine substituted data processor
		SuppliedDataProcessor = SuppliedDataProcessor(Source.Ref);
		
		If ValueIsFilled(SuppliedDataProcessor) Then
			
			// Clear a match of used data processor to the supplied one
			RecordSet = InformationRegisters.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas.CreateRecordSet();
			RecordSet.Filter.SuppliedDataProcessor.Set(SuppliedDataProcessor);
			RecordSet.Write();
			
			// Send to MS message about removing data processor from the data area
			Message = MessagesSaaS.NewMessage(
				MessageControlAdditionalReportsAndDataprocessorsInterface.MessageAdditionalReportOrDataProcessorIsDeleted());
			
			Message.Body.Zone = CommonUse.SessionSeparatorValue();
			Message.Body.Extension = SuppliedDataProcessor.UUID();
			Message.Body.Installation = Source.Ref.UUID();
			
			MessagesSaaS.SendMessage(
				Message,
				SaaSReUse.ServiceManagerEndPoint());
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Called while receiving registration data for a
// new additional report or processor.
//
Procedure OnGetOfRegistrationData(Object, RegistrationData, StandardProcessing) Export
	
	SetPrivilegedMode(True);
	
	If Not Object.IsNew() AND CommonUseReUse.DataSeparationEnabled() Then
		
		SuppliedDataProcessor = SuppliedDataProcessor(Object.Ref);
		If ValueIsFilled(SuppliedDataProcessor) Then
			
			RegistrationData = GetRegistrationData(SuppliedDataProcessor);
			StandardProcessing = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Called while enabling external processor.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors,
//  StandardProcessor - Boolean, check box showing the
//    need to
//  execute standard processor of enabling external processor, Result - String - name of enabled external report or processor (in this case, if
//    in the handler for the StandardProcessor parameter False value is set).
//
Procedure OnEnableExternalProcessor(Val Ref, StandardProcessing, Result) Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		// Check whether passed parameters are correct
		If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") Or Ref = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
			Raise NStr("en='You have requested to connect additional data processor that does not exist.';ru='Запрошено подключение несуществующей дополнительной обработки!'");
		EndIf;
		
		CheckOptionExecution(Ref);
		
		StandardProcessing = False;
		
		ConnectionParameters = UsedDataProcessorConnectionParameters(Ref);
		
		SafeMode = WorkInSafeModeServiceSaaS.ExternalModuleExecutionMode(Ref);
		If SafeMode = Undefined Then
			SafeMode = True;
		EndIf;
		
		AddressInTemporaryStorage = PutToTempStorage(ConnectionParameters.DataProcessorStorage.Get());
		
		If IsReport(Ref) Then
			Result = ExternalReports.Connect(AddressInTemporaryStorage, , SafeMode);
		Else
			Result = ExternalDataProcessors.Connect(AddressInTemporaryStorage, , SafeMode);
		EndIf;
		
	EndIf;
	
EndProcedure

// Called while creating external processor object.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors,
//  StandardProcessor - Boolean, check box showing the
//    need to
//  execute standard processor of enabling external processor, Result - ExternalDataProcessorObject, ExternalReportObject - object of enabled external
//    report or processor (in this case if in the handler for the StandardProcessor parameter False value is set).
//
Procedure OnCreateExternalDataProcessor(Val Ref, StandardProcessing, Result) Export
	
	StandardProcessing = True;
	DataProcessorName = Undefined;
	
	OnEnableExternalProcessor(Ref, StandardProcessing, DataProcessorName);
	
	If Not StandardProcessing Then
		
		If DataProcessorName = Undefined Then
			Raise NStr("en='You have requested to create additional data processor that does not exist.';ru='Запрошено создание объекта несуществующей дополнительной обработки!'");
		EndIf;
		
		CheckOptionExecution(Ref);
		
		If IsReport(Ref) Then
			Result = ExternalReports.Create(DataProcessorName);
		Else
			Result = ExternalDataProcessors.Create(DataProcessorName);
		EndIf;
		
	EndIf;
	
EndProcedure

// Called while receiving permissions of the safe mode session.
//
// Parameters:
//  SessionKey - UUID,
//  PermissionDescriptions - ValueTable:
//    * PermissionKind - String,
//    * Parameters - ValueStorage,
//  StandardProcessing - Boolean, check box showing the need to execute standard processor
//
Procedure OnGetSafeModeSessionsPermissions(Val SessionKey, PermissionDescriptions, StandardProcessing) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		StandardProcessing = False;
		
		SetPrivilegedMode(True);
		UsingDataProcessor = Catalogs.AdditionalReportsAndDataProcessors.GetRef(SessionKey);
		If IsSuppliedDataProcessor(UsingDataProcessor) Then
			
			SuppliedDataProcessor = SuppliedDataProcessor(UsingDataProcessor);
			
			QueryText =
				"SELECT
				|	permissions.TypePermissions AS TypePermissions,
				|	permissions.Parameters AS Parameters
				|FROM
				|	Catalog.SuppliedAdditionalReportsAndDataProcessors.permissions AS permissions
				|WHERE
				|	permissions.Ref = &Ref";
			Query = New Query(QueryText);
			Query.SetParameter("Ref", SuppliedDataProcessor);
			PermissionDescriptions = Query.Execute().Unload();
			
		Else
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Supplied processing for the launch key %1 has not been found!';ru='Не обнаружена поставляемая обработка для ключа запуска %1!'"),
				String(SessionKey));
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "AdditionalReportsAndDataProcessorsSaaS.LockAdditionalReportsAndDataProcessorsForUpdate";
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "AdditionalReportsAndDataProcessorsSaaS.RequestAdditionalReportsAndDataProcessorsUpdate";
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	
EndProcedure

#EndRegion

#Region SaaS

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetIBParameterTable()
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUseClientServer.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "UseAdditionalReportsDirectoryAndDataprocessorsSaaS");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "AdditionalReportsAndDataProcessorsProceduralTasksMinIntervalSaaS");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "AdditionalReportsAndDataProcessorsIndependentUseSaaS");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "AllowAdditionalReportsAndDataProcessorsPerformByProceduralTasksSaaS");
	EndIf;
	
EndProcedure

// Handler of event WhenYouDefineAliasesHandlers.
//
// Fills the map of method names and call aliases from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for
//   example, ClearDataArea Value - Method name for calling,
//    for example SaaSOperations.ClearDataArea. You can specify Undefined as a value, in this case
//    the name is assumed to match the alias
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("AdditionalReportsAndDataProcessorsSaaS.UsedDataProcessorSettingsActualization");
	// Compatibility with SSL versions 2.2.1.25 and less
	AccordanceNamespaceAliases.Insert("AdditionalReportsAndDataProcessorsSaaS.SetSuppliedDataProcessorToDataArea", 
		"AdditionalReportsAndDataProcessorsSaaS.SetSuppliedDataProcessorOnReceive");
	AccordanceNamespaceAliases.Insert("AdditionalReportsAndDataProcessorsSaaS.SetSuppliedDataProcessorOnReceive");
	AccordanceNamespaceAliases.Insert("AdditionalReportsAndDataProcessorsSaaS.DeleteSuppliedDataProcessorFromDataArea");
	AccordanceNamespaceAliases.Insert(Metadata.ScheduledJobs.LaunchAdditionalDataProcessors.MethodName);
	
EndProcedure

// Register provided data handlers
//
// When receiving notifications of new common data availability
// the NewDataAvailable procedure of the modules registered using GetProvidedDataHandlers is called.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// If NewDataAvailable sets the Import argument to the True value, the data is imported, the handle and the file path with data are passed to the ProcessNewData procedure. File will be automatically deleted after procedure completed.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//       Columns:
//        DataKind, string - data kind code processed
//        by the HandlerCode handler, string(20) - will be used at dataprocessor recovery after
//        the Handler failure, CommonModule - the module that contains the following procedures:
//          AvailableNewData(Handle,
//          Import) Export ProcessNewData(Handle,
//          PathToFile) Export DataProcessingCanceled(Handle) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

// Fills the transferred array with common modules which
//  comprise the handlers of received messages interfaces
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure RegistrationOfReceivedMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesManagementAdditionalReportsAndDataProcessorsInterface);
	
EndProcedure

// Fills the transferred array with the common modules
//  being the sent message interface handlers
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure RegistrationSendingMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessageControlAdditionalReportsAndDataprocessorsInterface);
	
EndProcedure

// Called when determining the message interface version
//  supported by IB-correspondent as well as by current IB. IN this procedure it is expected to implement
//  support mechanisms of backward compatibility with old versions of IB-correspondents
//
// Parameters:
//  InterfaceMessages - String, name of the message application interface for
//  which ConnectionParameters version is determined - structure, connection parameters
//  to the ReceiverPresentation IB-correspondent - String, IB-correspondent
//  presentation Result - String, defined version. You can change the value of this parameter in this procedure.
//
Procedure OnDeterminingVersionOfCorrespondingInterface(Val InterfaceMessages, Val ConnectionParameters, Val RecipientPresentation, Result) Export
	
	// Compatibility with MS versions where
	// ApplicationExtensionsControl interface is a part of the RemoteAdministrationControl interface
	
	If Result = Undefined AND InterfaceMessages = MessageControlAdditionalReportsAndDataprocessorsInterface.ProgramInterface() Then
		
		VerifiableInterface = MessageRemoteAdministratorControlInterface.ProgramInterface();
		VersionControlInterfaceForRemoteAdministration = MessageInterfacesSaaS.InterfaceVersionCorrespondent(
			VerifiableInterface, ConnectionParameters, RecipientPresentation);
		
		If CommonUseClientServer.CompareVersions(VersionControlInterfaceForRemoteAdministration, "1.0.2.4") >= 0 Then
			Result = "1.0.0.1";
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceTechnology

#Region DataAreasExportImport

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.UseSuppliedAdditionalReportsAndDataProcessorsInDataAreas);
	Types.Add(Metadata.InformationRegisters.SuppliedAdditionalReportsAndDataProcessorsInDataAreaSetupQueue);
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region ScheduledJobsHandlers

// Procedure is called as a scheduled job after receiving a
//  new version of additional data processor from the additional reports directory and service manager processors.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors.
//
Procedure UpdateSettingsUsedByDataProcessors(Val Ref) Export
	
	SuppliedDataProcessor = SuppliedDataProcessor(Ref);
	
	If ValueIsFilled(SuppliedDataProcessor) Then
		
		UsingDataProcessor = Ref.GetObject();
		FillUsedDataProcessorSettings(UsingDataProcessor,
			SuppliedDataProcessor.GetObject());
		UsingDataProcessor.Write();
		
	Else
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Additional processing with the %1 ID is not supplied.';ru='Дополнительная обработка с идентификатором %1 не является поставляемой!'"),
			String(Ref.UUID()));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SuppliedData

// Registers handlers of supplied data for a day and for the whole period
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = ProvidedDataKindId();
	Handler.ProcessorCode = ProvidedDataKindId();
	Handler.Handler = AdditionalReportsAndDataProcessorsSaaS;
	
EndProcedure

// It is called when a notification of new data received.
// IN the body you should check whether this data is necessary for the application, and if so, - select the Import check box.
// 
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   Import    - Boolean, return
//
Procedure AvailableNewData(Val Handle, Import) Export
	
	If Handle.DataType = ProvidedDataKindId() Then
		
		ProvidedDataProcessorDescription = ParseDataSuppliedHandle(Handle);
		
		Read = New XMLReader();
		Read.SetString(ProvidedDataProcessorDescription.Compatibility);
		Read.MoveToContent();
		TableOfCompatibilityXDTO = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Read.NamespaceURI, Read.Name));
		TableOfCompatibility = AdditionalReportsAndDataProcessorsSaaSCompatibility.ReadCompatibilityTable(TableOfCompatibilityXDTO);
		
		If CheckCompatibilityOfSuppliedDataProcessors(TableOfCompatibility) Then // If data processor is compatible with IB
			
			Import = True;
			
		Else
			
			Import = False;
			
			WriteLogEvent(
				NStr("en='The supplied additional reports and processings. Import of the supplied processing is cancelled';ru='Поставляемые дополнительные отчеты и обработки.Загрузка поставляемой обработки отменена'", 
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				,
				NStr("en='Supplied processing is not compatible with this configuration';ru='Поставляемая обработка несовместима с данной конфигурацией'") + Chars.LF + Chars.CR + ProvidedDataProcessorDescription.Compatibility);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// It is called after the call AvailableNewData, allows you to parse data.
//
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   PathToFile   - String or Undefined. The full name of the extracted file. File will be automatically
// deleted after procedure completed. If the file was not
//                  specified in the service manager - The argument value is Undefined.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	If Handle.DataType = ProvidedDataKindId() Then
		ProcessSuppliedAdditionalReportsAndDataProcessors(Handle, PathToFile);
	EndIf;
	
EndProcedure

// It is called when cancelling data processing in case of a failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
	
EndProcedure

#EndRegion

#Region UpdateHandlers

// Locks service additional reports and data processors in
// the data areas to receive new versions from the service manager.
//
Procedure LockAdditionalReportsAndDataProcessorsForUpdate() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		SetPrivilegedMode(True);
		
		QueryText =
		"SELECT
		|	SuppliedAdditionalReportsAndDataProcessors.Ref AS Ref
		|FROM
		|	Catalog.SuppliedAdditionalReportsAndDataProcessors AS SuppliedAdditionalReportsAndDataProcessors
		|WHERE
		|	Not SuppliedAdditionalReportsAndDataProcessors.Ref In
		|				(SELECT DISTINCT
		|					SuppliedAdditionalReportsAndDataProcessorsCompatibility.Ref
		|				FROM
		|					Catalog.SuppliedAdditionalReportsAndDataProcessors.Compatibility AS SuppliedAdditionalReportsAndDataProcessorsCompatibility
		|				WHERE
		|					SuppliedAdditionalReportsAndDataProcessorsCompatibility.Version = &Version)
		|	AND SuppliedAdditionalReportsAndDataProcessors.ControlCompatibilityWithConfigurationVersions = TRUE";
		Query = New Query(QueryText);
		Query.SetParameter("Version", Metadata.Version);
		BlockedDataProcessors = Query.Execute().Unload().UnloadColumn("Ref");
		
		For Each BlockedDataProcessor IN BlockedDataProcessors Do
			
			SuppliedDataProcessor = BlockedDataProcessor.GetObject();
			SuppliedDataProcessor.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
			SuppliedDataProcessor.ShutdownCause = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.ConfigurationVersionUpdate;
			SuppliedDataProcessor.Write();
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Requests for updates of supplied additional reports
// and data processors from the service manager.
//
Procedure RequestAdditionalReportsAndDataProcessorsUpdate() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		BeginTransaction();
		SuppliedData.RequestAllData();
		CommitTransaction();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region SuppliedData

// Returns supplied data jind ID for the
// additional reports and data processors
//
// Return value: String.
Function ProvidedDataKindId()
	
	Return "DOandO"; // Not localized
	
EndFunction

Function ProvidedDataProcessorDescription()
	
	Return New Structure("Identifier, Version, Manifest, Compatibility");
	
EndFunction

Function ParseDataSuppliedHandle(Handle)
	
	ProvidedDataProcessorDescription = ProvidedDataProcessorDescription();
	
	For Each CharacteristicOfDeliveredData IN Handle.Properties.Property Do
		
		ProvidedDataProcessorDescription[CharacteristicOfDeliveredData.Code] = CharacteristicOfDeliveredData.Value;
		
	EndDo;
	
	Return ProvidedDataProcessorDescription;
	
EndFunction

// Control compatibility with the current infobase configuration version
Function CheckCompatibilityOfSuppliedDataProcessors(Val TableOfCompatibility)
	
	For Each DeclarationOfCompatibility IN TableOfCompatibility Do
		
		If IsBlankString(DeclarationOfCompatibility.VersionNumber) Then
			
			If DeclarationOfCompatibility.ConfigarationName = Metadata.Name Then
				Return True;
			EndIf;
			
		Else
			
			If DeclarationOfCompatibility.ConfigarationName = Metadata.Name AND DeclarationOfCompatibility.VersionNumber = Metadata.Version Then
				Return True;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure ProcessSuppliedAdditionalReportsAndDataProcessors(Handle, PathToFile)
	
	SetPrivilegedMode(True);
	
	// Read characteristics of the provided data instance
	ProvidedDataProcessorDescription = ParseDataSuppliedHandle(Handle);
	
	Read = New XMLReader();
	Read.SetString(ProvidedDataProcessorDescription.Manifest);
	Read.MoveToContent();
	AdditionalInformationProcessorManifest = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Read.NamespaceURI, Read.Name));
	
	Read = New XMLReader();
	Read.SetString(ProvidedDataProcessorDescription.Compatibility);
	Read.MoveToContent();
	TableOfCompatibilityXDTO = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Read.NamespaceURI, Read.Name));
	TableOfCompatibility = AdditionalReportsAndDataProcessorsSaaSCompatibility.ReadCompatibilityTable(TableOfCompatibilityXDTO);
	
	WriteLogEvent(NStr("en='Supplied additional reports and processings. Supplied processing import';ru='Поставляемые дополнительные отчеты и обработки.Загрузка поставляемой обработки'", 
		CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Information,
		,
		,
		NStr("en='Supplied processing import is initiated';ru='Инициирована загрузка поставляемой обработки'") + Chars.LF + Chars.CR + ProvidedDataProcessorDescription.Manifest);
	
	// Receive CatalogObject.SuppliedAdditionalReportsAndDataProcessors
	RefsSuppliedDataProcessors = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		New UUID(ProvidedDataProcessorDescription.ID));
	If CommonUse.RefExists(RefsSuppliedDataProcessors) Then
		SuppliedDataProcessor = RefsSuppliedDataProcessors.GetObject();
	Else
		SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.CreateItem();
		SuppliedDataProcessor.SetNewObjectRef(RefsSuppliedDataProcessors);
	EndIf;
	
	If ValueIsFilled(SuppliedDataProcessor.ShutdownCause) Then
		If SuppliedDataProcessor.ShutdownCause = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.ConfigurationVersionUpdate Then
			SuppliedDataProcessor.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
			SuppliedDataProcessor.ShutdownCause = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.EmptyRef();
		EndIf;
	Else
		SuppliedDataProcessor.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
	EndIf;
	
	If SuppliedDataProcessor.GUIDVersion <> ProvidedDataProcessorDescription.Version Then
		
		// Fill in CatalogObject.SuppliedAdditionalReportsAndDataProcessors
		ReportsVariantsOfDeliveredDataProcessors = Undefined;
		AdditionalReportsAndDataProcessorsSaaSManifest.ReadManifest(
			AdditionalInformationProcessorManifest, SuppliedDataProcessor, SuppliedDataProcessor,
			ReportsVariantsOfDeliveredDataProcessors);
		
		// Writes supplied data file as the DataProcessorStorage attribute value
		DataProcessorBinaryData = New BinaryData(PathToFile);
		SuppliedDataProcessor.DataProcessorStorage = New ValueStorage(
			DataProcessorBinaryData, New Deflation(9));
		
		// Table of compatibility with configuration versions
		SuppliedDataProcessor.ControlCompatibilityWithConfigurationVersions = True;
		SuppliedDataProcessor.Compatibility.Clear();
		For Each InformationAboutCompatibility IN TableOfCompatibility Do
			
			If InformationAboutCompatibility.ConfigarationName = Metadata.Name Then
				
				If IsBlankString(InformationAboutCompatibility.VersionNumber) Then
					
					SuppliedDataProcessor.ControlCompatibilityWithConfigurationVersions = False;
					Break;
					
				Else
					
					TSRow = SuppliedDataProcessor.Compatibility.Add();
					TSRow.Version = InformationAboutCompatibility.VersionNumber;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		// Write CatalogObject.SuppliedAdditionalReportsAndDataProcessors
		SuppliedDataProcessor.GUIDVersion = ProvidedDataProcessorDescription.Version;
		SuppliedDataProcessor.Write();
		
		WriteLogEvent(NStr("en='Supplied additional reports and processings. Import of the supplied processing is completed';ru='Поставляемые дополнительные отчеты и обработки.Загрузка поставляемой обработки завершена'",
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			SuppliedDataProcessor.Ref,
			NStr("en='Supplied processing import is completed';ru='Завершена загрузка поставляемой обработки'") + Chars.LF + Chars.CR + ProvidedDataProcessorDescription.Manifest);
		
		// Plan actualization of the used data processor settings
		UsedDataProcessors = ListOfInstallations(SuppliedDataProcessor.Ref);
		For Each InstallationOfDataProcessors IN UsedDataProcessors Do
			
			MethodParameters = New Array;
			MethodParameters.Add(InstallationOfDataProcessors.UsingDataProcessor);
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName"    , "AdditionalReportsAndDataProcessorsSaaS.UsedDataProcessorSettingsActualization");
			JobParameters.Insert("Parameters"    , MethodParameters);
			JobParameters.Insert("RestartCountOnFailure", 3);
			JobParameters.Insert("DataArea", InstallationOfDataProcessors.DataArea);
			
			JobQueue.AddJob(JobParameters);
			
			WriteLogEvent(NStr("en='Supplied additional reports and processings. There is scheduled an actualization of the supplied processing settings';ru='Поставляемые дополнительные отчеты и обработки.Запланирована актуализация настроек поставляемой обработки'",
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				SuppliedDataProcessor.Ref,
				NStr("en='Data area';ru='Область данных:'") + InstallationOfDataProcessors.DataArea);
			
		EndDo;
		
		// Plan installation of the supplied data processor to areas that are waiting for it
		InstallationsQueue = InstallationsQueue(SuppliedDataProcessor.Ref);
		For Each ItemInQueue IN InstallationsQueue Do
			
			Context = ItemInQueue.InstallationParameters.Get();
			
			InstallationDetails = New Structure(
				"ID,Presentation,Installation",
				SuppliedDataProcessor.Ref.UUID(),
				Context.Presentation,
				Context.Installation);
			
			MethodParameters = New Array;
			MethodParameters.Add(InstallationDetails);
			MethodParameters.Add(Context.QuickAccess);
			MethodParameters.Add(Context.Tasks);
			MethodParameters.Add(Context.Sections);
			MethodParameters.Add(Context.CatalogsAndDocuments);
			MethodParameters.Add(Context.SettingsLocationOfCommands);
			MethodParameters.Add(Context.AdditionalReportVariants);
			MethodParameters.Add(Context.Responsible);
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName"    , "AdditionalReportsAndDataProcessorsSaaS.SetSuppliedDataProcessorOnReceive");
			JobParameters.Insert("Parameters"    , MethodParameters);
			JobParameters.Insert("RestartCountOnFailure", 1);
			JobParameters.Insert("DataArea", ItemInQueue.DataArea);
			
			JobQueue.AddJob(JobParameters);
			
			WriteLogEvent(
				NStr("en='Supplied additional reports and processings. A delayed installation of the supplied processing to the data area is scheduled';ru='Поставляемые дополнительные отчеты и обработки.Запланирована отложенная установка поставляемой обработки в область данных'",
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Information,
				,
				SuppliedDataProcessor.Ref,
				NStr("en='Data area';ru='Область данных:'") + ItemInQueue.DataArea);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region AdditionalReportsAndDataProcessors

// Returns True if passed ref to the
// AdditionalReportsAndDataProcessors catalog item is a report, not a data processor.
//
Function IsReport(Val Ref)
	
	Kind = CommonUse.ObjectAttributeValue(Ref, "Kind");
	Return (Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report) Or (Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	
EndFunction

// Procedure refills AdditionalReportsAndDataProcessors
//  catalog item by the SuppliedAdditionalReportsAndDataProcessors catalog item.
//
Procedure FillUsedDataProcessorSettings(UsingDataProcessor, SuppliedDataProcessor)
	
	FillPropertyValues(UsingDataProcessor, SuppliedDataProcessor, , "DataProcessorStorage,Owner,Parent");
	
	UsedDataProcessorCommands = UsingDataProcessor.Commands.Unload();
	ProvidedDataProcessorCommands = SuppliedDataProcessor.Commands.Unload();
	
	// Synchronize commands of the used data processor by commands of the supplied data processor
	For Each ProvidedDataProcessorCommand IN ProvidedDataProcessorCommands Do
		
		UsedDataProcessorCommand = UsedDataProcessorCommands.Find(
			ProvidedDataProcessorCommand.ID, "ID");
		
		If UsedDataProcessorCommand = Undefined Then
			UsedDataProcessorCommand = UsedDataProcessorCommands.Add();
		EndIf;
		
		FillPropertyValues(UsedDataProcessorCommand, ProvidedDataProcessorCommand,
			"ID,StartVariant,Presentation,ShowAlert,Modifier,Hide");
		
	EndDo;
	
	// Delete used data processor commands that were deleted from
	// the new version of the supplied data processor
	DeletedCommands = New Array();
	For Each UsedDataProcessorCommand IN UsedDataProcessorCommands Do
		
		ProvidedDataProcessorCommand = UsedDataProcessorCommands.Find(
			UsedDataProcessorCommand.ID, "ID");
		
		If ProvidedDataProcessorCommand = Undefined Then
			DeletedCommands.Add(UsedDataProcessorCommand);
		EndIf;
		
	EndDo;
	
	For Each DeletedCommand IN DeletedCommands Do
		UsedDataProcessorCommands.Delete(DeletedCommand);
	EndDo;
	
	UsingDataProcessor.Commands.Load(UsedDataProcessorCommands);
	
	UsingDataProcessor.permissions.Load(SuppliedDataProcessor.permissions.Unload());
	
EndProcedure

// Receives registration data for the registered data processor by the supplied data processor
//
// Parameters:
//  SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors
//
// Returns - structure similar to the structure
//  returned by the InformationAboutExternalDataProcessor() export function of external data processors.
//
Function GetRegistrationData(Val SuppliedDataProcessor)
	
	Result = New Structure("Kind, Name, Version, SafeMode, Information, SSLVersion, OptionsStorage");
	
	SetPrivilegedMode(True);
	DataProcessor = SuppliedDataProcessor.GetObject();
	FillPropertyValues(Result, DataProcessor);
	
	// Purpose
	Purpose = New Array();
	For Each ElementDestination IN DataProcessor.Purpose Do
		Purpose.Insert(ElementDestination.ObjectDestination);
	EndDo;
	Result.Insert("Purpose", Purpose);
	
	// Commands
	Result.Insert("Commands", DataProcessor.Commands.Unload(
		, "Presentation, Identifier, Modifier, ShowAlert, Usage"));
	
	Return Result;
	
EndFunction

#EndRegion

#Region AdditionalReportsAndDataProcessorsSaaSParticularity

// Procedure is designed to synchronize constants
//  values that regulate the use of additional reports and processors in the service model. Procedure
//  must be called on any change of any
//  constant regulating the use of additional reports and processors.
//
// Parameters:
//  Constant - String changed constant name as it is
//  specified in the metadata, Value - Boolean, new value of the changed constant
//
Procedure SynchronisationValuesForConstants(Val Constant, Val Value) Export
	
	StateUse = False;
	
	ControlConstants = AdditionalReportsAndDataProcessorsSaaSReUse.ControlConstants();
	
	For Each ControlConstant IN ControlConstants Do
		
		If ControlConstant = Constant Then
			ConstantValue = Value;
		Else
			ConstantValue = Constants[ControlConstant].Get();
		EndIf;
		
		If ConstantValue Then
			StateUse = True;
		EndIf;
		
	EndDo;
	
	Constants.UseAdditionalReportsAndDataProcessors.Set(StateUse);
	
EndProcedure

// Called while checking whether it is possible to execute additional report or data processor.
//
Procedure CheckOptionExecution(Ref)
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If IsSuppliedDataProcessor(Ref) Then
			
			CheckSuppliedDataProcessorExecutionPossibility(Ref);
			
		Else
			
			If Not Constants.AdditionalReportsAndDataProcessorsIndependentUseSaaS.Get() Then
				
				Raise NStr("en='This additional report or processing can not be used in the service!';ru='Этот дополнительный отчет или обработка не может быть использован в сервисе!'");
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure is called to check whether it is
//  possible to execute additional processor code in the infobase.
//
Procedure CheckSuppliedDataProcessorExecutionPossibility(Val UsingDataProcessor)
	
	UsedDataProcessorPublicationParameters = CommonUse.ObjectAttributesValues(UsingDataProcessor, "Publication, Version");
	If UsedDataProcessorPublicationParameters.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled Then
		Raise NStr("en='It is prohibited to use additional data processor in your application. Contact user with administrative privileges in this application.';ru='Использование дополнительной обработки в вашем приложении запрещено! Обратитесь за помощью к пользователю, обладающего правами администратора в данном приложении.'");
	EndIf;
	
	BlockingReasonsDescription = AdditionalReportsAndDataProcessorsSaaSReUse.ExtendedDescriptionsReasonsLock();
	
	SetPrivilegedMode(True);
	SuppliedDataProcessor = SuppliedDataProcessor(UsingDataProcessor);
	If ValueIsFilled(SuppliedDataProcessor) Then
		
		ProvidedDataProcessorPublicationParameters = CommonUse.ObjectAttributesValues(SuppliedDataProcessor, "Publication, ShutdownCause, Version");
		
		// Check supplied data processor publication
		If ProvidedDataProcessorPublicationParameters.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled Then
			
			Raise BlockingReasonsDescription[ProvidedDataProcessorPublicationParameters.ShutdownCause];
			
		EndIf;
		
		// Check whether data processor version is updated
		If UsedDataProcessorPublicationParameters.Version <> ProvidedDataProcessorPublicationParameters.Version Then
			Raise NStr("en='Additional data processor use is temporarily unavailable as it is updated. This may take several minutes. We apologize for the inconvenience.';ru='Использование дополнительной обработки временно недоступно по причине выполнения ее обновления. Данный процесс может занять несколько минут. Приносим извинения на доставленные неудобства.'");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ConditionalCallsHandlers

Procedure WhenSerializingPermissionsOwnerForExternalResourcesUse(Val Owner, StandardProcessing, Result) Export
	
	If TypeOf(Owner) = Type("CatalogRef.AdditionalReportsAndDataProcessors") Then
		
		StandardProcessing = False;
		
		Result = XDTOFactory.Create(XDTOFactory.Type(WorkInSafeModeServiceSaaS.PermissionsAdministrationPackage(), "PermissionsOwnerExternalModule"));
		Result.Type = "ApplicationExtension";
		Result.UUID = Owner.UUID();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
