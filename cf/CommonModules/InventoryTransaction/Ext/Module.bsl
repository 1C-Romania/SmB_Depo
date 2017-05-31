Function ConvertQuantity(Item, Quantity, UnitOfMeasureFrom, UnitOfMeasureTo) Export
	
	If UnitOfMeasureFrom = UnitOfMeasureTo Then
		Return Quantity;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ItemsUnitsOfMeasureFrom.Quantity / ItemsUnitsOfMeasureTo.Quantity AS Coef
	|FROM
	|	Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasureFrom,
	|	Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasureTo
	|WHERE
	|	ItemsUnitsOfMeasureFrom.Ref = &Item
	|	AND ItemsUnitsOfMeasureTo.Ref = &Item
	|	AND ItemsUnitsOfMeasureFrom.UnitOfMeasure = &UnitOfMeasureFrom
	|	AND ItemsUnitsOfMeasureTo.UnitOfMeasure = &UnitOfMeasureTo";
	
	Query.SetParameter("Item",          Item);
	Query.SetParameter("UnitOfMeasureFrom", UnitOfMeasureFrom);
	Query.SetParameter("UnitOfMeasureTo", UnitOfMeasureTo);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Coef = 0;
	Else	
		Selection = QueryResult.Select();
		Selection.Next();
		Coef = Selection.Coef;
	EndIf;	
	
	Return Round(Coef*Quantity,3);
	
EndFunction	

Function GetUnitOfMeasureQuantity(Item, UnitOfMeasure) Export 
	
	Query = New Query;
	Query.Text = "SELECT
	|	ItemsUnitsOfMeasure.Quantity
	|FROM
	|	Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasure
	|WHERE
	|	ItemsUnitsOfMeasure.Ref = &Item
	|	AND ItemsUnitsOfMeasure.UnitOfMeasure = &UnitOfMeasure";
	
	Query.SetParameter("Item", Item);
	Query.SetParameter("UnitOfMeasure", UnitOfMeasure);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If Selection.Quantity = 0 Then
			Return 1;
		Else
			Return Selection.Quantity;
		EndIf;
	Else
		Return 1;
	EndIf;
	
EndFunction // GetUnitOfMeasureQuantity()

// This function provides ratio for transformation of Item quantity given in UnitOfMeasure
// into quantity given in item's base unit of measure or vice versa.
// Usage example: 
// QuantityBase = QuantityUoM * GetUnitOfMeasureRatio(Item, UoM);
// or
// QuantityUoM = QuantityBase / GetUnitOfMeasureRatio(Item, UoM);
Function GetUnitOfMeasureRatio(Item, UnitOfMeasure) Export 
	
	Query = New Query;
	Query.Text = "SELECT
	|	ItemsUnitsOfMeasure.Quantity AS UnitOfMeasureQuantity
	|FROM
	|	Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasure
	|WHERE
	|	ItemsUnitsOfMeasure.Ref = &Item
	|	AND ItemsUnitsOfMeasure.UnitOfMeasure = &UnitOfMeasure";
	
	Query.SetParameter("Item",          Item);
	Query.SetParameter("UnitOfMeasure", UnitOfMeasure);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return 0;
	Else	
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.UnitOfMeasureQuantity;
	EndIf;	
	
EndFunction // GetUnitOfMeasureRatio()

// Function returns value table of avaliable goods in stock for the document.
// Parameters:
//  Items - Items Array
//  Company - reference on catalog Companies.
//  Warehouse - reference on catalog Warehouses or array of such refs.
//
Function GetTableOfAvaliableItemsInStock(ItemsList, Company, Warehouse, ReservationDoc = Undefined, Object = Undefined, Form = Undefined) Export
	
	Query = New Query;
	
	Query.Text ="SELECT
	|	InventoryTransactionsBalance.Warehouse,
	|	ISNULL(InventoryTransactionsBalance.QuantityBalance, 0) - ISNULL(ReservedGoodsBalance.QuantityBalance, 0) AS QuantityBalanceBase,
	|	InventoryTransactionsBalance.Item
	|FROM
	|	AccumulationRegister.InventoryTransactions.Balance(
	|			,
	|			Company = &Company
	|				AND Warehouse IN (&Warehouse)
	|				AND Item IN (&ItemsList)) AS InventoryTransactionsBalance
	|		LEFT JOIN AccumulationRegister.ReservedGoods.Balance(
	|				,
	|				Company = &Company
	|					AND ReservationDoc NOT IN (&ReservationDoc)
	|					AND Warehouse IN (&Warehouse)
	|					AND Item IN (&ItemsList)) AS ReservedGoodsBalance
	|		ON InventoryTransactionsBalance.Item = ReservedGoodsBalance.Item
	|			AND InventoryTransactionsBalance.Warehouse = ReservedGoodsBalance.Warehouse
	|
	|FOR UPDATE
	|	AccumulationRegister.ReservedGoods.Balance,
	|	AccumulationRegister.InventoryTransactions.Balance";
	
	Query.SetParameter("Company",    Company);
	Query.SetParameter("Warehouse",  Warehouse);
	Query.SetParameter("ReservationDoc",  ReservationDoc);
	Query.SetParameter("ItemsList",  ItemsList);
	
	If ReservationDoc = Undefined OR (TypeOf(ReservationDoc) = Type("Array") AND ReservationDoc.Count()=0) Then
		Query.Text = StrReplace(Query.Text, "AND ReservationDoc NOT IN (&ReservationDoc)", "");
	EndIf;
	
	Return Query.Execute().Unload();
	
EndFunction // GetTableOfAvaliableItemsInStock()

Function GetImmediateStockMovementsSalesDeliveryQuery() Export
	
	SalesDeliveryQuery = New Query("SELECT TOP 1
	|	SalesDelivery.Ref
	|FROM
	|	Document.SalesDelivery AS SalesDelivery
	|WHERE
	|	SalesDelivery.DocumentBase = &SalesInvoice
	|	AND SalesDelivery.Ref <> &CurrentSalesDelivery");
	Return SalesDeliveryQuery;
	
EndFunction	

Function GetImmediateStockMovementsOnSalesInvoice(SalesInvoiceRef,SalesDeliveryRefToExclude = Undefined) Export
	
	SalesDeliveryQuery = GetImmediateStockMovementsSalesDeliveryQuery();
	SalesDeliveryQuery.SetParameter("SalesInvoice",SalesInvoiceRef);
	SalesDeliveryQuery.SetParameter("CurrentSalesDelivery",?(SalesDeliveryRefToExclude = Undefined,Documents.SalesDelivery.EmptyRef(),SalesDeliveryRefToExclude));
	
	QueryResult = SalesDeliveryQuery.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Return Documents.SalesDelivery.EmptyRef();
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.Ref;
		
	EndIf;	
	
EndFunction	

Function GetImmediateStockMovementsSalesReturnReceiptQuery() Export
	
	SalesReturnReceiptQuery = New Query("SELECT TOP 1
	|	SalesReturnReceipt.Ref
	|FROM
	|	Document.SalesReturnReceipt AS SalesReturnReceipt
	|WHERE
	|	SalesReturnReceipt.DocumentBase = &SalesCreditNoteReturn
	|	AND SalesReturnReceipt.Ref <> &CurrentReturnReceipt");
	Return SalesReturnReceiptQuery;
	
EndFunction	

Function GetImmediateStockMovementsOnSalesCreditNoteReturn(SalesCreditNoteReturnRef,SalesReturnReceiptRefToExclude = Undefined) Export
	
	SalesReturnReceiptQuery = GetImmediateStockMovementsSalesReturnReceiptQuery();
	SalesReturnReceiptQuery.SetParameter("SalesCreditNoteReturn",SalesCreditNoteReturnRef);
	SalesReturnReceiptQuery.SetParameter("CurrentReturnReceipt",?(SalesReturnReceiptRefToExclude = Undefined,Documents.SalesReturnReceipt.EmptyRef(),SalesReturnReceiptRefToExclude));
	
	QueryResult = SalesReturnReceiptQuery.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Return Documents.SalesReturnReceipt.EmptyRef();
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.Ref;
		
	EndIf;	
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH COST OF GOODS

Function GetItemsCostDocument(CostingMethod, DocumentRef, Cancel, MessageTitle, MessageTextBegin = "", Object = Undefined) Export
	
	If CostingMethod = Enums.GoodsCostingMethods.Average Then
		Return Undefined;
	ElsIf CostingMethod = Enums.GoodsCostingMethods.FIFO Then
		Return DocumentRef;
	ElsIf CostingMethod = Enums.GoodsCostingMethods.LIFO Then
		Return DocumentRef;
	Else
		ErrorMessageTxt = MessageTextBegin + " " + NStr("en=""Item's costing method is not defined!"";pl='Sposób kalkulacji kosztu pozycji nie jest określony!'");
		Alerts.AddAlert(ErrorMessageTxt,Enums.AlertType.Error,Cancel,Object);
	EndIf;
	
EndFunction // GetItemsCostDocument()

Function GetCostingMethod(DocumentObject,MessageTitle = "",Cancel = False) Export
	
	Return GetCostingMethodOnDate(DocumentObject.Date,DocumentObject.Company,MessageTitle,Cancel,DocumentObject);
	
EndFunction // GetItemsCostDocument()

Function GetCostingMethodOnDate(Date,Company,MessageTitle = "",Cancel = False,DocumentObject = Undefined) Export
	
	IformationRegisterStructure = InformationRegisters.AccountingPolicyGeneral.GetLast(Date, New Structure("Company", Company));
	
	If IformationRegisterStructure = Undefined Then
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'The accounting policy was not defined for the company %P1 on %P2!'; pl = 'Nie została zdefiniowana polityka rachunkowości dla firmy %P1 na okres %P2!'"),New Structure("P1, P2",Company,Date)),Enums.AlertType.Error,Cancel,DocumentObject);
		Return Enums.GoodsCostingMethods.EmptyRef();
	EndIf;
	
	CostingMethod = IformationRegisterStructure.CostingMethod;
	If ValueIsNotFilled(CostingMethod) Then
	 	Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Costing method was not defined for the company %P1 on %P2!'; pl = 'Nie został zdefiniowany sposób kalkulacji kosztu dla firmy %P1 na okres %P2!'"),New Structure("P1, P2",Company,Date)),Enums.AlertType.Error,Cancel,DocumentObject);
		Return Enums.GoodsCostingMethods.EmptyRef();
	EndIf;	
	
	Return CostingMethod;
	
EndFunction	

Function GetCostOfGoodsMap(ItemsArray, CostingMethod, Company, PointInTime, GetBalance = True, ParcelDocument = Undefined,IsOpeningBalanceParcel = False) Export
	
	CostOfGoodsMap = New Map;
	
	NeedDocument = (CostingMethod = Enums.GoodsCostingMethods.FIFO OR CostingMethod = Enums.GoodsCostingMethods.LIFO);
	
	Query = New Query;
	Query.Text = "SELECT
	             |	CostOfGoodsBalance.Item AS Item, " + ?(NeedDocument,"
	             |	CostOfGoodsBalance.Document,
	             |	CASE
	             |		WHEN CostOfGoodsBalance.Document = UNDEFINED
	             |			THEN DATETIME(1, 1, 1, 0, 0, 0)
	             |		ELSE CostOfGoodsBalance.Document.Date
	             |	END AS Date,
	             |	CostOfGoodsBalance.Document.PointInTime AS PointInTime,","")+"
	             |	CostOfGoodsBalance.QuantityBalance,
				 |	CASE WHEN CostOfGoodsBalance.QuantityBalance = 0 THEN 0 ELSE CostOfGoodsBalance.AmountBalance/CostOfGoodsBalance.QuantityBalance END AS CostPerItem,
	             |	CostOfGoodsBalance.AmountBalance
	             |FROM
	             |	AccumulationRegister.CostOfGoods.Balance(
	             |			&DocumentPointInTime,
	             |			Company = &Company
	             |				AND Item IN (&ItemsArray)" + ?(NeedDocument AND NOT GetBalance," AND Document In (&ParcelDocument)","")+ "
	             |) AS CostOfGoodsBalance
	             |
	             |FOR UPDATE
	             |	AccumulationRegister.CostOfGoods.Balance
	             |
	             |ORDER BY
	             |	Item" + ?(NeedDocument,",
	             |	PointInTime","")+"
	             |TOTALS BY
	             |	Item";
	
	Query.SetParameter("DocumentPointInTime", PointInTime);
	Query.SetParameter("Company",             Company);
	Query.SetParameter("ItemsArray",          ItemsArray);
	Query.SetParameter("ParcelDocument", ParcelDocument);
	
	FIFO = Enums.GoodsCostingMethods.FIFO;
	LIFO = Enums.GoodsCostingMethods.LIFO;
	
	SelectionItem = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionItem.Next() Do
		
		CostOfGoodsTable = New ValueTable;
		CostOfGoodsTable.Columns.Add("Item");
		CostOfGoodsTable.Columns.Add("Document");
		CostOfGoodsTable.Columns.Add("Date");
		CostOfGoodsTable.Columns.Add("QuantityBalance");
		CostOfGoodsTable.Columns.Add("AmountBalance");
		CostOfGoodsTable.Columns.Add("CostPerItem");
		
		Selection = SelectionItem.Select();
		
		While Selection.Next() Do
			
			CostOfGoodsTableRow = CostOfGoodsTable.Add();
			
			CostOfGoodsTableRow.Item            = Selection.Item;
			If NeedDocument Then
				CostOfGoodsTableRow.Document        = Selection.Document;
				CostOfGoodsTableRow.Date            = Selection.Date;
			Else
				CostOfGoodsTableRow.Document        = Undefined;
				CostOfGoodsTableRow.Date            = '00010101000000';
			EndIf;	
			CostOfGoodsTableRow.QuantityBalance = Selection.QuantityBalance;
			CostOfGoodsTableRow.AmountBalance   = Selection.AmountBalance;
			CostOfGoodsTableRow.CostPerItem     = Selection.CostPerItem;
			
		EndDo;
		
		If CostingMethod = LIFO Then
			CostOfGoodsTable.Sort("Date DESC, Document DESC");
		ElsIf CostingMethod = FIFO Then
			CostOfGoodsTable.Sort("Date ASC, Document ASC");
		EndIf;
		
		CostOfGoodsMap.Insert(SelectionItem.Item, CostOfGoodsTable);
		
	EndDo;
	
	Return CostOfGoodsMap;
	
EndFunction // GetCostOfGoodsMap()

Function GetCostOfGoodsTurnoverMap(ItemsArray, CostingMethod, Company, PointInTime, GetBalance = True, ParcelDocument = Undefined) Export
	
	CostOfGoodsTurnoverMap = New Map;
	
	NeedDocument = (CostingMethod = Enums.GoodsCostingMethods.FIFO OR CostingMethod = Enums.GoodsCostingMethods.LIFO);
	
	Query = New Query;
	Query.Text = "SELECT
	             |	CostOfGoodsTurnoversTurnovers.Item AS Item, " + ?(NeedDocument,"
	             |	CostOfGoodsTurnoversTurnovers.Document,
				 |	CASE
	             |		WHEN CostOfGoodsTurnoversTurnovers.Document = UNDEFINED
	             |			THEN DATETIME(1, 1, 1, 0, 0, 0)
	             |		ELSE CostOfGoodsTurnoversTurnovers.Document.Date
	             |	END AS Date,
	             |	CostOfGoodsTurnoversTurnovers.Document.PointInTime AS PointInTime,","")+"
	             |	SUM(CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |				THEN CostOfGoodsTurnoversTurnovers.QuantityTurnover
	             |			ELSE -CostOfGoodsTurnoversTurnovers.QuantityTurnover
	             |		END) AS Quantity,
	             |	SUM(CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |				THEN CostOfGoodsTurnoversTurnovers.AmountTurnover
	             |			ELSE -CostOfGoodsTurnoversTurnovers.AmountTurnover
	             |		END) AS Amount,
	             |	SUM(CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |				THEN CostOfGoodsTurnoversTurnovers.AmountCurrencyTurnover
	             |			ELSE -CostOfGoodsTurnoversTurnovers.AmountCurrencyTurnover
	             |		END) AS AmountCurrency
	             |FROM
	             |	AccumulationRegister.CostOfGoodsTurnovers.Turnovers( "+?(NeedDocument AND ParcelDocument<>Undefined," &ParcelDocumentPointInTime","")+"
	             |			,
	             |			&DocumentPointInTime,
	             |			,
	             |			Company = &Company
	             |				AND Item IN (&ItemsArray) " +?(NeedDocument AND NOT GetBalance,"AND Document = &ParcelDocument","")+"
	             |			) AS CostOfGoodsTurnoversTurnovers
	             |
	             |GROUP BY
	             |	CostOfGoodsTurnoversTurnovers.Item"+?(NeedDocument,",
	             |	CostOfGoodsTurnoversTurnovers.Document,
	             |	CostOfGoodsTurnoversTurnovers.Document.PointInTime,
	             |	CASE
	             |		WHEN CostOfGoodsTurnoversTurnovers.Document = UNDEFINED
	             |			THEN DATETIME(1, 1, 1, 0, 0, 0)
	             |		ELSE CostOfGoodsTurnoversTurnovers.Document.Date
	             |	END","")+"
	             |
	             |FOR UPDATE
	             |	AccumulationRegister.CostOfGoodsTurnovers.Turnovers
	             |
	             |ORDER BY
	             |	Item"+?(NeedDocument,",
	             |	PointInTime","")+"
	             |TOTALS BY
	             |	Item";
				 
	Query.SetParameter("ParcelDocument", ParcelDocument);
	If ParcelDocument <> Undefined Then
		Query.SetParameter("ParcelDocumentPointInTime", CommonAtServer.GetAttribute(ParcelDocument,"PointInTime"));	
	EndIf;	
	Query.SetParameter("DocumentPointInTime", PointInTime);
	Query.SetParameter("Company",             Company);
	Query.SetParameter("ItemsArray",          ItemsArray);
	
	FIFO = Enums.GoodsCostingMethods.FIFO;
	LIFO = Enums.GoodsCostingMethods.LIFO;
	
	SelectionItem = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionItem.Next() Do
		
		CostOfGoodsTurnoverTable = New ValueTable;
		CostOfGoodsTurnoverTable.Columns.Add("Item");
		CostOfGoodsTurnoverTable.Columns.Add("Document");
		CostOfGoodsTurnoverTable.Columns.Add("Date");
		CostOfGoodsTurnoverTable.Columns.Add("Quantity");
		CostOfGoodsTurnoverTable.Columns.Add("Amount");
		CostOfGoodsTurnoverTable.Columns.Add("AmountCurrency");
		
		Selection = SelectionItem.Select();
		
		While Selection.Next() Do
			
			CostOfGoodsTurnoverTableRow = CostOfGoodsTurnoverTable.Add();
			
			CostOfGoodsTurnoverTableRow.Item            = Selection.Item;
			If NeedDocument Then
				CostOfGoodsTurnoverTableRow.Document        = Selection.Document;
				CostOfGoodsTurnoverTableRow.Date            = Selection.Date;
			Else
				CostOfGoodsTurnoverTableRow.Document        = Undefined;
				CostOfGoodsTurnoverTableRow.Date            = '00010101000000';
			EndIf;	
			CostOfGoodsTurnoverTableRow.Quantity = Selection.Quantity;
			CostOfGoodsTurnoverTableRow.Amount   = Selection.Amount;
			CostOfGoodsTurnoverTableRow.AmountCurrency   = Selection.AmountCurrency;
			
		EndDo;
		
		If CostingMethod = LIFO Then
			CostOfGoodsTurnoverTable.Sort("Date DESC, Document DESC");
		ElsIf CostingMethod = FIFO Then
			CostOfGoodsTurnoverTable.Sort("Date ASC, Document ASC");
		EndIf;
		
		CostOfGoodsTurnoverMap.Insert(SelectionItem.Item, CostOfGoodsTurnoverTable);
		
	EndDo;
	
	Return CostOfGoodsTurnoverMap;
	
EndFunction // CostOfGoodsTurnoverMap()

Function GetCostOfGoodsIssueTurnoverMap(ItemsArray, CostingMethod, Company, PointInTime, ParcelDocument = Undefined) Export
	
	CostOfGoodsIssueTurnoverMap = New Map;
	
	NeedDocument = (CostingMethod = Enums.GoodsCostingMethods.FIFO OR CostingMethod = Enums.GoodsCostingMethods.LIFO);
	
	ParcelDocumentPointInTime = Undefined;
	If TypeOf(ParcelDocument) = Type("Array") Then
		
		For Each ParcelDocumentItem In ParcelDocument Do
			If ParcelDocumentItem = Undefined Then
				ParcelDocumentPointInTime = Undefined;
				Break;
			Else
				If ParcelDocumentPointInTime = Undefined Then
					ParcelDocumentPointInTime = CommonAtServer.GetAttribute(ParcelDocumentItem,"PointInTime");
				Else
					TmpParcelDocumentItemPointInTime = CommonAtServer.GetAttribute(ParcelDocumentItem,"PointInTime");
					If TmpParcelDocumentItemPointInTime.Compare(ParcelDocumentPointInTime)<0 Then
						ParcelDocumentPointInTime = CommonAtServer.GetAttribute(ParcelDocumentItem,"PointInTime");
					EndIf;	
				EndIf;	
			EndIf;	
		EndDo;	
		
	EndIf;	
		
	Query = New Query;
	Query.Text = "SELECT
	             |	CostOfGoodsTurnoversTurnovers.Item AS Item,"+?(NeedDocument,"
	             |	CostOfGoodsTurnoversTurnovers.Document AS Document,
				 |	CASE
	             |		WHEN CostOfGoodsTurnoversTurnovers.Document = UNDEFINED
	             |			THEN DATETIME(1, 1, 1, 0, 0, 0)
	             |		ELSE CostOfGoodsTurnoversTurnovers.Document.Date
	             |	END AS Date,","")+"
	             |	SUM(CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |				THEN -CostOfGoodsTurnoversTurnovers.QuantityTurnover
	             |			ELSE CostOfGoodsTurnoversTurnovers.QuantityTurnover
	             |		END) AS Quantity,
	             |	SUM(CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |				THEN -CostOfGoodsTurnoversTurnovers.AmountTurnover
	             |			ELSE CostOfGoodsTurnoversTurnovers.AmountTurnover
	             |		END) AS Amount,
	             |	SUM(CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |				THEN -CostOfGoodsTurnoversTurnovers.AmountCurrencyTurnover
	             |			ELSE CostOfGoodsTurnoversTurnovers.AmountCurrencyTurnover
	             |		END) AS AmountCurrency,
				 |	CostOfGoodsTurnoversTurnovers.CostPerItem AS CostPerItem
	             |FROM
	             |	AccumulationRegister.CostOfGoodsTurnovers.Turnovers("+?(NeedDocument AND ParcelDocumentPointInTime<>Undefined," &ParcelDocumentPointInTime","")+"
	             |			,
	             |			&DocumentPointInTime,
	             |			,
				 |			Direction NOT IN (VALUE(Catalog.CostOfGoodsMovementsDirections.PurchaseReceipt),VALUE(Catalog.CostOfGoodsMovementsDirections.GoodsReceipt),VALUE(Catalog.CostOfGoodsMovementsDirections.OtherHistoricalIssues))
				 |			AND CASE
				 |			WHEN Direction = VALUE(Catalog.CostOfGoodsMovementsDirections.Assembling)
				 |						THEN ReceiptExpense = VALUE(Enum.ReceiptExpense.Expense)
				 |				 	ELSE TRUE
				 |				END
				 |			AND Company = &Company
	             |				AND Item IN (&ItemsArray) " +?(NeedDocument," AND Document In (&ParcelDocument)","")+"
	             |			) AS CostOfGoodsTurnoversTurnovers
	             |
	             |GROUP BY
	             |	CostOfGoodsTurnoversTurnovers.Item,"+?(NeedDocument,"
	             |	CostOfGoodsTurnoversTurnovers.Document,
	             |	CASE
	             |		WHEN CostOfGoodsTurnoversTurnovers.Document = UNDEFINED
	             |			THEN DATETIME(1, 1, 1, 0, 0, 0)
	             |		ELSE CostOfGoodsTurnoversTurnovers.Document.Date
	             |	END,","")+"
				 |	CostOfGoodsTurnoversTurnovers.CostPerItem
	             |
	             |FOR UPDATE
	             |	AccumulationRegister.CostOfGoodsTurnovers.Turnovers
	             |
	             |ORDER BY
	             |	Item"+?(NeedDocument,"
	             |	,Date, 
				 |	Document","")+"
	             |TOTALS BY
	             |	Item";
				 
	Query.SetParameter("ParcelDocument", ParcelDocument);
	Query.SetParameter("ParcelDocumentPointInTime", ParcelDocumentPointInTime);
	Query.SetParameter("DocumentPointInTime", PointInTime);
	Query.SetParameter("Company",             Company);
	Query.SetParameter("ItemsArray",          ItemsArray);
	
	FIFO = Enums.GoodsCostingMethods.FIFO;
	LIFO = Enums.GoodsCostingMethods.LIFO;
	
	SelectionItem = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionItem.Next() Do
		
		CostOfGoodsIssueTurnoverTable = New ValueTable;
		CostOfGoodsIssueTurnoverTable.Columns.Add("Item");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Document");
		CostOfGoodsIssueTurnoverTable.Columns.Add("CostPerItem");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Date");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Quantity");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Amount");
		CostOfGoodsIssueTurnoverTable.Columns.Add("AmountCurrency");
		
		Selection = SelectionItem.Select();
		
		While Selection.Next() Do
			
			CostOfGoodsTurnoverIssueTableRow = CostOfGoodsIssueTurnoverTable.Add();
			
			CostOfGoodsTurnoverIssueTableRow.Item            = Selection.Item;
			If NeedDocument Then
				CostOfGoodsTurnoverIssueTableRow.Document        = Selection.Document;
				CostOfGoodsTurnoverIssueTableRow.Date            = Selection.Date;
			Else
				CostOfGoodsTurnoverIssueTableRow.Document        = Undefined;
				CostOfGoodsTurnoverIssueTableRow.Date            = '00010101000000';
			EndIf;	
			CostOfGoodsTurnoverIssueTableRow.CostPerItem        = Selection.CostPerItem;
			CostOfGoodsTurnoverIssueTableRow.Quantity = Selection.Quantity;
			CostOfGoodsTurnoverIssueTableRow.Amount   = Selection.Amount;
			CostOfGoodsTurnoverIssueTableRow.AmountCurrency   = Selection.AmountCurrency;
			
		EndDo;
		
		If CostingMethod = LIFO Then
			CostOfGoodsIssueTurnoverTable.Sort("Date DESC, Document DESC");
		ElsIf CostingMethod = FIFO Then	
			CostOfGoodsIssueTurnoverTable.Sort("Date ASC, Document ASC");
		EndIf;
		
		CostOfGoodsIssueTurnoverMap.Insert(SelectionItem.Item, CostOfGoodsIssueTurnoverTable);
		
	EndDo;
	
	Return CostOfGoodsIssueTurnoverMap;
	
EndFunction // GetCostOfGoodsIssueTurnoverMap()

Function GetCostOfGoodsIssueDirectionsTurnoverMap(ItemsArray, CostingMethod, Company, PointInTime, ParcelDocument = Undefined) Export
	
	CostOfGoodsIssueTurnoverMap = New Map;
	
	NeedDocument = (CostingMethod = Enums.GoodsCostingMethods.FIFO OR CostingMethod = Enums.GoodsCostingMethods.LIFO);
	
	Query = New Query;
	Query.Text = "SELECT
	             |	NestedSelect.Item AS Item,"+?(NeedDocument,"
	             |	NestedSelect.Document,
				 |	NestedSelect.Date,
	             |	NestedSelect.PointInTime AS PointInTime,","")+"
	             |	SUM(NestedSelect.Quantity) AS Quantity,
	             |	SUM(NestedSelect.Amount) AS Amount,
	             |	SUM(NestedSelect.AmountCurrency) AS AmountCurrency,
	             |	NestedSelect.CostPerItem AS CostPerItem,
	             |	NestedSelect.Direction,
	             |	NestedSelect.ExtDimension1,
	             |	NestedSelect.ExtDimension2
	             |FROM
	             |	(SELECT
	             |		CostOfGoodsTurnoversTurnovers.Item AS Item," + ?(NeedDocument,"
	             |		CostOfGoodsTurnoversTurnovers.Document AS Document,
				 |		CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.Document = UNDEFINED
	             |				THEN DATETIME(1, 1, 1, 0, 0, 0)
	             |			ELSE CostOfGoodsTurnoversTurnovers.Document.Date
	             |		END AS Date,
	             |		CostOfGoodsTurnoversTurnovers.Document.PointInTime AS PointInTime,","")+"
	             |		SUM(CASE
	             |				WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |					THEN -CostOfGoodsTurnoversTurnovers.QuantityTurnover
	             |				ELSE CostOfGoodsTurnoversTurnovers.QuantityTurnover
	             |			END) AS Quantity,
	             |		SUM(CASE
	             |				WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |					THEN -CostOfGoodsTurnoversTurnovers.AmountTurnover
	             |				ELSE CostOfGoodsTurnoversTurnovers.AmountTurnover
	             |			END) AS Amount,
	             |		SUM(CASE
	             |				WHEN CostOfGoodsTurnoversTurnovers.ReceiptExpense = VALUE(Enum.ReceiptExpense.Receipt)
	             |					THEN -CostOfGoodsTurnoversTurnovers.AmountCurrencyTurnover
	             |				ELSE CostOfGoodsTurnoversTurnovers.AmountCurrencyTurnover
	             |			END) AS AmountCurrency,
	             |		CostOfGoodsTurnoversTurnovers.CostPerItem AS CostPerItem,
	             |		CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.Direction = VALUE(Catalog.CostOfGoodsMovementsDirections.SalesReturnReceipt)
	             |				THEN VALUE(Catalog.CostOfGoodsMovementsDirections.SalesDelivery)
	             |			ELSE CostOfGoodsTurnoversTurnovers.Direction
	             |		END AS Direction,
	             |		CostOfGoodsTurnoversTurnovers.ExtDimension1 AS ExtDimension1,
	             |		CostOfGoodsTurnoversTurnovers.ExtDimension2 AS ExtDimension2
	             |	FROM
	             |		AccumulationRegister.CostOfGoodsTurnovers.Turnovers("+?(NeedDocument AND ParcelDocument<>Undefined," &ParcelDocumentPointInTime","")+"
	             |				,
	             |				&DocumentPointInTime,
	             |				,
	             |			Direction NOT IN (VALUE(Catalog.CostOfGoodsMovementsDirections.PurchaseReceipt),VALUE(Catalog.CostOfGoodsMovementsDirections.GoodsReceipt),VALUE(Catalog.CostOfGoodsMovementsDirections.OtherHistoricalIssues))
				 |			AND CASE
				 |			WHEN Direction = VALUE(Catalog.CostOfGoodsMovementsDirections.Assembling)
				 |						THEN ReceiptExpense = VALUE(Enum.ReceiptExpense.Expense)
				 |				 	ELSE TRUE
				 |				END
	             |					AND Company = &Company
	             |					AND Item IN (&ItemsArray) " +?(NeedDocument," AND Document = &ParcelDocument","")+"
				 |) AS CostOfGoodsTurnoversTurnovers
	             |	
	             |	GROUP BY
	             |		CostOfGoodsTurnoversTurnovers.Item," + ?(NeedDocument,"
	             |		CostOfGoodsTurnoversTurnovers.Document,
	             |		CostOfGoodsTurnoversTurnovers.Document.PointInTime,
	             |		CASE
	             |			WHEN CostOfGoodsTurnoversTurnovers.Document = UNDEFINED
	             |				THEN DATETIME(1, 1, 1, 0, 0, 0)
	             |			ELSE CostOfGoodsTurnoversTurnovers.Document.Date
	             |		END,","")+"
	             |		CostOfGoodsTurnoversTurnovers.CostPerItem,
	             |		CostOfGoodsTurnoversTurnovers.Direction,
	             |		CostOfGoodsTurnoversTurnovers.ExtDimension1,
	             |		CostOfGoodsTurnoversTurnovers.ExtDimension2
	             |	FOR UPDATE
	             |		AccumulationRegister.CostOfGoodsTurnovers.Turnovers) AS NestedSelect
	             |
	             |GROUP BY
	             |	NestedSelect.CostPerItem,
	             |	NestedSelect.Direction,
	             |	NestedSelect.ExtDimension2,
	             |	NestedSelect.ExtDimension1,"+?(NeedDocument,"
				 |	NestedSelect.Document,
	             |	NestedSelect.PointInTime,
	             |	NestedSelect.Date,","")+"
	             |	NestedSelect.Item
	             |
	             |HAVING
	             |	SUM(NestedSelect.Quantity) <> 0
	             |
	             |ORDER BY
	             |	Item,"+?(NeedDocument,"
	             |	PointInTime,","")+"
	             |	CostPerItem DESC
	             |TOTALS BY
	             |	Item,
	             |	CostPerItem";
				 
	Query.SetParameter("ParcelDocument", ParcelDocument);
	If ParcelDocument <> Undefined Then
		Query.SetParameter("ParcelDocumentPointInTime", CommonAtServer.GetAttribute(ParcelDocument,"PointInTime"));	
	EndIf;	
	Query.SetParameter("DocumentPointInTime", PointInTime);
	Query.SetParameter("Company",             Company);
	Query.SetParameter("ItemsArray",          ItemsArray);
	
	FIFO = Enums.GoodsCostingMethods.FIFO;
	LIFO = Enums.GoodsCostingMethods.LIFO;
	
	SelectionItem = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionItem.Next() Do
		
		CostOfGoodsIssueTurnoverTable = New ValueTable;
		CostOfGoodsIssueTurnoverTable.Columns.Add("Item");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Document");
		CostOfGoodsIssueTurnoverTable.Columns.Add("CostPerItem");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Direction");
		CostOfGoodsIssueTurnoverTable.Columns.Add("ExtDimension1");
		CostOfGoodsIssueTurnoverTable.Columns.Add("ExtDimension2");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Date");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Quantity");
		CostOfGoodsIssueTurnoverTable.Columns.Add("Amount");
		CostOfGoodsIssueTurnoverTable.Columns.Add("AmountCurrency");
		
		Selection = SelectionItem.Select(QueryResultIteration.ByGroups);
		
		While Selection.Next() Do
			
			If Selection.Quantity <> 0 Then
				
				SubSelection = Selection.Select();
				
				While SubSelection.Next() Do
					
					CostOfGoodsTurnoverIssueTableRow = CostOfGoodsIssueTurnoverTable.Add();
					
					CostOfGoodsTurnoverIssueTableRow.Item            = SubSelection.Item;
					If NeedDocument Then
						CostOfGoodsTurnoverIssueTableRow.Document        = SubSelection.Document;
						CostOfGoodsTurnoverIssueTableRow.Date            = SubSelection.Date;
					Else
						CostOfGoodsTurnoverIssueTableRow.Document        = Undefined;
						CostOfGoodsTurnoverIssueTableRow.Date            = '00010101000000';
					EndIf;	
					CostOfGoodsTurnoverIssueTableRow.CostPerItem        = SubSelection.CostPerItem;
					CostOfGoodsTurnoverIssueTableRow.Direction        = SubSelection.Direction;
					CostOfGoodsTurnoverIssueTableRow.ExtDimension1        = SubSelection.ExtDimension1;
					CostOfGoodsTurnoverIssueTableRow.ExtDimension2        = SubSelection.ExtDimension2;
					CostOfGoodsTurnoverIssueTableRow.Quantity = SubSelection.Quantity;
					CostOfGoodsTurnoverIssueTableRow.Amount   = SubSelection.Amount;
					CostOfGoodsTurnoverIssueTableRow.AmountCurrency   = SubSelection.AmountCurrency;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
		CostOfGoodsIssueTurnoverMap.Insert(SelectionItem.Item, CostOfGoodsIssueTurnoverTable);
		
	EndDo;
	
	Return CostOfGoodsIssueTurnoverMap;
	
EndFunction // GetCostOfGoodsIssueDirectionsTurnoverMap()

Function GetLastWriteOffPrice(Item, Company, PointInTime) Export
	
	CostOfGoodsMap = New Map;
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	CostOfGoods.Period AS Period,
	|	CostOfGoods.Quantity,
	|	CostOfGoods.Amount,
	|	CostOfGoods.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.CostOfGoods AS CostOfGoods
	|WHERE
	|	CostOfGoods.Company = &Company
	|	AND CostOfGoods.Item = &Item
	|	AND CostOfGoods.RecordType = &RecordType
	|	AND CostOfGoods.PointInTime < &PointInTime
	|	AND CostOfGoods.Active = TRUE
	|
	|FOR UPDATE
	|	AccumulationRegister.CostOfGoods
	|
	|ORDER BY
	|	Period DESC,
	|	Recorder DESC";
	
	Query.SetParameter("PointInTime", PointInTime);
	Query.SetParameter("Company",     Company);
	Query.SetParameter("Item",        Item);
	Query.SetParameter("RecordType",  AccumulationRecordType.Expense);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		If Selection.Quantity = 0 Then
			Return 0;
		Else
			Return Selection.Amount/Selection.Quantity;
		EndIf;
		
	Else
		
		Return 0;
		
	EndIf;
	
EndFunction // GetLastWriteOffPrice()

Function GetLastWriteInPrice(Item, Company, PointInTime) Export
	
	CostOfGoodsMap = New Map;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	Invoice.Quantity,
	             |	Invoice.Amount,
	             |	10 AS AdditionalSort
	             |FROM
	             |	(SELECT DISTINCT TOP 1
	             |		CostOfGoods.Quantity AS Quantity,
	             |		CostOfGoods.Period AS Period,
	             |		CostOfGoods.Recorder AS Recorder,
	             |		CostOfGoods.Amount AS Amount
	             |	FROM
	             |		AccumulationRegister.CostOfGoods AS CostOfGoods
	             |	WHERE
	             |		CostOfGoods.Company = &Company
	             |		AND CostOfGoods.Item = &Item
	             |		AND CostOfGoods.RecordType = &RecordType
	             |		AND CostOfGoods.PointInTime < &PointInTime
	             |		AND CostOfGoods.Quantity > 0
	             |		AND CostOfGoods.Active = TRUE
	             |		AND (CostOfGoods.Recorder REFS Document.PurchaseReceipt
	             |				OR CostOfGoods.Recorder REFS Document.GoodsReceipt
	             |				OR CostOfGoods.Recorder REFS Document.PurchaseInvoice)
	             |	
	             |	FOR UPDATE
	             |		AccumulationRegister.CostOfGoods
	             |	
	             |	ORDER BY
	             |		Period DESC,
	             |		Recorder DESC) AS Invoice
	             |
	             |UNION
	             |
	             |SELECT
	             |	Assembling.Quantity,
	             |	Assembling.Amount,
	             |	1
	             |FROM
	             |	(SELECT DISTINCT TOP 1
	             |		CostOfGoods.Quantity AS Quantity,
	             |		CostOfGoods.Period AS Period,
	             |		CostOfGoods.Recorder AS Recorder,
	             |		CostOfGoods.Amount AS Amount
	             |	FROM
	             |		AccumulationRegister.CostOfGoods AS CostOfGoods
	             |	WHERE
	             |		CostOfGoods.Company = &Company
	             |		AND CostOfGoods.Item = &Item
	             |		AND CostOfGoods.RecordType = &RecordType
	             |		AND CostOfGoods.PointInTime < &PointInTime
	             |		AND CostOfGoods.Quantity > 0
	             |		AND CostOfGoods.Active = TRUE
	             |		AND CostOfGoods.Recorder REFS Document.Assembling
	             |	
	             |	FOR UPDATE
	             |		AccumulationRegister.CostOfGoods
	             |	
	             |	ORDER BY
	             |		Period DESC,
	             |		Recorder DESC) AS Assembling
	             |
	             |ORDER BY
	             |	AdditionalSort DESC";
	
	Query.SetParameter("PointInTime", PointInTime);
	Query.SetParameter("Company",     Company);
	Query.SetParameter("Item",        Item);
	Query.SetParameter("RecordType",  AccumulationRecordType.Receipt);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		If Selection.Quantity = 0 Then
			Return 0;
		Else
			Return Selection.Amount/Selection.Quantity;
		EndIf;
		
	Else
		
		Return 0;
		
	EndIf;
	
EndFunction // GetLastWriteOffPrice()

Function GetHistoricalCostPerItem(Item,Company) Export
	
	Query = New Query;
	Query.Text = "SELECT
	|	HistoricalCostOfGoods.CostPerItem
	|FROM
	|	InformationRegister.HistoricalCostOfGoods AS HistoricalCostOfGoods
	|WHERE
	|	HistoricalCostOfGoods.Company = &Company
	|	AND HistoricalCostOfGoods.Item = &Item";
	Query.SetParameter("Company",Company);
	Query.SetParameter("Item",Item);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return Undefined;
	Else
		HistoricalSelection = QueryResult.Select();
		HistoricalSelection.Next();
		Return HistoricalSelection.CostPerItem;
	EndIf;	
		
EndFunction

// Function write-off goods from ItemsTable.
// Parameters:
//  ItemsTable - value table with columns Item, QuantityBase, DirectionStructure
// Returns CostOfGoodsMap
Function WriteOffCostOfGoods(ItemsTable, DocumentObject, Cancel) Export
	
	InitialCancel = Cancel;
	
	IsCostOfGoodsSequenceRestoring = DocumentObject.AdditionalProperties.Property("CostOfGoodsSequenceRestoring");
	
	ReturningMap = New Map();
	
	CostingMethod = GetCostingMethod(DocumentObject, DocumentObject.AdditionalProperties.MessageTitle, Cancel);
	
	If Cancel Then
		ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
		Return ReturningMap;
	EndIf;
	
	ItemsArray = ItemsTable.UnloadColumn("Item");
	CostOfGoodsMap = GetCostOfGoodsMap(ItemsArray, CostingMethod, DocumentObject.Company, DocumentObject.PointInTime());
	If CostingMethod <> Enums.GoodsCostingMethods.Average Then
		CostOfGoodsTurnoverMap = GetCostOfGoodsTurnoverMap(ItemsArray, CostingMethod, DocumentObject.Company, DocumentObject.PointInTime());
	EndIf;	
	
	ReceiptExpense   = Enums.ReceiptExpense.Expense;
	
	TurnoverType     = Enums.CostOfGoodsTurnoverTypes.Regular;
	
	For each ItemsTableRow In ItemsTable Do
		
		TmpErrorTxt = NStr("en='Cannot calculate cost of goods for ';pl='Nie można obliczyć kosztu towarów dla '") + ItemsTableRow.Item;
		
		CostOfGoodsTable = CostOfGoodsMap[ItemsTableRow.Item];
		If CostingMethod <> Enums.GoodsCostingMethods.Average Then
			CostOfGoodsTurnoverTable = CostOfGoodsTurnoverMap[ItemsTableRow.Item];
		EndIf;
		
		If CostOfGoodsTable = Undefined
			Or (CostOfGoodsTurnoverTable = Undefined AND CostingMethod <> Enums.GoodsCostingMethods.Average) Then
			Alerts.AddAlert(TmpErrorTxt, ?(IsCostOfGoodsSequenceRestoring,Enums.AlertType.Error,Enums.AlertType.Warning), Cancel,DocumentObject);	
			Continue;
		EndIf;
		
		ReturningCostOfGoodsTable = CostOfGoodsTable.Copy();
		ReturningMap.Insert(ItemsTableRow.Item,ReturningCostOfGoodsTable);
		
		For each CostOfGoodsTableRow In CostOfGoodsTable Do
			
			CostQuantity = Min(CostOfGoodsTableRow.QuantityBalance, ItemsTableRow.QuantityBase);
			
			If CostQuantity = 0 Then
				Break;
			EndIf;
			
			CostAmountRate = ?(CostOfGoodsTableRow.QuantityBalance = 0, 0, CostQuantity/CostOfGoodsTableRow.QuantityBalance);
			CostAmount = CostOfGoodsTableRow.AmountBalance*CostAmountRate;
			
			// RegisterRecords CostOfGoods
			Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
			
			Record.RecordType = AccumulationRecordType.Expense;
			Record.Period     = DocumentObject.Date;
			Record.Company    = DocumentObject.Company;
			Record.Item       = CostOfGoodsTableRow.Item;
			Record.Document   = CostOfGoodsTableRow.Document;
			
			Record.Quantity = CostQuantity;
			Record.Amount   = CostAmount;
			
			ItemsTableRow.QuantityBase = ItemsTableRow.QuantityBase - CostQuantity;
			
			CostOfGoodsTableRow.QuantityBalance = CostOfGoodsTableRow.QuantityBalance - CostQuantity;
			CostOfGoodsTableRow.AmountBalance   = CostOfGoodsTableRow.AmountBalance - CostAmount;
			
			If CostingMethod = Enums.GoodsCostingMethods.Average Then
				
				// RegisterRecords CostOfGoodsTurnovers
				Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
				
				Record.Period         = DocumentObject.Date;
				Record.ReceiptExpense = ReceiptExpense;
				Record.Company        = DocumentObject.Company;
				Record.Item           = CostOfGoodsTableRow.Item;
				Record.Document       = CostOfGoodsTableRow.Document;
				Record.TurnoverType   = TurnoverType;
				Record.Direction      = ItemsTableRow.DirectionStructure.Direction;
				If ItemsTableRow.DirectionStructure.Property("ExtDimension1") Then
					Record.ExtDimension1 = ItemsTableRow.DirectionStructure.ExtDimension1;
				EndIf;
				If ItemsTableRow.DirectionStructure.Property("ExtDimension2") Then
					Record.ExtDimension2 = ItemsTableRow.DirectionStructure.ExtDimension2;
				EndIf;
				Record.CostPerItem = 0;
				
				Record.Quantity       = CostQuantity;
				Record.Amount         = CostAmount;
				Record.AmountCurrency = 0;
				
				If TypeOf(CostOfGoodsTableRow.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
					Record.PurchaseReceipt = CostOfGoodsTableRow.Document;
				EndIf;	
								
			Else
				CostOfGoodsTurnoverCostPerItemTable = CostOfGoodsTurnoverTable.Copy(New Structure("Item, Document",CostOfGoodsTableRow.Item,?(TypeOf(CostOfGoodsTableRow.Document) = TypeOf(Documents.SetAccountingPolicy.EmptyRef()),Undefined,CostOfGoodsTableRow.Document)));
				
				For Each CostOfGoodsTurnoverCostPerItemTableRow In CostOfGoodsTurnoverCostPerItemTable Do
					
					CostTurnoverQuantity = Min(CostOfGoodsTurnoverCostPerItemTableRow.Quantity, CostQuantity);
					
					If CostTurnoverQuantity = 0 Then
						Break;
					EndIf;
					
					CostTurnoverAmountRate = ?(CostOfGoodsTurnoverCostPerItemTableRow.Quantity = 0, 0, CostTurnoverQuantity/CostOfGoodsTurnoverCostPerItemTableRow.Quantity);
					CostTurnoverAmount = CostOfGoodsTurnoverCostPerItemTableRow.Amount*CostTurnoverAmountRate;
					CostTurnoverAmountCurrency = CostOfGoodsTurnoverCostPerItemTableRow.AmountCurrency*CostTurnoverAmountRate;
					
					// RegisterRecords CostOfGoodsTurnovers
					Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
					
					Record.Period         = DocumentObject.Date;
					Record.ReceiptExpense = ReceiptExpense;
					Record.Company        = DocumentObject.Company;
					Record.Item           = CostOfGoodsTurnoverCostPerItemTableRow.Item;
					Record.Document       = CostOfGoodsTurnoverCostPerItemTableRow.Document;
					Record.TurnoverType   = TurnoverType;
					Record.Direction      = ItemsTableRow.DirectionStructure.Direction;
					If ItemsTableRow.DirectionStructure.Property("ExtDimension1") Then
						Record.ExtDimension1 = ItemsTableRow.DirectionStructure.ExtDimension1;
					EndIf;
					If ItemsTableRow.DirectionStructure.Property("ExtDimension2") Then
						Record.ExtDimension2 = ItemsTableRow.DirectionStructure.ExtDimension2;
					EndIf;
					
					Record.Quantity       = CostTurnoverQuantity;
					Record.Amount         = CostTurnoverAmount;
					Record.AmountCurrency = CostTurnoverAmountCurrency;
					
					Record.CostPerItem = Record.Amount/Record.Quantity;
					
					If TypeOf(CostOfGoodsTableRow.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
						Record.PurchaseReceipt = CostOfGoodsTurnoverCostPerItemTableRow.Document;
					EndIf;	
					
					CostQuantity = CostQuantity - CostTurnoverQuantity;
						
				EndDo;
				
				If CostQuantity>0 Then
					Alerts.AddAlert(TmpErrorTxt, ?(IsCostOfGoodsSequenceRestoring,Enums.AlertType.Error,Enums.AlertType.Warning), Cancel,DocumentObject);
				EndIf;	
				
			EndIf;
			
		EndDo;
		
		If ItemsTableRow.QuantityBase > 0 Then
			Alerts.AddAlert(TmpErrorTxt, ?(IsCostOfGoodsSequenceRestoring,Enums.AlertType.Error,Enums.AlertType.Warning), Cancel,DocumentObject);	
		EndIf;
		
	EndDo;
	
	// write sales invoice cogs
	If TypeOf(DocumentObject) = Type("DocumentObject.SalesDelivery") Then
		
		If DocumentObject.OperationType = Enums.OperationTypesSalesDelivery.SalesInvoice Then
			
			CostOfGoodsTable = DocumentObject.RegisterRecords.CostOfGoods.Unload();
			CostOfGoodsTable.GroupBy("Item","Amount, Quantity");
			
			Records = AccumulationRegisters.SalesInvoices.CreateRecordSet();
			Records.Filter.Recorder.Set(DocumentObject.DocumentBase);
			Records.Read();
			
			For Each Record In Records Do
				
				WriteCostsOfSoldGoodsInRecord(Record,CostOfGoodsTable);
				
			EndDo;	
			
			If Records.Modified() Then
				Records.Write();
			EndIf;	
			
		EndIf;	
		
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.SalesRetail") Then
		
		CostOfGoodsTable = DocumentObject.RegisterRecords.CostOfGoods.Unload();
		CostOfGoodsTable.GroupBy("Item","Amount, Quantity");
		
		For Each Record In DocumentObject.RegisterRecords.SalesInvoices Do
			
			WriteCostsOfSoldGoodsInRecord(Record,CostOfGoodsTable);
			
		EndDo;	
		
	EndIf;	
	
	ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
	Return ReturningMap;
	
EndFunction // WriteOffCostOfGoods()

Procedure WriteCostsOfSoldGoodsInRecord(SalesInvoiceRecord,CostOfGoodsTable,Coef = 1) Export
	
	FoundRow = Common.FindTabularPartRow(CostOfGoodsTable,New Structure("Item",SalesInvoiceRecord.Item));
	If FoundRow <> Undefined Then
		If FoundRow.Quantity = ABS(SalesInvoiceRecord.Quantity) Then
			SalesInvoiceRecord.CostsOfSoldGoods = FoundRow.Amount;
			FoundRow.Quantity = 0;
			FoundRow.Amount = 0;
		ElsIf FoundRow.Quantity<>0 Then 	
			SalesInvoiceRecord.CostsOfSoldGoods = (FoundRow.Amount/FoundRow.Quantity)*ABS(SalesInvoiceRecord.Quantity);
			FoundRow.Quantity = FoundRow.Quantity - ABS(SalesInvoiceRecord.Quantity);
			FoundRow.Amount = FoundRow.Amount - SalesInvoiceRecord.CostsOfSoldGoods;
		EndIf;	
		SalesInvoiceRecord.CostsOfSoldGoods = SalesInvoiceRecord.CostsOfSoldGoods * Coef;
	EndIf;	
	
EndProcedure	

// Procedure write-in goods from ItemsTable with current average costs.
// Parameters:
//  ItemsTable - value table with columns Item, AccountingGroup, QuantityBase, NetAmount, NetAmountCurrency, DirectionStructure
//               If NetAmount column value equal to Undefined, net amount will
//               be calculated automatically.
//
Procedure WriteInCostOfGoods(ItemsTable, DocumentObject, Cancel) Export
	
	InitialCancel = Cancel;
	
	IsCostOfGoodsSequenceRestoring = DocumentObject.AdditionalProperties.Property("CostOfGoodsSequenceRestoring");
	
	CostingMethod = GetCostingMethod(DocumentObject, DocumentObject.AdditionalProperties.MessageTitle, Cancel);
	
	If Cancel Then
		ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
		Return;
	EndIf;
	
	ItemsArray = New Array;
	For each ItemsTableRow In ItemsTable Do
		If ItemsTableRow.NetAmount = Undefined And ItemsArray.Find(ItemsTableRow.Item) = Undefined Then
			ItemsArray.Add(ItemsTableRow.Item);
		EndIf;
	EndDo;
		
	ReceiptExpense   = Enums.ReceiptExpense.Receipt;
	TurnoverType     = Enums.CostOfGoodsTurnoverTypes.Regular;
	
	If ItemsArray.Count() > 0 Then
		If (CostingMethod = Enums.GoodsCostingMethods.FIFO
			OR CostingMethod = Enums.GoodsCostingMethods.LIFO)
			AND ( TypeOf(DocumentObject) = Type("DocumentObject.SalesRetailReturn")
			OR TypeOf(DocumentObject) = Type("DocumentObject.SalesReturnReceipt")) Then
			
			Query = New Query;
			If TypeOf(DocumentObject) = Type("DocumentObject.SalesRetailReturn") Then	
				RecorderArray = New Array;
				RecorderArray.Add(DocumentObject.SalesRetail);
			ElsIf TypeOf(DocumentObject) = Type("DocumentObject.SalesReturnReceipt") Then	
				RecorderArray = New Array;
				If DocumentObject.OperationType = Enums.OperationTypesSalesReturnReceipt.SalesDelivery Then
					RecorderArray.Add(DocumentObject.DocumentBase);
				ElsIf DocumentObject.OperationType = Enums.OperationTypesSalesReturnReceipt.ListOfSalesReturnOrders
					Or DocumentObject.OperationType = Enums.OperationTypesSalesReturnReceipt.SalesReturnOrder
					OR DocumentObject.OperationType = Enums.OperationTypesSalesReturnReceipt.SalesCreditNoteReturn Then
					
					If DocumentObject.OperationType = Enums.OperationTypesSalesReturnReceipt.ListOfSalesReturnOrders
						Or DocumentObject.OperationType = Enums.OperationTypesSalesReturnReceipt.SalesReturnOrder Then
						SalesReturnOrdersArray = DocumentObject.ItemsLines.UnloadColumn("SalesReturnOrder");
						SROQuery = New Query;
						SROQuery.Text = "SELECT DISTINCT
						|	SalesReturnOrderItemsLines.SalesInvoice AS SalesInvoice
						|FROM
						|	Document.SalesReturnOrder.ItemsLines AS SalesReturnOrderItemsLines
						|WHERE
						|	SalesReturnOrderItemsLines.Ref IN(&Ref)";
						SROQuery.SetParameter("Ref",SalesReturnOrdersArray);
						SalesInvoiceArray = SROQuery.Execute().Unload().UnloadColumn("SalesInvoice");
					Else
						SalesInvoiceArray = New Array;
						SalesInvoiceArray.Add(DocumentObject.DocumentBase.SalesInvoice);
					EndIf;
					
					ThirdPartySalesInvoices = New Array;
					NormalSalesInvoicesArray = New Array;
					ThirdPartyBeginOfPeriod = GetServerDate();
					For Each SalesInvoiceItem In SalesInvoiceArray Do
						
						If ValueIsFilled(SalesInvoiceItem) Then
							
							If SalesInvoiceItem.OperationType = Enums.OperationTypesSalesInvoice.ThirdPartySale Then
								ThirdPartySalesInvoices.Add(SalesInvoiceItem);
								If SalesInvoiceItem.Date<ThirdPartyBeginOfPeriod Then
									ThirdPartyBeginOfPeriod = SalesInvoiceItem.Date;
								EndIf;	
							Else
								NormalSalesInvoicesArray.Add(SalesInvoiceItem);
							EndIf;	
							
						EndIf;	
						
					EndDo;	
					
					SIQuery = New Query;
					SIQuery.Text = "SELECT DISTINCT
					               |	SalesDelivery.Ref AS SalesDelivery
					               |FROM
					               |	Document.SalesDelivery AS SalesDelivery
					               |WHERE
					               |	SalesDelivery.DocumentBase IN(&Ref)
					               |
					               |UNION
					               |
					               |SELECT DISTINCT
					               |	SalesInvoiceItemsLines.SalesDelivery
					               |FROM
					               |	Document.SalesInvoice.ItemsLines AS SalesInvoiceItemsLines
					               |WHERE
					               |	SalesInvoiceItemsLines.Ref IN(&Ref)
					               |
					               |UNION
					               |
					               |SELECT
					               |	SalesInvoice.DocumentBase
					               |FROM
					               |	Document.SalesInvoice AS SalesInvoice
					               |WHERE
					               |	SalesInvoice.OperationType = VALUE(Enum.OperationTypesSalesInvoice.SalesRetail)
					               |	AND SalesInvoice.Ref IN(&Ref)
					               |;
					               |
					               |////////////////////////////////////////////////////////////////////////////////
					               |SELECT
					               |	SalesInvoicesTurnovers.Item,
					               |	SUM(CASE WHEN SalesInvoicesTurnovers.QuantityTurnover = 0 THEN 0 ELSE SalesInvoicesTurnovers.CostsOfSoldGoodsTurnover / SalesInvoicesTurnovers.QuantityTurnover END) AS CostPerItem,
					               |	SUM(SalesInvoicesTurnovers.QuantityTurnover) AS Quantity
					               |FROM
					               |	AccumulationRegister.SalesInvoices.Turnovers(&BeginOfPeriod, &EndOfPeriod, , SalesInvoice IN (&ThirdPartySalesInvoices)) AS SalesInvoicesTurnovers
					               |
					               |GROUP BY
					               |	SalesInvoicesTurnovers.Item";
					SIQuery.SetParameter("Ref",NormalSalesInvoicesArray);
					SIQuery.SetParameter("ThirdPartySalesInvoices",ThirdPartySalesInvoices);
					SIQuery.SetParameter("BeginOfPeriod",ThirdPartyBeginOfPeriod);
					SIQuery.SetParameter("EndOfPeriod",DocumentObject.PointInTime());
					QueryResultArray = SIQuery.ExecuteBatch();
					RecorderArray = QueryResultArray[0].Unload().UnloadColumn("SalesDelivery");
					ThirdPartyCOGSTable = QueryResultArray[1].Unload();
				EndIf;	
			EndIf;	
			
			Query.Text = "SELECT DISTINCT
			             |	CostOfGoods.Document,
			             |	CostOfGoods.Item AS Item,
			             |	SUM(CostOfGoods.Quantity) AS Quantity
			             |FROM
			             |	AccumulationRegister.CostOfGoods AS CostOfGoods
			             |WHERE
			             |	CostOfGoods.Recorder In (&Recorder)
			             |
			             |GROUP BY
			             |	CostOfGoods.Document,
			             |	CostOfGoods.Item
			             |TOTALS BY
			             |	Item";
			Query.SetParameter("Recorder",RecorderArray);
			SelectionByItem = Query.Execute().Select(QueryResultIteration.ByGroups);
			ParcelDocumentArray = New Array;
			ParcelDocumentMap = New Map;
			While SelectionByItem.Next() Do
				
				Selection = SelectionByItem.Select();
				ParcelItemTable = New ValueTable;
				ParcelItemTable.Columns.Add("Document");
				ParcelItemTable.Columns.Add("Quantity");
				While Selection.Next() Do
					
					ParcelDocumentArray.Add(Selection.Document);
					ParcelItemTableRow = ParcelItemTable.Add();
					If TypeOf(Selection.Document) = TypeOf(Documents.SetAccountingPolicy.EmptyRef()) Then
						ParcelItemTableRow.Document = Undefined;
					Else	
						ParcelItemTableRow.Document = Selection.Document;
					EndIf;	
					ParcelItemTableRow.Quantity = Selection.Quantity;
					
				EndDo;	
				ParcelItemTable.GroupBy("Document","Quantity");
				ParcelDocumentMap.Insert(SelectionByItem.Item,ParcelItemTable);
				
			EndDo;	
			If ParcelDocumentArray.Count() = 0 Then
				ParcelDocumentArray = Undefined
			EndIf;	
			CostOfGoodsIssueTurnoverMap = GetCostOfGoodsIssueTurnoverMap(ItemsArray, CostingMethod, DocumentObject.Company, DocumentObject.PointInTime(),ParcelDocumentArray);
		Else
			CostOfGoodsMap = GetCostOfGoodsMap(ItemsArray, CostingMethod, DocumentObject.Company, DocumentObject.PointInTime());
		EndIf;	
	EndIf;
	
	For each ItemsTableRow In ItemsTable Do
			
		If CostingMethod = Enums.GoodsCostingMethods.Average Then

			If TypeOf(DocumentObject) <> Type("DocumentObject.Disassembling")
				OR NOT ItemsTableRow.ChargeOff Then
				
				If ItemsTableRow.NetAmount = Undefined Then
					
					CostOfGoodsTable = CostOfGoodsMap[ItemsTableRow.Item];
					
					If CostOfGoodsTable = Undefined Then
						CostPerItem = GetLastWriteOffPrice(ItemsTableRow.Item, DocumentObject.Company, DocumentObject.PointInTime());
					Else
						If CostOfGoodsTable.Total("QuantityBalance") = 0 Then
							CostPerItem = 0;
						Else
							CostPerItem = CostOfGoodsTable.Total("AmountBalance")/CostOfGoodsTable.Total("QuantityBalance");
						EndIf;
					EndIf;
					
					NetAmount = ItemsTableRow.QuantityBase*CostPerItem;
					
				Else
					
					NetAmount = ItemsTableRow.NetAmount;
					
				EndIf;
				
				// RegisterRecords CostOfGoods
				Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
				
				Record.RecordType = AccumulationRecordType.Receipt;
				Record.Period     = DocumentObject.Date;
				Record.Company    = DocumentObject.Company;
				Record.Item       = ItemsTableRow.Item;
				
				Record.Quantity = ItemsTableRow.QuantityBase;
				Record.Amount   = NetAmount;
				
				// RegisterRecords CostOfGoodsTurnovers
				Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
				
				Record.Period         = DocumentObject.Date;
				Record.ReceiptExpense = ReceiptExpense;
				Record.Company        = DocumentObject.Company;
				Record.Item           = ItemsTableRow.Item;
				Record.TurnoverType   = TurnoverType;
				Record.Direction      = ItemsTableRow.DirectionStructure.Direction;
				If ItemsTableRow.DirectionStructure.Property("ExtDimension1") Then
					Record.ExtDimension1 = ItemsTableRow.DirectionStructure.ExtDimension1;
				EndIf;
				If ItemsTableRow.DirectionStructure.Property("ExtDimension2") Then
					Record.ExtDimension2 = ItemsTableRow.DirectionStructure.ExtDimension2;
				EndIf;
				Record.CostPerItem = 0;
				
				Record.Quantity       = ItemsTableRow.QuantityBase;
				Record.Amount         = NetAmount;
				Record.AmountCurrency = ItemsTableRow.NetAmountCurrency;
				
			EndIf;
			
		Else	
			
			If TypeOf(DocumentObject) = Type("DocumentObject.SalesRetailReturn")
				Or TypeOf(DocumentObject) = Type("DocumentObject.SalesReturnReceipt") Then
				
				ParcelDocumentTable = ParcelDocumentMap[ItemsTableRow.Item];
				IssueTable = CostOfGoodsIssueTurnoverMap[ItemsTableRow.Item];
				If IssueTable <> Undefined AND ParcelDocumentTable<>Undefined Then
					IssueTable.Sort("CostPerItem Asc");
					
					For Each IssueTableRow In IssueTable Do
						
						If IssueTableRow.Quantity<0 Then
							Continue;
						EndIf;	
						
						FoundRow = Common.FindTabularPartRow(ParcelDocumentTable,New Structure("Document",IssueTableRow.Document));
						If FoundRow = Undefined Then
							// error
							FoundRowQuantity = 0;
						Else
							FoundRowQuantity = FoundRow.Quantity;
						EndIf;	
						
						CostQuantity = Min(ItemsTableRow.QuantityBase, IssueTableRow.Quantity,FoundRowQuantity);
						
						If CostQuantity = 0 Then
							Continue;
						EndIf;
						
						CostAmountRate = ?(IssueTableRow.Quantity = 0, 0, CostQuantity/IssueTableRow.Quantity);
						CostAmount = IssueTableRow.Amount*CostAmountRate;
						
						// RegisterRecords CostOfGoods
						Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
						
						Record.RecordType = AccumulationRecordType.Receipt;
						Record.Period     = DocumentObject.Date;
						Record.Company    = DocumentObject.Company;
						Record.Item       = ItemsTableRow.Item;
						Record.Document   = IssueTableRow.Document;
						
						Record.Quantity = CostQuantity;
						Record.Amount   = CostAmount;
						
						// RegisterRecords CostOfGoodsTurnovers
						Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
						
						Record.Period         = DocumentObject.Date;
						Record.ReceiptExpense = ReceiptExpense;
						Record.Company        = DocumentObject.Company;
						Record.Item           = ItemsTableRow.Item;
						Record.Document       = IssueTableRow.Document;
						Record.TurnoverType   = TurnoverType;
						Record.Direction      = ItemsTableRow.DirectionStructure.Direction;
						If ItemsTableRow.DirectionStructure.Property("ExtDimension1") Then
							Record.ExtDimension1 = ItemsTableRow.DirectionStructure.ExtDimension1;
						EndIf;
						If ItemsTableRow.DirectionStructure.Property("ExtDimension2") Then
							Record.ExtDimension2 = ItemsTableRow.DirectionStructure.ExtDimension2;
						EndIf;
						
						Record.CostPerItem    = IssueTableRow.CostPerItem;
						
						Record.Quantity       = CostQuantity;
						Record.Amount         = CostAmount;
						
						If TypeOf(IssueTableRow.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
							Record.PurchaseReceipt = IssueTableRow.Document;
						EndIf;	
						
						ItemsTableRow.QuantityBase = ItemsTableRow.QuantityBase - CostQuantity;
						If FoundRow <> Undefined Then
							FoundRow.Quantity = FoundRow.Quantity - CostQuantity;
						EndIf;
						
					EndDo;	
				EndIf;
				
				If ItemsTableRow.QuantityBase>0 AND ThirdPartyCOGSTable <> Undefined Then
					
					FoundRow = Common.FindTabularPartRow(ThirdPartyCOGSTable,New Structure("Item",ItemsTableRow.Item));
					If FoundRow <> Undefined AND FoundRow.Quantity>0 Then
						CostPerItem = FoundRow.CostPerItem;
						
						Quantity = min(ItemsTableRow.QuantityBase,FoundRow.Quantity);
						CostAmount = Quantity*CostPerItem;
												
						// RegisterRecords CostOfGoods
						Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
						
						Record.RecordType = AccumulationRecordType.Receipt;
						Record.Period     = DocumentObject.Date;
						Record.Company    = DocumentObject.Company;
						Record.Item       = ItemsTableRow.Item;
						Record.Document   = DocumentObject.Ref;
						
						Record.Quantity = Quantity;
						Record.Amount   = CostAmount;
						
						// RegisterRecords CostOfGoodsTurnovers
						Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
						
						Record.Period         = DocumentObject.Date;
						Record.ReceiptExpense = ReceiptExpense;
						Record.Company        = DocumentObject.Company;
						Record.Item           = ItemsTableRow.Item;
						Record.Document       = DocumentObject.Ref;
						Record.TurnoverType   = TurnoverType;
						Record.Direction      = Catalogs.CostOfGoodsMovementsDirections.SalesReturnReceipt;
						Record.CostPerItem    = CostPerItem;
						
						Record.Quantity       = Quantity;
						Record.Amount         = CostAmount;
						
						ItemsTableRow.QuantityBase = ItemsTableRow.QuantityBase - Quantity;
					EndIf;	
					
				EndIf;
				
				If ItemsTableRow.QuantityBase>0 Then
										
					CostPerItem = GetHistoricalCostPerItem(ItemsTableRow.Item,DocumentObject.Company);
					If CostPerItem = Undefined Then
						CostPerItem = 0;
						Alerts.AddAlert(Alerts.ParametrizeString(NstR("en = 'It was not possible to calculate the cost for the returning item % P1 (%P2 %P3). This item has been receipted by 0 cost.'; pl = 'Nie udało się obliczyć koszt dla %P2 %P3 zwracanej pozycji %P1. Pozycja została przyjęta po koszcie 0.'"),New Structure("P1, P2, P3",ItemsTableRow.Item,ItemsTableRow.QuantityBase,ItemsTableRow.Item.BaseUnitOfMeasure)),Enums.AlertType.Warning,Cancel,DocumentObject);
					Else
						Alerts.AddAlert(Alerts.ParametrizeString(NstR("en = 'It was not possible to calculate the cost for the returning item % P1 (%P2 %P3). This item has been receipted by the historical cost.'; pl = 'Nie udało się obliczyć koszt dla %P2 %P3 zwracanej pozycji %P1. Pozycja została przyjęta po koszcie historycznym.'"),New Structure("P1, P2, P3, P4",ItemsTableRow.Item,ItemsTableRow.QuantityBase,ItemsTableRow.Item.BaseUnitOfMeasure, CostPerItem)),Enums.AlertType.Warning,Cancel,DocumentObject);
					EndIf;	
					
					CostAmount = ItemsTableRow.QuantityBase*CostPerItem;
					
					// RegisterRecords CostOfGoods
					Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
					
					Record.RecordType = AccumulationRecordType.Receipt;
					Record.Period     = DocumentObject.Date;
					Record.Company    = DocumentObject.Company;
					Record.Item       = ItemsTableRow.Item;
					Record.Document   = Undefined;
					
					Record.Quantity = ItemsTableRow.QuantityBase;
					Record.Amount   = CostAmount;
					
					// RegisterRecords CostOfGoodsTurnovers
					Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
					
					Record.Period         = DocumentObject.Date;
					Record.ReceiptExpense = ReceiptExpense;
					Record.Company        = DocumentObject.Company;
					Record.Item           = ItemsTableRow.Item;
					Record.Document       = Undefined;
					Record.TurnoverType   = TurnoverType;
					Record.Direction      = Catalogs.CostOfGoodsMovementsDirections.SalesReturnReceipt;
					Record.CostPerItem    = CostPerItem;
					
					Record.Quantity       = ItemsTableRow.QuantityBase;
					Record.Amount         = CostAmount;
					
				EndIf;
				
			ElsIf TypeOf(DocumentObject) = Type("DocumentObject.PurchaseReceipt")
				Or TypeOf(DocumentObject) = Type("DocumentObject.GoodsReceipt")
				Or (TypeOf(DocumentObject) = Type("DocumentObject.Disassembling") AND NOT ItemsTableRow.ChargeOff)
				Or TypeOf(DocumentObject) = Type("DocumentObject.Assembling") Then
				// Documents which generate new parcel
				
				If TypeOf(DocumentObject) = Type("DocumentObject.GoodsReceipt") 
					AND DocumentObject.PriceCalculationType = Enums.GoodsReceiptPriceCalculationTypes.CurrentCosts
					AND ValueIsNotFilled(ItemsTableRow.NetAmount) Then
					ItemsTableRow.NetAmount = ItemsTableRow.QuantityBase*GetLastWriteInPrice(ItemsTableRow.Item,DocumentObject.Company,DocumentObject.PointInTime());
				EndIf;	
				
				ParcelDocument = DocumentObject.Ref;
				
				// RegisterRecords CostOfGoods
				Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
				
				Record.RecordType = AccumulationRecordType.Receipt;
				Record.Period     = DocumentObject.Date;
				Record.Company    = DocumentObject.Company;
				Record.Item       = ItemsTableRow.Item;
				If TypeOf(DocumentObject) = Type("DocumentObject.GoodsReceipt")
					AND DocumentObject.OperationType = Enums.OperationTypesGoodsReceipt.OpeningBalance Then
					Record.Document   = Undefined;
				Else
					Record.Document   = ParcelDocument;
				EndIf;	
				
				Record.Quantity = ItemsTableRow.QuantityBase;
				Record.Amount   = ItemsTableRow.NetAmount;
				
				// RegisterRecords CostOfGoodsTurnovers
				Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
				
				Record.Period         = DocumentObject.Date;
				Record.ReceiptExpense = ReceiptExpense;
				Record.Company        = DocumentObject.Company;
				Record.Item           = ItemsTableRow.Item;
				If TypeOf(DocumentObject) = Type("DocumentObject.GoodsReceipt")
					AND DocumentObject.OperationType = Enums.OperationTypesGoodsReceipt.OpeningBalance Then
					Record.Document   = Undefined;
				Else
					Record.Document   = ParcelDocument;
				EndIf;	
				Record.TurnoverType   = TurnoverType;
				Record.Direction      = ItemsTableRow.DirectionStructure.Direction;
				If ItemsTableRow.DirectionStructure.Property("ExtDimension1") Then
					Record.ExtDimension1 = ItemsTableRow.DirectionStructure.ExtDimension1;
				EndIf;
				If ItemsTableRow.DirectionStructure.Property("ExtDimension2") Then
					Record.ExtDimension2 = ItemsTableRow.DirectionStructure.ExtDimension2;
				EndIf;
				
				Record.CostPerItem    = 0;
				
				Record.Quantity       = ItemsTableRow.QuantityBase;
				Record.Amount         = ItemsTableRow.NetAmount;
				Record.AmountCurrency = ItemsTableRow.NetAmountCurrency;
				
				If TypeOf(ParcelDocument) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
					Record.PurchaseReceipt = ParcelDocument;
				EndIf;	
				
				If ItemsTableRow.NetAmount = 0 Then
					Alerts.AddAlert(Alerts.ParametrizeString(NstR("en = 'It was not possible to calculate the cost for the receiptin item % P1 (%P2 %P3). This item has been receipted by 0 cost.'; pl = 'Nie udało się obliczyć koszt dla %P2 %P3 przyjmowanej pozycji %P1. Pozycja została przyjęta po koszcie 0.'"),New Structure("P1, P2, P3",ItemsTableRow.Item,ItemsTableRow.QuantityBase,ItemsTableRow.Item.BaseUnitOfMeasure)),Enums.AlertType.Warning,Cancel,DocumentObject);
				EndIf;	
				
			EndIf;
		EndIf;
		
	EndDo;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.SalesRetailReturn") Then
		
		CostOfGoodsTable = DocumentObject.RegisterRecords.CostOfGoods.Unload();
		CostOfGoodsTable.GroupBy("Item","Amount, Quantity");
		
		For Each Record In DocumentObject.RegisterRecords.SalesInvoices Do
			
			WriteCostsOfSoldGoodsInRecord(Record,CostOfGoodsTable,-1);
			
		EndDo;	
		
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.SalesReturnReceipt") Then
		
		If DocumentObject.OperationType = Enums.OperationTypesSalesReturnReceipt.SalesCreditNoteReturn Then
			
			CostOfGoodsTable = DocumentObject.RegisterRecords.CostOfGoods.Unload();
			CostOfGoodsTable.GroupBy("Item","Amount, Quantity");
			
			Records = AccumulationRegisters.SalesInvoices.CreateRecordSet();
			Records.Filter.Recorder.Set(DocumentObject.DocumentBase);
			Records.Read();
			
			GroupedRecords = Records.Unload();
			
			DimensionsList = "";
			DimensionsStructure = New Structure();
			For Each Dimension In Metadata.AccumulationRegisters.SalesInvoices.Dimensions Do
				
				If Dimension <> Metadata.AccumulationRegisters.SalesInvoices.Dimensions.InvoiceRecordType Then
					
					DimensionsList = DimensionsList + Dimension.Name + ", ";
					DimensionsStructure.Insert(Dimension.Name);
					
				EndIf;	
				
			EndDo;	
			
			If NOT IsBlankString(DimensionsList) Then
				
				DimensionsList = Left(DimensionsList,StrLen(DimensionsList)-2);
				
			EndIf;	
			
			GroupedRecords.GroupBy(DimensionsList,"Quantity");
			
			For Each Record In Records Do
				
				If Record.InvoiceRecordType = Enums.InvoiceRecordType.CreditNote Then
					
					FillPropertyValues(DimensionsStructure,Record);
					FoundRow = Common.FindTabularPartRow(GroupedRecords,DimensionsStructure);
					If FoundRow <> Undefined Then
						SavedQuantity = Record.Quantity;
						Record.Quantity = FoundRow.Quantity;
						WriteCostsOfSoldGoodsInRecord(Record,CostOfGoodsTable,-1);
						Record.Quantity = SavedQuantity;
					EndIf;		
					
				EndIf;	
				
			EndDo;	
			
			If Records.Modified() Then
				Records.Write();
			EndIf;	
			
		EndIf;	
		
	EndIf;	
	
	ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
	
EndProcedure // WriteInCostOfGoods()

Procedure WriteCostDistributionTable(DistributionTable, CurrentItem ,DocumentObject, ReceiptDocumentOrDate, Cancel) Export
	
	InitialCancel = Cancel;
	
	IsCostOfGoodsSequenceRestoring = DocumentObject.AdditionalProperties.Property("CostOfGoodsSequenceRestoring");
	
	If TypeOf(ReceiptDocumentOrDate) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then	
		ReceiptDocument = ReceiptDocumentOrDate;
		ReceiptPointInTime = CommonAtServer.GetAttribute(ReceiptDocument,"PointInTime");
	Else
		ReceiptDocument = Documents.PurchaseReceipt.EmptyRef();
		ReceiptPointInTime = ReceiptDocumentOrDate;
	EndIf;	
	
	If DistributionTable.Count() = 0 Then
		ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
		Return;
	EndIf;	
			
	DirectionReceipt = Catalogs.CostOfGoodsMovementsDirections.PurchaseReceipt;
	ReceiptExpense   = Enums.ReceiptExpense.Receipt;
	TurnoverType     = Enums.CostOfGoodsTurnoverTypes.Additional;
	
	CostingMethod = GetCostingMethodOnDate(DocumentObject.PointInTime(),DocumentObject.Company,,Cancel,DocumentObject);
	
	For Each ItemsSelection in DistributionTable Do
		
		// First make additional records for incoming costs
		// RegisterRecords CostOfGoodsTurnovers
		SlaveDirection = DirectionReceipt;
		SlaveExtDimension1 = Undefined;
		SlaveExtDimension2 = Undefined;
		If ItemsSelection.Item <> CurrentItem Then
			// not primary direction
			For Each DistributionTableRow In DistributionTable Do
				
				If DistributionTableRow.ExtDimension1 = ItemsSelection.Item 
					OR DistributionTableRow.ExtDimension2 = ItemsSelection.Item Then
					SlaveDirection = DistributionTableRow.Direction;
					SlaveExtDimension1 = DistributionTableRow.ExtDimension1;
					SlaveExtDimension2 = DistributionTableRow.ExtDimension2;
				EndIf;	
				
			EndDo;	
			
		EndIf;	
		Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
		
		Record.Period         = DocumentObject.Date;
		Record.ReceiptExpense = ReceiptExpense;
		Record.Company        = DocumentObject.Company;
		Record.Item           = ItemsSelection.Item;
		Record.Document       = ItemsSelection.Document;
		Record.TurnoverType   = TurnoverType;
		Record.Direction      = SlaveDirection;
		Record.ExtDimension1  = SlaveExtDimension1;
		Record.ExtDimension2  = SlaveExtDimension2;
		
		Record.Quantity       = 0;
		Record.CostPerItem       = 0;
		Record.Amount         = ItemsSelection.Amount;
		Record.AmountCurrency = ItemsSelection.AmountCurrency;
		
		If TypeOf(Record.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
			Record.PurchaseReceipt = Record.Document;
		ElsIf TypeOf(ReceiptDocument) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
			Record.PurchaseReceipt = ReceiptDocument;
		EndIf;	
		
		If ItemsSelection.CostCalculationMethod = Enums.CostCalculationMethod.EditWarehouseValue Then
			
			Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
			
			Record.Period     = DocumentObject.Date;
			Record.RecordType = AccumulationRecordType.Receipt;
			Record.Company    = DocumentObject.Company;
			Record.Item       = ItemsSelection.Item;
			Record.Document   = ItemsSelection.Document;
			
			Record.Quantity   = 0;
			Record.Amount     = ItemsSelection.Amount;
			
		ElsIf ItemsSelection.CostCalculationMethod = Enums.CostCalculationMethod.EditIssuedCost Then
			
			Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
			
			Record.Period         = DocumentObject.Date;
			Record.ReceiptExpense = Enums.ReceiptExpense.Expense;
			Record.Company        = DocumentObject.Company;
			Record.Item           = ItemsSelection.Item;
			Record.Document       = ItemsSelection.Document;
			Record.TurnoverType   = Enums.CostOfGoodsTurnoverTypes.Additional;
			Record.Direction      = ItemsSelection.Direction;
			Record.ExtDimension1  = ItemsSelection.ExtDimension1;
			Record.ExtDimension2  = ItemsSelection.ExtDimension2;
			
			Record.Quantity       = ItemsSelection.Quantity;
			Record.CostPerItem       = ItemsSelection.CostPerItem;
			Record.Amount         = ItemsSelection.Amount;
			Record.AmountCurrency = ItemsSelection.AmountCurrency;
			
			If TypeOf(Record.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
				Record.PurchaseReceipt = Record.Document;
			ElsIf TypeOf(ReceiptDocument) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
				Record.PurchaseReceipt = ReceiptDocument;
			EndIf;	
			
		EndIf;	
		
	EndDo;
	
	ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
	
EndProcedure	

Function ReturnOnCostError(DocumentObject, Cancel,InitialCancel)
	
	If NOT DocumentObject.AdditionalProperties.Property("CostOfGoodsSequenceRestoring") Then
		If Cancel AND NOT InitialCancel Then
			DocumentObject.AdditionalProperties.Insert("IsCostError",True);
		EndIf;	
		Cancel = InitialCancel;
	EndIf;	
	
	Return Cancel;
	
EndFunction

// Procedure add cost to goods, that were bought earlier. E.g. price differences between
// receipt and invoice, or additional costs of bying.
// Parameters:
//  ItemsTable - value table with columns Item, QuantityBase, Amount, AmountCurrency,
//               that contains additional amounts, that should be added to cost of goods.
//  DocumentObject - object of psting document, e.g. invoice
//  ReceiptDocumentOrDate - document that receiced goods to which we add costs or date of begin accounting
//  Cancel - cancel flag of posting procedure in DocumentObject.
//
Procedure PostingAdditionalCostOfGoods(ItemsTable, DocumentObject, ReceiptDocumentOrDate, Cancel,PriceCorrection = False,ReturnTable = Undefined) Export
	
	InitialCancel = Cancel;
	
	IsCostOfGoodsSequenceRestoring = DocumentObject.AdditionalProperties.Property("CostOfGoodsSequenceRestoring");
	
	If TypeOf(ReceiptDocumentOrDate) = TypeOf(Documents.PurchaseReceipt.EmptyRef())	Then	
		ReceiptDocument = ReceiptDocumentOrDate;
		ReceiptPointInTime = CommonAtServer.GetAttribute(ReceiptDocument,"PointInTime");
	Else
		ReceiptDocument = Documents.PurchaseReceipt.EmptyRef();
		ReceiptPointInTime = ReceiptDocumentOrDate;
	EndIf;	
	
	If TypeOf(DocumentObject.Ref) <> TypeOf(Documents.PurchaseCreditNotePriceCorrection.EmptyRef()) Then
		ItemsTable.Columns.Add("Index");
		ItemsTable.Columns.Add("CostCalculationMode");
		For Each ItemsTableRow In ItemsTable Do
			ItemsTableRow.Index = 0;
			ItemsTableRow.CostCalculationMode = Enums.PurchaseCreditNoteCostCalculationMode.AutoWarehouseFirst;
		EndDo;	
	EndIf;	
	
	CostingMethod = GetCostingMethodOnDate(DocumentObject.PointInTime(),DocumentObject.Company,,Cancel,DocumentObject);
	
	ItemsArray = ItemsTable.UnloadColumn("Item");
	
	DirectionReceipt = Catalogs.CostOfGoodsMovementsDirections.PurchaseReceipt;
	ReceiptExpense   = Enums.ReceiptExpense.Receipt;
	TurnoverType     = Enums.CostOfGoodsTurnoverTypes.Additional;
	
	If Cancel Then
		ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
		Return;
	EndIf;
	
	If CostingMethod = Enums.GoodsCostingMethods.Average Then
		
		AccountingPolicyQuery = New Query;
		AccountingPolicyQuery.Text = "SELECT
		|	AccountingPolicyGeneralSliceLast.AdditionalCostOfGoodsPostingMethodWhenAverage,
		|	AccountingPolicyGeneralSliceLast.CostOfGoodsWriteOffDefaultDirection
		|FROM
		|	InformationRegister.AccountingPolicyGeneral.SliceLast(&EndOfPeriod, Company = &Company) AS AccountingPolicyGeneralSliceLast";
		
		AccountingPolicyQuery.SetParameter("EndOfPeriod", DocumentObject.PointInTime());
		AccountingPolicyQuery.SetParameter("Company", DocumentObject.Company);
		
		AccountingPolicySelection = AccountingPolicyQuery.Execute().Select();
		
		AdditionalCostOfGoodsPostingMethodWhenAverage = Undefined;
		CostOfGoodsWriteOffDefaultDirection = Undefined;
		
		If AccountingPolicySelection.Next() Then
			AdditionalCostOfGoodsPostingMethodWhenAverage = AccountingPolicySelection.AdditionalCostOfGoodsPostingMethodWhenAverage;
			CostOfGoodsWriteOffDefaultDirection = AccountingPolicySelection.CostOfGoodsWriteOffDefaultDirection;
		EndIf;
		
		If ValueIsNotFilled(AdditionalCostOfGoodsPostingMethodWhenAverage) Then
			Alerts.AddAlert(DocumentObject.AdditionalProperties.MessageTitle + " " + NStr("en=""Accounting policy's attribute 'Additional cost of goods posting method when average' is not set!"";pl=""Atrybut polityki rachunkowości 'Sposób uwzględnienia dodatkowych kosztów towarów przy medodzie po średniej' nie został ustawiony."""), ?(IsCostOfGoodsSequenceRestoring,Enums.AlertType.Error,Enums.AlertType.Warning),Cancel, ,DocumentObject);
		ElsIf AdditionalCostOfGoodsPostingMethodWhenAverage = Enums.AdditionalCostOfGoodsPostingMethods.AccordingFinalBalance
			And ValueIsNotFilled(CostOfGoodsWriteOffDefaultDirection) Then
			Alerts.AddAlert(DocumentObject.AdditionalProperties.MessageTitle + " " + NStr("en = 'Accounting policy''s attribute ''Cost of goods write off default direction'' is not set!'; pl = 'Atrybut polityki rachunkowości ''Domyślny kierunek wydania towarów'' nie został ustawiony.'"), ?(IsCostOfGoodsSequenceRestoring,Enums.AlertType.Error,Enums.AlertType.Warning),Cancel,DocumentObject );
		EndIf;
		
		If Cancel Then
			ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
			Return;
		EndIf;
		
		If AdditionalCostOfGoodsPostingMethodWhenAverage = Enums.AdditionalCostOfGoodsPostingMethods.AccordingFinalBalance Then
			
			Query = New Query;
			Query.Text = "SELECT
			|	CostOfGoodsBalance.Item,
			|	CostOfGoodsBalance.QuantityBalance AS QuantityBase
			|FROM
			|	AccumulationRegister.CostOfGoods.Balance(
			|		&EndOfPeriod,
			|		Company = &Company
			|			AND Item IN (&ItemsArray)
			|			AND Document = UNDEFINED) AS CostOfGoodsBalance
			|
			|FOR UPDATE
			|	AccumulationRegister.CostOfGoods.Balance";
			
			Query.SetParameter("EndOfPeriod", DocumentObject.PointInTime());
			Query.SetParameter("Company", DocumentObject.Company);
			Query.SetParameter("ItemsArray", ItemsArray);
			
			QueryTable = Query.Execute().Unload();
			
			ReceiptExpense = Enums.ReceiptExpense.Expense;
			
			For Each ItemsSelection In ItemsTable Do
								
				QueryTableRow = QueryTable.Find(ItemsSelection.Item, "Item");
				If QueryTableRow = Undefined Then
					BalanceQuantity = 0;
				Else
					BalanceQuantity = QueryTableRow.QuantityBase;
				EndIf;
				
				QuantityRatio = ?(BalanceQuantity < ItemsSelection.QuantityBase, BalanceQuantity/ItemsSelection.QuantityBase, 1);
				ExpenseAmount = ItemsSelection.Amount - ItemsSelection.Amount*QuantityRatio;
				ExpenseAmountCurrency = ItemsSelection.AmountCurrency - ItemsSelection.AmountCurrency*QuantityRatio;
				
				// RegisterRecords CostOfGoodsTurnovers
				If ExpenseAmount <> 0 Or ExpenseAmountCurrency <> 0 Then
					
					If PriceCorrection Then
						If ReturnTable <> Undefined Then
							Record = ReturnTable.Add();
							Record.Document       = Undefined;
							Record.Item           = ItemsSelection.Item;
							Record.Direction      = CostOfGoodsWriteOffDefaultDirection;
							Record.ExtDimension1  = Undefined;
							Record.ExtDimension2  = Undefined;
							Record.Amount         = ExpenseAmount;
							Record.AmountCurrency = ExpenseAmountCurrency;
							Record.Index          = ItemsSelection.Index;
							Record.CostCalculationMethod = Enums.CostCalculationMethod.EditIssuedCost;
						EndIf;	
					Else	
						
						Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
						
						Record.Period         = DocumentObject.Date;
						Record.ReceiptExpense = ReceiptExpense;
						Record.Company        = DocumentObject.Company;
						Record.Item           = ItemsSelection.Item;
						Record.Document       = Undefined;
						Record.TurnoverType   = TurnoverType;
						Record.Direction      = CostOfGoodsWriteOffDefaultDirection;
						Record.ExtDimension1  = Undefined;
						Record.ExtDimension2  = Undefined;
						
						Record.Quantity       = 0;
						Record.Amount         = ExpenseAmount;
						Record.AmountCurrency = ExpenseAmountCurrency;
						
						If TypeOf(ItemsSelection.ParcelDocument) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
							Record.PurchaseReceipt = ItemsSelection.ParcelDocument;
						EndIf;	
						
					EndIf;
					
				EndIf;
				
				// RegisterRecords CostOfGoods
				If ExpenseAmount <> ItemsSelection.Amount Then
					If PriceCorrection Then
						
						If ReturnTable <> Undefined Then
							Record = ReturnTable.Add();
							Record.Document       = Undefined;
							Record.Item           = ItemsSelection.Item;
							Record.Amount         = ItemsSelection.Amount - ExpenseAmount;
							Record.Index          = ItemsSelection.Index;
							Record.CostCalculationMethod = Enums.CostCalculationMethod.EditWarehouseValue;
							Record.Direction = Catalogs.CostOfGoodsMovementsDirections.PurchaseReceipt;
						EndIf;	
						
					Else	
						
						Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
						
						Record.Period     = DocumentObject.Date;
						Record.RecordType = AccumulationRecordType.Receipt;
						Record.Company    = DocumentObject.Company;
						Record.Item       = ItemsSelection.Item;
						Record.Document   = Undefined;
						
						Record.Quantity   = 0;
						Record.Amount     = ItemsSelection.Amount - ExpenseAmount;
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		ElsIf AdditionalCostOfGoodsPostingMethodWhenAverage = Enums.AdditionalCostOfGoodsPostingMethods.AccordingWrittenOffGoodsMinusInitialBalance
			Or AdditionalCostOfGoodsPostingMethodWhenAverage = Enums.AdditionalCostOfGoodsPostingMethods.AccordingWrittenOffGoods Then
			
			If AdditionalCostOfGoodsPostingMethodWhenAverage = Enums.AdditionalCostOfGoodsPostingMethods.AccordingWrittenOffGoodsMinusInitialBalance Then
				
				BalanceQuery = New Query;
				BalanceQuery.Text = "SELECT
				|	CostOfGoodsBalance.Item,
				|	CostOfGoodsBalance.QuantityBalance AS QuantityBase
				|FROM
				|	AccumulationRegister.CostOfGoods.Balance(
				|			&BegOfPeriod,
				|			Company = &Company
				|				AND Item IN (&ItemsArray)
				|				AND Document = UNDEFINED) AS CostOfGoodsBalance
				|
				|FOR UPDATE
				|	AccumulationRegister.CostOfGoods.Balance";
				
				BalanceQuery.SetParameter("BegOfPeriod", ReceiptPointInTime);
				BalanceQuery.SetParameter("Company", DocumentObject.Company);
				BalanceQuery.SetParameter("ItemsArray", ItemsArray);
				
				BalanceTable = BalanceQuery.Execute().Unload();
				
			EndIf;
			
			Query = New Query;
			Query.Text = "SELECT
			|	CostOfGoodsTurnoversTurnovers.Item,
			|	CostOfGoodsTurnoversTurnovers.Direction,
			|	CostOfGoodsTurnoversTurnovers.ExtDimension1,
			|	CostOfGoodsTurnoversTurnovers.ExtDimension2,
			|	CostOfGoodsTurnoversTurnovers.QuantityTurnover AS QuantityBase
			|FROM
			|	AccumulationRegister.CostOfGoodsTurnovers.Turnovers(
			|			&BegOfPeriod,
			|			&EndOfPeriod,
			|			,
			|			Company = &Company
			|				AND ReceiptExpense = &ReceiptExpense
			|				AND TurnoverType = &TurnoverType
			|				AND Document = UNDEFINED
			|				AND Item IN (&ItemsArray)
			|				AND Direction <> VALUE(Catalog.CostOfGoodsMovementsDirections.PurchaseReturnDelivery)) AS CostOfGoodsTurnoversTurnovers
			|
			|FOR UPDATE
			|	AccumulationRegister.CostOfGoodsTurnovers.Turnovers";
			
			Query.SetParameter("BegOfPeriod", ReceiptPointInTime);
			
			If NOT PriceCorrection Then
				Query.SetParameter("EndOfPeriod", DocumentObject.PointInTime());	
			Else
				Query.SetParameter("EndOfPeriod", CurrentDate());
			EndIf;	
			
			Query.SetParameter("Company", DocumentObject.Company);
			Query.SetParameter("ReceiptExpense", Enums.ReceiptExpense.Expense);
			Query.SetParameter("TurnoverType", Enums.CostOfGoodsTurnoverTypes.Regular);
			Query.SetParameter("ItemsArray", ItemsArray);
			
			QueryTable = Query.Execute().Unload();
			
			ReceiptExpense = Enums.ReceiptExpense.Expense;
			
			For Each ItemsSelection In ItemsTable Do
				
				QueryTableRows = QueryTable.FindRows(New Structure("Item", ItemsSelection.Item));
				ExpenseQuantity = 0;
				For Each QueryTableRow In QueryTableRows Do
					ExpenseQuantity = ExpenseQuantity + QueryTableRow.QuantityBase;
				EndDo;
				
				BalanceQuantity = 0;
				
				If AdditionalCostOfGoodsPostingMethodWhenAverage = Enums.AdditionalCostOfGoodsPostingMethods.AccordingWrittenOffGoodsMinusInitialBalance Then
									
					BalanceTableRow = BalanceTable.Find(ItemsSelection.Item, "Item");
					
					If BalanceTableRow = Undefined Then
						BalanceQuantity = 0;
					Else
						BalanceQuantity = BalanceTableRow.QuantityBase;
					EndIf;
					
					BalanceQuantity = ?(ExpenseQuantity > BalanceQuantity, BalanceQuantity, ExpenseQuantity);
					
				EndIf;
				
				QuantityRatio = ?((ExpenseQuantity - BalanceQuantity) < ItemsSelection.QuantityBase, (ExpenseQuantity - BalanceQuantity)/ItemsSelection.QuantityBase, 1);
				
				ExpenseAmount = ItemsSelection.Amount*QuantityRatio;
				ExpenseAmountCurrency = ItemsSelection.AmountCurrency*QuantityRatio;
				
				// RegisterRecords CostOfGoodsTurnovers
				If ExpenseAmount <> 0 Or ExpenseAmountCurrency <> 0 Then
					
					ReferenceExpenseAmount = ExpenseAmount;
					ReferenceExpenseAmountCurrency = ExpenseAmountCurrency;
					
					For Each QueryTableRow In QueryTableRows Do
						
						RowQuantityRatio = QueryTableRow.QuantityBase/ExpenseQuantity;
						RowExpenseAmount         = ExpenseAmount*RowQuantityRatio;
						RowExpenseAmountCurrency = ExpenseAmountCurrency*RowQuantityRatio;
						
						If PriceCorrection Then
							
							If ReturnTable <> Undefined Then
								Record = ReturnTable.Add();
								Record.Document       = Undefined;
								Record.Item           = ItemsSelection.Item;
								Record.Direction      = QueryTableRow.Direction;
								Record.ExtDimension1  = QueryTableRow.ExtDimension1;
								Record.ExtDimension2  = QueryTableRow.ExtDimension2;
								Record.Amount         = RowExpenseAmount;
								Record.AmountCurrency = RowExpenseAmountCurrency;
								Record.Index          = ItemsSelection.Index;
								Record.CostCalculationMethod = Enums.CostCalculationMethod.EditIssuedCost;
							EndIf;	
							
						Else	
							
							Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
							
							Record.Period         = DocumentObject.Date;
							Record.ReceiptExpense = ReceiptExpense;
							Record.Company        = DocumentObject.Company;
							Record.Item           = ItemsSelection.Item;
							Record.Document       = Undefined;
							Record.TurnoverType   = TurnoverType;
							Record.Direction      = QueryTableRow.Direction;
							Record.ExtDimension1  = QueryTableRow.ExtDimension1;
							Record.ExtDimension2  = QueryTableRow.ExtDimension2;
							
							Record.Quantity       = 0;
							Record.Amount         = RowExpenseAmount;
							Record.AmountCurrency = RowExpenseAmountCurrency;
														
						EndIf;
						
						ReferenceExpenseAmount = ReferenceExpenseAmount - Record.Amount;
						
						
					EndDo;
					
					// Add to the last record rounding errors
					Record.Amount         = Record.Amount + ReferenceExpenseAmount;
					
				EndIf;
				
				// RegisterRecords CostOfGoods
				If ExpenseAmount <> ItemsSelection.Amount Then
					
					If PriceCorrection Then
						
						If ReturnTable <> Undefined Then
							Record = ReturnTable.Add();
							Record.Document       = Undefined;
							Record.Item           = ItemsSelection.Item;
							Record.Amount         = ItemsSelection.Amount - ExpenseAmount;
							Record.Index          = ItemsSelection.Index;
							Record.CostCalculationMethod = Enums.CostCalculationMethod.EditWarehouseValue;
						EndIf;	
						
					Else	
						
						Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
						
						Record.Period     = DocumentObject.Date;
						Record.RecordType = AccumulationRecordType.Receipt;
						Record.Company    = DocumentObject.Company;
						Record.Item       = ItemsSelection.Item;
						Record.Document   = Undefined;
						
						Record.Quantity   = 0;
						Record.Amount     = ItemsSelection.Amount - ExpenseAmount;
						
					EndIf;	
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		
		// Fifo or lifo
		
		StartAccountingDate = Constants.StartAccountingDate.Get();
		IsArchiveDocument = (TypeOf(DocumentObject) = Type("DocumentObject.PurchaseCreditNotePriceCorrection")
			AND (DocumentObject.PurchaseInvoice.IsArchive = True 
				OR (TypeOf(ReceiptPointInTime) = Type("PointInTime") AND ReceiptPointInTime.Date<=StartAccountingDate) 
				OR (TypeOf(ReceiptPointInTime) = Type("Date") AND ReceiptPointInTime<=StartAccountingDate) 
				OR ((TypeOf(ReceiptDocument) = Type("DocumentRef.PurchaseReceipt")				) 
				AND ValueIsFilled(ReceiptDocument) AND ReceiptPointInTime.Date<StartAccountingDate)));
		If ValueIsFilled(ReceiptDocument) AND NOT IsArchiveDocument Then
			ReceiptDocumentCostingMethod = GetCostingMethodOnDate(CommonAtServer.GetAttribute(ReceiptDocument,"PointInTime"),ReceiptDocument.Company,,Cancel,ReceiptDocument);
			If ReceiptDocumentCostingMethod <> Enums.GoodsCostingMethods.FIFO
				AND ReceiptDocumentCostingMethod <> Enums.GoodsCostingMethods.LIFO Then
				ReceiptDocument = Undefined;	
			EndIf;	
		Else
			ReceiptDocument = Undefined;	
		EndIf;
		
		CostOfGoodsIssueTurnoverMap = GetCostOfGoodsIssueDirectionsTurnoverMap(ItemsArray,CostingMethod,DocumentObject.Company,DocumentObject.PointInTime(),ReceiptDocument);
		CostOfGoodsMap = GetCostOfGoodsMap(ItemsArray,CostingMethod,DocumentObject.Company,DocumentObject.PointInTime(),False,ReceiptDocument);
			
		ReceiptExpense = Enums.ReceiptExpense.Expense;
		
		For Each ItemsSelection In ItemsTable Do
			
			CostOfGoodsToCostOfGoodsTurnovers = New ValueTable;
			CostOfGoodsToCostOfGoodsTurnovers.Columns.Add("ParcelDocument");
			CostOfGoodsToCostOfGoodsTurnovers.Columns.Add("Amount");
			
			CostOfGoodsTable = CostOfGoodsMap[ItemsSelection.Item];
			// omit stock with cost per item <=0.01
			If CostOfGoodsTable <> Undefined Then
				For Each CostOfGoodsTableRow In CostOfGoodsTable Do
					If CostOfGoodsTableRow.CostPerItem<=0.01 Then
						CostOfGoodsTableRow.QuantityBalance = 0;
						CostOfGoodsTableRow.AmountBalance = 0;
					EndIf;	
				EndDo;
			EndIf;
			
			If CostOfGoodsTable = Undefined Then
				StockQuantity = 0;
			Else	
				StockQuantity = CostOfGoodsTable.Total("QuantityBalance");
			EndIf;	
						
			StockRate = ?(ItemsSelection.QuantityBase = 0, 0, StockQuantity/ItemsSelection.QuantityBase);
			If StockRate>1 Then
				StockRate = 1;
			EndIf;	
						
			If StockRate <> 0 AND ItemsSelection.CostCalculationMode <> Enums.PurchaseCreditNoteCostCalculationMode.AutoOnlyIssued Then
				ConstItemsSelectionQuantityBase = ItemsSelection.QuantityBase*StockRate;
				ConstItemsSelectionAmount = ItemsSelection.Amount*StockRate;
				If ItemsSelection.Amount<0 Then
					MinAvailableAmount = Max(0,CostOfGoodsTable.Total("AmountBalance"));
					If MinAvailableAmount<>0 Then
						MinAvailableAmount = Max(MinAvailableAmount - StockQuantity*0.01,0);
					EndIf;	
					ConstItemsSelectionAmount = Max(ConstItemsSelectionAmount,-MinAvailableAmount);
				EndIf;	
				
				For each CostOfGoodsTableRow In CostOfGoodsTable Do
					
					CostQuantity = Min(CostOfGoodsTableRow.QuantityBalance, ConstItemsSelectionQuantityBase);
					
					If CostQuantity = 0 Then
						Break;
					EndIf;
										
					CostAmountRate = ?(ConstItemsSelectionQuantityBase = 0, 0, CostQuantity/ConstItemsSelectionQuantityBase);
					CostAmount = ConstItemsSelectionAmount*CostAmountRate;
					
					If PriceCorrection Then
						If ReturnTable <> Undefined Then
							Record = ReturnTable.Add();
							Record.Document       = CostOfGoodsTableRow.Document;
							Record.Item           = ItemsSelection.Item;
							Record.Amount         = CostAmount;
							Record.Index          = ItemsSelection.Index;
							Record.CostCalculationMethod = Enums.CostCalculationMethod.EditWarehouseValue;
							Record.Direction      = Catalogs.CostOfGoodsMovementsDirections.PurchaseReceipt;
						EndIf;	
					Else
						Record = DocumentObject.RegisterRecords.CostOfGoods.Add();
						
						Record.Period     = DocumentObject.Date;
						Record.RecordType = AccumulationRecordType.Receipt;
						Record.Company    = DocumentObject.Company;
						Record.Item       = ItemsSelection.Item;
						Record.Document   = CostOfGoodsTableRow.Document;
						
						Record.Quantity   = 0;
						Record.Amount     = CostAmount;
						
						CostOfGoodsToCostOfGoodsTurnoversRow = CostOfGoodsToCostOfGoodsTurnovers.Add();
						CostOfGoodsToCostOfGoodsTurnoversRow.ParcelDocument = CostOfGoodsTableRow.Document; 
						CostOfGoodsToCostOfGoodsTurnoversRow.Amount = CostAmount; 
						
					EndIf;
					
					ItemsSelection.QuantityBase = ItemsSelection.QuantityBase - CostQuantity;
					ItemsSelection.Amount = ItemsSelection.Amount - CostAmount;
					
					ConstItemsSelectionQuantityBase = ConstItemsSelectionQuantityBase - CostQuantity;
					ConstItemsSelectionAmount = ConstItemsSelectionAmount - CostAmount;
					
					CostOfGoodsTableRow.QuantityBalance = CostOfGoodsTableRow.QuantityBalance - CostQuantity;
					CostOfGoodsTableRow.AmountBalance   = CostOfGoodsTableRow.AmountBalance - ABS(CostAmount);
					
				EndDo;
			EndIf;
			
			If StockRate<>1 OR ItemsSelection.CostCalculationMode = Enums.PurchaseCreditNoteCostCalculationMode.AutoOnlyIssued Then
				// need recalc issued
				
				// do not use proportion in the ItemsSelection.QuantityBase remains qty after stock correction
				ConstItemsSelectionQuantityBase = ItemsSelection.QuantityBase;
				ConstItemsSelectionAmount = ItemsSelection.Amount;
				
				IssuedItemTable = CostOfGoodsIssueTurnoverMap.Get(ItemsSelection.Item);
				If IssuedItemTable <> Undefined Then
					IssuedItemTable.Sort("CostPerItem DESC");
					
					For Each IssuedItemTableRow In IssuedItemTable Do
						
						If IssuedItemTableRow.Quantity<0
							OR (IssuedItemTableRow.Quantity=0 AND IssuedItemTableRow.Amount = 0) Then
							Continue;
						EndIf;	
						
						IssuedTurnoverQuantity = Min(IssuedItemTableRow.Quantity, ConstItemsSelectionQuantityBase);
						
						If IssuedTurnoverQuantity = 0 Then
							Break;
						EndIf;
						
						IssuedTurnoverAmountRate = ?(ConstItemsSelectionQuantityBase = 0, 0, IssuedTurnoverQuantity/ConstItemsSelectionQuantityBase);
						IssuedTurnoverAmountRateFull = ?(IssuedTurnoverQuantity = 0, 0, IssuedTurnoverQuantity/IssuedItemTableRow.Quantity);
						IssuedAmountAfterRate = ConstItemsSelectionAmount*IssuedTurnoverAmountRate;
						IssuedAmountAfterRateFull = IssuedItemTableRow.Amount*IssuedTurnoverAmountRateFull;
						
						If IssuedAmountAfterRateFull<ABS(IssuedAmountAfterRate) AND IssuedAmountAfterRate<0 Then
							// when issued try to go to negative
							Continue;
						EndIf;	
						
						If PriceCorrection Then
							If ReturnTable <> Undefined Then
								Record = ReturnTable.Add();
								Record.Document       = IssuedItemTableRow.Document;
								Record.Item           = ItemsSelection.Item;
								Record.Amount         = -IssuedAmountAfterRateFull;
								Record.Index          = ItemsSelection.Index;
								Record.CostCalculationMethod = Enums.CostCalculationMethod.EditIssuedCost;
								Record.Direction = IssuedItemTableRow.Direction;
								Record.ExtDimension1      = IssuedItemTableRow.ExtDimension1;
								Record.ExtDimension2      = IssuedItemTableRow.ExtDimension2;
								Record.CostPerItem = IssuedItemTableRow.CostPerItem;
							
								Record.Quantity       = -IssuedTurnoverQuantity;
							EndIf;	
						Else
							
							// RegisterRecords CostOfGoodsTurnovers
							Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
							
							Record.Period         = DocumentObject.Date;
							Record.ReceiptExpense = ReceiptExpense;
							Record.Company        = DocumentObject.Company;
							Record.Item           = IssuedItemTableRow.Item;
							Record.Document       = IssuedItemTableRow.Document;
							Record.TurnoverType   = TurnoverType;
							Record.Direction      = IssuedItemTableRow.Direction;
							Record.ExtDimension1      = IssuedItemTableRow.ExtDimension1;
							Record.ExtDimension2      = IssuedItemTableRow.ExtDimension2;
							Record.CostPerItem = IssuedItemTableRow.CostPerItem;
							
							Record.Quantity       = -IssuedTurnoverQuantity;
							Record.Amount         = -IssuedAmountAfterRateFull;
							
							If TypeOf(Record.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
								Record.PurchaseReceipt = Record.Document;
							EndIf;	
							
							CostOfGoodsToCostOfGoodsTurnoversRow = CostOfGoodsToCostOfGoodsTurnovers.Add();
							CostOfGoodsToCostOfGoodsTurnoversRow.ParcelDocument = Record.Document; 
							CostOfGoodsToCostOfGoodsTurnoversRow.Amount = -IssuedAmountAfterRateFull;
							
						EndIf;
						
						If PriceCorrection Then
							If ReturnTable <> Undefined Then
								Record = ReturnTable.Add();
								Record.Document       = IssuedItemTableRow.Document;
								Record.Item           = ItemsSelection.Item;
								Record.Amount         = IssuedAmountAfterRateFull + IssuedAmountAfterRate;
								Record.Index          = ItemsSelection.Index;
								Record.CostCalculationMethod = Enums.CostCalculationMethod.EditIssuedCost;
								Record.Direction      = IssuedItemTableRow.Direction;
								Record.ExtDimension1      = IssuedItemTableRow.ExtDimension1;
								Record.ExtDimension2      = IssuedItemTableRow.ExtDimension2;
								Record.Quantity       = IssuedTurnoverQuantity;
								Record.CostPerItem = Record.Amount/Record.Quantity;
							EndIf;	
						Else
							
							// RegisterRecords CostOfGoodsTurnovers
							Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
							
							Record.Period         = DocumentObject.Date;
							Record.ReceiptExpense = ReceiptExpense;
							Record.Company        = DocumentObject.Company;
							Record.Item           = IssuedItemTableRow.Item;
							Record.Document       = IssuedItemTableRow.Document;
							Record.TurnoverType   = TurnoverType;
							Record.Direction      = IssuedItemTableRow.Direction;
							Record.ExtDimension1      = IssuedItemTableRow.ExtDimension1;
							Record.ExtDimension2      = IssuedItemTableRow.ExtDimension2;
							
							Record.Quantity       = IssuedTurnoverQuantity;
							Record.Amount         = IssuedAmountAfterRateFull + IssuedAmountAfterRate;
							
							Record.CostPerItem = Record.Amount/Record.Quantity;
							
							If TypeOf(Record.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
								Record.PurchaseReceipt = Record.Document;
							EndIf;	
							
							CostOfGoodsToCostOfGoodsTurnoversRow = CostOfGoodsToCostOfGoodsTurnovers.Add();
							CostOfGoodsToCostOfGoodsTurnoversRow.ParcelDocument = Record.Document; 
							CostOfGoodsToCostOfGoodsTurnoversRow.Amount = IssuedAmountAfterRateFull + IssuedAmountAfterRate;
							
						EndIf;
						
						ConstItemsSelectionQuantityBase = ConstItemsSelectionQuantityBase - IssuedTurnoverQuantity;
						ConstItemsSelectionAmount = ConstItemsSelectionAmount - IssuedAmountAfterRate;
						
						ItemsSelection.QuantityBase = ItemsSelection.QuantityBase - IssuedTurnoverQuantity;
						ItemsSelection.Amount = ItemsSelection.Amount - IssuedAmountAfterRate;
						
						IssuedItemTableRow.Quantity = IssuedItemTableRow.Quantity - IssuedTurnoverQuantity;
						IssuedItemTableRow.Amount   = IssuedItemTableRow.Amount - IssuedAmountAfterRateFull;
						
					EndDo;	
				EndIf;
				
				If ItemsSelection.QuantityBase <> 0 Then
					
					If IsArchiveDocument Then
						// other historical issue
						If PriceCorrection Then
							If ReturnTable <> Undefined Then
								Record = ReturnTable.Add();
								Record.Document       = Undefined;
								Record.Item           = ItemsSelection.Item;
								Record.Amount         = ItemsSelection.Amount;
								Record.Index          = ItemsSelection.Index;
								Record.CostCalculationMethod = Enums.CostCalculationMethod.EditIssuedCost;
								Record.Direction      = Catalogs.CostOfGoodsMovementsDirections.OtherHistoricalIssues;
							EndIf;	
						Else
							
							// RegisterRecords CostOfGoodsTurnovers
							Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
							
							Record.Period         = DocumentObject.Date;
							Record.ReceiptExpense = ReceiptExpense;
							Record.Company        = DocumentObject.Company;
							Record.Item           = ItemsSelection.Item;
							Record.Document       = Undefined;
							Record.TurnoverType   = TurnoverType;
							Record.Direction      = Catalogs.CostOfGoodsMovementsDirections.OtherHistoricalIssues;
							
							Record.Amount         = ItemsSelection.Amount;
							
						EndIf;
					Else
						Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Could not distribute %P1 cost for %P2 %P3 for item %P4!'; pl = 'Nie udało rozłożyć koszt %P1 dla %P2 %P3 pozycji %P4!'"),New Structure("P1, P2, P3, P4",ItemsSelection.Amount,ItemsSelection.QuantityBase,ItemsSelection.Item.BaseUnitOfMeasure,ItemsSelection.Item)),?(IsCostOfGoodsSequenceRestoring,Enums.AlertType.Error,Enums.AlertType.Warning),Cancel,DocumentObject);
					EndIf;
					
				EndIf;	
				
			EndIf;
			
			If NOT PriceCorrection Then
				CostOfGoodsToCostOfGoodsTurnovers.GroupBy("ParcelDocument","Amount");
				For Each CostOfGoodsToCostOfGoodsTurnoversRow In CostOfGoodsToCostOfGoodsTurnovers do
					// RegisterRecords CostOfGoodsTurnovers
					Record = DocumentObject.RegisterRecords.CostOfGoodsTurnovers.Add();
					
					Record.Period         = DocumentObject.Date;
					Record.ReceiptExpense = Enums.ReceiptExpense.Receipt;
					Record.Company        = DocumentObject.Company;
					Record.Item           = ItemsSelection.Item;
					Record.Document       = CostOfGoodsToCostOfGoodsTurnoversRow.ParcelDocument;
					Record.TurnoverType   = TurnoverType;
					Record.Direction      = Catalogs.CostOfGoodsMovementsDirections.PurchaseReceipt;
					Record.CostPerItem = 0;
					
					Record.Quantity       = 0;
					Record.Amount         = CostOfGoodsToCostOfGoodsTurnoversRow.Amount;
					
					If TypeOf(Record.Document) = TypeOf(Documents.PurchaseReceipt.EmptyRef()) Then
						Record.PurchaseReceipt = Record.Document;
					EndIf;	
				EndDo;
			EndIf;
			
		EndDo;
			
	EndIf;
	
	ReturnOnCostError(DocumentObject,Cancel,InitialCancel);
	
EndProcedure // PostingAdditionalCostOfGoods()
