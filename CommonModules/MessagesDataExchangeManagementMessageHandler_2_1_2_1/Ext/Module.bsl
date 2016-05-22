////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER FOR THE VERSION
//  2.1.2.1 OF THE DATA EXCHANGE MANAGEMENT MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns namespace for message interface version
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Manage";
	
EndFunction

// Returns a message interface version served by the handler
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns default type for version messages
Function BaseType() Export
	
	Return MessagesSaaSReUse.TypeBody();
	
EndFunction

// Processes incoming messages in service model
//
// Parameters:
//  Message - ObjectXDTO,
//  incoming message, Sender - ExchangePlanRef.Messaging, exchange plan
//  node, corresponding to message sender MessageProcessed - Boolean, a flag showing that the message is successfully processed. The value of
//    this parameter shall be set as equal to True if the message was successfully read in this handler
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageHandled) Export
	
	MessageHandled = True;
	
	Dictionary = MessagesDataExchangeManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageSetExchangeStep1(Package()) Then
		
		SetExchangeStep1(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageSetExchangeStep2(Package()) Then
		
		SetExchangeStep2(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageImportExchangeMessage(Package()) Then
		
		ImportExchangeMessage(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageGetCorrespondentData(Package()) Then
		
		GetCorrespondentData(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageGetCorrespondentNodesCommonData(Package()) Then
		
		GetCorrespondentNodesCommonData(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageGetCorrespondentAccountingParameters(Package()) Then
		
		GetCorrespondentAccountingParameters(Message, Sender);
		
	Else
		
		MessageHandled = False;
		Return;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetExchangeStep1(Message, Sender)
	
	Body = Message.Body;
	
	Correspondent = Undefined;
	
	BeginTransaction();
	Try
		
		ThisNodeCode = CommonUse.ObjectAttributeValue(ExchangePlans[Body.ExchangePlan].ThisNode(), "Code");
		
		If Not IsBlankString(ThisNodeCode)
			AND ThisNodeCode <> Body.Code Then
			MessageString = NStr("en = 'Predefined node code in this application %1 does not correspond to the expected %2. Exchange plan: %3'");
			MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, ThisNodeCode, Body.Code, Body.ExchangePlan);
			Raise MessageString;
		EndIf;
		
		CorrespondentEndPoint = ExchangePlans.MessageExchange.FindByCode(Body.EndPoint);
		
		If CorrespondentEndPoint.IsEmpty() Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Correspondent end point with the %1 script is not found.'"),
				Body.EndPoint);
		EndIf;
		
		Prefix = "";
		If Message.IsSet("AdditionalInfo") Then
			Prefix = XDTOSerializer.ReadXDTO(Message.AdditionalInfo).Prefix;
		EndIf;
		
		FilterSsettingsAtNode = XDTOSerializer.ReadXDTO(Body.FilterSettings);
		
		// {Handler: AtReceivingSenderData} Begin
		ExchangePlans[Body.ExchangePlan].OnSendersDataGet(FilterSsettingsAtNode, False);
		// {Handler: AtReceivingSenderData} End
		
		// Create the exchange setting
		DataExchangeSaaS.CreateExchangeSetting(
			Body.ExchangePlan,
			Body.CorrespondentCode,
			Body.CorrespondentName,
			CorrespondentEndPoint,
			FilterSsettingsAtNode,
			Correspondent,
			True,
			,
			Prefix);
		
		// Record the catalogs to be exported
		DataExchangeServer.RegisterOnlyCatalogsForInitialLandings(Correspondent);
		
		CommitTransaction();
		
		// Export data
		Cancel = False;
		DataExchangeSaaS.ExecuteDataExport(Cancel, Correspondent);
		If Cancel Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'There were errors when exporting the catalogs for the %1 correspondent.'"),
				String(Correspondent));
		EndIf;
		
		// Send a reply message of successful operation
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageExchangeSettingStep1CompletedSuccessfully());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	Except
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
		
		DeleteSynchronizationSetting(Correspondent);
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Send a reply message of an error
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageExchangeSettingErrorStep1());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure SetExchangeStep2(Message, Sender)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		Correspondent = ExchangeCorrespondent(Body.ExchangePlan, Body.CorrespondentCode);
		
		// Update the exchange setting
		DataExchangeSaaS.RefreshYourExchangeConfiguration(Correspondent,
			DataExchangeServer.GetFilterSettingsValues(XDTOSerializer.ReadXDTO(Body.AdditionalSettings)));
		
		// Record all data to be exported, except catalogs
		DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExporting(Correspondent);
		
		// Send a reply message of successful operation
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageExchangeSettingStep2CompletedSuccessfully());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Send a reply message of an error
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageExchangeSettingErrorStep2());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure ImportExchangeMessage(Message, Sender)
	
	Body = Message.Body;
	
	Try
		
		Correspondent = ExchangeCorrespondent(Body.ExchangePlan, Body.CorrespondentCode);
		
		// Import the exchange message
		Cancel = False;
		DataExchangeSaaS.ExecuteDataImport(Cancel, Correspondent);
		If Cancel Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Errors have occurred during the catalogs import from the correspondent %1.'"),
				String(Correspondent));
		EndIf;
		
		// Send a reply message of successful operation
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageExchangeMessageImportingCompletedSuccessfully());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	Except
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Send a reply message of an error
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageExchangeMessageImportingError());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure GetCorrespondentData(Message, Sender)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		CorrespondentData = DataExchangeServer.CorrespondentTablesData(
			XDTOSerializer.ReadXDTO(Body.Tables), Body.ExchangePlan);
		
		// Send a reply message of successful operation
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageCorrespondentDataGettingCompletedSuccessfully());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.Data = New ValueStorage(CorrespondentData);
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Send a reply message of an error
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageCorrespondentDataGettingError());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure GetCorrespondentNodesCommonData(Message, Sender)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		CorrespondentData = DataExchangeServer.DataForThisInfobaseNodeTabularSections(Body.ExchangePlan);
		
		// Send a reply message of successful operation
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageCorrespondentNodesCommonDataGettingCompletedSuccessfully());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.Data = New ValueStorage(CorrespondentData);
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Send a reply message of an error
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageCorrespondentNodesCommonDataGettingError());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

