////////////////////////////////////////////////////////////////////////////////
// MessageExchange: messages exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Sends message to the messages address channel.
// Corresponds to the "End point/End point" sending type.
//
// Parameters:
//  MessageChannel                 - String. Address messages channel identifier.
//  MessageBody (optional) - Custom. System message body that should be sent.
//  Receiver (optional)    - Undefined; ExchangePlanRef.MessageExchange; Array.
//   Undefined - message receiver is not specified. Message will be sent
// to the end points that are determined with the current information system settings.:
//   in the MessagesExchangeOverridable.MessageReceivers
//   handler (programmatically) and in the SenderSettings information register (system setting).
//   ExchangePlanRef.MessageExchange - exchange plan node that corresponds
//   to the end point for which message is designed. Message will be sent only to this end point.
//   Array - messages receivers array; array items should have the ExchangePlanRef.MessagesExchange type.
//   Message will be sent to all end points specified in the array.
//   Default value: Undefined.
//
Procedure SendMessage(MessageChannel, MessageBody = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessageChannel, MessageBody, Recipient);
	
EndProcedure

// Sends quick message to address messages channel.
// Corresponds to the "End point/End point" sending type.
//
// Parameters:
//  MessageChannel                 - String. Address messages channel identifier.
//  MessageBody (optional) - Custom. System message body that should be sent.
//  Receiver (optional)    - Undefined; ExchangePlanRef.MessageExchange; Array.
//   Undefined - message receiver is not specified. Message will be sent
// to the end points that are determined with the current information system settings.:
//   in the MessagesExchangeOverridable.MessageReceivers
//   handler (programmatically) and in the SenderSettings information register (system setting).
//   ExchangePlanRef.MessageExchange - exchange plan node that corresponds
//   to the end point for which message is designed. Message will be sent only to this end point.
//   Array - messages receivers array; array items should have the ExchangePlanRef.MessagesExchange type.
//   Message will be sent to all end points specified in the array.
//   Default value: Undefined.
//
Procedure SendMessageImmediately(MessageChannel, MessageBody = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessageChannel, MessageBody, Recipient, True);
	
EndProcedure

// Sends message to the messages broadcast channel.
// Corresponds to the "Publishing/Subscription" sending type.
// Message will be sent to the end points that are subscribed to the broadcast channel.
// Subscriptions to broadcast channel are set via the ReceiversSubscriptions information register.
//
// Parameters:
//  MessageChannel                 - String. Identifier of the broadcast messages channel.
//  MessageBody (optional) - Custom. System message body that should be sent.
//
Procedure SendMessageToSubscribers(MessageChannel, MessageBody = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessageChannel, MessageBody);
	
EndProcedure

// Sends quick message to the broadcast messages channel.
// Corresponds to the "Publishing/Subscription" sending type.
// Message will be sent to the end points that are subscribed to the broadcast channel.
// Subscriptions to broadcast channel are set via the ReceiversSubscriptions information register.
//
// Parameters:
//  MessageChannel                 - String. Identifier of the broadcast messages channel.
//  MessageBody (optional) - Custom. System message body that should be sent.
//
Procedure SendMessageToSubscribersImmediately(MessageChannel, MessageBody = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessageChannel, MessageBody, True);
	
EndProcedure

// Immediately sends quick messages from general messages queue.
// Messages in cycle are sent until all quick messages are sent from
// messages queue.
// When messages are sent, immediate message sending from other sessions is locked.
//
Procedure DeliverMessages() Export
	
	If TransactionActive() Then
		Raise NStr("en='Delivery of the system instant messages  can not be performed in the active transaction.';ru='Доставка быстрых сообщений системы не может выполняться в активной транзакции.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not StartSendingInstantMessages() Then
		Return;
	EndIf;
	
	QueryText = "";
	CatalogsMessages = MessageExchangeReUse.GetMessagesCatalogs();
	For Each CatalogMessages IN CatalogsMessages Do
		
		IsFirstFragment = IsBlankString(QueryText);
		
		If Not IsFirstFragment Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		QueryText = QueryText +
			"SELECT
			|	ChangeTable.Node AS EndPoint,
			|	ChangeTable.Ref AS Message
			|[INTO]
			|FROM
			|	[CatalogMessages].Changes AS ChangeTable
			|WHERE
			|	ChangeTable.Ref.IsInstantMessage
			|	AND ChangeTable.MessageNo IS NULL
			|	AND Not ChangeTable.Node IN (&UnavailableEndPoints)";
		
		QueryText = StrReplace(QueryText, "[MessagesCatalog]", CatalogMessages.EmptyRef().Metadata().FullName());
		If IsFirstFragment Then
			QueryText = StrReplace(QueryText, "[INTO]", "INTO TT_Changes");
		Else
			QueryText = StrReplace(QueryText, "[INTO]", "");
		EndIf;		
	EndDo;
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Changes.EndPoint AS EndPoint,
	|	TU_Changes.Message
	|FROM
	|	TU_Changes AS TU_Changes
	|
	|ORDER BY
	|	TU_Changes.Message.Code
	|TOTALS BY
	|	EndPoint";
	
	Query = New Query;
	Query.Text = QueryText;
	
	UnavailableEndPoints = New Array;
	
	Try
		
		While True Do
			
			Query.SetParameter("UnavailableEndPoints", UnavailableEndPoints);
			
			QueryResult = CommonUse.ExecuteQueryBeyondTransaction(Query);
			
			If QueryResult.IsEmpty() Then
				Break;
			EndIf;
			
			Groups = QueryResult.Unload(QueryResultIteration.ByGroupsWithHierarchy);
			
			For Each Group IN Groups.Rows Do
				
				Messages = Group.Rows.UnloadColumn("Message");
				
				Try
					
					DeliverMessagesToRecipient(Group.EndPoint, Messages);
					
					DeleteChangeRecords(Group.EndPoint, Messages);
					
				Except
					
					UnavailableEndPoints.Add(Group.EndPoint);
					
					WriteLogEvent(MessageExchangeInternal.ThisSubsystemEventLogMonitorMessageText(),
											EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndDo;
			
		EndDo;
		
	Except
		CancelSendingInstantMessages();
		Raise;
	EndTry;
	
	FinishSendingInstantMessages();
	
EndProcedure

// Enables end point.
// Before you enable end point, sender to receiver and receiver to sender connection setting is checked. 
// It is also checked whether receiver connection settings point on the current sender.
//
// Parameters:
//  Cancel - Boolean - Check box of operation execution; selected if error occur while connecting of the end point.
//  RecipientWebServiceURL    - String - Web address of the enabled end point.
//  RecipientUserName  - String - User for authentification in the enabled
// end point while working via web-service of message exchange subsystem.
//  RecipientPassword           - String - User password in the enabled end point.
//  SenderWebServiceURL   - String - Web address of this infobase from the side of the enabled end point.
//  SenderUserName - String - User for authentification in this
// infobase while working via web-service of message exchange subsystem.
//  SenderPassword          - String - User password in this infobase.
//  EndPoint - ExchangePlanRef.MessageExchange, Undefined - If the end point
//                  is enabled successfully, then ref to exchange plan node that corresponds
//                  to enabled end point to this parameter.
//                                        If you failed to enable end point, then Undefined is returned.
//  RecipientEndPointDescription - String - Name of the enabled end point. If value is
//                                        not specified then synonym of the
//                                        enabled end point configuration is used as a name.
//  SenderEndPointDescription - String - Name of the end
//                                        point that corresponds to this infobase. If value is not specified
//                                        then synonym of this end point configuration is used as a name.
//
Procedure ToConnectEndPoint(Cancel,
									RecipientWebServiceURL,
									RecipientUserName,
									RecipientPassword,
									SenderWebServiceURL,
									SenderUserName,
									SenderPassword,
									EndPoint = Undefined,
									RecipientEndPointDescription = "",
									SenderEndPointDescription = ""
	) Export
	
	SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
	SenderConnectionSettings.WSURLWebService              = RecipientWebServiceURL;
	SenderConnectionSettings.WSUserName            = RecipientUserName;
	SenderConnectionSettings.WSPassword                     = RecipientPassword;
	
	RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
	RecipientConnectionSettings.WSURLWebService              = SenderWebServiceURL;
	RecipientConnectionSettings.WSUserName            = SenderUserName;
	RecipientConnectionSettings.WSPassword                     = SenderPassword;
	
	MessageExchangeInternal.ConnectEndPointAtSender(Cancel, 
														SenderConnectionSettings,
														RecipientConnectionSettings,
														EndPoint,
														RecipientEndPointDescription,
														SenderEndPointDescription);
	
EndProcedure

// Updates connection settings for an end point.
// Settings of this infobase connection to the specified end
// point and settings of end point connection to this infobase are updated.
// Before you apply settings, it is checked whether connection has correct settings specified.
// It is also checked whether receiver connection settings point on the current sender.
//
// Parameters:
//  Cancel         - Boolean - Check box of operation execution; selected in case an error occurs.
//  EndPoint - ExchangePlanRef.MessageExchange - Ref to exchange plan node that
//                                                      corresponds to the end point.
//  RecipientWebServiceURL    - String - End point web address.
//  RecipientUserName  - String - User for authentification in the
// end point while working via web-service of message exchange subsystem.
//  RecipientPassword           - String - User password in the end point.
//  SenderWebServiceURL   - String - Web address of this infobase from the side of an end point.
//  SenderUserName - String - User for authentification in this
// infobase while working via web-service of message exchange subsystem.
//  SenderPassword          - String - User password in this infobase.
//
Procedure UpdateEndPointConnectionSettings(Cancel,
									EndPoint,
									RecipientWebServiceURL,
									RecipientUserName,
									RecipientPassword,
									SenderWebServiceURL,
									SenderUserName,
									SenderPassword
	) Export
	
	SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
	SenderConnectionSettings.WSURLWebService              = RecipientWebServiceURL;
	SenderConnectionSettings.WSUserName            = RecipientUserName;
	SenderConnectionSettings.WSPassword                     = RecipientPassword;
	
	RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
	RecipientConnectionSettings.WSURLWebService              = SenderWebServiceURL;
	RecipientConnectionSettings.WSUserName            = SenderUserName;
	RecipientConnectionSettings.WSPassword                     = SenderPassword;
	
	MessageExchangeInternal.UpdateEndPointConnectionSettings(Cancel, EndPoint, SenderConnectionSettings, RecipientConnectionSettings);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Declares the SaaSOperations.MessagesExchange subsystem events:
//
// Server events:
//
//   OnDefenitionMessagesFeedHandlers,
//   WhenDeterminingRecipientsOfMessage,
//   OnMessageSending,
//   OnMessageReceiving.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Gets the list of message handlers that handle library subsystems.
	// 
	// Parameters:
	//  Handlers - ValueTable - see the content of fields in the MessageExchange.NewMessageHandlersTable.
	//
	// Syntax:
	// Procedure AtMessageChanelsHandlersDefinition(Handlers) Export
	//
	// For use in other libraries.
	//
	// (The same as MessageExchangeOverridable.GetMessagesChannelsHandlers).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS.MessageExchange\OnDefenitionMessagesFeedHandlers");
	
	// Handler of receiving a dynamic list of the endpoints messages.
	//
	// Parameters:
	//  MessageChannel - String - Identifier of the message channel for which it is required to define endpoints.
	//  Recipients     - Array - End points array to which it is required to address message.
	//                   Array should be filled in with the items of the ExchangePlanRef type.MessageExchange.
	//                   This parameter must be defined in the body of the handler.
	//
	// Syntax:
	// Procedure OnDefineMessageReceivers(Value MessagesChannel, Receivers) Export
	//
	// (The same as MessageExchangeOverridable.MessageReceivers).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS.MessageExchange\WhenDeterminingRecipientsOfMessage");
	
	// Handler of the event during sending the message.
	// The handler of this event is called before putting message into the XML stream.
	// Handler is called for each outgoing message.
	//
	// Parameters:
	//  MessageChannel - String - Identifier of the message channel to which the message is sent.
	//  MessageBody  - Arbitrary - The body of the outgoing message.
	//   IN the event handler the message body can be changed, for example supplemented with information.
	//
	// Syntax:
	// Procedure OnSendingMessage(MessagesChannel, MessagesBody) Export
	//
	// (The same as MessageExchangeOverridable.OnSendingMessage).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS.MessageExchange\OnMessageSending");
	
	// Handler of the event during receiving the message.
	// The handler of this event is called when receiving message from the XML stream.
	// Handler is called for each received message.
	//
	// Parameters:
	//  MessageChannel - String - Identifier of the message channel from which the message was received.
	//  MessageBody  - Arbitrary - The body of the received message.
	//   IN the event handler the message body can be changed, for example supplemented with information.
	//
	// Syntax:
	// Procedure OnReceiveMessage(MessagesChannel, MessageBody) Export
	//
	// (The same as MessageExchangeOverridable.OnReceivingMessage).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS.MessageExchange\OnMessageReceiving");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"MessageExchangeInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ServerHandlers["StandardSubsystems.DataExchange\DuringDataDumpService"].Add(
			"MessageExchange");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ServerHandlers["StandardSubsystems.DataExchange\WithImportingDataCall"].Add(
			"MessageExchange");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
		"MessageExchange");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
			"MessageExchange");
	EndIf;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.SystemMessages.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SendMessageToMessageChannel(MessageChannel, MessageBody, Recipient, IsInstantMessage = False)
	
	If TypeOf(Recipient) = Type("ExchangePlanRef.MessageExchange") Then
		
		SendMessageToRecipient(MessageChannel, MessageBody, Recipient, IsInstantMessage);
		
	ElsIf TypeOf(Recipient) = Type("Array") Then
		
		For Each Item IN Recipient Do
			
			If TypeOf(Item) <> Type("ExchangePlanRef.MessageExchange") Then
				
				Raise NStr("en='Wrong receiver for the MessagesExchange method is specified.SendMessage().';ru='Указан неправильный получатель для метода ОбменСообщениями.ОтправитьСообщение().'");
				
			EndIf;
			
			SendMessageToRecipient(MessageChannel, MessageBody, Item, IsInstantMessage);
			
		EndDo;
		
	ElsIf Recipient = Undefined Then
		
		SendMessageToRecipients(MessageChannel, MessageBody, IsInstantMessage);
		
	Else
		
		Raise NStr("en='Wrong receiver for the MessagesExchange method is specified.SendMessage().';ru='Указан неправильный получатель для метода ОбменСообщениями.ОтправитьСообщение().'");
		
	EndIf;
	
EndProcedure

Procedure SendMessageToSubscribersInMessageChannel(MessageChannel, MessageBody, IsInstantMessage = False)
	
	SetPrivilegedMode(True);
	
	Recipients = InformationRegisters.RecipientSubscriptions.MessageChannelSubscribers(MessageChannel);
	
	// Sending message to a receiver (end point).
	For Each Recipient IN Recipients Do
		
		SendMessageToRecipient(MessageChannel, MessageBody, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipients(MessageChannel, MessageBody, IsInstantMessage)
	Var DynamicallyAddedRecipients;
	
	SetPrivilegedMode(True);
	
	// Message receivers from register.
	Recipients = InformationRegisters.SenderSettings.MessageChannelSubscribers(MessageChannel);
	
	// Message receivers from code.
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.MessageExchange\WhenDeterminingRecipientsOfMessage");
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenDeterminingRecipientsOfMessage(MessageChannel, DynamicallyAddedRecipients);
	EndDo;
	
	MessageExchangeOverridable.MessageRecipients(MessageChannel, DynamicallyAddedRecipients);
	
	// Receive unique receivers array from two arrays. 
	// For this you should use the temporary values table.
	RecipientTable = New ValueTable;
	RecipientTable.Columns.Add("Recipient");
	For Each Recipient IN Recipients Do
		RecipientTable.Add().Recipient = Recipient;
	EndDo;
	
	If TypeOf(DynamicallyAddedRecipients) = Type("Array") Then
		
		For Each Recipient IN DynamicallyAddedRecipients Do
			RecipientTable.Add().Recipient = Recipient;
		EndDo;
		
	EndIf;
	
	RecipientTable.GroupBy("Recipient");
	
	Recipients = RecipientTable.UnloadColumn("Recipient");
	
	// Sending message to a receiver (end point).
	For Each Recipient IN Recipients Do
		
		SendMessageToRecipient(MessageChannel, MessageBody, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipient(MessageChannel, MessageBody, Recipient, IsInstantMessage)
	
	SetPrivilegedMode(True);
	
	If Not TransactionActive() Then
		
		Raise NStr("en='Sending of messages can be performed in transaction only.';ru='Отправка сообщений может выполняться только в транзакции.'");
		
	EndIf;
	
	If Not ValueIsFilled(MessageChannel) Then
		
		Raise NStr("en='The ""MessagesChannel"" parameter value is not specified for the MessagesExchange method.SendMessage.';ru='Не задано значение параметра ""КаналСообщений"" для метода ОбменСообщениями.ОтправитьСообщение.'");
		
	ElsIf StrLen(MessageChannel) > 150 Then
		
		Raise NStr("en='Messages channel name length must not exceed 150 symbols.';ru='Длина имени канала сообщений не должна превышать 150 символов.'");
		
	ElsIf Not ValueIsFilled(Recipient) Then
		
		Raise NStr("en='The ""Receiver"" parameter value is not specified for the MessagesExchange method.SendMessage.';ru='Не задано значение параметра ""Получатель"" для метода ОбменСообщениями.ОтправитьСообщение.'");
		
	ElsIf CommonUse.ObjectAttributeValue(Recipient, "Blocked") Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Attempt to send message to the locked end point ""%1"".';ru='Попытка отправки сообщения заблокированной конечной точке ""%1"".'"),
			String(Recipient));
	EndIf;
	
	CatalogForMessage = Catalogs.SystemMessages;
	StandardProcessing = True;
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleMessageSaaSDataSeparation = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		RedefinedCatalog = ModuleMessageSaaSDataSeparation.CatalogForMessagesOnChoice(MessageBody);
		If RedefinedCatalog <> Undefined Then
			CatalogForMessage = RedefinedCatalog;
		EndIf;
	EndIf;
	
	NewMessage = CatalogForMessage.CreateItem();
	NewMessage.Description = MessageChannel;
	NewMessage.Code = 0;
	NewMessage.ProcessMessageRetryCount = 0;
	NewMessage.Locked = False;
	NewMessage.MessageBody = New ValueStorage(MessageBody);
	NewMessage.Sender = MessageExchangeInternal.ThisNode();
	NewMessage.IsInstantMessage = IsInstantMessage;
	
	If Recipient = MessageExchangeInternal.ThisNode() Then
		
		NewMessage.Recipient = MessageExchangeInternal.ThisNode();
		
	Else
		
		NewMessage.DataExchange.Recipients.Add(Recipient);
		NewMessage.DataExchange.Recipients.AutoFill = False;
		
		NewMessage.Recipient = Recipient;
		
	EndIf;
	
	RecordStandardProcessing = True;
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleMessageSaaSDataSeparation = CommonUse.CommonModule("MessagesSaaSDataSeparation");
		ModuleMessageSaaSDataSeparation.MessageBeforeWrite(NewMessage, RecordStandardProcessing);
	EndIf;
	
	If RecordStandardProcessing Then
		NewMessage.Write();
	EndIf;
	
EndProcedure

Function StartSendingInstantMessages()
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Constant.InstantMessageSendingLocked");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		InstantMessageSendingLocked = Constants.InstantMessageSendingLocked.Get();
		
		// SessionCurrentDate() method can not be used.
		// IN this case server current date is used as a uniqueness key.
		If InstantMessageSendingLocked >= CurrentDate() Then
			CommitTransaction();
			Return False;
		EndIf;
		
		Constants.InstantMessageSendingLocked.Set(CurrentDate() + 60 * 5);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
EndFunction

Procedure FinishSendingInstantMessages()
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Constant.InstantMessageSendingLocked");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		Constants.InstantMessageSendingLocked.Set(Date('00010101'));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure CancelSendingInstantMessages()
	
	FinishSendingInstantMessages();
	
EndProcedure

Procedure DeleteChangeRecords(EndPoint, Val Messages)
	
	For Each Message IN Messages Do
		
		ExchangePlans.DeleteChangeRecords(EndPoint, Message);
		
	EndDo;
	
EndProcedure

Procedure DeliverMessagesToRecipient(EndPoint, Val Messages)
	
	Stream = "";
	
	MessageExchangeInternal.SerializeDataToStream(Messages, Stream);
	
	MessageExchangeReUse.WSEndPointProxy(EndPoint, 10).DeliverMessages(MessageExchangeInternal.ThisNodeCode(), New ValueStorage(Stream, New Deflation(9)));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Handler during data exporting.
// Used to override the standard processor of the data export.
// Data exporting logic shall be implemented in this handler:
// selection of data for export, data serialization to the message file or data serialization to flow.
// After the handler execution the data exchange subsystem will send the exported data to the receiver.
// Message format for export can be custom.
// If errors occur while sending data, you should abort
// execution of the handler using the CallException method with the error description.
//
// Parameters:
//
// StandardProcessing - Boolean -
//  A flag of standard (system) event handler is passed to this parameter.
//  If you set the False value for this parameter
//  in the body of the procedure-processor, there will be no standard processing of the event. Denial from the standard processor does not stop action.
//  Default value: True.
//
// Recipient - ExchangePlanRef -
//  Exchange plan node for which the data is exported.
//
// MessageFileName - String -
//  File name where the data shall be exported. If this parameter is filled in,
//  the system expects that the data will be exported to file. After exporting the system will send the data from this file.
//  If the parameter is empty, the system expects that the data will be exported to the MessageData parameter.
//
// MessageData - Arbitrary -
//  If the MessageFileName parameter is empty, the system expects that the data will be exported to this parameter.
//
// ItemCountInTransaction - Number -
//  It defines the maximum number of data items placed to the message within
//  one transaction of the data base.
//  You should implement the setting logic of transaction locks for the
//  exported data in the handler if needed.
//  The parameter value is specified in the data exchange subsystem settings.
//
// EventLogMonitorEventName - String -
//  Event name of the log for the current data exchange session. Used to write data with
// the specified event name to the events log monitor (errors, alerts, information).
//  Corresponds to the EventName parameter of the EventLogMonitorRecord global context method.
//
// SentObjectCount - Number -
//  Counter of the sent objects. Used to define a
//  quantity of sent objects for the subsequent record in the exchange protocol.
//
Procedure DuringDataDumpService(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								SentObjectCount
	) Export
	
	MessageExchangeInternal.DuringDataDump(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								SentObjectCount);
	
EndProcedure

// Handler during data importing.
// Used to override standard processor of the data import.
// Data importing logic shall be implemented in this handler.:
// required checks before the data import, data serialization from the message file
// or data serialization from the flow.
// Message format for import can be custom.
// If errors occur when obtaining data, interrupt the handler
// using the Raise method with the error description.
//
// Parameters:
//
//  StandardProcessing - Boolean - A flag of standard (system)
//                                  event handler is passed to this parameter. If you set
//                                  the False value for this parameter in
//                                  the body of the procedure-processor, there will be no standard processing of the event.
//                                  Denial from the standard processor does not stop action.
//                                  Default value: True.
//  Sender - ExchangePlanRef - Exchange plan node for which data is imported.
//  MessageFileName - String -    File name used to import the data.
//                                  If the parameter is not filled in,
//                                  then the data for import is passed via the MessageData parameter.
//  MessageData - Custom -Parameter contains data that should be imported.
//                                  If the MessageFileName
//                                  parameter is empty, then the data for import is passed via this parameter.
//  ItemCountInTransaction - Number - Defines the maximum quantity of the data
//                                  items that are read from message and written to the data base within one transaction.
//                                  You should implement the logic of data record in
//                                  transaction in the handler if needed.
//                                  The parameter value is specified in the data exchange subsystem settings.
//  EventLogMonitorEventName - String - Event name of the log for the current data exchange session.
//                                  Used to write data with
//                                  the specified event name to the events log monitor (errors, alerts, information).
//                                  Corresponds to the EventName
//                                  parameter of the EventLogMonitorRecord global context method.
// ReceivedObjectCount - Number - Received objects counter. Used
//                                  to define a quantity of imported objects for the subsequent record in the exchange protocol.
//
Procedure WithImportingDataCall(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								ReceivedObjectCount
	) Export
	
	MessageExchangeInternal.OnDataImport(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								ReceivedObjectCount);
	
EndProcedure

// Fills the structure with the arrays of supported
// versions of all subsystems subject to versioning and uses subsystems names as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = Names of the subsystems. 
// - Values = Arrays of supported version names.
//
// Example of implementation:
//
// // FileTransferServer
// VersionsArray = New Array;
// VersionsArray.Add("1.0.1.1");	
// VersionsArray.Add("1.0.2.1"); 
// SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
// // End FileTransferService
//
Procedure OnDefenitionSupportedVersionsOfSoftwareInterfaces(Val SupportedVersionStructure) Export
	
	VersionArray = New Array;
	VersionArray.Add("2.0.1.6");
	VersionArray.Add("2.1.1.7");
	VersionArray.Add("2.1.1.8");
	SupportedVersionStructure.Insert("MessageExchange", VersionArray);
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	ArrayCatalog = MessageExchangeReUse.GetMessagesCatalogs();
	For Each CatalogMessages IN ArrayCatalog Do
		Types.Add(CatalogMessages.EmptyRef().Metadata());
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Handler of the event during sending the message.
// The handler of this event is called before putting message into the XML stream.
// Handler is called for each outgoing message.
//
// Parameters:
//  MessageChannel - String -      Identifier of the message channel from which the message was received.
//  MessageBody - Arbitrary - The body of the received message. IN the
//                                 event handler the message body can be changed, for example supplemented with information.
//
Procedure OnMessageSending(MessageChannel, MessageBody, MessageObject) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		
		ModuleMessageSaaS = CommonUse.CommonModule("MessagesSaaS");
		ModuleMessageSaaS.OnMessageSending(MessageChannel, MessageBody, MessageObject);
		
	EndIf;
	
EndProcedure

// Handler of the event during receiving the message.
// The handler of this event is called when receiving message from the XML stream.
// Handler is called for each received message.
//
// Parameters:
//  MessageChannel - String -      Identifier of the message channel from which the message was received.
//  MessageBody - Arbitrary - The body of the received message. IN the
//                                 event handler the message body can be changed, for example supplemented with information.
//
Procedure OnMessageReceiving(MessageChannel, MessageBody, MessageObject) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleMessageSaaS = CommonUse.CommonModule("MessagesSaaS");
		ModuleMessageSaaS.OnMessageReceiving(MessageChannel, MessageBody, MessageObject);
	EndIf;
	
EndProcedure

#EndRegion
