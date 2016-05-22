
&AtServer
Procedure ImportAtServer(TemporaryStorageAddress)
	
	BinaryData = GetFromTempStorage(TemporaryStorageAddress);
	// get temporary attachment file name in the local FILESYSTEM at server
	TempFileName = GetTempFileName("xml");
	// get rule file for reading
	BinaryData.Write(TempFileName);
	BinaryData = Undefined;
	
	UUID_        = New UUID();
	TemporaryFileNameOfExchangeProtocol = TempFilesDir() + UUID_ + ".txt";
	
	UOD = DataProcessors.UniversalXMLDataExchange.Create();
	UOD.ExchangeFileName                        = TempFileName;
	UOD.ExchangeMode                            = "Import";
	UOD.RememberImportedObjects                 = False;
	UOD.ErrorMessagesOutputToLog                = True;
	UOD.OutputInInformationMessagesToProtocol   = False;
	UOD.ExchangeProtocolFileName                = TemporaryFileNameOfExchangeProtocol;
	
	UOD.ImportDataInExchangeMode               = True;
	UOD.ImportObjectsByRefWithoutDeletionMark  = True;
	UOD.OptimizedObjectWriting                 = True;
	UOD.RememberImportedObjects                = True;
	UOD.ThisIsInteractiveMode                  = True;
	
	UOD.HandlersDebugModeFlag = True;
	UOD.EventHandlersExternalDataProcessorFileName = "ImportHandlersFromTradeManagement103";
	
	SetPrivilegedMode(True);
	UOD.RunImport();
	SetPrivilegedMode(False);
	
	ExchangeLog = New TextDocument;
	ExchangeLog.Read(TemporaryFileNameOfExchangeProtocol);
	
	Try
		DeleteFiles(TemporaryFileNameOfExchangeProtocol);  // Delete the temporary rule file
	Except
	EndTry;
	
	Items.ExchangeLog.Visible = True;
	
EndProcedure

&AtClient
Procedure Import(Command)
	
	Try
		NotifyDescription = New NotifyDescription("ImportEnd", ThisObject);
		
		If Not FileOperationsExtensionConnected Then
			BeginPutFile(NOTifyDescription, TemporaryStorageAddress, "*.xml",, UUID); 
		Else
			BeginPutFile(NOTifyDescription, TemporaryStorageAddress, ExchangeFileName, False, UUID) 
		EndIf;
	Except
		Message = New UserMessage;
		Message.Text = NStr("en = 'Error at data import.'");
		Message.Message();
	EndTry;
	
EndProcedure

&AtClient
Procedure ImportEnd(Result, Address, SelectedFileName, AdditionalParameters) Export

	If Result Then
		
		TemporaryStorageAddress = Address;
		
		ClearMessages();
		ExchangeLog.Clear();
		
		Status(NStr("en = 'Importing data...'"),, NStr("en = 'Importing data from TM 10.3'"));
		ImportAtServer(TemporaryStorageAddress);
		
		RefreshInterface();
		StandardSubsystemsClient.SetAdvancedApplicationCaption();
		
		ShowUserNotification(NStr("en = 'Export complete'"),,, PictureLib.Information32);
		
	EndIf;

EndProcedure

&AtClient
Procedure ExchangeFilenameStartChoice(Item, ChoiceData, StandardProcessing)
	
	ExchangeFileName = Item.EditText;
	
	If FileOperationsExtensionConnected Then
		FileOpeningDialog = New FileDialog(FileDialogMode.Open);
		FileOpeningDialog.Filter             = "Export file (*.xml)|*.xml";
		FileOpeningDialog.Multiselect = False;
		FileOpeningDialog.Title = NStr("en = 'Select path to the file dump data form TM 10.3'");
		FileOpeningDialog.Directory = ExchangeFileName;
		FileOpeningDialog.Show(New NotifyDescription("ExchangeFileNameStartChoiceEnd", ThisObject, New Structure("FileDialog", FileOpeningDialog)));
	Else
		ShowMessageBox(Undefined,NStr("en = 'Extension for work with files is not installed.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameStartChoiceEnd(SelectedFiles, AdditionalParameters) Export
    
    FileOpeningDialog= AdditionalParameters.FileOpeningDialog;
    
    If (SelectedFiles <> Undefined) Then
        ExchangeFileName = FileOpeningDialog.FullFileName;
    EndIf;

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	BeginAttachingFileSystemExtension(New NotifyDescription("OnOpenEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure OnOpenEnd(Attached, AdditionalParameters) Export
	
	FileOperationsExtensionConnected = Attached;
	If Not FileOperationsExtensionConnected Then
		Items.ExchangeFileName.Visible = False;
		Items.WarningImport.Visible = True;
	Else
		Items.ExchangeFileName.Visible = True;
		Items.WarningImport.Visible = False;
	EndIf;

EndProcedure





