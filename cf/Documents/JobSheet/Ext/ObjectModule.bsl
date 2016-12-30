#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS OF DOCUMENT

// Procedure fills team members.
//
Procedure FillTeamMembers() Export

	If ValueIsFilled(Performer) AND TypeOf(Performer) = Type("CatalogRef.Teams") Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	WorkgroupsContent.Employee,
		|	1 AS LPF
		|FROM
		|	Catalog.Teams.Content AS WorkgroupsContent
		|WHERE
		|	WorkgroupsContent.Ref = &Ref";
		
		Query.SetParameter("Ref", Performer);	
		
		TeamMembers.Load(Query.Execute().Unload());
		
	EndIf;	

EndProcedure

// Procedure fills tabular section according to specification.
//
Procedure FillTableBySpecification(BySpecification, ByMeasurementUnit, ByQuantity, TableContent)
	
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
	|	SpecificationsContent.Specification AS Specification,
	|	SpecificationsContent.CostPercentage AS CostPercentage,
	|	SpecificationsContent.MeasurementUnit AS MeasurementUnit,
	|	SUM(SpecificationsContent.Quantity / SpecificationsContent.ProductsQuantity * &Factor * &Quantity) AS Quantity
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
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.MeasurementUnit,
	|	SpecificationsContent.ContentRowType,
	|	SpecificationsContent.CostPercentage
	|
	|ORDER BY
	|	SpecificationsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", Constants.FunctionalOptionUseCharacteristics.Get());
	
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("Quantity", ByQuantity);
	
	If TypeOf(ByMeasurementUnit) = Type("CatalogRef.UOM")
		AND ValueIsFilled(ByMeasurementUnit) Then
		ByFactor = ByMeasurementUnit.Factor;
	Else
		ByFactor = 1;
	EndIf;
	Query.SetParameter("Factor", ByFactor);
	Query.SetParameter("ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			
			FillTableBySpecification(Selection.Specification, Selection.MeasurementUnit, Selection.Quantity, TableContent);
			
		Else
			
			NewRow = TableContent.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillTableBySpecification()

// Procedure for filling the document basing on Customer order.
//
Procedure FillUsingCustomerOrder(FillingData)
	
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData,
			New Structure("Company, OperationKind, SalesStructuralUnit, Start, Finish, ShipmentDate"));
	
	Company = AttributeValues.Company;
	StructuralUnit = AttributeValues.SalesStructuralUnit;
	DocumentCurrency = Catalogs.PriceKinds.Accounting.PriceCurrency;
	
	If AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		ClosingDate = AttributeValues.Finish;
		Period = ?(ValueIsFilled(AttributeValues.Start), AttributeValues.Start, CurrentDate());
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	&Period AS Period,
		|	CustomerOrderWorks.LineNumber AS LineNumber,
		|	CustomerOrderWorks.Ref AS CustomerOrder,
		|	CustomerOrderWorks.ProductsAndServices AS ProductsAndServices,
		|	CustomerOrderWorks.Characteristic AS Characteristic,
		|	CustomerOrderWorks.Quantity AS QuantityPlan,
		|	CustomerOrderWorks.Specification AS Specification,
		|	OperationSpecification.Operation,
		|	OperationSpecification.Operation.MeasurementUnit AS MeasurementUnit,
		|	ISNULL(OperationSpecification.TimeNorm, 0) / ISNULL(OperationSpecification.ProductsQuantity, 1) AS TimeNorm,
		|	ISNULL(ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Tariff
		|FROM
		|	Document.CustomerOrder.Works AS CustomerOrderWorks
		|		LEFT JOIN Catalog.Specifications.Operations AS OperationSpecification
		|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&Period, PriceKind = VALUE(Catalog.PriceKinds.Accounting)) AS ProductsAndServicesPricesSliceLast
		|			ON OperationSpecification.Operation = ProductsAndServicesPricesSliceLast.ProductsAndServices
		|		ON CustomerOrderWorks.Specification = OperationSpecification.Ref
		|WHERE
		|	CustomerOrderWorks.Ref = &BasisDocument
		|	AND CustomerOrderWorks.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Work)
		|
		|ORDER BY
		|	LineNumber";
		
	Else
		
		ClosingDate = AttributeValues.ShipmentDate;
		Period = ?(ValueIsFilled(AttributeValues.ShipmentDate), AttributeValues.ShipmentDate, CurrentDate());
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	&Period AS Period,
		|	CustomerOrderInventory.LineNumber AS LineNumber,
		|	CustomerOrderInventory.Ref AS CustomerOrder,
		|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
		|	CustomerOrderInventory.Characteristic AS Characteristic,
		|	CustomerOrderInventory.Batch AS Batch,
		|	CustomerOrderInventory.Quantity AS QuantityPlan,
		|	CustomerOrderInventory.Specification AS Specification,
		|	OperationSpecification.Operation,
		|	OperationSpecification.Operation.MeasurementUnit AS MeasurementUnit,
		|	ISNULL(OperationSpecification.TimeNorm, 0) / ISNULL(OperationSpecification.ProductsQuantity, 1) * CASE
		|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOM)
		|				AND CustomerOrderInventory.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
		|			THEN CustomerOrderInventory.MeasurementUnit.Factor
		|		ELSE 1
		|	END AS TimeNorm,
		|	ISNULL(ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Tariff
		|FROM
		|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
		|		LEFT JOIN Catalog.Specifications.Operations AS OperationSpecification
		|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&Period, PriceKind = VALUE(Catalog.PriceKinds.Accounting)) AS ProductsAndServicesPricesSliceLast
		|			ON OperationSpecification.Operation = ProductsAndServicesPricesSliceLast.ProductsAndServices
		|		ON CustomerOrderInventory.Specification = OperationSpecification.Ref
		|WHERE
		|	CustomerOrderInventory.Ref = &BasisDocument
		|	AND (CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
		|			OR CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Work))
		|
		|ORDER BY
		|	LineNumber";
		
	EndIf;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Period", Period);
	
	Operations.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Operations.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
		
	EndIf
	
