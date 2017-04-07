&AtClient
Var ForceCloseForm, UserRepliedYesToMapping, SkipCurrentPageFailureControl, ExternalResourcesAllowed;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Parameterization of assistant by the name of exchange plan (mandatory).
	If Not Parameters.Property("ExchangePlanName", Object.ExchangePlanName) AND IsBlankString(Object.ExchangePlanName) Then
		
		Raise NStr("en='Data processor is not aimed for being used directly';ru='Обработка не предназначена для непосредственного использования.'");
		
	EndIf;
	
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	If Parameters.Property("AdditionalSetting") Then
		Object.ExchangeSettingsVariant = Parameters.AdditionalSetting;
	EndIf;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
	ExchangeWithServiceSetup = Parameters.Property("ExchangeWithServiceSetup");
	
	If GetFunctionalOption("SecurityProfilesAreUsed") Then
		Object.RefNew = ExchangePlans[Object.ExchangePlanName].GetRef();
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Setting the default values - common.
	InfobasePlacement          = "ConnectionUnavailable";
	InfobaseType                   = "Server";
	ExecuteDataExchangeNow             = True;
	CreateInitialImageNow = True;
	ExecuteInteractiveDataExchangeNow = True;
	
	Object.EMAILCompressOutgoingMessageFile = True;
	Object.FTPCompressOutgoingMessageFile   = True;
	Object.FTPConnectionPort = 21;
	
	// Default value for the type of exchange message transport.
	Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.FILE;
	
	// Checking the existence of the form of primary image creation for exchange plan.
	InitialImageCreationFormExists = (Metadata.ExchangePlans[Object.ExchangePlanName].Forms.Find("InitialImageCreationForm") <> Undefined);
	
	// Receive default values for the exchange plan.
	ExchangePlanManager = ExchangePlans[Object.ExchangePlanName];
	
	
	ShortDescription = ExchangePlanManager.BriefInformationOnExchange(Object.ExchangeSettingsVariant);
	RefToDetailedDescription = ExchangePlanManager.DetailedInformationAboutExchange(Object.ExchangeSettingsVariant);
	
	SettingsFilenameForReceiver = ExchangePlanManager.SettingsFilenameForReceiver() + ".xml";
	
	NodeConfigurationForm = "";
	DefaultValuesConfigurationForm = "";
	
	FilterSsettingsAtNode    = DataExchangeServer.FilterSsettingsAtNode(Object.ExchangePlanName, ConfigurationVersionCorrespondent, NodeConfigurationForm, Object.ExchangeSettingsVariant);
	DefaultValuesAtNode = DataExchangeServer.DefaultValuesAtNode(Object.ExchangePlanName, ConfigurationVersionCorrespondent, DefaultValuesConfigurationForm, Object.ExchangeSettingsVariant);
	ThisIsExchangePlanXDTO = DataExchangeServer.ThisIsExchangePlanXDTO(Object.ExchangePlanName);
	
	AccountingSettingsCommentLabel = ExchangePlanManager.AccountingSettingsSetupComment();
	
	NodesSettingFormContext = New Structure;
	
	NodeFiltersSettingsAvailable    = FilterSsettingsAtNode.Count() > 0
		AND DataExchangeServer.ExchangePlanSettingValue(Object.ExchangePlanName, "ShowFiltersSettingsOnNode", Object.ExchangeSettingsVariant);
	NodeDefaultValuesAvailable = DefaultValuesAtNode.Count() > 0
		AND DataExchangeServer.ExchangePlanSettingValue(Object.ExchangePlanName, "ShowDefaultValuesOnNode", Object.ExchangeSettingsVariant);
	
	Items.RestrictionsGroupBorder.Visible = NodeFiltersSettingsAvailable;
	Items.RestrictionsGroupBorder1.Visible = NodeFiltersSettingsAvailable;
	Items.RestrictionsGroupBorder2.Visible = NodeFiltersSettingsAvailable;
	Items.DefaultValueGroupBorder.Visible = NodeDefaultValuesAvailable;
	Items.DefaultValueGroupBorder1.Visible = NodeDefaultValuesAvailable;
	Items.DefaultValueGroupBorder2.Visible = NodeDefaultValuesAvailable;
	Items.DefaultValueGroupBorder6.Visible = NodeDefaultValuesAvailable;
	
	DataTransferRestrictionsDescriptionFull = DataExchangeServer.DataTransferRestrictionsDescriptionFull(Object.ExchangePlanName, FilterSsettingsAtNode, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	ValuesDescriptionFullByDefault       = DataExchangeServer.ValuesDescriptionFullByDefault(Object.ExchangePlanName, DefaultValuesAtNode, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	
	ThisNode = ExchangePlanManager.ThisNode();
	
	FormNameOfCreatingInitialImage = ExchangePlanManager.FormNameOfCreatingInitialImage();
	
	UsedTransportsOfExchangeMessages = DataExchangeReUse.UsedTransportsOfExchangeMessages(ThisNode);
	
	UseExchangeMessageTransportEMAIL = (UsedTransportsOfExchangeMessages.Find(Enums.ExchangeMessagesTransportKinds.EMAIL) <> Undefined);
	UseExchangeMessageTransportFILE  = (UsedTransportsOfExchangeMessages.Find(Enums.ExchangeMessagesTransportKinds.FILE) <> Undefined);
	UseExchangeMessageTransportFTP   = (UsedTransportsOfExchangeMessages.Find(Enums.ExchangeMessagesTransportKinds.FTP) <> Undefined);
	UseExchangeMessageTransportCOM   = (UsedTransportsOfExchangeMessages.Find(Enums.ExchangeMessagesTransportKinds.COM) <> Undefined);
	UseExchangeMessageTransportWS    = (UsedTransportsOfExchangeMessages.Find(Enums.ExchangeMessagesTransportKinds.WS) <> Undefined);
	
	// getting other settings
	Object.SourceInfobasePrefix           = GetFunctionalOption("InfobasePrefix");
	Object.SourceInfobasePrefixFilled = ValueIsFilled(Object.SourceInfobasePrefix);
	
	If Not Object.SourceInfobasePrefixFilled
		AND Not ExchangeWithServiceSetup Then
		
		Object.SourceInfobasePrefix = DataExchangeOverridable.InfobasePrefixByDefault();
		DataExchangeOverridable.OnDefineDefaultInfobasePrefix(Object.SourceInfobasePrefix);
		
	EndIf;
	
	AssistantOperationOption = "SetupNewDataExchange";
	
	If ExchangeWithServiceSetup Then
		
		AssistantRunMode = "ExchangeOverWebService";
		
	ElsIf UseExchangeMessageTransportCOM Then
		
		AssistantRunMode = "ExchangeOverExternalConnection";
		
	ElsIf UseExchangeMessageTransportWS Then
		
		AssistantRunMode = "ExchangeOverWebService";
		
	Else
		
		AssistantRunMode = "ExchangeOverOrdinaryCommunicationChannels";
		
	EndIf;
	
	ExchangePlanMetadata = Metadata.ExchangePlans[Object.ExchangePlanName];
	
	ExchangePlanSynonym = DataExchangeServer.ExchangePlanSettingValue(Object.ExchangePlanName, "CorrespondentConfigurationName", Object.ExchangeSettingsVariant);
	Title = DataExchangeServer.ExchangePlanSettingValue(Object.ExchangePlanName, "ExchangeCreationAssistantTitle", Object.ExchangeSettingsVariant);
	
	Object.ThisIsSettingOfDistributedInformationBase = DataExchangeReUse.ThisIsExchangePlanOfDistributedInformationBase(Object.ExchangePlanName);
	Object.IsStandardExchangeSetup               = DataExchangeReUse.IsStandardDataExchangeNode(ThisNode);
	
	FileInfobase = CommonUse.FileInfobase();
	
	Object.UseTransportParametersFILE  = True;
	Object.UseTransportParametersFTP   = False;
	Object.UseTransportParametersEMAIL = False;
	
	Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
	Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP;
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
	Items.UseTransportParametersFILE.Visible = UsedTransportsOfExchangeMessages.Count() > 1;
	Items.AssistantFileDescription.Title = StrReplace(Items.AssistantFileDescription.Title, "%CorrespondentApplication%", ExchangePlanSynonym);
	
	Object.ThisInfobaseDescription = DataExchangeServer.PredefinedExchangePlanNodeDescription(Object.ExchangePlanName);
	ThisInfobaseDescriptionSet = Not IsBlankString(Object.ThisInfobaseDescription);
	
	Items.ThisInfobaseDescription.ReadOnly = ThisInfobaseDescriptionSet;
	Items.ThisInfobaseDescription1.ReadOnly = ThisInfobaseDescriptionSet;
	
	If Not ThisInfobaseDescriptionSet Then
		
		Object.ThisInfobaseDescription = DataExchangeReUse.ThisInfobaseName();
		
	EndIf;
	
	Items.DecorationConnectionParametersWS.ExtendedTooltip.Title = StrReplace(
		Items.DecorationConnectionParametersWS.ExtendedTooltip.Title, "[InvalidCharacters]",
		DataExchangeClientServer.InadmissibleSymbolsInUserNameWSProxy());
		
	Items.ConnectionParametersToServiceDecoration.ExtendedTooltip.Title = StrReplace(
		Items.ConnectionParametersToServiceDecoration.ExtendedTooltip.Title, "[InvalidCharacters]",
		DataExchangeClientServer.InadmissibleSymbolsInUserNameWSProxy());
	
	SetVisibleAtServer();
	
	// Assign the values to explanatory notes at the bottom of the page to go by clicking "Next".
	
	// Explanatory note on the page of FILE setup assistant.
	If UseExchangeMessageTransportFILE Then
		
		If UseExchangeMessageTransportFTP Then
			
			Items.LabelNextFILE.Title = LabelNextFTP();
			
		ElsIf UseExchangeMessageTransportEMAIL Then
			
			Items.LabelNextFILE.Title = LabelNextEMAIL();
			
		Else
			
			Items.LabelNextFILE.Title = LabelNextSettings();
			
		EndIf;
		
	EndIf;
	
	// Explanatory note on the page of FTP setup assistant.
	If UseExchangeMessageTransportFTP Then
		
		If UseExchangeMessageTransportEMAIL Then
			
			Items.LabelNextFTP.Title = LabelNextEMAIL();
			
		Else
			
			Items.LabelNextFTP.Title = LabelNextSettings();
			
		EndIf;
		
	EndIf;
	
	// Explanatory note on the page of EMAIL setup assistant.
	If UseExchangeMessageTransportEMAIL Then
		
		Items.LabelNextEMAIL.Title = LabelNextSettings();
		
	EndIf;
	
	IsContinuedInDIBSubordinateNodeSetup = Parameters.Property("IsContinuedInDIBSubordinateNodeSetup");
	
	If Not IsContinuedInDIBSubordinateNodeSetup Then
		
		If DataExchangeServer.IsSubordinateDIBNode() Then
			
			DIBExchangePlanName = DataExchangeServer.MasterNode().Metadata().Name;
			
			If Object.ExchangePlanName = DIBExchangePlanName
				AND Not Constants.SubordinatedDIBNodeSettingsFinished.Get() Then
				
				IsContinuedInDIBSubordinateNodeSetup = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If IsContinuedInDIBSubordinateNodeSetup Then
		
		DataExchangeServer.OnContinuationDIBSubordinateNodeSetting();
		
		AssistantOperationOption = "ContinueDataExchangeSetup";
		
		DataProcessorObject = FormAttributeToValue("Object");
		DataProcessorObject.RunAssistantParametersImportFromConstant(False);
		ValueToFormAttribute(DataProcessorObject, "Object");
		
		Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
		Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP;
		Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
		
		Items.AssistantRunModeChoiceSwitchGroup.Title = NStr("en='Continuation of the data synchronization setting with the main node';ru='Продолжение настройки синхронизации данных с главным узлом'");
		
		Items.GroupBackup.Visible = False;
	EndIf;
	
	AssistantRunVariantOnChangeAtServer();
	
	AssistantRunModeOnChangeAtServer();
	
	EventLogMonitorMessageTextEstablishingConnectionToWebService = DataExchangeServer.EventLogMonitorMessageTextEstablishingConnectionToWebService();
	DataExchangeCreationEventLogMonitorMessageText = DataExchangeServer.DataExchangeCreationEventLogMonitorMessageText();
	
	LongOperation = False;
	PredefinedDataExchangeSchedule = "EveryHour";
	DataExchangeExecutionSchedule = PredefinedScheduleEveryHour();
	CustomDescriptionPresentation = String(DataExchangeExecutionSchedule);
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.AccessToInternetParameters.Visible = True;
		Items.ParametersInInternetAccess1.Visible = True;
		Items.AccessToInternetParameters2.Visible = True;
	Else
		Items.AccessToInternetParameters.Visible = False;
		Items.ParametersInInternetAccess1.Visible = False;
		Items.AccessToInternetParameters2.Visible = False;
	EndIf;
	
	Object.SecondInfobaseDescription = SecondInfobaseDescription(ThisNode);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClient.OfferToCreateBackups() Then
		
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Before you configure the synchronization it is recommended to <a href=""%1"">back up<a>.';ru='Перед настройкой синхронизации рекомендуется сделать <a href = %1 >резервную копию данных</a>.'"),
			"CreateBackup");
		
		FormattedString = StringFunctionsClientServer.FormattedString(Text);
		
		Items.BackupLabel.Title       = FormattedString;
		Items.BackupLabelService.Title = FormattedString;
		
	EndIf;
	
	If IsContinuedInDIBSubordinateNodeSetup Then
		WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
	EndIf;

	ForceCloseForm = False;
	UserRepliedYesToMapping = False;
	
	ExternalResourcesAllowed = New Structure;
	ExternalResourcesAllowed.Insert("AllowedCom", False);
	ExternalResourcesAllowed.Insert("AllowedFILE", False);
	ExternalResourcesAllowed.Insert("AllowedFTP", False);
	
	OSAuthenticationOnChange();
	
	InfobaseRunModeOnChange();
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If LongOperation Then
		ShowMessageBox(, NStr("en='Creating data synchronization.
		|Assistant work can not be completed.';ru='Выполняется создание синхронизации данных.
		|Работа помощника не может быть завершена.'"));
		Cancel = True;
		Return;
	EndIf;
	
	If ForceCloseForm = True Then
		Return;
	EndIf;
	
	If IsContinuedInDIBSubordinateNodeSetup Then
		WarningText = NStr("en='Setting the subordinate node of distributed infobase.
		|Decline to set up and use default values?';ru='Выполняется настройка подчиненного узла распределенной информационной базы.
		|Отказаться от настройки и использовать значения по умолчанию?'");
		
		AlertDescriptionDenyContinueDIB = New NotifyDescription("AlertDescriptionFailedToContinueDIB", ThisObject);
		CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, WarningText, "CloseFormWithoutWarnings", AlertDescriptionDenyContinueDIB);
		
		Return;
	EndIf;
	
	WarningText = NStr("en='Do you want to cancel the synchronization setup and exit from the assistant?';ru='Отменить настройку синхронизации и выйти из помощника?'");
	AlertDescriptionClose = New NotifyDescription("DeleteDataExchangeSetting", ThisObject);
	CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, WarningText, "CloseFormWithoutWarnings", AlertDescriptionClose);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify("DataExchangeCreationAssistantFormClosed");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ClosingObjectMappingForm" Then
		
		Cancel = False;
		
		Status(NStr("en='Gathering mapping information...';ru='Выполняется сбор информации сопоставления...'"));
		
		RefreshDataOfMappingStatisticsAtServer(Cancel, Parameter);
		
		If Cancel Then
			ShowMessageBox(, NStr("en='When getting the statistics information the errors occurred.';ru='При получении информации статистики возникли ошибки.'"));
		Else
			
			ExpandTreeOfInformationStatistics(Parameter.UniqueKey);
			
			Status(NStr("en='Information accumulation is completed';ru='Сбор информации завершен'"));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Page AssistantPageStart

&AtClient
Procedure DataExchangeSettingsForImportFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en='File of data synchronization settings (*.xml)';ru='Файл настроек синхронизации данных (*.xml)'") + "|*.xml" );
	
	Notification = New NotifyDescription("EndSelectingDataExchangeSettingsForImportFile", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogSettings, UUID);
EndProcedure

&AtClient
Procedure DataExchangeSettingsForImportFileNameOnChange(Item)
	
	DataExchangeSettingsFileSuccessfullyImported = False;
	
EndProcedure

&AtClient
Procedure AssistantOperationOptionManuallyOnChange(Item)
	
	AssistantRunVariantOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure AssistantOperationOptionFromFileOnChange(Item)
	
	AssistantRunVariantOnChangeAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page AssistantPageDataExchangeCreatedSuccessfullyEnd

&AtClient
Procedure PredefinedDataExchangeScheduleOnChange(Item)
	
	PredefinedDataExchangeScheduleOnValueChange();
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAutomaticallyOnChange(Item)
	
	ExecuteDataExchangeAutomaticallyOnValueChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page AssistantPageAssistantRunModeChoice

&AtClient
Procedure AssistantRunModeOnChange(Item)
	
	AssistantRunModeOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Object, "COMInfobaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryOpen(Item, StandardProcessing)
	
	DataExchangeClient.HandlerOfOpeningOfFileOrDirectory(Object, "COMInfobaseDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMInfobaseRunModeOnChange(Item)
	
	InfobaseRunModeOnChange();
	
EndProcedure

&AtClient
Procedure AuthentificationTypeOnChange(Item)
	
	OSAuthenticationOnChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page AssistantPageSettingTransportParametersFILE

&AtClient
Procedure FILEInformationExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not FileInfobase Then
		Return;
	EndIf;
	
	DataExchangeClient.FileDirectoryChoiceHandler(Object, "FILEInformationExchangeDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FILEInformationExchangeDirectoryOpening(Item, StandardProcessing)
	
	DataExchangeClient.HandlerOfOpeningOfFileOrDirectory(Object, "FILEInformationExchangeDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure UseTransportParametersFILEOnChange(Item)
	
	Items.TransportSettingsFILE.Enabled = Object.UseTransportParametersFILE;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page AssistantPageSettingTransportParametersFTP

&AtClient
Procedure UseTransportParametersFTPOnChange(Item)
	
	Items.TransportSettingsFTP.Enabled = Object.UseTransportParametersFTP;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page AssistantPageSettingTransportParametersEMAIL

&AtClient
Procedure UseTransportParametersEMAILOnChange(Item)
	
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersInformationStatisticsInformationTree

&AtClient
Procedure TreeOfInformationStatisticsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenMappingForm();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

////////////////////////////////////////////////////////////////////////////////
// Supplied part

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	UserRepliedYesToMapping = False;
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	
	RunCommandDone();
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure CommandHelp(Command)
	
	OpenFormHelp();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part

&AtClient
Procedure MapData(Command)
	
	OpenMappingForm();
	
EndProcedure

&AtClient
Procedure SetupDataExport(Command)
	
	ConnectionType = "WebService";
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSettingForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[NodesSetupForm]", NodesSettingForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
	FormParameters.Insert("ConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
	FormParameters.Insert("Settings", NodesSettingFormContext);
	
	Handler = New NotifyDescription("SetupDataExportEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure SetupDataExportEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		NodesSettingFormContext = Result;
		
		DataExportSettingsDescription = Result.ContextDetails;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataRegistrationRestrictionsSetting(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodeConfigurationForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[NodeConfigurationForm]", NodeConfigurationForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion",   ConfigurationVersionCorrespondent);
	FormParameters.Insert("FilterSsettingsAtNode", FilterSsettingsAtNode);
	FormParameters.Insert("SettingID", Object.ExchangeSettingsVariant);
	
	Handler = New NotifyDescription("DataRegistrationRestrictionsSetupEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure DataRegistrationRestrictionsSetupEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each FilterSettings IN FilterSsettingsAtNode Do
			
			FilterSsettingsAtNode[FilterSettings.Key] = Result[FilterSettings.Key];
			
		EndDo;
		
		// server call
		GetDataTransferRestrictionsDescription(FilterSsettingsAtNode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseRegistrationRestrictionSetupViaWebService(Command)
	
	CorrespondentInfobaseRegistrationRestrictionSetup("WebService");
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseRegistrationRestrictionSetupThroughExternalConnection(Command)
	
	CorrespondentInfobaseRegistrationRestrictionSetup("ExternalConnection");
	
EndProcedure

&AtClient
Procedure ValuesSettingByDefault(Command)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[DefaultValuesConfigurationForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[DefaultValuesSetupForm]", DefaultValuesConfigurationForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion",      ConfigurationVersionCorrespondent);
	FormParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
	FormParameters.Insert("SettingID",    Object.ExchangeSettingsVariant);
	
	Handler = New NotifyDescription("SettingDefaultValuesEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure SettingDefaultValuesEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each Setting IN DefaultValuesAtNode Do
			
			DefaultValuesAtNode[Setting.Key] = Result[Setting.Key];
			
		EndDo;
		
		// server call
		GetValuesDescriptionByDefault(DefaultValuesAtNode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDefaultValueSetupViaWebService(Command)
	
	CorrespondentInfobaseDefaultValueSetup("WebService");
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDefaultValueSetupViaExternalConnection(Command)
	
	CorrespondentInfobaseDefaultValueSetup("ExternalConnection");
	
EndProcedure

&AtClient
Procedure SaveDataExchangeSettingsFile(Command)
	
	Var TemporaryStorageAddress;
	
	Cancel = False;
	
	// server call
	DumpSettingsExchangeForReceiver(Cancel, TemporaryStorageAddress);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='When saving the data synchronization settings of the file, errors occurred.';ru='При сохранении файла настроек синхронизации данных возникли ошибки.'"));
		
	Else
		
		#If WebClient Then
			
			GetFile(TemporaryStorageAddress, SettingsFilenameForReceiver, True);
			
			Object.DataExchangeSettingsFileName = SettingsFilenameForReceiver;
			
		#Else
			
			AdditionalParameters = New Structure();
			AdditionalParameters.Insert("TemporaryStorageAddress", TemporaryStorageAddress);
			SuggestionText = NStr("en='To open a directory, you need to set an extension of working with files.';ru='Для открытия каталога необходимо необходимо установить расширение работы с файлами.'");
			Notification = New NotifyDescription("AfterWorksWithFilesExpansionCheck", ThisForm, AdditionalParameters);
			CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText);
			
		#EndIf
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterWorksWithFilesExpansionCheck(Result, AdditionalParameters) Export
	
	If Result Then
		
		Dialog = New FileDialog(FileDialogMode.Save);
		
		Dialog.Title      = NStr("en='Specify the attachment file name of the data synchronization settings';ru='Укажите имя файла настроек синхронизации данных'");
		Dialog.Extension     = "xml";
		Dialog.Filter         = "File of data synchronization settings(*.xml)|*.xml";
		Dialog.FullFileName = SettingsFilenameForReceiver;
		
		Notification = New NotifyDescription("AfterFileSelection", ThisForm, AdditionalParameters);
		Dialog.Show(Notification);
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
&AtClient
Procedure AfterFileSelection(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles.Count() = 1 Then
		Object.DataExchangeSettingsFileName = SelectedFiles[0];
		BinaryData = GetFromTempStorage(AdditionalParameters.TemporaryStorageAddress);
		DeleteFromTempStorage(AdditionalParameters.TemporaryStorageAddress);
		BinaryData.Write(Object.DataExchangeSettingsFileName);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFILEConnection(Command)
	
	ClosingAlert = New NotifyDescription("CheckFILEConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Object, False, True, False, False);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure CheckConnectionFTP(Command)
	
	ClosingAlert = New NotifyDescription("CheckFTPConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Object, False, False, False, True);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure CheckConnectionEMAIL(Command)
	
	CheckConnection("EMAIL");
	
EndProcedure

&AtClient
Procedure CheckCOMConnection(Command)
	
	ClosingAlert = New NotifyDescription("CheckCOMConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Object, True, False, False, False);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure CheckWSConnection(Command)
	
	ClosingAlert = New NotifyDescription("CheckWSConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Object, False, False, True, False);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure ChangeCustomSchedule(Command)
	
	Dialog = New ScheduledJobDialog(DataExchangeExecutionSchedule);
	NotifyDescription = New NotifyDescription("ChangeCustomScheduleEnd", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure ChangeCustomScheduleEnd(Schedule) Export
	
	If Schedule <> Undefined Then
		
		DataExchangeExecutionSchedule = Schedule;
		
		CustomDescriptionPresentation = String(DataExchangeExecutionSchedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DetailedDescription(Command)
	
	DataExchangeClient.OpenDetailedDescriptionOfSynchronization(RefToDetailedDescription);
	
EndProcedure

&AtClient
Procedure AccessToInternetParameters(Command)
	
	DataExchangeClient.OpenProxyServerParameterForm();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure RunCommandDone(Val CloseForm = True)
	
	Cancel = False;
	If AssistantRunMode = "ExchangeOverExternalConnection" Then
		FinishExchangeOverExternalConnectionSetup(CloseForm);
		
	ElsIf AssistantRunMode = "ExchangeOverWebService" Then
		FinishExchangeOverWebServiceSetup();
		
	ElsIf AssistantRunMode = "ExchangeOverOrdinaryCommunicationChannels" Then
		If AssistantOperationOption = "SetupNewDataExchange" Then
			FinishFirstExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel);
			
		ElsIf AssistantOperationOption = "ContinueDataExchangeSetup" Then
			FinishSecondExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel, CloseForm);
			
		EndIf;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	RefreshInterface();
	
	If CloseForm Then
		ForceCloseForm = True;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure BackupLabelDataProcessorNavigationRefs(Item, URL, StandardProcessing)
	
	If URL = "CreateBackup" Then
		
		StandardProcessing = False;
		
		CommonUseClient.OfferUserToBackup();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PredefinedDataExchangeScheduleOnValueChange()
	
	UseCustomSchedule = (PredefinedDataExchangeSchedule = "OtherSchedule");
	
	Items.CustomSchedulePages.CurrentPage = ?(UseCustomSchedule,
						Items.CustomSchedulePage,
						Items.EmptyCustomSchedulePage);
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAutomaticallyOnValueChange()
	
	Items.PredefinedSchedulePages.CurrentPage = ?(ExecuteDataExchangeAutomatically,
						Items.PredefinedSchedulePage,
						Items.NotAvailablePredefinedSchedulePage);
	
EndProcedure

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 1 Then
		
		GoToNumber = 1;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Execute the transition event handlers.
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Set the display of pages.
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying has not been defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Setting the current button by default.
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Go to event handlers.
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
		GoToRow = GoToRows[0];
		
		// Handler OnSkipForward.
		If Not IsBlankString(GoToRow.GoNextHandlerName)
			AND Not GoToRow.LongOperation Then
			
			ProcedureName = "Attachable_[HandlerName](Cancel)";
			ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
			
			Cancel = False;
			
			A = Eval(ProcedureName);
			
			If Cancel Then
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
		GoToRow = GoToRows[0];
		
		// Handler OnSkipBack.
		If Not IsBlankString(GoToRow.GoBackHandlerName)
			AND Not GoToRow.LongOperation Then
			
			ProcedureName = "Attachable_[HandlerName](Cancel)";
			ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
			
			Cancel = False;
			
			A = Eval(ProcedureName);
			
			If Cancel Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying has not been defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongOperation AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying has not been defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// Handler LongOperationProcessing.
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item IN FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Function CheckCOMConnectionOnServer()
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("COMAuthenticationOS");
	SettingsStructure.Insert("COMInfobaseOperationMode");
	SettingsStructure.Insert("COMInfobaseNameAtServer1CEnterprise");
	SettingsStructure.Insert("COMUserName");
	SettingsStructure.Insert("COMServerName1CEnterprise");
	SettingsStructure.Insert("COMInfobaseDirectory");
	SettingsStructure.Insert("COMUserPassword");
	FillPropertyValues(SettingsStructure, Object);
	
	Result = DataExchangeServer.InstallOuterDatabaseJoin(SettingsStructure);
	If Result.Join = Undefined Then
		Return Result.ErrorShortInfo;
	EndIf;
	Return ""; // successfully
	
EndFunction

&AtClient
Procedure AllowResourceEnd(Result, PermissionName) Export
	
	If Result = DialogReturnCode.OK Then
		
		ExternalResourcesAllowed[PermissionName] = True;
		ChangeGoToNumber(+1);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateQueryOnExternalResourcesUse(Val Object, AskCOM,
	AskFILE, AskWS, AskFTP)
	
	Record = InformationRegisters.ExchangeTransportSettings.CreateRecordManager();
	FillPropertyValues(Record, Object);
	Record.Node = Object.RefNew;
	
	PermissionsQueries = New Array;
	
	InformationRegisters.ExchangeTransportSettings.QueryOnExternalResourcesUse(PermissionsQueries,
		Record, AskCOM, AskFILE, AskWS, AskFTP);
	Return PermissionsQueries;
	
EndFunction

&AtClient
Procedure CheckCOMConnectionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		ClearMessages();
		
		If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase Then
			
			CommonUseClient.RegisterCOMConnector(False);
			
		EndIf;
		
		MessageText = CheckCOMConnectionOnServer();
		If IsBlankString(MessageText) Then
			MessageText = NStr("en='Connection verification is successfully completed.';ru='Проверка подключения успешно завершена.'");
		EndIf;
		ShowMessageBox(,MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFILEConnectionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		CheckConnection("FILE");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFTPConnectionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		CheckConnection("FTP");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckWSConnectionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Cancel = False;
		
		CheckWSConnectionAtClient(Cancel);
		
		If Not Cancel Then
			
			ShowMessageBox(, NStr("en='Connection has been successfully installed.';ru='Подключение успешно установлено.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function SecondInfobaseDescription(ThisNode)
	
	SecondInfobaseDescription = "";
	
	QueryText = "SELECT
		|	CreatedExchanges.Ref
		|FROM
		|	ExchangePlan.%ExchangePlanName% AS CreatedExchanges
		|WHERE
		|	CreatedExchanges.Description = &Description
		|	AND CreatedExchanges.Ref <> &ThisNode";
		
	QueryText = StrReplace(QueryText, "%ExchangePlanName%", Object.ExchangePlanName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Description", TrimAll(ExchangePlanSynonym));
	Query.SetParameter("ThisNode",     ThisNode.Ref);
	
	QueryResult = Query.Execute().Unload();
	
	If QueryResult.Count() = 0 Then
		SecondInfobaseDescription = ExchangePlanSynonym;
	Else
		CustomExchangeNumber = QueryResult.Count() + 1;
		SecondInfobaseDescription = TrimAll(ExchangePlanSynonym) + " (" + CustomExchangeNumber +")";
	EndIf;
	
	Return SecondInfobaseDescription;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Wait handlers

&AtClient
Procedure LongOperationIdleHandler()
	
	ErrorMessageString = "";
	
	ActionState = DataExchangeServerCall.LongOperationState(LongOperationID,
																		Object.WSURLWebService,
																		Object.WSUserName,
																		Object.WSPassword,
																		ErrorMessageString);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	ElsIf ActionState = "Executed" Then
		
		LongOperation = False;
		LongOperationFinished = True;
		
		CommandNext(Undefined);
		
	Else // Failed, Canceled
		
		WriteErrorInEventLogMonitor(ErrorMessageString, DataExchangeCreationEventLogMonitorMessageText);
		
		LongOperation = False;
		
		CommandBack(Undefined);
		
		QuestionText = NStr("en='Errors occurred during creation of data synchronization.
		|Do you want to open the event log?';ru='При создании синхронизации данных возникли ошибки.
		|Перейти в журнал регистрации?'");
		
		SuggestOpenEventLogMonitor(QuestionText, DataExchangeCreationEventLogMonitorMessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobTimeoutHandler()
	
	State = DataExchangeServerCall.JobState(LongOperationID);
	
	If State = "Active" Then
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	ElsIf State = "Completed" Then
		
		LongOperation = False;
		LongOperationFinished = True;
		
		CommandNext(Undefined);

	Else
		
		LongOperation = False;
		
		CommandBack(Undefined);
		
		QuestionText = NStr("en='Errors occurred during creation of data synchronization.
		|Do you want to open the event log?';ru='При создании синхронизации данных возникли ошибки.
		|Перейти в журнал регистрации?'");
		
		SuggestOpenEventLogMonitor(QuestionText, DataExchangeCreationEventLogMonitorMessageText);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Applied service procedures and functions.

&AtServer
Procedure ConfigureNewDataExchangeAtServer(Cancel, FilterSsettingsAtNode, DefaultValuesAtNode)
	
	Object.AssistantOperationOption = AssistantOperationOption;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.ExecuteNewDataExchangeConfigureActions(Cancel, FilterSsettingsAtNode, DefaultValuesAtNode);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure SetupNewDataExchangeOverExternalConnectionAtServer(Cancel, CorrespondentInfobaseNodeFilterSetup, CorrespondentInfobaseNodeDefaultValues)
	
	Object.AssistantOperationOption = AssistantOperationOption;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchangeOverExternalConnection(Cancel, FilterSsettingsAtNode, DefaultValuesAtNode, CorrespondentInfobaseNodeFilterSetup, CorrespondentInfobaseNodeDefaultValues);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	Items.ExecuteInteractiveDataExchangeNow.Title = StrReplace(Items.ExecuteInteractiveDataExchangeNow.Title, "%Application%", ExchangePlanSynonym);
	
EndProcedure

&AtServer
Procedure SetupNewDataExchangeAtServerOverWebService(Cancel)
	
	Object.AssistantOperationOption = AssistantOperationOption;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.SetUpNewDataExchangeOverWebServiceInTwoBases(Cancel,
																		NodesSettingFormContext,
																		LongOperation,
																		LongOperationID);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure UpdateDataExchangeSettings(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.UpdateDataExchangeSettings(Cancel,
												DefaultValuesAtNode,
												CorrespondentInfobaseNodeDefaultValues,
												LongOperation,
												LongOperationID);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure SetVisibleAtServer()
	
	Items.InformationExchangeDirectoryAtServerSelectionComment.Visible = Not FileInfobase;
	Items.FILEInformationExchangeDirectory.ChoiceButton = FileInfobase;
	
	Items.SourceInfobasePrefix.Visible = Not Object.SourceInfobasePrefixFilled;
	Items.SourceInfobasePrefix1.Visible = Not Object.SourceInfobasePrefixFilled;
	Items.TargetInfobasePrefix.Visible = False;
	
	Items.SourceInfobasePrefixExchangeOverWebService.Visible = Not Object.SourceInfobasePrefixFilled;
	Items.SourceInfobasePrefixExchangeOverWebService.ReadOnly = Object.SourceInfobasePrefixFilled;
	
	Items.SourceInfobasePrefixExchangeWithService.ReadOnly = Object.SourceInfobasePrefixFilled;
	Items.TargetInfobasePrefixExchangeWithService.ReadOnly = True;
	
	Items.FinalActionDisplayPages.CurrentPage = ?(Object.ThisIsSettingOfDistributedInformationBase,
					Items.ExecuteSubordinateNodeImageInitialCreationPage,
					Items.ExecuteDataExportForMappingPage);
	//
	If Object.ThisIsSettingOfDistributedInformationBase Then
		
		Items.AssistantRunModeChoiceSwitchGroup.Visible = False;
		
		Items.EndcapPrefix.Visible = False;
		Items.TargetInfobasePrefix1.ToolTipRepresentation = ToolTipRepresentation.None;
		
		Items.AssistantRunModeChoiceSwitchGroup.Title = NStr("en='Subordinate RIB node initial image creating';ru='Создание начального образа подчиненного узла РИБ'");
		
	EndIf;
	
EndProcedure

&AtClient
Function ResultPresentationMessagesTransport()
	
	If ExchangeWithServiceSetup Then
		
		Result = NStr("en='Parameters of connection to the
		|application in the service: %1';ru='Параметры подключения
		|к приложению в сервисе: %1'");
		Result = StringFunctionsClientServer.SubstituteParametersInString(Result, GetDescriptionOfSettingsOfExchangeTransport());
		
	Else
		
		Result = String(Object.ExchangeMessageTransportKind)
			+ NStr("en=', parameters:';ru=', параметры:'") + Chars.LF
			+ GetDescriptionOfSettingsOfExchangeTransport()
		;
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function ResultPresentationFiltersAtNode()
	
	Return ?(IsBlankString(DataTransferRestrictionsDescriptionFull), "", DataTransferRestrictionsDescriptionFull + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function CorrespondentInfobaseNodeFilterResultPresentation()
	
	Return ?(IsBlankString(CorrespondentInfobaseDataTransferRestrictionDetails), "", CorrespondentInfobaseDataTransferRestrictionDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function PresentationOfDefaultValueResultAtNode()
	
	Return ?(IsBlankString(ValuesDescriptionFullByDefault), "", ValuesDescriptionFullByDefault + Chars.LF + Chars.LF);
	
EndFunction

&AtClient
Function CorrespondentInfobaseNodeDefaultValueResultPresentation()
	
	Return ?(IsBlankString(CorrespondentInfobaseDefaultValueDetails), "", CorrespondentInfobaseDefaultValueDetails + Chars.LF + Chars.LF);
	
EndFunction

&AtServer
Procedure DumpSettingsExchangeForReceiver(Cancel, TemporaryStorageAddress)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.RunAssistantParametersDumpIntoTemporaryStorage(Cancel, TemporaryStorageAddress);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure ImportAssistantParameters(Cancel, TemporaryStorageAddress)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	DataProcessorObject.RunAssistantParametersImportFromTemporaryStorage(Cancel, TemporaryStorageAddress);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	Items.TransportSettingsFILE.Enabled  = Object.UseTransportParametersFILE;
	Items.TransportSettingsFTP.Enabled   = Object.UseTransportParametersFTP;
	Items.TransportSettingsEMAIL.Enabled = Object.UseTransportParametersEMAIL;
	
	If Not Cancel Then
		SettingsHasBeenRead = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure GetDataTransferRestrictionsDescription(FilterSsettingsAtNode)
	
	DataTransferRestrictionsDescriptionFull = DataExchangeServer.DataTransferRestrictionsDescriptionFull(Object.ExchangePlanName, FilterSsettingsAtNode, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	
EndProcedure

&AtServer
Procedure GetCorrespondentInfobaseDataTransferRestrictionDetails(CorrespondentInfobaseNodeFilterSetup)
	
	CorrespondentInfobaseDataTransferRestrictionDetails = DataExchangeServer.CorrespondentInfobaseDataTransferRestrictionDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeFilterSetup, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	
EndProcedure

&AtServer
Procedure GetValuesDescriptionByDefault(DefaultValuesAtNode)
	
	ValuesDescriptionFullByDefault = DataExchangeServer.ValuesDescriptionFullByDefault(Object.ExchangePlanName, DefaultValuesAtNode, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	
EndProcedure

&AtServer
Procedure GetCorrespondentInfobaseDefaultValueDetails(CorrespondentInfobaseNodeDefaultValues)
	
	CorrespondentInfobaseDefaultValueDetails = DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	
EndProcedure

&AtServerNoContext
Procedure InitializationOfDataExchangeAtClient(Cancel, InfobaseNode, ExchangeMessageTransportKind)
	
	// Export data
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel,
		InfobaseNode, False, True, ExchangeMessageTransportKind);
	
EndProcedure

&AtServer
Function GetDescriptionOfSettingsOfExchangeTransport()
	
	COMInfobaseOperationMode = 0;
	COMAuthenticationOS = False;
	
	// Return value of the function.
	Result = "";
	
	SettingsPresentation = InformationRegisters.ExchangeTransportSettings.TransportSettingsPresentations(Object.ExchangeMessageTransportKind);
	
	For Each Item IN SettingsPresentation Do
		
		SettingValue = Object[Item.Key];
		
		If AssistantRunMode = "ExchangeOverExternalConnection" Then
			
			If Item.Key = "COMInfobaseOperationMode" Then
				
				SettingValue = ?(Object[Item.Key] = 0, NStr("en='File';ru='Файловый'"), NStr("en='Client-server';ru='Клиент-серверный'"));
				
				COMInfobaseOperationMode = Object[Item.Key];
				
			EndIf;
			
			If Item.Key = "COMAuthenticationOS" Then
				
				COMAuthenticationOS = Object[Item.Key];
				
			EndIf;
			
			If COMInfobaseOperationMode = 0 Then
				
				If    Item.Key = "COMInfobaseNameAtServer1CEnterprise"
					OR Item.Key = "COMServerName1CEnterprise" Then
					Continue;
				EndIf;
				
			Else
				
				If Item.Key = "COMInfobaseDirectory" Then
					Continue;
				EndIf;
				
			EndIf;
			
			If COMAuthenticationOS Then
				
				If    Item.Key = "COMUserName"
					OR Item.Key = "COMUserPassword" Then
					Continue;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Find(Upper(Item.Value), "password") <> 0 Then
			
			Continue; // Values of passwords are not displayed.
			
		ElsIf  Not ValueType(SettingValue, "Number")
				 AND Not ValueType(SettingValue, "Boolean")
				 AND Not ValueIsFilled(SettingValue) Then
			
			// If the setting value is not specified, output value "<empty>".
			SettingValue = NStr("en='<empty>';ru='<пусто>'");
			
		EndIf;
		
		SettingRow = "[Presentation]: [Value]"; // Not localized
		SettingRow = StrReplace(SettingRow, "[Presentation]", Item.Value);
		SettingRow = StrReplace(SettingRow, "[Value]", SettingValue);
		
		Result = Result + SettingRow + Chars.LF;
		
	EndDo;
	
	If IsBlankString(Result) Then
		
		Result = NStr("en='Connection settings are not specified';ru='Настройки подключения не заданы.'");
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function ValueType(Value, TypeName)
	
	Return TypeOf(Value) = Type(TypeName);
	
EndFunction

&AtClient
Procedure CheckConnection(TransportKind)
	
	Cancel = False;
	
	CheckConnectionAtServer(Cancel, TransportKind);
	
	If Not Cancel Then
		
		If TransportKind = PredefinedValue("Enum.ExchangeMessagesTransportKinds.FILE") Then
			WarningText = NStr("en='Recording data in the specified directory is allowed.';ru='Запись данных в указанный каталог разрешена.'");
		Else
			WarningText = NStr("en='Connection has been successfully installed.';ru='Подключение успешно установлено.'");
		EndIf;
		
		ShowMessageBox(, WarningText);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckConnectionAtServer(Cancel, TransportKind)
	
	If TypeOf(TransportKind) = Type("String") Then
		
		TransportKind = Enums.ExchangeMessagesTransportKinds[TransportKind];
		
	EndIf;
	
	DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel, Object, TransportKind);
	
EndProcedure

&AtServer
Procedure CheckWSConnectionAtServer(Cancel, ExtendedCheck, IsSuggestOpenEventLogMonitor)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, Object);
	
	WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters);
	
	If WSProxy = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	CorrespondentVersions = DataExchangeReUse.CorrespondentVersions(ConnectionParameters);
	
	Object.CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	Object.CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	If Object.CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionParameters);
		
		If WSProxy = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf Object.CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters);
		
		If WSProxy = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
	EndIf;
		
	If ExtendedCheck Then
		
		// Getting the parameters of the second infobase.
		IsSuggestOpenEventLogMonitor = False;
		
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(Object.ExchangePlanName, "", ""));
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(Object.ExchangePlanName, "", ""));
			
		Else
			
			TargetParameters = ValueFromStringInternal(WSProxy.GetInfobaseParameters(Object.ExchangePlanName, "", ""));
			
		EndIf;
		
		// {Handler: WhenConnectingToCorrespondent} Start
		ConfigurationVersionCorrespondent = Undefined;
		TargetParameters.Property("ConfigurationVersion", ConfigurationVersionCorrespondent);
		
		OnConnectingToCorrespondent(Cancel, ConfigurationVersionCorrespondent);
		
		If Cancel Then
			Return;
		EndIf;
		// {Handler: WhenConnectingToCorrespondent} End
		
		If Not TargetParameters.ExchangePlanExists Then
			
			Message = NStr("en='Another application is not intended for the synchronization with the current one.';ru='Другая программа не предназначена для синхронизации с текущей.'");
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
			Return;
			
		EndIf;
		
		Object.CorrespondentNodeCode = TargetParameters.ThisNodeCode;
		
		Object.TargetInfobasePrefix = TargetParameters.InfobasePrefix;
		Object.TargetInfobasePrefixIsSet = ValueIsFilled(Object.TargetInfobasePrefix);
		
		If Not Object.TargetInfobasePrefixIsSet Then
			Object.TargetInfobasePrefix = TargetParameters.InfobasePrefixByDefault;
		EndIf;
		
		Items.TargetInfobasePrefixExchangeOverWebService.Visible = Not Object.TargetInfobasePrefixIsSet;
		Items.TargetInfobasePrefixExchangeOverWebService.ReadOnly = Object.TargetInfobasePrefixIsSet;
		
		// Checking the existence of exchange with correspondent base.
		CheckWhetherDataExchangeWithSecondBaseExists(Cancel);
		If Cancel Then
			Return;
		EndIf;
		
		Object.SecondInfobaseDescription = TargetParameters.InfobaseDescription;
		SecondInfobaseDescriptionSet = Not IsBlankString(Object.SecondInfobaseDescription);
		
		Items.SecondInfobaseDescription1.ReadOnly = SecondInfobaseDescriptionSet;
		
		If Not SecondInfobaseDescriptionSet Then
			
			Object.SecondInfobaseDescription = TargetParameters.DefaultInfobaseDescription;
			
		EndIf;
		
		NodeConfigurationForm = "";
		CorrespondentInfobaseNodeSettingsForm = "";
		DefaultValuesConfigurationForm = "";
		CorrespondentInfobaseDefaultValueSetupForm = "";
		NodesSettingForm = "";
		
		FilterSsettingsAtNode    = DataExchangeServer.FilterSsettingsAtNode(Object.ExchangePlanName, ConfigurationVersionCorrespondent, NodeConfigurationForm, Object.ExchangeSettingsVariant);
		DefaultValuesAtNode = DataExchangeServer.DefaultValuesAtNode(Object.ExchangePlanName, ConfigurationVersionCorrespondent, DefaultValuesConfigurationForm, Object.ExchangeSettingsVariant);
		
		DataExchangeServer.CommonNodeData(Object.ExchangePlanName, ConfigurationVersionCorrespondent, NodesSettingForm);
		
		CorrespondentInfobaseNodeDefaultValues = DataExchangeServer.CorrespondentInfobaseNodeDefaultValues(Object.ExchangePlanName, ConfigurationVersionCorrespondent, CorrespondentInfobaseDefaultValueSetupForm);
		
		CorrespondentInfobaseNodeDefaultValuesAvailable = CorrespondentInfobaseNodeDefaultValues.Count() > 0;
		
		Items.DefaultValueGroupBorder4.Visible                  = CorrespondentInfobaseNodeDefaultValuesAvailable;
		Items.CorrespondentInfobaseDefaultValueGroupBorder.Visible = CorrespondentInfobaseNodeDefaultValuesAvailable;
		
		CorrespondentInfobaseDefaultValueDetails = DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, ConfigurationVersionCorrespondent);
		
		CorrespondentAccountingSettingsCommentLabel = DataExchangeServer.CorrespondentInfobaseAccountingSettingsSetupComment(Object.ExchangePlanName, ConfigurationVersionCorrespondent);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckWSConnectionAtClient(Cancel, ExtendedCheck = False)
	
	If IsBlankString(Object.WSURLWebService) Then
		
		NString = NStr("en='Specify application address in the Internet.';ru='Укажите адрес приложения в Интернете.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSURLWebService",, Cancel);
		
	ElsIf IsBlankString(Object.WSUserName) Then
		
		NString = NStr("en='Specify a user name.';ru='Укажите имя пользователя.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSUserName",, Cancel);
		
	ElsIf IsBlankString(Object.WSPassword) Then
		
		NString = NStr("en='Specify the user password.';ru='Укажите пароль пользователя.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.WSPassword",, Cancel);
		
	Else
		
		Try
			DataExchangeClientServer.CheckInadmissibleSymbolsInUserNameWSProxy(Object.WSUserName);
		Except
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),, "Object.WSUserName",, Cancel);
			Return;
		EndTry;
		
		IsSuggestOpenEventLogMonitor = True;
		
		CheckWSConnectionAtServer(Cancel, ExtendedCheck, IsSuggestOpenEventLogMonitor);
		
		If Cancel AND IsSuggestOpenEventLogMonitor Then
			
			QuestionText = NStr("en='Connection installation error.
		|Do you want to open the event log?';ru='Ошибка установки подключения.
		|Перейти в журнал регистрации?'");
			
			SuggestOpenEventLogMonitor(QuestionText, EventLogMonitorMessageTextEstablishingConnectionToWebService);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SuggestOpenEventLogMonitor(QuestionText, Val Event)
	
	NotifyDescription = New NotifyDescription("SuggestOpenEventLogMonitorEnd", ThisObject, Event);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure SuggestOpenEventLogMonitorEnd(Response, Event) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure("EventLogMonitorEvent", Event);
		
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillGoToTable()
	
	If AssistantOperationOption = "SetupNewDataExchange" Then
		
		If AssistantRunMode = "ExchangeOverExternalConnection" Then
			
			DataExchangeOverExternalConnectionSettingsGoToTable();
			
		ElsIf AssistantRunMode = "ExchangeOverOrdinaryCommunicationChannels" Then
			
			FirstExchangeSetupStageGoToTable();
			
		ElsIf AssistantRunMode = "ExchangeOverWebService" Then
			
			If ExchangeWithServiceSetup Then
				
				ExtendedExchangeWithServiceSetupGoToTable();
				
			Else
				
				ExchangeOverWebServiceSetupGoToTable();
				
			EndIf;
			
		EndIf;
		
	Else // "ContinueDataExchangeSetup".
		
		SecondExchangeSetupStageGoToTable();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InfobaseRunModeOnChange()
	
	CurrentPage = ?(Object.COMInfobaseOperationMode = 0, Items.FileModePage, Items.ClientServerModePage);
	
	Items.InfobaseRunModes.CurrentPage = CurrentPage;
	
EndProcedure

&AtClient
Procedure OSAuthenticationOnChange()
	
	Object.COMAuthenticationOS = (AuthentificationType = 1);
	Items.COMUserName.Enabled    = Not Object.COMAuthenticationOS;
	Items.COMUserPassword.Enabled = Not Object.COMAuthenticationOS;
	
EndProcedure

&AtServer
Procedure AssistantRunVariantOnChangeAtServer()
	
	Items.DataExchangeSettingsForImportFileName.Enabled = AssistantOperationOption = "ContinueDataExchangeSetup"
																		AND Not Object.ThisIsSettingOfDistributedInformationBase;
	
	If AssistantOperationOption = "ContinueDataExchangeSetup" Then
		
		AssistantRunMode = "ExchangeOverOrdinaryCommunicationChannels";
		
	Else
		
		If ExchangeWithServiceSetup Then
			
			AssistantRunMode = "ExchangeOverWebService";
			
		ElsIf UseExchangeMessageTransportCOM Then
			
			AssistantRunMode = "ExchangeOverExternalConnection";
			
		ElsIf UseExchangeMessageTransportWS Then
			
			AssistantRunMode = "ExchangeOverWebService";
			
		Else
			
			AssistantRunMode = "ExchangeOverOrdinaryCommunicationChannels";
			
		EndIf;
		
	EndIf;
	
	FillGoToTable();
	
EndProcedure

&AtServer
Procedure AssistantRunModeOnChangeAtServer()
	
	AllPagesSettings = New Structure;
	
	SettingsVariant  = "ExchangeOverExternalConnection";
	SettingsValues = New Structure;
	
	SettingsValues.Insert("Transport",     Items.TransportParameterPageCOM);
	SettingsValues.Insert("Messages",     Enums.ExchangeMessagesTransportKinds.COM);
	SettingsValues.Insert("Use", AssistantRunMode = SettingsVariant Or UseExchangeMessageTransportCOM);
	AllPagesSettings.Insert(SettingsVariant, SettingsValues);
	
	SettingsVariant  = "ExchangeOverOrdinaryCommunicationChannels";
	SettingsValues = New Structure;
	SettingsValues.Insert("Transport",     Items.TransportParameterPage);
	SettingsValues.Insert("Messages",     Enums.ExchangeMessagesTransportKinds.FILE);
	SettingsValues.Insert("Use", AssistantRunMode = SettingsVariant Or UseExchangeMessageTransportFILE 
		Or UseExchangeMessageTransportFTP Or UseExchangeMessageTransportEMAIL);
	AllPagesSettings.Insert(SettingsVariant, SettingsValues);
		
	SettingsVariant  = "ExchangeOverWebService";
	SettingsValues = New Structure;
	SettingsValues.Insert("Transport",     Items.TransportParameterPageWS);
	SettingsValues.Insert("Messages",     Enums.ExchangeMessagesTransportKinds.WS);
	SettingsValues.Insert("Use", AssistantRunMode = SettingsVariant Or UseExchangeMessageTransportWS);
	AllPagesSettings.Insert(SettingsVariant, SettingsValues);
	
	// Real settings - only those that are valid.
	OptionsChoiceList = Items.AssistantRunMode.ChoiceList;
	
	For Each KeyValue IN AllPagesSettings Do
		SettingsVariant  = KeyValue.Key;
		SettingsValues = KeyValue.Value;
		VariantInList   = OptionsChoiceList.FindByValue(SettingsVariant);
		
		If SettingsValues.Use Then
			If SettingsVariant = AssistantRunMode Then
				Items.TransportParameterPages.CurrentPage        = SettingsValues.Transport;
				Object.ExchangeMessageTransportKind                          = SettingsValues.Messages;
			EndIf;
			
		Else
			If VariantInList <> Undefined Then
				OptionsChoiceList.Delete( VariantInList );
			EndIf;
			
		EndIf;
		
	EndDo;

	FillGoToTable();
EndProcedure

&AtClient
Function ExternalConnectionParameterStructure(ConnectionType = "ExternalConnection")
	
	Result = Undefined;
	
	If ConnectionType = "ExternalConnection" Then
		
		Result = CommonUseClientServer.ExternalConnectionParameterStructure();
		
		Result.InfobaseOperationMode             = Object.COMInfobaseOperationMode;
		Result.InfobaseDirectory                   = Object.COMInfobaseDirectory;
		Result.PlatformServerName                     = Object.COMServerName1CEnterprise;
		Result.InfobaseNameAtPlatformServer = Object.COMInfobaseNameAtServer1CEnterprise;
		Result.OSAuthentication           = Object.COMAuthenticationOS;
		Result.UserName                             = Object.COMUserName;
		Result.UserPassword                          = Object.COMUserPassword;
		
		Result.Insert("ConnectionType", ConnectionType);
		Result.Insert("CorrespondentVersion_2_0_1_6", Object.CorrespondentVersion_2_0_1_6);
		Result.Insert("CorrespondentVersion_2_1_1_7", Object.CorrespondentVersion_2_1_1_7);
		
	ElsIf ConnectionType = "WebService" Then
		
		Result = New Structure;
		Result.Insert("WSURLWebService");
		Result.Insert("WSUserName");
		Result.Insert("WSPassword");
		
		FillPropertyValues(Result, Object);
		
		Result.Insert("ConnectionType", ConnectionType);
		Result.Insert("CorrespondentVersion_2_0_1_6", Object.CorrespondentVersion_2_0_1_6);
		Result.Insert("CorrespondentVersion_2_1_1_7", Object.CorrespondentVersion_2_1_1_7);
		
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure CheckAttributeFillingOnForm(Cancel, FormToCheckName, FormParameters, FormAttributeName)
	
	SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[FormName]";
	SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	SettingsFormName = StrReplace(SettingsFormName, "[FormName]", FormToCheckName);
	
	SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
	
	If Not SettingsForm.CheckFilling() Then
		
		CommonUseClientServer.MessageToUser(NStr("en='It is necessary to specify the obligatory settings.';ru='Необходимо задать обязательные настройки.'"),,, FormAttributeName, Cancel);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteErrorInEventLogMonitor(ErrorMessageString, Event)
	
	WriteLogEvent(Event, EventLogLevel.Error,,, ErrorMessageString);
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseRegistrationRestrictionSetup(ConnectionType)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseNodeSettingsForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[CorrespondentBaseNodeSetupForm]", CorrespondentInfobaseNodeSettingsForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion",        ConfigurationVersionCorrespondent);
	FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
	FormParameters.Insert("FilterSsettingsAtNode",      CorrespondentInfobaseNodeFilterSetup);
	FormParameters.Insert("SettingID",      Object.ExchangeSettingsVariant);
	
	Handler = New NotifyDescription("CorrespondentBaseDataRegistrationRestrictionsSetupEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure CorrespondentBaseDataRegistrationRestrictionsSetupEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each FilterSettings IN CorrespondentInfobaseNodeFilterSetup Do
			
			CorrespondentInfobaseNodeFilterSetup[FilterSettings.Key] = Result[FilterSettings.Key];
			
		EndDo;
		
		// server call
		GetCorrespondentInfobaseDataTransferRestrictionDetails(CorrespondentInfobaseNodeFilterSetup);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CorrespondentInfobaseDefaultValueSetup(ConnectionType)
	
	NodeSettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[CorrespondentInfobaseDefaultValueSetupForm]";
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
	NodeSettingsFormName = StrReplace(NodeSettingsFormName, "[CorrespondentBaseDefaultValuesSetupForm]", CorrespondentInfobaseDefaultValueSetupForm);
	
	FormParameters = New Structure;
	FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
	FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
	FormParameters.Insert("DefaultValuesAtNode",   CorrespondentInfobaseNodeDefaultValues);
	FormParameters.Insert("SettingID",      Object.ExchangeSettingsVariant);
	
	Handler = New NotifyDescription("CorrespondentBaseDefaultValuesSetupEnd", ThisObject);
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm(NodeSettingsFormName, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure CorrespondentBaseDefaultValuesSetupEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		For Each FilterSettings IN CorrespondentInfobaseNodeDefaultValues Do
			
			CorrespondentInfobaseNodeDefaultValues[FilterSettings.Key] = Result[FilterSettings.Key];
			
		EndDo;
		
		// server call
		GetCorrespondentInfobaseDefaultValueDetails(CorrespondentInfobaseNodeDefaultValues);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishExchangeOverExternalConnectionSetup(Val OpenAfterClosingCurrent)
	
	If ExecuteInteractiveDataExchangeNow Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode",         Object.InfobaseNode);
		FormParameters.Insert("ExchangeMessageTransportKind",   Object.ExchangeMessageTransportKind);
		FormParameters.Insert("ExecuteMappingOnOpen", False);
		FormParameters.Insert("ExtendedModeAdditionsExportings", True);
		
		If OpenAfterClosingCurrent Then
			OpenParameters = New Structure;
			OpenParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
			DataExchangeClient.OpenFormAfterClosingCurrentOne(ThisObject, "DataProcessor.InteractiveDataExchangeAssistant.Form", FormParameters, OpenParameters);
			
		Else
			OpenForm("DataProcessor.InteractiveDataExchangeAssistant.Form", FormParameters);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishExchangeOverWebServiceSetup()
	
	If ExecuteDataExchangeAutomatically Then
		
		FinishExchangeOverWebServiceSetupAtServer(Object.InfobaseNode, PredefinedDataExchangeSchedule, DataExchangeExecutionSchedule);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure FinishExchangeOverWebServiceSetupAtServer(InfobaseNode, PredefinedSchedule, Schedule)
	
	SetPrivilegedMode(True);
	
	ScenarioSchedule = Undefined;
	
	If PredefinedSchedule = "Every15Minutes" Then
		
		ScenarioSchedule = PredefinedScheduleEvery15Minutes();
		
	ElsIf PredefinedSchedule = "Every30Minutes" Then
		
		ScenarioSchedule = PredefinedScheduleEvery30Minutes();
		
	ElsIf PredefinedSchedule = "EveryHour" Then
		
		ScenarioSchedule = PredefinedScheduleEveryHour();
		
	ElsIf PredefinedSchedule = "EveryDayIn_8_00" Then
		
		ScenarioSchedule = PredefinedScheduleEveryDayIn_8_00();
		
	ElsIf PredefinedSchedule = "OtherSchedule" Then
		
		ScenarioSchedule = Schedule;
		
	EndIf;
	
	If ScenarioSchedule <> Undefined Then
		
		Catalogs.DataExchangeScripts.CreateScenario(InfobaseNode, ScenarioSchedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishFirstExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel)
	
	ClearMessages();
	
	If Not Object.ThisIsSettingOfDistributedInformationBase
		AND IsBlankString(Object.DataExchangeSettingsFileName) Then
		
		NString = NStr("en='Save the file with the settings for another application';ru='Сохраните файл с настройками для другой программы'");
		
		CommonUseClientServer.MessageToUser(NString,,"Object.DataExchangeSettingsFileName",, Cancel);
		Return;
	EndIf;
	
	If Object.ThisIsSettingOfDistributedInformationBase Then
		
		If CreateInitialImageNow Then
			
			FormParameters = New Structure("Key, Node", Object.InfobaseNode, Object.InfobaseNode);
			
			Mode = FormWindowOpeningMode.LockOwnerWindow;
			Handler = New NotifyDescription("CloseFormAfterCreatingInitialImage", ThisObject);
			OpenForm(FormNameOfCreatingInitialImage, FormParameters,,,,, Handler, Mode);
			Cancel = True;
			
		EndIf;
		
	Else
		
		If ExecuteDataExchangeNow Then
			
			Status(NStr("en='Data sending is in progress...';ru='Выполняется отправка данных...'"));
			InitializationOfDataExchangeAtClient(Cancel, Object.InfobaseNode, Object.ExchangeMessageTransportKind);
			Status(NStr("en='Data sending is completed';ru='Отправка данных завершена'"));
			
			If Cancel Then
				
				ShowMessageBox(, NStr("en='Error occurred during data sending (see event log monitor).';ru='Во время отправки данных возникли ошибки(см. журнал регистрации).'"));
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseFormAfterCreatingInitialImage(Result, AdditionalParameters) Export
	
	RefreshInterface();
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

&AtClient
Procedure FinishSecondExchangeOverOrdinaryCommunicationChannelsSetupStage(Cancel, Val OpenAfterClosingCurrent)
	
	Status(NStr("en='Data synchronization setting is being created';ru='Выполняется создание настройки синхронизации данных'"));
	
	ConfigureNewDataExchangeAtServer(Cancel, FilterSsettingsAtNode, DefaultValuesAtNode);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='Errors occurred when creating data synchronization settings.';ru='При создании настройки синхронизации данных возникли ошибки.'"));
		Return;
	EndIf;
	
	OpenMappingAssistant = Not Object.ThisIsSettingOfDistributedInformationBase AND Not Object.IsStandardExchangeSetup;
	
	If OpenMappingAssistant Then
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode",         Object.InfobaseNode);
		FormParameters.Insert("ExchangeMessageTransportKind",   Object.ExchangeMessageTransportKind);
		FormParameters.Insert("ExecuteMappingOnOpen", False);
		FormParameters.Insert("ExtendedModeAdditionsExportings", True);
		
		AssistantFormName = "DataProcessor.InteractiveDataExchangeAssistant.Form";
		If OpenAfterClosingCurrent Then
			OpenParameters = New Structure;
			OpenParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
			DataExchangeClient.OpenFormAfterClosingCurrentOne(ThisObject, AssistantFormName, FormParameters, OpenParameters);
		Else
			OpenForm(AssistantFormName, FormParameters);
		EndIf;
		
	EndIf;
	
EndProcedure
&AtClient
Procedure OpenMappingForm()
	
	CurrentData = Items.StatisticsInformationTree.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("en='Impossible to perform matching for these data.';ru='Для этих данных нельзя выполнить сопоставление.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ReceiverTableName",            CurrentData.ReceiverTableName);
	FormParameters.Insert("TableSourceObjectTypeName", CurrentData.ObjectTypeAsString);
	FormParameters.Insert("ReceiverTableFields",           CurrentData.TableFields);
	FormParameters.Insert("SearchFieldsOfReceiverTable",     CurrentData.SearchFields);
	FormParameters.Insert("SourceTypeAsString",            CurrentData.SourceTypeAsString);
	FormParameters.Insert("ReceiverTypeAsString",            CurrentData.ReceiverTypeAsString);
	FormParameters.Insert("ThisIsObjectDeletion",             CurrentData.ThisIsObjectDeletion);
	FormParameters.Insert("DataSuccessfullyImported",         CurrentData.DataSuccessfullyImported);
	FormParameters.Insert("Key",                           CurrentData.Key);
	FormParameters.Insert("Synonym",                        CurrentData.Synonym);
	
	FormParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	FormParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	
	FormParameters.Insert("PerformDataImport", False);
	
	OpenForm("DataProcessor.InfobaseObjectsMapping.Form", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ExpandTreeOfInformationStatistics(RowKey = "")
	
	ItemCollection = StatisticsInformationTree.GetItems();
	
	For Each TreeRow IN ItemCollection Do
		
		Items.StatisticsInformationTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Cursor positioning in a value tree.
	If Not IsBlankString(RowKey) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsInformationTree.GetItems(), RowKey, False);
		
		Items.StatisticsInformationTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshDataOfMappingStatisticsAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", NotificationParameters.UniqueKey));
	
	FillPropertyValues(TableRows[0], NotificationParameters, "DataSuccessfullyImported");
	
	RowKeys = New Array;
	RowKeys.Add(NotificationParameters.UniqueKey);
	
	RefreshInformationOfMappingByRowAtServer(Cancel, RowKeys);
	
EndProcedure

&AtServer
Procedure RefreshInformationOfMappingByRowAtServer(Cancel, RowKeys)
	
	RowIndexes = GetIndexesOfRowsOfInformationStatisticsTable(RowKeys);
	
	InteractiveDataExchangeAssistant = DataProcessors.InteractiveDataExchangeAssistant.Create();
	
	FillPropertyValues(InteractiveDataExchangeAssistant, Object,, "StatisticsInformation");
	
	InteractiveDataExchangeAssistant.StatisticsInformation.Load(Object.StatisticsInformation.Unload());
	
	InteractiveDataExchangeAssistant.GetObjectMappingStatsByString(Cancel, RowIndexes);
	
	If Not Cancel Then
		
		Object.StatisticsInformation.Load(InteractiveDataExchangeAssistant.TableOfInformationStatistics());
		
		GetTreeOfInformationStatistics(InteractiveDataExchangeAssistant.TableOfInformationStatistics());
		
		SetVisibleOfAdditionalInformationGroup();
		
	EndIf;
	
EndProcedure

&AtServer
Function GetIndexesOfRowsOfInformationStatisticsTable(RowKeys)
	
	RowIndexes = New Array;
	
	For Each Key IN RowKeys Do
		
		TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", Key));
		
		RowIndex = Object.StatisticsInformation.IndexOf(TableRows[0]);
		
		RowIndexes.Add(RowIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServer
Procedure GetTreeOfInformationStatistics(StatisticsInformation)
	
	TreeItemCollection = StatisticsInformationTree.GetItems();
	TreeItemCollection.Clear();
	
	CommonUse.FillItemCollectionOfFormDataTree(TreeItemCollection,
		DataExchangeServer.GetTreeOfInformationStatistics(StatisticsInformation));
	
EndProcedure

&AtServer
Procedure OnConnectingToCorrespondent(Cancel, Val CorrespondentVersion)
	
	If CorrespondentVersion = Undefined
		OR IsBlankString(CorrespondentVersion) Then
		
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Try
		DataExchangeServer.OnConnectingToCorrespondent(Object.ExchangePlanName, CorrespondentVersion);
	Except
		CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),,,, Cancel);
		WriteErrorInEventLogMonitor(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='When executing the OnConnectingToCorrespondent handler, an error occurred:%1%2';ru='При выполнении обработчика ПриПодключенииККорреспонденту произошла ошибка:%1%2'"),
				Chars.LF,
				DetailErrorDescription(ErrorInfo())),
			DataExchangeCreationEventLogMonitorMessageText
		);
		Return;
	EndTry;
	
EndProcedure

&AtClient
Procedure DeleteDataExchangeSetting(Result, AdditionalParameters) Export
	
	If Object.InfobaseNode <> Undefined Then
		
		DataExchangeServerCall.DeleteSynchronizationSetting(Object.InfobaseNode);
		
		Notify("Write_ExchangePlanNode");
		
	EndIf;
	
EndProcedure

// Denial of DIB setup, accept all default settings.
&AtClient
Procedure AlertDescriptionFailedToContinueDIB(Val Result, AdditionalParameters) Export
	
	// Ignore all the steps, the settings should be configured in advance.
	RunCommandDone(False);
	
EndProcedure
	
////////////////////////////////////////////////////////////////////////////////
// Values of constants

&AtClientAtServerNoContext
Function LabelNextFTP()
	
	Return NStr("en='Press the ""Next"" button to set up the connection through the FTP resource.';ru='Нажмите кнопку ""Далее"" для настройки подключения через FTP-ресурс.'");
	
EndFunction

&AtClientAtServerNoContext
Function LabelNextEMAIL()
	
	Return NStr("en='Press the ""Next"" button to set the connection by email.';ru='Нажмите кнопку ""Далее"" для настройки подключения по почте.'");
	
EndFunction

&AtClientAtServerNoContext
Function LabelNextSettings()
	
	Return NStr("en='Click ""Next"" to set up additional parameters of data synchronization.';ru='Нажмите кнопку ""Далее"" для настройки дополнительных параметров синхронизации данных.'");
	
EndFunction

&AtServerNoContext
Function PredefinedScheduleEvery15Minutes()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 60*15; // 15 minutes
	Schedule.DaysRepeatPeriod        = 1; // every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleEvery30Minutes()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 60*30; // 30 minutes
	Schedule.DaysRepeatPeriod        = 1; // every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleEveryHour()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 60*60; // 60 minutes
	Schedule.DaysRepeatPeriod        = 1; // every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleEveryDayIn_8_00()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.BeginTime              = Date('00010101080000'); // 8:00
	Schedule.DaysRepeatPeriod        = 1; // every day
	
	Return Schedule;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Go to event handlers.

&AtClient
Procedure StepForwardByDeferredProcessing()
	
	AttachIdleHandler("Attachable_SkipForwardByDeferredProcessing", 0.01, True);
	
EndProcedure

&AtClient
Procedure Attachable_StepForwardByDeferredProcessing()
	
	// Step forward forcefully.
	SkipCurrentPageFailureControl = True;
	ChangeGoToNumber( +1 );
	
EndProcedure

&AtClient
Function Attachable_AssistantPageSetTransportParametersFILE_OnGoingNext(Cancel)
	
	If Object.UseTransportParametersFILE Then
		
		If IsBlankString(Object.FILEInformationExchangeDirectory) Or ExternalResourcesAllowed.AllowedFile Then
			AssistantPageSetTransportParametersFILE_OnGoingNextAtServer(Cancel);
		Else
			ClosingAlert = New NotifyDescription("AllowResourceEnd", ThisObject, "AllowedFile");
			Queries = CreateQueryOnExternalResourcesUse(Object, False, True, False, False);
			WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageSetTransportParametersFTP_OnGoingNext(Cancel)
	
	If Object.UseTransportParametersFTP Then
		
		If IsBlankString(Object.FTPConnectionPath) Or ExternalResourcesAllowed.AllowedFTP Then
			AssistantPageSetTransportParametersFTP_OnGoingNextAtServer(Cancel);
		Else
			ClosingAlert = New NotifyDescription("AllowResourceEnd", ThisObject, "AllowedFTP");
			Queries = CreateQueryOnExternalResourcesUse(Object, False, False, False, True);
			WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
			Cancel = True;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageSetTransportParametersEMAIL_OnGoingNext(Cancel)
	
	AssistantPageSetTransportParametersEMAIL_OnGoingNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_AssistantPageAssistantRunModeChoice_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not UseExchangeMessageTransportCOM Or Not UseExchangeMessageTransportWS Then
		
		Object.UseTransportParametersCOM = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageAssistantRunModeChoice_OnGoingNext(Cancel)
	
	If ((AssistantRunMode = "ExchangeOverExternalConnection" AND (NOT IsBlankString(Object.COMInfobaseDirectory) Or Not IsBlankString(Object.COMServerName1CEnterprise)))
		Or (AssistantRunMode = "ExchangeOverWebService" AND Not IsBlankString(Object.WSURLWebService)))
		AND Not ExternalResourcesAllowed.AllowedCom Then
		
		ClosingAlert = New NotifyDescription("AllowResourceEnd", ThisObject, "AllowedCom");
		If AssistantRunMode = "ExchangeOverWebService" Then
			Queries = CreateQueryOnExternalResourcesUse(Object, False, False, True, False);
		ElsIf AssistantRunMode = "ExchangeOverExternalConnection" Then
			Queries = CreateQueryOnExternalResourcesUse(Object, True, False, False, False);
		EndIf;
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
		Cancel = True;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageSetTransportParametersFILE_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ExternalResourcesAllowed.AllowedFile = False;
	
	If Not UseExchangeMessageTransportFILE Then
		
		Object.UseTransportParametersFILE = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageSetTransportParametersFTP_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ExternalResourcesAllowed.AllowedFTP = False;
	
	If Not UseExchangeMessageTransportFTP Then
		
		Object.UseTransportParametersFTP = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageSetTransportParametersEMAIL_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If Not UseExchangeMessageTransportEMAIL Then
		
		Object.UseTransportParametersEMAIL = False;
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageParameterSetup_OnGoingNext(Cancel)
	
	If IsBlankString(Object.ThisInfobaseDescription) Then
		
		NString = NStr("en='Specify the name of this application.';ru='Укажите наименование этой программы.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfobaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.SecondInfobaseDescription) Then
		
		NString = NStr("en='Specify another application name';ru='Укажите наименование другой программы.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfobaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en='Specify the existing or desired prefix of the second infobase.';ru='Укажите существующий или желаемый префикс второй информационной базы.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfobasePrefix) = TrimAll(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en='Infobase prefixes must be different.';ru='Префиксы информационных баз должны быть различными.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If NodeFiltersSettingsAvailable Then
		
		// Checking completion of the attributes in the form of data migration restriction settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("FilterSsettingsAtNode", FilterSsettingsAtNode);
		
		CheckAttributeFillingOnForm(Cancel, NodeConfigurationForm, FormParameters, "DataTransferRestrictionsDescriptionFull");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking the completion of attributes in the form of additional settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValuesConfigurationForm, FormParameters, "ValuesDescriptionFullByDefault");
		
	EndIf;
	
	AssistantPageParameterSetup_OnGoingNextAtServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_AssistantPageFirstInfobaseExternalConnectionParameterSetup_OnGoingNext(Cancel)
	
	If IsBlankString(Object.ThisInfobaseDescription) Then
		
		NString = NStr("en='Specify infobase name.';ru='Укажите наименование информационной базы.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfobaseDescription",, Cancel);
		Return Undefined;
	EndIf;
	
	If NodeFiltersSettingsAvailable Then
		
		// Checking completion of the attributes in the form of data migration restriction settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("FilterSsettingsAtNode", FilterSsettingsAtNode);
		
		CheckAttributeFillingOnForm(Cancel, NodeConfigurationForm, FormParameters, "DataTransferRestrictionsDescriptionFull");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking the completion of attributes in the form of additional settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValuesConfigurationForm, FormParameters, "ValuesDescriptionFullByDefault");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageDataExchangeSetupParameter_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext Then
		
		// Get the context and the description of nodes setup form context.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("GetDefaultValues");
		FormParameters.Insert("Settings", NodesSettingFormContext);
		
		SettingsFormName = "ExchangePlan.[ExchangePlanName].Form.[NodesSettingForm]";
		SettingsFormName = StrReplace(SettingsFormName, "[ExchangePlanName]", Object.ExchangePlanName);
		SettingsFormName = StrReplace(SettingsFormName, "[NodesSetupForm]", NodesSettingForm);
		
		SettingsForm = GetForm(SettingsFormName, FormParameters, ThisObject);
		
		NodesSettingFormContext    = SettingsForm.Context;
		DataExportSettingsDescription = SettingsForm.ContextDetails;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageDataExchangeSetupParameter_OnGoingNext(Cancel)
	
	CheckJobSettingsForFirstInfobase(Cancel, "WebService");
	
EndFunction

&AtClient
Function Attachable_AssistantPageSecondInfobaseExternalConnectionParameterSetup_OnGoingNext(Cancel)
	
	CheckJobSettingsForSecondInfobase(Cancel, "ExternalConnection");
	
EndFunction

&AtClient
Function Attachable_AssistantPageSecondSetupStageParameterSetup_OnGoingNext(Cancel)
	
	If NodeFiltersSettingsAvailable Then
		
		// Checking completion of the attributes in the form of data migration restriction settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("FilterSsettingsAtNode", FilterSsettingsAtNode);
		
		CheckAttributeFillingOnForm(Cancel, NodeConfigurationForm, FormParameters, "DataTransferRestrictionsDescriptionFull");
		
	EndIf;
	
	If NodeDefaultValuesAvailable Then
		
		// Checking the completion of attributes in the form of additional settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValuesConfigurationForm, FormParameters, "ValuesDescriptionFullByDefault");
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageStart_OnGoingNext(Cancel)
	
	If True = SkipCurrentPageFailureControl Then
		SkipCurrentPageFailureControl = Undefined;
		Return Undefined;
		
	ElsIf Object.ThisIsSettingOfDistributedInformationBase Then
		Return Undefined;
		
	ElsIf AssistantOperationOption <> "ContinueDataExchangeSetup" Then
		Return Undefined;
		
	ElsIf DataExchangeSettingsFileSuccessfullyImported Then
		// Additional checks are not required to continue the exchange.
		Return Undefined;
		
	EndIf;
	
	// Successful skip forward will be in the alerts.
	Cancel = True;
	
	// Trying to pass the file to the server with a query to set an extension without a dialog.
	If IsBlankString(Object.DataExchangeSettingsForImportFileName) Then
		ErrorText = NStr("en='Select the file with the data synchronization settings';ru='Выберите файл с настройками синхронизации данных'");
		CommonUseClientServer.MessageToUser(ErrorText, , "Object.DataExchangeSettingsForImportFileName");
		Return Undefined;
	EndIf;
	
	Notification = New NotifyDescription("AssistantPageStart_OnSkipForward_End", ThisObject, New Structure);
	WarningText = NStr("en='To transfer the file of data synchronization settings you should install the extension for 1C: Enterprise web client.';ru='Для передачи файла настроек синхронизации данных необходимо установить расширение для веб-клиента 1С:Предприятие.'");
	
	FileNames = New Array;
	FileNames.Add(Object.DataExchangeSettingsForImportFileName);
	
	DataExchangeClient.PassFilesToServer(Notification, FileNames, UUID, WarningText);
EndFunction

// Description of the notification on the completion of file transfer to the server.
//
&AtClient
Procedure AssistantPageStart_OnGoingNext_End(Val FilesPlacingResult, Val AdditionalParameters) Export
	
	EndSelectingDataExchangeSettingsForImportFile(FilesPlacingResult[0], Undefined);
	
	If DataExchangeSettingsFileSuccessfullyImported Then
		// Execute successful skip forward.
		StepForwardByDeferredProcessing();
	EndIf;
	
EndProcedure

&AtClient
Procedure EndSelectingDataExchangeSettingsForImportFile(Val FilesPlacingResult, Val AdditionalParameters) Export
	
	ClearMessages();
	
	PlacedFileAddress = FilesPlacingResult.Location;
	ErrorText           = FilesPlacingResult.ErrorDescription;
	
	Object.DataExchangeSettingsForImportFileName = FilesPlacingResult.Name;
	
	DataExchangeSettingsFileSuccessfullyImported = False;
	
	If IsBlankString(ErrorText) AND IsBlankString(PlacedFileAddress) Then
		ErrorText = NStr("en='An error occurred during sending a settings file of data synchronization to server';ru='Ошибка передачи файла настроек синхронизации данных на сервер'");
	EndIf;
	
	If IsBlankString(ErrorText) Then
		// The file is successfully transferred, trying to apply the settings.
		AssistantParametersImportError = False;
		// Calling the server
		ImportAssistantParameters(AssistantParametersImportError, PlacedFileAddress);
		If AssistantParametersImportError Then
			ErrorText = NStr("en='Incorrect file of data synchronization settings is indicated. Specify the correct file.';ru='Указан неправильный файл настроек синхронизации данных. Укажите корректный файл.'");
		Else
			DataExchangeSettingsFileSuccessfullyImported = True;
		EndIf;
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText, , "Object.DataExchangeSettingsForImportFileName");
	EndIf;
	
	RefreshDataRepresentation();
EndProcedure

&AtClient
Function Attachable_AssistantPageParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	// If a user navigates to the page of additional parameters and does not select any kind of transport, then there will be an error.
	If Not    (Object.UseTransportParametersEMAIL
			OR Object.UseTransportParametersFILE
			OR Object.UseTransportParametersFTP) Then
		
		NString = NStr("en='Connection parameters for data synchronization are not specified.
		|At least one connection variant should be configured.';ru='Не указаны параметры подключения для синхронизации данных.
		|Следует настроить хотя бы один вариант подключения.'");
		//
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		
		Return Undefined;
	EndIf;
	
	AssistantPageParameterSetup_OnOpenOnServer(Cancel, SkipPage, IsGoNext);
	
EndFunction

&AtClient
Function Attachable_AssistantPageFirstInfobaseExternalConnectionParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.DataTransferRestrictionDetails1.Title = StrReplace(Items.DataTransferRestrictionDetails1.Title,
																	   "%Application%", ExchangePlanSynonym);
	
	Items.DefaultValueDetails1.Title = StrReplace(Items.DefaultValueDetails1.Title,
																	   "%Application%", ExchangePlanSynonym);
	
EndFunction

&AtClient
Function Attachable_AssistantPageSecondInfobaseExternalConnectionParameterSetup_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.DataTransferRestrictionDetails4.Title = StrReplace(Items.DataTransferRestrictionDetails4.Title,
																	   "%Application%", Object.ThisInfobaseDescription);
	
	Items.DefaultValueDetails4.Title = StrReplace(Items.DefaultValueDetails4.Title,
																	   "%Application%", Object.ThisInfobaseDescription);
	
EndFunction

&AtClient
Function Attachable_AssistantPageExchangeSetupResults_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If AssistantOperationOption = "SetupNewDataExchange" Then
		
		// Display of exchange setup result.
		MessageString = NStr("en='%1%2%3Prefix of this
		|infobase: %4 Prefix of the second infobase: %5';ru='%1%2%3Префикс
		|этой информационной базы: %4 Префикс второй информационной базы: %5'");
		
		ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ResultPresentationMessagesTransport(),
							ResultPresentationFiltersAtNode(),
							PresentationOfDefaultValueResultAtNode(),
							Object.SourceInfobasePrefix,
							Object.TargetInfobasePrefix);
		
	Else
		
		// Display of exchange setup result.
		MessageString = NStr("en='%1%2%3Prefix of this infobase: %4';ru='%1%2%3Префикс этой информационной базы: %4'");
		
		ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
							ResultPresentationMessagesTransport(),
							ResultPresentationFiltersAtNode(),
							PresentationOfDefaultValueResultAtNode(),
							Object.SourceInfobasePrefix);
		
	EndIf;
	
	// display the explanatory inscription
	Items.MappingAssistantOpenedInfoLabelGroup.Visible =
	(AssistantOperationOption = "ContinueDataExchangeSetup" 
	AND Not Object.ThisIsSettingOfDistributedInformationBase
	AND Not Object.IsStandardExchangeSetup);
	
EndFunction

&AtClient
Function Attachable_AssistantPageExchangeSetupResults_OnOpen_ExternalConnection(Cancel, SkipPage, IsGoNext)
	
	// Display of exchange setup result.
	If ExchangeWithServiceSetup Then
		
		MessageString = NStr("en='%1 Settings for this infobase: ======================================================== %2%3Prefix of the infobase: %4 Settings for the application located in the service: ======================================================== %5%6Prefix of the application: %7';ru='%1 Настройки для этой информационной базы: ======================================================== %2%3Префикс информационной базы: %4 Настройки для приложения, расположенного в сервисе: ======================================================== %5%6Префикс приложения: %7'");
		
	Else
		
		MessageString = NStr("en='%1 Parameters of data synchronization for this application: ======================================================== %2%3Prefix of the infobase: %4 Parameters of data synchronization for another application:: ================================================ %5%6Prefix of the infobase: %7';ru='%1 Параметры синхронизации данных для этой программы: ======================================================== %2%3Префикс информационной базы: %4 Параметры синхронизации данных для другой программы:: ======================================================== %5%6Префикс информационной базы: %7'");
		
	EndIf;
	
	ExchangeSettingsResultPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
						ResultPresentationMessagesTransport(),
						ResultPresentationFiltersAtNode(),
						PresentationOfDefaultValueResultAtNode(),
						Object.SourceInfobasePrefix,
						CorrespondentInfobaseNodeFilterResultPresentation(),
						CorrespondentInfobaseNodeDefaultValueResultPresentation(),
						Object.TargetInfobasePrefix);
	
	// display the explanatory inscription
	Items.MappingAssistantOpenedInfoLabelGroup.Visible = False;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitForDataExchangeSettingsCreation_LongOperationProcessing(Cancel, GoToNext)
	
	AssistantPageWaitForDataExchangeSettingsCreation_LongOperationProcessorOnServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingDataExchangeSettingsCreationThroughExternalConnection_LongOperationProcessing(Cancel, GoToNext)
	
	// Create the setting of exchange through an external connection.
	SetupNewDataExchangeOverExternalConnectionAtServer(Cancel, CorrespondentInfobaseNodeFilterSetup, CorrespondentInfobaseNodeDefaultValues);
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitForCheckExternalConnectionConnected_LongOperationProcessing(Cancel, GoToNext)
	
	AssistantPageWaitForCheckExternalConnectionConnected_LongOperationProcessorOnServer(Cancel);
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingWebServiceConnectionCheck_LongOperationProcessing(Cancel, GoToNext)
	
	CheckWSConnectionAtClient(Cancel, True);
	
EndFunction

//

&AtClient
Function Attachable_AssistantPageWaitForExchangeSettingsCreationDataAnalysis_LongOperationProcessing(Cancel, GoToNext)
	
	// Creating data exchange settings:
	//  - creating nodes in this base and the correspondent with data export settings
	//  - registration of the catalogs for export in this base and in the correspondent.
	
	LongOperation = False;
	LongOperationFinished = False;
	LongOperationID = "";
	
	SetupNewDataExchangeAtServerOverWebService(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='Errors occurred when creating data synchronization setup.
		|To solve the problems use the event log.';ru='Возникли ошибки на этапе создания настройки синхронизации данных.
		|Для решения проблем воспользуйтесь журналом регистрации.'"));
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingDataAnalysisExchangeSettingCreationLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

//

&AtClient
Function Attachable_AssistantPageWaitForDataAnalysisGetMessage_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	MessageFileIDInService = "";
	LongOperationID = "";
	
	DataStructure = DataExchangeServerCall.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
		Cancel,
		Object.InfobaseNode,
		MessageFileIDInService,
		LongOperation,
		LongOperationID,
		Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='At the data analysis stage, errors occurred.
		|To solve the problems use the event log.';ru='Возникли ошибки на этапе анализа данных.
		|Для решения проблем воспользуйтесь журналом регистрации.'"));
		
	ElsIf Not LongOperation Then
		
		Object.TemporaryExchangeMessagesDirectoryName = DataStructure.TemporaryExchangeMessagesDirectoryName;
		Object.ExchangeMessageFileName              = DataStructure.ExchangeMessageFileName;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingDataAnalysisGettingMessageLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingDataAnalysisGettingMessageLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		DataStructure = DataExchangeServerCall.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongOperation(
			Cancel,
			Object.InfobaseNode,
			MessageFileIDInService,
			Object.WSPassword);
		
		If Cancel Then
			
			ShowMessageBox(, NStr("en='At the data analysis stage, errors occurred.
		|To solve the problems use the event log.';ru='Возникли ошибки на этапе анализа данных.
		|Для решения проблем воспользуйтесь журналом регистрации.'"));
			
		Else
			
			Object.TemporaryExchangeMessagesDirectoryName = DataStructure.TemporaryExchangeMessagesDirectoryName;
			Object.ExchangeMessageFileName              = DataStructure.ExchangeMessageFileName;
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitForDataAnalysisAutomaticMapping_LongOperationProcessing(Cancel, GoToNext)
	
	AssistantPageWaitForDataAnalysisAutomaticMapping_LongOperationProcessing(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='At the data analysis stage, errors occurred.';ru='Возникли ошибки на этапе анализа данных.'"));
		
	EndIf;
	
EndFunction

&AtServer
Procedure AssistantPageWaitForDataAnalysisAutomaticMapping_LongOperationProcessing(Cancel)
	
	InteractiveDataExchangeAssistant = DataProcessors.InteractiveDataExchangeAssistant.Create();
	
	FillPropertyValues(InteractiveDataExchangeAssistant, Object,, "StatisticsInformation");
	
	InteractiveDataExchangeAssistant.StatisticsInformation.Load(Object.StatisticsInformation.Unload());
	
	InteractiveDataExchangeAssistant.RunExchangeMessageAnalysis(Cancel);
	
	InteractiveDataExchangeAssistant.RunAutomaticMappingByDefaultAndGetMappingStats(Cancel);
	
	If Not Cancel Then
		
		TableOfInformationStatistics = InteractiveDataExchangeAssistant.TableOfInformationStatistics();
		
		// Delete the rows that have 100% mapping.
		ReverseIndex = TableOfInformationStatistics.Count() - 1;
		
		While ReverseIndex >= 0 Do
			
			TableRow = TableOfInformationStatistics[ReverseIndex];
			
			If TableRow.UnmappedObjectsCount = 0 Then
				
				TableOfInformationStatistics.Delete(TableRow);
				
			EndIf;
			
			ReverseIndex = ReverseIndex - 1;
		EndDo;
		
		Object.StatisticsInformation.Load(TableOfInformationStatistics);
		
		GetTreeOfInformationStatistics(TableOfInformationStatistics);
		
		SetVisibleOfAdditionalInformationGroup();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibleOfAdditionalInformationGroup()
	
	// If in the information table (statistics) there is at least one row with
	// mapping less than 100%, then make the group of additional information visible.
	RowArray = Object.StatisticsInformation.FindRows(New Structure("PictureIndex", 1));
	
	AllDataMapped = (RowArray.Count() = 0);
	
	Items.DataMappingStatePages.CurrentPage = ?(AllDataMapped,
				Items.MappingStateAllDataMapped,
				Items.MappingStateHasUnmappedData);
	
EndProcedure

&AtClient
Function Attachable_AssistantPageDataMapping_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext AND AllDataMapped Then
		
		SkipPage = True;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageDataMapping_OnGoingNext(Cancel)
	
	If Not AllDataMapped Then
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, "Continue");
		Buttons.Add(DialogReturnCode.No, "Cancel");
		
		Message = NStr("en='Not all data was mapped. Existence of
		|unmapped data can lead to identical catalog items (duplicates).
		|Continue?';ru='Не все данные сопоставлены. Наличие
		|несопоставленных данных может привести к появлению одинаковых элементов справочников (дублей).
		|Продолжить?'");
							   
		If Not UserRepliedYesToMapping Then
			NotifyDescription = New NotifyDescription("HandleUserResponseWhenCompared", ThisObject);
			ShowQueryBox(NOTifyDescription, Message, Buttons,, DialogReturnCode.No);
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Procedure HandleUserResponseWhenCompared(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		UserRepliedYesToMapping = True;
		ChangeGoToNumber(+1);
		
	EndIf;
	
EndProcedure

//

&AtClient
Function Attachable_AssistantPageWaitForCatalogSynchronizationImport_LongOperationProcessing(Cancel, GoToNext)
	
	AssistantPageWaitForCatalogSynchronizationImport_LongOperationProcessing();
	
EndFunction

&AtServer
Procedure AssistantPageWaitForCatalogSynchronizationImport_LongOperationProcessing()
	
	LongOperation = False;
	LongOperationFinished = False;
	LongOperationID = "";
	
	MethodParameters = New Structure;
	MethodParameters.Insert("InfobaseNode", Object.InfobaseNode);
	MethodParameters.Insert("ExchangeMessageFileName", Object.ExchangeMessageFileName);
	
	Result = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.DataExchangeCreationAssistant.RunCatalogImport",
		MethodParameters,
		NStr("en='Import of catalogs from the exchange message';ru='Загрузка справочников из сообщения обмена'"));
	
	If Not Result.JobCompleted Then
		
		LongOperation = True;
		LongOperationID = Result.JobID;
		
	EndIf;
	
EndProcedure

&AtClient
Function Attachable_AssistantPageWaitingCatalogSynchronizationImportLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitForCatalogSynchronizationExport_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	MessageFileIDInService = "";
	LongOperationID = "";
	
	AssistantPageWaitForCatalogSynchronizationExport_LongOperationProcessing(
											Cancel,
											Object.InfobaseNode,
											LongOperation,
											LongOperationID,
											MessageFileIDInService,
											OperationStartDate,
											Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='Errors occurred at the stage of catalogs synchronization.
		|To solve the problems use the event log.';ru='Возникли ошибки на этапе синхронизации справочников.
		|Для решения проблем воспользуйтесь журналом регистрации.'"));
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure AssistantPageWaitForCatalogSynchronizationExport_LongOperationProcessing(
											Cancel,
											InfobaseNode,
											LongOperation,
											ActionID,
											FileID,
											OperationStartDate,
											Password)
	
	OperationStartDate = CurrentSessionDate();
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											Enums.ExchangeMessagesTransportKinds.WS,
											LongOperation,
											ActionID,
											FileID,
											True,
											Password);
	
EndProcedure

&AtClient
Function Attachable_AssistantPageWaitingCatalogsSynchronizationExportLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingCatalogsSyncronizationExportLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		DataExchangeServerCall.CommitDataExportExecutionInLongOperationMode(Object.InfobaseNode, OperationStartDate);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitForSaveSettings_LongOperationProcessing(Cancel, GoToNext)
	
	// Update the settings of data exchange in this base and the correspondent:
	//  - updating the information of default values in exchange plan nodes
	//  - registration of all data except catalogs and CCT for export in this base and the correspondent bank.
	
	LongOperation = False;
	LongOperationFinished = False;
	LongOperationID = "";
	
	UpdateDataExchangeSettings(Cancel);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='Errors occurred when saving the settings.
		|To solve the problems use the event log.';ru='Возникли ошибки на этапе сохранения настроек.
		|Для решения проблем воспользуйтесь журналом регистрации.'"));
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingSettingsSavingLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

//

&AtClient
Function Attachable_AssistantPageWaitForDataSynchronizationImport_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	MessageFileIDInService = "";
	LongOperationID = "";
	
	AssistantPageWaitForDataSynchronizationImport_LongOperationProcessing(
											Cancel,
											Object.InfobaseNode,
											LongOperation,
											LongOperationID,
											MessageFileIDInService,
											OperationStartDate,
											Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='Errors occurred when synchronizing data.
		|To solve the problems use the event log.';ru='Возникли ошибки на этапе синхронизации данных.
		|Для решения проблем воспользуйтесь журналом регистрации.'"));
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure AssistantPageWaitForDataSynchronizationImport_LongOperationProcessing(
											Cancel,
											InfobaseNode,
											LongOperation,
											ActionID,
											FileID,
											OperationStartDate,
											Password)
	
	OperationStartDate = CurrentSessionDate();
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											True,
											False,
											Enums.ExchangeMessagesTransportKinds.WS,
											LongOperation,
											ActionID,
											FileID,
											True,
											Password);
	
EndProcedure

&AtClient
Function Attachable_AssistantPageWaitingDataSynchronizationImportLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtServer
Procedure AssistantPageWaitingDataSynchronizationImportLongOperationEnd_LongOperationProcessing()
	
	LongOperation = False;
	
EndProcedure

&AtClient
Function Attachable_AssistantPageWaitingDataSynchronizationImportLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	AssistantPageWaitingDataSynchronizationImportLongOperationEnd_LongOperationProcessing();
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingDataSynchronizationDataImport_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitForDataSynchronizationExport_LongOperationProcessing(Cancel, GoToNext)
	
	LongOperation = False;
	LongOperationFinished = False;
	MessageFileIDInService = "";
	LongOperationID = "";
	
	AssistantPageWaitForDataSynchronizationExport_LongOperationProcessing(
											Cancel,
											Object.InfobaseNode,
											LongOperation,
											LongOperationID,
											MessageFileIDInService,
											OperationStartDate,
											Object.WSPassword);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='Errors occurred when synchronizing data.
		|To solve the problems use the event log.';ru='Возникли ошибки на этапе синхронизации данных.
		|Для решения проблем воспользуйтесь журналом регистрации.'"));
		
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure AssistantPageWaitForDataSynchronizationExport_LongOperationProcessing(
											Cancel,
											InfobaseNode,
											LongOperation,
											ActionID,
											FileID,
											OperationStartDate,
											Password)
	
	OperationStartDate = CurrentSessionDate();
	
	// Start the exchange.
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
											Cancel,
											InfobaseNode,
											False,
											True,
											Enums.ExchangeMessagesTransportKinds.WS,
											LongOperation,
											ActionID,
											FileID,
											True,
											Password);
	
EndProcedure

&AtClient
Function Attachable_AssistantPageWaitingDataSynchronizationExportLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageWaitingDataSynchronizationExportLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		DataExchangeServerCall.CommitDataExportExecutionInLongOperationMode(Object.InfobaseNode, OperationStartDate);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageAddingDocumentDataToAccountingRecordSettings_OnOpen(Cancel, SkipPage, IsGoNext)
	
	If IsGoNext Then
		
		ConnectionType = "WebService";
		
		CheckAccountingSettingsAtServer(
										False,
										ConnectionType,
										Object.ExchangePlanName,
										ExternalConnectionParameterStructure(ConnectionType),
										SkipPage);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageAddingDocumentDataToAccountingRecordSettings_OnGoingNext(Cancel)
	
	ConnectionType = "WebService";
	
	CheckAccountingSettingsAtServer(
									Cancel,
									ConnectionType,
									Object.ExchangePlanName,
									ExternalConnectionParameterStructure(ConnectionType),
									False);
	
EndFunction

&AtClient
Function Attachable_AssistantPageReceivingParametersData_OnGoingNext(Cancel)
	
	ConnectionType = "WebService";
	
	ValidateDataReceivingRules(Cancel, ConnectionType);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_AssistantPageDataExchangeCreatedSuccessfully_OnOpen(Cancel, SkipPage, IsGoNext)
	
	PredefinedDataExchangeScheduleOnValueChange();
	
	ExecuteDataExchangeAutomaticallyOnValueChange();
	
EndFunction

//

&AtClient
Procedure ValidateDataReceivingRules(Cancel, ConnectionType)
	
	If NodeDefaultValuesAvailable Then
		
		// Checking the completion of attributes in the form of additional settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("DefaultValuesAtNode", DefaultValuesAtNode);
		
		CheckAttributeFillingOnForm(Cancel, DefaultValuesConfigurationForm, FormParameters, "ValuesDescriptionFullByDefault");
		
	EndIf;
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		// Checking the completion of attributes in the form of additional settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("DefaultValuesAtNode", CorrespondentInfobaseNodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, CorrespondentInfobaseDefaultValueSetupForm, FormParameters, "CorrespondentInfobaseDefaultValueDetails");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckAccountingSettingsAtServer(
									Cancel,
									Val ConnectionType,
									Val ExchangePlanName,
									ConnectionParameters,
									SkipPage)
	
	ErrorInfo = "";
	CorrespondentErrorMessage = "";
	
	NodeCode = CommonUse.ObjectAttributeValue(Object.InfobaseNode, "Code");
	
	SystemAccountingSettingsAreSet = DataExchangeServer.SystemAccountingSettingsAreSet(ExchangePlanName, NodeCode, ErrorInfo);
	
	If ConnectionType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionParameters, ErrorMessageString);
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			DataExchangeServer.ShowMessageAboutError(ErrorMessageString, Cancel);
			Return;
		EndIf;
		
		NodeCode = DataExchangeServerCall.GetThisNodeCodeForExchangePlan(Object.ExchangePlanName);
		
		// Getting the parameters of the second infobase.
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			TargetParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		Else
			
			TargetParameters = ValueFromStringInternal(WSProxy.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		EndIf;
		
		CorrespondentAccountingSettingsAreSet = TargetParameters.SystemAccountingSettingsAreSet;
		
	ElsIf ConnectionType = "ExternalConnection" Then
		
		TransportParameters = DataExchangeServer.TransportSettingsByExternalConnectionParameters(ConnectionParameters);
		Connection = DataExchangeServer.InstallOuterDatabaseJoin(ConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDescription;
		ExternalConnection       = Connection.Join;
		
		If ExternalConnection = Undefined Then
			DataExchangeServer.ShowMessageAboutError(ErrorMessageString, Cancel);
			Return;
		EndIf;
		
		NodeCode = DataExchangeServerCall.GetThisNodeCodeForExchangePlan(Object.ExchangePlanName);
		
		// Getting the parameters of the second infobase.
		If Object.CorrespondentVersion_2_1_1_7 Then
			
			TargetParameters = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_2_0_1_6(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		ElsIf Object.CorrespondentVersion_2_0_1_6 Then
			
			TargetParameters = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_2_0_1_6(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		Else
			
			TargetParameters = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters(ExchangePlanName, NodeCode, CorrespondentErrorMessage));
			
		EndIf;
		
		CorrespondentAccountingSettingsAreSet = TargetParameters.SystemAccountingSettingsAreSet;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If SystemAccountingSettingsAreSet AND CorrespondentAccountingSettingsAreSet Then
		SkipPage = True;
		Return;
	EndIf;
	
	If Not SystemAccountingSettingsAreSet Then
		
		If IsBlankString(ErrorInfo) Then
			ErrorInfo = NStr("en='Accounting parameters have not been specified in this application.';ru='Не заданы параметры учета в этой программе.'");
		EndIf;
		
		LabelAccountingSettings = ErrorInfo;
		Cancel = True;
		
	EndIf;
	
	If Not CorrespondentAccountingSettingsAreSet Then
		
		If IsBlankString(CorrespondentErrorMessage) Then
			CorrespondentErrorMessage = NStr("en='Accounting parameters in the application located in the Internet are not specified.';ru='Не заданы параметры учета в приложении, расположенном в Интернете.'");
		EndIf;
		
		LabelCorrespondentAccountingSettings = CorrespondentErrorMessage;
		Cancel = True;
		
	EndIf;
	
	Items.AccountingSettings.Visible = Not SystemAccountingSettingsAreSet;
	Items.CorrespondentAccountingSettings.Visible = Not CorrespondentAccountingSettingsAreSet;
	
EndProcedure

&AtClient
Procedure CheckJobSettingsForFirstInfobase(Cancel, ConnectionType = "WebService")
	
	If IsBlankString(Object.ThisInfobaseDescription) Then
		
		NString = NStr("en='Specify the name of this application.';ru='Укажите наименование этой программы.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.ThisInfobaseDescription",, Cancel);
		
	EndIf;
	
	If IsBlankString(Object.SecondInfobaseDescription) Then
		
		NString = NStr("en='Specify the application name in the Internet.';ru='Укажите наименование приложения в Интернете.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfobaseDescription",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfobasePrefix) = TrimAll(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en='Infobase prefixes must be different.';ru='Префиксы информационных баз должны быть различными.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SourceInfobasePrefix",, Cancel);
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
		Items.SourceInfobasePrefixExchangeWithService.Visible = True;
		Items.SourceInfobasePrefixExchangeWithService.Enabled = True;
		Items.TargetInfobasePrefixExchangeWithService.Visible = True;
		
		Items.SourceInfobasePrefixExchangeOverWebService.Visible = True;
		Items.SourceInfobasePrefixExchangeOverWebService.Enabled = True;
		Items.TargetInfobasePrefixExchangeOverWebService.Visible = True;
		Items.TargetInfobasePrefixExchangeOverWebService.Enabled = True;
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If NodeFiltersSettingsAvailable Then
		
		// Checking the completion of attributes in the form.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("ConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("Settings", NodesSettingFormContext);
		FormParameters.Insert("FillChecking");
		
		CheckAttributeFillingOnForm(Cancel, NodesSettingForm, FormParameters, "DataExportSettingsDescription");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckJobSettingsForSecondInfobase(Cancel, ConnectionType)
	
	If IsBlankString(Object.SecondInfobaseDescription) Then
		
		NString = NStr("en='Specify the application name.';ru='Укажите наименование программы.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.SecondInfobaseDescription",, Cancel);
		
	EndIf;
	
	If TrimAll(Object.SourceInfobasePrefix) = TrimAll(Object.TargetInfobasePrefix) Then
		
		NString = NStr("en='Infobase prefixes must be different.';ru='Префиксы информационных баз должны быть различными.'");
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If CorrespondentInfobaseNodeFilterSettingsAvailable Then
		
		// Checking completion of the attributes in the form of data migration restriction settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("FilterSsettingsAtNode", CorrespondentInfobaseNodeFilterSetup);
		
		CheckAttributeFillingOnForm(Cancel, CorrespondentInfobaseNodeSettingsForm, FormParameters, "CorrespondentInfobaseDataTransferRestrictionDetails");
		
	EndIf;
	
	If CorrespondentInfobaseNodeDefaultValuesAvailable Then
		
		// Checking the completion of attributes in the form of additional settings.
		FormParameters = New Structure;
		FormParameters.Insert("CorrespondentVersion", ConfigurationVersionCorrespondent);
		FormParameters.Insert("ExternalConnectionParameters", ExternalConnectionParameterStructure(ConnectionType));
		FormParameters.Insert("DefaultValuesAtNode", CorrespondentInfobaseNodeDefaultValues);
		
		CheckAttributeFillingOnForm(Cancel, CorrespondentInfobaseDefaultValueSetupForm, FormParameters, "CorrespondentInfobaseDefaultValueDetails");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AssistantPageSetTransportParametersFILE_OnGoingNextAtServer(Cancel)
	
	DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel, Object, Enums.ExchangeMessagesTransportKinds.FILE);
	
EndProcedure

&AtServer
Procedure AssistantPageSetTransportParametersFTP_OnGoingNextAtServer(Cancel)
	
	DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel, Object, Enums.ExchangeMessagesTransportKinds.FTP);
	
EndProcedure

&AtServer
Procedure AssistantPageSetTransportParametersEMAIL_OnGoingNextAtServer(Cancel)
	
	If Object.UseTransportParametersEMAIL Then
		
		DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel, Object, Enums.ExchangeMessagesTransportKinds.EMAIL);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AssistantPageParameterSetup_OnGoingNextAtServer(Cancel)
	
	If Not ExchangePlans[Object.ExchangePlanName].FindByCode(DataExchangeServer.ExchangePlanNodeCodeString(Object.TargetInfobasePrefix)).IsEmpty() Then
		
		NString = NStr("en='Value of second infobase prefix is not unique.
		|There is already data synchronization for the infobase (application) with specified prefix in the system.
		|Change the prefix value or use the existing synchronization.';ru='Значение префикса второй информационной базы не уникально.
		|В системе уже существует синхронизация данных для информационной базы (программы) с указанным префиксом.
		|Измените значение префикса или используйте существующую синхронизацию.'");
		//
		CommonUseClientServer.MessageToUser(NString,, "Object.TargetInfobasePrefix",, Cancel);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AssistantPageParameterSetup_OnOpenOnServer(Cancel, SkipPage, IsGoNext)
	
	// Filling in the list of exchange transport selection from available kinds (selected by user).
	ValueList = New ValueList;
	
	If Object.UseTransportParametersFILE Then
		EnumValue = Enums.ExchangeMessagesTransportKinds.FILE;
		ValueList.Add(EnumValue, String(EnumValue));
	EndIf;
	
	If Object.UseTransportParametersFTP Then
		EnumValue = Enums.ExchangeMessagesTransportKinds.FTP;
		ValueList.Add(EnumValue, String(EnumValue));
	EndIf;
	
	If Object.UseTransportParametersEMAIL Then
		EnumValue = Enums.ExchangeMessagesTransportKinds.EMAIL;
		ValueList.Add(EnumValue, String(EnumValue));
	EndIf;
	
	ChoiceList = Items.ExchangeMessageTransportKind.ChoiceList;
	ChoiceList.Clear();
	
	For Each Item IN ValueList Do
		
		FillPropertyValues(ChoiceList.Add(), Item);
		
	EndDo;
	
	Items.GroupConnectionMethod.Visible = ChoiceList.Count() > 1;
	
	// Set the kind of transport for
	// exchange messages by default depending on those kinds of transport that were selected by user.
	If Object.UseTransportParametersFILE Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.FILE;
		
	ElsIf Object.UseTransportParametersFTP Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.FTP;
		
	ElsIf Object.UseTransportParametersEMAIL Then
		
		Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.EMAIL;
		
	EndIf;
	
	Items.DataTransferRestrictionsDescriptionFull.Title = StrReplace(Items.DataTransferRestrictionsDescriptionFull.Title,
																	   "%Application%", ExchangePlanSynonym);
	Items.DataTransferRestrictionDetails2.Title = Items.DataTransferRestrictionsDescriptionFull.Title;
	
	Items.ValuesDescriptionFullByDefault.Title = StrReplace(Items.ValuesDescriptionFullByDefault.Title,
																 "%Application%", ExchangePlanSynonym);
	Items.DefaultValueDetails2.Title = Items.ValuesDescriptionFullByDefault.Title;
	
EndProcedure

&AtServer
Procedure AssistantPageWaitForDataExchangeSettingsCreation_LongOperationProcessorOnServer(Cancel)
	
	// create the exchange setting
	ConfigureNewDataExchangeAtServer(Cancel, FilterSsettingsAtNode, DefaultValuesAtNode);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Export the file with the settings for the second IB.
	If Object.ThisIsSettingOfDistributedInformationBase Then
		
		DataProcessorObject = FormAttributeToValue("Object");
		
		DataProcessorObject.RunAssistantParametersDumpIntoConstant(Cancel);
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
	ElsIf Object.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.FILE Then
		
		TemporaryStorageAddress = "";
		
		DumpSettingsExchangeForReceiver(Cancel, TemporaryStorageAddress);
		
		If Not Cancel Then
			
			Object.DataExchangeSettingsFileName = CommonUseClientServer.GetFullFileName(Object.FILEInformationExchangeDirectory, SettingsFilenameForReceiver);
			
			BinaryData = GetFromTempStorage(TemporaryStorageAddress);
			
			DeleteFromTempStorage(TemporaryStorageAddress);
			
			// get the file
			BinaryData.Write(Object.DataExchangeSettingsFileName);
			
		EndIf;
		
	EndIf;
	
	Items.ExecuteDataExchangeNow21.Title = StrReplace(Items.ExecuteDataExchangeNow21.Title, "%Application%", ExchangePlanSynonym);
	
EndProcedure

&AtServer
Procedure AssistantPageWaitForCheckExternalConnectionConnected_LongOperationProcessorOnServer(Cancel)
	
	If Object.COMInfobaseOperationMode = 0 Then
		
		If IsBlankString(Object.COMInfobaseDirectory) Then
			
			NString = NStr("en='Specify the infobase directory.';ru='Укажите каталог информационной базы.'");
			CommonUseClientServer.MessageToUser(NString,, "Object.COMInfobaseDirectory",, Cancel);
			Cancel = True;
			Return;
			
		EndIf;
		
	Else
		
		If IsBlankString(Object.COMServerName1CEnterprise) Then
			
			NString = NStr("en='Specify the server cluster name.';ru='Укажите имя кластера серверов.'");
			CommonUseClientServer.MessageToUser(NString,, "Object.COMServerName1CEnterprise",, Cancel);
			Cancel = True;
			Return;
			
		ElsIf IsBlankString(Object.COMInfobaseNameAtServer1CEnterprise) Then
			
			NString = NStr("en='Specify the infobase name.';ru='Укажите имя информационной базы.'");
			CommonUseClientServer.MessageToUser(NString,, "Object.COMInfobaseNameAtServer1CEnterprise",, Cancel);
			Cancel = True;
			Return;
			
		EndIf;
		
	EndIf;
	
	Result = DataExchangeServer.InstallOuterDatabaseJoin(Object);
	ExternalConnection = Result.Join;
	ErrorAttachingAddIn = Result.ErrorAttachingAddIn;
	If ExternalConnection = Undefined Then
		CommonUseClientServer.MessageToUser(Result.ErrorShortInfo,,,, Cancel);
		Return;
	EndIf;
	
	// {Handler: WhenConnectingToCorrespondent} Start
	ConfigurationVersionCorrespondent = ExternalConnection.Metadata.Version;
	
	OnConnectingToCorrespondent(Cancel, ConfigurationVersionCorrespondent);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: WhenConnectingToCorrespondent} End
	
	CorrespondentVersions = DataExchangeServer.CorrespondentVersionsViaExternalConnection(ExternalConnection);
	
	Object.CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	Object.CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	
	Try
		ExchangePlanExists = ExternalConnection.DataExchangeExternalConnection.ExchangePlanExists(Object.ExchangePlanName);
	Except
		ExchangePlanExists = False;
	EndTry;
	
	If Not ExchangePlanExists Then
		
		Message = NStr("en='There is no data synchronization for the specified application.';ru='Синхронизация данных с указанной программой не предусмотрена.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		Return;
		
	EndIf;
	
	If Lower(InfobaseConnectionString()) = Lower(ExternalConnection.InfobaseConnectionString()) Then
		
		Message = NStr("en='Connection settings for this infobase are set.';ru='Заданы настройки подключения к этой информационной базе.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		Return;
		
	EndIf;
	
	Object.TargetInfobasePrefix           = ExternalConnection.GetFunctionalOption("InfobasePrefix");
	Object.TargetInfobasePrefixIsSet = ValueIsFilled(Object.TargetInfobasePrefix);
	
	// Checking the existence of exchange with correspondent base.
	CheckWhetherDataExchangeWithSecondBaseExists(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	If Not Object.TargetInfobasePrefixIsSet Then
		Object.TargetInfobasePrefix = ExternalConnection.DataExchangeExternalConnection.InfobasePrefixByDefault();
	EndIf;
	
	Items.TargetInfobasePrefix.Visible = Not Object.TargetInfobasePrefixIsSet;
	
	Object.SecondInfobaseDescription = ExternalConnection.DataExchangeExternalConnection.PredefinedExchangePlanNodeDescription(Object.ExchangePlanName);
	SecondInfobaseDescriptionSet = Not IsBlankString(Object.SecondInfobaseDescription);
	
	Items.SecondInfobaseDescription2.ReadOnly = SecondInfobaseDescriptionSet;
	
	If Not SecondInfobaseDescriptionSet Then
		
		Object.SecondInfobaseDescription = ExternalConnection.DataExchangeReUse.ThisInfobaseName();
		
	EndIf;
	
	NodeConfigurationForm = "";
	CorrespondentInfobaseNodeSettingsForm = "";
	DefaultValuesConfigurationForm = "";
	CorrespondentInfobaseDefaultValueSetupForm = "";
	NodesSettingForm = "";
	
	FilterSsettingsAtNode    = DataExchangeServer.FilterSsettingsAtNode(Object.ExchangePlanName, ConfigurationVersionCorrespondent, NodeConfigurationForm, Object.ExchangeSettingsVariant);
	DefaultValuesAtNode = DataExchangeServer.DefaultValuesAtNode(Object.ExchangePlanName, ConfigurationVersionCorrespondent, DefaultValuesConfigurationForm, Object.ExchangeSettingsVariant);
	
	CorrespondentInfobaseNodeFilterSetup    = DataExchangeServer.CorrespondentInfobaseNodeFilterSetup(Object.ExchangePlanName, ConfigurationVersionCorrespondent, CorrespondentInfobaseNodeSettingsForm, Object.ExchangeSettingsVariant);
	CorrespondentInfobaseNodeDefaultValues = DataExchangeServer.CorrespondentInfobaseNodeDefaultValues(Object.ExchangePlanName, ConfigurationVersionCorrespondent, CorrespondentInfobaseDefaultValueSetupForm, Object.ExchangeSettingsVariant);
	
	CorrespondentInfobaseNodeFilterSettingsAvailable    = CorrespondentInfobaseNodeFilterSetup.Count() > 0
		AND DataExchangeServer.ExchangePlanSettingValue(Object.ExchangePlanName, "DisplayFiltersSettingOnCorrespondentBaseNode", Object.ExchangeSettingsVariant);
	CorrespondentInfobaseNodeDefaultValuesAvailable = CorrespondentInfobaseNodeDefaultValues.Count() > 0
		AND DataExchangeServer.ExchangePlanSettingValue(Object.ExchangePlanName, "DisplayDefaultValuesOnCorrespondentBaseNode", Object.ExchangeSettingsVariant);
	
	Items.RestrictionsGroupBorder4.Visible                          = CorrespondentInfobaseNodeFilterSettingsAvailable;
	Items.DefaultValueGroupBorder4.Visible                  = CorrespondentInfobaseNodeDefaultValuesAvailable;
	Items.CorrespondentInfobaseDefaultValueGroupBorder.Visible = CorrespondentInfobaseNodeDefaultValuesAvailable;
	
	CorrespondentInfobaseDataTransferRestrictionDetails = DataExchangeServer.CorrespondentInfobaseDataTransferRestrictionDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeFilterSetup, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	CorrespondentInfobaseDefaultValueDetails       = DataExchangeServer.CorrespondentInfobaseDefaultValueDetails(Object.ExchangePlanName, CorrespondentInfobaseNodeDefaultValues, ConfigurationVersionCorrespondent, Object.ExchangeSettingsVariant);
	
	CorrespondentAccountingSettingsCommentLabel = DataExchangeServer.CorrespondentInfobaseAccountingSettingsSetupComment(Object.ExchangePlanName, ConfigurationVersionCorrespondent);
	
EndProcedure

&AtServer
Procedure CheckWhetherDataExchangeWithSecondBaseExists(Cancel)
	
	NodeCode = ?(IsBlankString(Object.CorrespondentNodeCode),
					DataExchangeServer.ExchangePlanNodeCodeString(Object.TargetInfobasePrefix),
					Object.CorrespondentNodeCode);
	
	If Not IsBlankString(NodeCode)
		AND Not ExchangePlans[Object.ExchangePlanName].FindByCode(NodeCode).IsEmpty() Then
		
		Message = NStr("en='Data synchronization between the applications was already configured.';ru='Синхронизация данных между программами уже была настроена ранее.'");
		CommonUseClientServer.MessageToUser(Message,,,, Cancel);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable part - Initialization of the assistant's transitions.

&AtServer
Procedure FirstExchangeSetupStageGoToTable()
	
	GoToTable.Clear();
	
	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 1;
	NewTransition.MainPageName  = "AssistantPageStart";
	NewTransition.NavigationPageName = "NavigationPageStart";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 2;
	NewTransition.MainPageName  = "AssistantPageAssistantRunModeChoice";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.OnOpenHandlerName = "AssistantPageAssistantRunModeChoice_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 3;
	NewTransition.MainPageName  = "AssistantPageSetTransportParametersFILE";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPage_SetTransportParametersFILEOnGoNext";
	NewTransition.OnOpenHandlerName = "AssistantPageSetTransportParametersFILE_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 4;
	NewTransition.MainPageName  = "AssistantPageSetTransportParametersFTP";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageSetTransportParametersFTP_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageSetTransportParametersFTP_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 5;
	NewTransition.MainPageName  = "AssistantPageSetTransportParametersEMAIL";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageSetTransportParametersEMAIL_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageSetTransportParametersEMAIL_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 6;
	NewTransition.MainPageName  = "AssistantPageParameterSetup";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageParameterSetup_OnGoingNext";
	NewTransition.OnOpenHandlerName = "PageAssistantParameterSetup_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 7;
	NewTransition.MainPageName  = "AssistantPageExchangeSetupResults";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.OnOpenHandlerName = "AssistantPageExchangeSetupResults_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 8;
	NewTransition.MainPageName  = "AssistantPageWaitForDataExchangeSettingsCreation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataExchangeSettingsCreation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 9;
	NewTransition.MainPageName  = "AssistantPageEndWithSettingsExport";
	NewTransition.NavigationPageName = "NavigationPageEnd";
	
EndProcedure

&AtServer
Procedure SecondExchangeSetupStageGoToTable()
	
	GoToTable.Clear();
	
	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 1;
	NewTransition.MainPageName  = "AssistantPageStart";
	NewTransition.NavigationPageName = "NavigationPageStart";
	NewTransition.GoNextHandlerName = "AssistantPageStart_OnGoingNext";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 2;
	NewTransition.MainPageName  = "AssistantPageSetTransportParametersFILE";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPage_SetTransportParametersFILEOnGoNext";
	NewTransition.OnOpenHandlerName = "AssistantPageSetTransportParametersFILE_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 3;
	NewTransition.MainPageName  = "AssistantPageSetTransportParametersFTP";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageSetTransportParametersFTP_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageSetTransportParametersFTP_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 4;
	NewTransition.MainPageName  = "AssistantPageSetTransportParametersEMAIL";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageSetTransportParametersEMAIL_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageSetTransportParametersEMAIL_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 5;
	NewTransition.MainPageName  = "AssistantPageSecondSetupStageParameterSetup";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageSecondSetupStageParameterSetup_OnGoingNext";
	NewTransition.OnOpenHandlerName = "PageAssistantParameterSetup_OnOpen";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 6;
	NewTransition.MainPageName  = "AssistantPageExchangeSetupResults";
	NewTransition.NavigationPageName = "NavigationPageEndAndBack";
	NewTransition.OnOpenHandlerName = "AssistantPageExchangeSetupResults_OnOpen";
	
EndProcedure

&AtServer
Procedure DataExchangeOverExternalConnectionSettingsGoToTable()
	
	GoToTable.Clear();
	
	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 1;
	NewTransition.MainPageName  = "AssistantPageStart";
	NewTransition.NavigationPageName = "NavigationPageStart";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 2;
	NewTransition.MainPageName  = "AssistantPageAssistantRunModeChoice";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageAssistantRunModeChoice_OnSkipForward";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 3;
	NewTransition.MainPageName  = "AssistantPageWaitForCheckExternalConnectionConnected";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCheckExternalConnectionConnected_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 4;
	NewTransition.MainPageName  = "AssistantPageFirstInfobaseExternalConnectionParameterSetup";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageFirstInfobaseExternalConnectionParameterSetup_OnGoingNext";
	NewTransition.OnOpenHandlerName = "PageOfAssistantToConfigureSettingsForExternalConnectionFirstBase_AtOpeningOfThe";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 5;
	NewTransition.MainPageName  = "AssistantPageSecondInfobaseExternalConnectionParameterSetup";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageSecondInfobaseExternalConnectionParameterSetup_OnGoingNext";
	NewTransition.OnOpenHandlerName = "PageOfAssistantToConfigureSettingsForExternalConnectionSecondBase_AtOpeningOfThe";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 6;
	NewTransition.MainPageName  = "AssistantPageExchangeSetupResults";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.OnOpenHandlerName = "AssistantPageExchangeSetupResults_OnOpen_ExternalConnection";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 7;
	NewTransition.MainPageName  = "AssistantPageWaitForDataExchangeSettingsCreation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataExchangeSettingsCreationOverExternalConnection_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 8;
	NewTransition.MainPageName  = "AssistantPageEndWithExchangeOverExternalConnection";
	NewTransition.NavigationPageName = "NavigationPageEnd";
	
EndProcedure

&AtServer
Procedure ExchangeOverWebServiceSetupGoToTable()
	
	GoToTable.Clear();
	
	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 1;
	NewTransition.MainPageName  = "AssistantPageStart";
	NewTransition.NavigationPageName = "NavigationPageStart";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 2;
	NewTransition.MainPageName  = "AssistantPageAssistantRunModeChoice";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	
	// Setting connection parameters; Connection verification.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 3;
	NewTransition.MainPageName  = "AssistantPageWaitForConnectionToServiceCheck";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCheckConnectionViaWebService_LongOperationProcessing";
	
	// Setting the parameters for data export (filters on the nodes).

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 4;
	NewTransition.MainPageName  = "AssistantPageDataExchangeOverWebServiceParameterSetup";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageDataExchangeParameterSetup_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageDataExchangeParameterSetup_OnOpen";
	
	// Default values when importing data.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 5;
	NewTransition.MainPageName  = "AssistantPageReceivingParametersData";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageDataReceivingParameters_OnSkipForward";
	
	// Creating exchange settings; Registration of the catalogs for export.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 6;
	NewTransition.MainPageName  = "AssistantPageWaitForExchangeSettingsCreationDataAnalysis";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForExchangeSettingsCreationDataAnalysis_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 7;
	NewTransition.MainPageName  = "AssistantPageWaitForExchangeSettingsCreationDataAnalysis";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForExchangeSettingsCreationDataAnalysisLongOperation_LongOperationProcessing";
	
	// Getting the catalogs from the correspondent.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 8;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisGetMessage";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataAnalysisGetMessage_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 9;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisGetMessage";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataAnalysisGetMessageLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 10;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisGetMessage";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataAnalysisGetMessageLongOperationEnd_LongOperationProcessing";
	
	// Automatic data mapping in progress; Getting mapping statistics.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 11;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisAutomaticMapping";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForAutomaticMappingDataAnalysis_LongOperationProcessing";
	
	// Manual data mapping.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 12;
	NewTransition.MainPageName  = "AssistantPageDataMapping";
	NewTransition.NavigationPageName = "NavigationPageContinuationOnlyNext";
	NewTransition.GoNextHandlerName = "AssistantPageDataMapping_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageDataMapping_OnOpen";
	
	// Synchronization of catalogs.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 13;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationImport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 14;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitingCatalogSynchronizationImportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 15;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationExport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 16;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationExportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 17;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationExportLongOperationEnd_LongOperationProcessing";
	
	// Accounting settings

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 18;
	NewTransition.MainPageName  = "AssistantPageAddingDocumentDataToAccountingRecordSettings";
	NewTransition.NavigationPageName = "NavigationPageContinuationOnlyNext";
	NewTransition.GoNextHandlerName = "AssistantPageAddingDocumentDataToAccountingRecordSettings_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageAddingDocumentDataToAccountingRecordSettings_OnOpen";
	
	// Saving settings; Registration of all data for export, except catalogs.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 19;
	NewTransition.MainPageName  = "AssistantPageWaitForSaveSettings";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForSaveSettings_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 20;
	NewTransition.MainPageName  = "AssistantPageWaitForSaveSettings";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForSaveSettingsLongOperation_LongOperationProcessing";
	
	// Synchronization of all data except the catalogs.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 21;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationImport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 22;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationImportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 23;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationImportLongOperationEnd_LongOperationProcessing";
	
	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 24;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitingDataSynchronizationDataImport_LongOperationProcessing";
	
	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 25;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationExport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 26;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationExportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 27;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationExportLongOperationEnd_LongOperationProcessing";
	
	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 28;
	NewTransition.MainPageName  = "AssistantPageDataExchangeCreatedSuccessfully";
	NewTransition.NavigationPageName = "NavigationPageEnd";
	NewTransition.OnOpenHandlerName = "AssistantPageDataExchangeSuccessfullyCreated_OnOpen";
	
EndProcedure

&AtServer
Procedure ExtendedExchangeWithServiceSetupGoToTable()
	
	GoToTable.Clear();
	
	// Setting connection parameters; Connection verification.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 1;
	NewTransition.MainPageName  = "AssistantPageStartExchangeWithServiceSetup";
	NewTransition.NavigationPageName = "NavigationPageStart";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 2;
	NewTransition.MainPageName  = "AssistantPageWaitForConnectionToServiceCheck";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCheckConnectionViaWebService_LongOperationProcessing";
	
	// Setting the parameters for data export (filters on the nodes).

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 3;
	NewTransition.MainPageName  = "AssistantPageDataExchangeSetupParameter";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageDataExchangeParameterSetup_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageDataExchangeParameterSetup_OnOpen";
	
	// Default values when importing data.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 4;
	NewTransition.MainPageName  = "AssistantPageReceivingParametersData";
	NewTransition.NavigationPageName = "NavigationPageContinuation";
	NewTransition.GoNextHandlerName = "AssistantPageDataReceivingParameters_OnSkipForward";
	
	// Creating exchange settings; Registration of the catalogs for export.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 5;
	NewTransition.MainPageName  = "AssistantPageWaitForExchangeSettingsCreationDataAnalysis";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForExchangeSettingsCreationDataAnalysis_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 6;
	NewTransition.MainPageName  = "AssistantPageWaitForExchangeSettingsCreationDataAnalysis";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForExchangeSettingsCreationDataAnalysisLongOperation_LongOperationProcessing";
	
	// Getting the catalogs from the correspondent.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 7;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisGetMessage";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataAnalysisGetMessage_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 8;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisGetMessage";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataAnalysisGetMessageLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 9;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisGetMessage";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataAnalysisGetMessageLongOperationEnd_LongOperationProcessing";
	
	// Automatic data mapping in progress; Getting mapping statistics.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 10;
	NewTransition.MainPageName  = "AssistantPageWaitForDataAnalysisAutomaticMapping";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForAutomaticMappingDataAnalysis_LongOperationProcessing";
	
	// Manual data mapping.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 11;
	NewTransition.MainPageName  = "AssistantPageDataMapping";
	NewTransition.NavigationPageName = "NavigationPageContinuationOnlyNext";
	NewTransition.GoNextHandlerName = "AssistantPageDataMapping_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageDataMapping_OnOpen";
	
	// Synchronization of catalogs.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 12;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationImport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 13;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitingCatalogSynchronizationImportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 14;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationExport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 15;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationExportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 16;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForCatalogSynchronizationExportLongOperationEnd_LongOperationProcessing";
	
	// Accounting settings

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 17;
	NewTransition.MainPageName  = "AssistantPageAddingDocumentDataToAccountingRecordSettings";
	NewTransition.NavigationPageName = "NavigationPageContinuationOnlyNext";
	NewTransition.GoNextHandlerName = "AssistantPageAddingDocumentDataToAccountingRecordSettings_OnGoingNext";
	NewTransition.OnOpenHandlerName = "AssistantPageAddingDocumentDataToAccountingRecordSettings_OnOpen";
	
	// Saving settings; Registration of all data for export, except catalogs.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 18;
	NewTransition.MainPageName  = "AssistantPageWaitForSaveSettings";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForSaveSettings_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 19;
	NewTransition.MainPageName  = "AssistantPageWaitForSaveSettings";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForSaveSettingsLongOperation_LongOperationProcessing";
	
	// Synchronization of all data except the catalogs.

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 20;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationImport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 21;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationImportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 22;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationImportLongOperationEnd_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 23;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitingDataSynchronizationDataImport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 24;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationExport_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 25;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationExportLongOperation_LongOperationProcessing";

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 26;
	NewTransition.MainPageName  = "DataSynchronizationExpectation";
	NewTransition.NavigationPageName = "NavigationPageWait";
	NewTransition.LongOperation = True;
	NewTransition.LongOperationHandlerName = "AssistantPageWaitForDataSynchronizationExportLongOperationEnd_LongOperationProcessing";
	

	NewTransition = GoToTable.Add();
	NewTransition.GoToNumber = 27;
	NewTransition.MainPageName  = "AssistantPageDataExchangeCreatedSuccessfully";
	NewTransition.NavigationPageName = "NavigationPageEnd";
	NewTransition.OnOpenHandlerName = "AssistantPageDataExchangeSuccessfullyCreated_OnOpen";
	
EndProcedure

#EndRegion
