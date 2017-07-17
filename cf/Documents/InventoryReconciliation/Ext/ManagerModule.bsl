#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument
// 			   in which printing form will be displayed.
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
		
		If TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	InventoryReconciliation.Date AS DocumentDate,
			|	InventoryReconciliation.StructuralUnit AS WarehousePresentation,
			|	InventoryReconciliation.Cell AS CellPresentation,
			|	InventoryReconciliation.Number,
			|	InventoryReconciliation.Company.Prefix AS Prefix,
			|	InventoryReconciliation.Inventory.(
			|		LineNumber AS LineNumber,
			|		ProductsAndServices.Warehouse AS Warehouse,
			|		ProductsAndServices.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull AS String(100))) = """"
			|				THEN InventoryReconciliation.Inventory.ProductsAndServices.Description
			|			ELSE InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull
			|		END AS InventoryItem,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
			|		ConnectionKey
			|	),
			|	InventoryReconciliation.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryReconciliation AS InventoryReconciliation
			|WHERE
			|	InventoryReconciliation.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryOfInventory_FormOfFilling";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryReconciliation.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = NStr("ru = 'Инвентаризация запасов № '; en = 'Inventory survey No'") + 
												 DocumentNumber + 
												 NStr("ru = ' от '; en = ' dated '") + 
												 Format(Header.DocumentDate, "DLF=DD");
			
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
			TemplateArea.Parameters.PrintingTime = 	NStr("ru = 'Дата и время печати: '; en = 'Date and time of printing: '") +
													CurrentDate() + 
													NStr("ru = '. Пользователь: '; en = '. User: '") + 
													Users.CurrentUser();
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
			
		ElsIf TemplateName = "InventoryReconciliation" Then
			
			PrintingCurrency = Constants.AccountingCurrency.Get();
			
			Query = New Query;
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text =
			"SELECT
			|	InventoryReconciliation.Number,
			|	InventoryReconciliation.Date AS DocumentDate,
			|	InventoryReconciliation.Company,
			|	InventoryReconciliation.StructuralUnit.Presentation AS WarehousePresentation,
			|	InventoryReconciliation.Company.Prefix AS Prefix,
			|	InventoryReconciliation.Inventory.(
			|		LineNumber,
			|		ProductsAndServices,
			|		CASE
			|			WHEN (CAST(InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN InventoryReconciliation.Inventory.ProductsAndServices.Description
			|			ELSE CAST(InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull AS String(1000))
			|		END AS Product,
			|		Characteristic,
			|		ProductsAndServices.SKU AS SKU,
			|		Quantity AS Quantity,
			|		QuantityAccounting AS AccountingCount,
			|		Deviation AS Deviation,
			|		MeasurementUnit AS MeasurementUnit,
			|		Price,
			|		Amount,
			|		AmountAccounting AS AmountByAccounting
			|	)
			|FROM
			|	Document.InventoryReconciliation AS InventoryReconciliation
			|WHERE
			|	InventoryReconciliation.Ref = &CurrentDocument
			|
			|ORDER BY
			|	InventoryReconciliation.Inventory.LineNumber";
			
			Header = Query.Execute().Select();
			
			Header.Next();
			
			StringSelectionProducts = Header.Inventory.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryInventory_InventoryInventory";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryReconciliation.PF_MXL_InventoryReconciliation");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			// Displaying invoice header
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = NStr("ru = 'Инвентаризация запасов № '; en = 'Inventory survey No'") + DocumentNumber + NStr("ru = ' от '; en = ' dated '") + Format(Header.DocumentDate, "DLF=DD");
			SpreadsheetDocument.Put(TemplateArea);
			
			// Output company and warehouse data
			TemplateArea = Template.GetArea("Vendor");
			TemplateArea.Parameters.Fill(Header);
			
			InfoAboutCompany    = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
			CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
			TemplateArea.Parameters.CompanyPresentation = CompanyPresentation;
			
			TemplateArea.Parameters.CurrencyName = String(PrintingCurrency);
			TemplateArea.Parameters.Currency             = PrintingCurrency;
			SpreadsheetDocument.Put(TemplateArea);

			// Output table header.
			TemplateArea = Template.GetArea("TableHeader");
			TemplateArea.Parameters.Fill(Header);
			SpreadsheetDocument.Put(TemplateArea);
			
			TotalAmount        = 0;
			TotalAmountByAccounting = 0;

			TemplateArea = Template.GetArea("String");
			While StringSelectionProducts.Next() Do

				TemplateArea.Parameters.Fill(StringSelectionProducts);
				TemplateArea.Parameters.Product = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(StringSelectionProducts.Product, 
																		StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
				TotalAmount        = TotalAmount        + StringSelectionProducts.Amount;
				TotalAmountByAccounting = TotalAmountByAccounting + StringSelectionProducts.AmountByAccounting;
				SpreadsheetDocument.Put(TemplateArea);

			EndDo;

			// Output Total
			TemplateArea                        = Template.GetArea("Total");
			TemplateArea.Parameters.Total        = SmallBusinessServer.AmountsFormat(TotalAmount);
			TemplateArea.Parameters.TotalByAccounting = SmallBusinessServer.AmountsFormat(TotalAmountByAccounting);
			SpreadsheetDocument.Put(TemplateArea);

			// Output signatures to document
			TemplateArea = Template.GetArea("Signatures");
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "InventoryReconciliation") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "InventoryReconciliation", "Inventory reconciliation", PrintForm(ObjectsArray, PrintObjects, "InventoryReconciliation"));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure // Print()

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "InventoryReconciliation";
	PrintCommand.Presentation = NStr("en='Physical inventory';ru='Инвентаризации запасов'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en='Goods content form';ru='Бланк товарного наполнения'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 17;
	
EndProcedure

#EndRegion

#EndIf