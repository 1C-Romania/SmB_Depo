#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInvoiceGenerated, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	SupplierInvoiceNoteInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	MIN(SupplierInvoiceNoteInventory.LineNumber) AS LineNumber,
	|	SupplierInvoiceNoteInventory.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SupplierInvoiceNoteInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SupplierInvoiceNoteInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	SUM(CASE
	|			WHEN VALUETYPE(SupplierInvoiceNoteInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN SupplierInvoiceNoteInventory.Quantity
	|			ELSE SupplierInvoiceNoteInventory.Quantity * SupplierInvoiceNoteInventory.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	SupplierInvoiceNoteInventory.CountryOfOrigin,
	|	SupplierInvoiceNoteInventory.CCDNo
	|FROM
	|	Document.SupplierInvoiceNote.Inventory AS SupplierInvoiceNoteInventory
	|WHERE
	|	SupplierInvoiceNoteInventory.CCDNo <> VALUE(Catalog.CCDNumbers.EmptyRef)
	|	AND SupplierInvoiceNoteInventory.CountryOfOrigin <> VALUE(Catalog.WorldCountries.EmptyRef)
	|	AND SupplierInvoiceNoteInventory.Ref = &Ref
	|	AND SupplierInvoiceNoteInventory.Ref.OperationKind = VALUE(Enum.OperationKindsSupplierInvoiceNote.Receipt)
	|
	|GROUP BY
	|	SupplierInvoiceNoteInventory.CountryOfOrigin,
	|	SupplierInvoiceNoteInventory.CCDNo,
	|	SupplierInvoiceNoteInventory.ProductsAndServices,
	|	SupplierInvoiceNoteInventory.Ref.Date,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SupplierInvoiceNoteInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SupplierInvoiceNoteInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END");
	
	Query.SetParameter("Ref"							, DocumentRefInvoiceGenerated);
	Query.SetParameter("Company"						, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime"					, StructureAdditionalProperties.ForPosting.PointInTime);
	Query.SetParameter("UseCharacteristics"   	, StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches"				, StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryByCCD", ResultsArray[0].Unload());
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInvoiceGenerated, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary table
	// "RegisterRecordsInventoryInCCDChange" contains entries, execute the control of incoming products.
	
	If StructureTemporaryTables.RegisterRecordsInventoryByCCDChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryByCCDChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.CCDNo) AS CCDNoPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.CountryOfOrigin) AS CountryOfOriginPresentation,
		|	REFPRESENTATION(InventoryByCCDBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryByCCDChange.QuantityChange, 0) + ISNULL(InventoryByCCDBalances.QuantityBalance, 0) AS BalanceInventoryByCCD,
		|	ISNULL(InventoryByCCDBalances.QuantityBalance, 0) AS QuantityBalanceInventoryByCCD
		|FROM
		|	RegisterRecordsInventoryByCCDChange AS RegisterRecordsInventoryByCCDChange
		|		LEFT JOIN AccumulationRegister.InventoryByCCD.Balance(
		|				&ControlTime,
		|				(Company, CCDNo, ProductsAndServices, Characteristic, Batch, CountryOfOrigin) In
		|					(SELECT
		|						RegisterRecordsInventoryByCCDChange.Company AS Company,
		|						RegisterRecordsInventoryByCCDChange.CCDNo AS CCDNo,
		|						RegisterRecordsInventoryByCCDChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryByCCDChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryByCCDChange.Batch AS Batch,
		|						RegisterRecordsInventoryByCCDChange.CountryOfOrigin AS CountryOfOrigin
		|					FROM
		|						RegisterRecordsInventoryByCCDChange AS RegisterRecordsInventoryByCCDChange)) AS InventoryByCCDBalances
		|		ON RegisterRecordsInventoryByCCDChange.Company = InventoryByCCDBalances.Company
		|			AND RegisterRecordsInventoryByCCDChange.CCDNo = InventoryByCCDBalances.CCDNo
		|			AND RegisterRecordsInventoryByCCDChange.ProductsAndServices = InventoryByCCDBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryByCCDChange.Characteristic = InventoryByCCDBalances.Characteristic
		|			AND RegisterRecordsInventoryByCCDChange.Batch = InventoryByCCDBalances.Batch
		|			AND RegisterRecordsInventoryByCCDChange.CountryOfOrigin = InventoryByCCDBalances.CountryOfOrigin
		|WHERE
		|	ISNULL(InventoryByCCDBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		// Negative balance of inventory by CCD accounting.
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			DocumentObjectSupplierInvoiceNote = DocumentRefInvoiceGenerated.GetObject();
			QueryResultSelection = QueryResult.Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryByCCDRegisterErrors(DocumentObjectSupplierInvoiceNote, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Document printing procedure.
//
Function PrintForm(ObjectsArray, PrintObjects) Export
	
	CustomerInvoiceNote1137UsageBegin = Constants.CustomerInvoiceNote1137UsageBegin.Get();
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ReceivedInvoice";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoiceNote.Date AS DocumentDate,
	|	SupplierInvoiceNote.IncomingDocumentDate AS IncomingDocumentDate,
	|	SupplierInvoiceNote.Number AS Number,
	|	SupplierInvoiceNote.Counterparty AS Vendor,
	|	SupplierInvoiceNote.Company AS Customer,
	|	SupplierInvoiceNote.Company AS Payer,
	|	SupplierInvoiceNote.Company.Prefix AS Prefix,
	|	SupplierInvoiceNote.Contract.Presentation AS Basis,
	|	SupplierInvoiceNote.DocumentCurrency AS Currency,
	|	ISNULL(SupplierInvoiceNote.Contract.SettlementsInStandardUnits, FALSE) AS SettlementsInStandardUnits,
	|	SupplierInvoiceNote.PaymentAccountingDocumentDate AS DatePRD,
	|	SupplierInvoiceNote.PaymentAccountingDocumentNumber AS NumberPRD,
	|	SupplierInvoiceNote.OperationKind,
	|	SupplierInvoiceNote.Company AS Head,
	|	SupplierInvoiceNote.BasisDocument AS BasisDocument,
	|	SupplierInvoiceNote.Ref AS Ref,
	|	SupplierInvoiceNote.Multiplicity,
	|	SupplierInvoiceNote.ExchangeRate,
	|	SupplierInvoiceNote.IncomingDocumentNumber,
	|	SupplierInvoiceNote.IncomingDocumentDate
	|FROM
	|	Document.SupplierInvoiceNote AS SupplierInvoiceNote
	|WHERE
	|	SupplierInvoiceNote.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	Ref";
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	
	While Header.Next() Do
		
		If Header.IncomingDocumentDate >= '20150101'
			AND TypeOf(Header.BasisDocument) = Type("DocumentRef.ReportToPrincipal") 
			AND Header.Ref.InvoiceNotesIssuedToCustomers.Count() > 0 Then
			
			Template = PrintManagement.PrintedFormsTemplate("Document.SupplierInvoiceNote.PF_MXL_CustomerInvoiceNote1137");
			AreaClarification = Template.GetArea("ConsolidatedCommission");
			
			AreaClarification.Parameters.Fill(New Structure("Clarification", NStr("en='You can not generate received (incoming) customer invoice note based on the report to principal by the summary data (several customers).';ru='Формирование полученного (входящего) счета-фактуры на основании отчета комитенту по сводным данным (несколько покупателей) не поддерживается.'")));
			SpreadsheetDocument.Put(AreaClarification);
			
			Return SpreadsheetDocument;
			
		EndIf;
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If Header.DocumentDate < '20090609' Then
			
			SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_SupplierInvoiceNote_Invoice283";
			Template = PrintManagement.PrintedFormsTemplate("Document.SupplierInvoiceNote.PF_MXL_Invoice283");
			
		ElsIf Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_Invoice_Invoice283";
			Template = PrintManagement.PrintedFormsTemplate("Document.SupplierInvoiceNote.PF_MXL_CustomerInvoiceNote1137");
			
		Else

			SpreadsheetDocument.PrintParametersKey = "PARAMETERS_PRINT_ReceivedInvoice_Invoice451";
			Template = PrintManagement.PrintedFormsTemplate("Document.SupplierInvoiceNote.PF_MXL_Invoice451");

		EndIf;
		
		InfoAboutCustomer = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Customer, Header.DocumentDate, ,);
		InfoAboutVendor  = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Vendor, Header.DocumentDate, ,);
		
		UseConversion = Header.SettlementsInStandardUnits AND Not Header.Currency = Constants.NationalCurrency.Get();
		
		If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			TemplateArea = Template.GetArea("HeaderInformation");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		// Displaying invoice header
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		
		TemplateArea.Parameters.Number = "Invoice # " + Header.IncomingDocumentNumber
				+ " dated " + Format(Header.IncomingDocumentDate, "DF=dd MMMM yyyy'")+ " g.";
				
		If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			TemplateArea.Parameters.CorrectionNumber = "Correction # -- dated --";
			
		EndIf;
		
		If Header.DocumentDate < '20090609' Then
			
			TemplateArea.Parameters.VendorPresentation = "Seller: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,");
			
		ElsIf Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			TemplateArea.Parameters.VendorPresentation = "Seller: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,");
			
		Else
			
			TemplateArea.Parameters.VendorPresentation = "Seller: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,") + 
																	" (" + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "Presentation,") + ")";
																	
		EndIf;
		
		TemplateArea.Parameters.VendorAddress = "Address: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "LegalAddress,");
		
		If IsBlankString(Header.NumberPRD) OR IsBlankString(Header.DatePRD) Then
			
			If Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance
				OR Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance Then
				
				TemplateArea.Parameters.ByDocument = "To payment and settlement document # -- dated --";
				
			Else
				
				TemplateArea.Parameters.ByDocument = "To payment and settlement document # dated";
				
			EndIf; 
			
		Else 
			
			TemplateArea.Parameters.ByDocument				= "To payment and settlement document # " + Header.NumberPRD + " dated " + Format(Header.DatePRD, "DF=dd.MM.yyyy");
			
		EndIf; 
		
		TemplateArea.Parameters.CustomerPresentation = "Customer: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr,");
		
		CustomerAddressValue = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "LegalAddress,");
		
		TemplateArea.Parameters.CustomerAddress = "Address: "; 
		If IsBlankString(CustomerAddressValue) 
			AND Header.OperationKind <> Enums.OperationKindsSupplierInvoiceNote.Advance Then
				
				TemplateArea.Parameters.CustomerAddress = "Address: --"; 
				
		Else
			
			TemplateArea.Parameters.CustomerAddress = TemplateArea.Parameters.CustomerAddress + CustomerAddressValue;
			
		EndIf;
		
		If Header.OperationKind <> Enums.OperationKindsSupplierInvoiceNote.Advance Then
			
			TemplateArea.Parameters.PresentationOfShipper = "Consignor and its address: the same";
			TemplateArea.Parameters.PresentationOfConsignee  = "Consignee and its address: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr,ActualAddress,");
			
		Else
			
			TemplateArea.Parameters.PresentationOfShipper = "Consignor and their address: --";
			TemplateArea.Parameters.PresentationOfConsignee  = "Consignee and their address: --";
			
		EndIf;
			
		KPP = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "KPP,", False);
		If ValueIsFilled(KPP) Then
			KPP = "/" + KPP;
		EndIf;
		TemplateArea.Parameters.VendorTIN = "TIN/KPP seller: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "TIN,", False) + KPP;
		
		KPP = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "KPP,", False);
		If ValueIsFilled(KPP) Then 
			KPP = "/" + KPP;
		EndIf;
		TemplateArea.Parameters.TINOfHBuyer = "TIN/KPP customer: " + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "TIN,", False) + KPP;
		
		If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			If Not ValueIsFilled(Header.Currency) 
				OR UseConversion Then
				
				TemplateArea.Parameters.Currency = "Currency: name, Russian ruble code,643 ";
				
			Else
				
				TemplateArea.Parameters.Currency = "Currency: name, code " + TrimAll(Header.Currency.DescriptionFull) + ", " + TrimAll(Header.Currency.Code) + "";
				
			EndIf;
			
		EndIf;
		
		If Not Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			PutDashesToEmptyFields(TemplateArea);
			
		EndIf;
		

		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("TableTitle");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("String");
		
		TotalCost	= 0;
		TotalVATAmount	= 0;
		SubtotalTotal		= 0;
		
		Query = New Query;
		Query.SetParameter("Ref", Header.Ref);

		Query.Text =

		"SELECT
		|	1 AS ID,
		|	NestedSelect.LineNumber AS LineNumber,
		|	CASE
		|		WHEN (CAST(NestedSelect.ProductsAndServices.DescriptionFull AS String(1000))) = """"
		|			THEN NestedSelect.ProductsAndServices.Description
		|		ELSE CAST(NestedSelect.ProductsAndServices.DescriptionFull AS String(1000))
		|	END AS ProductDescription,
		|	NestedSelect.ProductsAndServices AS ProductsAndServices,
		|	NestedSelect.ProductsAndServices.SKU AS SKU,
		|	NestedSelect.Characteristic AS Characteristic,
		|	NestedSelect.MeasurementUnitForPrint.Code AS MeasurementUnitCode,
		|	NestedSelect.MeasurementUnitForPrint AS MeasurementUnit,
		|	NestedSelect.MeasurementUnitCoefficient AS MeasurementUnitCoefficient,
		|	NestedSelect.Quantity,
		|	""no excise"" AS Excise,
		|	&AmountWithoutVAT_Parameter AS AmountWithoutVAT,
		|	NestedSelect.VATRate,
		|	&VATAmount_Parameter AS VATAmount,
		|	&Price_Parameter AS Price,
		|	&Total_Parameter AS Total,
		|	NestedSelect.CCDNo AS CCDPresentation,
		|	NestedSelect.CountryPresentation,
		|	NestedSelect.CountryOfOriginCode AS CountryOfOriginCode,
		|	NestedSelect.Content
		|FROM
		|	(SELECT
		|		MIN(SupplierInvoiceNoteInventory.LineNumber) AS LineNumber,
		|		SupplierInvoiceNoteInventory.ProductsAndServices AS ProductsAndServices,
		|		SupplierInvoiceNoteInventory.Characteristic AS Characteristic,
		|		SupplierInvoiceNoteInventory.ProductsAndServices.MeasurementUnit AS MeasurementUnitForPrint,
		|		SupplierInvoiceNoteInventory.MeasurementUnit AS MeasurementUnitCoefficient,
		|		SupplierInvoiceNoteInventory.Price AS Price,
		|		SUM(SupplierInvoiceNoteInventory.Quantity) AS Quantity,
		|		SUM(SupplierInvoiceNoteInventory.Amount) AS AmountWithoutVAT,
		|		SupplierInvoiceNoteInventory.VATRate AS VATRate,
		|		SUM(SupplierInvoiceNoteInventory.VATAmount) AS VATAmount,
		|		SUM(SupplierInvoiceNoteInventory.Total) AS Total,
		|		SupplierInvoiceNoteInventory.CCDNo AS CCDNo,
		|		SupplierInvoiceNoteInventory.CountryOfOrigin.Presentation AS CountryPresentation,
		|		SupplierInvoiceNoteInventory.CountryOfOrigin.Code AS CountryOfOriginCode,
		|		CAST(SupplierInvoiceNoteInventory.Content AS String(1000)) AS Content
		|	FROM
		|		Document.SupplierInvoiceNote.Inventory AS SupplierInvoiceNoteInventory
		|	WHERE
		|		SupplierInvoiceNoteInventory.Ref = &Ref
		|	
		|	GROUP BY
		|		SupplierInvoiceNoteInventory.CCDNo,
		|		SupplierInvoiceNoteInventory.MeasurementUnit,
		|		SupplierInvoiceNoteInventory.ProductsAndServices,
		|		SupplierInvoiceNoteInventory.Characteristic,
		|		CAST(SupplierInvoiceNoteInventory.Content AS String(1000)),
		|		SupplierInvoiceNoteInventory.VATRate,
		|		SupplierInvoiceNoteInventory.Price,
		|		SupplierInvoiceNoteInventory.CountryOfOrigin.Presentation,
		|		SupplierInvoiceNoteInventory.CountryOfOrigin.Code,
		|		SupplierInvoiceNoteInventory.ProductsAndServices.MeasurementUnit) AS NestedSelect
		|
		|ORDER BY
		|	ID,
		|	LineNumber";
		
		If UseConversion Then
			
			Query.Text = StrReplace(Query.Text, "&Price_Parameter",			"CAST(NestedSelect.Price * &ExchangeRate / &Multiplicity AS Number(15,2))");
			Query.Text = StrReplace(Query.Text, "&AmountWithoutVAT_Parameter",	"CAST(NestedSelect.AmountWithoutVAT * &ExchangeRate / &Multiplicity AS Number(15,2))");
			Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter",		"CAST(NestedSelect.VATAmount * &ExchangeRate / &Multiplicity AS Number(15,2))");
			Query.Text = StrReplace(Query.Text, "&Total_Parameter",			"CAST(NestedSelect.Total * &ExchangeRate / &Multiplicity AS Number(15,2))");
			
			Query.SetParameter("ExchangeRate",		Header.ExchangeRate);
			Query.SetParameter("Multiplicity",	Header.Multiplicity);
			
		Else
			
			Query.Text = StrReplace(Query.Text, "&Price_Parameter", 			"NestedSelect.Price");
			Query.Text = StrReplace(Query.Text, "&AmountWithoutVAT_Parameter",	"NestedSelect.AmountWithoutVAT");
			Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter", 		"NestedSelect.VATAmount");
			Query.Text = StrReplace(Query.Text, "&Total_Parameter", 		"NestedSelect.Total");
			
		EndIf;
		
		If  Header.OperationKind = Enums.OperationKindsSupplierInvoiceNote.AccrualDifferences Then
			
			TableByProducts = Query.Execute().Unload();
			
			TemplateArea.Parameters.ProductDescription = "Amounts connected with calculations on settlements (art. 162 TC RF)";
			
			If TableByProducts.Count() > 0 Then
			
				TemplateArea.Parameters.VATRate = TableByProducts[0].VATRate;
				TemplateArea.Parameters.VATAmount = TableByProducts[0].VATAmount;
				TemplateArea.Parameters.Total = TableByProducts[0].Total;
				
				TotalCost	= 0;
				TotalVATAmount	= TableByProducts[0].VATAmount;
				SubtotalTotal		= TableByProducts[0].Total;
				
			EndIf;
			
			PutDashesToEmptyFields(TemplateArea);
			SpreadsheetDocument.Put(TemplateArea);
			
		ElsIf  Header.OperationKind = Enums.OperationKindsSupplierInvoiceNote.Receipt Then 
			
			TableByProducts = Query.Execute().Unload();
			
			For Each Row IN TableByProducts Do
				TemplateArea.Parameters.Fill(Row);
				
				If ValueIsFilled(Row.Content) Then
					TemplateArea.Parameters.ProductDescription = Row.Content;
				Else
					TemplateArea.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(Row.ProductDescription, 
																Row.Characteristic, Row.SKU);
				EndIf;
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin
					AND Not ValueIsFilled(TemplateArea.Parameters.MeasurementUnitCode) Then
					
					TemplateArea.Parameters.MeasurementUnitCode = "--";
					
				EndIf;
				
				If Not ValueIsFilled(TemplateArea.Parameters.MeasurementUnit) Then
					
					TemplateArea.Parameters.MeasurementUnit = "--";
					
				EndIf;
				
				If Not Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					TemplateArea.Parameters.Excise = "--";
					
				EndIf;
				
				Factor = 1;
				If TypeOf(Row.MeasurementUnitCoefficient) = Type("CatalogRef.UOM") Then
					
					Factor = Row.MeasurementUnitCoefficient.Factor;
					
				EndIf;
				
				Quantity  = Row.Quantity * Factor;
				
				TemplateArea.Parameters.Quantity = Quantity;
				If Row.Price <> 0 Then
					TemplateArea.Parameters.Price = ?(Quantity = 0, 0, Row.AmountWithoutVAT / Quantity);
				Else
					TemplateArea.Parameters.Price = Row.Price * Factor;
				EndIf;
				
				TemplateArea.Parameters.Cost = Row.AmountWithoutVAT;
					
				TemplateArea.Parameters.Total = Row.Total;
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					If Upper(Row.VATRate) = "WITHOUT VAT" Then
						
						TemplateArea.Parameters.VATRate	= "Without VAT";
						TemplateArea.Parameters.VATAmount	= "Without VAT";
						
					Else
						
						TemplateArea.Parameters.VATRate	= Row.VATRate;
						TemplateArea.Parameters.VATAmount = Row.VATAmount;
						
					EndIf;
					
				Else
					
					TemplateArea.Parameters.VATRate = Row.VATRate;
					
				EndIf;
				
				TotalCost	= TotalCost + Row.AmountWithoutVAT;
				TotalVATAmount	= TotalVATAmount + Row.VATAmount;
				SubtotalTotal		= SubtotalTotal + Row.Total;
				
				If Not Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					PutDashesToEmptyFields(TemplateArea);
					
				Else
					
					If String(Row.CountryPresentation) = "Russia"
						OR IsBlankString(Row.CountryPresentation) Then
						
						TemplateArea.Parameters.CountryPresentation = "--";
						TemplateArea.Parameters.CountryOfOriginCode = "--";
						
					EndIf;
					
					If IsBlankString(Row.CCDPresentation) Then
						
						TemplateArea.Parameters.CCDPresentation = "--";
						
					EndIf;
					
				EndIf;
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo; 
			
		ElsIf  Header.OperationKind = Enums.OperationKindsSupplierInvoiceNote.Advance Then 
			
			Query.Text =
			
			"SELECT
			|	1 AS ID,
			|	NestedSelect.LineNumber AS LineNumber,
			|	NestedSelect.ProductsAndServices.DescriptionFull AS ProductDescription,
			|	NestedSelect.ProductsAndServices.SKU AS SKU,
			|	NestedSelect.ProductsAndServices AS ProductsAndServices,
			|	NestedSelect.Characteristic AS Characteristic,
			|	""no excise"" AS Excise,
			|	&AmountWithoutVAT_Parameter AS AmountWithoutVAT,
			|	NestedSelect.VATRate,
			|	&VATAmount_Parameter AS VATAmount,
			|	&Total_Parameter AS Total,
			|	NestedSelect.Content
			|FROM
			|	(SELECT
			|		MIN(SupplierInvoiceNoteInventory.LineNumber) AS LineNumber,
			|		SupplierInvoiceNoteInventory.ProductsAndServices AS ProductsAndServices,
			|		SupplierInvoiceNoteInventory.Characteristic AS Characteristic,
			|		SUM(SupplierInvoiceNoteInventory.Amount) AS AmountWithoutVAT,
			|		SupplierInvoiceNoteInventory.VATRate AS VATRate,
			|		SUM(SupplierInvoiceNoteInventory.VATAmount) AS VATAmount,
			|		SUM(SupplierInvoiceNoteInventory.Total) AS Total,
			|		CAST(SupplierInvoiceNoteInventory.Content AS String(1000)) AS Content
			|	FROM
			|		Document.SupplierInvoiceNote.Inventory AS SupplierInvoiceNoteInventory
			|	WHERE
			|		SupplierInvoiceNoteInventory.Ref = &Ref
			|	
			|	GROUP BY
			|		SupplierInvoiceNoteInventory.ProductsAndServices,
			|		SupplierInvoiceNoteInventory.Characteristic,
			|		SupplierInvoiceNoteInventory.VATRate,
			|		CAST(SupplierInvoiceNoteInventory.Content AS String(1000))) AS NestedSelect
			|
			|ORDER BY
			|	ID,
			|	LineNumber";
			
			If UseConversion Then
				
				Query.Text = StrReplace(Query.Text, "&AmountWithoutVAT_Parameter",	"CAST(NestedSelect.AmountWithoutVAT * &ExchangeRate / &Multiplicity AS Number(15,2))");
				Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter",		"CAST(NestedSelect.VATAmount * &ExchangeRate / &Multiplicity AS Number(15,2))");
				Query.Text = StrReplace(Query.Text, "&Total_Parameter",			"CAST(NestedSelect.Total * &ExchangeRate / &Multiplicity AS Number(15,2))");
				
				Query.SetParameter("ExchangeRate",		Header.ExchangeRate);
				Query.SetParameter("Multiplicity",	Header.Multiplicity);
				
			Else
				
				Query.Text = StrReplace(Query.Text, "&AmountWithoutVAT_Parameter", 	"NestedSelect.AmountWithoutVAT");
				Query.Text = StrReplace(Query.Text, "&VATAmount_Parameter", 	"	NestedSelect.VATAmount");
				Query.Text = StrReplace(Query.Text, "&Total_Parameter", 		"NestedSelect.Total");
				
			EndIf;
			
			TableByProducts = Query.Execute().Unload();
			
			For Each Row IN TableByProducts Do

				If ValueIsFilled(Row.Content) Then
					
					TemplateArea.Parameters.ProductDescription = Row.Content;
					
				Else
					
					TemplateArea.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(Row.ProductDescription, 
																		Row.Characteristic, Row.SKU);
																		
 				EndIf; 
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					TemplateArea.Parameters.MeasurementUnitCode = "--";
					TemplateArea.Parameters.CountryPresentation = "--";
					TemplateArea.Parameters.CountryOfOriginCode = "--";
					TemplateArea.Parameters.CCDPresentation = "--";
					
				EndIf;
				
				TemplateArea.Parameters.MeasurementUnit 	= "--";
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					TemplateArea.Parameters.Excise = Row.Excise;
					
				Else
					
					TemplateArea.Parameters.Excise = "--";
					
				EndIf;
				
				TemplateArea.Parameters.Total = Row.Total;
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					If Upper(Row.VATRate) = "WITHOUT VAT" Then
						
						TemplateArea.Parameters.VATRate	= "Without VAT";
						TemplateArea.Parameters.VATAmount	= "Without VAT";
						
					Else
						
						TemplateArea.Parameters.VATRate	= Row.VATRate;
						TemplateArea.Parameters.VATAmount = Row.VATAmount;
						
					EndIf;
					
				Else
					
					TemplateArea.Parameters.VATRate = Row.VATRate;
					TemplateArea.Parameters.VATAmount = Row.VATAmount;
					
				EndIf;
				
				TotalVATAmount = TotalVATAmount + Row.VATAmount;
				SubtotalTotal = SubtotalTotal + Row.Total;
				
				If Not Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					PutDashesToEmptyFields(TemplateArea);
					
				EndIf;
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
		EndIf;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.TotalVATAmount = TotalVATAmount;
		TemplateArea.Parameters.SubtotalTotal = SubtotalTotal;
		
		If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			TemplateArea.Parameters.TotalCost	= ?(TotalCost = 0, "--", TotalCost);
			
		Else
			
			PutDashesToEmptyFields(TemplateArea);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Footer");
		
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Head, Header.DocumentDate);
		
		TemplateArea.Parameters.Fill(Heads);
		
		If Not Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			PutDashesToEmptyFields(TemplateArea);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Procedure puts dashes into empty fields.
//
Procedure PutDashesToEmptyFields(TemplateArea)

	For t = 0 To TemplateArea.Parameters.Count() - 1 Do
		
		CurParameter = TemplateArea.Parameters.Get(t);
		
		If (Find(CurParameter, "Seller:") <> 0)
		   and (TrimAll(CurParameter) = "Seller:") Then
			TemplateArea.Parameters.Set(t, "Salesperson: ----");
			
		ElsIf (Find(CurParameter, "Address:") <> 0)
			    and (TrimAll(CurParameter) = "Address:") Then
			TemplateArea.Parameters.Set(t, "Address: ----");
			
		ElsIf (Find(CurParameter, "Seller identification number (TIN):") <> 0)
			    and (TrimAll(CurParameter) = "Seller identification number (TIN):") Then
			TemplateArea.Parameters.Set(t, "Seller identification number (TIN): ----");
			
		ElsIf (Find(CurParameter, "Consignor and its address:") <> 0)
			    and (TrimAll(CurParameter) = "Consignor and its address:") Then
			TemplateArea.Parameters.Set(t, "Consignor and its address: ----");
			
		ElsIf (Find(CurParameter, "Consignee and its address:") <> 0)
		   		and (TrimAll(CurParameter) = "Consignee and its address:") Then
			TemplateArea.Parameters.Set(t, "Consignee and its address: ----");
			
		ElsIf (Find(CurParameter, "To payment and settlement document #") <> 0)
		   		and (TrimAll(CurParameter) = "To payment and settlement document # from") Then
			TemplateArea.Parameters.Set(t, "To payment and settlement document # -- from --");
			
		ElsIf (Find(CurParameter, "Customer:") <> 0)
		   		and (TrimAll(CurParameter) = "Customer:") Then
			TemplateArea.Parameters.Set(t, "Customer: ----");
			
		ElsIf (Find(CurParameter, "Customer identification number (TIN):") <> 0)
			    and (TrimAll(CurParameter) = "Customer identification number (TIN):") Then
			TemplateArea.Parameters.Set(t, "Customer identification number (TIN): ----");
			
		ElsIf Not ValueIsFilled(CurParameter) Then
			TemplateArea.Parameters.Set(t, "--");
			
		EndIf;
		
	EndDo;
	
EndProcedure // PutDashesToEmptyFields()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CustomerInvoiceNoteIncoming") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CustomerInvoiceNoteIncoming", "Customer invoice note (incoming)", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "CustomerInvoiceNoteIncoming";
	PrintCommand.Presentation = NStr("en='Supplier invoice note';ru='Счет-фактура (полученный)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf