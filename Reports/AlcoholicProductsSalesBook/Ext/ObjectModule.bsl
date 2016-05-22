#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	Template = Reports.AlcoholicProductsSalesBook.GetTemplate("Template");
	
	ReportParameters = SettingsComposer.GetSettings();
	
	Period		= ReportParameters.DataParameters.FindParameterValue(
					New DataCompositionParameter("Period")).Value;
	Company = ReportParameters.DataParameters.FindParameterValue(
					New DataCompositionParameter("Company")).Value;
	Warehouse		= ReportParameters.DataParameters.FindParameterValue(
					New DataCompositionParameter("Warehouse")).Value;
					
	If Not ValueIsFilled(Company) Then
		Raise NStr("en = 'Value of mandatory parameter ""Company"" is not filled in'");
	EndIf;
	If Not ValueIsFilled(Warehouse) Then
		Raise NStr("en = 'Value of mandatory parameter ""Warehouse"" is not filled in'");
	EndIf;
	
	InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Company, Period.EndDate);

	ResultDocument.FitToPage = True;
	ResultDocument.PageOrientation = PageOrientation.Landscape;
	ResultDocument.RepeatOnRowPrint = ResultDocument.Area(11,, 11,);
	
	OutputCoverPage = ReportParameters.DataParameters.FindParameterValue(New DataCompositionParameter("OutputCoverPage")).Value;
	If OutputCoverPage = True Then
		AreaCompany = Template.GetArea("FrontSheet");
		
		AreaCompany.Parameters.PeriodPresentation = PeriodPresentation(Period.StartDate, Period.EndDate);
		AreaCompany.Parameters.CompanyName = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		AreaCompany.Parameters.Warehouse = Warehouse;
		
		ResultDocument.Put(AreaCompany);
		ResultDocument.PutHorizontalPageBreak();
		
		ResultDocument.Area("R1:R" + ResultDocument.TableHeight).Name = "FrontSheet";
	EndIf;
	
	TemplateArea = Template.GetArea("Header");
	ResultDocument.Put(TemplateArea);
	ResultDocument.RepeatOnRowPrint = ResultDocument.Area(11, , 11, );

	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Company", Company);
	Query.SetParameter("Warehouse", Warehouse);
	Query.SetParameter("StartDate", BegOfDay(Period.StartDate));
	Query.SetParameter("EndDate", EndOfDay(Period.EndDate));
	Query.SetParameter("Receipt", AccumulationRecordType.Receipt);
	Query.SetParameter("IsBlankString", "");
	Query.SetParameter("BlankDate", Date(1, 1, 1));
	
	Query.Text = 
	"SELECT ALLOWED
	|	ProductsFlow.Recorder AS Recorder,
	|	ProductsFlow.Period AS Period,
	|	ProductsFlow.Recorder.Number AS Number,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN SupplierInvoice.IncomingDocumentDate
	|		ELSE &BlankDate
	|	END AS IncomingDocumentDate,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN SupplierInvoice.IncomingDocumentNumber
	|		ELSE &IsBlankString
	|	END AS IncomingDocumentNumber,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN CAST(ISNULL(Counterparties.DescriptionFull, &IsBlankString) AS String(200))
	|		ELSE &IsBlankString
	|	END AS CounterpartyDescription,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN ISNULL(Counterparties.TIN, &IsBlankString)
	|		ELSE &IsBlankString
	|	END AS TIN,
	|	ISNULL(ProductsFlow.ProductsAndServices.AlcoholicProductsKind, &IsBlankString) AS ProductsKind,
	|	ISNULL(ProductsFlow.ProductsAndServices.AlcoholicProductsKind.Code, &IsBlankString) AS KindCode,
	|	ISNULL(ProductsFlow.ProductsAndServices.VolumeDAL, 0) * 10 AS Capacity,
	|	SUM(ProductsFlow.Quantity) AS Quantity,
	|	SUM(ISNULL(ProductsFlow.ProductsAndServices.VolumeDAL, 0) * ProductsFlow.Quantity) AS Volume,
	|	ProductsFlow.RecordType AS RecordType,
	|	ProductsFlow.Recorder.OperationKind AS OperationKind,
	|	ProductsFlow.StructuralUnitCorr AS StructuralUnitCorr,
	|	ProductsFlow.ProductsAndServices AS ProductsAndServices
	|FROM
	|	AccumulationRegister.Inventory AS ProductsFlow
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON (SupplierInvoice.Ref = ProductsFlow.Recorder)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON (Counterparties.Ref = SupplierInvoice.Counterparty)
	|WHERE
	|	ProductsFlow.Period between &StartDate AND &EndDate
	|	AND ProductsFlow.StructuralUnit = &Warehouse
	|	AND ProductsFlow.Recorder.Company = &Company
	|	AND ProductsFlow.ProductsAndServices.AlcoholicProductsKind <> VALUE(Catalog.AlcoholicProductsKinds.EmptyRef)
	|	AND Not(VALUETYPE(ProductsFlow.Recorder) = Type(Document.CustomerOrder)
	|					AND ProductsFlow.Recorder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForSale)
	|				OR VALUETYPE(ProductsFlow.Recorder) = Type(Document.InventoryReservation)
	|				OR VALUETYPE(ProductsFlow.Recorder) = Type(Document.CustomerOrder)
	|					AND ProductsFlow.ContentOfAccountingRecord = ""Inventory reservation"")
	|
	|GROUP BY
	|	ProductsFlow.Recorder,
	|	ProductsFlow.Period,
	|	ProductsFlow.Recorder.Number,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN SupplierInvoice.IncomingDocumentDate
	|		ELSE &BlankDate
	|	END,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN SupplierInvoice.IncomingDocumentNumber
	|		ELSE &IsBlankString
	|	END,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN CAST(ISNULL(Counterparties.DescriptionFull, &IsBlankString) AS String(200))
	|		ELSE &IsBlankString
	|	END,
	|	CASE
	|		WHEN ProductsFlow.Recorder REFS Document.SupplierInvoice
	|			THEN ISNULL(Counterparties.TIN, &IsBlankString)
	|		ELSE &IsBlankString
	|	END,
	|	ProductsFlow.ProductsAndServices.AlcoholicProductsKind,
	|	ISNULL(ProductsFlow.ProductsAndServices.VolumeDAL, 0) * 10,
	|	ProductsFlow.RecordType,
	|	ISNULL(ProductsFlow.ProductsAndServices.AlcoholicProductsKind.Code, &IsBlankString),
	|	ProductsFlow.Recorder.OperationKind,
	|	ProductsFlow.StructuralUnitCorr,
	|	ProductsFlow.ProductsAndServices
	|
	|ORDER BY
	|	Period";
	
	Selection = Query.Execute().Select();
	
	LineNumber = 0;
	TotalVolumeReceipt = 0;
	TotalVolumeExpense = 0;
	TotalQuantityReceipt = 0;
	TotalQuantityExpense = 0;
	
	TemplateArea = Template.GetArea("String");

	While Selection.Next() Do
		
		LineNumber = LineNumber + 1;
		
		FillPropertyValues(TemplateArea.Parameters, Selection);
		TemplateArea.Parameters.LineNumber = LineNumber;
		TemplateArea.Parameters.Recorder = Selection.Recorder;
		
		ProductsName = StringFunctionsClientServer.PlaceParametersIntoString("%1 (%2)",
			Selection.ProductsKind, TrimAll(Selection.ProductsAndServices));
		
		If Selection.RecordType = AccumulationRecordType.Receipt
			AND Not (TypeOf(Selection.Recorder) = Type("DocumentRef.SupplierInvoice")
				AND Selection.OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromCustomer)
			AND Not (TypeOf(Selection.Recorder) = Type("DocumentRef.CustomerInvoice")
				AND Selection.OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor) Then
			
			TemplateArea.Parameters.RecorderReceipt = Selection.Recorder;
			
			If ValueIsFilled(Selection.IncomingDocumentDate) Then
				TemplateArea.Parameters.BOLDate = Selection.IncomingDocumentDate;
			Else
				TemplateArea.Parameters.BOLDate = Selection.Period;
			EndIf;
			If ValueIsFilled(Selection.IncomingDocumentNumber) Then
				TemplateArea.Parameters.BOLNumber = Selection.IncomingDocumentNumber;
			Else
				TemplateArea.Parameters.BOLNumber = Selection.Number;
			EndIf;
			If TypeOf(Selection.Recorder) = Type("DocumentRef.SupplierInvoice")
				AND Selection.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor Then
				TemplateArea.Parameters.Vendor = Selection.CounterpartyDescription;
				TemplateArea.Parameters.TINReceipt = Selection.TIN;
			Else
				TemplateArea.Parameters.Vendor = InfoAboutCompany.FullDescr;
				TemplateArea.Parameters.TINReceipt = InfoAboutCompany.TIN;
			EndIf;
			
			TemplateArea.Parameters.KindGoodsReceipt = ProductsName;
			TemplateArea.Parameters.KindCodeReceipt = Selection.KindCode;
			
			TemplateArea.Parameters.CapacityReceipt = Selection.Capacity;
			TemplateArea.Parameters.QuantityReceipt = Selection.Count;
			
			TemplateArea.Parameters.RecorderExpense = Undefined;
			TemplateArea.Parameters.ExpenceContent = "";
			TemplateArea.Parameters.ProductionExpenseKind = "";
			TemplateArea.Parameters.CapacityExpense = 0;
			TemplateArea.Parameters.QuantityExpense = 0;
			
			TotalVolumeReceipt = TotalVolumeReceipt + Selection.Volume;
			TotalQuantityReceipt = TotalQuantityReceipt + Selection.Count;
			
		Else
			
			TemplateArea.Parameters.RecorderReceipt = Undefined;
			TemplateArea.Parameters.BOLDate = "";
			TemplateArea.Parameters.BOLNumber = "";
			TemplateArea.Parameters.Vendor = "";
			TemplateArea.Parameters.TINReceipt = "";
			TemplateArea.Parameters.KindGoodsReceipt = "";
			TemplateArea.Parameters.KindCodeReceipt = "";
			TemplateArea.Parameters.CapacityReceipt = 0;
			TemplateArea.Parameters.QuantityReceipt = 0;
			
			TemplateArea.Parameters.RecorderExpense = Selection.Recorder;
			
			VolumeExpense = Selection.Volume;
			QuantityExpense = Selection.Count;
			
			If TypeOf(Selection.Recorder) = Type("DocumentRef.RetailReport")
				OR (TypeOf(Selection.Recorder) = Type("DocumentRef.CustomerInvoice")
				AND Selection.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer)
				OR (TypeOf(Selection.Recorder) = Type("DocumentRef.SupplierInvoice")
				AND Selection.OperationKind = Enums.OperationKindsSupplierInvoice.ReturnFromCustomer) Then
				
				ContentOperations = NStr("en = 'Sold products'");
				
			ElsIf TypeOf(Selection.Recorder) = Type("DocumentRef.CustomerInvoice")
				AND Selection.OperationKind = Enums.OperationKindsCustomerInvoice.ReturnToVendor Then
				
				ContentOperations = NStr("en = 'Products returned to the supplier'");
				VolumeExpense = - VolumeExpense;
				QuantityExpense = - QuantityExpense;
				
			ElsIf TypeOf(Selection.Recorder) = Type("DocumentRef.InventoryWriteOff") Then
				
				ContentOperations = NStr("en = 'Shortage of products'");
				
			ElsIf TypeOf(Selection.Recorder) = Type("DocumentRef.InventoryTransfer")
				AND Selection.OperationKind = Enums.OperationKindsInventoryTransfer.Move
				AND Selection.StructuralUnitCorr.StructuralUnitType <> Enums.StructuralUnitsTypes.Division Then
				
				ContentOperations = NStr("en = 'Products transferred to other division'");
				
			Else
				
				ContentOperations = NStr("en = 'Written-off products'");
				
			EndIf;
			
			TemplateArea.Parameters.ExpenceContent = ContentOperations;
			TemplateArea.Parameters.ProductionExpenseKind = ProductsName;
			TemplateArea.Parameters.CapacityExpense = Selection.Capacity;
			TemplateArea.Parameters.QuantityExpense = QuantityExpense;
			
			TotalVolumeExpense = TotalVolumeExpense + VolumeExpense;
			TotalQuantityExpense = TotalQuantityExpense + QuantityExpense;
			
		EndIf;
		
		ResultDocument.Put(TemplateArea);
		
		ResultDocument.RepeatOnRowPrint = ResultDocument.Area("RowsForRepeat");
		
	EndDo;
	
	TemplateArea = Template.GetArea("Totals");
	
	TemplateArea.Parameters.VolumeReceipt = TotalVolumeReceipt;
	TemplateArea.Parameters.VolumeExpense = TotalVolumeExpense;
	TemplateArea.Parameters.QuantityReceipt = TotalQuantityReceipt;
	TemplateArea.Parameters.QuantityExpense = TotalQuantityExpense;
	
	ResultDocument.Put(TemplateArea);
	
EndProcedure

#EndRegion

#EndIf
