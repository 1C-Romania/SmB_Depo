&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.List.ChoiceMode Then 
		If Parameters.ReturnRow Then
			NotifyChoice(New Structure("TypeOfChoice, ExchangeRate, ExchangeRateDate, NBPTableNumber","CURRENCYEXCHANGERATECHOICE",Item.CurrentData.ExchangeRate,Item.CurrentData.Period,Item.CurrentData.NBPTableNumber));
		Else	
			NotifyChoice(Item.CurrentData.ExchangeRate);
		EndIf;	
	EndIf;

EndProcedure


