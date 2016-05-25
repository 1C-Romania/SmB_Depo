
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	StartUOSOnStart = False;
	
	OnlineSupportMonitorOverridable.UseMonitorDisplayOnWorkStart(
		StartUOSOnStart);
	
	Items.GroupSettingsRunAtStart.Visible = (StartUOSOnStart = True);
	
	CommonSettingsStorage.Save(
		"OnlineUserSupport",
		"InformationWindowUpdateHash",
		Parameters.HashInformationMonitor);
	
	UserTitle = String(Parameters.login);
	
	Items.LoginLabel.Title = UserTitle;
	Items.LoginLabel.ToolTip = NStr("en = 'Login of the current online support user:'")
		+ " " + UserTitle;
	
	GenerateForm(Parameters);
	
	LaunchSetting = CommonSettingsStorage.Load(
		"OnlineUserSupport",
		"AlwaysShowOnApplicationStart");
	
	If LaunchSetting = Undefined Then
		ShowSettingsAtStart = 0;
	ElsIf LaunchSetting = True Then
		ShowOnUpdate = CommonSettingsStorage.Load(
			"OnlineUserSupport",
			"ShowOnStartOnlyOnChange");
		If ShowOnUpdate = True Then
			ShowSettingsAtStart = 1;
		Else
			ShowSettingsAtStart = 0;
		EndIf;
	Else
		ShowSettingsAtStart = 2;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
#If WebClient Then
	ShowMessageBox(,
		NStr("en = 'Some references may work incorrectly in the web client.
			|Sorry for the inconvenience.'"),
		,
		NStr("en = 'Online user support'"));
#EndIf
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not SoftwareClosing Then
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ClickExitLabel(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure HTMLDocumentOnClick(Item, EventData, StandardProcessing)
	
	ActiveItemData = Item.Document.activeElement;
	If ActiveItemData = Undefined Then
		Return;
	EndIf;
	
	Try
		ActiveItemClass = ActiveItemData.HRef;
	Except
		Return;
	EndTry;
	
	Try
		ItemTarget = ActiveItemData.target;
	Except
		ItemTarget = Undefined;
	EndTry;
	
	Try
		ItemTitle = ActiveItemData.innerHTML;
	Except
		ItemTitle = Undefined;
	EndTry;
	
	If ItemTarget <> Undefined Then
		
		If Lower(TrimAll(ItemTarget)) = "_blank" Then
			StandardProcessing = False;
			OnlineUserSupportClient.OpenInternetPage(
				ActiveItemClass,
				ItemTitle);
		EndIf;
		
	EndIf;
	
	If Find(Lower(TrimAll(ActiveItemClass)),"openupdate") <> 0 Then
		
		StandardProcessing = False;
		
		UpdateProcessorVersion = OnlineUserSupportClientServer.UpdateProcessorVersion();
		
		If IsBlankString(UpdateProcessorVersion) Then
			ShowMessageBox(
				,
				NStr("en = 'Mechanism of the automatic update is unavailable.'"));
			Return;
		EndIf;
		
		ErrorInfo = "";
		UpdateProcessorMainFormName = ConfigurationUpdateMainProcessorFormName(
			ErrorInfo);
		
		If UpdateProcessorMainFormName <> Undefined Then
			OpenForm(UpdateProcessorMainFormName);
		Else
			If Not IsBlankString(ErrorInfo) Then
				ShowMessageBox(, ErrorInfo);
				Return;
			EndIf;
		EndIf;
		
	ElsIf Find(Lower(TrimAll(ActiveItemClass)), "problemupdate") <> 0 Then
		
		StandardProcessing = False;
		OnlineUserSupportClient.OpenDialogForSendingEmail(
			InteractionContext,
			MessageParametersToTechicalSupportUpdate());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsShowAtStartOnChange(Item)
	
	SettingsShowOnStartOnChangeOnServer(ShowSettingsAtStart);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills in the browser address
&AtServer
Procedure GenerateForm(FormParameters)
	
	If FormParameters = Undefined Then
		Return;
	EndIf;
	
	URL = Undefined;
	FormParameters.Property("URL", URL);
	
	If URL <> Undefined Then
		HTMLDocument = URL;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SettingsShowOnStartOnChangeOnServer(ShowSettingsAtStart)
	
	If ShowSettingsAtStart = 0 Then
		CommonSettingsStorage.Save(
			"OnlineUserSupport",
			"AlwaysShowOnApplicationStart",
			True);
		CommonSettingsStorage.Save(
			"OnlineUserSupport",
			"ShowOnStartOnlyOnChange",
			False);
	ElsIf ShowSettingsAtStart = 1 Then
		CommonSettingsStorage.Save(
			"OnlineUserSupport",
			"AlwaysShowOnApplicationStart",
			True);
		CommonSettingsStorage.Save(
			"OnlineUserSupport",
			"ShowOnStartOnlyOnChange",
			True);
	Else
		CommonSettingsStorage.Save(
			"OnlineUserSupport",
			"AlwaysShowOnApplicationStart",
			False);
		CommonSettingsStorage.Save(
			"OnlineUserSupport",
			"ShowOnStartOnlyOnChange",
			False);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ConfigurationUpdateMainProcessorFormName(ErrorInfo)
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ErrorInfo = NStr("en = 'Mechanism of the automatic update is unavailable.'");
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			NStr("en = 'An error occurred while calling an automatic update. Mechanism of the automatic update is unavailable.'"));
		Return Undefined;
	EndIf;
	
	MetadataDataProcessor = Metadata.DataProcessors.Find("ConfigurationUpdate");
	If MetadataDataProcessor = Undefined Then
		
		ErrorInfo = NStr("en = 'Mechanism of the automatic update is unavailable.'");
		
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			NStr("en = 'An error occurred while calling an automatic update. The ConfigurationUpdate processor is unavailable in the metadata.'"));
		
		Return Undefined;
		
	Else
		
		MetadataMainForm = MetadataDataProcessor.DefaultForm;
		If MetadataMainForm <> Undefined Then
			Return MetadataMainForm.FullName();
		Else
			ErrorInfo = NStr("en = 'An error occurred while calling an automatic update.
				|For more details see the event log.'");
			OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
				NStr("en = 'An error occurred while calling an automatic update. The main form of the ConfigurationUpdate processor is unavailable.'"));
			Return Undefined;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function MessageParametersToTechicalSupportUpdate()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en = 'Online support. Problems with the configuration update.'"));
	
	MessageText = NStr("en = 'Hello, the following problems occurred while updating the configuration to a new release: Login %1 Registration number: %2 %TechnicalParameters% ----------------------------------------------- Sincerely, .'");
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	RegNumber = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"regnumber");
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		MessageText,
		UserLogin,
		RegNumber);
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
EndFunction

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
