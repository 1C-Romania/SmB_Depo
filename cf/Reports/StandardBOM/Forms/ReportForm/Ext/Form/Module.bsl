
////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

Var Template;
Var Document;
Var TableOfOperations, ContentTable;
Var RowAppearance;

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS GENERATING REPORT

&AtServer
// Procedure of product content scheme formation.
// 
Procedure DisplayProductContent()
	
	If ContentTable.Count() < 2 Then
		
		Message = New UserMessage();
		Message.Text = NStr("en='Standard bill of materials is not filled';ru='Не заполнен нормативный состав изделия'");
		Message.Message();
		
		Return;
		
	EndIf;
	
	RowIndex = ContentTable.Count() - 1;
	TotalsCorrespondence = New Map;
	
	While RowIndex >= 0 Do 
		
        CurRow = ContentTable[RowIndex];
		
		If RowIndex = 0 Then
			CurRow.Cost = TotalsCorrespondence.Get(CurRow.Level);
		Else
			NextRow = ContentTable[RowIndex - 1];
			If CurRow.Node Then
				CurRow.Cost = TotalsCorrespondence.Get(CurRow.Level);
				If TotalsCorrespondence.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondence.Insert(CurRow.Level - 1, CurRow.Cost);
				Else
					TotalsCorrespondence[CurRow.Level - 1] = TotalsCorrespondence[CurRow.Level - 1] + CurRow.Cost;
				EndIf;	
				TotalsCorrespondence.Insert(CurRow.Level, 0);
			Else
				If TotalsCorrespondence.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondence.Insert(CurRow.Level - 1, CurRow.Cost);
				Else
					TotalsCorrespondence[CurRow.Level - 1] = TotalsCorrespondence[CurRow.Level - 1] + CurRow.Cost;
				EndIf;				
			EndIf;
			
		EndIf;
		
		RowIndex = RowIndex - 1;
		
	EndDo;
	
	For Each ContentRow IN ContentTable Do
		
		Template.Area("ContentRow|ProductsAndServices").Indent = ContentRow.Level*2;
		TemplateArea = Template.GetArea("ContentRow|ContentColumn");
		
		TemplateArea.Parameters.PresentationOfProductsAndServices 	= ContentRow.ProductsAndServices.Description +" "+ContentRow.Characteristic.Description;
		TemplateArea.Parameters.ProductsAndServices				= ContentRow.ProductsAndServices;
		TemplateArea.Parameters.Quantity					= ContentRow.Quantity;
		TemplateArea.Parameters.MeasurementUnit			= ContentRow.MeasurementUnit;
		TemplateArea.Parameters.AccountingPrice                 = ContentRow.AccountingPrice;
		TemplateArea.Parameters.Cost	         		= ContentRow.Cost;
		
		RowIndex = ContentTable.IndexOf(ContentRow);
		
		If ContentRow.Node Then
			TemplateArea.Area(1,2,1,19).BackColor = RowAppearance[ContentRow.Level - Int(ContentRow.Level / 5) * 5];
		EndIf;
		
		If RowIndex < ContentTable.Count() - 1 Then
			
			NexRows = ContentTable[RowIndex+1];
			
			If NexRows.Level > ContentRow.Level Then
				Document.Put(TemplateArea);
				Document.StartRowGroup(ContentRow.ProductsAndServices.Description);
			ElsIf NexRows.Level < ContentRow.Level Then
				Document.Put(TemplateArea);
				DifferenceOfLevels = ContentRow.Level - NexRows.Level;
				While DifferenceOfLevels >= 1 Do
					Document.EndRowGroup();
					DifferenceOfLevels = DifferenceOfLevels - 1;
				EndDo;
			Else
				Document.Put(TemplateArea);
			EndIf;
		Else
			Document.Put(TemplateArea);
			Document.EndRowGroup();
		EndIf;
		
	EndDo;
	
	ContentTable.Clear();
	
EndProcedure // DisplayProductContent()

&AtServer
// Procedure of product operation scheme formation.
// 
Procedure OutputOperationsContent()
	
	RowIndex = TableOfOperations.Count() - 1;
	TotalsCorrespondenceTimeNorm = New Map;
	MapTotalsDuration = New Map;
	TotalsCorrespondenceCost = New Map;
	
	While RowIndex >= 0 Do 
		
        CurRow = TableOfOperations[RowIndex];
		
		If RowIndex = 0 Then
			
			CurRow.TimeNorm = TotalsCorrespondenceTimeNorm.Get(CurRow.Level);
			CurRow.Duration = MapTotalsDuration.Get(CurRow.Level);
			CurRow.Cost = TotalsCorrespondenceCost.Get(CurRow.Level);
			
		Else
			
			NextRow = TableOfOperations[RowIndex - 1];
			
			If CurRow.Node Then
				
				CurRow.TimeNorm = TotalsCorrespondenceTimeNorm.Get(CurRow.Level);
				If TotalsCorrespondenceTimeNorm.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceTimeNorm.Insert(CurRow.Level - 1, CurRow.TimeNorm);
				Else
					TotalsCorrespondenceTimeNorm[CurRow.Level - 1] = TotalsCorrespondenceTimeNorm[CurRow.Level - 1] + CurRow.TimeNorm;
				EndIf;	
				TotalsCorrespondenceTimeNorm.Insert(CurRow.Level, 0);
				
				CurRow.Duration = MapTotalsDuration.Get(CurRow.Level);
				If MapTotalsDuration.Get(CurRow.Level - 1) = Undefined Then 
					MapTotalsDuration.Insert(CurRow.Level - 1, CurRow.Duration);
				Else
					MapTotalsDuration[CurRow.Level - 1] = MapTotalsDuration[CurRow.Level - 1] + CurRow.Duration;
				EndIf;	
				MapTotalsDuration.Insert(CurRow.Level, 0);
				
				CurRow.Cost = TotalsCorrespondenceCost.Get(CurRow.Level);
				If TotalsCorrespondenceCost.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceCost.Insert(CurRow.Level - 1, CurRow.Cost);
				Else
					TotalsCorrespondenceCost[CurRow.Level - 1] = TotalsCorrespondenceCost[CurRow.Level - 1] + CurRow.Cost;
				EndIf;	
				TotalsCorrespondenceCost.Insert(CurRow.Level, 0);
				
			Else
				
				If TotalsCorrespondenceTimeNorm.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceTimeNorm.Insert(CurRow.Level - 1, CurRow.TimeNorm);
				Else
					TotalsCorrespondenceTimeNorm[CurRow.Level - 1] = TotalsCorrespondenceTimeNorm[CurRow.Level - 1] + CurRow.TimeNorm;
				EndIf;	
				
				If MapTotalsDuration.Get(CurRow.Level - 1) = Undefined Then 
					MapTotalsDuration.Insert(CurRow.Level - 1, CurRow.Duration);
				Else
					MapTotalsDuration[CurRow.Level - 1] = MapTotalsDuration[CurRow.Level - 1] + CurRow.Duration;
				EndIf;	
				
				If TotalsCorrespondenceCost.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceCost.Insert(CurRow.Level - 1, CurRow.Cost);
				Else
					TotalsCorrespondenceCost[CurRow.Level - 1] = TotalsCorrespondenceCost[CurRow.Level - 1] + CurRow.Cost;
				EndIf;	
				
			EndIf;
			
		EndIf;
		
		RowIndex = RowIndex - 1;
		
	EndDo;
	
	GroupRowsIsOpen = False;
	
	For Each RowOperation IN TableOfOperations Do
		
		Template.Area("RowOperation|ProductsAndServices").Indent = RowOperation.Level * 2;
		TemplateArea = Template.GetArea("RowOperation|ContentColumn");
		
		If RowOperation.Node Then
			TemplateArea.Parameters.PresentationOfProductsAndServices = RowOperation.ProductsAndServices.Description +" "+RowOperation.Characteristic.Description;
		Else
			TemplateArea.Parameters.PresentationOfProductsAndServices = RowOperation.ProductsAndServices.Description;
		EndIf;
		
		TemplateArea.Parameters.ProductsAndServices = RowOperation.ProductsAndServices;
		TemplateArea.Parameters.Norm		 = RowOperation.TimeNorm;
		TemplateArea.Parameters.Duration = RowOperation.Duration;
		TemplateArea.Parameters.AccountingPrice  = RowOperation.AccountingPrice;
		TemplateArea.Parameters.Cost	 = RowOperation.Cost;
		
		RowIndex = TableOfOperations.IndexOf(RowOperation);
		
		If RowOperation.Node Then
			TemplateArea.Area(1,2,1,19).BackColor = RowAppearance[RowOperation.Level - Int(RowOperation.Level / 5) * 5];
		EndIf;
		
		If RowIndex < TableOfOperations.Count() - 1 Then
			
			NexRows = TableOfOperations[RowIndex+1];
			
			If NexRows.Level > RowOperation.Level Then
				
				Document.Put(TemplateArea);
				Document.StartRowGroup(RowOperation.ProductsAndServices.Description);
				GroupRowsIsOpen = True;
				
			ElsIf NexRows.Level < RowOperation.Level Then
				
				Document.Put(TemplateArea);
				DifferenceOfLevels = RowOperation.Level - NexRows.Level;                                  
				While DifferenceOfLevels >= 1 Do
					
					Document.EndRowGroup();
					DifferenceOfLevels = DifferenceOfLevels - 1;
					
				EndDo;
				
			Else
				
				Document.Put(TemplateArea);
				
			EndIf;
			
		Else
			
			Document.Put(TemplateArea);
			
			//Check the need to close the grouping
			If GroupRowsIsOpen Then 
				
				Document.EndRowGroup();
				GroupRowsIsOpen = False;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TableOfOperations.Clear();
	
EndProcedure // DisplayOperationContent()

&AtServer
// Function forms tree by request.
//
// Parameters:
//  exProductsAndServices - CatalogRef.ProductsAndServices - products.
//
Function GenerateTree(ProductsAndServices, Specification, Characteristic)
	
	ContentStructure = SmallBusinessServer.GenerateContentStructure();
	ContentStructure.ProductsAndServices		= ProductsAndServices;
	ContentStructure.Characteristic		= Characteristic;
	ContentStructure.MeasurementUnit	= ProductsAndServices.MeasurementUnit;
	ContentStructure.Quantity			= Report.Quantity;
	ContentStructure.Specification		= Specification;
	ContentStructure.ProcessingDate		= Report.CalculationDate;
	ContentStructure.PriceKind     		= Report.PriceKind;
	ContentStructure.Level			= 0;
	ContentStructure.AccountingPrice		= 0;
	ContentStructure.Cost			= 0;
	
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, , , New NumberQualifiers(15, 3));
	
	ContentTable = New ValueTable;
	
	ContentTable.Columns.Add("ProductsAndServices");
	ContentTable.Columns.Add("Characteristic");
	ContentTable.Columns.Add("MeasurementUnit");
	ContentTable.Columns.Add("Quantity", TypeDescription);
    ContentTable.Columns.Add("Level");
	ContentTable.Columns.Add("Node");
	ContentTable.Columns.Add("AccountingPrice", TypeDescription);
	ContentTable.Columns.Add("Cost", TypeDescription);
	
	TableOfOperations = New ValueTable;
	
	TableOfOperations.Columns.Add("ProductsAndServices");
	TableOfOperations.Columns.Add("Characteristic");
	TableOfOperations.Columns.Add("TimeNorm", TypeDescription);
	TableOfOperations.Columns.Add("Duration", TypeDescription);
	TableOfOperations.Columns.Add("Level");
	TableOfOperations.Columns.Add("Node");
	TableOfOperations.Columns.Add("AccountingPrice", TypeDescription);
	TableOfOperations.Columns.Add("Cost", TypeDescription);
	
	SmallBusinessServer.Denoding(ContentStructure, ContentTable, TableOfOperations);
	
EndFunction // GenerateTree()

