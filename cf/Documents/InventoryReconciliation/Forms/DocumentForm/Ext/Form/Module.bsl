
#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	SubsidiaryCompany = SmallBusinessServer.GetCompany(Object.Company);
	NationalCurrency = Constants.NationalCurrency.Get();
	
	SetCellVisible();
	
	// Setting the method of structural unit selection depending on FO.
	If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
		AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
		
	EndIf;
	
	ResetFilterSettings();
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

// Procedure - event handler BeforeWriteAtServer.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	FilterSettingsStructure = New Structure;
	FilterSettingsStructure.Insert("ProductsAndServicesList", ProductsAndServicesList);
	FilterSettingsStructure.Insert("ListProductsAndServicesGroups", ListProductsAndServicesGroups);
	FilterSettingsStructure.Insert("ProductsAndServicesGroupsList", ProductsAndServicesGroupsList);
	
	CurrentObject.SettingsOfFilters = New ValueStorage(FilterSettingsStructure);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	UpdateFilterHeaders();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals

EndProcedure // OnOpen()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			//Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		InventoryAddressInStorage = Parameter;
		
		GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
		
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		//Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf; 
	EndIf;
	
EndProcedure // NotificationProcessing()

#EndRegion

////////////////////////////////////////////////////////////////////////////////GENERAL
// PURPOSE PROCEDURES AND FUNCTIONS

// The function returns the query text for the balances at warehouse.
//
Function GenerateQueryTextByWarehouseBalances()
	
	QueryText =
	"SELECT
	|	FALSE AS FlagInCell,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting,
	|	SUM(InventoryBalances.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.AmountBalance) AS Amount
	|INTO InventoryBalanceReconciliation
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND ProductsAndServices IN (&ProductsAndServicesList)
	|				AND ProductsAndServices IN HIERARCHY (&ListProductsAndServicesGroups)
	|				AND ProductsAndServices.ProductsAndServicesCategory IN (&ProductsAndServicesGroupsList)) AS InventoryBalances
	|WHERE
	|	InventoryBalances.ProductsAndServices <> VALUE(Catalog.ProductsAndServices.EmptyRef)
	|
	|GROUP BY
	|	InventoryBalances.Batch,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.ProductsAndServices.MeasurementUnit";
	
	Return QueryText;
	
EndFunction // GenerateQueryTextByWarehouseBalances()

// The function returns the query text for the balances in a cell at the warehouse.
//
Function FormQueryTextOnBalancesInCellInWarehouse()
	
	QueryText =
	"SELECT
	|	TRUE AS FlagInCell,
	|	InventoryInWarehousesOfBalance.ProductsAndServices AS ProductsAndServices,
	|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.AmountBalance) AS Amount
	|INTO InventoryBalanceReconciliation
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Cell = &Cell
	|				AND ProductsAndServices IN (&ProductsAndServicesList)
	|				AND ProductsAndServices IN HIERARCHY (&ListProductsAndServicesGroups)
	|				AND ProductsAndServices.ProductsAndServicesCategory IN (&ProductsAndServicesGroupsList)) AS InventoryInWarehousesOfBalance
	|		LEFT JOIN AccumulationRegister.Inventory.Balance(
	|				&Period,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND ProductsAndServices IN (&ProductsAndServicesList)
	|					AND ProductsAndServices IN HIERARCHY (&ListProductsAndServicesGroups)
	|					AND ProductsAndServices.ProductsAndServicesCategory IN (&ProductsAndServicesGroupsList)) AS InventoryBalances
	|		ON InventoryInWarehousesOfBalance.ProductsAndServices = InventoryBalances.ProductsAndServices
	|			AND InventoryInWarehousesOfBalance.Characteristic = InventoryBalances.Characteristic
	|			AND InventoryInWarehousesOfBalance.Batch = InventoryBalances.Batch
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.Batch,
	|	InventoryInWarehousesOfBalance.ProductsAndServices,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit";
	
	Return QueryText;
	
