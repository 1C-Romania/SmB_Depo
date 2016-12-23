#Region FormEventsHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AddressInRelatedDocumentsStorage = Parameters.AddressInRelatedDocumentsStorage;
	RelatedDocuments.Load(GetFromTempStorage(AddressInRelatedDocumentsStorage));
	
	If RelatedDocuments.Count() = 0 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If RelatedDocuments.Count() = 1 Then
		CurDocument = RelatedDocuments[0].RelatedDocument;
		If ValueIsFilled(CurDocument) Then
			OpenDocument(CurDocument);
		EndIf;
		
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler OK form.
//
&AtClient
Procedure OK(Command)
	
	If Items.RelatedDocuments.CurrentData <> Undefined Then
		CurDocument = Items.RelatedDocuments.CurrentData.RelatedDocument;
		If ValueIsFilled(CurDocument) Then
			OpenDocument(CurDocument);
		EndIf;
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure - Selection PM RelatedDocuments form event handler.
//
&AtClient
Procedure RelatedDocumentsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurDocument = RelatedDocuments[SelectedRow].RelatedDocument;
	If ValueIsFilled(CurDocument) Then
		OpenDocument(CurDocument);
	EndIf;
	
	Close();
	
EndProcedure

// Procedure parses the document value type and opens it form.
//
&AtClient
Procedure OpenDocument(CurDocument)
	
	If TypeOf(CurDocument) = Type("DocumentRef.CashPayment") Then
		OpenForm("Document.CashPayment.ObjectForm", New Structure("Key", CurDocument));
	ElsIf TypeOf(CurDocument) = Type("DocumentRef.SupplierInvoice") Then
		OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Key", CurDocument));
	ElsIf TypeOf(CurDocument) = Type("DocumentRef.ReceiptCRReturn") Then
		OpenForm("Document.ReceiptCRReturn.ObjectForm", New Structure("Key", CurDocument));
	EndIf;
	
EndProcedure

#EndRegion














