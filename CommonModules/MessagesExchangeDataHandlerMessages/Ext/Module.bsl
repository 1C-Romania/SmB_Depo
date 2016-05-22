////////////////////////////////////////////////////////////////////////////////
// DataExchangeMessageChannelHandlerInServiceMode.
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Receives message handler list which this subsystem is processing.
// 
// Parameters:
//  Handlers - ValueTable - for the field content see MessageExchange.NewMessageHandlersTable
// 
Procedure GetMessageChannelHandlers(Handlers) Export
	
	AddMessageChannelHandler("DataExchange\Application\ExchangeCreation",                 MessagesExchangeDataHandlerMessages, Handlers);
	AddMessageChannelHandler("DataExchange\Application\ExchangeDeletion",                 MessagesExchangeDataHandlerMessages, Handlers);
	AddMessageChannelHandler("DataExchange\Application\SetDataAreaPrefix", MessagesExchangeDataHandlerMessages, Handlers);
	
EndProcedure

// Executes the message body data processor from channel according to the current message channel procedure
//
// Parameters:
//  MessageChannel (necessary) - String - Identifier of the message channel from which the message was received.
//  MessageBody (necessary) - Arbitrary - Message body received from channel which must be processed.
//  Sender (necessary) - ExchangePlanRef.MessageExchange - End point which is message sender.
//
Procedure ProcessMessage(MessageChannel, MessageBody, Sender) Export
	
	SetDataArea(MessageBody.DataArea);
	Try
		
		If MessageChannel = "DataExchange\Application\ExchangeCreation" Then
			
			CreateDataExchangeInInfobase(
									Sender,
									MessageBody.Settings,
									MessageBody.FilterSsettingsAtNode,
									MessageBody.DefaultValuesAtNode,
									MessageBody.ThisNodeCode,
									MessageBody.NewNodeCode);
			
		ElsIf MessageChannel = "DataExchange\Application\ExchangeDeletion" Then
			
			DeleteDataExchangeFromInfobase(Sender, MessageBody.ExchangePlanName, MessageBody.NodeCode);
			
		ElsIf MessageChannel = "DataExchange\Application\SetDataAreaPrefix" Then
			
			SetDataAreaPrefix(MessageBody.Prefix);
			
		EndIf;
		
	Except
		CancelInstallationDataAreas();
		Raise;
	EndTry;
	
	CancelInstallationDataAreas();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// For compatibility if correspondent has SSL lower than 2.1.2 version
//
Procedure CreateDataExchangeInInfobase(Sender, Settings, FilterSsettingsAtNode, DefaultValuesAtNode, ThisNodeCode, NewNodeCode)
	
	// Create the message exchange directory (if necessary)
	Directory = New File(Settings.FILEInformationExchangeDirectory);
	
	If Not Directory.Exist() Then
		
		Try
			CreateDirectory(Directory.DescriptionFull);
		Except
			
			// Mark the operation execution error in managing application
			SendErrorCreatingExchangeMessage(Number(ThisNodeCode), Number(NewNodeCode), DetailErrorDescription(ErrorInfo()), Sender);
			
			WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
	EndIf;
	
	BeginTransaction();
	Try
		
		CorrespondentDataArea = Number(NewNodeCode);
		ExchangePlanName              = Settings.ExchangePlanName;
		CorrespondentCode           = DataExchangeSaaS.ExchangePlanNodeCodeInService(CorrespondentDataArea);
		CorrespondentDescription  = Settings.SecondInfobaseDescription;
		FilterSsettingsAtNode      = New Structure;
		ThisApplicationCode          = DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
		ThisApplicationName = DataExchangeSaaS.GeneratePredefinedNodeDescription();
		
		CorrespondentEndPoint = ExchangePlans.MessageExchange.FindByCode(Settings.CorrespondentEndPoint);
		
		If CorrespondentEndPoint.IsEmpty() Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Correspondent end point with the %1 script is not found.'"),
				Settings.CorrespondentEndPoint);
		EndIf;
		
		Correspondent = Undefined;
		
		// Create exchange setting in this base
		DataExchangeSaaS.CreateExchangeSetting(
			ExchangePlanName,
			CorrespondentCode,
			CorrespondentDescription,
			CorrespondentEndPoint,
			FilterSsettingsAtNode,
			Correspondent,
			,
			True);
		
		// Save exchange message transport settings for the current data area
		RecordStructure = New Structure;
		RecordStructure.Insert("Correspondent", Correspondent);
		RecordStructure.Insert("CorrespondentEndPoint", CorrespondentEndPoint);
		RecordStructure.Insert("InformationExchangeDirectory", Settings.FILEInformationExchangeDirectoryRelative);
		
		InformationRegisters.DataAreaTransportExchangeSettings.UpdateRecord(RecordStructure);
		
		// Write data to export in this base
		DataExchangeServer.RegisterDataForInitialExport(Correspondent);
		
		// Mark successful operation execution in managing application
		SendMessageActionSuccessful(Number(ThisNodeCode), Number(NewNodeCode), Sender);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		// Mark the operation execution error in managing application
		SendErrorCreatingExchangeMessage(Number(ThisNodeCode), Number(NewNodeCode), DetailErrorDescription(ErrorInfo()), Sender);
		
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For compatibility if correspondent has SSL lower than 2.1.2 version
//
Procedure DeleteDataExchangeFromInfobase(Sender, ExchangePlanName, NodeCode)
	
	// Searching the node by the S00000123 node code format
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(DataExchangeSaaS.ExchangePlanNodeCodeInService(Number(NodeCode)));
	
	If InfobaseNode.IsEmpty() Then
		
		// Searching for the node by the 0000123 (old) code format
		InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
		
	EndIf;
	
	ThisNodeCode = DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	ThisNodeCode = DataExchangeServer.DataAreaNumberByExchangePlanNodeCode(ThisNodeCode);
	
	If InfobaseNode.IsEmpty() Then
		
		// Mark successful operation execution in managing application
		SendMessageActionSuccessful(ThisNodeCode, Number(NodeCode), Sender);
		
		Return; // exchange setting is not found (it was probably deleted earlier)
	EndIf;
	
	// Delete data exchange directory
	TransportSettings = InformationRegisters.DataAreaTransportExchangeSettings.TransportSettings(InfobaseNode);
	
	If TransportSettings <> Undefined
		AND TransportSettings.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.FILE Then
		
		If Not IsBlankString(TransportSettings.FILEInformationExchangeCommonDirectory)
			AND Not IsBlankString(TransportSettings.InformationExchangeDirectoryRelative) Then
			
			InformationExchangeAbsoluteDirectory = CommonUseClientServer.GetFullFileName(
				TransportSettings.FILEInformationExchangeCommonDirectory,
				TransportSettings.InformationExchangeDirectoryRelative);
			
			AbsoluteDirectory = New File(InformationExchangeAbsoluteDirectory);
			
			Try
				DeleteFiles(AbsoluteDirectory.DescriptionFull);
			Except
				WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		EndIf;
		
	EndIf;
	
	// Delete node
	Try
		InfobaseNode.GetObject().Delete();
	Except
		
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		
		// Mark the operation execution error in managing application
		SendErrorDeletingExchangeMessage(ThisNodeCode, Number(NodeCode), ErrorMessageString, Sender);
		
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndTry;
	
	// Mark successful operation execution in managing application
	SendMessageActionSuccessful(ThisNodeCode, Number(NodeCode), Sender);
	
EndProcedure

Procedure SetDataAreaPrefix(Val Prefix)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(Constants.DistributedInformationBaseNodePrefix.Get()) Then
		
		Constants.DistributedInformationBaseNodePrefix.Set(Format(Prefix, "ND=2; NLZ=; NG=0"));
		
	EndIf;
	
EndProcedure

Procedure SetDataArea(Val DataArea)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
EndProcedure

Procedure CancelInstallationDataAreas()
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

Procedure SendMessageActionSuccessful(Code1, Code2, EndPoint)
	
	BeginTransaction();
	Try
		
		MessageBody = New Structure("Script1, Script2", Code1, Code2);
		
		MessageExchange.SendMessage("DataExchange\Application\Response\ActionSuccessful", MessageBody, EndPoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMonitorMessageTextSendMessages(),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SendErrorCreatingExchangeMessage(Code1, Code2, ErrorString, EndPoint)
	
	BeginTransaction();
	Try
		
		MessageBody = New Structure("Script1, Script2, ErrorString", Code1, Code2, ErrorString);
		
		MessageExchange.SendMessage("DataExchange\Application\Response\ErrorCreatingExchange", MessageBody, EndPoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMonitorMessageTextSendMessages(),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SendErrorDeletingExchangeMessage(Code1, Code2, ErrorString, EndPoint)
	
	BeginTransaction();
	Try
		
		MessageBody = New Structure("Script1, Script2, ErrorString", Code1, Code2, ErrorString);
		
		MessageExchange.SendMessage("DataExchange\Application\Response\ErrorDeletingExchange", MessageBody, EndPoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMonitorMessageTextSendMessages(),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers)
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

Function EventLogMonitorMessageTextSendMessages()
	
	Return NStr("en = 'Send messages'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

#EndRegion
