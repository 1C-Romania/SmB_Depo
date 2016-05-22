////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// "BeforeWrite" event procedure-handler of the documents for objects registration mechanism on nodes.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  Source       - DocumentObject - event source.
//  Cancel          - Boolean - check box of handler execution.
//  WriteMode - see in the DocumentWriteMode syntax assistant.
//  PostingMode - see in the DocumentPostingMode syntax assistant.
// 
Procedure ObjectsRegistrationMechanismBeforeWriteDocument(ExchangePlanName, Source, Cancel, WriteMode, PostingMode) Export
	
	AdditionalParameters = New Structure("WriteMode", WriteMode);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

// "BeforeWrite" event procedure-handler of the reference data type (except
// documents) for objects registration mechanism on nodes.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  Source       - event source in addition to the DocumentObject type.
//  Cancel          - Boolean - check box of handler execution.
// 
Procedure ObjectsRegistrationMechanismBeforeWrite(ExchangePlanName, Source, Cancel) Export
	
	RegisterObjectChange(ExchangePlanName, Source, Cancel);
	
EndProcedure

// "BeforeWrite" event procedure-handler of the registers for objects registration mechanism on nodes.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  Source       - RegisterRecordSet - event source.
//  Cancel          - Boolean - check box of handler execution.
//  Replacing      - Boolean - shows that the existing records set is replaced.
// 
Procedure ObjectsRegistrationMechanismBeforeWriteRegister(ExchangePlanName, Source, Cancel, Replacing) Export
	
	AdditionalParameters = New Structure("ThisIsRegister,Replacing", True, Replacing);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

// "BeforeWrite" event procedure-handler of the constant for objects registration mechanism on nodes.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  Source       - ConstantValueManager - event source.
//  Cancel          - Boolean - check box of handler execution.
// 
Procedure ObjectsRegistrationMechanismBeforeConstantWrite(ExchangePlanName, Source, Cancel) Export
	
	AdditionalParameters = New Structure("ThisIsConstant", True);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

// "BeforeDeletion" event procedure-handler of the reference data types for objects registration mechanism on nodes.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  Source       - event source.
//  Cancel          - Boolean - check box of handler execution.
// 
Procedure ObjectsRegistrationMechanismBeforeDelete(ExchangePlanName, Source, Cancel) Export
	
	AdditionalParameters = New Structure("IsRemoval", True);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for use in registration rule event handlers.

// Procedure expands the nodes-receivers object list with the passed values.
//
// Parameters:
//  Object - object for which registration rule is executed.
//  Nodes   - Array - exchange plan nodes that should be added to the object nodes-receivers list.
//
Procedure AddRecipients(Object, Nodes) Export
	
	For Each Item IN Nodes Do
		
		Try
			Object.DataExchange.Recipients.Add(Item);
		Except
			ExchangePlanName = Item.Metadata().Name;
			MetadataObject = Object.Metadata();
			MessageString = NStr("en = 'For exchange plan content [ExchangePlanName] not specified object registration [FullName}'");
			MessageString = StrReplace(MessageString, "[ExchangePlanName]", ExchangePlanName);
			MessageString = StrReplace(MessageString, "[DescriptionFull]",      MetadataObject.FullName());
			Raise MessageString;
		EndTry;
		
	EndDo;
	
EndProcedure

// Procedure deducts passed values from the object node-receivers list.
//
// Parameters:
//  Object - object for which registration rule is executed.
//  Nodes - Array - exchange plan nodes that should be deducted from the object nodes-receivers list.
// 
Procedure ReduceRecipients(Object, Nodes) Export
	
	Recipients = ReduceArray(Object.DataExchange.Recipients, Nodes);
	
	// Clear receivers list and fill it in again.
	Object.DataExchange.Recipients.Clear();
	
	// Add nodes for object registration.
	AddRecipients(Object, Recipients);
	
EndProcedure

// Determines nodes-receivers array for object when exchange plan is specified and
// registers objects on the received nodes.
//
// Parameters:
//  Object         - object for which it is required to execute registration rules and register on nodes.
//  ExchangePlanName - String - exchange plan name as specified in the designer.
//  Sender (optional) - ExchangePlanRef - exchange plan node from which exchange
//                    message is received while data import: if it is specified, then object is registred on the main node.
// 
Procedure ExecuteRegistrationRulesForObject(Object, ExchangePlanName, Sender = Undefined) Export
	
	Recipients = DefineRecipients(Object, ExchangePlanName);
	
	CommonUseClientServer.DeleteValueFromArray(Recipients, Sender);
	
	If Recipients.Count() > 0 Then
		
		ExchangePlans.RecordChanges(Recipients, Object);
		
	EndIf;
	
EndProcedure

// Subtracts one items array from another array. Returns subtracting result.
//
// Parameters:
// Array - Array - Source array.
// SubstractionArray - Array - Array deducted from the source array.
//
Function ReduceArray(Array, SubstractionArray) Export
	
	Return CommonUseClientServer.ReduceArray(Array, SubstractionArray);
	
EndFunction

// The function returns the list of all specified exchange plan nodes except for the predefined node.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name as specified in the designer for which
//                            you shall receive the node list.
//
//  Returns:
//   Array - list of all specified exchange plan nodes.
//
Function AllExchangePlanNodes(ExchangePlanName) Export
	
	#If ExternalConnection OR ThickClientOrdinaryApplication Then
		
		Return DataExchangeServerCall.AllExchangePlanNodes(ExchangePlanName);
		
	#Else
		
		SetPrivilegedMode(True);
		Return DataExchangeReUse.GetExchangePlanNodesArray(ExchangePlanName);
		
	#EndIf
	
EndFunction

// Function determines nodes-receivers array for the object when exchange plan is specified.
// 
// Parameters:
//  Object         - object for which it is required to execute
//                   registration rules and to determine node-receivers list.
//  ExchangePlanName - String - exchange plan name as specified in the designer.
// 
// Returns:
//  ArrayOfNodesResult - Array - node-receivers array for object.
//
Function DefineRecipients(Object, ExchangePlanName) Export
	
	ArrayOfNodesResult = New Array;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("MetadataObject", Object.Metadata());
	AdditionalParameters.Insert("ThisIsRegister", CommonUse.ThisIsRegister(AdditionalParameters.MetadataObject));
	ExecuteObjectRegistrationRulesForExchangePlans(ArrayOfNodesResult, Object, ExchangePlanName, AdditionalParameters);
	
	Return ArrayOfNodesResult;
	
EndFunction

// It defines the metadata object autorecording flag in the exchange plan.
//
// Parameters:
// MetadataObject (mandatory) - metadata object for which it is required to get autoregistration flag.
// ExchangePlanName (mandatory) - String - exchange plan name as specified in the designer including
// the metadata object.
//
// Returns:
//  True - metadata object has Allowed autorecording flag in the exchange plan;
//  False   - The metadata object has Prohibited autorecording flag in the
//           exchange plan or the metadata object is not included in the exchange plan.
//
Function AutoRecordPermitted(MetadataObject, ExchangePlanName) Export
	
	Return DataExchangeReUse.AutoRecordPermitted(ExchangePlanName, MetadataObject.FullName());
	
EndFunction

// Checks the existence of the data item import prohibition.
//  Function operation requires the setup
// of the DataForChangingProhibitionCheck procedure of the ChangeProhibitionDatesOverridable module.
//
// Parameters:
//  Data              - CatalogObject.<Name>,
//                        DocumentObject.<Name>,
//                        ChartOfCharacteristicTypesObject.<Name>,
//                        ChartOfAccountsObject.<Name>,
//                        ChartOfCalculationTypesObject.<Name>,
//                        BusinessProcessObject.<Name>,
//                        TaskObject.<Name>,
//                        ExchangePlanObject.<Name>,
//                        ObjectDeletion - data object.
//                        InformationRegisterRecordSet.<Name>,
//                        AccumulationRegisterRecordSet.<Name>,
//                        AccountingRegisterRecordSet.<Name>,
//                        CalculationRegisterRecordSet.<Name> - record set.
//
//  ExchangePlanNode     - ExchangePlansRef.<Exchange plan name> - node
//                        for which the check will be executed.
//
// Returns:
//  Boolean - If True import is prohibited.
//
Function ImportingIsProhibited(Data, Val ExchangePlanNode) Export
	
	If Data.AdditionalProperties.Property("DataImportProhibitionFound") Then
		Return True;
	EndIf;
	
	ItemReceive = DataItemReceive.Auto;
	ValidateImportProhibitionExistanceByDate(Data, ItemReceive, ExchangePlanNode);
	
	Return ItemReceive = DataItemReceive.Ignore;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// Procedure is designed to determine the sending kind of imported data item.
// Called from exchange plan handlers: OnSendDataToMain(), OnSendDataToSubordinate().
//
// Parameters:
//  DataItem, SendItem - see parameters description
//                                    in syntax assistant for methods OnSendDataToMain() and OnSendDataToSubordinate().
//
Procedure OnDataSendingToCorrespondent(DataItem,
										ItemSend,
										Val CreatingInitialImage = False,
										Val Recipient = Undefined,
										Val Analysis = True
	) Export
	
	If Recipient = Undefined Then
		
		//
		
	ElsIf ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf DataExchangeReUse.IsSLDataExchangeNode(Recipient.Ref) Then
		
		OnDataSending(DataItem, ItemSend, Recipient.Ref, CreatingInitialImage, Analysis);
		
	EndIf;
	
	If Analysis Then
		Return;
	EndIf;
	
	// Fix exported predefined data (only for DIB).
	If Not CreatingInitialImage
		AND ItemSend <> DataItemSend.Ignore
		AND DataExchangeReUse.ThisIsDistributedInformationBaseNode(Recipient.Ref)
		AND TypeOf(DataItem) <> Type("ObjectDeletion")
		Then
		
		BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(DataItem.Metadata());
		
		If BaseTypeName = CommonUse.TypeNameCatalogs()
			OR BaseTypeName = CommonUse.TypeNameChartsOfCharacteristicTypes()
			OR BaseTypeName = CommonUse.TypeNameChartsOfAccounts()
			OR BaseTypeName = CommonUse.TypeNameChartsOfCalculationTypes() Then
			
			If DataItem.Predefined Then
				
				DataExchangeServerCall.AddExchangePriorityData(DataItem.Ref);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMasterAtStart(DataItem, ItemReceive, SendBack, Sender) Export
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"ImportApplicationSettings") Then
		
		// IN the mode of application work parameters import ignore getting of all data.
		ItemReceive = DataItemReceive.Ignore;
		
	EndIf;
	
EndProcedure

// Procedure is designed to check for conflicts of import and data change prohibition.
// Called from exchange plan handler: OnReceiveDataFromMain.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMasterAtTheEnd(DataItem, ItemReceive, Val Sender) Export
	
	// Check for import prohibition by the prohibition date.
	ValidateImportProhibitionExistanceByDate(DataItem, ItemReceive, Sender);
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Check for data change conflict.
	ValidateDataChangeConflicts(DataItem, ItemReceive, Sender, True);
	
EndProcedure

// Procedure is designed to check for conflicts of import and data change prohibition.
// Called from exchange plan handler: OnReceiveDataFromSubordinate.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubOrdinateEOF(DataItem, ItemReceive, Val Sender) Export
	
	// Check for import prohibition by the prohibition date.
	ValidateImportProhibitionExistanceByDate(DataItem, ItemReceive, Sender);
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Check for data change conflict.
	ValidateDataChangeConflicts(DataItem, ItemReceive, Sender, False);
	
EndProcedure

