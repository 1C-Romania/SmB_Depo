////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB version update".  
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Check if it is required to update infobase during the configuration version change.
//
Function InfobaseUpdateRequired() Export
	
	If InfobaseUpdateService.NeedToDoUpdate(
			Metadata.Version, InfobaseUpdateService.IBVersion(Metadata.Name)) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	Run = SessionParameters.ClientParametersOnServer.Get("RunInfobaseUpdate");
	SetPrivilegedMode(False);
	
	If Run <> Undefined AND InfobaseUpdateService.AreRightsForInfobaseUpdate() Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Only for internal use.
Function MinimumIBVersion() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		ModuleInfobaseUpdateServiceSaaS = CommonUse.CommonModule(
			"InfobaseUpdateServiceSaaS");
		
		MinimumVersionOfDataAreas = ModuleInfobaseUpdateServiceSaaS.MinimumVersionOfDataAreas();
	Else
		MinimumVersionOfDataAreas = Undefined;
	EndIf;
	
	IBVersion = InfobaseUpdateService.IBVersion(Metadata.Name);
	
	If MinimumVersionOfDataAreas = Undefined Then
		MinimumIBVersion = IBVersion;
	Else
		If CommonUseClientServer.CompareVersions(IBVersion, MinimumVersionOfDataAreas) > 0 Then
			MinimumIBVersion = MinimumVersionOfDataAreas;
		Else
			MinimumIBVersion = IBVersion;
		EndIf;
	EndIf;
	
	Return MinimumIBVersion;
	
EndFunction

#EndRegion
