////////////////////////////////////////////////////////////////////////////////
// Document search and creation (SB)

Function GetTSRowsData(FillingData, ParseTree) Export
	
	IBAttributes			 		= New Structure;
	CounterpartyIBAttributes 		= New Structure;
	DataForFillingTSRow = New Structure();
	
	For Each CurRow IN FillingData Do
		
		AttributeNameInDB = CurRow.Attribute;
		
		If Upper(AttributeNameInDB) = Upper("Definition") Then
			AttributeNameInDB = "Content";
		EndIf;
		
		FoundValue = GetAttributeValue(CurRow, CurRow.Attribute, True, ParseTree);
		
		//If it is the order number, you shall search for the document reference.
		If UPPER(AttributeNameInDB) = UPPER("NumberBySupplierData")
			AND Not IsBlankString(FoundValue) Then
			CounterpartyIBAttributes.Insert("NumberBySupplierData", FoundValue);
		EndIf;
		
		If UPPER(AttributeNameInDB) = UPPER("AccordingToBuyersOrderNumber")
			AND Not IsBlankString(FoundValue) Then
			IBAttributes.Insert("Number", FoundValue);
		EndIf;
		
		DataForFillingTSRow.Insert(AttributeNameInDB, FoundValue);
		
		If CurRow.Attribute = "ProductsAndServices" AND ValueIsFilled(FoundValue) Then
			
			CurProductsAndServices = FoundValue;
			
			StringProductsAndServices = ParseTree.Rows.Find(CurRow.AttributeValue,"RowIndex",True);
			FoundValue = GetAttributeValue(StringProductsAndServices, "MeasurementUnit", True, ParseTree);
			If ValueIsFilled(FoundValue) Then
				DataForFillingTSRow.Insert("MeasurementUnit", FoundValue);
			Else
				DataForFillingTSRow.Insert("MeasurementUnit", CurProductsAndServices.MeasurementUnit);
			EndIf;
			
		ElsIf CurRow.Attribute = "ID" AND ValueIsFilled(CurRow.AttributeValue) Then
			
			FoundValue = Catalogs.SuppliersProductsAndServices.FindByAttribute("ID", CurRow.AttributeValue);
			If ValueIsFilled(FoundValue) AND ValueIsFilled(FoundValue.Characteristic) Then
				DataForFillingTSRow.Insert("Characteristic", FoundValue.Characteristic);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	DataForFillingTSRow.Amount = DataForFillingTSRow.Quantity * DataForFillingTSRow.Price;
	
	// Attribute AmontInclVAT in SB is called TOTAL
	DataForFillingTSRow.Insert("Total",
		?(DataForFillingTSRow.Property("SumWithVAT"),
				DataForFillingTSRow.SumWithVAT,
				DataForFillingTSRow.Amount + DataForFillingTSRow.VATAmount)
				);
				
	// If the order number is passed, try to find
	If IBAttributes.Count() > 0
		OR CounterpartyIBAttributes.Count() > 0 Then
		
		EDKind 		= Enums.EDKinds.ResponseToOrder;
		Counterparty	= GetAttributeValue(ParseTree, "Counterparty", True, ParseTree);
		
		If ValueIsFilled(Counterparty) Then
		
			FoundDocument = FindDocument(EDKind, Counterparty, IBAttributes, CounterpartyIBAttributes);
			If ValueIsFilled(FoundDocument) Then
				DataForFillingTSRow.Insert("Order", FoundDocument);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not DataForFillingTSRow.Property("Content")
		AND DataForFillingTSRow.Property("Description") Then
		DataForFillingTSRow.Insert("Content", DataForFillingTSRow.Description);
	EndIf;
	
	Return DataForFillingTSRow;
	
EndFunction

Function GetAttributeValue(TreeRow, AttributeName, IncludeSubordinated = False, ParseTree = Undefined) Export
	
	Result = Undefined;
	
	If TreeRow.Rows.Count()>0 Then
		FoundString = TreeRow.Rows.Find(AttributeName, "Attribute", IncludeSubordinated);
	Else
		FoundString = TreeRow;
	EndIf;
	
	If FoundString <> Undefined Then
		Result = FoundString.AttributeValue;
		// If the attribute is of reference
		// type (ParseTree attribute is passed), we find only string index
		If ValueIsFilled(ParseTree) Then 
			FoundString = ParseTree.Rows.Find(Result, "RowIndex", True);
			If FoundString <> Undefined Then
				Result = FoundString.ObjectReference;
			EndIf;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Function PrepareStructureForGoodsServicesReceipt(StringForImport, ParseTree, ThisIsAct = False) Export
	
	DataForObject		= New Structure;
	FillingDataHeader	= New Structure;
	Inventory 					= Documents.SupplierInvoice.EmptyRef().Inventory.UnloadColumns();
	Expenses 				= Documents.SupplierInvoice.EmptyRef().Expenses.UnloadColumns();
	
	For Each AttributeString IN StringForImport.Rows Do
		
		If AttributeString.Attribute = "DescriptionsList" Then
			
			WorksDescriptionAttributeString = GetAttributeValue(AttributeString, AttributeString.Attribute, True, ParseTree);
			
			For Each DescriptionAttributeString IN WorksDescriptionAttributeString.Rows Do
				
				If DescriptionAttributeString.Rows.Count() = 0 Then
					
					AttributeValue = GetAttributeValue(DescriptionAttributeString, DescriptionAttributeString.Attribute, True, ParseTree);
					
					If ValueIsFilled(AttributeValue) Then
						FillingDataHeader.Insert(DescriptionAttributeString.Attribute, AttributeValue);
					EndIf;
					
				Else
					
					DataForFillingTSRow = GetTSRowsData(DescriptionAttributeString.Rows, ParseTree);
					
					If ThisIsAct
						OR (ValueIsFilled(DataForFillingTSRow.ProductsAndServices)
						AND DataForFillingTSRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service) Then
						
						NewRow = Expenses.Add();
					Else
						NewRow = Inventory.Add();
					EndIf;
					
					FillPropertyValues(NewRow, DataForFillingTSRow);
					
				EndIf;
				
			EndDo;
			
		Else
			
			If AttributeString.Rows.Count() = 0 Then 
				
				// Fill in header attribute
				AttributeValue = GetAttributeValue(AttributeString, AttributeString.Attribute, True, ParseTree);
				
				If AttributeString.Attribute = "Date" Then
					AttributeName = "IncomingDocumentDate";
				ElsIf AttributeString.Attribute = "Number" Then
					AttributeName = "IncomingDocumentNumber";
				ElsIf AttributeString.Attribute = "Currency" Then
					AttributeName = "DocumentCurrency";
				Else
					AttributeName = AttributeString.Attribute;
				EndIf;
				
				If ValueIsFilled(AttributeValue) Then
					FillingDataHeader.Insert(AttributeName, AttributeValue);
				EndIf;
				
			Else 
				// Add the table section line
				DataForFillingTSRow = GetTSRowsData(AttributeString.Rows, ParseTree);
				
				If ThisIsAct
					OR (ValueIsFilled(DataForFillingTSRow.ProductsAndServices)
					AND DataForFillingTSRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service) Then
					
					NewRow = Expenses.Add();
				Else
					NewRow = Inventory.Add();
				EndIf;
				
				FillPropertyValues(NewRow, DataForFillingTSRow);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	FillingDataHeader.Insert("PurchaseOrderPosition", Enums.AttributePositionOnForm.InTabularSection);
	
	If Not GetFunctionalOption("AccountingBySeveralWarehouses") Then
		FillingDataHeader.Insert("StructuralUnit", Catalogs.StructuralUnits.MainWarehouse);
	EndIf;
	
	FillingDataHeader.Delete("OperationKind");
	DataForObject.Insert("Header"  , FillingDataHeader);
	DataForObject.Insert("Inventory" , Inventory);
	
	User = Users.CurrentUser();
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDepartment);
	
	For Each String IN Expenses Do
		String.StructuralUnit = MainDepartment;
		If ValueIsFilled(String.ProductsAndServices) Then
			String.BusinessActivity = CommonUse.GetAttributeValue(String.ProductsAndServices, "BusinessActivity");
		EndIf;
	EndDo;
	DataForObject.Insert("Expenses", Expenses);
	
	Return DataForObject;
	
EndFunction

Function PrepareStructureForCustomerOrder(StringForImport, ParseTree) Export
	
	DataForObject = New Structure;
	FillingDataHeader = New Structure;
	Inventory = Documents.CustomerOrder.EmptyRef().Inventory.UnloadColumns();
	
	For Each AttributeString IN StringForImport.Rows Do
		
		If AttributeString.Rows.Count()=0 Then // primitive type
			
			AttributeValue = GetAttributeValue(AttributeString, AttributeString.Attribute, True, ParseTree);
			
			If AttributeString.Attribute = "PriceIncludesVAT" Then
				
				AttributeName = "AmountIncludesVAT";
				
			ElsIf AttributeString.Attribute = "Currency" Then
				
				AttributeName = "DocumentCurrency";
				
			ElsIf AttributeString.Attribute = "ExchangeRate" Then
				
				AttributeName = "MutualSettlementsExchangeRate";
				
			ElsIf AttributeString.Attribute = "DateByCustomerData" 
				OR AttributeString.Attribute = "DateBySupplierData" Then
				
				AttributeName = "IncomingDocumentDate";
				
			ElsIf AttributeString.Attribute = "NumberByCustomerData" 
				OR AttributeString.Attribute = "NumberBySupplierData" Then
				
				AttributeName = "IncomingDocumentNumber";
				
			Else
				
				AttributeName = AttributeString.Attribute;
				
			EndIf;
			
			If ValueIsFilled(AttributeValue) Then
				
				FillingDataHeader.Insert(AttributeName, AttributeValue);
				
			EndIf;
			
		ElsIf AttributeString.Attribute = "TSRow" Then
			
			// Add the table section line
			DataForFillingTSRow = GetTSRowsData(AttributeString.Rows, ParseTree);
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, DataForFillingTSRow);
			
			If ValueIsFilled(NewRow.ProductsAndServices) Then
				ProductsAndServicesType = CommonUse.ObjectAttributeValue(NewRow.ProductsAndServices, "ProductsAndServicesType");
				NewRow.ProductsAndServicesTypeInventory = ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	DataForObject.Insert("Header", 	FillingDataHeader);
	DataForObject.Insert("Inventory",	Inventory);
	
	Return DataForObject;
	
EndFunction

Function PrepareStructureForPaymentOrder(StringForImport, ParseTree) Export
	
	DataForObject			= New Structure;
	FillingDataHeader		= New Structure;
	Inventory = Documents.PurchaseOrder.EmptyRef().Inventory.UnloadColumns();
	
	For Each AttributeString IN StringForImport.Rows Do
		
		If AttributeString.Rows.Count() = 0 Then // primitive type
			
			AttributeValue = GetAttributeValue(AttributeString, AttributeString.Attribute, True, ParseTree);
			
			If AttributeString.Attribute = "PriceIncludesVAT" Then
				
				AttributeName = "AmountIncludesVAT";
				
			ElsIf AttributeString.Attribute = "Currency" Then
				
				AttributeName = "DocumentCurrency";
				
			ElsIf AttributeString.Attribute = "ExchangeRate" Then
				
				AttributeName = "ExchangeRate";
				
			ElsIf AttributeString.Attribute = "NumberBySupplierData" Then
				
				AttributeName = "IncomingDocumentNumber";
				
			ElsIf AttributeString.Attribute = "DateBySupplierData" Then
				
				AttributeName = "IncomingDocumentDate";
				
			Else
				
				AttributeName = AttributeString.Attribute;
				
			EndIf;
			
			FillingDataHeader.Insert(AttributeName, AttributeValue);
			
		ElsIf AttributeString.Attribute = "TSRow" Then
			
			// Add the table section line
			DataForFillingTSRow = GetTSRowsData(AttributeString.Rows, ParseTree);
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, DataForFillingTSRow);
			
		EndIf;
		
	EndDo;
	
	DataForObject.Insert("Header",  FillingDataHeader);
	DataForObject.Insert("Inventory", Inventory);
	
	Return DataForObject;
	
