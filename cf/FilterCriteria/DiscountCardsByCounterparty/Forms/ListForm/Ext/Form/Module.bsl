
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



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
