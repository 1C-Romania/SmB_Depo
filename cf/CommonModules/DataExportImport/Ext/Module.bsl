////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

// This module includes interface procedures
// of data export and import processes call function.


////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Exports data into zip archive from which it can
//  be imported later into another infobase or data area using
//  the DataExportImport.ImportDataFromArchive() function
//
// Parameters:
//  ExportParameters - The structure that contains the parameters of data export.
//    Keys:
//      ExportedTypes - Array(MetadataObject) - array of the
//       metadata objects which data must
//      be exported to the archive, ExportUsers - Boolean - export the information about the
//      users of the infobase, ExportUserSettings - Boolean is ignored if ExportUsers = False.
//    Also structure can contain additional keys that can be
//      processed inside the arbitrary handlers of data export.
//
// Returns - String, a path to the export file.
//
Function ExportDataIntoArchive(Val ExportParameters) Export
	
	If Not ValidateRights() Then
		Raise NStr("en='You have not enough access rights to export data!';ru='Недостаточно прав доступа для выгрузки данных!'");
	EndIf;
	
	ExternalExclusiveMode = ExclusiveMode();
	
	SetPrivilegedMode(True);
	
	If Not ExportParameters.Property("ExportedTypes") Then
		ExportParameters.Insert("ExportedTypes", New Array());
	EndIf;
	
	If Not ExportParameters.Property("ExportUsers") Then
		ExportParameters.Insert("ExportUsers", False);
	EndIf;
	
	If Not ExportParameters.Property("ExportUserSettings") Then
		ExportParameters.Insert("ExportUserSettings", False);
	EndIf;
	
	Directory = GetTempFileName();
	CreateDirectory(Directory);
	Directory = Directory + "\";
	
	archive = Undefined;
	
	Try
		
		If Not ExternalExclusiveMode Then
			SetExclusiveMode(True);
		EndIf;
		
		DataExportImportService.DataExportToDirectory(Directory, ExportParameters);
		
		If Not ExternalExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		
		archive = GetTempFileName("zip");
		Archiver = New ZipFileWriter(archive, , , ZIPCompressionMethod.Deflate, ZIPCompressionLevel.Optimal);
		Archiver.Add(Directory + "*", ZIPStorePathMode.StoreRelativePath, ZIPSubDirProcessingMode.ProcessRecursively);
		Archiver.Write();
		
		DataExportImportService.DeleteTemporaryFile(Directory);
		
		Return archive;
		
	Except
		
		DataExportImportService.DeleteTemporaryFile(Directory);
		If archive <> Undefined Then
			DataExportImportService.DeleteTemporaryFile(archive);
		EndIf;
		
		Raise;
		
	EndTry;
	
EndFunction

// Imports data from a zip archive with XML files.
//
// Parameters:
//  ArchiveName - String - Full attachment file name of the
//  archive with the data, ExportParameters - Structure containing parameters of data import.
//    Keys:
//      ImportedTypes - Array(MetadataObject) - the array of metadata objects, the data of which is required to be imported from the archive. If the parameter value is set - all
//        other data contained in the import file will not be imported. If the
//        parameter value is not set - all the data contained in the export file will be imported.
//      ImportUsers - Boolean - Import the information about the
//      users of the info base, LoadUserSettings - Boolean is ignored if ImportUsers = False.
//    The structure can also contain additional keys that can be processed inside the random data import handlers.
//
Procedure ImportDataFromArchive(Val ArchiveName, Val ExportParameters) Export
	
	If Not ValidateRights() Then
		Raise NStr("en='You have not enough access rights to import data!';ru='Недостаточно прав доступа для загрузки данных!'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	ExternalExclusiveMode = ExclusiveMode();
	
	Directory = GetTempFileName();
	CreateDirectory(Directory);
	Directory = Directory + "\";
	
	Archiver = New ZipFileReader(ArchiveName);
	
	Try
		
		If Not ExternalExclusiveMode Then
			SetExclusiveMode(True);
		EndIf;
		
		Archiver.ExtractAll(Directory, ZIPRestoreFilePathsMode.Restore);
		DataExportImportService.ImportDataFromDirectory(Directory, ExportParameters);
		
		If Not ExternalExclusiveMode Then
			SetExclusiveMode(False);
		EndIf;
		
		DataExportImportService.DeleteTemporaryFile(Directory);
		Archiver.Close();
		
	Except
		
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		DataExportImportService.DeleteTemporaryFile(Directory);
		Archiver.Close();
		
		Raise ErrorMessage;
		
	EndTry;
	
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
	
	Directory = GetTempFileName();
	CreateDirectory(Directory);
	Directory = Directory + "\";
	
	Archiver = New ZipFileReader(ArchiveName);
	
	Try
		
		ImportDescriptionItem = Archiver.Items.Find("DumpInfo.xml");
		
		If ImportDescriptionItem = Undefined Then
			Raise NStr("en='The DumpInfo.xml file is not available in the export file!';ru='В файле выгрузки отсутствует файл DumpInfo.xml!'");
		EndIf;
		
		Archiver.Extract(ImportDescriptionItem, Directory, ZIPRestoreFilePathsMode.Restore);
		
		ImportDescriptionFile = Directory + "DumpInfo.xml";
		
		ExportInfo = DataExportImportService.ReadXDTOObjectFromFile(
			ImportDescriptionFile, XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "DumpInfo")
		);
		
		Result = DataExportImportService.ExportArchiveIsCompatibleWithCurrentConfiguration(ExportInfo)
			AND DataExportImportService.ExportInArchiveIsCompatibleWithCurrentConfigurationVersion(ExportInfo);
		
		DataExportImportService.DeleteTemporaryFile(Directory);
		Archiver.Close();
		
		Return Result;
		
	Except
		
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		DataExportImportService.DeleteTemporaryFile(Directory);
		Archiver.Close();
		
		Raise ErrorMessage;
		
	EndTry;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Checks the availability of "DataAdministration" right
//
// Returns:
// Boolean - True if exists, False - else.
//
Function ValidateRights()
	
	Return AccessRight("DataAdministration", Metadata);
	
EndFunction
