#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

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
			|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
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
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryOfInventory_FormOfFilling";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryReconciliation.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "Inventory survey No "
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
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
					LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);	
			
		ElsIf TemplateName = "INV3" OR TemplateName = "INV3WithoutFactData" Then
			
			PrintingCurrency = Constants.NationalCurrency.Get();
			
			Query = New Query;
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.SetParameter("Date", CurrentDocument.Date);
			Query.Text =
			"SELECT
			|	InventoryReconciliation.Number AS Number,
			|	InventoryReconciliation.Date AS DocumentDate,
			|	InventoryReconciliation.Date AS BeginDateOfInventory,
			|	InventoryReconciliation.Date AS EndDateOfInventory,
			|	InventoryReconciliation.StructuralUnit.FRP AS ResponsiblePerson,
			|	InventoryReconciliation.Company,
			|	InventoryReconciliation.StructuralUnit.Presentation AS Division,
			|	InventoryReconciliation.Company.Prefix AS Prefix,
			|	InventoryReconciliation.Inventory.(
			|		LineNumber AS Number,
			|		ProductsAndServices,
			|		CASE
			|			WHEN (CAST(InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN InventoryReconciliation.Inventory.ProductsAndServices.Description
			|			ELSE CAST(InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull AS String(1000))
			|		END AS ProductDescription,
			|		Characteristic,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS ProductCode,
			|		ProductsAndServices.MeasurementUnit.Description AS MeasurementUnitDescription,
			|		ProductsAndServices.MeasurementUnit.Code AS MeasurementUnitCodeByOKEI,
			|		ProductsAndServices.InventoryGLAccount.Code AS SubAccount,
			|		CAST(CASE
			|				WHEN Constants.AccountingCurrency = Constants.NationalCurrency
			|					THEN InventoryReconciliation.Inventory.Price
			|				ELSE InventoryReconciliation.Inventory.Price * ManagCurrencyRates.ExchangeRate / ManagCurrencyRates.Multiplicity
			|			END AS NUMBER(15, 2)) AS Price,
			|		Quantity AS FactCount,
			|		QuantityAccounting AS AccCount,
			|		CAST(CASE
			|				WHEN Constants.AccountingCurrency = Constants.NationalCurrency
			|					THEN InventoryReconciliation.Inventory.Amount
			|				ELSE InventoryReconciliation.Inventory.Amount * ManagCurrencyRates.ExchangeRate / ManagCurrencyRates.Multiplicity
			|			END AS NUMBER(15, 2)) AS FactAmount,
			|		CAST(CASE
			|				WHEN Constants.AccountingCurrency = Constants.NationalCurrency
			|					THEN InventoryReconciliation.Inventory.AmountAccounting
			|				ELSE InventoryReconciliation.Inventory.AmountAccounting * ManagCurrencyRates.ExchangeRate / ManagCurrencyRates.Multiplicity
			|			END AS NUMBER(15, 2)) AS AccSum
			|	)
			|FROM
			|	Document.InventoryReconciliation AS InventoryReconciliation
			|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
			|				&Date,
			|				Currency In
			|					(SELECT
			|						ConstantAccountingCurrency.Value
			|					FROM
			|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
			|		ON (TRUE),
			|	Constants AS Constants
			|WHERE
			|	InventoryReconciliation.Ref = &CurrentDocument
			|
			|ORDER BY
			|	InventoryReconciliation.Inventory.LineNumber";
			Header = Query.Execute().Select();
			
			Header.Next();
			
			StringSelectionProducts = Header.Inventory.Select();
			
			// Specify default layout parameters
			SpreadsheetDocument.TopMargin              = 10;
			SpreadsheetDocument.LeftMargin               = 0;
			SpreadsheetDocument.BottomMargin               = 0;
			SpreadsheetDocument.RightMargin              = 0;
			SpreadsheetDocument.HeaderSize = 10;
			SpreadsheetDocument.PageOrientation      = PageOrientation.Landscape;
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryOFInventory_INV3";
			Template       = PrintManagement.PrintedFormsTemplate("Document.InventoryReconciliation.PF_MXL_INV3");
			
			//////////////////////////////////////////////////////////////////////
			// 1st form page
			
			// Displaying invoice header
			TemplateArea = Template.GetArea("Header");
			TemplateArea.Parameters.Fill(Header);
			
			InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
			CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
			TemplateArea.Parameters.CompanyPresentation = CompanyPresentation;
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;		
			
			TemplateArea.Parameters.CompanyByOKPO        = InfoAboutCompany.CodeByOKPO;
			TemplateArea.Parameters.DocumentDate            = Header.DocumentDate;
			TemplateArea.Parameters.DocumentNumber           = DocumentNumber;
			TemplateArea.Parameters.EndDateOfInventoryLocalFormat = Header.EndDateOfInventory; 
			
			ICData = SmallBusinessServer.IndData(Header.Company, Header.ResponsiblePerson, Header.DocumentDate);
			TemplateArea.Parameters.PostFRP1     = ICData.Position;
			TemplateArea.Parameters.PAName1           = ICData.Presentation;	
			
			SpreadsheetDocument.Put(TemplateArea);
			SpreadsheetDocument.PutHorizontalPageBreak();
			
			//////////////////////////////////////////////////////////////////////
			// 2nd form page
			
			TotalFactQuantity = 0;
			TotalFactAmount      = 0;
			TotalRealSumTotal = 0;
			TotalAccQuantity  = 0;
			TotalAccSum       = 0;
			
			RowsOnPageQty = 0;
			QuantityOnPage      = 0;
			SheetAmount           = 0;
			TotalNumber           = 0;
			
			PageNumber = 2;
			Num = 0;
			
			// Displaying table title
			TableTitle = Template.GetArea("TableTitle");
			TableTitle.Parameters.PageNumber = "Page " + PageNumber; 
			SpreadsheetDocument.Put(TableTitle);
			
			// Displaying multiline part of the document
			FooterPages  = Template.GetArea("FooterPages");	
			
			While StringSelectionProducts.Next() Do
				
				Num = Num + 1;
				TableRow   = Template.GetArea("String");
				TableRow.Parameters.Fill(StringSelectionProducts);
				TableRow.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(StringSelectionProducts.ProductDescription, 
				StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
				
				If TemplateName = "INV3WithoutFactData" Then
					TableRow.Parameters.FactCount = "";
					TableRow.Parameters.FactAmount = "";	
				EndIf;
				
				RowWithFooter = New Array;
				RowWithFooter.Add(TableRow);
				RowWithFooter.Add(FooterPages);
				
				If Not SpreadsheetDocument.CheckPut(RowWithFooter) Then
					
					TotalsAreaByPage = Template.GetArea("FooterPages");
					
					If TemplateName = "INV3" Then
						TotalsAreaByPage.Parameters.TotalFactCount = TotalFactQuantity;
						TotalsAreaByPage.Parameters.TotalAmountOfFact      = TotalFactAmount;	
					EndIf;
					TotalsAreaByPage.Parameters.TotalAccountingCount  = TotalAccQuantity;
					TotalsAreaByPage.Parameters.TotalAccountingSum       = TotalAccSum;
					
					TotalsAreaByPage.Parameters.CountOfSequenceNumbersInWordsOnPage     = NumberInWords(RowsOnPageQty, ,",,,,,,,,0");
					If TemplateName = "INV3" Then
						TotalsAreaByPage.Parameters.CountTotalUnitsActuallyOnPageInWords = SmallBusinessServer.QuantityInWords(QuantityOnPage);
						TotalsAreaByPage.Parameters.RealAmountOnPageInWords                 = WorkWithCurrencyRates.GenerateAmountInWords(SheetAmount, PrintingCurrency);	
					EndIf;
					
					SpreadsheetDocument.Put(TotalsAreaByPage);
					
					PageNumber = PageNumber + 1;
					SpreadsheetDocument.PutHorizontalPageBreak();
					
					TableTitle.Parameters.PageNumber = "Page " + PageNumber;
					SpreadsheetDocument.Put(TableTitle);
					
					TotalFactQuantity = 0;
					TotalFactAmount      = 0;
					TotalAccQuantity  = 0;
					TotalAccSum       = 0;
					
					RowsOnPageQty = 0;
					QuantityOnPage      = 0;
					SheetAmount           = 0;
					
				EndIf;
				
				TableRow.Parameters.Number = Num;
				
				SpreadsheetDocument.Put(TableRow);
				
				If TemplateName = "INV3" Then
					TotalFactQuantity = TotalFactQuantity + StringSelectionProducts.FactCount;
					TotalFactAmount      = TotalFactAmount      + StringSelectionProducts.FactAmount;
					TotalRealSumTotal = TotalRealSumTotal + StringSelectionProducts.FactAmount;
				EndIf;
				TotalAccQuantity  = TotalAccQuantity  + StringSelectionProducts.AccCount;
				TotalAccSum       = TotalAccSum       + StringSelectionProducts.AccSum;
				TotalNumber         = TotalNumber         + StringSelectionProducts.FactCount;
				
				RowsOnPageQty = RowsOnPageQty + 1;
				QuantityOnPage      = QuantityOnPage      + StringSelectionProducts.FactCount;
				SheetAmount           = SheetAmount           + StringSelectionProducts.FactAmount;
				
			EndDo;
			
			// Display totals on the last page
			TotalsAreaByPage = Template.GetArea("FooterPages");
			
			If TemplateName = "INV3" Then
				TotalsAreaByPage.Parameters.TotalFactCount  = TotalFactQuantity;
				TotalsAreaByPage.Parameters.TotalAmountOfFact       = TotalFactAmount;
				TotalsAreaByPage.Parameters.CountTotalUnitsActuallyOnPageInWords = SmallBusinessServer.QuantityInWords(QuantityOnPage);
				TotalsAreaByPage.Parameters.RealAmountOnPageInWords                 = WorkWithCurrencyRates.GenerateAmountInWords(SheetAmount, PrintingCurrency);
			EndIf;
			TotalsAreaByPage.Parameters.TotalAccountingCount   = TotalAccQuantity;
			TotalsAreaByPage.Parameters.TotalAccountingSum        = TotalAccSum;
			TotalsAreaByPage.Parameters.CountOfSequenceNumbersInWordsOnPage     = NumberInWords(RowsOnPageQty, ,",,,,,,,,0");
			SpreadsheetDocument.Put(TotalsAreaByPage);
			
			// Display the footer of the document
			SpreadsheetDocument.PutHorizontalPageBreak();
			TemplateArea = Template.GetArea("FooterDescription");
			TemplateArea.Parameters.Fill(Header);
			If TemplateName = "INV3" Then
				TemplateArea.Parameters.CountTotalUnitsActuallyOnPageInWords = SmallBusinessServer.QuantityInWords(TotalNumber);
				TemplateArea.Parameters.RealAmountOnPageInWords                 = WorkWithCurrencyRates.GenerateAmountInWords(TotalRealSumTotal, PrintingCurrency);
			EndIf;
			TemplateArea.Parameters.CountOfSequenceNumbersInWordsOnPage     = NumberInWords(StringSelectionProducts.Count(), ,",,,,,,,,0");
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("FooterDescriptionFRP");
			TemplateArea.Parameters.Fill(Header);
			TemplateArea.Parameters.StartingSerialNumber = 1;
			TemplateArea.Parameters.NumberEnd              = StringSelectionProducts.Count();
			
			TemplateArea.Parameters.PostFRP1   = ICData.Position;
			TemplateArea.Parameters.PAName1         = ICData.Presentation;
			
			TemplateArea.Parameters.DocumentDate 	= Header.DocumentDate;
			
			SpreadsheetDocument.Put(TemplateArea);	
			
		ElsIf TemplateName = "INV19" Then
			
			PrintingCurrency = Constants.NationalCurrency.Get();

			Query       = New Query;
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.SetParameter("Date", CurrentDocument.Date);
			Query.Text =
			"SELECT
			|	InventoryReconciliation.Number AS Number,
			|	InventoryReconciliation.Date AS DocumentDate,
			|	InventoryReconciliation.Date AS BeginDateOfInventory,
			|	InventoryReconciliation.Date AS EndDateOfInventory,
			|	InventoryReconciliation.StructuralUnit.FRP AS ResponsiblePerson,
			|	InventoryReconciliation.Company,
			|	InventoryReconciliation.Company AS Heads,
			|	InventoryReconciliation.StructuralUnit.Presentation AS DivisionsPresentation,
			|	InventoryReconciliation.Company.Prefix AS Prefix,
			|	InventoryReconciliation.Inventory.(
			|		LineNumber AS Number,
			|		ProductsAndServices,
			|		CASE
			|			WHEN (CAST(InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull AS String(1000))) = """"
			|				THEN InventoryReconciliation.Inventory.ProductsAndServices.Description
			|			ELSE CAST(InventoryReconciliation.Inventory.ProductsAndServices.DescriptionFull AS String(1000))
			|		END AS ProductDescription,
			|		Characteristic,
			|		ProductsAndServices.SKU AS SKU,
			|		ProductsAndServices.Code AS ProductCode,
			|		ProductsAndServices.MeasurementUnit.Presentation AS MeasurementUnitDescription,
			|		ProductsAndServices.MeasurementUnit.Code AS MeasurementUnitCodeByOKEI,
			|		CAST(CASE
			|				WHEN Constants.AccountingCurrency = Constants.NationalCurrency
			|					THEN InventoryReconciliation.Inventory.Price
			|				ELSE InventoryReconciliation.Inventory.Price * ManagCurrencyRates.ExchangeRate / ManagCurrencyRates.Multiplicity
			|			END AS NUMBER(15, 2)) AS Price,
			|		Quantity AS FactCount,
			|		QuantityAccounting AS AccCount,
			|		CAST(CASE
			|				WHEN Constants.AccountingCurrency = Constants.NationalCurrency
			|					THEN InventoryReconciliation.Inventory.Amount
			|				ELSE InventoryReconciliation.Inventory.Amount * ManagCurrencyRates.ExchangeRate / ManagCurrencyRates.Multiplicity
			|			END AS NUMBER(15, 2)) AS FactAmount,
			|		CAST(CASE
			|				WHEN Constants.AccountingCurrency = Constants.NationalCurrency
			|					THEN InventoryReconciliation.Inventory.AmountAccounting
			|				ELSE InventoryReconciliation.Inventory.AmountAccounting * ManagCurrencyRates.ExchangeRate / ManagCurrencyRates.Multiplicity
			|			END AS NUMBER(15, 2)) AS AccSum
			|	)
			|FROM
			|	Document.InventoryReconciliation AS InventoryReconciliation
			|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
			|				&Date,
			|				Currency In
			|					(SELECT
			|						ConstantAccountingCurrency.Value
			|					FROM
			|						Constant.AccountingCurrency AS ConstantAccountingCurrency)) AS ManagCurrencyRates
			|		ON (TRUE),
			|	Constants AS Constants
			|WHERE
			|	InventoryReconciliation.Ref = &CurrentDocument
			|
			|ORDER BY
			|	InventoryReconciliation.Inventory.LineNumber";

			Header = Query.Execute().Select();
			Header.Next();
			StringSelectionProducts = Header.Inventory.Select();

			// Printing parameters.
			SpreadsheetDocument.TopMargin = 0;
			SpreadsheetDocument.LeftMargin  = 0;
			SpreadsheetDocument.BottomMargin  = 0;
			SpreadsheetDocument.RightMargin = 0;
			SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryInventoryOf_INV19";
			
			// Receive layout areas.
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryReconciliation.PF_MXL_INV19");
			
			TemplateAreaHeader            = Template.GetArea("Header");
			TemplateAreaTableHeader = Template.GetArea("TableHeader1");
			TemplateAreaRow           = Template.GetArea("TableString1");
			TemplateAreaTotalByPage  = Template.GetArea("TotalTables1");
			TemplateAreaFooter           = Template.GetArea("Footer");

			// Output document header.
			TemplateAreaHeader.Parameters.Fill(Header);
			
			InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
			CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
			TemplateAreaHeader.Parameters.CompanyPresentation = CompanyPresentation;
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;		
			
			TemplateAreaHeader.Parameters.CompanyByOKPO        = InfoAboutCompany.CodeByOKPO;
			TemplateAreaHeader.Parameters.DocumentDate            = Header.DocumentDate;
			TemplateAreaHeader.Parameters.BeginDateOfInventory = Header.BeginDateOfInventory;
			TemplateAreaHeader.Parameters.DocumentNumber           = DocumentNumber;
			
			ICData = SmallBusinessServer.IndData(Header.Company, Header.ResponsiblePerson, Header.DocumentDate);
			TemplateAreaHeader.Parameters.PostFRP1     = ICData.Position;
			TemplateAreaHeader.Parameters.PAName1           = ICData.Presentation;

			Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Header.Heads, Header.DocumentDate);
			Head = Heads.HeadDescriptionFull;
			Accountant    = Heads.ChiefAccountantNameAndSurname;

			SpreadsheetDocument.Put(TemplateAreaHeader);
			SpreadsheetDocument.PutHorizontalPageBreak();

			PageNumber   = 2;
			LineNumber     = 1;
			LineCount = StringSelectionProducts.Count();

			TotalAmountResultExceedCount   = 0;
			TotalResultSumExcess        = 0;
			TotalResultShortageAmount = 0;
			TotalAmountResultLossAmount      = 0;

			// Output table title.
			TemplateAreaTableHeader.Parameters.PageNumber = "Page " + PageNumber; 
			SpreadsheetDocument.Put(TemplateAreaTableHeader);

			// Output multiline document section.
			While StringSelectionProducts.Next() Do

				TemplateAreaRow.Parameters.Fill(StringSelectionProducts);
				TemplateAreaRow.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(StringSelectionProducts.ProductDescription, 
																		StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
				
				Difference     = 0;
				ValueDifference = 0;

				Difference     = StringSelectionProducts.FactCount - StringSelectionProducts.AccCount;
				ValueDifference = StringSelectionProducts.FactAmount      - StringSelectionProducts.AccSum;
				
				If Difference = 0 Then
					Continue;
				EndIf;

				TemplateAreaRow.Parameters.Number = LineNumber;
				
				If Difference < 0 Then
					
					TemplateAreaRow.Parameters.ResultShortageCount = - Difference;
					TemplateAreaRow.Parameters.ResultLossAmount      = - ValueDifference;
					TemplateAreaRow.Parameters.ResultExceedCount   = 0;
					TemplateAreaRow.Parameters.ResultSumExcess        = 0;

					TotalResultShortageAmount = TotalResultShortageAmount + ( - Difference);
					TotalAmountResultLossAmount      = TotalAmountResultLossAmount      + ( - ValueDifference);
					TotalAmountResultExceedCount   = TotalAmountResultExceedCount   + 0;
					TotalResultSumExcess        = TotalResultSumExcess        + 0;
					
				Else
					
					TemplateAreaRow.Parameters.ResultShortageCount = 0;
					TemplateAreaRow.Parameters.ResultLossAmount      = 0;
					TemplateAreaRow.Parameters.ResultExceedCount   = Difference;
					TemplateAreaRow.Parameters.ResultSumExcess        = ValueDifference;

					TotalResultShortageAmount = TotalResultShortageAmount + 0;
					TotalAmountResultLossAmount      = TotalAmountResultLossAmount      + 0;
					TotalAmountResultExceedCount   = TotalAmountResultExceedCount   + Difference;
					TotalResultSumExcess        = TotalResultSumExcess        + ValueDifference;
					
				EndIf;

				// Output check.
				RowWithFooter = New Array();
				RowWithFooter.Add(TemplateAreaRow);
				RowWithFooter.Add(TemplateAreaTotalByPage);
				RowWithFooter.Add(TemplateAreaFooter);
				
				If Not SpreadsheetDocument.CheckPut(RowWithFooter) Then
					
					If Not LineCount = 1 Then
				
						// Output totals by page.
						SpreadsheetDocument.Put(TemplateAreaTotalByPage);
						
						// Output pages separator.
						SpreadsheetDocument.PutHorizontalPageBreak();
						
						// Output table title.
						PageNumber = PageNumber + 1;
						TemplateAreaTableHeader.Parameters.PageNumber = "Page " + PageNumber;
						SpreadsheetDocument.Put(TemplateAreaTableHeader);
						
					EndIf;

				EndIf;
				
				SpreadsheetDocument.Put(TemplateAreaRow);
				
				LineNumber = LineNumber + 1;

			EndDo;

			// Output totals by page.
			TemplateAreaTotalByPage.Parameters.TotalAmountResultExceedCount   = TotalAmountResultExceedCount;
			TemplateAreaTotalByPage.Parameters.TotalResultSumExcess        = TotalResultSumExcess;
			TemplateAreaTotalByPage.Parameters.TotalResultShortageAmount = TotalResultShortageAmount;
			TemplateAreaTotalByPage.Parameters.TotalAmountResultLossAmount      = TotalAmountResultLossAmount;
			SpreadsheetDocument.Put(TemplateAreaTotalByPage);
			
			// Output footer.
			TemplateAreaFooter.Parameters.Fill(Header);
			TemplateAreaFooter.Parameters.AccountantDescriptionFull = Heads.ChiefAccountantNameAndSurname;
			TemplateAreaFooter.Parameters.PostFRP1 = ICData.Position;
			TemplateAreaFooter.Parameters.PAName1       = ICData.Presentation;
			SpreadsheetDocument.Put(TemplateAreaFooter);
			
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
			TemplateArea.Parameters.HeaderText = NStr("en ='Inventory survey No '") + DocumentNumber + NStr("en = ' from '") + Format(Header.DocumentDate, "DLF=DD");
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
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "INV3") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "INV3", "INV-3 (Inventory List)", PrintForm(ObjectsArray, PrintObjects, "INV3"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "INV3WithoutFactData") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "INV3WithoutFactData", "INV-Inventory List with Empty Actual Data", PrintForm(ObjectsArray, PrintObjects, "INV3WithoutFactData"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "INV19") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "INV19", "INV-19 (Collation Statement)", PrintForm(ObjectsArray, PrintObjects, "INV19"));
		
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
	PrintCommand.ID = "InventoryReconciliation,INV3,INV3WithoutFactData,INV19";
	PrintCommand.Presentation = NStr("en = 'Custom kit of documents'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "InventoryReconciliation";
	PrintCommand.Presentation = NStr("en = 'Inventory reconciliation'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "INV3";
	PrintCommand.Presentation = NStr("en = 'INV-3 (Inventory List)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "INV3WithoutFactData";
	PrintCommand.Presentation = NStr("en = 'INV-Inventory List with Empty Actual Data'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 10;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "INV19";
	PrintCommand.Presentation = NStr("en = 'INV-19 (Collation Statement)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 14;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en = 'Merchandise filling form'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 17;
	
EndProcedure

#EndRegion

#EndIf