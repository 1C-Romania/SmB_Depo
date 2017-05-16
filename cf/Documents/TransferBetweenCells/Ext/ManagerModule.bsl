#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefTransferBetweenCells, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	InventoryByCellsTransfer.LineNumber AS LineNumber,
	|	InventoryByCellsTransfer.ConnectionKey AS ConnectionKey,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryByCellsTransfer.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryByCellsTransfer.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN InventoryByCellsTransfer.Ref.OperationKind = VALUE(Enum.OperationKindsTransferBetweenCells.FromOneToSeveral)
	|			THEN InventoryByCellsTransfer.Ref.Cell
	|		ELSE InventoryByCellsTransfer.Cell
	|	END AS Cell,
	|	CASE
	|		WHEN InventoryByCellsTransfer.Ref.OperationKind = VALUE(Enum.OperationKindsTransferBetweenCells.FromOneToSeveral)
	|			THEN InventoryByCellsTransfer.Cell
	|		ELSE InventoryByCellsTransfer.Ref.Cell
	|	END AS CellPayee,
	|	InventoryByCellsTransfer.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryByCellsTransfer.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryByCellsTransfer.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryByCellsTransfer.Quantity AS Quantity
	|FROM
	|	Document.TransferBetweenCells.Inventory AS InventoryByCellsTransfer
	|WHERE
	|	InventoryByCellsTransfer.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Record) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic
	|FROM
	|	Document.TransferBetweenCells.Inventory AS TableInventory
	|		INNER JOIN Document.TransferBetweenCells.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN TableInventory.Ref.OperationKind = VALUE(Enum.OperationKindsTransferBetweenCells.FromOneToSeveral)
	|			THEN TableInventory.Ref.Cell
	|		ELSE TableInventory.Cell
	|	END AS Cell,
	|	1 AS Quantity
	|FROM
	|	Document.TransferBetweenCells.Inventory AS TableInventory
	|		INNER JOIN Document.TransferBetweenCells.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.Ref.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableSerialNumbers.SerialNumber,
	|	&Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ref.StructuralUnit,
	|	CASE
	|		WHEN TableInventory.Ref.OperationKind = VALUE(Enum.OperationKindsTransferBetweenCells.FromOneToSeveral)
	|			THEN TableInventory.Cell
	|		ELSE TableInventory.Ref.Cell
	|	END,
	|	1
	|FROM
	|	Document.TransferBetweenCells.Inventory AS TableInventory
	|		INNER JOIN Document.TransferBetweenCells.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers");
	
	Query.SetParameter("Ref", DocumentRefTransferBetweenCells);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[0].Unload());
	
	Selection = ResultsArray[0].Select();
	While Selection.Next() Do
			
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.RecordType = AccumulationRecordType.Receipt;
		NewRow.Cell = Selection.CellPayee;
		
	EndDo;
	
	// Serial numbers
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersGuarantees", ResultsArray[1].Unload());
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", ResultsArray[2].Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefTransferBetweenCells, AdditionalProperties, Cancel, PostingDelete = False) Export
	
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
			DocumentObjectTransferBetweenCells = DocumentRefTransferBetweenCells.GetObject();
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocumentObjectTransferBetweenCells, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;

EndProcedure // RunControl()

#Region PrintInterface

