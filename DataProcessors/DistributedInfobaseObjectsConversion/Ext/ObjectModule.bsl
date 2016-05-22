#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Imports data from message exchange file.
//
// Parameters:
//  Cancel - Boolean - flag of denial; it is set when errors occurred while processing an exchange message.
// 
Procedure ExecuteDataImport(Cancel, Val ImportOnlyParameters) Export
	
	If Not ThisIsDistributedInformationBaseNode() Then
		
		// Exchange against the conversion rules is unsupported.
		FixEndExchange(Cancel,, ErrorOfDataExchangeKind());
		Return;
	EndIf;
	
	ImportMetadata = ImportOnlyParameters
		AND DataExchangeServer.IsSubordinateDIBNode()
		AND (DataExchangeServerCall.RetryDataExportExchangeMessagesBeforeStart()
			OR Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
					"MessageReceivedFromCache"));
	
	XMLReader = New XMLReader;
	
	Try
		XMLReader.OpenFile(ExchangeMessageFileName());
	Except
		
		// Error of exchange message file opening.
		FixEndExchange(Cancel, ErrorDescription(), ErrorOfOpeningOfExchangeMessageFile());
		Return;
	EndTry;
	
	ReadExchangeMessageFile(Cancel, XMLReader, ImportOnlyParameters, ImportMetadata);
	
	XMLReader.Close();
EndProcedure

// It exports data in the exchange message file.
//
// Parameters:
//  Cancel - Boolean - flag of denial; it is set when errors occurred while processing an exchange message.
// 
Procedure ExecuteDataExport(Cancel) Export
	
	If Not ThisIsDistributedInformationBaseNode() Then
		
		// Exchange against the conversion rules is unsupported.
		FixEndExchange(Cancel,, ErrorOfDataExchangeKind());
		Return;
	EndIf;
	
	XMLWriter = New XMLWriter;
	
	Try
		XMLWriter.OpenFile(ExchangeMessageFileName());
	Except
		
		// Error of exchange message file opening.
		FixEndExchange(Cancel, ErrorDescription(), ErrorOfOpeningOfExchangeMessageFile());
		Return;
	EndTry;
	
	WriteChangesToExchangeMessagesFile(Cancel, XMLWriter);
	
	XMLWriter.Close();
	
EndProcedure

// It sets as
// local variable ExchangeMessageFileNameField the string with the full name of the exchange message file for import or export data.
// As a rule the exchange message file is located in the temporary directory of the user operating system.
//
// Parameters:
//  FileName - String - full attachment file name of exchange message for exporting or importing data.
// 
Procedure SetExchangeMessageFileName(Val FileName) Export
	
	ExchangeMessageFileNameField = FileName;
	
EndProcedure

//

