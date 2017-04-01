
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CurrentUser = Users.CurrentUser();
	
	ColumnArray = New Array;
	For Each ColumnDetails IN FormAttributeToValue("DigitalSignatures").Columns Do
		ColumnArray.Add(ColumnDetails.Name);
	EndDo;
	SignaturesTableColumnsDescription = New FixedArray(ColumnArray);
	
	FileDataCorrect = False;
	
	If Parameters.Property("CreationMode") Then 
		CreationMode = Parameters.CreationMode;
	EndIf;
	
	If Parameters.Key = Undefined Or Parameters.Key.IsEmpty() Then
		
		NewFile = True;
		
		If Parameters.CopyingValue.IsEmpty() Then
			Object.FileOwner = Parameters.FileOwner;
		Else
			Object.CurrentVersion = Catalogs.FileVersions.EmptyRef();
			Parameters.BasisFile = Parameters.CopyingValue;
		EndIf;
		
	EndIf;
	
	BasisDocument = Parameters.BasisFile;
	If Not BasisDocument.IsEmpty() Then
		
		Object.FullDescr = BasisDocument.FullDescr;
		Object.Description = Object.FullDescr;
		Object.StoreVersions = BasisDocument.StoreVersions;
		
	EndIf;
	
	If Not Object.Ref.IsEmpty() Then
		FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
		FileDataCorrect = True;
	EndIf;
	
	OwnerType = TypeOf(Object.FileOwner);
	Items.Owner.Title = OwnerType;
	
	NewFileWritten = False;
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemNameForPlacement", "AdditionalAttributesGroup");
	PropertiesManagement.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders") Then
		RefreshFullPath();
	EndIf;
	
	If Not Parameters.BasisFile.IsEmpty() Then
		BasisFileDigitallySigned = Parameters.BasisFile.DigitallySigned;
	EndIf;
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = CommonUse.CommonModule("DigitalSignature");
		CommonSettings = ModuleDigitalSignature.CommonSettings();
		
		If CommonSettings.UseDigitalSignatures Then
			FillListOfSignatures();
		EndIf;
		
		If CommonSettings.UseEncryption Then
			FillEncryptionList();
		EndIf;
	EndIf;
	
	CommonSettings = FileFunctionsServiceClientServer.FileOperationsCommonSettings();
	
	FileExtensionInList = FileFunctionsServiceClientServer.FileExtensionInList(
		CommonSettings.TextFileExtensionsList, Object.CurrentVersionExtension);
	
	If FileExtensionInList Then
		If ValueIsFilled(Object.CurrentVersion) Then
			
			EncodingValue = FileOperationsServiceServerCall.GetFileVersionEncoding(
				Object.CurrentVersion);
			
			EncodingsList = FileOperationsService.GetEncodingsList();
			ItemOfList = EncodingsList.FindByValue(EncodingValue);
			If ItemOfList = Undefined Then
				Encoding = EncodingValue;
			Else
				Encoding = ItemOfList.Presentation;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Encoding) Then
			Encoding = NStr("en='By default';ru='По умолчанию'");
		EndIf;
		
	Else
		Items.Encoding.Visible = False;
	EndIf;
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders")
	   AND CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		AccessControlModule = CommonUse.CommonModule("AccessManagement");
		
		If Not AccessControlModule.IsRight("FilesUpdate", Object.FileOwner) Then
			ReadOnly = True;
		EndIf;
	EndIf;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject, "GroupAdditionalInformation");
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject, "VersionGroup");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEnabledOfFormItems();
	
	DescriptionBeforeWrite = Object.Description;
	
	If Not Parameters.BasisFile.IsEmpty() AND BasisFileDigitallySigned Then
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File ""%1"" is signed.
		|Once the DS data is copied into a new file, it will be unavailable for editing.
		|
		|Copy DS information into a new file?';ru='Файл ""%1"" подписан.
		|Копирование сведений об ЭП в новый файл сделает его недоступным для изменения.
		|
		|Скопировать сведения об ЭП в новый файл?'"),
			String(Parameters.BasisFile));
		Handler = New NotifyDescription("OnOpenAfterAnswerToQuestionCopyInformation", ThisObject);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	OnOpenEnd();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If FileEdited AND Not AnswerQuestionOnReceivedFileIsBusy Then
		ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
		If ClientWorkParameters.AuthorizedUser = Object.IsEditing Then
			QuestionText = NStr("en='File is not available for editing.
		|
		|Close the card?';ru='Файл занят для редактирования.
		|
		|Закрыть карточку?'");
			CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, QuestionText, "AnswerQuestionOnReceivedFileIsBusy");
			Return;
		EndIf;
	EndIf;
	
	If CreationMode = "FromTemplate" AND Not Object.DigitallySigned Then
		If NewFile AND NewFileWritten AND (NOT FileEdited) Then
			If Not AnswerToQuestionReceivedOpenForEditing Then
				Cancel = True;
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Open file ""%1"" for editing?';ru='Открыть файл ""%1"" для редактирования?'"),
					TrimAll(Object.FullDescr));
				Handler = New NotifyDescription("BeforeCloseAfterAnswerToQuestionOpenForEditing", ThisObject);
				ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
				Return;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "FileOpened" AND Source = Object.Ref Then
		NewFile = False;
	EndIf;

	If EventName = "Record_File" AND Parameter.Event = "FileEdited" AND Source = Object.Ref Then
		FileEdited = True;
	EndIf;

	If EventName = "Record_File" AND Parameter.Event = "ObjectDigitallySigned" AND Source = Object.Ref Then
		Read();
	EndIf;
	
	If EventName = "Record_File" AND Parameter.Event = "ActiveVersionChanged" AND Source = Object.Ref Then
		Read();
	EndIf;
	
	If EventName = "Record_File" AND Parameter.Event = "VersionSaved" AND Source = Object.Ref Then
		Read();
	EndIf;
	
	If Upper(EventName) = Upper("Record_ConstantsSet")
	   AND (    Upper(Source) = Upper("UseDigitalSignatures")
		  Or Upper(Source) = Upper("UseEncryption")) Then
			
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel)
	
	Object.Description = Object.FullDescr;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject)
	
	If DescriptionBeforeWrite <> CurrentObject.Description Then
		If CurrentObject.CurrentVersion.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
			
			FileOperationsServiceServerCall.RenameVersionFileOnDrive(
				CurrentObject.CurrentVersion,
				DescriptionBeforeWrite,
				CurrentObject.Description,
				UUID);
		EndIf;
	EndIf;
	
	If NewFile Then
		FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
		FileDataCorrect = True;
	EndIf;
	
	If Not Parameters.BasisFile.IsEmpty() AND Object.CurrentVersion.IsEmpty() Then
		CreateCopyOfVersion(Object.Ref, Parameters.BasisFile, CopySignaturesES);
		Modified = False;
	EndIf;
	
	UnlockDataForEdit(Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure AfterWrite()
	If NewFile Then 
		NewFileWritten = True;
		
		NotificationParameters = New Structure("Owner, File, Event", Object.FileOwner, Object.Ref, "FileCreated");
		Notify("Record_File", NotificationParameters);
		
	Else
		If DescriptionBeforeWrite <> Object.Description Then
			// update a file in cache
			FileOperationsServiceClient.UpdateInformationInWorkingDirectory(
				Object.CurrentVersion, Object.Description);
			
			DescriptionBeforeWrite = Object.Description;
		EndIf;
	EndIf;
	
	SetEnabledOfFormItems();
	SetEPListCommandsAvailability();
	SetEncriptionListCommandsEnabled();
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FullDescrOnChange(Item)
	Object.FullDescr = TrimAll(Object.FullDescr);
	Try
		FileFunctionsServiceClient.CorrectFileName(Object.FullDescr, True);
	Except
		ShowMessageBox(, BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Object.Description = TrimAll(Object.FullDescr);
EndProcedure

&AtClient
Procedure OwnerOnChange(Item)
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders") Then
		RefreshFullPath();
	EndIf;
	
	OwnerType = TypeOf(Object.FileOwner);
	Items.Owner.Title = OwnerType;
	
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
	OpenEncryptionCertificateRun();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Lock(Command)
	
	If Modified Then
		Write();
	EndIf;
	
	Handler = New NotifyDescription("ReadAndEnableFormItems", ThisObject);
	
	FileOperationsServiceClient.TakeWithAlarm(Handler, Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	If Object.Ref.IsEmpty() Then
		Write();
	EndIf;
	
	If Modified Then
		Write();
	EndIf;
	
	Handler = New NotifyDescription("ReadAndEnableFormItems", ThisObject);
	
	FileOperationsServiceClient.EditWithAlert(Handler, Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure Cancel_Edit(Command)
	
	If Modified Then
		Write();
	EndIf;
	
	GetFileDataIfIncorrect();
	
	Handler = New NotifyDescription("ReadAndEnableFormItems", ThisObject);
	
	FileReleaseParameters = FileOperationsServiceClient.FileReleaseParameters(Handler, FileData.Ref);
	FileReleaseParameters.StoreVersions = FileData.StoreVersions;	
	FileReleaseParameters.CurrentUserIsEditing = FileData.CurrentUserIsEditing;	
	FileReleaseParameters.IsEditing = FileData.IsEditing;	
	FileReleaseParameters.UUID = UUID;	
	FileOperationsServiceClient.ReleaseFileWithAlert(FileReleaseParameters);
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If Modified Then
		Write();
	EndIf;
	
	GetFileDataIfIncorrect();
	
	Handler = New NotifyDescription("ReadAndEnableFormItems", ThisObject);
	FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Handler, FileData.Ref, UUID);
	FileUpdateParameters.StoreVersions = FileData.StoreVersions;
	FileUpdateParameters.CurrentUserIsEditing = FileData.CurrentUserIsEditing;
	FileUpdateParameters.IsEditing = FileData.IsEditing;
	FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	If Modified Then
		Write();
	EndIf;
	
	Handler = New NotifyDescription("ReadAndEnableFormItems", ThisObject);
	
	FileOperationsServiceClient.SaveFileChangesWithAlert(Handler,
		Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Object.Ref, UUID);
	FileOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(Object.Ref, UUID);
	FileOperationsServiceClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnDrive(Command)
	
	If Modified Then
		Write();
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
	Handler = New NotifyDescription("ReadAndEnableFormItems", ThisObject);
	FileOperationsServiceClient.UpdateFromFileOnDiskWithAlert(Handler, FileData, UUID);
	
EndProcedure

&AtClient
Procedure Sign(Command)
	
	If Object.Ref.IsEmpty() Or Modified Then
		If Not Write() Then
			Return;
		EndIf;
	EndIf;
	
	FilesArray = New Array;
	FilesArray.Add(Object.Ref);
	
	FileOperationsServiceClient.SignFile(FilesArray, UUID,
		New NotifyDescription("SignEnding", ThisObject));
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Object.Ref.IsEmpty() Then 
		QuestionText =
			NStr("en='Data is still not recorded. You
		|can run command ""Encrypt"" only once the data is written.
		|
		|Data will be written.';ru='Данные еще не записаны. Выполнение
		|команды ""Зашифровать"" возможно только после записи данных.
		|
		|Данные будут записаны.'");
		Handler = New NotifyDescription("EncryptAfterAnswerToWriteQuestion", ThisObject);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.OKCancel);
		Return;
	EndIf;
	
	EncryptContinued();
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	FileData = FileOperationsServiceServerCall.GetFileDataAndNumberOfVersions(Object.Ref);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("DecryptAfterDecryptionAtClient", ThisObject, HandlerParameters);
	
	FileOperationsServiceClient.Decrypt(
		Handler,
		FileData.Ref,
		UUID,
		FileData);
	
EndProcedure

&AtClient
Procedure AddSignatureFromFile(Command)
	
	FileOperationsServiceClient.AddSignatureFromFile(
		Object.Ref,
		UUID,
		New NotifyDescription("AddSignatureFromFileEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveTogetherWithSignature(Command)
	
	FileOperationsServiceClient.SaveFileTogetherWithSignature(Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure OpenSignature(Command)
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.OpenSignature(Items.DigitalSignatures.CurrentData);
	
EndProcedure

&AtClient
Procedure Validate(Command)
	
	If Items.DigitalSignatures.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	GetFileDataIfIncorrect();
	ReturnStructure = FileOperationsServiceServerCall.FileDataAndBinaryData(Object.Ref,, UUID);
	FileFunctionsServiceClient.CheckSignatures(ThisObject,
		ReturnStructure.BinaryData, Items.DigitalSignatures.SelectedRows);
	
EndProcedure

&AtClient
Procedure Check_All(Command)
	
	GetFileDataIfIncorrect();
	ReturnStructure = FileOperationsServiceServerCall.FileDataAndBinaryData(Object.Ref,, UUID);
	FileFunctionsServiceClient.CheckSignatures(ThisObject, ReturnStructure.BinaryData);
	
EndProcedure

&AtClient
Procedure Save(Command)
	
	If Items.DigitalSignatures.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Items.DigitalSignatures.CurrentData.Object = Undefined
	 Or Items.DigitalSignatures.CurrentData.Object.IsEmpty() Then
		
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.SaveSignature(Items.DigitalSignatures.CurrentData.SignatureAddress);
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	Handler = New NotifyDescription("DeleteEnd", ThisObject);
	
	ShowQueryBox(Handler, NStr("en='Delete selected signature?';ru='Удалить выделенные подписи?'"), QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure OpenEncryptionCertificate(Command)
	OpenEncryptionCertificateRun();
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DigitalSignaturesCertificateIsIssuedTo.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DigitalSignaturesStatus.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DigitalSignaturesSignatureDate.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DigitalSignaturesComment.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DigitalSignatures.Invalid");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.IsEditing.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.IsEditing");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterElement.RightValue = Catalogs.Users.EmptyRef();

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.IsEditing.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.IsEditing");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = New DataCompositionField("CurrentUser");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);

EndProcedure

&AtClient
Procedure BeforeCloseAfterAnswerToQuestionOpenForEditing(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.Yes Then
		FileOperationsServiceClient.EditWithAlert(Undefined, Object.Ref, UUID);
	EndIf;
	AnswerToQuestionReceivedOpenForEditing = True;
	Close();
EndProcedure

&AtClient
Procedure OnOpenEnd()
	SetEPListCommandsAvailability();
	SetEncriptionListCommandsEnabled();
EndProcedure

&AtClient
Procedure OnOpenAfterAnswerToQuestionCopyInformation(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.Yes Then
		CopySignaturesES = True;
	EndIf;
	OnOpenEnd();
EndProcedure

&AtClient
Procedure ReadAndEnableFormItems(Result, ExecuteParameters) Export
	Read();
	SetEnabledOfFormItems();
EndProcedure

&AtClient
Procedure SignEnding(Result, ExecuteParameters) Export
	
	ReadAndFillSignatures();
	
	SetEnabledOfFormItems();
	SetEPListCommandsAvailability();
	
EndProcedure

&AtClient
Procedure EncryptAfterAnswerToWriteQuestion(Response, ExecuteParameters) Export
	If Response <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	ShowUserNotification(
		NStr("en='Creating:';ru='Создание:'"),
		GetURL(Object.Ref),
		String(Object.Ref),
		PictureLib.Information32);
	
	EncryptContinued();
EndProcedure

&AtClient
Procedure EncryptContinued()
	FileData = FileOperationsServiceServerCall.GetFileDataAndNumberOfVersions(Object.Ref);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("EncryptAfterEncryptionAtClient", ThisObject, HandlerParameters);
	
	FileOperationsServiceClient.Encrypt(
		Handler,
		FileData,
		UUID);
EndProcedure

&AtClient
Procedure EncryptAfterEncryptionAtClient(Result, ExecuteParameters) Export
	If Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FilesArrayInWorkingDirectoryForDelete = New Array;
	
	EncryptServer(
		Result.ArrayDataForPlacingToBase,
		Result.ThumbprintArray,
		FilesArrayInWorkingDirectoryForDelete,
		WorkingDirectoryName);
	
	FileOperationsServiceClient.InformAboutEncryption(
		FilesArrayInWorkingDirectoryForDelete,
		ExecuteParameters.FileData.Owner,
		Object.Ref);
	
	SetEnabledOfFormItems();
	SetEncriptionListCommandsEnabled();
	
EndProcedure

&AtClient
Procedure DecryptAfterDecryptionAtClient(Result, ExecuteParameters) Export
	If Not Result.Success Then
		Return;
	EndIf;
	WorkingDirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	DrillDownServer(Result.ArrayDataForPlacingToBase, WorkingDirectoryName);
	
	FileOperationsServiceClient.InformAboutDescripting(
		ExecuteParameters.FileData.Owner,
		Object.Ref);
	
	SetEnabledOfFormItems();
	SetEncriptionListCommandsEnabled();
EndProcedure

&AtClient
Procedure AddSignatureFromFileEnd(Result, ExecuteParameters) Export
	
	If Result = True Then
		SetEnabledOfFormItems();
		FillListOfSignatures();
		SetEPListCommandsAvailability();
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteEnd(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	AttributeDigitallySignedChanged = False;
	DeleteSignaturesAndRefreshList(AttributeDigitallySignedChanged);
	
	If AttributeDigitallySignedChanged Then
		NotifyChanged(Object.Ref);
		Read();
	EndIf;
	
	Notify("Record_File", New Structure("Event", "AttachedFileDigitallySigned"), Object.FileOwner);
	
	SetEPListCommandsAvailability();
	SetEnabledOfFormItems();
	
EndProcedure

&AtServer
Procedure CreateCopyOfVersion(Receiver, Source, CopySignaturesES)
	
	If Source.CurrentVersion.IsEmpty() Then
		Return;
	EndIf;
		
	FileStorage = Undefined;
	If Source.CurrentVersion.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		FileStorage = FileOperationsServiceServerCall.GetFileStorageFromInformationBase(Source.CurrentVersion);
	EndIf;
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
	FileInformation.BaseName = Object.Description;
	FileInformation.Size = Source.CurrentVersion.Size;
	FileInformation.ExtensionWithoutDot = Source.CurrentVersion.Extension;
	FileInformation.FileTemporaryStorageAddress = FileStorage;
	FileInformation.TextTemporaryStorageAddress = Source.CurrentVersion.TextStorage;
	FileInformation.RefOnVersionSource = Source.CurrentVersion;
	Version = FileOperationsServiceServerCall.Create_Version(Receiver, FileInformation);
	
	// Update the File form (data can be written not only when closing the form).
	Object.CurrentVersion = Version.Ref;
	
	// Update a record in the infobase.
	FileOperationsServiceServerCall.RefreshVersionInFile(
		Receiver, Version, Source.CurrentVersion.TextStorage, UUID);
	
	Read();
	
	If CopySignaturesES Then
		
		FileObject = Object.Ref.GetObject();
		FileObject.DigitallySigned = True;
		FileObject.Write();
		
		VersionObject = Object.CurrentVersion.GetObject();
		
		For Each String IN Source.CurrentVersion.DigitalSignatures Do
			NewRow = VersionObject.DigitalSignatures.Add();
			FillPropertyValues(NewRow, String);
		EndDo;
		
		VersionObject.DigitallySigned = True;
		VersionObject.Write();
		
		ReadAndFillSignatures();
		
	EndIf;	
	
	If Source.Encrypted Then
		
		FileObject = Object.Ref.GetObject();
		FileObject.Encrypted = True;
		
		For Each String IN Source.EncryptionCertificates Do
			NewRow = FileObject.EncryptionCertificates.Add();
			FillPropertyValues(NewRow, String);
		EndDo;
		
		FileObject.Write();
		
		VersionObject = Object.CurrentVersion.GetObject();
		VersionObject.Encrypted = True;
		VersionObject.Write();
		
		ReadAndFillEncryption();
		
	EndIf;	
		
EndProcedure

&AtClient
Procedure SetEnabledOfFormItems()
	
	FileActionsAvailable = Not Object.CurrentVersion.IsEmpty() AND Not Object.Ref.IsEmpty();
	
	Items.StoreVersions.Enabled = FileActionsAvailable AND Not Object.DeletionMark;
	
	Items.FormCancelEditing.Enabled = Not Object.IsEditing.IsEmpty();
	Items.FormOpenFileDirectory.Enabled = FileActionsAvailable;
	Items.FormSaveAs.Enabled = FileActionsAvailable;
	
	Items.FormEdit.Enabled = Not Object.DigitallySigned;
	Items.FormEndEdit.Enabled = Not Object.IsEditing.IsEmpty();
	
	Items.FullDescr.ReadOnly = Not Object.IsEditing.IsEmpty();
	
	Items.FormLock.Enabled = Object.IsEditing.IsEmpty() AND (FileActionsAvailable) AND Not Object.DigitallySigned;
	Items.FormSaveChanges.Enabled = Not Object.IsEditing.IsEmpty();
	
	Items.FormUpdateFromFileOnDrive.Enabled = FileActionsAvailable AND Not Object.DigitallySigned;
	
	Items.FormSign.Enabled = (FileActionsAvailable AND Object.IsEditing.IsEmpty()) OR Not FileActionsAvailable;
	Items.FormEncrypt.Enabled = (FileActionsAvailable AND Object.IsEditing.IsEmpty() AND Not Object.Encrypted) OR Not FileActionsAvailable;
	
	Items.FormAddSignatureFromFile.Enabled = FileActionsAvailable AND Object.IsEditing.IsEmpty();
	Items.FormSaveWithSignature.Enabled = FileActionsAvailable AND Object.DigitallySigned;
	Items.FormDrillDown.Enabled = FileActionsAvailable AND Object.Encrypted;
	
EndProcedure

&AtClient
Procedure WriteExecute()
	Write();
	Read();
EndProcedure

&AtClient
Procedure CopyExecute()
	
	FileOperationsClient.CopyFile(Object.FileOwner, Object.Ref);

EndProcedure

&AtServer
Procedure FillEncryptionList()
	
	EncryptionCertificates.Clear();
	
	If Object.Encrypted Then
		ArrayOfEncryptionCertificates = FileOperationsServiceServerCall.GetArrayOfEncryptionCertificates(Object.Ref);
		For Each CertificateStructure IN ArrayOfEncryptionCertificates Do
			NewRow = EncryptionCertificates.Add();
			NewRow.Presentation = CertificateStructure.Presentation;
			NewRow.Imprint = CertificateStructure.Imprint;
			If CertificateStructure.Certificate <> Undefined Then
				NewRow.CertificateAddress = PutToTempStorage(CertificateStructure.Certificate, UUID);
			EndIf;
		EndDo;
	EndIf;
	
	HeaderText = NStr("en='Allowed to decrypt';ru='Разрешено расшифровывать'");
	
	If EncryptionCertificates.Count() <> 0 Then
		HeaderText =HeaderText + " (" + Format(EncryptionCertificates.Count(), "NG=") + ")";
	EndIf;
	
	Items.GroupEncryptionCertificates.Title = HeaderText;
	
EndProcedure

&AtServer
Procedure FillListOfSignatures()
	
	DigitalSignatures.Clear();
		
	If Object.DigitallySigned Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		               |	DigitalSignatures.CertificateIsIssuedTo AS CertificateIsIssuedTo,
		               |	DigitalSignatures.SignatureDate AS SignatureDate,
		               |	DigitalSignatures.Comment AS Comment,
		               |	DigitalSignatures.Signature AS Signature,
		               |	DigitalSignatures.Imprint AS Imprint,
		               |	DigitalSignatures.Signer AS Signer,
		               |	DigitalSignatures.Certificate AS Certificate
		               |FROM
		               |	Catalog.FileVersions.DigitalSignatures AS DigitalSignatures
		               |WHERE
		               |	DigitalSignatures.Ref = &ObjectRef";
					   
		Query.Parameters.Insert("ObjectRef", Object.CurrentVersion);
		QuerySelection = Query.Execute().Select();
		
		While QuerySelection.Next() Do
			NewRow = DigitalSignatures.Add();
			
			NewRow.CertificateIsIssuedTo = QuerySelection.CertificateIsIssuedTo;
			NewRow.SignatureDate = QuerySelection.SignatureDate;
			NewRow.Comment = QuerySelection.Comment;
			NewRow.Object 		= Object.CurrentVersion;
			NewRow.Imprint 	= QuerySelection.Imprint;
			NewRow.Signer = QuerySelection.Signer;
			NewRow.Wrong 	= False;
			NewRow.PictureIndex = -1;
			
			BinaryData = QuerySelection.Signature.Get();
			If BinaryData <> Undefined Then 
				NewRow.SignatureAddress = PutToTempStorage(BinaryData, UUID);
			EndIf;
			
			CertificateBinaryData = QuerySelection.Certificate.Get();
			If CertificateBinaryData <> Undefined Then 
				NewRow.CertificateAddress = PutToTempStorage(CertificateBinaryData, UUID);
			EndIf;
			
		EndDo;
	EndIf;
	
	If DigitalSignatures.Count() = 0 Then
		HeaderText = NStr("en='Digital signatures';ru='Электронные подписи'");
	Else
		HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='DigitalSignatures (%1)';ru='Электронные подписи (%1)'"),
			Format(DigitalSignatures.Count(), "NG="));
	EndIf;
	Items.DigitalSignaturesGroup.Title = HeaderText;
	
EndProcedure

&AtServer
Procedure RefreshFullPath()
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders") Then
		
		FolderParent = CommonUse.ObjectAttributeValue(Object.Ref, "FileOwner");
		
		If ValueIsFilled(FolderParent) Then
			
			FullPath = "";
			
			While ValueIsFilled(FolderParent) Do
				
				If Not IsBlankString(FullPath) Then
					FullPath = "\" + FullPath;
				EndIf;
				
				FullPath = String(FolderParent) + FullPath;
				
				FolderParent = CommonUse.ObjectAttributeValue(FolderParent, "Parent");
				If Not ValueIsFilled(FolderParent) Then
					Break;
				EndIf;
				
			EndDo;
			
			Items.Owner.ToolTip = FullPath;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenFileExecute()
	
	If Object.Ref.IsEmpty() Then
		Write();
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Object.Ref, UUID);
	FileOperationsClient.Open(FileData);
	
EndProcedure

&AtClient
Procedure GetFileDataIfIncorrect()
	
	If FileData = Undefined OR Not FileDataCorrect Then
		FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
		FileDataCorrect = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadAndFillSignatures()
	
	Read();
	FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
	FileDataCorrect = True;
	FillListOfSignatures();
	
EndProcedure

&AtServer
Procedure ReadAndFillEncryption()
	
	Read();
	FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
	FileDataCorrect = True;
	FillEncryptionList();
	
EndProcedure

&AtServer
Procedure EncryptServer(ArrayDataForPlacingToBase,
                            ThumbprintArray,
                            FilesArrayInWorkingDirectoryForDelete,
                            WorkingDirectoryName)
	
	Encrypt = True;
	
	FileOperationsServiceServerCall.AddInformationAboutEncryption(
		Object.Ref,
		Encrypt,
		ArrayDataForPlacingToBase,
		UUID,
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryForDelete,
		ThumbprintArray);
		
	Read();
	FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
	FillEncryptionList();
	
EndProcedure

&AtServer
Procedure DrillDownServer(ArrayDataForPlacingToBase,
                             WorkingDirectoryName)
	
	Encrypt = False;
	ThumbprintArray = New Array;
	FilesArrayInWorkingDirectoryForDelete = New Array;
	
	FileOperationsServiceServerCall.AddInformationAboutEncryption(
		Object.Ref,
		Encrypt,
		ArrayDataForPlacingToBase,
		UUID,
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryForDelete,
		ThumbprintArray);
		
	Read();
	FileData = FileOperationsServiceServerCall.FileData(Object.Ref);
	FillEncryptionList();
	
EndProcedure

&AtServer
Procedure DeleteSignaturesAndRefreshList(AttributeDigitallySignedChanged)
	
	RowIndexes = New Array;
	
	For Each Item IN Items.DigitalSignatures.SelectedRows Do
		RowData = DigitalSignatures.FindByID(Item);
		
		If RowData.Object <> Undefined AND (NOT RowData.Object.IsEmpty()) Then
			
			RowIndexes.Add(DigitalSignatures.IndexOf(RowData));
		EndIf;
	EndDo;
	
	FileOperationsServiceServerCall.DeleteFileVersionSignatures(
		Object.CurrentVersion,
		RowIndexes,
		AttributeDigitallySignedChanged,
		UUID);
	
	FillListOfSignatures();
	
EndProcedure

&AtClient
Procedure SetEPListCommandsAvailability()
	
	FileFunctionsServiceClient.SetEnabledForElectronicSignaturesCommandsList(ThisObject);
	
EndProcedure

&AtClient
Procedure SetEncriptionListCommandsEnabled()
	
	FileFunctionsServiceClient.SetEnabledForEncryptionCertificatesListCommands(ThisObject);
	
EndProcedure

&AtClient
Procedure OpenEncryptionCertificateRun()
	
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
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeSigningOrEncryptionUsageAtServer()
	
	FileFunctionsService.CryptographyOnCreateFormAtServer(ThisObject, False);
	
EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion














