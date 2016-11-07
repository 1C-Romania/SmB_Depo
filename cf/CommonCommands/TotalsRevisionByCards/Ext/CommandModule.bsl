
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	UUID = New UUID();
	EquipmentManagerClient.RunTotalsOnPOSTerminalRevision(UUID);
	
EndProcedure
