////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	UserID = Users.CurrentUser().ServiceUserID;
	DataArea = ServiceTechnologyIntegrationWithSSL.SessionSeparatorValue();
	
	CreateReference = Parameters.CreateReference;
	SupportRequestID = Parameters.SupportRequestID;
	
	FillContentWithTemplate();
	
	MaximalFileSize = InformationCenterServer.AttachmentsMaximumSizeForSendingMessageToServiceSupport();
	
	AddressForAnswer = InformationCenterServer.DefineUserEmailAddress();
	If IsBlankString(AddressForAnswer) Then 
		Items.ReplyTo.Visible = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetCursorInTextTemplate();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure DeleteFile(Item)
	
	ButtonName = Item.Name;
	DeleteFileServer(ButtonName);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Send(Command)
	
	If Items.ReplyTo.Visible Then 
		If IsBlankString(AddressForAnswer) Then 
			Raise NStr("en='You need to enter email address for an answer';ru='Необходимо ввести адрес электронной почты для ответа'");
		EndIf;
		If Not ParseStringWithPostalAddresses(AddressForAnswer) Then 
			Notification = New NotifyDescription("SendMessageToSupport", ThisForm);
			ShowQueryBox(Notification, NStr("en='The email address you have typed may be incorrect Send the email?';ru='Адрес электронной почты возможно введен неверно. Отправить сообщение?'"), QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndIf;
	
	SendMessageServer();
	ShowUserNotification(NStr("en='Message to support is sent.';ru='Сообщение в службу поддержки отправлено.'"));
	Notify("SendingMessageToSupportService");
	Close();
	
EndProcedure

&AtClient
Procedure AttachFile(Command)
	
#If WebClient Then
	NotifyDescription = New NotifyDescription("AttachFileAlert", ThisObject);
	BeginAttachingFileSystemExtension(NOTifyDescription);
#Else
	AddExternalFiles(True);
#EndIf
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure DeleteFileServer(ButtonNameDelete)
	
	Filter = New Structure("ButtonNameDelete", ButtonNameDelete);
	FoundStrings = SelectedFiles.FindRows(Filter);
	If FoundStrings.Count() = 0 Then 
		Return;
	EndIf;
	
	FoundString = FoundStrings.Get(0);
	NameIndex = GetFormItemIndex(ButtonNameDelete);
	DeleteAllSubordinateItems(NameIndex);
	DeleteFromTempStorage(FoundString.StorageAddress);
	
	IndexOf = SelectedFiles.IndexOf(FoundString);
	SelectedFiles.Delete(IndexOf);
	
EndProcedure

&AtClient
Procedure SendMessageToSupport(Result) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SendMessageServer();
	ShowUserNotification(NStr("en='Message to support is sent.';ru='Сообщение в службу поддержки отправлено.'"));
	Notify("SendingMessageToSupportService");
	Close();
	
EndProcedure

&AtServer
Procedure FillContentWithTemplate()
	
	Text = InformationCenterServer.TexttemplateToSupport();
	StringCursorPosition = NStr("en='CursorPosition';ru='ПозицияКурсора'");
	CursorPosition = Find(Text, StringCursorPosition)- 9;
	Text = StrReplace(Text, StringCursorPosition, "");
	Content.SetHTML(Text, New Structure);
	
EndProcedure

&AtServer
Procedure DeleteAllSubordinateItems(ItemIndex)
	
	ItemNotFound = Items.Find("FileGroup" + String(ItemIndex));
	If ItemNotFound <> Undefined Then 
		Items.Delete(ItemNotFound);
	EndIf;
	
	ItemNotFound = Items.Find("TextFileName" + String(ItemIndex));
	If ItemNotFound <> Undefined Then 
		Items.Delete(ItemNotFound);
	EndIf;
	
	ItemNotFound = Items.Find("DeleteFileButton" + String(ItemIndex));
	If ItemNotFound <> Undefined Then 
		Items.Delete(ItemNotFound);
	EndIf;
	
EndProcedure

&AtServer
Function GetFormItemIndex(ItemName)
	
	PositionBegin = StrLen("DeleteFileButton") + 1;
	Return Number(Mid(ItemName, PositionBegin));
	
EndFunction

&AtClient
Procedure AttachFileAlert(Attached, Context) Export
	
	AddExternalFiles(Attached);
	
EndProcedure

&AtClient
Procedure AddExternalFiles(ExtensionAttached)
	
	If ExtensionAttached Then 
		PlaceFilesWithExtension();
	Else
		PlaceFilesWithoutExtension();
	EndIf;
	
EndProcedure

&AtClient
Procedure PlaceFilesWithExtension()
	
	// Open the files selection dialog.
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Title = NStr("en='Select the file';ru='Выберите файл'");
	Dialog.Multiselect = False;
	
	NotifyDescription = New NotifyDescription("PutFileWithExtensionAlert", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure PutFileWithExtensionAlert(SelectedFiles, EndProcessor) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	FullFileName = SelectedFiles.Get(0);
	
	// Check if total files size is correct.
	File = New File(FullFileName);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FullFileName", FullFileName);
	
	NotifyDescription = New NotifyDescription("PutFileWithAlertExtensionSizeAlert", ThisObject, AdditionalParameters);
	File.BeginGettingSize(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure PutFileWithAlertExtensionSizeAlert(Size, AdditionalParameters) Export
	
	If Size = 0 Then 
		Return;
	EndIf;
	
	If Not TotalFilesSizeIsOptimal(Size) Then 
		WarningText = NStr("en='Unable to add file. Selected files size exceeds the limit in %1 MB';ru='Не удалось добавить файл. Размер выбранных файлов превышает предел в %1 Мб'");
		WarningText = StringFunctionsClientServer.PlaceParametersIntoString(WarningText, MaximalFileSize);
		ClearMessages();
		ShowMessageToUser(WarningText);
	EndIf;
	
	Status(NStr("en='File is added to a message.';ru='Файл добавляется к сообщению.'"));

	// Add files to table.
	AddFilesInSelectedFiles(AdditionalParameters.FullFileName);
	
	Status();
	
	CreateFormElementsForAttachedFile();
	
EndProcedure

&AtClient
Procedure PlaceFilesWithoutExtension()
	
	AfterPlacingFile = New NotifyDescription(
		"AfterPlacingFiles", ThisObject);
	
	BeginPutFile(
		AfterPlacingFile,
		,
		,
		True,
		UUID);
	
EndProcedure

&AtClient
Procedure AfterPlacingFiles(Result, StorageAddress, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		FileNameAndExtension = GetNameAndFileExtension(SelectedFileName);
		PlaceFilesWithoutExtensionAtServer(StorageAddress, FileNameAndExtension);
		
	EndIf;
	
EndProcedure

&AtClient
Function GetNameAndFileExtension(SelectedFileName)
	
	FileName = SelectedFileName;
	
	FileNameAndExtension = New Structure;
	FileNameAndExtension.Insert("Name", "");
	FileNameAndExtension.Insert("Extension", "");
	
	While Find(FileName, "/") <> 0 or
		Find(FileName, "\") <> 0 Do
		
		FileNamePosition = Find(SelectedFileName, "/");
		FileName = Mid(FileName, FileNamePosition + 1);
		
		FileNamePosition = Find(SelectedFileName, "\");
		FileName = Mid(FileName, FileNamePosition + 1);
		
	EndDo;
	
	FileExtensionPosition = Find(FileName, ".");
	If FileExtensionPosition = 0 Then 
		FileNameAndExtension.Insert("Name", FileName);
	Else
		Extension = Mid(FileName, FileExtensionPosition);
		FileNameAndExtension.Name = StrReplace(FileName, Extension, "");
		FileNameAndExtension.Extension = Extension;
	EndIf;
	
	Return FileNameAndExtension;
	
EndFunction

&AtServer
Procedure PlaceFilesWithoutExtensionAtServer(StorageAddress, FileNameAndExtension)
	
	NewFile = GetFromTempStorage(StorageAddress);
	
	// Check if total files size is correct.
	FileSize = NewFile.Size();
	If Not TotalFilesSizeIsOptimal(FileSize) Then 
		WarningText = NStr("en='Selected files size exceeds the limit in %1 MB';ru='Размер выбранных файлов превышает предел в %1 Мб'");
		WarningText = StringFunctionsClientServer.PlaceParametersIntoString(WarningText, MaximalFileSize);
		ShowMessageToUser(WarningText);
		DeleteFromTempStorage(StorageAddress);
		Return;
	EndIf;
	
	TableRow = SelectedFiles.Add();
	TableRow.FileName = FileNameAndExtension.Name;
	TableRow.Extension = FileNameAndExtension.Extension;
	TableRow.Size = FileSize;
	TableRow.StorageAddress = StorageAddress;
	
	CreateFormElementsForAttachedFile();
	
EndProcedure

&AtServer
Function TotalFilesSizeIsOptimal(FileSize)
	
	Size = FileSize / 1024;
	
	// Calculate the total size of files attached to email (with a set mark).
	For Iteration = 0 to SelectedFiles.Count() - 1 Do
		Size = Size + (SelectedFiles.Get(Iteration).Size / 1024);
	EndDo;
	
	SizeInMegabytes = Size / 1024;
	
	If SizeInMegabytes > MaximalFileSize Then 
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

&AtClient
Procedure AddFilesInSelectedFiles(FullFileName)
	
	NotifyDescription = New NotifyDescription(
		"AfterPlacingFiles", ThisObject);
		
	
	BeginPutFile(NOTifyDescription,
		Undefined,
		FullFileName,
		False,
		UUID);
	
EndProcedure

&AtServer
Procedure SendMessageServer()
	
	HTMLText = "";
	HTMLAttachments = New Structure;
	Content.GetHTML(HTMLText, HTMLAttachments);
	MessageText = Content.GetText();
	
	If IsBlankString(MessageText) Then 
		Raise NStr("en='Message body can not be empty.';ru='Текст сообщения не может быть пустым.'");
	EndIf;
	
	If IsBlankString(Subject) Then 
		MessageSubject = IdentifyTheme();
	Else
		MessageSubject = Subject;
	EndIf;
	
	Try
		
		WSProxy = InformationCenterServer.GetProxyServicesSupport();
		
		XDTOFilesList = GenerateXDTOFilesList(WSProxy.XDTOFactory);
		
		WSProxy.addComments(String(UserID), String(SupportRequestID), MessageSubject, HTMLText, CreateReference,  XDTOFilesList, DataArea, AddressForAnswer);
		
	Except
		
		ErrorText = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(InformationCenterServer.GetEventNameForEventLogMonitor(), 
		                         EventLogLevel.Error,
		                         ,
		                         ,
		                         ErrorText);
		OutputText = InformationCenterServer.ErrorInformationTextOutputInSupport();
		Raise OutputText;
		
	EndTry;
	
EndProcedure

&AtServer
Function IdentifyTheme()
	
	If Not IsBlankString(Subject) Then 
		Return Subject;
	EndIf;
	
	MessageText = Content.GetText();
	MessageText = StrReplace(MessageText, "Hello!", "");
	MessageText = Left(MessageText, 500);
	MessageText = StrReplace(MessageText, Chars.LF, " ");
	MessageText = StrReplace(MessageText, "  ", " ");
	
	Return TrimAll(MessageText);
	
EndFunction

&AtServer
Function GenerateXDTOFilesList(Factory)
	
	FilesListType = Factory.Type("http://www.1c.ru/1cFresh/InformationCenter/SupportServiceData/1.0.0.1", "ListFile");
	FileList = Factory.Create(FilesListType);
	
	For Each CurrentFile IN SelectedFiles Do 
		
		FileType = Factory.Type("http://www.1c.ru/1cFresh/InformationCenter/SupportServiceData/1.0.0.1", "File");
		FileObject = Factory.Create(FileType);
		FileObject.Name = CurrentFile.FileName;
		FileObject.Data = GetFromTempStorage(CurrentFile.StorageAddress);
		FileObject.Extension = CurrentFile.Extension;
		FileObject.Size = CurrentFile.Size;
		
		FileList.Files.Add(FileObject);
		
	EndDo;
	
	Return FileList;
	
EndFunction

&AtClient
Procedure SetCursorInTextTemplate()
	
	AttachIdleHandler("HandlerPlaceCursorInTextTemplate", 0.5, True);
	
EndProcedure

&AtClient
Procedure HandlerPlaceCursorInTextTemplate()
	
	CurrentItem = Items.Content;
	Bookmark = Content.GetPositionBookmark(CursorPosition);
	Items.Content.SetTextSelectionBounds(Bookmark, Bookmark);
	
EndProcedure

&AtServer
Function CreateFormElementsForAttachedFile()
	
	For Each SelectedFile IN SelectedFiles Do
		
		If Not IsBlankString(SelectedFile.ButtonNameDelete) Then 
			Continue;
		EndIf;
		
		FilePresentation = SelectedFile.FileName + SelectedFile.Extension + " (" + Round(SelectedFile.Size / 1024, 2) + NStr("en=' Kb';ru=' Кб'") +")";
		
		IndexOf = SelectedFile.GetID();
		
		FileGroup = Items.Add("FileGroup" + String(IndexOf), Type("FormGroup"), Items.AttachedFilesGroup);
		FileGroup.Type = FormGroupType.UsualGroup;
		FileGroup.ShowTitle = False;
		FileGroup.Group = ChildFormItemsGroup.Horizontal;
		FileGroup.Representation = UsualGroupRepresentation.None;
		
		TextFileName = Items.Add("TextFileName" + String(IndexOf), Type("FormDecoration"), FileGroup);
		TextFileName.Type = FormDecorationType.Label;
		TextFileName.Title = FilePresentation;
		
		DeleteFileButton = Items.Add("DeleteFileButton" + String(IndexOf), Type("FormDecoration"), FileGroup);
		DeleteFileButton.Type = FormDecorationType.Picture;
		DeleteFileButton.Picture = PictureLib.DeleteDirectly;
		DeleteFileButton.ToolTip = NStr("en='Delete file';ru='Удалить файл'");
		DeleteFileButton.Width = 2;
		DeleteFileButton.Height = 1;
		DeleteFileButton.PictureSize = PictureSize.Stretch;
		DeleteFileButton.Hyperlink = True;
		DeleteFileButton.SetAction("Click", "DeleteFile");
		
		SelectedFile.ButtonNameDelete = DeleteFileButton.Name;
		
	EndDo;
	
EndFunction

&AtServer
Function ShowMessageToUser(Text)
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.Message();
	
EndFunction

&AtServer
Function ParseStringWithPostalAddresses(AddressForAnswer)
	
	Return ServiceTechnologyIntegrationWithSSL.ParseStringWithPostalAddresses(AddressForAnswer, False);
	
EndFunction


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
