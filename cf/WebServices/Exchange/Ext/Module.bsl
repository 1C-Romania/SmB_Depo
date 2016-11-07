
#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Operation handlers

// Corresponds to operation Import.
Function RunExport(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessageStorage)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	ExchangeMessage = "";
	
	DataExchangeServer.ExportForInfobaseNodeViaString(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessage);
	
	ExchangeMessageStorage = New ValueStorage(ExchangeMessage, New Deflation(9));
	
EndFunction

// Corresponds to operation Export.
Function RunImport(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessageStorage)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.ImportForInfobaseNodeViaString(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessageStorage.Get());
	
EndFunction

// Corresponds to operation ImportData.
Function ExecuteDataExport(ExchangePlanName,
								CodeOfInfobaseNode,
								FileIDString,
								LongOperation,
								ActionID,
								LongOperationAllowed)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID;
	FileIDString = String(FileID);
	
	If CommonUse.FileInfobase() Then
		
		DataExchangeServer.ExportToFileTransferServiceForInfobaseNode(ExchangePlanName, CodeOfInfobaseNode, FileID);
		
	Else
		
		ExecuteDataExportInClientServerMode(ExchangePlanName, CodeOfInfobaseNode, FileID, LongOperation, ActionID, LongOperationAllowed);
		
	EndIf;
	
EndFunction

// Corresponds to operation DataExport.
Function ExecuteDataImport(ExchangePlanName,
								CodeOfInfobaseNode,
								FileIDString,
								LongOperation,
								ActionID,
								LongOperationAllowed)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID(FileIDString);
	
	If CommonUse.FileInfobase() Then
		
		DataExchangeServer.ImportForInfobaseNodeFromFileTransferService(ExchangePlanName, CodeOfInfobaseNode, FileID);
		
	Else
		
		ImportDataInClientServerMode(ExchangePlanName, CodeOfInfobaseNode, FileID, LongOperation, ActionID, LongOperationAllowed);
		
	EndIf;
	
EndFunction

// Corresponds to operation GetIBParameters.
Function GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorInfo)
	
	Return DataExchangeServer.GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorInfo);
	
EndFunction

// Corresponds to operation GetIBData.
Function GetInfobaseData(FullTableName)
	
	Result = New Structure("MetadataObjectProperties, CorrespondentBaseTable");
	
	Result.MetadataObjectProperties = ValueToStringInternal(DataExchangeServer.MetadataObjectProperties(FullTableName));
	Result.CorrespondentInfobaseTable = ValueToStringInternal(DataExchangeServer.GetTableObjects(FullTableName));
	
	Return ValueToStringInternal(Result);
EndFunction

// Corresponds to operation GetCommonNodsData.
Function GetCommonNodeData(ExchangePlanName)
	
	SetPrivilegedMode(True);
	
	Return ValueToStringInternal(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// Corresponds to operation CreateExchange.
Function CreateDataExchange(ExchangePlanName, ParameterString, FilterStructureString, DefaultValuesString)
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	// Get data processor of the exchange settings assistant on the second base.
	DataExchangeCreationAssistant = DataProcessors.DataExchangeCreationAssistant.Create();
	DataExchangeCreationAssistant.ExchangePlanName = ExchangePlanName;
	
	Cancel = False;
	
	// Import assistant parameters from string to assistant data processor.
	DataExchangeCreationAssistant.RunAssistantParametersImport(Cancel, ParameterString);
	
	If Cancel Then
		Message = NStr("en='An error occurred when creating an exchange setting in the second infobase: %1';ru='При создании настройки обмена во второй информационной базе возникли ошибки: %1'");
		Message = StringFunctionsClientServer.PlaceParametersIntoString(Message, DataExchangeCreationAssistant.ErrorMessageString());
		Raise Message;
	EndIf;
	
	DataExchangeCreationAssistant.AssistantOperationOption = "ContinueDataExchangeSetup";
	DataExchangeCreationAssistant.ThisIsSettingOfDistributedInformationBase = False;
	DataExchangeCreationAssistant.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.WS;
	DataExchangeCreationAssistant.SourceInfobasePrefixFilled = ValueIsFilled(GetFunctionalOption("InfobasePrefix"));
	
	// Create exchange setting.
	DataExchangeCreationAssistant.SetUpNewWebSaaSDataExchange(
											Cancel,
											ValueFromStringInternal(FilterStructureString),
											ValueFromStringInternal(DefaultValuesString));
	
	If Cancel Then
		Message = NStr("en='An error occurred when creating an exchange setting in the second infobase: %1';ru='При создании настройки обмена во второй информационной базе возникли ошибки: %1'");
		Message = StringFunctionsClientServer.PlaceParametersIntoString(Message, DataExchangeCreationAssistant.ErrorMessageString());
		Raise Message;
	EndIf;
	
EndFunction

// Corresponds to operation UpdateExchange.
Function UpdateDataExchangeSettings(ExchangePlanName, NodeCode, DefaultValuesString)
	
	DataExchangeServer.ExternalConnectionRefreshExchangeSettingsData(ExchangePlanName, NodeCode, DefaultValuesString);
	
EndFunction

// Corresponds to operation RegisterOnlyCatalogData.
Function RecordCatalogChangesOnly(ExchangePlanName, NodeCode, LongOperation, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongOperation, ActionID, True);
	
EndFunction

// Corresponds to operation RegisterAllDataExceptCatalogs.
Function RecordAllChangesExceptCatalogs(ExchangePlanName, NodeCode, LongOperation, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongOperation, ActionID, False);
	
EndFunction

// Corresponds to operation GetContinuousOperationStatus.
Function GetLongOperationState(ActionID, ErrorMessageString)
	
	BackgroundJobState = New Map;
	BackgroundJobState.Insert(BackgroundJobState.Active,           "Active");
	BackgroundJobState.Insert(BackgroundJobState.Completed,         "Executed");
	BackgroundJobState.Insert(BackgroundJobState.Failed, "Failed");
	BackgroundJobState.Insert(BackgroundJobState.Canceled,          "Canceled");
	
	SetPrivilegedMode(True);
	
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(ActionID));
	
	If BackgroundJob.ErrorInfo <> Undefined Then
		
		ErrorMessageString = DetailErrorDescription(BackgroundJob.ErrorInfo);
		
	EndIf;
	
	Return BackgroundJobState.Get(BackgroundJob.State);
EndFunction

// Corresponds to operation GetFunctionalOption.
Function GetFunctionalOptionValue(Name)
	
	Return GetFunctionalOption(Name);
	
EndFunction

// Corresponds to operation PrepareGetFile.
Function PrepareGetFile(FileId, BlockSize, TransferId, PartQuantity)
	
	SetPrivilegedMode(True);
	
	TransferId = New UUID;
	
	SourceFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	File = New File(SourceFileName);
	
	SourceFileNameInTemporaryDirectory = CommonUseClientServer.GetFullFileName(TemporaryDirectory, File.Name);
	SharedFileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	CreateDirectory(TemporaryDirectory);
	
	MoveFile(SourceFileName, SourceFileNameInTemporaryDirectory);
	
	Archiver = New ZipFileWriter(SharedFileName,,,, ZIPCompressionLevel.Maximum);
	Archiver.Add(SourceFileNameInTemporaryDirectory);
	Archiver.Write();
	
	If BlockSize <> 0 Then
		// Divide file into parts
		FileNames = SplitFile(SharedFileName, BlockSize * 1024);
		PartQuantity = FileNames.Count();
	Else
		PartQuantity = 1;
		MoveFile(SharedFileName, SharedFileName + ".1");
	EndIf;
	
EndFunction

// Corresponds to operation GetFilePart.
Function GetFilePart(TransferId, PartNumber, PartData)
	
	FileName = "data.zip.[n]";
	FileName = StrReplace(FileName, "[n]", Format(PartNumber, "NG=0"));
	
	FileNames = FindFiles(TemporaryExportDirectory(TransferId), FileName);
	If FileNames.Count() = 0 Then
		
		MessagePattern = NStr("en='Fragment %1 of transfer session with the %2 ID is not found';ru='Не найден фрагмент %1 сессии передачи с идентификатором %2'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	ElsIf FileNames.Count() > 1 Then
		
		MessagePattern = NStr("en='Several fragments %1 of the transfer session with the %2 ID have been found';ru='Найдено несколько фрагментов %1 сессии передачи с идентификатором %2'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	EndIf;
	
	FileNamePart = FileNames[0].FullName;
	PartData = New BinaryData(FileNamePart);
	
EndFunction

// Corresponds to operation ReleaseFile.
Function ReleaseFile(TransferId)
	
	Try
		DeleteFiles(TemporaryExportDirectory(TransferId));
	Except
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextRemovingTemporaryFile(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Corresponds to operation PutFilePart.
Function PutFilePart(TransferId, PartNumber, PartData)
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	If PartNumber = 1 Then
		
		CreateDirectory(TemporaryDirectory);
		
	EndIf;
	
	FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
	
	PartData.Write(FileName);
	
EndFunction

// Corresponds to operation SaveFileFromParts.
Function SaveFileFromParts(TransferId, PartQuantity, FileId)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	PartFilesToMerge = New Array;
	
	For PartNumber = 1 To PartQuantity Do
		
		FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
		
		If FindFiles(FileName).Count() = 0 Then
			MessagePattern = NStr("en='Fragment of transfer session %1 with ID %2 is not found.
		|It is necessary to make sure that
		|in application settings parameters ""Directory of temporary files for Linux"" and ""Directory of temporary files for Windows"" are specified.';ru='Не найден фрагмент %1 сессии передачи с идентификатором %2.
		|Необходимо убедиться, что в настройках программы заданы параметры
		|""Каталог временных файлов для Linux"" и ""Каталог временных файлов для Windows"".'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, String(PartNumber), String(TransferId));
			Raise(MessageText);
		EndIf;
		
		PartFilesToMerge.Add(FileName);
		
	EndDo;
	
	ArchiveName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	MergeFiles(PartFilesToMerge, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	
	If Dearchiver.Items.Count() = 0 Then
		Try
			DeleteFiles(TemporaryDirectory);
		Except
			WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextRemovingTemporaryFile(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise(NStr("en='Archive file does not contain the data.';ru='Файл архива не содержит данных.'"));
	EndIf;
	
	ExportDirectory = DataExchangeReUse.TempFileStorageDirectory();
	
	FileName = CommonUseClientServer.GetFullFileName(ExportDirectory, Dearchiver.Items[0].Name);
	
	Dearchiver.Extract(Dearchiver.Items[0], ExportDirectory);
	Dearchiver.Close();
	
	FileId = DataExchangeServer.PutFileToStorage(FileName);
	
	Try
		DeleteFiles(TemporaryDirectory);
	Except
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextRemovingTemporaryFile(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Corresponds to operation PutFileIntoStorage.
Function PutFileIntoStorage(FileName, FileId)
	
	SetPrivilegedMode(True);
	
	FileId = DataExchangeServer.PutFileToStorage(FileName);
	
EndFunction

// Corresponds to operation GetFileFromStorage.
Function GetFileFromStorage(FileId)
	
	SetPrivilegedMode(True);
	
	SourceFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	File = New File(SourceFileName);
	
	Return File.Name;
EndFunction

// Corresponds to operation FileExists.
Function FileExists(FileName)
	
	SetPrivilegedMode(True);
	
	TempFileFullName = CommonUseClientServer.GetFullFileName(DataExchangeReUse.TempFileStorageDirectory(), FileName);
	
	File = New File(TempFileFullName);
	
	Return File.Exist();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

Procedure ValidateLockInformationBaseForUpdate()
	
	IBIsLockedToUpdate = InfobaseUpdateService.InfobaseLockedForUpdate();
	If ValueIsFilled(IBIsLockedToUpdate) Then
		Raise IBIsLockedToUpdate;
	EndIf;
	
EndProcedure

Procedure ExecuteDataExportInClientServerMode(ExchangePlanName,
														CodeOfInfobaseNode,
														FileID,
														LongOperation,
														ActionID,
														LongOperationAllowed)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(CodeOfInfobaseNode);
	Parameters.Add(FileID);
	
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName, CodeOfInfobaseNode);
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	If BackgroundJobs.GetBackgroundJobs (Filter).Count() = 1 Then
		Raise NStr("en='Data synchronization is already executing.';ru='Синхронизация данных уже выполняется.'");
	EndIf;
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ExportToFileTransferServiceForInfobaseNode",
										Parameters,
										BackgroundJobKey,
										NStr("en='Data exchange through the web service is being performed.';ru='Выполнение обмена данными через веб-сервис.'"));
	
	Try
		Timeout = ?(LongOperationAllowed, 5, Undefined);
		
		BackgroundJob.WaitForCompletion(Timeout);
	Except
		
		BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
		
		If BackgroundJob.State = BackgroundJobState.Active Then
			
			ActionID = String(BackgroundJob.UUID);
			LongOperation = True;
			Return;
			
		Else
			
			If BackgroundJob.ErrorInfo <> Undefined Then
				Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
			EndIf;
			
			Raise;
		EndIf;
		
	EndTry;
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
	
	If BackgroundJob.State <> BackgroundJobState.Completed Then
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
		EndIf;
		
		Raise NStr("en='Error when exporting the data through the web service.';ru='Ошибка при выгрузке данных через веб-сервис.'");
	EndIf;
	
EndProcedure

Procedure ImportDataInClientServerMode(ExchangePlanName,
													CodeOfInfobaseNode,
													FileID,
													LongOperation,
													ActionID,
													LongOperationAllowed)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(CodeOfInfobaseNode);
	Parameters.Add(FileID);
	
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName, CodeOfInfobaseNode);
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	If BackgroundJobs.GetBackgroundJobs (Filter).Count() = 1 Then
		Raise NStr("en='Data synchronization is already executing.';ru='Синхронизация данных уже выполняется.'");
	EndIf;
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ImportForInfobaseNodeFromFileTransferService",
										Parameters,
										BackgroundJobKey,
										NStr("en='Data exchange through the web service is being performed.';ru='Выполнение обмена данными через веб-сервис.'"));
	
	Try
		Timeout = ?(LongOperationAllowed, 5, Undefined);
		
		BackgroundJob.WaitForCompletion(Timeout);
	Except
		
		BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
		
		If BackgroundJob.State = BackgroundJobState.Active Then
			
			ActionID = String(BackgroundJob.UUID);
			LongOperation = True;
			Return;
			
		Else
			
			If BackgroundJob.ErrorInfo <> Undefined Then
				Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
			EndIf;
			Raise;
		EndIf;
		
	EndTry;
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
	
	If BackgroundJob.State <> BackgroundJobState.Completed Then
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
		EndIf;
		
		Raise NStr("en='Error when importing the data through the web service.';ru='Ошибка при загрузке данных через веб-сервис.'");
	EndIf;
	
EndProcedure

Function ExportImportDataBackgroundJobKey(ExchangePlan, NodeCode)
	
	Key = "ExchangePlan:[ExchangePlan] NodeCode:[NodeCode]";
	Key = StrReplace(Key, "[ExchangePlan]", ExchangePlan);
	Key = StrReplace(Key, "[NodeCode]", NodeCode);
	
	Return Key;
EndFunction

Function RegisterDataForInitialExport(Val ExchangePlanName, Val NodeCode, LongOperation, ActionID, CatalogsOnly)
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfobaseNode) Then
		Message = NStr("en='Exchange plan node is not found; %1 exchange plan name; %2 node code';ru='Не найден узел плана обмена; имя плана обмена %1; код узла %2'");
		Message = StringFunctionsClientServer.PlaceParametersIntoString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	If CommonUse.FileInfobase() Then
		
		If CatalogsOnly Then
			
			DataExchangeServer.RegisterOnlyCatalogsForInitialLandings(InfobaseNode);
			
		Else
			
			DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExporting(InfobaseNode);
			
		EndIf;
		
	Else
		
		If CatalogsOnly Then
			MethodName = "DataExchangeServer.RegisterOnlyCatalogsForInitialExport";
		Else
			MethodName = "DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport";
		EndIf;
		
		Parameters = New Array;
		Parameters.Add(InfobaseNode);
		
		BackgroundJob = BackgroundJobs.Execute(MethodName, Parameters,, NStr("en='Data exchange creation.';ru='Создание обмена данными.'"));
		
		Try
			BackgroundJob.WaitForCompletion(5);
		Except
			
			BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
			
			If BackgroundJob.State = BackgroundJobState.Active Then
				
				ActionID = String(BackgroundJob.UUID);
				LongOperation = True;
				
			Else
				If BackgroundJob.ErrorInfo <> Undefined Then
					Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
				EndIf;
				
				Raise;
			EndIf;
			
		EndTry;
		
	EndIf;
	
EndFunction

Function GetPartFileName(PartNumber)
	
	Result = "data.zip.[n]";
	
	Return StrReplace(Result, "[n]", Format(PartNumber, "NG=0"));
EndFunction

Function TemporaryExportDirectory(Val SessionID)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = "{SessionID}";
	TemporaryDirectory = StrReplace(TemporaryDirectory, "SessionID", String(SessionID));
	
	Result = CommonUseClientServer.GetFullFileName(DataExchangeReUse.TempFileStorageDirectory(), TemporaryDirectory);
	
	Return Result;
EndFunction

#EndRegion
