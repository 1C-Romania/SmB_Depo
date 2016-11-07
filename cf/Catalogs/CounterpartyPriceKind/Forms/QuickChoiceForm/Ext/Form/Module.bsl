
&AtClient
//Procedure - OnChange event handler of the Counterparty field
//
Procedure CounterpartyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure // CounterpartyOnChange()



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
