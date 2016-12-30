#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If StructuralUnitType = Enums.StructuralUnitsTypes.Department
	 OR StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "RetailPriceKind");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "GLAccountInRetail");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "MarkupGLAccount");
	EndIf;
	
	If StructuralUnitType = Enums.StructuralUnitsTypes.Retail Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "GLAccountInRetail");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "MarkupGLAccount");
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndRegion

#EndIf