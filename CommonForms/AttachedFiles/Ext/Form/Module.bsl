
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.FileOwner = Undefined Then
		Raise NStr("en = 'Attached file list can
		                             |be looked at only in the form of an objectowner.'");
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "PickupSelection");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		Title = NStr("en = 'Attached file selection'");
		
		// Filter of items not marked for deletion.
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	CatalogNameFilesStorage = Undefined;
	ConfigureDynamicList(CatalogNameFilesStorage);
	
	CatalogWithFilesType = Type("CatalogRef." + CatalogNameFilesStorage);
	
	MetadataCatalogWithFiles = Metadata.FindByType(CatalogWithFilesType);
	
	If Not AccessRight("InteractiveInsert", MetadataCatalogWithFiles) Then
		HideButtonsOfAdding();
	Else
		If CommonUseClientServer.ThisIsWebClient() Then
			If Not AddRight(CatalogNameFilesStorage, Parameters.FileOwner) Then
				HideButtonsOfAdding();
			EndIf;
		EndIf;
	EndIf;
		
	If Not AccessRight("Edit", MetadataCatalogWithFiles)
	 OR Not AccessRight("Edit", Parameters.FileOwner.Metadata())
	 OR Parameters.ReadOnly = True Then
		
		HideButtonsChanges();
	EndIf;
	
	AllCommandsNamesForms = GetFormCommandsNames();
	NamesOfElements = New Array;
	
	For Each FormItem IN Items Do
		
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If AllCommandsNamesForms.Find(FormItem.CommandName) <> Undefined Then
			NamesOfElements.Add(FormItem.Name);
		EndIf;
	EndDo;
	
	ButtonsFormElementsNames = New FixedArray(NamesOfElements);
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormChange.Visible = False;
		Items.ChangeForm82.Visible = True;
		Items.FormCopy.OnlyInAllActions = False;
		Items.FormSetDeletionMark.OnlyInAllActions = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetButtonsEnabled();
	
	// CurrentDate is received not for saving in the
	// data base and it is used only in
	// the dynamic list calculation of local
	// time from universal time saving in the data base, so it is not necessary to CurrentSessionDate casting.
	CurrentDateClient = CurrentDate();
	
	List.Parameters.SetParameterValue(
		"SecondsUntilLocalTime",
		CurrentDateClient - ToUniversalTime(CurrentDateClient));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Record_ConstantsSet")
	   AND (    Upper(Source) = Upper("UseDigitalSignatures")
		  Or Upper(Source) = Upper("UseEncryption")) Then
			
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
	If EventName <> "Record_AttachedFile" Then
		Return;
	EndIf;
	
	FileReference = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
	
	If TypeOf(FileReference) <> CatalogWithFilesType Then
		Return;
	EndIf;
	
	If Parameter.Property("IsNew") AND Parameter.IsNew Then
		
		Items.List.CurrentRow = FileReference;
		SetButtonsEnabled();
	Else
		If Not ValidateActionAllowed() Then
			Return;
		EndIf;
		
		If FileReference = Items.List.CurrentData.Ref Then
			SetButtonsEnabled();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.List.ChoiceMode Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	OpenFile();
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	SetButtonsEnabled();
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	If Copy Then
		
		If Not ValidateActionAllowed() Then
			Return;
		EndIf;
		
		FormParameters = New Structure("CopyingValue", Item.CurrentData.Ref);
		
		OpenForm("CommonForm.AttachedFile", FormParameters);
		
	Else
		AttachedFilesClient.AddFiles(Parameters.FileOwner, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key",           CurrentData.Ref);
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("CommonForm.AttachedFile", FormParameters, , False);
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	FileNameArray = New Array;
	
	If TypeOf(DragParameters.Value) = Type("File")
	   AND DragParameters.Value.IsFile() = True Then
		
		FileNameArray.Add(DragParameters.Value.FullName);
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1
		   AND TypeOf(DragParameters.Value[0]) = Type("File") Then
			
			For Each Value IN DragParameters.Value Do
				
				If TypeOf(Value) = Type("File") AND Value.IsFile() Then
					FileNameArray.Add(Value.FullName);
				EndIf;
			EndDo;
		EndIf;
			
	EndIf;
	
	If FileNameArray.Count() > 0 Then
		
		AttachedFilesServiceClient.AddFilesByDragging(
			Parameters.FileOwner, UUID, FileNameArray);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

///////////////////////////////////////////////////////////////////////////////////
// File command handlers

&AtClient
Procedure Create(Command)
	
	Items.List.AddRow();
	
EndProcedure

&AtClient
Procedure OpenFileForViewing(Command)
	
	OpenFile();
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If CurrentData.Encrypted Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesServiceClient.OpenDirectoryWithFile(FileData);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.List.Refresh();
	
	AttachIdleHandler("SetButtonsEnabled", 0.1, True);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnDrive(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData.Encrypted Or CurrentData.DigitallySigned Or CurrentData.FileIsEditing Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, , False);
	If FileData.Encrypted Or FileData.DigitallySigned Or FileData.FileIsEditing Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesServiceClient.UpdateAttachedFile(CurrentData.Ref, FileData, UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted
	 OR (CurrentData.FileIsEditing AND CurrentData.FileCurrentUserIsEditing) Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.Encrypted
	 OR (FileData.FileIsEditing AND FileData.FileCurrentUserIsEditing) Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.SaveFileAs(FileData);
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	Items.List.CopyRow();
	
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("AttachedFile", Items.List.CurrentData.Ref);
	
	OpenForm("CommonForm.AttachedFile", FormParameters);
	
EndProcedure

&AtClient
Procedure SetDeletionMark(Command)
	
	If Not ValidateActionAllowed("DeletionMark") Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.DeletionMark Then
		QuestionText = NStr("en = 'Unmark the %1 file
		                          |from deletion?'");
	Else
		QuestionText = NStr("en = 'Mark the
		                          |%1 file for deletion?'");
	EndIf;
	
	QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(QuestionText, CurrentData.Ref);
	
	NotifyDescription = New NotifyDescription("SetDeletionMarkResponseReceived", ThisObject, CurrentData);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure SetDeletionMarkResponseReceived(QuestionResult, CurrentData) Export
	If QuestionResult = DialogReturnCode.Yes Then
		SetDeletionFlagValue(CurrentData.Ref, Not CurrentData.DeletionMark);
		Items.List.Refresh();
	EndIf;
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers for DS supporting and encryption.

&AtClient
Procedure Sign(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileIsEditing
	 OR CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.FileIsEditing
	 OR FileData.Encrypted Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFile = CurrentData.Ref;
	FileData = GetFileData(AttachedFile, UUID);
	
	AttachedFilesServiceClient.SignFile(AttachedFile, FileData, UUID,
		New NotifyDescription("AddingSignaturesComplete", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveWithDS(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.Encrypted Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.SaveWithDS(CurrentData.Ref, FileData, UUID);
	
EndProcedure

&AtClient
Procedure AddDSFromFile(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileIsEditing
	 OR CurrentData.Encrypted Then
		Return;
	EndIf;
	
	AttachedFile = CurrentData.Ref;
	AttachedFilesServiceClient.AddSignatureFromFile(AttachedFile, UUID,
		New NotifyDescription("AddingSignaturesComplete", ThisObject));
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileIsEditing
	 OR CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.FileIsEditing
	 OR FileData.Encrypted Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesServiceClient.Encrypt(
		CurrentData.Ref, FileData, UUID);
	
	SetButtonsEnabled();
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If Not CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If Not FileData.Encrypted Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesServiceClient.Decrypt(
		CurrentData.Ref, FileData, UUID);
	
	SetButtonsEnabled();
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers for file collaboration supporting.

&AtClient
Procedure Edit(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If (CurrentData.FileIsEditing AND Not CurrentData.FileCurrentUserIsEditing)
	   OR CurrentData.Encrypted
	   OR CurrentData.DigitallySigned Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If (  FileData.FileIsEditing
	      AND Not FileData.FileCurrentUserIsEditing)
	 OR FileData.Encrypted
	 OR FileData.DigitallySigned Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.OpenFile(FileData, True);
	
	If Not CurrentData.FileIsEditing Then
		
		LockFileForEditingServer(CurrentData.Ref);
		
		NotifyChanged(CurrentData.Ref);
		SetButtonsEnabled();
	EndIf;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If Not CurrentData.FileIsEditing
	 OR Not CurrentData.FileCurrentUserIsEditing Then
		Return;
	EndIf;
	
	FileData = GetFileData(CurrentData.Ref, , False);
	
	If Not FileData.FileIsEditing
	 OR Not FileData.FileCurrentUserIsEditing Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("EndEditStagingIsCompleted", ThisObject, CurrentData);
	AttachedFilesServiceClient.PlaceEditedFileOnDriveIntoStorage(NOTifyDescription, FileData, UUID);
	
EndProcedure

&AtClient
Procedure EndEditStagingIsCompleted(InformationAboutFile, CurrentData) Export
	
	If InformationAboutFile <> Undefined
		AND InformationAboutFile.FilePlacedToStorage Then
		PlaceFileIntoStorageAndRelease(CurrentData.Ref, InformationAboutFile);
		NotifyChanged(CurrentData.Ref);
		SetButtonsEnabled();
	EndIf;
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If Not CurrentData.FileIsEditing
	 OR Not CurrentData.FileCurrentUserIsEditing Then
		Return;
	EndIf;
	
	ReleaseFile(CurrentData.Ref);
	NotifyChanged(CurrentData.Ref);
	SetButtonsEnabled();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Formatting of the file serving for editing by another user.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.FileEditedByAnotherUser");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	
	// Formatting of the file serving for editing by current user.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.FileCurrentUserIsEditing");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);
	
EndProcedure

&AtClient
Procedure OpenFile()
	
	If Not ValidateActionAllowed() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileIsEditing = CurrentData.FileIsEditing AND CurrentData.FileCurrentUserIsEditing;
	
	FileData = GetFileData(CurrentData.Ref, UUID);
	
	If FileData.Encrypted Then
		// File can be changed in another session.
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	AttachedFilesClient.OpenFile(FileData, FileIsEditing);
	
EndProcedure

&AtClient
Function ValidateActionAllowed(Val CurrentAction = "")
	
	If Items.List.CurrentData = Undefined Then
		Return False;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentAction = "DeletionMark" AND CurrentData.FileIsEditing Then
		
		If CurrentData.FileCurrentUserIsEditing Then
			WarningText = NStr("en = 'Action is unavailable because the file is locked for editing.'");
		Else
			WarningText = NStr("en = 'Action is unavailable because file
			                                 |is served for editing by another user.'");
		EndIf;
		
		ShowMessageBox(, WarningText);
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentRow) = CatalogWithFilesType Then
		Return True;
	Else
		ShowMessageBox(, NStr("en = 'Action is unavailable for the grouping row of the list.'"));
		Return False;
	EndIf;
	
	If Not Items.FormCopy.Visible
	 OR Not Items.FormCopy.Enabled Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Procedure HideButtonsOfAdding()
	
	Items.FormCreate.Visible = False;
	Items.ListContextMenuCreate.Visible = False;
	
	Items.FormCopy.Visible = False;
	Items.ListContextMenuCopy.Visible = False;
	
EndProcedure

&AtServer
Procedure HideButtonsChanges()
	
	CommandsNames = GetCommandsNamesChangesObjects();
	
	For Each FormItem IN Items Do
		
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetButtonsEnabled()
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		CommandsNames = New Array;
		CommandsNames.Add("Create");
		
	ElsIf TypeOf(Items.List.CurrentRow) <> CatalogWithFilesType Then
		CommandsNames = New Array;
	Else
		CommandsNames = GetAvailableCommands(
			CurrentData.FileIsEditing,
			CurrentData.FileCurrentUserIsEditing,
			CurrentData.DigitallySigned,
			CurrentData.Encrypted);
	EndIf;
	
	For Each FormItemName IN ButtonsFormElementsNames Do
		
		FormItem = Items.Find(FormItemName);
		
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			If Not FormItem.Enabled Then
				FormItem.Enabled = True;
			EndIf;
			
		ElsIf FormItem.Enabled Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetRefToBinaryData = True)
	
	Return AttachedFiles.GetFileData(
		AttachedFile, FormID, GetRefToBinaryData);
	
EndFunction

&AtServerNoContext
Procedure LockFileForEditingServer(Val AttachedFile)
	
	AttachedFilesService.LockFileForEditingServer(AttachedFile);
	
EndProcedure

&AtServerNoContext
Procedure ReleaseFile(Val AttachedFile)
	
	AttachedFilesService.ReleaseFile(AttachedFile);
	
EndProcedure

&AtServerNoContext
Procedure PlaceFileIntoStorageAndRelease(Val AttachedFile,
                                             Val InformationAboutFile)
	
	AttachedFilesService.PlaceFileIntoStorageAndRelease(
		AttachedFile, InformationAboutFile);
	
EndProcedure

&AtServerNoContext
Procedure SetDeletionFlagValue(Val AttachedFile, Val DeletionMark)
	
	AttachedFileObject = AttachedFile.GetObject();
	AttachedFileObject.DeletionMark = DeletionMark;
	AttachedFileObject.Write();
	
EndProcedure

&AtServer
Procedure ConfigureDynamicList(CatalogNameFilesStorage)
	
	QueryText = 
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.DeletionMark,
	|	CASE
	|		WHEN Files.DeletionMark = TRUE
	|			THEN Files.PictureIndex + 1
	|		ELSE Files.PictureIndex
	|	END AS PictureIndex,
	|	Files.Description AS Description,
	|	CAST(Files.Definition AS String(500)) AS Definition,
	|	Files.Author,
	|	Files.CreationDate,
	|	Files.Changed AS Edited,
	|	DATEADD(Files.ModificationDateUniversal, Second, &SecondsUntilLocalTime) AS ChangeDate,
	|	CAST(Files.Size / 1024 AS NUMBER(10, 0)) AS Size,
	|	Files.DigitallySigned,
	|	Files.Encrypted,
	|	CASE
	|		WHEN Files.DigitallySigned
	|				AND Files.Encrypted
	|			THEN 2
	|		WHEN Files.Encrypted
	|			THEN 1
	|		WHEN Files.DigitallySigned
	|			THEN 0
	|		ELSE -1
	|	END AS PictureNumberDigitallySignedEncrypted,
	|	CASE
	|		WHEN Not Files.IsEditing IN (&EmptyUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileIsEditing,
	|	CASE
	|		WHEN Files.IsEditing = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileCurrentUserIsEditing,
	|	CASE
	|		WHEN Not Files.IsEditing IN (&EmptyUsers)
	|				AND Files.IsEditing <> &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileEditedByAnotherUser,
	|	Files.IsEditing AS IsEditing
	|FROM
	|	&CatalogName AS Files
	|WHERE
	|	Files.FileOwner = &FilesOwner";
	
	ErrorTitle = NStr("en = 'Error when setting up the dynamic list of the attached files.'");
	EndErrors = NStr("en = 'In this case the dynamic list configuration is impossible.'");
	
	CatalogNameFilesStorage = AttachedFilesService.CatalogNameStorageFiles(
		Parameters.FileOwner, "", ErrorTitle, EndErrors);
	
	CatalogFullName = "Catalog." + CatalogNameFilesStorage;
	List.QueryText = StrReplace(QueryText, "&CatalogName", CatalogFullName);
	
	EmptyUsers = New Array;
	EmptyUsers.Add(Undefined);
	EmptyUsers.Add(Catalogs.Users.EmptyRef());
	EmptyUsers.Add(Catalogs.ExternalUsers.EmptyRef());
	
	List.Parameters.SetParameterValue("FilesOwner",      Parameters.FileOwner);
	List.Parameters.SetParameterValue("CurrentUser", Users.AuthorizedUser());
	List.Parameters.SetParameterValue("EmptyUsers",  EmptyUsers);
	List.Parameters.SetParameterValue("SecondsUntilLocalTime", '00010101'); // Installation on client
	List.MainTable = CatalogFullName;
	List.DynamicDataRead = True;
	
EndProcedure

&AtServerNoContext
Function AddRight(CatalogName, FileOwner)
	
	BeginTransaction();
	
	Try
		NewFile = Catalogs[CatalogName].CreateItem();
		NewFile.FileOwner = FileOwner;
		NewFile.Description = "DeleteFile";
		NewFile.Write();
		RollbackTransaction();
		Return True;
	Except
		RollbackTransaction();
		Return False;
	EndTry;
	
EndFunction

&AtClientAtServerNoContext
Function GetFormCommandsNames()
	
	CommandsNames = GetCommandsNamesChangesObjects();
	For Each CommandName IN GetObjectsBasicCommandsNames() Do
		CommandsNames.Add(CommandName);
	EndDo;
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetCommandsNamesChangesObjects()
	
	CommandsNames = New Array;
	
	// Commands that depend on object states.
	CommandsNames.Add("EndEdit");
	CommandsNames.Add("Release");
	CommandsNames.Add("Edit");
	CommandsNames.Add("SetDeletionMark");
	
	CommandsNames.Add("Sign");
	CommandsNames.Add("AddDSFromFile");
	CommandsNames.Add("SaveWithDS");
	
	CommandsNames.Add("Encrypt");
	CommandsNames.Add("Decrypt");
	
	CommandsNames.Add("UpdateFromFileOnDrive");
	
	// Commands that do not depend on object states.
	CommandsNames.Add("Create");
	CommandsNames.Add("OpenFileProperties");
	CommandsNames.Add("Copy");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetObjectsBasicCommandsNames()
	
	CommandsNames = New Array;
	
	// Simple commands available to any user who reads files.
	CommandsNames.Add("OpenFileDirectory");
	CommandsNames.Add("OpenFileForViewing");
	CommandsNames.Add("SaveAs");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetAvailableCommands(FileIsEditing,
                                 FileCurrentUserIsEditing,
                                 IsFileDigitallySigned,
                                 FileEncrypted)
	
	CommandsNames = GetFormCommandsNames();
	
	If FileIsEditing Then
		If FileCurrentUserIsEditing Then
			RemoveCommandFromArray(CommandsNames, "UpdateFromFileOnDrive");
		Else
			RemoveCommandFromArray(CommandsNames, "EndEdit");
			RemoveCommandFromArray(CommandsNames, "Release");
			RemoveCommandFromArray(CommandsNames, "Edit");
		EndIf;
		RemoveCommandFromArray(CommandsNames, "SetDeletionMark");
		
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
	Else
		RemoveCommandFromArray(CommandsNames, "Decrypt");
	EndIf;
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Procedure DeleteCommandsDS(CommandsNames)
	
	RemoveCommandFromArray(CommandsNames, "Sign");
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

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeSigningOrEncryptionUsageAtServer()
	
	FileFunctionsService.CryptographyOnCreateFormAtServer(ThisObject);
	
EndProcedure

// The Sign, AddFileDS procedure continuation.
&AtClient
Procedure AddingSignaturesComplete(Success, NotSpecified) Export
	
	If Success = True Then
		SetButtonsEnabled();
	EndIf;
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
