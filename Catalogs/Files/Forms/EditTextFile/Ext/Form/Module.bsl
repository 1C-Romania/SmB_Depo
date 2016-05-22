
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	File = Parameters.File;
	FileData = Parameters.FileData;
	FileNameToOpen = Parameters.FileNameToOpen;
	
	FileCode = File.Code;
	
	If FileData.CurrentUserIsEditing Then
		EditMode = True;
	EndIf;
	
	If FileData.Version <> FileData.CurrentVersion Then
		EditMode = False;
	EndIf;
	
	Items.Text.ReadOnly = Not EditMode;
	Items.ShowDifference.Visible = Not CommonUseClientServer.IsLinuxClient();
	Items.ShowDifference.Enabled = EditMode;
	Items.Edit.Enabled = Not EditMode;
	Items.EndEdit.Enabled = EditMode;
	Items.WriteAndClose.Enabled = EditMode;
	Items.Write.Enabled = EditMode;
	
	If FileData.Version <> FileData.CurrentVersion Then
		Items.Edit.Enabled = False;
	EndIf;
	
	TitleString = CommonUseClientServer.GetNameWithExtention(
		FileData.FullDescrOfVersion, FileData.Extension);
	
	If Not EditMode Then
		TitleString = TitleString + NStr("en=' (read only)'");
	EndIf;
	Title = TitleString;
	
	If ValueIsFilled(FileData.Version) Then
		FileTextEncoding = FileOperationsServiceServerCall.GetFileVersionEncoding(
			FileData.Version);
		
		If ValueIsFilled(FileTextEncoding) Then
			EncodingsList = FileOperationsService.GetEncodingsList();
			ItemOfList = EncodingsList.FindByValue(FileTextEncoding);
			If ItemOfList = Undefined Then
				EncodingPresentation = FileTextEncoding;
			Else
				EncodingPresentation = ItemOfList.Presentation;
			EndIf;
		Else
			EncodingPresentation = NStr("en='By default'");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UniqueKey = FileCode;
	
	TextEncodingForReading = FileTextEncoding;
	If Not ValueIsFilled(TextEncodingForReading) Then
		TextEncodingForReading = Undefined;
	EndIf;
	
	Text.Read(FileNameToOpen, TextEncodingForReading);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_File" AND Parameter.Event = "FileEdited" AND Source = File Then
		EditMode = True;
		SetCommandsEnabled();
	EndIf;
	
	If EventName = "Record_File" AND Parameter.Event = "FileDataChanged" AND Source = File Then
		
		FileData = FileOperationsServiceServerCall.FileData(File);
		
		EditMode = False;
		
		If FileData.CurrentUserIsEditing Then
			EditMode = True;
		EndIf;
		
		If FileData.Version <> FileData.CurrentVersion Then
			EditMode = False;
		EndIf;
		
		SetCommandsEnabled();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Modified Then
		Cancel = True;
		NameAndExtension = CommonUseClientServer.GetNameWithExtention(
			FileData.FullDescrOfVersion,
			FileData.Extension);
		QuestionText = StrReplace(NStr("en ='File ""%1"" was modified.'"), "%1", NameAndExtension);
		FormParameters = New Structure;
		FormParameters.Insert("QuestionText", QuestionText);
		Handler = New NotifyDescription("BeforeCloseAfterAnsweringOnQuestionOnExitFromTextEditor", ThisObject);
		OpenForm("Catalog.Files.Form.QuestionOnExitFromTextEditor", FormParameters, ThisObject, , , , Handler);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveAs(Command)
	
	// Select path to file on disk.
	FileChoice = New FileDialog(FileDialogMode.Save);
	FileChoice.Multiselect = False;
	
	NameWithExtension = CommonUseClientServer.GetNameWithExtention(
		FileData.FullDescrOfVersion, FileData.Extension);
	
	FileChoice.FullFileName = NameWithExtension;
	Filter = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en = 'All files (*.%1)|*.%1'"), FileData.Extension, FileData.Extension);
	FileChoice.Filter = Filter;
	
	If FileChoice.Choose() Then
		
		SelectedFullFileName = FileChoice.FullFileName;
		
		TextEncodingForWrite = FileTextEncoding;
		If Not ValueIsFilled(TextEncodingForWrite) Then
			TextEncodingForWrite = Undefined;
		EndIf;
		
		Text.Write(SelectedFullFileName, TextEncodingForWrite);
		
		Status(NStr("en = 'The file was successfully saved'"), , SelectedFullFileName);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	
	ShowValue(, File);
	
EndProcedure

&AtClient
Procedure ExternalEditor(Command)
	
	WriteText();
	FileOperationsServiceClient.RunApplicationStart(FileNameToOpen);
	Close();
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	FileOperationsServiceClient.EditWithAlert(Undefined, File, UUID);
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	WriteText();
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	WriteText();
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Script", 1);
	Handler = New NotifyDescription("FinishEditEnd", ThisObject, HandlerParameters);
	
	FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Handler, File, UUID);
	FileUpdateParameters.Encoding = FileTextEncoding;
	FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure ShowDifference(Command)
	#If WebClient Then
		ShowMessageBox(, NStr("en = 'Version comparing is not supported in the web client'"));
	#Else
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("CurrentStep", 1);
		ExecuteParameters.Insert("FileVersionComparisonMethod", Undefined);
		ExecuteParameters.Insert("FullFileNameLeft", GetTempFileName(FileData.Extension));
		VersionsComparisonAutomatic(-1, ExecuteParameters);
	#EndIf
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	If Modified Then
		WriteText();
		
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Script", 2);
		Handler = New NotifyDescription("FinishEditEnd", ThisObject, HandlerParameters);
		
		FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Handler, File, UUID);
		FileUpdateParameters.Encoding = FileTextEncoding;
		FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
		
		Return;
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	Handler = New NotifyDescription("SelectEncodingEnd", ThisObject);
	OpenForm("Catalog.Files.Form.EncodingChoice", FormParameters, ThisObject, , , , Handler);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure BeforeCloseAfterAnsweringOnQuestionOnExitFromTextEditor(Result, ExecuteParameters) Export
	
	If Result = "SaveAndEndEditing" Then
		
		WriteText();
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Script", 3);
		Handler = New NotifyDescription("FinishEditEnd", ThisObject, HandlerParameters);
		FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Handler, File, UUID);
		FileUpdateParameters.Encoding = FileTextEncoding;
		FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
		
	ElsIf Result = "SaveChanges" Then
		
		WriteText();
		Modified = False;
		Close();
		
	ElsIf Result = "DontSave" Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectEncodingEnd(Result, ExecuteParameters) Export
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	FileTextEncoding = Result.Value;
	EncodingPresentation = Result.Presentation;
	
	ReadText();
	
	FileOperationsServiceServerCall.WriteFileVersionEncodingAndExtractedText(
		FileData.Version,
		FileTextEncoding,
		Text.GetText());
EndProcedure

&AtClient
Procedure FinishEditEnd(Result, ExecuteParameters) Export
	If ExecuteParameters.Script = 1 Then
		EditMode = False;
		SetCommandsEnabled();
	ElsIf ExecuteParameters.Script = 2 Then
		EditMode = False;
		SetCommandsEnabled();
		Close();
	ElsIf ExecuteParameters.Script = 3 Then
		Modified = False;
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure WriteText()
	
	If Modified Then
		
		TextEncodingForWrite = FileTextEncoding;
		If Not ValueIsFilled(TextEncodingForWrite) Then
			TextEncodingForWrite = Undefined;
		EndIf;
		
		Text.Write(FileNameToOpen, TextEncodingForWrite);
		Modified = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCommandsEnabled()
	
	Items.Text.ReadOnly = Not EditMode;
	Items.ShowDifference.Enabled = EditMode;
	Items.Edit.Enabled = Not EditMode;
	Items.EndEdit.Enabled = EditMode;
	Items.WriteAndClose.Enabled = EditMode;
	Items.Write.Enabled = EditMode;
	
	TitleString = CommonUseClientServer.GetNameWithExtention(
		FileData.FullDescrOfVersion, FileData.Extension);
	
	If Not EditMode Then
		TitleString = TitleString + NStr("en=' (read only)'");
	EndIf;
	Title = TitleString;
	
EndProcedure

&AtClient
Procedure ReadText()
	
	Text.Read(FileNameToOpen, FileTextEncoding);
	
EndProcedure

&AtClient
Procedure VersionsComparisonAutomatic(Result, ExecuteParameters) Export
	If ExecuteParameters.CurrentStep = 1 Then
		PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
		ExecuteParameters.FileVersionComparisonMethod = PersonalSettings.FileVersionComparisonMethod;
		// First call - the setup is not initialized yet.
		If ExecuteParameters.FileVersionComparisonMethod = Undefined Then
			Handler = New NotifyDescription("VersionsComparisonAutomatic", ThisObject, ExecuteParameters);
			OpenForm("Catalog.FileVersions.Form.SelectionOfVersionsComparisonMethod", , ThisObject, , , , Handler);
			ExecuteParameters.CurrentStep = 1.1;
			Return;
		EndIf;
		ExecuteParameters.CurrentStep = 2;
	ElsIf ExecuteParameters.CurrentStep = 1.1 Then
		If Result <> DialogReturnCode.OK Then
			Return;
		EndIf;
		PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
		ExecuteParameters.FileVersionComparisonMethod = PersonalSettings.FileVersionComparisonMethod;
		If ExecuteParameters.FileVersionComparisonMethod = Undefined Then
			Return;
		EndIf;
		ExecuteParameters.CurrentStep = 2;
	EndIf;
	
	If ExecuteParameters.CurrentStep = 2 Then
		// Saving file for right section.
		WriteText(); // Full name is placed in the attribute OpenedFileName.
		
		// Saving file for left section.
		If FileData.CurrentVersion = FileData.Version Then
			FileDataLeft = FileOperationsServiceServerCall.FileDataForSave(File, UUID);
			FileURLLeft = FileDataLeft.CurrentVersionURL;
		Else
			FileURLLeft = FileOperationsServiceServerCall.GetURLForOpening(
				FileData.Version,
				UUID);
		EndIf;
		FilesToTransfer = New Array;
		FilesToTransfer.Add(New TransferableFileDescription(ExecuteParameters.FullFileNameLeft, FileURLLeft));
		If Not GetFiles(FilesToTransfer,, ExecuteParameters.FullFileNameLeft, False) Then
			Return;
		EndIf;
		
		// Comparison.
		FileOperationsServiceClient.CompareFiles(
			ExecuteParameters.FullFileNameLeft,
			FileNameToOpen,
			ExecuteParameters.FileVersionComparisonMethod);
	EndIf;
EndProcedure

#EndRegion
