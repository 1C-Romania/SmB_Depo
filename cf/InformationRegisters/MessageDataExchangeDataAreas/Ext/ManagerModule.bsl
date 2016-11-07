#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "MessageDataExchangeDataAreas");
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	DataExchangeServer.DeleteRecordSetInInformationRegister(RecordStructure, "MessageDataExchangeDataAreas");
	
EndProcedure

#EndRegion

#EndIf