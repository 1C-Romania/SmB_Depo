#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel, Replacing)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record IN ThisObject Do
		If Record.ProductsAndServices.IsEmpty() Then
			Cancel = True;
			Message("You can not perform writing if the value of products and services is blank.");
			Continue;
		EndIf; 
		If Record.ProductsAndServices.IsFolder Then
			Cancel = True;
			Message("You can't Select products and services group as counterparty ProductsAndServices.");
			Continue;
		EndIf; 
	EndDo; 
	
EndProcedure

#EndIf