EndFunction // FormQueryTextOnBalancesInCellInWarehouse()

// The function returns the query text by accounting data of the warehouse.
//
Function GenerateQueryTextAccountingDataAtWarehouse()
	
	QueryText =
	"SELECT
	|	FALSE AS FlagInCell,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting
	|INTO TemporaryTableInventoryBalances
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND (ProductsAndServices, Characteristic, Batch) In
	|					(SELECT
	|						InventoryReconciliation.ProductsAndServices AS ProductsAndServices,
	|						InventoryReconciliation.Characteristic AS Characteristic,
	|						InventoryReconciliation.Batch AS Batch
	|					FROM
	|						InventoryReconciliation AS InventoryReconciliation)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.ProductsAndServices.MeasurementUnit,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch";
	
	Return QueryText + Chars.LF +
		";
		|
		|////////////////////////////////////////////////////////////////////////////////"
		+ Chars.LF;
	
EndFunction // GenerateQueryTextAccountingDataAtWarehouse()

// The function returns the query text for the accounting data in a cells of the warehouse.
//
Function IssueQueryTextAccountsDataInCellInInventory()
	
	QueryText =
	"SELECT
	|	TRUE AS FlagInCell,
	|	InventoryInWarehousesOfBalance.ProductsAndServices AS ProductsAndServices,
	|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting
	|INTO TemporaryTableInventoryBalances
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Cell = &Cell
	|				AND (ProductsAndServices, Characteristic, Batch) In
	|					(SELECT
	|						InventoryReconciliation.ProductsAndServices AS ProductsAndServices,
	|						InventoryReconciliation.Characteristic AS Characteristic,
	|						InventoryReconciliation.Batch AS Batch
	|					FROM
	|						InventoryReconciliation AS InventoryReconciliation)) AS InventoryInWarehousesOfBalance
	|		LEFT JOIN AccumulationRegister.Inventory.Balance(
	|				&Period,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit) AS InventoryBalances
	|		ON InventoryInWarehousesOfBalance.ProductsAndServices = InventoryBalances.ProductsAndServices
	|			AND InventoryInWarehousesOfBalance.Characteristic = InventoryBalances.Characteristic
	|			AND InventoryInWarehousesOfBalance.Batch = InventoryBalances.Batch
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.ProductsAndServices,
	|	InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.Batch
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch";
	
	Return QueryText + Chars.LF +
		";
		|
		|////////////////////////////////////////////////////////////////////////////////"
		+ Chars.LF;
	
EndFunction // IssueQueryTextAccountsDataInCellInInventory()

