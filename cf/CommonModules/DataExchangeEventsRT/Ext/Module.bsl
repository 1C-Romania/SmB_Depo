////////////////////////////////////////////////////////////////////////////////
// Exchange SmallBusiness 1.4 and Retail 2.1 

// Procedure-processor of the BeforeWrite event of reference data types (except for documents) for objects registration mechanism on nodes
//
// Parameters:
//  ExchangePlanName - String - exchange plan name,
//  for which the Source registration mechanism is run       - source of the event
//  in addition to the ObjectDocument Denial type          - Boolean - check box of handler run denial
// 
Procedure ExchangeRetailSmallBusinessRegisterChange(Source, Cancel) Export
	
	DataExchangeEvents.ObjectsRegistrationMechanismBeforeWrite("ExchangeRetailSmallBusiness", Source, Cancel);
	
EndProcedure

// Procedure-processor of the BeforeWrite event of the documents for objects registration mechanism on nodes
//
// Parameters:
//  ExchangePlanName - String - exchange plan name,
//  for which the Source registration mechanism is run       - DocumentObject - the
//  Denial event source          - Boolean - check box of handler run denial
// 
Procedure RetailSmallBusinessExchangeDocumentChangeRecord(Source, Cancel, WriteMode, PostingMode) Export
	
	DataExchangeEvents.ObjectsRegistrationMechanismBeforeWriteDocument("ExchangeRetailSmallBusiness", Source, Cancel, WriteMode, PostingMode);
	
EndProcedure

// Procedure-processor of the BeforeDelete event of reference data types for objects registration mechanism on nodes
//
// Parameters:
//  ExchangePlanName - String - exchange plan name,
//  for which the Source registration mechanism is run       - the
//  Denial event source          - Boolean - check box of handler run denial
// 
Procedure ExchangeRetailSmallBusinessRegisterDeletion(Source, Cancel) Export
	
	DataExchangeEvents.ObjectsRegistrationMechanismBeforeDelete("ExchangeRetailSmallBusiness", Source, Cancel);
	
EndProcedure

// Procedure-processor of the BeforeWrite event of registers for objects registration mechanism on nodes
//
// Parameters:
//  ExchangePlanName - String - exchange plan name,
//  for which the Source registration mechanism is run       - RegisterRecordSet - the
//  Denial event source          - Boolean - check box of the
//  Replace handler run denial      - Boolean - shows that an existing records set was replaced
// 
Procedure ExchangeRetailSmallBusinessRegisterRecordSetChange(Source, Cancel, Replacing) Export
	
	DataExchangeEvents.ObjectsRegistrationMechanismBeforeWriteRegister("ExchangeRetailSmallBusiness", Source, Cancel, Replacing);
	
EndProcedure
