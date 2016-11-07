
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters 	= New Structure("VariantKey", "SalesByDiscountCards");
	
	OpenForm("Report.SalesByDiscountCards.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
