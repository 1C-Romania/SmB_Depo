Function ExternalModuleExecutionMode(Val SoftwareModuleType, Val SoftwareModuleID) Export
	
	Manager = CreateRecordManager();
	Manager.SoftwareModuleType = SoftwareModuleType;
	Manager.SoftwareModuleID = SoftwareModuleID;
	Manager.Read();
	If Manager.Selected() Then
		
		Return Manager.SafeMode;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction