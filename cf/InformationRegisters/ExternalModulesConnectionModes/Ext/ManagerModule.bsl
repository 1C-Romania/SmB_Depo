#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Returns the connection mode of the external module.
//
// Parameters:
//  ProgramModule - AnyRef, ref corresponding to a application
//    module for which the connection mode is requested.
//
// Return value: String - name of a security profile which shall
//  be used for connection of an external module. If the connection mode is not registered for external module - returns Undefined.
//
Function ExternalModuleConnectionMode(Val ProgramModule) Export
	
	If WorkInSafeMode.SafeModeIsSet() Then
		
		// If the safe mode specified above the stack is set - you can
		// connect external modules only in the same safe mode.
		Result = SafeMode();
		
	Else
		
		SetPrivilegedMode(True);
		
		ProgramModuleProperties = WorkInSafeModeService.PropertiesForPermissionsRegister(ProgramModule);
		
		Manager = CreateRecordManager();
		Manager.SoftwareModuleType = ProgramModuleProperties.Type;
		Manager.SoftwareModuleID = ProgramModuleProperties.ID;
		Manager.Read();
		If Manager.Selected() Then
			Result = Manager.SafeMode;
		Else
			Result = Undefined;
		EndIf;
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.BasicFunctionality\WhenConnectingExternalModule");
		For Each Handler IN EventHandlers Do
			Handler.Module.WhenConnectingExternalModule(ProgramModule, Result);
		EndDo;
		
		WorkInSafeModeOverridable.WhenConnectingExternalModule(ProgramModule, Result);
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf
