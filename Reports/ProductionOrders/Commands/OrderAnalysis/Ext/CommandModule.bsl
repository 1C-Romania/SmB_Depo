&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure;
	Filter.Insert("ProductionOrder", GetOrderArray(CommandParameter));
	
	OpenForm("Report.ProductionOrders.Form",
		New Structure("UsePurposeKey, Filter, GenerateOnOpen", CommandParameter, Filter, True),
		,
		"ProductionOrder=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()

&AtServer
Function GetOrderArray(CommandParameter)

	OrdersArray = New Array;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		For Each Document IN CommandParameter Do
			If TypeOf(Document) = Type("DocumentRef.InventoryAssembly") Then
				ProductionOrder = CommonUse.ObjectAttributeValue(Document, "BasisDocument");
				OrdersArray.Add(ProductionOrder);
			Else
				OrdersArray.Add(Document);
			EndIf;
		EndDo;
	EndIf;
	
	Return OrdersArray;

EndFunction // GetOrderArray()
// 
