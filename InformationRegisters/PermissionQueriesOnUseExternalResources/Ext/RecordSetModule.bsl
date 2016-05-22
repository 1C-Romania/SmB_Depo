#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure OnWrite(Cancel, Replacing)
	
	If WorkInSafeMode.SafeModeIsSet() Then
		
		CurrentSafeMode = SafeMode();
		
		For Each Record IN ThisObject Do
			
			If Record.SafeMode <> CurrentSafeMode Then
				
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Safe mode %1 differs from the current %2'"),
					Record.SafeMode, CurrentSafeMode);
				
			EndIf;
			
			ProgramModule = WorkInSafeModeService.RefFromPermissionsRegister(
				Record.OwnerType, Record.SoftwareModuleID);
			
			If ProgramModule <> Catalogs.MetadataObjectIDs.EmptyRef() Then
				
				SoftwareModuleSafeMode = InformationRegisters.ExternalModulesConnectionModes.ExternalModuleConnectionMode(
					ProgramModule);
				
				If Record.SafeMode <> SoftwareModuleSafeMode Then
					
					Raise StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = 'For software module %1 permission request from the safe mode %2 can''t be executed'"),
						String(ProgramModule), Record.SafeMode);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
