////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER FOR VERSION 2.1.2.1
//  DATA EXCHANGE CONTROL MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns namespace for message interface version
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Control";
	
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
//  Message - ObjectXDTO, incoming message,
//  Sender - ExchangePlanRef.Messaging, exchange plan node, corresponding to message sender 
//  MessageProcessed - Boolean, a flag showing that the message is successfully processed. The value of
//    this parameter shall be set to True if the message was successfully read in this handler
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageHandled) Export
	
	MessageHandled = True;
	
	Dictionary = MessageControlDataExchangeInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageExchangeSettingStep1CompletedSuccessfully(Package()) Then
		
		SettingExchangeStep1SuccessfullyCompleted(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageExchangeSettingStep2CompletedSuccessfully(Package()) Then
		
		ExchangeSettingStep2CompletedSuccessfully(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageExchangeSettingErrorStep1(Package()) Then
		
		ExchangeSettingErrorStep1(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageExchangeSettingErrorStep2(Package()) Then
		
		ExchangeSettingErrorStep2(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageExchangeMessageImportingCompletedSuccessfully(Package()) Then
		
		ImportMessageExchangeSuccessfullyCompleted(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageExchangeMessageImportingError(Package()) Then
		
		ExchangeMessageImportingError(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageCorrespondentDataGettingCompletedSuccessfully(Package()) Then
		
		CorrespondentDataGettingCompletedSuccessfully(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageCorrespondentNodesCommonDataGettingCompletedSuccessfully(Package()) Then
		
		CorrespondentNodesCommonDataGettingCompletedSuccessfully(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageCorrespondentDataGettingError(Package()) Then
		
		CorrespondentDataGettingError(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageCorrespondentNodesCommonDataGettingError(Package()) Then
		
		CorrespondentNodesCommonDataGettingError(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageCorrespondentAccountingParametersGettingCompletedSuccessfully(Package()) Then
		
		CorrespondentAccountingParametersGettingCompletedSuccessfully(Message, Sender);
		
	ElsIf MessageType = Dictionary.MessageCorrespondentAccountingParametersGettingError(Package()) Then
		
		CorrespondentAccountingParametersGettingError(Message, Sender);
		
	Else
		
		MessageHandled = False;
		Return;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// exchange setup

Procedure SettingExchangeStep1SuccessfullyCompleted(Message, Sender)
	
	DataExchangeSaaS.FixSuccessfullSessionCompletion(Message, RepresentationSynchronizationSettingStep1());
	
EndProcedure

Procedure ExchangeSettingStep2CompletedSuccessfully(Message, Sender)
	
	DataExchangeSaaS.FixSuccessfullSessionCompletion(Message, RepresentationSynchronizationSettingStep2());
	
EndProcedure

Procedure ExchangeSettingErrorStep1(Message, Sender)
	
	DataExchangeSaaS.FixUnsuccessfullSessionCompletion(Message, RepresentationSynchronizationSettingStep1());
	
EndProcedure

Procedure ExchangeSettingErrorStep2(Message, Sender)
	
	DataExchangeSaaS.FixUnsuccessfullSessionCompletion(Message, RepresentationSynchronizationSettingStep2());
	
EndProcedure

Procedure ImportMessageExchangeSuccessfullyCompleted(Message, Sender)
	
	DataExchangeSaaS.FixSuccessfullSessionCompletion(Message, RepresentationExchangeMessageImporting());
	
EndProcedure

Procedure ExchangeMessageImportingError(Message, Sender)
	
	DataExchangeSaaS.FixSuccessfullSessionCompletion(Message, RepresentationExchangeMessageImporting());
	
EndProcedure

// Receive correspondent data

Procedure CorrespondentDataGettingCompletedSuccessfully(Message, Sender)
	
	DataExchangeSaaS.SaveSessionData(Message, RepresentationCorrespondentDataGetting());
	
EndProcedure

Procedure CorrespondentNodesCommonDataGettingCompletedSuccessfully(Message, Sender)
	
	DataExchangeSaaS.SaveSessionData(Message, RepresentationCorrespondentNodesCommonDataGetting());
	
EndProcedure

Procedure CorrespondentDataGettingError(Message, Sender)
	
	DataExchangeSaaS.FixUnsuccessfullSessionCompletion(Message, RepresentationCorrespondentDataGetting());
	
EndProcedure

Procedure CorrespondentNodesCommonDataGettingError(Message, Sender)
	
	DataExchangeSaaS.FixUnsuccessfullSessionCompletion(Message, RepresentationCorrespondentNodesCommonDataGetting());
	
EndProcedure

// Getting correspondent accounting parameters

Procedure CorrespondentAccountingParametersGettingCompletedSuccessfully(Message, Sender)
	
	DataExchangeSaaS.SaveSessionData(Message, RepresentationCorrespondentAccountingParametersGetting());
	
EndProcedure

Procedure CorrespondentAccountingParametersGettingError(Message, Sender)
	
	DataExchangeSaaS.FixUnsuccessfullSessionCompletion(Message, RepresentationCorrespondentAccountingParametersGetting());
	
EndProcedure

// Auxiliary functions

Function RepresentationSynchronizationSettingStep1()
	
	Return NStr("en='Synchronization setup, step 1.';ru='Настройка синхронизации, шаг 1.'");
	
EndFunction

Function RepresentationSynchronizationSettingStep2()
	
	Return NStr("en='Synchronization setup, step 2.';ru='Настройка синхронизации, шаг 2.'");
	
EndFunction

Function RepresentationExchangeMessageImporting()
	
	Return NStr("en='Import the exchange messages.';ru='Загрузка сообщения обмена.'");
	
EndFunction

Function RepresentationCorrespondentDataGetting()
	
	Return NStr("en='Receiving the correspondent data.';ru='Получение данных корреспондента.'");
	
EndFunction

Function RepresentationCorrespondentNodesCommonDataGetting()
	
	Return NStr("en='Receiving the correspondent nodes common date.';ru='Получение общих данных узлов корреспондента.'");
	
EndFunction

Function RepresentationCorrespondentAccountingParametersGetting()
	
	Return NStr("en='Receiving the correspondent accounting parameters.';ru='Получение параметров учета корреспондента.'");
	
EndFunction

#EndRegion
