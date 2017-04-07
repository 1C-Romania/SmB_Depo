
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("OtherRelationship", True));
	FormParameters.Insert("PurposeUseKey", "OtherCounterpartiesList");
	
	OpenForm("Catalog.Counterparties.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure
