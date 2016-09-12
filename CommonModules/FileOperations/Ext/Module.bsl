////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Creates file card in database together with a version.
// 
// Parameters:
//  Owner - Ref - file owner which will be set in attribute FileOwner at created file.
//
//  PathToFileOnDrive  - String - full path to file on the disk including name and file extension.
//                       File should be at server.
//
// Returns:
//  CatalogRef.Files - created file.
//
Function CreateFileBasedOnFileOnDrive(Owner, PathToFileOnDrive) Export
	
	File = New File(PathToFileOnDrive);
	
	BinaryData = New BinaryData(PathToFileOnDrive);
	FileTemporaryStorageAddress = PutToTempStorage(BinaryData);
	
	TextTemporaryStorageAddress = "";
	
	If FileFunctionsService.ExtractFileTextsAtServer() Then
		// Text extracts scheduled job.
		TextTemporaryStorageAddress = ""; 
	Else
		// Try text extracting if server under Windows.
		If FileFunctionsService.ThisIsWindowsPlatform() Then
			Text = FileFunctionsServiceClientServer.ExtractText(PathToFileOnDrive);
			TextTemporaryStorageAddress = New ValueStorage(Text);
		EndIf;
	EndIf;
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion", File);
	FileInformation.FileTemporaryStorageAddress = FileTemporaryStorageAddress;
	FileInformation.TextTemporaryStorageAddress = TextTemporaryStorageAddress;
	Return FileOperationsServiceServerCall.CreateFileWithVersion(Owner, FileInformation);
	
EndFunction

// Event handler BeforeWrite file owner object.
// It is defined for objects except Document.
//
// Parameters:
//  Source - Object - standard event parameter BeforeWrite, for example CatalogObject.
//                      Except - DocumentObject.
//  Cancel - Boolean - standard event parameter BeforeWrite.
//
Procedure SetDeletionMarkOfFilesBeforeWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.DeletionMark <> CommonUse.ObjectAttributeValue(Source.Ref, "DeletionMark") Then
		MarkToDeleteAttachedFiles(Source.Ref, Source.DeletionMark);
	EndIf;
	
EndProcedure

// Event handler BeforeWrite file owner object.
// It is defined only for Document objects.
//
// Parameters:
//  Source        - DocumentObject      - standard event parameter BeforeWrite.
//  Cancel        - Boolean             - standard event parameter BeforeWrite.
//  WriteMode     - DocumentWriteMode   - standard event parameter BeforeWrite.
//  PostingMode   - DocumentPostingMode - standard event parameter BeforeWrite.
//
Procedure SetDeletionMarkOfDocumentFilesBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.DeletionMark <> CommonUse.ObjectAttributeValue(Source.Ref, "DeletionMark") Then
		MarkToDeleteAttachedFiles(Source.Ref, Source.DeletionMark);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Marks/unmarks for deletion the attached files.
Procedure MarkToDeleteAttachedFiles(FileOwner, DeletionMark)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.IsEditing AS IsEditing
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		If DeletionMark AND Not Selection.IsEditing.IsEmpty() Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='""%1"" can not be"
"deleted, so. contains"
"file ""%2"" taken for editing.';ru='""%1"" не может быть удален,"
"т.к. содержит файл ""%2"","
"занятый для редактирования.'"),
				String(FileOwner),
				String(Selection.Ref));
		EndIf;
		FileObject = Selection.Ref.GetObject();
		FileObject.Lock();
		FileObject.SetDeletionMark(DeletionMark);
	EndDo;
	
EndProcedure

#EndRegion
