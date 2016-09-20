
#Region EventsHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "RecordForm" Then
		
		StandardProcessing = False;
		
		If Parameters.Key.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectConversionRules";
			
		ElsIf Parameters.Key.RuleKind = Enums.DataExchangeRuleKinds.ObjectRegistrationRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectRegistrationRules";
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Imports rules to register.
//
// Parameters:
// Cancel - Boolean - Deny writing to the register.
// Record - InformationRegisterRecord.DataExchangeRules - register record to which data will be put.
// TemporaryStorageAddress - String - Temporary storage address from which XML-rules will be imported.
// RulesFilename - String - File name from which files were imported(it is also recorded in the register).
// BinaryData - BinaryData - data to which XML-file is saved(including the one unpacked from ZIP-archive).
// IsArchive - Boolean - Shows that rules are imported from ZIP-archive not from XML-file.
//
Procedure ImportRules(Cancel, Record, TemporaryStorageAddress = "", RulesFilename = "", IsArchive = False) Export
	
	// Check whether mandatory record fields are filled in.
	RunFieldsFillCheckup(Cancel, Record);
	
	If Cancel Then
		Return;
	EndIf;
	
	AreConversionRules = (Record.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules);
	
	// Get rules binary data from file or configuration template.
	If Record.RulesSource = Enums.RuleSourcesForDataExchange.ConfigurationTemplate Then
		
		BinaryData = GetBinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.RulesTemplateName);
		
		If AreConversionRules Then
			
			If IsBlankString(Record.RulesTemplateNameCorrespondent) Then
				Record.RulesTemplateNameCorrespondent = Record.RulesTemplateName + "correspondent";
			EndIf;
			CorrespondentBinaryData = GetBinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.RulesTemplateNameCorrespondent);
			
		EndIf;
		
	Else
		
		BinaryData = GetFromTempStorage(TemporaryStorageAddress);
		
	EndIf;
	
	// If it is an archive, then unzip it and put to the binary data again for the subsequent work.
	If IsArchive Then
		
		// Get archive file from binary data.
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Unpack archive
		TempFolderName = GetTempFileName("");
		If DataExchangeServer.UnpackZIPFile(TemporaryArchiveName, TempFolderName) Then
			
			UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
			
			// There was no file in the archive - deny importing.
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("en='When unpacking the archive the file with rules has not been found.';ru='При распаковке архива не найден файл с правилами.'");
				DataExchangeServer.ShowMessageAboutError(NString, Cancel);
			EndIf;
			
			If AreConversionRules Then
				
				// Put rules received file back to the binary data.
				If UnpackedFileList.Count() = 2 Then
					
					If UnpackedFileList[0].Name = "ExchangeRules.xml" 
						AND UnpackedFileList[1].Name ="CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[0].DescriptionFull);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[1].DescriptionFull);
						
					ElsIf UnpackedFileList[1].Name = "ExchangeRules.xml" 
						AND UnpackedFileList[0].Name ="CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[1].DescriptionFull);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[0].DescriptionFull);
						
					Else
						
						NString = NStr("en='File names in archive does not correspond to the expected ones. Files
		|are expected: ExchangeRules.xml - conversion rules for
		|the current application; CorrespondentExchangeRules.xml - conversion rules for application-correspondent.';ru='Имена файлов в архиве не соответствуют ожидаемым. Ожидаются файлы:
		|ExchangeRules.xml - правила конвертации для текущей программы;
		|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента.'");
						DataExchangeServer.ShowMessageAboutError(NString, Cancel);
						
					EndIf;
					
				// Old format
				ElsIf UnpackedFileList.Count() = 1 Then
					NString = NStr("en='No conversion rules file is found in the archive. Expected files quantity in archive - two. Files
		|are expected: ExchangeRules.xml - conversion rules for
		|the current application; CorrespondentExchangeRules.xml - conversion rules for application-correspondent.';ru='В архиве найден один файл правил конвертации. Ожидаемое количество файлов в архиве - два. Ожидаются файлы: ExchangeRules.xml - правила конвертации для текущей программы; CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента.'");
					DataExchangeServer.ShowMessageAboutError(NString, Cancel);
				// There are several files in the archive but there should be one - deny importing.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("en='Several files are found while unzipping archive. There must be only one file with rules.';ru='При распаковке архива найдено несколько файлов. Должен быть только один файл с правилами.'");
					DataExchangeServer.ShowMessageAboutError(NString, Cancel);
				EndIf;
				
			Else
				
				// Put rules received file back to the binary data.
				If UnpackedFileList.Count() = 1 Then
					BinaryData = New BinaryData(UnpackedFileList[0].DescriptionFull);
					
				// There are several files in the archive but there should be one - deny importing.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("en='Several files are found while unzipping archive. There must be only one file with rules.';ru='При распаковке архива найдено несколько файлов. Должен быть только один файл с правилами.'");
					DataExchangeServer.ShowMessageAboutError(NString, Cancel);
				EndIf;
				
			EndIf;
			
		Else // If you failed to unpack file - deny importing.
			NString = NStr("en='Failed to unpack the archive with rules.';ru='Не удалось распаковать архив с правилами.'");
			DataExchangeServer.ShowMessageAboutError(NString, Cancel);
		EndIf;
		
		// Delete temporary archive and temporary folder to which archive was unzipped.
		DeleteTemporaryFile(TempFolderName);
		DeleteTemporaryFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Get temporary attachment file name in the local FS on server.
	TempFileName = GetTempFileName("xml");
	
	// Get rules file for clearing.
	BinaryData.Write(TempFileName);
	
	If AreConversionRules Then
		
		// Read conversion rules.
		InfobaseObjectsConversion = DataProcessors.InfobaseObjectsConversion.Create();
		
		// data processor properties
		InfobaseObjectsConversion.ExchangeMode = "Export";
		InfobaseObjectsConversion.ExchangePlanNameVRO = Record.ExchangePlanName;
		InfobaseObjectsConversion.EventLogMonitorMessageKey = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
		
		DataExchangeServer.SetSettingsDebuggingExportingsForRulesExchange(InfobaseObjectsConversion, Record.ExchangePlanName, Record.DebugMode);
		
		// data processor methods
		ReadOutRules = InfobaseObjectsConversion.GetExchangeRulesStructure(TempFileName);
		
		RulesInformation = InfobaseObjectsConversion.GetInformationAboutRules(False);
		
		If InfobaseObjectsConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
		// Get temporary attachment file name in the local FS on server.
		CorrespondentTemporaryFileName = GetTempFileName("xml");
		// Get rules file for clearing.
		CorrespondentBinaryData.Write(CorrespondentTemporaryFileName);
		
		// Read conversion rules.
		InfobaseObjectsConversion = DataProcessors.InfobaseObjectsConversion.Create();
		
		// data processor properties
		InfobaseObjectsConversion.ExchangeMode = "Import";
		InfobaseObjectsConversion.ExchangePlanNameVRO = Record.ExchangePlanName;
		InfobaseObjectsConversion.EventLogMonitorMessageKey = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
		
		// data processor methods
		ReadOutRulesCorrespondent = InfobaseObjectsConversion.GetExchangeRulesStructure(CorrespondentTemporaryFileName);
		
		InformationAboutCorrespondentRules = InfobaseObjectsConversion.GetInformationAboutRules(True);
		
		If InfobaseObjectsConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
 		RulesInformation = RulesInformation + Chars.LF + Chars.LF + InformationAboutCorrespondentRules;
		
	Else // ObjectRegistrationRules
		
		// Read registration rules.
		ImportRecordRules = DataProcessors.ObjectRegistrationRulesImport.Create();
		
		// data processor properties
		ImportRecordRules.ExchangePlanImportName = Record.ExchangePlanName;
		
		// data processor methods
		ImportRecordRules.ImportRules(TempFileName);
		
		ReadOutRules = ImportRecordRules.ObjectRegistrationRules;
		
		RulesInformation = ImportRecordRules.GetInformationAboutRules();
		
		If ImportRecordRules.ErrorFlag Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
	// Delete rules temporary file.
	DeleteTemporaryFile(TempFileName);
	
	If Not Cancel Then
		
		Record.XML_Rules          = New ValueStorage(BinaryData, New Deflation());
		Record.ReadOutRules   = New ValueStorage(ReadOutRules);
		
		If AreConversionRules Then
			
			Record.XMLRulesCorrespondent = New ValueStorage(CorrespondentBinaryData, New Deflation());
			Record.ReadOutRulesCorrespondent = New ValueStorage(ReadOutRulesCorrespondent);
			
		EndIf;
		
		Record.RulesInformation = RulesInformation;
		Record.RulesFilename = RulesFilename;
		Record.RulesImported = True;
		Record.ExchangePlanNameFromRules = Record.ExchangePlanName;
		
	EndIf;
	
EndProcedure

Procedure ImportRuleSet(Cancel, DataForWriting, ErrorDescription, TemporaryStorageAddress = "", RulesFilename = "") Export
	
	ConversionRulesRecord = DataForWriting.ConversionRulesRecord;
	RegistrationRulesRecord = DataForWriting.RegistrationRulesRecord;
	
	// Get rules binary data from file or configuration template.
	If ConversionRulesRecord.RulesSource = Enums.RuleSourcesForDataExchange.ConfigurationTemplate Then
		
		BinaryData               = GetBinaryDataFromConfigurationTemplate(Cancel, ConversionRulesRecord.ExchangePlanName, ConversionRulesRecord.RulesTemplateName);
		CorrespondentBinaryData = GetBinaryDataFromConfigurationTemplate(Cancel, ConversionRulesRecord.ExchangePlanName, ConversionRulesRecord.RulesTemplateNameCorrespondent);
		RegistrationBinaryData    = GetBinaryDataFromConfigurationTemplate(Cancel, RegistrationRulesRecord.ExchangePlanName, RegistrationRulesRecord.RulesTemplateName);
		
	Else
		
		BinaryData = GetFromTempStorage(TemporaryStorageAddress);
		
	EndIf;
	
	If ConversionRulesRecord.RulesSource = Enums.RuleSourcesForDataExchange.File Then
		
		// Get archive file from binary data.
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Unpack archive
		TempFolderName = GetTempFileName("");
		If DataExchangeServer.UnpackZIPFile(TemporaryArchiveName, TempFolderName) Then
			
			UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
			
			// There was no file in the archive - deny importing.
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("en='When unpacking the archive the file with rules has not been found.';ru='При распаковке архива не найден файл с правилами.'");
				DataExchangeServer.ShowMessageAboutError(NString, Cancel);
			EndIf;
			
			// Files quantity does not correspond to the expected one - deny importing.
			If UnpackedFileList.Count() <> 3 Then
				NString = NStr("en='Incorrect rules set format. Expected files quantity in archive - three. Files
		|are expected: ExchangeRules.xml - conversion rules for
		|the current application; CorrespondentExchangeRules.xml - conversion rules
		|for the application-correspondent; RegistrationRules.xml - rules of registration for the current application.';ru='Не верный формат комплекта правил. Ожидаемое количество файлов в архиве - три. Ожидаются файлы: ExchangeRules.xml - правила конвертации для текущей программы; CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента; RegistrationRules.xml - правила регистрации для текущей программы.'");
				DataExchangeServer.ShowMessageAboutError(NString, Cancel);
			EndIf;
				
			// Put rules received file back to the binary data.
			For Each ReceivedFile IN UnpackedFileList Do
				
				If ReceivedFile.Name = "ExchangeRules.xml" Then
					BinaryData = New BinaryData(ReceivedFile.DescriptionFull);
				ElsIf ReceivedFile.Name ="CorrespondentExchangeRules.xml" Then
					CorrespondentBinaryData = New BinaryData(ReceivedFile.DescriptionFull);
				ElsIf ReceivedFile.Name ="RegistrationRules.xml" Then
					RegistrationBinaryData = New BinaryData(ReceivedFile.DescriptionFull);
				Else
					NString = NStr("en='File names in archive does not correspond to the expected ones. Files are expected:<BR>      |ExchangeRules.xml - conversion rules for the current application; <BR>      |CorrespondentExchangeRules.xml - conversion rules for application-correspondent; <BR>      |RegistrationRules.xml - rules of registration for the current application.';ru='Имена файлов в архиве не соответствуют ожидаемым. Ожидаются файлы:
		|ExchangeRules.xml - правила конвертации для текущей программы;
		|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента;
		|RegistrationRules.xml - правила регистрации для текущей программы.'");

					DataExchangeServer.ShowMessageAboutError(NString, Cancel);
					Break;
				EndIf;
				
			EndDo;
			
		Else 
			// If you failed to unpack file - deny importing.
			NString = NStr("en='Failed to unpack the archive with rules.';ru='Не удалось распаковать архив с правилами.'");
			DataExchangeServer.ShowMessageAboutError(NString, Cancel);
		EndIf;
		
		// Delete temporary archive and temporary folder to which archive was unzipped.
		DeleteTemporaryFile(TempFolderName);
		DeleteTemporaryFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	ConversionRulesInformation = "[SourceRulesInformation] [CorrespondentRulesInformation]";
		
	// Get conversion temporary attachment file name in the local FS on server.
	TempFileName = GetTempFileName("xml");
	
	// Get rules file for clearing.
	BinaryData.Write(TempFileName);
	
	// Read conversion rules.
	InfobaseObjectsConversion = DataProcessors.InfobaseObjectsConversion.Create();
	
	// data processor properties
	InfobaseObjectsConversion.ExchangeMode = "Export";
	InfobaseObjectsConversion.ExchangePlanNameVRO = ConversionRulesRecord.ExchangePlanName;
	InfobaseObjectsConversion.EventLogMonitorMessageKey = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
	DataExchangeServer.SetSettingsDebuggingExportingsForRulesExchange(InfobaseObjectsConversion, ConversionRulesRecord.ExchangePlanName, ConversionRulesRecord.DebugMode);
	
	// data processor methods
	If ConversionRulesRecord.RulesSource = Enums.RuleSourcesForDataExchange.File AND ErrorDescription = Undefined
		AND Not ConversionRulesAreCompatibleWithCurrentVersion(ConversionRulesRecord.ExchangePlanName, ErrorDescription, RulesFromFileInformation(TempFileName)) Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	ReadOutRules = InfobaseObjectsConversion.GetExchangeRulesStructure(TempFileName);
	
	SourceRulesInformation = InfobaseObjectsConversion.GetInformationAboutRules(False);
	
	If InfobaseObjectsConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	// Get conversion temporary attachment file name of correspondent in the local FS on server.
	CorrespondentTemporaryFileName = GetTempFileName("xml");
	// Get rules file for clearing.
	CorrespondentBinaryData.Write(CorrespondentTemporaryFileName);
	
	// Read conversion rules.
	InfobaseObjectsConversion = DataProcessors.InfobaseObjectsConversion.Create();
	
	// data processor properties
	InfobaseObjectsConversion.ExchangeMode = "Import";
	InfobaseObjectsConversion.ExchangePlanNameVRO = ConversionRulesRecord.ExchangePlanName;
	InfobaseObjectsConversion.EventLogMonitorMessageKey = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
	// data processor methods
	ReadOutRulesCorrespondent = InfobaseObjectsConversion.GetExchangeRulesStructure(CorrespondentTemporaryFileName);
	
	InformationAboutCorrespondentRules = InfobaseObjectsConversion.GetInformationAboutRules(True);
	
	If InfobaseObjectsConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[SourceRulesInformation]", SourceRulesInformation);
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[CorrespondentRulesInformation]", InformationAboutCorrespondentRules);
	
	// Get registration temporary attachment file name in the local FS on server.
	RegistrationTemporaryFileName = GetTempFileName("xml");
	// Get rules file for clearing.
	RegistrationBinaryData.Write(RegistrationTemporaryFileName);

	
	// Read registration rules.
	ImportRecordRules = DataProcessors.ObjectRegistrationRulesImport.Create();
	
	// data processor properties
	ImportRecordRules.ExchangePlanImportName = RegistrationRulesRecord.ExchangePlanName;
	
	// data processor methods
	ImportRecordRules.ImportRules(RegistrationTemporaryFileName);
	ReadRegistrationRules   = ImportRecordRules.ObjectRegistrationRules;
	RegistrationRulesInformation = ImportRecordRules.GetInformationAboutRules();
	
	If ImportRecordRules.ErrorFlag Then
		Cancel = True;
	EndIf;
	
	// Delete rules temporary files.
	DeleteTemporaryFile(TempFileName);
	DeleteTemporaryFile(CorrespondentTemporaryFileName);
	DeleteTemporaryFile(RegistrationTemporaryFileName);
	
	If Not Cancel Then
		
		// Create conversion rules record.
		ConversionRulesRecord.XML_Rules                      = New ValueStorage(BinaryData, New Deflation());
		ConversionRulesRecord.ReadOutRules               = New ValueStorage(ReadOutRules);
		ConversionRulesRecord.XMLRulesCorrespondent        = New ValueStorage(CorrespondentBinaryData, New Deflation());
		ConversionRulesRecord.ReadOutRulesCorrespondent = New ValueStorage(ReadOutRulesCorrespondent);
		ConversionRulesRecord.RulesInformation             = ConversionRulesInformation;
		ConversionRulesRecord.RulesFilename                  = RulesFilename;
		ConversionRulesRecord.RulesImported                = True;
		ConversionRulesRecord.ExchangePlanNameFromRules          = ConversionRulesRecord.ExchangePlanName;
		
		// Create registration rules record.
		RegistrationRulesRecord.XML_Rules             = New ValueStorage(RegistrationBinaryData, New Deflation());
		RegistrationRulesRecord.ReadOutRules      = New ValueStorage(ReadRegistrationRules);
		RegistrationRulesRecord.RulesInformation    = RegistrationRulesInformation;
		RegistrationRulesRecord.RulesFilename         = RulesFilename;
		RegistrationRulesRecord.RulesImported       = True;
		RegistrationRulesRecord.ExchangePlanNameFromRules = RegistrationRulesRecord.ExchangePlanName;
		
	EndIf;
	
EndProcedure

Procedure ImportProvidedRules(ExchangePlanName, RulesFilename) Export
	
	File = New File(RulesFilename);
	FileName = File.Name;
	
	// Unpack archive
	TempFolderName = GetTempFileName("");
	If DataExchangeServer.UnpackZIPFile(RulesFilename, TempFolderName) Then
		
		UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
		
		// There was no file in the archive - deny importing.
		If UnpackedFileList.Count() = 0 Then
			Raise NStr("en='When unpacking the archive the file with rules has not been found.';ru='При распаковке архива не найден файл с правилами.'");
		EndIf;
		
		// Files quantity does not correspond to the expected one - deny importing.
		If UnpackedFileList.Count() <> 3 Then
			Raise NStr("en='Incorrect rules set format. Expected files quantity in archive - three. Files
		|are expected: ExchangeRules.xml - conversion rules for
		|the current application; CorrespondentExchangeRules.xml - conversion rules
		|for the application-correspondent; RegistrationRules.xml - rules of registration for the current application.';ru='Не верный формат комплекта правил. Ожидаемое количество файлов в архиве - три. Ожидаются файлы: ExchangeRules.xml - правила конвертации для текущей программы; CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента; RegistrationRules.xml - правила регистрации для текущей программы.'");
		EndIf;
		
		// Put rules received file back to the binary data.
		For Each ReceivedFile IN UnpackedFileList Do
			
			If ReceivedFile.Name = "ExchangeRules.xml" Then
				BinaryData = New BinaryData(ReceivedFile.DescriptionFull);
			ElsIf ReceivedFile.Name ="CorrespondentExchangeRules.xml" Then
				CorrespondentBinaryData = New BinaryData(ReceivedFile.DescriptionFull);
			ElsIf ReceivedFile.Name ="RegistrationRules.xml" Then
				RegistrationBinaryData = New BinaryData(ReceivedFile.DescriptionFull);
			Else
				Raise NStr("en='File names in archive does not correspond to the expected ones. Files
		|are expected: ExchangeRules.xml - conversion rules for
		|the current application; CorrespondentExchangeRules.xml - conversion rules
		|for the application-correspondent; RegistrationRules.xml - rules of registration for the current application.';ru='Имена файлов в архиве не соответствуют ожидаемым. Ожидаются файлы:
		|ExchangeRules.xml - правила конвертации для текущей программы;
		|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента;
		|RegistrationRules.xml - правила регистрации для текущей программы.'");
			EndIf;
			
		EndDo;
		
	Else
		// If you failed to unpack file - deny importing.
		Raise NStr("en='Failed to unpack the archive with rules.';ru='Не удалось распаковать архив с правилами.'");
	EndIf;
	
	// Delete temporary archive and temporary folder to which archive was unzipped.
	DeleteTemporaryFile(TempFolderName);
	
	ConversionRulesInformation = "[SourceRulesInformation] [CorrespondentRulesInformation]";
		
	// Get conversion temporary attachment file name in the local FS on server.
	TempFileName = GetTempFileName("xml");
	
	// Get rules file for clearing.
	BinaryData.Write(TempFileName);
	
	// Read conversion rules.
	InfobaseObjectsConversion = DataProcessors.InfobaseObjectsConversion.Create();
	
	// data processor properties
	InfobaseObjectsConversion.ExchangeMode = "Export";
	InfobaseObjectsConversion.ExchangePlanNameVRO = ExchangePlanName;
	InfobaseObjectsConversion.EventLogMonitorMessageKey = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
	DataExchangeServer.SetSettingsDebuggingExportingsForRulesExchange(InfobaseObjectsConversion, ExchangePlanName, False);
	
	ReadOutRules = InfobaseObjectsConversion.GetExchangeRulesStructure(TempFileName);
	
	SourceRulesInformation = InfobaseObjectsConversion.GetInformationAboutRules(False);
	
	If InfobaseObjectsConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	// Get conversion temporary attachment file name of correspondent in the local FS on server.
	CorrespondentTemporaryFileName = GetTempFileName("xml");
	// Get rules file for clearing.
	CorrespondentBinaryData.Write(CorrespondentTemporaryFileName);
	
	// Read conversion rules.
	InfobaseObjectsConversion = DataProcessors.InfobaseObjectsConversion.Create();
	
	// data processor properties
	InfobaseObjectsConversion.ExchangeMode = "Import";
	InfobaseObjectsConversion.ExchangePlanNameVRO = ExchangePlanName;
	InfobaseObjectsConversion.EventLogMonitorMessageKey = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
	// data processor methods
	ReadOutRulesCorrespondent = InfobaseObjectsConversion.GetExchangeRulesStructure(CorrespondentTemporaryFileName);
	
	InformationAboutCorrespondentRules = InfobaseObjectsConversion.GetInformationAboutRules(True);
	
	If InfobaseObjectsConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[SourceRulesInformation]", SourceRulesInformation);
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[CorrespondentRulesInformation]", InformationAboutCorrespondentRules);
	
	// Get registration temporary attachment file name in the local FS on server.
	RegistrationTemporaryFileName = GetTempFileName("xml");
	// Get rules file for clearing.
	RegistrationBinaryData.Write(RegistrationTemporaryFileName);
	
	// Read registration rules.
	ImportRecordRules = DataProcessors.ObjectRegistrationRulesImport.Create();
	
	// data processor properties
	ImportRecordRules.ExchangePlanImportName = ExchangePlanName;
	
	// data processor methods
	ImportRecordRules.ImportRules(RegistrationTemporaryFileName);
	ReadRegistrationRules   = ImportRecordRules.ObjectRegistrationRules;
	RegistrationRulesInformation = ImportRecordRules.GetInformationAboutRules();
	
	If ImportRecordRules.ErrorFlag Then
		Raise NStr("en='An error occurred while importing registration rules.';ru='Ошибка при загрузке правил регистрации.'");
	EndIf;
	
	// Delete rules temporary files.
	DeleteTemporaryFile(TempFileName);
	DeleteTemporaryFile(CorrespondentTemporaryFileName);
	DeleteTemporaryFile(RegistrationTemporaryFileName);
	
	// Create conversion rules record.
	ConversionRulesRecord = InformationRegisters.DataExchangeRules.CreateRecordManager();
	ConversionRulesRecord.ExchangePlanName = ExchangePlanName;
	ConversionRulesRecord.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules;
	ConversionRulesRecord.RulesTemplateName = "ExchangeRules";
	ConversionRulesRecord.RulesTemplateNameCorrespondent = "CorrespondentExchangeRules";
	ConversionRulesRecord.ExchangePlanNameFromRules = ExchangePlanName;
	ConversionRulesRecord.RulesFilename = FileName;
	ConversionRulesRecord.RulesInformation = ConversionRulesInformation;
	ConversionRulesRecord.RulesSource = Enums.RuleSourcesForDataExchange.File;
	ConversionRulesRecord.XML_Rules = New ValueStorage(BinaryData, New Deflation());
	ConversionRulesRecord.XMLRulesCorrespondent = New ValueStorage(CorrespondentBinaryData, New Deflation());
	ConversionRulesRecord.ReadOutRules = New ValueStorage(ReadOutRules);
	ConversionRulesRecord.ReadOutRulesCorrespondent = New ValueStorage(ReadOutRulesCorrespondent);
	ConversionRulesRecord.DebugMode = False;
	ConversionRulesRecord.UseSelectiveObjectsRegistrationFilter = True;
	ConversionRulesRecord.RulesImported = True;
	ConversionRulesRecord.Write();
	
	// Create registration rules record.
	RegistrationRulesRecord = InformationRegisters.DataExchangeRules.CreateRecordManager();
	RegistrationRulesRecord.ExchangePlanName = ExchangePlanName;
	RegistrationRulesRecord.RuleKind = Enums.DataExchangeRuleKinds.ObjectRegistrationRules;
	RegistrationRulesRecord.RulesTemplateName = "RegistrationRules";
	RegistrationRulesRecord.ExchangePlanNameFromRules = ExchangePlanName;
	RegistrationRulesRecord.RulesFilename = FileName;
	RegistrationRulesRecord.RulesInformation = RegistrationRulesInformation;
	RegistrationRulesRecord.RulesSource = Enums.RuleSourcesForDataExchange.File;
	RegistrationRulesRecord.XML_Rules = New ValueStorage(RegistrationBinaryData, New Deflation());
	RegistrationRulesRecord.ReadOutRules = New ValueStorage(ReadRegistrationRules);
	RegistrationRulesRecord.RulesImported = True;
	RegistrationRulesRecord.Write();
	
EndProcedure

Procedure DeleteProvidedRules(ExchangePlanName) Export
	
	For Each RuleKind IN Enums.DataExchangeRuleKinds Do
		
		RecordManager = InformationRegisters.DataExchangeRules.CreateRecordManager();
		RecordManager.RuleKind = RuleKind;
		RecordManager.ExchangePlanName = ExchangePlanName;
		RecordManager.Read();
		RecordManager.RulesSource = Enums.RuleSourcesForDataExchange.ConfigurationTemplate;
		HasErrors = False;
		InformationRegisters.DataExchangeRules.ImportRules(HasErrors, RecordManager);
		If HasErrors Then
			Raise NStr("en='An error occurred while importing rules from configuration.';ru='Ошибка при загрузке правил из конфигурации.'");
		Else
			RecordManager.Write();
		EndIf;
		
	EndDo;
	
EndProcedure

// Gets get objects conversion rules from IB for an exchange plan.
// 
// Parameters:
//  ExchangePlanName - String - exchange plan name as metadata object.
// 
// Returns:
//  ReadOutRules - ValueStorage - read objects conversion rules.
//  Undefined - If conversion rules were not imported to the base for an exchange plan.
//
Function GetReadObjectConversionRules(Val ExchangePlanName, ReceiveCorrespondentRules = False) Export
	
	// Return value of the function.
	ReadOutRules = Undefined;
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.%1 AS ReadOutRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind      = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.RulesImported
	|";
	
	QueryText = StringFunctionsClientServer.PlaceParametersIntoString(QueryText,
		?(ReceiveCorrespondentRules, "ReadOutRulesCorrespondent", "ReadOutRules"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		ReadOutRules = Selection.ReadOutRules;
		
	EndIf;
	
	Return ReadOutRules;
	
EndFunction

Function RulesFromFileUsed(ExchangePlanName, DetailedResult = False) Export
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.RuleKind AS RuleKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesSource = VALUE(Enum.RuleSourcesForDataExchange.File)
	|	AND DataExchangeRules.RulesImported
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	Result = Query.Execute();
	
	If DetailedResult Then
		
		RulesFromFile = New Structure("RegistrationRules, ConversionRules", False, False);
		
		Selection = Result.Select();
		While Selection.Next() Do
			If Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
				RulesFromFile.ConversionRules = True;
			ElsIf Selection.RuleKind = Enums.DataExchangeRuleKinds.ObjectRegistrationRules Then
				RulesFromFile.RegistrationRules = True;
			EndIf;
		EndDo;
		
		Return RulesFromFile;
		
	Else
		Return Not Result.IsEmpty();
	EndIf;
	
EndFunction

Procedure ImportInformationAboutRules(Cancel, TemporaryStorageAddress, RuleInformationString) Export
	
	Var RuleKind;
	
	RuleInformationString = "";
	
	BinaryData = GetFromTempStorage(TemporaryStorageAddress);
	
	// Get temporary attachment file name in the local FS on server.
	TempFileName = GetTempFileName("xml");
	
	// Get rules file for clearing.
	BinaryData.Write(TempFileName);
	
	DefineRuleKindForDataExchange(RuleKind, TempFileName, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules Then
		
		// Read conversion rules.
		InfobaseObjectsConversion = DataProcessors.InfobaseObjectsConversion.Create();
		
		InfobaseObjectsConversion.ImportExchangeRules(TempFileName, "XMLFile",, True);
		
		If InfobaseObjectsConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
		If Not Cancel Then
			RuleInformationString = InfobaseObjectsConversion.GetInformationAboutRules();
		EndIf;
		
	Else // ObjectRegistrationRules
		
		// Read registration rules.
		ImportRecordRules = DataProcessors.ObjectRegistrationRulesImport.Create();
		
		ImportRecordRules.ImportRules(TempFileName, True);
		
		If ImportRecordRules.ErrorFlag Then
			Cancel = True;
		EndIf;
		
		If Not Cancel Then
			RuleInformationString = ImportRecordRules.GetInformationAboutRules();
		EndIf;
		
	EndIf;
	
	// Delete rules temporary file.
	DeleteTemporaryFile(TempFileName);
	
EndProcedure

Function GetBinaryDataFromConfigurationTemplate(Cancel, ExchangePlanName, TemplateName)
	
	// Get temporary attachment file name in the local FS on server.
	TempFileName = GetTempFileName("xml");
	
	ExchangePlanManager = DataExchangeReUse.GetExchangePlanManagerByName(ExchangePlanName);
	
	// Get typical rights array.
	Try
		RuleTemplate = ExchangePlanManager.GetTemplate(TemplateName);
	Except
		
		MessageString = NStr("en='An error while receiving the configuration template %1 for the exchnage plan of %2 has occurred';ru='Ошибка получения макета конфигурации %1 для плана обмена %2'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, TemplateName, ExchangePlanName);
		DataExchangeServer.ShowMessageAboutError(MessageString, Cancel);
		Return Undefined;
		
	EndTry;
	
	RuleTemplate.Write(TempFileName);
	
	BinaryData = New BinaryData(TempFileName);
	
	// Delete rules temporary file.
	DeleteTemporaryFile(TempFileName);
	
	Return BinaryData;
EndFunction

Procedure DeleteTemporaryFile(TempFileName)
	
	If Not IsBlankString(TempFileName) Then
		DeleteFiles(TempFileName);
	EndIf;
	
EndProcedure

Procedure RunFieldsFillCheckup(Cancel, Record)
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		NString = NStr("en='Specify exchange plan.';ru='Укажите план обмена.'");
		
		DataExchangeServer.ShowMessageAboutError(NString, Cancel);
		
	ElsIf Record.RulesSource = Enums.RuleSourcesForDataExchange.ConfigurationTemplate
		    AND IsBlankString(Record.RulesTemplateName) Then
		
		NString = NStr("en='Specify typical rules.';ru='Укажите типовые правила.'");
		
		DataExchangeServer.ShowMessageAboutError(NString, Cancel);
		
	EndIf;
	
EndProcedure

Procedure DefineRuleKindForDataExchange(RuleKind, FileName, Cancel)
	
	// open file for reading
	Try
		Rules = New XMLReader();
		Rules.OpenFile(FileName);
		Rules.Read();
	Except
		Rules = Undefined;
		
		NString = NStr("en='Unable to determine rules kind because an error occurred while parsing XML-file [FileName]. 
		|The wrong file may be selected or XML-file has an incorrect structure. Choose the correct file.';ru='Не удалось определить вид правил из-за ошибки в разбора XML-файла [ИмяФайла]. 
		|Возможно выбран не тот файл, либо XML-файл имеет некорректную структуру. Выберите корректный файл.'");
		NString = StringFunctionsClientServer.SubstituteParametersInStringByName(NString, New Structure("FileName", FileName));
		DataExchangeServer.ShowMessageAboutError(NString, Cancel);
		Return;
	EndTry;
	
	If Rules.NodeType = XMLNodeType.StartElement Then
		
		If Rules.LocalName = "ExchangeRules" Then
			
			RuleKind = Enums.DataExchangeRuleKinds.ObjectConversionRules;
			
		ElsIf Rules.LocalName = "RegistrationRules" Then
			
			RuleKind = Enums.DataExchangeRuleKinds.ObjectRegistrationRules;
			
		Else
			
			NString = NStr("en='nable to determine rules kind because an error occurred in XML-file rules format [FileName].
		|The wrong file may be selected or XML-file has an incorrect structure. Choose the correct file.';ru='Не удалось определить вид правил из-за ошибки в разбора XML-файла [ИмяФайла]. 
		|Возможно выбран не тот файл, либо XML-файл имеет некорректную структуру. Выберите корректный файл.'");
			NString = StringFunctionsClientServer.SubstituteParametersInStringByName(NString, New Structure("FileName", FileName));
			DataExchangeServer.ShowMessageAboutError(NString, Cancel);
			
		EndIf;
		
	Else
		
		NString = NStr("en='nable to determine rules kind because an error occurred in XML-file rules format [FileName].
		|The wrong file may be selected or XML-file has an incorrect structure. Choose the correct file.';ru='Не удалось определить вид правил из-за ошибки в разбора XML-файла [ИмяФайла]. 
		|Возможно выбран не тот файл, либо XML-файл имеет некорректную структуру. Выберите корректный файл.'");
		NString = StringFunctionsClientServer.SubstituteParametersInStringByName(NString, New Structure("FileName", FileName));
		DataExchangeServer.ShowMessageAboutError(NString, Cancel);
		
	EndIf;
	
	Rules.Close();
	Rules = Undefined;
	
EndProcedure

// Procedure adds record in the register by passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeRules");
	
EndProcedure

Function RulesFromFileInformation(RulesFilename)
	
	ExchangeRules = New XMLReader();
	ExchangeRules.OpenFile(RulesFilename);
	ExchangeRules.Read();
	
	If Not ((ExchangeRules.LocalName = "ExchangeRules") AND (ExchangeRules.NodeType = XMLNodeType.StartElement)) Then
		Raise NStr("en='Exchange rules format error';ru='Ошибка формата правил обмена'");
	EndIf;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" AND ExchangeRules.NodeType = XMLNodeType.StartElement Then
			
			RulesInformation = New Structure;
			RulesInformation.Insert("ConfigurationVersion", ExchangeRules.GetAttribute("ConfigurationVersion"));
			RulesInformation.Insert("ConfigurationSynonymInRules", ExchangeRules.GetAttribute("ConfigurationSynonym"));
			ExchangeRules.Read();
			RulesInformation.Insert("ConfigurationName", ExchangeRules.Value);
			
		ElsIf (NodeName = "Source") AND (ExchangeRules.NodeType = XMLNodeType.EndElement) Then
			
			ExchangeRules.Close();
			Return RulesInformation;
			
		EndIf;
		
	EndDo;
	
	Raise NStr("en='Exchange rules format error';ru='Ошибка формата правил обмена'");
	
EndFunction

Function ConversionRulesAreCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription, RulesData)
	
	If Not DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRulesVersionsMismatch") Then
		Return True;
	EndIf;
	
	ConfigurationNameFromRules = Upper(RulesData.ConfigurationName);
	InfobaseConfigurationName = StrReplace(Upper(Metadata.Name), "BASE", "");
	If ConfigurationNameFromRules <> InfobaseConfigurationName Then
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorText", NStr("en='Rules can not be imported as they are designed for application ""%1"". You should use rules from configuration or import correct rules set from file.';ru='Правила не могут быть загружены, т.к. они предназначены для программы ""%1"". Следует использовать правила из конфигурации или загрузить корректный комплект правил из файла.'"));
		ErrorDescription.ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorDescription.ErrorText,
		RulesData.ConfigurationSynonymInRules);
		ErrorDescription.Insert("ErrorKind", "IncorrectConfiguration");
		ErrorDescription.Insert("Picture", PictureLib.Error32);
		Return False;
		
	EndIf;
	
	VersionInRulesWithoutAssembly = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(RulesData.ConfigurationVersion);
	ConfigurationVersionWithoutAssembly = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(Metadata.Version);
	ComparisonResult = CommonUseClientServer.CompareVersionsWithoutBatchNumber(VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
	
	If ComparisonResult <> 0 Then
		
		If ComparisonResult < 0 Then
			
			ErrorText = NStr("en='Data synchronization may work incorrectly as imported rules are designed for the previous application version ""%1"" (%2). It is recommended to use rules from configuration or import rules set designed for the current application version (%3).';ru='Синхронизация данных может работать некорректно, так как загружаемые правила предназначены для предыдущей версии программы ""%1"" (%2). Рекомендуется использовать правила из конфигурации или загрузить комплект правил, предназначенный для текущей версии программы (%3).'");
			ErrorKind = "OutdatedConfigurationVersion";
			
		Else
			
			ErrorText = NStr("en='Data synchronization may work incorrectly as imported rules are designed for more recent application version ""%1"" (%2). It is recommended to update application version or use rules set designed for the current application version (%3).';ru='Синхронизация данных может работать некорректно, так как загружаемые правила предназначены для более новой версии программы ""%1"" (%2). Рекомендуется обновить версию программы или использовать комплект правил, предназначенный для текущей версии программы (%3).'");
			ErrorKind = "OutdatedRules";
			
		EndIf;
		
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorText, Metadata.Synonym,
			VersionInRulesWithoutAssembly, ConfigurationVersionWithoutAssembly);
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorText", ErrorText);
		ErrorDescription.Insert("ErrorKind", ErrorKind);
		ErrorDescription.Insert("Picture", PictureLib.Warning32);
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Security profiles

Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	ImportedRules = ImportedRules();
	
	While ImportedRules.Next() Do
		
		QueryOnExternalResourcesUse(PermissionsQueries, ImportedRules);
		
	EndDo;
	
EndProcedure

Function RegistrationFromFileRules(ExchangePlanName) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1 1
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesImported = TRUE
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectRegistrationRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.RuleSourcesForDataExchange.File)
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function ConversionRulesFromFile(ExchangePlanName) Export
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	DataExchangeRules.DebugMode,
	|	DataExchangeRules.ExportDebuggingMode,
	|	DataExchangeRules.ImportDebuggingMode,
	|	DataExchangeRules.DataExchangeLoggingMode,
	|	DataExchangeRules.DataProcessorFileNameForExportDebugging,
	|	DataExchangeRules.DataProcessorFileNameForImportDebugging,
	|	DataExchangeRules.ExchangeProtocolFileName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesImported = TRUE
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		Return Undefined;
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		Return Selection;
		
	EndIf;
	
EndFunction

Function ImportedRules()
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	DataExchangeRules.DebugMode,
	|	DataExchangeRules.ExportDebuggingMode,
	|	DataExchangeRules.ImportDebuggingMode,
	|	DataExchangeRules.DataExchangeLoggingMode,
	|	DataExchangeRules.DataProcessorFileNameForExportDebugging,
	|	DataExchangeRules.DataProcessorFileNameForImportDebugging,
	|	DataExchangeRules.ExchangeProtocolFileName,
	|	TRUE AS ThereAreConversionRules
	|INTO ConversionRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectConversionRules)
	|	AND DataExchangeRules.RulesImported = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	TRUE AS RegistrationFromFileRules
	|INTO RegistrationRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesImported = TRUE
	|	AND DataExchangeRules.RuleKind = VALUE(Enum.DataExchangeRuleKinds.ObjectRegistrationRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.RuleSourcesForDataExchange.File)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN RegistrationRules.RegistrationFromFileRules
	|			THEN RegistrationRules.ExchangePlanName
	|		ELSE ConversionRules.ExchangePlanName
	|	END AS ExchangePlanName,
	|	ConversionRules.DebugMode,
	|	ConversionRules.ExportDebuggingMode,
	|	ConversionRules.ImportDebuggingMode,
	|	ConversionRules.DataExchangeLoggingMode,
	|	ConversionRules.DataProcessorFileNameForExportDebugging,
	|	ConversionRules.DataProcessorFileNameForImportDebugging,
	|	ConversionRules.ExchangeProtocolFileName,
	|	ISNULL(RegistrationRules.RegistrationFromFileRules, FALSE) AS RegistrationFromFileRules,
	|	ISNULL(ConversionRules.ThereAreConversionRules, FALSE) AS ThereAreConversionRules
	|FROM
	|	ConversionRules AS ConversionRules
	|		Full JOIN RegistrationRules AS RegistrationRules
	|		ON ConversionRules.ExchangePlanName = RegistrationRules.ExchangePlanName";
	
	QueryResult = Query.Execute();
	Return QueryResult.Select();
	
EndFunction

Procedure QueryOnExternalResourcesUse(PermissionsQueries, Record, ThereAreConversionRules = Undefined, RegistrationFromFileRules = Undefined) Export
	
	permissions = New Array;
	
	If RegistrationFromFileRules = Undefined Then
		RegistrationFromFileRules = Record.RegistrationFromFileRules;
	EndIf;
	
	If ThereAreConversionRules = Undefined Then
		ThereAreConversionRules = Record.ThereAreConversionRules;
	EndIf;
	
	If RegistrationFromFileRules Then
		permissions.Add(WorkInSafeMode.PermissionToUsePrivelegedMode());
	EndIf;
	
	If ThereAreConversionRules Then
		
		If Not Record.DebugMode Then
			// Query for a personal profile is not required.
		Else
			
			If Not RegistrationFromFileRules Then
				permissions.Add(WorkInSafeMode.PermissionToUsePrivelegedMode());
			EndIf;
			
			If Record.DebugMode Then
				
				If Record.ExportDebuggingMode Then
					
					FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.DataProcessorFileNameForExportDebugging);
					permissions.Add(WorkInSafeMode.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.ImportDebuggingMode Then
					
					FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.DataProcessorFileNameForExportDebugging);
					permissions.Add(WorkInSafeMode.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.DataExchangeLoggingMode Then
					
					FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.DataProcessorFileNameForExportDebugging);
					permissions.Add(WorkInSafeMode.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, True));
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ExchangePlanID = CommonUse.MetadataObjectID(Metadata.ExchangePlans[Record.ExchangePlanName]);
	
	CommonUseClientServer.SupplementArray(PermissionsQueries,
		WorkInSafeModeService.PermissionsRequestForExternalModule(ExchangePlanID, permissions));
	
EndProcedure

#EndRegion

#EndIf
