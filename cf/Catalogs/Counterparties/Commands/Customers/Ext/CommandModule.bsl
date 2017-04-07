﻿
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("Customer", True));
	FormParameters.Insert("PurposeUseKey", "CustomerList");
	
	OpenForm("Catalog.Counterparties.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure
