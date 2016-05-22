
// The function generates the exchange pack that will be sent to the ExchangeNode node.
//
// Parameters:
//  ExchangeNode	- exchange plan node "MobileApplication" with which the exchange is executed
//
// Returns:
//  generated pack put to the value storage
Function GenerateQueueMessagesExchange(ExchangeNode, ReceivedNo, NeedNodeInitialization = False) Export
	
	If NeedNodeInitialization Then
		ExchangePlans.DeleteChangeRecords(ExchangeNode);
		ExchangeMobileApplicationOverridable.ClearQueueMessagesExchangeWithMobileClient(ExchangeNode);
		ExchangeMobileApplicationOverridable.RecordChangesData(ExchangeNode);
	Else
		ExchangeMobileApplicationOverridable.ClearQueueMessagesExchangeWithMobileClient(ExchangeNode, ReceivedNo);
	EndIf;
	
	QueueMessageNumber = ExchangeNode.SentNo;
	
	// Writing catalogs and documents.
	ExchangeMobileApplicationOverridable.RegisteredDataInWriteQueueMessagesExchange(ExchangeNode, QueueMessageNumber);
	
	// Write balance.
	ExchangeMobileApplicationOverridable.WriteMessagesToQueueInBalanceOfExchange(ExchangeNode, QueueMessageNumber);
	
	// Check the sequence of the exchange messages.
	ExchangeMobileApplicationOverridable.ValidateQueueMessagesExchange(ExchangeNode, ReceivedNo);
	
	// Delete changes registration for the exchange messages put to the queue.
	ExchangePlans.DeleteChangeRecords(ExchangeNode);
	
EndFunction // GenerateQueueMessagesExchange()

// The procedure puts data to the infobase that are passed from the ExchangeNode node 
//
// Parameters:
//  ExchangeNode	- exchange plan node "MobileApplication" with
//  which the exchange is executed ExchangeData - exchange pack received from the ExchangeNode node
//  put to ValueStorage ClearChanges - the parameter determines whether it is required to clear changes sent earlier
//
Procedure AcceptExchangePackage(ExchangeNode, DataExchange, ClearChanges = False) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(DataExchange.Get());
	MessageReader = ExchangePlans.CreateMessageReader();
	MessageReader.BeginRead(XMLReader);
	
	If ClearChanges Then
		ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
	EndIf;
	
	XDTOObjectType = XDTOFactory.Type("http://www.1c.ru/SB/MobileExchange", "Objects");
	
	Objects = XDTOFactory.ReadXML(XMLReader, XDTOObjectType);
	
	ExchangeMobileApplicationOverridable.ImportObjects(ExchangeNode, Objects);
	
	MessageReader.EndRead();
	XMLReader.Close();
	
EndProcedure // AcceptExchangePackage()

Procedure RunExchangeMessagesQueueFormation(ExchangeNode, CodeMobileComputer, ReceivedNo, NeedNodeInitialization, JobID) Export
	
	ThisIsFileBase = CommonUse.FileInfobase();
	If ThisIsFileBase Then
		
		// The message in the file variant is being prepared at the time of a call from client
		MobileApplicationExchangeGeneral.GenerateQueueMessagesExchange(ExchangeNode, ReceivedNo, NeedNodeInitialization);
		
	Else
		// The message in the client server variant is being prepared in the background job.
		// It allows to avoid time-outs on the side of a mobile client as messages may be under preparation for a long time.
		
		ParameterArray = New Array;
		ParameterArray.Add(ExchangeNode);
		ParameterArray.Add(ReceivedNo);
		ParameterArray.Add(NeedNodeInitialization);
		
		FunctionName = "MobileApplicationExchangeGeneral.GenerateQueueMessagesExchange";
		
		BackgroundJob = BackgroundJobs.Execute(
			FunctionName, 
			ParameterArray, 
			,
			CodeMobileComputer);
			
		JobID = BackgroundJob.UUID;
		
	EndIf;
	
EndProcedure

// Receives an exchange message by the message number.
//
Function GetExchangeMessage(ExchangeNode, MessageNumberExchange, JobID) Export

	AnswerStructure = New Structure("Wait, ContinueExport, BreakImport, ExchangeMessage", False, True, False, Undefined);
	
	ExchangeMessage = ExchangeMobileApplicationOverridable.GetMessageExchangeByNumber(ExchangeNode, MessageNumberExchange);
	If ExchangeMessage <> Undefined Then
		AnswerStructure.ExchangeMessage = ExchangeMessage;
		Return New ValueStorage(AnswerStructure, New Deflation(9));
	EndIf;
	
	// If there is no message in the queue, check the state of the background job execution.
	HasErrors = False;
	ThisIsFileBase = CommonUse.FileInfobase();
	If ThisIsFileBase Then
		QueueMessagesFormed = True;
	Else
		QueueMessagesFormed = ExchangeMobileApplicationOverridable.QueueMessagesFormed(JobID, HasErrors);
	EndIf;
	
	// If there are errors, reset message counters to send data again during the next exchange session.
	If HasErrors Then
		ExchangeMobileApplicationOverridable.ReinitializeMessagesOnSiteCountersPlanExchange(ExchangeNode);
	EndIf;
	
	//If there are no messages and the queue is generated, consider that all packs are received successfully, otherwise, wait for packs.
	If QueueMessagesFormed Then
		AnswerStructure.Wait = False;
		AnswerStructure.ContinueExport = False;
	Else
		AnswerStructure.Wait = True;
		AnswerStructure.ContinueExport = Not HasErrors;
	EndIf;
	
	AnswerStructure.BreakImport = HasErrors;
	
	Return New ValueStorage(AnswerStructure, New Deflation(9));

EndFunction

// The function generates the exchange pack that will be sent to the ExchangeNode node.
//
// Parameters:
//  ExchangeNode	- exchange plan node "MobileApplication" with which the exchange is executed
//
// Returns:
//  generated pack put to the value storage
Function GeneratePackageExchange(ExchangeNode) Export
	
	XMLWriter = New XMLWriter;
	
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	WriteMessage = ExchangePlans.CreateMessageWriter();
	WriteMessage.BeginWrite(XMLWriter, ExchangeNode);
	
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	XMLWriter.WriteNamespaceMapping("v8",  "http://v8.1c.ru/data");
	
	DeletionDataType = Type("ObjectDeletion");
	
	ChangeSelection = ExchangePlans.SelectChanges(ExchangeNode, WriteMessage.MessageNo);
	
	ReturnedList = ExchangeMobileApplicationOverridable.CreateXDTOObject("Objects");
	
	While ChangeSelection.Next() Do
		
		Data = ChangeSelection.Get();
		
		// If a data transfer is not needed, then it may be required to record deletion of the data.
		If Not ExchangeMobileApplicationOverridable.NeedTransferData(Data, ExchangeNode) Then
			
			// We get the value with possible deletion of the data.
			ExchangeMobileApplicationOverridable.DeleteData(Data);
			
		EndIf;
		
		ExchangeMobileApplicationOverridable.WriteData(ReturnedList, Data);
		
	EndDo;
	
	ExchangeMobileApplicationOverridable.WriteBalance(ReturnedList, Data);
	
	XDTOFactory.WriteXML(XMLWriter, ReturnedList);
	
	WriteMessage.EndWrite();
	
	Return New ValueStorage(XMLWriter.Close(), New Deflation(9));
	
EndFunction // GeneratePackageExchange()
// 
