////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Procedures and function for work with scanner.

// Opens the scanning set form.
Procedure OpenScanSettingsForm() Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		MessageText = NStr("en='Scanning is not supported in the client under OS Linux.';ru='Сканирование не поддерживается в клиенте под управлением ОС Linux.'");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
	AddInInstalled = FileOperationsServiceClient.InitializeComponent();
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	FormParameters = New Structure;
	FormParameters.Insert("AddInInstalled", AddInInstalled);
	FormParameters.Insert("ClientID",  ClientID);
	
	OpenForm("Catalog.Files.Form.ScanningSetup", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work commands with files

// Opens file for view.
//
// Parameters:
//  FileData - Structure - structure with file data.
//
Procedure Open(FileData) Export
	
	FileOperationsServiceClient.OpenFileWithAlert(Undefined, FileData);
	
EndProcedure

// Opens directory on the local computer in which this file is placed.
//
// Parameters:
//  FileData - Structure - structure with file data.
//
Procedure OpenFileDirectory(FileData) Export
	
	FileOperationsServiceClient.FileDir(Undefined, FileData);
	
EndProcedure

// Creates a new file interactively.
//
// Parameters:
//   ResultHandler - NotifyDescription - Optional. Description of
//                   the procedure that receives the result of method work.
//
//   FileOwner     - AnyRef - specifies group in which Item is created.
//                   If group is unknown at the time call this method - There will be Undefined.
//
//   OwnerForm     - ManagedForm - form from which file creation is caused.
//
//   CreationMode - file creation mode:
//       - Undefined - default value. Show file creation mode selection dialog.
//       - Number    - Create file by specified way:
//           * 1 - from pattern (by copying another file), 
//           * 2 - from disk (from the file client system),
//           * 3 - from scanner.
//
//   DontOpenCard - Boolean - action after creation:
//       * False - Value by default. Open file card after creation.
//       * True  - Don't open the file card after creation.
//
Procedure AddFile(ResultHandler = Undefined, FileOwner = Undefined,
		OwnerForm = Undefined, CreationMode = Undefined, DontOpenCard = False) Export
	
	If CreationMode = Undefined Then
		FileOperationsServiceClient.AddFile(ResultHandler, FileOwner, OwnerForm, , DontOpenCard);
	Else
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("ResultHandler", ResultHandler);
		ExecuteParameters.Insert("FileOwner", FileOwner);
		ExecuteParameters.Insert("OwnerForm", OwnerForm);
		ExecuteParameters.Insert("DoNotOpenCardAfterCreateFromFile", DontOpenCard);
		FileOperationsServiceClient.AddAfterCreateModeSelection(CreationMode, ExecuteParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions for work with files.

// Opens a form for working directory setting.
Procedure OpenWorkingDirectorySettingForm() Export
	
	OpenForm("CommonForm.MainWorkingDirectorySetting");
	
EndProcedure

// Prompts the user about continuation of closing the form if there remain captured files in the form.
// It is called from BeforeClose forms with files.
//
// By object reference checks whether there were captured files.
// If the captured files remained:
// - IN the Denial parameter True value is set,
// - User is prompted.
// If user answered affirmatively then the form closes again.
//
// Parameters:
//   Form          - ManagedForm - form in which you can edit file.
//   Cancel        - Boolean     - event parameter BeforeClose.
//   ObjectRef     - AnyRef      - ref to the file owner.
//   AttributeName - String      - attribute name of type Boolean in which sign
//                                 of that question was already displayed is stored.
//
// Example:
// &AtClient
// Procedure BeforeClose(Denial, StandardProcessing)
//  FileOperationsClient.ShowFormClosingConfirmationWithFiles(ThisObject, Denial, Object.Ref);
// 	// <If there are another code:>.
// 	If Denial
// 		Then Return;
// 	EndIf;
// 	// <Another applied code...>.
// EndProcedure
//
Procedure ShowFormClosingConfirmationWithFiles(Form, Cancel, ObjectRef, AttributeName = "CanCloseFormWithFiles") Export
	
	If Form[AttributeName] Then
		Return;
	EndIf;
	
	Quantity = FileOperationsServiceServerCall.CountOfFilesLockedByCurrentUser(ObjectRef);
	If Quantity = 0 Then
		Return;
	EndIf;
	
	Cancel = True;
	QuestionText = NStr("en='One or several files are occupied by you for editing."
""
"Continue?';ru='Один или несколько файлов заняты вами для редактирования."
""
"Продолжить?'");
	CommonUseClient.ShowArbitraryFormClosingConfirmation(Form, Cancel, QuestionText, AttributeName);
	
EndProcedure

// Copies an existing file.
//
// Parameters:
//  FileOwner - AnyRef - file owner.
//  BasisFile - CatalogRef - from where the File is copied.
//
Procedure CopyFile(FileOwner, BasisFile) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("BasisFile", BasisFile);
	FormParameters.Insert("FileOwner", FileOwner);
	
	OpenForm("Catalog.Files.ObjectForm", FormParameters);
	
EndProcedure

#EndRegion
