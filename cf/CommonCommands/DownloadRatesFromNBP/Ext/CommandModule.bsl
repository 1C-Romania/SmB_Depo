
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	// Wstaw zawartość procedury obsługi zdarzeń.
	FormParameters = New Structure("SelectedCurrency", CommandParameter);
	OpenForm("DataProcessor.ExchangeRatesFromNBP.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
