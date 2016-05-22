
// Custom settings. Initial filling.

// The procedure allows you to override the initial filling of the custom settings
//
Procedure OverrideInitialSelectionSettingsFilling(User, StandardProcessing) Export
	
	
	
EndProcedure // OverrideInitialSelectionSettingsFilling()

// End Custom settings. Initial filling.

// Usage table

// The procedure describes the table of using selection forms by documents and tabular sections
//
// Table form UsageTable:
//
// -		DocumentName, Row (100), Document name;
// -	TabularSectionName, Row (100), Document tabular section name;
// - ChoiceForm, Row (100), Full name of the selection form which should be used as a selection form;
//
Procedure ChoiceFormsUsageTable(UsageTable) Export
	
	// Implementation
	ChoiceFormFullName = DataProcessors.PickingSales.ChoiceFormFullName();
	
	AddSelectionUsageRow(UsageTable, Metadata.Documents.InvoiceForPayment.Name, Metadata.Documents.InvoiceForPayment.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.CustomerOrder.Name, Metadata.Documents.CustomerOrder.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.AcceptanceCertificate.Name, Metadata.Documents.AcceptanceCertificate.TabularSections.WorksAndServices.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.CustomerInvoice.Name, Metadata.Documents.CustomerInvoice.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.CustomerInvoiceNote.Name, Metadata.Documents.CustomerInvoiceNote.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.ReceiptCR.Name, Metadata.Documents.ReceiptCR.TabularSections.Inventory.Name, ChoiceFormFullName);
	
	// Receipt
	ChoiceFormFullName = DataProcessors.PickingReceipt.ChoiceFormFullName();
	
	AddSelectionUsageRow(UsageTable, Metadata.Documents.SupplierInvoiceForPayment.Name, Metadata.Documents.SupplierInvoiceForPayment.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.PurchaseOrder.Name, Metadata.Documents.PurchaseOrder.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.SupplierInvoice.Name, Metadata.Documents.SupplierInvoice.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.SupplierInvoice.Name, Metadata.Documents.SupplierInvoice.TabularSections.Expenses.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.SupplierInvoiceNote.Name, Metadata.Documents.SupplierInvoiceNote.TabularSections.Inventory.Name, ChoiceFormFullName);
	
	// Other
	ChoiceFormFullName = DataProcessors.PickingTransfer.ChoiceFormFullName();
	
	AddSelectionUsageRow(UsageTable, Metadata.Documents.InventoryTransfer.Name, Metadata.Documents.InventoryTransfer.TabularSections.Inventory.Name, ChoiceFormFullName);
	
EndProcedure // ChoiceFormsUsageTable()

// The procedure adds a new row to the usage table
//
Procedure AddSelectionUsageRow(UsageTable, DocumentName, TabularSectionName, ChoiceFormFullName)
	
	NewRow = UsageTable.Add();
	
	NewRow.DocumentName 		= DocumentName;
	NewRow.TabularSectionName	= TabularSectionName;
	NewRow.PickForm		= ChoiceFormFullName;
	
EndProcedure // AddSelectionUsageRow()

// End Usage table


// Full-text search

Function FullTextSearchProducts(SearchString, SearchResult)
	
	BarcodesArray = New Array;
	
	// Search data
	PortionSize = 200;
	SearchArea = New Array;
	SearchArea.Add(Metadata.Catalogs.ProductsAndServices);
	SearchArea.Add(Metadata.Catalogs.ProductsAndServicesCharacteristics);
	SearchArea.Add(Metadata.InformationRegisters.AdditionalInformation);
	SearchArea.Add(Metadata.InformationRegisters.ProductsAndServicesBarcodes);
	
	SearchList = FullTextSearch.CreateList(SearchString, PortionSize);
	SearchList.GetDescription = False;
	SearchList.SearchArea = SearchArea;
	SearchList.FirstPart();
	
	If SearchList.TooManyResults() Then
		Return "TooManyResults";
	EndIf;
	
	FoundItemsQuantity = SearchList.TotalCount();
	If FoundItemsQuantity = 0 Then
		Return "FoundNothing";
	EndIf;
	
	// Data processing
	StartPosition	= 0;
	EndPosition		= ?(FoundItemsQuantity > PortionSize, PortionSize, FoundItemsQuantity) - 1;
	IsNextPortion = True;

	While IsNextPortion Do
		
		For CountElements = 0 To EndPosition Do
			
			Item = SearchList.Get(CountElements);
			
			If Item.Metadata = Metadata.Catalogs.ProductsAndServices Then
				
				SearchResult.ProductsAndServices.Add(Item.Value);
				
			ElsIf Item.Metadata = Metadata.Catalogs.ProductsAndServicesCharacteristics Then
				
				SearchResult.ProductsAndServicesCharacteristics.Add(Item.Value);
				
			ElsIf Item.Metadata = Metadata.InformationRegisters.AdditionalInformation Then
				
				If TypeOf(Item.Value.Object) = Type("CatalogRef.ProductsAndServices") Then
					
					SearchResult.ProductsAndServices.Add(Item.Value.Object);
					
				EndIf;
				
			ElsIf Item.Metadata = Metadata.InformationRegisters.ProductsAndServicesBarcodes Then
				
				BarcodesArray.Add(Item.Value.Barcode);
				
			Else
				
				Raise NStr("en = 'Unknown error'");
				
			EndIf;
			
		EndDo;
		
		StartPosition    = StartPosition + PortionSize;
		IsNextPortion = (StartPosition < FoundItemsQuantity - 1);
		
		If IsNextPortion Then
			
			EndPosition = ?(FoundItemsQuantity > StartPosition + PortionSize,
			                    PortionSize,
			                    FoundItemsQuantity - StartPosition
			                    ) - 1;
			SearchList.NextPart();
			
		EndIf;
		
	EndDo;
	
	If BarcodesArray.Count() > 0 Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ProductsAndServicesBarcodes.ProductsAndServices AS ProductsAndServices,
		|	ProductsAndServicesBarcodes.Characteristic AS Characteristic
		|FROM
		|	InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
		|WHERE
		|	ProductsAndServicesBarcodes.Barcode IN(&BarcodesArray)
		|	AND ProductsAndServicesBarcodes.ProductsAndServices REFS Catalog.ProductsAndServices";
		
		Query.SetParameter("BarcodesArray", BarcodesArray);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			SearchResult.ProductsAndServices.Add(Selection.ProductsAndServices);
			
		EndDo;
		
	EndIf;
	
	Return "CompletedSuccessfully";
	
EndFunction

Function SearchGoods(SearchString, ErrorDescription) Export
	
	SearchResult = New Structure;
	SearchResult.Insert("ProductsAndServices", New Array);
	SearchResult.Insert("ProductsAndServicesCharacteristics", New Array);
	
	Result = FullTextSearchProducts(SearchString, SearchResult);
	
	If Result = "CompletedSuccessfully" Then
		
		Return SearchResult;
		
	ElsIf Result = "TooManyResults" Then
		
		ErrorDescription = NStr("en = 'Too many results. Refine your query.'");
		Return SearchResult;
		
	ElsIf Result = "FoundNothing" Then
		
		ErrorDescription = NStr("en = 'Nothing found'");
		Return SearchResult;
		
	Else
		
		Raise NStr("en = 'Unknown error'");
		
	EndIf;
	
EndFunction

// End Full-text search

Function PriceKindCustomerInvoiceNotes(Counterparty, CounterpartyContract, Incoming = True) Export
	
	PriceKind = Undefined;
	If ValueIsFilled(CounterpartyContract) Then
		
		PriceKind = CommonUse.GetAttributeValue(CounterpartyContract, ?(Incoming, "CounterpartyPriceKind", "PriceKind"));
		
	ElsIf ValueIsFilled(Counterparty) Then
		
		CounterpartyContract = Counterparty.ContractByDefault;
		If ValueIsFilled(CounterpartyContract) Then
			
			PriceKind = CommonUse.GetAttributeValue(CounterpartyContract, ?(Incoming, "CounterpartyPriceKind", "PriceKind"));
			
		EndIf;
		
	EndIf;
	
	Return PriceKind
	
EndFunction
