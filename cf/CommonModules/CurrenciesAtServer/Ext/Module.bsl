Function GetExchangeRatesValueList(Val Currency, Val ValueStructure, Val GetTopX = 9) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP " + Format(GetTopX,"NFD=0; NG=0") +"
	             |	CurrencyExchangeRates.ExchangeRate,
	             |	CurrencyExchangeRates.Period AS Period,
	             |	CurrencyExchangeRates.NBPTableNumber
	             |FROM
	             |	InformationRegister.CurrencyExchangeRates AS CurrencyExchangeRates
	             |WHERE
	             |	CurrencyExchangeRates.Currency = &Currency
	             |
	             |ORDER BY
	             |	Period DESC";
	
	Query.SetParameter("Currency", Currency);
	Selection = Query.Execute().Select();

	ExchangeRatesValueList = New ValueList;
	
	While Selection.Next() Do
		
		If ValueStructure = Undefined Then
			Value = Selection.ExchangeRate;
		Else
			Value = New Structure;
			For Each KeyAndValue In ValueStructure Do
				Value.Insert(KeyAndValue.Key);
			EndDo;	
			FillPropertyValues(Value,Selection);
		EndIf;	
		ExchangeRatesValueList.Add(Value, "" + Selection.ExchangeRate + " (" + Selection.Period + ")");
		
	EndDo;
	
	Return ExchangeRatesValueList;
	
EndFunction	