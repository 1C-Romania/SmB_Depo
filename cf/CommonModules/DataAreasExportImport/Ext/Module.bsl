////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Exports application data to the zip-archive from which they can be imported later into another infobase or data area with the help of the DataAreasExportImport.ImportCurrentDataAreaFromArchive() function
//
// Returns - String, a path to the export file.
//
Function ExportCurrentDataAreaToArchive() Export
	
	ExportedTypes = New Array();
	CommonUseClientServer.SupplementArray(ExportedTypes, GetDataAreasModelTypes());
	CommonUseClientServer.SupplementArray(ExportedTypes,
		DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport(), True);
	
	ExportParameters = New Structure();
	ExportParameters.Insert("ExportedTypes", ExportedTypes);
	ExportParameters.Insert("ExportUsers", True);
	ExportParameters.Insert("ExportUserSettings", True);
	
	Return DataExportImport.ExportDataIntoArchive(ExportParameters);
	
	
EndFunction

// Exports application data to the zip-archive, which is placed to the temporary storage.
//  Later the data from the archive can be imported into another infobase or data area with the help of the DataAreasExportImport.ImportCurrentDataAreaFromArchive() funtion
//
// Parameters:
//  StorageAddress - String, the address in the temporary storage in which it is required to place the zip-archive with the data.
//
Procedure ExportCurrentDataAreaIntoTemporaryStorage(StorageAddress) Export
	
	FileName = ExportCurrentDataAreaToArchive();
	
	Try
		
		ExportData = New BinaryData(FileName);
		PutToTempStorage(ExportData, StorageAddress);
		
		DataExportImportService.DeleteTemporaryFile(FileName);
		
	Except
		
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		DataExportImportService.DeleteTemporaryFile(FileName);
		
		Raise ErrorMessage;
		
	EndTry;
	
EndProcedure

// Imports application data from zip-archive with XML files.
//
// Parameters:
//  ArchiveName - String - Full attachment file name of the
//  archive with the data, ExportParameters - Structure containing parameters of data import.
//    Keys:
//      ImportedTypes - Array(MetadataObject) - the array of metadata objects, the data of which are required to be imported from the archive. If the parameter value is set - all
//        other data contained in the import file will not be imported. If the
//        parameter value is not set - all the data contained in the export file will be imported.
//      ImportUsers - Boolean - import the information on the infobase users, LoadUserSettings - Boolean, it is ignored if ImportUsers = False.
//    The structure can also contain additional keys that can be processed inside the random data import handlers.
//
Procedure ImportCurrentDataAreaFromArchive(Val ArchiveName, Val ImportUsers = False, Val MinimizeUsersCatalogItems = False) Export
	
	ImportedTypes = New Array();
	CommonUseClientServer.SupplementArray(ImportedTypes, GetDataAreasModelTypes());
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		CommonUseClientServer.SupplementArray(ImportedTypes,
			DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport(), True);
	EndIf;
	
	ExportParameters = New Structure();
	ExportParameters.Insert("ImportedTypes", ImportedTypes);
	
	If ServiceTechnologyIntegrationWithSSL.DataSeparationEnabled() Then
		
		ExportParameters.Insert("ImportUsers", False);
		ExportParameters.Insert("LoadUserSettings", False);
		
	Else
		
		ExportParameters.Insert("ImportUsers", ImportUsers);
		ExportParameters.Insert("LoadUserSettings", ImportUsers);
		
	EndIf;
	
	ExportParameters.Insert("MinimizeSeparatedUsers", MinimizeUsersCatalogItems);
	
	DataExportImport.ImportDataFromArchive(ArchiveName, ExportParameters);
	
EndProcedure

// Checks the compatibility of exporting from the file with the current infobase configuration.
//
// Parameters:
//  ArchiveName - String, a path to the export file.
//
// Return value: Boolean, True - if the data from the archive
//  can be imported into the current configuration.
//
Function ExportArchiveIsCompatibleWithCurrentConfiguration(Val ArchiveName) Export
	
	Return DataExportImport.ExportArchiveIsCompatibleWithCurrentConfiguration(ArchiveName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function GetDataAreasModelTypes()
	
	Result = New Array();
	
	DataModel = ServiceTechnologyIntegrationWithSSL.GetDataAreaModel();
	
	For Each DataModelItem IN DataModel Do
		
		MetadataObject = Metadata.FindByFullName(DataModelItem.Key);
		
		If Not CommonUseSTL.ThisIsScheduledJob(MetadataObject)
				AND Not CommonUseSTL.IsDocumentJournal(MetadataObject)
				AND Not CommonUseSTL.ThisIsExternalDataSource(MetadataObject) Then
			
			Result.Add(MetadataObject);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction
