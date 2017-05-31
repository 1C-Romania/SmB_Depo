Function IsInvoiceDocument(DocumentRef) Export
	
	If TypeOf(DocumentRef) = Type("DocumentRef.SalesInvoice")
		OR TypeOf(DocumentRef) = Type("DocumentRef.SalesRetail")
		OR TypeOf(DocumentRef) = Type("DocumentRef.SalesCreditNotePriceCorrection")
		OR TypeOf(DocumentRef) = Type("DocumentRef.SalesCreditNoteReturn")
		OR TypeOf(DocumentRef) = Type("DocumentRef.SalesRetailReturn") Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction
