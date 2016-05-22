
&AtClient
Var ExternalResourcesAllowed;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	RefreshExchangePlansChoiceList();
	
	RefreshRulesTemplateChoiceList();
	
	UpdateRuleInfo();
	
	RulesSource = ?(Record.RulesSource = Enums.RuleSourcesForDataExchange.ConfigurationTemplate,
		"StandardFromConfiguration", "ExportedFromTheFile");
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
	Items.DebuggingGroup.Enabled = (RulesSource = "ExportedFromTheFile");
	Items.GroupSettingDebug.Enabled = Record.DebugMode;
	Items.SourceFile.Enabled = (RulesSource = "ExportedFromTheFile");
	
	DataExchangeRuleImportingEventLogMonitorMessageText = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not CheckFillingOnClient() Then
		Cancel = True;
		Return;
	EndIf;
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingAlert = New NotifyDescription("AllowExternalResourceEnd", ThisObject, WriteParameters);
		Queries = CreateQueryOnExternalResourcesUse(Record);
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
		
		Cancel = True;
		Return;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
	If RulesSource = "StandardFromConfiguration" Then
		// From configuration
		ImportRulesExecute(Undefined, "", False);
	EndIf;
	
EndProcedure

&AtClient
Function CheckFillingOnClient()
	
	HasUnfilledFields = False;
	
	If RulesSource = "ExportedFromTheFile" AND IsBlankString(Record.RulesFilename) Then
		
		MessageString = NStr("en = 'The exchange rules file is not specified.'");
		CommonUseClientServer.MessageToUser(MessageString,,,, HasUnfilledFields);
		
	EndIf;
	
	If Record.DebugMode Then
		
		If Record.ExportDebuggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.DataProcessorFileNameForExportDebugging);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External processing attachment file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "Record.DataProcessorFileNameForExportDebugging",, HasUnfilledFields);
				
			EndIf;
			
		EndIf;
		
		If Record.ImportDebuggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.DataProcessorFileNameForImportDebugging);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External processing attachment file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "Record.DataProcessorFileNameForImportDebugging",, HasUnfilledFields);
				
			EndIf;
			
		EndIf;
		
		If Record.DataExchangeLoggingMode Then
			
			FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ExchangeProtocolFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'Exchange protocol attachment file name is not specified.'");
				CommonUseClientServer.MessageToUser(MessageString,, "Record.ExchangeProtocolFileName",, HasUnfilledFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasUnfilledFields;
	
EndFunction

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ExchangePlanNameOnChange(Item)
	
	Record.RulesTemplateName = "";
	
	// server call
	RefreshRulesTemplateChoiceList();
	
EndProcedure

&AtClient
Procedure RulesSourceOnChange(Item)
	
	Items.DebuggingGroup.Enabled = (RulesSource = "ExportedFromTheFile");
	Items.SourceFile.Enabled = (RulesSource = "ExportedFromTheFile");
	
	If RulesSource = "StandardFromConfiguration" Then
		
		Record.DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableDebuggingExportingsOnChange(Item)
	
	Items.ExternalDataProcessorForExportDebugging.Enabled = Record.ExportDebuggingMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebuggingBeginChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External processor(*.epf)'") + "|*.epf" );
	
	DataExchangeClient.FileChoiceHandler(Record, "DataProcessorFileNameForExportDebugging", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalProcessingForExportDebuggingBeginChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External processor(*.epf)'") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileChoiceHandler(Record, "DataProcessorFileNameForImportDebugging", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForImportDebugging.Enabled = Record.ImportDebuggingMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeLoggingOnChange(Item)
	
	Items.ProtocolExchangeFile.Enabled = Record.DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ProtocolExchangeFileBeginChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'Text document(*.txt)'")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	StandardProcessing = False;
	DataExchangeClient.FileChoiceHandler(Record, "ExchangeProtocolFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ProtocolExchangeFileOpen(Item, StandardProcessing)
	
	DataExchangeClient.HandlerOfOpeningOfFileOrDirectory(Record, "ExchangeProtocolFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure RulesTemplateNameOnChange(Item)
	Record.RulesTemplateNameCorrespondent = Record.RulesTemplateName + "correspondent";
EndProcedure

&AtClient
Procedure EnableDebugModeOnChange(Item)
	
	Items.GroupSettingDebug.Enabled = Record.DebugMode;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportRules(Command)
	
	// From file from client
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RulesFilename);
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Title", NStr("en = 'Specify archive with exchange rules'"));
	DialogueParameters.Insert("Filter", NStr("en = 'ZIP archives (*.zip)'") + "|*.zip");
	DialogueParameters.Insert("FullFileName", NameParts.FullName);
	
	Notification = New NotifyDescription("ImportRulesEnd", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogueParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RulesFilename);

	// Export as an archive
	StorageAddress = GetRuleArchiveTempStorageAddressAtServer();
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en = 'Conversion rules'");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Mode", FileDialogMode.Save);
	DialogueParameters.Insert("Title", NStr("en = 'Specify the file to which the rules should be exported'") );
	DialogueParameters.Insert("FullFileName", FullFileName);
	DialogueParameters.Insert("Filter", NStr("en = 'ZIP archives (*.zip)'") + "|*.zip");
	
	ReceivedFile = New Structure("Name, Storage", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileOnClient(ReceivedFile, DialogueParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RefreshExchangePlansChoiceList()
	
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	
	FillList(ExchangePlanList, Items.ExchangePlanName.ChoiceList);
	
EndProcedure

&AtServer
Procedure RefreshRulesTemplateChoiceList()
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		Items.MainGroup.Title = NStr("en = 'Conversion rules'");
		
	Else
		
		Items.MainGroup.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			Items.MainGroup.Title, Metadata.ExchangePlans[Record.ExchangePlanName].Synonym);
		
	EndIf;
	
	TemplateList = DataExchangeReUse.GetTypicalExchangeRulesList(Record.ExchangePlanName);
	
	ChoiceList = Items.RulesTemplateName.ChoiceList;
	ChoiceList.Clear();
	
	FillList(TemplateList, ChoiceList);
	
	Items.SourceConfigurationTemplate.CurrentPage = ?(TemplateList.Count() = 1,
		Items.PageOneTemplate, Items.MultipleModelsPage);
	
EndProcedure

&AtServer
Procedure FillList(SourceList, TargetList)
	
	For Each Item IN SourceList Do
		
		FillPropertyValues(TargetList.Add(), Item);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ImportRulesEnd(Val FilesPlacingResult, Val AdditionalParameters) Export
	
	PlacedFileAddress = FilesPlacingResult.Location;
	ErrorText           = FilesPlacingResult.ErrorDescription;
	
	If IsBlankString(ErrorText) AND IsBlankString(PlacedFileAddress) Then
		ErrorText = NStr("en = 'An error occurred during sending a settings file of data synchronization to server'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	// Sent file successfully, import on server.
	NameParts = CommonUseClientServer.SplitFullFileName(FilesPlacingResult.Name);
	
	ImportRulesExecute(PlacedFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
	
EndProcedure

&AtClient
Procedure ImportRulesExecute(Val PlacedFileAddress, Val FileName, Val IsArchive)
	Cancel = False;
	
	Status(NStr("en = 'Importing rules to the infobase...'"));
	ImportRulesAtServer(Cancel, PlacedFileAddress, FileName, IsArchive);
	Status();
	
	If Not Cancel Then
		ShowUserNotification(,, NStr("en = 'Rules have been successfully loaded to the infobase.'"));
		Return;
	EndIf;
	
	ErrorText = NStr("en = 'Errors were found during the import.
	                         |Do you want to open the event log?'");
	
	Notification = New NotifyDescription("ShowEventLogMonitorOnError", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
EndProcedure

&AtClient
Procedure ShowEventLogMonitorOnError(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMonitorEvent", DataExchangeRuleImportingEventLogMonitorMessageText);
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportRulesAtServer(Cancel, TemporaryStorageAddress, RulesFilename, IsArchive)
	
	Record.RulesSource = ?(RulesSource = "StandardFromConfiguration",
		Enums.RuleSourcesForDataExchange.ConfigurationTemplate, Enums.RuleSourcesForDataExchange.File);
	
	Object = FormAttributeToValue("Record");
	
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, Object, TemporaryStorageAddress, RulesFilename, IsArchive);
	
	If Not Cancel Then
		
		Object.Write();
		
		Modified = False;
		
		// Cache of open sessions for the registration mechanism has become irrelevant.
		DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
		RefreshReusableValues();
	EndIf;
	
	ValueToFormAttribute(Object, "Record");
	
	UpdateRuleInfo();
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Create the temporary directory on server and generate paths to files and folders.
	TempFolderName = GetTempFileName("");
	CreateDirectory(TempFolderName);
	PathToFile = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "ExchangeRules";
	PathToCorrespondentFile = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "CorrespondentExchangeRules";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataExchangeRules.XML_Rules,
	|	DataExchangeRules.XMLRulesCorrespondent
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RuleKind = &RuleKind";
	Query.SetParameter("ExchangePlanName", Record.ExchangePlanName); 
	Query.SetParameter("RuleKind", Record.RuleKind);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		NString = NStr("en = 'Failed to receive exchange rules.'");
		DataExchangeServer.ShowMessageAboutError(NString);
		Return "";
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		
		// Get, save and archive the rules file in a temporary directory.
		RuleBinaryData = Selection.XML_Rules.Get();
		RuleBinaryData.Write(PathToFile + ".xml");
		
		CorrespondentRulesBinaryData = Selection.XMLRulesCorrespondent.Get();
		CorrespondentRulesBinaryData.Write(PathToCorrespondentFile + ".xml");
		
		FilePackingMask = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + "*.xml";
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", FilePackingMask);
		
		// Place rules archive to the storage.
		RuleArchiveBinaryData = New BinaryData(PathToFile + ".zip");
		TemporaryStorageAddress = PutToTempStorage(RuleArchiveBinaryData);
		Return TemporaryStorageAddress;
		
	EndIf;
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	If Record.RulesSource = Enums.RuleSourcesForDataExchange.File Then
		
		RulesInformation = NStr("en = 'Use of rules imported
		|from the file may lead to errors when updating application to a new version.
		|
		|[InformationAboutRules]'");
		
		RulesInformation = StrReplace(RulesInformation, "[InformationAboutRules]", Record.RulesInformation);
		
	Else
		
		RulesInformation = Record.RulesInformation;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateQueryOnExternalResourcesUse(Val Record)
	
	PermissionsQueries = New Array;
	RegistrationFromFileRules = InformationRegisters.DataExchangeRules.RegistrationFromFileRules(Record.ExchangePlanName);
	InformationRegisters.DataExchangeRules.QueryOnExternalResourcesUse(PermissionsQueries, Record, True, RegistrationFromFileRules);
	Return PermissionsQueries;
	
EndFunction

#EndRegion
