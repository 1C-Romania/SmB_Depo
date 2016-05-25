////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("FromWhom") Then 
		FromWhom = Parameters.FromWhom;
	EndIf;
	
	If Parameters.Property("Text") Then 
		Text = Parameters.Text;
		StringCursorPosition = NStr("en = 'CursorPosition'");
		CursorRow = DeterminePositionNumberForCursor(Text, StringCursorPosition) - 9;
		Text = StrReplace(Text, StringCursorPosition, "");
		Content.SetHTML(Text, New Structure);
	EndIf;
	
	If Parameters.Property("Attachments") Then 
		If TypeOf(Parameters.Attachments) = Type("ValueList") Then 
			For Each ListRow in Parameters.Attachments Do 
				Attachments.Add(ListRow.Value, ListRow.Presentation);
			EndDo;
		EndIf;
	EndIf;
	
	If Parameters.Property("ShowTheme") Then 
		Items.Subject.Visible = Parameters.ShowTheme;
	EndIf;
	
	TechnicalParametersFileName = InformationCenterServer.GetTechnicalParametersFileNameForInformToSupport();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	MaximalFileSize = InformationCenterClient.AttachmentsMaximumSizeForSendingMessageToServiceSupport();;
	
	SetCursorInTextTemplate();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure AttachFile(Item)
	
#If WebClient Then
	NotifyDescription = New NotifyDescription("AttachFileAlert", ThisObject);
	BeginAttachingFileSystemExtension(NOTifyDescription);
#Else
	AddExternalFiles(True);
#EndIf
	
EndProcedure

