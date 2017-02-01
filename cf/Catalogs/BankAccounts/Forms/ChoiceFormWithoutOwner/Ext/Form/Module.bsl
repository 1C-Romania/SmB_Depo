
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SettlementsInStandardUnits")
		AND Parameters.SettlementsInStandardUnits Then
		
		SmallBusinessClientServer.SetListFilterItem(List,"Owner",Parameters.Owner);
		
		SmallBusinessClientServer.SetListFilterItem(List,"CashCurrency",Parameters.CurrenciesList,True,DataCompositionComparisonType.InList);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

#EndRegion
