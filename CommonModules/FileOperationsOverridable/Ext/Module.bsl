////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Checks if this file can be locked.
//
// Parameters:
//  FileData         - Structure - with file data.
//  ErrorDescription - String - containing the text of error in case there is no option to lock.
//                     If it is not empty, then the file can not be locked.
//
Procedure WhenTryingToLockFile(FileData, ErrorDescription = "") Export
	
	
	
EndProcedure

// It is called when creating a file.
//
// Parameters:
//  File - CatalogRef.Files - ref to the file created.
//
Procedure OnFileCreate(File) Export
	
EndProcedure

// It is called after copying the file from the source file for filling out those attributes of a new file
// which are not provided in the SSL and were added to the Files or FileVersions catalogs in the configuration.
//
// Parameters:
//  NewFile    - CatalogRef.Files - ref to a new file which you must fill.
//  SourceFile - CatalogRef.Files - ref to the source file from which you should copy the attributes.
//
Procedure FillFileAttributesFromSourceFile(NewFile, SourceFile) Export
	
EndProcedure

// It is called when capturing a file.
//
// Parameters:
//  FileData - Structure - containing file information 
//                see function FileOperationsServiceServerCall.GetFileData().
//
//  UUID - form unique ID.
//
Procedure AtFileCapture(FileData, UUID) Export
	
EndProcedure

// It is called when releasing the file.
//
// Parameters:
//  FileData - Structure - containing file information
//                see function FileOperationsServiceServerCall.GetFileData().
//
//  UUID - form unique ID.
//
Procedure OnFileRelease(FileData, UUID) Export
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Outdated. It will be deleted in the next edition of the SSL.
// You should use the WhenTryingToLockFile procedure.
Function ProbablyFileIsLocked(FileData, ErrorString = "") Export 
	
	Return True;
	
EndFunction

#EndRegion