Procedure GetCorrespondentAccountingParameters(Message, Sender)
	
	Body = Message.Body;
	
	BeginTransaction();
	Try
		
		Correspondent = ExchangeCorrespondent(Body.ExchangePlan, Body.CorrespondentCode);
		
		Cancel = False;
		ErrorPresentation = "";
		
		ExchangePlans[Body.ExchangePlan].AccountingSettingsCheckHandler(Cancel, Correspondent, ErrorPresentation);
		
		CorrespondentData = New Structure("AccountingParametersAreSpecified, ErrorPresentation", Not Cancel, ErrorPresentation);
		
		// Send a reply message of successful operation
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageCorrespondentAccountingParametersGettingCompletedSuccessfully());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.Data = New ValueStorage(CorrespondentData);
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		// Send a reply message of an error
		ReplyMessage = MessagesSaaS.NewMessage(
			MessageControlDataExchangeInterface.MessageCorrespondentAccountingParametersGettingError());
		ReplyMessage.Body.Zone = CommonUse.SessionSeparatorValue();
		ReplyMessage.Body.CorrespondentZone = Body.CorrespondentZone;
		ReplyMessage.Body.SessionId = Body.SessionId;
		
		ReplyMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender, True);
		CommitTransaction();
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
EndProcedure

//

Function ExchangeCorrespondent(Val ExchangePlanName, Val Code)
	
	Result = ExchangePlans[ExchangePlanName].FindByCode(Code);
	
	If Not ValueIsFilled(Result) Then
		MessageString = NStr("en = 'Exchange plan node is not found; %1 exchange plan name; %2 node code'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, ExchangePlanName, Code);
		Raise MessageString;
	EndIf;
	
	Return Result;
EndFunction

Procedure DeleteSynchronizationSetting(Val Correspondent)
	
	SetPrivilegedMode(True);
	
	Try
		If Correspondent <> Undefined Then
			
			CorrespondentObject = Correspondent.GetObject();
			
			If CorrespondentObject <> Undefined Then
				
				CorrespondentObject.Delete();
				
			EndIf;
			
		EndIf;
	Except
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
EndProcedure

#EndRegion
