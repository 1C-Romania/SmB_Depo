
&AtClient
Procedure Create(Command)
	
	If ValueIsFilled(List.Parameters.Items) Then 
		FormOpenParameters = New Structure("FillingValues", New Structure("CardOwner", List.Parameters.Items[0].Value));
	EndIf;
	OpenForm("Catalog.DiscountCards.ObjectForm", FormOpenParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure NewWriteProcessing(NewObject, Source, StandardProcessing)
	
	Items.List.Refresh();
	
EndProcedure