// Registers one data item change for the subsequent sending to the node-receiver address.
// Data item will be registered only if it corresponds to objects registration rules filters set to the node-receiver properties.
// Data items that are exported if necessary, registered unconditionally.
// Object ObjectDeletion is registered unconditionally.
//
// Parameters:
//     Recipient - ExchangePlanRef          - exchange plan node for which data
//                                              changes registration is executed;
//     Data     - <Data>, ObjectDeletion - an object that represents data stored in the
//                  database such as catalog document, catalog item, bookkeeping account,
//                  constant record manager, register records set etc CheckExportPermission - Boolean   - Optional check box. If you set to False, then additional
//                                              check on the match to node general settings is
//                                              not executed during registration.
//
Procedure RecordChangesData(Val Recipient, Val Data, Val CheckPermissionOfUplouding=True) Export
	
	If TypeOf(Data) = Type("ObjectDeletion") Then
		// Object removal is registered unconditionally.
		ExchangePlans.RecordChanges(Recipient, Data);
		
	Else
		ObjectExportMode = DataExchangeReUse.ObjectExportMode(Data.Metadata().FullName(), Recipient);
		
		If ObjectExportMode = Enums.ExchangeObjectsExportModes.ExportIfNecessary Then
			
			If CommonUse.ReferenceTypeValue(Data) Then
				IsNewObject = Data.IsEmpty();
			Else
				IsNewObject = Data.IsNew(); 
			EndIf;
			
			If IsNewObject Then
				Raise NStr("en = 'Registration of the unrecorded objects exported by the reference is not supported.'");
			EndIf;
			
			BeginTransaction();
			Try
				// Register data on the node-receiver.
				ExchangePlans.RecordChanges(Recipient, Data);
				
				// For the data exported by the reference put additional information to the filter of objects allowed for export.
				// It is also required for data to pass filter during export and be exported to the exchange message.
				If DataExchangeReUse.ThisIsExchangePlanXDTO(Recipient) Then
					DataExchangeXDTOServer.AddObjectToFilterOfPermittedObjects(Data.Ref, Recipient);
				Else
					InformationRegisters.InfobasesObjectsCompliance.AddObjectToFilterOfPermittedObjects(Data.Ref, Recipient);
				EndIf;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		ElsIf Not CheckPermissionOfUplouding Then
			// Register unconditionally
			ExchangePlans.RecordChanges(Recipient, Data);
			
		ElsIf ObjectExportPermitted(Recipient, Data) Then
			// Register only if the object meets the general restrictions.
			ExchangePlans.RecordChanges(Recipient, Data);
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// Only for internal use.
//
Procedure RecordDataMigrationRestrictionFilterChanges(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // Write node while receiving exchange message (universal data exchange).
	ElsIf Not DataExchangeReUse.IsSLDataExchangeNode(Source.Ref) Then
		Return;
	ElsIf Source.ThisNode Then
		Return;
	EndIf;
	
	SourceRef = CommonUse.ObjectAttributesValues(Source.Ref, "SentNo, ReceivedNo");
	
	If SourceRef.SentNo <> Source.SentNo Then
		Return; // Write node while sending exchange message.
	ElsIf SourceRef.ReceivedNo <> Source.ReceivedNo Then
		Return; // Write node while receiving exchange message.
	EndIf;
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(Source.Ref);
	
	// Receives the attributes of the reference type that are supposedly used as filters of registration rules filters.
	ReferenceTypeAttributeTable = GetRefTypeObjectAttributes(Source, ExchangePlanName);
	
	// Determine a flag showing that node is modified relative to the selected attributes.
	ObjectModified = ObjectModifiedByAttributes(Source, ReferenceTypeAttributeTable);
	
	If ObjectModified Then
		
		Source.AdditionalProperties.Insert("NodeAttributeTable", ReferenceTypeAttributeTable);
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure CheckDataMigrationRestrictionFiltersChangessOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	RegisteredToExportObjects = Undefined;
	If Source.AdditionalProperties.Property("RegisteredToExportObjects", RegisteredToExportObjects) Then
		
		DataExchangeServerCall.RefreshCacheMechanismForRegistrationOfObjects();
		
		For Each Object IN RegisteredToExportObjects Do
			
			If Not ObjectExportPermitted(Source.Ref, Object) Then
				
				ExchangePlans.DeleteChangeRecords(Source.Ref, Object);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ReferenceTypeAttributeTable = Undefined;
	If Source.AdditionalProperties.Property("NodeAttributeTable", ReferenceTypeAttributeTable) Then
		
		// Register selected objects of the reference type on the current node without using ORR.
		ExecuteRefTypeObjectsRegistrationByNodeProperties(Source, ReferenceTypeAttributeTable);
		
		// Update reused mechanism values.
		DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure EnableUseExchangePlan(Source, Cancel) Export
	
	If Source.IsNew() AND DataExchangeReUse.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		
		// Cache of open sessions for ORM has become irrelevant.
		DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure DisableUseExchangePlan(Source, Cancel) Export
	
	If DataExchangeReUse.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		
		// Cache of open sessions for ORM has become irrelevant.
		DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure CheckDataExchangeSettingChangePossibility(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If  Not Source.AdditionalProperties.Property("GettingExchangeMessage")
		AND Not Source.IsNew()
		AND Not Source.ThisNode
		AND DataExchangeReUse.IsSLDataExchangeNode(Source.Ref)
		AND DataDifferent(Source, Source.Ref.GetObject(),, "SentNo, ReceivedNo, DeletionMark, Code, Name")
		AND DataExchangeServerCall.ChangesRegistered(Source.Ref)
		Then
		
		SaveAllowedToExportObjects(Source);
		
	EndIf;
	
	// Code and name of node can not be changed in service.
	If CommonUseReUse.DataSeparationEnabled()
		AND Not CommonUseReUse.SessionWithoutSeparator()
		AND Not Source.IsNew()
		AND DataDifferent(Source, Source.Ref.GetObject(), "Code, description") Then
		
		Raise NStr("en = 'Modification of the data synchronization code and name is invalid.'");
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure DisableAutomaticDataSynchronizationOnWrite(Source, Cancel, Replacing) Export
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		ModuleOfflineWorkService = CommonUse.CommonModule("OfflineWorkService");
		ModuleOfflineWorkService.DisableAutomaticDataSynchronizationWithApplicationInInternet(Source);
	EndIf;
	
EndProcedure

Procedure SaveAllowedToExportObjects(NodeObject)
	
	SetPrivilegedMode(True);
	
	RegisteredData = New Array;
	ExchangePlanContent = NodeObject.Metadata().Content;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	*
	|FROM
	|	[Table].Changes AS ChangeTable
	|WHERE
	|	ChangeTable.Node = &Node";
	Query.SetParameter("Node", NodeObject.Ref);
	
	For Each ContentItem IN ExchangePlanContent Do
		
		If ContentItem.AutoRecord = AutoChangeRecord.Allow Then
			Continue;
		EndIf;
		
		MetadataElement = ContentItem.Metadata;
		FullMetadataObjectName = MetadataElement.FullName();
		
		Query.Text = StrReplace(QueryText, "[Table]", FullMetadataObjectName);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			
			RegisteredDataOfSameType = Result.Unload();
			
			If CommonUse.ThisIsObjectOfReferentialType(MetadataElement) Then
				
				For Each String IN RegisteredDataOfSameType Do
					
					If CommonUse.RefExists(String.Ref) Then
						
						ReferenceObject = String.Ref.GetObject();
						
						If ObjectExportPermitted(NodeObject.Ref, ReferenceObject) Then
							RegisteredData.Add(ReferenceObject);
						EndIf;
						
					EndIf;
					
				EndDo;
				
			ElsIf CommonUse.ThisIsConstant(MetadataElement) Then
				
				ConstantValueManager = Constants[MetadataElement.Name].CreateValueManager();
				If ObjectExportPermitted(NodeObject.Ref, ConstantValueManager) Then
					RegisteredData.Add(ConstantValueManager);
				EndIf;
				
			Else // Register or sequence.
				
				For Each String IN RegisteredDataOfSameType Do
					
					RecordSet = CommonUse.ObjectManagerByFullName(FullMetadataObjectName).CreateRecordSet();
					
					For Each FilterItem IN RecordSet.Filter Do
						
						If RegisteredDataOfSameType.Columns.Find(FilterItem.Name) <> Undefined Then
							
							RecordSet.Filter[FilterItem.Name].Set(String[FilterItem.Name]);
							
						EndIf;
						
					EndDo;
					
					RecordSet.Read();
					
					If ObjectExportPermitted(NodeObject.Ref, RecordSet) Then
						RegisteredData.Add(RecordSet);
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	NodeObject.AdditionalProperties.Insert("RegisteredToExportObjects", RegisteredData);
	
EndProcedure

Function ObjectExportPermitted(ExchangeNode, Object)
	
	If CommonUse.ReferenceTypeValue(Object) Then
		Return DataExchangeServer.ExportingReferencesPermitted(ExchangeNode, Object);
	EndIf;
	
	sending = DataItemSend.Auto;
	OnDataSendingToCorrespondent(Object, sending, , ExchangeNode);
	Return sending = DataItemSend.Auto;
EndFunction

// Only for internal use.
//
Procedure CancelSendNodeDataInDistributedInfobase(Source, DataItem, Ignore) Export
	
	Ignore = True;
	
EndProcedure

// Only for internal use.
//
Procedure RegisterNodesCommonDataChanges(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // Write node while receiving exchange message (universal data exchange).
	ElsIf Not DataExchangeReUse.IsSeparatedSLDataExchangeNode(Source.Ref) Then
		Return;
	ElsIf Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	CommonNodeData = DataExchangeReUse.CommonNodeData(Source.Ref);
	
	If IsBlankString(CommonNodeData) Then
		Return;
	EndIf;
	
	If Source.ThisNode Then
		Return;
	EndIf;
	
	If DataDifferent(Source, Source.Ref.GetObject(), CommonNodeData) Then
		
		InformationRegisters.NodesCommonDataChange.RecordChanges(Source.Ref);
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure ClearInfobaseNodeReferences(Source, Cancel) Export
	
	InformationRegisters.DataExchangeResults.ClearInfobaseNodeReferences(Source.Ref);
	
	Catalogs.DataExchangeScripts.ClearInfobaseNodeReferences(Source.Ref);
	
EndProcedure

// Receives records set current value in the infobase.
// 
// Parameters:
// Data - Registers record set.
// 
// Returns:
// RecordSet containing current value in the infobase.
// 
Function GetRecordSet(Val Data) Export
	
	MetadataObject = Data.Metadata();
	
	RecordSet = RecordSetByType(MetadataObject);
	
	For Each FilterValue IN Data.Filter Do
		
		If FilterValue.Use = False Then
			Continue;
		EndIf;
		
		FilterRow = RecordSet.Filter.Find(FilterValue.Name);
		FilterRow.Value = FilterValue.Value;
		FilterRow.Use = True;
		
	EndDo;
	
	RecordSet.Read();
	
	Return RecordSet;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Objects registration mechanism (ORM).

// Determines nodes list of the ExchangePlanName exchange plan receivers for which it is required to register the Object object for the subsequent export.
//
// First, it is defined using selective object
// registration (SOR) mechanism on which exchange plans object for export should be registered.
// Then, using objects registration mechanism (ORM, registration rules) it is determined on which nodes of each exchange plan object should be registered.
//
// Parameters:
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  Object - Arbitrary - changed data: object, records set, constant or information about object removal.
//  Cancel - Boolean - Shows that an error occurred while registering object on nodes:
//    if errors occur while registering object, check box will be selected to the True value.
//  AdditionalParameters - Structure - clarifications on changed data:
//    * IsRegister - Boolean - the True value means that register is processed.
//        Optional, default value is False.
//    * IsObjectDeletion - Boolean - the True value means that object removal is processed.
//        Optional, default value is False.
//    * IsConstant - Boolean - the True value means that constant is processed.
//        Optional, default value is False.
//    * WriteMode - see in the DocumentWritingMode syntax assistant - document writing mode (only for documents).
//        Optional, default value is Undefined.
//    * Replacing - Boolean - register writing mode (only for registers).
//        Optional, default value is Undefined.
//
Procedure RegisterObjectChange(ExchangePlanName, Object, Cancel, AdditionalParameters = Undefined)
	
	OptionalParameters = New Structure;
	OptionalParameters.Insert("ThisIsRegister", False);
	OptionalParameters.Insert("ThisIsObjectDeletion", False);
	OptionalParameters.Insert("ThisIsConstant", False);
	OptionalParameters.Insert("WriteMode", Undefined);
	OptionalParameters.Insert("Replacing", Undefined);
	
	If AdditionalParameters <> Undefined Then
		FillPropertyValues(OptionalParameters, AdditionalParameters);
	EndIf;
	
	ThisIsRegister = OptionalParameters.ThisIsRegister;
	ThisIsObjectDeletion = OptionalParameters.ThisIsObjectDeletion;
	ThisIsConstant = OptionalParameters.ThisIsConstant;
	WriteMode = OptionalParameters.WriteMode;
	Replacing = OptionalParameters.Replacing;
	
	Try
		
		If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
			Return;
		EndIf;
		
		SetPrivilegedMode(True);
		
		MetadataObject = Object.Metadata();
		
		If CommonUseReUse.DataSeparationEnabled() Then
			
			If Not SeparatedExchangePlan(ExchangePlanName) Then
				Raise NStr("en = 'Registration of modifications for undivided exchange plans is not supported.'");
			EndIf;
			
			If CommonUseReUse.CanUseSeparatedData() Then
				
				If Not SeparatedData(MetadataObject) Then
					Raise NStr("en = 'Registration of the unseparated data modifications in the divided mode.'");
				EndIf;
				
			Else
				
				If SeparatedData(MetadataObject) Then
					Raise NStr("en = 'Registration of the separated data modifications in the undivided mode.'");
				EndIf;
					
				// For undivided data in the undivided mode register data
				// changes on all nodes of divided exchange plans.
				// Using registration mechanism in this mode is not supported.
				RegisterChangesOnAllSeparatedExchangePlanNodes(ExchangePlanName, Object);
				Return;
				
			EndIf;
			
		EndIf;
		
		DataExchangeServerCall.CheckObjectRegistrationMechanismCache();
		
		// Determine whether it is necessary to register object on sender node.
		If Object.AdditionalProperties.Property("RecordObjectChangeAtSenderNode") Then
			Object.DataExchange.Sender = Undefined;
		EndIf;
		
		If Not DataExchangeServerCall.DataExchangeEnabled(ExchangePlanName, Object.DataExchange.Sender) Then
			Return;
		EndIf;
		
		// Ignore objects registration of DIB node initial image.
		If StandardSubsystemsServer.ThisIsObjectOfPrimaryImageNodeRIB(MetadataObject) Then
			Return;
		EndIf;
		
		// During physical object removal do not execute SOR.
		RecordObjectChangeToExport = ThisIsRegister Or ThisIsObjectDeletion Or ThisIsConstant;
		
		ObjectModified = Object.AdditionalProperties.Property("WriteBack")
			Or Object.AdditionalProperties.Property("DeferredPosting")
			Or ObjectModifiedForExchangePlan(
				Object, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport
			);
		
		If Not ObjectModified Then
			
			If DataExchangeReUse.AutoRecordPermitted(ExchangePlanName, MetadataObject.FullName()) Then
				
				// If object is not modified and it
				// is registered automatically, delete all nodes by autoregistration for the current exchange plan.
				ReduceRecipients(Object, AllExchangePlanNodes(ExchangePlanName));
				
			EndIf;
			
			// Object is not modified relative
			// to the current exchange plan do not register on this exchange plan nodes.
			Return;
			
		EndIf;
		
		If Not DataExchangeReUse.AutoRecordPermitted(ExchangePlanName, MetadataObject.FullName()) Then
			
			ArrayOfNodesResult = New Array;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("MetadataObject", MetadataObject);
			AdditionalParameters.Insert("ThisIsRegister", ThisIsRegister);
			AdditionalParameters.Insert("ThisIsObjectDeletion", ThisIsObjectDeletion);
			AdditionalParameters.Insert("Replacing", Replacing);
			AdditionalParameters.Insert("WriteMode", WriteMode);
			
			CheckRef = ?(ThisIsRegister OR ThisIsConstant, False, Not Object.IsNew() AND Not ThisIsObjectDeletion);
			AdditionalParameters.Insert("CheckRef", CheckRef);
			
			ExecuteObjectRegistrationRulesForExchangePlans(ArrayOfNodesResult, Object, ExchangePlanName, AdditionalParameters);
			
			// After Defining Recipients handler.
			DataExchangeServer.AfterGetRecipients(Object, ArrayOfNodesResult, ExchangePlanName);
			
			AddRecipients(Object, ArrayOfNodesResult);
			
		EndIf;
		
	Except
		WriteLogEvent(NStr("en = 'Data exchange. Objects registration rules'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		ProcessRegistrationRulesError(ExchangePlanName);
		Cancel = True;
	EndTry;
	
EndProcedure

Procedure RegisterChangesOnAllSeparatedExchangePlanNodes(ExchangePlanName, Object)
	
	QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	ExchangePlan.RegisterChanges
		|	AND Not ExchangePlan.DeletionMark";

	Query = New Query;
	Query.Text = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
	Recipients = Query.Execute().Unload().UnloadColumn("Recipient");

	For Each Recipient IN Recipients Do
		Object.DataExchange.Recipients.Add(Recipient);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Selective objects registration (SOR).

Function ObjectModifiedForExchangePlan(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	Try
		ObjectModified = ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport);
	Except
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Error on defining object modification: %1'"),
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return ObjectModified;
EndFunction

Function ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	If RecordObjectChangeToExport Or Source.IsNew() Or Source.DataExchange.Load Then
		// Always register changes
		// - for the register record sets,
		// - while physical objects removal,
		// - for new objects,
		// - for objects written by the data exchange.
		Return True;
		
	ElsIf WriteMode <> Undefined AND DocumentPostingChanged(Source, WriteMode) Then
		// If "Posted" document flag is changed, then document is changed.
		Return True;
		
	EndIf;
	
	ObjectName = MetadataObject.FullName();
	
	ChangeRecordAttributeTable = DataExchangeReUse.GetRegistrationAttributesTable(ObjectName, ExchangePlanName);
	
	If ChangeRecordAttributeTable.Count() = 0 Then
		// If SOR rules are not specified, then there is no SOR filter.
		// Object is always modified.
		Return True;
	EndIf;
	
	For Each ChangeRecordAttributeTableRow IN ChangeRecordAttributeTable Do
		
		HasObjectVersioningChanges = DefineObjectsVersionsChanges(Source, ChangeRecordAttributeTableRow);
		
		If HasObjectVersioningChanges Then
			Return True;
		EndIf;
		
	EndDo;
	
	// If you reached the end, the object has not changed by registration attributes. Registration on the nodes is not needed.
	Return False;
EndFunction

Function ObjectModifiedByAttributes(Source, ReferenceTypeAttributeTable)
	
	For Each TableRow IN ReferenceTypeAttributeTable Do
		
		HasObjectVersioningChanges = DefineObjectsVersionsChanges(Source, TableRow);
		
		If HasObjectVersioningChanges Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Function DefineObjectsVersionsChanges(Object, ChangeRecordAttributeTableRow)
	
	If IsBlankString(ChangeRecordAttributeTableRow.TabularSectionName) Then // Object header attributes
		
		ChangeRecordAttributeTableObjectVersioningBeforeChanges = GetTableOfHeaderRegistrationAttributesBeforeChange(Object, ChangeRecordAttributeTableRow);
		
		ChangeRecordAttributeTableObjectVersioningAfterChange = GetTableOfHeaderRegistrationAttributesAfterChange(Object, ChangeRecordAttributeTableRow);
		
	Else // object TS attributes
		
		ChangeRecordAttributeTableObjectVersioningBeforeChanges = GetTableOfTabularSectionRegistrationAttributesBeforeChange(Object, ChangeRecordAttributeTableRow);
		
		ChangeRecordAttributeTableObjectVersioningAfterChange = GetTableOfTabularSectionRegistrationAttributesAfterChange(Object, ChangeRecordAttributeTableRow);
		
	EndIf;
	
	Return Not RegistrationAttributesTablesAreIdentical(ChangeRecordAttributeTableObjectVersioningBeforeChanges, ChangeRecordAttributeTableObjectVersioningAfterChange, ChangeRecordAttributeTableRow);
	
EndFunction

Function GetTableOfHeaderRegistrationAttributesBeforeChange(Object, ChangeRecordAttributeTableRow)
	
	QueryText = "
	|SELECT " + ChangeRecordAttributeTableRow.ChangeRecordAttributes 
	  + " IN " + ChangeRecordAttributeTableRow.ObjectName + " AS
	|CurrentObject
	|WHERE CurrentObject.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetTableOfTabularSectionRegistrationAttributesBeforeChange(Object, ChangeRecordAttributeTableRow)
	
	QueryText = "
	|SELECT "+ ChangeRecordAttributeTableRow.ChangeRecordAttributes
	+ " IN " + ChangeRecordAttributeTableRow.ObjectName 
	+ "." + ChangeRecordAttributeTableRow.TabularSectionName + " AS
	|CurrentObjectTabularSectionName
	|WHERE CurrentObjectTabularSectionName.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetTableOfHeaderRegistrationAttributesAfterChange(Object, ChangeRecordAttributeTableRow)
	
	ChangeRecordAttributeStructure = ChangeRecordAttributeTableRow.ChangeRecordAttributeStructure;
	
	ChangeRecordAttributeTable = New ValueTable;
	
	For Each ChangeRecordAttribute IN ChangeRecordAttributeStructure Do
		
		ChangeRecordAttributeTable.Columns.Add(ChangeRecordAttribute.Key);
		
	EndDo;
	
	TableRow = ChangeRecordAttributeTable.Add();
	
	For Each ChangeRecordAttribute IN ChangeRecordAttributeStructure Do
		
		TableRow[ChangeRecordAttribute.Key] = Object[ChangeRecordAttribute.Key];
		
	EndDo;
	
	Return ChangeRecordAttributeTable;
EndFunction

Function GetTableOfTabularSectionRegistrationAttributesAfterChange(Object, ChangeRecordAttributeTableRow)
	
	ChangeRecordAttributeTable = Object[ChangeRecordAttributeTableRow.TabularSectionName].Unload(, ChangeRecordAttributeTableRow.ChangeRecordAttributes);
	
	Return ChangeRecordAttributeTable;
	
EndFunction

Function RegistrationAttributesTablesAreIdentical(Table1, Table2, ChangeRecordAttributeTableRow)
	
	AddColumnWithValueToTable(Table1, +1);
	AddColumnWithValueToTable(Table2, -1);
	
	ResultTable = Table1.Copy();
	
	CommonUseClientServer.SupplementTable(Table2, ResultTable);
	
	ResultTable.GroupBy(ChangeRecordAttributeTableRow.ChangeRecordAttributes, "ChangeRecordAttributeTableIterator");
	
	SameRowCount = ResultTable.FindRows(New Structure ("ChangeRecordAttributeTableIterator", 0)).Count();
	
	TableRowCount = ResultTable.Count();
	
	Return SameRowCount = TableRowCount;
	
EndFunction

Function DocumentPostingChanged(Source, WriteMode)
	
	Return (Source.Posted AND WriteMode = DocumentWriteMode.UndoPosting)
	 OR (NOT Source.Posted AND WriteMode = DocumentWriteMode.Posting);
	
EndFunction

Procedure AddColumnWithValueToTable(Table, IteratorValue)
	
	Table.Columns.Add("ChangeRecordAttributeTableIterator");
	
	Table.FillValues(IteratorValue, "ChangeRecordAttributeTableIterator");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Object registration rules (ORR).

// Procedure-wrapper, execute main procedure
// code in the attempt mode (see ExecuteObjectRegistrationRulesForExchangePlanAttemptException).
//
// Parameters:
//  ArrayOfNodesResult - Array - array of the ExchangePlan exchange
//   plan receivers node for which it is required to execute registration.
//  Object - Arbitrary - changed data: object, records set, constant or information about object removal.
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  AdditionalParameters - Structure - clarifications on changed data:
//    * MetadataObject - MetadataObject - metadata object to which changed data are matched. IsRequired.
//    * IsRegister - Boolean - the True value means that register is processed.
//        Optional, default value is False.
//    * IsObjectDeletion - Boolean - the True value means that object removal is processed.
//        Optional, default value is False.
//    * WriteMode - see in the DocumentWritingMode syntax assistant - document writing mode (only for documents).
//        Optional, default value is Undefined.
//    * Replacing - Boolean - register writing mode (only for registers).
//        Optional, default value is Undefined.
//    * CheckRef - Boolean - shows that it is required to consider data version at the time before their change.
//        Optional, default value is False.
//    * Export - Boolean - parameter determines registration rule execution context.
//        True - registration rule is executed in the object export context.
//        False - registration rule is executed in the context before object writing.
//        Optional, default value is False.
//
Procedure ExecuteObjectRegistrationRulesForExchangePlans(ArrayOfNodesResult, Object, ExchangePlanName, AdditionalParameters)

	MetadataObject = AdditionalParameters.MetadataObject;
	OptionalParameters = New Structure;
	OptionalParameters.Insert("ThisIsRegister", False);
	OptionalParameters.Insert("ThisIsObjectDeletion", False);
	OptionalParameters.Insert("WriteMode", Undefined);
	OptionalParameters.Insert("Replacing", False);
	OptionalParameters.Insert("CheckRef", False);
	OptionalParameters.Insert("Export", False);
	FillPropertyValues(OptionalParameters, AdditionalParameters);
	
	AdditionalParameters = OptionalParameters;
	
	AdditionalParameters.Insert("MetadataObject", MetadataObject);
	
	Try
		ExecuteObjectRegistrationRulesForExchangePlansTryExcept(ArrayOfNodesResult, Object, ExchangePlanName, AdditionalParameters);
	Except
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'An error occurred while executing object registration for %1 exchange plan.
			|Error
			|description: %2'"),
			ExchangePlanName,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Determines nodes list of the ExchangePlanName exchange plan receivers for which it is required to register the Object object for the subsequent export.
//
// Parameters:
//  ArrayOfNodesResult - Array - array of the ExchangePlan exchange
//   plan receivers node for which it is required to execute registration.
//  Object - Arbitrary - changed data: object, records set, constant or information about object removal.
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  AdditionalParameters - Structure - clarifications on changed data:
//    * MetadataObject - MetadataObject - metadata object to which changed data are matched. IsRequired.
//    * IsRegister - Boolean - the True value means that register is processed. IsRequired.
//    * IsObjectDeletion - Boolean - the True value means that object removal is processed. IsRequired.
//    * WriteMode - see in the DocumentWritingMode syntax assistant - document writing mode (only for documents).
//                    IsRequired.
//    * Replacing - Boolean - register writing mode (only for registers). IsRequired.
//    * CheckRef - Boolean - shows that it is required to consider data version at the time before their change.
//                                 IsRequired.
//    * Export - Boolean - parameter determines registration rule execution context.
//        True - registration rule is executed in the object export context.
//        False - registration rule is executed in the context before object writing. IsRequired.
//
Procedure ExecuteObjectRegistrationRulesForExchangePlansTryExcept(ArrayOfNodesResult, Object, ExchangePlanName, AdditionalParameters)
	
	MetadataObject = AdditionalParameters.MetadataObject;
	ThisIsRegister = AdditionalParameters.ThisIsRegister;
	ThisIsObjectDeletion = AdditionalParameters.ThisIsObjectDeletion;
	WriteMode = AdditionalParameters.WriteMode;
	Replacing = AdditionalParameters.Replacing;
	CheckRef = AdditionalParameters.CheckRef;
	Exporting = AdditionalParameters.Export;
	
	ObjectChangeRecordRules = New Array;
	
	SecurityProfileName = DataExchangeReUse.SecurityProfileName(ExchangePlanName);
	If SecurityProfileName <> Undefined Then
		SetSafeMode(SecurityProfileName);
	EndIf;
	
	Rules = ObjectChangeRecordRules(ExchangePlanName, MetadataObject.FullName());
	
	For Each Rule IN Rules Do
		
		ObjectChangeRecordRules.Add(ChangeRecordRuleStructure(Rule, Rules.Columns));
		
	EndDo;
	
	If ObjectChangeRecordRules.Count() = 0 Then // Registration Rules are not set.
		
		// if ORR are not created for object and
		// autoregistration is disabled, then register object on all exchange plan nodes except of the predefined one.
		Recipients = AllExchangePlanNodes(ExchangePlanName);
		
		CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, Recipients);
		
	Else // Consistently execute registration rules.
		
		If ThisIsRegister Then // for register
			
			For Each ORR IN ObjectChangeRecordRules Do
				
				// DETERMINE RECEIVERS WITH THE "UNDER CONDITION" EXPORT MODE
				
				DefineRecipientsByConditionForRecordSet(ArrayOfNodesResult, ORR, Object, MetadataObject, ExchangePlanName, Replacing, Exporting);
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					// DETERMINE RECEIVERS WITH THE "ALWAYS" EXPORT MODE
					
					#If ExternalConnection OR ThickClientOrdinaryApplication Then
						
						Recipients = DataExchangeServerCall.GetNodesArrayForRegistrationAlwaysExport(ExchangePlanName, ORR.FlagAttributeName);
						
					#Else
						
						SetPrivilegedMode(True);
						Recipients = GetNodesArrayForRegistrationAlwaysExport(ExchangePlanName, ORR.FlagAttributeName);
						SetPrivilegedMode(False);
						
					#EndIf
					
					CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, Recipients);
					
					// DETERMINE RECEIVERS WITH THE
					// "IF NEEDED" EXPORT MODE for record sets "if needed" registration does not make physical sense.
					
				EndIf;
				
			EndDo;
			
		Else // for reference type
			
			For Each ORR IN ObjectChangeRecordRules Do
				
				// DETERMINE RECEIVERS WITH THE "UNDER CONDITION" EXPORT MODE
				
				DefineRecipientsByCondition(ArrayOfNodesResult, ORR, Object, ExchangePlanName, AdditionalParameters);
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					// DETERMINE RECEIVERS WITH THE "ALWAYS" EXPORT MODE
					
					#If ExternalConnection OR ThickClientOrdinaryApplication Then
						
						Recipients = DataExchangeServerCall.GetNodesArrayForRegistrationAlwaysExport(ExchangePlanName, ORR.FlagAttributeName);
						
					#Else
						
						SetPrivilegedMode(True);
						Recipients = GetNodesArrayForRegistrationAlwaysExport(ExchangePlanName, ORR.FlagAttributeName);
						SetPrivilegedMode(False);
						
					#EndIf
					
					CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, Recipients);
					
					// DETERMINE RECEIVERS WITH THE "IF NEEDED" EXPORT MODE
					
					If Not Object.IsNew() Then
						
						#If ExternalConnection OR ThickClientOrdinaryApplication Then
							
							Recipients = DataExchangeServerCall.GetArrayOfNodesForRegistrationExportIfNeeded(Object.Ref, ExchangePlanName, ORR.FlagAttributeName);
							
						#Else
							
							SetPrivilegedMode(True);
							Recipients = GetArrayOfNodesForRegistrationExportIfNeeded(Object.Ref, ExchangePlanName, ORR.FlagAttributeName);
							SetPrivilegedMode(False);
							
						#EndIf
						
						CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, Recipients);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// It receives the array of the exchange plan nodes for which the check box "Always export" is selected.
//
// Parameters:
//  ExchangePlanName    - String - name of an exchange plan as metadata object according to which the nodes are defined.
//  FlagAttributeName - String - name of the exchange plan attribute according to which a filter of nodes selection is set.
//
// Returns:
//  Array - Exchange plan nodes array for which the "Always export» flag is set.
//
Function GetNodesArrayForRegistrationAlwaysExport(Val ExchangePlanName, Val FlagAttributeName) Export
	
	QueryText = "
	|SELECT
	|	ExchangePlanHeader.Ref AS Node
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
	|WHERE
	|	  ExchangePlanHeader.Ref <> &ThisNode
	|	AND ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectsExportModes.AlwaysExport)
	|	AND Not ExchangePlanHeader.DeletionMark
	|";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]",    ExchangePlanName);
	QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
	
	Query = New Query;
	Query.SetParameter("ThisNode", DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName));
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Node");
EndFunction

