////////////////////////////////////////////////////////////////////////////////
// MessageExchangeInternal.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem event handlers.

// Handler of the AtDataExport event of the data exchange subsystem.
// For the handler description, see CommonModule.DataExchangeOverridable.AtDataExport().
//
Procedure DuringDataDump(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								SentObjectCount
	) Export
	
	If TypeOf(Recipient) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	CatalogsMessages = MessageExchangeReUse.GetMessagesCatalogs();
	
	StandardProcessing = False;
	
	DataSelectionTable = New ValueTable;
	DataSelectionTable.Columns.Add("Data");
	DataSelectionTable.Columns.Add("Order", New TypeDescription("Number"));
	
	WritingToFile = Not IsBlankString(MessageFileName);
	
	XMLWriter = New XMLWriter;
	
	If WritingToFile Then
		XMLWriter.OpenFile(MessageFileName);
	Else
		XMLWriter.SetString();
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	// Create a new message
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	WriteMessage.BeginWrite(XMLWriter, Recipient);
	
	// Count the number of written objects.
	SentObjectCount = 0;
	
	// Get the changed data selection.
	ChangeSelection = DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
	
	Try
		
		While ChangeSelection.Next() Do
			
			TableRow = DataSelectionTable.Add();
			TableRow.Data = ChangeSelection.Get();
			
			TableRow.Order = 0;
			For Each CatalogMessages IN CatalogsMessages Do
				If TypeOf(TableRow.Data) = TypeOf(CatalogMessages.EmptyRef()) Then
					TableRow.Order = TableRow.Data.Code;
					Break;
				EndIf;
			EndDo;
			
		EndDo;
		
		DataSelectionTable.Sort("Order Asc");
		
		For Each TableRow IN DataSelectionTable Do
			
			InProgressMessageSending = False;
			
			For Each CatalogMessages IN CatalogsMessages Do
				
				If TypeOf(TableRow.Data) = TypeOf(CatalogMessages.CreateItem()) Then
					InProgressMessageSending = True;
					Break;
				EndIf;
				
			EndDo;
			
			If InProgressMessageSending Then
				
				TableRow.Data.Code = 0;
				
				// {Event handler: AtMessageSending} Begin.
				MessageBody = TableRow.Data.Body.Get();
				
				OnMessageSendingSSL(TableRow.Data.Description, MessageBody, TableRow.Data);
				
				OnMessageSending(TableRow.Data.Description, MessageBody);
				
				TableRow.Data.Body = New ValueStorage(MessageBody);
				// {Event handler: AtMessageSending} End.
				
			EndIf;
			
			If TypeOf(TableRow.Data) = Type("ObjectDeletion") Then
				
				If TypeOf(TableRow.Data.Ref) <> Type("CatalogRef.SystemMessages") Then
					
					TableRow.Data = New ObjectDeletion(Catalogs.SystemMessages.GetRef(
						TableRow.Data.Ref.UUID()));
					
				EndIf;
				
			EndIf;
			
			// Write data to the message.
			WriteXML(XMLWriter, TableRow.Data);
			
			SentObjectCount = SentObjectCount + 1;
			
		EndDo;
		
		// Finish writing the message
		WriteMessage.EndWrite();
		MessageData = XMLWriter.Close();
		
	Except
		
		WriteMessage.CancelWrite();
		XMLWriter.Close();
		Raise DetailErrorDescription(ErrorInfo());
		
	EndTry;
	
EndProcedure

// Handler of the AtDataImport event of the data exchange subsystem.
// For the handler description, see CommonModule.DataExchangeOverridable.AtDataImport().
//
Procedure OnDataImport(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								ReceivedObjectCount
	) Export
	
	If TypeOf(Sender) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Undefined;
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
	EndIf;
	
	CatalogsMessages = MessageExchangeReUse.GetMessagesCatalogs();
	
	StandardProcessing = False;
	
	XMLReader = New XMLReader;
	
	If Not IsBlankString(MessageData) Then
		XMLReader.SetString(MessageData);
	Else
		XMLReader.OpenFile(MessageFileName);
	EndIf;
	
	MessageReader = ExchangePlans.CreateMessageReader();
	MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	
	BackupCopiesParameters = DataExchangeServer.BackupCopiesParameters(MessageReader.Sender, MessageReader.ReceivedNo);
	
	DeleteChangeRecords = Not BackupCopiesParameters.BackupRestored;
	
	If DeleteChangeRecords Then
		
		// Delete changes registration for the message sender node.
		ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
		
	EndIf;
	
	// Count how many objects you have read.
	ReceivedObjectCount = 0;
	
	Try
		
		MessageExchangeCanBeAcceptedPartially = GetPartialMessagesSupportsCorrespondentExchange(Sender);
		ExchangeMessageAcceptedInPart = False;
		
		// Read data from the message
		While CanReadXML(XMLReader) Do
			
			Try
				// Read the next value
				Data = ReadXML(XMLReader);
			Except
				ErrInfo = ErrorInfo();
				DetailDescription = DetailErrorDescription(ErrInfo);
			EndTry;
			
			ReceivedObjectCount = ReceivedObjectCount + 1;
			
			InProgressGetMessage = False;
			For Each CatalogMessages IN CatalogsMessages Do
				If TypeOf(Data) = TypeOf(CatalogMessages.CreateItem()) Then
					InProgressGetMessage = True;
					Break;
				EndIf;
			EndDo;
			
			If InProgressGetMessage Then
				
				If Not Data.IsNew() Then
					Continue; // Import only new messages.
				EndIf;
				
				// {Handler: AtMessageReception} Begin
				MessageBody = Data.Body.Get();
				
				OnMessageGettingSSL(Data.Description, MessageBody, Data);
				
				OnMessageReceiving(Data.Description, MessageBody);
				
				Data.Body = New ValueStorage(MessageBody);
				// {Handler: AtMessageReception} End
				
				If Not Data.IsNew() Then
					Continue; // Import only new messages.
				EndIf;
				
				Data.SetNewCode();
				Data.Sender = MessageReader.Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
				
			ElsIf TypeOf(Data) = Type("InformationRegisterRecordSet.RecipientSubscriptions") Then
				
				Data.Filter["Recipient"].Value = MessageReader.Sender;
				
				For Each RecordSetRow IN Data Do
					
					RecordSetRow.Recipient = MessageReader.Sender;
					
				EndDo;
				
			ElsIf TypeOf(Data) = Type("ObjectDeletion") Then
				
				If TypeOf(Data.Ref) = Type("CatalogRef.SystemMessages") Then
					
					For Each CatalogMessages IN CatalogsMessages Do
						
						SubstitutionOfLinks = CatalogMessages.GetRef(Data.Ref.UUID());
						If CommonUse.RefExists(SubstitutionOfLinks) Then
							
							Data = New ObjectDeletion(SubstitutionOfLinks);
							Break;
							
						EndIf;
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
			DataArea = -1;
			If TypeOf(Data) = Type("ObjectDeletion") Then
				
				Ref = Data.Ref;
				If Not CommonUse.RefExists(Ref) Then
					Continue;
				EndIf;
				If CommonUseReUse.IsSeparatedConfiguration() AND CommonUse.IsSeparatedMetadataObject(Ref.Metadata(), CommonUseReUse.SupportDataSplitter()) Then
					DataArea = CommonUse.ObjectAttributeValue(Data.Ref, CommonUseReUse.SupportDataSplitter());
				EndIf;
				
			Else
				
				If CommonUseReUse.IsSeparatedConfiguration() AND CommonUse.IsSeparatedMetadataObject(Data.Metadata(), CommonUseReUse.SupportDataSplitter()) Then
					DataArea = Data[CommonUseReUse.SupportDataSplitter()];
				EndIf;
				
			EndIf;
			
			RequiredRestorationDivision = False;
			If DataArea <> -1 Then
				
				If ModuleSaaSOperations.DataAreaBlocked(DataArea) Then
					// A message for a locked field can not be received.
					If MessageExchangeCanBeAcceptedPartially Then
						ExchangeMessageAcceptedInPart = True;
						Continue;
					Else
						Raise StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='Cannot perform an email exchange due to: data area %1 is locked.';ru='Не удалось выполнить обмен сообщениями по причине: область данных %1 заблокирована!'"),
							DataArea);
					EndIf;
				EndIf;
				
				RequiredRestorationDivision = True;
				CommonUse.SetSessionSeparation(True, DataArea);
				
			EndIf;
			
			// IN case of a conflict between changes, priority is given to the
			// current
			// infobase (except for incoming ObjectDeletion from messages whose recipient is an infobase correspondent).
			If TypeOf(Data) <> Type("ObjectDeletion") AND ExchangePlans.IsChangeRecorded(MessageReader.Sender, Data) Then
				If RequiredRestorationDivision Then
					CommonUse.SetSessionSeparation(False);
				EndIf;
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = MessageReader.Sender;
			Data.DataExchange.Load = True;
			Data.Write();
			
			If RequiredRestorationDivision Then
				CommonUse.SetSessionSeparation(False);
			EndIf;
			
		EndDo;
		
		If ExchangeMessageAcceptedInPart Then
			// If the data exchange message included messages which
			// could not be accepted, - the sender has to keep on
			// sending them during generation of further exchange messages.
			MessageReader.CancelRead();
		Else
			MessageReader.EndRead();
		EndIf;
		
		DataExchangeServer.WhenRestoringBackupCopies(BackupCopiesParameters);
		
		XMLReader.Close();
		
	Except
		MessageReader.CancelRead();
		XMLReader.Close();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	Handler.Procedure = "MessageExchangeInternal.SetThisEndPointCode";
	
EndProcedure

// This code sets the endpoint code if it is not set.
// 
Procedure SetThisEndPointCode() Export
	
	If IsBlankString(ThisNodeCode()) Then
		
		ThisEndPoint = ThisNode().GetObject();
		ThisEndPoint.Code = String(New UUID());
		ThisEndPoint.Write();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Scheduled job handler for sending and receiving system messages.
//
Procedure SendReceiveMessagesByScheduledJob() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	SendAndReceiveMessages(False);
	
EndProcedure

// Executes sending and receiving of system messages.
//
// Parameters:
//  Cancel - Boolean. Cancelation flag. Rises in case of errors when executing the operation.
//
Procedure SendAndReceiveMessages(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SendReceiveMessagesViaWebServiceExecute(Cancel);
	
	SendReceiveMessagesViaStandardCommunicationLines(Cancel);
	
	ProcessSystemMessageQueue();
	
EndProcedure

// Only for internal use.
Procedure ProcessSystemMessageQueue(Filter = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		
		WriteLogEvent(ThisSubsystemEventLogMonitorMessageText(),
				EventLogLevel.Information,,,
				NStr("en='System messages queue data processor was started from
		|the session with established values of separators. Data processing will be made
		|only for messages saved in a divided directory, in
		|items which separator values match separator values of the session.';ru='Обработка очереди сообщений системы запущена
		|из сеанса с установленными значениями разделителей. Обработка будет производиться
		|только для сообщений, сохраненных в разделенном справочнике,
		|в элементах со значениями разделителей, совпадающих со значениями разделителей сеанса.'")
		);
		
		ProcessMessageInUndividedData = False;
		
	Else
		
		ProcessMessageInUndividedData = True;
		
	EndIf;
	
	ModuleSaaSOperations = Undefined;
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
	EndIf;
	
	MessageHandlers = MessageHandlers();
	
	QueryText = "";
	CatalogsMessages = MessageExchangeReUse.GetMessagesCatalogs();
	For Each CatalogMessages IN CatalogsMessages Do
		
		CatalogFullName = CatalogMessages.EmptyRef().Metadata().FullName();
		IsUndividedCatalog = Not CommonUseReUse.IsSeparatedConfiguration() OR
			Not CommonUse.IsSeparatedMetadataObject(CatalogFullName, CommonUseReUse.SupportDataSplitter());
		
		If IsUndividedCatalog AND Not ProcessMessageInUndividedData Then
			Continue;
		EndIf;
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		Subquery =  StringFunctionsClientServer.SubstituteParametersInString(
			"SELECT
			|	MessagesTable.DataAreaAuxiliaryData AS DataArea,
			|	MessagesTable.Ref AS Ref,
			|	MessagesTable.Code AS Code,
			|	MessagesTable.Sender.Locked AS EndPointLocked
			|FROM
			|	%1 AS MessagesTable
			|WHERE
			|	MessagesTable.Recipient = &Recipient
			|	AND (NOT MessagesTable.Locked)
			|	[Filter]"
			, CatalogFullName);
		
		If IsUndividedCatalog Then
			Subquery = StrReplace(Subquery, "MessagesTable.DataAreaAuxiliaryData AS DataArea", "-1 AS DataArea");
		EndIf;
		
		QueryText = QueryText + Subquery;
		
	EndDo;
	
	FilterRow = ?(Filter = Undefined, "", "And MessagesTable.Ref IN(&Filter)");
	
	QueryText = StrReplace(QueryText, "[Filter]", FilterRow);
	
	QueryText = "SELECT TOP 100
	|	NestedSelect.DataArea,
	|	NestedSelect.Ref,
	|	NestedSelect.Code,
	|	NestedSelect.EndPointLocked
	|FROM
	|	(" +  QueryText + ") AS NestedSelect
	|
	| ORDER BY
	| Code";
	
	Query = New Query;
	Query.SetParameter("Recipient", ThisNode());
	Query.SetParameter("Filter", Filter);
	Query.Text = QueryText;
	
	QueryResult = CommonUse.ExecuteQueryBeyondTransaction(Query);
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		Try
			LockDataForEdit(Selection.Ref);
		Except
			Continue; // turn further
		EndTry;
		
		// Checks whether the data area is locked on.
		If ModuleSaaSOperations <> Undefined
				AND Selection.DataArea <> -1
				AND ModuleSaaSOperations.DataAreaBlocked(Selection.DataArea) Then
			
			// The area is locked, move to the next record.
			Continue;
		EndIf;
		
		Try
			
			BeginTransaction();
			Try
				MessageObject = Selection.Ref.GetObject();
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		
			MessageTitle = New Structure("MessageChannel, Sender", MessageObject.Description, MessageObject.Sender);
			
			FoundStrings = MessageHandlers.FindRows(New Structure("Channel", MessageTitle.MessageChannel));
			
			MessageHandled = True;
			
			// Processing a message
			Try
				
				If Selection.EndPointLocked Then
					MessageObject.Locked = True;
					Raise NStr("en='Attempting to process the message received from the locked endpoint.';ru='Попытка обработки сообщения, полученного от заблокированной конечной точки.'");
				EndIf;
				
				If FoundStrings.Count() = 0 Then
					MessageObject.Locked = True;
					Raise NStr("en='Message handler is not set.';ru='Не назначен обработчик для сообщения.'");
				EndIf;
				
				For Each TableRow IN FoundStrings Do
					
					TableRow.Handler.ProcessMessage(MessageTitle.MessageChannel, MessageObject.Body.Get(), MessageTitle.Sender);
					
					If TransactionActive() Then
						While TransactionActive() Do
							RollbackTransaction();
						EndDo;
						MessageObject.Locked = True;
						Raise NStr("en='The transaction was not recorded in the message handler.';ru='В обработчике сообщения не была зафиксирована транзакция.'");
					EndIf;
					
				EndDo;
			Except
				
				While TransactionActive() Do
					RollbackTransaction();
				EndDo;
				
				MessageHandled = False;
				
				DetailErrorDescription = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(ThisSubsystemEventLogMonitorMessageText(),
						EventLogLevel.Error,,,
						StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='An error occurred when processing message %1: %2';ru='Ошибка обработки сообщения %1: %2'"),
							MessageTitle.MessageChannel, DetailErrorDescription));
			EndTry;
			
			If MessageHandled Then
				
				// We delete the message
				If ValueIsFilled(MessageObject.Sender)
					AND MessageObject.Sender <> ThisNode() Then
					
					MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
					MessageObject.DataExchange.Recipients.AutoFill = False;
					
				EndIf;
				
				// Existing references to the catalog shall prevent from or slow down deletion of catalog items.
				MessageObject.DataExchange.Load = True;
				CommonUse.DeleteAuxiliaryData(MessageObject);
				
			Else
				
				MessageObject.ProcessMessageRetryCount = MessageObject.ProcessMessageRetryCount + 1;
				MessageObject.DetailErrorDescription = DetailErrorDescription;
				
				If MessageObject.ProcessMessageRetryCount >= 3 Then
					MessageObject.Locked = True;
				EndIf;
				
				CommonUse.AuxilaryDataWrite(MessageObject);
				
			EndIf;
			
			If ProcessMessageInUndividedData AND CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
				
				ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='After data processor of %1 channel message session separation was not disabled.';ru='После обработки сообщения канала %1 не было выключено разделение сеанса!'"),
					MessageTitle.MessageChannel);
				
				WriteLogEvent(
					ThisSubsystemEventLogMonitorMessageText(),
					EventLogLevel.Error,
					,
					,
					ErrorMessageText);
				
				CommonUse.SetSessionSeparation(False);
				
			EndIf;
			
		Except
			WriteLogEvent(ThisSubsystemEventLogMonitorMessageText(),
					EventLogLevel.Error,,,
					DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		UnlockDataForEdit(Selection.Ref);
		
	EndDo;
	
EndProcedure

// Only for internal use.
Procedure SetLeadingEndPointAtSender(Cancel, SenderConnectionSettings, EndPoint) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(LeadingEndPointSettingEventLogMonitorMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndPointObject = EndPoint.GetObject();
		EndPointObject.Leading = False;
		EndPointObject.Write();
		
		// Update the connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPoint);
		RecordStructure.Insert("ExchangeMessageTransportKindByDefault", Enums.ExchangeMessagesTransportKinds.WS);
		
		RecordStructure.Insert("WSURLWebService",   SenderConnectionSettings.WSURLWebService);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// add record to the information register
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		// We set the leading endpoint on the side of the recipient.
		WSProxy.SetLeadingEndPoint(EndPointObject.Code, ThisNodeCode());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(LeadingEndPointSettingEventLogMonitorMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure SetLeadingEndPointAtRecipient(ThisEndPointCode, LeadingEndPointCode) Export
	
	SetPrivilegedMode(True);
	
	If ExchangePlans.MessageExchange.FindByCode(ThisEndPointCode) <> ThisNode() Then
		ErrorMessageString = NStr("en='Incorrect parameters of connection to the end point were set. Connection parameters indicate another end point.';ru='Заданы неверные параметры подключения к конечной точке. Параметры подключения указывают на другую конечную точку.'");
		MessageStringForErrorLogRegistration = NStr("en='Incorrect parameters of connection to the end point were set.
		|Connection parameters indicate another end point.';ru='Заданы неверные параметры подключения к конечной точке.
		|Параметры подключения указывают на другую конечную точку.'", CommonUseClientServer.MainLanguageCode());
		WriteLogEvent(LeadingEndPointSettingEventLogMonitorMessageText(),
				EventLogLevel.Error,,, MessageStringForErrorLogRegistration);
		Raise ErrorMessageString;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndPointNode = ExchangePlans.MessageExchange.FindByCode(LeadingEndPointCode);
		
		If EndPointNode.IsEmpty() Then
			
			Raise NStr("en='Endpoint is not found in the correspondent base.';ru='Конечная точка в базе-корреспонденте не обнаружена.'");
			
		EndIf;
		EndPointNodeObject = EndPointNode.GetObject();
		EndPointNodeObject.Leading = True;
		EndPointNodeObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(LeadingEndPointSettingEventLogMonitorMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure ConnectEndPointAtRecipient(Cancel, Code, Description, RecipientConnectionSettings) Export
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// We create/ update an exchange plan node, which corresponds to the endpoint to be connected.
		EndPointNode = ExchangePlans.MessageExchange.FindByCode(Code);
		If EndPointNode.IsEmpty() Then
			EndPointNodeObject = ExchangePlans.MessageExchange.CreateNode();
			EndPointNodeObject.Code = Code;
		Else
			EndPointNodeObject = EndPointNode.GetObject();
			EndPointNodeObject.ReceivedNo = 0;
		EndIf;
		EndPointNodeObject.Description = Description;
		EndPointNodeObject.Leading = True;
		EndPointNodeObject.Write();
		
		// Update the connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPointNodeObject.Ref);
		RecordStructure.Insert("ExchangeMessageTransportKindByDefault", Enums.ExchangeMessagesTransportKinds.WS);
		
		RecordStructure.Insert("WSURLWebService",   RecipientConnectionSettings.WSURLWebService);
		RecordStructure.Insert("WSUserName", RecipientConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          RecipientConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// add record to the information register
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		// We set the sign of using a regular job.
		ScheduledJobsServer.SetUseScheduledJob(
			Metadata.ScheduledJobs.SendReceiveSystemMessages, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure UpdateEndPointConnectionSettings(Cancel, EndPoint, SenderConnectionSettings, RecipientConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	CorrespondentVersions = CorrespondentVersions(SenderConnectionSettings);
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = GetWSProxy_2_0_1_6(SenderConnectionSettings, ErrorMessageString);
	Else
		WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.CheckConnectionAtRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.CheckConnectionAtRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
	Except
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	BeginTransaction();
	Try
		
		// Update the connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPoint);
		RecordStructure.Insert("ExchangeMessageTransportKindByDefault", Enums.ExchangeMessagesTransportKinds.WS);
		
		RecordStructure.Insert("WSURLWebService",   SenderConnectionSettings.WSURLWebService);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// add record to the information register
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.UpdateConnectionSettings(ThisNodeCode(), XDTOSerializer.WriteXDTO(RecipientConnectionSettings));
		Else
			WSProxy.UpdateConnectionSettings(ThisNodeCode(), ValueToStringInternal(RecipientConnectionSettings));
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// Only for internal use.
Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

// Only for internal use.
Function ThisNodeCode() Export
	
	Return CommonUse.ObjectAttributeValue(ThisNode(), "Code");
	
EndFunction

// Only for internal use.
Function ThisNodeDescription() Export
	
	Return CommonUse.ObjectAttributeValue(ThisNode(), "Description");
	
EndFunction

// Only for internal use.
Function ThisNode() Export
	
	Return ExchangePlans.MessageExchange.ThisNode();
	
EndFunction

// Only for internal use.
Function AllRecipients() Export
	
	QueryText =
	"SELECT
	|	MessageExchange.Ref AS Recipient
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|WHERE
	|	MessageExchange.Ref <> &ThisNode";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction

// Only for internal use.
Procedure SerializeDataToStream(DataSelection, Stream) Export
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("Root");
	
	For Each Ref IN DataSelection Do
		
		Data = Ref.GetObject();
		Data.Code = 0;
		
		// {Event handler: AtMessageSending} Begin.
		MessageBody = Data.Body.Get();
		
		MessageBody = MessageExchangeInternal.ConvertInstantMessageData(MessageBody);
		
		OnMessageSendingSSL(Data.Description, MessageBody, Data);
		
		OnMessageSending(Data.Description, MessageBody);
		
		Data.Body = New ValueStorage(MessageBody);
		// {Event handler: AtMessageSending} End.
		
		WriteXML(XMLWriter, Data);
		
	EndDo;
	XMLWriter.WriteEndElement();
	
	Stream = XMLWriter.Close();
	
EndProcedure

// Only for internal use.
Procedure SerializeDataFromStream(Sender, Stream, ImportedObjects, DataReadInPart) Export
	
	ModuleSaaSOperations = Undefined;
	If CommonUseReUse.IsSeparatedConfiguration() Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
	EndIf;
	
	DataCanBeReadInPart = GetPartialMessagesSupportsCorrespondentExchange(Sender);
	
	ImportedObjects = New Array;
	
	BeginTransaction();
	Try
		
		XMLReader = New XMLReader;
		XMLReader.SetString(Stream);
		XMLReader.Read(); // "Root" node
		XMLReader.Read(); // object node
		
		While CanReadXML(XMLReader) Do
			
			Data = ReadXML(XMLReader);
			
			If TypeOf(Data) = Type("ObjectDeletion") Then
				
				Raise NStr("en='Passing of object ObjectDeletion via instant message tool is not supported.';ru='Передача объекта УдалениеОбъекта через механизм быстрых сообщений не поддерживается!'");
				
			Else
				
				If Not Data.IsNew() Then
					Continue; // Import only new messages.
				EndIf;
				
				// {Handler: AtMessageReception} Begin
				MessageBody = Data.Body.Get();
				
				MessageBody = MessageExchangeInternal.ConvertInstantMessageData(MessageBody);
				
				OnMessageGettingSSL(Data.Description, MessageBody, Data);
				
				OnMessageReceiving(Data.Description, MessageBody);
				
				Data.Body = New ValueStorage(MessageBody);
				// {Handler: AtMessageReception} End
				
				If Not Data.IsNew() Then
					Continue; // Import only new messages.
				EndIf;
				
				Data.SetNewCode();
				Data.Sender = Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
				
			EndIf;
			
			RequiredRestorationDivision = False;
			If CommonUseReUse.IsSeparatedConfiguration() AND CommonUse.IsSeparatedMetadataObject(Data.Metadata(), CommonUseReUse.SupportDataSplitter()) Then
				
				DataArea = Data[CommonUseReUse.SupportDataSplitter()];
				
				If ModuleSaaSOperations.DataAreaBlocked(DataArea) Then
					// A message for a locked field can not be received.
					If DataCanBeReadInPart Then
						DataReadInPart = True;
						Continue;
					Else
						Raise StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='Cannot perform an email exchange due to: data area %1 is locked.';ru='Не удалось выполнить обмен сообщениями по причине: область данных %1 заблокирована!'"),
							DataArea);
					EndIf;
				EndIf;
				
				RequiredRestorationDivision = True;
				CommonUse.SetSessionSeparation(True, DataArea);
				
			EndIf;
			
			// IN case of a conflict between changes, priority is given to the current infobase.
			If ExchangePlans.IsChangeRecorded(Sender, Data) Then
				If RequiredRestorationDivision Then
					CommonUse.SetSessionSeparation(False);
				EndIf;
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = Sender;
			Data.DataExchange.Load = True;
			Data.Write();
			
			If RequiredRestorationDivision Then
				CommonUse.SetSessionSeparation(False);
			EndIf;
			
			ImportedObjects.Add(Data.Ref);
			
		EndDo;
		
		XMLReader.Close();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Only for internal use.
Function GetWSProxy(SettingsStructure, ErrorMessageString = "", Timeout = 60) Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/MessageExchange");
	SettingsStructure.Insert("WSServiceName",                 "MessageExchange");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Only for internal use.
Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "", Timeout = 60) Export
	
	SettingsStructure.Insert("NamespaceWebServiceURL", "http://www.1c.ru/SSL/MessageExchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",                 "MessageExchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Checks whether the correspondent of partial data
//  exchange messages reception is supported by the infobase at message exchange (if it does not support - then partial
//  reception of data exchange messages on the side of this infobase must not be used).
//
// Parameters:
//  Sender - ExchangePlanRef.MessagesExchange,
//
// Return value: Boolean.
//
Function GetPartialMessagesSupportsCorrespondentExchange(Val Correspondent)
	
	CorrespondentVersions = CorrespondentVersions(Correspondent);
	Return (CorrespondentVersions.Find("2.1.1.8") <> Undefined);
	
EndFunction

// Returns the array of version numbers supported by the correspondent interface for the MessagesExchange subsystem.
// 
// Parameters:
// Correspondent - Structure, ExchangePlanRef. Exchange plan node that
//                 corresponds to the correspondent infobase.
//
// Returns:
// Array of the version numbers supported by the correspondent interface.
//
Function CorrespondentVersions(Val Correspondent) Export
	
	If TypeOf(Correspondent) = Type("Structure") Then
		SettingsStructure = Correspondent;
	Else
		SettingsStructure = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(Correspondent);
	EndIf;
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURLWebService);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "MessageExchange");
EndFunction

// Only for internal use.
Function EndPointConnectionEventLogMonitorMessageText() Export
	
	Return NStr("en='Message exchange.Endpoint connection';ru='Обмен сообщениями.Подключение конечной точки'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Only for internal use.
Function LeadingEndPointSettingEventLogMonitorMessageText() Export
	
	Return NStr("en='Message exchange.Setting leading endpoint';ru='Обмен сообщениями.Установка ведущей конечной точки'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Only for internal use.
Function ThisSubsystemEventLogMonitorMessageText() Export
	
	Return NStr("en='Message exchange';ru='Обмен сообщениями'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Only for internal use.
Function ThisNodeDefaultDescription() Export
	
	Return ?(CommonUseReUse.DataSeparationEnabled(), Metadata.Synonym, DataExchangeReUse.ThisInfobaseName());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// Only for internal use.
Procedure SendReceiveMessagesViaWebServiceExecute(Cancel)
	
	QueryText =
	"SELECT DISTINCT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON MessageExchange.Ref = ExchangeTransportSettings.Node
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND (NOT MessageExchange.Leading)
	|	AND (NOT MessageExchange.DeletionMark)
	|	AND (NOT MessageExchange.Locked)
	|	AND ExchangeTransportSettings.ExchangeMessageTransportKindByDefault = VALUE(Enum.ExchangeMessagesTransportKinds.WS)";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	NodesArray = QueryResult.Unload().UnloadColumn("Ref");
	
	// Data import from all endpoints.
	For Each Recipient IN NodesArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, True, False, Enums.ExchangeMessagesTransportKinds.WS);
		
		Cancel = Cancel OR Cancel1;
		
	EndDo;
	
	// Data export for all endpoints.
	For Each Recipient IN NodesArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, False, True, Enums.ExchangeMessagesTransportKinds.WS);
		
		Cancel = Cancel OR Cancel1;
		
	EndDo;
	
EndProcedure

// Only for internal use.
Procedure SendReceiveMessagesViaStandardCommunicationLines(Cancel)
	
	QueryText =
	"SELECT DISTINCT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON MessageExchange.Ref = ExchangeTransportSettings.Node
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND (NOT MessageExchange.DeletionMark)
	|	AND (NOT MessageExchange.Locked)
	|	AND ExchangeTransportSettings.ExchangeMessageTransportKindByDefault <> VALUE(Enum.ExchangeMessagesTransportKinds.WS)";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	NodesArray = QueryResult.Unload().UnloadColumn("Ref");
	
	// Data import from all endpoints.
	For Each Recipient IN NodesArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, True, False);
		
		Cancel = Cancel OR Cancel1;
		
	EndDo;
	
	// Data export for all endpoints.
	For Each Recipient IN NodesArray Do
		
		Cancel1 = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Cancel1, Recipient, False, True);
		
		Cancel = Cancel OR Cancel1;
		
	EndDo;
	
EndProcedure

// Only for internal use.
Procedure ConnectEndPointAtSender(Cancel,
														SenderConnectionSettings,
														RecipientConnectionSettings,
														EndPoint,
														RecipientEndPointDescription,
														SenderEndPointDescription
	) Export
	
	DataExchangeServer.CheckUseDataExchange();
	
	ErrorMessageString = "";
	
	SetPrivilegedMode(True);
	
	CorrespondentVersions = CorrespondentVersions(SenderConnectionSettings);
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = GetWSProxy_2_0_1_6(SenderConnectionSettings, ErrorMessageString);
	Else
		WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.CheckConnectionAtRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.CheckConnectionAtRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
		
	Except
		Cancel = True;
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	If CorrespondentVersion_2_0_1_6 Then
		EndPointParameters = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseParameters(RecipientEndPointDescription));
	Else
		EndPointParameters = ValueFromStringInternal(WSProxy.GetInfobaseParameters(RecipientEndPointDescription));
	EndIf;
	
	EndPointNode = ExchangePlans.MessageExchange.FindByCode(EndPointParameters.Code);
	
	If Not EndPointNode.IsEmpty() Then
		Cancel = True;
		ErrorMessageString = NStr("en='Endpoint is already connected to the infobase; point name: %1';ru='Конечная точка уже подключена к информационной базе; наименование точки: %1'", CommonUseClientServer.MainLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, CommonUse.ObjectAttributeValue(EndPointNode, "Description"));
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		// We set description of this point when necessary.
		If IsBlankString(ThisNodeDescription()) Then
			
			ThisNodeObject = ThisNode().GetObject();
			ThisNodeObject.Description = ?(IsBlankString(SenderEndPointDescription), ThisNodeDefaultDescription(), SenderEndPointDescription);
			ThisNodeObject.Write();
			
		EndIf;
		
		// Create a node of the exchange plan, which corresponds to the endpoint to be connected.
		EndPointNodeObject = ExchangePlans.MessageExchange.CreateNode();
		EndPointNodeObject.Code = EndPointParameters.Code;
		EndPointNodeObject.Description = EndPointParameters.Description;
		EndPointNodeObject.Write();
		
		// Update the connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPointNodeObject.Ref);
		RecordStructure.Insert("ExchangeMessageTransportKindByDefault", Enums.ExchangeMessagesTransportKinds.WS);
		
		RecordStructure.Insert("WSURLWebService",   SenderConnectionSettings.WSURLWebService);
		RecordStructure.Insert("WSUserName", SenderConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// add record to the information register
		InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
		
		ThisPointParameters = CommonUse.ObjectAttributesValues(ThisNode(), "Code, description");
		
		// We connect to the endpoint on the side of the recipient.
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, XDTOSerializer.WriteXDTO(RecipientConnectionSettings));
		Else
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, ValueToStringInternal(RecipientConnectionSettings));
		EndIf;
		
		// We set the sign of using a regular job.
		ScheduledJobsServer.SetUseScheduledJob(
			Metadata.ScheduledJobs.SendReceiveSystemMessages, True);
		
		EndPoint = EndPointNodeObject.Ref;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		EndPoint = Undefined;
		WriteLogEvent(EndPointConnectionEventLogMonitorMessageText(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// Only for internal use.
Function MessageHandlers()
	
	Result = NewMessageHandlerTable();
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.MessageExchange\OnDefenitionMessagesFeedHandlers");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDefenitionMessagesFeedHandlers(Result);
	EndDo;
	
	MessageExchangeOverridable.GetMessageChannelHandlers(Result);
	
	Return Result;
	
EndFunction

// Only for internal use.
Function NewMessageHandlerTable()
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("Channel");
	Handlers.Columns.Add("Handler");
	
	Return Handlers;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event handlers of sending and receiving messages.

Procedure OnMessageSendingSSL(Val MessageChannel, MessageBody, MessageObject)
	
	MessageExchange.OnMessageSending(MessageChannel, MessageBody, MessageObject);
	
EndProcedure

Procedure OnMessageSending(Val MessageChannel, MessageBody)
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.MessageExchange\OnMessageSending");
	For Each Handler IN EventHandlers Do
		Handler.Module.OnMessageSending(MessageChannel, MessageBody);
	EndDo;
	
	MessageExchangeOverridable.OnMessageSending(MessageChannel, MessageBody);
	
EndProcedure

Procedure OnMessageGettingSSL(Val MessageChannel, MessageBody, MessageObject)
	
	MessageExchange.OnMessageReceiving(MessageChannel, MessageBody, MessageObject);
	
EndProcedure

Procedure OnMessageReceiving(Val MessageChannel, MessageBody)
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.MessageExchange\OnMessageReceiving");
	For Each Handler IN EventHandlers Do
		Handler.Module.OnMessageReceiving(MessageChannel, MessageBody);
	EndDo;
	
	MessageExchangeOverridable.OnMessageReceiving(MessageChannel, MessageBody);
	
EndProcedure

#EndRegion


Function ConvertExchangePlanName(ExchangePlanName) Export

	Return StrReplace(ExchangePlanName, "ОбменСообщениями", "MessageExchange");

EndFunction

Function ConvertBackExchangePlanMessageData(MessageData) Export

	Return StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(   
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(MessageData, 
		"<Body>", "<ТелоСообщения>"), 
		"<Sender>", "<Отправитель>"), 
		"<Recipient>", "<Получатель>"), 
		"<Locked>", "<Заблокировано>"), 
		"<ProcessMessageRetryCount>", "<КоличествоПопытокОбработкиСообщения>"), 
		"<DetailErrorDescription>", "<ПодробноеПредставлениеОшибки>"), 
		"<IsInstantMessage>", "<ЭтоБыстроеСообщение>"), 
		"</Body>", "</ТелоСообщения>"), 
		"</Sender>", "</Отправитель>"), 
		"</Recipient>", "</Получатель>"), 
		"</Locked>", "</Заблокировано>"), 
		"</ProcessMessageRetryCount>", "</КоличествоПопытокОбработкиСообщения>"), 
		"</DetailErrorDescription>", "</ПодробноеПредставлениеОшибки>"), 
		"</IsInstantMessage>", "</ЭтоБыстроеСообщение>"), 
		"<DetailErrorDescription/>", "<ПодробноеПредставлениеОшибки/>"), 
		"CatalogObject.SystemMessages>", "CatalogObject.СообщенияСистемы>"), 
		">MessageExchange<", ">ОбменСообщениями<"), 
		"""CatalogRef.SystemMessages""", """CatalogRef.СообщенияСистемы"""),
		"DataExchange\ManagementApplication\DataChangeFlag", "ОбменДанными\УправляющееПриложение\ПризнакИзмененияДанных"),
		"NodeCode", "КодУзла");

EndFunction

Function ConvertInstantMessageData(MessageData) Export

	Return StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(   
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(MessageData, 
		"""ОбластьДанных""", "DataArea"), 
		"""Префикс""", """Prefix"""), 
		"""URLСервиса""", """ServiceURL"""), 
		"""ИмяСлужебногоПользователяСервиса""", """AuxiliaryServiceUserName"""), 
		"""ПарольСлужебногоПользователяСервиса""", """AuxiliaryServiceUserPassword"""), 
		"""РежимИспользованияИнформационнойБазы""", """InfobaseUsageMode"""), 
		"""КопироватьОбластиДанныхИзЭталонной""", """CopyDataAreasFromPrototype"""), 
		"""НезависимоеИспользованиеДополнительныхОтчетовИОбработокВМоделиСервиса""", """IndependentUseOfAdditionalReportsAndDataProcessorsInSaaSMode"""), 
		"""ИспользованиеКаталогаДополнительныхОтчетовИОбработокВМоделиСервиса""", """UseAdditionalReportsAndDataProcessorsFolderInSaaSMode"""), 
		"""РазрешитьВыполнениеДополнительныхОтчетовИОбработокРегламентнымиЗаданиямиВМоделиСервиса""", """AllowUseAdditionalReportsAndDataProcessorsByScheduledJobsInSaaSMode"""), 
		"""МинимальныйИнтервалРегламентныхЗаданийДополнительныхОтчетовИОбработокВМоделиСервиса""", """MinimumAdditionalReportsAndDataProcessorsScheduledJobIntervalInSaaSMode"""), 
		"""АдресУправленияКонференцией""", """ForumManagementURL"""), 
		"""ИмяПользователяКонференцииИнформационногоЦентра""", """InformationCenterForumUserName"""), 
		"""ПарольПользователяКонференцииИнформационногоЦентра""", """InformationCenterForumPassword"""), 
		"EnumRef.РежимыИспользованияИнформационнойБазы""", "EnumRef.InfobaseUsageModes"""), 
		">ru<", ">en<"), 
		">Рабочий<", ">Production<"), 
		">Демонстрационный<", ">Demo<"),
		">НомерИнформационнойБазы<", ">InfobaseNumber<"),
		">КодУзлаИнформационнойБазы<", ">InfobaseNodeCode<"),
		">КодЭтогоУзла<",">ThisNodeCode<"),
		">ВыполняемоеДействие<", ">CurrentAction<"),
		">ПорядковыйНомерВыполнения<", ">ExecutionOrderNumber<"),
		">ЗначениеРазделителяПервойИнформационнойБазы<", ">FirstInfobaseSeparatorValue<"),
		">ЗначениеРазделителяВторойИнформационнойБазы<", ">SecondInfobaseSeparatorValue<"),
		">ДатаАктуальностиБлокировки<", ">DataLockUpdateDate<"),
		">Приложение1Код<",">Application1Code<"),
		">Приложение2Код<", ">Application2Code<"),
		">ИмяПланаОбмена<", ">ExchangePlanName<"),
		">Режим<",">Mode<"),
		">ВыгрузкаДанных<", ">DataExport<"),
		">ЗагрузкаДанных<", ">DataImport<"),
		">Ручной<", ">Manual<"),
		">Автоматический<",">Automatic<");