&AtServer
// Procedure forms report by product content.
//
Procedure GenerateReport(ProductsAndServices, Characteristic, Specification)
	
	If Not ValueIsFilled(ProductsAndServices) Then
		
		MessageText = NStr("en='The Products and services field is not filled';ru='Поле Номенклатура не заполнено'");
		MessageField = "ProductsAndServices";
		SmallBusinessServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		
		Return;
	
	EndIf;
	
	If Not ValueIsFilled(Specification) Then
		
		MessageText = NStr("en='The Specification field is not filled';ru='Поле Спецификация не заполнено'");
		MessageField = "Specification";
		SmallBusinessServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		
		Return;
	
	EndIf;
	
	Document = SpreadsheetDocumentReport;
	Document.Clear();
	
	GenerateTree(ProductsAndServices, Specification, Characteristic);
	
	Report.Cost = ContentTable.Total("Cost") + TableOfOperations.Total("Cost");
	
	Template = Reports.StandardBOM.GetTemplate("Template");
	
	TemplateArea = Template.GetArea("Title");
	TemplateArea.Parameters.Title = "Standard product content on " + Format(Report.CalculationDate,"DLF=DD") + Chars.LF
										+ "Product: " + ProductsAndServices.Description
										+ ?(ValueIsFilled(Report.Characteristic), ", " + Report.Characteristic, "")
										+ ", " + Specification + Chars.LF
										+ "Quantity: " + Report.Quantity + " " + ProductsAndServices.MeasurementUnit
										+ ", cost: " + Report.Cost + " " + Report.PriceKind.PriceCurrency.Description
										+ Chars.LF;
	Document.Put(TemplateArea);
	
	RowAppearance = New Array;
	
	RowAppearance.Add(WebColors.MediumTurquoise);
	RowAppearance.Add(WebColors.MediumGreen);
	RowAppearance.Add(WebColors.AliceBlue);
	RowAppearance.Add(WebColors.Cream);
	RowAppearance.Add(WebColors.Azure);

	TemplateArea = Template.GetArea("ContentTitle|ContentColumn");
	Document.Put(TemplateArea);
	
	DisplayProductContent();
	
	If Constants.FunctionalOptionUseTechOperations.Get() AND TableOfOperations.Count() > 0 Then
	
		TemplateAreaOperations = Template.GetArea("Indent");
		Document.Put(TemplateAreaOperations);
		
		TemplateArea = Template.GetArea("OperationTitle|ContentColumn");
		Document.Put(TemplateArea);
		
		OutputOperationsContent();
		
	EndIf;	

EndProcedure // GenerateReport()

&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure is called when clicking "Generate" command
// panel of tabular field.
//
Procedure Generate(Command)
	
	GenerateReport(Report.ProductsAndServices, Report.Characteristic, Report.Specification);
	
EndProcedure // Generate()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure ProductsAndServicesOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", Report.ProductsAndServices);
	StructureData.Insert("Characteristic", Report.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	Report.Specification = StructureData.Specification;

EndProcedure // ProductsAndServicesOnChange()

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure CharacteristicOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", Report.ProductsAndServices);
	StructureData.Insert("Characteristic", Report.Characteristic);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	Report.Specification = StructureData.Specification;
	
EndProcedure // CharacteristicOnChange()

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	Report.CalculationDate = CurrentDate();
		
EndProcedure // OnOpen() 

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ProductsAndServices") Then
		
		If ValueIsFilled(Parameters.ProductsAndServices) Then
			
			StructureData = New Structure;
			
			If TypeOf(Parameters.ProductsAndServices ) = Type("CatalogRef.ProductsAndServices") Then
				StructureData.Insert("ProductsAndServices", Parameters.ProductsAndServices);
				StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
				StructureData      = GetDataProductsAndServicesOnChange(StructureData);
				Report.ProductsAndServices   = StructureData.ProductsAndServices;
				Report.Specification   = StructureData.Specification;
			Else // Specifications
				Report.ProductsAndServices   = Parameters.ProductsAndServices.Owner;
				Report.Characteristic = Parameters.ProductsAndServices.ProductCharacteristic;
				Report.Specification   = Parameters.ProductsAndServices;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Report.PriceKind = Catalogs.PriceKinds.Accounting;
	Report.Quantity = 1;
	
EndProcedure // OnCreateAtServer()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

















