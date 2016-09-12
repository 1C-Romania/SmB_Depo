#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler ChoiceDataReceivingProcessing.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Property("Recursion")
		AND Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.ProductsAndServices") Then
		// When first entering if selection parameter link is set by
		// products and services value then add selection parameters by the selection on owner - products and services categories according to the hierarchy.
		
		StandardProcessing = False;
		
		ProductsAndServices 		 = Parameters.Filter.Owner;
		ProductsAndServicesCategory = Parameters.Filter.Owner.ProductsAndServicesCategory;
		
		FilterArray = New Array;
		FilterArray.Add(ProductsAndServices);
		FilterArray.Add(ProductsAndServicesCategory);
		
		Parent = ProductsAndServicesCategory.Parent;
		While ValueIsFilled(Parent) Do
			FilterArray.Add(Parent);
			Parent = Parent.Parent;
		EndDo;
		
		Parameters.Filter.Insert("Owner", FilterArray);
		
		// Flag of repeated logon.
		Parameters.Insert("Recursion");
		
		// Get standard selection list with respect to added filter.
		StandardList = GetChoiceData(Parameters);
		
		If Not (Parameters.Property("DontUseClassifier") AND Parameters.DontUseClassifier = True) Then
			If ValueIsFilled(Parameters.Filter.Owner) Then
			// Add standard list by basic products and services UOM according to the classifier.
				PresentationUOM = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1 (storage unit)';ru='%1 (ед. хранения)'"),
					ProductsAndServices.MeasurementUnit.Description);
				StandardList.Insert(0, ProductsAndServices.MeasurementUnit, 
					New FormattedString(PresentationUOM, New Font(,,True)));
			Else
				CommonUseClientServer.MessageToUser(NStr("en='Products and services are not filled!';ru='Не заполнена номенклатура!'"));
			EndIf;
		EndIf;
		
		ChoiceData = StandardList;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf