////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors", safe mode extension.
// 
////////////////////////////////////////////////////////////////////////////////

#Region OutdatedProgramInterface

// Creates a TextDocument object and initializes his file data placed
// in the temporary storage to the address passed as parameter values BinaryDataAddress.
//
// Parameters:
//  BinaryDataAddress - String, address in the temporary storage
//    to which was placed
//  the binary file data, FileType - TextEncoding or string - text encoding in
//    an open file, see the description
//  of TextDocument.Read() method in syntax helper, LineSeparator - String, the string that
//    is a line separator, see method description TextDocument.Read() in a syntax helper.
//
// Return value: TextDocument.
//
Function DocumentTextFromBinaryData(Val BinaryDataAddress, Val FileType = Undefined, Val LineSeparator = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = AdditionalReportsAndDataProcessorsInSafeModeService.GetFileFromTemporaryStore(BinaryDataAddress);
	TextDocument = New TextDocument();
	TextDocument.Read(TempFile, FileType, LineSeparator);
	DeleteFiles(TempFile);
	
	Return TextDocument;
	
EndFunction

// Writes a text document to a temporary file, places binary data
// in a temporary storage and returns binary file data address to a temporary storage.
//
// Parameters:
//  TextDocument - TextDocument that
//  is required to be saved, FileType - TextEncoding or string - text encoding in
//    an open file, see the description
//  of TextDocument.Write() method in syntax helper, LineSeparator - String, the string that
//    is a line separator, see TextDocument.Write()
//  method description in syntax helper, Address - String or UUID, address in temporary storage to which data
//    or unique form identifier must be put, in temporary storage of which
//    must be put the data and return the new address, see global context method description, PutToTempStorage.
//    IN syntax helper.
//
// Returns - String, address in the temporary storage.
//
Function TextDocumentInBinaryData(Val TextDocument, Val FileType = Undefined, Val LineSeparator = Undefined, Val Address = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = GetTempFileName();
	TextDocument.Write(TempFile, FileType, LineSeparator);
	Address = PutToTempStorage(New BinaryData(TempFile), Address);
	DeleteFiles(TempFile);
	
	Return Address;
	
EndFunction

// Creates a TableDocument object and initializes with its file data
// placed in temporary storage at the address passed as a parameter value BinaryDataAddress.
//
// Parameters:
//  BinaryDataAddress - String, address in the temporary storage
//    to which the file binary data was placed.
//
// Return value: SpreadSheet.
//
Function SpreadsheetDocumentFormBinaryData(Val BinaryDataAddress) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = AdditionalReportsAndDataProcessorsInSafeModeService.GetFileFromTemporaryStore(BinaryDataAddress);
	SpreadsheetDocument = New SpreadsheetDocument();
	SpreadsheetDocument.Read(TempFile);
	DeleteFiles(TempFile);
	
	Return SpreadsheetDocument;
	
EndFunction

// Writes a table document in a temporary file, puts the binary
// data to a temporary storage and returns address of the binary file data in a temporary storage.
//
// Parameters:
//  SpreadsheetDocument - TableDocument that
//  is required to be saved, FileType - SpreadsheetDocumentFileType - a format in which the table
//    document will be saved, see TableDocument.Write()
//  method description in syntax helper, Address - String or UUID, address in temporary storage to which data
//    or unique form identifier must be put, in temporary storage of which
//    must be put the data and return the new address, see global context method description, PutToTempStorage.
//    IN syntax helper.
//
// Returns - String, address in the temporary storage.
//
Function SpreadsheetDocumentInBinaryData(Val SpreadsheetDocument, Val FileType = Undefined, Val Address = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = GetTempFileName();
	SpreadsheetDocument.Write(TempFile, FileType);
	Address = PutToTempStorage(New BinaryData(TempFile), Address);
	DeleteFiles(TempFile);
	
	Return Address;
	
EndFunction

// Writes a formatted document to a temporary file, puts the binary
// data to a temporary storage, and returns  binary data address file to the temporary storage.
//
// Parameters:
//  FormattedDocument - FormattedDocument
//  that is required to be saved, FileType - FormattedDocumentFileType - format in which a formatted
//    document will be saved, see FormattedDocument.Write()
//  method description in syntax helper, Address - String or UUID, address in temporary storage to which data
//    or unique form identifier must be put, in temporary storage of which
//    must be put the data and return the new address, see global context method description, PutToTempStorage.
//    IN syntax helper.
//
// Returns - String, address in the temporary storage.
//
Function FormattedDocumentInBinaryData(Val FormattedDocument, Val FileType = Undefined, Val Address = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = GetTempFileName();
	FormattedDocument.Write(TempFile, FileType);
	Address = PutToTempStorage(New BinaryData(TempFile), Address);
	DeleteFiles(TempFile);
	
	Return Address;
	
EndFunction

// Returns the text contents of the file placed
// in temporary storage at the address passed as a parameter value BinaryDataAddress.
//
// Parameters:
//  BinaryDataAddress - String, address in the temporary storage,
//    at which was placed
//  the binary data, Encoding - TextEncoding or string - readable text
//    file encoding, see the description of
//  TextReading.Open() method in syntax helper, LineSeparator - String, the string is a line
//    divider in the file, see the
//  description of TextReading.Open() method syntax helper, ConvertibleLineSeparator - String, the string is a line
//    separator when converting to a standard line translation, see the description of TextReading method.Open()
//    in syntax helper.
//
// Return value: string.
//
Function AStringOfBinaryData(Val BinaryDataAddress, Val Encoding = Undefined, Val LineSeparator = Undefined, Val ConvertibleLineSeparator = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = AdditionalReportsAndDataProcessorsInSafeModeService.GetFileFromTemporaryStore(BinaryDataAddress);
	Read = New TextReader();
	Read.Open(TempFile, Encoding, LineSeparator, ConvertibleLineSeparator);
	Result = Read.Read();
	Read.Close();
	DeleteFiles(TempFile);
	
	Return Result;
	
EndFunction

// Writes the passed string into a temporary file, puts the binary
// data to the temporary storage, and returns binary file data address in the temporary storage.
//
// Parameters:
//  String - FormattedDocument
//  that is required to be saved, Script - TextEncoding or string - readable text
//    file encoding, see the description of
//  TextReading.Open() method in syntax helper, LineSeparator - String, the string is a line
//    divider in the file, see the
//  description of TextReading.Open() method syntax helper, ConvertibleLineSeparator - String, the string is a line
//    separator when converting to a standard line translation,
//    see the description of TextReading.Open() method in syntax helper.
//  Address - String or UUID, address in temporary storage to which data
//    or unique form identifier is required to be placed, in temporary storage
//    of which the data is required to be put
//    and return new address, see description of global context PutToTempStorage method in syntax helper.
//
// Returns - String, address in the temporary storage.
//
Function StringToBinaryData(Val String, Val Encoding = Undefined, Val LineSeparator = Undefined, Val ConvertibleLineSeparator = Undefined, Val Address = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = GetTempFileName();
	Record = New TextWriter();
	Record.Open(TempFile, Encoding, LineSeparator, False, ConvertibleLineSeparator);
	Record.Write(String);
	Record.Close();
	Address = PutToTempStorage(New BinaryData(TempFile), Address);
	DeleteFiles(TempFile);
	
	Return Address;
	
EndFunction

// Function runs zip archive unpacking.
//
// Parameters:
//  BinaryDataAddress - String, address in the temporary storage
//    to which the binary
//  file data is placed, Password - String, password for access to the ZIP
//  file if file is encrypted, FormID - UUID, unique form
//    identifier, see description of global
//    context PutToTempStorage method in syntax helper.
//
// Returns:
//  Map:
//    Correspondence key is the names of the files
//    and the directory containing in the archive, Correspondence value for
//    files from the archive is the address in the
//    temporary storage to which the binary file data is placed, for catalogs - similar correspondence.
//
Function UnpackArchive(Val BinaryDataAddress, Val Password = Undefined, Val FormID = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	TempFile = AdditionalReportsAndDataProcessorsInSafeModeService.GetFileFromTemporaryStore(BinaryDataAddress);
	UnpackingCatalog = GetTempFileName();
	CreateDirectory(UnpackingCatalog);
	Read = New ZipFileReader();
	Read.Open(TempFile, Password);
	Read.ExtractAll(UnpackingCatalog, ZIPRestoreFilePathsMode.Restore);
	Read.Close();
	ArchiveDescription = New Map;
	ArchiveUnpackingIteration(UnpackingCatalog + "\", ArchiveDescription, FormID);
	DeleteFiles(TempFile);
	DeleteFiles(UnpackingCatalog);
	
	Return ArchiveDescription;
	
EndFunction

// Function runs the packaging of files in zip archive.
//
// Parameters:
//  ArchiveDescription - Map:
//    Correspondence key is the names of the files
//    and the directory containing in the archive, Correspondence value for
//    files from the archive is the address in the
//    temporary storage to which the binary file data is placed, for catalogs - similar
//  correspondence, Password - String, password for access to the ZIP
//  file if the file is encrypted, Comment - String, comment that
//  describes the zip file, CompressionMethod - ZIPCompressionMethod - a compression method that will
//  compress the zip file, CompressionLevel - ZIPCompressionLevel - data compression
//  level, EncodingMethod - ZIPEncryptionMethod - encryption algorithm
//    that will
//  encrypt the zip file, FormID - UUID, unique form
//    identifier, see description of global
//    context PutToTempStorage method in syntax helper.
//
// Returns:
//  String, address in the temporary storage to which the
//    binary data of the packed archive was placed.
//
Function PackFilesInArchive(Val ArchiveDescription, Val Password = Undefined, Val Comment = Undefined, Val MethodCompression = Undefined, Val CompressionLevel = Undefined, Val CryptographyMethod = Undefined, Val Address = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	If MethodCompression = Undefined Then
		MethodCompression = ZIPCompressionMethod.Deflate;
	EndIf;
	
	If CompressionLevel = Undefined Then
		CompressionLevel = ZIPCompressionLevel.Optimal;
	EndIf;
	
	If CryptographyMethod = Undefined Then
		CryptographyMethod = ZIPEncryptionMethod.Zip20;
	EndIf;
	
	TempFile = GetTempFileName();
	PackageDirectory = GetTempFileName();
	CreateDirectory(PackageDirectory);
	ArchivePackingIteration(ArchiveDescription, PackageDirectory + "\");
	Record = New ZipFileWriter();
	Record.Open(TempFile, Password, Comment, MethodCompression, CompressionLevel, CryptographyMethod);
	Record.Add(PackageDirectory,
		ZIPStorePathMode.StoreRelativePath,
		ZIPSubDirProcessingMode.ProcessRecursively);
	Record.Write();
	Address = PutToTempStorage(New BinaryData(TempFile), Address);
	DeleteFiles(TempFile);
	DeleteFiles(PackageDirectory);
	
	Return Address;
	
EndFunction

// Runs a script of additional report or data processor in safe mode.
//
// Parameters:
//  SessionKey - UUID, safe mode extension
//  session key, AddressScript - String, address in the temporary storage to which
//    value table
//  is placed that is the script, LaunchKey - CatalogRef.AdditionalReportsAndDataProcessors,
//    start key passed to additional data processor on its initialization.
//
// Return value: Custom.
//
Function ExecuteScriptInSafeMode(Val SessionKey, Val AddressScript, ExecuteParameters = Undefined, SavedParameters = Undefined, DestinationObjects = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	Script = GetFromTempStorage(AddressScript);
	ExecutableObject = AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(
		Catalogs.AdditionalReportsAndDataProcessors.GetRef(SessionKey));
	
	AdditionalReportsAndDataProcessorsInSafeModeService.ExecuteScriptSafeMode(
		SessionKey, Script, ExecutableObject, ExecuteParameters, SavedParameters, DestinationObjects);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// For an internal use.
Function ArchiveUnpackingIteration(Val UnpackingCatalog, ArchiveDescription, Val FormID)
	
	Content = FindFiles(UnpackingCatalog, "*" , False);
	For Each ElementOfContent IN Content Do
		If ElementOfContent.IsDirectory() Then
			
			ArchiveDescription.Insert(ElementOfContent.Name,
				ArchiveUnpackingIteration(
					ElementOfContent.Path + "\", New Map(), FormID));
			
		Else
			
			ArchiveDescription.Insert(ElementOfContent.Name,
				PutToTempStorage(New BinaryData(ElementOfContent.FullName),
					FormID));
			
		EndIf;
	EndDo;
	
EndFunction

// For an internal use.
Procedure ArchivePackingIteration(Val ArchiveDescription, Val PackageDirectory)
	
	For Each ArchiveItem IN ArchiveDescription Do
		
		If TypeOf(ArchiveItem.Value) = Type("Map") Then
			
			SubdirectoryName = PackageDirectory + ArchiveItem.Key;
			CreateDirectory(SubdirectoryName);
			ArchivePackingIteration(ArchiveItem.Value, SubdirectoryName + "\");
			
		Else
			
			GetFromTempStorage(ArchiveItem.Value).Write(
				PackageDirectory + ArchiveItem.Key);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CheckCorrectnessOfCallOnEnvironment()
	
	If Not AdditionalReportsAndDataProcessorsInSafeModeService.CheckCorrectnessOfCallOnEnvironment() Then
		
		Raise NStr("en = 'Incorrect call for common AdditionalReportsAndDataProcessorsInSafeModeServerCall module function!
                                |This function module to be exported for use in safe
                                |mode should be called only from the script or context of client application!'");
		
	EndIf;
	
EndProcedure

#EndRegion
