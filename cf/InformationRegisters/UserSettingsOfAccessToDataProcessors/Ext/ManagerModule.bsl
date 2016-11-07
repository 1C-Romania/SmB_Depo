#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Writes the settings of quick access to data processors "by users".
//
Procedure RefreshDataOnAdditionalWriteObject(AdditionalReportOrDataProcessor, QuickAccess) Export
	RecordSet = CreateRecordSet();
	RecordSet.Filter.AdditionalReportOrDataProcessor.Set(AdditionalReportOrDataProcessor);
	
	For Each TableRow IN QuickAccess Do
		Record = RecordSet.Add();
		Record.AdditionalReportOrDataProcessor = AdditionalReportOrDataProcessor;
		FillPropertyValues(Record, TableRow);
		Record.Available = True;
	EndDo;
	
	RecordSet.Write(True);
EndProcedure

#EndRegion

#EndIf