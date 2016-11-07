#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() = 1 Then
		
		FirstRecord = Get(0);
		
		DataExchange.Recipients.AutoFill = False;
		DataExchange.Recipients.Clear();
		
		Query = New Query(
		"SELECT
		|	Peripherals.InfobaseNode AS ExchangeNode
		|FROM
		|	Catalog.Peripherals AS Peripherals
		|WHERE
		|	Peripherals.ExchangeRule = &ExchangeRule
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)");
		
		Query.SetParameter("ExchangeRule", FirstRecord.ExchangeRule);
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
		While Selection.Next() Do
		
			Set.Filter.ExchangeRule.Value = FirstRecord.ExchangeRule;
			Set.Filter.ExchangeRule.Use = True;
			
			Set.Filter.Code.Value = FirstRecord.Code;
			Set.Filter.Code.Use = True;
			
			ExchangePlans.RecordChanges(Selection.ExchangeNode, Set);
		
		EndDo;
		
	EndIf;

EndProcedure

#EndRegion

#EndIf