
#Region WorkWithTabularSectionProducts
	
Procedure CalculateVATAmount(Object, TabularSectionRow) Export
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
											
EndProcedure // CalculateVATAmount() 

Procedure CalculateAmountInTabularSectionRow(Object, TabularSectionRow, TabularSectionName = "Inventory") Export
	
	If TabularSectionName = "Works" Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Multiplicity * TabularSectionRow.Factor * TabularSectionRow.Price;
	Else
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	If IsObjectAttribute("UseDiscounts", TabularSectionRow) And TabularSectionRow.UseDiscounts Then
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			TabularSectionRow.Amount = 0;
		ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 And TabularSectionRow.Quantity <> 0 Then
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		EndIf;
		
		TabularSectionRow.AutomaticDiscountsPercent = 0;
		TabularSectionRow.AutomaticDiscountAmount = 0;
	EndIf; 
	
	CalculateVATAmount(Object, TabularSectionRow);
	
	If IsObjectAttribute("Total", TabularSectionRow) Then
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	EndIf;
	
EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

Function IsObjectAttribute(Val AttributeName, Val Object) Export
	CheckAttribute = New Structure(AttributeName, Undefined);
	FillPropertyValues(CheckAttribute, Object);
	If CheckAttribute[AttributeName] <> Undefined Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction	
	
#EndRegion
