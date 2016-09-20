
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
// Generate a filter structure according to passed parameters
//
// DetailsMatch - map received from details
//
Function GetCounterpartyPriceKindChoiceList(DetailsMatch, CopyChangeDelete = FALSE)
	
	ChoiceList = New ValueList;
	
	If TypeOf(DetailsMatch) = Type("Map") Then
		
		For Each MapItem IN DetailsMatch Do
			
			If (CopyChangeDelete
				AND Not TypeOf(MapItem.Value) = Type("Structure"))
				OR (TypeOf(MapItem.Value) = Type("Structure")
					AND MapItem.Value.Property("Price")
					AND Not ValueIsFilled(MapItem.Value.Price)) Then
				
				Continue;
				
			EndIf;
			
			ChoiceList.Add(MapItem.Key, TrimAll(MapItem.Key));
			
		EndDo;
		
	EndIf;
	
	Return ChoiceList;
	
EndFunction // GetSelectionStructure()

&AtServer
// Creates price kind map for the tabular document fields details
//
Function CreateMapPattern()
	
	MapForDetail = New Map;
	
	For Each TableRow IN TableCounterpartyPriceKind Do
		
		If ValueIsFilled(TableRow.CounterpartyPriceKind) Then
			
			MapForDetail.Insert(TableRow.CounterpartyPriceKind, Catalogs.PriceKinds.EmptyRef());
			
		EndIf;
		
	EndDo;
	
	Return MapForDetail;
	
EndFunction //CreateMapPattern()

&AtServer
// Procedure updates the form title
//
Procedure UpdateFormTitleAtServer()
	
	ThisForm.Title	= NStr("en=""Counterparties' price lists"";ru='прайс-листы контрагентов'") + 
		?(ValueIsFilled(ToDate), NStr("en=' on ';ru=' на '") + Format(ToDate, "DLF=DD"), NStr("en='.';ru='.'"));
	
EndProcedure // UpdateFormTitleAtServer()

&AtServer
// Procedure fills tabular document.
//
Procedure UpdateAtServer()
	
	UpdateFormTitleAtServer();
	
	SpreadsheetDocument.Clear();
	
	Query = New Query;
	
	VirtualTableParameters = "&Period, ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem) ";
	
	Conjunction = "AND ";
	
	If ValueIsFilled(CounterpartyPriceKind) Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + " CounterpartyPriceKind = &CounterpartyPriceKind ";
		Conjunction = "AND ";
		
		Query.SetParameter("CounterpartyPriceKind", CounterpartyPriceKind);
		
	ElsIf Object.CounterpartyPriceKind.Count() > 0 Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + " CounterpartyPriceKind IN (&ArrayCounterpartyPriceKind) ";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayCounterpartyPriceKind", Object.CounterpartyPriceKind.Unload(,"Ref"));
		
	EndIf;
	
	If ValueIsFilled(PriceGroup) Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "ProductsAndServices.PriceGroup IN HIERARCHY (&PriceGroup) ";
		Conjunction = "AND ";	
		
		Query.SetParameter("PriceGroup",  	PriceGroup);
		
	ElsIf Object.PriceGroups.Count() > 0 Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "ProductsAndServices.PriceGroup IN HIERARCHY (&ArrayPriceGroup) ";
		Conjunction = "AND ";	
		
		Query.SetParameter("ArrayPriceGroup", Object.PriceGroups.Unload(,"Ref"));
		
	EndIf; 
	
	If ValueIsFilled(ProductsAndServices) Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "ProductsAndServices IN HIERARCHY (&ProductsAndServices) ";
		
		Query.SetParameter("ProductsAndServices", ProductsAndServices);
		
	ElsIf Object.ProductsAndServices.Count() > 0 Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "ProductsAndServices IN HIERARCHY (&ArrayProductsAndServices) ";
		
		Query.SetParameter("ArrayProductsAndServices", Object.ProductsAndServices.Unload(,"Ref"));
		
	EndIf; 
	
	Condition = "";	
	If Actuality Then
		Condition = "
		|WHERE
		|	CounterpartyProductsAndServicesPricesSliceLast.Actuality";	
	EndIf;
		
	Query.SetParameter("Period",  			ToDate);
	
	Query.Text =
	"SELECT
	|	Groups.ProductsAndServices AS ProductsAndServices,
	|	Groups.PriceGroup AS PriceGroup,
	|	Groups.Parent AS Parent,
	|	Groups.Characteristic AS Characteristic,
	|	Groups.CounterpartyPriceKind AS CounterpartyPriceKind,
	|	Groups.CounterpartyPriceKind.Owner AS Counterparty,
	|	CounterpartyProductsAndServicesPricesSliceLast.MeasurementUnit,
	|	CounterpartyProductsAndServicesPricesSliceLast.Actuality,
	|	CounterpartyProductsAndServicesPricesSliceLast.Price,
	|	Groups.CounterpartyPriceKind.PriceCurrency AS Currency
	|FROM
	|	(SELECT
	|		ProductsAndServicesCharacteristic.ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServicesCharacteristic.Characteristic AS Characteristic,
	|		Columns.CounterpartyPriceKind AS CounterpartyPriceKind,
	|		ProductsAndServicesCharacteristic.PriceGroup AS PriceGroup,
	|		ProductsAndServicesCharacteristic.Parent AS Parent,
	|		ProductsAndServicesCharacteristic.Order AS Order,
	|		ProductsAndServicesCharacteristic.ParentOrder AS ParentOrder
	|	FROM
	|		(SELECT DISTINCT
	|			CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind AS CounterpartyPriceKind
	|		FROM
	|			InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|					" + VirtualTableParameters + ") AS CounterpartyProductsAndServicesPricesSliceLast) AS Columns,
	|		(SELECT DISTINCT
	|			CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices AS ProductsAndServices,
	|			CounterpartyProductsAndServicesPricesSliceLast.Characteristic AS Characteristic,
	|			CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup AS PriceGroup,
	|			CASE
	|				WHEN CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|					THEN CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup
	|				ELSE CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent
	|			END AS Parent,
	|			CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Order AS Order,
	|			CASE
	|				WHEN CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|					THEN CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Order
	|				ELSE CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices.PriceGroup.Parent.Order
	|			END AS ParentOrder
	|		FROM
	|			InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|					" + VirtualTableParameters + ") AS CounterpartyProductsAndServicesPricesSliceLast) AS ProductsAndServicesCharacteristic) AS Groups 
	|		LEFT JOIN InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|					" + VirtualTableParameters + ") AS CounterpartyProductsAndServicesPricesSliceLast 
	|		ON Groups.ProductsAndServices = CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices 
	|			AND Groups.Characteristic = CounterpartyProductsAndServicesPricesSliceLast.Characteristic
	|			AND Groups.CounterpartyPriceKind = CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind" + Condition + "
	|
	|ORDER BY
	|	Groups.ParentOrder,
	|	Groups.Order,
	|	Groups.ProductsAndServices.Description,
	|	Groups.Characteristic.Description,
	|	CounterpartyPriceKind,
	|	Counterparty 
	|TOTALS BY
	|	Parent,
	|	PriceGroup,
	|	ProductsAndServices,
	|	Characteristic,
	|	CounterpartyPriceKind";
	
	ResultQuery = Query.Execute();
	
	Template = DataProcessors.CounterpartyPriceLists.GetTemplate("Template");
	
	AreaIndent	 				= Template.GetArea("Indent|ProductsAndServices");
	HeaderArea 				= Template.GetArea("Title|ProductsAndServices");
	AreaHeaderProductsAndServices 		= Template.GetArea("Header|ProductsAndServices");
	AreaHeaderCharacteristic 		= Template.GetArea("Header|Characteristic");
	AreaPriceGroup 			= Template.GetArea("PriceGroup|ProductsAndServices");
	AreaHeaderPriceKindCounterparty 	= Template.GetArea("Header|CounterpartyPriceKind");
		
	Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	If ResultQuery.IsEmpty() Then
		Return;
	EndIf; 
	
	SpreadsheetDocument.Put(AreaIndent);
	
	If Items.ShowTitle.Check Then
	
		HeaderArea.Parameters.Title	 = "PRICE-SHEET";
		HeaderArea.Parameters.ToDate		 = Format(ToDate, "DF=dd.MM.yyyy");
		SpreadsheetDocument.Put(HeaderArea);	
		
	EndIf;	
		
	SpreadsheetDocument.Put(AreaHeaderProductsAndServices);
	If UseCharacteristics Then
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);	
	EndIf;
	
	NPP = 0;
	TableCounterpartyPriceKind.Clear();
	
	SelectionCounterpartyPriceKind = ResultQuery.Select(QueryResultIteration.ByGroups, "CounterpartyPriceKind");
	While SelectionCounterpartyPriceKind.Next() Do
		AreaHeaderPriceKindCounterparty.Parameters.CounterpartyPriceKind = SelectionCounterpartyPriceKind.CounterpartyPriceKind;
		AreaHeaderPriceKindCounterparty.Parameters.Counterparty = SelectionCounterpartyPriceKind.Counterparty;
		AreaHeaderPriceKindCounterparty.Parameters.Currency = SelectionCounterpartyPriceKind.Currency;
		SpreadsheetDocument.Join(AreaHeaderPriceKindCounterparty);
		
		NewRow = TableCounterpartyPriceKind.Add();
		NewRow.CounterpartyPriceKind = SelectionCounterpartyPriceKind.CounterpartyPriceKind;
		NewRow.NPP = NPP;
		NPP = NPP + 1;
	EndDo; 
	
	SelectionParent = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
	While SelectionParent.Next() Do
		
		If ValueIsFilled(SelectionParent.Parent) Then
				
			AreaPriceGroup.Parameters.PriceGroup = SelectionParent.Parent;
			SpreadsheetDocument.Put(AreaPriceGroup);
			CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
			CurrentAreaPriceGroup.Merge();
			CurrentAreaPriceGroup.BackColor = New Color(252, 249, 226);
			CurrentAreaPriceGroup.Details = SelectionParent.Parent;
			SpreadsheetDocument.StartRowGroup();	
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
				
				If SelectionPriceGroup.PriceGroup = SelectionPriceGroup.Parent Then
					
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, False, Template);
					
				Else					
					
					AreaPriceGroup.Parameters.PriceGroup = SelectionPriceGroup.PriceGroup;
					SpreadsheetDocument.Put(AreaPriceGroup);
					
					CurrentAreaPriceGroup 			= SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
					CurrentAreaPriceGroup.Merge();
					CurrentAreaPriceGroup.BackColor	= New Color(252, 249, 226);
					CurrentAreaPriceGroup.Details = SelectionPriceGroup.PriceGroup;
					SpreadsheetDocument.StartRowGroup();
					
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, True, Template);
					
					SpreadsheetDocument.EndRowGroup();
					
				EndIf;
			
			EndDo;
			
			SpreadsheetDocument.EndRowGroup();
			
		Else
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
				OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "ProductsAndServices"), UseCharacteristics, False, Template);
			EndDo;	
				
		EndIf;
	
	EndDo;
	
	AreaTable = SpreadsheetDocument.Area(?(Items.ShowTitle.Check, 5, 2), 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
 
	AreaTable.TopBorder 	= Line;
	AreaTable.BottomBorder 	= Line;
	AreaTable.LeftBorder 	= Line;
	AreaTable.RightBorder 	= Line;
	
EndProcedure

&AtServer
// Procedure displays detailed records in tabular document.
//
Procedure OutputDetails(SelectionProductsAndServices, UseCharacteristics, UsePriceGroups, Template)
	
	AreaDetailsProductsAndServices 		= Template.GetArea("Details|ProductsAndServices");
	AreaDetailsCharacteristic 	= Template.GetArea("Details|Characteristic");
	AreaDetailsPriceKindCounterparty	= Template.GetArea("Details|CounterpartyPriceKind");
		
	While SelectionProductsAndServices.Next() Do
			
		SelectionCharacteristic = SelectionProductsAndServices.Select(QueryResultIteration.ByGroups, "Characteristic");
		While SelectionCharacteristic.Next() Do
			
			ProductsAndServicesCharacteristicDetailsStructure = New Structure;
			ProductsAndServicesCharacteristicDetailsStructure.Insert("ProductsAndServices",				SelectionProductsAndServices.ProductsAndServices);
			ProductsAndServicesCharacteristicDetailsStructure.Insert("Characteristic",			Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
			ProductsAndServicesCharacteristicDetailsStructure.Insert("DetailsMatch",	CreateMapPattern());
			
			TableHeight = SpreadsheetDocument.TableHeight;
			TableWidth = ?(UseCharacteristics, 3, 2);
			
			AreaDetailsProductsAndServices.Parameters.ProductsAndServices = SelectionCharacteristic.ProductsAndServices;
			SpreadsheetDocument.Put(AreaDetailsProductsAndServices);
			If UseCharacteristics Then
				AreaDetailsCharacteristic.Parameters.Characteristic = SelectionCharacteristic.Characteristic;
				SpreadsheetDocument.Join(AreaDetailsCharacteristic);
			EndIf;
			
			//Remember the used prices in the values list
			UsedPrices = New ValueList;
			
			SelectionCounterpartyPriceKind = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "CounterpartyPriceKind");
			While SelectionCounterpartyPriceKind.Next() Do
				
				Selection = SelectionCounterpartyPriceKind.Select();
				While Selection.Next() Do	
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("ProductsAndServices", 		Selection.ProductsAndServices);
					DetailsStructure.Insert("Characteristic", 	Selection.Characteristic);
					DetailsStructure.Insert("CounterpartyPriceKind", 	Selection.CounterpartyPriceKind);
					DetailsStructure.Insert("Period", 			ToDate);
					DetailsStructure.Insert("Price", 				Selection.Price);
					DetailsStructure.Insert("Actuality", 		Selection.Actuality);
					DetailsStructure.Insert("MeasurementUnit", 	Selection.MeasurementUnit);
					
					NPP = TableCounterpartyPriceKind.FindRows(New Structure("CounterpartyPriceKind", Selection.CounterpartyPriceKind))[0].NPP;
					
					AreaUnit 				= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP*2 + 1);
					AreaUnit.Text 		= Selection.MeasurementUnit;
					AreaUnit.Details 	= DetailsStructure;
					AreaUnit.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
					
					AreaPrice 				= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP*2 + 2);
					AreaPrice.Text 			= Format(Selection.Price, "ND=15; NFD=2");
					AreaPrice.Details 	= DetailsStructure;
					
					ProductsAndServicesCharacteristicDetailsStructure.DetailsMatch.Insert(Selection.CounterpartyPriceKind, DetailsStructure);
					UsedPrices.Add(Selection.CounterpartyPriceKind);
					
				EndDo;
				
			EndDo;
			
			//Fill out explanation for other price kinds.
			For Each CounterpartyPriceKindTableRow IN TableCounterpartyPriceKind Do
				
				If UsedPrices.FindByValue(CounterpartyPriceKindTableRow.CounterpartyPriceKind) = Undefined Then
					
					AreaUnit	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + CounterpartyPriceKindTableRow.NPP*2 + 1);
					AreaPrice 	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + CounterpartyPriceKindTableRow.NPP*2 + 2);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("ProductsAndServices", 		SelectionProductsAndServices.ProductsAndServices);
					DetailsStructure.Insert("Characteristic", 	SelectionCharacteristic.Characteristic);
					DetailsStructure.Insert("CounterpartyPriceKind", 	CounterpartyPriceKindTableRow.CounterpartyPriceKind);
					DetailsStructure.Insert("Period", 			ToDate);
					DetailsStructure.Insert("MeasurementUnit", 	SelectionProductsAndServices.ProductsAndServices.MeasurementUnit);
					
					AreaUnit.Details	= DetailsStructure;
					AreaPrice.Details 	= DetailsStructure;
					
				EndIf;
				
			EndDo;
			
			AreaProductsAndServices 			= SpreadsheetDocument.Area(TableHeight + 1, 2);
			AreaProductsAndServices.Text 		= ?(FullDescr, SelectionProductsAndServices.ProductsAndServices.DescriptionFull, SelectionProductsAndServices.ProductsAndServices.Description);
			AreaProductsAndServices.Details	= ProductsAndServicesCharacteristicDetailsStructure;
			
			If UseCharacteristics Then
				
				AreaCharacteristic 				= SpreadsheetDocument.Area(TableHeight + 1, 3);
				AreaCharacteristic.Details 	= ProductsAndServicesCharacteristicDetailsStructure;
				
			EndIf;
			
			SpreadsheetDocument.Area(TableHeight + 1, 2, SpreadsheetDocument.TableHeight, 2).Merge();
			If UseCharacteristics Then
				
				SpreadsheetDocument.Area(TableHeight + 1, 3, SpreadsheetDocument.TableHeight, 3).Merge();
				
			EndIf;
			
		EndDo;
	
	EndDo;
		
