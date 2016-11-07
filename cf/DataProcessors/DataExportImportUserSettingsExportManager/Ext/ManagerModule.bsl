#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

Procedure ExportInfobaseUserSettings(Container, Handlers, Serializer) Export
	
	StorageTypes = DataExportImportService.StandardSettingsStorageTypes();
	
	For Each StorageType IN StorageTypes Do
		
		ExportManager = Create();
		ExportManager.Initialize(Container, StorageType, Handlers, Serializer);
		ExportManager.ExportData();
		ExportManager.Close();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
