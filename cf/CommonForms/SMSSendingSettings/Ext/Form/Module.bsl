#Region FormEventsHandlers

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_SMSSendingSettings", WriteParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ServiceDescriptionBeelineClick(Item)
	GotoURL("");
EndProcedure

&AtClient
Procedure DescriptionMTSServiceClick(Item)
	GotoURL("");
EndProcedure

#EndRegion