EndProcedure

&AtServerNoContext
// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure, ActualOnly = False)

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	CounterpartyProductsAndServicesPricesSliceLast.Period
	|FROM
	|	InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|			&ToDate,
	|			CounterpartyPriceKind = &CounterpartyPriceKind
	|				AND ProductsAndServices = &ProductsAndServices
	|				AND Characteristic = &Characteristic
	|				AND &ActualOnly) AS CounterpartyProductsAndServicesPricesSliceLast";
	
	If ActualOnly Then
		
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "Actuality");
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "True");
		
	EndIf;
	
	
	Query.SetParameter("ToDate", 					ParametersStructure.Period);
	Query.SetParameter("ProductsAndServices", 				ParametersStructure.ProductsAndServices);
	Query.SetParameter("Characteristic", 			ParametersStructure.Characteristic);
	Query.SetParameter("CounterpartyPriceKind", 			ParametersStructure.CounterpartyPriceKind);

	ReturnStructure = New Structure("NewRegisterRecord, Period, CounterpartyPriceKind, ProductsAndServices, Characteristic", True);
	FillPropertyValues(ReturnStructure, ParametersStructure);
	
	ResultTable = Query.Execute().Unload();
	If ResultTable.Count() > 0 Then
		
		ReturnStructure.Period 				= ResultTable[0].Period;
		ReturnStructure.NewRegisterRecord	= False;
		
	EndIf; 

	Return ReturnStructure;

EndFunction // GetRecordKey()

&AtClient
// Creates a decoration title by the first items values of the specified tabular section
//
Function GetDecorationTitleContent(TabularSectionName) 
	
	If Object[TabularSectionName].Count() < 1 Then
		
		DecorationTitle = "Multiple filter is not filled";
		
	ElsIf Object[TabularSectionName].Count() = 2 Then
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref);
		
	ElsIf Object[TabularSectionName].Count() > 2 Then
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref) + "...";
		
	Else
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref);
		
	EndIf;
	
	Return DecorationTitle;
	
EndFunction //GetDecorationTitleContent()

&AtClient
// Procedure analyses executed specified filters
//
Procedure AnalyzeChoice(TabularSectionName)
	
	ItemCount = Object[TabularSectionName].Count();
	
	ChangeFilterPage(TabularSectionName, ItemCount > 0);
	
EndProcedure // AnalyzeChoice()

&AtClient
// Procedure opens the register record.
//
Procedure OpenRegisterRecordForm(ParametersStructure)

	RecordKey = GetRecordKey(ParametersStructure, Actuality);
	If ValueIsFilled(RecordKey)
		AND TypeOf(RecordKey) = Type("Structure") 
		AND Not RecordKey.NewRegisterRecord Then
		
		RecordKey.Delete("NewRegisterRecord");
		
		ParametersArray = New Array;
		ParametersArray.Add(RecordKey);
		RecordKeyRegister = New("InformationRegisterRecordKey.CounterpartyProductsAndServicesPrices", ParametersArray);
		OpenForm("InformationRegister.CounterpartyProductsAndServicesPrices.RecordForm", New Structure("Key", RecordKeyRegister));
		
	Else
		
		OpenForm("InformationRegister.CounterpartyProductsAndServicesPrices.RecordForm", New Structure("FillingValues", RecordKey));
		
	EndIf; 
	
EndProcedure // OpenRegisterRecordForm()

&AtServer
// Procedure removes register record.
//
Procedure DeleteAtServer(ParametersStructure)

	RecordKey = GetRecordKey(ParametersStructure);

	If Not ValueIsFilled(RecordKey) 
		OR TypeOf(RecordKey) <> Type("Structure") 
		OR RecordKey.NewRegisterRecord Then
		
		Return;
		
	EndIf; 
	
	RecordKey.Delete("NewRegisterRecord");
	
	RecordSet = InformationRegisters.CounterpartyProductsAndServicesPrices.CreateRecordSet();
	
	For Each StructureItem IN RecordKey Do
		
		RecordSet.Filter[StructureItem.Key].Set(StructureItem.Value);
		
	EndDo; 
	
	RecordSet.Write();

EndProcedure // Delete()

&AtServerNoContext
// Procedure saves the form settings.
//
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("DatProcessorCounterpartyPriceListsForm", "SettingsStructure", SettingsStructure);
	
EndProcedure

&AtClient
// Function returns the value array containing tabular section units
//
// TabularSectionName - tabular section ID,the units of which fill the array
//
Function FillArrayByTabularSectionAtClient(TabularSectionName)
	
	ValueArray = New Array;
	
	For Each TableRow IN Object[TabularSectionName] Do
		
		ValueArray.Add(TableRow.Ref);
		
	EndDo;
	
	Return ValueArray;
	
EndFunction //FillArrayByTabularSectionAtClient()

&AtClient
// Fills the specified tabular section by values from the passed array
//
Procedure FillTabularSectionFromArrayItemsAtClient(TabularSectionName, ItemArray, ClearTable)
	
	If ClearTable Then
		
		Object[TabularSectionName].Clear();
		
	EndIf;
	
	For Each ArrayElement IN ItemArray Do
		
		NewRow 		= Object[TabularSectionName].Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure // FillTabularSectionFromArrayItemsAtClient()

&AtClient
// Toggling pages with filters(Quick/Multiple)
//
Procedure ChangeFilterPage(TabularSectionName, List)
	
	GroupPages = Items["FilterPages" + TabularSectionName];
	
	SetAsCurrentPage = Undefined;
	
	For Each PageOfGroup in GroupPages.ChildItems Do
		
		If List Then
			
			If Find(PageOfGroup.Name, "MultipleFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
			
			EndIf;
			
		Else
			
			If Find(PageOfGroup.Name, "QuickFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Items["DecorationMultipleFilter" + TabularSectionName].Title = GetDecorationTitleContent(TabularSectionName);
	
	GroupPages.CurrentPage = SetAsCurrentPage;
	
EndProcedure // ChangeFilterPage()

&AtServer
//Procedure fills the filters with the values from the saved settings
//
Procedure RestoreValuesOfFilters(SettingsStructure, TSNamesStructure)
	
	For Each NamesStructureItem IN TSNamesStructure Do
		
		TabularSectionName	= NamesStructureItem.Key;
		If SettingsStructure.Property(NamesStructureItem.Value) Then
			
			ItemArray		= SettingsStructure[NamesStructureItem.Value];
			
		EndIf;
		
		If Not TypeOf(ItemArray) = Type("Array") 
			OR ItemArray.Count() < 1 Then
			
			Continue;
			
		EndIf;
		
		Object[TabularSectionName].Clear();
		
		For Each ArrayElement IN ItemArray Do
			
			NewRow 		= Object[TabularSectionName].Add();
			NewRow.Ref	= ArrayElement;
			
		EndDo;
	
	EndDo;
	
	If Object.CounterpartyPriceKind.Count() < 1 Then
		
		CounterpartyPriceKind = SettingsStructure.CounterpartyPriceKind;
		
	EndIf;
	
	If Object.PriceGroups.Count() < 1 Then 
		
		PriceGroup = SettingsStructure.PriceGroup;
	
	EndIf;
	
	If Object.ProductsAndServices.Count() < 1 Then
		
		ProductsAndServices = SettingsStructure.ProductsAndServices;
		
	EndIf;
	
	If SettingsStructure.Property("ToDate") Then
		
		ToDate = SettingsStructure.ToDate;
		
	EndIf;
	
	If SettingsStructure.Property("Actuality") Then
		
		Actuality = SettingsStructure.Actuality;
		
	EndIf;
	
	If SettingsStructure.Property("FullDescr") Then
		
		FullDescr = SettingsStructure.FullDescr;
		
	EndIf;
	
EndProcedure // RestoreFiltersValues()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SettingsStructure = FormDataSettingsStorage.Load("DatProcessorCounterpartyPriceListsForm", "SettingsStructure");
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		TSNamesStructure = New Structure("CounterpartyPriceKind, PriceGroups, ProductsAndServices", "TS_CounterpartyPriceKind", "CWT_PriceGroups", "CWT_ProductsAndServices");
		RestoreValuesOfFilters(SettingsStructure, TSNamesStructure);
		
	Else
		
		ToDate 			= CurrentDate();
		Actuality	= True;
		
	EndIf;	
	
	UseCharacteristics 				= Constants.FunctionalOptionUseCharacteristics.Get();
	Items.ShowTitle.Check	= False;
	
	UpdateFormTitleAtServer();
	
	UpdateAtServer();
	
	CurrentArea = "R1C1";
	
EndProcedure

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	
	//Set current form pages depending on the saved filters
	AnalyzeChoice("CounterpartyPriceKind");
	AnalyzeChoice("PriceGroups");
	AnalyzeChoice("ProductsAndServices");
	
EndProcedure // OnOpen()

&AtClient
// Procedure - event handler OnClose form.
//
Procedure OnClose()
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("TS_CounterpartyPriceKind", FillArrayByTabularSectionAtClient("CounterpartyPriceKind"));
	SettingsStructure.Insert("CounterpartyPriceKind", 	CounterpartyPriceKind);
	
	SettingsStructure.Insert("CWT_PriceGroups",		FillArrayByTabularSectionAtClient("PriceGroups"));
	SettingsStructure.Insert("PriceGroup", 		PriceGroup);
	
	SettingsStructure.Insert("CWT_ProductsAndServices",		FillArrayByTabularSectionAtClient("ProductsAndServices"));
	SettingsStructure.Insert("ProductsAndServices",			ProductsAndServices);
	
	SettingsStructure.Insert("ToDate", 				ToDate);
	SettingsStructure.Insert("Actuality",			Actuality);
	SettingsStructure.Insert("FullDescr",	FullDescr);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure

&AtClient
// Procedure - handler of form notification.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	If EventName = "CounterpartyPriceChanged" Then
		
		If Parameter Then
			
			UpdateAtServer();
			
		EndIf;
		
	ElsIf EventName = "MultipleFiltersCounterpartyPriceLists" AND TypeOf(Parameter) = Type("Structure") Then
		
		ToDate 					= Parameter.ToDate;
		Actuality			= Parameter.Actuality;
		FullDescr		= Parameter.FullDescr;
		
		// Counterparty price kinds
		ThisIsMultipleFilter = (TypeOf(Parameter.CounterpartyPriceKind) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("CounterpartyPriceKind", Parameter.CounterpartyPriceKind, True);
			CounterpartyPriceKind = Undefined;
			
		Else
			
			CounterpartyPriceKind = Parameter.CounterpartyPriceKind;
			Object.CounterpartyPriceKind.Clear();
			
		EndIf;
		
		ChangeFilterPage("CounterpartyPriceKind", ThisIsMultipleFilter);
		
		// Price groups
		ThisIsMultipleFilter = (TypeOf(Parameter.PriceGroup) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", Parameter.PriceGroup, True);
			PriceGroup = Undefined;
			
		Else
			
			PriceGroup = Parameter.PriceGroup;
			Object.PriceGroups.Clear();
			
		EndIf;
		
		ChangeFilterPage("PriceGroups", ThisIsMultipleFilter);
		
		// ProductsAndServices
		ThisIsMultipleFilter = (TypeOf(Parameter.ProductsAndServices) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("ProductsAndServices", Parameter.ProductsAndServices, True);
			ProductsAndServices = Undefined;
			
		Else
			
			ProductsAndServices = Parameter.ProductsAndServices;
			Object.ProductsAndServices.Clear();
			
		EndIf;
		
		ChangeFilterPage("ProductsAndServices", ThisIsMultipleFilter);
		
		UpdateAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of form.
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		
		ClearTable = True;
		
		If ChoiceSource.FormName = "DataProcessor.CounterpartyPriceLists.Form.CounterpartyPriceKindEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("CounterpartyPriceKind", ValueSelected, ClearTable);
			AnalyzeChoice("CounterpartyPriceKind");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.CounterpartyPriceLists.Form.PriceGroupsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", ValueSelected, ClearTable);
			AnalyzeChoice("PriceGroups");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.CounterpartyPriceLists.Form.ProductsAndServicesEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("ProductsAndServices", ValueSelected, ClearTable);
			AnalyzeChoice("ProductsAndServices");
			
		EndIf;
		
		UpdateAtServer();
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS

&AtClient
// Procedure - Refresh command handler.
//
Procedure Refresh(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Add command.
//
Procedure Add(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") Then
		
		FillingValues = New Structure("ProductsAndServices", ProductsAndServices);
		
		If ValueIsFilled(CounterpartyPriceKind) Then
			
			FillingValues.Insert("CounterpartyPriceKind", CounterpartyPriceKind);
			
		ElsIf Object.CounterpartyPriceKind.Count() = 1 Then
			
			FillingValues.Insert("CounterpartyPriceKind", Object.CounterpartyPriceKind[0].Ref);
			
		EndIf;
		
		OpenForm("InformationRegister.CounterpartyProductsAndServicesPrices.RecordForm", New Structure("FillingValues", FillingValues));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetCounterpartyPriceKindChoiceList(DetailFromArea.DetailsMatch);
		
		If AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		Else
			
			Details 	= Undefined;
			
		EndIf;
			
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	FillingValues	= New Structure("Counterparty, CounterpartyPriceKind, ProductsAndServices, Characteristic, Actuality", , , , , True);
	
	If Details = Undefined
		OR Not TypeOf(Details) = Type("Structure") Then
		
		If Object.CounterpartyPriceKind.Count() < 1 
			AND ValueIsFilled(CounterpartyPriceKind) Then
			
			FillingValues.Insert("CounterpartyPriceKind", CounterpartyPriceKind);
			
		ElsIf TypeOf(SelectedPriceKind) = Type("ValueListItem") Then
			
			FillingValues.Insert("CounterpartyPriceKind", SelectedPriceKind.Value);
			
		EndIf;
		
		If Object.ProductsAndServices.Count() < 1 
			AND ValueIsFilled(ProductsAndServices) Then
			
			FillingValues.Insert("ProductsAndServices", ProductsAndServices);
			
		ElsIf DetailFromArea.Property("ProductsAndServices")
			AND ValueIsFilled(DetailFromArea.ProductsAndServices) Then
			
			FillingValues.Insert("ProductsAndServices", DetailFromArea.ProductsAndServices);
			
			If DetailFromArea.Property("Characteristic")
				AND ValueIsFilled(DetailFromArea.Characteristic) Then
				
				FillingValues.Insert("Characteristic", DetailFromArea.Characteristic);
				
			EndIf;
			
		ElsIf TypeOf(Details) = Type("CatalogRef.ProductsAndServices") Then
			
			FillingValues.Insert("ProductsAndServices", Details);
			
		ElsIf TypeOf(Details) = Type("CatalogRef.ProductsAndServicesCharacteristics") Then
			
			FillingValues.Insert("ProductsAndServices", SmallBusinessClient.ReadAttributeValue_Owner(Details));
			
		EndIf;
		
		OpenForm("InformationRegister.CounterpartyProductsAndServicesPrices.RecordForm", New Structure("FillingValues", FillingValues));
		Return;
		
	EndIf;
	
	If TypeOf(Details) = Type("Structure") Then
		
		FillingValues.Counterparty			= SmallBusinessClient.ReadAttributeValue_Owner(Details.CounterpartyPriceKind);
		FillingValues.CounterpartyPriceKind 	= Details.CounterpartyPriceKind;
		FillingValues.ProductsAndServices			= Details.ProductsAndServices;
		FillingValues.Characteristic		= Details.Characteristic;
		
	EndIf;
	
	OpenForm("InformationRegister.CounterpartyProductsAndServicesPrices.RecordForm", New Structure("FillingValues", FillingValues),,,,, New NotifyDescription("AddEnd", ThisObject));

EndProcedure

&AtClient
Procedure AddEnd(Result, AdditionalParameters) Export
    
    // StandardSubsystems.PerformanceEstimation
    PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
    // StandardSubsystems.PerformanceEstimation
    
    UpdateAtServer();

EndProcedure

&AtClient
// Procedure - the Copy commands.
//
Procedure Copy(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Impossible to copy the price.
		|Perhaps, empty cell is selected.';ru='Невозможно скопировать цену.
		|Возможно выбрана пустая ячейка.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetCounterpartyPriceKindChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceKindsList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en='No prices available for copying exist for the current products and services in the current price list.';ru='В текущем прайс-листе для данной номенклатурной позиции нет цен, доступных для копирования.'")
						);
						
			Return;
			
		ElsIf AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;

	If Details = Undefined 
		OR Not TypeOf(Details) = Type("Structure") 
		OR Not Details.Property("Price") //There are no price details
		OR (Details.Property("Price") AND Not ValueIsFilled(Details.Price)) //there is a price but it is not filled out
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Perhaps a blank cell is selected.
		|Copying is not possible.';ru='Возможно указана пустая ячейка.
		|Копирование не возможно.'")
				);
				
		Return;
		
	EndIf;
	
	OpenForm("InformationRegister.CounterpartyProductsAndServicesPrices.RecordForm", New Structure("FillingValues", Details));
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - the Change commands.
//
Procedure Change(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (NOT DetailFromArea.Property("DetailsMatch")
		AND Not DetailFromArea.Property("Price")) //There are no price details
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Impossible to change the price.
		|Perhaps, empty cell is selected.';ru='Невозможно изменить цену.
		|Возможно выбрана пустая ячейка.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetCounterpartyPriceKindChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceKindsList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en='No prices available for editing exist for the current products and services in current price list.';ru='В текущем прайс-листе для данной номенклатурной позиции нет цен, доступных для изменения.'")
						);
						
			Return;
			
		ElsIf AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	OpenRegisterRecordForm(Details);
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - The Delete command handler.
//
Procedure Delete(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") 
		OR (NOT DetailFromArea.Property("DetailsMatch")
		AND Not DetailFromArea.Property("Price")) //There are no price details
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='It is impossible to delete the price.
		|Perhaps, empty cell is selected.';ru='Невозможно удалить цену.
		|Возможно выбрана пустая ячейка.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetCounterpartyPriceKindChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceKindsList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en='No prices available for deletion exist for the current products and services in the current price list.';ru='В текущем прайс-листе для данной номенклатурной позиции нет цен, доступных для удаления.'")
						);
						
			Return;
			
		ElsIf AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	DeleteAtServer(Details);
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the History command.
//
Procedure History(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (NOT DetailFromArea.Property("DetailsMatch")
		AND Not DetailFromArea.Property("Price")) //There are no price details
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Can not show history of the prices generation.';ru='Невозможно отобразить историю формирования цен.'")
					);
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceKindsList = GetCounterpartyPriceKindChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceKindsList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en='Cannot show history of price generation for the current products and services.';ru='Невозможно отобразить историю формирорвания цен для данной номенклатурной позиции.'")
						);
						
			Return;
			
		ElsIf AvailablePriceKindsList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceKindsList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	StructureFilter = New Structure;
	
	If TypeOf(Details) = Type("Structure") Then
		
		StructureFilter.Insert("Characteristic", Details.Characteristic);
		StructureFilter.Insert("ProductsAndServices", Details.ProductsAndServices);
		
		If ValueIsFilled(Details.CounterpartyPriceKind) Then
			
			StructureFilter.Insert("CounterpartyPriceKind", Details.CounterpartyPriceKind);
			
		EndIf;
		
		OpenForm("InformationRegister.CounterpartyProductsAndServicesPrices.ListForm", New Structure("Filter", StructureFilter),,,,, New NotifyDescription("HistoryEnd", ThisObject));
		
	EndIf; 

EndProcedure

&AtClient
Procedure HistoryEnd(Result, AdditionalParameters) Export
    
    // StandardSubsystems.PerformanceEstimation
    PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
    // StandardSubsystems.PerformanceEstimation
    
    UpdateAtServer();

EndProcedure

&AtClient
// Procedure - the Print commands.
//
Procedure Print(Command)
	
	If SpreadsheetDocument = Undefined Then
		Return;
	EndIf;

	SpreadsheetDocument.Copies = 1;

	If Not ValueIsFilled(SpreadsheetDocument.PrinterName) Then
		SpreadsheetDocument.FitToPage = True;
	EndIf;
	
	SpreadsheetDocument.Print(False);
	SpreadsheetDocument.Show();

EndProcedure

&AtClient
// Procedure changes the ShowTitle button mark.
//
Procedure ShowTitle(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	Items.ShowTitle.Check = Not Items.ShowTitle.Check;
	
	UpdateAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - handler of the Selection event of the TabularDocument attribute.
//
Procedure SpreadsheetDocumentSelection(Item, Area, StandardProcessing)
	
	If TypeOf(Area.Details) = Type("Structure") Then
		StandardProcessing = False;
		If Area.Left = 2 Then
			OpeningStructure = New Structure("Key", Area.Details.ProductsAndServices);
			OpenForm("Catalog.ProductsAndServices.ObjectForm", OpeningStructure);
		ElsIf UseCharacteristics AND Area.Left = 3 Then
		OpeningStructure = New Structure("Key", Area.Details.Characteristic);
			OpenForm("Catalog.ProductsAndServicesCharacteristics.ObjectForm", OpeningStructure);
		Else
			OpenRegisterRecordForm(Area.Details);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of the OnActivateArea event of the TabularDocument attribute.
//
Procedure SpreadsheetDocumentOnActivateArea(Item)
	
	CurrentArea = Item.CurrentArea.Name;

EndProcedure

&AtClient
// Procedure - The OnChange event handler of the CounterpartyPriceKind attribute.
//
Procedure CounterpartyPriceKindOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the PriceGroup attribute.
//
Procedure PriceGroupOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the ProductsAndServices attribute.
//
Procedure ProductsAndServicesOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PricesKind attribute.
//
Procedure PriceKindClear(Item, StandardProcessing)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PriceGroup attribute.
//
Procedure PriceGroupClear(Item, StandardProcessing)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the ProductsAndServices attribute.
//
Procedure ProductsAndServicesClear(Item, StandardProcessing)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceEstimation
	
	UpdateAtServer();
	
EndProcedure

&AtClient
//Procedure - event handler of the GoToMultipleFilters clicking button
Procedure GoToMultipleFilters(Command)
	
	FormParameters = New Structure;
	
	// Pass filled filters
	FormParameters.Insert("ToDate", 				ToDate);
	FormParameters.Insert("Actuality",			Actuality);
	FormParameters.Insert("FullDescr",	FullDescr);
	
	ParameterValue = ?(Object.CounterpartyPriceKind.Count() > 0, FillArrayByTabularSectionAtClient("CounterpartyPriceKind"), CounterpartyPriceKind);
	FormParameters.Insert("CounterpartyPriceKind", ParameterValue);
	
	ParameterValue = ?(Object.PriceGroups.Count() > 0, FillArrayByTabularSectionAtClient("PriceGroups"), PriceGroup);
	FormParameters.Insert("PriceGroup", ParameterValue);
	
	ParameterValue = ?(Object.ProductsAndServices.Count() > 0, FillArrayByTabularSectionAtClient("ProductsAndServices"), ProductsAndServices);
	FormParameters.Insert("ProductsAndServices", ParameterValue);
	
	OpenForm("DataProcessor.CounterpartyPriceLists.Form.MultipleFiltersForm", FormParameters, ThisForm);
	
EndProcedure //GoToMultipleFilters()

&AtClient
//Procedure - event handler of the the MultipleFilterByPricesKind decoration clicking
//
Procedure MultipleFilterByPriceKindClick(Item)
	
	OpenForm("DataProcessor.CounterpartyPriceLists.Form.CounterpartyPriceKindEditForm", New Structure("ArrayCounterpartyPriceKind", FillArrayByTabularSectionAtClient("CounterpartyPriceKind")), ThisForm);
	
EndProcedure // MultipleFilterByPriceKindClick()

&AtClient
//Procedure - event handler of the MultipleFilterByPriceGroup decoration clicking
//
Procedure MultipleFilterByPriceGroupClick(Item)
	
	OpenForm("DataProcessor.CounterpartyPriceLists.Form.PriceGroupsEditForm", New Structure("ArrayPriceGroups", FillArrayByTabularSectionAtClient("PriceGroups")), ThisForm);
	
EndProcedure // MultipleFilterByPriceGroupClick()

&AtClient
//Procedure - event handler of the MultipleFilterOnProductsAndServices decoration clicking
//
Procedure MultipleFilterByProductsAndServicesClick(Item)
	
	OpenForm("DataProcessor.CounterpartyPriceLists.Form.ProductsAndServicesEditForm", New Structure("ProductsAndServicesArray", FillArrayByTabularSectionAtClient("ProductsAndServices")), ThisForm);
	
EndProcedure // MultipleFilterByProductsAndServicesClick()



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
