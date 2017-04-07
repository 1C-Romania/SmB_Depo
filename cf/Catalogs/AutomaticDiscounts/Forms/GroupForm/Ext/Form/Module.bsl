
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	ThisForm.ReadOnly = Not AllowedEditDocumentPrices;
	
	If Parameters.Key = Undefined Or Parameters.Key.IsEmpty() Then
		
		If Object.SharedUsageVariant.IsEmpty() Then
			Object.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Max;
		EndIf;
		Object.Description = String(Object.SharedUsageVariant);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

// Procedure - event handler OnChange item DiscountsSharedUsageOption.
//
&AtClient
Procedure SharedUsageVariantOfDiscountChargeOnChange(Item)
	
	If IsBlankString(Object.Description) Then
		Object.Description = String(Object.SharedUsageVariant);
	Else
		For Each ItemOfList IN Items.SharedUsageVariantOfDiscountCharge.ChoiceList Do
			If String(ItemOfList.Value) = Object.Description Then
				Object.Description = String(Object.SharedUsageVariant);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion
