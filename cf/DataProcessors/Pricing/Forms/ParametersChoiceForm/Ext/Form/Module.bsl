
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
