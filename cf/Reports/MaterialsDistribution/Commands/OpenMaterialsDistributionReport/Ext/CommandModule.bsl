
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure	= New Structure("Recorder", CommandParameter);
	FormParameters 	= New Structure("Filter, GenerateOnOpen", FilterStructure, True);
	
	OpenForm("Report.MaterialsDistribution.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
