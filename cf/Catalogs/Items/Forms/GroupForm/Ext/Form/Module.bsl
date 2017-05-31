
&AtClient
Procedure BaseUnitOfMeasureOnChange(Item)
	
	If Object.PurchaseUnitOfMeasure.IsEmpty() then
		Object.PurchaseUnitOfMeasure = Object.BaseUnitOfMeasure;
	EndIf;
	
	If Object.SalesUnitOfMeasure.IsEmpty() then
		Object.SalesUnitOfMeasure = Object.BaseUnitOfMeasure;
	EndIf;

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	FormsAtServer.CatalogFormOnCreateAtServer(ThisForm, Cancel, StandardProcessing);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	FormsAtServer.BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters);	
EndProcedure
