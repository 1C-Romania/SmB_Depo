#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PredeterminedProceduresEventsHandlers

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Owner.ThisIsMembershipCard Then
		CheckedAttributes.Add("CardOwner");
	EndIf;
	
	If Not Owner.IsEmpty() Then
		If Owner.CardType = Enums.CardsTypes.Magnetic Then
			CheckedAttributes.Add("CardCodeMagnetic");
		ElsIf Owner.CardType = Enums.CardsTypes.Barcode Then
			CheckedAttributes.Add("CardCodeBarcode");
		Else
			CheckedAttributes.Add("CardCodeMagnetic");
			CheckedAttributes.Add("CardCodeBarcode");
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If Not Owner.ThisIsMembershipCard Then
		CardOwner = Catalogs.Counterparties.EmptyRef();
	EndIf;
	
	If Owner.CardType = Enums.CardsTypes.Magnetic Then
		CardCodeBarcode = "";
	ElsIf Owner.CardType = Enums.CardsTypes.Barcode Then
		CardCodeMagnetic = "";
	EndIf;
	
EndProcedure

#EndRegion

#EndIf