// Procedure of generating
//tabular document
Procedure GenerateInventoryTransferInCells(CurrentDocument, SpreadsheetDocument, TemplateName)
	
	FillStructureSection = New Structure;
	
	Query = New Query;
	Query.SetParameter("CurrentDocument", CurrentDocument);
	Query.Text =
	"SELECT
	|	TransferBetweenCells.Number AS DocumentNumber,
	|	TransferBetweenCells.Date AS DocumentDate,
	|	TransferBetweenCells.OperationKind AS OperationKind,
	|	TransferBetweenCells.Company AS Company,
	|	TransferBetweenCells.Company.Prefix AS Prefix,
	|	TransferBetweenCells.StructuralUnit AS StructuralUnit,
	|	TransferBetweenCells.StructuralUnit.FRP AS FRP,
	|	TransferBetweenCells.Cell AS Cell
	|FROM
	|	Document.TransferBetweenCells AS TransferBetweenCells
	|WHERE
	|	TransferBetweenCells.Ref = &CurrentDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryByCellsTransfer.LineNumber,
	|	InventoryByCellsTransfer.Cell,
	|	InventoryByCellsTransfer.ProductsAndServices.Code AS ProductsAndServicesCode,
	|	InventoryByCellsTransfer.ProductsAndServices.SKU AS ProductsAndServicesSKU,
	|	InventoryByCellsTransfer.ProductsAndServices,
	|	InventoryByCellsTransfer.Characteristic,
	|	PRESENTATION(InventoryByCellsTransfer.Batch) AS Batch,
	|	InventoryByCellsTransfer.Quantity,
	|	InventoryByCellsTransfer.MeasurementUnit,
	|	InventoryByCellsTransfer.ConnectionKey
	|FROM
	|	Document.TransferBetweenCells.Inventory AS InventoryByCellsTransfer
	|WHERE
	|	InventoryByCellsTransfer.Ref = &CurrentDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryByCellsTransfer.Ref,
	|	MAX(InventoryByCellsTransfer.LineNumber) AS PositionsQuantity,
	|	SUM(InventoryByCellsTransfer.Quantity) AS TotalQuantity
	|FROM
	|	Document.TransferBetweenCells.Inventory AS InventoryByCellsTransfer
	|WHERE
	|	InventoryByCellsTransfer.Ref = &CurrentDocument
	|
	|GROUP BY
	|	InventoryByCellsTransfer.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TransferBetweenCellsSerialNumbers.SerialNumber,
	|	TransferBetweenCellsSerialNumbers.ConnectionKey
	|FROM
	|	Document.TransferBetweenCells.SerialNumbers AS TransferBetweenCellsSerialNumbers
	|WHERE
	|	TransferBetweenCellsSerialNumbers.Ref = &CurrentDocument";
	
	ExecutionResult = Query.ExecuteBatch();
	
	DocumentHeader = ExecutionResult[0].Select();
	DocumentHeader.Next();
	
	TabularSection = ExecutionResult[1].Select();
	
	TotalsSelection = ExecutionResult[2].Select();
	TotalsSelection.Next();
	
	SelectionSerialNumbers = ExecutionResult[3].Select();
	
	SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_" + TemplateName + "_" + TemplateName;
	Template = PrintManagement.PrintedFormsTemplate("Document.TransferBetweenCells." + TemplateName);
	
	//::: Title
	TemplateArea = Template.GetArea("Title");
	If DocumentHeader.DocumentDate < Date('20110101') Then
		
		DocumentNumber = SmallBusinessServer.GetNumberForPrinting(DocumentHeader.DocumentNumber, DocumentHeader.Prefix);
		
	Else
		
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(DocumentHeader.DocumentNumber, True, True);
		
	EndIf;
	
	HeaderText = NStr("ru = 'Перемещение запасов по ячейкам № '; en = 'Inventory transfer between cells No'") + DocumentHeader.DocumentNumber + NStr("ru = ' от '; en = ' dated '") + Format(DocumentHeader.DocumentDate, "DLF=DD");
	FillStructureSection.Insert("HeaderText", HeaderText);
	FillStructureSection.Insert("StructuralUnit", DocumentHeader.StructuralUnit);
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
	//::: Table header
	TemplateArea = Template.GetArea("TableHeader");
	FillStructureSection.Clear();
	
	FillStructureSection.Insert("TransferKind", NStr("ru = 'Вид перемещения: '; en = 'Transfer kind: '") + String(DocumentHeader.OperationKind));
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
	//::: Table strings
	TemplateArea = Template.GetArea("TableRow");
	IsMoveFromOneToSeveral = (DocumentHeader.OperationKind = Enums.OperationKindsTransferBetweenCells.FromOneToSeveral);
	While TabularSection.Next() Do
		
		FillStructureSection.Clear();
		FillStructureSection.Insert("LineNumber", TabularSection.LineNumber);
		
		CellSender = ?(IsMoveFromOneToSeveral,	DocumentHeader.Cell, TabularSection.Cell);
		CellReceive = ?(IsMoveFromOneToSeveral, 	TabularSection.Cell, DocumentHeader.Cell);
		
		FillStructureSection.Insert("CellSender", CellSender);
		FillStructureSection.Insert("CellReceive", CellReceive);
		
		StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(SelectionSerialNumbers, TabularSection.ConnectionKey);
		PresentationOfProductsAndServices = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
			TabularSection.ProductsAndServices,
			TabularSection.Characteristic,
			TabularSection.ProductsAndServicesSKU,
			StringSerialNumbers);
		
		FillStructureSection.Insert("PresentationOfProductsAndServices", PresentationOfProductsAndServices);
		FillStructureSection.Insert("BatchPresentation", TabularSection.Batch);
		FillStructureSection.Insert("Quantity", TabularSection.Quantity);
		FillStructureSection.Insert("MeasurementUnit", TabularSection.MeasurementUnit);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
	EndDo;
	
	//::: Table footer
	TemplateArea = Template.GetArea("TableFooter");
	FillStructureSection.Clear();
	
	FillStructureSection.Insert("TotalQuantity", TotalsSelection.TotalQuantity);
	
	If TotalsSelection.TotalQuantity = 0 Then
		
		InventoryTransferredCountInWords = NStr("ru = 'В документе не указаны перемещаемые запасы.'; en = 'Transferred inventories are not specified in the document.'");
		
	ElsIf IsMoveFromOneToSeveral Then
		
		InventoryTransferredCountInWords = NStr("ru = 'Из ячейки ""%1"" изъято позиций: %2.
		|Общим количеством: %3.'; en = 'Positions withdrawn from cell ""%1"": %2.
		|General quantity: %3'");
		
	Else
		
		InventoryTransferredCountInWords = NStr("ru = 'В ячейку ""%1"" поступило позиций: %2.
		|Общим количеством: %3.'; en = 'Positions delivered to cell ""%1"": %2.
		|General quantity: %3'");
		
	EndIf;
	
	InventoryTransferredCountInWords = 
		StringFunctionsClientServer.SubstituteParametersInString(InventoryTransferredCountInWords
			,DocumentHeader.Cell
			,?(TotalsSelection.PositionsQuantity = Undefined, 0, TotalsSelection.PositionsQuantity)
			,NumberInWords(?(TotalsSelection.TotalQuantity = Undefined, 0, TotalsSelection.TotalQuantity), "L= ru_RU;SN=true;FN=false;FS=false", "unit, unit, units, f, , , , , 0")
		);
	
	FillStructureSection.Insert("InventoryTransferredCountInWords", InventoryTransferredCountInWords);
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
	//::: Signatures
	TemplateArea = Template.GetArea("Signatures");
	FillStructureSection.Clear();
	
	MRPPresentation = InformationRegisters.IndividualsDescriptionFull.IndividualDescriptionFull(DocumentHeader.DocumentDate, DocumentHeader.FRP);
	
	FillStructureSection.Insert("ResponsiblePresentation", MRPPresentation);
	FillStructureSection.Insert("ReceivedPresentation", MRPPresentation);
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
EndProcedure // GenerateInventoryTransferInCells()

// Document printing procedure
//
Function DocumentPrinting(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	FirstDocument = True;
	FirstLineNumber = 0;
	
	For Each CurrentDocument IN ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "PF_MXL_TransferBetweenCells" Then
			
			GenerateInventoryTransferInCells(CurrentDocument, SpreadsheetDocument, TemplateName);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	Return SpreadsheetDocument;

EndFunction // DocumentPrinting()

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
	
	FillInParametersOfElectronicMail = True;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "TransferBetweenCells") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "TransferBetweenCells", "Inventory transfer between locations", DocumentPrinting(ObjectsArray, PrintObjects, "PF_MXL_TransferBetweenCells"));
		
	EndIf;
	
	// parameters of sending printing forms by email
	If FillInParametersOfElectronicMail Then
		
		SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
		
	EndIf;
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "TransferBetweenCells";
	PrintCommand.Presentation = NStr("en='Inventory transfer between locations';ru='Перемещение запасов по ячейкам'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf