////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Determine whether you can lock the file, and if not, then generate error text.
//
// Parameters:
//  FileData    - Structure - structure with file data.
//  ErrorString - String    - (return value) - if you can not
//                take the file then it contains error description.
//
// Returns:
//  Boolean - If True then the current user can occupy
//           the file or the file is already occupied by the current user.
//
Function IfYouCanLockFile(FileData, ErrorString = "") Export
	
	If FileData.DeletionMark = True Then
		ErrorString = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Impossible to
			           |occupy file ""%1"", so. it is marked for deleting.'"),
			String(FileData.Ref));
		Return False;
	EndIf;
	
	Result = FileData.IsEditing.IsEmpty() Or FileData.CurrentUserIsEditing;  
	If Not Result Then
		ErrorString = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'File
			           |""%1"" is already locked
			           |for editing by the user ""%2"" with %3.'"),
			String(FileData.Ref),
			String(FileData.IsEditing),
			Format(FileData.LoanDate, "DLF=DV"));
	EndIf;
		
	Return Result;
	
EndFunction

// Get the name of scanned file of the DM-00000012 kind, where DM - base prefix.
//
// Parameters:
//  FileNumber  - Number - an integer for example 12.
//  BasePrefix - String - base prefix for example "DM".
//
// Returns:
//  String - scanned attachment file name for example "DM-00000012".
//
Function ScannedFileName(FileNumber, BasePrefix) Export
	
	FileName = "";
	If Not IsBlankString(BasePrefix) Then
		FileName = BasePrefix + "-";
	EndIf;
	
	FileName = FileName + Format(FileNumber, "ND=9; NLZ=; NG=0");
	Return FileName;
	
EndFunction

// Returns a string constant to form the events log messages.
//
// Returns:
//   String
//
Function EventLogMonitorEvent() Export
	
	Return NStr("en = 'Files'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Initializes a structure with file information.
//
// Parameters:
//   Mode        - String - "File" or "FileWithVersion".
//   SourceFile  - File   - file on the basis of which structure properties are filled.
//
// Returns:
//   Structure - with properties:
//    * NameWithoutExtension         - String - File name without extension.
//    * ExtensionWithoutDot          - String - file extension.
//    * ChangeTime                   - Date   - date and time of file change.
//    * ModificationTimeUniversal    - Date   - UTC date and time of file change.
//    * Size                         - Number  - file size in bytes.
//    * TemporaryFileStorageAddress  - String, ValueStorage - address in temporary storage with
//                                     binary file data or binary file data directly.
//    * TemporaryTextStorageAddress  - String, ValueStorage - address in temporary storage with
//                                       the taken text for PPD or directly data with the text.
//    * ThisIsWebClient                 - Boolean - True if the call is coming from a web client.
//    * Author                          - CatalogRef.Users - file author. If Undefined that
//                                                                     the current user.
//    * Comment                      - String  - comment to the file.
//    * WriteIntoHistory             - Boolean - write in user work history.
//    * StoreVersions                - Boolean - allow storage of file versions in the IB;
//                                               when creating new version - create a new
//                                               version or modify existing (False).
//    * Encrypted                    - Boolean - The file is encrypted.
//
Function FileInformation(Val Mode, Val SourceFile = Undefined) Export
	
	Result = New Structure;
	Result.Insert("BaseName");
	Result.Insert("Comment", "");
	Result.Insert("TextTemporaryStorageAddress");
	Result.Insert("StoreVersions", True);
	Result.Insert("Author"); 
	If Mode = "FileWithVersion" Then
		Result.Insert("ExtensionWithoutDot");
		Result.Insert("ModifiedAt", Date('00010101'));
		Result.Insert("ModificationTimeUniversal", Date('00010101'));
		Result.Insert("Size", 0);
		Result.Insert("Encrypted");
		Result.Insert("FileTemporaryStorageAddress");
		Result.Insert("WriteIntoHistory", False);
		Result.Insert("Encoding");
		Result.Insert("RefOnVersionSource");
		Result.Insert("NewVersionCreationDate"); 
		Result.Insert("NewVersionAuthor"); 
		Result.Insert("NewVersionComment"); 
		Result.Insert("NewVersionVersionNumber"); 
		Result.Insert("NewTextExtractionStatus"); 
	EndIf;
	
	If SourceFile <> Undefined Then
		Result.BaseName = SourceFile.BaseName;
		Result.ExtensionWithoutDot = CommonUseClientServer.ExtensionWithoutDot(SourceFile.Extension);
		Result.ModifiedAt = SourceFile.GetModificationTime();
		Result.ModificationTimeUniversal = SourceFile.GetModificationUniversalTime();
		Result.Size = SourceFile.Size();
	EndIf;
	Return Result;
	
EndFunction

#EndRegion
