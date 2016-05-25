
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	ToDate = CurrentDate();
	If Parameters.Property("PriceKind") AND ValueIsFilled(Parameters.PriceKind) Then
		PriceKind = Parameters.PriceKind
	Else
		PriceKind = Catalogs.PriceKinds.Wholesale;
	EndIf;	
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	Close(New Structure("PriceKind, ToDate", PriceKind, ToDate)); 
	
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
