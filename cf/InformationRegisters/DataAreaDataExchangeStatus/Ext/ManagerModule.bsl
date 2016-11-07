#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Adds the record to the register by the passed structure values
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreaDataExchangeStatus");
	
EndProcedure

#EndRegion

#EndIf