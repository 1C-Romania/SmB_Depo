////////////////////////////////////////////////////////////////////////////////
// The Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It defines the code prefix and infobase object numbers by default.
//
// Parameters:
//  Prefix - String, 2 - code prefix and infobase object numbers by default.
//
Procedure OnDefineDefaultInfobasePrefix(Prefix) Export
	
	Prefix = NStr("en='FR';ru='ФР'");
	
EndProcedure

// It defines the list of the exchange plans that use data exchange subsystem functionality.
//
// Parameters:
// SubsystemExchangePlans - Array - The array of
//  the configuration exchange plans that use data exchange subsystem functionality.
//  Metadata objects of the exchange plans are array items.
//
// Example of the procedure body:
//
// SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeWithoutConversionRulesUse);
// SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangewithStandardSubsystemLibrary);
// SubsystemExchangePlans.Add(Metadata.ExchangePlans.DistributedInfobase);
//
Procedure GetExchangePlans(SubsystemExchangePlans) Export
	
	SetPrivilegedMode(True);
	
	If GetFunctionalOption("WorkInLocalMode") Then
		SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeSmallBusinessAccounting20);
	EndIf;
	
	SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeRetailSmallBusiness);
	SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeSmallBusinessAccounting30);
	SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeSmallBusinessEntrepreneurReporting);
	
EndProcedure

// Handler during data exporting.
// Used to override the standard processor of the data export.
// Data exporting logic shall be implemented in this handler:
// selection of data for export, data serialization to the message file or data serialization to flow.
// After the handler execution the data exchange subsystem will send the exported data to the receiver.
// Message format for export can be custom.
// If errors occur while sending data, you should abort
// execution of the handler using the CallException method with the error description.
//
// Parameters:
//
// StandardProcessing - Boolean - A flag of standard (system) event handler is passed to this parameter.
//  If you set the False value for this parameter
//  in the body of the procedure-processor, there will be no standard processing of the event. Denial from the standard processor does not stop action.
//  Value by default - True.
//
// Recipient - ExchangePlanRef - Exchange plan node for which the data is exported.
//
// MessageFileName - String - File name where the data shall be exported.
//  If this parameter is filled in,
//  the system expects that the data will be exported to file. After exporting the system will send the data from this file.
//  If the parameter is empty, the system expects that the data will be exported to the MessageData parameter.
//
// MessageData - Arbitrary - If the MessageFileName
//  parameter is empty, the system expects that the data will be exported to this parameter.
//
// ItemCountInTransaction - Number - It defines the maximum
//  number of data items placed to the message within one transaction of the data base.
//  You should implement the setting logic
//  of transaction locks for the exported data in the handler if needed.
//  The parameter value is specified in the data exchange subsystem settings.
//
// EventLogMonitorEventName - String - Event name of the log for the current data exchange session.
//  Used to write data with the specified event name to the events log monitor (errors, alerts, information).
//  Corresponds to the EventName parameter of the EventLogMonitorRecord global context method.
//
// SentObjectCount - Number - Counter of the sent objects.
//  Used to define a
//  quantity of sent objects for the subsequent record in the exchange protocol.
//
Procedure DuringDataDump(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								SentObjectCount
	) Export
	
EndProcedure

// Handler during data importing.
// Used to override standard processor of the data import.
// Data importing logic shall be implemented in this handler.:
// required checks before the data import, data serialization from the message file
// or data serialization from the flow.
// Message format for import can be custom.
// If errors occur when obtaining data, interrupt the handler
// using the Raise method with the error description.
//
// Parameters:
//
// StandardProcessing - Boolean - A flag of standard (system) event handler is
//                                passed to this parameter.
//  standard (system) event DataProcessor.
//  If you set the False value for this
//  parameter in the body of the procedure-processor, there will be no standard processing of the event.
//  Denial from the standard processor does not stop action.
//  Default value: True.
//
// Sender - ExchangePlanRef - Exchange plan node for which the data is imported.
//
// MessageFileName - String - File name used to import the data.
//  If the parameter is not filled in, then the data for import is passed via the MessageData parameter.
//
// MessageData - Arbitrary - Parameter contains data that is required to be imported.
//  If the MessageFileName parameter is empty,
//  then the data for import is passed via this parameter.
//
// ItemCountInTransaction - Number - Defines the maximum quantity
//  of the data items that are read from message and written to the data base within one transaction.
//  You should implement the logic of data record in transaction in the handler if needed.
//  The parameter value is specified in the data exchange subsystem settings.
//
// EventLogMonitorEventName - String - Event name of the log for the current data exchange session.
//  Used to write data with the specified event name to the events log monitor (errors, alerts, information).
//  Corresponds to the EventName parameter of the EventLogMonitorRecord global context method.
//
// ReceivedObjectCount - Number-counter of the received objects.
//  Used to define a quantity of imported objects
//  for the subsequent record in the exchange protocol.
//
Procedure OnDataImport(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								ItemCountInTransaction,
								EventLogMonitorEventName,
								ReceivedObjectCount
	) Export
	
EndProcedure