// It receives the array of the exchange plan nodes for which the "Export if necessary" flag is selected.
//
// Parameters:
//  Ref - IB object reference for which it is necessary to receive the node array where the object was previously exported.
//  ExchangePlanName    - String - name of an exchange plan as metadata object according to which the nodes are defined.
//  FlagAttributeName - String - name of the exchange plan attribute according to which a filter of nodes selection is set.
//
// Returns:
//  Array - Exchange plan node array for which the "Export if needed" flag is set.
//
Function GetArrayOfNodesForRegistrationExportIfNeeded(Ref, Val ExchangePlanName, Val FlagAttributeName) Export
	
	NodesArray = New Array;
	
	If DataExchangeReUse.ThisIsExchangePlanXDTO(ExchangePlanName) Then
		NodesArray = DataExchangeXDTOServer.NodesArrayForRegistrationExportIfNeeded(
			Ref, ExchangePlanName, FlagAttributeName);
	Else
		
		QueryText = "
		|SELECT DISTINCT
		|	ExchangePlanHeader.Ref AS Node
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
		|LEFT JOIN
		|	InformationRegister.InfobasesObjectsCompliance AS InfobasesObjectsCompliance
		|ON
		|	ExchangePlanHeader.Ref = InfobasesObjectsCompliance.InfobaseNode
		|	AND InfobasesObjectsCompliance.UniqueSourceHandle = &Object
		|WHERE
		|	     ExchangePlanHeader.Ref <> &ThisNode
		|	AND    ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectsExportModes.ExportIfNecessary)
		|	AND Not ExchangePlanHeader.DeletionMark
		|	AND    InfobasesObjectsCompliance.UniqueSourceHandle = &Object
		|";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]",    ExchangePlanName);
		QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
		
		Query = New Query;
		Query.Text = QueryText;
		Query.SetParameter("ThisNode", DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName));
		Query.SetParameter("Object",   Ref);
		
		NodesArray = Query.Execute().Unload().UnloadColumn("Node");
		
	EndIf;
	
	Return NodesArray;
	
