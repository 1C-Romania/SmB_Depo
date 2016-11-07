#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// For an internal use.
//
Procedure RunCatalogImport(Parameters, TemporaryStorageAddress) Export
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(
		Parameters.InfobaseNode,
		Parameters.ExchangeMessageFileName,
		Enums.ActionsAtExchange.DataImport);
	
EndProcedure

// For an internal use.
//
Procedure ExecuteDataImport(Parameters, TemporaryStorageAddress) Export
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNodeFinishLongOperation(
		False,
		Parameters.InfobaseNode,
		Parameters.FileID,
		Parameters.OperationStartDate,
		Parameters.AuthenticationParameters,
		True);
	
EndProcedure

#EndRegion

#EndIf