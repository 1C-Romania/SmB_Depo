#If Server Or ThickClientOrdinaryApplication Then

////////////////////////////////////////////////////////////////////////////////
// SERVICE HANDLERS

// Function receives the default counterparty price kind
//
Function CounterpartyDefaultPriceKind(Counterparty) Export
	
	Return ?(ValueIsFilled(Counterparty) AND ValueIsFilled(Counterparty.ContractByDefault),
				Counterparty.ContractByDefault.CounterpartyPriceKind,
				Undefined);
	
EndFunction //CreateUpdateCounterpartyPriceKindDefault()

// Function finds any first price kind of specified counterparty
//
Function FindAnyFirstKindOfCounterpartyPrice(Counterparty) Export
	
	If Not ValueIsFilled(Counterparty) Then
		
		Return Undefined;
		
	EndIf;
	
	Query = New Query("Select TOP 1 * From Catalog.CounterpartyPriceKind AS CounterpartyPriceKind Where CounterpartyPriceKind.Owner = &Counterparty");
	Query.SetParameter("Counterparty", Counterparty);
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Ref, Undefined);
	
EndFunction //FindAnyFirstCounterpartyPriceKind()

// Function creates a price kind of specified counterparty
//
Function CreateCounterpartyPriceKind(Counterparty, SettlementsCurrency) Export
	
	If Not ValueIsFilled(Counterparty)
		OR Not ValueIsFilled(SettlementsCurrency) Then
		
		Return Undefined;
		
	EndIf;
	
	FillStructure = New Structure("Description, Owner, PriceCurrency, PriceIncludesVAT, Comment", 
		Left("Prices for " + Counterparty.Description, 25),
		Counterparty,
		SettlementsCurrency,
		True,
		"Registers the incoming prices. It is created automatically.");
		
	NewCounterpartyPriceKind = Catalogs.CounterpartyPriceKind.CreateItem();
	FillPropertyValues(NewCounterpartyPriceKind, FillStructure);
	NewCounterpartyPriceKind.Write();
	
	Return NewCounterpartyPriceKind.Ref;
	
EndFunction // CreateCounterpartyPriceKind()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf