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