// Change record handler for initial data exporting.
// It is used to override standard change record DataProcessor.
// For the standard processor the changes of all data from the exchange plan content shall be recorded.
// If the filters for the data migration restrictions
// is used for the exchange plan, this handler use can improve the performance of the initial data export.
// In the handler you shall implement change recording with data migration restriction filters.
// If migration restrictions by the date or date and companies is used
// for the exchange plan, you
// can use  general-purpose DataExchangeServer procedure.RecordDataByExportStartDateAndCompanies.
// The handler is used only for general data exchange using
// the exchange rules and for general data exchange without exchange rules and is not used for exchanges in DIB.
// Handler usage improves performance
// of the initial data exporting on average by 2-4 times.
//
// Parameters:
//
// Recipient - ExchangePlanRef - Exchange plan node where the data shall be exported.
//
// StandardProcessing - Boolean - A flag of standard (system) event handler is
//                                 passed to this parameter.
//  If you set the False value for this parameter in the
//  body of the procedure-processor, there will be no standard processing of the event.
//  Denial from the standard processor does not stop action.
//  Value by default - True.
//
Procedure InitialDataExportChangeRecord(Val Recipient, StandardProcessing, Filter) Export
	
	If    TypeOf(Recipient) = Type("ExchangePlanRef.ExchangeSmallBusinessAccounting20")
		OR TypeOf(Recipient) = Type("ExchangePlanRef.ExchangeSmallBusinessAccounting30") Then
		
		StandardProcessing = False;
		
		Filter = New Array;
		
		AttributeValues = CommonUse.ObjectAttributesValues(Recipient, "UseDocumentTypeFilter, ManualExchange, DocumentKinds");
		If AttributeValues.ManualExchange
			OR AttributeValues.UseDocumentTypesFilter Then
			
			For Each ContentItem IN Recipient.Metadata().Content Do
				If Metadata.Catalogs.Contains(ContentItem.Metadata) Then
					Filter.Add(ContentItem.Metadata);
				EndIf;
			EndDo;
			
			If AttributeValues.UseDocumentTypesFilter Then
				
				For Each TabularSectionRow IN Recipient.DocumentKinds Do
					MetadataObject = Metadata.Documents.Find(TabularSectionRow.MetadataObjectName);
					If MetadataObject <> Undefined Then
						Filter.Add(MetadataObject);
					EndIf;
				EndDo;
				
			EndIf;
			
		Else
			
			For Each ContentItem IN Recipient.Metadata().Content Do
				Filter.Add(ContentItem.Metadata);
			EndDo;
			
		EndIf;
		
		MetadataQualifiers = New Array;
		MetadataQualifiers.Add(Metadata.Catalogs.Banks);
		MetadataQualifiers.Add(Metadata.Catalogs.Currencies);
		MetadataQualifiers.Add(Metadata.Catalogs.UOMClassifier);
		MetadataQualifiers.Add(Metadata.Catalogs.WorldCountries);
		
		For Each ArrayElement IN MetadataQualifiers Do
			FoundItem = Filter.Find(ArrayElement);
			If FoundItem <> Undefined Then
				Filter.Delete(FoundItem);
			EndIf;
		EndDo;
		
		AttributeValues = CommonUse.ObjectAttributesValues(Recipient, "UseCompanyFilter, DocumentsExportingStartDate, Companies");
		
		Companies = ?(AttributeValues.UseCompaniesFilter, AttributeValues.Companies.Unload().UnloadColumn("Company"), Undefined);
		
		DataExchangeServer.RegisterDataByExportStartDateAndCounterparty(Recipient, AttributeValues.DocumentsDumpStartDate, Companies, Filter);
		
	EndIf;
	
EndProcedure

// Handler at data change conflicts.
// Event occurs on receiving data if the same object as received from the
// exchange message is changed in the current infobase and these objects differ.
// It is used to override standard data change conflict processors.
// Standard conflict processing involves receiving changes from
// the main node and ignoring changes received from the subordinate node.
// In this handler you shall override the
// ReceiveItem parameter if it is necessary to change the behavior by default.
// In this handler you can specify the behavior of the system in case a
// data change conflict occurs in terms of data, data properties, senders or for all infobases or for all data
// in general.
// The handler is called both in the exchange
// of the distributed infobase (DIB) and in all other exchanges including exchanges based on the exchange rules.
//
// Parameters:
//  DataItem - Data item read from the data exchange messages.
//  Data elements can be ConstantValueManager.<Constant
//  name>, data base objects (except Remove Object), set of register records,
//  sequences or recalculations.
//
// ItemReceive - DataItemReceive - It defines whether the read data item will
//                                               be recorded to the data base or not in case of conflict.
//  When calling a handler, the parameter value is set to Auto
//  that means default actions (receive from the main node, ignore from the subordinate node).
//  You can override this parameter value in the handler.
//
// Sender - ExchangePlanRef - Exchange plan node which name is used to receive the data.
//
// GetFromMain - Boolean -  It denotes the sign of data receiving from the
//                                main node in distributed infobase.
//  True - the data is received from the main node, False - from subordinate.
//  It takes True value in the exchange based on the exchange rules - if the Above value (value by default) is specified 
//  or the value is not specified as the object priority at the conflict in the exchange rules;
//  False - If the Below or Match value is selected for the object priority at the conflict in the exchange rules.
//  For other types of the data exchange, the parameter value is set to True.
//
Procedure OnCollisionOfDataChange(Val DataItem, ItemReceive, Val Sender, Val GetFromMain) Export
	
	
	
EndProcedure

// Outdated. You shall use OnDefiningInfobasePrefixByDefault.
//
//
Function InfobasePrefixByDefault() Export
	Return NStr("en='FR';ru='ФР'");
EndFunction

#EndRegion
