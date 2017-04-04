
#Region Interface

Procedure OnDefiningRulesStructuralUnitsSettings(Rules) Export
	
	Rules[Type("DocumentObject.WorkOrder")]			= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.PurchaseOrder")]		= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.Payroll")]			= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.SalesTarget")]		= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.PayrollSheet")]		= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.OtherExpenses")]		= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.CostAllocation")]	= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.JobSheet")]			= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.Timesheet")]			= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.TimeTracking")]		= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.InventoryAssembly")]	= Catalogs.StructuralUnits.MainDepartment;
	Rules[Type("DocumentObject.ProductionOrder")]	= Catalogs.StructuralUnits.MainDepartment;
	
	Rules[Type("DocumentObject.AdditionalCosts")]			= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.InventoryReconciliation")]	= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.InventoryReceipt")]			= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.ProcessingReport")]			= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.SubcontractorReport")]		= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.TransferBetweenCells")]		= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.FixedAssetsEnter")]			= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.SupplierInvoice")]			= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.GoodsReceipt")]				= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.GoodsExpense")]				= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.CustomerInvoice")]			= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.InventoryWriteOff")]			= Catalogs.StructuralUnits.MainWarehouse;
	Rules[Type("DocumentObject.InventoryTransfer")]			= Catalogs.StructuralUnits.MainWarehouse;
	
EndProcedure

#EndRegion
