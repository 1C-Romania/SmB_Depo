&AtClient
Var ExternalResourcesAllowed;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SetFormItemsVisible();
	
	If ValueIsFilled(Record.ExchangeMessageTransportKindByDefault) Then
		
		PageName = "TransportSettings[TransportKind]";
		PageName = StrReplace(PageName, "[TransportKind]"
		, CommonUse.NameOfEnumValue(Record.ExchangeMessageTransportKindByDefault));
		
		If Items[PageName].Visible Then
			
			Items.TransportKindPages.CurrentPage = Items[PageName];
			
		EndIf;
		
	EndIf;
	
	EventLogMonitorMessageTextEstablishingConnectionToWebService 
		= DataExchangeServer.EventLogMonitorMessageTextEstablishingConnectionToWebService();
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.AccessToInternetParameters.Visible = True;
		Items.ParametersInInternetAccess1.Visible = True;
	Else
		Items.AccessToInternetParameters.Visible = False;
		Items.ParametersInInternetAccess1.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	InfobaseRunModeOnChange();
	
	OSAuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingAlert = New NotifyDescription("AllowExternalResourceEnd", ThisObject, WriteParameters);
		Queries = CreateQueryOnExternalResourcesUse(Record, True, True, True, True);
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
		
		Cancel = True;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FILEInformationExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "FILEInformationExchangeDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FILEInformationExchangeDirectoryOpening(Item, StandardProcessing)
	
	DataExchangeClient.HandlerOfOpeningOfFileOrDirectory(Record, "FILEInformationExchangeDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "COMInfobaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryOpen(Item, StandardProcessing)

DataExchangeClient.HandlerOfOpeningOfFileOrDirectory(Record, "COMInfobaseDirectory", StandardProcessing)

EndProcedure

&AtClient
Procedure COMInfobaseRunModeOnChange(Item)
	
	InfobaseRunModeOnChange();
	
EndProcedure

&AtClient
Procedure COMAuthenticationOSOnChange(Item)
	
	OSAuthenticationOnChange();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CheckCOMConnection(Command)
	
	ClosingAlert = New NotifyDescription("CheckCOMConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Record, True, False, False, False);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure CheckWSConnection(Command)
	
	ClosingAlert = New NotifyDescription("CheckWSConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Record, False, False, True, False);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure CheckFILEConnection(Command)
	
	ClosingAlert = New NotifyDescription("CheckFILEConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Record, False, True, False, False);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure CheckConnectionFTP(Command)
	
	ClosingAlert = New NotifyDescription("CheckFTPConnectionEnd", ThisObject);
	Queries = CreateQueryOnExternalResourcesUse(Record, False, False, False, True);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
	
EndProcedure

&AtClient
Procedure CheckConnectionEMAIL(Command)
	
	CheckConnection("EMAIL");
	
EndProcedure

&AtClient
Procedure AccessToInternetParameters(Command)
	
	DataExchangeClient.OpenProxyServerParameterForm();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CheckConnection(TransportKindString)
	
	Cancel = False;
	
	ClearMessages();
	
	CheckConnectionAtServer(Cancel, TransportKindString);
	
	NotifyUserAboutConnectionResults(Cancel);
	
EndProcedure

&AtServer
Procedure CheckConnectionAtServer(Cancel, TransportKindString)
	
	DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel, Record, Enums.ExchangeMessagesTransportKinds[TransportKindString]);
	
EndProcedure

&AtServer
Procedure CheckExternalConnection(Cancel)
	
	DataExchangeServerCall.CheckExternalConnection(Cancel, Record);
	
EndProcedure

&AtServer
Procedure CheckWSConnectionEstablished(Cancel)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, Record);
	
	UserMessage = "";
	If Not DataExchangeServer.IsConnectionToCorrespondent(Record.Node, ConnectionParameters, UserMessage) Then
		CommonUseClientServer.MessageToUser(UserMessage,,,, Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemsVisible()
	
	UsedTransports = New Array;
	
	If ValueIsFilled(Record.Node) Then
		
		UsedTransports = DataExchangeReUse.UsedTransportsOfExchangeMessages(Record.Node);
		
	EndIf;
	
	For Each TransportTypePage IN Items.TransportKindPages.ChildItems Do
		
		TransportTypePage.Visible = False;
		
	EndDo;
	
	Items.ExchangeMessageTransportKindByDefault.ChoiceList.Clear();
	
	For Each Item IN UsedTransports Do
		
		FormItemName = "TransportSettings[TransportKind]";
		FormItemName = StrReplace(FormItemName, "[TransportKind]", CommonUse.NameOfEnumValue(Item));
		
		Items[FormItemName].Visible = True;
		
		Items.ExchangeMessageTransportKindByDefault.ChoiceList.Add(Item, String(Item));
		
	EndDo;
	
	If UsedTransports.Count() = 1 Then
		
		Items.TransportKindPages.PagesRepresentation = FormPagesRepresentation.None;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyUserAboutConnectionResults(Val ErrorConnection)
	
	WarningText = ?(ErrorConnection, NStr("en = 'Failed to install connection.'"),
											   NStr("en = 'Connection has been successfully installed.'"));
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure InfobaseRunModeOnChange()
	
	CurrentPage = ?(Record.COMInfobaseOperationMode = 0, Items.FileModePage, Items.ClientServerModePage);
	
	Items.InfobaseRunModes.CurrentPage = CurrentPage;
	
EndProcedure

&AtClient
Procedure OSAuthenticationOnChange()
	
	Items.COMUserName.Enabled    = Not Record.COMAuthenticationOS;
	Items.COMUserPassword.Enabled = Not Record.COMAuthenticationOS;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateQueryOnExternalResourcesUse(Val Record, AskCOM,
	AskFILE, AskWS, AskFTP)
	
	PermissionsQueries = New Array;
	InformationRegisters.ExchangeTransportSettings.QueryOnExternalResourcesUse(PermissionsQueries,
		Record, AskCOM, AskFILE, AskWS, AskFTP);
	Return PermissionsQueries;
	
EndFunction

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
		
		ClearMessages();
		
		CheckWSConnectionEstablished(Cancel);
		
		NotifyUserAboutConnectionResults(Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckCOMConnectionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Cancel = False;
		
		ClearMessages();
		
		If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase Then
			
			CommonUseClient.RegisterCOMConnector(False);
			
		EndIf;
		
		CheckExternalConnection(Cancel);
		
		NotifyUserAboutConnectionResults(Cancel);
		
	EndIf;
	
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
