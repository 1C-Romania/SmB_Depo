
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Counterparty", CommandParameter);
	
	FormParameters = New Structure("VariantKey, Filter, GenerateOnOpen", "Counterparty contact information", FilterStructure, True);
	
	If CommandExecuteParameters.Window = Undefined Then
		FormParameters.Insert("OpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
	OpenForm("Report.CounterpartyContactInformation.Form.ReportForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
