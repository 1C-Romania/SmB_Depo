////////////////////////////////////////////////////////////////////////////////
// CHANNEL HANDLER MESSAGES FOR VERSION 1.0.3.4
//  REMOTE ADMINISTRATION MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns version name space of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/RemoteAdministration/App/" + Version();
	
EndFunction

// Returns message interface version, served by the handler.
Function Version() Export
	
	Return "1.0.3.4";
	
EndFunction

// Returns default type for version messages.
Function BaseType() Export
	
	Return MessagesSaaSReUse.TypeBody();
	
EndFunction

// Processes incoming messages in service model.
//
// Parameters:
//  Message - ObjectXDTO,
//  incoming message, Sender - ExchangePlanRef.MessageExchange, exchange node plan corresponding to the message sender.
//  MessageHandled - Boolean, a flag showing that the message is successfully processed. The value of
//    this parameter shall be set as equal True if the message was successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageHandled) Export
	
	MessageHandled = True;
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface = CommonUse.CommonModule("MessagesManagementAdditionalReportsAndDataProcessorsInterface");
	Else
		ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface = Undefined;
	EndIf;
	MessageType = Message.Body.Type();
	
	If MessageType = RemoteAdministrationMessagesInterface.MessageUpdateUser(Package()) Then
		UpdateUser(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessagePrepareDataArea(Package()) Then
		PrepareDataArea(Message, Sender, False);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessagePrepareDataAreaFromExporting(Package()) Then
		PrepareDataArea(Message, Sender, True);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageDeleteDataArea(Package()) Then
		DeleteDataArea(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageSetAccessToDataArea(Package()) Then
		SetAccessToDataArea(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageSetServiceManagerEndPoint(Package()) Then
		SetServiceManagerEndPoint(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageSetInfobaseParameters(Package()) Then
		SetInfobaseParameters(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageSetDataAreaParameters(Package()) Then
		SetDataAreaParameters(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageSetDataAreaFullAccess(Package()) Then
		SetDataAreaFullAccess(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageSetDefaultUserRights(Package()) Then
		SetDefaultUserRights(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageSetDataAreaRating(Package()) Then
		SetDataAreaRating(Message, Sender);
	ElsIf MessageType = RemoteAdministrationMessagesInterface.MessageDataAreaAttach(Package()) Then
		DataAreaAttach(Message, Sender);
	ElsIf ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface <> Undefined AND MessageType = ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface.MessageSetAdditionalReportOrProcessing(Package()) Then
		SetAdditionalReportOrProcessing(Message, Sender);
	ElsIf ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface <> Undefined AND MessageType = ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface.MessageDeleteAdditionalReportOrProcessing(Package()) Then
		DeleteAdditionalReportOrProcessing(Message, Sender);
	ElsIf ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface <> Undefined AND MessageType = ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface.MessageDisableAdditionalReportOrProcessing(Package()) Then
		DisableAdditionalReportOrProcessing(Message, Sender);
	ElsIf ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface <> Undefined AND MessageType = ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface.MessageEnableAdditionalReportOrProcessing(Package()) Then
		EnableAdditionalReportOrProcessing(Message, Sender);
	ElsIf ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface <> Undefined AND MessageType = ManagementMessagesModuleAdditionalReportsAndDataProcessorsInterface.MessageRecallAdditionalReportOrProcessing(Package()) Then
		RecallAdditionalReportOrProcessing(Message, Sender);
	Else
		MessageHandled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure UpdateUser(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesRemoteAdministrationImplementation.UpdateUser(
		MessageBody.Name,
		MessageBody.DescriptionFull,
		MessageBody.StoredPasswordValue,
		MessageBody.UserApplicationID,
		MessageBody.UserServiceID,
		MessageBody.Phone,
		MessageBody.EMail,
		MessageBody.Language);
	
EndProcedure

Procedure PrepareDataArea(Val Message, Val Sender, Val FromExporting)
	
	MessageBody = Message.Body;
	MessagesRemoteAdministrationImplementation.PrepareDataArea(
		MessageBody.Zone,
		FromExporting,
		?(FromExporting, Undefined, MessageBody.Kind),
		MessageBody.DataFileId);
	
EndProcedure

Procedure DeleteDataArea(Message, Sender)
	
	MessagesRemoteAdministrationImplementation.DeleteDataArea(Message.Body.Zone);
	
EndProcedure

Procedure SetAccessToDataArea(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesRemoteAdministrationImplementation.SetAccessToDataArea(
		MessageBody.Name,
		MessageBody.StoredPasswordValue,
		MessageBody.UserServiceID,
		MessageBody.Value,
		MessageBody.Language);
	
EndProcedure

Procedure SetServiceManagerEndPoint(Val Message, Val Sender)
	
	MessagesRemoteAdministrationImplementation.SetServiceManagerEndPoint(Sender);
	
EndProcedure

Procedure SetInfobaseParameters(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	Parameters = XDTOSerializer.ReadXDTO(MessageBody.Params);
	MessagesRemoteAdministrationImplementation.SetInfobaseParameters(Parameters);
	
EndProcedure

Procedure SetDataAreaParameters(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesRemoteAdministrationImplementation.SetDataAreaParameters(
		MessageBody.Zone,
		MessageBody.Presentation,
		MessageBody.TimeZone);
	
EndProcedure

Procedure SetDataAreaFullAccess(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesRemoteAdministrationImplementation.SetDataAreaFullAccess(
		MessageBody.UserServiceID,
		MessageBody.Value);
	
EndProcedure

Procedure SetDefaultUserRights(Val Message, Val Sender)
	
	MessagesRemoteAdministrationImplementation.SetDefaultUserRights(
		Message.Body.UserServiceID);
	
EndProcedure

Procedure SetDataAreaRating(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	RatingTable = New ValueTable();
	RatingTable.Columns.Add("DataAreaAuxiliaryData", New TypeDescription("Number", , New NumberQualifiers(7,0)));
	RatingTable.Columns.Add("Rating", New TypeDescription("Number", , New NumberQualifiers(7,0)));
	For Each MessageString IN MessageBody.Item Do
		RatingRow = RatingTable.Add();
		RatingRow.DataAreaAuxiliaryData = MessageString.Zone;
		RatingRow.Rating = MessageString.Rating;
	EndDo;
	MessagesRemoteAdministrationImplementation.SetDataAreaRating(
		RatingTable, MessageBody.SetAllZones);
	
EndProcedure

Procedure DataAreaAttach(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesRemoteAdministrationImplementation.DataAreaAttach(MessageBody); 
	
EndProcedure

Procedure SetAdditionalReportOrProcessing(Val Message, Val Sender)
	
	
	
EndProcedure

Procedure DeleteAdditionalReportOrProcessing(Val Message, Val Sender)
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		
		MessageBody = Message.Body;
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule = CommonUse.CommonModule("MessagesManagementAdditionalReportsAndDataProcessorsImplementation");
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule.DeleteAdditionalReportOrProcessing(
			MessageBody.Extension, MessageBody.Installation);
		
	EndIf;
	
EndProcedure

Procedure DisableAdditionalReportOrProcessing(Val Message, Val Sender)
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule = CommonUse.CommonModule("MessagesManagementAdditionalReportsAndDataProcessorsImplementation");
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule.DisableAdditionalReportOrProcessing(
			Message.Body.Extension);
		
	EndIf;
	
EndProcedure

Procedure EnableAdditionalReportOrProcessing(Val Message, Val Sender)
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule = CommonUse.CommonModule("MessagesManagementAdditionalReportsAndDataProcessorsImplementation");
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule.EnableAdditionalReportOrProcessing(
			Message.Body.Extension);
		
	EndIf;
	
EndProcedure

Procedure RecallAdditionalReportOrProcessing(Val Message, Val Sender)
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule = CommonUse.CommonModule("MessagesManagementAdditionalReportsAndDataProcessorsImplementation");
		
		AdditionalReportsAndProcessingImplementationMessagesManagementModule.RecallAdditionalReportOrProcessing(
			Message.Body.Extension);
		
	EndIf;
	
EndProcedure

#EndRegion