EndFunction

// Finds the IB document by parameters.
//
// Parameters:
//  EDKind - Enums.EDKinds - Electronic document kind used to search IB document,
//  Counterparty - Ref to the counterparty,
//  IBAttributes - infobase parameter structure,
//  CounterpartyIBAttributes - counterparty parameter structure in the infobase.
//
Function FindDocument(EDKind, Counterparty, IBAttributes = Undefined, CounterpartyIBAttributes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	FoundDoc	= Undefined;
	Query 			= New Query("SELECT ALLOWED SearchedDocument.Ref AS Ref FROM &SpecifyQueryDocumentKind AS SearchedDocument WHERE SearchedDocument.Counterparty = &Counterparty");
	Query.SetParameter("Counterparty", Counterparty);
	
	If EDKind = Enums.EDKinds.ProductOrder Then
		
		Query.Text = StrReplace(Query.Text, "&IndicateQueryDocumentKind", "Document.CustomerOrder");
		
	ElsIf EDKind = Enums.EDKinds.ResponseToOrder Then
		
		Query.Text = StrReplace(Query.Text, "&IndicateQueryDocumentKind", "Document.PurchaseOrder");
		
	EndIf;
	
	FoundDoc = SearchDocumentForDetails(IBAttributes, Query);
	
	If FoundDoc = Undefined Then
		
		FoundDoc = SearchDocumentForDetails(CounterpartyIBAttributes, Query);
		
	EndIf;
	
	Return FoundDoc;
	
EndFunction

Function FoundCreateProductsServicesReceipt(StringForImport, ParseTree, RefToOwner = Undefined, ThisIsAct = False) Export
	
	DataForExport = PrepareStructureForGoodsServicesReceipt(StringForImport, ParseTree, ThisIsAct);
	If DataForExport.Property("Header") Then 
		FillingData = DataForExport.Header;
	EndIf; 
	
	WriteMode = DocumentWriteMode.Write;
	
	Try
		
		If ValueIsFilled(RefToOwner) Then // we receive the changes of the existing document
			
			If RefToOwner.Posted Then 
				Raise NStr("en='Filling according to the ED is possible only for the unposted document';ru='Заполнение на основании ЭД возможно только для непроведенного документа'");
			EndIf;
			
			DocumentObject = RefToOwner.GetObject();
			
		Else // create new
			
			SetPrivilegedMode(True);
			DocumentObject = Documents.SupplierInvoice.CreateDocument();
			DocumentObject.Date = CurrentSessionDate();
			
			SmallBusinessServer.FillDocumentHeader(DocumentObject,,,, True, );
			DocumentObject.Fill(FillingData);
			DocumentObject.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
			
			DocumentObject.DataExchange.Load = True;
			
		EndIf;
		
		// Fill in the header attributes based on the filling data structure
		RefillingHeaderAttributesValues(DocumentObject, FillingData);
		
		// Import tabular sections
		DocumentObject.Inventory.Load(DataForExport.Inventory);
		DocumentObject.Expenses.Load(DataForExport.Expenses);
		
		// Fill in rate and multiplicity
		ExchangeRateCurrencies					= WorkWithCurrencyRates.GetCurrencyRate(DocumentObject.DocumentCurrency, DocumentObject.Date);
		DocumentObject.ExchangeRate			= ExchangeRateCurrencies.ExchangeRate;
		DocumentObject.Multiplicity	= ExchangeRateCurrencies.Multiplicity;
		
		NationalCurrency = Constants.NationalCurrency.Get();
		If DocumentObject.DocumentCurrency <> NationalCurrency Then
			RecalculateTabularSectionPricesByCurrency(DocumentObject, NationalCurrency, "Inventory");
			RecalculateTabularSectionPricesByCurrency(DocumentObject, NationalCurrency, "Expenses");
		EndIf;
		
		// We configure some header attributes manually
		If Not ValueIsFilled(DocumentObject.Contract)
			OR DocumentObject.Contract.SettlementsCurrency <> DocumentObject.DocumentCurrency Then
			FillCounterpartyContract(DocumentObject);
		EndIf;
		
		If FillingData.Property("VATAmount")
			AND FillingData.VATAmount > 0 Then
			DocumentObject.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		Else
			DocumentObject.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT;
		EndIf;
		
		DocumentObject.AmountIncludesVAT = True;
		DocumentObject.DocumentAmount = DocumentObject.Inventory.Total("Total") + DocumentObject.Expenses.Total("Total");
		
		If Not ValueIsFilled(DocumentObject.DocumentCurrency) Then
			DocumentObject.DocumentCurrency = Constants.NationalCurrency.Get();
		EndIf;
		
		If DocumentObject.IsNew() Then
			DocumentObject.SetNewNumber();
		EndIf;
		
		DocumentObject.DataExchange.Load = True;
		DocumentObject.Write(WriteMode);
	Except
		
		WriteLogEvent(NStr("en='Filling on the ED basis';ru='Заполнение на основании ЭД'"),
			EventLogLevel.Error, 
			Metadata.Documents.PurchaseOrder, 
			RefToOwner, 
			DetailErrorDescription(ErrorInfo()));
		Raise;
		
	EndTry;
	
	Return DocumentObject.Ref;
	
EndFunction

Function FoundCreateCustomerOrder(StringForImport, ParseTree, RefToOwner = Undefined) Export
	
	DataForExport = PrepareStructureForCustomerOrder(StringForImport, ParseTree);
	
	If DataForExport.Property("Header") Then 
		
		FillingData = DataForExport.Header;
		
	EndIf; 
	
	WriteMode = DocumentWriteMode.Write;
	
	Try
		
		If ValueIsFilled(RefToOwner) Then // we receive the changes of the existing document
			
			If RefToOwner.Posted Then 
				Raise NStr("en='Filling according to the ED is possible only for the unposted document';ru='Заполнение на основании ЭД возможно только для непроведенного документа'");
			EndIf;
			
			DocumentObject = RefToOwner.GetObject();
			
		Else // try to find by IBAttributes and CounterpartyIBAttributes
			
			SetPrivilegedMode(True);
			
			FoundDoc = Undefined;
			If FillingData.Property("Counterparty") Then
				
				CounterpartyIBAttributes = New Structure;
				If FillingData.Property("NumberByCustomerData") AND ValueIsFilled(FillingData.NumberByCustomerData) Then
					
					CounterpartyIBAttributes.Insert("NumberByCustomerData", FillingData.NumberByCustomerData);
					
				ElsIf FillingData.Property("IncomingDocumentNumber") AND ValueIsFilled(FillingData.IncomingDocumentNumber) Then
					
					CounterpartyIBAttributes.Insert("IncomingDocumentNumber", FillingData.IncomingDocumentNumber);
					
				EndIf;
				
				If FillingData.Property("DateByCustomerData") AND ValueIsFilled(FillingData.DateByCustomerData) Then
					
					CounterpartyIBAttributes.Insert("DateByCustomerData", FillingData.DateByCustomerData);
					
				ElsIf FillingData.Property("IncomingDocumentDate") AND ValueIsFilled(FillingData.IncomingDocumentDate) Then
					
					CounterpartyIBAttributes.Insert("IncomingDocumentDate", FillingData.IncomingDocumentDate);
					
				EndIf;
				
				IBAttributes = New Structure;
				If FillingData.Property("NumberBySupplierData") AND ValueIsFilled(FillingData.NumberBySupplierData) Then
					
					IBAttributes.Insert("Number", FillingData.NumberBySupplierData);
					
				EndIf;
				
				If FillingData.Property("DateBySupplierData") AND ValueIsFilled(FillingData.DateBySupplierData) Then
					
					IBAttributes.Insert("Date", FillingData.DateBySupplierData);
					
				EndIf;
				
				If IBAttributes.Count() > 0 OR CounterpartyIBAttributes.Count() > 0 Then // besides there are search attributes, except for Counterparty
					
					FoundDoc = FindDocument(Enums.EDKinds.ProductOrder, FillingData.Counterparty, IBAttributes, CounterpartyIBAttributes);
					
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(FoundDoc) Then // we find the document, return the reference to attach ED
				
				DocumentObject = FoundDoc.GetObject();
				Return DocumentObject.Ref;
				
			EndIf;
			
			DocumentObject = Documents.CustomerOrder.CreateDocument();
			
			SmallBusinessServer.FillDocumentHeader(DocumentObject,,,, True, );
			DocumentObject.Fill(FillingData);
			DocumentObject.Company = FillingData.Company;
			
			DocumentObject.Date = CurrentSessionDate();
			
		EndIf;
		
		// Fill in the header attribute values
		RefillingHeaderAttributesValues(DocumentObject, FillingData);
		
		If Not ValueIsFilled(DocumentObject.Contract)
			OR DocumentObject.Contract.SettlementsCurrency <> DocumentObject.DocumentCurrency Then
			FillCounterpartyContract(DocumentObject);
		EndIf;
		
		//DocumentObject.DocumentAmount 			= DataForExport.Header.AmountTotal;
		DocumentObject.Multiplicity	= 1;
		DocumentObject.OperationKind	= Enums.OperationKindsCustomerOrder.OrderForSale;
		
		// Import tabular sections
		DocumentObject.Inventory.Load(DataForExport.Inventory);
		
		If DocumentObject.AmountIncludesVAT Then
			
			For Each String in DocumentObject.Inventory Do
				
				String.Amount = String.Amount + String.VATAmount;
				
			EndDo;
			
		EndIf;
		
		If DocumentObject.IsNew() Then
			
			DocumentObject.SetNewNumber();
			
		EndIf;
		
		DocumentObject.DataExchange.Load = True;
		DocumentObject.Write();
		
	Except
		
		WriteLogEvent(NStr("en='Filling on the ED basis';ru='Заполнение на основании ЭД'"), 
			EventLogLevel.Error, 
			Metadata.Documents.CustomerOrder, 
			RefToOwner, 
			DetailErrorDescription(ErrorInfo()));
		Raise;
		
	EndTry;
	
	Return DocumentObject.Ref;
	
EndFunction

Function FoundCreatePurchaseOrder(StringForImport, ParseTree, RefToOwner = Undefined) Export
	
	DataForExport = PrepareStructureForPaymentOrder(StringForImport, ParseTree);
	
	If DataForExport.Property("Header") Then 
		
		FillingData = DataForExport.Header;
		
	EndIf;
	
	WriteMode = DocumentWriteMode.Write;
	
	Try
		
		If ValueIsFilled(RefToOwner) Then // we receive the changes of the existing document
			
			If RefToOwner.Posted Then 
				Raise NStr("en='Filling according to the ED is possible only for the unposted document';ru='Заполнение на основании ЭД возможно только для непроведенного документа'");
			EndIf;
			
			DocumentObject = RefToOwner.GetObject();
			
		Else // try to find by IBAttributes and CounterpartyIBAttributes
			
			SetPrivilegedMode(True);
			
			FoundDoc = Undefined;
			If FillingData.Property("Counterparty") Then
				
				CounterpartyIBAttributes = New Structure;
				If FillingData.Property("IncomingDocumentNumber") 
					AND ValueIsFilled(FillingData.IncomingDocumentNumber) Then
					
					CounterpartyIBAttributes.Insert("IncomingDocumentNumber", FillingData.IncomingDocumentNumber);
					
				EndIf;
				
				If FillingData.Property("IncomingDocumentDate") 
					AND ValueIsFilled(FillingData.IncomingDocumentDate) Then
					
					CounterpartyIBAttributes.Insert("IncomingDocumentDate", FillingData.IncomingDocumentDate);
					
				EndIf;
				
				IBAttributes = New Structure;
				If FillingData.Property("Number") 
					AND ValueIsFilled(FillingData.Number) Then
					
					IBAttributes.Insert("Number", FillingData.Number);
					
				EndIf;
				
				If FillingData.Property("Date") 
					AND ValueIsFilled(FillingData.Date) Then
					
					IBAttributes.Insert("Date", FillingData.Date);
					
				EndIf;
				
				If IBAttributes.Count() > 0 
					OR CounterpartyIBAttributes.Count() > 0 Then 
					
					FoundDoc = FindDocument(Enums.EDKinds.ResponseToOrder, FillingData.Counterparty, IBAttributes, CounterpartyIBAttributes);
					
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(FoundDoc) Then 
				
				// we find the document, return the reference to attach ED
				Return FoundDoc.Ref;
				
			EndIf;
			
			DocumentObject 				= Documents.PurchaseOrder.CreateDocument();
			SmallBusinessServer.FillDocumentHeader(DocumentObject,,,, True, );
			DocumentObject.Fill(FillingData);
			DocumentObject.Date			= CurrentSessionDate();
			
			If TypeOf(FillingData) = Type("Structure")
				AND FillingData.Property("Company") Then
				
				DocumentObject.Company	= FillingData.Company;
				
			EndIf;
			
		EndIf;
		
		// Fill in the header attribute values
		RefillingHeaderAttributesValues(DocumentObject, FillingData);
		
		DocumentObject.DocumentAmount 	= DataForExport.Header.AmountTotal;
		DocumentObject.OperationKind		= Enums.OperationKindsPurchaseOrder.OrderForPurchase;
		
		// Import tabular sections
		DocumentObject.Inventory.Load(DataForExport.Inventory);
		
		// We configure some header attributes manually
		If Not ValueIsFilled(DocumentObject.Contract)
			OR DocumentObject.Contract.SettlementsCurrency <> DocumentObject.DocumentCurrency Then
			FillCounterpartyContract(DocumentObject);
		EndIf;
		
		If DocumentObject.AmountIncludesVAT Then
			
			For Each String in DocumentObject.Inventory Do
				String.Amount = String.Amount + String.VATAmount;
			EndDo
			
		EndIf;
		
		If FillingData.TaxAmountTotal > 0 Then
			DocumentObject.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		Else
			DocumentObject.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT;
		EndIf;
		
		If Not ValueIsFilled(DocumentObject.DocumentCurrency) Then
			DocumentObject.DocumentCurrency = Constants.NationalCurrency.Get();
		EndIf;
		
		// Fill in rate and multiplicity
		ExchangeRateCurrencies					= WorkWithCurrencyRates.GetCurrencyRate(DocumentObject.DocumentCurrency, DocumentObject.Date);
		DocumentObject.ExchangeRate			= ExchangeRateCurrencies.ExchangeRate;
		DocumentObject.Multiplicity	= ExchangeRateCurrencies.Multiplicity;
		
		If DocumentObject.IsNew() Then
			DocumentObject.SetNewNumber();
		EndIf;
		
		DocumentObject.DataExchange.Load = True;
		DocumentObject.Write();
		
	Except
		
		WriteLogEvent(NStr("en='Filling on the ED basis';ru='Заполнение на основании ЭД'"),
			EventLogLevel.Error, 
			Metadata.Documents.PurchaseOrder, 
			RefToOwner, 
			DetailErrorDescription(ErrorInfo()));
		Raise;
		
	EndTry;
	
	Return DocumentObject.Ref;
	
EndFunction

Procedure SaveProductCatalogData(ImportRow, ParseTree, RefToOwner = Undefined) Export
	
	TSRows = ImportRow.Rows.FindRows(New Structure("Attribute", "TSRow"));
	ImportTab = New ValueTable;
	ImportTab.Columns.Add("ProductIdentifier");
	ImportTab.Columns.Add("PropertyValues");
	
	For Each TSRow IN TSRows Do
		
		ProductIdentifier = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																TSRow,
																"SupplierProductsAndServices.ID");
		
		PropertyValues = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
																ParseTree,
																TSRow,
																"SupplierProductsAndServices.PropertyValues");
		If Not PropertyValues = Undefined Then
			NewRow = ImportTab.Add();
			NewRow.ProductIdentifier = ProductIdentifier;
			NewRow.PropertyValues     = PropertyValues;
		EndIf;
		
	EndDo;
	
	If ImportTab.Count() > 0 Then
		
		AlcoholicProductsAccounting = GetFunctionalOption("EnterInformationForDeclarationsOnAlcoholicProducts");
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	SuppliersProductsAndServices.ProductsAndServices,
		|	SuppliersProductsAndServices.ID
		|FROM
		|	Catalog.SuppliersProductsAndServices AS SuppliersProductsAndServices
		|WHERE
		|	SuppliersProductsAndServices.ID IN(&ArrayOfIDs)
		|	AND Not SuppliersProductsAndServices.ProductsAndServices = VALUE(Catalog.ProductsAndServices.EmptyRef)";
		Query.SetParameter("ArrayOfIDs", ImportTab.UnloadColumn("ProductIdentifier"));
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			String = ImportTab.Find(Selection.ID, "ProductIdentifier");
			If AlcoholicProductsAccounting Then
				ProductsAndServicesAttributesFillingForAlcoholicProductsAccounting(Selection.ProductsAndServices, String.PropertyValues);
			EndIf;
			
			For Each Property IN String.PropertyValues Do
				If Mid(Property.ID, 1, 8) = "Property" Then
					PropertyReference = ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.FindByDescription(
																									Property.Description);
					If Not ValueIsFilled(PropertyReference) Then
						NewCharacteristic = ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.CreateItem();
						NewCharacteristic.PropertySet = Catalogs.AdditionalAttributesAndInformationSets.Catalog_ProductsAndServices;
						NewCharacteristic.Description = Property.Description;
						NewCharacteristic.Title = Property.Description;
						NewCharacteristic.ValueType = Type("CatalogRef.ObjectsPropertiesValues");
						NewCharacteristic.Write();
						PropertyReference = NewCharacteristic.Ref;
					EndIf;
					
					If PropertyReference.ValueType = New TypeDescription("String") Then
						PropertyValue = Property.Value[0];
					ElsIf PropertyReference.ValueType = New TypeDescription("Boolean") Then
						PropertyValue = Boolean(Property.Value[0]);
					ElsIf PropertyReference.ValueType = New TypeDescription("Date") Then
						PropertyValue = Date(Property.Value[0]);
					ElsIf PropertyReference.ValueType = New TypeDescription("CatalogRef.ObjectsPropertiesValues") Then
						PropertyValue = Catalogs.ObjectsPropertiesValues.FindByDescription(Property.Value[0]);
						If Not ValueIsFilled(PropertyValue) Then
							NewPropertyValue = Catalogs.ObjectsPropertiesValues.CreateItem();
							NewPropertyValue.Description = Property.Value[0];
							NewPropertyValue.Owner = PropertyReference;
							NewPropertyValue.Write();
							PropertyValue = NewPropertyValue.Ref;
						EndIf;
					EndIf;
					
					ProductObject = Selection.ProductsAndServices.GetObject();
					PropertiesString = ProductObject.AdditionalAttributes.Find(PropertyReference, "Property");
					If PropertiesString = Undefined Then
						PropertiesString = ProductObject.AdditionalAttributes.Add();
					EndIf;
					PropertiesString.Property = PropertyReference;
					PropertiesString.Value = PropertyValue;
					
					ProductObject.Write();
				ElsIf Property.ID = "Barcode" Then
					MeasurementUnit = Catalogs.UOM.EmptyRef();
					If ValueIsFilled(Property.Description) Then
						MeasurementUnit = Catalogs.UOM.FindByCode(Property.Description);
					EndIf;
					For Each Barcode IN Property.Value Do
						RecordManager = InformationRegisters.ProductsAndServicesBarcodes.CreateRecordManager();
						RecordManager.Barcode = Barcode;
						RecordManager.Read();
						If Not RecordManager.Selected() Then
							RecordManager.ProductsAndServices = Selection.ProductsAndServices;
							RecordManager.MeasurementUnit = MeasurementUnit;
							RecordManager.Barcode = Barcode;
							RecordManager.Write();
						EndIf;
					EndDo;
				EndIf;
			EndDo
		EndDo;
	EndIf;
	