// The procedure fills in the "Inventory" tabular section by
// balance
&AtServer
Procedure FillByBalanceAtWarehouse()
	
	Object.Inventory.Clear();
	Object.SerialNumbers.Clear();
	
	ThereIsFilterByProductsAndServices = ProductsAndServicesList.Count() > 0;
	ThereIsFilterByProductsAndServicesGroups = ListProductsAndServicesGroups.Count() > 0;
	ThereIsFilterByProductsAndServicesCategories = ProductsAndServicesGroupsList.Count() > 0;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If ValueIsFilled(Object.Cell) Then
		Query.Text = FormQueryTextOnBalancesInCellInWarehouse();
		Query.SetParameter("Cell", Object.Cell);
	Else
		Query.Text = GenerateQueryTextByWarehouseBalances();
	EndIf;
	
	Query.SetParameter("Period", EndOfDay(Object.Date));
	Query.SetParameter("Company", SubsidiaryCompany);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	
	If ThereIsFilterByProductsAndServices Then
		Query.SetParameter("ProductsAndServicesList", ProductsAndServicesList);
	Else
		Query.Text = StrReplace(Query.Text, "AND ProductsAndServices IN (&ProductsAndServicesList)", "");
	EndIf;
	
	If ThereIsFilterByProductsAndServicesGroups Then
		Query.SetParameter("ListProductsAndServicesGroups", ListProductsAndServicesGroups);
	Else
		Query.Text = StrReplace(Query.Text, "AND ProductsAndServices IN HIERARCHY (&ListProductsAndServicesGroups)", "");
	EndIf;
	
	If ThereIsFilterByProductsAndServicesCategories Then
		Query.SetParameter("ProductsAndServicesGroupsList", ProductsAndServicesGroupsList);
	Else
		Query.Text = StrReplace(Query.Text, "AND ProductsAndServices.ProductsAndServicesCategory IN (&ProductsAndServicesGroupsList)", "");
	EndIf;
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN CtlProductsAndServices.Parent = VALUE(Catalog.ProductsAndServices.EmptyRef)
	|				AND Not CtlProductsAndServices.IsFolder
	|			THEN 0
	|		ELSE 1
	|	END AS Order,
	|	CtlProductsAndServices.Description AS Description,
	|	InventoryBalanceReconciliation.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalanceReconciliation.MeasurementUnit AS MeasurementUnit,
	|	InventoryBalanceReconciliation.Characteristic AS Characteristic,
	|	InventoryBalanceReconciliation.Batch AS Batch,
	|	ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0) AS QuantityAccounting,
	|	ISNULL(InventoryBalanceReconciliation.AmountAccounting, 0) AS AmountAccounting,
	|	CASE
	|		WHEN ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0) <= 0
	|				OR ISNULL(InventoryBalanceReconciliation.Amount, 0) = 0
	|			THEN 0
	|		ELSE ISNULL(InventoryBalanceReconciliation.Amount, 0) / ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0)
	|	END AS PriceAccount,
	|	ISNULL(InventoryBalanceReconciliation.Quantity, 0) AS Quantity,
	|	ISNULL(InventoryBalanceReconciliation.Amount, 0) AS Amount,
	|	CASE
	|		WHEN InventoryBalanceReconciliation.FlagInCell
	|			THEN CASE
	|					WHEN ISNULL(InventoryBalanceReconciliation.Quantity, 0) < 0
	|						THEN -ISNULL(InventoryBalanceReconciliation.Quantity, 0)
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0) < 0
	|					THEN -ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0)
	|				ELSE 0
	|			END
	|	END AS Deviation
	|FROM
	|	Catalog.ProductsAndServices AS CtlProductsAndServices
	|		LEFT JOIN InventoryBalanceReconciliation AS InventoryBalanceReconciliation
	|		ON CtlProductsAndServices.Ref = InventoryBalanceReconciliation.ProductsAndServices
	|WHERE
	|	CtlProductsAndServices.Ref IN (&ProductsAndServicesList)
	|	AND CtlProductsAndServices.Ref IN HIERARCHY(&ListProductsAndServicesGroups)
	|	AND CtlProductsAndServices.ProductsAndServicesCategory IN(&ProductsAndServicesGroupsList)
	|
	|ORDER BY
	|	Order DESC,
	|	Description HIERARCHY";
	
	If ThereIsFilterByProductsAndServices Then
		Query.SetParameter("ProductsAndServicesList", ProductsAndServicesList);
	Else
		Query.Text = StrReplace(Query.Text, "CtlProductsAndServices.Ref IN (&ProductsAndServicesList)", "TRUE");
	EndIf;
	
	If ThereIsFilterByProductsAndServicesGroups Then
		Query.SetParameter("ListProductsAndServicesGroups", ListProductsAndServicesGroups);
	Else
		Query.Text = StrReplace(Query.Text, "AND CtlProductsAndServices.Ref IN HIERARCHY(&ListProductsAndServicesGroups)", "");
	EndIf;
	
	If ThereIsFilterByProductsAndServicesCategories Then
		Query.SetParameter("ProductsAndServicesGroupsList", ProductsAndServicesGroupsList);
	Else
		Query.Text = StrReplace(Query.Text, "AND CtlProductsAndServices.ProductsAndServicesCategory IN(&ProductsAndServicesGroupsList)", "");
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Not ValueIsFilled(Selection.ProductsAndServices) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(Object.Cell)
			AND Selection.Quantity <> Selection.QuantityAccounting
			AND Selection.Quantity <> 0 Then
			
			NewRow = Object.Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			NewRow.QuantityAccounting = Selection.Quantity;
			
			If Selection.PriceAccount = 0 Then
				NewRow.Price = 0;
				NewRow.Amount = 0;
			Else
				NewRow.Price = ?(Selection.PriceAccount < 0, Selection.PriceAccount * (-1), Selection.PriceAccount);
				NewRow.Amount = NewRow.Price * NewRow.Quantity;
			EndIf;
			
			NewRow.AmountAccounting = NewRow.Amount;
			
		ElsIf Selection.QuantityAccounting <> 0 Then
			
			NewRow = Object.Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			If Selection.PriceAccount = 0 Then
				NewRow.Amount = 0;
			Else
				NewRow.Price = ?(Selection.PriceAccount < 0, Selection.PriceAccount * (-1), Selection.PriceAccount);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillByBalanceAtWarehouse()

// The procedure fills in the Inventory tabular section by accounting data.
// 
&AtServer
Procedure FillOnlyAccountingData()
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableCosts.ProductsAndServices AS ProductsAndServices,
	|	TableCosts.Characteristic AS Characteristic,
	|	TableCosts.Batch AS Batch,
	|	TableCosts.MeasurementUnit AS MeasurementUnit,
	|	TableCosts.Quantity AS Quantity,
	|	TableCosts.Price AS Price,
	|	TableCosts.Amount AS Amount
	|INTO InventoryReconciliation
	|FROM
	|	&TableCosts AS TableCosts";
	
	Query.SetParameter("TableCosts", Object.Inventory.Unload());
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If ValueIsFilled(Object.Cell) Then
		QueryText = IssueQueryTextAccountsDataInCellInInventory();
		Query.SetParameter("Cell", Object.Cell);
	Else
		QueryText = GenerateQueryTextAccountingDataAtWarehouse();
	EndIf;
	
	Query.Text = QueryText +
	"SELECT
	|	InventoryReconciliationInventory.ProductsAndServices AS ProductsAndServices,
	|	InventoryReconciliationInventory.Characteristic AS Characteristic,
	|	InventoryReconciliationInventory.Batch AS Batch,
	|	InventoryReconciliationInventory.MeasurementUnit AS MeasurementUnit,
	|	InventoryReconciliationInventory.Quantity AS Quantity,
	|	InventoryReconciliationInventory.Price AS Price,
	|	InventoryReconciliationInventory.Amount AS Amount,
	|	ISNULL(TTInventoryRemains.Quantity, 0) / ISNULL(InventoryReconciliationInventory.MeasurementUnit.Factor, 1) AS QuantityInCell,
	|	ISNULL(TTInventoryRemains.QuantityAccounting, 0) / ISNULL(InventoryReconciliationInventory.MeasurementUnit.Factor, 1) AS QuantityAccounting,
	|	ISNULL(TTInventoryRemains.AmountAccounting, 0) AS AmountAccounting,
	|	CASE
	|		WHEN TTInventoryRemains.FlagInCell
	|			THEN InventoryReconciliationInventory.Quantity - ISNULL(TTInventoryRemains.Quantity, 0) / ISNULL(InventoryReconciliationInventory.MeasurementUnit.Factor, 1)
	|		ELSE InventoryReconciliationInventory.Quantity - ISNULL(TTInventoryRemains.QuantityAccounting, 0) / ISNULL(InventoryReconciliationInventory.MeasurementUnit.Factor, 1)
	|	END AS Deviation
	|FROM
	|	InventoryReconciliation AS InventoryReconciliationInventory
	|		LEFT JOIN TemporaryTableInventoryBalances AS TTInventoryRemains
	|		ON InventoryReconciliationInventory.ProductsAndServices = TTInventoryRemains.ProductsAndServices
	|			AND InventoryReconciliationInventory.Characteristic = TTInventoryRemains.Characteristic
	|			AND InventoryReconciliationInventory.Batch = TTInventoryRemains.Batch";
	
	Query.SetParameter("Company", SubsidiaryCompany);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	Query.SetParameter("Period", EndOfDay(Object.Date));
	Query.SetParameter("Ref", Object.Ref);
	
	ResultsArray = Query.ExecuteBatch();
	
	If ValueIsFilled(Object.Cell) Then
		
		Object.Inventory.Clear();
		Object.SerialNumbers.Clear();
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			NewRow = Object.Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			If Selection.QuantityInCell <> Selection.QuantityAccounting Then
				
				NewRow.QuantityAccounting = Selection.QuantityInCell;
				If Selection.QuantityInCell = 0
					OR Selection.QuantityAccounting <= 0
					OR Selection.AmountAccounting = 0 Then
					NewRow.AmountAccounting = 0;
				Else
					NewRow.AmountAccounting = Selection.AmountAccounting / Selection.QuantityAccounting * NewRow.QuantityAccounting;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	Else
		
		Object.Inventory.Load(ResultsArray[1].Unload());
		
	EndIf;
	
EndProcedure // FillOnlyAccountingData()

// It receives data set from server for the DateOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("SubsidiaryCompany", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()	

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataMeasurementUnitOnChange()	

// Sets the cell visible.
//
&AtServer
Procedure SetCellVisible()
	
	If Not ValueIsFilled(Object.StructuralUnit) 
		OR Object.StructuralUnit.OrderWarehouse
		OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail Then
		Items.Cell.Enabled = False;
	Else
		Items.Cell.Enabled = True;
	EndIf;
	
EndProcedure // SetCellVisible()	

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		InformationRegisters.ProductsAndServicesBarcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsAndServicesData = New Structure();
			StructureProductsAndServicesData.Insert("ProductsAndServices", BarcodeData.ProductsAndServices);
			BarcodeData.Insert("StructureProductsAndServicesData", GetDataProductsAndServicesOnChange(StructureProductsAndServicesData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,Batch,MeasurementUnit",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				Items.Inventory.CurrentRow = NewRow.GetID();
				
				// Rejection calculation.
				NewRow.Deviation = NewRow.Quantity - NewRow.QuantityAccounting;
				
			Else
				
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				Items.Inventory.CurrentRow = NewRow.GetID();
				
				// Rejection calculation.
				NewRow.Deviation = NewRow.Quantity - NewRow.QuantityAccounting;
				
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
			
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction // FillByBarcodesData()

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.ProductsAndServicesBarcodes.Form.ProductsAndServicesBarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure // BarcodesAreReceived()

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement IN ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement IN ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode IN UnknownBarcodes Do
		
		MessageString = NStr("en='Barcode data is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

// Recalculates prices of the document tabular section.
//
&AtClient
Procedure RefillTabularSectionPricesByPriceKind(PriceKind)
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;
	
	DataStructure.Insert("Date", Object.Date);
	DataStructure.Insert("Company", SubsidiaryCompany);
	DataStructure.Insert("PriceKind", PriceKind);
	DataStructure.Insert("DocumentCurrency", NationalCurrency);
	
	For Each TSRow IN Object.Inventory Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.ProductsAndServices) Then
			Continue;
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		TabularSectionRow.Insert("Characteristic", TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price", 0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
	
	SmallBusinessServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	For Each TSRow IN DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		
		SearchResult = Object.Inventory.FindRows(SearchStructure);
		
		For Each ResultRow IN SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			ResultRow.Amount = ResultRow.Quantity * ResultRow.Price;
			
		EndDo;
		
	EndDo;
	
EndProcedure // RefillTabularSectionPricesByPriceKind()

&AtClient
Function GenerateFilterHeaderFromList(ItemList)
	
	FilterHeaderString = "";
	For Each ItemOfList IN ItemList Do
		
		FilterHeaderString = FilterHeaderString + ?(FilterHeaderString = "","","; ") + ItemOfList.Presentation;
		
	EndDo;
	
	If FilterHeaderString = "" Then
		FilterHeaderString = NStr("en='Filter not set';ru='Отбор не установлен'");
	EndIf;
	
	Return FilterHeaderString;
	
EndFunction // GenerateFilterHeaderFromList()

// It updates the headers of the filters for inventory count conditions.
//
&AtClient
Procedure UpdateFilterHeaders()

	ListTitle = GenerateFilterHeaderFromList(ProductsAndServicesList);
	Items.SetFilterByProductsAndServices.Title = ListTitle;
	
	ListTitle = GenerateFilterHeaderFromList(ListProductsAndServicesGroups);
	Items.SetFilterByProductsAndServicesGroups.Title = ListTitle;
	
	ListTitle = GenerateFilterHeaderFromList(ProductsAndServicesGroupsList);
	Items.SetFilterByProductsAndServicesCategories.Title = ListTitle;

EndProcedure // UpdateFilterHeaders()

// Restores the settings of filters of reconciliation conditions.
//
&AtServer
Procedure ResetFilterSettings()

	FilterSettingsStructure = FormAttributeToValue("Object").SettingsOfFilters.Get();
	If TypeOf(FilterSettingsStructure) = Type("Structure") Then
		FilterSettingsStructure.Property("ProductsAndServicesList", ProductsAndServicesList);
		FilterSettingsStructure.Property("ListProductsAndServicesGroups", ListProductsAndServicesGroups);
		FilterSettingsStructure.Property("ProductsAndServicesGroupsList", ProductsAndServicesGroupsList);
	EndIf;

EndProcedure // ResetFilterSettings()

&AtClient
Procedure ClearFilterConditionByProductsAndServices()

	ProductsAndServicesList.Clear();
	Items.SetFilterByProductsAndServices.Title = NStr("en='Filter not set';ru='Отбор не установлен'");

EndProcedure // ClearFilterConditionByProductsAndServices()

&AtClient
Procedure ClearFilterCriteriaByProductAndServicesGroups()

	ListProductsAndServicesGroups.Clear();
	Items.SetFilterByProductsAndServicesGroups.Title = NStr("en='Filter not set';ru='Отбор не установлен'");

EndProcedure // ClearFilterCriteriaByProductsAndServicesGroups()

&AtClient
Procedure ClearFilterCriteriaByProductsAndServicesCategories()

	ProductsAndServicesGroupsList.Clear();
	Items.SetFilterByProductsAndServicesCategories.Title = NStr("en='Filter not set';ru='Отбор не установлен'");

EndProcedure // ClearFilterCriteriaByProductsAndServicesCategories()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName 	= "Inventory";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			SubsidiaryCompany);
	
	SelectionParameters.Insert("StructuralUnit", 	Object.StructuralUnit);
	
	ProductsAndServicesType = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "ProductsAndServices"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.ProductsAndServicesType" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					ProductsAndServicesType.Add(FixArrayItem);
				EndDo; 
			Else
				ProductsAndServicesType.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	SelectionParameters.Insert("ProductsAndServicesType", ProductsAndServicesType);
		
	BatchStatus = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo; 
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExecutePick()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		// Rejection calculation.
		NewRow.Deviation = NewRow.Quantity - NewRow.QuantityAccounting;
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en='Enter barcode';ru='Введите штрихкод'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
    EndIf;

EndProcedure // SearchByBarcode()

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='Select a line for which the weight should be received.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NOTifyDescription, UUID);
		
	EndIf;
	
EndProcedure // GetWeight()

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en='Electronic scales returned zero weight.';ru='Электронные весы вернули нулевой вес.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
			
			// Rejection calculation.
			TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

////////////////////////////////////////////////////////////////////////////////PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the
// date of a document this document is found in
// another period of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	SubsidiaryCompany = StructureData.SubsidiaryCompany;
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	SetCellVisible();
	
EndProcedure // StructuralUnitOnChange()

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // StructuralUnitOpening()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

// Procedure - FillInByBalanceOnWarehouse button clicking handler.
// 
&AtClient
Procedure CommandFillByBalanceAtWarehouse()

	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillCommandByBalanceOnWarehouseEnd", ThisObject), NStr("en='Tabular section will be cleared. Continue?';ru='Табличная часть будет очищена! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;

	FillCommandByBalanceOnWarehouseFragment();
EndProcedure

&AtClient
Procedure FillCommandByBalanceOnWarehouseEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillCommandByBalanceOnWarehouseFragment();

EndProcedure

&AtClient
Procedure FillCommandByBalanceOnWarehouseFragment()
    
    FillByBalanceAtWarehouse();

EndProcedure // FillByBalanceAtWarehouse()

// Procedure - FillOnlyAccountingData click handler.
// 
&AtClient
Procedure CommandFillOnlyAccountingData()
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CommandFillOnlyAccountingDataEnd", ThisObject), NStr("en='Accounting data will be cleared. Continue?';ru='Учетные данные будут очищены! Продолжить?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	Else
		Return;
	EndIf;
	
	CommandFillOnlyAccountingDataFragment();
EndProcedure

&AtClient
Procedure CommandFillOnlyAccountingDataEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    CommandFillOnlyAccountingDataFragment();

EndProcedure

&AtClient
Procedure CommandFillOnlyAccountingDataFragment()
    
    FillOnlyAccountingData();

EndProcedure // FillOnlyAccountingData()

// Procedure - FillByPriceKind click handler.
// 
&AtClient
Procedure CommandFillByPriceKind(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("CommandFillByPriceKindEnd1", ThisObject), NStr("en='Prices will be refilled. Continue?';ru='Цены будут перезаполнены! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure CommandFillByPriceKindEnd1(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf;
    
    PriceKind = Undefined;
    
    
    OpenForm("Catalog.PriceKinds.Form.ChoiceForm",,,,,, New NotifyDescription("CommandFillByPriceKindEnd", ThisObject));

EndProcedure

&AtClient
Procedure CommandFillByPriceKindEnd(Result, AdditionalParameters) Export
    
    PriceKind = Result;
    
    If TypeOf(PriceKind) = Type("CatalogRef.PriceKinds") Then
        RefillTabularSectionPricesByPriceKind(PriceKind);
    EndIf;

EndProcedure // CommandFillByPriceKind()

// Procedure - CommandZeroOutQuantityAndAmount click handler.
// 
&AtClient
Procedure CommandZeroQuantityAndTheAmount(Command)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CommandZeroOutQuantityAndAmountEnd", ThisObject), NStr("en='The ""Quantity"" and ""Amount"" columns will be cleared. Continue?';ru='Колонки ""Количество"" и ""Сумма"" будут очищены! Продолжить?'"), QuestionDialogMode.YesNo, 0);
        Return;
	Else
		Return;
	EndIf;
	
	CommandZeroOutQuantityAndAmountFragment();
EndProcedure

&AtClient
Procedure CommandZeroOutQuantityAndAmountEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf;
    
    CommandZeroOutQuantityAndAmountFragment();

EndProcedure

&AtClient
Procedure CommandZeroOutQuantityAndAmountFragment()
    
    Var TabularSectionRow;
    
    For Each TabularSectionRow IN Object.Inventory Do
        
        TabularSectionRow.Quantity = 0;
        TabularSectionRow.Amount 		= 0;
        TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
        
    EndDo;
    
    Modified = True;

EndProcedure // CommandZeroOutQuantityAndAmount()

&AtClient
Procedure ClearFilterByProductsAndServicesClick(Item)
	
	ClearFilterConditionByProductsAndServices();
	
EndProcedure

&AtClient
Procedure ClearFilterByProductsAndServicesGroupsClick(Item)
	
	ClearFilterCriteriaByProductAndServicesGroups();
	
EndProcedure

&AtClient
Procedure ClearFilterByProductsAndServicesCategoriesClick(Item)
	
	ClearFilterCriteriaByProductsAndServicesCategories();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	TabularSectionRow.QuantityAccounting = 0;
	TabularSectionRow.AmountAccounting = 0;
	
	// Rejection calculation.
	TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
	
	//Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 AND StructureData.Factor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
		TabularSectionRow.Quantity = TabularSectionRow.Quantity * StructureData.CurrentFactor / StructureData.Factor;
		TabularSectionRow.QuantityAccounting = TabularSectionRow.QuantityAccounting * StructureData.CurrentFactor / StructureData.Factor;
	EndIf;
	
	// Rejection calculation.
	TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - OnChange event handler
// of the Quantity input field in the Inventory tabular section line.
// Recalculates the amount in the tabular section line.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // GoodsUnitNumberOnChange()

// Procedure - OnChange event handler of the
// Price input field in the Inventory tabular section line.
// Recalculates the amounts in the tabular section line.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

// Procedure - OnChange event handler of the
// Amount input field in the Inventory tabular section line.
// Recalculates prices in the tabular section line.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	StringPrice = ?(TabularSectionRow.Quantity = 0, 0, TabularSectionRow.Amount / TabularSectionRow.Quantity);
	
	TabularSectionRow.Price = ?(StringPrice < 0, -1 * StringPrice, StringPrice);
	
EndProcedure // InventoryAmountOnChange()

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSerialNumbersSelection();
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;

	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure SetFilterByProductsAndServices(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterKind", "FilterByProductsAndServices");
	FormParameters.Insert("ListValueSelection", ProductsAndServicesList);
	
	Notification = New NotifyDescription("SetFilterEnd",ThisForm);
	OpenForm("Document.InventoryReconciliation.Form.ChoiceFormValuesSelection", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure SetFilterByProductsAndServicesGroups(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterKind", "FilterByProductsAndServicesGroups");
	FormParameters.Insert("ListValueSelection", ListProductsAndServicesGroups);
	
	Notification = New NotifyDescription("SetFilterEnd",ThisForm);
	OpenForm("Document.InventoryReconciliation.Form.ChoiceFormValuesSelection", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure SetFilterByProductsAndServicesCategories(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterKind", "FilterByProductsAndServicesCategories");
	FormParameters.Insert("ListValueSelection", ProductsAndServicesGroupsList);
	
	Notification = New NotifyDescription("SetFilterEnd",ThisForm);
	OpenForm("Document.InventoryReconciliation.Form.ChoiceFormValuesSelection", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure SetFilterEnd(Result,Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		ListValueSelection = GetFromTempStorage(Result.SelectionValueListAddress);
		ListTitle = GenerateFilterHeaderFromList(ListValueSelection);
		
		FilterKind = Result.FilterKind;
		If FilterKind = "FilterByProductsAndServices" Then
			ProductsAndServicesList = ListValueSelection;
			Items.SetFilterByProductsAndServices.Title = ListTitle;
		ElsIf FilterKind = "FilterByProductsAndServicesGroups" Then
			ListProductsAndServicesGroups = ListValueSelection;
			Items.SetFilterByProductsAndServicesGroups.Title = ListTitle;
		Else
			ProductsAndServicesGroupsList = ListValueSelection;
			Items.SetFilterByProductsAndServicesCategories.Title = ListTitle;
		EndIf;
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// Deviation calculation.
	TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

#EndRegion