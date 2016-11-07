////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNELS HANDLER FOR DATA EXCHANGE
//  ADMINISTRATION CONTROL MESSAGES INTERFACE VERSION 2.1.2.1
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns namespace for message interface version
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage";
	
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
	
	Dictionary = MessagesDataExchangeAdministrationManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageConnectCorrespondent(Package()) Then
		ConnectCorrespondent(Message, Sender);
	ElsIf MessageType = Dictionary.MessageSetTransportSettings(Package()) Then
		SetTransportSettings(Message, Sender);
	ElsIf MessageType = Dictionary.MessageDeleteSynchronizationSetting(Package()) Then
		DeleteSynchronizationSetting(Message, Sender);
	ElsIf MessageType = Dictionary.MessagePerformSynchronization(Package()) Then
		Synchronize(Message, Sender);
	Else
		MessageHandled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ConnectCorrespondent(Message, Sender)
	
	Body = Message.Body;
	
	// We check this end point
	ThisEndPoint = ExchangePlans.MessageExchange.FindByCode(Body.SenderId);
	
	If ThisEndPoint.IsEmpty()
		OR ThisEndPoint <> MessageExchangeInternal.ThisNode() Then
		
		// We send a message to the error service manager
		ErrorPresentation = NStr("en='The end point does not correspond to the expected one. The code of the expected end point is %1. Current end point code %2.';ru='Конечная точка не соответствует ожидаемой. Код ожидаемой конечной точки %1. Код текущей конечной точки %2.'");
		ErrorPresentation = StringFunctionsClientServer.PlaceParametersIntoString(ErrorPresentation,
			Body.SenderId,
			MessageExchangeInternal.ThisNodeCode());
		
		WriteLogEvent(EventLogMonitorMessageTextConnectionCorrespondent(),
			EventLogLevel.Error,,, ErrorPresentation);
		
		ReplyMessage = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationControlInterface.MessageCorrespondentConnectingError());
		ReplyMessage.Body.RecipientId      = Body.RecipientId;
		ReplyMessage.Body.SenderId         = Body.SenderId;
		ReplyMessage.Body.ErrorDescription = ErrorPresentation;
		
		BeginTransaction();
		MessagesSaaS.SendMessage(ReplyMessage, Sender);
		CommitTransaction();
		Return;
	EndIf;
	
	// We check if the correspondent has been already connected
	Correspondent = ExchangePlans.MessageExchange.FindByCode(Body.RecipientId);
	
	If Correspondent.IsEmpty() Then // We connect the correspondent's end point
		
		Cancel = False;
		ConnectedCorrespondent = Undefined;
		
		MessageExchange.ToConnectEndPoint(
									Cancel,
									Body.RecipientURL,
									Body.RecipientUser,
									Body.RecipientPassword,
									Body.SenderURL,
									Body.SenderUser,
									Body.SenderPassword,
									ConnectedCorrespondent,
									Body.RecipientName,
									Body.SenderName);
		
		If Cancel Then // We send a message to the error service manager
			
			ErrorPresentation = NStr("en=""Error of connecting the exchange correspondent's end point. End point code of the exchange correspondent %1."";ru='Ошибка подключения конечной точки корреспондента обмена. Код конечной точки корреспондента обмена %1.'");
			ErrorPresentation = StringFunctionsClientServer.PlaceParametersIntoString(ErrorPresentation,
				Body.RecipientId);
			
			WriteLogEvent(EventLogMonitorMessageTextConnectionCorrespondent(),
				EventLogLevel.Error,,, ErrorPresentation);
			
			ReplyMessage = MessagesSaaS.NewMessage(
				MessagesDataExchangeAdministrationControlInterface.MessageCorrespondentConnectingError());
			ReplyMessage.Body.RecipientId      = Body.RecipientId;
			ReplyMessage.Body.SenderId         = Body.SenderId;
			ReplyMessage.Body.ErrorDescription = ErrorPresentation;
			
			BeginTransaction();
			MessagesSaaS.SendMessage(ReplyMessage, Sender);
			CommitTransaction();
			Return;
		EndIf;
		
		ConnectedCorrespondentCode = CommonUse.ObjectAttributeValue(ConnectedCorrespondent, "Code");
		
		If ConnectedCorrespondentCode <> Body.RecipientId Then
			
			// A wrong exchange correspondent was connected.
			// We send a message to the error service manager
			ErrorPresentation = NStr("en=""Error at connecting the exchange correspondent's end point.
		|The web service connection settings do not correspond to the expected ones.
		|The code of the expected exchange correspondent's end point is %1.
		|Code of the connected end point of the exchange correspondent %2."";ru='Ошибка при подключении конечной точки корреспондента обмена.
		|Настройки подключения веб-сервиса не соответствуют ожидаемым.
		|Код ожидаемой конечной точки корреспондента обмена %1.
		|Код подключенной конечной точки корреспондента обмена %2.'");
			ErrorPresentation = StringFunctionsClientServer.PlaceParametersIntoString(ErrorPresentation,
				Body.RecipientId,
				ConnectedCorrespondentCode);
			
			WriteLogEvent(EventLogMonitorMessageTextConnectionCorrespondent(),
				EventLogLevel.Error,,, ErrorPresentation);
			
			ReplyMessage = MessagesSaaS.NewMessage(
				MessagesDataExchangeAdministrationControlInterface.MessageCorrespondentConnectingError());
			ReplyMessage.Body.RecipientId      = Body.RecipientId;
			ReplyMessage.Body.SenderId         = Body.SenderId;
			ReplyMessage.Body.ErrorDescription = ErrorPresentation;
			
			BeginTransaction();
			MessagesSaaS.SendMessage(ReplyMessage, Sender);
			CommitTransaction();
			Return;
		EndIf;
		
		CorrespondentObject = ConnectedCorrespondent.GetObject();
		CorrespondentObject.Blocked = True;
		CorrespondentObject.Write();
		
	Else // We update connection settings for this end point and correspondent
		
		Cancel = False;
		
		MessageExchange.UpdateEndPointConnectionSettings(
									Cancel,
									Correspondent,
									Body.RecipientURL,
									Body.RecipientUser,
									Body.RecipientPassword,
									Body.SenderURL,
									Body.SenderUser,
									Body.SenderPassword);
		
		If Cancel Then // We send a message to the error service manager
			
			ErrorPresentation = NStr("en=""Failed to update parameters of connecting this end point and the exchange correspondent's end point.
		|The code of this
		|end point is %1 The code of the exchange correspondent's end point is %2"";ru='Ошибка обновления параметров подключения этой конечной точки и конечной точки корреспондента обмена.
		|Код этой
		|конечной токи %1 Код конечной точки корреспондента обмена %2'");
			ErrorPresentation = StringFunctionsClientServer.PlaceParametersIntoString(ErrorPresentation,
				MessageExchangeInternal.ThisNodeCode(),
				Body.RecipientId);
			
			WriteLogEvent(EventLogMonitorMessageTextConnectionCorrespondent(),
				EventLogLevel.Error,,, ErrorPresentation);
			
			ReplyMessage = MessagesSaaS.NewMessage(
				MessagesDataExchangeAdministrationControlInterface.MessageCorrespondentConnectingError());
			ReplyMessage.Body.RecipientId      = Body.RecipientId;
			ReplyMessage.Body.SenderId         = Body.SenderId;
			ReplyMessage.Body.ErrorDescription = ErrorPresentation;
			
			BeginTransaction();
			MessagesSaaS.SendMessage(ReplyMessage, Sender);
			CommitTransaction();
			Return;
		EndIf;
		
		CorrespondentObject = Correspondent.GetObject();
		CorrespondentObject.Blocked = True;
		CorrespondentObject.Write();
		
	EndIf;
	
	// We send a message that the operation was completed successfully to the service manager
	BeginTransaction();
	ReplyMessage = MessagesSaaS.NewMessage(
		MessagesDataExchangeAdministrationControlInterface.MessageCorrespondentConnectedSuccessfully());
	ReplyMessage.Body.RecipientId = Body.RecipientId;
	ReplyMessage.Body.SenderId    = Body.SenderId;
	MessagesSaaS.SendMessage(ReplyMessage, Sender);
	CommitTransaction();
	
EndProcedure

Procedure SetTransportSettings(Message, Sender)
	
	Body = Message.Body;
	
	Correspondent = ExchangePlans.MessageExchange.FindByCode(Body.RecipientId);
	
	If Correspondent.IsEmpty() Then
		MessageString = NStr("en='Correspondent end point with the %1 script is not found.';ru='Не найдена конечная точка корреспондента с кодом ""%1"".'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, Body.RecipientId);
		Raise MessageString;
	EndIf;
	
	DataExchangeServer.SetDataImportItemsInTransactionQuantity(Body.ImportTransactionQuantity);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("CorrespondentEndPoint", Correspondent);
	
	RecordStructure.Insert("FILEInformationExchangeDirectory",       Body.FILE_ExchangeFolder);
	RecordStructure.Insert("FILECompressOutgoingMessageFile", Body.FILE_CompressExchangeMessage);
	
	RecordStructure.Insert("FTPCompressOutgoingMessageFile",                  Body.FTP_CompressExchangeMessage);
	RecordStructure.Insert("FTPConnectionMaximumValidMessageSize", Body.FTP_MaxExchangeMessageSize);
	RecordStructure.Insert("FTPConnectionPassword",                                Body.FTP_Password);
	RecordStructure.Insert("FTPConnectionPassiveConnection",                   Body.FTP_PassiveMode);
	RecordStructure.Insert("FTPConnectionUser",                          Body.FTP_User);
	RecordStructure.Insert("FTPConnectionPort",                                  Body.FTP_Port);
	RecordStructure.Insert("FTPConnectionPath",                                  Body.FTP_ExchangeFolder);
	
	RecordStructure.Insert("ExchangeMessageTransportKindByDefault",      Enums.ExchangeMessagesTransportKinds[Body.ExchangeTransport]);
	RecordStructure.Insert("ExchangeMessageArchivePassword",                  Body.ExchangeMessagePassword);
	
	InformationRegisters.DataAreasTransportExchangeSettings.UpdateRecord(RecordStructure);
	
EndProcedure

Procedure DeleteSynchronizationSetting(Message, Sender)
	
	Body = Message.Body;
	
	// Searching the node by the S00000123 node code format
	Correspondent = ExchangePlans[Body.ExchangePlan].FindByCode(
		DataExchangeSaaS.ExchangePlanNodeCodeInService(Body.CorrespondentZone));
	If Correspondent.IsEmpty() Then
		
		// Searching for the node by the 0000123 (old) code format
		Correspondent = ExchangePlans[Body.ExchangePlan].FindByCode(
			Format(Body.CorrespondentZone,"ND=7; NLZ=; NG=0"));
	EndIf;
	
	If Correspondent.IsEmpty() Then
		Return; // exchange setting is not found (it was probably deleted earlier)
	EndIf;
	
	TransportSettings = InformationRegisters.DataAreaTransportExchangeSettings.TransportSettings(Correspondent);
	
	If TransportSettings <> Undefined Then
		
		If TransportSettings.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.FILE Then
			
			If Not IsBlankString(TransportSettings.FILEInformationExchangeCommonDirectory)
				AND Not IsBlankString(TransportSettings.InformationExchangeDirectoryRelative) Then
				
				InformationExchangeAbsoluteDirectory = CommonUseClientServer.GetFullFileName(
					TransportSettings.FILEInformationExchangeCommonDirectory,
					TransportSettings.InformationExchangeDirectoryRelative);
				
				AbsoluteDirectory = New File(InformationExchangeAbsoluteDirectory);
				
				Try
					DeleteFiles(AbsoluteDirectory.FullName);
				Except
					WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
						EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndIf;
			
		ElsIf TransportSettings.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.FTP Then
			
			Try
				
				FTPSettings = DataExchangeServer.FTPConnectionSettings();
				FTPSettings.Server               = TransportSettings.FTPServer;
				FTPSettings.Port                 = TransportSettings.FTPConnectionPort;
				FTPSettings.UserName      = TransportSettings.FTPConnectionUser;
				FTPSettings.UserPassword   = TransportSettings.FTPConnectionPassword;
				FTPSettings.PassiveConnection  = TransportSettings.FTPConnectionPassiveConnection;
				FTPSettings.SecureConnection = DataExchangeServer.SecureConnection(TransportSettings.FTPConnectionPath);
				
				FTPConnection = DataExchangeServer.FTPConnection(FTPSettings);
				
				If DataExchangeServer.FTPDirectoryExist(TransportSettings.FTPPath, TransportSettings.InformationExchangeDirectoryRelative, FTPConnection) Then
					FTPConnection.Delete(TransportSettings.FTPPath);
				EndIf;
				
			Except
				WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSyncronizationSetting(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		EndIf;
		
	EndIf;
	
	// We delete the correspondent's node
	Correspondent.GetObject().Delete();
	
EndProcedure

Procedure Synchronize(Message, Sender)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(Message.Body.Scenario);
	
	If DataExchangeScenario.Count() > 0 Then
		
		// Run the script
		DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase(0, DataExchangeScenario);
		
	EndIf;
	
EndProcedure

Function EventLogMonitorMessageTextConnectionCorrespondent()
	
	Return NStr("en='Data exchange. Exchange correspondent connection';ru='Обмен данными.Подключение корреспондента обмена'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

#EndRegion
