#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure OnWrite(Cancel, Replacing)
	
	If WorkInSafeMode.SafeModeIsSet() Then
		
		CurrentSafeMode = SafeMode();
		
		For Each Record IN ThisObject Do
			
			If Record.SafeMode <> CurrentSafeMode Then
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Safe mode %1 differs from current %2';ru='Безопасный режим %1 отличается от текущего %2'"),
					Record.SafeMode, CurrentSafeMode);
				
			EndIf;
			
			ProgramModule = WorkInSafeModeService.RefFromPermissionsRegister(
				Record.OwnerType, Record.SoftwareModuleID);
			
			If ProgramModule <> Catalogs.MetadataObjectIDs.EmptyRef() Then
				
				SoftwareModuleSafeMode = InformationRegisters.ExternalModulesConnectionModes.ExternalModuleConnectionMode(
					ProgramModule);
				
				If Record.SafeMode <> SoftwareModuleSafeMode Then
					
					Raise StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='The permission query cannot be executed from safe mode %2 for application module %1';ru='Для программного модуля %1 не может быть выполнен запрос разрешений из безопасного режима %2'"),
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