EndProcedure

Procedure ProductsAndServicesAttributesFillingForAlcoholicProductsAccounting(ProductReference, PropertyValues)

	PropertyStructure = New Structure;
	
	PropertyStructure.Insert("AlcoholicProductsKindCode");
	PropertyStructure.Insert("ManufacturerImporterTIN");
	PropertyStructure.Insert("VolumeDAL");
	
	PropertiesForDeletion = New Array;
	
	For Each Property IN PropertyValues Do
		If Not ValueIsFilled(Property.Description) Then
			Continue;
		EndIf;
		If PropertyStructure.Property(Property.Description) Then
			PropertyStructure[Property.Description] = Property.Value[0];
			PropertiesForDeletion.Add(Property);
		EndIf;
	EndDo;
	
	For Each Property IN PropertiesForDeletion Do
		FoundItem = PropertyValues.Find(Property);
		If FoundItem <> Undefined Then
			PropertyValues.Delete(FoundItem);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AlcoholicProductsKinds.Ref AS AlcoholicProductsKind
	|FROM
	|	Catalog.AlcoholicProductsKinds AS AlcoholicProductsKinds
	|WHERE
	|	AlcoholicProductsKinds.Code = &AlcoholicProductsKindCode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Counterparties.Ref AS AlcoholicProductsManufacturerImporter
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	&ManufacturerImporterTIN <> Undefined AND Counterparties.TIN = &ManufacturerImporterTIN";
	
	Query.SetParameter("AlcoholicProductsKindCode", PropertyStructure.AlcoholicProductsKindCode);
	Query.SetParameter("ManufacturerImporterTIN", ?(ValueIsFilled(PropertyStructure.ManufacturerImporterTIN), PropertyStructure.ManufacturerImporterTIN, Undefined));
	
	ResultsArray = Query.ExecuteBatch();
	
	ProductObject = ProductReference.GetObject();
	DataModified = False;
	
	If ValueIsFilled(PropertyStructure.VolumeDAL) Then
		ProductObject.VolumeDAL = PropertyStructure.VolumeDAL;
		DataModified = True;
	EndIf;
	
	Selection = ResultsArray[0].Select();
	If Selection.Next() Then
		ProductObject.AlcoholicProductsKind = Selection.AlcoholicProductsKind;
		DataModified = True;
	EndIf;

	Selection = ResultsArray[1].Select();
	If Selection.Next() Then
		ProductObject.AlcoholicProductsManufacturerImporter = Selection.AlcoholicProductsManufacturerImporter;
		DataModified = True;
	EndIf;
	
	If DataModified Then
		ProductObject.DataExchange.Load = True;
		ProductObject.Write();
	EndIf;

EndProcedure