EndProcedure // FillByCustomerOrder()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// IN the event handler of the FillingProcessor document
// - document filling by inventory reconciliation in the warehouse.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
		If FillingData.Property("Operations") Then
			For Each StringOperations IN FillingData.Operations Do
				NewRow = Operations.Add();
				FillPropertyValues(NewRow, StringOperations);
			EndDo;
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		
		FillUsingCustomerOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		
		If FillingData.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse Then
			
			Raise NStr("en='Job sheet can not be based on production order by warehouse!';ru='Сдельный наряд не может быть введен на основании заказа на производство по складу!'");
			
		ElsIf FillingData.OperationKind = Enums.OperationKindsProductionOrder.Assembly Then
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	OrderForProductsProduction.Ref.Company AS Company,
			|	OrderForProductsProduction.Ref.StructuralUnit AS StructuralUnit,
			|	OrderForProductsProduction.Ref.Finish AS ClosingDate,
			|	&Period AS Period,
			|	OrderForProductsProduction.Ref.CustomerOrder AS CustomerOrder,
			|	OrderForProductsProduction.ProductsAndServices AS ProductsAndServices,
			|	OrderForProductsProduction.Characteristic AS Characteristic,
			|	OrderForProductsProduction.Quantity AS QuantityPlan,
			|	OrderForProductsProduction.Specification AS Specification,
			|	OperationSpecification.Operation,
			|	OperationSpecification.Operation.MeasurementUnit AS MeasurementUnit,
			|	ISNULL(OperationSpecification.TimeNorm, 0) / ISNULL(OperationSpecification.ProductsQuantity, 1) * CASE
			|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOM)
			|				AND OrderForProductsProduction.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
			|			THEN OrderForProductsProduction.MeasurementUnit.Factor
			|		ELSE 1
			|	END AS TimeNorm,
			|	ISNULL(ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Tariff
			|FROM
			|	Document.ProductionOrder.Products AS OrderForProductsProduction
			|		LEFT JOIN Catalog.Specifications.Operations AS OperationSpecification
			|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&Period, PriceKind = VALUE(Catalog.PriceKinds.Accounting)) AS ProductsAndServicesPricesSliceLast
			|			ON OperationSpecification.Operation = ProductsAndServicesPricesSliceLast.ProductsAndServices
			|		ON OrderForProductsProduction.Specification = OperationSpecification.Ref
			|WHERE
			|	OrderForProductsProduction.Ref = &BasisDocument";
			
			Query.SetParameter("BasisDocument", FillingData);
			Query.SetParameter("Period", ?(ValueIsFilled(FillingData.Start), FillingData.Start, CurrentDate()));
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				
				QueryResultSelection = QueryResult.Select();
				QueryResultSelection.Next();
				FillPropertyValues(ThisObject, QueryResultSelection);
				ThisObject.DocumentCurrency = Catalogs.PriceKinds.Accounting.PriceCurrency;
				
				QueryResultSelection.Reset();
				Operations.Clear();
				While QueryResultSelection.Next() Do
					NewRow = Operations.Add();
					FillPropertyValues(NewRow, QueryResultSelection);
				EndDo;
				
			EndIf
			
		Else
			
			TableContent = New ValueTable;
			
			Array = New Array;
			
			Array.Add(Type("CatalogRef.ProductsAndServices"));
			TypeDescription = New TypeDescription(Array, ,);
			Array.Clear();
			TableContent.Columns.Add("ProductsAndServices", TypeDescription);
			
			Array.Add(Type("CatalogRef.ProductsAndServicesCharacteristics"));
			TypeDescription = New TypeDescription(Array, ,);
			Array.Clear();
			TableContent.Columns.Add("Characteristic", TypeDescription);
			
			Array.Add(Type("CatalogRef.Specifications"));
			TypeDescription = New TypeDescription(Array, ,);
			Array.Clear();
			TableContent.Columns.Add("Specification", TypeDescription);
			
			Array.Add(Type("Number"));
			TypeDescription = New TypeDescription(Array, ,);
			TableContent.Columns.Add("Quantity", TypeDescription);
			
			Array.Add(Type("Number"));
			TypeDescription = New TypeDescription(Array, ,);
			TableContent.Columns.Add("CostPercentage", TypeDescription);
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	&Period AS Period,
			|	OrderForProductsProduction.Ref.Company AS Company,
			|	OrderForProductsProduction.Ref.StructuralUnit AS StructuralUnit,
			|	OrderForProductsProduction.Ref.Finish AS ClosingDate,
			|	OrderForProductsProduction.Ref.CustomerOrder AS CustomerOrder,
			|	OrderForProductsProduction.ProductsAndServices AS ProductsAndServices,
			|	OrderForProductsProduction.Characteristic AS Characteristic,
			|	OrderForProductsProduction.MeasurementUnit AS MeasurementUnit,
			|	OrderForProductsProduction.Quantity AS Quantity,
			|	OrderForProductsProduction.Specification AS Specification,
			|	OperationSpecification.Operation AS Operation,
			|	OperationSpecification.Operation.MeasurementUnit AS OperationMeasurementUnit,
			|	ISNULL(OperationSpecification.TimeNorm, 0) / ISNULL(OperationSpecification.ProductsQuantity, 1) * CASE
			|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOM)
			|				AND OrderForProductsProduction.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
			|			THEN OrderForProductsProduction.MeasurementUnit.Factor
			|		ELSE 1
			|	END AS TimeNorm,
			|	ISNULL(ProductsAndServicesPricesSliceLast.Price / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Tariff
			|FROM
			|	Document.ProductionOrder.Products AS OrderForProductsProduction
			|		LEFT JOIN Catalog.Specifications.Operations AS OperationSpecification
			|			LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&Period, PriceKind = VALUE(Catalog.PriceKinds.Accounting)) AS ProductsAndServicesPricesSliceLast
			|			ON OperationSpecification.Operation = ProductsAndServicesPricesSliceLast.ProductsAndServices
			|		ON OrderForProductsProduction.Specification = OperationSpecification.Ref
			|WHERE
			|	OrderForProductsProduction.Ref = &BasisDocument";
			
			Query.SetParameter("BasisDocument", FillingData);
			Query.SetParameter("Period", ?(ValueIsFilled(FillingData.Start), FillingData.Start, CurrentDate()));
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
				FillPropertyValues(ThisObject, Selection);
				ThisObject.DocumentCurrency = Catalogs.PriceKinds.Accounting.PriceCurrency;
				
				Selection.Reset();
				While Selection.Next() Do
					
					TableContent.Clear();
					FillTableBySpecification(Selection.Specification, Selection.MeasurementUnit, Selection.Quantity, TableContent);
					TotalCostPercentage = TableContent.Total("CostPercentage");
					
					LeftToDistribute = Selection.TimeNorm;
					
					NewRow = Undefined;
					For Each TableRow IN TableContent Do
					
						NewRow = Operations.Add();
						NewRow.Period = Selection.Period;
						NewRow.CustomerOrder = Selection.CustomerOrder;
						NewRow.ProductsAndServices = TableRow.ProductsAndServices;
						NewRow.Characteristic = TableRow.Characteristic;
						NewRow.Operation = Selection.Operation;
						NewRow.MeasurementUnit = Selection.OperationMeasurementUnit;
						NewRow.QuantityPlan = TableRow.Quantity;
						NewRow.Tariff = Selection.Tariff;
						NewRow.Specification = Selection.Specification;
						
						TimeNorm = Round(Selection.TimeNorm * TableRow.CostPercentage / ?(TotalCostPercentage = 0, 1, TotalCostPercentage),3,0);
						NewRow.TimeNorm = TimeNorm;
						LeftToDistribute = LeftToDistribute - TimeNorm;
						
					EndDo;
					
					If NewRow <> Undefined Then
						NewRow.TimeNorm = NewRow.TimeNorm + LeftToDistribute;
					EndIf;
					
				EndDo;
				
			Else
				Return;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
	
		Return;
		
	EndIf;
	
	If Closed Then
		
		CheckedAttributes.Add("ClosingDate");
	
	EndIf;
		
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Operations.Total("Cost");
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)

	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.JobSheet.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectAccrualsAndDeductions(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPayrollPayments(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectJobSheets(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)

	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
EndProcedure // UndoPosting()

#EndIf