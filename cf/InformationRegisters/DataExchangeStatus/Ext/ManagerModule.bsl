#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure adds record in the register by transferred structure values.
Procedure AddRecord(RecordStructure) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreaDataExchangeStatus");
	Else
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeStatus");
	EndIf;
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	DataExchangeServer.DeleteRecordSetInInformationRegister(RecordStructure, "DataExchangeStatus");
	
EndProcedure

#EndRegion

#EndIf