Procedure ReadExchangeMessageFile(Cancel, XMLReader, Val ImportOnlyParameters, Val ImportMetadata)
	
	MessageReader = ExchangePlans.CreateMessageReader();
	
	Try
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		// Unknown exchange plan is set;
		// node that is not a part of the exchange plan is specified;
		// message number does not correspond to the expected one.
		FixEndExchange(Cancel, ErrorDescription(), ErrorOfStartReadOfExchangeMessageFile());
		Return;
	EndTry;
	
	CommonDataNode = Undefined;
	ReceivedNo = MessageReader.ReceivedNo;
	ExchangeNode = MessageReader.Sender;
	
	If ImportOnlyParameters Then
		
		If ImportMetadata Then
			
			Try
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationSettings", True);
				SetPrivilegedMode(False);
				
				// Get configuration changes, ignore data changes.
				ExchangePlans.ReadChanges(MessageReader, ItemCountInTransaction);
				
				// We read priority data (metadata object IDs).
				ReadPriorityChangesFromExchangeMessages(MessageReader, CommonDataNode);
				
				// The message is considered to be not received, interrupt reading.
				MessageReader.CancelRead();
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationSettings", False);
				SetPrivilegedMode(False);
			Except
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationSettings", False);
				SetPrivilegedMode(False);
				
				MessageReader.CancelRead();
				FixEndExchange(Cancel, ErrorDescription(), ErrorOfReadingOFExchangeMessageFile());
				Return;
			EndTry;
			
		Else
			
			Try
				
				// Skip configuration changes and data changes in the exchange message.
				MessageReader.XMLReader.Skip(); // <Changes>...</Changes>
				
				MessageReader.XMLReader.Read(); // </Changes>
				
				// We read priority data (metadata object IDs).
				ReadPriorityChangesFromExchangeMessages(MessageReader, CommonDataNode);
				
				// The message is considered to be not received, interrupt reading.
				MessageReader.CancelRead();
			Except
				MessageReader.CancelRead();
				FixEndExchange(Cancel, ErrorDescription(), ErrorOfReadingOFExchangeMessageFile());
				Return
			EndTry;
			
		EndIf;
		
	Else
		
		Try
			
			// We get configuration changes and data changes from exchange message .
			ExchangePlans.ReadChanges(MessageReader, ItemCountInTransaction);
			
			// We read priority data (metadata object IDs).
			ReadPriorityChangesFromExchangeMessages(MessageReader, CommonDataNode);
			
			// We consider the message accepted
			MessageReader.EndRead();
		Except
			MessageReader.CancelRead();
			FixEndExchange(Cancel, ErrorDescription(), ErrorOfReadingOFExchangeMessageFile());
			Return
		EndTry;
		
	EndIf;
	
	// Node common data writing is executed after message reading.
	If CommonDataNode <> Undefined Then
		
		CommonNodeData = DataExchangeReUse.CommonNodeData(ExchangePlans.MasterNode());
		CurrentNode = ExchangePlans.MasterNode().GetObject();
		If DataExchangeEvents.DataDifferent(CurrentNode, CommonDataNode, CommonNodeData) Then
			DataExchangeEvents.FillObjectPropertiesValues(CurrentNode, CommonDataNode, CommonNodeData);
			CurrentNode.Write();
		EndIf;
		
	EndIf;
	
	InformationRegisters.NodesCommonDataChange.DeleteChangeRecords(ExchangeNode, ReceivedNo);
	
EndProcedure

Procedure WriteChangesToExchangeMessagesFile(Cancel, XMLWriter)
	
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	Try
		WriteMessage.BeginWrite(XMLWriter, InfobaseNode);
	Except
		FixEndExchange(Cancel, ErrorDescription(), ErrorBeginningRecordsExchangeMessageFile());
		Return;
	EndTry;
	
	Try
		
		DataExchangeServerCall.ClearExchangeDataPriority();
		
		// We write configuration changes and data changes in exchange message.
		ExchangePlans.WriteChanges(WriteMessage, ItemCountInTransaction);
		
		// We write priority data in the end of exchange messages.
		WritePriorityChangesInExchangeMessage(WriteMessage);
		
		WriteMessage.EndWrite();
	Except
		WriteMessage.CancelWrite();
		FixEndExchange(Cancel, ErrorDescription(), ErrorOfExchangeMessageFileWrite());
		Return;
	EndTry;
	
EndProcedure

// Writing of priority data in exchange message.
// For example, of the metadata object identifiers.
//
Procedure WritePriorityChangesInExchangeMessage(Val WriteMessage)
	
	// We write the <Parameters> item
	WriteMessage.XMLWriter.WriteStartElement("Parameters");
	
	If WriteMessage.Recipient <> ExchangePlans.MasterNode() Then
		
		// Export priority data of exchange (predefined items).
		ExchangeDataPriority = DataExchangeServerCall.ExchangeDataPriority();
		
		If ExchangeDataPriority.Count() > 0 Then
			
			ChangeSelection = DataExchangeServer.SelectChanges(
				WriteMessage.Recipient,
				WriteMessage.MessageNo,
				ExchangeDataPriority);
			
			BeginTransaction();
			Try
				
				While ChangeSelection.Next() Do
					
					WriteXML(WriteMessage.XMLWriter, ChangeSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
		If Not StandardSubsystemsReUse.DisableCatalogMetadataObjectIDs() Then
			
			// Export the metadata object IDs catalog.
			ChangeSelection = DataExchangeServer.SelectChanges(
				WriteMessage.Recipient,
				WriteMessage.MessageNo,
				Metadata.Catalogs["MetadataObjectIDs"]);
			
			BeginTransaction();
			Try
				
				While ChangeSelection.Next() Do
					
					WriteXML(WriteMessage.XMLWriter, ChangeSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
		// Exporting common node data.
		NodeChangesSelection = InformationRegisters.NodesCommonDataChange.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
		
		If NodeChangesSelection.Count() <> 0 Then
			
			CommonNodeData = DataExchangeReUse.CommonNodeData(WriteMessage.Recipient);
			
			If Not IsBlankString(CommonNodeData) Then
				
				ExchangePlanName = DataExchangeReUse.GetExchangePlanName(WriteMessage.Recipient);
				CommonNode = ExchangePlans[ExchangePlanName].CreateNode();
				DataExchangeEvents.FillObjectPropertiesValues(CommonNode, WriteMessage.Recipient.GetObject(), CommonNodeData);
				WriteXML(WriteMessage.XMLWriter, CommonNode);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	WriteMessage.XMLWriter.WriteEndElement(); // Parameters
	
EndProcedure

// Reading priority data from exchange messages.
// For example, of the metadata object identifiers.
//
Procedure ReadPriorityChangesFromExchangeMessages(Val MessageReader, CommonDataNode)
	
	If MessageReader.Sender = ExchangePlans.MasterNode() Then
		
		MessageReader.XMLReader.Read(); // <Parameters>
		
		BeginTransaction();
		Try
			
			PredefinedItemDoubles = "";
			Cancel = False;
			DenialDescription = "";
			IDObjects = New Array;
			ExchangePlanName = DataExchangeReUse.GetExchangePlanName(MessageReader.Sender);
			TypeExchangePlanObject = Type("ExchangePlanObject." + ExchangePlanName);
			
			If NonUniqueRecordsAreFound("Catalog.MetadataObjectIDs") Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NonUniqueRecordErrorTemplate(),
					NStr("en = 'Before exporting of the
					           |metadata object IDs non unique records were found in catalog.'"));
			EndIf;
			
			While CanReadXML(MessageReader.XMLReader) Do
				
				Data = ReadXML(MessageReader.XMLReader);
				
				Data.DataExchange.Load = True;
				
				If TypeOf(Data) = TypeExchangePlanObject Then // Common nodes data
					
					CommonDataNode = Data;
					Continue;
					
				EndIf;
				
				Data.DataExchange.Sender = MessageReader.Sender;
				Data.DataExchange.Recipients.AutoFill = False;
				
				If TypeOf(Data) = Type("CatalogObject.MetadataObjectIDs") Then
					IDObjects.Add(Data);
					Continue;
					
				ElsIf TypeOf(Data) <> Type("ObjectDeletion") Then // It is predefined item.
					
					If Not Data.Predefined Then
						Continue; // Only predefined items are processed.
					EndIf;
					
				Else // Type("ObjectRemoval")
					
					// 1. ID refs are deleted independently in
					//    all nodes through deletion mark mechanism and marked object deletion.
					// 2. Predefined items deletion is not exported.
					Continue;
				EndIf;
				
				WritePredefinedDataRef(Data);
				AddPredefinedItemDoubleDescription(Data, PredefinedItemDoubles, Cancel, DenialDescription);
			EndDo;
			
			If Cancel Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Import of important changes is not completed.
					           |While importing predefined items, non-unique records were found.
					           |For the following reasons the continuation is impossible.
					           |%1'"),
					DenialDescription);
			EndIf;
			
			If ValueIsFilled(PredefinedItemDoubles) Then
				WriteLogEvent(
					NStr("en = 'Predefined items.Non-unique records are found.'",
						CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					,
					,
					StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = 'While importing predefined items, non-unique records were found.
						           |%1'"),
						PredefinedItemDoubles));
			EndIf;
			
			RefreshPredefinedDeletion();
			
			Catalogs.MetadataObjectIDs.ImportDataToSubordinateNode(IDObjects);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	Else
		
		// We skip parameters of application work.
		MessageReader.XMLReader.Skip(); // <Parameters>...</Parameters>
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	EndIf;
	
EndProcedure

Procedure FixEndExchange(Cancel, ErrorDescription = "", ContextErrorDetails = "")
	
	Cancel = True;
	
	Comment = "[ContextErrorDetails]: [ErrorDetails]"; // Not localized
	
	Comment = StrReplace(Comment, "[ContextErrorDetails]", ContextErrorDetails);
	Comment = StrReplace(Comment, "[ErrorDescription]", ErrorDescription);
	
	WriteLogEvent(EventLogMonitorMessageKey, EventLogLevel.Error,
		InfobaseNode.Metadata(), InfobaseNode, Comment);
	
EndProcedure

Function ThisIsDistributedInformationBaseNode()
	
	Return DataExchangeReUse.ThisIsDistributedInformationBaseNode(InfobaseNode);
	
EndFunction

Procedure WritePredefinedDataRef(Data)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(Data.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	ObjectManager = CommonUse.ObjectManagerByRef(Data.Ref);
	
	If Data.IsNew() Then
		If CommonUse.ThisIsCatalog(ObjectMetadata) Then
			If ObjectMetadata.Hierarchical
				AND ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems
				AND Data.IsFolder Then
				Object = ObjectManager.CreateFolder();
			Else
				Object = ObjectManager.CreateItem();
			EndIf;
		ElsIf CommonUse.ThisIsChartOfCharacteristicTypes(ObjectMetadata) Then
			If ObjectMetadata.Hierarchical
				AND Data.IsFolder Then
				Object = ObjectManager.CreateFolder();
			Else
				Object = ObjectManager.CreateItem();
			EndIf;
		ElsIf CommonUse.ThisIsChartOfAccounts(ObjectMetadata) Then
			Object = ObjectManager.CreateAccount();
		ElsIf CommonUse.ThisIsChartOfCalculationTypes(ObjectMetadata) Then
			Object = ObjectManager.CreateCalculationType();
		EndIf;
	Else
		Object = Data.Ref.GetObject();
	EndIf;
	
	If Data.IsNew() Then
		Object.SetNewObjectRef(Data.GetNewObjectRef());
		Object.PredefinedDataName = Data.PredefinedDataName;
		InfobaseUpdate.WriteData(Object);
		
	ElsIf Object.PredefinedDataName <> Data.PredefinedDataName Then
		Object.PredefinedDataName = Data.PredefinedDataName;
		InfobaseUpdate.WriteData(Object);
	Else
		// If there is predefined item then preloading is not required.
	EndIf;
	
	Data = Object;
	
EndProcedure

Procedure AddPredefinedItemDoubleDescription(WrittenObject, PredefinedItemDoubles, Cancel, DenialDescription)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(WrittenObject.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	Table = ObjectMetadata.FullName();
	PredefinedDataName = WrittenObject.PredefinedDataName;
	Ref = WrittenObject.Ref;
	
	Query = New Query;
	Query.SetParameter("PredefinedDataName", PredefinedDataName);
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.PredefinedDataName = &PredefinedDataName";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	Selection = Query.Execute().Select();
	
	DuplicateReferenceIds = "";
	DoubleNumber = 0;
	FoundRefs = New Map;
	ExportedRefIsFound = False;
	
	While Selection.Next() Do
		// Definition of non-unique records that are related to predefined items.
		If FoundRefs.Get(Selection.Ref) = Undefined Then
			FoundRefs.Insert(Selection.Ref, 1);
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NonUniqueRecordErrorTemplate(),
				NStr("en = 'While importing predefined items, non-unique records were found.'"));
		EndIf;
		// Definition of predefined item duplicates.
		If Ref = Selection.Ref AND Not ExportedRefIsFound Then
			ExportedRefIsFound = True;
			Continue;
		EndIf;
		DoubleNumber = DoubleNumber + 1;
		If ValueIsFilled(DuplicateReferenceIds) Then
			DuplicateReferenceIds = DuplicateReferenceIds + ",";
		EndIf;
		DuplicateReferenceIds = DuplicateReferenceIds
			+ String(Selection.Ref.UUID());
	EndDo;
	
	If DoubleNumber = 0 Then
		Return;
	EndIf;
		
	WriteInJournal = True;
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnDetectPredefinedNonUniqueness");
	
	For Each Handler IN EventHandlers Do
		Definition = "";
		Handler.Module.OnDetectPredefinedNonUniqueness(
			WrittenObject, WriteInJournal, Cancel, DenialDescription);
		
		If ValueIsFilled(Definition) Then
			DenialDescription = DenialDescription + Chars.LF + TrimAll(Definition) + Chars.LF;
		EndIf;
	EndDo;

	If WriteInJournal Then
		If DoubleNumber = 1 Then
			Pattern = NStr("en = '(exported ref: %1, duplicate ref: %2)'");
		Else
			Pattern = NStr("en = '(exported ref: %1, duplicate refs: %2)'");
		EndIf;
		PredefinedItemDoubles = PredefinedItemDoubles + Chars.LF
			+ Table + "." + PredefinedDataName + Chars.LF
			+ StringFunctionsClientServer.PlaceParametersIntoString(
				Pattern,
				String(Ref.UUID()),
				DuplicateReferenceIds)
			+ Chars.LF;
	EndIf;
	
EndProcedure

Function NonUniqueRecordsAreFound(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|
	|GROUP BY
	|	MetadataObjectIDs.Ref
	|
	|HAVING
	|	COUNT(MetadataObjectIDs.Ref) > 1";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function NonUniqueRecordErrorTemplate()
	Return
		NStr("en = 'Import of important changes is not completed.
		           |%1
		           |Information base correction is required.
		           |1. Open the configurator, go to
		           |   the Administration menu, select item ""Testing and correction ..."".
		           |2. IN the
		           |   opened form - activate the Checking of the logical infobase integrity item only"";
		           |   - select the Testing and correction variant and not Testing only"";
		           |   - click Execute.
		           |3. After this, launch 1C:Enterprise and resync data.'");
EndFunction

Procedure RefreshPredefinedDeletion()
	
	SetPrivilegedMode(True);
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each Collection IN MetadataCollections Do
		For Each MetadataObject IN Collection Do
			If MetadataObject = Metadata.Catalogs.MetadataObjectIDs Then
				Continue; // It is updated separately in the ID update procedure.
			EndIf;
			RefreshDeletePredefined(MetadataObject.FullName());
		EndDo;
	EndDo;
	
EndProcedure

Procedure RefreshDeletePredefined(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Predefined = TRUE";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Left(Selection.PredefinedDataName, 1) = "#" Then
			
			Object = Selection.Ref.GetObject();
			Object.PredefinedDataName = "";
			Object.DeletionMark = True;
			
			InfobaseUpdate.WriteData(Object);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local service functions-properties.

Function ExchangeMessageFileName()
	
	If Not ValueIsFilled(ExchangeMessageFileNameField) Then
		
		ExchangeMessageFileNameField = "";
		
	EndIf;
	
	Return ExchangeMessageFileNameField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Execution context error details.

Function ErrorOfOpeningOfExchangeMessageFile()
	
	Return NStr("en = 'Exchange message file opening error'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

Function ErrorOfStartReadOfExchangeMessageFile()
	
	Return NStr("en = 'An error occurred while starting to read the exchange message file'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

Function ErrorBeginningRecordsExchangeMessageFile()
	
	Return NStr("en = 'An error occurred while starting to write the exchange message file'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

Function ErrorOfReadingOFExchangeMessageFile()
	
	Return NStr("en = 'Error reading data exchange file'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

Function ErrorOfExchangeMessageFileWrite()
	
	Return NStr("en = 'An error occurred while writing data to the exchange message file'");
	
EndFunction

Function ErrorOfDataExchangeKind()
	
	Return NStr("en = 'Exchange not according to the conversion rules is not supported'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

#EndRegion

#EndIf
