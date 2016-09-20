////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens the file for viewing or editing.
//  If the file is opened for viewing, it receives the file
// in the user working directory while looking for the file in the working directory and offers to open the existing file or get a file from the server.
//  If the file is opened for editing, it opens the file in the
// working directory (if any) or receives it from the server.
//
// Parameters:
//  FileData       - Structure - file data.
//  ForEditing - Boolean - True if the file is opened for editing, otherwise - False.
//
Procedure OpenFile(Val FileData, Val ForEditing = True) Export
	
	Parameters = New Structure;
	Parameters.Insert("FileData", FileData);
	Parameters.Insert("ForEditing", ForEditing);
	
	NotifyDescription = New NotifyDescription("OpenFileExtensionRequested", AttachedFilesServiceClient, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
	
EndProcedure

// Handler of the command for adding files.
//  Suggests the user to choose files in a
// file selection dialog and attempts to place the selected files in a files storage, when:
// - file size does not exceed the maximum allowable,
// - file extension is allowable,
// - there is free space in the volume (when files are stored in volumes),
// - in other conditions.
//
// Parameters:
//  FileOwner      - Ref - file owner.
//  FormID - UUID - identifier of managed form.
//  Filter             - String - optional
//                       parameter that allows you to
//                       specify a filter for the selected file, for example, images for poducts and services.
//
Procedure AddFiles(Val FileOwner, Val FormID, Val Filter = "") Export
	
	Parameters = New Structure;
	Parameters.Insert("FileOwner", FileOwner);
	Parameters.Insert("FormID", FormID);
	Parameters.Insert("Filter", Filter);
	
	NotifyDescription = New NotifyDescription("AddFilesExtensionRequested", AttachedFilesServiceClient, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
	
EndProcedure

// Signs the attached file.
//
// Parameters:
//  AttachedFile      - CatalogRef - ref to catalog with the "AttachedFiles" name.
//  FormID      - UUID - identifier of managed form.
//  AdditionalParameters - Undefined - standard behavior (see below).
//                          - Structure - with properties:
//       * FileData            - Structure - the file data if there is no property, it will be added.
//       * ResultProcessing    - NotifyDescription - At a call, a Boolean
//                                  type value is transferred if True - the file is successfully signed,
//                                  otherwise not signed if there are no properties, the notification will not be called.
//
Procedure SignFile(AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	If Not ValueIsFilled(AttachedFile) Then
		ShowMessageBox(, NStr("en='The file to be signed is not selected.';ru='Не выбран файл, который нужно подписать.'"));
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ShowMessageBox(, NStr("en='Insertion of digital signatures is not supported.';ru='Добавление электронных подписей не поддерживается.'"));
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	
	If Not ModuleDigitalSignatureClient.UseDigitalSignatures() Then
		ShowMessageBox(,
			NStr("en='To add a digital
		|signature, activate the option of using digital signatures in the application settings.';ru='Чтобы добавить
		|электронную подпись, включите в настройках программы использование электронных подписей.'"));
		Return;
	EndIf;
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	
	If Not AdditionalParameters.Property("FileData") Then
		AdditionalParameters.Insert("FileData", GetFileData(
			AttachedFile, FormID));
	EndIf;
	
	ResultProcessing = Undefined;
	AdditionalParameters.Property("ResultProcessing", ResultProcessing);
	
	AttachedFilesServiceClient.SignFile(AttachedFile,
		AdditionalParameters.FileData, FormID, ResultProcessing);
	
EndProcedure

// Saves the file along with the DS.
// Used in the Save File command handler.
//
// Parameters:
//  AttachedFile - CatalogRef - ref to catalog with the "AttachedFiles" name.
//  FileData        - Structure - (optional) - file data.
//  FormID - UUID - identifier of managed form.
//
Procedure SaveWithDS(Val AttachedFile, Val FileData, Val FormID) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FileData",        FileData);
	Parameters.Insert("FormID", FormID);
	
	DataDescription = New Structure;
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("ShowComment", True);
	DataDescription.Insert("Object",              AttachedFile);
	DataDescription.Insert("Data",              New NotifyDescription(
		"WhenYouSaveDataFile", AttachedFilesServiceClient, Parameters));
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.SaveDataWithSignature(DataDescription);
	
EndProcedure

// Saves the file to a directory on the drive.
// It is also used as an auxiliary function when you save a file with the DS.
//
// Parameters:
//  FileData  - Structure - file data.
//
// Returns:
//  String - name of the saved file.
//
Procedure SaveFileAs(Val FileData) Export
	
	Parameters = New Structure;
	Parameters.Insert("FileData", FileData);
	
	NotifyDescription = New NotifyDescription("SaveFileAsExtensionRequested", AttachedFilesServiceClient, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
	
EndProcedure

// Opens the common attached file form
// from the attached files catalog item form. The item form is closed.
// 
// Parameters:
//  Form     - ManagedForm - form of the attached files catalog.
//
Procedure GoToAttachedFileForm(Val Form) Export
	
	AttachedFile = Form.Key;
	
	Form.Close();
	
	For Each WindowKP IN GetWindows() Do
		
		Content = WindowKP.GetContent();
		
		If Content = Undefined Then
			Continue;
		EndIf;
		
		If Content.FormName = "CommonForm.AttachedFile" Then
			If Content.Parameters.Property("AttachedFile")
			   AND Content.Parameters.AttachedFile = AttachedFile Then
				WindowKP.Activate();
				Return;
			EndIf;
		EndIf;
		
	EndDo;
	
	OpenAttachedFileForm(AttachedFile);
	
EndProcedure

// Opens a form of files selection.
// Used in the selection handler for standard behavior overriding.
//
// Parameters:
//  FilesOwner       - Ref - reference to an object with files.
//  FormItem         - FormTable, FormField - the form item to
//                         which the notification of selection will be sent.
//  StandardProcessing - Boolean - (return value), is always set to False.
//
Procedure OpenFileChoiceForm(Val FilesOwner, Val FormItem, StandardProcessing = False) Export
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("FileOwner", FilesOwner);
	
	OpenForm("CommonForm.AttachedFiles", FormParameters, FormItem);
	
EndProcedure

// Opens the attached file form.
// Can be used as the attached file opening handler.
//
// Parameters:
//  AttachedFile   - CatalogRef - ref to catalog with the "AttachedFiles" name.
//  StandardProcessing - Boolean - (return value), is always set to False.
//
Procedure OpenAttachedFileForm(Val AttachedFile, StandardProcessing = False) Export
	
	StandardProcessing = False;
	
	If ValueIsFilled(AttachedFile) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("AttachedFile", AttachedFile);
		
		OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
	EndIf;
	
EndProcedure

// See this function in the AttachedFiles module.
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetRefToBinaryData = True,
                            Val ForEditing = False) Export
	
	Return AttachedFilesServiceServerCall.GetFileData(
		AttachedFile, FormID, GetRefToBinaryData, ForEditing);
	
EndFunction

// Receives the file from the files storage to the user working directory.
// Analog of the View or Edit interactive actions without opening the received file.
//   The ReadOnly property of the received file will be set
// depending on whether the file is captured for editing or not. If not captured - Read only is set.
//   If the file already exists in the working directory, it will be deleted
// and replaced with the file from the files storage.
//
// Parameters:
//  Notification - NotifyDescription - a warning that is executed after
//   the file is received in the user working directory. As a result, Structure with properties is returned:
//     * FileFullName - String - full attachment file name (with the path).
//     * ErrorDescription - String - error text if the file can not be received.
//
//  AttachedFile - CatalogRef - ref to catalog with the "AttachedFiles" name.
//  FormID - UUID - identifier of managed form.
//
//  AdditionalParameters - Undefined - use default values.
//     - Structure - with optional properties:
//         * ForEdit - Boolean    - Initial value is False. If
//                                           True, then the file will be captured for editing.
//         * FileData       - Structure - properties of the file which
//                                           can be passed to make the process faster if the properties had been received to the client from the server.
//
Procedure GetAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	AttachedFilesServiceClient.GetAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters);
	
EndProcedure

// Places the file from the user working directory to the files storage.
// Analog of the Complete Editing interactive action.
//
// Parameters:
//  Notification - NotifyDescription - alert that is executed after the
//   file is transferred to the files storage. As a result, Structure with properties is returned:
//     * ErrorDescription - String - text of the error if the file could not be placed.
//
//  AttachedFile - CatalogRef - ref to catalog with the "AttachedFiles" name.
//  FormID - UUID - identifier of managed form.
//
//  AdditionalParameters - Undefined - use default values.
//     - Structure - with optional properties:
//         * FileFullName - String - if blank, then the specified file will be placed
//                                     in the user working directory and then in the files storage.
//         * FileData    - Structure - properties of the file which
//                                        can be passed to make the process faster if the properties had been received to the client from the server.
//
Procedure PlaceAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	AttachedFilesServiceClient.PlaceAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Outdated procedures and functions.

// Outdated. You should use GetAttachedFile.
// To work with files, you need to have the extention connected.
//
// Parameters:
//  FileBinaryDataAddress     - String - the address in the temporary storage
//                                 with binary data or a navigation link to the file data in the infobase.
//  RelativePath            - String - a file path relative to the working directory.
//  ModificationDateUniversal - Date - universal date of file modification.
//  FileName                     - String - attachment file name (with extension).
//  UserWorkingDirectory   - String - path to the working directory.
//  FullFileNameAtClient      - String - (return value) is set in case of successful execution.
//
// Returns:
//  Boolean - if True, then the file is received and saved successfully, otherwise - False.
//
Function GetFileIntoWorkingDirectory(Val FileBinaryDataAddress,
                                    Val RelativePath,
                                    Val ModificationDateUniversal,
                                    Val FileName,
                                    Val UserWorkingDirectory = "",
                                    FullFileNameAtClient) Export
	
	Return AttachedFilesServiceClient.GetFileIntoWorkingDirectory(
		FileBinaryDataAddress, RelativePath, ModificationDateUniversal,
		FileName, UserWorkingDirectory, FullFileNameAtClient);
	
EndFunction

// Outdated. You should use PlaceAttachedFile.
// To work with files, you need to have the extention connected.
//
// Parameters:
//  PathToFile         - String - full path to the file.
//  FormID - UUID - identifier of managed form.
//
// Returns:
//  Structure - data of the file placed in the temporary storage.
//
Function PutFileToStorage(Val PathToFile, Val FormID) Export
	
	Return AttachedFilesServiceClient.PutFileToStorage(PathToFile, FormID);
	
EndFunction

// Outdated. You should use StartGetAttachedFile.
//
// Places a file from client drive into temporary storage.
//
// Parameters:
//  FileData             - (not used).
//  InformationAboutFile        - Structure - (the value to be returned).
//  FullFileNameAtClient - String - attachment file name on the client drive.
//  FormID      - UUID of the form.
//
// Returns:
//  Boolean - True - the file was successfully placed in the storage, otherwise - False.
//
Function PlaceFileOnDriveIntoStorage(Val FileData, InformationAboutFile, Val FullFileNameAtClient, Val FormID) Export
	InformationAboutFile = PutFileToStorage(FullFileNameAtClient, FormID);
	Return InformationAboutFile.FilePlacedToStorage;
EndFunction

#EndRegion
