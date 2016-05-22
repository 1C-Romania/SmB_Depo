#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Get and read the corresponding layout (text document)
//
Function QueryText_ProductsAndServicesWithSetPrice(UseCharacteristics)
	
	Template = GetTemplate("QueryText_ProductsAndServicesWithSetPrice");
	
	QueryText = Template.GetText();
	
	Return StrReplace(QueryText, "&CharacteristicCondition",
		?(UseCharacteristics, "TRUE", "Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)"));
	
EndFunction // QueryText_ProductsAndServicesWithSetPrice()

// Get and read the corresponding layout (text document)
//
Function QueryText_ProductsAndServicesWithoutSetPrice(UseCharacteristics)
	
	Template = GetTemplate("QueryText_ProductsAndServicesWithoutSetPrice");
	
	QueryText = Template.GetText();
	
	Return StrReplace(QueryText, "&CharacteristicCondition",
		?(UseCharacteristics, "TRUE", "Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)"));
	
EndFunction // QueryText_ProductsAndServicesWithoutSetPrice()

// Function returns the corresponding query text
//
Function QueryTextForAddingByPriceKind(PriceFilled, UseCharacteristics) Export
	
	Return ?(PriceFilled,
		QueryText_ProductsAndServicesWithSetPrice(UseCharacteristics),
		QueryText_ProductsAndServicesWithoutSetPrice(UseCharacteristics)
		);
	
EndFunction // QueryTextForAddingByPriceKind()

#EndRegion

#EndIf