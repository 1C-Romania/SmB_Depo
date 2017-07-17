
#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Operation handlers

// Corresponds to operation DeliverMessages.
Function DeliverMessages(SenderCode, StreamStorage)
	
	SetPrivilegedMode(True);
	
	// Get a reference to the sender.
	Sender = ExchangePlans.MessageExchange.FindByCode(SenderCode);
	
	If Sender.IsEmpty() Then
		
		Raise NStr("en='Invalid endpoint connection settings.';ru='Заданы неправильные настройки подключения к конечной точке.'");
		
	EndIf;
	
	ImportedMessages = Undefined;
	DataReadInPart = False;
	
	// Importing messages into the infobase.
	MessageExchangeInternal.SerializeDataFromStream(
		Sender,
		StreamStorage.Get(),
		ImportedMessages,
		DataReadInPart);
	
	// Processing the queue of messages.
	If CommonUse.FileInfobase() Then
		
		MessageExchangeInternal.ProcessSystemMessageQueue(ImportedMessages);
		
	Else
		
		BackgroundJobParameters = New Array;
		BackgroundJobParameters.Add(ImportedMessages);
		
		BackgroundJobs.Execute("MessageExchangeInternal.ProcessSystemMessageQueue", BackgroundJobParameters);
		
	EndIf;
	
	If DataReadInPart Then
		
		Raise NStr("en='Error occurred when delivering quick messages
		|- some messages were not delivered due to specified data area locks!
		|
		|These messages will be processed within the messages processing queue of the system.';ru='Произошла ошибка при доставке быстрых сообщений - некоторые сообщения
		|не были доставлены из-за установленных блокировок областей данных!
		|
		|Эти сообщения будут обработаны в рамках очереди обработки сообщений системы'");
		
	EndIf;
	
EndFunction

// Corresponds to operation GetIBParameters.
Function GetInfobaseParameters(ThisEndPointDescription)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(MessageExchangeInternal.ThisNodeCode()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Code = String(New UUID());
		ThisNodeObject.Description = ?(IsBlankString(ThisEndPointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndPointDescription);
		ThisNodeObject.Write();
		
	ElsIf IsBlankString(MessageExchangeInternal.ThisNodeDescription()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Description = ?(IsBlankString(ThisEndPointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndPointDescription);
		ThisNodeObject.Write();
		
	EndIf;
	
	ThisPointParameters = CommonUse.ObjectAttributesValues(MessageExchangeInternal.ThisNode(), "Code, description");
	
	Result = New Structure;
	Result.Insert("Code",          ThisPointParameters.Code);
	Result.Insert("Description", ThisPointParameters.Description);
	
	Return XDTOSerializer.WriteXDTO(Result);
EndFunction

// Corresponds to operation ConnectEndPoint.
Function ToConnectEndPoint(Code, Description, XDTOReceiverConnectionSettings)
	
	Cancel = False;
	
	MessageExchangeInternal.ConnectEndPointAtRecipient(
				Cancel,
				Code,
				Description,
				XDTOSerializer.ReadXDTO(XDTOReceiverConnectionSettings));
	
	Return Not Cancel;
EndFunction

// Corresponds to operation UpdateConnectionSettings.
Function RefreshConnectionSettings(Code, XDTOConnectionSettings)
	
	ConnectionSettings = XDTOSerializer.ReadXDTO(XDTOConnectionSettings);
	
	SetPrivilegedMode(True);
	
	EndPoint = ExchangePlans.MessageExchange.FindByCode(Code);
	If EndPoint.IsEmpty() Then
		Raise NStr("en='Invalid endpoint connection settings.';ru='Заданы неправильные настройки подключения к конечной точке.'");
	EndIf;
	
	BeginTransaction();
	Try
		
		// Update the connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPoint);
		RecordStructure.Insert("ExchangeMessageTransportKindByDefault", Enums.ExchangeMessagesTransportKinds.WS);
		
		RecordStructure.Insert("WSURLWebService",   ConnectionSettings.WSURLWebService);
		RecordStructure.Insert("WSUserName", ConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          ConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// add record to the information register
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndFunction

// Corresponds to operation SetLeadingEndPoint.
Function SetLeadingEndPoint(ThisEndPointCode, LeadingEndPointCode)
	
	MessageExchangeInternal.SetLeadingEndPointAtRecipient(ThisEndPointCode, LeadingEndPointCode);
	
EndFunction

// Corresponds to operation TestConnectionRecipient.
Function CheckConnectionAtRecipient(XDTOConnectionSettings, SenderCode)
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	WSProxy = MessageExchangeInternal.GetWSProxy(XDTOSerializer.ReadXDTO(XDTOConnectionSettings), ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	WSProxy.CheckConnectionAtSender(SenderCode);
	
EndFunction

// Corresponds to operation TestConnectionSender.
Function CheckConnectionAtSender(SenderCode)
	
	SetPrivilegedMode(True);
	
	If MessageExchangeInternal.ThisNodeCode() <> SenderCode Then
		
		Raise NStr("en='Receiver base connection settings indicate another sender.';ru='Настройки подключения базы получателя указывают на другого отправителя.'");
		
	EndIf;
	
EndFunction

// Corresponds to operation Ping.
Function Ping()
	
	// Cap. It is necessary to the configuration check error wasn't given.
	Return Undefined;
	
EndFunction

#EndRegion
