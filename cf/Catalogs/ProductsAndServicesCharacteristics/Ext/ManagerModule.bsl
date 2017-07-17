#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.ProductsAndServices") Then
		// If selection parameter link by products and
		// services value is set, then add selection parameters by the owner filter - products and services group.
		
		ProductsAndServices 		 = Parameters.Filter.Owner;
		ProductsAndServicesCategory = Parameters.Filter.Owner.ProductsAndServicesCategory;
		
		MessageText = "";
		If Not ValueIsFilled(ProductsAndServices) Then
			MessageText = NStr("en='Products and services are not filled in.';ru='Не заполнена номенклатура!'");
		ElsIf Parameters.Property("ThisIsReceiptDocument") AND ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
			MessageText = NStr("en='Accounting by characteristics is not kept for services of external counterparties.';ru='Для услуг сторонних контрагентов не ведется учет по характеристикам!'");
		ElsIf Not ProductsAndServices.UseCharacteristics Then
			MessageText = NStr("en='Accounting by characteristics is not kept for the products and services.';ru='Для номенклатуры не ведется учет по характеристикам!'");
		EndIf;
		
		If Not IsBlankString(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText);
			StandardProcessing = False;
			Return;
		EndIf;
		
		FilterArray = New Array;
		FilterArray.Add(ProductsAndServices);
		FilterArray.Add(ProductsAndServicesCategory);
		
		Parameters.Filter.Insert("Owner", FilterArray);
		
	EndIf;
	
EndProcedure // ChoiceDataGetProcessor()

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf