
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FileWasCreated = Parameters.IsNew;
	
	ColumnArray = New Array;
	For Each ColumnDetails IN FormAttributeToValue("DigitalSignatures").Columns Do
		ColumnArray.Add(ColumnDetails.Name);
	EndDo;
	SignaturesTableColumnsDescription = New FixedArray(ColumnArray);
	
	CurrentUser = Users.AuthorizedUser();
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		CopiedObject = Parameters.CopyingValue.GetObject();
		CopyingValue = Parameters.CopyingValue;
		
		ObjectValue = Catalogs[CopiedObject.Metadata().Name].CreateItem();
		FillPropertyValues(
			ObjectValue,
			CopiedObject,
			"ModificationDateUniversal,
			|CreatedDate,
			|Encrypted,
			|Definition,
			|DSSigned,
			|Size,
			|Extension,
			|TextStorage,
			|FileOwner,
			|DeletionNote");
		
		For Each ItemEP IN CopiedObject.DigitalSignatures Do
			NewRow = ObjectValue.DigitalSignatures.Add();
			FillPropertyValues(NewRow, ItemEP);
		EndDo;
		
		For Each EncryptionItem IN CopiedObject.EncryptionCertificates Do
			NewRow = ObjectValue.EncryptionCertificates.Add();
			FillPropertyValues(NewRow, EncryptionItem);
		EndDo;
		
		ObjectValue.Author = Users.AuthorizedUser();
	Else
		If Parameters.Property("AttachedFile") Then
			ObjectValue = Parameters.AttachedFile.GetObject();
		Else
			ObjectValue = Parameters.Key.GetObject();
		EndIf;
	EndIf;
	
	CatalogName = ObjectValue.Metadata().Name;
	
	ConfigureFormObject(ObjectValue);
	
	OnChangeSigningOrEncryptionUsageAtServer();
	FillListOfSignatures();
	FillEncryptionList();
	
	If ReadOnly
	 OR Not AccessRight("Update", ThisObject.Object.FileOwner.Metadata()) Then
		
		SetChangeButtonsToInvisible(Items);
	EndIf;
	
	If Not ReadOnly
	   AND Not ThisObject.Object.Ref.IsEmpty() Then
		
		LockDataForEdit(ThisObject.Object.Ref, , UUID);
	EndIf;
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
	UpdateTitle();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ModificationDate = ToLocalTime(ThisObject.Object.ModificationDateUniversal);
	
	SetEPListCommandsAvailability();
	SetEncriptionListCommandsEnabled();
	
	ReadSignaturesCertificates();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	UnlockObject(ThisObject.Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Record_ConstantsSet")
	   AND (    Upper(Source) = Upper("UseDigitalSignatures")
		  Or Upper(Source) = Upper("UseEncryption")) Then
			
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersDigitalSignatures

&AtClient
Procedure DigitalSignaturesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.OpenSignature(Items.DigitalSignatures.CurrentData);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersEncryptionCertificates

&AtClient
Procedure EncryptionCertificatesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenEncryptionCertificate(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

///////////////////////////////////////////////////////////////////////////////////
// File command handlers

&AtClient
Procedure UpdateFromFileOnDrive(Command)
	
	Var NewExtension;
	
	If IsNew()
	 OR ThisObject.Object.Encrypted
	 OR ThisObject.Object.DigitallySigned
	 OR ValueIsFilled(ThisObject.Object.IsEditing) Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, , False);
	
	InformationAboutFile = New Structure;
	
	NotifyDescription = New NotifyDescription("UpdateFromDiskFileEnd", ThisObject);
	AttachedFilesServiceClient.SelectFileOnDriveAndPlaceIntoStorage(
		NotifyDescription, FileData, UUID);
	
EndProcedure

&AtClient
Procedure StandardWriteAndClose(Command)
	
	If ProcessFileWriteCommand() Then
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardWrite(Command)
	
	ProcessFileWriteCommand();
	
EndProcedure

&AtClient
Procedure StandardSetDeletionMark(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Modified Then
		If ThisObject.Object.DeletionMark Then
			QuestionText = NStr("en='File changes have to be written for actuation.
		|Write changes and uncheck deletion from
		|the %1 file?';ru='Для выполнения действия требуется записать изменения файла.
		|Записать изменения и снять
		|пометку на удаление с файла ""%1""?'");
		Else
			QuestionText = NStr("en='File changes have to be written for actuation.
		|Record changes and mark the
		|%1 file for deletion?';ru='Для выполнения действия требуется записать изменения файла.
		|Записать изменения и
		|пометить на удаление файл ""%1""?'");
		EndIf;
	Else
		If ThisObject.Object.DeletionMark Then
			QuestionText = NStr("en='Unmark the %1 file
		|from deletion?';ru='Снять пометку на удаление с файла
		|""%1""?'");
		Else
			QuestionText = NStr("en='Mark the
		|%1 file for deletion?';ru='Пометить
		|на удаление файл ""%1""?'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		QuestionText, ThisObject.Object.Ref);
		
	NotifyDescription = New NotifyDescription("StandardSetNoteDeletionResponseReceived", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure StandardSetNoteDeletionResponseReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ThisObject.Object.DeletionMark = Not ThisObject.Object.DeletionMark;
		ProcessFileWriteCommand();
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardReread(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Not Modified Then
		Return;
	EndIf;
	
	QuestionText = NStr("en='Data is changed. Reread?';ru='Данные изменены. Перечитать данные?'");
	
	NotifyDescription = New NotifyDescription("StandardRereadResponseReceived", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure StandardRereadResponseReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		RereadDataFromServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardCopy(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	FormParameters = New Structure("CopyingValue", ThisObject.Object.Ref);
	
	OpenForm("CommonForm.AttachedFile", FormParameters);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Handlers of EP commands and encryption.

&AtClient
Procedure SignFileDS(Command)
	
	If IsNew()
	 Or ValueIsFilled(ThisObject.Object.IsEditing)
	 Or ThisObject.Object.Encrypted Then
		
		Return;
	EndIf;
	
	AttachedFile = ThisObject.Object.Ref;
	FileData = GetFileData(AttachedFile, UUID);
	
	AttachedFilesServiceClient.SignFile(AttachedFile, FileData, UUID,
		, New NotifyDescription("OnReceiveSignature", ThisObject));
	
EndProcedure

&AtClient
Procedure AddDSFromFile(Command)
	
	If IsNew()
	 Or ValueIsFilled(ThisObject.Object.IsEditing)
	 Or ThisObject.Object.Encrypted Then
		
		Return;
	EndIf;
	
	AttachedFile = ThisObject.Object.Ref;
	AttachedFilesServiceClient.AddSignatureFromFile(AttachedFile, UUID,
		, New NotifyDescription("SignaturesOnReceive", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveWithDS(Command)
	
	If IsNew()
	 OR ValueIsFilled(ThisObject.Object.IsEditing)
	 OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	AttachedFilesClient.SaveWithDS(
		ThisObject.Object.Ref,
		FileData,
		UUID);
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If IsNew() Or ValueIsFilled(ThisObject.Object.IsEditing) Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	NotifyDescription = New NotifyDescription("EncryptDataReceived", ThisObject, FileData);
	AttachedFilesServiceClient.GetEncryptedData(NOTifyDescription, ThisObject.Object.Ref, FileData, UUID);

EndProcedure

&AtClient
Procedure EncryptDataReceived(ReceiptResult, FileData) Export
	If ReceiptResult = Undefined Then
		Return;
	EndIf;
	
	EncryptedData = ReceiptResult.EncryptedData;
	ThumbprintArray = ReceiptResult.ThumbprintArray;
	
	EncryptServer(EncryptedData, ThumbprintArray);
	
	AttachedFilesServiceClient.NotifyAboutChangeAndDeleteFileInWorkDirectory(
		ThisObject.Object.Ref, FileData);
	
	FillEncryptionList();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Record_AttachedFile", New Structure, ThisObject.Object.Ref);
	
	SetEncriptionListCommandsEnabled();
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If IsNew() Or Not ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	NotifyDescription = New NotifyDescription("DecryptDataReceived", ThisObject);
	
	AttachedFilesServiceClient.GetDecryptedData(NOTifyDescription,
		ThisObject.Object.Ref, FileData, UUID);
	
EndProcedure

&AtClient
Procedure DecryptDataReceived(DecryptedData, AdditionalParameters) Export
	
	If DecryptedData = Undefined Then
		Return;
	EndIf;
	
	DrillDownServer(DecryptedData);
	AttachedFilesServiceClient.NotifyAboutFileDecrypting(ThisObject.Object.Ref);
	FillEncryptionList();
	
	SetEncriptionListCommandsEnabled();
	
EndProcedure

&AtClient
Procedure CommandDSListOpenSignature(Command)
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.OpenSignature(Items.DigitalSignatures.CurrentData);
	
EndProcedure

&AtClient
Procedure CheckDS(Command)
	
	If Items.DigitalSignatures.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	FileFunctionsServiceClient.CheckSignatures(ThisObject,
		FileData.FileBinaryDataRef,
		Items.DigitalSignatures.SelectedRows);
	
EndProcedure

&AtClient
Procedure Check_All(Command)
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	FileFunctionsServiceClient.CheckSignatures(ThisObject, FileData.FileBinaryDataRef);
	
EndProcedure

&AtClient
Procedure SaveSignature(Command)
	
	If Items.DigitalSignatures.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.DigitalSignatures.CurrentData;
	
	If CurrentData.Object = Undefined Or CurrentData.Object.IsEmpty() Then
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.SaveSignature(CurrentData.SignatureAddress);
	
EndProcedure

&AtClient
Procedure DeleteDS(Command)
	
	NotifyDescription = New NotifyDescription("DeleteDSResponseReceived", ThisObject);
	ShowQueryBox(NOTifyDescription, NStr("en='Delete the selected signatures?';ru='Удалить выделенные подписи?'"), QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteDSResponseReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	
	RemoveFromSignaturesListAndSaveFile();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Record_AttachedFile", New Structure, ThisObject.Object.Ref);
	SetEPListCommandsAvailability();
	
EndProcedure

&AtClient
Procedure OpenEncryptionCertificate(Command)
	
	CurrentData = Items.EncryptionCertificates.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	
	If IsBlankString(CurrentData.CertificateAddress) Then
		ModuleDigitalSignatureClient.OpenCertificate(CurrentData.Imprint);
	Else
		ModuleDigitalSignatureClient.OpenCertificate(CurrentData.CertificateAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEPListCommandsAvailability()
	
	FileFunctionsServiceClient.SetEnabledForElectronicSignaturesCommandsList(ThisObject);
	
EndProcedure

&AtClient
Procedure SetEncriptionListCommandsEnabled()
	
	FileFunctionsServiceClient.SetEnabledForEncryptionCertificatesListCommands(ThisObject);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers for file collaboration supporting.

&AtClient
Procedure Edit(Command)
	
	If IsNew()
		OR ThisObject.Object.DigitallySigned
		OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If ValueIsFilled(ThisObject.Object.IsEditing)
	   AND ThisObject.Object.IsEditing <> CurrentUser Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	If ValueIsFilled(ThisObject.Object.IsEditing) Then
		AttachedFilesClient.OpenFile(FileData, True);
	Else
		AttachedFilesClient.OpenFile(FileData, True);
		LockFileForEditingServer();
		NotifyChanged(ThisObject.Object.Ref);
		Notify("Record_AttachedFile", New Structure, ThisObject.Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If IsNew()
		Or Not ValueIsFilled(ThisObject.Object.IsEditing)
		Or ThisObject.Object.IsEditing <> CurrentUser Then
			Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, , False);
	
	NotifyDescription = New NotifyDescription("EndEditStagingIsCompleted", ThisObject);
	AttachedFilesServiceClient.PlaceEditedFileOnDriveIntoStorage(NOTifyDescription,FileData, UUID);
	
EndProcedure

&AtClient
Procedure EndEditStagingIsCompleted(InformationAboutFile, AdditionalParameters) Export
	
	If InformationAboutFile <> Undefined Then
		PlaceFileIntoStorageAndRelease(InformationAboutFile);
		NotifyChanged(ThisObject.Object.Ref);
		Notify("Record_AttachedFile", New Structure, ThisObject.Object.Ref);
	EndIf;
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If IsNew()
	 OR Not ValueIsFilled(ThisObject.Object.IsEditing)
	 OR ThisObject.Object.IsEditing <> CurrentUser Then
		Return;
	EndIf;
	
	ReleaseFile();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Record_AttachedFile", New Structure, ThisObject.Object.Ref);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure UpdateTitle()
	
	If ValueIsFilled(ThisObject.Object.Ref) Then
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (Attached file)';ru='%1 (Присоединенный файл)'"), String(ThisObject.Object.Ref));
	Else
		Title = NStr("en='Attached file (Creation)';ru='Присоединенный файл (Создание)'")
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetRefToBinaryData = True)
	
	Return AttachedFiles.GetFileData(
		AttachedFile, FormID, GetRefToBinaryData);
	
EndFunction

&AtClient
Procedure OpenFileForViewing()
	
	If IsNew()
	 OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	FileIsEditing = ValueIsFilled(ThisObject.Object.IsEditing)
	                  AND ThisObject.Object.IsEditing = CurrentUser;
	
	AttachedFilesClient.OpenFile(FileData, FileIsEditing);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory()
	
	If IsNew()
	 OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	AttachedFilesServiceClient.OpenDirectoryWithFile(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs()
	
	If IsNew()
	 OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(ThisObject.Object.Ref, UUID);
	
	AttachedFilesClient.SaveFileAs(FileData);
	
EndProcedure

&AtServer
Procedure UpdateBinaryDataOfFileAtServer(InformationAboutFile)
	
	RecordedObject = FormAttributeToValue("Object");
	AttachedFiles.UpdateAttachedFile(RecordedObject, InformationAboutFile);
	ValueToFormAttribute(RecordedObject, "Object");
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetChangeButtonsToInvisible(Items)
	
	CommandsNames = GetObjectModificationCommandsNames();
	
	For Each FormItem IN Items Do
	
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillEncryptionList()
	
	EncryptionCertificates.Clear();
	
	If ThisObject.Object.Encrypted Then
		For Each CertificateStructure IN FormAttributeToValue("Object").EncryptionCertificates Do
			
			NewRow = EncryptionCertificates.Add();
			NewRow.Presentation = CertificateStructure.Presentation;
			NewRow.Imprint = CertificateStructure.Imprint;
			
			CertificateBinaryData = CertificateStructure.Certificate.Get();
			If CertificateBinaryData <> Undefined Then
				
				NewRow.CertificateAddress = PutToTempStorage(
					CertificateBinaryData, UUID);
			EndIf;
			
		EndDo;
	EndIf;
	
	HeaderText = NStr("en='Decryption allowed';ru='Разрешено расшифровывать'");
	
	If EncryptionCertificates.Count() <> 0 Then
		HeaderText =HeaderText + " (" + Format(EncryptionCertificates.Count(), "NG=") + ")";
	EndIf;
	
	Items.GroupEncryptionCertificates.Title = HeaderText;
	
EndProcedure

&AtServer
Procedure FillListOfSignatures()
	
	DigitalSignatures.Clear();
	
	If ThisObject.Object.DigitallySigned Then
		
		For Each ItemEP IN FormAttributeToValue("Object").DigitalSignatures Do
			
			NewRow = DigitalSignatures.Add();
			
			NewRow.CertificateIsIssuedTo = ItemEP.CertificateIsIssuedTo;
			NewRow.SignatureDate         = ItemEP.SignatureDate;
			NewRow.Comment         = ItemEP.Comment;
			NewRow.Object              = ThisObject.Object.Ref;
			NewRow.Imprint           = ItemEP.Imprint;
			NewRow.Signer = ItemEP.Signer;
			NewRow.Wrong             = False;
			NewRow.SignatureAddress        = PutToTempStorage(
				ItemEP.Signature.Get(), UUID);
			
			CertificateBinaryData = ItemEP.Certificate.Get();
			If CertificateBinaryData <> Undefined Then 
				
				NewRow.CertificateAddress = PutToTempStorage(
					CertificateBinaryData, UUID);
			EndIf;
			
		EndDo;
	EndIf;
	
	HeaderText = NStr("en='Digital signatures';ru='Электронные подписи'");
	
	If DigitalSignatures.Count() <> 0 Then
		HeaderText = HeaderText + " (" + String(DigitalSignatures.Count()) + ")";
	EndIf;
	
	Items.DigitalSignaturesGroup.Title = HeaderText;
	
EndProcedure

&AtServer
Procedure RemoveFromSignaturesListAndSaveFile()
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = CommonUse.CommonModule("DigitalSignature");
	
	RowIndexes = New Array;
	
	For Each SelectedRowsNumber IN Items.DigitalSignatures.SelectedRows Do
		RemovedRow = DigitalSignatures.FindByID(SelectedRowsNumber);
		RowIndexes.Add(DigitalSignatures.IndexOf(RemovedRow));
	EndDo;
	
	RecordedObject = FormAttributeToValue("Object");
	ModuleDigitalSignature.DeleteSignature(RecordedObject, RowIndexes);
	WriteFile(RecordedObject);
	ValueToFormAttribute(RecordedObject, "Object");
	
	FillListOfSignatures();
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure DrillDownServer(DecryptedData)
	
	RecordedObject = FormAttributeToValue("Object");
	AttachedFilesService.Decrypt(RecordedObject, DecryptedData);
	ValueToFormAttribute(RecordedObject, "Object");
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetButtonsEnabled(Form, Items, CurrentUser)
	
	FileIsEditing = ValueIsFilled(Form.Object.IsEditing);
	FileCurrentUserIsEditing = Form.Object.IsEditing = CurrentUser;
	
	AllCommandsNames = GetFormCommandsNames();
	CommandsNames = GetAvailableCommands(
		FileIsEditing,
		FileCurrentUserIsEditing,
		Form.Object.DigitallySigned,
		Form.Object.Encrypted,
		Form.Object.Ref.IsEmpty());
		
	If Form.DigitalSignatures.Count() = 0 Then
		RemoveCommandFromArray(CommandsNames, "OpenSignature");
	EndIf;
	
	For Each FormItem IN Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If AllCommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
	For Each FormItem IN Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = True;
		EndIf;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function GetFormCommandsNames()
	
	CommandsNames = GetObjectModificationCommandsNames();
	
	For Each CommandName IN GetObjectsBasicCommandsNames() Do
		CommandsNames.Add(CommandName);
	EndDo;
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetObjectsBasicCommandsNames()
	
	CommandsNames = New Array;
	
	// Simple commands that available to any user who is reading files.
	CommandsNames.Add("SaveWithDS");
	
	CommandsNames.Add("OpenCertificate");
	CommandsNames.Add("OpenSignature");
	CommandsNames.Add("CheckDS");
	CommandsNames.Add("Check_All");
	CommandsNames.Add("SaveSignature");
	
	CommandsNames.Add("OpenFileDirectory");
	CommandsNames.Add("OpenFileForViewing");
	CommandsNames.Add("SaveAs");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetObjectModificationCommandsNames()
	
	CommandsNames = New Array;
	
	CommandsNames.Add("SignFileDS");
	CommandsNames.Add("AddDSFromFile");
	
	CommandsNames.Add("DeleteDS");
	
	CommandsNames.Add("Edit");
	CommandsNames.Add("EndEdit");
	CommandsNames.Add("Release");
	
	CommandsNames.Add("Encrypt");
	CommandsNames.Add("Decrypt");
	
	CommandsNames.Add("StandardCopy");
	CommandsNames.Add("UpdateFromFileOnDrive");
	
	CommandsNames.Add("StandardWrite");
	CommandsNames.Add("StandardWriteAndClose");
	CommandsNames.Add("StandardSetDeletionMark");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetAvailableCommands(FileIsEditing,
                                 FileCurrentUserIsEditing,
                                 IsFileDigitallySigned,
                                 FileEncrypted,
                                 IsNewFile)
	
	If IsNewFile Then
		CommandsNames = New Array;
		CommandsNames.Add("StandardWrite");
		CommandsNames.Add("StandardWriteAndClose");
		Return CommandsNames;
	EndIf;
	
	CommandsNames = GetFormCommandsNames();
	
	If FileIsEditing Then
		If FileCurrentUserIsEditing Then
			RemoveCommandFromArray(CommandsNames, "UpdateFromFileOnDrive");
		Else
			RemoveCommandFromArray(CommandsNames, "EndEdit");
			RemoveCommandFromArray(CommandsNames, "Release");
			RemoveCommandFromArray(CommandsNames, "Edit");
		EndIf;
		DeleteCommandsDS(CommandsNames);
		
		RemoveCommandFromArray(CommandsNames, "UpdateFromFileOnDrive");
		RemoveCommandFromArray(CommandsNames, "SaveAs");
		
		RemoveCommandFromArray(CommandsNames, "Encrypt");
		RemoveCommandFromArray(CommandsNames, "Decrypt");
	Else
		RemoveCommandFromArray(CommandsNames, "EndEdit");
		RemoveCommandFromArray(CommandsNames, "Release");
	EndIf;
	
	If IsFileDigitallySigned Then
		RemoveCommandFromArray(CommandsNames, "EndEdit");
		RemoveCommandFromArray(CommandsNames, "Release");
		RemoveCommandFromArray(CommandsNames, "Edit");
		RemoveCommandFromArray(CommandsNames, "UpdateFromFileOnDrive");
	Else
		RemoveCommandFromArray(CommandsNames, "OpenCertificate");
		RemoveCommandFromArray(CommandsNames, "OpenSignature");
		RemoveCommandFromArray(CommandsNames, "CheckDS");
		RemoveCommandFromArray(CommandsNames, "Check_All");
		RemoveCommandFromArray(CommandsNames, "SaveSignature");
		RemoveCommandFromArray(CommandsNames, "DeleteDS");
		RemoveCommandFromArray(CommandsNames, "SaveWithDS");
	EndIf;
	
	If FileEncrypted Then
		DeleteCommandsDS(CommandsNames);
		RemoveCommandFromArray(CommandsNames, "EndEdit");
		RemoveCommandFromArray(CommandsNames, "Release");
		RemoveCommandFromArray(CommandsNames, "Edit");
		
		RemoveCommandFromArray(CommandsNames, "UpdateFromFileOnDrive");
		
		RemoveCommandFromArray(CommandsNames, "Encrypt");
		
		RemoveCommandFromArray(CommandsNames, "OpenFileDirectory");
		RemoveCommandFromArray(CommandsNames, "OpenFileForViewing");
		RemoveCommandFromArray(CommandsNames, "SaveAs");
		
		RemoveCommandFromArray(CommandsNames, "SignFileDS");
	Else
		RemoveCommandFromArray(CommandsNames, "Decrypt");
	EndIf;
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Procedure DeleteCommandsDS(Val CommandsNames)
	
	RemoveCommandFromArray(CommandsNames, "SignFileDS");
	RemoveCommandFromArray(CommandsNames, "AddDSFromFile");
	RemoveCommandFromArray(CommandsNames, "SaveWithDS");
	
EndProcedure

&AtClientAtServerNoContext
Procedure RemoveCommandFromArray(Array, CommandName)
	
	Position = Array.Find(CommandName);
	
	If Position = Undefined Then
		Return;
	EndIf;
	
	Array.Delete(Position);
	
EndProcedure

&AtServer
Procedure EncryptServer(EncryptedData, ThumbprintArray)
	
	RecordedObject = FormAttributeToValue("Object");
	
	AttachedFilesService.Encrypt(RecordedObject, EncryptedData, ThumbprintArray);
	
	ValueToFormAttribute(RecordedObject, "Object");
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure LockFileForEditingServer()
	
	RecordedObject = FormAttributeToValue("Object");
	AttachedFilesService.LockFileForEditingServer(RecordedObject);
	ValueToFormAttribute(RecordedObject, "Object");
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtServer
Procedure PlaceFileIntoStorageAndRelease(Val InformationAboutFile)
	
	RecordedObject = FormAttributeToValue("Object");
	AttachedFilesService.PlaceFileIntoStorageAndRelease(RecordedObject, InformationAboutFile);
	ValueToFormAttribute(RecordedObject, "Object");
	
EndProcedure

&AtServer
Procedure ReleaseFile()
	
	RecordedObject = FormAttributeToValue("Object");
	AttachedFilesService.ReleaseFile(RecordedObject);
	ValueToFormAttribute(RecordedObject, "Object");
	
EndProcedure

&AtClient
Function ProcessFileWriteCommand()
	
	If IsBlankString(ThisObject.Object.Description) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='To continue, specify the file name.';ru='Для продолжения укажите имя файла.'"), , "Description", "Object");
		Return False;
	EndIf;
	
	Try
		FileFunctionsServiceClient.CorrectFileName(ThisObject.Object.Description);
	Except
		CommonUseClientServer.MessageToUser(
			BriefErrorDescription(ErrorInfo()), ,"Description", "Object");
		Return False;
	EndTry;
	
	If Not WriteFile() Then
		Return False;
	EndIf;
	
	Modified = False;
	RepresentDataChange(ThisObject.Object.Ref, DataChangeType.Update);
	NotifyChanged(ThisObject.Object.Ref);
	
	Notify("Record_AttachedFile",
	           New Structure("IsNew", FileWasCreated),
	           ThisObject.Object.Ref);
	
	SetEPListCommandsAvailability();
	SetEncriptionListCommandsEnabled();
	
	Return True;
	
EndFunction

&AtServer
Procedure RereadDataFromServer()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	
EndProcedure

&AtServer
Function WriteFile(Val ObjectParameter = Undefined)
	
	If ObjectParameter = Undefined Then
		RecordedObject = FormAttributeToValue("Object");
	Else
		RecordedObject = ObjectParameter;
	EndIf;
	
	TransactionActive = False;
	Try
		If ValueIsFilled(CopyingValue) Then
			BinaryData = AttachedFiles.GetFileBinaryData(CopyingValue);
			
			If FileFunctionsService.TypeOfFileStorage() = Enums.FileStorageTypes.InInfobase Then
				
				BeginTransaction();
				TransactionActive = True;
				RefNew = Catalogs[CatalogName].GetRef();
				RecordedObject.SetNewObjectRef(RefNew);
				AttachedFilesService.WriteFileToInformationBase(RefNew, BinaryData);
				RecordedObject.FileStorageType = Enums.FileStorageTypes.InInfobase;
			Else
				FileInformation = FileFunctionsService.AddFileToVolume(BinaryData, RecordedObject.ModificationDateUniversal,
					RecordedObject.Description, RecordedObject.Extension); 
				RecordedObject.Volume = FileInformation.Volume;
				RecordedObject.PathToFile = FileInformation.PathToFile;
				RecordedObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive;
			EndIf;
		EndIf;
		
		RecordedObject.Write();
		
		If TransactionActive Then
			CommitTransaction();
		EndIf;
	Except
		If TransactionActive Then
			RollbackTransaction();
			WriteLogEvent(NStr("en='Files.An error occurred when writing the attached file';ru='Файлы.Ошибка записи присоединенного файла'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,,,	DetailErrorDescription(ErrorInfo()) );
		EndIf;
		Raise;
	EndTry;
	
	If ObjectParameter = Undefined Then
		ValueToFormAttribute(RecordedObject, "Object");
	EndIf;
	
	CopyingValue = Catalogs[CatalogName].EmptyRef();
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
	UpdateTitle();
	
	Return True;
	
EndFunction

&AtServer
Procedure ConfigureFormObject(Val NewObject)
	
	NewObjectType = New Array;
	NewObjectType.Add(TypeOf(NewObject));
	
	NewAttribute = New FormAttribute("Object", New TypeDescription(NewObjectType));
	NewAttribute.StoredData = True;
	
	AttributesToAdd = New Array;
	AttributesToAdd.Add(NewAttribute);
	
	ChangeAttributes(AttributesToAdd);
	
	ValueToFormAttribute(NewObject, "Object");
	
	For Each Item IN Items Do
		If TypeOf(Item) = Type("FormField")
		   AND Left(Item.DataPath, StrLen("PrototypeObject[0].")) = "PrototypeObject[0]."
		   AND Right(Item.Name, 1) = "0" Then
			
			ItemName = Left(Item.Name, StrLen(Item.Name) -1);
			If Items.Find(ItemName) <> Undefined Then
				Continue;
			EndIf;
			
			NewItem = Items.Insert(ItemName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			FillPropertyValues(NewItem, Item, ,
				"Name, DataPath, SelectedText, TypeLink");
			
			Item.Visible = False;
		EndIf;
	EndDo;
	
	If Not NewObject.IsNew() Then
		URL = GetURL(NewObject);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure UnlockObject(Val Ref, Val UUID)
	
	UnlockDataForEdit(Ref, UUID);
	
EndProcedure

// Continuance of procedure SignFileDS.
// Called out of subsystem DigitalSignature after data
// signing for method of nonstandard signature addition to item.
//
&AtClient
Procedure OnReceiveSignature(ExecuteParameters, Context) Export
	
	AddSignatureToFileAtServer(ExecuteParameters.DataDescription.SignatureProperties);
	SetEPListCommandsAvailability();
	
	ExecuteNotifyProcessing(ExecuteParameters.Notification, New Structure);
	
EndProcedure

// Continuance of procedure SignFileDS.
// Called out of subsystem DigitalSignature after signature
// preparation from files for method of nonstandard signature addition to item.
//
&AtClient
Procedure SignaturesOnReceive(ExecuteParameters, Context) Export
	
	AddSignatureToFileAtServer(ExecuteParameters.DataDescription.Signatures);
	SetEPListCommandsAvailability();
	
	ExecuteNotifyProcessing(ExecuteParameters.Notification, New Structure);
	
EndProcedure

&AtServer
Procedure AddSignatureToFileAtServer(SignatureProperties)
	
	RecordedObject = FormAttributeToValue("Object");
	AttachedFiles.AddFileSignature(RecordedObject, SignatureProperties, UUID);
	WriteFile(RecordedObject);
	ValueToFormAttribute(RecordedObject, "Object");
	FillListOfSignatures();
	
	SetButtonsEnabled(ThisObject, Items, CurrentUser);
	
EndProcedure

&AtClient
Procedure ReadSignaturesCertificates()
	
	If DigitalSignatures.Count() = 0 Then
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ModuleDigitalSignatureClientServer", 
		CommonUseClient.CommonModule("DigitalSignatureClientServer"));
	
	CommonSettings = Context.ModuleDigitalSignatureClientServer.CommonSettings();
	
	If CommonSettings.VerifyDigitalSignaturesAtServer Then
		Return;
	EndIf;
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"ReadSignaturesCertificatesAfterExtensionConnection", ThisObject, Context));
	
EndProcedure

// Continuance of procedure ReadSignaturesCertificates.
&AtClient
Procedure ReadSignaturesCertificatesAfterExtensionConnection(Attached, Context) Export
	
	If Not Attached Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	
	ModuleDigitalSignatureClient.CreateCryptoManager(New NotifyDescription(
			"ReadSignaturesCertificatesAfterCryptographyManagerCreating", ThisObject, Context),
		"GetCertificates", False);
	
EndProcedure

// Continuance of procedure ReadSignaturesCertificates.
&AtClient
Procedure ReadSignaturesCertificatesAfterCryptographyManagerCreating(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		Return;
	EndIf;
	
	Context.Insert("IndexOf", -1);
	Context.Insert("CryptoManager", Result);
	ReadSignaturesCertificatesCycleStart(Context);
	
EndProcedure

// Continuance of procedure ReadSignaturesCertificates.
&AtClient
Procedure ReadSignaturesCertificatesCycleStart(Context)
	
	If DigitalSignatures.Count() <= Context.IndexOf + 1 Then
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("TableRow", DigitalSignatures[Context.IndexOf]);
	
	If ValueIsFilled(Context.TableRow.Imprint) Then
		ReadSignaturesCertificatesCycleStart(Context);
		Return;
	EndIf;
	
	// Signature was not read when item was written.
	Signature = GetFromTempStorage(Context.TableRow.SignatureAddress);
	
	If Not ValueIsFilled(Signature) Then
		ReadSignaturesCertificatesCycleStart(Context);
		Return;
	EndIf;
	
	Context.CryptoManager.StartGettingCertificatesFromSignature(New NotifyDescription(
			"ReadSignaturesCertificatesCycleAfterCertificatesReceivingFromSignature", ThisObject, Context,
			"ReadSignaturesCertificatesCycleAfterCertificatesReceivingErrorFromSignature", ThisObject),
		Signature);
	
EndProcedure

// Continuance of procedure ReadSignaturesCertificates.
&AtClient
Procedure ReadSignaturesCertificatesCycleAfterCertificatesReceivingErrorFromSignature(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ReadSignaturesCertificatesCycleStart(Context);
	
EndProcedure

// Continuance of procedure ReadSignaturesCertificates.
&AtClient
Procedure ReadSignaturesCertificatesCycleAfterCertificatesReceivingFromSignature(Certificates, Context) Export
	
	If Certificates.Count() = 0 Then
		ReadSignaturesCertificatesCycleStart(Context);
		Return;
	EndIf;
	
	Context.Insert("Certificate", Certificates[0]);
	
	Context.Certificate.BeginUnloading(New NotifyDescription(
		"ReadSignaturesCertificatesCycleAfterCertificateExport", ThisObject, Context,
		"ReadSignaturesCertificatesCycleAfterCertificateExportErrors", ThisObject));
	
EndProcedure

// Continuance of procedure ReadSignaturesCertificates.
&AtClient
Procedure ReadSignaturesCertificatesCycleAfterCertificateExportErrors(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ReadSignaturesCertificatesCycleStart(Context);
	
EndProcedure

// Continuance of procedure ReadSignaturesCertificates.
&AtClient
Procedure ReadSignaturesCertificatesCycleAfterCertificateExport(CertificateData, Context) Export
	
	TableRow = Context.TableRow;
	
	TableRow.Imprint = Base64String(Context.Certificate.Imprint);
	TableRow.CertificateAddress = PutToTempStorage(CertificateData, UUID);
	TableRow.CertificateIsIssuedTo =
		Context.ModuleDigitalSignatureClientServer.SubjectPresentation(Context.Certificate);
	
	ReadSignaturesCertificatesCycleStart(Context);
	
EndProcedure


&AtClient
Function IsNew()
	
	Return ThisObject.Object.Ref.IsEmpty();
	
EndFunction

&AtClient
Procedure UpdateFromDiskFileEnd(InformationAboutFile, AdditionalParameters) Export
	
	If InformationAboutFile = Undefined Then
		Return;
	EndIf;
		
	UpdateBinaryDataOfFileAtServer(InformationAboutFile);
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Record_AttachedFile", New Structure, ThisObject.Object.Ref);
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeSigningOrEncryptionUsageAtServer()
	
	FileFunctionsService.CryptographyOnCreateFormAtServer(ThisObject, False);
	
EndProcedure

#EndRegion
