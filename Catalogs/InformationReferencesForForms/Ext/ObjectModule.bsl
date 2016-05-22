Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	If ActualityEndingDate = '00010101000000' Then 
		ActualityEndingDate = '39991231235959';
	EndIf;
	
EndProcedure