EndFunction

Function ConvertExchangePlanMessageData(MessageData) Export

	Return StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		StrReplace(
		MessageData, 
		"ОбменДанными\ПрикладноеПриложение\УстановитьПрефиксОбластиДанных", "DataExchange\Application\SetDataAreaPrefix"), 
		"ОбменДанными\ПрикладноеПриложение\УдалениеОбмена", "DataExchange\Application\ExchangeDeletion"), 
		"ОбменДанными\ПрикладноеПриложение\СозданиеОбмена", "DataExchange\Application\ExchangeCreation"), 
		"ОбменСообщениями", "MessageExchange"), 
		"СообщенияСистемы", "SystemMessages"), 
		"ТелоСообщения", "Body"), 
		"Отправитель", "Sender"), 
		"Получатель", "Recipient"), 
		"Заблокировано", "Locked"), 
		"КоличествоПопытокОбработкиСообщения", "ProcessMessageRetryCount"), 
		"ПодробноеПредставлениеОшибки", "DetailErrorDescription"), 
		"ЭтоБыстроеСообщение", "IsInstantMessage"),
		"ПоставляемыеДанные\Обновление", "SuppliedData\Update");

EndFunction
	
Function ConvertRecipientConnectionSettings(Val SettingsStructure) Export

	If SettingsStructure.Property("WSИмяПользователя") Then
		SettingsStructure.Insert("WSUserName", SettingsStructure.WSИмяПользователя);
	EndIf;
	If SettingsStructure.Property("WSПароль") Then
		SettingsStructure.Insert("WSPassword", SettingsStructure.WSПароль);
	EndIf;
	If SettingsStructure.Property("WSURLВебСервиса") Then
		SettingsStructure.Insert("WSURL", SettingsStructure.WSURLВебСервиса);
		SettingsStructure.Insert("WSURLWebService", SettingsStructure.WSURLВебСервиса);
	EndIf;
	
	Return SettingsStructure;

EndFunction

Function ConvertTransportSettingsStructure(Val SettingsStructure) Export

	If SettingsStructure.Property("FILEКаталогОбменаИнформацией") Then
		SettingsStructure.Insert("FILEDataExchangeDirectory", SettingsStructure.FILEКаталогОбменаИнформацией);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПароль") Then
		SettingsStructure.Insert("FTPConnectionPassword", SettingsStructure.FTPСоединениеПароль);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПассивноеСоединение") Then
		SettingsStructure.Insert("FTPConnectionPassiveConnection", SettingsStructure.FTPСоединениеПассивноеСоединение);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПользователь") Then
		SettingsStructure.Insert("FTPConnectionUser", SettingsStructure.FTPСоединениеПользователь);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПорт") Then
		SettingsStructure.Insert("FTPConnectionPort", SettingsStructure.FTPСоединениеПорт);	
	EndIf;
	
	If SettingsStructure.Property("FTPСоединениеПуть") Then
		SettingsStructure.Insert("FTPConnectionPath", SettingsStructure.FTPСоединениеПуть);	
	EndIf;
	
	Return SettingsStructure;

EndFunction // ()

Function ConvertSynchronizationSettingsTable(Val SynchronizationSettingsTable) Export

	If SynchronizationSettingsTable.Columns.Find("ПланОбмена") <> Undefined Then
		SynchronizationSettingsTable.Columns.ПланОбмена.Name = "ExchangePlan";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("ОбластьДанных") <> Undefined Then
		SynchronizationSettingsTable.Columns.ОбластьДанных.Name = "DataArea";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("НаименованиеПриложения") <> Undefined Then
		SynchronizationSettingsTable.Columns.НаименованиеПриложения.Name = "ApplicationDescription";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("СинхронизацияНастроена") <> Undefined Then
		SynchronizationSettingsTable.Columns.СинхронизацияНастроена.Name = "SynchronizationConfigured";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("НастройкаСинхронизацииВМенеджереСервиса") <> Undefined Then
		SynchronizationSettingsTable.Columns.НастройкаСинхронизацииВМенеджереСервиса.Name = "SynchronizationSetupInServiceManager";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("КонечнаяТочкаКорреспондента") <> Undefined Then
		SynchronizationSettingsTable.Columns.КонечнаяТочкаКорреспондента.Name = "CorrespondentEndpoint";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("Префикс") <> Undefined Then
		SynchronizationSettingsTable.Columns.Префикс.Name = "Prefix";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("ПрефиксКорреспондента") <> Undefined Then
		SynchronizationSettingsTable.Columns.ПрефиксКорреспондента.Name = "CorrespondentPrefix";	
	EndIf;
	
	If SynchronizationSettingsTable.Columns.Find("ВерсияКорреспондента") <> Undefined Then
		SynchronizationSettingsTable.Columns.ВерсияКорреспондента.Name = "CorrespondentVersion";	
	EndIf;
	
	Return SynchronizationSettingsTable;

EndFunction // ConvertSynchronizationSettingsTable()

Function ConvertBackDataExchangeScenarioValueTable(Val DataExchangeScenarioValueTable) Export
	
	For Each Column In DataExchangeScenarioValueTable.Columns Do
		
		If Column.Name = "InfobaseNumber" Then
			Column.Name = "НомерИнформационнойБазы";
		ElsIf Column.Name = "InfobaseNodeCode" Then
			Column.Name = "КодУзлаИнформационнойБазы";
		ElsIf Column.Name = "ThisNodeCode" Then
			Column.Name = "КодЭтогоУзла";
		ElsIf Column.Name = "CurrentAction" Then
			Column.Name = "ВыполняемоеДействие";
		ElsIf Column.Name = "ExecutionOrderNumber" Then
			Column.Name = "ПорядковыйНомерВыполнения";
		ElsIf Column.Name = "FirstInfobaseSeparatorValue" Then
			Column.Name = "ЗначениеРазделителяПервойИнформационнойБазы";
		ElsIf Column.Name = "SecondInfobaseSeparatorValue" Then
			Column.Name = "ЗначениеРазделителяВторойИнформационнойБазы";
		ElsIf Column.Name = "DataLockUpdateDate" Then
			Column.Name = "ДатаАктуальностиБлокировки";
		ElsIf Column.Name = "Application1Code" Then
			Column.Name = "Приложение1Код";
		ElsIf Column.Name = "Application2Code" Then
			Column.Name = "Приложение2Код";
		ElsIf Column.Name = "ExchangePlanName" Then
			Column.Name = "ИмяПланаОбмена";
		ElsIf Column.Name = "Mode" Then
			Column.Name = "Режим";
		EndIf;
		
	EndDo;
	
	For Each TableRow In DataExchangeScenarioValueTable Do
		
		For Each Column In DataExchangeScenarioValueTable.Columns Do
			
			If TableRow[Column.Name] = "DataExport" Then				
				TableRow[Column.Name] = "ВыгрузкаДанных";
			ElsIf TableRow[Column.Name] = "DataImport" Then
				TableRow[Column.Name] = "ЗагрузкаДанных";
			ElsIf TableRow[Column.Name] = "Manual" Then
				TableRow[Column.Name] = "Ручной";
			ElsIf TableRow[Column.Name] = "Automatic" Then
				TableRow[Column.Name] = "Автоматический";
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return DataExchangeScenarioValueTable;	