// It returns the structure for opening the form of ProductsAndServices matching
//
// Parameters:
//  LinkToED - CatalogRef.EDAttachedFiles
//
// Returns:
//  Structure containing FormName and FormOpenParameters
//
Function GetProductsAndServicesComparingFormParameters(LinkToED) Export
	
	ParametersStructure = Undefined;
	
	// Products and services matching is called 
	// 	- for incoming documents of kinds:
	// 		- TORG12
	// 		- TORG12Seller
	// 		- ResponseToOrder
	// 		- ProductsDirectory
	// 		- ActPerformer
	// 	- for the outgoing document 
	//		- TORG12Customer 
	If (LinkToED.EDDirection = Enums.EDDirections.Incoming 
		    AND (LinkToED.EDKind = Enums.EDKinds.TORG12
				OR LinkToED.EDKind = Enums.EDKinds.TORG12Seller
				OR LinkToED.EDKind = Enums.EDKinds.ResponseToOrder
				OR LinkToED.EDKind = Enums.EDKinds.ProductsDirectory
				OR LinkToED.EDKind = Enums.EDKinds.ActPerformer)) 
		 OR (LinkToED.EDDirection = Enums.EDDirections.Outgoing
			AND LinkToED.EDKind = Enums.EDKinds.TORG12Customer) Then
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("FormName", "CommonForm.DataMatchingByProductsAndServices");
		FormOpenParameters = New Structure("ElectronicDocument, DoNotOpenFormIfUnmatchedProductsAndServicesAreAbsent", LinkToED, True);
		ParametersStructure.Insert("FormOpenParameters", FormOpenParameters);
		
	EndIf;
	
	Return ParametersStructure;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Creating catalog items

// It receives the attributes of Companies catalog item.
//
// Parameters:
//  Company - CatalogRef.Companies - Company catalog item;
//  ReturnStructure - structure - company parameter list.
//
Procedure GetCompanyAttributes(Company, ReturnStructure) Export
	
	Query = New Query();
	Query.Text =  
	"SELECT
	|	Companies.Description 		AS Description,
	|	Companies.DescriptionFull 	AS DescriptionFull,
	|	Companies.TIN 				AS TIN
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.Ref = &Company";
	Query.SetParameter("Company", Company);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ReturnStructure.Description 			= Selection.Description;
		ReturnStructure.DescriptionFull 	= Selection.DescriptionFull;
		ReturnStructure.TIN 					= Selection.TIN;
	EndIf;
	
EndProcedure

// Checks whether required automatic conditions for signing the document are fulfilled.
// 
// Parameters:
//  ElectronicDocument - references to attached file.
//
Function ElectronicDocumentReadyForSigning(ElectronicDocument) Export
	
	Return True;
EndFunction

// The procedure allows to select the check box for the forced start of the update handler.
//
// Parameters:
//  HandlerVersion - String - handler version to start on updating;
//  HandlerForcedStartFlag - Boolean - flag of handler start.
//
Procedure DetermineUpdateHandlerStartFlag(HandlerVersion, HandlerForcedStartFlag) Export
	
	If HandlerVersion = "1.0.5" Then
		HandlerForcedStartFlag = True;
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Data receiving for generating electronic documents

Procedure ProcessProductsTable(ProductsTable) Export
	
	For Each String in ProductsTable Do
		
		// Generate identifier
		ProductID = String.ProductsAndServices.UUID();
		CharacteristicID = ?(ValueIsFilled(String.Characteristic), String.Characteristic.UUID(), "");
		
		String.ID = String(ProductID) + "#" + String(CharacteristicID) + "#";
		
		// Generate name
		String.Description = String.Description + ?(ValueIsFilled(String.Characteristic), " (" + String.Characteristic + ")", "");
		
	EndDo;
	
EndProcedure

// It adds the string values to the table from another value table and values of columns with matching names.
//
// Parameters:
//  SourceTable - value table or array of value table rows from which the values are taken.
//  TargetTable - value table where the rows are added.
//  FillRowsNumbersBySource - Boolean - determines whether it
// 	is necessary to save information of the source-table string indexes in the receiver-table.
// 	It is used in the cases when it is necessary to match the strings of the receiver and source.
//
Procedure ImportIntoValueTable(SourceTable, TargetTable, FillRowsNumbersBySource = False) Export
	
	// Fill in the values in the matching columns.
	For Each TableSourceRow IN SourceTable Do
		
		ReceiverTableRow = TargetTable.Add();
		FillPropertyValues(ReceiverTableRow, TableSourceRow);
		
		If FillRowsNumbersBySource Then
			ReceiverTableRow.LineNumber = TableSourceRow.Owner().IndexOf(TableSourceRow);
		EndIf;
		
	EndDo;
	
EndProcedure // ImportToValuesTable()

Function AdaptReceivedItem(AttributeName) Export
	
	If UPPER(AttributeName) = UPPER("NumberByCustomerData") 
		OR UPPER(AttributeName) = UPPER("NumberBySupplierData")  Then
		
		KeyValue = "IncomingDocumentNumber";
		
	ElsIf UPPER(AttributeName) = UPPER("DateByCustomerData")
		OR UPPER(AttributeName) = UPPER("DateBySupplierData") Then
		
		KeyValue = "IncomingDocumentDate";
		
	Else
		
		KeyValue = AttributeName;
		
	EndIf;
	
	Return KeyValue;
	
EndFunction

Function AddToQueryTextFilterByAttributeWithDateType(QueryText, AttributeName) Export
	
	Return QueryText +
		" AND ENDOFPERIOD(SearchDocument." + AttributeName + ", DAY) = ENDOFPERIOD(&" + AttributeName + ", DAY)";
	
EndFunction

Function AddQueryFilterOnArbitraryTextAttribute(QueryText, AttributeName) Export
	
	Return QueryText +
		" And SearchedDocument." + AttributeName + " = &" + AttributeName;
		
EndFunction

Function SearchDocumentForDetails(AttributesStructure, Query) Export
	
	If AttributesStructure <> Undefined
		AND AttributesStructure.Count() > 0 Then
		
		For Each CurrentItem IN AttributesStructure Do
			
			AttributeName = AdaptReceivedItem(CurrentItem.Key);
			
			Query.Text = ?(Find(Upper(AttributeName), Upper("Date")) > 0,
				AddToQueryTextFilterByAttributeWithDateType(Query.Text, AttributeName), // For the date the behavior differs
				AddQueryFilterOnArbitraryTextAttribute(Query.Text, AttributeName));
			
			Query.SetParameter(AttributeName, CurrentItem.Value);
			
		EndDo;
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Return Selection.Ref;
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// To send additional data to a print form, it is required:
//
// 1. in the function of data preparation (within the override module) create a structure, where key - name
//  of transferred additional parameter, and value - Thus the value of additional parameter and
//  send to interface function "ElectronicDocuments.AddDataToAdditDataTree" (description of parameters in the comments to it).
//
// 2. in the function of data preparation for printing "GetData...ForPrinting"
//  write reading of transferred additional data by name (under which the parameter was placed to the structure at step 1) and assignment of the template to required attribute.
//
Function AdditDataTree() Export
	
	DataTree = New ValueTree;
	
	TypeArray = New Array;
	TypeArray.Add(Type("Structure"));
	TypeArray.Add(Type("Array"));
	TypeArray.Add(Type("String"));
	TypeStructureArrayString = New TypeDescription(TypeArray);
	
	DataTree.Columns.Add("AttributeName", New TypeDescription("String"));
	DataTree.Columns.Add("AttributeValue", TypeStructureArrayString);
	DataTree.Columns.Add("LegallyMeaningful", New TypeDescription("Boolean"));
	DataTree.Columns.Add("CWT", New TypeDescription("Boolean"));
	
	Return DataTree;
	
EndFunction

