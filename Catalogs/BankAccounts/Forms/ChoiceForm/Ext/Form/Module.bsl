﻿
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
