#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Function checks whether discount cards with the same code (bar or magnetic) as in transmitted data exist in the IB
//
// Parameters:
//  Data - Structure - data on discount card for which the existence of duplicates is checked
//
Function CheckCatalogDuplicatesDiscountCardsByCodes(Data) Export

	Duplicates = New Array;
	
	Query = New Query;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	DiscountCards.Ref AS DiscountCard,
		|	DiscountCards.Description,
		|	DiscountCards.CardCodeBarcode,
		|	DiscountCards.CardCodeMagnetic,
		|	DiscountCards.CardOwner,
		|	CASE
		|		WHEN DiscountCards.CardCodeBarcode = &CardCodeBarcode
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS FoundByBarcode,
		|	CASE
		|		WHEN DiscountCards.CardCodeMagnetic = &CardCodeMagnetic
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS FoundByMagneticCode
		|FROM
		|	Catalog.DiscountCards AS DiscountCards
		|WHERE
		|	DiscountCards.Owner = &Owner
		|	AND (DiscountCards.CardCodeBarcode = &CardCodeBarcode
		|				AND &CheckBarcode
		|			OR DiscountCards.CardCodeMagnetic = &CardCodeMagnetic
		|				AND &CheckMagneticCode)
		|	AND DiscountCards.Ref <> &Ref";
	
	Query.SetParameter("Owner", Data.Owner);
	Query.SetParameter("CardCodeMagnetic", Data.CardCodeMagnetic);
	Query.SetParameter("CardCodeBarcode", Data.CardCodeBarcode);
	Query.SetParameter("Ref", Data.Ref);
	Query.SetParameter("CheckBarcode", (Data.Owner.CardType = Enums.CardsTypes.Barcode OR Data.Owner.CardType = Enums.CardsTypes.Mixed) AND 
	                                               ValueIsFilled(Data.CardCodeBarcode));
	Query.SetParameter("CheckMagneticCode", (Data.Owner.CardType = Enums.CardsTypes.Magnetic OR Data.Owner.CardType = Enums.CardsTypes.Mixed) AND 
	                                               ValueIsFilled(Data.CardCodeMagnetic));
	
	Result = Query.Execute();
	DuplicatesSelection = Result.Select();
	While DuplicatesSelection.Next() Do
		Duplicates.Add(DuplicatesSelection.DiscountCard);
	EndDo;
	
	Return Duplicates;
	
EndFunction

#EndRegion

#EndIf