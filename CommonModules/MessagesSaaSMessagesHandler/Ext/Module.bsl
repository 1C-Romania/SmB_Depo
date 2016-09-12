////////////////////////////////////////////////////////////////////////////////
// Message channel handler for service model messages.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Processes the body of message from channel in compliance with the algorithm of the current message channel.
//
// Parameters:
//  MessageChannel - String - message channel identifier from which the message was received.
//  MessageBody - Arbitrary - message body which is received from the channel which is subject to processing.
//  Sender - ExchangePlanRef.MessageExchange - end point which is the message sender.
//
Procedure ProcessMessage(Val MessageChannel, Val MessageBody, Val Sender) Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		SeparatedModule = CommonUse.CommonModule("MessagesSaaSDataSeparation");
	EndIf;
	
	// Read message
	MessageType = MessagesSaaS.MessageTypeByChannelName(MessageChannel);
	Message = MessagesSaaS.ReadMessageFromUntypedBody(MessageBody);
	
	MessagesSaaS.WriteMessageStartProcessing(Message);
	
	Try
		
		If CommonUseReUse.IsSeparatedConfiguration() Then
			SeparatedModule.MessageOnProcessStart(Message, Sender);
		EndIf;
		
		MessagesSaaSOverridable.MessageOnProcessStart(Message, Sender);
		
		// Receiving and performance message interface handler.
		Handler = GetChannelHandlerMessagesService(MessageChannel);
		If Handler <> Undefined Then
			
			MessageHandled = False;
			Handler.ProcessSaaSMessage(Message, Sender, MessageHandled);
			
		Else
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Failed to define the messages channel handler in the %1 service model';ru='Не удалось определить обработчик канала сообщений в модели сервиса %1'"), MessageChannel);
			
		EndIf;
		
		If CommonUseReUse.IsSeparatedConfiguration() Then
			SeparatedModule.AfterMessageProcessing(Message, Sender, MessageHandled);
		EndIf;
		
		MessagesSaaSOverridable.AfterMessageProcessing(Message, Sender, MessageHandled);
		
	Except
		
		If CommonUseReUse.IsSeparatedConfiguration() Then
			SeparatedModule.MessageOnProcessError(Message, Sender);
		EndIf;
		
		MessagesSaaSOverridable.MessageOnProcessError(Message, Sender);
		
		Raise;
		
	EndTry;
	
	MessagesSaaS.WriteEventEndDataProcessors(Message);
	
	If Not MessageHandled Then
		
		MessagesSaaS.UnknownChannelNameError(MessageChannel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GetChannelHandlerMessagesService(MessageChannel)
	
	InterfaceHandlers = MessageInterfacesSaaS.GetInterfaceHandlersOfMessages();
	
	For Each HandlerInterface IN InterfaceHandlers Do
		
		InterfaceChannelsHandlers  = New Array();
		HandlerInterface.MessageChanelProcessors(InterfaceChannelsHandlers);
		
		For Each InterfaceChannelHandler IN InterfaceChannelsHandlers Do
			
			Package = InterfaceChannelHandler.Package();
			BaseType = InterfaceChannelHandler.BaseType();
			
			ChannelNames = MessageInterfacesSaaS.GetPackageChannels(Package, BaseType);
			
			For Each ChannelName IN ChannelNames Do
				If ChannelName = MessageChannel Then
					
					Return InterfaceChannelHandler;
					
				EndIf;
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndFunction

#EndRegion
