#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region LocalVariables

Var CurrentHandlers;

#EndRegion

#Region ServiceProgramInterface

Procedure BeforeCleaningData(Container) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeCleaningData", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeCleaningData(Container);
	EndDo;
	
EndProcedure

// see procedure OnAddServiceEvents of general module DataExportImportServiceEvents
//
Procedure BeforeDataImport(Container) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeDataImport", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeDataImport(Container);
	EndDo;
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\BeforeDataImport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.BeforeDataImport(Container);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.BeforeDataImport(Container);
	
EndProcedure

// Performs actions when importing an info base user.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//
Procedure AfterDataImport(Container) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterDataImport", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterDataImport(Container);
	EndDo;
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\AfterDataImport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.AfterDataImport(Container);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.AfterDataImport(Container);
	
	// For backward compatibility, call AfterDataImportFromAnotherModel()
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\AfterDataImportFromOtherMode");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.AfterDataImportFromOtherMode();
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.AfterDataImportFromOtherMode();
	
EndProcedure

Procedure BeforeMatchRefs(Container, MetadataObject, SourceRefsTable, StandardProcessing, NonstandardHandler, Cancel) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeMatchRefs", True);
	FilterHandlers.Insert("MetadataObject", MetadataObject);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		
		ProcessingDetails.Handler.BeforeMatchRefs(Container, MetadataObject, SourceRefsTable, StandardProcessing, Cancel);
		
		If Not StandardProcessing OR Cancel Then
			NonstandardHandler = ProcessingDetails.Handler;
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure

// Performed actions when replacing refs.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// ReferenceMap - see parameter ReplacementDictionary of procedure UpdateRefsMappingDictionary of general module InfobaseDataExportImport.
//
Procedure WhenReplacingReferences(Container, ReferenceMap) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("WhenReplacingReferences", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.WhenReplacingReferences(Container, ReferenceMap);
	EndDo;
	
EndProcedure

// Executes handlers before importing a specific data type.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// MetadataObject - MetadataObject - Metadata object.
// Cancel - Boolean - Shows that the operation is executed.
//
Procedure BeforeImportType(Container, MetadataObject, Cancel) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeImportType", True);
	FilterHandlers.Insert("MetadataObject", MetadataObject);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeImportType(Container, MetadataObject, Cancel);
	EndDo;
	
EndProcedure

//Called before
// exporting the object. see "OnRegisteringDataExportHandlers"
//
Procedure BeforeObjectImport(Container, Object, Artifacts, Cancel) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeObjectImport", True);
	FilterHandlers.Insert("MetadataObject", Object.Metadata());
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeObjectImport(Container, Object, Artifacts, Cancel);
	EndDo;
	
EndProcedure

// Performs handlers after importing the object.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Object - object of the data being loaded.
// Artifacts - Array - artifact array (XDTO objects).
//
Procedure AftertObjectImport(Container, Object, Artifacts) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AftertObjectImport", True);
	FilterHandlers.Insert("MetadataObject", Object.Metadata());
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AftertObjectImport(Container, Object, Artifacts);
	EndDo;
	
EndProcedure

// See description to the WhenAddServiceEvents() procedure of the DataExportImportServiceEvents general module
//
Procedure AfterImportType(Container, MetadataObject) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterImportType", True);
	FilterHandlers.Insert("MetadataObject", MetadataObject);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterImportType(Container, MetadataObject);
	EndDo;
	
EndProcedure

Procedure BeforeLoadSettingsStorage(Container, SettingsStorageName, SettingsStorage, Cancel) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeLoadSettingsStorage", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeLoadSettingsStorage(Container, SettingsStorageName, SettingsStorage, Cancel);
	EndDo;
	
EndProcedure

Procedure BeforeLoadSettings(Container, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation, Artifacts, Cancel) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeLoadSettings", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeLoadSettings(
			Container,
			SettingsStorageName,
			SettingsKey,
			ObjectKey,
			Settings,
			User,
			Presentation,
			Artifacts,
			Cancel);
	EndDo;
	
EndProcedure

Procedure AfterLoadSettings(Container, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation, Artifacts) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterLoadSettings", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterLoadSettings(
			Container,
			SettingsStorageName,
			SettingsKey,
			ObjectKey,
			Settings,
			User,
			Presentation,
			Artifacts);
	EndDo;
	
EndProcedure

Procedure AfterLoadSettingsStorage(Container, SettingsStorageName, SettingsStorage) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterLoadSettingsStorage", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterLoadSettingsStorage(Container, SettingsStorageName, SettingsStorage);
	EndDo;
	
EndProcedure

#EndRegion

#Region Initialization

CurrentHandlers = New ValueTable();

CurrentHandlers.Columns.Add("MetadataObject");
CurrentHandlers.Columns.Add("Handler");
CurrentHandlers.Columns.Add("Version", New TypeDescription("String"));

CurrentHandlers.Columns.Add("BeforeCleaningData", New TypeDescription("Boolean"));

CurrentHandlers.Columns.Add("BeforeDataImport", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterDataImport", New TypeDescription("Boolean"));

CurrentHandlers.Columns.Add("BeforeMatchRefs", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("WhenReplacingReferences", New TypeDescription("Boolean"));

CurrentHandlers.Columns.Add("BeforeImportType", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("BeforeObjectImport", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AftertObjectImport", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterImportType", New TypeDescription("Boolean"));

CurrentHandlers.Columns.Add("BeforeLoadSettingsStorage", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("BeforeLoadSettings", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterLoadSettings", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterLoadSettingsStorage", New TypeDescription("Boolean"));


// Integrated handlers
ValueStorageDataExportImport.WhenDataExportHandlersRegistration(CurrentHandlers);
DataExportImportSequencesLimits.WhenDataExportHandlersRegistration(CurrentHandlers);
PredefinedDataExportImport.WhenDataExportHandlersRegistration(CurrentHandlers);
UndividedPredefinedDataExportImport.WhenDataExportHandlersRegistration(CurrentHandlers);
JointlySeparatedDataExportImport.WhenDataExportHandlersRegistration(CurrentHandlers);
DataExportImportTotalsControl.WhenDataExportHandlersRegistration(CurrentHandlers);
ExportImportUserWorkFavorites.WhenDataExportHandlersRegistration(CurrentHandlers);
ExportImportStandardInterfaceStructureOData.WhenDataExportHandlersRegistration(CurrentHandlers);
ExportImportExchangePlanNodes.WhenDataExportHandlersRegistration(CurrentHandlers);

// Events handlers SSL
ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
	"ServiceTechnology.DataExportImport\WhenDataExportHandlersRegistration");
For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
	ProgrammingEventsHandlerSSL.Module.WhenDataExportHandlersRegistration(CurrentHandlers);
EndDo;

// Redefined procedure
DataExportImportOverridable.WhenDataExportHandlersRegistration(CurrentHandlers);

// Ensure backward compatibility
For Each String IN CurrentHandlers Do
	If IsBlankString(String.Version) Then
		String.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_0();
	EndIf;
EndDo;

#EndRegion

#EndIf