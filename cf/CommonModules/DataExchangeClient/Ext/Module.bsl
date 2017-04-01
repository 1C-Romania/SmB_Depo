////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Procedure-handler of closing form of exchange plan nodes setting.
//
// Parameters:
//  Form - managed form from which procedure is called
// 
Procedure SetupOfNodesFormCloseFormCommand(Form) Export
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	Form.Modified = False;
	FillStructureData(Form);
	Form.Close(Form.Context);
	
EndProcedure

// Procedure-handler of closing form of exchange plan node setting.
//
// Parameters:
//  Form - managed form from which procedure is called
// 
Procedure NodeConfigurationFormCommandCloseForm(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "FilterSsettingsAtNode");
	
EndProcedure

// Procedure-handler of closing the default values setting form of exchange plan node.
//
// Parameters:
//  Form - managed form from which procedure is called
// 
Procedure DefaultValuesConfigurationFormCommandCloseForm(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "DefaultValuesAtNode");
	
EndProcedure

// Procedure-handler of closing form of exchange plan node setting.
//
// Parameters:
//  Cancel - check box canceling form closing.
//  Form - managed form from which procedure is called
// 
Procedure SettingFormBeforeClose(Cancel, Form) Export
	
	If Form.Modified Then
		
		Cancel = True;
		
		QuestionText = NStr("en='Data was changed. Do you want to close the form without saving the changes?';ru='Данные изменены. Закрыть форму без сохранения изменений?'");
		NotifyDescription = New NotifyDescription("SettingFormBeforeCloseEnd", ThisObject, Form);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.No);
		
	EndIf;
	
EndProcedure

// Opens setting assistant form of the data exchange for the specified exchange plan.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as metadata object for which it is required to open assistant.
//  ExchangeWithServiceSetup - Boolean - Shows that exchange with applications in the service model is set.
// 
Procedure OpenDataExchangeSettingAssistant(Val ExchangePlanName, ExchangeWithServiceSetup = False) Export
	
	AdditionalSetting = "";
	
	If Find(ExchangePlanName, "CorrespondentSaaS") > 0 Then
		
		ExchangePlanName = StrReplace(ExchangePlanName, "CorrespondentSaaS", "");
		
		ExchangeWithServiceSetup = True;
		
	EndIf;
	
	If Find(ExchangePlanName, "SettingID") > 0 Then
		
		CharactersQuantityExchangePlanName = Find(ExchangePlanName, "SettingID") - 1;
		
		AdditionalSetting = Right(ExchangePlanName, StrLen(ExchangePlanName) - CharactersQuantityExchangePlanName - 22);
		ExchangePlanName          = Left(ExchangePlanName, CharactersQuantityExchangePlanName);
		
	EndIf;
	
	FormParameters = New Structure("ExchangePlanName", ExchangePlanName);
	FormParameters.Insert("AdditionalSetting", AdditionalSetting);
	
	If ExchangeWithServiceSetup Then
		FormParameters.Insert("ExchangeWithServiceSetup");
	EndIf;
	
	OpenForm("DataProcessor.DataExchangeCreationAssistant.Form.Form", FormParameters, , ExchangePlanName + ExchangeWithServiceSetup, , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Handler of the item selection start for settings form of the base-correspondent node
// during exchange setting via the external connection.
//
// Parameters:
// AttributeName - String - Name form attribute.
// TableName - String - Full name of metadata object.
// Owner - ManagedForm - Selection form of base-correspondent items.
// StandardProcessing - Boolean - Shows that the standard (system) event processor is executed.
// ExternalConnectionParameters - Structure - external connection settings.
// ChoiceParameters - Structure - Selection parameters structure.
//
Procedure CorrespondentInfobaseObjectSelectionHandlerStartChoice(Val AttributeName, Val TableName, Val Owner,
	Val StandardProcessing, Val ExternalConnectionParameters, Val ChoiceParameters=Undefined) Export
	
	IdentificatorAttributeName = AttributeName + "_Key";
	
	ChoiceInitialValue = Undefined;
	ChoiceFoldersAndItems    = Undefined;
	
	OwnerType = TypeOf(Owner);
	If OwnerType=Type("FormTable") Then
		CurrentData = Owner.CurrentData;
		If CurrentData<>Undefined Then
			ChoiceInitialValue = CurrentData[IdentificatorAttributeName];
		EndIf;
		
	ElsIf OwnerType=Type("ManagedForm") Then
		ChoiceInitialValue = Owner[IdentificatorAttributeName];
		
	EndIf;
	
	If ChoiceParameters<>Undefined Then
		If ChoiceParameters.Property("ChoiceFoldersAndItems") Then
			ChoiceFoldersAndItems = ChoiceParameters.ChoiceFoldersAndItems;
		EndIf;
	EndIf;
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters",        ExternalConnectionParameters);
	FormParameters.Insert("CorrespondentInfobaseTableFullName", TableName);
	FormParameters.Insert("ChoiceInitialValue",            ChoiceInitialValue);
	FormParameters.Insert("AttributeName",                       AttributeName);
	FormParameters.Insert("ChoiceFoldersAndItems",               ChoiceFoldersAndItems);
	
	OpenForm("CommonForm.CorrespondentInfobaseObjectSelection", FormParameters, Owner);
	
EndProcedure

// Handler of the item selection for settings form of the base-correspondent node during
// exchange setting via the external connection.
//
// Parameters:
// AttributeName - String - Name form attribute.
// TableName - String - Full name of metadata object.
// Owner - ManagedForm - Selection form of base-correspondent items.
// ExternalConnectionParameters - Structure - external connection settings.
// ChoiceParameters - Structure - Selection parameters structure.
//
Procedure CorrespondentInfobaseObjectSelectionHandlerFill(Val AttributeName, Val TableName, Val Owner,
	Val ExternalConnectionParameters, Val ChoiceParameters=Undefined) Export
	
	IdentificatorAttributeName = AttributeName + "_Key";
	
	ChoiceInitialValue = Undefined;
	ChoiceFoldersAndItems    = Undefined;
	
	CurrentData = Owner.CurrentData;
	If CurrentData<>Undefined Then
		ChoiceInitialValue = CurrentData[IdentificatorAttributeName];
	EndIf;
	
	StandardProcessing = False;
	
	If ChoiceParameters<>Undefined Then
		If ChoiceParameters.Property("ChoiceFoldersAndItems") Then
			ChoiceFoldersAndItems = ChoiceParameters.ChoiceFoldersAndItems;
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters",        ExternalConnectionParameters);
	FormParameters.Insert("CorrespondentInfobaseTableFullName", TableName);
	FormParameters.Insert("ChoiceInitialValue",            ChoiceInitialValue);
	FormParameters.Insert("CloseOnChoice",                 False);
	FormParameters.Insert("AttributeName",                       AttributeName);
	FormParameters.Insert("ChoiceFoldersAndItems",               ChoiceFoldersAndItems);
	
	OpenForm("CommonForm.CorrespondentInfobaseObjectSelection", FormParameters, Owner);
EndProcedure

// Handler of the item selection processor for settings form of the base-correspondent node
// during exchange setting via the external connection.
//
// Parameters:
// Item - ManagedForm, FormTable - Item for selection processor.
// ValueSelected - see description of the SelectedValue parameter of the ChoiceProcessing events.
// FormDataCollection - FormDataCollection - For selection from list mode.
//
Procedure CorrespondentInfobaseObjectSelectionProcessingHandler(Val Item, Val ValueSelected, Val FormDataCollection=Undefined) Export
	
	If TypeOf(ValueSelected)<>Type("Structure") Then
		Return;
	EndIf;
	
	IdentificatorAttributeName = ValueSelected.AttributeName + "_Key";
	RepresentationAttributeName  = ValueSelected.AttributeName;
	
	PointType = TypeOf(Item);
	If PointType=Type("FormTable") Then
		
		If ValueSelected.PickMode Then
			If FormDataCollection<>Undefined Then
				Filter = New Structure(IdentificatorAttributeName, ValueSelected.ID);
				ExistingRows = FormDataCollection.FindRows(Filter);
				If ExistingRows.Count() > 0 Then
					Return;
				EndIf;
			EndIf;
			
			Item.AddLine();
		EndIf;
		
		CurrentData = Item.CurrentData;
		If CurrentData<>Undefined Then
			CurrentData[IdentificatorAttributeName] = ValueSelected.ID;
			CurrentData[RepresentationAttributeName]  = ValueSelected.Presentation;
		EndIf;
		
	ElsIf PointType=Type("ManagedForm") Then
		Item[IdentificatorAttributeName] = ValueSelected.ID;
		Item[RepresentationAttributeName]  = ValueSelected.Presentation;
		
	EndIf;
	
EndProcedure

// Checks if the "Use" check box is selected for all table rows.
//
// Table - ValueTable - checked table.
//
Function AllRowsMarkedInTable(Table) Export
	
	For Each Item IN Table Do
		
		If Item.Use = False Then
			
			Return False;
			
		EndIf;
		
	EndDo;
	
	Return True;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service functions-properties.

// Returns max allowed fields
// quantities that are displayed in IB objects match assistant.
//
// Returns:
//     Number - max quantity of fields for match
//
Function MaximumQuantityOfFieldsOfObjectMapping() Export
	
	Return 5;
	
EndFunction

// Returns structure of the data import statuses.
//
Function PagesOfDataImportStatus() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ImportStateUndefined");
	Structure.Insert("Error",       "ImportStateError");
	Structure.Insert("Success",        "ImportStateSuccess");
	Structure.Insert("Execution",   "ImportStateExecution");
	
	Structure.Insert("Warning_ExchangeMessageHasBeenPreviouslyReceived", "ImportStateWarning");
	Structure.Insert("CompletedWithWarnings",                     "ImportStateWarning");
	Structure.Insert("Error_MessageTransport",                      "ImportStateError");
	
	Return Structure;
EndFunction

// Returns structure of the data export statuses.
//
Function PagesOfDataDumpStatus() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ExportStateUndefined");
	Structure.Insert("Error",       "ExportStateError");
	Structure.Insert("Success",        "ExportStateSuccess");
	Structure.Insert("Execution",   "ExportStateExecution");
	
	Structure.Insert("Warning_ExchangeMessageHasBeenPreviouslyReceived", "ExportStateWarning");
	Structure.Insert("CompletedWithWarnings",                     "ExportStateWarning");
	Structure.Insert("Error_MessageTransport",                      "ExportStateError");
	
	Return Structure;
EndFunction

// Returns structure with the name of data import field hyperlink.
//
Function HyperlinkHeadersOfDataImport() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined",               NStr("en='Data receiving has not been performed';ru='Получение данных не выполнялось'"));
	Structure.Insert("Error",                     NStr("en='Failed to receive the data';ru='Не удалось получить данные'"));
	Structure.Insert("CompletedWithWarnings", NStr("en='Data is received with notifications';ru='Данные получены с предупреждениями'"));
	Structure.Insert("Success",                      NStr("en='Data are successfully received';ru='Данные успешно получены'"));
	Structure.Insert("Execution",                 NStr("en='Receiving data...';ru='Выполняется получение данных...'"));
	
	Structure.Insert("Warning_ExchangeMessageHasBeenPreviouslyReceived", NStr("en='No new data to be received';ru='Нет новых данных для получения'"));
	Structure.Insert("Error_MessageTransport",                      NStr("en='Failed to receive the data';ru='Не удалось получить данные'"));
	
	Return Structure;
EndFunction

// Returns structure with the name of data export field hyperlink.
//
Function HyperlinkHeadersOfDataDump() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", NStr("en='Data sending has not been performed';ru='Отправка данных не выполнялась'"));
	Structure.Insert("Error",       NStr("en='Failed to send data';ru='Не удалось отправить данные'"));
	Structure.Insert("Success",        NStr("en='Data are successfully sent';ru='Данные успешно отправлены'"));
	Structure.Insert("Execution",   NStr("en='Data sending is in progress...';ru='Выполняется отправка данных...'"));
	
	Structure.Insert("Warning_ExchangeMessageHasBeenPreviouslyReceived", NStr("en='Data sent with notifications';ru='Данные отправлены с предупреждениями'"));
	Structure.Insert("CompletedWithWarnings",                     NStr("en='Data sent with notifications';ru='Данные отправлены с предупреждениями'"));
	Structure.Insert("Error_MessageTransport",                      NStr("en='Failed to send data';ru='Не удалось отправить данные'"));
	
	Return Structure;
EndFunction

// Opens form or hyperlink with the detailed data synchronization description.
//
Procedure OpenDetailedDescriptionOfSynchronization(RefToDetailedDescription) Export
	
	If Upper(Left(RefToDetailedDescription, 4)) = "HTTP" Then
		
		GotoURL(RefToDetailedDescription);
		
	Else
		
		OpenForm(RefToDetailedDescription);
		
	EndIf;
	
EndProcedure

// Opens form for proxy server parameters input.
//
Procedure OpenProxyServerParameterForm() Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleGetFilesFromInternetClient = CommonUseClient.CommonModule("GetFilesFromInternetClient");
		ModuleGetFilesFromInternetClient.OpenProxyServerParameterForm();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Procedure-handler of application client session start.
// If IB is started for the subordinate
// node and it needs to import exchange
// message again, then user is offered to
// decide whether to import again or continue without import.
// 
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If Not ClientParameters.Property("RetryDataExportExchangeMessagesBeforeStart") Then
		Return;
	EndIf;
	
	Parameters.InteractiveDataProcessor = New NotifyDescription(
		"InteractiveProcessorDataExchangeMessageReuloadBeforeStart", ThisObject);
	
EndProcedure

// Procedure-handler of application client session start.
// If the first IB start is executed for
// the subordinate RIB node, then assistant form of data exchange creation is opened.
// 
Procedure OnStart(Parameters) Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientWorkParameters.Property("OpenCommunicationAssistantToConfigureSlaveNode") Then
		
		For Each Window IN GetWindows() Do
			If Window.Main Then
				Window.Activate();
				Break;
			EndIf;
		EndDo;
		
		FormParameters = New Structure("ExchangePlanName, IsContinuedInDIBSubordinateNodeSetup", ClientWorkParameters.DIBExchangePlanName, True);
		OpenForm("DataProcessor.DataExchangeCreationAssistant.Form.Form", FormParameters, , , , , , FormWindowOpeningMode.LockWholeInterface);
	EndIf;
	
EndProcedure

Procedure AfterSystemOperationStart() Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If Not ClientWorkParameters.CanUseSeparatedData OR ClientWorkParameters.DataSeparationEnabled Then
		Return;
	EndIf;
		
	If Not ClientWorkParameters.Property("OpenCommunicationAssistantToConfigureSlaveNode")
		AND ClientWorkParameters.Property("CheckSubordinatedNodeConfigurationUpdateNecessity") Then
		
		AttachIdleHandler("CheckSubordinatedNodeConfigurationUpdateNecessityOnStart", 1, True);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Only for internal use.
//
Procedure InteractiveProcessorDataExchangeMessageReuloadBeforeStart(Parameters, NotSpecified) Export
	
	Form = OpenForm(
		"InformationRegister.ExchangeTransportSettings.Form.DataSynchronizationBeforeStartingAgain", , , , , ,
		New NotifyDescription(
			"AfterFormClosingDataReSynchronizationBeforeStart", ThisObject, Parameters));
	
	If Form = Undefined Then
		AfterFormClosingDataReSynchronizationBeforeStart("Continue", Parameters);
	EndIf;
	
EndProcedure

// Only for internal use. Continue the procedure.
// InteractiveProcessorReuloadDataExchangeMessageBeforeStart.
//
Procedure AfterFormClosingDataReSynchronizationBeforeStart(Result, Parameters) Export
	
	If Result <> "Continue" Then
		Parameters.Cancel = True;
	Else
		Parameters.ReceivedClientParameters.Insert(
			"RetryDataExportExchangeMessagesBeforeStart");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Only for internal use. Continue the procedure.
// SettingFormBeforeClose.
//
Procedure SettingFormBeforeCloseEnd(Response, Form) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Form.Modified = False;
	Form.Close();
	
	// Clear reuse cache for possible COM connections reset.
	RefreshReusableValues();
EndProcedure

// Opens file in the associated application of the operating system.
//
// Parameters:
//     Object               - Arbitrary - Object from which by attachment file name for opening will be received the property name.
//     PropertyName          - String       - Object property name from which attachment file name for opening will be received.
//     StandardProcessing - Boolean       - Check box of the standard processor, set to False.
//
Procedure HandlerOfOpeningOfFileOrDirectory(Object, PropertyName, StandardProcessing = False) Export
	StandardProcessing = False;
	
	FullFileName = Object[PropertyName];
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("FileOrDirectoryOpeningHandlerAfterApplicationStart", ThisObject);
	BeginRunningApplication(Notification, FullFileName);
	
EndProcedure

// Procedure continued (see above).
Procedure FileOrDirectoryOpeningHandlerAfterApplicationStart(ReturnCode, AdditionalParameters) Export
	// No processing is required.
EndProcedure

// Opens dialog for file dialog selection requesting for setting of work with files extension.
//
// Parameters:
//     Object                - Arbitrary       - Object to which the selected property will be set.
//     PropertyName           - String             - Property name with the attachment file name set to object. Initial
//                                                  value source.
//     StandardProcessing  - Boolean             - Check box of the standard processor, set to False.
//     DialogueParameters      - Structure          - Optional additional parameters of directory selection dialog.
//     CompletionAlert  - NotifyDescription - Optional alert that will be called
//                                                  with the following parameters.:
//                                 Result               - String - Selected file (rows array if
//                                                                    there is a multi selection);
//                                 AdditionalParameters - Undefined
//
Procedure FileDirectoryChoiceHandler(Object, Val PropertyName, StandardProcessing = False, Val DialogueParameters = Undefined, CompletionAlert = Undefined) Export
	StandardProcessing = False;
	
	DialogDefaults = New Structure;
	DialogDefaults.Insert("Title", NStr("en='Specify the folder!';ru='Укажите каталог'") );
	
	SetStructureDefaultValues(DialogueParameters, DialogDefaults);
	
	WarningText = NStr("en='For this operation you need to install extension for 1C:Enterprise web client.';ru='Для данной операции необходимо установить расширение для веб-клиента 1С:Предприятие.'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Object",               Object);
	AdditionalParameters.Insert("PropertyName",          PropertyName);
	AdditionalParameters.Insert("DialogueParameters",     DialogueParameters);
	AdditionalParameters.Insert("CompletionAlert", CompletionAlert);
	
	Notification = New NotifyDescription("FileDirectorySelectionHandlerEnd", ThisObject, AdditionalParameters);
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(Notification, WarningText, False);
EndProcedure

// Handler of the modeless directory selection dialog end.
//
Procedure FileDirectorySelectionHandlerEnd(Val Result, Val AdditionalParameters) Export
	If Result <> True Then
		Return;
	EndIf;
	
	PropertyName = AdditionalParameters.PropertyName;
	Object      = AdditionalParameters.Object;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FillPropertyValues(Dialog, AdditionalParameters.DialogueParameters);
	
	Dialog.Directory = Object[PropertyName];
	If Dialog.Choose() Then
		Object[PropertyName] = Dialog.Directory;
		
		If AdditionalParameters.CompletionAlert <> Undefined Then
			Result = ?(Dialog.Multiselect, Dialog.SelectedFiles, Dialog.Directory);
			ExecuteNotifyProcessing(AdditionalParameters.CompletionAlert, Result);
		EndIf;
	EndIf;
	
EndProcedure

// Opens dialog for file selection requesting for extension setting for work with files.
//
// Parameters:
//     Object                - Arbitrary       - Object to which the selected property will be set.
//     PropertyName           - String             - Property name with the attachment file name set to object. Initial
//                                                  value source.
//     StandardProcessing  - Boolean             - Check box of the standard processor, set to False.
//     DialogueParameters      - Structure          - Optional additional parameters of file selection dialog.
//     CompletionAlert  - NotifyDescription - Optional alert that will be called
//                                                  with the following parameters.:
//                                 Result               - String - Selected file (rows array if
//                                                                    there is a multi selection);
//                                 AdditionalParameters - Undefined
//
//
Procedure FileChoiceHandler(Object, Val PropertyName, StandardProcessing = False, Val DialogueParameters = Undefined, CompletionAlert = Undefined) Export
	StandardProcessing = False;
	
	DialogDefaults = New Structure;
	DialogDefaults.Insert("Mode",                       FileDialogMode.Open);
	DialogDefaults.Insert("CheckFileExist", True);
	DialogDefaults.Insert("Title",                   NStr("en='Select the file';ru='Выберите файл'"));
	DialogDefaults.Insert("Multiselect",          False);
	DialogDefaults.Insert("Preview",     False);
	
	SetStructureDefaultValues(DialogueParameters, DialogDefaults);
	
	WarningText = NStr("en='For this operation you need to install extension for 1C:Enterprise web client.';ru='Для данной операции необходимо установить расширение для веб-клиента 1С:Предприятие.'");
	
	Notification = New NotifyDescription("FileChoiceHandlerEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Object",               Object);
	Notification.AdditionalParameters.Insert("PropertyName",          PropertyName);
	Notification.AdditionalParameters.Insert("DialogueParameters",     DialogueParameters);
	Notification.AdditionalParameters.Insert("CompletionAlert", CompletionAlert);
	
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(Notification, WarningText, False);
EndProcedure

// Handler of the modeless file selection dialog end.
//
Procedure FileChoiceHandlerEnd(Val Result, Val AdditionalParameters) Export
	If Result <> True Then
		Return;
	EndIf;
	
	PropertyName = AdditionalParameters.PropertyName;
	Object      = AdditionalParameters.Object;
	
	SelectionDialogParameters = AdditionalParameters.DialogueParameters;
	Dialog = New FileDialog(SelectionDialogParameters.Mode);
	FillPropertyValues(Dialog, SelectionDialogParameters);
	
	Dialog.FullFileName = Object[PropertyName];
	If Dialog.Choose() Then
		Object[PropertyName] = Dialog.FullFileName;
		
		If AdditionalParameters.CompletionAlert <> Undefined Then
			Result = ?(Dialog.Multiselect, Dialog.SelectedFiles, Dialog.FullFileName);
			ExecuteNotifyProcessing(AdditionalParameters.CompletionAlert, Result);
		EndIf;
	EndIf;
	
EndProcedure

// Passes files to server requesting for extension setting for work with files.
//
// Parameters:
//     CompletionAlert - NotifyDescription - Export procedure that will be called with the following parameters:
//                                Result               - Array - Contains stuctures with fields
//                                                                   Name, Storing, ErrorDescription for each file.
//                                AdditionalParameters - Undefined
//
//     FileNames          - Array                  - Files names array for pass.
//     FormID   - UUID - Parameter for storage.
//     WarningText  - String                  - Text of warning about the need
//                                                      to set work with files extension.
//
Procedure PassFilesToServer(CompletionAlert, Val FileNames, Val FormID = Undefined, Val WarningText = Undefined) Export
	
	DataFiles = New Array;
	HasEmpty   = False;
	
	For Each FileName IN FileNames Do
		FileDescription = New Structure("Name, Storing, ErrorDescription", FileName);
		If IsBlankString(FileName) Then
			HasEmpty = True;
			FileDescription.ErrorDescription = NStr("en='File not selected.';ru='Файл не выбран.'");
		EndIf;
		DataFiles.Add(FileDescription);
	EndDo;
	
	If HasEmpty Then
		ExecuteNotifyProcessing(CompletionAlert, DataFiles);
		Return;
	EndIf;

	Notification= New NotifyDescription("PassFileToServerEndExtensionConnection", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Notification",         CompletionAlert);
	Notification.AdditionalParameters.Insert("DataFiles",       DataFiles);
	Notification.AdditionalParameters.Insert("FormID", FormID);
	
	If WarningText = Undefined Then
		If FileNames.Count() = 1 Then
			WarningText = NStr("en='To send file to server, you need to install extension for 1C:Enterprise web client.';ru='Для передачи файла на сервер необходимо установить расширение для веб-клиента 1С:Предприятие.'");
		Else
			WarningText = NStr("en='To send files to server, you need to install extension for 1C:Enterprise web client.';ru='Для передачи файлов на сервер необходимо установить расширение для веб-клиента 1С:Предприятие.'");
		EndIf;
	EndIf;
	
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(Notification, WarningText, False);
EndProcedure

// Handler of the modeless file pass to server end.
// 
Procedure PassFileToServerEndExtensionConnection(Val Result, Val AdditionalParameters) Export
	If Not Result Then
		Return;
	EndIf;
	// Extension is successfully installed.
	
	ListForPassParametersFilling = New Structure;
	ListForPassParametersFilling.Insert("DataFiles", AdditionalParameters.DataFiles);
	ListForPassParametersFilling.Insert("ListForPass", New Array);
	ListForPassParametersFilling.Insert("HasErrors", False);
	ListForPassParametersFilling.Insert("PositionNumber", 0);
	AdditionalParameters.Insert("ListForPassParametersFilling", ListForPassParametersFilling);
	
	PassFileToServerEndExtensionConnectionFillListForPass(AdditionalParameters);
	
EndProcedure

// Procedure continued (see above).
// 
Procedure PassFileToServerEndExtensionConnectionFillListForPass(AdditionalParameters)
	
	ListForPassParametersFilling = AdditionalParameters.ListForPassParametersFilling;
	Path = ListForPassParametersFilling.DataFiles[ListForPassParametersFilling.PositionNumber].Name;
	Notification = New NotifyDescription(
		"PassFileToServerEndExtensionConnectionAfterFileInitialization",
		ThisObject,
		AdditionalParameters);
	
	CheckedFile = New File();
	CheckedFile.BeginInitialization(Notification, Path);
	
EndProcedure

// Procedure continued (see above).
// 
Procedure PassFileToServerEndExtensionConnectionAfterFileInitialization(File, AdditionalParameters) Export
	
	AdditionalParameters.ListForPassParametersFilling.Insert("File", File);
	Notification = New NotifyDescription(
		"PassFileToServerEndExtensionConnectionAfterFileExistenceCheck",
		ThisObject,
		AdditionalParameters);
	
	File.StartExistenceCheck(Notification);
	
EndProcedure

// Procedure continued (see above).
// 
Procedure PassFileToServerEndExtensionConnectionAfterFileExistenceCheck(Exists, AdditionalParameters) Export
	
	ListForPassParametersFilling = AdditionalParameters.ListForPassParametersFilling;
	If Not Exists Then
		ListForPassParametersFilling.HasErrors = True;
		Item = ListForPassParametersFilling.DataFiles[ListForPassParametersFilling.PositionNumber];
		Item.ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File %1 does not exist or there is no access to it.';ru='Файл ""%1"" не существует или к нему нет доступа'"), Item.Name);
			
		// Go to the next file or complete list filling for passing.
		If ListForPassParametersFilling.PositionNumber = ListForPassParametersFilling.DataFiles.UBound() Then
			PassFileToServerActionAfterFillingPassListConnectEnd(AdditionalParameters);
		Else
			ListForPassParametersFilling.PositionNumber = ListForPassParametersFilling.PositionNumber + 1;
			PassFileToServerEndExtensionConnectionFillListForPass(AdditionalParameters);
		EndIf;
		
	Else
		
		Notification = New NotifyDescription(
			"PassFileToServerEndExtensionConnectionAfterCheckOnDirectory",
			ThisObject,
			AdditionalParameters);
		
		AdditionalParameters.ListForPassParametersFilling.File.StartCheckingIsDirectory(Notification);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
// 
Procedure PassFileToServerEndExtensionConnectionAfterCheckOnDirectory(IsDirectory, AdditionalParameters) Export
	
	ListForPassParametersFilling = AdditionalParameters.ListForPassParametersFilling;
	Item = ListForPassParametersFilling.DataFiles[ListForPassParametersFilling.PositionNumber];
	
	If IsDirectory Then
		ListForPassParametersFilling.HasErrors = True;
		Item.ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File %1 does not exist or there is no access to it.';ru='Файл ""%1"" не существует или к нему нет доступа'"), Item.Name);
	Else
		ListForPassParametersFilling.ListForPass.Add(New TransferableFileDescription(Item.Name));
	EndIf;
	
	// Go to the next file or complete list filling for passing.
	If ListForPassParametersFilling.PositionNumber = ListForPassParametersFilling.DataFiles.UBound() Then
		PassFileToServerActionAfterFillingPassListConnectEnd(AdditionalParameters);
	Else
		ListForPassParametersFilling.PositionNumber = ListForPassParametersFilling.PositionNumber + 1;
		PassFileToServerEndExtensionConnectionFillListForPass(AdditionalParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
// 
Procedure PassFileToServerActionAfterFillingPassListConnectEnd(AdditionalParameters)
	
	ListForPassParametersFilling = AdditionalParameters.ListForPassParametersFilling;
	
	If ListForPassParametersFilling.HasErrors Then
		
		// Notify the original caller.
		ExecuteNotifyProcessing(AdditionalParameters.Notification, AdditionalParameters.DataFiles);
		
	Else
		PlacedFiles = New Array;
		
		NotifyDescription = New NotifyDescription("PassFileToServerEndActionExtensionConnectionAfterPlacingFiles",
			ThisObject, AdditionalParameters);
		
		BeginPuttingFiles(
			NotifyDescription,
			ListForPassParametersFilling.ListForPass,,
			False,
			AdditionalParameters.FormID);
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
// 
Procedure PassFileToServerEndActionExtensionConnectionAfterPlacingFiles(PlacedFiles, AdditionalParameters) Export
	
	For IndexOf = 0 To PlacedFiles.UBound() Do
		AdditionalParameters.DataFiles[IndexOf].Location = PlacedFiles[IndexOf].Location;
	EndDo;
	
	// Notify the original caller.
	ExecuteNotifyProcessing(AdditionalParameters.Notification, AdditionalParameters.DataFiles);
	
EndProcedure

// Interactively passes file to server without extension for work with files.
//
// Parameters:
//     CompletionAlert - NotifyDescription - Export procedure that will be called
//                                                 with the following parameters:
//                                Result               - Structure with fields Name, Storing, ErrorDescription.
//                                AdditionalParameters - Undefined
//
//     DialogueParameters     - Structure                       - Optional additional parameters of
//                                                              files selection dialog.
//     FormID   - String, UUID - Parameter for storage.
//
Procedure SelectAndSendFileToServer(CompletionAlert, Val DialogueParameters = Undefined, Val FormID = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CompletionAlert", CompletionAlert);
	AdditionalParameters.Insert("DialogueParameters", DialogueParameters);
	AdditionalParameters.Insert("FormID", FormID);
	
	AlertFileOperationsConnectionExtension = New NotifyDescription(
		"SelectAndPassFileToServerAfterWorksWithFilesExtensionConnection",
		ThisObject, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(AlertFileOperationsConnectionExtension);

EndProcedure

// Procedure continued (see above).
// 
Procedure SelectAndPassFileToServerAfterWorksWithFilesExtensionConnection(Attached, AdditionalParameters) Export
	
	Result  = New Structure("Name, Storing, ErrorDescription");
	AdditionalParameters.Insert("Result", Result);
	Notification = New NotifyDescription("SelectAndPassFilesToServerEnd", ThisObject, AdditionalParameters);
	
	If Not Attached Then
		// You do not have extension, use selection dialog from StartFileLocating.
		BeginPutFile(Notification, , , True, AdditionalParameters.FormID);
		Return;
	EndIf;
	
	// You have extension, use dialog.
	DialogDefaults = New Structure;
	DialogDefaults.Insert("CheckFileExist", True);
	DialogDefaults.Insert("Title",                   NStr("en='Select the file';ru='Выберите файл'"));
	DialogDefaults.Insert("Multiselect",          False);
	DialogDefaults.Insert("Preview",     False);
	
	SetStructureDefaultValues(AdditionalParameters.DialogueParameters, DialogDefaults);
	
	ChoiceDialog = New FileDialog(FileDialogMode.Open);
	FillPropertyValues(ChoiceDialog, AdditionalParameters.DialogueParameters);
	
	SelectionDialogAlertDescription = New NotifyDescription("SelectAndPassFileToServerAfterSelectionInDialog", ThisObject, AdditionalParameters);
	ChoiceDialog.Show(SelectionDialogAlertDescription);

EndProcedure

// Procedure continued (see above).
// 
Procedure SelectAndPassFileToServerAfterSelectionInDialog(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined
		AND SelectedFiles.Count() = 1 Then
		
		Notification = New NotifyDescription("SelectAndPassFilesToServerEnd", ThisObject, AdditionalParameters);
		BeginPutFile(Notification, , SelectedFiles[0], False, AdditionalParameters.FormID);
	EndIf;
	
EndProcedure

// Handler of modeless selection end and pass files to server.
//
Procedure SelectAndPassFilesToServerEnd(Val Successfully, Val Address, Val SelectedFileName, Val AdditionalParameters) Export
	If Not Successfully Then
		Return;
	EndIf;
	
	// Notify the original caller.
	Result = AdditionalParameters.Result;
	Result.Name      = SelectedFileName;
	Result.Location = Address;
	
	ExecuteNotifyProcessing(AdditionalParameters.CompletionAlert, Result);
EndProcedure

// Interactively starts file receipt from server without work with files extension.
//
// Parameters:
//     ReceivedFile   - Structure - File description for receipt. Contains properties Name and Storing.
//     DialogueParameters - Structure - Optional additional parameters of files selection dialog.
//
Procedure SelectAndSaveFileOnClient(Val ReceivedFile, Val DialogueParameters = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ReceivedFile", ReceivedFile);
	AdditionalParameters.Insert("DialogueParameters", DialogueParameters);
	
	AlertFileOperationsConnectionExtension = New NotifyDescription(
		"SelectAndSaveFileOnClientAfterWorksWithFilesExtensionConnection",
		ThisObject, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(AlertFileOperationsConnectionExtension);
	
EndProcedure

// Procedure continued (see above).
// 
Procedure SelectAndSaveFileOnClientAfterWorksWithFilesExtensionConnection(Attached, AdditionalParameters) Export
	
	If Not Attached Then
		// You do not have extension, use selection dialog from ReceiveFile.
		GetFile(AdditionalParameters.ReceivedFile.Location, AdditionalParameters.ReceivedFile.Name, True);
		Return;
	EndIf;
	
	// Extension is available, use dialog.
	DialogDefaults = New Structure;
	DialogDefaults.Insert("Title",               NStr("en='Choose file for saving';ru='Выберите файл для сохранения'"));
	DialogDefaults.Insert("Multiselect",      False);
	DialogDefaults.Insert("Preview", False);
	
	SetStructureDefaultValues(AdditionalParameters.DialogueParameters, DialogDefaults);
	
	SaveDialog = New FileDialog(FileDialogMode.Save);
	FillPropertyValues(SaveDialog, AdditionalParameters.DialogueParameters);
	
	Received = New Array;
	Received.Add( New TransferableFileDescription(AdditionalParameters.ReceivedFile.Name,
		AdditionalParameters.ReceivedFile.Location) );
	
	FilesReceiptAlertDescription = New NotifyDescription(
		"SelectAndSaveFileOnClientAfterReceivingFiles",
		ThisObject, AdditionalParameters);
	
	BeginGettingFiles(FilesReceiptAlertDescription, Received, SaveDialog, True);
	
EndProcedure

// Procedure continued (see above).
// 
Procedure SelectAndSaveFileOnClientAfterReceivingFiles(ReceivedFiles, AdditionalParameters) Export
	// No processing is required.
EndProcedure

// Adds fields to the target structure if there are no fields there.
//
// Parameters:
//     Result           - Structure - Target structure.
//     DefaultValues - Structure - Values by default.
//
Procedure SetStructureDefaultValues(Result, Val DefaultValues) Export
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	For Each KeyValue IN DefaultValues Do
		PropertyName = KeyValue.Key;
		If Not Result.Property(PropertyName) Then
			Result.Insert(PropertyName, KeyValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

// Opens information register write form by the specified filter.
Procedure OpenInformationRegisterRecordFormByFilter(
												Filter,
												FillingValues,
												Val RegisterName,
												OwnerForm,
												Val FormName = "",
												FormParameters = Undefined,
												ClosingAlert = Undefined) Export
	
	Var RecordKey;
	
	EmptyRecordSet = DataExchangeServerCall.RecordSetRegisterIsEmpty(Filter, RegisterName);
	
	If Not EmptyRecordSet Then
		// Create using the type as you are on client.
		
		ValueType = Type("InformationRegisterRecordKey." + RegisterName);
		Parameters = New Array(1);
		Parameters[0] = Filter;
		
		RecordKey = New(ValueType, Parameters);
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("Key",               RecordKey);
	WriteParameters.Insert("FillingValues", FillingValues);
	
	If FormParameters <> Undefined Then
		
		For Each Item IN FormParameters Do
			
			WriteParameters.Insert(Item.Key, Item.Value);
			
		EndDo;
		
	EndIf;
	
	If IsBlankString(FormName) Then
		
		FormFullName = "InformationRegister.[RegisterName].RecordForm";
		FormFullName = StrReplace(FormFullName, "[RegisterName]", RegisterName);
		
	Else
		
		FormFullName = "InformationRegister.[RegisterName].Form.[FormName]";
		FormFullName = StrReplace(FormFullName, "[RegisterName]", RegisterName);
		FormFullName = StrReplace(FormFullName, "[FormName]", FormName);
		
	EndIf;
	
	// open IR write form
	If ClosingAlert <> Undefined Then
		OpenForm(FormFullName, WriteParameters, OwnerForm, , , , ClosingAlert);
	Else
		OpenForm(FormFullName, WriteParameters, OwnerForm);
	EndIf;
	
EndProcedure

// Opens form of conversion rules import and registration as a single file.
//
Procedure ImportDataSynchronizationRules(Val ExchangePlanName) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	
	OpenForm("InformationRegister.DataExchangeRules.Form.ImportDataSynchronizationRules", FormParameters,, ExchangePlanName);
	
EndProcedure

// Opens events log monitor with filter by export or upImport data events for the specified exchange plan node.
// 
Procedure GoToEventLogMonitorOfDataEvents(InfobaseNode, CommandExecuteParameters, ExchangeActionString) Export
	
	EventLogMonitorEvent = DataExchangeServerCall.GetEventLogMonitorMessageKeyByActionString(InfobaseNode, ExchangeActionString);
	
	FormParameters = New Structure;
	FormParameters.Insert("EventLogMonitorEvent", EventLogMonitorEvent);
	
	OpenForm("DataProcessor.EventLogMonitor.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

// Opens the events log monitor modally with the filter by events of export or import
// data for the specified exchange plan node.
//
Procedure GoToEventLogMonitorOfDataEventsModalRegistartion(InfobaseNode, Owner, ActionOnExchange) Export
	
	// server call
	FormParameters = DataExchangeServerCall.GetEventLogMonitorDataFilterStructureData(InfobaseNode, ActionOnExchange);
	
	OpenForm("DataProcessor.EventLogMonitor.Form", FormParameters, Owner);
	
EndProcedure

// Opens form of the data exchange for the specified exchange plan.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node for which it is required to open form;
//  Owner               - form-owner for opened form;
// 
Procedure ExecuteDataExchangeCommandProcessing(InfobaseNode, Owner,
		AddressForAccountPasswordRecovery = "", Val AutomaticSynchronization = Undefined) Export
	
	If AutomaticSynchronization = Undefined Then
		AutomaticSynchronization = (DataExchangeServerCall.VariantExchangeData(InfobaseNode) = "Synchronization");
	EndIf;
	
	If AutomaticSynchronization Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode", InfobaseNode);
		FormParameters.Insert("AddressForAccountPasswordRecovery", AddressForAccountPasswordRecovery);
		
		OpenForm("DataProcessor.DataExchangeExecution.Form.Form", FormParameters, Owner, InfobaseNode);
		
	Else
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode", InfobaseNode);
		FormParameters.Insert("ExtendedModeAdditionsExportings", True);
		
		FormName = "DataProcessor.InteractiveDataExchangeAssistant.Form";
		OpenForm(FormName, FormParameters, Owner, InfobaseNode);
		
	EndIf;
	
EndProcedure

// Opens form of interactive data exchange execution for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node for which it is required to open form;
//  Owner               - form-owner for opened form;
//
Procedure OpenObjectMappingAssistantCommandProcessing(InfobaseNode, Owner) Export
	
	// Open the objects match assistant form;
	// set infobase node as a parameter;
	FormParameters = New Structure("InfobaseNode", InfobaseNode);
	
	FormName = "DataProcessor.InteractiveDataExchangeAssistant.Form";
	OpenForm(FormName, FormParameters, Owner, InfobaseNode, , , ,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Opens scripts list form of data exchange execution for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - exchange plan node for which it is required to open form;
//  Owner               - form-owner for opened form;
//
Procedure CommandProcessingConfigureExchangeProcessingSchedule(InfobaseNode, Owner) Export
	
	FormParameters = New Structure("InfobaseNode", InfobaseNode);
	
	OpenForm("Catalog.DataExchangeScripts.Form.DataExchangesScheduleSetup", FormParameters, Owner);
	
EndProcedure

// Notifies all opened dynamic lists on need to update the displayed data.
//
Procedure RefreshAllOpenDynamicLists() Export
	
	Types = DataExchangeServerCall.AllConfigurationReferenceTypes();
	
	For Each Type IN Types Do
		
		NotifyChanged(Type);
		
	EndDo;
	
EndProcedure

// Opens monitor form of the data registered for sending.
//
Procedure OpenSentDataContent(Val InfobaseNode) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNode", InfobaseNode);
	FormParameters.Insert("ProhibitedToChooseExchangeNode", True);
	
	// Service data that can not be corrected if you access processor via command.
	FormParameters.Insert("NamesOfHiddenMetadata", New ValueList);
	FormParameters.NamesOfHiddenMetadata.Add("InformationRegister.InfobasesObjectsCompliance");
	
	DoNotUnloadRules = DataExchangeServerCall.NotExportedNodeObjectsMetadataNames(InfobaseNode);
	For Each MetadataName IN DoNotUnloadRules Do
		FormParameters.NamesOfHiddenMetadata.Add(MetadataName);
	EndDo;
	
	OpenForm("DataProcessor.ChangeRecordForExchangeData.Form", FormParameters,, InfobaseNode);
EndProcedure

// Deletes data synchronization setting.
//
Procedure DeleteSynchronizationSetting(Val InfobaseNode) Export
	
	QuestionText = NStr("en='Do you want to delete the data synchronization setting?';ru='Удалить настройку синхронизации данных?'");
	NotifyDescription = New NotifyDescription("DeleteSynchronizationSettingEnd", ThisObject, InfobaseNode);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

// Handler notification
//
Procedure DeleteSynchronizationSettingEnd(Response, InfobaseNode) Export
	
	If Response = DialogReturnCode.Yes Then
		
		ClosingAlert = New NotifyDescription("AfterPermissionsRemoval", ThisObject, InfobaseNode);
		Queries = DataExchangeServerCall.QueryOnClearPermissionToUseExternalResources(InfobaseNode);
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, Undefined, ClosingAlert);
		
	EndIf;
	
EndProcedure

Procedure AfterPermissionsRemoval(Result, InfobaseNode)Export
	
	If Result = DialogReturnCode.OK Then
		
		DataExchangeServerCall.DeleteSynchronizationSetting(InfobaseNode);
		Notify("Write_ExchangePlanNode");
		CloseForms("NodeForm");
		
	EndIf;
	
EndProcedure

// Closes all opened forms in the name of
// which there is the specified subrow and where modification check box is not set.
//
Procedure CloseForms(Val FormName)
	
	Windows = GetWindows();
	
	If Windows <> Undefined Then
		
		For Each Window IN Windows Do
			
			If Not Window.Main Then
				
				Form = Window.GetContent();
				
				If TypeOf(Form) = Type("ManagedForm")
					AND Not Form.Modified
					AND Find(Form.FormName, FormName) <> 0 Then
					
					Form.Close();
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Registers handler for new form opening immediately after closing the current one.
// 
Procedure OpenFormAfterClosingCurrentOne(CurrentForm, Val FormName, Val Parameters = Undefined, Val OpenParameters = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FormName",          FormName);
	AdditionalParameters.Insert("Parameters",         Parameters);
	AdditionalParameters.Insert("OpenParameters", OpenParameters);
	
	AdditionalParameters.Insert("PreviousClosingAlert",  CurrentForm.OnCloseNotifyDescription);
	
	CurrentForm.OnCloseNotifyDescription = New NotifyDescription("FormOpeningHandlerAfterClosingCurrentOne", ThisObject, AdditionalParameters);
EndProcedure

// Deffered opening
Procedure FormOpeningHandlerAfterClosingCurrentOne(Val ClosingResult, Val AdditionalParameters) Export
	
	OpenParameters = New Structure("Owner, Uniqueness, Window,  NavigationRef, ClosingAlertDescription, WindowOpeningMode");
	FillPropertyValues(OpenParameters, AdditionalParameters.OpenParameters);
	OpenForm(AdditionalParameters.FormName, AdditionalParameters.Parameters,
		OpenParameters.Owner, OpenParameters.Uniqueness, OpenParameters.Window, OpenParameters.URL, OpenParameters.OnCloseNotifyDescription, OpenParameters.WindowOpeningMode
	);
	
	If AdditionalParameters.PreviousClosingAlert <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.PreviousClosingAlert, ClosingResult);
	EndIf;
	
EndProcedure

// Opens message form about failed update due to error in PRO during infobase update.
//
Procedure MessageFormNameAboutUnsuccessfulUpdate(OpenableFormName) Export
	
	OpenableFormName = "InformationRegister.DataExchangeRules.Form.UnsuccessfulUpdateMessage";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls from other subsystems.

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Updates the data base configuration.
//
Procedure SetConfigurationUpdate(CompletingOfWorkSystem = False) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdateClient = CommonUseClient.CommonModule("ConfigurationUpdateClient");
		ModuleConfigurationUpdateClient.SetConfigurationUpdate(CompletingOfWorkSystem);
	Else
		OpenForm("CommonForm.AdditionalDetails", New Structure("Title,TemplateName",
		NStr("en='Setting update';ru='Установка обновления'"), "InstructionHowToInstallUpdateManually"));
	EndIf;
	
EndProcedure

// Used for the opening of the form of objects group change.
//
// Parameters:
//  List - FormTable - list form item containing references to the objects being changed.
//
Procedure OnSelectedObjectsChange(List) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.GroupObjectsChange") Then
		ModuleBatchObjectChangingClient = CommonUseClient.CommonModule("GroupObjectsChangeClient");
		ModuleBatchObjectChangingClient.ChangeSelected(List);
	EndIf;
	
EndProcedure

// Handler of the instruction opening event on how
// to resore/change data synchronization password with offline work place.
//
Procedure OnInstructionOpenHowToChangeDataSynchronizationPassword(Val AddressForAccountPasswordRecovery) Export
	
	If IsBlankString(AddressForAccountPasswordRecovery) Then
		
		ShowMessageBox(, NStr("en='Address for the account password recovery is not specified.';ru='Адрес для восстановления пароля учетной записи не задан.'"));
		
	Else
		
		GotoURL(AddressForAccountPasswordRecovery);
		
	EndIf;
	
EndProcedure

// Open a report about the version or about the versions comparison.
//
// Parameters:
// Refs - ref
// to the ComparedVersions object - Array - Contains the array
// of the compared versions if there is one version, then it opens the report on version.
//
Procedure OnReportFormByVersionOpen(Refs, ComparedVersions) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		ModuleObjectVersioningClient = CommonUseClient.CommonModule("ObjectVersioningClient");
		ModuleObjectVersioningClient.OnReportFormByVersionOpen(Refs, ComparedVersions);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

Procedure OnCloseExchangePlanNodeSettingsForm(Form, FormAttributeName)
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	For Each FilterSettings IN Form[FormAttributeName] Do
		
		If TypeOf(Form[FilterSettings.Key]) = Type("FormDataCollection") Then
			
			TabularSectionStructure = Form[FormAttributeName][FilterSettings.Key];
			
			For Each Item IN TabularSectionStructure Do
				
				TabularSectionStructure[Item.Key].Clear();
				
				For Each CollectionRow IN Form[FilterSettings.Key] Do
					
					TabularSectionStructure[Item.Key].Add(CollectionRow[Item.Key]);
					
				EndDo;
				
			EndDo;
			
		Else
			
			Form[FormAttributeName][FilterSettings.Key] = Form[FilterSettings.Key];
			
		EndIf;
		
	EndDo;
	
	Form.Modified = False;
	Form.Close(Form[FormAttributeName]);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// SERVICE PROGRAM INTERFACE OF INTERACTIVE EXPORT ADDITION
//

// Interactive addition dialogs processor.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - opening parameters form window.
//
// Returns:
//     Opened form
//
Function OpenFormAdditionsExportingsScriptNode(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	
	FormParameters = New Structure("ChoiceMode, CloseOnChoice", True, True);
	FormParameters.Insert("InfobaseNode", ExportAddition.InfobaseNode);
	FormParameters.Insert("FilterPeriod",           ExportAddition.NodeScriptFilterPeriod);
	FormParameters.Insert("Filter",                  ExportAddition.AdditionalRegistrationScriptSite);

	Return OpenForm(ExportAddition.ScriptParametersAdditions.VariantAdditionally.FormNameFilter,
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Interactive addition dialogs processor.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - opening parameters form window.
//
// Returns:
//     Opened form
//
Function OpenFormAdditionsExportingsAllDocuments(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("Title", NStr("en='Adding of the documents for sending';ru='Добавление документов для отправки'") );
	FormParameters.Insert("ActionSelect", 1);
	
	FormParameters.Insert("PeriodSelection", True);
	FormParameters.Insert("PeriodOfData", ExportAddition.AllDocumentsFilterPeriod);
	
	FormParameters.Insert("AddressLinkerSettings", ExportAddition.AddressLinkerAllDocuments);
	
	FormParameters.Insert("AddressOfFormStore", ExportAddition.AddressOfFormStore);
	
	Return OpenForm("DataProcessor.InteractiveExportChange.Form.PeriodAndFilterEditing", 
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Interactive addition dialogs processor.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - opening parameters form window.
//
// Returns:
//     Opened form
//
Function OpenFormAdditionsExportingsDetailedFilter(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("ActionSelect", 2);
	FormParameters.Insert("SettingsObject", ExportAddition);
	
	FormParameters.Insert("OpenByScenario", True);
	Return OpenForm("DataProcessor.InteractiveExportChange.Form", 
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Interactive addition dialogs processor.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - opening parameters form window.
//
// Returns:
//     Opened form
//
Function OpenFormAdditionsExportingsContentData(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("SettingsObject", ExportAddition);
	If ExportAddition.ExportVariant=3 Then
		FormParameters.Insert("SimplifiedMode", True);
	EndIf;
	
	Return OpenForm("DataProcessor.InteractiveExportChange.Form.ExportContent",
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Interactive addition dialogs processor.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - opening parameters form window.
//
// Returns:
//     Opened form
//
Function OpenFormAdditionsExportingsSaveSettings(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure("CloseOnChoice, ActionSelect", True, 3);
	
	// Do not pass linker there.
	ExportAddition.ComposerAllDocumentsFilter = Undefined;
	
	FormParameters.Insert("ViewCurrentSettings", ExportAddition.ViewCurrentSettings);
	FormParameters.Insert("Object", ExportAddition);
	
	Return OpenForm("DataProcessor.InteractiveExportChange.Form.SettingsContentEditing",
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Selection handler for export addition assistants form.
// Function analyzes whether the source is called from the export addition and operates AdditionDownImport data.
//
// Parameters:
//     ValueSelected  - Arbitrary                    - selection result.
//     ChoiceSource     - ManagedForm                - form that executed the selection.
//     ExportAddition - Structure, FormDataCollection - corrected settings of selection addition.
//
// Returns:
//     Boolean - True if the selection is called by one of export addition form, False - else.
//
Function ChoiceProcessingAdditionsExportings(Val ValueSelected, Val ChoiceSource, ExportAddition) Export
	
	If ChoiceSource.FormName="DataProcessor.InteractiveExportChange.Form.PeriodAndFilterEditing" Then
		// Change predefined selection "All documents", action is defined with the SelectedValue value.
		Return ExportAdditionChoiceProcessingModelOptions(ValueSelected, ExportAddition);
		
	ElsIf ChoiceSource.FormName="DataProcessor.InteractiveExportChange.Form.Form" Then
		// Change predefined selection "Detailed", action is defined with the SelectedValue value.
		Return ExportAdditionChoiceProcessingModelOptions(ValueSelected, ExportAddition);
		
	ElsIf ChoiceSource.FormName="DataProcessor.InteractiveExportChange.Form.SettingsContentEditing" Then
		// Settings, action is defined by the SelectedValue value.
		Return ExportAdditionChoiceProcessingModelOptions(ValueSelected, ExportAddition);
		
	ElsIf ChoiceSource.FormName=ExportAddition.ScriptParametersAdditions.VariantAdditionally.FormNameFilter Then
		// Change settings by the node script.
		Return ExportAdditionChoiceProcessingScriptNode(ValueSelected, ExportAddition);
		
	EndIf;
	
	Return False;
EndFunction

Procedure FillStructureData(Form)
	
	// Save the entered values of this application.
	SettingsStructure = Form.Context.FilterSsettingsAtNode;
	CorrespondingAttributes = Form.AttributeNames;
	
	For Each SettingItem IN SettingsStructure Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			
			AttributeName = CorrespondingAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item IN Form[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, Form[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	Form.Context.FilterSsettingsAtNode = SettingsStructure;
	
	// Save the entered values of another application.
	SettingsStructure = Form.Context.CorrespondentInfobaseNodeFilterSetup;
	CorrespondingAttributes = Form.CorrespondentBaseAttributeNames;
	
	For Each SettingItem IN SettingsStructure Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			
			AttributeName = CorrespondingAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item IN Form[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, Form[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	Form.Context.CorrespondentInfobaseNodeFilterSetup = SettingsStructure;
	
	Form.Context.Insert("ContextDetails", Form.ContextDetails);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// SERVICE PROCEDURES AND FUCTIONS OF INTERACTIVE EXPORT ADDITION
//

Function ExportAdditionChoiceProcessingModelOptions(Val ValueSelected, ExportAddition)
	
	Result = False;
	If TypeOf(ValueSelected)=Type("Structure") Then 
		
		If ValueSelected.ActionSelect=1 Then
			// Filter and period of all documents.
			ExportAddition.ComposerAllDocumentsFilter = Undefined;
			ExportAddition.AddressLinkerAllDocuments = ValueSelected.AddressLinkerSettings;
			ExportAddition.AllDocumentsFilterPeriod      = ValueSelected.PeriodOfData;
			Result = True;
			
		ElsIf ValueSelected.ActionSelect=2 Then
			// Detail setting
			ChoiceObject = GetFromTempStorage(ValueSelected.AddressOfObject);
			FillPropertyValues(ExportAddition, ChoiceObject, , "AdditionalRegistration");
			ExportAddition.AdditionalRegistration.Clear();
			For Each String IN ChoiceObject.AdditionalRegistration Do
				FillPropertyValues(ExportAddition.AdditionalRegistration.Add(), String);
			EndDo;
			Result = True;
			
		ElsIf ValueSelected.ActionSelect=3 Then
			// Settings were saved, you should remember the current name.
			ExportAddition.ViewCurrentSettings = ValueSelected.SettingRepresentation;
			Result = True;
			
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

Function ExportAdditionChoiceProcessingScriptNode(Val ValueSelected, ExportAddition)
	If TypeOf(ValueSelected)<>Type("Structure") Then 
		Return False;
	EndIf;
	
	ExportAddition.NodeScriptFilterPeriod        = ValueSelected.FilterPeriod;
	ExportAddition.NodeScriptFilterPresentation = ValueSelected.FilterPresentation;
	
	ExportAddition.AdditionalRegistrationScriptSite.Clear();
	For Each RowRegistration IN ValueSelected.Filter Do
		FillPropertyValues(ExportAddition.AdditionalRegistrationScriptSite.Add(), RowRegistration);
	EndDo;
	
	Return True;
EndFunction

#EndRegion
