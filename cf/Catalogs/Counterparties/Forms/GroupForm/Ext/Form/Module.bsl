
#Region FormEventHandlers

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_CounterpartyGroup", Object.Ref, ThisObject);
	
EndProcedure

#EndRegion
