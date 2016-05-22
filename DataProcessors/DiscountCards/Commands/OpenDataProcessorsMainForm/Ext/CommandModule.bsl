
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	//Insert handler contents.
	//FormParameters = New Structure("", );
	OpenForm("DataProcessor.DiscountCards.Form", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
EndProcedure
