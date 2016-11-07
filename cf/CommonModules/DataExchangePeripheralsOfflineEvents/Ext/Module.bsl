Procedure RegisterCatalogChanges(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	SourceType = TypeOf(Source);
	If SourceType = Type("CatalogObject.ProductsAndServices") Then
		
		Query = New Query(
		"SELECT
		|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule,
		|	ProductsCodesPeripheralOffline.Code AS Code,
		|	Peripherals.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
		|		LEFT JOIN Catalog.Peripherals AS Peripherals
		|		ON ProductsCodesPeripheralOffline.ExchangeRule = Peripherals.ExchangeRule
		|WHERE
		|	ProductsCodesPeripheralOffline.Used
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)
		|	AND ProductsCodesPeripheralOffline.ProductsAndServices = &Value
		|	AND (ProductsCodesPeripheralOffline.ProductsAndServices.Description <> &ValueName
		|	OR CAST(ProductsCodesPeripheralOffline.ProductsAndServices.DescriptionFull AS String(1024)) <> CAST(&DescriptionFullValue AS String(1024)))");
		
		Query.SetParameter("DescriptionFullValue", Source.DescriptionFull);
		
	ElsIf SourceType = Type("CatalogObject.ProductsAndServicesCharacteristics") Then
		
		Query = New Query(
		"SELECT
		|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule,
		|	ProductsCodesPeripheralOffline.Code AS Code,
		|	Peripherals.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
		|		LEFT JOIN Catalog.Peripherals AS Peripherals
		|		ON ProductsCodesPeripheralOffline.ExchangeRule = Peripherals.ExchangeRule
		|WHERE
		|	ProductsCodesPeripheralOffline.Used
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)
		|	AND ProductsCodesPeripheralOffline.Characteristic = &Value
		|	AND ProductsCodesPeripheralOffline.Characteristic.Description <> &ValueName");
		
	ElsIf SourceType = Type("CatalogObject.ProductsAndServicesBatches") Then
		
		Query = New Query(
		"SELECT
		|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule,
		|	ProductsCodesPeripheralOffline.Code AS Code,
		|	Peripherals.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
		|		LEFT JOIN Catalog.Peripherals AS Peripherals
		|		ON ProductsCodesPeripheralOffline.ExchangeRule = Peripherals.ExchangeRule
		|WHERE
		|	ProductsCodesPeripheralOffline.Used
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)
		|	AND ProductsCodesPeripheralOffline.Batch = &Value
		|	AND ProductsCodesPeripheralOffline.Batch.Description <> &ValueName");
		
	ElsIf SourceType = Type("CatalogObject.UOM") Then
		
		Query = New Query(
		"SELECT
		|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule,
		|	ProductsCodesPeripheralOffline.Code AS Code,
		|	Peripherals.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
		|		LEFT JOIN Catalog.Peripherals AS Peripherals
		|		ON ProductsCodesPeripheralOffline.ExchangeRule = Peripherals.ExchangeRule
		|WHERE
		|	ProductsCodesPeripheralOffline.Used
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)
		|	AND ProductsCodesPeripheralOffline.MeasurementUnit = &Value
		|	AND ProductsCodesPeripheralOffline.MeasurementUnit.Description <> &ValueName");
	
	ElsIf SourceType = Type("CatalogObject.ProductsAndServicesCategories") Then
		
		Query = New Query(
		"SELECT
		|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule,
		|	ProductsCodesPeripheralOffline.Code AS Code,
		|	Peripherals.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
		|		LEFT JOIN Catalog.Peripherals AS Peripherals
		|		ON ProductsCodesPeripheralOffline.ExchangeRule = Peripherals.ExchangeRule
		|WHERE
		|	ProductsCodesPeripheralOffline.Used
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)
		|	AND ProductsCodesPeripheralOffline.ProductsAndServices.ProductsAndServicesCategory = &Value");
		
	ElsIf SourceType = Type("CatalogObject.Peripherals") Then
		
		If  ValueIsFilled(Source.InfobaseNode)
			AND ValueIsFilled(Source.ExchangeRule)
			AND Source.ExchangeRule <> Source.Ref.ExchangeRule
			AND (Source.EquipmentType = Enums.PeripheralTypes.CashRegistersOffline
			   OR Source.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales) Then
			
			ExchangePlans.DeleteChangeRecords(Source.InfobaseNode);
			
			Query = New Query(
			"SELECT
			|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule,
			|	ProductsCodesPeripheralOffline.Code           AS Code,
			|	&InfobaseNode                                   AS InfobaseNode
			|FROM
			|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
			|WHERE
			|	ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule");
			
			Query.SetParameter("ExchangeRule", Source.ExchangeRule);
			Query.SetParameter("InfobaseNode", Source.InfobaseNode);
			
		Else
			Return;
		EndIf;
		
	Else
		Return;
	EndIf;
	
	Query.SetParameter("Value",             Source.Ref);
	Query.SetParameter("ValueName", Source.Description);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
	While Selection.Next() Do
		
		Set.Filter.ExchangeRule.Value = Selection.ExchangeRule;
		Set.Filter.ExchangeRule.Use = True;
		
		Set.Filter.Code.Value = Selection.Code;
		Set.Filter.Code.Use = True;
		
		ExchangePlans.RecordChanges(Selection.InfobaseNode, Set);
	
	EndDo;
	
EndProcedure

Procedure RegisterInformationRegisterChanges(Source, Cancel, Replacing) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	SourceType = TypeOf(Source);
	If SourceType = Type("InformationRegisterRecordSet.ProductsAndServicesBarcodes") Then
		
		Query = New Query(
		"SELECT
		|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule,
		|	ProductsCodesPeripheralOffline.Code AS Code,
		|	Peripherals.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
		|		LEFT JOIN Catalog.Peripherals AS Peripherals
		|		ON ProductsCodesPeripheralOffline.ExchangeRule = Peripherals.ExchangeRule
		|		LEFT JOIN InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
		|		ON ProductsCodesPeripheralOffline.ProductsAndServices = ProductsAndServicesBarcodes.ProductsAndServices
		|			AND ProductsCodesPeripheralOffline.Characteristic = ProductsAndServicesBarcodes.Characteristic
		|			AND ProductsCodesPeripheralOffline.Batch = ProductsAndServicesBarcodes.Batch
		|			AND ProductsCodesPeripheralOffline.MeasurementUnit = ProductsAndServicesBarcodes.MeasurementUnit
		|WHERE
		|	ProductsCodesPeripheralOffline.Used
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)
		|	AND ProductsAndServicesBarcodes.Barcode = &Value");
		
		Query.SetParameter("Value", Source.Filter.Barcode.Value);
		
	Else
		Return;
	EndIf;
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
	While Selection.Next() Do
		
		Set.Filter.ExchangeRule.Value = Selection.ExchangeRule;
		Set.Filter.ExchangeRule.Use = True;
		
		Set.Filter.Code.Value = Selection.Code;
		Set.Filter.Code.Use = True;
		
		ExchangePlans.RecordChanges(Selection.InfobaseNode, Set);
	
	EndDo;
	
EndProcedure

Procedure CreateExchangeNodeWithOfflinePeripherals(Source, Cancel) Export
	
	If Not ValueIsFilled(Source.InfobaseNode)
		AND (Source.EquipmentType = Enums.PeripheralTypes.CashRegistersOffline
		OR Source.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales) Then
		Source.InfobaseNode = EquipmentManagerServerCallOverridable.GetDIBNode(Source);
	EndIf;
	
	Source.AdditionalProperties.Insert("ChangedExchangeRule", Source.ExchangeRule <> Source.Ref.ExchangeRule);
	
EndProcedure

Procedure ClearExchangeNodeWithOfflinePeripherals(Source, CopiedObject) Export
	
	Source.InfobaseNode = ExchangePlans.ExchangeWithPeripheralsOffline.EmptyRef();
	
EndProcedure

Procedure RegisterChangesOnPeripheralsExchangeRuleChange(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If (Source.EquipmentType = Enums.PeripheralTypes.CashRegistersOffline
		OR Source.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales)
		AND Source.AdditionalProperties.ChangedExchangeRule Then
		
		SetPrivilegedMode(True);
		ExchangePlans.RecordChanges(Source.InfobaseNode, Metadata.InformationRegisters.ProductsCodesPeripheralOffline);
		
	EndIf;
	
EndProcedure



