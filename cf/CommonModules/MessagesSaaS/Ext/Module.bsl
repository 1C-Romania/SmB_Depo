
#Region ProgramInterface

// Returns the new message.
//
// Parameters:
//  MessageBodyType - XDTOObjectType - type of body of the message which has to be created.
//
// Returns:
//  XDTODataObject - object of the desired type.
Function NewMessage(Val MessageBodyType) Export
	
	Message = XDTOFactory.Create(MessagesSaaSReUse.TypeMessage());
	
	Message.Header = XDTOFactory.Create(MessagesSaaSReUse.TypeMessageTitle());
	Message.Header.Id = New UUID;
	Message.Header.Created = CurrentUniversalDate();
	
	Message.Body = XDTOFactory.Create(MessageBodyType);
	
	Return Message;
	
EndFunction

// Sends message
//
// Parameters:
//  Message - XDTODataObject - message.
//  Recipient - ExchangePlanRef.MessageExchange - message recipient.
//  Now - Boolean - send the messages through the rapid messages mechanism.
//
Procedure SendMessage(Val Message, Val Recipient = Undefined, Val Now = False) Export
	
	Message.Header.Sender = MessagesExchangeNodeDescription(ExchangePlans.MessageExchange.ThisNode());
	
	If ValueIsFilled(Recipient) Then
		Message.Header.Recipient = MessagesExchangeNodeDescription(Recipient);
	EndIf;
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Recipient);
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURLWebService);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);

	BroadcastMessageToCorrespondentIfNecessary(
		Message, 
		ConnectionParameters,
		String(Recipient));
	
	UntypedBody = WriteMessageToUntypedBody(Message);
	
	MessageChannel = ChannelNameByMessageType(Message.Body.Type());
	
	If Now Then
		MessageExchange.SendMessageImmediately(MessageChannel, UntypedBody, Recipient);
	Else
		MessageExchange.SendMessage(MessageChannel, UntypedBody, Recipient);
	EndIf;
	
EndProcedure

// Obtains the list of message handlers for the namespaces.
// 
// Parameters:
//  Handlers - ValueTable - see field content in MessageExchange.NewMessageHandlersTable.
//  TargetNamespace - String - uri of the name space in which the message body types are defined.
//  CommonModule - a common module which contains message handlers.
// 
Procedure GetMessageChannelHandlers(Val Handlers, Val TargetNamespace, Val CommonModule) Export
	
	ChannelNames = MessagesSaaSReUse.GetPackageChannels(TargetNamespace);
	
	For Each ChannelName IN ChannelNames Do
		Handler = Handlers.Add();
		Handler.Channel = ChannelName;
		Handler.Handler = CommonModule;
	EndDo;
	
EndProcedure

// Returns the name of the message channel which corresponds to the message type.
//
// Parameters:
//  MessageType - XDTOObjectType - type of the remote administration message.
//
// Returns:
//  String - name of the message channel which corresponds to the supplied type of message.
//
Function ChannelNameByMessageType(Val MessageType) Export
	
	Return XDTOSerializer.XMLString(New XMLExpandedName(MessageType.NamespaceURI, MessageType.Name));
	
EndFunction

// Returns the type of remote administration messages by the name of the message channel.
//
// Parameters:
//  ChannelName - String - name of the message channel which corresponds to the supplied type of message.
//
// Returns:
//  XDTOObjectType - type of the remote administration message.
//
Function MessageTypeByChannelName(Val ChannelName) Export
	
	Return XDTOFactory.Type(XDTOSerializer.XMLValue(Type("XMLExpandedName"), ChannelName));
	
EndFunction

// Raises an exception when messages are received to an unknown channel.
//
// Parameters:
//  MessageChannel - String - name of the unknown message channel .
//
Procedure UnknownChannelNameError(Val MessageChannel) Export
	
	MessagePattern = NStr("en='Unknown message channel name %1';ru='Неизвестное имя канала сообщений %1'");
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, MessageChannel);
	Raise(MessageText);
	
EndProcedure

// Reads the message from the untyped message body.
//
// Parameters:
//  UntypedBody - String - untyped message body.
//
// Returns:
//  {http://www.1c.ru/SaaS/Messages}Message - message
//
Function ReadMessageFromUntypedBody(Val UntypedBody) Export
	
	Read = New XMLReader;
	Read.SetString(UntypedBody);
	
	Message = XDTOFactory.ReadXML(Read, MessagesSaaSReUse.TypeMessage());
	
	Read.Close();
	
	Return Message;
	
EndFunction

// Writes the message to the untyped message body.
//
// Parameters:
//  Message - {http://www.1c.ru/SaaS/Messages}Message - message.
//
// Returns:
//  String - untyped message body.
//
Function WriteMessageToUntypedBody(Val Message) Export
	
	Record = New XMLWriter;
	Record.SetString();
	XDTOFactory.WriteXML(Record, Message, , , , XMLTypeAssignment.Explicit);
	
	Return Record.Close();
	
EndFunction

// Writes the message handling start event to the event log.
//
// Parameters:
//  Message - {http://www.1c.ru/SaaS/Messages}Message - message.
//
Procedure WriteMessageStartProcessing(Val Message) Export
	
	WriteLogEvent(NStr("en='Messages in the service models. Start of processing';ru='Сообщения в модели сервиса.Начало обработки'",
		CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Information,
		,
		,
		MessagePresentationForLog(Message));
	
EndProcedure

// Writes the message handling end event to the event log.
//
// Parameters:
//  Message - {http://www.1c.ru/SaaS/Messages}Message - message.
//
Procedure WriteEventEndDataProcessors(Val Message) Export
	
	WriteLogEvent(NStr("en='Messages in the service model. End of processing';ru='Сообщения в модели сервиса.Окончание обработки'",
		CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Information,
		,
		,
		MessagePresentationForLog(Message));
	
	EndProcedure

// Delivers quick messages.
//
Procedure DeliverQuickMessages() Export
	
	If TransactionActive() Then
		Raise(NStr("en='Fast messages delivery is impossible in transaction';ru='Доставка быстрых сообщений невозможна в транзакции'"));
	EndIf;
	
	JobMethodName = "MessageExchange.DeliverMessages";
	JobKey = 1;
	
	SetPrivilegedMode(True);
	
	JobsFilter = New Structure;
	JobsFilter.Insert("MethodName", JobMethodName);
	JobsFilter.Insert("Key", JobKey);
	JobsFilter.Insert("State", BackgroundJobState.Active);
	
	Jobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
	If Jobs.Count() > 0 Then
		Try
			Jobs[0].WaitForCompletion(3);
		Except
			
			Job = BackgroundJobs.FindByUUID(Tasks[0].UUID);
			If Job.State = BackgroundJobState.Failed
				AND Job.ErrorInfo <> Undefined Then
				
				Raise(DetailErrorDescription(Job.ErrorInfo));
			EndIf;
			
			Return;
		EndTry;
	EndIf;
		
	Try
		BackgroundJobs.Execute(JobMethodName, , JobKey, NStr("en='Instant messages delivery';ru='Доставка быстрых сообщений'"))
	Except
		// Additional exception data processor
		// is not required, the expected exception - duplication of a job with the same key.
		WriteLogEvent(NStr("en='Instant messages delivery';ru='Доставка быстрых сообщений'",
			CommonUseClientServer.MainLanguageCode()), EventLogLevel.Error, , ,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Event handler prior to message sending.
// The handler of this event is called in prior to recording the message for subsequent sending.
// Handler is called for each outgoing message.
//
//  Parameters:
// MessageChannel - String - message channel identifier from which the message was received.
// MessageBody - Arbitrary - body of the message being recorded.
//
Procedure BeforeMessageSending(Val MessageChannel, Val MessageBody) Export
	
	If Not CommonUse.UseSessionSeparator() Then
		Return;
	EndIf;
	
	Message = Undefined;
	If BodyContainTypedMessage(MessageBody, Message) Then
		If MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
			If CommonUse.SessionSeparatorValue() <> Message.Body.Zone Then
				WriteLogEvent(NStr("en='Messages in the service model. Message sending';ru='Сообщения в модели сервиса.Отправка сообщения'",
					CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					,
					,
					MessagePresentationForLog(Message));
					
				ErrorTemplate = NStr("en='Error at message sending. Data area %1 does not match the current one (%2).';ru='Ошибка при отправке сообщения. Область данных %1 не совпадает с текущей (%2).'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorTemplate, 
					Message.Body.Zone, CommonUse.SessionSeparatorValue());
					
				Raise(ErrorText);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Handler of the event during sending the message.
// The handler of this event is called before putting message into the XML stream.
// Handler is called for each outgoing message.
//
//  Parameters:
// MessageChannel - String - message channel identifier to which the message is sent.
// MessageBody - Arbitrary - sent message body. IN the event handler
//    the message body can be changed, for example supplemented with information.
//
Procedure OnMessageSending(MessageChannel, MessageBody, MessageObject) Export
	
	Message = Undefined;
	If BodyContainTypedMessage(MessageBody, Message) Then
		
		Message.Header.Sent = CurrentUniversalDate();
		MessageBody = WriteMessageToUntypedBody(Message);
		
		WriteLogEvent(NStr("en='Messages in the service model. Sending';ru='Сообщения в модели сервиса.Отправка'",
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			,
			MessagePresentationForLog(Message));
		
	EndIf;
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		
		ModuleMessageSaaSDataSeparation = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		ModuleMessageSaaSDataSeparation.OnMessageSending(MessageChannel, MessageBody, MessageObject);
		
	EndIf;
	
	MessagesSaaSOverridable.OnMessageSending(MessageChannel, MessageBody, MessageObject);
	
EndProcedure

// Handler of the event during receiving the message.
// The handler of this event is called when receiving message from the XML stream.
// Handler is called for each received message.
//
//  Parameters:
// MessageChannel - String - message channel identifier from which the message was received.
// MessageBody - Arbitrary - Body of the received message. IN the event handler
//    the message body can be changed, for example supplemented with information.
//
Procedure OnMessageReceiving(MessageChannel, MessageBody, MessageObject) Export
	
	Message = Undefined;
	If BodyContainTypedMessage(MessageBody, Message) Then
		
		Message.Header.Delivered = CurrentUniversalDate();
		
		MessageBody = WriteMessageToUntypedBody(Message);
		
		WriteLogEvent(NStr("en='Messages in the service model. Receiving';ru='Сообщения в модели сервиса.Получение'",
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			,
			MessagePresentationForLog(Message));
		
	EndIf;
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		
		ModuleMessageSaaSDataSeparation = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		ModuleMessageSaaSDataSeparation.OnMessageReceiving(MessageChannel, MessageBody, MessageObject);
		
	EndIf;
	
	MessagesSaaSOverridable.OnMessageReceiving(MessageChannel, MessageBody, MessageObject);
	
EndProcedure

Function MessagesExchangeNodeDescription(Val Node)
	
	Attributes = CommonUse.ObjectAttributesValues(
		Node,
		New Structure("Code, description"));
	
	Definition = XDTOFactory.Create(MessagesSaaSReUse.TypeMessagesExchangeNode());
	Definition.Code = Attributes.Code;
	Definition.Presentation = Attributes.Description;
	
	Return Definition;
	
EndFunction

// For an internal use.
//
Function BodyContainTypedMessage(Val UntypedBody, Message) Export
	
	If TypeOf(UntypedBody) <> Type("String") Then
		Return False;
	EndIf;
	
	If Left(UntypedBody, 1) <> "<" OR Right(UntypedBody, 1) <> ">" Then
		Return False;
	EndIf;
	
	Try
		Read = New XMLReader;
		Read.SetString(UntypedBody);
		
		Message = XDTOFactory.ReadXML(Read);
		
		Read.Close();
		
	Except
		Return False;
	EndTry;
	
	Return Message.Type() = MessagesSaaSReUse.TypeMessage();
	
EndFunction

Function MessagePresentationForLog(Val Message)
	
	Pattern = NStr("en='Channel: %1';ru='Канал: %1'", CommonUseClientServer.MainLanguageCode());
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(Pattern, 
		ChannelNameByMessageType(Message.Body.Type()));
		
	Record = New XMLWriter;
	Record.SetString();
	XDTOFactory.WriteXML(Record, Message.Header, , , , XMLTypeAssignment.Explicit);
		
	Pattern = NStr("en='Title: %1';ru='Заголовок: %1'", CommonUseClientServer.MainLanguageCode());
	Presentation = Presentation + Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(Pattern, 
		Record.Close());
		
	If MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
		Pattern = NStr("en='Data area: %1';ru='Область данных: %1'", CommonUseClientServer.MainLanguageCode());
		Presentation = Presentation + Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(Pattern, 
			Format(Message.Body.Zone, "NZ=0; NG="));
	EndIf;
		
	Return Presentation;
	
EndFunction

// Translates the message being sent to a version supported by the IB-correspondent.
//
// Parameters:
//  Message: XDTOObject, message being sent.
//  InformationConnection - structure, parameters of connection to IB-recipient.
//  RecipientPresentation - String, presentation of IB-recipient.
//
// Returns:
//  XDTOObject, a message translated to the IB-recipient version.
//
Procedure BroadcastMessageToCorrespondentIfNecessary(Message, Val InformationConnection, Val RecipientPresentation) Export
	
	InterfaceMessages = TranslationXDTOService.GetInterfaceMessages(Message);
	If InterfaceMessages = Undefined Then
		Raise NStr("en='The application failed to define interface of the message being sent: there is no interface handler registered for any of the types used in the message!';ru='Не удалось определить интерфейс отправляемого сообщения: ни для одного из типов, используемых в сообщении, не зарегистрирован обработчик интерфейса!'");
	EndIf;
	
	If Not InformationConnection.Property("URL") 
			Or Not ValueIsFilled(InformationConnection.URL) Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='URL of the messages exchange service with the infobase %1 is not specified';ru='Не задан URL сервиса обмена сообщениями с информационной базой %1'"), RecipientPresentation);
	EndIf;
	
	CorrespondentVersion = MessageInterfacesSaaS.InterfaceVersionCorrespondent(
			InterfaceMessages.ProgramInterface, InformationConnection, RecipientPresentation);
	
	If CorrespondentVersion = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Correspondent %1 does not support the %2 interface messages versions receipt supported by the current infobase!';ru='Корреспондент %1 не поддерживает получение версий сообщений интерфейса %2, поддерживаемых текущей информационной базой!'"),
			RecipientPresentation, InterfaceMessages.ProgramInterface);
	EndIf;
	
	IsSentVersion = MessageInterfacesSaaS.GetVersionsSentMessages().Get(InterfaceMessages.ProgramInterface);
	If IsSentVersion = CorrespondentVersion Then
		Return;
	EndIf;
	
	Message = TranslationXDTO.TransferToVersion(Message, CorrespondentVersion, InterfaceMessages.TargetNamespace);
	
EndProcedure

#EndRegion
