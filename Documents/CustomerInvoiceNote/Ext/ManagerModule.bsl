#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInvoice, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	InvoiceInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	MIN(InvoiceInventory.LineNumber) AS LineNumber,
	|	InvoiceInventory.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	SUM(CASE
	|			WHEN VALUETYPE(InvoiceInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN InvoiceInventory.Quantity
	|			ELSE InvoiceInventory.Quantity * InvoiceInventory.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	InvoiceInventory.CountryOfOrigin,
	|	InvoiceInventory.CCDNo
	|FROM
	|	Document.CustomerInvoiceNote.Inventory AS InvoiceInventory
	|WHERE
	|	InvoiceInventory.CCDNo <> VALUE(Catalog.CCDNumbers.EmptyRef)
	|	AND InvoiceInventory.Ref = &Ref
	|	AND InvoiceInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerInvoiceNote.Sale)
	|
	|GROUP BY
	|	InvoiceInventory.CountryOfOrigin,
	|	InvoiceInventory.CCDNo,
	|	InvoiceInventory.ProductsAndServices,
	|	InvoiceInventory.Ref.Date,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END");
	
	Query.SetParameter("Ref"							, DocumentRefInvoice);
	Query.SetParameter("Company"						, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime"					, StructureAdditionalProperties.ForPosting.PointInTime);
	Query.SetParameter("UseCharacteristics"   	, StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches"				, StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryByCCD", ResultsArray[0].Unload());
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInvoice, AdditionalProperties, Cancel, PostingDelete = False) Export
	
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
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Company) AS Company,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.ProductsAndServices) AS ProductsAndServices,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.CCDNo) AS CCDNo,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Characteristic) AS Characteristic,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.Batch) AS Batch,
		|	REFPRESENTATION(RegisterRecordsInventoryByCCDChange.CountryOfOrigin) AS CountryOfOrigin,
		|	ISNULL(InventoryByCCDBalances.QuantityBalance, 0) AS QuantityBalanceInventoryByCCD
		|FROM
		|	RegisterRecordsInventoryByCCDChange AS RegisterRecordsInventoryByCCDChange
		|		LEFT JOIN AccumulationRegister.InventoryByCCD.Balance(
		|				&ControlTime,
		|				(Company, ProductsAndServices, CCDNo, Characteristic, Batch, CountryOfOrigin) In
		|					(SELECT
		|						RegisterRecordsInventoryByCCDChange.Company AS Company,
		|						RegisterRecordsInventoryByCCDChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryByCCDChange.CCDNo AS CCDNo,
		|						RegisterRecordsInventoryByCCDChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryByCCDChange.Batch AS Batch,
		|						RegisterRecordsInventoryByCCDChange.CountryOfOrigin AS CountryOfOrigin
		|					FROM
		|						RegisterRecordsInventoryByCCDChange AS RegisterRecordsInventoryByCCDChange)) AS InventoryByCCDBalances
		|		ON RegisterRecordsInventoryByCCDChange.Company = InventoryByCCDBalances.Company
		|			AND RegisterRecordsInventoryByCCDChange.ProductsAndServices = InventoryByCCDBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryByCCDChange.CCDNo = InventoryByCCDBalances.CCDNo
		|			AND RegisterRecordsInventoryByCCDChange.Characteristic = InventoryByCCDBalances.Characteristic
		|			AND RegisterRecordsInventoryByCCDChange.Batch = InventoryByCCDBalances.Batch
		|			AND RegisterRecordsInventoryByCCDChange.CountryOfOrigin = InventoryByCCDBalances.CountryOfOrigin
		|WHERE
		|	ISNULL(InventoryByCCDBalances.QuantityBalance, 0) < 0");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		// Negative balance of inventory by CCD accounting.
		QueryResultSelection = Query.Execute().Select();
		While QueryResultSelection.Next() Do
			
			PresentationProductsAndServicesText = SmallBusinessServer.PresentationOfProductsAndServices(QueryResultSelection.ProductsAndServices,
				QueryResultSelection.Characteristic, 
				QueryResultSelection.Batch);

            If ValueIsFilled(QueryResultSelection.CCDNo)Then
				PresentationProductsAndServicesText = PresentationProductsAndServicesText + " | """ + TrimAll(QueryResultSelection.CCDNo) + """";
			EndIf;
			
			If ValueIsFilled(QueryResultSelection.CountryOfOrigin)Then
				PresentationProductsAndServicesText = PresentationProductsAndServicesText + " | """ + TrimAll(QueryResultSelection.CountryOfOrigin) + """";
			EndIf;

			MessageText = NStr("en='%ProductsAndServicesPresentationText% - negative balance of inventories in CCD accounting."
"Inventory balance by CCD accounting (number): %BalanceQuantity%.';ru='%ПредставлениеНоменклатурыТекст% - отрицательный остаток запасов в разрезе ГТД."
"Остаток запасов в разрезе ГТД (количество): %КоличествоОстаток%.'");
			MessageText = StrReplace(MessageText, "%%ProductsAndServicesPresentationText%", PresentationProductsAndServicesText);
			MessageText = StrReplace(MessageText, "%BalanceQuantity%", QueryResultSelection.QuantityBalanceInventoryByCCD);
								
			SmallBusinessServer.ShowMessageAboutError(DocumentRefInvoice.GetObject(), MessageText, Undefined, Undefined, "", Cancel);
			
		EndDo;
		
	EndIf;
		
EndProcedure

#EndRegion

#Region PrintInterface

// Function determines the absense of inventories in the invoice
//
Function IsInventory(Document)
	
	Query = New Query(
	"SELECT
	|	SUM(1) AS CountInventory
	|FROM
	|	Document.CustomerInvoiceNote.Inventory AS Inventory
	|WHERE
	|	Inventory.Ref = &Document
	|	AND Inventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)");
	
	Query.SetParameter("Document", Document);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Return False;
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		Return ?(Selection.CountInventory = NULL, False, Selection.CountInventory > 0);
		
	EndIf;
	
EndFunction // ThereIsStock()

// Document printing procedure.
//
Function PrintForm(ObjectsArray, PrintObjects, ItIsUniversalTransferDocument) Export
	Var Errors;
	
	CustomerInvoiceNote1137UsageBegin = Constants.CustomerInvoiceNote1137UsageBegin.Get();
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CustomerInvoiceNote.Date AS DocumentDate,
	|	CustomerInvoiceNote.Number AS Number,
	|	CustomerInvoiceNote.Counterparty AS Customer,
	|	CustomerInvoiceNote.Company AS Vendor,
	|	CustomerInvoiceNote.Company.Prefix AS Prefix,
	|	CustomerInvoiceNote.Counterparty AS Payer,
	|	CustomerInvoiceNote.Consignor AS Consignor,
	|	CustomerInvoiceNote.Consignee AS Consignee,
	|	CustomerInvoiceNote.Same,
	|	CASE
	|		WHEN CustomerInvoiceNote.StampBase = """"
	|			THEN CustomerInvoiceNote.Contract.Presentation
	|		ELSE CustomerInvoiceNote.StampBase
	|	END AS Basis,
	|	CustomerInvoiceNote.DocumentCurrency AS Currency,
	|	CustomerInvoiceNote.OperationKind AS OperationKind,
	|	CustomerInvoiceNote.Company AS Head,
	|	CustomerInvoiceNote.Ref AS Ref,
	|	1 AS StatusOfUPD,
	|	""Correction No -- from --"" AS CorrectionNumber,
	|	ISNULL(CustomerInvoiceNote.Contract.SettlementsInStandardUnits, FALSE) AS SettlementsInStandardUnits,
	|	CustomerInvoiceNote.PaymentDocumentsDateNumber.(
	|		Ref,
	|		LineNumber,
	|		PaymentAccountingDocumentDate,
	|		PaymentAccountingDocumentNumber
	|	),
	|	CustomerInvoiceNote.Multiplicity,
	|	CustomerInvoiceNote.ExchangeRate,
	|	CustomerInvoiceNote.BasisDocument AS BasisDocument,
	|	CustomerInvoiceNote.BasisDocuments.(
	|		BasisDocument
	|	) AS BasisDocuments
	|FROM
	|	Document.CustomerInvoiceNote AS CustomerInvoiceNote
	|WHERE
	|	CustomerInvoiceNote.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	Ref";
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	
	While Header.Next() Do
		
		If ItIsUniversalTransferDocument 
			AND Header.DocumentDate < Date('20130101') Then 
			
			MessageText = NStr("en='__________________"
"Printing of the universal transmission document is available from January 1, 2013. "
"For the %1 document the print form is not generated.';ru='__________________"
"Печать универсального передаточного документа доступна c 1 января 2013. "
"Для документа %1 печатная форма не сформирована.'");
			
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Header.Ref);
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
			Continue;
			
		EndIf;
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		PageCount = 1;
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If ItIsUniversalTransferDocument Then
			
			SpreadsheetDocument.PrintParametersKey = "PARAMETRS_PRINT_UniversalTransferDocument";
			Template = PrintManagement.PrintedFormsTemplate("Document.CustomerInvoiceNote.PF_MXL_UniversalTransferDocument");
			
		ElsIf Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_Invoice_Invoice1137";
			Template = PrintManagement.PrintedFormsTemplate("Document.CustomerInvoiceNote.PF_MXL_CustomerInvoiceNote1137");
		
		ElsIf Header.DocumentDate < '20090609' Then
			
			SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_Invoice_Invoice283";
			Template = PrintManagement.PrintedFormsTemplate("Document.CustomerInvoiceNote.PF_MXL_Invoice283");
			
		Else
			
			SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_Invoice_Invoice451";		
			Template = PrintManagement.PrintedFormsTemplate("Document.CustomerInvoiceNote.PF_MXL_Invoice451");
			
		EndIf;
		
		ThisIsConsolidatedCustomerInvoice = (TypeOf(Header.BasisDocument) = Type("DocumentRef.AgentReport")) AND Header.BasisDocument.MakeOutInvoicesCollective 
			AND Header.DocumentDate >= '20150101' AND Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.Sale;
		If ThisIsConsolidatedCustomerInvoice Then
			
			Query = New Query("Select Agents.Buyer From Document.AgentReport.Buyers AS Agents Where Agents.Invoice = &Invoice");
			Query.SetParameter("CustomerInvoiceNote", Header.Ref);
			CustomersTable = Query.Execute().Unload();
			CustomersTable.Columns.Add("InfoAboutCustomer");
			CustomersTable.Columns.Add("InfoAboutConsignee");
			For Each String IN CustomersTable Do
				
				String.InfoAboutCustomer		= SmallBusinessServer.InfoAboutLegalEntityIndividual(String.Customer, Header.DocumentDate,	,	);
				String.InfoAboutConsignee	= SmallBusinessServer.InfoAboutLegalEntityIndividual(
					?(Header.Same, String.Customer, Header.Consignee), 
					Header.DocumentDate,,);
				
			EndDo;
			
			InfoAboutVendor			= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Vendor, Header.DocumentDate,	,	);
			InfoAboutShipper	= SmallBusinessServer.InfoAboutLegalEntityIndividual(
				?(Header.Same, Header.Vendor, Header.Consignor), 
				Header.DocumentDate,	,);
			
		Else
			
			InfoAboutCustomer			= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Customer, Header.DocumentDate,	,	);
			InfoAboutVendor			= SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Vendor, Header.DocumentDate,	,	);
			
			InfoAboutShipper	= SmallBusinessServer.InfoAboutLegalEntityIndividual(
				?(Header.Same, Header.Vendor, Header.Consignor), 
				Header.DocumentDate,	,);
				
			InfoAboutConsignee	= SmallBusinessServer.InfoAboutLegalEntityIndividual(
				?(Header.Same AND Not ValueIsFilled(Header.Consignee), Header.Customer, Header.Consignee), 
				Header.DocumentDate,	,);
				
		EndIf;
			
		UseConversion 		= Header.SettlementsInStandardUnits AND Not Header.Currency = Constants.NationalCurrency.Get();
		
		If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin 
			AND Not ItIsUniversalTransferDocument Then
			
			TemplateArea = Template.GetArea("HeaderInformation");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		// Displaying invoice header
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;
		
		If ItIsUniversalTransferDocument Then
			
			TemplateArea.Parameters.Number = DocumentNumber;
			TemplateArea.Parameters.Date = Format(Header.DocumentDate, "DF=dd MMMM yyyy'")+ " g.";
			
		Else
			
			TemplateArea.Parameters.Number = "Invoice # " + DocumentNumber
					+ " dated " + Format(Header.DocumentDate, "DF=dd MMMM yyyy'")+ " g.";
					
		EndIf;
		
		If ItIsUniversalTransferDocument Then
			
			TemplateArea.Parameters.CorrectionNumber = "--";
			TemplateArea.Parameters.DateOfCorrection = "--";
			
		Else
			
			If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
				
				TemplateArea.Parameters.CorrectionNumber = "Correction No -- from --";
				
			EndIf;
			
		EndIf;
		
		TitleFields = ?(ItIsUniversalTransferDocument, "", "Seller: ");
		If Header.DocumentDate < '20090609' Then
			TemplateArea.Parameters.VendorPresentation =
				TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,");
				
		ElsIf Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
				
			TemplateArea.Parameters.VendorPresentation =
				TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,");
				
		Else
			
			TemplateArea.Parameters.VendorPresentation =
				TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,")
							+ " (" + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "Presentation,") + ")";
				
		EndIf;
		
		TitleFields = ?(ItIsUniversalTransferDocument, "", "Address: ");
		TemplateArea.Parameters.VendorAddress = TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "LegalAddress,");
		
		TitleFields = ?(ItIsUniversalTransferDocument, "", "To payment and settlement document ");
		
		LinesSelectionPaymentDocumentsDateNumber = Header.PaymentDocumentsDateNumber.Select();
		If LinesSelectionPaymentDocumentsDateNumber.Count() = 0 Then
			
			If Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance
				OR Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance Then
				
				TemplateArea.Parameters.ByDocument = TitleFields + "# -- dated --";
				
			Else
				
				TemplateArea.Parameters.ByDocument = TitleFields + "# dated";
				
			EndIf;
			
		Else
			
			While LinesSelectionPaymentDocumentsDateNumber.Next() Do
				
				TemplateArea.Parameters.ByDocument =
					?(ValueIsFilled(TemplateArea.Parameters.ByDocument), TemplateArea.Parameters.ByDocument + ", ", TitleFields)
					+ "No "
					+ LinesSelectionPaymentDocumentsDateNumber.PaymentAccountingDocumentNumber
					+ " from "
					+ Format(LinesSelectionPaymentDocumentsDateNumber.PaymentAccountingDocumentDate, "DF=dd.MM.yyyy");
				
			EndDo;
			
		EndIf;
		
		If ThisIsConsolidatedCustomerInvoice Then
			
			HeaderCustomerField = ?(ItIsUniversalTransferDocument, "", "Customer: ");
			HeaderAddressField = ?(ItIsUniversalTransferDocument, "", "Address: ");
			
			CustomerPresentation = "";
			CustomerAddressValue = "";
			CustomersData = New Structure;
			For Each String IN CustomersTable Do
				
				CustomerPresentation = CustomerPresentation + ?(IsBlankString(CustomerPresentation), HeaderCustomerField, "; ") 
					+ SmallBusinessServer.CompaniesDescriptionFull(String.InfoAboutCustomer, "FullDescr,");
				
				CustomerAddressValue = CustomerAddressValue + ?(IsBlankString(CustomerAddressValue), HeaderAddressField, "; ") 
					+ SmallBusinessServer.CompaniesDescriptionFull(String.InfoAboutCustomer, "LegalAddress,");
				
			EndDo;
			
			CustomersData.Insert("CustomerPresentation", CustomerPresentation);
			CustomersData.Insert("CustomerAddress", CustomerAddressValue);
			TemplateArea.Parameters.Fill(CustomersData);
			
		Else
			
			TitleFields = ?(ItIsUniversalTransferDocument, "", "Customer: ");
			TemplateArea.Parameters.CustomerPresentation = TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr,");
			
			TitleFields = ?(ItIsUniversalTransferDocument, "", "Address: ");
			CustomerAddressValue = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "LegalAddress,");
			If IsBlankString(CustomerAddressValue) 
				AND (Header.OperationKind <> Enums.OperationKindsCustomerInvoiceNote.Advance 
					OR Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance) Then
					
					TemplateArea.Parameters.CustomerAddress = TitleFields + "--"; 
					
			Else
				
				TemplateArea.Parameters.CustomerAddress = TitleFields + CustomerAddressValue;
				
			EndIf;
			
		EndIf;
		
		If Header.OperationKind <> Enums.OperationKindsCustomerInvoiceNote.Advance 
			OR Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance Then
			
			TitleFields = ?(ItIsUniversalTransferDocument, "", "Consignor and its address: ");
			If Header.Same Then
				
				TemplateArea.Parameters.PresentationOfShipper = TitleFields + NStr("en='the same';ru='Он же'");
				
			ElsIf Not ValueIsFilled(Header.Consignor) Then
				
				TemplateArea.Parameters.PresentationOfShipper = TitleFields + "--";
				
			Else
				
				TemplateArea.Parameters.PresentationOfShipper = TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutShipper, "FullDescr, ActualAddress,");
				
			EndIf; 
			
			If ThisIsConsolidatedCustomerInvoice Then
				
				TitleFields = ?(ItIsUniversalTransferDocument, "", "Consignee and its address: ");
				PresentationOfConsignee  = "";
				For Each String IN CustomersTable Do
					
					PresentationOfConsignee = PresentationOfConsignee + ?(IsBlankString(PresentationOfConsignee), TitleFields, "; ") 
						+ SmallBusinessServer.CompaniesDescriptionFull(String.InfoAboutConsignee, "FullDescr, ActualAddress,");
					
				EndDo;
				
				TemplateArea.Parameters.PresentationOfConsignee = PresentationOfConsignee;
				
			Else
				
				TitleFields = ?(ItIsUniversalTransferDocument, "", "Consignee and its address: ");
				If ValueIsFilled(Header.Consignee) Then
					
					TemplateArea.Parameters.PresentationOfConsignee  = TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutConsignee, "FullDescr, ActualAddress,");
					
				ElsIf IsInventory(Header.Ref) Then
					
					TemplateArea.Parameters.PresentationOfConsignee  = TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr, ActualAddress,");
					
				Else
					
					If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
						TemplateArea.Parameters.PresentationOfConsignee  = TitleFields + "--";
						
					Else
						
						TemplateArea.Parameters.PresentationOfConsignee  = TitleFields;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		Else
			
			TemplateArea.Parameters.PresentationOfShipper = "Consignor and their address: --";
			TemplateArea.Parameters.PresentationOfConsignee  = "Consignee and their address: --";
			
		EndIf;
		
		KPP = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "KPP,", False);
		If ValueIsFilled(KPP) Then
			KPP = "/" + KPP;
		EndIf;
		TitleFields = ?(ItIsUniversalTransferDocument, "", "TIN/KPP seller: ");
		TemplateArea.Parameters.VendorTIN = TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "TIN,", False) + KPP;
		
		If ThisIsConsolidatedCustomerInvoice Then
			
			TIN_KPP_customer = "";
			For Each String IN CustomersTable Do
				
				KPP = "";
				KPP = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "KPP,", False);
				If ValueIsFilled(KPP) Then 
					KPP = "/" + KPP;
				EndIf;
				
				TIN_KPP_customer = TIN_KPP_customer + ?(IsBlankString(TIN_KPP_customer),"","; ") 
					+ SmallBusinessServer.CompaniesDescriptionFull(String.InfoAboutCustomer, "TIN,", False) + KPP;
				
			EndDo;
			
			TitleFields = ?(ItIsUniversalTransferDocument, "", "TIN/KPP customer: ");
			TemplateArea.Parameters.TINOfHBuyer = TitleFields + TIN_KPP_customer;
			
		Else
			
			KPP = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "KPP,", False);
			If ValueIsFilled(KPP) Then 
				KPP = "/" + KPP;
			EndIf;
			TitleFields = ?(ItIsUniversalTransferDocument, "", "TIN/KPP customer: ");
			TemplateArea.Parameters.TINOfHBuyer = TitleFields + SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "TIN,", False) + KPP;
			
		EndIf;
		
		If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			TitleFields = ?(ItIsUniversalTransferDocument, "", "Currency: name, code ");
			
			If Not ValueIsFilled(Header.Currency) 
				OR UseConversion Then
				
				TemplateArea.Parameters.Currency = TitleFields + " Russian ruble,643 ";
				
			Else
				
				TemplateArea.Parameters.Currency = TitleFields + TrimAll(Header.Currency.DescriptionFull) + ", " + TrimAll(Header.Currency.Code) + "";
				
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
		|	CASE
		|		WHEN NestedSelect.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
		|			THEN NestedSelect.ProductsAndServices.SKU
		|		ELSE NULL
		|	END AS ProductCode,
		|	NestedSelect.ProductsAndServices.SKU AS SKU,
		|	NestedSelect.Characteristic AS Characteristic,
		|	NestedSelect.MeasurementUnitForPrint.Code AS MeasurementUnitCode,
		|	NestedSelect.MeasurementUnitForPrint AS MeasurementUnit,
		|	NestedSelect.MeasurementUnitCoefficient AS MeasurementUnitCoefficient,
		|	NestedSelect.Quantity,
		|	&Price_Parameter AS Price,
		|	&AmountWithoutVAT_Parameter AS AmountWithoutVAT,
		|	NestedSelect.VATRate,
		|	&VATAmount_Parameter AS VATAmount,
		|	&Total_Parameter AS Total,
		|	""no excise"" AS Excise,
		|	NestedSelect.CCDNo,
		|	NestedSelect.CCDNo AS CCDPresentation,
		|	NestedSelect.CountryOfOrigin AS CountryOfOrigin,
		|	NestedSelect.CountryOfOriginCode AS CountryOfOriginCode,
		|	NestedSelect.CountryPresentation,
		|	NestedSelect.Content,
		|	NestedSelect.Same
		|FROM
		|	(SELECT
		|		MIN(InvoiceInventory.LineNumber) AS LineNumber,
		|		InvoiceInventory.ProductsAndServices AS ProductsAndServices,
		|		InvoiceInventory.Characteristic AS Characteristic,
		|		InvoiceInventory.ProductsAndServices.MeasurementUnit AS MeasurementUnitForPrint,
		|		InvoiceInventory.MeasurementUnit AS MeasurementUnitCoefficient,
		|		SUM(InvoiceInventory.Quantity) AS Quantity,
		|		InvoiceInventory.Price AS Price,
		|		SUM(InvoiceInventory.Amount) AS AmountWithoutVAT,
		|		InvoiceInventory.VATRate AS VATRate,
		|		SUM(InvoiceInventory.VATAmount) AS VATAmount,
		|		SUM(InvoiceInventory.Total) AS Total,
		|		InvoiceInventory.CCDNo AS CCDNo,
		|		InvoiceInventory.CountryOfOrigin AS CountryOfOrigin,
		|		InvoiceInventory.CountryOfOrigin.Code AS CountryOfOriginCode,
		|		InvoiceInventory.CountryOfOrigin.Presentation AS CountryPresentation,
		|		CAST(InvoiceInventory.Content AS String(1000)) AS Content,
		|		InvoiceInventory.Ref.Same AS Same
		|	FROM
		|		Document.CustomerInvoiceNote.Inventory AS InvoiceInventory
		|	WHERE
		|		InvoiceInventory.Ref = &Ref
		|	
		|	GROUP BY
		|		InvoiceInventory.CCDNo,
		|		InvoiceInventory.MeasurementUnit,
		|		InvoiceInventory.ProductsAndServices,
		|		CAST(InvoiceInventory.Content AS String(1000)),
		|		InvoiceInventory.Characteristic,
		|		InvoiceInventory.VATRate,
		|		InvoiceInventory.Price,
		|		InvoiceInventory.CountryOfOrigin,
		|		InvoiceInventory.CountryOfOrigin.Code,
		|		InvoiceInventory.CountryOfOrigin.Presentation,
		|		InvoiceInventory.Ref.Same,
		|		InvoiceInventory.ProductsAndServices.MeasurementUnit) AS NestedSelect
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
		
		If  Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.AccrualDifferences Then
			
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
			
		ElsIf  Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.Sale Then
			
			TableByProducts = Query.Execute().Unload();
			
			LineNumber = 0;
			NumberWorksheet = 1;
			LineCount = TableByProducts.Count();
			
			For Each Row IN TableByProducts Do
				TemplateArea.Parameters.Fill(Row);
				
				LineNumber = LineNumber + 1;
				If ItIsUniversalTransferDocument Then
					
					TemplateArea.Parameters.LineNumber = LineNumber;
					
				EndIf;
				
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
				
				Quantity = Row.Quantity * Factor;
				
				TemplateArea.Parameters.Quantity = Quantity;
				
				If Row.Price <> 0 Then
					
					TemplateArea.Parameters.Price = ?(Quantity = 0, 0, (Row.Total - Row.VATAmount) / Quantity);
					
				Else
					
					TemplateArea.Parameters.Price = Row.Price * Factor;
					
				EndIf;
				
				// Due to round-off for contracts in c.u. or currency, it will be incorrect to receive the amount without VAT with direct recalculation
				TemplateArea.Parameters.Cost = Row.Total - Row.VATAmount;
				
				TemplateArea.Parameters.Total = Row.Total;
				
				If Upper(Row.VATRate) = "WITHOUT VAT" Then
					
					TemplateArea.Parameters.VATRate	= "Without VAT";
					TemplateArea.Parameters.VATAmount	= "Without VAT";
					
				Else
					
					TemplateArea.Parameters.VATRate	= Row.VATRate;
					TemplateArea.Parameters.VATAmount = Row.VATAmount;
					
				EndIf;
				
				TotalCost	= TotalCost + (Row.Total - Row.VATAmount);
				TotalVATAmount	= TotalVATAmount + Row.VATAmount;
				SubtotalTotal		= SubtotalTotal + Row.Total;
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					If String(Row.CountryPresentation) = "Russia" 
						OR IsBlankString(Row.CountryPresentation) Then
						
						TemplateArea.Parameters.CountryPresentation  = "--";
						TemplateArea.Parameters.CountryOfOriginCode = "--";
						
					EndIf;
				
					If IsBlankString(Row.CCDPresentation) Then
						
						TemplateArea.Parameters.CCDPresentation = "--";
						
					EndIf;
					
				EndIf;
				
				If ItIsUniversalTransferDocument
					AND Not SmallBusinessServer.CheckAccountsInvoicePagePut(SpreadsheetDocument, TemplateArea, (LineNumber = LineCount), Template, NumberWorksheet, DocumentNumber, ItIsUniversalTransferDocument) Then
					
					PageCount = PageCount + 1;
					
				EndIf;
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
		ElsIf Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance 
			OR Header.OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance Then
			
			Query.Text =
			"SELECT
			|	1 AS ID,
			|	NestedSelect.LineNumber AS LineNumber,
			|	NestedSelect.ProductsAndServices.DescriptionFull AS ProductDescription,
			|	NestedSelect.ProductsAndServices AS ProductsAndServices,
			|	NestedSelect.ProductsAndServices.SKU AS SKU,
			|	NestedSelect.Characteristic AS Characteristic,
			|	&AmountWithoutVAT_Parameter AS AmountWithoutVAT,
			|	NestedSelect.VATRate,
			|	&VATAmount_Parameter AS VATAmount,
			|	&Total_Parameter AS Total,
			|	""no excise"" AS Excise,
			|	NestedSelect.Content
			|FROM
			|	(SELECT
			|		MIN(InvoiceInventory.LineNumber) AS LineNumber,
			|		InvoiceInventory.ProductsAndServices AS ProductsAndServices,
			|		InvoiceInventory.Characteristic AS Characteristic,
			|		SUM(InvoiceInventory.Amount) AS AmountWithoutVAT,
			|		InvoiceInventory.VATRate AS VATRate,
			|		SUM(InvoiceInventory.VATAmount) AS VATAmount,
			|		SUM(InvoiceInventory.Total) AS Total,
			|		CAST(InvoiceInventory.Content AS String(1000)) AS Content
			|	FROM
			|		Document.CustomerInvoiceNote.Inventory AS InvoiceInventory
			|	WHERE
			|		InvoiceInventory.Ref = &Ref
			|	
			|	GROUP BY
			|		InvoiceInventory.ProductsAndServices,
			|		InvoiceInventory.Characteristic,
			|		InvoiceInventory.VATRate,
			|		CAST(InvoiceInventory.Content AS String(1000))) AS NestedSelect
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
					
				ElsIf Not ValueIsFilled(Row.ProductsAndServices) Then
					
					TemplateArea.Parameters.ProductDescription = "Preliminary payment";
					
				Else
					
					TemplateArea.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(Row.ProductDescription, 
																		Row.Characteristic, Row.SKU);
					
				EndIf;
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					TemplateArea.Parameters.MeasurementUnitCode = "--";
					TemplateArea.Parameters.CountryPresentation  = "--";
					TemplateArea.Parameters.CountryOfOriginCode = "--";
					TemplateArea.Parameters.CCDPresentation = "--";
					
				EndIf;
				
				TemplateArea.Parameters.MeasurementUnit 	= "--";
				
				If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					TemplateArea.Parameters.Excise = Row.Excise;
					
				Else
					
					TemplateArea.Parameters.Excise = "--";
					
				EndIf;
				
				TemplateArea.Parameters.Total 				= Row.Total;
				
				If Upper(Row.VATRate) = "WITHOUT VAT" Then
					
					TemplateArea.Parameters.VATRate	= "Without VAT";
					TemplateArea.Parameters.VATAmount	= "Without VAT";
					
				Else
					
					TemplateArea.Parameters.VATRate	= Row.VATRate;
					TemplateArea.Parameters.VATAmount = Row.VATAmount;
					
				EndIf;
				
				TotalVATAmount	= TotalVATAmount + Row.VATAmount;
				SubtotalTotal		= SubtotalTotal + Row.Total;
				
				If Not Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
					
					PutDashesToEmptyFields(TemplateArea);
					
				EndIf;
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
		EndIf;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.TotalVATAmount	= TotalVATAmount;
		TemplateArea.Parameters.SubtotalTotal		= SubtotalTotal;
		
		If Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			TemplateArea.Parameters.TotalCost	= ?(TotalCost = 0, "--", TotalCost);
			
		Else
			
			PutDashesToEmptyFields(TemplateArea);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Footer");
		
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Head, Header.DocumentDate);
		
		If Header.Head.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind Then
			TemplateArea.Parameters.SNPPBOLP = Heads.HeadDescriptionFull;
			Heads.Delete("HeadDescriptionFull"); 
		EndIf;
		
		TemplateArea.Parameters.Fill(Heads);
		TemplateArea.Parameters.Certificate = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "Certificate,");
		
		If ItIsUniversalTransferDocument Then
			
			TemplateArea.Parameters.PagesNumber = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Document is drawn up for%1%2 %3';ru='Документ составлен на%1%2 %3'"), Chars.LF, PageCount,
				SmallBusinessServer.FormOfMultipleNumbers(NStr("en='list';ru='список'"), NStr("en='Worksheets';ru='листах'"), NStr("en='Worksheets';ru='листах'"), PageCount)
				);
			
		EndIf;
		
		If Not Header.DocumentDate >= CustomerInvoiceNote1137UsageBegin Then
			
			PutDashesToEmptyFields(TemplateArea);
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		If ItIsUniversalTransferDocument Then
			
			TemplateArea = Template.GetArea("InvoiceFooter");
			TemplateArea.Parameters.Fill(Header);
			If TypeOf(Header.BasisDocument) = Type("DocumentRef.CustomerInvoice") Then
				
				If ValueIsFilled(Header.BasisDocument)
					AND
					(ValueIsFilled(Header.BasisDocument.PowerOfAttorneyIssued)
						OR ValueIsFilled(Header.BasisDocument.PowerOfAttorneyDate)
						OR ValueIsFilled(Header.BasisDocument.PowerAttorneyPerson)
						OR ValueIsFilled(Header.BasisDocument.PowerOfAttorneyNumber))
					Then
					
					TemplateArea.Parameters.Basis = 
						Header.Basis + NStr("en='; by power of attorney No';ru='; по доверенности №'") + Header.BasisDocument.PowerOfAttorneyNumber 
						+ NStr("en=' from ';ru=' от '") + Format(Header.BasisDocument.PowerOfAttorneyDate, "DLF=DD") 
						+ NStr("en=' Paid ';ru=' Paid '") + Header.BasisDocument.PowerOfAttorneyIssued + " " 
						+ Header.BasisDocument.PowerAttorneyPerson;
					
				EndIf;
			
			EndIf;
			
			TemplateArea.Parameters.ShipmentDateTransfer = Format(Header.DocumentDate, "DF='"" dd "" MMMM yyyy'");
			
			CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutVendor, "FullDescr,");
			If Not IsBlankString(InfoAboutVendor.TIN) 
				AND Not IsBlankString(InfoAboutVendor.KPP) Then
				
				CompanyPresentation = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1, TIN/KPP %2/%3';ru='%1, TIN/KPP %2/%3'"),
					CompanyPresentation, InfoAboutVendor.TIN, InfoAboutVendor.KPP);
				
			ElsIf Not IsBlankString(InfoAboutVendor.TIN) Then
				
				CompanyPresentation = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1, TIN %2';ru='%1, ИНН %2'"),
					CompanyPresentation, InfoAboutVendor.TIN);
				
			EndIf;
			
			TemplateArea.Parameters.CompanyPresentation = CompanyPresentation;
			
			PresentationOfCounterparty = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr,");
			If Not IsBlankString(InfoAboutCustomer.TIN)
				AND Not IsBlankString(InfoAboutCustomer.KPP) Then
				
				PresentationOfCounterparty = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1, TIN/KPP %2/%3';ru='%1, TIN/KPP %2/%3'"),
					PresentationOfCounterparty, InfoAboutCustomer.TIN, InfoAboutCustomer.KPP);
					
			ElsIf Not IsBlankString(InfoAboutCustomer.TIN) Then
				
				PresentationOfCounterparty = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1, TIN %2';ru='%1, ИНН %2'"),
					PresentationOfCounterparty, InfoAboutCustomer.TIN);
				
			EndIf;
			
			TemplateArea.Parameters.PresentationOfCounterparty = PresentationOfCounterparty;
			
			TemplateArea.Parameters.WarehousemanPosition = Heads.WarehouseMan_Position;
			TemplateArea.Parameters.WarehouseManSNP = Heads.WarehouseManSNP;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	If Errors <> Undefined Then
		
		CommonUseClientServer.ShowErrorsToUser(Errors);
		
	EndIf;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Procedure puts dashes into empty fields.
//
Procedure PutDashesToEmptyFields(TemplateArea)

	For t = 0 To TemplateArea.Parameters.Count() - 1 Do
		
		CurParameter = TemplateArea.Parameters.Get(t);
		
		If (Find(CurParameter, "Seller:") <> 0)
			AND (TrimAll(CurParameter) = "Seller:") Then
			TemplateArea.Parameters.Set(t, "Seller: --");
			
		ElsIf (Find(CurParameter, "Address:") <> 0)
			AND(TrimAll(CurParameter) = "Address:") Then
			TemplateArea.Parameters.Set(t, "Address: --");
			
		ElsIf (Find(CurParameter, "Seller identification number (TIN):") <> 0)
			AND (TrimAll(CurParameter) = "Seller identification number (TIN):") Then
			TemplateArea.Parameters.Set(t, "Seller identification number (TIN): --");
			
		ElsIf (Find(CurParameter, "Consignor and its address:") <> 0)
			AND (TrimAll(CurParameter) = "Consignor and its address:") Then
			TemplateArea.Parameters.Set(t, "Consignor and their address: --");
			
		ElsIf (Find(CurParameter, "Consignee and its address:") <> 0)
			AND (TrimAll(CurParameter) = "Consignee and its address:") Then
			TemplateArea.Parameters.Set(t, "Consignee and their address: --");
			
		ElsIf (Find(CurParameter, "To payment and settlement document #") <> 0)
			and (TrimAll(CurParameter) = "To payment and settlement document # from") Then
			TemplateArea.Parameters.Set(t, "To payment and settlement document # -- from --");
			
		ElsIf (Find(CurParameter, "Customer:") <> 0)
			AND (TrimAll(CurParameter) = "Customer:") Then
			TemplateArea.Parameters.Set(t, "Customer: --");
			
		ElsIf (Find(CurParameter, "Customer identification number (TIN):") <> 0)
			AND (TrimAll(CurParameter) = "Customer identification number (TIN):") Then
			TemplateArea.Parameters.Set(t, "Customer identification number (TIN): --");
			
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CustomerInvoiceNote") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CustomerInvoiceNote", "Account-texture", PrintForm(ObjectsArray, PrintObjects, False));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "UniversalTransferDocument") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "UniversalTransferDocument", "Universal transfer document", PrintForm(ObjectsArray, PrintObjects, True));
		
		If TypeOf(PrintParameters) = Type("Structure")
			AND PrintParameters.Property("Errors")
			AND PrintParameters.Errors <> Undefined Then
			
			CommonUseClientServer.ShowErrorsToUser(PrintParameters.Errors);
			
		EndIf;
		
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
	PrintCommand.ID = "CustomerInvoiceNote";
	PrintCommand.Presentation = NStr("en='Account-texture';ru='Счет-фактура'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "UniversalTransferDocument";
	PrintCommand.Presentation = NStr("en='Universal transfer document';ru='Универсальный передаточный документ'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
EndProcedure

#EndRegion

#EndIf