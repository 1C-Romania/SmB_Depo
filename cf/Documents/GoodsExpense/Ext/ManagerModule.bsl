#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefGoodsExpense, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	GoodsExpenseInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	GoodsExpenseInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	GoodsExpenseInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN GoodsExpenseInventory.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	GoodsExpenseInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsExpenseInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN GoodsExpenseInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(GoodsExpenseInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN GoodsExpenseInventory.Quantity
	|		ELSE GoodsExpenseInventory.Quantity * GoodsExpenseInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.GoodsExpense.Inventory AS GoodsExpenseInventory
	|WHERE
	|	GoodsExpenseInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ref.StructuralUnit AS StructuralUnit,
	|	TableInventory.Ref.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	Document.GoodsExpense.Inventory AS TableInventory
	|		INNER JOIN Document.GoodsExpense.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND TableInventory.Ref = &Ref
	|	AND &UseSerialNumbers");
	
	Query.SetParameter("Ref", DocumentRefGoodsExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForExpenseFromWarehouses", ResultsArray[0].Unload());
	
	// Serial numbers
	QueryResult1 = ResultsArray[1].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", QueryResult1);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult1);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefGoodsExpense, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefGoodsExpense, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange", "RegisterRecordsInventoryChange"
	// temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then

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
		|				(Company, StructuralUnit, ProductsAndServices, Characteristic, Batch, Cell) IN
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.ProductsAndServices AS ProductsAndServicesPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS CellаPresentation,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS QuantityBalanceSerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.ProductsAndServices = SerialNumbersBalance.ProductsAndServices
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");

		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If NOT ResultsArray[0].IsEmpty()
			OR NOT ResultsArray[1].IsEmpty() Then
			DocumentObjectGoodsExpense = DocumentRefGoodsExpense.GetObject();
		EndIf;
			
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectGoodsExpense, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectGoodsExpense, QueryResultSelection, Cancel);
		EndIf;		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;

	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "GoodsExpense" Then
		
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	GoodsExpense.Date AS DocumentDate,
			|	GoodsExpense.Company AS Company,
			|	GoodsExpense.Number AS Number,
			|	GoodsExpense.Company.Prefix AS Prefix,
			|	GoodsExpense.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.DescriptionFull AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit AS StorageUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ConnectionKey
			|	),
			|	GoodsExpense.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.GoodsExpense AS GoodsExpense
			|WHERE
			|	GoodsExpense.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();

			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_GoodsExpense_GoodsExpense";
                                          
			Template = PrintManagement.PrintedFormsTemplate("Document.GoodsExpense.PF_MXL_GoodsExpense");

			InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);

			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;		
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "Good expense No. "
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
			
		ElsIf TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	GoodsExpense.Date AS DocumentDate,
			|	GoodsExpense.StructuralUnit AS WarehousePresentation,
			|	GoodsExpense.Number AS Number,
			|	GoodsExpense.Company.Prefix AS Prefix,
			|	GoodsExpense.Cell AS CellPresentation,
			|	GoodsExpense.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.Warehouse AS Warehouse,
			|		ProductsAndServices.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(GoodsExpense.Inventory.ProductsAndServices.DescriptionFull AS STRING(100))) = """"
			|				THEN GoodsExpense.Inventory.ProductsAndServices.Description
			|			ELSE GoodsExpense.Inventory.ProductsAndServices.DescriptionFull
			|		END AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
			|		ConnectionKey
			|	),
			|	GoodsExpense.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.GoodsExpense AS GoodsExpense
			|WHERE
			|	GoodsExpense.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();

			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_GoodsExpense_BlankOfGoodsFilling";
                                          
			Template = PrintManagement.PrintedFormsTemplate("Document.GoodsExpense.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;		
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "Good expense No. "
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
//   TemplateNames   - String    - Names of layouts separated by commas 
//   ObjectsArray    - Array    - Array of refs to objects that need to be printed
//   PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated table documents 
//   OutputParameters     - Structure    - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsExpense") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "GoodsExpense", "Goods expense", PrintForm(ObjectsArray, PrintObjects, "GoodsExpense"));
		
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
	PrintCommand.ID = "GoodsExpense";
	PrintCommand.Presentation = NStr("en='Issue slip';ru='Расходный ордер'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en='Goods content form';ru='Бланк товарного наполнения'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
EndProcedure

#EndRegion

#EndIf