EndFunction

Procedure ExecuteObjectRegistrationRuleForRecordSet(ArrayOfNodesResult,
															ORR,
															Object,
															MetadataObject,
															ExchangePlanName,
															Replacing,
															Exporting)
	
	// Define array of node-receivers by the current records set.
	DefineArrayOfRecipientsByRecordSet(ArrayOfNodesResult, Object, ORR, MetadataObject, ExchangePlanName, False, Exporting);
	
	If Replacing AND Not Exporting Then
		
		OldRecordSet = GetRecordSet(Object);
		
		// Define array of node-receivers by the old records set.
		DefineArrayOfRecipientsByRecordSet(ArrayOfNodesResult, OldRecordSet, ORR, MetadataObject, ExchangePlanName, True, False);
		
	EndIf;
	
EndProcedure

// Determines nodes list of the ExchangePlanName exchange plan receivers for which it is required to register the Object object according to ORR (universal part) for the subsequent export.
//
// Parameters:
//  ArrayOfNodesResult - Array - array of the ExchangePlan exchange
//   plan receivers node for which it is required to execute registration.
//  ORR - ValueTableRow - contains information about object registration rule for which procedure is executed.
//  Object - Arbitrary - changed data: object, records set, constant or information about object removal.
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  AdditionalParameters - Structure - clarifications on changed data:
//    * IsObjectDeletion - Boolean - the True value means that object removal is processed. IsRequired.
//    * WriteMode - see in the DocumentWritingMode syntax assistant - document writing mode (only for documents).
//                    IsRequired.
//    * CheckRef - Boolean - shows that it is required to consider data version at the time before their change.
//                                 IsRequired.
//    * Export - Boolean - parameter determines registration rule execution context.
//        True - registration rule is executed in the object export context.
//        False - registration rule is executed in the context before object writing. IsRequired.
//
Procedure ExecuteObjectRegistrationRuleForRefType(ArrayOfNodesResult,
															ORR,
															Object,
															ExchangePlanName,
															AdditionalParameters)
	
	ThisIsObjectDeletion = AdditionalParameters.ThisIsObjectDeletion;
	WriteMode = AdditionalParameters.WriteMode;
	CheckRef = AdditionalParameters.CheckRef;
	Exporting = AdditionalParameters.Export;
	
	// ORRO - Registration rules by Object properties.
	// ORRP - Registration rules by Exchange plan properties.
	// ORR = ORRO <AND> ORRP
	
	// ORRO
	If  Not ORR.RuleByObjectPropertiesEmpty
		AND Not ObjectPassedFilterOfRegistrationRulesByProperties(ORR, Object, CheckRef, WriteMode) Then
		
		Return;
		
	EndIf;
	
	// ORRP
	// determine nodes for object registration.
	DefineNodesArrayForObject(ArrayOfNodesResult, Object, ExchangePlanName, ORR, ThisIsObjectDeletion, CheckRef, Exporting);
	
EndProcedure

// Determines nodes list of the ExchangePlanName exchange plan receivers for which it is required to register the Object object according to ORR for the subsequent export.
//
// Parameters:
//  ArrayOfNodesResult - Array - array of the ExchangePlan exchange
//   plan receivers node for which it is required to execute registration.
//  ORR - ValueTableRow - contains information about object registration rule for which procedure is executed.
//  Object - Arbitrary - changed data: object, records set, constant or information about object removal.
//  ExchangePlanName - String - exchange plan name for which registration mechanism is executed.
//  AdditionalParameters - Structure - clarifications on changed data:
//    * MetadataObject - MetadataObject - metadata object to which changed data are matched. IsRequired.
//    * IsObjectDeletion - Boolean - the True value means that object removal is processed. IsRequired.
//    * WriteMode - see in the DocumentWritingMode syntax assistant - document writing mode (only for documents).
//                    IsRequired.
//    * CheckRef - Boolean - shows that it is required to consider data version at the time before their change.
//                                 IsRequired.
//    * Export - Boolean - parameter determines registration rule execution context.
//        True - registration rule is executed in the object export context.
//        False - registration rule is executed in the context before object writing. IsRequired.
//
Procedure DefineRecipientsByCondition(ArrayOfNodesResult, ORR, Object, ExchangePlanName, AdditionalParameters)
	
	MetadataObject = AdditionalParameters.MetadataObject;
	Exporting = AdditionalParameters.Export;
	
	// {Handler: Before data processor} Start.
	Cancel = False;
	
	ExecuteORRHandlerBeforeProcessing(ORR, Cancel, Object, MetadataObject, Exporting);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: Before data processor} End.
	
	Recipients = New Array;
	
	ExecuteObjectRegistrationRuleForRefType(Recipients, ORR, Object, ExchangePlanName, AdditionalParameters);
	
	// {Handler: After data processor} Start.
	Cancel = False;
	
	ExecuteORRHandlerAfterProcessing(ORR, Cancel, Object, MetadataObject, Recipients, Exporting);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: After data processor} End.
	
	CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, Recipients);
	
EndProcedure

Procedure DefineRecipientsByConditionForRecordSet(ArrayOfNodesResult,
														ORR,
														Object,
														MetadataObject,
														ExchangePlanName,
														Replacing,
														Exporting)
	
	// {Handler: Before data processor} Start.
	Cancel = False;
	
	ExecuteORRHandlerBeforeProcessing(ORR, Cancel, Object, MetadataObject, Exporting);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: Before data processor} End.
	
	Recipients = New Array;
	
	ExecuteObjectRegistrationRuleForRecordSet(Recipients, ORR, Object, MetadataObject, ExchangePlanName, Replacing, Exporting);
	
	// {Handler: After data processor} Start.
	Cancel = False;
	
	ExecuteORRHandlerAfterProcessing(ORR, Cancel, Object, MetadataObject, Recipients, Exporting);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: After data processor} End.
	
	CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, Recipients);
	
EndProcedure

Procedure DefineNodesArrayForObject(ArrayOfNodesResult,
										Source,
										ExchangePlanName,
										ORR,
										ThisIsObjectDeletion,
										CheckRef,
										Exporting)
	
	// Get the property values structure for object.
	ObjectPropertiesValues = GetPropertiesValuesForObject(Source, ORR);
	
	// Determine nodes array for object registration.
	NodesArray = DefineNodesArrayByPropertiesValues(ObjectPropertiesValues, ORR, ExchangePlanName, Source, Exporting);
	
	// Add nodes for registration.
	CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, NodesArray);
	
	If CheckRef Then
		
		// Get the property values structure for reference.
		#If ExternalConnection OR ThickClientOrdinaryApplication Then
			
			RefPropertiesValues = DataExchangeServerCall.GetPropertiesValuesForRef(Source.Ref, ORR.PropertiesOfObject, ORR.ObjectPropertiesString, ORR.MetadataObjectName);
			
		#Else
			
			SetPrivilegedMode(True);
			RefPropertiesValues = GetPropertiesValuesForRef(Source.Ref, ORR.PropertiesOfObject, ORR.ObjectPropertiesString, ORR.MetadataObjectName);
			SetPrivilegedMode(False);
			
		#EndIf
		
		// Determine nodes array for reference registration.
		NodesArray = DefineNodesArrayByPropertiesValuesAdditional(RefPropertiesValues, ORR, ExchangePlanName, Source);
		
		// Add nodes for registration.
		CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, NodesArray);
		
	EndIf;
	
EndProcedure

Procedure DefineArrayOfRecipientsByRecordSet(ArrayOfNodesResult,
													RecordSet,
													ORR,
													MetadataObject,
													ExchangePlanName,
													ThisIsObjectVersioningBeforeChange,
													Exporting)
	
	// Get the register value from filter for records set.
	Recorder = Undefined;
	
	FilterItem = RecordSet.Filter.Find("Recorder");
	
	HasRecorder = FilterItem <> Undefined;
	
	If HasRecorder Then
		
		Recorder = FilterItem.Value;
		
	EndIf;
	
	For Each SetRow IN RecordSet Do
		
		ORR_SetRows = CopyStructure(ORR);
		
		If HasRecorder AND SetRow["Recorder"] = Undefined Then
			
			If Recorder <> Undefined Then
				
				SetRow["Recorder"] = Recorder;
				
			EndIf;
			
		EndIf;
		
		// ORRO
		If Not ObjectPassedFilterOfRegistrationRulesByProperties(ORR_SetRows, SetRow, False) Then
			
			Continue;
			
		EndIf;
		
		// ORRP
		
		// Get the property values structure for object.
		ObjectPropertiesValues = GetPropertiesValuesForObject(SetRow, ORR_SetRows);
		
		If ThisIsObjectVersioningBeforeChange Then
			
			// Determine nodes array for object registration.
			NodesArray = DefineNodesArrayByPropertiesValuesAdditional(ObjectPropertiesValues,
				ORR_SetRows, ExchangePlanName, SetRow, RecordSet.AdditionalProperties);
			
		Else
			
			// Determine nodes array for object registration.
			NodesArray = DefineNodesArrayByPropertiesValues(ObjectPropertiesValues, ORR_SetRows,
				ExchangePlanName, SetRow, Exporting, RecordSet.AdditionalProperties);
			
		EndIf;
		
		// Add nodes for registration.
		CommonUse.FillArrayWithUniqueValues(ArrayOfNodesResult, NodesArray);
		
	EndDo;
	
EndProcedure

// It returns the structure with the object property values received using the IB request.
// Structure key - property name; Value - object property value.
//
// Parameters:
//  Ref - ref to the IB object which property values shall be received.
//
// Returns:
//  Structure - Structure with the object property values.
//
Function GetPropertiesValuesForRef(Ref, PropertiesOfObject, Val ObjectPropertiesString, Val MetadataObjectName) Export
	
	PropertyValues = CopyStructure(PropertiesOfObject);
	
	If PropertyValues.Count() = 0 Then
		
		Return PropertyValues; // Return an empty structure.
		
	EndIf;
	
	QueryText = "
	|SELECT
	|	[ObjectPropertiesString]
	|FROM
	|	[MetadataObjectName] AS Table
	|WHERE
	|	Table.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[ObjectPropertiesAsString]", ObjectPropertiesString);
	QueryText = StrReplace(QueryText, "[MetadataObjectName]",    MetadataObjectName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	
	Try
		
		Selection = Query.Execute().Select();
		
	Except
		MessageString = NStr("en = 'An error occurred while receiving reference properties. An error occurred while executing query: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", DetailErrorDescription(ErrorInfo()));
		Raise MessageString;
	EndTry;
	
	If Selection.Next() Then
		
		For Each Item IN PropertyValues Do
			
			PropertyValues[Item.Key] = Selection[Item.Key];
			
		EndDo;
		
	EndIf;
	
	Return PropertyValues;
EndFunction

Function DefineNodesArrayByPropertiesValues(PropertyValues, ORR, Val ExchangePlanName, Object, Val Exporting, AdditionalProperties = Undefined)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {Handler: During data processor} Start.
	Cancel = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("QueryText", QueryText);
	AdditionalParameters.Insert("QueryParameters", PropertyValues);
	AdditionalParameters.Insert("UseCache", UseCache);
	AdditionalParameters.Insert("Export", Exporting);
	AdditionalParameters.Insert("AdditionalProperties", AdditionalProperties);
	
	ExecuteORRHandlerOnProcessing(Cancel, ORR, Object, AdditionalParameters);
	
	QueryText = AdditionalParameters.QueryText;
	PropertyValues = AdditionalParameters.QueryParameters;
	UseCache = AdditionalParameters.UseCache;
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {Handler: During data processor} End.
	
	If UseCache Then
		
		Return DataExchangeReUse.NodesArrayByPropertiesValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, Exporting);
		
	Else
		
		#If ExternalConnection OR ThickClientOrdinaryApplication Then
			
			Return DataExchangeServerCall.NodesArrayByPropertiesValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, Exporting);
			
		#Else
			
			SetPrivilegedMode(True);
			Return NodesArrayByPropertiesValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, Exporting);
			
		#EndIf
		
	EndIf;
	
EndFunction

