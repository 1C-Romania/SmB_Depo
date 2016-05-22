#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Prices kind.
	If ValueIsFilled(DiscountMarkupKind) Then
		CheckedAttributes.Add("PriceKind");
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Ref <> &Ref
	|	AND CounterpartyContracts.Owner = &Owner
	|	AND Not CounterpartyContracts.Owner.DoOperationsByContracts");
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Owner", Owner);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		MessageText = NStr("en = 'Contracts are not accounted for the counterparty.'");
		SmallBusinessServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			,
			Cancel
		);
	EndIf
	
EndProcedure

#EndIf