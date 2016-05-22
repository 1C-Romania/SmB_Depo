#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

//Getting data on shipment procedure
//
Procedure GetDataOnShipment(DocumentData, CurrentDocument)
	
	Query = New Query;
	Query.SetParameter("Document",  CurrentDocument);
	
	Query.Text =
	"SELECT
	|	CustomerInvoice.Number,
	|	CustomerInvoice.Ref AS CurrentDocument,
	|	CustomerInvoice.Date AS DocumentDate,
	|	CustomerInvoice.DeliveryTerm AS DeliveryTerm,
	|	CustomerInvoice.Company,
	|	CustomerInvoice.Company.Prefix AS Prefix,
	|	CustomerInvoice.Company AS LegalEntityIndividual,
	|	CustomerInvoice.Company AS Vendor,
	|	CustomerInvoice.StructuralUnit AS StructuralUnit,
	|	CustomerInvoice.Head AS Head,
	|	CustomerInvoice.HeadPosition AS HeadPosition,
	|	CustomerInvoice.ChiefAccountant AS ChiefAccountant,
	|	CustomerInvoice.Released AS Released,
	|	CustomerInvoice.ReleasedPosition AS ReleasedPosition,
	|	CASE
	|		WHEN CustomerInvoice.Consignor = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN CustomerInvoice.Company
	|		ELSE CustomerInvoice.Consignor
	|	END AS Consignor,
	|	CASE
	|		WHEN CustomerInvoice.Consignee = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN CustomerInvoice.Counterparty
	|		ELSE CustomerInvoice.Consignee
	|	END AS Consignee,
	|	CustomerInvoice.BankAccount AS BankAccount,
	|	CustomerInvoice.Counterparty AS Customer,
	|	CustomerInvoice.Counterparty AS Payer,
	|	CustomerInvoice.CounterpartyBankAcc AS PayerBankAcc,
	|	CustomerInvoice.ShippingAddress AS ShippingAddress,
	|	CustomerInvoice.Carrier AS Carrier,
	|	CustomerInvoice.DocumentCurrency,
	|	CustomerInvoice.ExchangeRate AS ExchangeRate,
	|	CustomerInvoice.Multiplicity AS Multiplicity,
	|	CustomerInvoice.IncludeVATInPrice,
	|	CustomerInvoice.AmountIncludesVAT,
	|	CustomerInvoice.PowerOfAttorneyNumber AS PowerOfAttorneyNumber,
	|	CustomerInvoice.PowerOfAttorneyDate AS PowerOfAttorneyDate,
	|	CustomerInvoice.PowerOfAttorneyIssued AS PowerOfAttorneyIssued,
	|	CustomerInvoice.PowerAttorneyPerson AS PowerAttorneyPerson,
	|	CustomerInvoice.StructuralUnit.FRP AS WarehouseMan,
	|	CustomerInvoice.Vehicle,
	|	CustomerInvoice.Vehicle.Brand AS VehicleBrand,
	|	CustomerInvoice.Vehicle.Code AS VehicleRegistrationNo,
	|	CustomerInvoice.trailer AS trailer,
	|	CustomerInvoice.trailer.Brand AS TrailerBrand,
	|	CustomerInvoice.trailer.Code AS TrailerRegistrationNo,
	|	CustomerInvoice.Vehicle.CurrentLicenseCard AS CurrentLicenseCard,
	|	CustomerInvoice.Vehicle.CurrentLicenseCard.RegistrationNumberInGovernmentAgency AS LicenceCardRegistrationNo,
	|	CustomerInvoice.Vehicle.CurrentLicenseCard.LicenseCardSeries AS LicenceCardSeries,
	|	CustomerInvoice.Vehicle.CurrentLicenseCard.LicenseCardNumber AS LicenceCardNo,
	|	CustomerInvoice.Vehicle.CurrentLicenseCard.ActivityKind AS LicenseCardActivityKind,
	|	CustomerInvoice.Driver AS Driver,
	|	CustomerInvoice.Inventory.(
	|		LineNumber AS Number,
	|		ProductsAndServices,
	|		CASE
	|			WHEN (CAST(CustomerInvoice.Inventory.ProductsAndServices.DescriptionFull AS String(1000))) = """"
	|				THEN CustomerInvoice.Inventory.ProductsAndServices.Description
	|			ELSE CAST(CustomerInvoice.Inventory.ProductsAndServices.DescriptionFull AS String(1000))
	|		END AS InventoryItemDescription,
	|		ProductsAndServices.Code AS CodeProducts,
	|		Quantity AS Quantity,
	|		0 AS PlacesQuantity,
	|		ProductsAndServices.MeasurementUnit AS BaseUnitDescription,
	|		MeasurementUnit AS MeasurementUnitDocument,
	|		MeasurementUnit AS PackagingKind,
	|		ProductsAndServices.MeasurementUnit.Code AS BaseUnitCodeRCUM,
	|		MeasurementUnit.Factor AS Factor,
	|		CustomerInvoice.Inventory.Price * CustomerInvoice.ExchangeRate / CustomerInvoice.Multiplicity AS Price,
	|		CustomerInvoice.Inventory.Amount * CustomerInvoice.ExchangeRate / CustomerInvoice.Multiplicity AS Amount,
	|		CustomerInvoice.Inventory.VATAmount * CustomerInvoice.ExchangeRate / CustomerInvoice.Multiplicity AS VATAmount,
	|		CustomerInvoice.Inventory.Total * CustomerInvoice.ExchangeRate / CustomerInvoice.Multiplicity AS Total,
	|		Amount AS AmountInDocumentCurrency,
	|		VATAmount AS VATAmountInDocumentCurrency,
	|		Total AS TotalInCurrencyOfDocument,
	|		VATRate,
	|		ProductsAndServices.SKU AS SKU,
	|		Characteristic,
	|		Content
	|	)
	|FROM
	|	Document.CustomerInvoice AS CustomerInvoice
	|WHERE
	|	CustomerInvoice.Ref = &Document";
	
	DocumentDataSelection = Query.Execute().Select();
	
	DocumentDataSelection.Next();
	DocumentData.Insert("Header", DocumentDataSelection);
	
	DocumentTabularSection = DocumentDataSelection.Inventory.Unload();
	DocumentData.Insert("DocumentTabularSection", DocumentTabularSection);
	
EndProcedure // GetDataOnShipment()

//Getting data to move inventories procedure
//
Procedure GetDataOnInventoryMovement(DocumentData, CurrentDocument)
	
	Query = New Query;
	Query.SetParameter("DocumentDate",	CurrentDocument.Date);
	Query.SetParameter("Document",  		CurrentDocument);
	
	// If moving has something to do with retail, try to fill the amount of retail. prices
	// otherwise fill in accounting costs
	If ValueIsFilled(CurrentDocument.StructuralUnit.RetailPriceKind) Then
		Query.SetParameter("PriceKind",  		CurrentDocument.StructuralUnit.RetailPriceKind);
		Query.SetParameter("PriceKindCurrency", ?(ValueIsFilled(CurrentDocument.StructuralUnit.RetailPriceKind.PriceCurrency), CurrentDocument.StructuralUnit.RetailPriceKind.PriceCurrency, Constants.NationalCurrency.Get()));
	ElsIf ValueIsFilled(CurrentDocument.StructuralUnitPayee.RetailPriceKind) Then
		Query.SetParameter("PriceKind",  		CurrentDocument.StructuralUnitPayee.RetailPriceKind);
		Query.SetParameter("PriceKindCurrency", ?(ValueIsFilled(CurrentDocument.StructuralUnitPayee.RetailPriceKind.PriceCurrency), CurrentDocument.StructuralUnitPayee.RetailPriceKind.PriceCurrency, Constants.NationalCurrency.Get()));
	Else
		Query.SetParameter("PriceKind",  		Catalogs.PriceKinds.Accounting);
		Query.SetParameter("PriceKindCurrency", ?(ValueIsFilled(Catalogs.PriceKinds.Accounting.PriceCurrency), Catalogs.PriceKinds.Accounting.PriceCurrency, Constants.NationalCurrency.Get()));
	EndIf;
	
	Query.Text =
	"SELECT
	|	InventoryTransfer.Number,
	|	InventoryTransfer.Ref AS CurrentDocument,
	|	InventoryTransfer.Date AS DocumentDate,
	|	InventoryTransfer.Company,
	|	InventoryTransfer.Company.Prefix AS Prefix,
	|	InventoryTransfer.Company AS LegalEntityIndividual,
	|	InventoryTransfer.Company AS Vendor,
	|	InventoryTransfer.Company AS Counterparty,
	|	InventoryTransfer.Company AS Heads,
	|	InventoryTransfer.StructuralUnit.Company AS Consignor,
	|	InventoryTransfer.Company.BankAccountByDefault AS BankAccount,
	|	InventoryTransfer.StructuralUnitPayee.Company AS Consignee,
	|	InventoryTransfer.StructuralUnitPayee.Company AS Customer,
	|	InventoryTransfer.StructuralUnit.Company AS Payer,
	|	InventoryTransfer.Company.BankAccountByDefault AS PayerBankAcc,
	|	InventoryTransfer.StructuralUnit,
	|	InventoryTransfer.Cell,
	|	InventoryTransfer.CustomerOrder,
	|	InventoryTransfer.GLExpenseAccount,
	|	InventoryTransfer.BusinessActivity,
	|	InventoryTransfer.Released AS WarehouseMan,
	|	InventoryTransfer.ShippingAddress AS ShippingAddress,
	|	InventoryTransfer.Vehicle,
	|	InventoryTransfer.Vehicle.Brand AS VehicleBrand,
	|	InventoryTransfer.Vehicle.Code AS VehicleRegistrationNo,
	|	InventoryTransfer.CarrierBankAccount,
	|	InventoryTransfer.Driver,
	|	InventoryTransfer.ChiefAccountant,
	|	InventoryTransfer.PowerOfAttorneyIssued,
	|	InventoryTransfer.PowerOfAttorneyDate,
	|	InventoryTransfer.PowerAttorneyPerson,
	|	InventoryTransfer.PowerOfAttorneyNumber,
	|	InventoryTransfer.Released,
	|	InventoryTransfer.ReleasedPosition,
	|	InventoryTransfer.Carrier,
	|	InventoryTransfer.trailer,
	|	InventoryTransfer.trailer.Brand AS TrailerBrand,
	|	InventoryTransfer.trailer.Code AS TrailerRegistrationNo,
	|	InventoryTransfer.Vehicle.CurrentLicenseCard AS CurrentLicenseCard,
	|	InventoryTransfer.Vehicle.CurrentLicenseCard.RegistrationNumberInGovernmentAgency AS LicenceCardRegistrationNo,
	|	InventoryTransfer.Vehicle.CurrentLicenseCard.LicenseCardSeries AS LicenceCardSeries,
	|	InventoryTransfer.Vehicle.CurrentLicenseCard.LicenseCardNumber AS LicenceCardNo,
	|	InventoryTransfer.Vehicle.CurrentLicenseCard.ActivityKind AS LicenseCardActivityKind,
	|	InventoryTransfer.Head,
	|	InventoryTransfer.HeadPosition,
	|	InventoryTransfer.DeliveryTerm,
	|	InventoryTransfer.StampBase
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	InventoryTransfer.Ref = &Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTransferInventory.Ref,
	|	InventoryTransferInventory.LineNumber,
	|	InventoryTransferInventory.ProductsAndServices,
	|	InventoryTransferInventory.ProductsAndServices.DescriptionFull AS InventoryItemDescription,
	|	InventoryTransferInventory.ProductsAndServices.Code AS CodeProducts,
	|	InventoryTransferInventory.ProductsAndServices.SKU AS SKU,
	|	InventoryTransferInventory.ProductsAndServices.MeasurementUnit AS BaseUnitDescription,
	|	InventoryTransferInventory.MeasurementUnit AS MeasurementUnitDocument,
	|	InventoryTransferInventory.MeasurementUnit AS PackagingKind,
	|	InventoryTransferInventory.MeasurementUnit.Code AS BaseUnitCodeRCUM,
	|	InventoryTransferInventory.MeasurementUnit.Factor AS Factor,
	|	0 AS PlacesQuantity,
	|	InventoryTransferInventory.Quantity AS Quantity,
	|	InventoryTransferInventory.Characteristic,
	|	InventoryTransferInventory.Batch,
	|	InventoryTransferInventory.Reserve,
	|	InventoryTransferInventory.CustomerOrder,
	|	CAST(CASE
	|			WHEN &PriceKindCurrency = ConstantNationalCurrency.Value
	|				THEN ISNULL(ProductsAndServicesPricesSliceLast.Price * InventoryTransferInventory.Quantity, 0)
	|			ELSE ISNULL(ProductsAndServicesPricesSliceLast.Price * InventoryTransferInventory.Quantity, 0) * CurrencyRatesSliceLast.ExchangeRate / CASE
	|					WHEN ISNULL(CurrencyRatesSliceLast.Multiplicity, 0) = 0
	|						THEN 1
	|					ELSE CurrencyRatesSliceLast.Multiplicity
	|				END
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
	|				&DocumentDate,
	|				PriceKind = &PriceKind
	|					AND ProductsAndServices In
	|						(SELECT
	|							InventoryTransferInventory.ProductsAndServices
	|						FROM
	|							Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|						WHERE
	|							InventoryTransferInventory.Ref = &Document)
	|					AND Characteristic In
	|						(SELECT
	|							InventoryTransferInventory.Characteristic
	|						FROM
	|							Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|						WHERE
	|							InventoryTransferInventory.Ref = &Document)) AS ProductsAndServicesPricesSliceLast
	|		ON InventoryTransferInventory.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|			AND InventoryTransferInventory.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic,
	|	InformationRegister.CurrencyRates.SliceLast(&DocumentDate, Currency = &PriceKindCurrency) AS CurrencyRatesSliceLast,
	|	Constant.NationalCurrency AS ConstantNationalCurrency
	|WHERE
	|	InventoryTransferInventory.Ref = &Document";
	
	QueryResult = Query.ExecuteBatch();
	DocumentDataSelection = QueryResult[0].Select();
	
	DocumentDataSelection.Next();
	DocumentData.Insert("Header", DocumentDataSelection);
	
	DocumentTabularSection = QueryResult[1].Unload();
	DocumentData.Insert("DocumentTabularSection", DocumentTabularSection);
	
EndProcedure // GetDataOnInventoryMovement()

// Getting data about report processing procedure
//
Procedure GetDataOnReportAboutRecycling(DocumentData, CurrentDocument)
	
	Query = New Query;
	Query.SetParameter("Document",  CurrentDocument);
	
	Query.Text =
	"SELECT
	|	ProcessingReport.Number,
	|	ProcessingReport.Ref AS CurrentDocument,
	|	ProcessingReport.Date AS DocumentDate,
	|	ProcessingReport.Company,
	|	ProcessingReport.Company.Prefix AS Prefix,
	|	ProcessingReport.Company AS LegalEntityIndividual,
	|	ProcessingReport.Company AS Vendor,
	|	ProcessingReport.Company AS Counterparty,
	|	ProcessingReport.Counterparty AS Customer,
	|	ProcessingReport.Counterparty AS Payer,
	|	ProcessingReport.CounterpartyBankAcc AS PayerBankAcc,
	|	ProcessingReport.DocumentCurrency,
	|	ProcessingReport.ExchangeRate AS ExchangeRate,
	|	ProcessingReport.Multiplicity AS Multiplicity,
	|	ProcessingReport.IncludeVATInPrice,
	|	ProcessingReport.AmountIncludesVAT,
	|	CASE
	|		WHEN ProcessingReport.Consignor = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN ProcessingReport.Company
	|		ELSE ProcessingReport.Consignor
	|	END AS Consignor,
	|	CASE
	|		WHEN ProcessingReport.Consignee = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN ProcessingReport.Counterparty
	|		ELSE ProcessingReport.Consignee
	|	END AS Consignee,
	|	ProcessingReport.BankAccount AS BankAccount,
	|	ProcessingReport.ShippingAddress AS ShippingAddress,
	|	ProcessingReport.Vehicle,
	|	ProcessingReport.Vehicle.Brand AS VehicleBrand,
	|	ProcessingReport.Vehicle.Code AS VehicleRegistrationNo,
	|	ProcessingReport.CarrierBankAccount,
	|	ProcessingReport.Driver,
	|	ProcessingReport.ChiefAccountant,
	|	ProcessingReport.PowerOfAttorneyIssued,
	|	ProcessingReport.PowerOfAttorneyDate,
	|	ProcessingReport.PowerAttorneyPerson,
	|	ProcessingReport.PowerOfAttorneyNumber,
	|	ProcessingReport.Released AS WarehouseMan,
	|	ProcessingReport.Released,
	|	ProcessingReport.ReleasedPosition,
	|	ProcessingReport.Carrier,
	|	ProcessingReport.trailer,
	|	ProcessingReport.trailer.Brand AS TrailerBrand,
	|	ProcessingReport.trailer.Code AS TrailerRegistrationNo,
	|	ProcessingReport.Vehicle.CurrentLicenseCard AS CurrentLicenseCard,
	|	ProcessingReport.Vehicle.CurrentLicenseCard.RegistrationNumberInGovernmentAgency AS LicenceCardRegistrationNo,
	|	ProcessingReport.Vehicle.CurrentLicenseCard.LicenseCardSeries AS LicenceCardSeries,
	|	ProcessingReport.Vehicle.CurrentLicenseCard.LicenseCardNumber AS LicenceCardNo,
	|	ProcessingReport.Vehicle.CurrentLicenseCard.ActivityKind AS LicenseCardActivityKind,
	|	ProcessingReport.Head,
	|	ProcessingReport.HeadPosition,
	|	ProcessingReport.DeliveryTerm,
	|	ProcessingReport.StampBase,
	|	ProcessingReport.StructuralUnit AS StructuralUnit,
	|	ProcessingReport.Products.(
	|		LineNumber AS Number,
	|		ProductsAndServices,
	|		ProductsAndServices.DescriptionFull AS InventoryItemDescription,
	|		ProductsAndServices.Code AS CodeProducts,
	|		Quantity AS Quantity,
	|		0 AS PlacesQuantity,
	|		ProductsAndServices.MeasurementUnit AS BaseUnitDescription,
	|		MeasurementUnit AS MeasurementUnitDocument,
	|		MeasurementUnit AS PackagingKind,
	|		MeasurementUnit.Code AS BaseUnitCodeRCUM,
	|		MeasurementUnit.Factor AS Factor,
	|		ProcessingReport.Products.Price * ProcessingReport.ExchangeRate / ProcessingReport.Multiplicity AS Price,
	|		ProcessingReport.Products.Amount * ProcessingReport.ExchangeRate / ProcessingReport.Multiplicity AS Amount,
	|		ProcessingReport.Products.VATAmount * ProcessingReport.ExchangeRate / ProcessingReport.Multiplicity AS VATAmount,
	|		ProcessingReport.Products.Total * ProcessingReport.ExchangeRate / ProcessingReport.Multiplicity AS Total,
	|		Amount AS AmountInDocumentCurrency,
	|		VATAmount AS VATAmountInDocumentCurrency,
	|		Total AS TotalInCurrencyOfDocument,
	|		VATRate,
	|		ProductsAndServices.SKU AS SKU,
	|		Characteristic
	|	),
	|	ProcessingReport.Disposals.(
	|		LineNumber AS Number,
	|		ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServices.DescriptionFull AS InventoryItemDescription,
	|		ProductsAndServices.Code AS CodeProducts,
	|		Quantity,
	|		0 AS PlacesQuantity,
	|		ProductsAndServices.MeasurementUnit AS BaseUnitDescription,
	|		MeasurementUnit AS MeasurementUnitDocument,
	|		MeasurementUnit AS PackagingKind,
	|		MeasurementUnit.Code AS BaseUnitCodeRCUM,
	|		MeasurementUnit.Factor AS Factor,
	|		0 AS Price,
	|		0 AS Amount,
	|		0 AS VATAmount,
	|		0 AS TotalAmount,
	|		0 AS AmountInDocumentCurrency,
	|		0 AS VATAmountInDocumentCurrency,
	|		0 AS TotalInCurrencyOfDocument,
	|		NULL AS VATRate,
	|		ProductsAndServices.SKU AS SKU,
	|		Characteristic AS Characteristic
	|	)
	|FROM
	|	Document.ProcessingReport AS ProcessingReport
	|WHERE
	|	ProcessingReport.Ref = &Document";
	
	DocumentDataSelection = Query.Execute().Select();
	
	DocumentDataSelection.Next();
	DocumentData.Insert("Header", DocumentDataSelection);
	
	TabularSectionProducts = DocumentDataSelection.Products.Unload();
	DocumentData.Insert("TabularSectionProducts", TabularSectionProducts);
	
	TabularSectionDisposals = DocumentDataSelection.Products.Unload();
	DocumentData.Insert("TabularSectionDisposals", TabularSectionDisposals);
	
EndProcedure // GetDataOnReportAboutRecycling()

#EndRegion

#Region PrintInterface

// The function returns a tabular document for printing BoL
//
Function PrintForm(ObjectsArray, PrintObjects, PrintParameters) Export
	
	DocumentData		= New Structure;
	SpreadsheetDocument	= New SpreadsheetDocument;
	FirstDocument 		= True;
	
	For Each CurrentDocument IN ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_OPTIONS_PrintWayBill_Waybill";
		
		DocumentData.Clear();
		
		If TypeOf(CurrentDocument) = Type("DocumentRef.CustomerInvoice") Then
			
			GetDataOnShipment(DocumentData, CurrentDocument);
			Header = DocumentData.Header;
			DocumentTabularSection = DocumentData.DocumentTabularSection;
			
		ElsIf TypeOf(CurrentDocument) = Type("DocumentRef.InventoryTransfer") Then
			
			GetDataOnInventoryMovement(DocumentData, CurrentDocument);
			Header = DocumentData.Header;
			DocumentTabularSection = DocumentData.DocumentTabularSection;
			
		ElsIf TypeOf(CurrentDocument) = Type("DocumentRef.ProcessingReport") Then
			
			GetDataOnReportAboutRecycling(DocumentData, CurrentDocument);
			Header = DocumentData.Header;
			TabularSectionProducts = DocumentData.TabularSectionProducts;
			TabularSectionDisposals = DocumentData.TabularSectionDisposals;
			
		EndIf; 
		
		Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintBOL.PF_MXL_BOL");
		
		// Displaying general header attributes
		InfoAboutVendor       = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.LegalEntityIndividual,        Header.DocumentDate, , Header.BankAccount);
		InfoAboutShipper = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Consignor, Header.DocumentDate, , ?(Header.Consignor = Header.LegalEntityIndividual, Header.BankAccount, Undefined));
		InfoAboutCustomer       = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Customer,       Header.DocumentDate, , Header.PayerBankAcc);
		InfoAboutConsignee  = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Consignee,  Header.DocumentDate);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.DocumentNumber                = DocumentNumber;
		TemplateArea.Parameters.DocumentDate                 = Header.DocumentDate;
		TemplateArea.Parameters.Consignor              = Header.Consignor;
		TemplateArea.Parameters.Consignee               = Header.Consignee;
		TemplateArea.Parameters.Payer                    = Header.Customer;
		TemplateArea.Parameters.ShipperPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutShipper, "FullDescr,TIN,ActualAddress,PhoneNumbers,AccountNo,Bank,BIN,CorrAccount");
		TemplateArea.Parameters.ConsigneePresentation  = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutConsignee,  "FullDescr,TIN,ActualAddress,PhoneNumbers,AccountNo,Bank,BIN,CorrAccount");
		TemplateArea.Parameters.PayerRepresentation       = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer);
		TemplateArea.Parameters.ShipperByARBOC        = InfoAboutShipper.CodeByOKPO;
		TemplateArea.Parameters.ConsigneeByARBOC         = InfoAboutConsignee.CodeByOKPO;
		TemplateArea.Parameters.PayerByRCEO              = InfoAboutCustomer.CodeByOKPO;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		RowsPerPage = 23;
		RowsCaps      = 10;
		RowsOfBasement    = 9;
		PageNumber   = 1;
		
		// Displaying table title
		TableTitle = Template.GetArea("TableTitle");
		TableTitle.Parameters.PageNumber = "Page " + PageNumber; 
		SpreadsheetDocument.Put(TableTitle);
		
		// initializing totals on the page
		TotalQuantityOnPage = 0;
		TotalAmountOnPage      = 0;
		TotalVATOnPage        = 0;
		TotalAmountOfWithVATOnPage  = 0;
		
		// initializing totals on the document
		TotalPlaces		= 0;
		TotalQuantity = 0;
		TotalAmountWithVAT	= 0;
		TotalAmount		= 0;
		TotalVAT		= 0;
		Num				= 0;
		
		// Displaying multiline part of the document
		TemplateArea = Template.GetArea("String");
		
		If TypeOf(CurrentDocument) = Type("DocumentRef.CustomerInvoice") Then
			
			LineQuantity = DocumentTabularSection.Count();
			
			If LineQuantity = 1 Then
				WrapLastRow = 0;
			Else
				EntirePagesWithBasement		= Int((RowsCaps + LineQuantity + RowsOfBasement) / RowsPerPage);
				EntirePagesWithoutBasement		= Int((RowsCaps + LineQuantity - 1) / RowsPerPage);
				WrapLastRow	= EntirePagesWithBasement - EntirePagesWithoutBasement;
			EndIf;
			
			For Each LinesSelectionInventory IN DocumentTabularSection Do
				
				Num				= Num + 1;
				AWholePage	= (RowsCaps + Num - 1) / RowsPerPage;
				
				If (AWholePage = Int(AWholePage))
					OR ((WrapLastRow = 1) AND (Num = LineQuantity)) Then
				
					TotalsAreaByPage = Template.GetArea("TotalByPage");
					
					TotalsAreaByPage.Parameters.TotalQuantityOnPage = TotalQuantityOnPage;
					TotalsAreaByPage.Parameters.TotalAmountOfWithVATOnPage  = TotalAmountOfWithVATOnPage;
					
					// clear totals on the page
					TotalQuantityOnPage = 0;
					TotalAmountOfWithVATOnPage  = 0;
					
					PageNumber = PageNumber + 1;
					SpreadsheetDocument.PutHorizontalPageBreak();
					TableTitle.Parameters.PageNumber = "Page " + PageNumber;
					SpreadsheetDocument.Put(TableTitle);
					
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				If ValueIsFilled(LinesSelectionInventory.Content) Then
					TemplateArea.Parameters.InventoryItemDescription = LinesSelectionInventory.Content;
				Else
					TemplateArea.Parameters.InventoryItemDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItemDescription, 
																		LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
				EndIf;
				
				SumWithVAT	= LinesSelectionInventory.Total;
				
				Places		= LinesSelectionInventory.PlacesQuantity;
				
				Factor = 1;
				If TypeOf(LinesSelectionInventory.MeasurementUnitDocument) = Type("CatalogRef.UOM") Then
					
					Factor = LinesSelectionInventory.Factor;
					
				EndIf;
				Quantity = LinesSelectionInventory.Quantity * Factor;
				
				TemplateArea.Parameters.Quantity = Quantity;
				
				VATAmount	= LinesSelectionInventory.VATAmount;
				AmountWithoutVAT = LinesSelectionInventory.Amount - ?(Header.AmountIncludesVAT, LinesSelectionInventory.VATAmount, 0);
				
				TemplateArea.Parameters.Amount = SumWithVAT;
				TemplateArea.Parameters.Price  = SumWithVAT / ?(Quantity = 0, 1, Quantity);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				// increase totals on the page
				TotalQuantityOnPage	= TotalQuantityOnPage + Quantity;
				TotalAmountOnPage		= TotalAmountOnPage		+ AmountWithoutVAT;
				TotalVATOnPage 			= TotalVATOnPage		+ VATAmount;
				TotalAmountOfWithVATOnPage 	= TotalAmountOfWithVATOnPage	+ SumWithVAT;
				
				// increase totals on the document
				TotalPlaces		= TotalPlaces			+ Places;
				TotalQuantity = TotalQuantity	+ Quantity;
				TotalAmount		= TotalAmount		+ AmountWithoutVAT;
				TotalVAT		= TotalVAT			+ VATAmount;
				TotalAmountWithVAT	= TotalAmountWithVAT	+ SumWithVAT;
			
			EndDo;
			
		ElsIf TypeOf(CurrentDocument) = Type("DocumentRef.InventoryTransfer") Then
			
			LineQuantity = DocumentTabularSection.Count();
			
			If LineQuantity = 1 Then
				WrapLastRow = 0;
			Else
				EntirePagesWithBasement     = Int((RowsCaps + LineQuantity + RowsOfBasement) / RowsPerPage);
				EntirePagesWithoutBasement    = Int((RowsCaps + LineQuantity - 1) / RowsPerPage);
				WrapLastRow = EntirePagesWithBasement - EntirePagesWithoutBasement;
			EndIf;
			
			
			For Each LinesSelectionInventory IN DocumentTabularSection Do
				
				Num				= Num + 1;
				AWholePage	= (RowsCaps + Num - 1) / RowsPerPage;
				
				If (AWholePage = Int(AWholePage))
				 or ((WrapLastRow = 1) and (Num = LineQuantity)) Then
				
					TotalsAreaByPage = Template.GetArea("TotalByPage");
					
					TotalsAreaByPage.Parameters.TotalQuantityOnPage = TotalQuantityOnPage;
					TotalsAreaByPage.Parameters.TotalAmountOfWithVATOnPage  = TotalAmountOfWithVATOnPage;
					
					// clear totals on the page
					TotalQuantityOnPage = 0;
					TotalAmountOfWithVATOnPage  = 0;
					
					PageNumber = PageNumber + 1;
					SpreadsheetDocument.PutHorizontalPageBreak();
					TableTitle.Parameters.PageNumber = "Page " + PageNumber;
					SpreadsheetDocument.Put(TableTitle);
				
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				TemplateArea.Parameters.InventoryItemDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItemDescription, 
																		LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
				
				Places		= LinesSelectionInventory.PlacesQuantity;
				
				Factor = 1;
				If TypeOf(LinesSelectionInventory.MeasurementUnitDocument) = Type("CatalogRef.UOM") Then
					
					Factor = LinesSelectionInventory.Factor;
					
				EndIf;
				Quantity	= LinesSelectionInventory.Quantity * Factor;
				
				TemplateArea.Parameters.Quantity = Quantity;
				
				TemplateArea.Parameters.Price  = LinesSelectionInventory.Amount / ?(Quantity = 0, 1, Quantity);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				// increase totals on the page
				TotalQuantityOnPage = TotalQuantityOnPage + Quantity;
				TotalAmountOnPage      = TotalAmountOnPage      + LinesSelectionInventory.Amount;
				TotalVATOnPage        = TotalVATOnPage        + 0;
				TotalAmountOfWithVATOnPage  = TotalAmountOfWithVATOnPage  + LinesSelectionInventory.Amount;
				
				// increase totals on the document
				TotalPlaces       = TotalPlaces       + Places;
				TotalQuantity = TotalQuantity + Quantity;
				TotalAmount      = TotalAmount      + LinesSelectionInventory.Amount; 	//AmountWithoutVAT;
				TotalVAT        = TotalVAT        + 0;							//VATAmount;
				TotalAmountWithVAT  = TotalAmountWithVAT  + LinesSelectionInventory.Amount; 	//AmountWithVAT;
			
			EndDo;
			
		Else
			
			LineQuantity = TabularSectionProducts.Count() + TabularSectionDisposals.Count();
			
			If LineQuantity = 1 Then
				WrapLastRow = 0;
			Else
				EntirePagesWithBasement     = Int((RowsCaps + LineQuantity + RowsOfBasement) / RowsPerPage);
				EntirePagesWithoutBasement    = Int((RowsCaps + LineQuantity - 1) / RowsPerPage);
				WrapLastRow = EntirePagesWithBasement - EntirePagesWithoutBasement;
			EndIf;
			
			For Each RowsSelectionProduction IN TabularSectionProducts Do
			
				Num           = Num + 1;
				AWholePage = (RowsCaps + Num - 1) / RowsPerPage;
				
				If (AWholePage = Int(AWholePage))
				 or ((WrapLastRow = 1) and (Num = LineQuantity)) Then
				
					TotalsAreaByPage = Template.GetArea("TotalByPage");
					
					TotalsAreaByPage.Parameters.TotalQuantityOnPage = TotalQuantityOnPage;
					TotalsAreaByPage.Parameters.TotalAmountOfWithVATOnPage  = TotalAmountOfWithVATOnPage;
					
					// clear totals on the page
					TotalQuantityOnPage = 0;
					TotalAmountOfWithVATOnPage  = 0;
					
					PageNumber = PageNumber + 1;
					SpreadsheetDocument.PutHorizontalPageBreak();
					TableTitle.Parameters.PageNumber = "Page " + PageNumber;
					SpreadsheetDocument.Put(TableTitle);
				
				EndIf;
				
				TemplateArea.Parameters.Fill(RowsSelectionProduction);
				
				TemplateArea.Parameters.InventoryItemDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(RowsSelectionProduction.InventoryItemDescription, RowsSelectionProduction.Characteristic);
					
				SumWithVAT	= RowsSelectionProduction.Total;
				Places		= RowsSelectionProduction.PlacesQuantity;
				
				Factor = 1;
				If TypeOf(RowsSelectionProduction.MeasurementUnitDocument) = Type("CatalogRef.UOM") Then
					
					Factor = RowsSelectionProduction.Factor;
					
				EndIf;
				Quantity	= RowsSelectionProduction.Quantity * Factor;
				
				TemplateArea.Parameters.Quantity = Quantity;
				
				VATAmount	= RowsSelectionProduction.VATAmount;
				AmountWithoutVAT = RowsSelectionProduction.Amount - ?(Header.AmountIncludesVAT, RowsSelectionProduction.VATAmount, 0);
				
				TemplateArea.Parameters.Amount = SumWithVAT;
				TemplateArea.Parameters.Price  = SumWithVAT / ?(Quantity = 0, 1, Quantity);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				// increase totals on the page
				TotalQuantityOnPage = TotalQuantityOnPage + Quantity;
				TotalAmountOnPage      = TotalAmountOnPage      + AmountWithoutVAT;
				TotalVATOnPage        = TotalVATOnPage        + VATAmount;
				TotalAmountOfWithVATOnPage  = TotalAmountOfWithVATOnPage  + SumWithVAT;
				
				// increase totals on the document
				TotalPlaces       = TotalPlaces       + Places;
				TotalQuantity = TotalQuantity + Quantity;
				TotalAmount      = TotalAmount      + AmountWithoutVAT;
				TotalVAT        = TotalVAT        + VATAmount;
				TotalAmountWithVAT  = TotalAmountWithVAT  + SumWithVAT;
			
			EndDo;
			
			For Each LinesSelectionDisposals IN TabularSectionDisposals Do
			
				Num = Num + 1;
				AWholePage = (RowsCaps + Num - 1) / RowsPerPage;
				
				If (AWholePage = Int(AWholePage))
				Or ((WrapLastRow = 1) and (Num = LineQuantity)) Then
					
					TotalsAreaByPage = Template.GetArea("TotalByPage");
					
					TotalsAreaByPage.Parameters.TotalQuantityOnPage = TotalQuantityOnPage;
					TotalsAreaByPage.Parameters.TotalAmountOfWithVATOnPage  = TotalAmountOfWithVATOnPage;
					
					// clear totals on the page
					TotalQuantityOnPage = 0;
					TotalAmountOfWithVATOnPage  = 0;
					
					PageNumber = PageNumber + 1;
					SpreadsheetDocument.PutHorizontalPageBreak();
					TableTitle.Parameters.PageNumber = "Page " + PageNumber;
					SpreadsheetDocument.Put(TableTitle);
				
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionDisposals);
				
				TemplateArea.Parameters.InventoryItemDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionDisposals.InventoryItemDescription, LinesSelectionDisposals.Characteristic);
					
				Places		= LinesSelectionDisposals.PlacesQuantity;
				
				Factor = 1;
				If TypeOf(LinesSelectionDisposals.MeasurementUnitDocument) = Type("CatalogRef.UOM") Then
					
					Factor = LinesSelectionDisposals.Factor;
					
				EndIf;
				Quantity	= LinesSelectionDisposals.Quantity * Factor;
				
				TemplateArea.Parameters.Quantity = Quantity;
				
				SpreadsheetDocument.Put(TemplateArea);
				
				// increase totals on the page
				TotalQuantityOnPage = TotalQuantityOnPage + Quantity;
				
				// increase totals on the document
				TotalPlaces		= TotalPlaces			+ Places;
				TotalQuantity = TotalQuantity	+ Quantity;
			
			EndDo;
			
		EndIf;
		
		// Display totals on the last page
		TotalsAreaByPage = Template.GetArea("TotalByPage");
		TotalsAreaByPage.Parameters.TotalQuantityOnPage = TotalQuantityOnPage;
		TotalsAreaByPage.Parameters.TotalAmountOfWithVATOnPage  = TotalAmountOfWithVATOnPage;
		SpreadsheetDocument.Put(TotalsAreaByPage);
		
		// Display totals on the full document
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.TotalQuantity = TotalQuantity;
		TemplateArea.Parameters.TotalAmountWithVAT  = TotalAmountWithVAT;
		SpreadsheetDocument.Put(TemplateArea);
		
		// Display the footer of the document
		TemplateArea = Template.GetArea("Footer");
		
		ParameterValues = New Structure;
		
		SNPReleasePermitted = "";
		SmallBusinessServer.SurnameInitialsByName(SNPReleasePermitted, String(Header.Head));
		ParameterValues.Insert("SNPReleasePermitted", SNPReleasePermitted);
		ParameterValues.Insert("VacationApprovedPosition", Header.HeadPosition);
		
		ChiefAccountantNameAndSurname = "";
		SmallBusinessServer.SurnameInitialsByName(ChiefAccountantNameAndSurname, String(Header.ChiefAccountant));
		ParameterValues.Insert("ChiefAccountantNameAndSurname", ChiefAccountantNameAndSurname);
		
		SNPReleaseMade = "";
		SmallBusinessServer.SurnameInitialsByName(SNPReleaseMade, String(Header.Released));
		ParameterValues.Insert("SNPReleaseMade", SNPReleaseMade);
		ParameterValues.Insert("ReleaseMadePosition", Header.ReleasedPosition);
		
		ParameterValues.Insert("RecordsSequenceNumbersQuantityInWords", NumberInWords(LineQuantity, ,",,,,,,,,0"));
		ParameterValues.Insert("AmountReleasedInWords", WorkWithCurrencyRates.GenerateAmountInWords(TotalAmountWithVAT, Constants.NationalCurrency.Get()));
		ParameterValues.Insert("TotalPlacesInWords", NumberInWords(TotalPlaces, ,",,,,,,,,0"));
		ParameterValues.Insert("TotalDescriptions", NumberInWords(LineQuantity, ,",,,,,,,,0"));
		
		ParameterValues.Insert("PowerOfAttorneyNumber", Header.PowerOfAttorneyNumber);
		ParameterValues.Insert("PowerOfAttorneyDate", Format(Header.PowerOfAttorneyDate,"DF=MM/dd/yyyy"));
		ParameterValues.Insert("PowerOfAttorneyIssued", Header.PowerOfAttorneyIssued);
		ParameterValues.Insert("PowerAttorneyPerson", Header.PowerAttorneyPerson);
		
		TemplateArea.Parameters.Fill(ParameterValues);
		SpreadsheetDocument.Put(TemplateArea);
		
		SpreadsheetDocument.PutHorizontalPageBreak();
		
		// Display transport section
		TemplateArea = Template.GetArea("TransportSection");
		ParameterValues.Clear();
		
		ParameterValues.Insert("Number", DocumentNumber);
		ParameterValues.Insert("DeliveryTerm", Format(Header.DeliveryTerm, "DF=MM/dd/yyyy"));
		
		InformationAboutCarrier = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Carrier,  Header.DocumentDate);
		CarrierPresentation = SmallBusinessServer.CompaniesDescriptionFull(InformationAboutCarrier, "FullDescr, TIN, ActualAddress, PhoneNumbers, AccountNo, Bank, BIN, CorrAccount");
		ParameterValues.Insert("Carrier", CarrierPresentation);
		
		ParameterValues.Insert("VehicleBrand", Header.VehicleBrand);
		ParameterValues.Insert("VehicleRegistrationNo", Header.VehicleRegistrationNo);
		
		TransportCustomerPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr, TIN, ActualAddress, PhoneNumbers, AccountNo, Bank, BIN, CorrAccount");
		ParameterValues.Insert("TransportCustomer", TransportCustomerPresentation);
		
		If ValueIsFilled(Header.Driver) Then
			
			DriverInformation = SmallBusinessServer.IndData(Header.Company, Header.Driver, Header.DocumentDate, True);
			ParameterValues.Insert("Driver", DriverInformation.Presentation);
			
			IndividualsDocuments = Catalogs.Individuals.IndividualDocumentByType(Header.DocumentDate, Header.Driver, Catalogs.IndividualsDocumentsKinds.DriversLicense);
			If IndividualsDocuments.Count() > 0 Then
				
				DriversLicense = NStr("en = 'Series '") + String(IndividualsDocuments[0].Series) + NStr("en = ' No. '") + String(IndividualsDocuments[0].Number);
				ParameterValues.Insert("DriversLicense", DriversLicense);
				
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(Header.CurrentLicenseCard) Then
			
			LicenseCard = Header.CurrentLicenseCard.LicenseCardKind;
			ParameterValues.Insert("TransportationKind", Header.LicenseCardActivityKind);
			ParameterValues.Insert("LicenceCardRegistrationNo", Header.LicenceCardRegistrationNo);
			ParameterValues.Insert("LicenceCardSeries", Header.LicenceCardSeries);
			ParameterValues.Insert("LicenceCardNo", Header.LicenceCardNo);
			
		Else
			
			LicenseCard = "Standard";
			
		EndIf;
		
		StandardFont   = New Font(TemplateArea.Areas.Standard.Font, , , , , , LicenseCard = "Limited");
		FontLimited = New Font(TemplateArea.Areas.limited.Font, , , , , , Not LicenseCard = "Limited");
		
		TemplateArea.Areas.Standard.Font   = StandardFont;
		TemplateArea.Areas.limited.Font = FontLimited;
		
		ImportingPoint = "";
		ArrayOfOwners = New Array;
		ArrayOfOwners.Add(Header.StructuralUnit);
		Addresses = ContactInformationManagement.ContactInformationOfObjects(ArrayOfOwners, , Catalogs.ContactInformationTypes.StructuralUnitsActualAddress);
		If Addresses.Count() > 0 Then
			
			ImportingPoint = Addresses[0].Presentation;
			
		EndIf;
		
		PhoneNumbers = ContactInformationManagement.ContactInformationOfObjects(ArrayOfOwners, , Catalogs.ContactInformationTypes.StructuralUnitsPhone);
		If PhoneNumbers.Count() > 0 Then
			
			For Each Phone IN PhoneNumbers Do
				
				ImportingPoint = ImportingPoint + ?(IsBlankString(ImportingPoint), "", ", ") + Phone.Presentation;
				
			EndDo;
			
		EndIf;
		ParameterValues.Insert("ImportingPoint", ImportingPoint);
		
		DischargePoint = "";
		If Not IsBlankString(Header.ShippingAddress) Then
			
			DischargePoint = Header.ShippingAddress;
			
		EndIf;
		
		ArrayOfOwners.Clear();
		If TypeOf(CurrentDocument) <> Type("DocumentRef.InventoryTransfer") Then
			
			ArrayOfOwners.Add(Header.Customer);
			PhoneNumbersCounterparty = ContactInformationManagement.ContactInformationOfObjects(ArrayOfOwners, , Catalogs.ContactInformationTypes.CounterpartyPhone);
			
		Else
			
			ArrayOfOwners.Add(Header.Customer);
			PhoneNumbersCounterparty = ContactInformationManagement.ContactInformationOfObjects(ArrayOfOwners, , Catalogs.ContactInformationTypes.CompanyPhone);
			
		EndIf;
		
		If PhoneNumbersCounterparty.Count() > 0 Then
			
			For Each Phone IN PhoneNumbersCounterparty Do
				
				ImportingPoint = ImportingPoint + ?(IsBlankString(ImportingPoint), "", ", ") + Phone.Presentation;
				
			EndDo;
			
		EndIf;
		ParameterValues.Insert("DischargePoint", DischargePoint);
		
		ParameterValues.Insert("TrailerBrand", Header.TrailerBrand);
		ParameterValues.Insert("TrailerRegistrationNo", Header.TrailerRegistrationNo);
		
		TemplateArea.Parameters.Fill(ParameterValues);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("AdditionalInformationOnCargo");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("FooterInformationAboutCargo");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("ImportingOperations");
		SpreadsheetDocument.Put(TemplateArea);
		TemplateArea = Template.GetArea("OtherAdditionalInformation");
		SpreadsheetDocument.Put(TemplateArea);
		
		// Set the layout parameters
		SpreadsheetDocument.TopMargin = 0;
		SpreadsheetDocument.LeftMargin  = 0;
		SpreadsheetDocument.BottomMargin  = 0;
		SpreadsheetDocument.RightMargin = 0;
		SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// BoL printing procedure
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "BoL") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "BoL", "Customer invoice", PrintForm(ObjectsArray, PrintObjects, PrintParameters));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

#EndRegion

#EndIf