
&AtClient
//Procedure - OnChange event handler of the Counterparty field
//
Procedure CounterpartyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure // CounterpartyOnChange()














