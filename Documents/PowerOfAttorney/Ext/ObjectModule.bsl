#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
	
		// Filling out a document header.
		ThisObject.BasisDocument = FillingData.Ref;
		Company = FillingData.Company;
		Counterparty = FillingData.Counterparty;
		ForReceiptFrom = ?(ValueIsFilled(Counterparty.DescriptionFull), Counterparty.DescriptionFull, Counterparty.Description);
		Contract = FillingData.Contract;
		ByDocument = FillingData.Ref;
		ForReceiptFrom = FillingData.Counterparty.DescriptionFull;
		BankAccount = FillingData.Company.BankAccountByDefault;
		ActivityDate = CurrentDate() + 5 * 24 * 60 * 60;
		
		// Filling document tabular section.
		Inventory.Clear();
		
		For Each TabularSectionRow IN FillingData.Inventory Do
			
			If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
			
				NewRow = Inventory.Add();
				NewRow.ProductDescription = TabularSectionRow.ProductsAndServices.DescriptionFull;
				NewRow.MeasurementUnit = TabularSectionRow.MeasurementUnit;
				NewRow.Quantity = TabularSectionRow.Quantity;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf