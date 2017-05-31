
Function GetPurchaseInvoiceLine(PurchaseInvoiceRef, Item) Export 
	
	Query = New Query("SELECT
	                  |	PurchaseItemsLines.VATRate,
	                  |	PurchaseItemsLines.UnitOfMeasure,
	                  |	PurchaseItemsLines.VAT,
	                  |	PurchaseItemsLines.Amount
	                  |FROM
	                  |	Document.PurchaseInvoice.ItemsLines AS PurchaseItemsLines
	                  |WHERE
	                  |	PurchaseItemsLines.Ref = &Ref
	                  |	AND PurchaseItemsLines.Item = &Item");
	
	Query.SetParameter("Ref", PurchaseInvoiceRef);
	Query.SetParameter("Item", Item);
	
	Return Query.Execute().Select();
	
EndFunction 

Function GetPurchaseInvoiceVATRate(PurchaseInvoiceRef, Item) Export 
	
	Selection = GetPurchaseInvoiceLine(PurchaseInvoiceRef, Item);
	
	While Selection.Next() Do
		Return Selection.VATRate;
	EndDo;
	
	Return Undefined;
	
EndFunction 

Function GetPurchaseInvoiceUnitOfMeasure(PurchaseInvoiceRef, Item) Export 
	
	Selection = GetPurchaseInvoiceLine(PurchaseInvoiceRef, Item);
	
	While Selection.Next() Do
		Return Selection.UnitOfMeasure;
	EndDo;
	
	Return Undefined;
	
EndFunction 

Function GetPurchaseInvoiceVAT(PurchaseInvoiceRef, Item) Export 
	
	Selection = GetPurchaseInvoiceLine(PurchaseInvoiceRef, Item);
	
	While Selection.Next() Do
		Return Selection.VAT;
	EndDo;
	
	Return Undefined;
	
EndFunction 

Function GetPurchaseInvoiceAmount(PurchaseInvoiceRef, Item) Export 
	
	Selection = GetPurchaseInvoiceLine(PurchaseInvoiceRef, Item);
	
	While Selection.Next() Do
		Return Selection.Amount;
	EndDo;
	
	Return Undefined;
	
EndFunction 


Function GetSalesInvoiceLine(SalesInvoiceRef, Item) Export 
	
	Query = New Query("SELECT
	                  |	SalesInvoiceItemsLines.VATRate,
	                  |	SalesInvoiceItemsLines.UnitOfMeasure,
	                  |	SalesInvoiceItemsLines.VAT,
	                  |	SalesInvoiceItemsLines.Amount
	                  |FROM
	                  |	Document.SalesInvoice.ItemsLines AS SalesInvoiceItemsLines
	                  |WHERE
	                  |	SalesInvoiceItemsLines.Ref = &Ref
	                  |	AND SalesInvoiceItemsLines.Item = &Item");
	
	Query.SetParameter("Ref", SalesInvoiceRef);
	Query.SetParameter("Item", Item);
	
	Return Query.Execute().Select();
	
EndFunction 

Function GetSalesInvoiceVATRate(SalesInvoiceRef, Item) Export 
	
	Selection = GetSalesInvoiceLine(SalesInvoiceRef, Item);	

	While Selection.Next() Do
		Return Selection.VATRate;
	EndDo;
	
	Return Undefined;
	
EndFunction 

Function GetSalesInvoiceUnitOfMeasure(SalesInvoiceRef, Item) Export 
	
	Selection = GetSalesInvoiceLine(SalesInvoiceRef, Item);	
	
	While Selection.Next() Do
		Return Selection.UnitOfMeasure;
	EndDo;
	
	Return Undefined;
	
EndFunction 

Function GetSalesInvoiceVAT(SalesInvoiceRef, Item) Export 
	
	Selection = GetSalesInvoiceLine(SalesInvoiceRef, Item);	
	
	While Selection.Next() Do
		Return Selection.VAT;
	EndDo;
	
	Return Undefined;
	
EndFunction 

Function GetSalesInvoiceAmount(SalesInvoiceRef, Item) Export 
	
	Selection = GetSalesInvoiceLine(SalesInvoiceRef, Item);	
	
	While Selection.Next() Do
		Return Selection.Amount;
	EndDo;
	
	Return Undefined;
	
EndFunction 
