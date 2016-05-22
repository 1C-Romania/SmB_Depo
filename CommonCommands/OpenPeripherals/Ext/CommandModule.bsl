
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	EquipmentManagerClient.RefreshClientWorkplace();

	FormParameters = New Structure();
	OpenForm("Catalog.Peripherals.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);

EndProcedure
