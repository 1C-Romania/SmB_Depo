////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Info base update

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Handler of the update BED 1.0.5.0
// Filling regulations version in agreements.
//
Procedure UpdateEDEScheduleVersion() Export
	
	RecordSet = InformationRegisters.DeleteEDExchangeMembersThroughEDFOperators.CreateRecordSet();
	RecordSet.Read();
	
	For Each Record IN RecordSet Do
		If Not ValueIsFilled(Record.EDFScheduleVersion) Then
			Record.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version10;
		EndIf;
	EndDo;
	
	InfobaseUpdate.WriteData(RecordSet)
	
EndProcedure

// Handler of the update BED 1.1.13.2
// Replaces regulations version to 2.0, as 1.0 is not supported any more.
//
Procedure ReplaceFrom1On2RegulationsVersionEDF() Export
	
	RecordSet = InformationRegisters.DeleteEDExchangeMembersThroughEDFOperators.CreateRecordSet();
	RecordSet.Read();
	
	For Each Record IN RecordSet Do
		If Record.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version10 Then
			Record.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20;
		EndIf;
	EndDo;
	
	InfobaseUpdate.WriteData(RecordSet)
	
EndProcedure

#EndIf