&AtClient
Procedure DeleteFile(Item)
	
	For Iteration = 0 to SelectedFiles.Count() - 1 Do 
		
		If SelectedFiles.Get(Iteration).ButtonNameDelete = Item.Name Then 
			NameIndex = GetFormItemIndex(Item.Name);
			DeleteAllSubordinateItems(NameIndex);
			DeleteFromTempStorage(SelectedFiles.Get(Iteration).StorageAddress);
			ItemOfList = Attachments.FindByID(SelectedFiles.Get(Iteration).IdentifierInValuesList);
			If ItemOfList <> Undefined Then 
				Attachments.Delete(ItemOfList);
			EndIf;
			SelectedFiles.Get(Iteration).Size = 0;
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Send(Command)
	
	If Not CheckAttributesFilling() Then 
		Return;
	EndIf;
	
	SendingResult = SendMessageServer();
	If SendingResult Then 
		ShowUserNotification(NStr("en = 'Message is sent.'"));
		Close();
	Else
		ClearMessages();
		ShowMessageToUser(NStr("en = 'Sorry, your message was not sent.
			|Repeat attempt later.'"));
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

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

&AtClient
Function GetFormItemIndex(ItemName)
	
	PositionBegin = StrLen("DeleteFileButton") + 1;
	Return Number(Mid(ItemName, PositionBegin));
	
EndFunction

&AtClient
Function CheckAttributesFilling()
	
	If ValueIsFilled(FromWhom) Then
		Try
			CommonUseClientServer.ParseStringWithPostalAddresses(FromWhom);
			Return True;
		Except
			CommonUseClientServer.MessageToUser(
					BriefErrorDescription(ErrorInfo()), ,
					"FromWhom");
			Return False;
		EndTry;
	Else 
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The Response address is not filled in'"), ,
			"FromWhom");
	EndIf;
	
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
	Dialog.Title = NStr("en = 'Select the file'");
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
		WarningText = NStr("en = 'Unable to add file. Selected files size exceeds the limit in %1 MB'");
		WarningText = StringFunctionsClientServer.PlaceParametersIntoString(WarningText, MaximalFileSize);
		ClearMessages();
		ShowMessageToUser(WarningText);
	EndIf;
	
	Status(NStr("en = 'File is added to a message.'"));

	// Add files to table.
	AddFilesInSelectedFiles(AdditionalParameters.FullFileName);
	
	Status();
	
	CreateFormElementsForAttachedFile();
	
EndProcedure

&AtClient
Procedure PlaceFilesWithoutExtension()
	
	AfterPlacingFilesWithoutExtension = New NotifyDescription(
		"AfterPlacingFilesWithoutExtension", ThisObject);
	
	BeginPutFile(
		AfterPlacingFilesWithoutExtension,
		,
		,
		True,
		UUID);
	
EndProcedure

&AtClient
Procedure AfterPlacingFilesWithoutExtension(Result, StorageAddress, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		FileName = GetFileName(SelectedFileName);
		PlaceFilesWithoutExtensionAtServer(StorageAddress, FileName);
		
	EndIf;
	
EndProcedure

&AtClient
Function GetFileName(SelectedFileName)
	
	FileName = SelectedFileName;
	
	While Find(FileName, "/") <> 0 or
		Find(FileName, "\") <> 0 Do
		
		ItemPosition = Find(SelectedFileName, "/");
		FileName = Mid(FileName, ItemPosition + 1);
		
		ItemPosition = Find(SelectedFileName, "\");
		FileName = Mid(FileName, ItemPosition + 1);
		
	EndDo;
	
	Return FileName;
	
EndFunction

&AtServer
Procedure PlaceFilesWithoutExtensionAtServer(StorageAddress, FileName)
	
	NewFile = GetFromTempStorage(StorageAddress);
	
	// Check if total files size is correct.
	FileSize = NewFile.Size();
	If Not TotalFilesSizeIsOptimal(FileSize) Then 
		WarningText = NStr("en = 'Selected files size exceeds the limit in %1 MB'");
		WarningText = StringFunctionsClientServer.PlaceParametersIntoString(WarningText, MaximalFileSize);
		ShowMessageToUser(WarningText);
		DeleteFromTempStorage(StorageAddress);
		Return;
	EndIf;
	
	TableRow = SelectedFiles.Add();
	TableRow.FileName = FileName;
	TableRow.Size = FileSize/1024;
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
	
	SelectedFile = New File(FullFileName);
	
	AfterPlacingFile = New NotifyDescription(
		"AfterPlacingFiles", ThisObject);
	
	BeginPutFile(
		AfterPlacingFile, 
		Undefined,
		FullFileName,
		False,
		UUID);
	
EndProcedure

&AtClient
Procedure AfterPlacingFiles(Result, StorageAddress, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		FileName = GetFileName(SelectedFileName);
		PlaceFilesWithoutExtensionAtServer(StorageAddress, FileName);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AddFilesToListOfSent()
	
	For Each CurrentFile in SelectedFiles Do 
		
		If CurrentFile.IdentifierInValuesList <> 0 Then 
			Continue;
		EndIf;
		
		FileName = CurrentFile.FileName;
		StorageAddress = CurrentFile.StorageAddress;
		NewFileAttachments = Attachments.Add(GetFromTempStorage(StorageAddress), FileName);
		CurrentFile.IdentifierInValuesList = NewFileAttachments.GetID();
		
	EndDo;
	
EndProcedure

&AtServer
Function SendMessageServer()
	
	Text = "";
	HTMLAttachments = Undefined;
	Content.GetHTML(Text, HTMLAttachments);
	
	MessageParameters = New Structure();
	MessageParameters.Insert("FromWhom",    FromWhom);
	MessageParameters.Insert("Subject",      IdentifyTheme());
	MessageParameters.Insert("Text",     Text);
	MessageParameters.Insert("Attachments",  Attachments);
	MessageParameters.Insert("TextType", "HTML");
	
	Result = True;
	InformationCenterServer.OnMessageSendingUserTechnicalSupport(MessageParameters, Result);
	
	Return Result;
	
EndFunction

&AtServer
Function IdentifyTheme()
	
	If Not IsBlankString(Subject) Then 
		Return Subject;
	EndIf;
	
	MessageText = Content.GetText();
	MessageText = StrReplace(MessageText, "Hello!", "");
	
	Return TrimAll(MessageText);
	
EndFunction

&AtClient
Procedure SetCursorInTextTemplate()
	
	AttachIdleHandler("HandlerPlaceCursorInTextTemplate", 0.5, True);
	
EndProcedure

&AtServer
Function DeterminePositionNumberForCursor(TextParameter, StringCursorPosition)
	
	Return Find(TextParameter, StringCursorPosition);
	
EndFunction

&AtClient
Procedure HandlerPlaceCursorInTextTemplate()
	
	CurrentItem = Items.Content;
	Bookmark = Content.GetPositionBookmark(CursorRow);
	Items.Content.SetTextSelectionBounds(Bookmark, Bookmark);
	
EndProcedure

&AtServer
Function CreateFormElementsForAttachedFile()
	
	For Iteration = 0 to SelectedFiles.Count() - 1 Do
		
		If Not IsBlankString(SelectedFiles.Get(Iteration).ButtonNameDelete) Then 
			Continue;
		EndIf;
		
		FileGroup							= Items.Add("FileGroup" + String(Iteration), Type("FormGroup"), Items.AttachedFilesGroup);
		FileGroup.Type						= FormGroupType.UsualGroup;
		FileGroup.ShowTitle		= False;
		FileGroup.Group				= ChildFormItemsGroup.Horizontal;
		FileGroup.Representation				= UsualGroupRepresentation.None;
		
		TextFileName						= Items.Add("TextFileName" + String(Iteration), Type("FormDecoration"), FileGroup);
		TextFileName.Type					= FormDecorationType.Label;
		TextFileName.Title			= SelectedFiles.Get(Iteration).FileName + " (" + SelectedFiles.Get(Iteration).Size + " Kb)";
		
		DeleteFileButton					= Items.Add("DeleteFileButton" + String(Iteration), Type("FormDecoration"), FileGroup);
		DeleteFileButton.Type				= FormDecorationType.Picture;
		DeleteFileButton.Picture		= PictureLib.DeleteDirectly;
		DeleteFileButton.ToolTip		= NStr("en = 'Delete file'");
		DeleteFileButton.Width			= 2;
		DeleteFileButton.Height			= 1;
		DeleteFileButton.PictureSize	= PictureSize.Stretch;
		DeleteFileButton.Hyperlink		= True;
		DeleteFileButton.SetAction("Click", "DeleteFile");
		
		SelectedFiles.Get(Iteration).ButtonNameDelete = DeleteFileButton.Name;
		
	EndDo;
	
	// Handler of the file add waiting is enabled.
	AddFilesToListOfSent();
	
EndFunction

&AtServer
Function ShowMessageToUser(Text)
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.Message();
	
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
