#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS OF DOCUMENT

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(BySpecification, RequiredQuantity, UsedMeasurementUnit, OnRequest) Export
    
	Query = New Query(
	"SELECT
	|	MAX(SpecificationsContent.LineNumber) AS SpecificationsContentLineNumber,
	|	SpecificationsContent.ProductsAndServices AS ProductsAndServices,
	|	SpecificationsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SpecificationsContent.MeasurementUnit AS MeasurementUnit,
	|	SpecificationsContent.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(&MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * &Quantity
	|			ELSE SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * &Factor * &Quantity
	|		END) AS Quantity,
	|	&CustomerOrder AS CustomerOrder
	|FROM
	|	Catalog.Specifications.Content AS SpecificationsContent
	|WHERE
	|	SpecificationsContent.Ref = &Specification
	|	AND SpecificationsContent.ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType
	|
	|GROUP BY
	|	SpecificationsContent.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	SpecificationsContent.MeasurementUnit,
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.ContentRowType,
	|	SpecificationsContent.CostPercentage
	|
	|ORDER BY
	|	SpecificationsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", Constants.FunctionalOptionUseCharacteristics.Get());
	Query.SetParameter("ProcessingDate", EndOfDay(Date));
	
	Query.SetParameter("CustomerOrder", OnRequest);
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("Quantity", RequiredQuantity);
	
	Query.SetParameter("MeasurementUnit", UsedMeasurementUnit);
	
	If TypeOf(UsedMeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
    	Query.SetParameter("Factor", 1);
	Else
		Query.SetParameter("Factor", UsedMeasurementUnit.Factor);
	EndIf;
	
	Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			
			FillTabularSectionBySpecification(Selection.Specification, Selection.Quantity, Selection.MeasurementUnit, OnRequest);
			
		Else
			
	    	NewRow = Inventory.Add();
	    	FillPropertyValues(NewRow, Selection);
			
		EndIf;
		
   EndDo;

EndProcedure // FillTabularSectionBySpecification()

// Procedure allocates tabular section by specification.
//
Procedure DistributeTabularSectionBySpecification(OnLine, TemporaryTableDistribution, ProductionSpecification) Export
    
	Query = New Query(
	"SELECT
	|	MAX(SpecificationsContent.LineNumber) AS SpecificationsContentLineNumber,
	|	SpecificationsContent.ProductsAndServices AS ProductsAndServices,
	|	SpecificationsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SpecificationsContent.MeasurementUnit AS MeasurementUnit,
	|	SpecificationsContent.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(&MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * &Quantity
	|			ELSE SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * &Factor * &Quantity
	|		END) AS Quantity,
	|	&Products AS Products,
	|	&ProductCharacteristic AS ProductCharacteristic,
	|	&ProductionBatch AS ProductionBatch,
	|	&CustomerOrder AS CustomerOrder
	|FROM
	|	Catalog.Specifications.Content AS SpecificationsContent
	|WHERE
	|	SpecificationsContent.Ref = &Specification
	|	AND SpecificationsContent.ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType
	|
	|GROUP BY
	|	SpecificationsContent.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	SpecificationsContent.MeasurementUnit,
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.ContentRowType,
	|	SpecificationsContent.CostPercentage
	|
	|ORDER BY
	|	SpecificationsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", Constants.FunctionalOptionUseCharacteristics.Get());
	Query.SetParameter("ProcessingDate", EndOfDay(Date));
	
	Query.SetParameter("Products", 					OnLine.Products);
	Query.SetParameter("ProductCharacteristic", 	OnLine.ProductCharacteristic);
	Query.SetParameter("ProductionBatch", 			OnLine.ProductionBatch);
	Query.SetParameter("CustomerOrder", 			OnLine.CustomerOrder);
	    	
	Query.SetParameter("Specification", OnLine.Specification);
	Query.SetParameter("Quantity", OnLine.Quantity);
	
	Query.SetParameter("MeasurementUnit", OnLine.MeasurementUnit);
	
	If TypeOf(OnLine.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
    	Query.SetParameter("Factor", 1);
	Else
		Query.SetParameter("Factor", OnLine.MeasurementUnit.Factor);
	EndIf;
	
	Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			
			DistributeTabularSectionBySpecification(Selection, TemporaryTableDistribution, ProductionSpecification);
			
		Else
			
	    	NewRow = TemporaryTableDistribution.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.ProductionSpecification = ProductionSpecification;
			
		EndIf;
		
   EndDo;

EndProcedure // DistributeTabularSectionBySpecification()

// Procedure fills inventory according to standards.
//
Procedure RunInventoryFillingByStandards() Export
	
	Inventory.Clear();
	InventoryDistribution.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CostAllocationProducts.Specification AS Specification,
	|	CostAllocationProducts.CustomerOrder AS CustomerOrder,
	|	CostAllocationProducts.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&CostAllocationProducts AS CostAllocationProducts
	|WHERE
	|	CostAllocationProducts.Specification <> VALUE(Catalog.Specifications.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(SpecificationsContent.LineNumber) AS SpecificationsContentLineNumber,
	|	SpecificationsContent.ContentRowType AS ContentRowType,
	|	SpecificationsContent.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SpecificationsContent.MeasurementUnit AS MeasurementUnit,
	|	SpecificationsContent.Specification AS Specification,
	|	TemporaryTableProduction.CustomerOrder AS CustomerOrder,
	|	SUM(SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * TemporaryTableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TemporaryTableProduction
	|		LEFT JOIN Catalog.Specifications.Content AS SpecificationsContent
	|		ON TemporaryTableProduction.Specification = SpecificationsContent.Ref
	|WHERE
	|	SpecificationsContent.ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType
	|
	|GROUP BY
	|	SpecificationsContent.ProductsAndServices,
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.ContentRowType,
	|	TemporaryTableProduction.CustomerOrder,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	SpecificationsContent.MeasurementUnit
	|
	|ORDER BY
	|	SpecificationsContentLineNumber";
	
	UseCharacteristics = Constants.FunctionalOptionUseCharacteristics.Get(); 
	
	TemporaryTableProduction = Products.Unload();
	
	For Each StringTT IN TemporaryTableProduction Do
		If TypeOf(StringTT.MeasurementUnit) = Type("CatalogRef.UOM") Then
			StringTT.Quantity = StringTT.Quantity * StringTT.MeasurementUnit.Factor;
		EndIf;	
	EndDo;	
	
	Query.SetParameter("CostAllocationProducts", TemporaryTableProduction);
	Query.SetParameter("UseCharacteristics", 	UseCharacteristics);
	
	Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
	
	TableInventory = Query.Execute().Unload();
	For Each VTRow IN TableInventory Do
		
		If VTRow.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			
			FillTabularSectionBySpecification(VTRow.Specification, VTRow.Quantity, VTRow.MeasurementUnit, VTRow.CustomerOrder);
									
		Else	
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, VTRow);
						
		EndIf;	
		
	EndDo;	
	
	Inventory.GroupBy("ProductsAndServices, Characteristic, MeasurementUnit, CustomerOrder, Specification", "Quantity");
	
	ConnectionKey = 0;
	For Each TabularSectionRow IN Inventory Do
		TabularSectionRow.ConnectionKey = ConnectionKey;
		ConnectionKey = ConnectionKey + 1;
	EndDo;	
	
EndProcedure // RunInventoryFillingByStandards()

// Procedure fills inventory according to standards.
//
Procedure RunInventoryFillingByBalance() Export
	
	Inventory.Clear();
	InventoryDistribution.Clear();
	
	Query = New Query;
	Query.Text =
    "SELECT
    |	SUM(InventoryBalances.QuantityBalance) AS Quantity,
    |	SUM(CASE
    |			WHEN InventoryBalances.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
    |				THEN InventoryBalances.QuantityBalance
    |			ELSE 0
    |		END) AS Reserve,
    |	ISNULL(InventoryBalances.ProductsAndServices, VALUE(Catalog.ProductsAndServices.EmptyRef)) AS ProductsAndServices,
    |	InventoryBalances.Characteristic AS Characteristic,
    |	InventoryBalances.Batch AS Batch,
    |	InventoryBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
    |	InventoryBalances.CustomerOrder AS CustomerOrder,
    |	InventoryBalances.Company AS Company,
    |	InventoryBalances.StructuralUnit AS StructuralUnit
    |FROM
    |	AccumulationRegister.Inventory.Balance(&ProcessingDate, CustomerOrder IN (&CustomerOrder)) AS InventoryBalances
    |WHERE
    |	InventoryBalances.QuantityBalance > 0
    |	AND InventoryBalances.ProductsAndServices <> VALUE(Catalog.ProductsAndServices.EmptyRef)
    |	AND InventoryBalances.Company = &Company
    |	AND InventoryBalances.StructuralUnit = &StructuralUnit
    |
    |GROUP BY
    |	InventoryBalances.Batch,
    |	InventoryBalances.ProductsAndServices,
    |	InventoryBalances.Characteristic,
    |	InventoryBalances.ProductsAndServices.MeasurementUnit,
    |	InventoryBalances.Company,
    |	InventoryBalances.StructuralUnit,
    |	InventoryBalances.CustomerOrder";
	
	OrdersArray = Products.UnloadColumn("CustomerOrder");
	OrdersArray.Add(Documents.CustomerOrder.EmptyRef());
	Query.SetParameter("CustomerOrder", OrdersArray);
	Query.SetParameter("ProcessingDate", EndOfDay(Date));
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	ConnectionKey = 0;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
        NewRow.ConnectionKey = ConnectionKey;
		
		ConnectionKey = ConnectionKey + 1;
		
	EndDo;	
	
EndProcedure // RunInventoryFillingByBalance()

// Procedure allocates inventory according to quantity.
//
Procedure RunInventoryDistributionByStandards() Export
	
	InventoryDistribution.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CostAllocationProducts.ProductsAndServices AS Products,
	|	CostAllocationProducts.Characteristic AS ProductCharacteristic,
	|	CostAllocationProducts.Batch AS ProductionBatch,
	|	CostAllocationProducts.CustomerOrder AS CustomerOrder,
	|	CostAllocationProducts.Specification AS Specification,
	|	CostAllocationProducts.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&CostAllocationProducts AS CostAllocationProducts
	|WHERE
	|	CostAllocationProducts.Specification <> VALUE(Catalog.Specifications.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableProduction.Products AS Products,
	|	TemporaryTableProduction.ProductCharacteristic AS ProductCharacteristic,
	|	TemporaryTableProduction.ProductionBatch AS ProductionBatch,
	|	TemporaryTableProduction.CustomerOrder AS CustomerOrder,
	|	TemporaryTableProduction.Specification AS ProductionSpecification,
	|	SpecificationsContent.ContentRowType AS ContentRowType,
	|	SpecificationsContent.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SpecificationsContent.MeasurementUnit AS MeasurementUnit,
	|	SpecificationsContent.Specification AS Specification,
	|	SUM(SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * TemporaryTableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TemporaryTableProduction
	|		LEFT JOIN Catalog.Specifications.Content AS SpecificationsContent
	|		ON TemporaryTableProduction.Specification = SpecificationsContent.Ref
	|WHERE
	|	SpecificationsContent.ProductsAndServices.ProductsAndServicesType = &ProductsAndServicesType
	|
	|GROUP BY
	|	TemporaryTableProduction.Products,
	|	TemporaryTableProduction.ProductCharacteristic,
	|	TemporaryTableProduction.ProductionBatch,
	|	TemporaryTableProduction.Specification,
	|	SpecificationsContent.ProductsAndServices,
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.ContentRowType,
	|	TemporaryTableProduction.CustomerOrder,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SpecificationsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	SpecificationsContent.MeasurementUnit";
	
	UseCharacteristics = Constants.FunctionalOptionUseCharacteristics.Get(); 
	
	TemporaryTableProduction = Products.Unload();
	
	For Each StringTT IN TemporaryTableProduction Do
		If TypeOf(StringTT.MeasurementUnit) = Type("CatalogRef.UOM") Then
			StringTT.Quantity = StringTT.Quantity * StringTT.MeasurementUnit.Factor;
		EndIf;
	EndDo;
	
	Query.SetParameter("CostAllocationProducts", TemporaryTableProduction);
	Query.SetParameter("UseCharacteristics", 	UseCharacteristics);
	
	Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
	
	TemporaryTableDistribution = Query.Execute().Unload();
	
	For n = 0 To TemporaryTableDistribution.Count() - 1 Do
		
		VTRow = TemporaryTableDistribution[n];
		
		If VTRow.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			
			DistributeTabularSectionBySpecification(VTRow, TemporaryTableDistribution, VTRow.ProductionSpecification);
			
		EndIf;
		
	EndDo;

	For Each TabularSectionRow IN Inventory Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices", 		TabularSectionRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic", 		TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		SearchStructure.Insert("CustomerOrder", 	TabularSectionRow.CustomerOrder);
		SearchStructure.Insert("Specification", 		TabularSectionRow.Specification);
		
		CountToDistribution = TabularSectionRow.Quantity;
		ReserveAllocation = TabularSectionRow.Reserve;
		
		SearchingArray = TemporaryTableDistribution.FindRows(SearchStructure);
		For Each ArrayRow IN SearchingArray Do
			
			If CountToDistribution > 0 Then
				
				ArrayRow.Quantity = min(ArrayRow.Quantity, CountToDistribution);
				CountToDistribution = CountToDistribution - ArrayRow.Quantity;
				
				StringReserve = min(ArrayRow.Quantity, ReserveAllocation);
				ReserveAllocation = ReserveAllocation - StringReserve;
				
				NewRow = InventoryDistribution.Add();
				NewRow.Quantity 		= ArrayRow.Quantity;
				NewRow.Reserve 			= StringReserve;
				NewRow.ProductsAndServices	= ArrayRow.Products;
				NewRow.Characteristic 	= ArrayRow.ProductCharacteristic;
				NewRow.Batch 			= ArrayRow.ProductionBatch;
				NewRow.CustomerOrder	= ArrayRow.CustomerOrder;
				NewRow.Specification	= ArrayRow.ProductionSpecification;
				NewRow.ConnectionKey		= TabularSectionRow.ConnectionKey;
				
			Else
				
				Break;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure // RunInventoryDistributionByStandards()

// Procedure allocates inventory according to quantity.
//
Procedure RunInventoryDistributionByCount() Export
	
	InventoryDistribution.Clear();
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ConnectionKey AS ConnectionKey,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Reserve AS Reserve
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.CustomerOrder AS CustomerOrder,
	|	TableProduction.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction";
	
	Query.SetParameter("TableProduction", Products.Unload());
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableProduction.ProductsAndServices AS ProductsAndServices,
	|	TemporaryTableProduction.Characteristic AS Characteristic,
	|	TemporaryTableProduction.Batch AS Batch,
	|	TemporaryTableProduction.MeasurementUnit AS MeasurementUnit,
	|	TemporaryTableProduction.Specification AS Specification,
	|	TemporaryTableProduction.CustomerOrder AS CustomerOrder,
	|	TemporaryTableInventory.ConnectionKey AS ConnectionKey,
	|	TemporaryTableProduction.Quantity AS Quantity,
	|	TemporaryTableInventory.Quantity AS TotalAmountCount,
	|	TemporaryTableInventory.Reserve AS TotalReserve
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory,
	|	TemporaryTableProduction AS TemporaryTableProduction
	|TOTALS
	|	SUM(Quantity)
	|BY
	|	ConnectionKey";
	
	SelectionKeyLinks = Query.Execute().Select(QueryResultIteration.ByGroups, "ConnectionKey");
	While SelectionKeyLinks.Next() Do
		
		InitQuantity = 0;
		InitReserve = 0;
		DistributionBaseQuantity = SelectionKeyLinks.Quantity;
		DistributionBaseReserve = SelectionKeyLinks.Quantity;
		SelectionDetailing = SelectionKeyLinks.Select();
		While SelectionDetailing.Next() Do
			
			NewRow = InventoryDistribution.Add();
			NewRow.ConnectionKey = SelectionDetailing.ConnectionKey;
			NewRow.ProductsAndServices = SelectionDetailing.ProductsAndServices;
			NewRow.Characteristic = SelectionDetailing.Characteristic;
			NewRow.Batch = SelectionDetailing.Batch;
			NewRow.CustomerOrder = SelectionDetailing.CustomerOrder;
			NewRow.Specification = SelectionDetailing.Specification;
			
			NewRow.Quantity = ?(DistributionBaseQuantity <> 0, Round((SelectionDetailing.TotalAmountCount - InitQuantity) * SelectionDetailing.Quantity / DistributionBaseQuantity, 3, 1),0);
			DistributionBaseQuantity = DistributionBaseQuantity - SelectionDetailing.Quantity;
			InitQuantity = InitQuantity + NewRow.Quantity;
			
			NewRow.Reserve = ?(DistributionBaseReserve <> 0, Round((SelectionDetailing.TotalReserve - InitReserve) * SelectionDetailing.Quantity / DistributionBaseReserve, 3, 1),0);
			DistributionBaseReserve = DistributionBaseReserve - SelectionDetailing.Quantity;
			InitReserve = InitReserve + NewRow.Reserve;
			
		EndDo;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure // RunCostingByCount()

// Procedure fills expenses according to balances.
//
Procedure RunExpenseFillingByBalance() Export
	
	Costs.Clear();
	CostAllocation.Clear();
	
	Query = New Query;
	Query.Text =
    "SELECT
    |	SUM(InventoryBalances.AmountBalance) AS Amount,
    |	InventoryBalances.GLAccount AS GLExpenseAccount,
    |	InventoryBalances.CustomerOrder AS CustomerOrder
    |FROM
    |	AccumulationRegister.Inventory.Balance(
    |			&ProcessingDate,
    |			Company = &Company
    |				AND StructuralUnit = &StructuralUnit
    |				AND ProductsAndServices = VALUE(Catalog.ProductsAndServices.EmptyRef)
    |				AND GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
    |				AND CustomerOrder IN (&CustomerOrder)) AS InventoryBalances
    |WHERE
    |	InventoryBalances.AmountBalance > 0
    |
    |GROUP BY
    |	InventoryBalances.GLAccount,
    |	InventoryBalances.CustomerOrder";
	
	OrdersArray = Products.UnloadColumn("CustomerOrder");
	OrdersArray.Add(Documents.CustomerOrder.EmptyRef());
	Query.SetParameter("CustomerOrder", OrdersArray);
	Query.SetParameter("ProcessingDate", EndOfDay(Date));
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	ConnectionKey = 0;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Costs.Add();
		FillPropertyValues(NewRow, Selection);
        NewRow.ConnectionKey = ConnectionKey;
		
		ConnectionKey = ConnectionKey + 1;
		
	EndDo;
	
EndProcedure // RunExpenseFillingByBalance()

// Procedure allocates expenses according to quantity.
//
Procedure RunCostingByCount() Export
	
	CostAllocation.Clear();
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableCosts.ConnectionKey AS ConnectionKey,
	|	TableCosts.Amount AS Amount
	|INTO TemporaryTableCost
	|FROM
	|	&TableCosts AS TableCosts";
	
	Query.SetParameter("TableCosts", Costs.Unload());
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.CustomerOrder AS CustomerOrder,
	|	TableProduction.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction";
	
	Query.SetParameter("TableProduction", Products.Unload());
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableProduction.ProductsAndServices AS ProductsAndServices,
	|	TemporaryTableProduction.Characteristic AS Characteristic,
	|	TemporaryTableProduction.Batch AS Batch,
	|	TemporaryTableProduction.MeasurementUnit AS MeasurementUnit,
	|	TemporaryTableProduction.Specification AS Specification,
	|	TemporaryTableProduction.CustomerOrder AS CustomerOrder,
	|	TemporaryTableCost.ConnectionKey AS ConnectionKey,
	|	TemporaryTableProduction.Quantity AS Quantity,
	|	TemporaryTableCost.Amount AS Amount
	|FROM
	|	TemporaryTableCost AS TemporaryTableCost,
	|	TemporaryTableProduction AS TemporaryTableProduction
	|TOTALS
	|	SUM(Quantity)
	|BY
	|	ConnectionKey";
	
	SelectionKeyLinks = Query.Execute().Select(QueryResultIteration.ByGroups, "ConnectionKey");
	While SelectionKeyLinks.Next() Do
		
		SrcAmount = 0;
		DistributionBase = SelectionKeyLinks.Quantity;
		SelectionDetailing = SelectionKeyLinks.Select();
		While SelectionDetailing.Next() Do
			
			NewRow = CostAllocation.Add();
			NewRow.ConnectionKey = SelectionDetailing.ConnectionKey;
			NewRow.ProductsAndServices = SelectionDetailing.ProductsAndServices;
			NewRow.Characteristic = SelectionDetailing.Characteristic;
			NewRow.Batch = SelectionDetailing.Batch;
			NewRow.CustomerOrder = SelectionDetailing.CustomerOrder;
			NewRow.Specification = SelectionDetailing.Specification;
			
			NewRow.Amount = ?(DistributionBase <> 0, Round((SelectionDetailing.Amount - SrcAmount) * SelectionDetailing.Quantity / DistributionBase, 2, 1),0);
			DistributionBase = DistributionBase - SelectionDetailing.Quantity;
			SrcAmount = SrcAmount + NewRow.Amount;
			
		EndDo;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure // RunCostingByCount()

// Procedure fills products according to release.
//
Procedure RunProductsFillingByOutput() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductReleaseTurnovers.ProductsAndServices AS ProductsAndServices,
	|	ProductReleaseTurnovers.Characteristic AS Characteristic,
	|	ProductReleaseTurnovers.Batch AS Batch,
	|	ProductReleaseTurnovers.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	ProductReleaseTurnovers.Specification AS Specification,
	|	CASE
	|		WHEN &InventoryReservation
	|			THEN ProductReleaseTurnovers.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	SUM(ProductReleaseTurnovers.QuantityTurnover) AS Quantity
	|FROM
	|	AccumulationRegister.ProductRelease.Turnovers(
	|			&StartDate,
	|			&EndDate,
	|			,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND ProductsAndServices.ProductsAndServicesType <> &ProductsAndServicesTypeService) AS ProductReleaseTurnovers
	|
	|GROUP BY
	|	ProductReleaseTurnovers.Characteristic,
	|	ProductReleaseTurnovers.Specification,
	|	ProductReleaseTurnovers.Batch,
	|	ProductReleaseTurnovers.ProductsAndServices,
	|	ProductReleaseTurnovers.CustomerOrder,
	|	ProductReleaseTurnovers.ProductsAndServices.MeasurementUnit";
	
	Query.SetParameter("InventoryReservation", Constants.FunctionalOptionInventoryReservation.Get());
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("ProductsAndServicesTypeService", Enums.ProductsAndServicesTypes.Service);
	Query.SetParameter("StartDate", PeriodOpenDate);
	Query.SetParameter("EndDate", EndOfDay(Date));
	
	Products.Load(Query.Execute().Unload());
	
EndProcedure // RunProductsFillingByOutput()	

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.InventoryAssembly") Then
		
		Query = New Query(
		"SELECT
		|	InventoryAssembly.Ref AS BasisDocument,
		|	InventoryAssembly.OperationKind AS OperationKind,
		|	InventoryAssembly.Company AS Company,
		|	InventoryAssembly.StructuralUnit AS StructuralUnit,
		|	InventoryAssembly.Cell AS Cell,
		|	InventoryAssembly.CustomerOrder AS CustomerOrder,
		|	InventoryAssembly.Products.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	),
		|	InventoryAssembly.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	)
		|FROM
		|	Document.InventoryAssembly AS InventoryAssembly
		|WHERE
		|	InventoryAssembly.Ref = &Ref");
		
		Query.SetParameter("Ref", FillingData);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			If QueryResultSelection.OperationKind = Enums.OperationKindsInventoryAssembly.Disassembly Then
				TabularSectionName = "Inventory";
			Else
				TabularSectionName = "Products";
			EndIf;
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection[TabularSectionName].Select();
			While SelectionProducts.Next() Do
				NewRow = Products.Add();
				NewRow.ProductsAndServices 		= SelectionProducts.ProductsAndServices;
				NewRow.Characteristic 		= SelectionProducts.Characteristic;
				NewRow.Batch 				= SelectionProducts.Batch;
				NewRow.MeasurementUnit 	= SelectionProducts.MeasurementUnit;
				NewRow.Quantity 			= SelectionProducts.Quantity;
				NewRow.Specification 		= SelectionProducts.Specification;
				NewRow.CustomerOrder		= QueryResultSelection.CustomerOrder;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		
		Query = New Query(
		"SELECT
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.Company AS Company,
		|	ProductionOrder.OperationKind AS OperationKind,
		|	ProductionOrder.StructuralUnit AS StructuralUnit,
		|	ProductionOrder.CustomerOrder AS CustomerOrder,
		|	ProductionOrder.Products.(
		|		ProductsAndServices AS ProductsAndServices,
		|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	),
		|	ProductionOrder.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Ref = &Ref");
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.Service);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			If QueryResultSelection.OperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
				NameTSProducts = "Inventory";
				NameTSInventory = "Products";
			Else
				NameTSProducts = "Products";
				NameTSInventory = "Inventory";
			EndIf;
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection[NameTSProducts].Select();
			While SelectionProducts.Next() Do
				If SelectionProducts.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
					Continue;
				EndIf;
				NewRow = Products.Add();
				NewRow.ProductsAndServices 		= SelectionProducts.ProductsAndServices;
				NewRow.Characteristic 		= SelectionProducts.Characteristic;
				NewRow.MeasurementUnit 	= SelectionProducts.MeasurementUnit;
				NewRow.Quantity 			= SelectionProducts.Quantity;
				NewRow.Specification 		= SelectionProducts.Specification;
				NewRow.CustomerOrder		= QueryResultSelection.CustomerOrder;
			EndDo;
			
			ConnectionKey = 0;
			SelectionInventory = QueryResultSelection[NameTSInventory].Select();
			While SelectionInventory.Next() Do
				If SelectionProducts.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
					NewRow = Inventory.Add();
					NewRow.ProductsAndServices 		= SelectionInventory.ProductsAndServices;
					NewRow.Characteristic 		= SelectionInventory.Characteristic;
					NewRow.MeasurementUnit 	= SelectionInventory.MeasurementUnit;
					NewRow.Quantity 			= SelectionInventory.Quantity;
					NewRow.Reserve 				= SelectionInventory.Reserve;
					NewRow.Specification 		= SelectionInventory.Specification;
					NewRow.CustomerOrder		= QueryResultSelection.CustomerOrder;
					NewRow.ConnectionKey			= ConnectionKey;
					ConnectionKey = ConnectionKey + 1;
				EndIf;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder")
		AND FillingData.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then	
		
		Raise NStr("en = 'Cost allocation can not be entered on the basis of job order!'");
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder")
		AND FillingData.OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale Then
		
		Query = New Query(
		"SELECT
		|	CustomerOrder.Ref AS BasisDocument,
		|	CustomerOrder.Company AS Company,
		|	CASE
		|		WHEN CustomerOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
		|			THEN CustomerOrder.SalesStructuralUnit
		|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CustomerOrder.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification,
		|		Ref AS CustomerOrder,
		|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
		|	)
		|FROM
		|	Document.CustomerOrder AS CustomerOrder
		|WHERE
		|	CustomerOrder.Ref = &Ref");
		
		Query.SetParameter("Ref", FillingData);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				
				If SelectionInventory.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.Service Then
				
					NewRow = Products.Add();
					NewRow.ProductsAndServices 		= SelectionInventory.ProductsAndServices;
					NewRow.Characteristic 		= SelectionInventory.Characteristic;
					NewRow.MeasurementUnit 	= SelectionInventory.MeasurementUnit;
					NewRow.Quantity 			= SelectionInventory.Quantity;
					NewRow.Specification		= SelectionInventory.Specification;
					NewRow.CustomerOrder		= SelectionInventory.CustomerOrder;
					
					FillTabularSectionBySpecification(SelectionInventory.Specification, SelectionInventory.Quantity, SelectionInventory.MeasurementUnit, SelectionInventory.CustomerOrder);
					
				EndIf;
				
			EndDo;
			
			Inventory.GroupBy("ProductsAndServices, Characteristic, MeasurementUnit, CustomerOrder, Specification", "Quantity");
			
			ConnectionKey = 0;
			For Each TabularSectionRow IN Inventory Do
				TabularSectionRow.ConnectionKey = ConnectionKey;
				ConnectionKey = ConnectionKey + 1;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder")
		AND FillingData.OperationKind = Enums.OperationKindsCustomerOrder.OrderForProcessing Then
		
		Query = New Query(
		"SELECT
		|	CustomerOrder.Ref AS BasisDocument,
		|	CustomerOrder.Company AS Company,
		|	CASE
		|		WHEN CustomerOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
		|			THEN CustomerOrder.SalesStructuralUnit
		|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CustomerOrder.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification,
		|		Ref AS CustomerOrder,
		|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
		|	),
		|	CustomerOrder.ConsumerMaterials.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Ref AS CustomerOrder
		|	)
		|FROM
		|	Document.CustomerOrder AS CustomerOrder
		|WHERE
		|	CustomerOrder.Ref = &Ref");
		 
		Query.SetParameter("Ref", FillingData);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionMaterials = QueryResultSelection.ConsumerMaterials.Select();
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				
				If SelectionInventory.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.Service Then
				
					NewRow = Products.Add();
					NewRow.ProductsAndServices 		= SelectionInventory.ProductsAndServices;
					NewRow.Characteristic 		= SelectionInventory.Characteristic;
					NewRow.MeasurementUnit 	= SelectionInventory.MeasurementUnit;
					NewRow.Quantity 			= SelectionInventory.Quantity;
					NewRow.Specification		= SelectionInventory.Specification;
					NewRow.CustomerOrder		= SelectionInventory.CustomerOrder;
					
					If SelectionMaterials.Count() = 0 Then
						FillTabularSectionBySpecification(SelectionInventory.Specification, SelectionInventory.Quantity, SelectionInventory.MeasurementUnit, SelectionInventory.CustomerOrder);
					EndIf;
					
				EndIf;
				
			EndDo;
			
			While SelectionMaterials.Next() Do
				
				NewRow = Inventory.Add();
				NewRow.ProductsAndServices 		= SelectionMaterials.ProductsAndServices;
				NewRow.Characteristic 		= SelectionMaterials.Characteristic;
				NewRow.MeasurementUnit 	= SelectionMaterials.MeasurementUnit;
				NewRow.Quantity 			= SelectionMaterials.Quantity;
				NewRow.CustomerOrder		= SelectionMaterials.CustomerOrder;
				
			EndDo;
			
			Inventory.GroupBy("ProductsAndServices, Characteristic, MeasurementUnit, CustomerOrder, Specification", "Quantity");
			
			ConnectionKey = 0;
			For Each TabularSectionRow IN Inventory Do
				TabularSectionRow.ConnectionKey = ConnectionKey;
				ConnectionKey = ConnectionKey + 1;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Total("Quantity") <> InventoryDistribution.Total("Quantity") Then

		MessageText = NStr("en = 'The inventory quantity does not match with the quantity of allocation!'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,"Inventory",Cancel);
			
	EndIf;
	
	If Costs.Total("Amount") <> CostAllocation.Total("Amount") Then

		MessageText = NStr("en = 'Amount of expenses does not match the amount of distribution!'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,"Costs",Cancel);
			
	EndIf;

	If Constants.FunctionalOptionInventoryReservation.Get() Then
		
		For Each StringInventory IN Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				MessageText = NStr("en = 'In row No.%Number% of the ""Inventory"" tabular section, the number of positions for write-off from reserve exceeds the total inventory quantity.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;	
			
		EndDo;
		
		For Each StringInventoryDistribution IN InventoryDistribution Do
			
			If StringInventoryDistribution.Reserve > StringInventoryDistribution.Quantity Then
				
				MessageText = NStr("en = 'In row No.%Number% of the ""Inventory allocation"" tabular section, the number of positions for write-off from reserve exceeds the total inventory quantity.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventoryDistribution.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"InventoryDistribution",
					StringInventoryDistribution.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;	
			
		EndDo;
		
	EndIf;	
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CostAllocation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.CostAllocation.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo the posting of a document.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.CostAllocation.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

#EndIf