EndFunction // ConvertBackE()

Function ConvertMessageBodyStructure(Val MessageBodyStructure) Export

	If TypeOf(MessageBodyStructure) = Type("Structure") Then
		
		If MessageBodyStructure.Property("ОбластьДанных") Then
			MessageBodyStructure.Insert("DataArea", MessageBodyStructure.ОбластьДанных);	
		EndIf;
		
		If MessageBodyStructure.Property("Префикс") Then
			MessageBodyStructure.Insert("Prefix", MessageBodyStructure.Префикс);	
		EndIf;
		
		If MessageBodyStructure.Property("ИмяПланаОбмена") Then
			MessageBodyStructure.Insert("ExchangePlanName", MessageBodyStructure.ИмяПланаОбмена);
		EndIf;
		
		If MessageBodyStructure.Property("КодУзла") Then
			MessageBodyStructure.Insert("NodeCode", MessageBodyStructure.КодУзла);
		EndIf;
		
	EndIf;
	
	Return MessageBodyStructure;

EndFunction // ConvertMessageBodyStructure()

Function ConvertMessageChannel(Val MessageChannel) Export

	Return StrReplace(MessageChannel, "ПоставляемыеДанные\Обновление", "SuppliedData\Update");	

EndFunction // ConvertMessageSender()

// ConvertMessageBodyString
//
//
// Parameters:
//	MessageBodyString - 
//
// Returns:
//	<>
Function ConvertMessageBodyString(Val MessageBodyString) Export
	
	If TypeOf(MessageBodyString) = Type("String") Then
		Return StrReplace(
			StrReplace(
			StrReplace( 
			StrReplace( 
			StrReplace(
			StrReplace(
			StrReplace(
			StrReplace(
			StrReplace(
			StrReplace(MessageBodyString, "ЭталонОбластиДанных", "DataAreaPrototype"), 
			"ИмяКонфигурации", "ConfigurationName"),
			"ВерсияКонфигурации", "ConfigurationVersion"),
			"Режим", "Mode"),
			"Демонстрационный", "Demo"),
			"Состояние", "State"),
			"Отсутствует", "Missing"),
			"Вариант", "Option"),
			"Стандарт", "Standard"),
			"Готов", "Done");
	Else
		Return MessageBodyString;
	EndIf;
	
EndFunction



 