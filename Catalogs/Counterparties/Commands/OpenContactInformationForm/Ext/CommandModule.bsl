
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("CounterpartiesInitialValue", CommandParameter);
	If CommandParameter.Count() > 0 Then
		UniqueKey = String(CommandParameter[0]);
	Else
		UniqueKey = CommandExecuteParameters.Uniqueness;
	EndIf;
	OpenForm("Catalog.Counterparties.Form.ContactInformationForm", FormParameters, CommandExecuteParameters.Source, UniqueKey, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
EndProcedure