Function GetDataAcceptanceCertificate(ObjectReference) Export
	
	DocumentData = New Structure();
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	AcceptanceCertificate.Ref AS Ref,
	|	AcceptanceCertificate.Number AS DocumentNumber,
	|	AcceptanceCertificate.Date AS DocumentDate,
	|	AcceptanceCertificate.Company AS Company,
	|	AcceptanceCertificate.Counterparty AS Counterparty,
	|	AcceptanceCertificate.AmountIncludesVAT AS AmountIncludesVAT,
	|	AcceptanceCertificate.DocumentCurrency AS DocumentCurrency,
	|	AcceptanceCertificate.DocumentCurrency.Code AS CurrencyCode,
	|	AcceptanceCertificate.Company.Prefix AS Prefix
	|FROM
	|	Document.AcceptanceCertificate AS AcceptanceCertificate
	|WHERE
	|	AcceptanceCertificate.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AcceptanceCertificateWorksAndServices.LineNumber AS LineNumber,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices,
	|	CASE
	|		WHEN (CAST(AcceptanceCertificateWorksAndServices.ProductsAndServices.DescriptionFull AS String(1000))) = """"
	|			THEN AcceptanceCertificateWorksAndServices.ProductsAndServices.Description
	|		ELSE CAST(AcceptanceCertificateWorksAndServices.ProductsAndServices.DescriptionFull AS String(1000))
	|	END AS ProductsAndServicesDescription,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.SKU AS SKU,
	|	AcceptanceCertificateWorksAndServices.MeasurementUnit AS MeasurementUnitDocument,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.MeasurementUnit.Code AS MeasurementUnitCode,
	|	AcceptanceCertificateWorksAndServices.ProductsAndServices.MeasurementUnit.Description AS MeasurementUnitDescription,
	|	AcceptanceCertificateWorksAndServices.Quantity AS Quantity,
	|	AcceptanceCertificateWorksAndServices.Price AS Price,
	|	AcceptanceCertificateWorksAndServices.Amount AS Amount,
	|	AcceptanceCertificateWorksAndServices.VATRate,
	|	AcceptanceCertificateWorksAndServices.VATAmount AS VATAmount,
	|	AcceptanceCertificateWorksAndServices.Total AS Total,
	|	AcceptanceCertificateWorksAndServices.Characteristic,
	|	AcceptanceCertificateWorksAndServices.Content,
	|	AcceptanceCertificateWorksAndServices.DiscountMarkupPercent
	|FROM
	|	Document.AcceptanceCertificate.WorksAndServices AS AcceptanceCertificateWorksAndServices
	|WHERE
	|	AcceptanceCertificateWorksAndServices.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", ObjectReference);
	Result = Query.ExecuteBatch();
	
	Header = Result[0].Select();
	Header.Next();
	
	DocumentData.Insert("HeaderAttributes", Header);
	
	WorkTable = Result[1].Unload();
	DocumentData.Insert("WorkTable", WorkTable);
	
	Return DocumentData;
	
EndFunction

Function GetDataSellingProductsAndServices(ObjectReference) Export
	
	DocumentData = New Structure();
	
	// Prepare the document header data
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsServicesSale.Number,
	|	GoodsServicesSale.Number AS NumberByCustomerData,
	|	GoodsServicesSale.Date AS DocumentDate,
	|	GoodsServicesSale.Date AS DateByCustomerData,
	|	GoodsServicesSale.Company,
	|	GoodsServicesSale.Company AS LegalEntityIndividual,
	|	GoodsServicesSale.Company AS Vendor,
	|	GoodsServicesSale.Company AS Counterparty,
	|	GoodsServicesSale.Company AS Heads,
	|	CASE
	|		WHEN GoodsServicesSale.Consignee = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN GoodsServicesSale.Counterparty
	|		ELSE GoodsServicesSale.Consignee
	|	END AS Consignee,
	|	CASE
	|		WHEN GoodsServicesSale.Consignor = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN GoodsServicesSale.Company
	|		ELSE GoodsServicesSale.Consignor
	|	END AS Consignor,
	|	GoodsServicesSale.BankAccount AS BankAccount,
	|	GoodsServicesSale.Counterparty AS Customer,
	|	GoodsServicesSale.Counterparty AS Payer,
	|	NULL AS Deal,
	|	GoodsServicesSale.Contract.Description AS DocBasisDescription,
	|	CASE
	|		WHEN GoodsServicesSale.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Order.Number
	|		ELSE UNDEFINED
	|	END AS DocBasisNumber,
	|	CASE
	|		WHEN GoodsServicesSale.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Order.Date
	|		ELSE UNDEFINED
	|	END AS DocBasisDate,
	|	NULL AS MutualSettlementsConduction,
	|	GoodsServicesSale.Department AS Department,
	|	GoodsServicesSale.DocumentCurrency,
	|	GoodsServicesSale.ExchangeRate AS ExchangeRate,
	|	GoodsServicesSale.Multiplicity AS Multiplicity,
	|	CASE
	|		WHEN GoodsServicesSale.VATTaxation = VALUE(Enum.VATTaxationTypes.NotTaxableByVAT)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ConsiderVAT,
	|	GoodsServicesSale.AmountIncludesVAT,
	|	GoodsServicesSale.Responsible AS ReleasePermitted,
	|	GoodsServicesSale.StructuralUnit.FRP AS ReleaseMade
	|FROM
	|	Document.CustomerInvoice AS GoodsServicesSale
	|WHERE
	|	GoodsServicesSale.Ref = &CurrentDocument";
	
	Query.SetParameter("CurrentDocument", 	ObjectReference);
	Query.SetParameter("CutoffDate", 			ObjectReference.Date);
	Query.SetParameter("Company", 		ObjectReference.Company);
	Query.SetParameter("Department", 		ObjectReference.Department);
	Query.SetParameter("StructuralUnit", ObjectReference.StructuralUnit);
	
	Header = Query.Execute().Select();
	Header.Next();
	
	DocumentData.Insert("HeaderAttributes", Header);
	
	// Prepare data of the tabular sections
	CurrencyOfRegulatedAccounting = Constants.NationalCurrency.Get();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	GoodsServicesSale.LineNumber AS LineNumber,
	|	GoodsServicesSale.ProductsAndServices.Code AS ProductCode,
	|	GoodsServicesSale.ProductsAndServices.SKU AS SKU,
	|	GoodsServicesSale.ProductsAndServices.DescriptionFull AS ProductsAndServicesDescription,
	|	GoodsServicesSale.ProductsAndServices AS ProductsAndServices,
	|	GoodsServicesSale.Quantity AS Quantity,
	|	GoodsServicesSale.Amount * &ExchangeRate / &Multiplicity AS Amount,
	|	GoodsServicesSale.Total * &ExchangeRate / &Multiplicity - GoodsServicesSale.VATAmount * &ExchangeRate / &Multiplicity AS AmountWithoutVAT,
	|	GoodsServicesSale.Total * &ExchangeRate / &Multiplicity AS SumWithVAT,
	|	GoodsServicesSale.Price * &ExchangeRate / &Multiplicity AS Price,
	|	PRESENTATION(GoodsServicesSale.Characteristic) AS CharacteristicDescription,
	|	GoodsServicesSale.Characteristic AS Characteristic,
	|	GoodsServicesSale.ProductsAndServices.MeasurementUnit AS BaseUnit,
	|	GoodsServicesSale.ProductsAndServices.MeasurementUnit.Code AS BaseUnitCode,
	|	GoodsServicesSale.ProductsAndServices.MeasurementUnit.Description AS BaseUnitDescription,
	|	GoodsServicesSale.ProductsAndServices.MeasurementUnit.DescriptionFull AS BaseUnitDescriptionFull,
	|	GoodsServicesSale.ProductsAndServices.MeasurementUnit.InternationalAbbreviation AS BaseUnitInternationalAbbreviation,
	|	GoodsServicesSale.MeasurementUnit AS MeasurementUnit,
	|	GoodsServicesSale.MeasurementUnit AS Package,
	|	GoodsServicesSale.MeasurementUnit.Code AS PackageCode,
	|	GoodsServicesSale.MeasurementUnit.Description AS PackageDescription,
	|	GoodsServicesSale.VATRate AS VATRate,
	|	GoodsServicesSale.VATAmount * &ExchangeRate / &Multiplicity AS VATAmount,
	|	"""" AS PackagingKind,
	|	0 AS DiscountAmount,
	|	1 AS Factor,
	|	0 AS PlacesQuantity,
	|	0 AS QuantityInOnePlace,
	|	CASE
	|		WHEN GoodsServicesSale.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Order.Number
	|		WHEN GoodsServicesSale.Ref.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Ref.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Ref.Order.Number
	|		ELSE NULL
	|	END AS CustomerOrderNumber,
	|	CASE
	|		WHEN GoodsServicesSale.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Order.Date
	|		WHEN GoodsServicesSale.Ref.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Ref.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Ref.Order.Date
	|		ELSE NULL
	|	END AS CustomerOrderDate,
	|	CASE
	|		WHEN GoodsServicesSale.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Order.IncomingDocumentNumber
	|		WHEN GoodsServicesSale.Ref.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Ref.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Ref.Order.IncomingDocumentNumber
	|		ELSE NULL
	|	END AS AccordingToBuyersOrderNumber,
	|	CASE
	|		WHEN GoodsServicesSale.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Order.IncomingDocumentDate
	|		WHEN GoodsServicesSale.Ref.Order REFS Document.CustomerOrder
	|				AND GoodsServicesSale.Ref.Order <> VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN GoodsServicesSale.Ref.Order.IncomingDocumentDate
	|		ELSE NULL
	|	END AS OrderDateByBuyerData
	
	|FROM
	|	Document.CustomerInvoice.Inventory AS GoodsServicesSale
	|WHERE
	|	GoodsServicesSale.Ref = &Ref";
	
	ExchangeRateCurrencies = WorkWithCurrencyRates.GetCurrencyRate(CurrencyOfRegulatedAccounting, ObjectReference.Date);
	
	Query.SetParameter("ExchangeRate",		ExchangeRateCurrencies.ExchangeRate);
	Query.SetParameter("Multiplicity",	ExchangeRateCurrencies.Multiplicity);
	Query.SetParameter("Ref",		ObjectReference);
	
	ProductsTable = Query.Execute().Unload();
	
	// Calculate the document currency rate for printing
	
	DocumentData.Insert("ProductsTable", ProductsTable);
	
	Return DocumentData;
	
EndFunction

Procedure FillSNPAndPosition(StructureReceiver, DataSource, Position = Undefined) Export
	
	If TypeOf(DataSource) = Type("Structure") Then
		FillPropertyValues(StructureReceiver, DataSource);
	ElsIf TypeOf(DataSource) = Type("String") Then
		Surname = ""; 
		Name = ""; 
		Patronymic = "";
		ElectronicDocuments.SurnameInitialsOfIndividual(DataSource, Surname, Name, Patronymic);
		StructureReceiver.Insert("Surname", Surname);
		StructureReceiver.Insert("Name", Name);
		StructureReceiver.Insert("Patronymic", Patronymic);
	EndIf;
	
	If ValueIsFilled(Position) Then
		StructureReceiver.Insert("Position", Position);
	EndIf;
	
EndProcedure

// The procedure adds a new string to the parameter structure data tables
//
Procedure AddDataTableString(DataTable, RowData, ParametersStructure, OwnerItemNameAddData) Export
	
	NewRow = DataTable.Add();
	FillPropertyValues(NewRow, RowData);
	
	NewRow.NetWeight = RowData.Quantity;
	
	// Generate additional parameters
	AdditDataStructure = GetProductsAndServicesAdditDataStructure(
		RowData.ProductsAndServices, 
		RowData.Characteristic, 
		RowData.ProductsAndServicesDescription);
	
	If ValueIsFilled(RowData.CustomerOrderNumber) Then
		
		AdditDataStructure.Insert("NumberBySupplierData", RowData.CustomerOrderNumber);
		AdditDataStructure.Insert("DateBySupplierData", RowData.CustomerOrderDate);
		
	EndIf;
	
	If ValueIsFilled(RowData.AccordingToBuyersOrderNumber) Then
		
		AdditDataStructure.Insert("AccordingToBuyersOrderNumber", RowData.AccordingToBuyersOrderNumber);
		AdditDataStructure.Insert("OrderDateByBuyerData", RowData.OrderDateByBuyerData);
		
	EndIf;
	
	// Due to the nature of the FTS scheme, some VAT rates shall be passed in add. parameters.
	If DataTable.Columns.Find("VATRate") <> Undefined Then
		// IN TORG12 the fractional VAT rates are not passed
		
		AccordanceOfRatesVAT = New Map;
		AccordanceOfRatesVAT.Insert(ElectronicDocumentsOverridable.EnumerationValueVATRate("18% / 118%#"), 
			ElectronicDocumentsOverridable.EnumerationValueVATRate("18%#"));
		AccordanceOfRatesVAT.Insert(ElectronicDocumentsOverridable.EnumerationValueVATRate("10% / 110%#"), 
			ElectronicDocumentsOverridable.EnumerationValueVATRate("10%#"));
		
		If AccordanceOfRatesVAT[NewRow.VATRate] <> Undefined Then
			
			// We transfer the fractional VAT rate in the structure of add. parameters
			AdditDataStructure.Insert("VATRate", NewRow.VATRate);
			
			// We will transfer the corresponding VAT rate as the number to the scheme
			NewRow.VATRate = AccordanceOfRatesVAT[NewRow.VATRate];
			
		EndIf;
		
	Else
		
		// VAT rate transfer is not provided for the Certificate
		AdditDataStructure.Insert("VATRate", RowData.VATRate);
		
	EndIf;
	
	ElectronicDocuments.AddDataToAdditDataTree(ParametersStructure, AdditDataStructure, OwnerItemNameAddData, True, NewRow.LineNumber);
	
EndProcedure

Function StructureTotalAmounts(ProductsTable) Export
	
	Structure = New Structure;
	
	Structure.Insert("PlacesQuantity", ProductsTable.Total("PlacesQuantity"));
	Structure.Insert("GrossWeight",    ProductsTable.Total("GrossWeight"));
	Structure.Insert("NetWeight",     ProductsTable.Total("NetWeight"));
	Structure.Insert("AmountWithoutVAT",    ProductsTable.Total("AmountWithoutVAT"));
	Structure.Insert("VATAmount",       ProductsTable.Total("VATAmount"));
	Structure.Insert("SumWithVAT",      ProductsTable.Total("AmountWithoutVAT") + ProductsTable.Total("VATAmount"));
	Structure.Insert("SequentialRecordsNumbersQuantity", ProductsTable.Count());
	
	Return Structure;
	
EndFunction

Procedure FillParticipantsAttributesTORG12(PrintInfo, ParametersStructure) Export
	
	InfoAboutVendor			= ElectronicDocumentsOverridable.GetDataLegalIndividual(PrintInfo.Company);
	InfoAboutCustomer			= ElectronicDocumentsOverridable.GetDataLegalIndividual(PrintInfo.Customer);
	InfoAboutConsignee	= ElectronicDocumentsOverridable.GetDataLegalIndividual(PrintInfo.Consignee);
	InfoAboutShipper	= ElectronicDocumentsOverridable.GetDataLegalIndividual(PrintInfo.Consignor);
	
	//FillExchangeParticipantInfo(ParametersStructure.Supplier, InfoAboutSupplier);
	
	If PrintInfo.Company <> PrintInfo.Consignor Then
		
		FillExchangeParticipantInfo(ParametersStructure.InfoAboutShipper.Consignor, InfoAboutShipper, "Fact");
		ParametersStructure.InfoAboutShipper.OrganizationDepartment = PrintInfo.Department;
		
	EndIf;
	
	//FillExchangeParticipantInfo(ParametersStructure.Payer,      InfoAboutCustomer);
	//FillExchangeParticipantInfo(ParametersStructure.Consignee, InfoAboutConsignee, "Actual");
	
EndProcedure

Procedure FillExchangeParticipantInfo(ParticipantStructure, Participant, InfoAboutParticipant, AddressKind = "Legal") Export
	
	ParticipantStructure.Insert("CompanyDescription",	InfoAboutParticipant.FullDescr);
	ParticipantStructure.Insert("TIN",						InfoAboutParticipant.TIN);
	ParticipantStructure.Insert("CodeRCLF",					"");
	ParticipantStructure.Insert("ThisIsInd",				InfoAboutParticipant.LegalEntityIndividual <> Enums.CounterpartyKinds.LegalEntity);
	
	If InfoAboutParticipant.LegalEntityIndividual <> Enums.CounterpartyKinds.LegalEntity Then
		
		FillSNPAndPosition(ParticipantStructure, InfoAboutParticipant.FullDescr);
		
	EndIf;
	
	// Address types are presented by the value list in which item presentation - type
	// description (Structured, Random, Foreign), item value - structure describing the address fields, mark - specifies
	// from which list item you shall take data when filling in ED.
	StructureOfAddress = New Structure;
	ErrorText = "";
	
	ElectronicDocumentsOverridable.GetAddressAsStructure(StructureOfAddress, InfoAboutParticipant, "Ref", AddressKind, ErrorText);
	FillAddressInListTypesAddressov(ParticipantStructure.Address, StructureOfAddress, "Structured");
	
	ParticipantStructure.Insert("Phone", InfoAboutParticipant.PhoneNumbers);
	ParticipantStructure.Insert("Fax");
	
	StructureBankAccount = ParticipantStructure.BankAccount;
	StructureBankAccount.Insert("BIN", InfoAboutParticipant.BIN);
	StructureBankAccount.Insert("DescBank", ?(ValueIsFilled(InfoAboutParticipant.Bank), InfoAboutParticipant.Bank.Description, ""));
	StructureBankAccount.Insert("AccountNo ", InfoAboutParticipant.AccountNo);
	
EndProcedure

// Fills in the corresponding address type by the passed data.
// Parameters:
//  AddressesTypesList - ValueList - Item presentation - type
//    description (Structured, Random, Foreign), item value - structure describing the address fields, mark - specifies
//    from which list item you shall take data when filling in ED.
//  ParticipantAddress - Structure - contains data of the exchange participant address. Structure field names shall
//    match the structure field names of the selected address type:
//    Structured - "ZipCode, StateCode, Region, City, Settlement, Street, House, Block, Apartment";
//    Arbitrary/Foreign - CountryCode, AddressInString (distributed into different
//      list items to fill in ED properly).
//  AddressType - String - one of 3 variants: Structured, Random, Foreign.
//
Procedure FillAddressInListTypesAddressov(AddressesTypesList, ParticipantAddress, AddressType = "Structured") Export
	
	// Address types are presented by the value list in which item presentation - type
	// description (Structured, Random, Foreign), item value - structure describing the address fields, mark - specifies
	// from which list item you shall take data when filling in ED.
	AddressesTypesList.FillMarks(False);
	SelectedAddressType = Undefined;
	For Each Item IN AddressesTypesList Do
		If Item.Presentation = AddressType Then
			SelectedAddressType = Item;
			Break;
		EndIf;
	EndDo;
	If SelectedAddressType <> Undefined Then
		FillPropertyValues(SelectedAddressType.Value, ParticipantAddress);
		SelectedAddressType.Check = True;
	EndIf;
	
EndProcedure

// The function generates a structure with ProductsAndServices data to transfer it to add. data
//
Function GetProductsAndServicesAdditDataStructure(ProductsAndServices, Characteristic, ProductsAndServicesDescription = "") Export
	
	AdditionalInformationStructure = New Structure;
	
	If Not ValueIsFilled(ProductsAndServices) 
		OR IsBlankString(ProductsAndServicesDescription) Then
		
		Return AdditionalInformationStructure;
		
	EndIf;
	
	ProductID 			= ProductsAndServices.UUID();
	CharacteristicID	= "";
	InventoryDescription	= ProductsAndServicesDescription;
	
	If ValueIsFilled(Characteristic) Then
		
		CharacteristicID	= Characteristic.UUID();
		InventoryDescription	= InventoryDescription + " (" + Characteristic + ")";
		
	EndIf;
	
	AdditionalInformationStructure.Insert("ID", 			 String(ProductID) + "#" + String(CharacteristicID) + "#");
	AdditionalInformationStructure.Insert("Description", 	 InventoryDescription);
	AdditionalInformationStructure.Insert("Characteristic", Characteristic);
	
	Return AdditionalInformationStructure;
	
EndFunction // GetProductsAndServicesAdditDataStructure()

// When copying documents, the EDF key fields shall be cleared
//
Procedure ClearIncomingDocumentDateNumber(DocumentObject) Export
	
	NameArrayAttributes	= GetAttributeNamesArrayToClear();
	DocumentMetadata 	= DocumentObject.Metadata();
	
	For Each ArrayElement IN NameArrayAttributes Do
		
		If Not DocumentMetadata.Attributes.Find(ArrayElement) = Undefined Then
			
			DocumentObject[ArrayElement] = Undefined;
			
		EndIf;
		
	EndDo;
	
EndProcedure // ClearDateIncomingDocumentNumber()

Function GetAttributeNamesArrayToClear() Export
	
	NameArray = New Array;
	
	NameArray.Add("IncomingDocumentNumber");
	NameArray.Add("IncomingDocumentDate");
	
	NameArray.Add("InitialDocumentNumber");
	NameArray.Add("InitialDocumentDate");
	
	Return NameArray;
	
EndFunction

