
#Region ServiceProceduresAndFunctions
// IN custom development, the use of service procedures and functions is not recommended

Procedure ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, Owner) Export
	
	If Find(DataLoadSettings.DataImportFormNameFromExternalSources, "DataLoadFromFile") > 0 Then
		
		DataImportingParameters = DataLoadSettings;
		
	ElsIf Find(DataLoadSettings.DataImportFormNameFromExternalSources, "DataImportFromExternalSources") > 0 Then
		
		DataImportingParameters = New Structure("DataLoadSettings", DataLoadSettings);
		
	EndIf;
	
	OpenForm(DataLoadSettings.DataImportFormNameFromExternalSources, DataImportingParameters, Owner, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion