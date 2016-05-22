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
		
		DataSelectionTable.Sort("Asc order");
		
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
				MessageBody = TableRow.Data.MessageBody.Get();
				
				OnMessageSendingSSL(TableRow.Data.Description, MessageBody, TableRow.Data);
				
				OnMessageSending(TableRow.Data.Description, MessageBody);
				
				TableRow.Data.MessageBody = New ValueStorage(MessageBody);
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
	
	DeleteChangeRecords = Not BackupCopiesParameters.RestoredBackupCopy;
	
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
			
			// Read the next value
			Data = ReadXML(XMLReader);
			
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
				MessageBody = Data.MessageBody.Get();
				
				OnMessageGettingSSL(Data.Description, MessageBody, Data);
				
				OnMessageReceiving(Data.Description, MessageBody);
				
				Data.MessageBody = New ValueStorage(MessageBody);
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
						Raise StringFunctionsClientServer.PlaceParametersIntoString(
							NStr("en = 'The application failed to exchange the messages due to the following reason: the %1 data field is blocked!'"),
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
				NStr("en = 'System messages queue data processor was started from
                      |the session with established values of separators. Data processing will be made
                      |only for messages saved in a divided directory, in
                      |items which separator values match separator values of the session.'")
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
		
		Subquery =  StringFunctionsClientServer.PlaceParametersIntoString(
			"SELECT
			|	MessagesTable.DataAreaAuxiliaryData AS DataArea,
			|	MessagesTable.Ref AS Ref,
			|	MessagesTable.Code AS Code,
			|	MessagesTable.Sender.Blocked AS EndPointLocked
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
	
	FilterRow = ?(Filter = Undefined, "", "And MessagesTable.Ref IN(&Selection)");
	
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
					Raise NStr("en = 'Attempt to process the messages received from the locked end point.'");
				EndIf;
				
				If FoundStrings.Count() = 0 Then
					MessageObject.Locked = True;
					Raise NStr("en = 'Handler is not assigned for the message.'");
				EndIf;
				
				For Each TableRow IN FoundStrings Do
					
					TableRow.Handler.ProcessMessage(MessageTitle.MessageChannel, MessageObject.MessageBody.Get(), MessageTitle.Sender);
					
					If TransactionActive() Then
						While TransactionActive() Do
							RollbackTransaction();
						EndDo;
						MessageObject.Locked = True;
						Raise NStr("en = 'Transaction has not been fixed in the message handler.'");
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
						StringFunctionsClientServer.PlaceParametersIntoString(
							NStr("en = 'Error of processing of message %1: %2'"),
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
				
				ErrorMessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'For processing of the %1 message channel the session separation was not disabled!'"),
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
		ErrorMessageString = NStr("en = 'Incorrect parameters of connection to the end point were set. Connection parameters indicate another end point.'");
		MessageStringForErrorLogRegistration = NStr("en = 'Incorrect parameters of connection to the end point were set.
			|Connection parameters indicate another end point.'", CommonUseClientServer.MainLanguageCode());
		WriteLogEvent(LeadingEndPointSettingEventLogMonitorMessageText(),
				EventLogLevel.Error,,, MessageStringForErrorLogRegistration);
		Raise ErrorMessageString;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndPointNode = ExchangePlans.MessageExchange.FindByCode(LeadingEndPointCode);
		
		If EndPointNode.IsEmpty() Then
			
			Raise NStr("en = 'End point in the correspondent base is not found.'");
			
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
		MessageBody = Data.MessageBody.Get();
		
		OnMessageSendingSSL(Data.Description, MessageBody, Data);
		
		OnMessageSending(Data.Description, MessageBody);
		
		Data.MessageBody = New ValueStorage(MessageBody);
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
				
				Raise NStr("en = 'Transfer of the ObjectDeletion object through the quick messages mechanism is not supported!'");
				
			Else
				
				If Not Data.IsNew() Then
					Continue; // Import only new messages.
				EndIf;
				
				// {Handler: AtMessageReception} Begin
				MessageBody = Data.MessageBody.Get();
				
				OnMessageGettingSSL(Data.Description, MessageBody, Data);
				
				OnMessageReceiving(Data.Description, MessageBody);
				
				Data.MessageBody = New ValueStorage(MessageBody);
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
						Raise StringFunctionsClientServer.PlaceParametersIntoString(
							NStr("en = 'The application failed to exchange the messages due to the following reason: the %1 data field is blocked!'"),
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
	
	Return NStr("en = 'Messages exchange. End point connection'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Only for internal use.
Function LeadingEndPointSettingEventLogMonitorMessageText() Export
	
	Return NStr("en = 'Messages exchange. Leading end point installation'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Only for internal use.
Function ThisSubsystemEventLogMonitorMessageText() Export
	
	Return NStr("en = 'Message exchange'", CommonUseClientServer.MainLanguageCode());
	
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
	|	AND (NOT MessageExchange.Blocked)
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
	|	AND (NOT MessageExchange.Blocked)
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
		ErrorMessageString = NStr("en = 'The endpoint is already connected to the infobase; point description: %1'", CommonUseClientServer.MainLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.PlaceParametersIntoString(ErrorMessageString, CommonUse.ObjectAttributeValue(EndPointNode, "Description"));
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