// The function receives data to create the TORG electronic document structure - 12
//
Function GetDataForTrade12(CurrentDocument, WithoutServices = False) Export

	Query = New Query;
	Query.SetParameter("CurrentDocument", CurrentDocument);
	Query.Text =
	"SELECT
	|	CustomerInvoice.Date AS DocumentDate,
	|	CustomerInvoice.Number AS Number,
	|	CustomerInvoice.Company AS Heads,
	|	CustomerInvoice.Company.Prefix AS Prefix,
	|	CustomerInvoice.Company AS Company,
	|	CustomerInvoice.BankAccount AS BankAccount,
	|	CustomerInvoice.Counterparty AS Counterparty,
	|	CustomerInvoice.Company AS Vendor,
	|	CASE
	|		WHEN CustomerInvoice.Consignee = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN CustomerInvoice.Counterparty
	|		ELSE CustomerInvoice.Consignee
	|	END AS Consignee,
	|	CASE
	|		WHEN CustomerInvoice.Consignor = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN CustomerInvoice.Company
	|		ELSE CustomerInvoice.Consignor
	|	END AS Consignor,
	|	CustomerInvoice.Counterparty AS Payer,
	|	CustomerInvoice.Contract.Presentation AS Basis,
	|	CustomerInvoice.Contract.ContractDate AS BasisDate,
	|	CustomerInvoice.Contract.ContractNo AS BasisNumber,
	|	CustomerInvoice.DocumentCurrency,
	|	CustomerInvoice.AmountIncludesVAT,
	|	CustomerInvoice.IncludeVATInPrice,
	|	CustomerInvoice.ExchangeRate,
	|	CustomerInvoice.Multiplicity,
	|	CustomerInvoice.DocumentCurrency.Code AS CurrencyCode
	|FROM
	|	Document.CustomerInvoice AS CustomerInvoice
	|WHERE
	|	CustomerInvoice.Ref = &CurrentDocument";
	
	Header = Query.Execute().Select();
	Header.Next();
	
	UseConversion = (NOT Header.DocumentCurrency = Constants.NationalCurrency.Get());
	
	Query = New Query;
	Query.SetParameter("CurrentDocument", CurrentDocument);
	
	Query.Text =
	"SELECT
	|	NestedSelect.ProductsAndServices AS ProductsAndServices,
	|	NestedSelect.Content AS Content,
	|	CASE
	|		WHEN (CAST(NestedSelect.ProductsAndServices.DescriptionFull AS String(1000))) = """"
	|			THEN NestedSelect.ProductsAndServices.Description
	|		ELSE CAST(NestedSelect.ProductsAndServices.DescriptionFull AS String(1000))
	|	END AS ProductsAndServicesDescription,
	|	NestedSelect.Characteristic,
	|	NestedSelect.Characteristic.Description AS CharacteristicDescription,
	|	NestedSelect.ProductsAndServices.Code AS ProductCode,
	|	NestedSelect.ProductsAndServices.SKU AS SKU,
	|	NestedSelect.MeasurementUnitForPrint.Description AS BaseUnitDescription,
	|	NestedSelect.MeasurementUnitForPrint.Code AS BaseUnitCode,
	|	NestedSelect.MeasurementUnitForPrint.Description AS MeasurementUnit,
	|	NestedSelect.MeasurementUnitDocument AS MeasurementUnitDocument,
	|	UNDEFINED AS PackagingKind,
	|	0 AS QuantityInOnePlace,
	|	NestedSelect.VATRate AS VATRate,
	|	NestedSelect.VATRate.Rate AS TaxRateVATAsNumber,
	|	&Price_Parameter AS Price,
	|	NestedSelect.Quantity AS Quantity,
	|	0 AS PlacesQuantity,
	|	&Amount_Parameter AS Amount,
	|	&VATAmount_Parameter AS VATAmount,
	|	&Total_Parameter AS SumWithVAT,
	|	NestedSelect.LineNumber AS LineNumber,
	|	1 AS ID,
	|	0 AS NetWeight,
	|	0 AS GrossWeight,
	|	UNDEFINED AS Package,
	|	NestedSelect.Definition AS Definition
	|FROM
	|	(SELECT
	|		CustomerInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|		CustomerInvoiceInventory.ProductsAndServices.MeasurementUnit AS MeasurementUnitForPrint,
	|		CustomerInvoiceInventory.MeasurementUnit AS MeasurementUnitDocument,
	|		CustomerInvoiceInventory.VATRate AS VATRate,
	|		CustomerInvoiceInventory.Price AS Price,
	|		SUM(CustomerInvoiceInventory.Quantity) AS Quantity,
	|		SUM(CustomerInvoiceInventory.Amount) AS Amount,
	|		SUM(CustomerInvoiceInventory.VATAmount) AS VATAmount,
	|		SUM(CustomerInvoiceInventory.Total) AS Total,
	|		MIN(CustomerInvoiceInventory.LineNumber) AS LineNumber,
	|		CustomerInvoiceInventory.Characteristic AS Characteristic,
	|		CAST(CustomerInvoiceInventory.Content AS String(1000)) AS Content,
	|		CAST(CustomerInvoiceInventory.ProductsAndServices.Comment AS String(1000)) AS Definition
	|	FROM
	|		Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
	|	WHERE
	|		CustomerInvoiceInventory.Ref = &CurrentDocument
	|	
	|	GROUP BY
	|		CustomerInvoiceInventory.ProductsAndServices,
	|		CustomerInvoiceInventory.ProductsAndServices.MeasurementUnit,
	|		CustomerInvoiceInventory.MeasurementUnit,
	|		CustomerInvoiceInventory.VATRate,
	|		CustomerInvoiceInventory.Price,
	|		CustomerInvoiceInventory.Characteristic,
	|		CAST(CustomerInvoiceInventory.Content AS String(1000)),
	|		CAST(CustomerInvoiceInventory.ProductsAndServices.Comment AS String(1000))) AS NestedSelect
	|WHERE
	|	&ServiceFilterCondition
	|
	|ORDER BY
	|	ID,
	|	LineNumber";
	
	If UseConversion Then
		
		Query.Text = StrReplace(Query.Text, "&Price_Parameter", 		"CAST(NestedSelect.Price * &ExchangeRate / &Multiplicity AS Number(15,2))");
		Query.Text = StrReplace(Query.Text, "&Amount_Parameter", 	"CAST(NestedSelect.Amount * &ExchangeRate / &Multiplicity AS Number(15,2))");
		Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter", 	"CAST(NestedSelect.VATAmount * &ExchangeRate / &Multiplicity AS Number(15,2))");
		Query.Text = StrReplace(Query.Text, "&Total_Parameter", 	"CAST(NestedSelect.Total * &ExchangeRate / &Multiplicity AS Number(15,2))");
		
		Query.SetParameter("ExchangeRate",		Header.ExchangeRate);
		Query.SetParameter("Multiplicity",	Header.Multiplicity);
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&Price_Parameter", 		"NestedSelect.Price");
		Query.Text = StrReplace(Query.Text, "&Amount_Parameter", 	"NestedSelect.Amount");
		Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter", 	"NestedSelect.VATAmount");
		Query.Text = StrReplace(Query.Text, "&Total_Parameter", 	"NestedSelect.Total");
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ServiceFilterCondition", 
	?(WithoutServices, "NOT NestedSelect.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)", "TRUE"));
	
	TableByProducts = Query.Execute().Unload();
	
	DataTORG12 = New Structure();
	DataTORG12.Insert("HeaderData", Header);
	DataTORG12.Insert("DocumentTable", TableByProducts);
	
	Return DataTORG12;

EndFunction

Procedure FillIndividualAttributes(DataTree, DataSource, TypePerson, Position = Undefined) Export
	
	Surname = ""; Name = ""; Patronymic = "";
	ElectronicDocuments.SurnameInitialsOfIndividual(DataSource, Surname, Name, Patronymic);
	CommonUseED.FillTreeAttributeValue(DataTree, TypePerson + ".Surname", Surname);
	CommonUseED.FillTreeAttributeValue(DataTree, TypePerson + ".Name", Name);
	CommonUseED.FillTreeAttributeValue(DataTree, TypePerson + ".Patronymic", Patronymic);
	If Position <> Undefined Then
		CommonUseED.FillTreeAttributeValue(DataTree, TypePerson + ".Position", Position);
	EndIf;
	
EndProcedure

Procedure ParticipantDataFill(DataTree, InfoAboutParticipant, ParticipantKind, AddressKind = "Structured", TreeRootItem = "") Export
	
	If InfoAboutParticipant.LegalEntityIndividual = Enums.CounterpartyKinds.LegalEntity Then
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".ParticipantType.LegalEntity.TIN",
									InfoAboutParticipant.TIN);
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".ParticipantType.LegalEntity.CompanyDescription",
									InfoAboutParticipant.FullDescr);
	Else
		FullPath = ParticipantKind + ".ParticipantType.Individual.FullDescr";
		If CommonUseED.AttributeExistsInTree(DataTree, FullPath) Then
			CommonUseED.FillTreeAttributeValue(DataTree, FullPath, InfoAboutParticipant.FullDescr, TreeRootItem);
		EndIf;
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".ParticipantType.Individual.TIN",
									InfoAboutParticipant.TIN, TreeRootItem);
		Surname = ""; Name = ""; Patronymic = "";
		ElectronicDocuments.SurnameInitialsOfIndividual(InfoAboutParticipant.FullDescr, Surname, Name, Patronymic);
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".ParticipantType.Individual.Surname",
									Surname, TreeRootItem);
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".ParticipantType.Individual.Name",
									Name, TreeRootItem);
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".ParticipantType.Individual.Patronymic",
									Patronymic, TreeRootItem);
	EndIf;
	
	ParticipantAddress = New Structure;
	AddressKind = ?(ParticipantKind = "Seller" OR ParticipantKind = "Vendor" OR ParticipantKind = "Payer", "Legal", "Fact");
	ElectronicDocumentsOverridable.GetAddressAsStructure(ParticipantAddress, InfoAboutParticipant.Ref, "Ref", AddressKind, "");
	
	If ValueIsFilled(ParticipantAddress) Then
		FullPath = ParticipantKind + ".Address.Structured";
		If CommonUseED.AttributeExistsInTree(DataTree, FullPath) Then
			AddressType = ?(ParticipantAddress.AddressRF, "Structured", "Foreign");
		Else
			AddressType = "Arbitrary";
		EndIf;
		FillAddressInTree(DataTree, ParticipantAddress, AddressType, ParticipantKind);
	EndIf;
	
	FullPath = ParticipantKind + ".Contact.Phone";
	If CommonUseED.AttributeExistsInTree(DataTree, FullPath) Then
		CommonUseED.FillTreeAttributeValue(
								DataTree,
								ParticipantKind + ".Contact.Phone",
								InfoAboutParticipant.PhoneNumbers, TreeRootItem);
	EndIf;
	
	FullPath = ParticipantKind + ".BankAccount";
	AccountNo = "";
	If InfoAboutParticipant.Property("AccountNo", AccountNo) AND ValueIsFilled(AccountNo)
		AND CommonUseED.AttributeExistsInTree(DataTree, FullPath) Then
		Bank = "";
		BIN = "";
		CommonUseED.FillTreeAttributeValue(
				DataTree,
				ParticipantKind + ".BankAccount.AccountNo",
				AccountNo, TreeRootItem);
		If InfoAboutParticipant.Property("Bank", Bank) AND ValueIsFilled(Bank) Then
			CommonUseED.FillTreeAttributeValue(
										DataTree,
										ParticipantKind + ".BankAccount.DescBank",
										Bank.Description, TreeRootItem);
		EndIf;
		If InfoAboutParticipant.Property("BIN", BIN) AND ValueIsFilled(BIN) Then
			CommonUseED.FillTreeAttributeValue(
										DataTree,
										ParticipantKind + ".BankAccount.BIN",
										BIN, TreeRootItem);
		EndIf;
	EndIf;
	
	FullPath = ParticipantKind + ".Head";
	Value = "";
	If CommonUseED.AttributeExistsInTree(DataTree, FullPath)
		AND InfoAboutParticipant.Property("Head", Value) Then
		CommonUseED.FillTreeAttributeValue(DataTree, FullPath + ".Surname", Value.Surname, TreeRootItem);
		CommonUseED.FillTreeAttributeValue(DataTree, FullPath + ".Name", Value.Name, TreeRootItem);
		CommonUseED.FillTreeAttributeValue(DataTree, FullPath + ".Patronymic", Value.Patronymic, TreeRootItem);
		CommonUseED.FillTreeAttributeValue(DataTree, FullPath + ".Position", Value.Position, TreeRootItem);
	EndIf;
	
	FullPath = ParticipantKind + ".Comment";
	Value = "";
	If CommonUseED.AttributeExistsInTree(DataTree, FullPath)
		AND InfoAboutParticipant.Property("Comment", Value) Then
		CommonUseED.FillTreeAttributeValue(DataTree, FullPath, Value, TreeRootItem);
	EndIf;
	
EndProcedure

Procedure FillCargoSenderRecipientData(DataTree, InfoAboutParticipant, ParticipantKind, AddressKind = "Structured") Export
	
	If InfoAboutParticipant.LegalEntityIndividual = Enums.CounterpartyKinds.LegalEntity Then
		CommonUseED.FillTreeAttributeValue(
			DataTree,
			ParticipantKind + ".Description.CompanyDescription",
			InfoAboutParticipant.FullDescr);
	Else
		Surname = ""; Name = ""; Patronymic = "";
		ElectronicDocuments.SurnameInitialsOfIndividual(InfoAboutParticipant.FullDescr, Surname, Name, Patronymic);
			CommonUseED.FillTreeAttributeValue(
			DataTree,
			ParticipantKind + ".Description.NameAndSurnameIP.Surname",
			Surname);
		CommonUseED.FillTreeAttributeValue(
			DataTree,
			ParticipantKind + ".Description.NameAndSurnameIP.Name",
			Name);
		CommonUseED.FillTreeAttributeValue(
			DataTree,
			ParticipantKind + ".Description.NameAndSurnameIP.Patronymic",
			Patronymic);
	EndIf;
	
	ParticipantAddress = New Structure;
	AddressKind = "Fact";
	ElectronicDocumentsOverridable.GetAddressAsStructure(ParticipantAddress, InfoAboutParticipant.Ref, "Ref", AddressKind, "");
	
	If ValueIsFilled(ParticipantAddress) Then
		AddressType = ?(ParticipantAddress.AddressRF, "Structured", "Foreign");
		FillAddressInTree(DataTree, ParticipantAddress, AddressType, ParticipantKind);
	EndIf;
	
EndProcedure

// Fills in the corresponding address type by the passed data.
// Parameters:
//  TreeRow - ValueTreeRow - Tree string containing data
//  of the participant ParticipantAddress - Structure - contains data of the exchange participant address. Structure field names shall
//    match the structure field names of the selected address type:
//    Structured - "ZipCode, StateCode, Region, City, Settlement, Street, House, Block, Apartment";
//    Arbitrary/Foreign - CountryCode, AddressInString (distributed into different
//      list items to fill in ED properly).
//  AddressType - String - one of 3 variants: Structured, Random, Foreign.
//  ParticipantKind - String - participant kind as presented in the data tree.
//  TreeRootItem - String - It is required to use if in the
//    table complex data type (group, choice) shall be filled. For example: "Goods.LineNumber.Customer", Customer -
//    is a complex type of data, Then TreeRootItem = "Goods.LineNumber".
//
Procedure FillAddressInTree(DataTree, ParticipantAddress, AddressType, ParticipantKind, TreeRootItem = "")
	
	If AddressType = "Arbitrary" Then
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".Address.Arbitrary",
									ParticipantAddress.AdrText, TreeRootItem);
	Else
		If ParticipantAddress.AddressRF Then
			ParticipantAddress.Delete("AddressRF");
			ParticipantAddress.Delete("StrCode");
			ParticipantAddress.Delete("AdrText");
		Else
			ParticipantAddress.Delete("AddressRF");
			ParticipantAddress.Delete("PostalIndex");
			ParticipantAddress.Delete("IndexOf");
			ParticipantAddress.Delete("Region");
			ParticipantAddress.Delete("CodeState");
			ParticipantAddress.Delete("District");
			ParticipantAddress.Delete("City");
			ParticipantAddress.Delete("Settlement");
			ParticipantAddress.Delete("Settlement");
			ParticipantAddress.Delete("Street");
			ParticipantAddress.Delete("Building");
			ParticipantAddress.Delete("Section");
			ParticipantAddress.Delete("Apartment");
			ParticipantAddress.Delete("Qart");
		EndIf;
		For Each Item IN ParticipantAddress Do
			CommonUseED.FillTreeAttributeValue(
									DataTree,
									ParticipantKind + ".Address." + AddressType + "." + Item.Key,
									Item.Value, TreeRootItem);
		EndDo;
		
	EndIf;
	
EndProcedure

Function FindLinkToVendorsProductsAndServicesIdIdentificator(ID, Counterparty, ReturnTypeValues = "ProductsAndServices") Export
	
	FoundItem = Undefined;
	
	Query = New Query;
	Query.SetParameter("ID", ID);
	Query.SetParameter("Counterparty", Counterparty);
	
	Query.Text = 
	"SELECT ALLOWED
	|	CtlProductsAndServices.ProductsAndServices AS ProductsAndServices,
	|	CtlProductsAndServices.Ref AS Ref
	|FROM
	|	Catalog.SuppliersProductsAndServices AS CtlProductsAndServices
	|WHERE
	|	CtlProductsAndServices.ID = &ID
	|	AND CtlProductsAndServices.Owner = &Counterparty";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			If ReturnTypeValues = "ProductsAndServices" Then
				FoundItem = Selection.ProductsAndServices;
			Else
				FoundItem = Selection.Ref;
			EndIf;
		EndIf;
	EndIf;
	
	Return FoundItem;
	
EndFunction

Procedure FillFirstAndLastNameOfSignatoryAtTree(DataTree, SignerType, DataSource) Export
	
	Surname = ""; Name = ""; Patronymic = "";
	ElectronicDocuments.SurnameInitialsOfIndividual(DataSource, Surname, Name, Patronymic);
	CommonUseED.FillTreeAttributeValue(
								DataTree,
								"Signer." + SignerType + ".Surname",
								Surname);
	CommonUseED.FillTreeAttributeValue(DataTree, "Signer." + SignerType + ".Name", Name);
	CommonUseED.FillTreeAttributeValue(
								DataTree,
								"Signer." + SignerType + ".Patronymic",
								Patronymic);
	
EndProcedure

Function CreateRefillVendorsProductsAndServices(ObjectString, ParseTree) Export
	
	SetPrivilegedMode(True);
	
	If ValueIsFilled(ObjectString.ObjectReference) Then
		NewEl = ObjectString.ObjectReference.GetObject();
		RefsOnObjectProductsAndServices = ObjectString.ObjectReference.ProductsAndServices;
	Else
		NewEl = Catalogs.SuppliersProductsAndServices.CreateItem();
		RefsOnObjectProductsAndServices = Undefined;
	EndIf;
	
	FillObjectAttributesByAccordanceDescriptions(ObjectString, NewEl);
	
	// if there is no reference to products and services, we will create it
	If Not ValueIsFilled(RefsOnObjectProductsAndServices) Then 
		FoundString = ObjectString.Rows.Find("ProductsAndServices", "Attribute", True);
		If FoundString <> Undefined Then
			If ValueIsFilled(FoundString.ObjectReference) Then // Ref is found
				RefsOnObjectProductsAndServices = FoundString.ObjectReference;
			Else // will search by index
				IndexOfDesiredRow = FoundString.AttributeValue;	
				FoundString = ParseTree.Rows.Find(IndexOfDesiredRow, "RowIndex", True); // string with object
				If FoundString <> Undefined Then
					If ValueIsFilled(FoundString.ObjectReference) Then // there is reference to DB object
						RefsOnObjectProductsAndServices = FoundString.ObjectReference;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		NewEl.ProductsAndServices = RefsOnObjectProductsAndServices;
	EndIf;
	
	If Not ValueIsFilled(NewEl.Code) Then
		NewEl.SetNewCode();
	EndIf;
	
	NewEl.DataExchange.Load = True;
	Try
		NewEl.Write();
	Except
		Text = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Creating of the catalog item %1.';ru='Создание элемента справочника %1.'"), "Supplier products and services"); 
		WriteLogEvent(Text, EventLogLevel.Error,,,DetailErrorDescription(ErrorInfo()));		
		Raise;
	EndTry;
	
	ObjectReference = NewEl.Ref;
	
	Return ObjectReference;
EndFunction

// Fills in the object attributes by matching the items
//
// Parameters:
//  ArrayRow - ValueTreeRow, parameter set
//  used to fill in MetadataObject - IB object which attributes shall be filled in.
//
Procedure FillObjectAttributesByAccordanceDescriptions(ArrayRow, MetadataObject)
	
	For Each CurRow IN ArrayRow.Rows Do
		If Not ValueIsFilled(CurRow.AttributeValue) Then
			Continue;
		EndIf;
		
		If CommonUse.ThisIsStandardAttribute(MetadataObject.Metadata().StandardAttributes, CurRow.Attribute) Then
			MetadataObject[CurRow.Attribute] = CurRow.AttributeValue;
		ElsIf MetadataObject.Metadata().Attributes.Find(CurRow.Attribute) <> Undefined Then
			If ValueIsFilled(CurRow.ObjectReference) Then
				MetadataObject[CurRow.Attribute] = CurRow.ObjectReference;
			Else
				MetadataObject[CurRow.Attribute] = CurRow.AttributeValue;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Refills in the object header attributes.
//
// Parameters:
//  CurrentObject    - IB object which header attributes shall
//  be filled, FillingData - Value structure to be substituted to the IB object.
//
Procedure RefillingHeaderAttributesValues(CurrentObject, FillingData)
	
	SetPrivilegedMode(True);
	
	For Each String IN FillingData Do
		
		If ValueIsFilled(String.Key) AND CurrentObject.Metadata().Attributes.Find(String.Key) <> Undefined Then
			If CurrentObject[String.Key] <> String.Value Then
				CurrentObject[String.Key] = String.Value;
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

Function StateCodeByName(Description) Export
	
	If IsBlankString(Description) Then
		Return "";
	EndIf;
	
	Titles = TrimL(Description);
	FirstThSpace = Find(Titles, " ");
	If FirstThSpace <> 0 Then
		Titles = Left(Titles, FirstThSpace - 1);
	EndIf;
	
	// first we are trying to find it in the address classifier
	Query = New Query();
	Query.Text = "SELECT TOP 1
	|	AddressClassifier.InCodeAddressObjectCode,
	|	AddressClassifier.AddressPointType,
	|	AddressClassifier.Description
	|FROM
	|	InformationRegister.AddressClassifier AS AddressClassifier
	|
	|WHERE
	|	AddressClassifier.Description = &Description AND
	|	AddressClassifier.AddressPointType = &AddressPointType";
	
	Query.SetParameter("Description", Titles);
	Query.SetParameter("AddressPointType", 1);
	
	Selection = Query.Execute().Select();
	
	If Selection.Count() > 0 Then
		Selection.Next();
		Return Format(Selection.InCodeAddressObjectCode, "ND=2; NLZ=")
	EndIf;
	
	Return "";
	
EndFunction

Procedure FillCounterpartyContract(DocumentObject)

	If Not DocumentObject.Counterparty.DoOperationsByContracts Then
		DocumentObject.Contract = DocumentObject.Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(DocumentObject.Ref, DocumentObject.OperationKind);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Owner = &Counterparty
	|	AND CounterpartyContracts.Company = &Company
	|	AND CounterpartyContracts.DeletionMark = FALSE
	|	AND CounterpartyContracts.SettlementsCurrency = &SettlementsCurrency
	|	AND CounterpartyContracts.ContractKind IN (&ContractKindsList)";
	
	Query.SetParameter("Counterparty", DocumentObject.Counterparty);
	Query.SetParameter("Company", DocumentObject.Company);
	Query.SetParameter("ContractKindsList", ContractTypesList);
	Query.SetParameter("SettlementsCurrency", DocumentObject.DocumentCurrency);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		NewContract = Catalogs.CounterpartyContracts.CreateItem();
		NewContract.Owner = DocumentObject.Counterparty;
		NewContract.Description = "Default contract (" + String(DocumentObject.DocumentCurrency) + ")";
		NewContract.ContractKind = ?(ContractTypesList.Count() > 0, ContractTypesList[0].Value, Enums.ContractKinds.WithCustomer);
		NewContract.Company = DocumentObject.Company;
		NewContract.SettlementsCurrency = DocumentObject.DocumentCurrency;
		NewContract.VendorPaymentDueDate = Constants.VendorPaymentDueDate.Get();
		NewContract.CustomerPaymentDueDate = Constants.CustomerPaymentDueDate.Get();
		NewContract.Write();
		
		DocumentObject.Contract = NewContract.Ref;
		Return;
		
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	DocumentObject.Contract = Selection.Ref;

EndProcedure

Function GetDeliveryAddress(Counterparty) Export

	ShippingAddress = "";
	
	PurposeOfCI = Catalogs.ContactInformationKinds.CatalogCounterparties;
	ShippingAddressKindOfCI = Catalogs.ContactInformationKinds.FindByDescription("Shipping address", True, PurposeOfCI);
	If ValueIsFilled(ShippingAddressKindOfCI) Then
		ShippingAddress = SmallBusinessServer.GetContactInformation(Counterparty, ShippingAddressKindOfCI);
	EndIf;
	
	Return ShippingAddress;

EndFunction // GetDeliveryAddress()

Function GetAddressOfContactInformation(Owner, AddressType = "Legal") Export
	
	Result = New Structure;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactInformation.Country,
	|	ContactInformation.State,
	|	ContactInformation.FieldsValues,
	|	ContactInformation.Presentation
	|FROM
	|	Catalog.%CatalogName%.ContactInformation AS ContactInformation 
	|WHERE
	|	ContactInformation.Ref = &Owner
	|	AND ContactInformation.Type = &Type
	|	AND ContactInformation.Kind = &AddressKind";
	
	If TypeOf(Owner) = Type("CatalogRef.Companies") Then
		AddressKind = Catalogs.ContactInformationKinds["Company" + AddressType + "Address"].Ref;
		Query.Text = StrReplace(Query.Text, "%CatalogName%", "Companies");
	ElsIf TypeOf(Owner) = Type("CatalogRef.Counterparties") Then
		AddressKind = Catalogs.ContactInformationKinds["Counterparty" + AddressType + "Address"].Ref;
		Query.Text = StrReplace(Query.Text, "%CatalogName%", "Counterparties");
	EndIf;
	
	Query.SetParameter("Owner",  Owner);
	Query.SetParameter("Type",       Enums.ContactInformationTypes.Address);
	Query.SetParameter("AddressKind", AddressKind);
	
	QueryResult = Query.Execute();
	
	For Each Column IN QueryResult.Columns Do
		Result.Insert(Column.Name);
	EndDo;
	
	Selection = QueryResult.Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
	
EndFunction

Function GetPhoneFromContactInformation(Owner) Export
	
	Result = Undefined;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactInformation.Presentation AS Phone
	|FROM
	|	Catalog.%CatalogName%.ContactInformation AS ContactInformation 
	|WHERE
	|	ContactInformation.Ref = &Owner
	|	AND ContactInformation.Type = &Type
	|	AND ContactInformation.Kind = &KindOfPhone";
	
	If TypeOf(Owner) = Type("CatalogRef.Companies") Then
		KindOfPhone = Catalogs.ContactInformationKinds["CompanyPhone"].Ref;
		Query.Text = StrReplace(Query.Text, "%CatalogName%", "Companies");
	ElsIf TypeOf(Owner) = Type("CatalogRef.Counterparties") Then
		KindOfPhone = Catalogs.ContactInformationKinds["CounterpartyPhone"].Ref;
		Query.Text = StrReplace(Query.Text, "%CatalogName%", "Counterparties");
	EndIf;
	
	Query.SetParameter("Owner",    Owner);
	Query.SetParameter("Type",         Enums.ContactInformationTypes.Phone);
	Query.SetParameter("KindOfPhone", KindOfPhone);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.Phone;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure RecalculateTabularSectionPricesByCurrency(Document, PreviousCurrency, TabularSectionName)
	
	RatesStructure = SmallBusinessServer.GetCurrencyRates(PreviousCurrency, Document.DocumentCurrency, Document.Date);
																   
	For Each TabularSectionRow IN Document[TabularSectionName] Do
		
		TabularSectionRow.Price = SmallBusinessServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.Price, 
																								RatesStructure.InitRate, 
																								RatesStructure.ExchangeRate, 
																								RatesStructure.RepetitionBeg, 
																								RatesStructure.Multiplicity);
		
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
		VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
		If Document.AmountIncludesVAT Then
			TabularSectionRow.VATAmount = ?(
				Document.AmountIncludesVAT, 
				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
				TabularSectionRow.Amount * VATRate / 100
			);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Document.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		Else
			TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
			TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
		EndIf;
		
	EndDo;
	
EndProcedure









