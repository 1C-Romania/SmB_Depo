
// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SettlementsInStandardUnits")
		AND Parameters.SettlementsInStandardUnits Then
		
		SmallBusinessClientServer.SetListFilterItem(List,"Owner",Parameters.Owner);
		
		SmallBusinessClientServer.SetListFilterItem(List,"CashCurrency",Parameters.CurrenciesList,True,DataCompositionComparisonType.InList);
		
	EndIf;
	
	If Parameters.Filter.Property("Owner") Then
		OwnerType = TypeOf(Parameters.Filter.Owner);
		Items.AgreementOnDirectExchange.Visible =
			GetFunctionalOption("UseEDExchangeWithBanks") AND OwnerType = Type("CatalogRef.Companies");
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure














