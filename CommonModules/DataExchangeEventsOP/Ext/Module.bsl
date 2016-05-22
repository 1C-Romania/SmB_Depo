
////////////////////////////////////////////////////////////////////////////////
// Exchange Small Business and Entrepreneur Reporting

// Procedure-processor of the BeforeWrite event of reference data types (except for documents) for objects registration mechanism on nodes
//
// Parameters:
//  ExchangePlanName - String - exchange plan name,
//  for which the Source registration mechanism is run       - source of the event
//  in addition to the ObjectDocument Denial type          - Boolean - check box of handler run denial
// 
Procedure ExchangeSmallBusinessAccountingAndEnterpreneurReportingBeforeWrite(Source, Cancel) Export
	
	DataExchangeEvents.ObjectsRegistrationMechanismBeforeWrite("ExchangeSmallBusinessEntrepreneurReporting", Source, Cancel);
	
EndProcedure

// Procedure-processor of the BeforeWrite event of the documents for objects registration mechanism on nodes
//
// Parameters:
//  ExchangePlanName - String - exchange plan name,
//  for which the Source registration mechanism is run       - DocumentObject - the
//  Denial event source          - Boolean - check box of handler run denial
// 
Procedure ExchangeSmallBusinessAccountingAndEnterpreneurReportingBeforeDocumentWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	DataExchangeEvents.ObjectsRegistrationMechanismBeforeWriteDocument("ExchangeSmallBusinessEntrepreneurReporting", Source, Cancel, WriteMode, PostingMode);
	
EndProcedure

// Procedure-processor of the BeforeDelete event of reference data types for objects registration mechanism on nodes
//
// Parameters:
//  ExchangePlanName - String - exchange plan name,
//  for which the Source registration mechanism is run       - the
//  Denial event source          - Boolean - check box of handler run denial
// 
Procedure ExchangeSmallBusinessAccountingEnterperneurReportingBeforeDelete(Source, Cancel) Export
	
	DataExchangeEvents.ObjectsRegistrationMechanismBeforeDelete("ExchangeSmallBusinessEntrepreneurReporting", Source, Cancel);
	
EndProcedure



