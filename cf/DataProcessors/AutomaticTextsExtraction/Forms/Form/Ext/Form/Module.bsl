
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Or CommonUseClientServer.IsLinuxClient() Then
		Return; // Fail is set in OnOpen().
	EndIf;
	
	TextExtractionEnabled = False;
	
	RunTimeInterval = CommonUse.CommonSettingsStorageImport("AutomaticTextsExtraction", "RunTimeInterval");
	If RunTimeInterval = 0 Then
		RunTimeInterval = 60;
		CommonUse.CommonSettingsStorageSave("AutomaticTextsExtraction", "RunTimeInterval",  RunTimeInterval);
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\OnDeterminingNumberOfVersionsWithNotImportedText");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingNumberOfVersionsWithNotImportedText(NumberOfFilesWithUnrecoveredText);
	EndDo;
	
	NumberOfFilesInBatches = CommonUse.CommonSettingsStorageImport("AutomaticTextsExtraction", "NumberOfFilesInBatches");
	If NumberOfFilesInBatches = 0 Then
		NumberOfFilesInBatches = 100;
		CommonUse.CommonSettingsStorageSave("AutomaticTextsExtraction", "NumberOfFilesInBatches",  NumberOfFilesInBatches);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClientServer.ThisIsWebClient() Then
		Cancel = True;
		ShowMessageBox(, NStr("en='Text extraction is not supported in the web client.';ru='Извлечение текстов не поддерживается в Веб-клиенте.'"));
		Return;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Cancel = True;
		MessageText = NStr("en='Text extraction is not supported in the client under Linux OS.';ru='Извлечение текстов не поддерживается в клиенте под управлением ОС Linux.'");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure RunTimeIntervalOnChange(Item)
	
	CommonUseServerCall.CommonSettingsStorageSave("AutomaticTextsExtraction", "RunTimeInterval",  RunTimeInterval);
	
	If TextExtractionEnabled Then
		DetachIdleHandler("CheckForClientEngine");
		// CurrentDate here isn't displayed and is not written to the
		// database and is used only on client for information purposes therefore it isn't necessary to replace with CurrentSessionDate.
		ExtractionStartForecastedTime = CurrentDate() + RunTimeInterval;
		AttachIdleHandler("CheckForClientEngine", RunTimeInterval);
		UpdateOfCountdown();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FilesCountInPortionOnChange(Item)
	CommonUseServerCall.CommonSettingsStorageSave("AutomaticTextsExtraction", "NumberOfFilesInBatches",  NumberOfFilesInBatches);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Start(Command)
	
	TextExtractionEnabled = True; 
	
	// CurrentDate here is not displayed and is not written to the
	// database and is used only on client for information purposes, therefore it is not necessary to replace it with CurrentSessionDate.
	ExtractionStartForecastedTime = CurrentDate();
	AttachIdleHandler("CheckForClientEngine", RunTimeInterval);
	
#If Not WebClient Then
	CheckForClientEngine();
#EndIf
	
	AttachIdleHandler("UpdateOfCountdown", 1);
	UpdateOfCountdown();
	
EndProcedure

&AtClient
Procedure Stop(Command)
	ExecuteStop();
EndProcedure

&AtClient
Procedure ExtractAll(Command)
	
	#If Not WebClient Then
		FilesCountWithUnextractedTextBeforeOperationStart = NumberOfFilesWithUnrecoveredText;
		Status = "";
		PortionSize = 0; // extract all
		ExtractionOfTextsClient(PortionSize);
		
		ShowMessageBox(, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Text extraction from
		|all files with not extract text is completed.
		|
		|Number of processed files: %1.';ru='Завершено извлечение текста из
		|всех файлов с неизвлеченным текстом.
		|
		|Обработано файлов: %1.'"),
			FilesCountWithUnextractedTextBeforeOperationStart));
	#EndIf
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure WriteLogEventServer(MessageText)
	
	WriteLogEvent(
		NStr("en='Files. Text extraction';ru='Файлы.Извлечение текста'",
		     CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Error,
		,
		,
		MessageText);
	
EndProcedure

&AtClient
Procedure UpdateOfCountdown()
	
	// CurrentDate here isn't displayed and is not written to the
	// database and is used only on client for information purposes therefore it isn't necessary to replace with CurrentSessionDate.
	Left = ExtractionStartForecastedTime - CurrentDate();
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Text extraction will start in %1 sec';ru='До начала извлечения текстов осталось %1 сек'"),
		Left);
	
	If Left <= 1 Then
		MessageText = "";
	EndIf;
	
	RunTimeInterval = Items.RunTimeInterval.EditText;
	Status = MessageText;
	
EndProcedure

&AtClient
Procedure CheckForClientEngine()
	
#If Not WebClient Then
	ExtractionOfTextsClient();
#EndIf

EndProcedure

