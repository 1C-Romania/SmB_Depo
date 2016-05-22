////////////////////////////////////////////////////////////////////////////////
// Subsystem "DataAreasBackupDataFormsInterface".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

Function GetFormParametersSettings(Val DataArea) Export
	
	Parameters = Implementation().GetFormParametersSettings(DataArea);
	Parameters.Insert("DataArea", DataArea);
	
	Return Parameters;
	
EndFunction

Function GetAreaSettings(Val DataArea) Export
	
	Return Implementation().GetAreaSettings(DataArea);
	
EndFunction

Procedure SetAreasSettings(Val DataArea, Val NewSettings, Val InitialSettings) Export
	
	Implementation().SetAreasSettings(DataArea, NewSettings, InitialSettings);
	
EndProcedure

Function GetStandardSettings() Export
	
	Return Implementation().GetStandardSettings();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Function Implementation()
	
	If CommonUse.SubsystemExists("StandardSubsystems.MSDataAreasBackup") Then
		Return CommonUse.CommonModule("DataBackupDataFormsAreasImplementationOfIB");
	Else
		Return CommonUse.CommonModule("DataAreasBackupDataFormsImplementationWebService");
	EndIf;
	
EndFunction

#EndRegion
