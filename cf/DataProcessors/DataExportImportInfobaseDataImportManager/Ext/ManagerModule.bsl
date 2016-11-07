#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Imports the info base data.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//
Procedure ImportInfobaseData(Container, Handlers) Export
	
	ImportedTypes = Container.ExportParameters().ImportedTypes;
	ExcludedTypes = DataExportImportServiceEvents.GetTypesExcludedFromExportImport();
	
	ImportManager = DataProcessors.DataExportImportInfobaseDataImportManager.Create();
	ImportManager.Initialize(Container, ImportedTypes, ExcludedTypes, Handlers);
	ImportManager.ImportData();
	
EndProcedure

#EndRegion

#EndIf
