
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	EquipmentManagerClient.RefreshClientWorkplace();
	
	OpenForm("CommonForm.ExchangeWithPeripheralsOffline", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
