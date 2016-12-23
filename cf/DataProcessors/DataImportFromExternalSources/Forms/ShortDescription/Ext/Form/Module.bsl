&AtServer
Procedure FillDetails(TemplateName)
	
	Description = DataProcessors.DataImportFromExternalSources.GetTemplate(TemplateName).GetText();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillDetails("QuickStart");
	
EndProcedure

&AtClient
Procedure ShortDescriptionOnClick(Item, EventData, StandardProcessing)
	
	If ValueIsFilled(EventData.Element.id) Then
		
		StandardProcessing = False;
		
		CommandID = EventData.Element.id;
		If Find(CommandID, "Counterparties") > 0 Then
			
			OpenForm("Catalog.Counterparties.ListForm");
			
		ElsIf Find(CommandID, "ProductsAndServices") > 0 Then
			
			OpenForm("Catalog.ProductsAndServices.ListForm");
			
		ElsIf Find(CommandID, "Prices") > 0 Then
			
			OpenForm("DataProcessor.PriceList.Form");
			
		ElsIf Find(CommandID, "ShortAbbreviation") > 0 Then
			
			FillDetails("ShortDescription");
			
		ElsIf Find(CommandID, "QuickStart") > 0 Then
			
			FillDetails("QuickStart");
			
		ElsIf Find(CommandID, "ImportFromSpreadsheet") > 0 Then
			
			OpenForm("DataProcessor.ImportFromSpreadsheet.Form");
			
		EndIf;
		
	EndIf;
	
EndProcedure













