#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region LocalVariables

Var CurrentHandlers;

#EndRegion

#Region ServiceProgramInterface

Procedure BeforeDataExport(Container) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeDataExport", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeDataExport(Container);
	EndDo;
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\BeforeDataExport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.BeforeDataExport(Container);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.BeforeDataExport(Container);
	
EndProcedure

// It is called after data export.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//
Procedure AfterDataExport(Container) Export
	
	// RegisteredHandlers
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterDataExport", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterDataExport(Container);
	EndDo;
	
	// Events handlers SSL
	ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.DataExportImport\AfterDataExport");
	For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
		ProgrammingEventsHandlerSSL.Module.AfterDataExport(Container);
	EndDo;
	
	// Redefined procedure
	DataExportImportOverridable.AfterDataExport(Container);
	
EndProcedure

// See description to the WhenAddServiceEvents() procedure of the DataExportImportServiceEvents general module
//
Procedure BeforeExportType(Container, Serializer, MetadataObject, Cancel) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeExportType", True);
	FilterHandlers.Insert("MetadataObject", MetadataObject);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeExportType(Container, Serializer, MetadataObject, Cancel);
	EndDo;
	
EndProcedure

//Called before
// exporting the object. see "OnRegisteringDataExportHandlers"
//
Procedure BeforeObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeObjectExport", True);
	FilterHandlers.Insert("MetadataObject", Object.Metadata());
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	
	For Each ProcessingDetails IN HandlersDescription Do
		
		If ProcessingDetails.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_0() Then
			
			ProcessingDetails.Handler.BeforeObjectExport(Container, Serializer, Object, Artifacts, Cancel);
			
		Else
			
			ProcessingDetails.Handler.BeforeObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel);
			
		EndIf;
		
	EndDo;
	
EndProcedure

//It is called before
// exporting data object see "WhenDataExportHandlerRegistration"
//
Procedure AfterObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterObjectExport", True);
	FilterHandlers.Insert("MetadataObject", Object.Metadata());
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	
	For Each ProcessingDetails IN HandlersDescription Do
		
		If ProcessingDetails.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_0() Then
			
			ProcessingDetails.Handler.AfterObjectExport(Container, Serializer, Object, Artifacts);
			
		Else
			
			ProcessingDetails.Handler.AfterObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Executes handlers after exporting a particular data type.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Serializer - XDTOSerializer - serializer.
// MetadataObject - MetadataObject - Metadata object.
//
Procedure AfterExportType(Container, Serializer, MetadataObject) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterExportType", True);
	FilterHandlers.Insert("MetadataObject", MetadataObject);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterExportType(Container, Serializer, MetadataObject);
	EndDo;
	
EndProcedure

Procedure BeforeExportSettingsStorage(Container, Serializer, SettingsStorageName, SettingsStorage, Cancel) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeExportSettingsStorage", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeExportSettingsStorage(Container, Serializer, SettingsStorageName, SettingsStorage, Cancel);
	EndDo;
	
EndProcedure

Procedure BeforeExportSettings(Container, Serializer, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation, Artifacts, Cancel) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("BeforeExportSettings", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.BeforeExportSettings(
			Container,
			Serializer,
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

Procedure AfterExportSettings(Container, Serializer, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterExportSettings", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterExportSettings(
			Container,
			Serializer,
			SettingsStorageName,
			SettingsKey,
			ObjectKey,
			Settings,
			User,
			Presentation);
	EndDo;
	
EndProcedure

Procedure AfterExportSettingsStorage(Container, Serializer, SettingsStorageName, SettingsStorage) Export
	
	FilterHandlers = New Structure();
	FilterHandlers.Insert("AfterExportSettingsStorage", True);
	HandlersDescription = CurrentHandlers.FindRows(FilterHandlers);
	For Each ProcessingDetails IN HandlersDescription Do
		ProcessingDetails.Handler.AfterExportSettingsStorage(Container, Serializer, SettingsStorageName, SettingsStorage);
	EndDo;
	
EndProcedure

#EndRegion

#Region Initialization

CurrentHandlers = New ValueTable();

CurrentHandlers.Columns.Add("MetadataObject");
CurrentHandlers.Columns.Add("Handler");
CurrentHandlers.Columns.Add("Version", New TypeDescription("String"));

CurrentHandlers.Columns.Add("BeforeDataExport", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterDataExport", New TypeDescription("Boolean"));

CurrentHandlers.Columns.Add("BeforeExportType", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("BeforeObjectExport", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterObjectExport", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterExportType", New TypeDescription("Boolean"));

CurrentHandlers.Columns.Add("BeforeExportSettingsStorage", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("BeforeExportSettings", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterExportSettings", New TypeDescription("Boolean"));
CurrentHandlers.Columns.Add("AfterExportSettingsStorage", New TypeDescription("Boolean"));

// Integrated handlers
DataExportImportSequencesLimits.WhenDataImportHandlersRegistration(CurrentHandlers);
UndividedDataExportImport.WhenDataImportHandlersRegistration(CurrentHandlers);
PredefinedDataExportImport.WhenDataImportHandlersRegistration(CurrentHandlers);
UndividedPredefinedDataExportImport.WhenDataImportHandlersRegistration(CurrentHandlers);
JointlySeparatedDataExportImport.WhenDataImportHandlersRegistration(CurrentHandlers);
ExportImportUserWorkFavorites.WhenDataImportHandlersRegistration(CurrentHandlers);
ValueStorageDataExportImport.WhenDataImportHandlersRegistration(CurrentHandlers);
ExportImportStandardInterfaceStructureOData.WhenDataImportHandlersRegistration(CurrentHandlers);
ExportImportExchangePlanNodes.WhenDataImportHandlersRegistration(CurrentHandlers);

// Events handlers SSL
ProgrammingEventsHandlersSSL = CommonUseSTL.GetProgrammaticSSLEventHandlers(
	"ServiceTechnology.DataExportImport\WhenDataImportHandlersRegistration");
For Each ProgrammingEventsHandlerSSL IN ProgrammingEventsHandlersSSL Do
	ProgrammingEventsHandlerSSL.Module.WhenDataImportHandlersRegistration(CurrentHandlers);
EndDo;

// Redefined procedure
DataExportImportOverridable.WhenDataImportHandlersRegistration(CurrentHandlers);

// Ensure backward compatibility
For Each String IN CurrentHandlers Do
	If IsBlankString(String.Version) Then
		String.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_0();
	EndIf;
EndDo;

#EndRegion

#EndIf

