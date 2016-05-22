#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Imports infobase user settings.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//
Procedure ImportInfobaseUserSettings(Container, Handlers) Export
	
	StorageTypes = DataExportImportService.StandardSettingsStorageTypes();
	
	For Each StorageType IN StorageTypes Do
		
		ImportManager = Create();
		ImportManager.Initialize(Container, StorageType, Handlers);
		ImportManager.ImportData();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