#If Not WebClient Then
// Extracts text from files on disk on client.
&AtClient
Procedure ExtractionOfTextsClient(PortionSize = Undefined)
	
	// CurrentDate here is not displayed and is not written to the
	// database and is used only on client for information purposes, therefore it is not necessary to replace with CurrentSessionDate.
	ExtractionStartForecastedTime = CurrentDate() + RunTimeInterval;
	
	Status(NStr("en='Extracting text started';ru='Начато извлечение текста'"));
	
	Try
		
		PortionSizeCurrent = NumberOfFilesInBatches;
		If PortionSize <> Undefined Then
			PortionSizeCurrent = PortionSize;
		EndIf;
		FilesArray = GetFilesForTextExtraction(PortionSizeCurrent);
		
		If FilesArray.Count() = 0 Then
			Status(NStr("en='No file to extract the text from!';ru='Нет файлов для извлечения текста'"));
			Return;
		EndIf; 
		
		For IndexOf = 0 To FilesArray.Count() - 1 Do
			
			Extension = FilesArray[IndexOf].Extension;
			FileDescription = FilesArray[IndexOf].Description;
			FileOrFileVersion = FilesArray[IndexOf].Ref;
			Encoding = FilesArray[IndexOf].Encoding;
			
			Try
				FileURL = GetURLOfFile(
					FileOrFileVersion, UUID);
				
				NameWithExtension = CommonUseClientServer.GetNameWithExtention(
					FileDescription, Extension);
				
				Progress = IndexOf * 100 / FilesArray.Count();
				Status(NStr("en='Extracting text from file';ru='Идет извлечение текста файла'"), Progress, NameWithExtension);
				
				FileFunctionsServiceClient.ExtractVersionText(
					FileOrFileVersion, FileURL, Extension, UUID, Encoding);
			
			Except
				
				ErrorDescriptionInfo = BriefErrorDescription(ErrorInfo());
				
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='An unknown error occurred while
		|extracting text from  file ""%1""';ru='Во время извлечения текста из файла ""%1"" произошла неизвестная ошибка'"),
					String(FileOrFileVersion));
				
				MessageText = MessageText + String(ErrorDescriptionInfo);
				
				Status(MessageText);
				
				ExtractionResult = "ExtractFailed";
				WriteErrorsExtracting(FileOrFileVersion, ExtractionResult, MessageText);
				
			EndTry;
			
		EndDo;
		
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Text extraction is completed.
		|Number of processed files: %1';ru='Извлечение текста завершено.
		|Обработано файлов: %1'"),
			FilesArray.Count());
		
		Status(MessageText);
		
	Except
		
		ErrorDescriptionInfo = BriefErrorDescription(ErrorInfo());
		
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An unknown error occurred while
		|extracting text from  file ""%1""';ru='Во время извлечения текста из файла ""%1"" произошла неизвестная ошибка'"),
			String(FileOrFileVersion));
		
		MessageText = MessageText + String(ErrorDescriptionInfo);
		
		Status(MessageText);
		
		WriteLogEventServer(MessageText);
		
	EndTry;
	
	GetVersionsNumberWithNotExtractedText(NumberOfFilesWithUnrecoveredText);
	
EndProcedure
#EndIf

&AtServerNoContext
Procedure WriteErrorsExtracting(FileOrFileVersion, ExtractionResult, MessageText)
	
	SetPrivilegedMode(True);
	
	FileFunctionsService.WriteTextExtractionResult(FileOrFileVersion, ExtractionResult, "");
	
	// Record in the event log.
	WriteLogEventServer(MessageText);
	
EndProcedure

&AtServerNoContext
Function GetFilesForTextExtraction(NumberOfFilesInBatches)
	
	Result = New Array;
	
	Query = New Query;
	GetAllFiles = (NumberOfFilesInBatches = 0);
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\WhenDefiningTextQueryForTextRetrieval");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenDefiningTextQueryForTextRetrieval(Query.Text, GetAllFiles);
	EndDo;
	
	For Each String IN Query.Execute().Unload() Do
		
		Encoding = FileFunctionsService.GetFileVersionEncoding(String.Ref);
		
		Result.Add(New Structure("Ref, Extension, Description, Encoding",
			String.Ref, String.Extension, String.Description, Encoding));
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetURLOfFile(Val FileOrFileVersion, Val UUID)
	
	URLFile = Undefined;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\WhenDefiningNavigationLinksFile");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenDefiningNavigationLinksFile(
			FileOrFileVersion, UUID, URLFile);
	EndDo;
	
	Return URLFile;
	
EndFunction

&AtServerNoContext
Procedure GetVersionsNumberWithNotExtractedText(NumberOfFilesWithUnrecoveredText)
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\OnDeterminingNumberOfVersionsWithNotImportedText");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingNumberOfVersionsWithNotImportedText(
			NumberOfFilesWithUnrecoveredText);
	EndDo;
	
EndProcedure

&AtClient
Procedure ExecuteStop()
	DetachIdleHandler("CheckForClientEngine");
	DetachIdleHandler("UpdateOfCountdown");
	Status = "";
	TextExtractionEnabled = False;
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
