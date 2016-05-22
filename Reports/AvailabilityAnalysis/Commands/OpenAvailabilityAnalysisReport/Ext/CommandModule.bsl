
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure;
	
	If TypeOf(CommandParameter) = Type("DocumentRef.CustomerOrder")
		OR TypeOf(CommandParameter) = Type("DocumentRef.CustomerInvoice") Then
		
		ProductsAndServicesList = GetProductsAndServicesListOfDocument(CommandParameter);
		FilterStructure.Insert("ProductsAndServices", ProductsAndServicesList);
	Else
		FilterStructure.Insert("ProductsAndServices", CommandParameter);
	EndIf;
	
	FormParameters = New Structure("VariantKey, Filter, GenerateOnOpen, ReportVariantsCommandsVisible", "AvailableBalanceContext", FilterStructure, True, False);
	
	OpenForm("Report.AvailabilityAnalysis.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function GetProductsAndServicesListOfDocument(Document)
	
	ProductsAndServicesList = Document.Inventory.UnloadColumn("ProductsAndServices");
	
	If TypeOf(Document) = Type("DocumentRef.CustomerOrder")
		AND Document.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		For Each TableRow IN Document.Materials Do
			ProductsAndServicesList.Add(TableRow.ProductsAndServices);
		EndDo;
		
		For Each TableRow IN Document.ConsumerMaterials Do
			ProductsAndServicesList.Add(TableRow.ProductsAndServices);
		EndDo;
		
	EndIf;
	
	Return ProductsAndServicesList;
	
EndFunction
