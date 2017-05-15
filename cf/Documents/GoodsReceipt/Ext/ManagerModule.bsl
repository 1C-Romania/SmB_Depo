#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefGoodsReceipt, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	GoodsReceiptInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	GoodsReceiptInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	GoodsReceiptInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN GoodsReceiptInventory.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	GoodsReceiptInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsReceiptInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN GoodsReceiptInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(GoodsReceiptInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN GoodsReceiptInventory.Quantity
	|		ELSE GoodsReceiptInventory.Quantity * GoodsReceiptInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.GoodsReceipt.Inventory AS GoodsReceiptInventory
	|WHERE
	|	GoodsReceiptInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ref.StructuralUnit AS StructuralUnit,
	|	TableInventory.Ref.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	Document.GoodsReceipt.Inventory AS TableInventory
	|		INNER JOIN Document.GoodsReceipt.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|	AND TableInventory.Ref.StructuralUnit.OrderWarehouse");
	
	Query.SetParameter("Ref", DocumentRefGoodsReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForWarehouses", ResultsArray[0].Unload());
	
	// Serial numbers
	QueryResult1 = ResultsArray[1].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", QueryResult1);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult1);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefGoodsReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange", "RegisterRecordsInventoryChange"
	// temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, ProductsAndServices, Characteristic, Batch, Cell) In
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.ProductsAndServices = InventoryInWarehousesOfBalance.ProductsAndServices
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectGoodsReceipt = DocumentRefGoodsReceipt.GetObject();
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;

EndProcedure // RunControl()

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_GoodsReceipt";

	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "GoodsReceipt" Then
		
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	GoodsReceipt.Date AS DocumentDate,
			|	GoodsReceipt.Company AS Company,
			|	GoodsReceipt.Number,
			|	GoodsReceipt.Company.Prefix AS Prefix,
			|	GoodsReceipt.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.DescriptionFull AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit AS StorageUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ConnectionKey
			|	),
			|	GoodsReceipt.SerialNumbers.(
			|		PRESENTATION(GoodsReceipt.SerialNumbers.SerialNumber) AS SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.GoodsReceipt AS GoodsReceipt
			|WHERE
			|	GoodsReceipt.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();

			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_GoodsReceipt_GoodsReceipt";
                                          
			Template = PrintManagement.PrintedFormsTemplate("Document.GoodsReceipt.PF_MXL_GoodsReceipt");
						InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);

			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;		
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "PURCHASE ORDER RECEIPT # "
													+ DocumentNumber
													+ " from "
													+ Format(Header.DocumentDate, "DLF=DD");
													
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Customer");
			TemplateArea.Parameters.RecipientPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
			SpreadsheetDocument.Put(TemplateArea);

			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("String");
			
			Quantity = 0;

			While LinesSelectionInventory.Next() Do

				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				Quantity = Quantity + 1;
				
			EndDo;

			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Signatures");
			SpreadsheetDocument.Put(TemplateArea);
			
		ElsIf TemplateName = "M4" Then
		
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	GoodsReceipt.Date AS DocumentDate,
			|	GoodsReceipt.Company AS Company,
			|	GoodsReceipt.StructuralUnit.Description AS WarehouseDescription,
			|	GoodsReceipt.Number,
			|	GoodsReceipt.Company.Prefix AS Prefix,
			|	GoodsReceipt.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.DescriptionFull AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		MeasurementUnit.Code
			|	)
			|FROM
			|	Document.GoodsReceipt AS GoodsReceipt
			|WHERE
			|	GoodsReceipt.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();

			SpreadsheetDocument.PrintParametersName = "PRINTING_OPTIONS_PurchaseOrder_M4";
                                          
			Template = PrintManagement.PrintedFormsTemplate("Document.GoodsReceipt.PF_MXL_M4");
						InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
            					
			TemplateAreaHeader              = Template.GetArea("Header");
			TitleOfDocumentLayoutArea = Template.GetArea("DocumentTitle");
			TemplateAreaTableHeader   = Template.GetArea("TableTitle");
			TemplateAreaRow             = Template.GetArea("String");
			AreaLayoutFooterRows        = Template.GetArea("FooterRows");
			LayoutOfAreaTotal              = Template.GetArea("Total");
			TemplateAreaFooter             = Template.GetArea("Footer");
	
			// Displaying general header attributes
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;		
			
			TemplateAreaHeader.Parameters.Fill(Header);
			TemplateAreaHeader.Parameters.CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany);
			TemplateAreaHeader.Parameters.DocumentNumber           = DocumentNumber;
	
			SpreadsheetDocument.Put(TemplateAreaHeader);

			// Output document title
			TitleOfDocumentLayoutArea.Parameters.Fill(Header);
			TitleOfDocumentLayoutArea.Parameters.CompilationDate = Header.DocumentDate;
			SpreadsheetDocument.Put(TitleOfDocumentLayoutArea);
	
			// Displaying table title
			SpreadsheetDocument.Put(TemplateAreaTableHeader);

			// Initialize totals in document
			TotalQuantityAccepted = 0;
			Num                    = 0;

			// Initialize page and string count
			PageNumber   = 1;
			LineNumber     = 0;
			LineCount = Header.Inventory.Unload().Count();
	
			// Displaying multiline part of the document
			While LinesSelectionInventory.Next() Do

				LineNumber = LineNumber + 1;

				TemplateAreaRow.Parameters.Fill(LinesSelectionInventory);

				TemplateAreaRow.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);

				// Check output
				RowWithFooter = New Array;
				If LineNumber = 1 Then
					RowWithFooter.Add(TemplateAreaTableHeader); // if the first string, then should
				EndIf;                                                   // fit title
				RowWithFooter.Add(TemplateAreaRow);
				If LineNumber = LineCount Then           // if the last string, should
					RowWithFooter.Add(LayoutOfAreaTotal);  // fit and document footer
					RowWithFooter.Add(TemplateAreaFooter);
				Else                                              // else - only strings footer
					RowWithFooter.Add(AreaLayoutFooterRows);
				EndIf;

				If LineNumber <> 1 AND Not SpreadsheetDocument.CheckPut(RowWithFooter) Then
					
					SpreadsheetDocument.PutHorizontalPageBreak();
					
					// Display table header
					PageNumber = PageNumber + 1;
					TemplateAreaTableHeader.Parameters.PageNumber = "Page " + PageNumber; 
					SpreadsheetDocument.Put(TemplateAreaTableHeader);
					
				EndIf;
				
				SpreadsheetDocument.Put(TemplateAreaRow);

				TotalQuantityAccepted = TotalQuantityAccepted + LinesSelectionInventory.Quantity;

			EndDo;

			// Output totals by document
			LayoutOfAreaTotal.Parameters.TotalQuantityAccepted = TotalQuantityAccepted;
			SpreadsheetDocument.Put(LayoutOfAreaTotal);

			// Output totals by document
			TemplateAreaFooter = Template.GetArea("Footer");
			TemplateAreaFooter.Parameters.Fill(Header);
			SpreadsheetDocument.Put(TemplateAreaFooter);
			
		ElsIf TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	GoodsReceipt.Date AS DocumentDate,
			|	GoodsReceipt.StructuralUnit AS WarehousePresentation,
			|	GoodsReceipt.Cell AS CellPresentation,
			|	GoodsReceipt.Number,
			|	GoodsReceipt.Company.Prefix AS Prefix,
			|	GoodsReceipt.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.Warehouse AS Warehouse,
			|		ProductsAndServices.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(GoodsReceipt.Inventory.ProductsAndServices.DescriptionFull AS String(100))) = """"
			|				THEN GoodsReceipt.Inventory.ProductsAndServices.Description
			|			ELSE GoodsReceipt.Inventory.ProductsAndServices.DescriptionFull
			|		END AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
			|		ConnectionKey
			|	),
			|	GoodsReceipt.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey		
			|	)
			|FROM
			|	Document.GoodsReceipt AS GoodsReceipt
			|WHERE
			|	GoodsReceipt.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_CreditSlip_BlankOfGoodsFilling";
                                          
			Template = PrintManagement.PrintedFormsTemplate("Document.GoodsReceipt.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;		
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "PURCHASE ORDER RECEIPT # "
													+ DocumentNumber
													+ " from "
													+ Format(Header.DocumentDate, "DLF=DD");
													
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.FunctionalOptionAccountingByCells.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = "Date and time of printing: "
												 	+ CurrentDate()
													+ ". User: "
													+ Users.CurrentUser();
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);			
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do

				If Not LinesSelectionInventory.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																		LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
						
				SpreadsheetDocument.Put(TemplateArea);
								
			EndDo;

			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);			
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceipt") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "GoodsReceipt", "Purchase order receipt", PrintForm(ObjectsArray, PrintObjects, "GoodsReceipt"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "M4") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "M4", "M-4", PrintForm(ObjectsArray, PrintObjects, "M4"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "M4";
	PrintCommand.Presentation = NStr("en='Purchase order receipt';ru='Приходный ордер'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "GoodsReceipt";
	PrintCommand.Presentation = NStr("en='Purchase order receipt';ru='Приходный ордер'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en='Merchandise filling form';ru='Бланк товарного наполнения'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 10;
	
EndProcedure

#EndRegion

#EndIf