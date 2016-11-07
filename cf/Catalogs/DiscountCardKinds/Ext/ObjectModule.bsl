#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PredeterminedProceduresEventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DiscountKindForDiscountCards = Enums.DiscountKindsForDiscountCards.FixedDiscount Then
		DiscountsShortContent = "" + Discount + "%";
		PeriodKind = Enums.PeriodKindsForProgressiveDiscounts.EmptyRef();
		Periodicity = Enums.Periodicity.EmptyRef();
	Else
		FirstPass = True;
		CurContent = "";
		For Each CurRow IN ProgressiveDiscountLimits Do
		
			If FirstPass Then
				FirstPass = False;
			Else
				CurContent = CurContent + "; ";
			EndIf;
			CurContent = CurContent + CurRow.LowerBound + " - " + CurRow.Discount + "%";
		
		EndDo;
		
		DiscountsShortContent = CurContent;
		
		If PeriodKind = Enums.PeriodKindsForProgressiveDiscounts.EntirePeriod Then
			Periodicity = Enums.Periodicity.EmptyRef();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DiscountKindForDiscountCards <> Enums.DiscountKindsForDiscountCards.ProgressiveDiscount OR PeriodKind = Enums.PeriodKindsForProgressiveDiscounts.EntirePeriod Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Periodicity"));
	EndIf;
	
	If DiscountKindForDiscountCards <> Enums.DiscountKindsForDiscountCards.ProgressiveDiscount Then
		CheckedAttributes.Delete(CheckedAttributes.Find("PeriodKind"));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf