#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Price list generating procedure
//
Procedure Generate(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	If Not IsBlankString(BackgroundJobStorageAddress) Then
		
		SpreadsheetDocument = New SpreadsheetDocument;
		PrepareSpreadsheetDocument(ParametersStructure, SpreadsheetDocument);
		PutToTempStorage(SpreadsheetDocument, BackgroundJobStorageAddress);
		
	EndIf;
	
EndProcedure // Generate()

// Function prepares the tabular document with the data
//
Procedure PrepareSpreadsheetDocument(ParametersStructure, SpreadsheetDocument) Export
	
	ItemHierarchy = ParametersStructure.ItemHierarchy;
	If ItemHierarchy Then
		
		SpreadsheetDocument_ItemHierarchy(ParametersStructure, SpreadsheetDocument);
		
	Else
		
		SpreadsheetDocument_PriceGroupsHierarchy(ParametersStructure, SpreadsheetDocument);
		
	EndIf;
	
EndProcedure // PrepareSpreadsheetDocument()

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure of generating the dynamic price kinds mapping to their basic kinds
//
Function CreateMapPattern(TablePriceKinds)
	
	MapForDetail = New Map;
	
	For Each TableRow IN TablePriceKinds Do
		
		If ValueIsFilled(TableRow.PriceKind) 
			AND Not TableRow.PriceKind.CalculatesDynamically Then
			
			MapForDetail.Insert(TableRow.PriceKind, Catalogs.PriceKinds.EmptyRef());
			
		EndIf;
		
	EndDo;
	
	Return MapForDetail;
	
EndFunction //CreateMapPattern()

// Output procedure of the price list detail sections
//
Procedure OutputDetails(SelectionProductsAndServices, UseCharacteristics, UsePriceGroups, SpreadsheetDocument, Template, ParametersStructure, TablePriceKinds)
	
	ToDate = ParametersStructure.ToDate;
	PriceKind = ParametersStructure.PriceKind;
	TSPriceKinds = ParametersStructure.TSPriceKinds;
	PriceGroup = ParametersStructure.PriceGroup;
	TSPriceGroups = ParametersStructure.TSPriceGroups;
	ProductsAndServices = ParametersStructure.ProductsAndServices;
	ProductsAndServicesTS = ParametersStructure.ProductsAndServicesTS;
	Actuality = ParametersStructure.Actuality;
	OutputCode = ParametersStructure.OutputCode;
	OutputFullDescr = ParametersStructure.OutputFullDescr;
	ShowTitle = ParametersStructure.ShowTitle;
	UseCharacteristics = ParametersStructure.UseCharacteristics;
	FormateByAvailabilityInWarehouses = ParametersStructure.FormateByAvailabilityInWarehouses;
	
	AreaDetailsProductsAndServices 	= Template.GetArea("Details|ProductsAndServices");
	AreaDetailsCharacteristic = Template.GetArea("Details|Characteristic");
	AreaDetailsPriceKind 		= Template.GetArea("Details|PriceKind");
	
	EnumValueYes		= Enums.YesNo.Yes;
	
	While SelectionProductsAndServices.Next() Do
		
		SelectionCharacteristic = SelectionProductsAndServices.Select(QueryResultIteration.ByGroups, "Characteristic");
		While SelectionCharacteristic.Next() Do
			
			ProductsAndServicesCharacteristicDetailsStructure = New Structure;
			ProductsAndServicesCharacteristicDetailsStructure.Insert("ProductsAndServices",				SelectionProductsAndServices.ProductsAndServices);
			ProductsAndServicesCharacteristicDetailsStructure.Insert("Characteristic",			Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
			ProductsAndServicesCharacteristicDetailsStructure.Insert("DetailsMatch",	CreateMapPattern(TablePriceKinds));
			
			TableHeight = SpreadsheetDocument.TableHeight;
			TableWidth = ?(UseCharacteristics, 4, 3);
			
			SpreadsheetDocument.Put(AreaDetailsProductsAndServices);
			
			If UseCharacteristics Then
				
				ProductsAndServicesCharacteristicDetailsStructure.Insert("Characteristic", SelectionCharacteristic.Characteristic);
				
				AreaDetailsCharacteristic.Parameters.Characteristic = SelectionCharacteristic.Characteristic;
				SpreadsheetDocument.Join(AreaDetailsCharacteristic);
				
			EndIf;
			
			//Remember the used prices in the values list
			UsedPrices = New ValueList;
			
			SelectionPriceKind = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "PriceKind");
			While SelectionPriceKind.Next() Do
				
				Selection = SelectionPriceKind.Select();
				While Selection.Next() Do
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("ProductsAndServices", 		SelectionProductsAndServices.ProductsAndServices);
					DetailsStructure.Insert("Characteristic", 	SelectionCharacteristic.Characteristic);
					DetailsStructure.Insert("PriceKind", 			Selection.PriceKind);
					DetailsStructure.Insert("Dynamic",		Selection.PriceKind.CalculatesDynamically);
					DetailsStructure.Insert("PricesBaseKind",		Selection.PriceKind.PricesBaseKind);
					DetailsStructure.Insert("Period", 			ToDate);
					DetailsStructure.Insert("Period", 			Selection.Period);
					DetailsStructure.Insert("Price", 				Selection.Price);
					DetailsStructure.Insert("Actuality", 		Selection.Actuality);
					DetailsStructure.Insert("MeasurementUnit", 	Selection.MeasurementUnit);
					
					NPP = TablePriceKinds.FindRows(New Structure("PriceKind", Selection.PriceKind))[0].NPP;
					AreaUnit	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP*2 + 1);
					AreaPrice 	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP*2 + 2);
					
					AreaUnit.Text 		= Selection.MeasurementUnit;
					AreaUnit.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
					
					If (Selection.PriceKind.CalculatesDynamically) Then //on query of all prices
						
						If ValueIsFilled(Selection.Price) Then
							
							Price = Selection.Price * (1 + Selection.PriceKind.Percent / 100);
							
						Else
							
							Price = 0;
							
						EndIf;
						
						Price 		= SmallBusinessServer.RoundPrice(Price, Selection.PriceKind.RoundingOrder, Selection.PriceKind.RoundUp);
						AreaPrice.Text = Format(Price, Selection.PriceKind.PriceFormat);
						
					ElsIf ValueIsFilled(PriceKind) AND PriceKind.CalculatesDynamically Then//on query of dynamic price type
						
						If ValueIsFilled(Selection.Price) Then
							
							Price = Selection.Price * (1 + PriceKind.Percent / 100);
							
						Else
							
							Price = 0;
							
						EndIf;
						
						Price		= SmallBusinessServer.RoundPrice(Price, PriceKind.RoundingOrder, PriceKind.RoundUp);
						AreaPrice.Text = Format(Price, PriceKind.PriceFormat);
						
					Else
						
						AreaPrice.Text = Format(Selection.Price, Selection.PriceFormat);
						
					EndIf; 
					
					AreaUnit.Details	= DetailsStructure;
					AreaPrice.Details 	= DetailsStructure;
						
					If Not Selection.PriceKind.CalculatesDynamically Then
						
						ProductsAndServicesCharacteristicDetailsStructure.DetailsMatch.Insert(Selection.PriceKind, DetailsStructure);
						
					EndIf;
					
					UsedPrices.Add(Selection.PriceKind);
					
				EndDo;
				
			EndDo;
			
			//Fill out explanation for other price kinds.
			For Each PriceKindsTableRow IN TablePriceKinds Do
				
				If UsedPrices.FindByValue(PriceKindsTableRow.PriceKind) = Undefined Then
					
					AreaUnit	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + PriceKindsTableRow.NPP*2 + 1);
					AreaPrice 	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + PriceKindsTableRow.NPP*2 + 2);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("ProductsAndServices", 		SelectionProductsAndServices.ProductsAndServices);
					DetailsStructure.Insert("Characteristic", 	SelectionCharacteristic.Characteristic);
					DetailsStructure.Insert("PriceKind", 			PriceKindsTableRow.PriceKind);
					DetailsStructure.Insert("Dynamic",		PriceKindsTableRow.PriceKind.CalculatesDynamically);
					DetailsStructure.Insert("PricesBaseKind",		PriceKindsTableRow.PriceKind.PricesBaseKind);
					DetailsStructure.Insert("Period", 			Selection.Period);
					DetailsStructure.Insert("MeasurementUnit", 	SelectionProductsAndServices.ProductsAndServicesMeasurementUnit);
					
					AreaUnit.Details	= DetailsStructure;
					AreaPrice.Details 	= DetailsStructure;
					
				EndIf;
				
			EndDo;
			
			AreaSKUCode 				= SpreadsheetDocument.Area(TableHeight + 1, 2);
			AreaSKUCode.Text			= ?(OutputCode = EnumValueYes, SelectionProductsAndServices.ProductsAndServicesCode, SelectionProductsAndServices.ProductsAndServicesSKU);
			AreaSKUCode.Details	= ProductsAndServicesCharacteristicDetailsStructure;
			
			AreaProductsAndServices 			= SpreadsheetDocument.Area(TableHeight + 1, 3);
			AreaProductsAndServices.Text		= ?(OutputFullDescr = EnumValueYes, SelectionProductsAndServices.DescriptionFull, SelectionProductsAndServices.ProductsAndServicesDescription);
			AreaProductsAndServices.Details	= ProductsAndServicesCharacteristicDetailsStructure;
			
			If UseCharacteristics Then
				
				AreaCharacteristic 				= SpreadsheetDocument.Area(TableHeight + 1, TableWidth);
				AreaCharacteristic.Details 	= ProductsAndServicesCharacteristicDetailsStructure;
				
			EndIf;
			
		EndDo;
	
	EndDo;
	
EndProcedure // OutputDetails()

Procedure SpreadsheetDocument_ItemHierarchy(ParametersStructure, SpreadsheetDocument)
	
	ToDate = ParametersStructure.ToDate;
	PriceKind = ParametersStructure.PriceKind;
	TSPriceKinds = ParametersStructure.TSPriceKinds;
	PriceGroup = ParametersStructure.PriceGroup;
	TSPriceGroups = ParametersStructure.TSPriceGroups;
	ProductsAndServices = ParametersStructure.ProductsAndServices;
	ProductsAndServicesTS = ParametersStructure.ProductsAndServicesTS;
	Actuality = ParametersStructure.Actuality;
	OutputCode = ParametersStructure.OutputCode;
	OutputFullDescr = ParametersStructure.OutputFullDescr;
	ShowTitle = ParametersStructure.ShowTitle;
	UseCharacteristics = ParametersStructure.UseCharacteristics;
	FormateByAvailabilityInWarehouses = ParametersStructure.FormateByAvailabilityInWarehouses;
	
	TablePriceKinds = New ValueTable;
	TablePriceKinds.Columns.Add("NPP");
	TablePriceKinds.Columns.Add("PriceKind");
	
	VirtualTableParameters = "&Period, ";
	
	TextSelectionOnPricesKinds		= " TRUE";
	Conjunction 			= "";
	PriceKindConditions 	= " TRUE";
	
	Query = New Query;
	
	If ValueIsFilled(PriceKind) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind = (&PriceKind) ";
		Conjunction = "AND ";
		
		If PriceKind.CalculatesDynamically Then
			
			Query.SetParameter("PriceKind",  PriceKind.PricesBaseKind);
			Query.SetParameter("PricesKindsCatalogSelection",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PricesKindsCatalogSelection";
			
		Else
			
			Query.SetParameter("PriceKind",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PriceKind";
			
		EndIf;
		
	ElsIf TSPriceKinds.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind IN HIERARCHY (&MassivPriceKind)";
		Conjunction = "AND ";
		
		PriceKindsArray = New Array;
		PriceKindsArrayCatalogSelection = TSPriceKinds.UnloadColumn("Ref");
		For Each FilterPricesKind IN TSPriceKinds Do
			
			If FilterPricesKind.Ref.CalculatesDynamically Then
				
				PriceKindsArray.Add(FilterPricesKind.Ref.PricesBaseKind);
				
			Else
				
				PriceKindsArray.Add(FilterPricesKind.Ref);
				
			EndIf;
			
		EndDo;
		
		TextSelectionOnPricesKinds = "CatalogPricesKind.Refs IN(&PriceKindsArrayCatalogSelection)";
		
		Query.SetParameter("ArrayPriceKind", PriceKindsArray);
		Query.SetParameter("PriceKindsArrayCatalogSelection", PriceKindsArrayCatalogSelection);
		
	EndIf;
	
	If ValueIsFilled(PriceGroup) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						ProductsAndServices.PriceGroup IN HIERARCHY (&PriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("PriceGroup",  PriceGroup);
		
	ElsIf TSPriceGroups.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						ProductsAndServices.PriceGroup IN HIERARCHY (&ArrayPriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayPriceGroup", TSPriceGroups.UnloadColumn("Ref"));
		
	EndIf; 
	
	If ValueIsFilled(ProductsAndServices) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						" + "ProductsAndServices IN HIERARCHY (&ProductsAndServices)";
		Conjunction = "AND ";
		
		Query.SetParameter("ProductsAndServices",  	ProductsAndServices);
		
	ElsIf ProductsAndServicesTS.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						" + "ProductsAndServices IN HIERARCHY (&ArrayProductsAndServices)";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayProductsAndServices", ProductsAndServicesTS.UnloadColumn("Ref"));
		
	EndIf; 
	
	If Actuality Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + " Actuality";
		
	EndIf;
	
	Query.SetParameter("Period", ToDate);
	
	Query.Text =
	"SELECT
	|	CatalogPricesKind.Ref AS PriceKind
	|	,CASE
	|		WHEN CatalogPricesKind.CalculatesDynamically
	|			THEN CatalogPricesKind.PricesBaseKind
	|		ELSE UNDEFINED
	|	END AS PricesBaseKind
	|	,CatalogPricesKind.PriceCurrency
	|	,CatalogPricesKind.PriceFormat
	|	,CASE
	|		WHEN Not CatalogPricesKind.CalculatesDynamically
	|			THEN CatalogPricesKind.Ref
	|		ELSE CatalogPricesKind.PricesBaseKind
	|	END AS FieldForConnection
	|INTO TU_PriceKinds
	|FROM
	|	Catalog.PriceKinds AS CatalogPricesKind
	|WHERE
	|	&TextSelectionOnPricesKinds
	|
	|INDEX BY
	|	FieldForConnection
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesPricesSliceLast.ProductsAndServices AS ProductsAndServices
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.DescriptionFull AS DescriptionFull
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.Code AS ProductsAndServicesCode
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.SKU AS ProductsAndServicesSKU
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.MeasurementUnit AS ProductsAndServicesMeasurementUnit
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.Description AS ProductsAndServicesDescription
	|	,ISNULL(ProductsAndServicesPricesSliceLast.ProductsAndServices.Parent, VALUE(Catalog.ProductsAndServices.EmptyRef)) AS Parent
	|	,CASE
	|		WHEN ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|			THEN ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup
	|		ELSE ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent
	|	END AS PriceGroup
	|	,ProductsAndServicesPricesSliceLast.Characteristic AS Characteristic
	|	,ProductsAndServicesPricesSliceLast.Period
	|	,ProductsAndServicesPricesSliceLast.MeasurementUnit
	|	,ProductsAndServicesPricesSliceLast.Actuality
	|	,ProductsAndServicesPricesSliceLast.Price AS Price
	|	,PriceKinds.PriceCurrency AS Currency
	|	,PriceKinds.PriceFormat AS PriceFormat
	|	,ProductsAndServicesPricesSliceLast.Characteristic.Description AS CharacteristicDescription
	|	,PriceKinds.PriceKind AS PriceKind
	|	,PriceKinds.PricesBaseKind AS PricesBaseKind
	|FROM
	|	TU_PriceKinds AS PriceKinds
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&VirtualTableParameters) AS ProductsAndServicesPricesSliceLast
	|		ON PriceKinds.FieldForConnection = ProductsAndServicesPricesSliceLast.PriceKind
	|	,&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses
	|WHERE
	|	Not ProductsAndServicesPricesSliceLast.ProductsAndServices.DeletionMark
	|	AND &FilterConditionByActuality
	|	AND &ConditionByBalance
	|
	|ORDER BY
	|	ProductsAndServicesDescription
	|	,CharacteristicDescription
	|	,PriceKind
	|TOTALS BY
	|	Parent
	|	,ProductsAndServices
	|	,Characteristic
	|	,PriceKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServices.Ref AS Ref
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServices
	|WHERE
	|	ProductsAndServices.IsFolder
	|
	|ORDER BY
	|	Ref HIERARCHY";
	
	If TrimAll(VirtualTableParameters) = "&Period," Then
		
		VirtualTableParameters = "&Period";
		
	EndIf;
	
	TextAvailabilityAtWarehouses = " 
	|			INNER JOIN AccumulationRegister.Inventory.Balance(&Period, ) AS InventoryBalances ON (InventoryBalances.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices) And (InventoryBalances.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic) And (InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef))";
	
	If Not ValueIsFilled(ToDate) Then
		
		VirtualTableParameters = StrReplace(VirtualTableParameters, "&Period", "");
		TextAvailabilityAtWarehouses = StrReplace(TextAvailabilityAtWarehouses, "&Period", "");
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&FilterConditionByActuality",	?(Actuality, "ProductsAndServicesPricesSliceLast.Actuality", "True"));
	Query.Text = StrReplace(Query.Text, "&TextSelectionOnPricesKinds",			TextSelectionOnPricesKinds);
	Query.Text = StrReplace(Query.Text, "&VirtualTableParameters",	VirtualTableParameters);
	Query.Text = StrReplace(Query.Text, "&ConditionByBalance", 				?(FormateByAvailabilityInWarehouses, "InventoryBalances.QuantityBalance > 0", "True"));
	Query.Text = StrReplace(Query.Text, ",&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses", ?(FormateByAvailabilityInWarehouses, TextAvailabilityAtWarehouses, ""));
	
	ArrayQueryResult		= Query.ExecuteBatch();
	ResultQuery				= ArrayQueryResult[1];
	ResultHierarchy			= ArrayQueryResult[2];
	
	Template 						= DataProcessors.PriceList.GetTemplate("Template");
	
	AreaIndent	 			= Template.GetArea("Indent|ProductsAndServices");
	HeaderArea 			= Template.GetArea("Title|ProductsAndServices");
	AreaHeaderProductsAndServices	= Template.GetArea("Header|ProductsAndServices");
	AreaHeaderCharacteristic	= Template.GetArea("Header|Characteristic");
	AreaPriceGroup 		= Template.GetArea("PriceGroup|ProductsAndServices");
	AreaHeaderPriceKind 			= Template.GetArea("Header|PriceKind");
		
	Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	SpreadsheetDocument.Clear();
	
	If ResultQuery.IsEmpty() Then
		
		Return;
		
	EndIf; 
	
	SpreadsheetDocument.Put(AreaIndent);
	
	If ShowTitle Then
	
		HeaderArea.Parameters.Title	 = "PRICE-SHEET";
		HeaderArea.Parameters.ToDate		 = Format(ToDate, "DF=dd.MM.yyyy");
		SpreadsheetDocument.Put(HeaderArea);	
		
	EndIf;	
		
	AreaHeaderProductsAndServices.Parameters.SKUCode = ?(OutputCode = Enums.YesNo.Yes, "Code", "SKU");
	
	SpreadsheetDocument.Put(AreaHeaderProductsAndServices);
	If UseCharacteristics Then
		
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);
		
	EndIf;
	
	NPP = 0;
	TablePriceKinds.Clear();
	SelectionPriceKind = ResultQuery.Select(QueryResultIteration.ByGroups, "PriceKind");
	While SelectionPriceKind.Next() Do
		
		AreaHeaderPriceKind.Parameters.PriceKind = SelectionPriceKind.PriceKind;
		AreaHeaderPriceKind.Parameters.Currency = SelectionPriceKind.PriceKind.PriceCurrency;
		
		SpreadsheetDocument.Join(AreaHeaderPriceKind);
		
		NewRow 		= TablePriceKinds.Add();
		NewRow.PriceKind	= SelectionPriceKind.PriceKind;
		NewRow.NPP		= NPP;
		
		NPP					= NPP + 1;
		
	EndDo; 
	
	OutputDataOnProductAndServicesParent(Catalogs.ProductsAndServices.EmptyRef(), SpreadsheetDocument, ResultQuery, TablePriceKinds, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup);
	
	ProductsAndServicesParentSelection = ResultHierarchy.Select(QueryResultIteration.ByGroupsWithHierarchy);
	While ProductsAndServicesParentSelection.Next() Do
		
		OutputDataOnProductAndServicesParent(ProductsAndServicesParentSelection, SpreadsheetDocument, ResultQuery, TablePriceKinds, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup);
		
	EndDo;
	
	AreaTable = SpreadsheetDocument.Area(?(ShowTitle, 5, 2), 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
 
	AreaTable.TopBorder 	= Line;
	AreaTable.BottomBorder 	= Line;
	AreaTable.LeftBorder 	= Line;
	AreaTable.RightBorder 	= Line;
	
EndProcedure

Procedure SpreadsheetDocument_PriceGroupsHierarchy(ParametersStructure, SpreadsheetDocument)
	
	ToDate = ParametersStructure.ToDate;
	PriceKind = ParametersStructure.PriceKind;
	TSPriceKinds = ParametersStructure.TSPriceKinds;
	PriceGroup = ParametersStructure.PriceGroup;
	TSPriceGroups = ParametersStructure.TSPriceGroups;
	ProductsAndServices = ParametersStructure.ProductsAndServices;
	ProductsAndServicesTS = ParametersStructure.ProductsAndServicesTS;
	Actuality = ParametersStructure.Actuality;
	OutputCode = ParametersStructure.OutputCode;
	OutputFullDescr = ParametersStructure.OutputFullDescr;
	ShowTitle = ParametersStructure.ShowTitle;
	UseCharacteristics = ParametersStructure.UseCharacteristics;
	FormateByAvailabilityInWarehouses = ParametersStructure.FormateByAvailabilityInWarehouses;
	
	TablePriceKinds = New ValueTable;
	TablePriceKinds.Columns.Add("NPP");
	TablePriceKinds.Columns.Add("PriceKind");
	
	VirtualTableParameters = "&Period, ";
	TextSelectionOnPricesKinds		= " TRUE";
	Conjunction 						= "";
	
	Query = New Query;	
	
	If ValueIsFilled(PriceKind) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind = (&PriceKind) ";
		Conjunction = "AND ";
		
		If PriceKind.CalculatesDynamically Then
			
			Query.SetParameter("PriceKind",  PriceKind.PricesBaseKind);
			Query.SetParameter("PricesKindsCatalogSelection",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PricesKindsCatalogSelection";
			
		Else
			
			Query.SetParameter("PriceKind",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PriceKind";
			
		EndIf;
		
	ElsIf TSPriceKinds.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind IN HIERARCHY (&MassivPriceKind)";
		Conjunction = "AND ";
		
		PriceKindsArray = New Array;
		PriceKindsArrayCatalogSelection = TSPriceKinds.UnloadColumn("Ref");
		For Each FilterPricesKind IN TSPriceKinds Do
			
			If FilterPricesKind.Ref.CalculatesDynamically Then
				
				PriceKindsArray.Add(FilterPricesKind.Ref.PricesBaseKind);
				
			Else
				
				PriceKindsArray.Add(FilterPricesKind.Ref);
				
			EndIf;
			
		EndDo;
		
		TextSelectionOnPricesKinds = "CatalogPricesKind.Refs IN(&PriceKindsArrayCatalogSelection)";
		
		Query.SetParameter("ArrayPriceKind", PriceKindsArray);
		Query.SetParameter("PriceKindsArrayCatalogSelection", PriceKindsArrayCatalogSelection);
		
	EndIf;
	
	If ValueIsFilled(PriceGroup) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						ProductsAndServices.PriceGroup IN HIERARCHY (&PriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("PriceGroup",  PriceGroup);
		
	ElsIf TSPriceGroups.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						ProductsAndServices.PriceGroup IN HIERARCHY (&ArrayPriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayPriceGroup", TSPriceGroups.UnloadColumn("Ref"));
		
	EndIf; 
	
	If ValueIsFilled(ProductsAndServices) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products and services IN HIERARCHY (&ProductsAndServices)";
		Conjunction = "AND ";
		
		Query.SetParameter("ProductsAndServices",  	ProductsAndServices);
		
	ElsIf ProductsAndServicesTS.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products and services IN HIERARCHY (&ArrayProductsAndServices)";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayProductsAndServices", ProductsAndServicesTS.UnloadColumn("Ref"));
		
	EndIf; 
	
	Query.SetParameter("Period", ToDate);
	
	// ATTENTION! After the use of the query designer,
	// make sure that in the
	// string LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&VirtualTableParameters) AS ProductsAndServicesPricesSliceLast, there is no comma remained (added automatically) after "&VirtualTableParameters"
	//
	// IN the same way, the comma is added to the &TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses string
	
	Query.Text	= 
	"SELECT
	|	CatalogPricesKind.Ref AS PriceKind
	|	,CatalogPricesKind.PricesBaseKind AS PricesBaseKind
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices AS ProductsAndServices
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.DescriptionFull AS DescriptionFull
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.Description AS ProductsAndServicesDescription
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup AS PriceGroup
	|	,CASE
	|		WHEN ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|			THEN ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup
	|		ELSE ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent
	|	END AS Parent
	|	,CASE
	|		WHEN ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|			THEN ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Order
	|		ELSE ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent.Order
	|	END AS ParentOrder
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Order AS Order
	|	,ProductsAndServicesPricesSliceLast.Characteristic AS Characteristic
	|	,ProductsAndServicesPricesSliceLast.Characteristic.Description AS CharacteristicDescription
	|	,ProductsAndServicesPricesSliceLast.Period
	|	,ProductsAndServicesPricesSliceLast.MeasurementUnit
	|	,ProductsAndServicesPricesSliceLast.Actuality
	|	,ProductsAndServicesPricesSliceLast.Price AS Price
	|	,ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency AS Currency
	|	,ProductsAndServicesPricesSliceLast.PriceKind.PriceFormat AS PriceFormat
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.Code AS ProductsAndServicesCode
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.SKU AS ProductsAndServicesSKU
	|	,ProductsAndServicesPricesSliceLast.ProductsAndServices.MeasurementUnit AS ProductsAndServicesMeasurementUnit
	|FROM
	|	Catalog.PriceKinds AS CatalogPricesKind
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&VirtualTableParameters) AS ProductsAndServicesPricesSliceLast 
	|		ON CASE
	|				WHEN Not CatalogPricesKind.CalculatesDynamically
	|					THEN CatalogPricesKind.Ref = ProductsAndServicesPricesSliceLast.PriceKind
	|				ELSE CatalogPricesKind.PricesBaseKind = ProductsAndServicesPricesSliceLast.PriceKind
	|			END
	|	,&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses
	|WHERE
	|	&FilterConditionByActuality
	|	AND &TextSelectionOnPricesKinds
	|	AND &ConditionByBalance
	|	
	|ORDER BY
	|	ParentOrder
	|	,Order
	|	,ProductsAndServicesDescription
	|	,CharacteristicDescription
	|	
	|TOTALS BY
	|	Parent
	|	,PriceGroup
	|	,ProductsAndServices
	|	,Characteristic
	|	,PriceKind";
	
	If TrimAll(VirtualTableParameters) = "&Period," Then
	
		VirtualTableParameters = "&Period";
	
	EndIf;
	
	TextAvailabilityAtWarehouses = " 
	|			INNER JOIN AccumulationRegister.Inventory.Balance(&Period, ) AS InventoryBalances ON (InventoryBalances.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices) And (InventoryBalances.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic) And (InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef))";
	
	If Not ValueIsFilled(ToDate) Then
		
		VirtualTableParameters = StrReplace(VirtualTableParameters, "&Period", "");
		TextAvailabilityAtWarehouses = StrReplace(TextAvailabilityAtWarehouses, "&Period", "");
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&FilterConditionByActuality",	?(Actuality, "ProductsAndServicesPricesSliceLast.Actuality", "True"));
	Query.Text = StrReplace(Query.Text, "&TextSelectionOnPricesKinds",			TextSelectionOnPricesKinds);
	Query.Text = StrReplace(Query.Text, "&VirtualTableParameters",	VirtualTableParameters);
	Query.Text = StrReplace(Query.Text, "&ConditionByBalance", 				?(FormateByAvailabilityInWarehouses, "InventoryBalances.QuantityBalance > 0", "True"));
	Query.Text = StrReplace(Query.Text, ",&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses", ?(FormateByAvailabilityInWarehouses, TextAvailabilityAtWarehouses, ""));
	
	ResultQuery 			= Query.Execute();
	
	Template 						= DataProcessors.PriceList.GetTemplate("Template");
	
	AreaIndent	 			= Template.GetArea("Indent|ProductsAndServices");
	HeaderArea 			= Template.GetArea("Title|ProductsAndServices");
	AreaHeaderProductsAndServices	= Template.GetArea("Header|ProductsAndServices");
	AreaHeaderCharacteristic	= Template.GetArea("Header|Characteristic");
	AreaPriceGroup 		= Template.GetArea("PriceGroup|ProductsAndServices");
	AreaHeaderPriceKind 			= Template.GetArea("Header|PriceKind");
		
	Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	SpreadsheetDocument.Clear();
	
	If ResultQuery.IsEmpty() Then
		
		Return;
		
	EndIf; 
	
	SpreadsheetDocument.Put(AreaIndent);
	
	If ShowTitle Then
	
		HeaderArea.Parameters.Title	 = "PRICE-SHEET";
		HeaderArea.Parameters.ToDate		 = Format(ToDate, "DF=dd.MM.yyyy");
		SpreadsheetDocument.Put(HeaderArea);	
		
	EndIf;	
		
	AreaHeaderProductsAndServices.Parameters.SKUCode = ?(OutputCode = Enums.YesNo.Yes, "Code", "SKU");
	
	SpreadsheetDocument.Put(AreaHeaderProductsAndServices);
	If UseCharacteristics Then
		
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);
		
	EndIf;
	
	NPP = 0;
	TablePriceKinds.Clear();
	SelectionPriceKind = ResultQuery.Select(QueryResultIteration.ByGroups, "PriceKind");
	While SelectionPriceKind.Next() Do
		
		AreaHeaderPriceKind.Parameters.PriceKind = SelectionPriceKind.PriceKind;
		AreaHeaderPriceKind.Parameters.Currency = SelectionPriceKind.PriceKind.PriceCurrency;
		
		SpreadsheetDocument.Join(AreaHeaderPriceKind);
		
		NewRow 		= TablePriceKinds.Add();
		NewRow.PriceKind	= SelectionPriceKind.PriceKind;
		NewRow.NPP		= NPP;
		
		NPP					= NPP + 1;
		
	EndDo; 
	
	SelectionParent = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
	While SelectionParent.Next() Do
		
		If ValueIsFilled(SelectionParent.Parent) Then
			
			AreaPriceGroup.Parameters.PriceGroup = SelectionParent.Parent;
			SpreadsheetDocument.Put(AreaPriceGroup);
			
			CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
			CurrentAreaPriceGroup.Merge();
			
			CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
			CurrentAreaPriceGroup.Details = SelectionParent.Parent;
			SpreadsheetDocument.StartRowGroup();
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
			
				If SelectionPriceGroup.PriceGroup = SelectionPriceGroup.Parent Then
					
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceKinds);
					
				Else
					
					AreaPriceGroup.Parameters.PriceGroup = SelectionPriceGroup.PriceGroup;
					SpreadsheetDocument.Put(AreaPriceGroup);
					
					CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
					CurrentAreaPriceGroup.Merge();
					
					CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
					CurrentAreaPriceGroup.Details = SelectionPriceGroup.PriceGroup;
					SpreadsheetDocument.StartRowGroup();
					
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, True, SpreadsheetDocument, Template, ParametersStructure, TablePriceKinds);
					
					SpreadsheetDocument.EndRowGroup();
					
				EndIf;
			
			EndDo;
			
			SpreadsheetDocument.EndRowGroup();
			
		Else
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
				
				OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceKinds);
				
			EndDo;
				
		EndIf;
	
	EndDo;
	
	AreaTable = SpreadsheetDocument.Area(?(ShowTitle, 5, 2), 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
 
	AreaTable.TopBorder 	= Line;
	AreaTable.BottomBorder 	= Line;
	AreaTable.LeftBorder 	= Line;
	AreaTable.RightBorder 	= Line;
	
EndProcedure

Procedure OutputDataOnProductAndServicesParent(ProductsAndServicesParentSelection, SpreadsheetDocument, ResultQuery, TablePriceKinds, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup)
	
	If Not ValueIsFilled(ProductsAndServicesParentSelection) Then
		
		AreaPriceGroup.Parameters.PriceGroup = NStr("en = '<...>'");
		SpreadsheetDocument.Put(AreaPriceGroup);
		
		CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
		CurrentAreaPriceGroup.Merge();
		
		CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
		
		SpreadsheetDocument.StartRowGroup();
		
		Filter = New Structure("Parent", ProductsAndServicesParentSelection);
		
		Selection = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
		While Selection.FindNext(Filter) Do
			
			OutputDetails(Selection.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceKinds);
			
		EndDo;
		
		SpreadsheetDocument.EndRowGroup();
		
	Else
		
		AreaPriceGroup.Parameters.PriceGroup = ProductsAndServicesParentSelection.Ref;
		SpreadsheetDocument.Put(AreaPriceGroup);
		
		CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
		CurrentAreaPriceGroup.Merge();
		
		CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
		CurrentAreaPriceGroup.Details = ProductsAndServicesParentSelection.Ref;
		
		SpreadsheetDocument.StartRowGroup();
		
		ProductsAndServicesParentSubordinateSelection = ProductsAndServicesParentSelection.Select(QueryResultIteration.ByGroupsWithHierarchy);
		While ProductsAndServicesParentSubordinateSelection.Next() Do
			
			OutputDataOnProductAndServicesParent(ProductsAndServicesParentSubordinateSelection, SpreadsheetDocument, ResultQuery, TablePriceKinds, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup)
			
		EndDo;
		
		Filter = New Structure("Parent", ProductsAndServicesParentSelection.Ref);
		Selection = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
		While Selection.FindNext(Filter) Do
			
			OutputDetails(Selection.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceKinds);
			
		EndDo;
		
		SpreadsheetDocument.EndRowGroup();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf