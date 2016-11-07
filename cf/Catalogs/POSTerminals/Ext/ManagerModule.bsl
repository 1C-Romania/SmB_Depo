#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Function GetObjectAttributesBeingLocked() Export
	Result = New Array;
	Return Result;
EndFunction

// Function defines the company, petty cash and currency of selected POS terminal.
//
// Parameters:
//  POSTerminal - CatalogRef.POSTerminals - Refs to POS-Terminal
//
// Returns:
//  Structure - Company, PettyCash and Currency of POS terminal
//
Function GetPOSTerminalAttributes(POSTerminal) Export
	
	Query = New Query("
	|SELECT
	|	POSTerminals.Company AS Company,
	|	POSTerminals.PettyCash AS PettyCash
	|FROM
	|	Catalog.POSTerminals AS POSTerminals
	|WHERE
	|	POSTerminals.Ref = &POSTerminal
	|");
	
	Query.SetParameter("POSTerminal", POSTerminal);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Company = Selection.Company;
		PettyCash = Selection.PettyCash;
	Else
		Company = Undefined;
		PettyCash = Undefined;
	EndIf;
	
	AttributesStructure = New Structure("Company, PettyCash",
		Company,
		PettyCash
	);
	
	Return AttributesStructure;
	
EndFunction // GetPOSTerminalAttributes()

// Function defines the POS terminal by selected petty cash.
//
// Returns POS terminal if one POS terminal is found.
// Returns Undefined if POS terminal is not found or there are more than one POS terminals.
//
// Parameters:
//  Company - CatalogRef.PettyCashes (CatalogRef.CashRegisters) - Ref to petty cash
//
// Returns:
// CatalogRef.POSTerminals - Found POS-Terminal
//
Function GetPOSTerminalByDefault(PettyCash) Export
	
	Query = New Query(
	"SELECT TOP 2
	|	POSTerminals.Ref AS POSTerminal
	|FROM
	|	Catalog.POSTerminals AS POSTerminals
	|WHERE
	|	POSTerminals.PettyCash = &PettyCash");
	
	Query.SetParameter("PettyCash", PettyCash);
	
	Selection = Query.Execute().Select();
	If Selection.Count() = 1 
	   AND Selection.Next()
	Then
		POSTerminal = Selection.POSTerminal;
	Else
		POSTerminal = Undefined;
	EndIf;
	
	Return POSTerminal;

EndFunction // GetPOSTerminalByDefault()

// Procedure kind getting of payment cards accepted by the acquiring contract
//
// Parameters:
//  POSTerminal - CatalogRef.POSTerminals - Refs to POS-Terminal
//
// Return value:
//  Array - Kind array of payment cards
//
Function PaymentCardKinds(POSTerminal) Export
	
	ArrayTypesOfPaymentCards = New Array;
	
	If ValueIsFilled(POSTerminal) Then
		
		Query = New Query(
		"SELECT
		|	PaymentCardKinds.ChargeCardKind AS ChargeCardKind
		|FROM
		|	Catalog.POSTerminals.PaymentCardKinds AS PaymentCardKinds
		|WHERE
		|	PaymentCardKinds.Ref = &Ref");
		
		Query.SetParameter("Ref", POSTerminal);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ArrayTypesOfPaymentCards.Add(Selection.ChargeCardKind);
		EndDo;
		
	EndIf;
	
	Return ArrayTypesOfPaymentCards;
	
EndFunction // PaymentCardKinds()

#EndRegion

#EndIf