////////////////////////////////////////////////////////////////////////////////
// MessageExchange: support of work with data area messages.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// It is called when filling the array of catalogs which you can use to store messages.
// 
//
// Parameters:
//  ArrayCatalog - Array - you need to add catalog managers to this parameter, these managers can be used to store queue jobs.
//    
//
Procedure WhenFillingCatalogsMessages(ArrayCatalog) Export
	
	ArrayCatalog.Add(Catalogs.DataAreasMessages);
	
EndProcedure

// Selects a catalog for message.
//
// Parameters:
// MessageBody - Arbitrary - message body.
//
Function CatalogForMessagesOnChoice(Val MessageBody) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainTypedMessage(MessageBody, Message) Then
		
		If MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
			
			Return Catalogs.DataAreasMessages;
			
		EndIf;
		
	Else
		
		If CommonUse.UseSessionSeparator() Then
			Return Catalogs.DataAreasMessages;
		EndIf;
		
	EndIf;
	
EndFunction

// called before write of message catalog item.
//
// Parameters:
//  MessageObject - CatalogObject.SystemMessages, CatalogObject.DataAreasMessages, 
//  StandardDataProcessor - Boolean.
//
Procedure MessageBeforeWrite(MessageObject, StandardProcessing) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainTypedMessage(MessageObject.MessageBody.Get(), Message) Then
		
		If MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
			
			MessageObject.DataAreaAuxiliaryData = Message.Body.Zone;
			
		EndIf;
		
	EndIf;
	
	StandardProcessing = False;
	CommonUse.AuxilaryDataWrite(MessageObject);
	
EndProcedure

// Handler of the event during sending the message.
// The handler of this event is called before putting message into the XML stream.
// Handler is called for each outgoing message.
//
// Parameters:
//  MessageChannel - String - message channel identifier to which the message is sent.
//  MessageBody - Arbitrary - The body of the outgoing message. 
//    In the event handler the message body can be changed, for example supplemented with information.
//
Procedure OnMessageSending(MessageChannel, MessageBody, MessageObject) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainTypedMessage(MessageBody, Message) Then
		
		If CommonUseReUse.CanUseSeparatedData()
			AND MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
			
			If CommonUse.SessionSeparatorValue() <> Message.Body.Zone Then
				MessagePattern = NStr("en='Attempting to send message on behalf of area %1 from area %2';ru='Попытка отправить сообщение от имени области %1 из области %2'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, 
					Message.Body.Zone, 
					CommonUse.SessionSeparatorValue());
				Raise(MessageText);
			EndIf;
		EndIf;
		
		If MessagesSaaSReUse.TypeAuthenticatedZoneBody().IsDescendant(Message.Body.Type()) Then
			
			If CommonUseReUse.CanUseSeparatedData() Then
				Message.Body.ZoneKey = Constants.DataAreaKey.Get();
			Else
				SetPrivilegedMode(True);
				CommonUse.SetSessionSeparation(True, Message.Body.Zone);
				Message.Body.ZoneKey = Constants.DataAreaKey.Get();
				CommonUse.SetSessionSeparation(False);
			EndIf;
			
		EndIf;
		
		MessageBody = MessagesSaaS.WriteMessageToUntypedBody(Message);
		
	EndIf;
	
	If TypeOf(MessageObject) <> Type("CatalogObject.SystemMessages") Then
		
		MessageObjectChange = Catalogs.SystemMessages.CreateItem();
		
		FillPropertyValues(MessageObjectChange, MessageObject, , "Parent,Owner");
		
		MessageObjectChange.SetNewObjectRef(Catalogs.SystemMessages.GetRef(
			MessageObject.Ref.UUID()));
		
		MessageObject = MessageObjectChange;
		
	EndIf;
	
EndProcedure

// Handler of the event during receiving the message.
// The handler of this event is called when receiving message from the XML stream.
// Handler is called for each received message.
//
// Parameters:
//  MessageChannel - String - message channel identifier from which the message was received.
//  MessageBody - Arbitrary - The body of the received message. 
//    In the event handler the message body can be changed, for example supplemented with information.
//
Procedure OnMessageReceiving(MessageChannel, MessageBody, MessageObject) Export
	
	SetPrivilegedMode(True);
	
	Message = Undefined;
	If MessagesSaaS.BodyContainTypedMessage(MessageBody, Message) Then
		
		If CommonUseReUse.IsSeparatedConfiguration() Then
			
			RedefinedCatalog = CatalogForMessagesOnChoice(MessageBody);
			
			If RedefinedCatalog <> Undefined Then
				
				If TypeOf(RedefinedCatalog.EmptyRef()) <> TypeOf(MessageObject.Ref) Then
					
					MessageObjectReferenceChange = RedefinedCatalog.GetRef(
						MessageObject.GetNewObjectRef().UUID());
					
					If CommonUse.RefExists(MessageObjectReferenceChange) Then
						
						MessageObjectChange = MessageObjectReferenceChange.GetObject();
						
					Else
						
						MessageObjectChange = RedefinedCatalog.CreateItem();
						MessageObjectChange.SetNewObjectRef(MessageObjectReferenceChange);
						
					EndIf;
					
					FillPropertyValues(MessageObjectChange, MessageObject, , "Parent,Owner");
					MessageObjectChange.DataAreaAuxiliaryData = Message.Body.Zone;
					
					MessageObject = MessageObjectChange;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is called when starting the processing of incoming message.
//
// Parameters:
//  Message - XDTODataObject - incoming message, 
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node corresponding to the infobase which sent the message.
//    
//
Procedure MessageOnProcessStart(Val Message, Val Sender) Export
	
	If MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
		
		CommonUse.SetSessionSeparation(True, Message.Body.Zone);
		ProcessKeyAreasInMessage(Message);
		
	EndIf;
	
EndProcedure

// Procedure is called after processing the incoming message.
//
// Parameters:
//  Message - XDTODataObject - incoming message, 
//  Sender - ExchangePlanRef.MessageExchange - exchange plan  node corresponding to the infobase which sent the message,
//  MessageHandled - Boolean, flag showing that the message was successfully processed. 
//    If value is set to False - an exception will be thrown after execution of this procedure. 
//    In this procedure this parameter value can be changed.
//
Procedure AfterMessageProcessing(Val Message, Val Sender, MessageHandled) Export
	
	If MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
		
		CommonUse.SetSessionSeparation(False);
		
	EndIf;
	
EndProcedure

// Procedure is called when there is an error in message processor.
//
// Parameters:
//  Message - XDTODataObject - incoming message, 
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node corresponding to the infobase which sent the message.
//    
//
Procedure MessageOnProcessError(Val Message, Val Sender) Export
	
	If MessagesSaaSReUse.TypeAreaBody().IsDescendant(Message.Body.Type()) Then
		
		CommonUse.SetSessionSeparation(False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ProcessKeyAreasInMessage(Message)
	
	MessageContainsAreaKey = False;
	
	If MessagesSaaSReUse.TypeAuthenticatedZoneBody().IsDescendant(Message.Body.Type()) Then
		MessageContainsAreaKey = True;
	EndIf;
	
	If Not MessageContainsAreaKey Then
		
		ArrayOfHandlers = New Array();
		RemoteAdministrationMessagesInterface.MessageChanelProcessors(ArrayOfHandlers);
		For Each Handler IN ArrayOfHandlers Do
			
			ProcessorMessageType = RemoteAdministrationMessagesInterface.MessageSetDataAreaParameters(
				Handler.Package());
			
			If Message.Body.Type() = ProcessorMessageType Then
				MessageContainsAreaKey = True;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If MessageContainsAreaKey Then
		
		AreaCurrentKey = Constants.DataAreaKey.Get();
		
		If Not ValueIsFilled(AreaCurrentKey) Then
			
			Constants.DataAreaKey.Set(Message.Body.ZoneKey);
			
		Else
			
			If AreaKeyCheckAtMessageAvailable() Then
				
				If AreaCurrentKey <> Message.Body.ZoneKey Then
					
					Raise NStr("en='Incorrect key of the data area in the message.';ru='Неверный ключ области данных в сообщении!'");
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function AreaKeyCheckAtMessageAvailable()
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(
		SaaSReUse.ServiceManagerEndPoint());
	ConnectionParametersPBC = New Structure;
	ConnectionParametersPBC.Insert("URL",      SettingsStructure.WSURLWebService);
	ConnectionParametersPBC.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParametersPBC.Insert("Password", SettingsStructure.WSPassword);
	
	MaximalVersion = Undefined;
	VersionsMS = CommonUse.GetInterfaceVersions(ConnectionParametersPBC, "MessagesSaaS");
	If VersionsMS = Undefined Then
		Return False;
	EndIf;
	
	For Each VersionMS IN VersionsMS Do
		
		If MaximalVersion = Undefined Then
			MaximalVersion = VersionMS;
		Else
			MaximalVersion = ?(CommonUseClientServer.CompareVersions(
				VersionMS, MaximalVersion) > 0, VersionMS,
				MaximalVersion);
		EndIf;
		
	EndDo;
	
	If VersionMS = Undefined Then
		Return False;
	EndIf;
	
	Return (CommonUseClientServer.CompareVersions(MaximalVersion, "1.0.4.1") >= 0);
	
EndFunction

#EndRegion