Function DefineNodesArrayByPropertiesValuesAdditional(PropertyValues, ORR, Val ExchangePlanName, Object, AdditionalProperties = Undefined)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {Handler: During data processor (additional)} Start.
	Cancel = False;
	
	ExecuteORRHandlerOnProcessingAdditional(Cancel, ORR, Object, QueryText, PropertyValues, UseCache, AdditionalProperties);
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {Handler: During data processor (additional)} End.
	
	If UseCache Then
		
		Return DataExchangeReUse.NodesArrayByPropertiesValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
		
	Else
		
		#If ExternalConnection OR ThickClientOrdinaryApplication Then
			
			Return DataExchangeServerCall.NodesArrayByPropertiesValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
			
		#Else
			
			SetPrivilegedMode(True);
			Return NodesArrayByPropertiesValues(PropertyValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
			
		#EndIf
		
	EndIf;
	
EndFunction

// It returns the array of exchange plan nodes by the specified request parameters and query text to the exchange plan table.
//
//
Function NodesArrayByPropertiesValues(PropertyValues, Val QueryText, Val ExchangePlanName, Val FlagAttributeName, Val Exporting = False) Export
	
	// Return value of the function.
	ArrayOfNodesResult = New Array;
	
	// Prepare a query for exchange plan nodes receipt.
	Query = New Query;
	
	QueryText = StrReplace(QueryText, "[MandatoryConditions]",
				"And    ExchangePlanMainTable.Ref <> &" + ExchangePlanName + "ThisNode
				|AND
				|NOT ExchangePlanMainTable.DeletionMark [FilterByAttributeCheckBoxCondition]
				|");
	//
	If IsBlankString(FlagAttributeName) Then
		
		QueryText = StrReplace(QueryText, "[FilterByAttributeCheckBoxCondition]", "");
		
	Else
		
		If Exporting Then
			QueryText = StrReplace(QueryText, "[FilterByAttributeCheckBoxCondition]",
				"And (ExchangePlanMainTable.[CheckBoxAttributeName] = VALUE(Enumeration.ExchangeObjectsExportModes.ExportByCondition) OR ExchangePlanMainTable.[CheckBoxAttributeName] = VALUE(Enumeration.ExchangeObjectsExportModes.ExportManually) OR ExchangePlanMainTable.[CheckBoxAttributeName] = VALUE(Enumeration.ExchangeObjectsExportModes.EmptyRef))"
			);
		Else
			QueryText = StrReplace(QueryText, "[FilterByAttributeCheckBoxCondition]",
				"AND (ExchangePlanMainTable.[CheckBoxAttributeName] = VALUE(Enumeration.ExchangeObjectsExportModes.ExportByCondition) OR ExchangePlanMainTable.[CheckBoxAttributeName] = VALUE(Enumeration.ExchangeObjectsExportModes.EmptyRef))"
			);
		EndIf;
		
		QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
		
	EndIf;
	
	// query text
	Query.Text = QueryText;
	
	Query.SetParameter(ExchangePlanName + "ThisNode", DataExchangeReUse.GetThisNodeOfExchangePlan(ExchangePlanName));
	
	// Specify query parameters value from object properties.
	For Each Item IN PropertyValues Do
		
		Query.SetParameter("ObjectProperty_" + Item.Key, Item.Value);
		
	EndDo;
	
	Try
		
		ArrayOfNodesResult = Query.Execute().Unload().UnloadColumn("Ref");
		
	Except
		MessageString = NStr("en = 'An error occurred while getting receiver nodes list. An error occurred while executing query: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", DetailErrorDescription(ErrorInfo()));
		Raise MessageString;
	EndTry;
	
	Return ArrayOfNodesResult;
EndFunction

Function GetPropertiesValuesForObject(Object, ORR)
	
	PropertyValues = New Structure;
	
	For Each Item IN ORR.PropertiesOfObject Do
		
		PropertyValues.Insert(Item.Key, GetObjectPropertyValue(Object, Item.Value));
		
	EndDo;
	
	Return PropertyValues;
	
EndFunction

Function GetObjectPropertyValue(Object, ObjectPropertyString)
	
	Value = Object;
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ObjectPropertyString, ".");
	
	// Get value considering possible property dereference.
	For Each PropertyName IN SubstringArray Do
		
		Value = Value[PropertyName];
		
	EndDo;
	
	Return Value;
	
EndFunction

// Only for internal use.
//
Function ExchangePlanObjectChangeRecordRules(Val ExchangePlanName) Export
	
	Return DataExchangeReUse.ExchangePlanObjectChangeRecordRules(ExchangePlanName);
	
EndFunction

// Only for internal use.
//
Function ObjectChangeRecordRules(Val ExchangePlanName, Val FullObjectName) Export
	
	Return DataExchangeReUse.ObjectChangeRecordRules(ExchangePlanName, FullObjectName);
	
EndFunction

Function ChangeRecordRuleStructure(Rule, Columns)
	
	Result = New Structure;
	
	For Each Column IN Columns Do
		
		Key = Column.Name;
		Value = Rule[Key];
		
		If TypeOf(Value) = Type("ValueTable") Then
			
			Result.Insert(Key, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("ValueTree") Then
			
			Result.Insert(Key, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("Structure") Then
			
			Result.Insert(Key, CopyStructure(Value));
			
		Else
			
			Result.Insert(Key, Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function SeparatedExchangePlan(Val ExchangePlanName)
	
	Return CommonUseReUse.IsSeparatedMetadataObject(
		"ExchangePlan." + ExchangePlanName,
		CommonUseReUse.MainDataSeparator());
	
EndFunction

Function SeparatedData(MetadataObject)
	
	Return CommonUseReUse.IsSeparatedMetadataObject(
		MetadataObject.FullName(),
		CommonUseReUse.MainDataSeparator());
	
EndFunction

// Creates records set for register.
//
// Parameters:
// register MetadataObject - to receive records set.
//
// Returns:
// RecordSet. If metadata object does not have a records
// set, an exception is thrown.
//
Function RecordSetByType(MetadataObject)
	
	BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
	
	If BaseTypeName = CommonUse.TypeNameInformationRegisters() Then
		
		Result = InformationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.TypeNameAccumulationRegisters() Then
		
		Result = AccumulationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.TypeNameOfAccountingRegisters() Then
		
		Result = AccountingRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.NameKindCalculationRegisters() Then
		
		Result = CalculationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.TypeNameSequences() Then
		
		Result = Sequences[MetadataObject.Name].CreateRecordSet();
		
	ElsIf BaseTypeName = CommonUse.TypeNameRecalculations() Then
		
		Result = CalculationRegisters[MetadataObject.Parent().Name].Recalculations[MetadataObject.Name].CreateRecordSet();
		
	Else
		
		MessageString = NStr("en = 'For the metadata object %1 the records set is not provided.'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, MetadataObject.FullName());
		Raise MessageString;
		
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Registration rules by object properties.

Procedure FillPropertyValuesFromObject(ValueTree, Object)
	
	For Each TreeRow IN ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			FillPropertyValuesFromObject(TreeRow, Object);
			
		Else
			
			TreeRow.PropertyValue = GetObjectPropertyValue(Object, TreeRow.ObjectProperty);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CreateValidFilterByProperties(Object, TargetValueTree, SourceValueTree)
	
	For Each SourceTreeRow IN SourceValueTree.Rows Do
		
		If SourceTreeRow.IsFolder Then
			
			TargetTreeRow = TargetValueTree.Rows.Add();
			
			FillPropertyValues(TargetTreeRow, SourceTreeRow);
			
			CreateValidFilterByProperties(Object, TargetTreeRow, SourceTreeRow);
			
		Else
			
			If ChainPropertiesIsValid(Object, SourceTreeRow.ObjectProperty) Then
				
				TargetTreeRow = TargetValueTree.Rows.Add();
				
				FillPropertyValues(TargetTreeRow, SourceTreeRow);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Designed to get constants values that are calculated according to random expressions.
// Values are calculated in the exclusive mode.
//
Procedure GetValuesOfConstantAlgorithms(ORR, ValueTree)
	
	For Each TreeRow IN ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			GetValuesOfConstantAlgorithms(ORR, TreeRow);
			
		Else
			
			If TreeRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				Value = Undefined;
				
				Try
					
					#If ExternalConnection OR ThickClientOrdinaryApplication Then
						
						DataExchangeServerCall.ExecuteHandlerInPrivilegedMode(Value, TreeRow.ConstantValue);
						
					#Else
						
						SetPrivilegedMode(True);
						Execute(TreeRow.ConstantValue);
						SetPrivilegedMode(False);
						
					#EndIf
					
				Except
					
					MessageString = NStr("en = 'An error occurred while
												|calculating constant value:
												|Exchange plan: [ExchangePlanName]
												|Metadata object: [MetadataObjectName]
												|Error
												|description: [Description] Algorithm:
												|//
												|{Algorithm start} [ConstantValue] // {Algorithm end}
												|'");
					MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
					MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
					MessageString = StrReplace(MessageString, "[Definition]",            ErrorInfo().Definition);
					MessageString = StrReplace(MessageString, "[ConstantValue]",   String(TreeRow.ConstantValue));
					
					Raise MessageString;
					
				EndTry;
				
				TreeRow.ConstantValue = Value;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ChainPropertiesIsValid(Object, Val ObjectPropertyString)
	
	Value = Object;
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ObjectPropertyString, ".");
	
	// Get value considering possible property dereference.
	For Each PropertyName IN SubstringArray Do
		
		Try
			Value = Value[PropertyName];
		Except
			Return False;
		EndTry;
		
	EndDo;
	
	Return True;
EndFunction

// Execute ORRO for reference and exchange.
// Consider result by the "OR" condition.
// If object was filtered by ORRO by values
// from ref, do not execute ORRO for object values.
//
Function ObjectPassedFilterOfRegistrationRulesByProperties(ORR, Object, CheckRef, WriteMode = Undefined)
	
	PostedPropertyInitialValue = Undefined;
	
	GetValuesOfConstantAlgorithms(ORR, ORR.FilterByObjectProperties);
	
	If WriteMode <> Undefined Then
		
		PostedPropertyInitialValue = Object.Posted;
		
		If WriteMode = DocumentWriteMode.UndoPosting Then
			
			Object.Posted = False;
			
		ElsIf WriteMode = DocumentWriteMode.Posting Then
			
			Object.Posted = True;
			
		EndIf;
		
	EndIf;
	
	// ORRO by Object properties value.
	If ObjectPassingOBRRFilter(ORR, Object) Then
		
		If PostedPropertyInitialValue <> Undefined Then
			
			Object.Posted = PostedPropertyInitialValue;
			
		EndIf;
		
		Return True;
		
	EndIf;
	
	If PostedPropertyInitialValue <> Undefined Then
		
		Object.Posted = PostedPropertyInitialValue;
		
	EndIf;
	
	If CheckRef Then
		
		// ORRO by Reference properties value.
		If ObjectPassingOBRRFilter(ORR, Object.Ref) Then
			
			Return True;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

Function ObjectPassingOBRRFilter(ORR, Object)
	
	ORR.FilterByProperties = DataProcessors.ObjectRegistrationRulesImport.FilterByObjectPropertiesTableInitialization();
	
	CreateValidFilterByProperties(Object, ORR.FilterByProperties, ORR.FilterByObjectProperties);
	
	FillPropertyValuesFromObject(ORR.FilterByProperties, Object);
	
	Return ConditionIsTrueForValueTreeBranch(ORR.FilterByProperties);
	
EndFunction

// By default consider that items of root group filter are compared by the "AND" condition.
// That is why the IsOperatorAnd default parameter takes the True value.
//
Function ConditionIsTrueForValueTreeBranch(ValueTree, Val IsAndOperator = True)
	
	// initializing
	If IsAndOperator Then // AND
		Result = True;
	Else // OR
		Result = False;
	EndIf;
	
	For Each TreeRow IN ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			ItemResult = ConditionIsTrueForValueTreeBranch(TreeRow, TreeRow.IsAndOperator);
		Else
			
			ItemResult = ConditionIsTrueForItem(TreeRow, IsAndOperator);
		EndIf;
		
		If IsAndOperator Then // AND
			
			Result = Result AND ItemResult;
			
			If Not Result Then
				Return False;
			EndIf;
			
		Else // OR
			
			Result = Result OR ItemResult;
			
			If Result Then
				Return True;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function ConditionIsTrueForItem(TreeRow, IsAndOperator)
	
	Var ComparisonType;
	
	ComparisonType = TreeRow.ComparisonType;
	
	Try
		
		If      ComparisonType = "Equal"          Then Return TreeRow.PropertyValue =  TreeRow.ConstantValue;
		ElsIf ComparisonType = "NotEqual"        Then Return TreeRow.PropertyValue <> TreeRow.ConstantValue;
		ElsIf ComparisonType = "Greater"         Then Return TreeRow.PropertyValue >  TreeRow.ConstantValue;
		ElsIf ComparisonType = "GreaterOrEqual" Then Return TreeRow.PropertyValue >= TreeRow.ConstantValue;
		ElsIf ComparisonType = "Less"         Then Return TreeRow.PropertyValue <  TreeRow.ConstantValue;
		ElsIf ComparisonType = "LessOrEqual" Then Return TreeRow.PropertyValue <= TreeRow.ConstantValue;
		EndIf;
		
	Except
		
		Return False;
		
	EndTry;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Events of objects registration rules (ORR events).

Procedure ExecuteORRHandlerBeforeProcessing(ORR, Cancel, Object, MetadataObject, Val Exporting)
	
	If ORR.HasBeforeProcessHandler Then
		
		Try
			Execute(ORR.BeforeProcess);
		Except
			MessageString = NStr("en = 'An error occurred while executing handler: ""[HandlerName]"";
				|Exchange plan: [ExchangePlanName];
				|Metadata object: [MetadataObjectName]
				|Error description: [Description]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'Before processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Definition]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcessing(Cancel, ORR, Object, AdditionalParameters)
	
	QueryText = AdditionalParameters.QueryText;
	QueryParameters = AdditionalParameters.QueryParameters;
	UseCache = AdditionalParameters.UseCache;
	Exporting = AdditionalParameters.Export;
	AdditionalProperties = AdditionalParameters.AdditionalProperties;
	
	If ORR.HasOnProcessHandler Then
		
		Try
			Execute(ORR.OnProcess);
		Except
			MessageString = NStr("en = 'An error occurred while executing handler: ""[HandlerName]""; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName] Error description: [Description]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'On processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Definition]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
	AdditionalParameters.QueryText = QueryText;
	AdditionalParameters.QueryParameters = QueryParameters;
	AdditionalParameters.UseCache = UseCache;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcessingAdditional(Cancel, ORR, Object, QueryText, QueryParameters, UseCache, AdditionalProperties = Undefined)
	
	If ORR.HasOnProcessHandlerAdditional Then
		
		Try
			Execute(ORR.OnProcessAdditional);
		Except
			MessageString = NStr("en = 'An error occurred while executing handler: ""[HandlerName]""; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName] Error description: [Description]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'When processing (additional)'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Definition]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerAfterProcessing(ORR, Cancel, Object, MetadataObject, Recipients, Val Exporting)
	
	If ORR.HasAfterProcessHandler Then
		
		Try
			Execute(ORR.AfterProcessing);
		Except
			MessageString = NStr("en = 'An error occurred while executing handler: ""[HandlerName]""; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName] Error description: [Description]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("en = 'After processing'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Definition]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Procedure OnDataSending(DataItem, ItemSend, Val Recipient, Val CreatingInitialImage, Val Analysis)
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		Return;
	EndIf;
	
	// Check whether object registration mechanism cache is relevant.
	DataExchangeServerCall.CheckObjectRegistrationMechanismCache();
	
	ObjectExportMode = DataExchangeReUse.ObjectExportMode(DataItem.Metadata().FullName(), Recipient);
	
	If ObjectExportMode = Enums.ExchangeObjectsExportModes.AlwaysExport Then
		
		// Export data item
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition
		OR ObjectExportMode = Enums.ExchangeObjectsExportModes.ExportIfNecessary Then
		
		If Not DataMapFilterRegesteringRules(DataItem, Recipient) Then
			
			If CreatingInitialImage Then
				
				ItemSend = DataItemSend.Ignore;
				
			Else
				
				ItemSend = DataItemSend.Delete;
				
			EndIf;
			
		EndIf;
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectsExportModes.ExportManually Then
		
		If CreatingInitialImage Then
			
			ItemSend = DataItemSend.Ignore;
			
		Else
			
			If DataMapFilterRegesteringRules(DataItem, Recipient) Then
				
				If Not Analysis Then
					
					// Delete data changes registration exported manually.
					ExchangePlans.DeleteChangeRecords(Recipient, DataItem);
					
				EndIf;
				
			Else
				
				ItemSend = DataItemSend.Ignore;
				
			EndIf;
			
		EndIf;
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectsExportModes.DoNotExport Then
		
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

Function DataMapFilterRegesteringRules(DataItem, Val Recipient)
	
	Result = True;
	
	ExchangePlanName = Recipient.Metadata().Name;
	
	MetadataObject = DataItem.Metadata();
	
	BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
	
	If    BaseTypeName = CommonUse.TypeNameCatalogs()
		OR BaseTypeName = CommonUse.TypeNameDocuments()
		OR BaseTypeName = CommonUse.TypeNameChartsOfCharacteristicTypes()
		OR BaseTypeName = CommonUse.TypeNameChartsOfAccounts()
		OR BaseTypeName = CommonUse.TypeNameChartsOfCalculationTypes()
		OR BaseTypeName = CommonUse.BusinessProcessTypeName()
		OR BaseTypeName = CommonUse.TypeNameTasks() Then
		
		// Determine nodes array for object registration.
		NodeArrayForObjectChangeRecord = New Array;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("MetadataObject", MetadataObject);
		AdditionalParameters.Insert("Export", True);
		ExecuteObjectRegistrationRulesForExchangePlans(NodeArrayForObjectChangeRecord,
														DataItem,
														ExchangePlanName,
														AdditionalParameters);
		//
		
		// If there is no current node, send object removal.
		If NodeArrayForObjectChangeRecord.Find(Recipient) = Undefined Then
			
			Result = False;
			
		EndIf;
		
	ElsIf BaseTypeName = CommonUse.TypeNameInformationRegisters()
		OR BaseTypeName = CommonUse.TypeNameAccumulationRegisters()
		OR BaseTypeName = CommonUse.TypeNameOfAccountingRegisters()
		OR BaseTypeName = CommonUse.NameKindCalculationRegisters() Then
		
		ExcludingProperties = ?(BaseTypeName = CommonUse.TypeNameAccumulationRegisters(), "RecordType", "");
		
		DataForChecking = RecordSetByType(MetadataObject);
		
		For Each FilterItemSource IN DataItem.Filter Do
			
			FilterItemReceiver = DataForChecking.Filter.Find(FilterItemSource.Name);
			
			FillPropertyValues(FilterItemReceiver, FilterItemSource);
			
		EndDo;
		
		DataForChecking.Add();
		
		ReverseIndex = DataItem.Count() - 1;
		
		While ReverseIndex >= 0 Do
			
			FillPropertyValues(DataForChecking[0], DataItem[ReverseIndex],, ExcludingProperties);
			
			// Determine nodes array for object registration.
			NodeArrayForObjectChangeRecord = New Array;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("MetadataObject", MetadataObject);
			AdditionalParameters.Insert("ThisIsRegister", True);
			AdditionalParameters.Insert("Export", True);
			ExecuteObjectRegistrationRulesForExchangePlans(NodeArrayForObjectChangeRecord,
															DataForChecking,
															ExchangePlanName,
															AdditionalParameters);
			
			// If there is no current node, delete string from set.
			If NodeArrayForObjectChangeRecord.Find(Recipient) = Undefined Then
				
				DataItem.Delete(ReverseIndex);
				
			EndIf;
			
			ReverseIndex = ReverseIndex - 1;
			
		EndDo;
		
		If DataItem.Count() = 0 Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Fills in attributes and tabular sections values of infobase objects of the same type.
//
// Parameters:
//  Source - Infobase object (Catalog, DocumentObject, CharacteristicKindsPlanObject
//   etc) that is a data source for filling.
//
//  Receiver (mandatory) - infobase object (Catalog, DocumentObject,
//  CharacteristicKindsPlanObject etc) that will be filled in with source data.
//
//  PropertyList - String - Properties list of object and tabular sections separated by commas.
//                           If parameter is specified, then object properties
//                           are filled in according to the specified properties and the parameter.
//                           ExcludingProperties will be ignored.
//
//  ExcludingProperties - String -  Properties list of object and tabular sections separated by commas.
//                           If parameter is specified, then object properties are
//                           filled for all properties and tabular sections excluding specified properties.
//
Procedure FillObjectPropertiesValues(Receiver, Source, Val PropertyList = Undefined, Val ExcludingProperties = Undefined) Export
	
	If PropertyList <> Undefined Then
		
		PropertyList = StrReplace(PropertyList, " ", "");
		
		PropertyList = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(PropertyList);
		
		MetadataObject = Receiver.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		HeaderPropertyList = New Array;
		UsedTabularSections = New Array;
		
		For Each Property IN PropertyList Do
			
			If TabularSections.Find(Property) <> Undefined Then
				
				UsedTabularSections.Add(Property);
				
			Else
				
				HeaderPropertyList.Add(Property);
				
			EndIf;
			
		EndDo;
		
		HeaderPropertyList = StringFunctionsClientServer.RowFromArraySubrows(HeaderPropertyList);
		
		FillPropertyValues(Receiver, Source, HeaderPropertyList);
		
		For Each TabularSection IN UsedTabularSections Do
			
			Receiver[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	ElsIf ExcludingProperties <> Undefined Then
		
		FillPropertyValues(Receiver, Source,, ExcludingProperties);
		
		MetadataObject = Receiver.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		For Each TabularSection IN TabularSections Do
			
			If Find(ExcludingProperties, TabularSection) <> 0 Then
				Continue;
			EndIf;
			
			Receiver[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	Else
		
		FillPropertyValues(Receiver, Source);
		
		MetadataObject = Receiver.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		For Each TabularSection IN TabularSections Do
			
			Receiver[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExecuteRefTypeObjectsRegistrationByNodeProperties(Object, ReferenceTypeAttributeTable)
	
	InfobaseNode = Object.Ref;
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	
	For Each TableRow IN ReferenceTypeAttributeTable Do
		
		If IsBlankString(TableRow.TabularSectionName) Then // header attributes
			
			For Each Item IN TableRow.ChangeRecordAttributeStructure Do
				
				Ref = Object[Item.Key];
				
				If Not Ref.IsEmpty()
					AND ExchangePlanContentContainsType(ExchangePlanName, TypeOf(Ref)) Then
					
					ExchangePlans.RecordChanges(InfobaseNode, Ref);
					
				EndIf;
				
			EndDo;
			
		Else // tabular section attributes
			
			TabularSection = Object[TableRow.TabularSectionName];
			
			For Each TabularSectionRow IN TabularSection Do
				
				For Each Item IN TableRow.ChangeRecordAttributeStructure Do
					
					Ref = TabularSectionRow[Item.Key];
					
					If Not Ref.IsEmpty()
						AND ExchangePlanContentContainsType(ExchangePlanName, TypeOf(Ref)) Then
						
						ExchangePlans.RecordChanges(InfobaseNode, Ref);
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetRefTypeObjectAttributes(Object, ExchangePlanName)
	
	// Initialize table.
	Result = DataExchangeServer.ObjectSelectiveRegistrationRulesTableInitialization();
	
	MetadataObject = Object.Metadata();
	MetadataObjectFullName = MetadataObject.FullName();
	
	// Get header attributes
	Attributes = GetRefTypeAttributes(MetadataObject.Attributes, ExchangePlanName);
	
	If Attributes.Count() > 0 Then
		
		TableRow = Result.Add();
		TableRow.ObjectName                     = MetadataObjectFullName;
		TableRow.TabularSectionName              = "";
		TableRow.ChangeRecordAttributes           = StructureKeysToString(Attributes);
		TableRow.ChangeRecordAttributeStructure = CopyStructure(Attributes);
		
	EndIf;
	
	// Get tabular sections attributes.
	For Each TabularSection IN MetadataObject.TabularSections Do
		
		Attributes = GetRefTypeAttributes(TabularSection.Attributes, ExchangePlanName);
		
		If Attributes.Count() > 0 Then
			
			TableRow = Result.Add();
			TableRow.ObjectName                     = MetadataObjectFullName;
			TableRow.TabularSectionName              = TabularSection.Name;
			TableRow.ChangeRecordAttributes           = StructureKeysToString(Attributes);
			TableRow.ChangeRecordAttributeStructure = CopyStructure(Attributes);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function GetRefTypeAttributes(Attributes, ExchangePlanName)
	
	// Return value of the function.
	Result = New Structure;
	
	For Each Attribute IN Attributes Do
		
		TypeArray = Attribute.Type.Types();
		
		IsReference = False;
		
		For Each Type IN TypeArray Do
			
			If  CommonUse.IsReference(Type)
				AND ExchangePlanContentContainsType(ExchangePlanName, Type) Then
				
				IsReference = True;
				
				Break;
				
			EndIf;
			
		EndDo;
		
		If IsReference Then
			
			Result.Insert(Attribute.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function ExchangePlanContentContainsType(ExchangePlanName, Type)
	
	Return Metadata.ExchangePlans[ExchangePlanName].Content.Contains(Metadata.FindByType(Type));
	
EndFunction

Procedure ProcessRegistrationRulesError(ExchangePlanName)
	
	If InfobaseUpdate.InfobaseUpdateInProgress()
		AND InformationRegisters.DataExchangeRules.RulesFromFileUsed(ExchangePlanName) Then
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString("DataExchange=%1", ExchangePlanName);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Creates Structure object new instance, fills in object with the specified structure data.
//
// Parameters:
//  SourceStructure - Structure - structure which copy should be received.
//
// Returns:
//  Structure - passed structure copy.
//
Function CopyStructure(SourceStructure) Export
	
	ResultStructure = New Structure;
	
	For Each Item IN SourceStructure Do
		
		If TypeOf(Item.Value) = Type("ValueTable") Then
			
			ResultStructure.Insert(Item.Key, Item.Value.Copy());
			
		ElsIf TypeOf(Item.Value) = Type("ValueTree") Then
			
			ResultStructure.Insert(Item.Key, Item.Value.Copy());
			
		ElsIf TypeOf(Item.Value) = Type("Structure") Then
			
			ResultStructure.Insert(Item.Key, CopyStructure(Item.Value));
			
		ElsIf TypeOf(Item.Value) = Type("ValueList") Then
			
			ResultStructure.Insert(Item.Key, Item.Value.Copy());
			
		Else
			
			ResultStructure.Insert(Item.Key, Item.Value);
			
		EndIf;
		
	EndDo;
	
	Return ResultStructure;
EndFunction

// Receives a row containing structure keys separated by the separator character.
//
// Parameters:
// Structure - Structure - Structure keys of which are converted to row.
// Delimiter - String - Separator that is input to row between structure keys.
//
// Returns:
// String - String containing structure keys separated by a separator.
//
Function StructureKeysToString(Structure, Delimiter = ",") Export
	
	Result = "";
	
	For Each Item IN Structure Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Delimiter);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
EndFunction

// Compares versions of two object versions of the same type.
//
// Parameters:
//  Data1 - CatalogObject,
//            DocumentObject,
//            ChartOfCharacteristicTypesObject,
//            ChartOfCalculationTypesObject,
//            ChartOfAccountsObject,
//            ExchangePlanObject,
//            BusinessProcessObject,
//            TaskObject - The first data version for comparison.
//  Data2 - CatalogObject,
//            DocumentObject,
//            ChartOfCharacteristicTypesObject,
//            ChartOfCalculationTypesObject,
//            ChartOfAccountsObject,
//            ExchangePlanObject,
//            BusinessProcessObject,
//            TaskObject - The second data version for comparison.
//  PropertyList - String - Properties list of object and tabular sections separated by commas.
//                           If parameter is specified, then object properties
//                           are filled in according to the specified properties and the parameter.
//                           ExcludingProperties will be ignored.
//  ExcludingProperties - String -  Properties list of object and tabular sections separated by commas.
//                           If parameter is specified, then object properties are
//                           filled for all properties and tabular sections excluding specified properties.
//
// Returns:
//  True - if data versions differ, otherwise, False.
//
Function DataDifferent(Data1, Data2, PropertyList = Undefined, ExcludingProperties = Undefined) Export
	
	If TypeOf(Data1) <> TypeOf(Data2) Then
		Return True;
	EndIf;
	
	MetadataObject = Data1.Metadata();
	
	If CommonUse.ThisIsCatalog(MetadataObject) Then
		
		If Data1.IsFolder Then
			Object1 = Catalogs[MetadataObject.Name].CreateFolder();
		Else
			Object1 = Catalogs[MetadataObject.Name].CreateItem();
		EndIf;
		
		If Data2.IsFolder Then
			Object2 = Catalogs[MetadataObject.Name].CreateFolder();
		Else
			Object2 = Catalogs[MetadataObject.Name].CreateItem();
		EndIf;
		
	ElsIf CommonUse.ThisIsDocument(MetadataObject) Then
		
		Object1 = Documents[MetadataObject.Name].CreateDocument();
		Object2 = Documents[MetadataObject.Name].CreateDocument();
		
	ElsIf CommonUse.ThisIsChartOfCharacteristicTypes(MetadataObject) Then
		
		If Data1.IsFolder Then
			Object1 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateFolder();
		Else
			Object1 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateItem();
		EndIf;
		
		If Data2.IsFolder Then
			Object2 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateFolder();
		Else
			Object2 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateItem();
		EndIf;
		
	ElsIf CommonUse.ThisIsChartOfCalculationTypes(MetadataObject) Then
		
		Object1 = ChartsOfCalculationTypes[MetadataObject.Name].CreateCalculationType();
		Object2 = ChartsOfCalculationTypes[MetadataObject.Name].CreateCalculationType();
		
	ElsIf CommonUse.ThisIsChartOfAccounts(MetadataObject) Then
		
		Object1 = ChartsOfAccounts[MetadataObject.Name].CreateAccount();
		Object2 = ChartsOfAccounts[MetadataObject.Name].CreateAccount();
		
	ElsIf CommonUse.ThisIsExchangePlan(MetadataObject) Then
		
		Object1 = ExchangePlans[MetadataObject.Name].CreateNode();
		Object2 = ExchangePlans[MetadataObject.Name].CreateNode();
		
	ElsIf CommonUse.ThisIsBusinessProcess(MetadataObject) Then
		
		Object1 = BusinessProcesses[MetadataObject.Name].CreateBusinessProcess();
		Object2 = BusinessProcesses[MetadataObject.Name].CreateBusinessProcess();
		
	ElsIf CommonUse.ThisIsTask(MetadataObject) Then
		
		Object1 = Tasks[MetadataObject.Name].CreateTask();
		Object2 = Tasks[MetadataObject.Name].CreateTask();
		
	Else
		
		Raise NStr("en = 'Invalid parameter value is specified [1] of the CommonUse method.PropertyValuesChanged.'");
		
	EndIf;
	
	FillObjectPropertiesValues(Object1, Data1, PropertyList, ExcludingProperties);
	FillObjectPropertiesValues(Object2, Data2, PropertyList, ExcludingProperties);
	
	Return InfobaseDataRow(Object1) <> InfobaseDataRow(Object2);
	
EndFunction

Function InfobaseDataRow(Data)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	WriteXML(XMLWriter, Data, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();
	
EndFunction

// Returns object tabular sections array.
//
Function ObjectTabularSections(MetadataObject) Export
	
	Result = New Array;
	
	For Each TabularSection IN MetadataObject.TabularSections Do
		
		Result.Add(TabularSection.Name);
		
	EndDo;
	
	Return Result;
EndFunction

//

// Only for internal use.
//
Procedure SetValuesOfFiltersAtNode(ExchangePlanNode, Settings) Export
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	SetValuesOnNode(ExchangePlanNode, Settings);
	
EndProcedure

// Only for internal use.
//
Procedure SetDefaultValuesAtNode(ExchangePlanNode, Settings) Export
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	SetValuesOnNode(ExchangePlanNode, Settings);
	
EndProcedure

Procedure SetValuesOnNode(ExchangePlanNode, Settings)
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	For Each Item IN Settings Do
		
		Key = Item.Key;
		Value = Item.Value;
		
		If ExchangePlanNode.Metadata().Attributes.Find(Key) = Undefined
			AND ExchangePlanNode.Metadata().TabularSections.Find(Key) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(Value) = Type("Array") Then
			
			AttributeData = GetReferenceTypeFromFirstExchangePlanTabularSectionAttribute(ExchangePlanName, Key);
			
			If AttributeData = Undefined Then
				Continue;
			EndIf;
			
			NodeTable = ExchangePlanNode[Key];
			
			NodeTable.Clear();
			
			For Each TableRow IN Value Do
				
				If TableRow.Use Then
					
					ObjectManager = CommonUse.ObjectManagerByRef(AttributeData.Type.AdjustValue());
					
					AttributeValue = ObjectManager.GetRef(New UUID(TableRow.RefUUID));
					
					NodeTable.Add()[AttributeData.Name] = AttributeValue;
					
				EndIf;
				
			EndDo;
			
		ElsIf TypeOf(Value) = Type("Structure") Then
			
			FillExchangePlanNodeTable(ExchangePlanNode, Value, Key);
			
		Else // primitive types
			
			ExchangePlanNode[Key] = Value;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillExchangePlanNodeTable(Node, TabularSectionStructure, TableName)
	
	NodeTable = Node[TableName];
	
	NodeTable.Clear();
	
	For Each Item IN TabularSectionStructure Do
		
		SetTableRowQuantity(NodeTable, Item.Value.Count());
		
		NodeTable.LoadColumn(Item.Value, Item.Key);
		
	EndDo;
	
EndProcedure

Procedure SetTableRowQuantity(Table, LineCount)
	
	While Table.Count() < LineCount Do
		
		Table.Add();
		
	EndDo;
	
EndProcedure

Function GetReferenceTypeFromFirstExchangePlanTabularSectionAttribute(Val ExchangePlanName, Val TabularSectionName)
	
	TabularSection = Metadata.ExchangePlans[ExchangePlanName].TabularSections[TabularSectionName];
	
	For Each Attribute IN TabularSection.Attributes Do
		
		Type = Attribute.Type.Types()[0];
		
		If CommonUse.IsReference(Type) Then
			
			Return New Structure("Name, Type", Attribute.Name, Attribute.Type);
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
EndFunction

Procedure CheckDocumentProblemSolvingPosting(Source, Cancel, PostingMode) Export
	
	InformationRegisters.DataExchangeResults.RegisterProblemSolving(Source, Enums.DataExchangeProblemTypes.UnpostedDocument);
	
EndProcedure

Procedure CheckObjectProblemSolvingOnWrite(Source, Cancel) Export
	
	InformationRegisters.DataExchangeResults.RegisterProblemSolving(Source, Enums.DataExchangeProblemTypes.BlankAttributes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with collisions of data changes during exchange.

// Checks whether there are
// collisions during import and gives information on whether there is a collisions during exchange.
Procedure ValidateDataChangeConflicts(DataItem, ItemReceive, Val Sender, Val IsAcceptFromMain)
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		
		Return;
		
	ElsIf DataItem.AdditionalProperties.Property("DataExchange") AND DataItem.AdditionalProperties.DataExchange.DataAnalysis Then
		
		Return;
		
	EndIf;
	
	Sender = Sender.Ref;
	ObjectMetadata = DataItem.Metadata();
	IsReferenceType = CommonUse.ThisIsObjectOfReferentialType(ObjectMetadata);
	
	HasCollision = ExchangePlans.IsChangeRecorded(Sender, DataItem);
	
	// Additionally check whether an object
	// is changed if the object is not changed before
	// and after collision, consider that there is no collision.
	If HasCollision Then
		
		If IsReferenceType AND Not DataItem.Ref.IsEmpty() Then
			
			ObjectInDataBase = DataItem.Ref.GetObject();
			RefExists = (ObjectInDataBase <> Undefined);
			
		Else
			RefExists = False;
			ObjectInDataBase = Undefined;
		EndIf;
		
		ObjectRowBeforeChange    = GetDataObjectAsStringBeforeChange(DataItem, ObjectMetadata, IsReferenceType, RefExists, ObjectInDataBase);
		ObjectRowAfterChange = GetDataObjectAsStringAfterChange(DataItem, ObjectMetadata);
		
		// If values match, there is no collision.
		If ObjectRowBeforeChange = ObjectRowAfterChange Then
			
			HasCollision = False;
			
		EndIf;
		
	EndIf;
	
	If HasCollision Then
		
		DataExchangeOverridable.OnCollisionOfDataChange(DataItem, ItemReceive, Sender, IsAcceptFromMain);
		
		If ItemReceive = DataItemReceive.Auto Then
			ItemReceive = ?(IsAcceptFromMain, DataItemReceive.Accept, DataItemReceive.Ignore);
		EndIf;
		
		WriteObject = (ItemReceive = DataItemReceive.Accept);
		
		RegisterColissionWarningEventLogMonitor(DataItem, ObjectMetadata, WriteObject, IsReferenceType);
		
		If Not IsReferenceType Then
			Return;
		EndIf;
			
		If DataExchangeReUse.UseVersioning(Sender) Then
			
			If RefExists Then
				
				If WriteObject Then
					Comment = NStr("en = 'Previous version (automatic conflict resolution).'");
				Else
					Comment = NStr("en = 'Current version (automatic conflict resolution).'");
				EndIf;
				
				InfoAboutObjectVersion = New Structure("Comment", Comment);
				OnCreateObjectVersion(ObjectInDataBase, InfoAboutObjectVersion, RefExists);
				
			EndIf;
			
			If WriteObject Then
				
				InfoAboutObjectVersion = CommonUseClientServer.CopyStructure(
					DataItem.AdditionalProperties.InfoAboutObjectVersion);
				
				InfoAboutObjectVersion.ObjectVersioningType = "AcceptDataOnConflicts";
				InfoAboutObjectVersion.VersionAuthor = Sender;
				InfoAboutObjectVersion.Comment = NStr("en = 'Accepted version (automatic conflict resolution)'");
				
				DataItem.AdditionalProperties.InfoAboutObjectVersion = New FixedStructure(InfoAboutObjectVersion);
				
			Else
				
				Comment = NStr("en = 'Rejected version (automatic conflict resolution).'");
				
				InfoAboutObjectVersion = New Structure;
				InfoAboutObjectVersion.Insert("VersionAuthor", Sender);
				InfoAboutObjectVersion.Insert("ObjectVersioningType", "DataUnacceptedByCollision");
				InfoAboutObjectVersion.Insert("Comment", Comment);
				OnCreateObjectVersion(DataItem, InfoAboutObjectVersion, RefExists);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks whether there is import prohibition by date.
//
// Parameters:
// DataItem	  - CatalogObject, DocumentObject, InformationRegisterRecordSet etc data.
// 					Data that was written from the exchange message but was not written to IB.
// ItemReceive - DataDebitItem.
// Sender		  - ExchangePlansRef.
//
Procedure ValidateImportProhibitionExistanceByDate(DataItem, ItemReceive, Val Sender)
	
	If Sender.Metadata().DistributedInfobase Then
		Return;
	EndIf;
	
	If CommonUse.ThisIsConstant(DataItem.Metadata()) Then
		Return;
	EndIf;
	
	ErrorInfo = "";
	If CommonUse.SubsystemExists("StandardSubsystems.ChangeProhibitionDates") Then
		ProhibitionDateChangesModule = CommonUse.CommonModule("ChangeProhibitionDates");
		
		If ProhibitionDateChangesModule.ImportingIsProhibited(DataItem, Sender, ErrorInfo) = True Then
			
			RegisterDataProhibitionImportByDate(DataItem, Sender, ErrorInfo);
			ItemReceive = DataItemReceive.Ignore;
			
		EndIf;
		
	EndIf;
	
	DataItem.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
	
EndProcedure

// Registers data import prohibition as the data import prohibition
// date is set to the events log monitor. For reference types if there
// is the ObjectVersioning subsystem registers it in the exchange problems monitor.
// 
// Parameters:
// Object - Reference type object for which prohibition registration is executed.
// ExchangeNode - ExchangePlanRef - Infobase node from which the object is received.
// ErrorInfo - String - Detailed description of import denial reason.
//
// Note: To check whether there is import prohibition
// by date, see procedure of the general module ChangeProhibitionDates.ImportProhibited.
//
Procedure RegisterDataProhibitionImportByDate(DataItem, Sender, ErrorInfo)
	
	WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
		EventLogLevel.Warning, , DataItem, ErrorInfo);
	
	If DataExchangeReUse.UseVersioning(Sender) AND CommonUse.ThisIsObjectOfReferentialType(DataItem.Metadata()) Then
		
		ObjectReference = DataItem.Ref;
		
		If CommonUse.RefExists(ObjectReference) Then
			
			ObjectInDataBase = ObjectReference.GetObject();
			
			Comment = NStr("en = 'Version is created at the data synchronization.'");
			InfoAboutObjectVersion = New Structure("Comment", Comment);
			
			OnCreateObjectVersion(ObjectInDataBase, InfoAboutObjectVersion, True);
			
			ErrorMessageString = ErrorInfo;
			ObjectVersioningType = "UnacceptedDataByProhibitionDateObjectExists";
			
		Else
			
			ErrorMessageString = NStr("en = '%1 prohibited to import to the prohibited period.%2%2%3'");
			ErrorMessageString = StringFunctionsClientServer.PlaceParametersIntoString(ErrorMessageString,
				String(DataItem), Chars.LF, ErrorInfo);
			ObjectVersioningType = "UnacceptedDataByProhibitionDateObjectNotExists";
			
		EndIf;
		
		InfoAboutObjectVersion = New Structure;
		InfoAboutObjectVersion.Insert("Author", Sender);
		InfoAboutObjectVersion.Insert("ObjectVersioningType", ObjectVersioningType);
		InfoAboutObjectVersion.Insert("Comment", ErrorMessageString);
		OnCreateObjectVersion(DataItem, InfoAboutObjectVersion);
		
	EndIf;
	
EndProcedure

// Creates and writes the version of an object into the infobase.
//
// Parameters:
//  Object - written IB object.
//  RefExists - Boolean - Sign of object existence by reference in the infobase.
//  InfoAboutObjectVersion - Structure - object version information:
//    * VersionAuthor - User or Exchange plan node - Version source.
//        Optional, default value is Undefined.
//    * ObjectVersionType - String - Created version type.
//        Optional, "UsedByUser" default value.
//    * Comment - String - Comment to the created version.
//        Optional, default value "".
//
Procedure OnCreateObjectVersion(Object, InfoAboutObjectVersion, RefExists = Undefined)
	
	If CommonUse.SubsystemExists("StandardSubsystems.ObjectVersioning") Then
		
		ObjectNewVersionInformation = New Structure;
		ObjectNewVersionInformation.Insert("VersionAuthor", Undefined);
		ObjectNewVersionInformation.Insert("ObjectVersioningType", "ChangedByUser");
		ObjectNewVersionInformation.Insert("Comment", "");
		FillPropertyValues(ObjectNewVersionInformation, InfoAboutObjectVersion);
		
		ObjectVersioningModule = CommonUse.CommonModule("ObjectVersioning");
		ObjectVersioningModule.CreateVersionObjectByDataExchange(Object, ObjectNewVersionInformation, RefExists);
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure RegisterColissionWarningEventLogMonitor(Object, ObjectMetadata, WriteObject, IsReferenceType)
	
	If WriteObject Then
		
		WarningTextRL = NStr("en = 'Object changes conflict appeared.
		|This infobase object has been replaced by the second infobase object version.'");
		
	Else
		
		WarningTextRL = NStr("en = 'Object changes conflict appeared.
		|Object from the second infobase is not accepted. This infobase object has not been modified.'");
		
	EndIf;
	
	Data = ?(IsReferenceType, Object.Ref, Undefined);
		
	WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
		EventLogLevel.Warning, ObjectMetadata, Data, WarningTextRL);
	
EndProcedure

// Only for internal use.
//
Function GetDataObjectAsStringBeforeChange(Object, ObjectMetadata, IsReferenceType, RefExists, ObjectInDataBase)
	
	// Return value of the function.
	ObjectString = "";
	
	If IsReferenceType Then
		
		If RefExists Then
			
			// Get object presentation from IB by reference.
			ObjectString = CommonUse.ValueToXMLString(ObjectInDataBase);
			
		Else
			
			ObjectString = NStr("en = 'Object deleted'");
			
		EndIf;
		
	ElsIf CommonUse.ThisIsConstant(ObjectMetadata) Then
		
		// Get constant value from IB.
		ObjectString = XMLString(Constants[ObjectMetadata.Name].Get());
		
	Else // Record set
		
		OldRecordSet = GetRecordSet(Object);
		ObjectString = CommonUse.ValueToXMLString(OldRecordSet);
		
	EndIf;
	
	Return ObjectString;
	
EndFunction

// Only for internal use.
//
Function GetDataObjectAsStringAfterChange(Object, ObjectMetadata)
	
	// Return value of the function.
	ObjectString = "";
	
	If CommonUse.ThisIsConstant(ObjectMetadata) Then
		
		ObjectString = XMLString(Object.Value);
		
	Else
		
		ObjectString = CommonUse.ValueToXMLString(Object);
		
	EndIf;
	
	Return ObjectString;
	
EndFunction

#EndRegion
