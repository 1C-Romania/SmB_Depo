
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_InventoryAndPurchasing");
	ReportsVariantsClient.ShowReportsPanel("InventoryAndPurchasing", CallParameters, NStr("en='Inventory and purchasing reports';ru='Отчеты по закупкам и запасам'"));
	
EndProcedure
