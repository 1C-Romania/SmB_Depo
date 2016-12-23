
&AtClient
Var RefreshInterface;

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonUseClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure // VisibleManagement()

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData() Then
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogStructuralUnitsWarehouses", "Enabled", ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UsePurchaseOrderStates" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingPurchaseOrderStatesDefault","Enabled", Not ConstantsSet.UsePurchaseOrderStates);
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogCustomerOrderStates",			"Enabled", ConstantsSet.UsePurchaseOrderStates);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionUseBatches" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingsReceptionProductsForSafeCustody", "Enabled", ConstantsSet.FunctionalOptionUseBatches);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure("Value", ConstantValue), ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UsePurchaseOrderStates" Then
		
		ThisForm.ConstantsSet.UsePurchaseOrderStates = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.PurchaseOrdersInProgressStatus" Then
		
		ThisForm.ConstantsSet.PurchaseOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.PurchaseOrdersCompletedStatus" Then
		
		ThisForm.ConstantsSet.PurchaseOrdersCompletedStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses" Then
		
		ThisForm.ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionAccountingInVariousUOM" Then
		
		ThisForm.ConstantsSet.FunctionalOptionAccountingInVariousUOM = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionTransferInventoryOnSafeCustody" Then
		
		ThisForm.ConstantsSet.FunctionalOptionTransferInventoryOnSafeCustody = CurrentValue;
		
	ElsIf  AttributePathToData = "ConstantsSet.FunctionalOptionTakingInventoryOnResponsibleStorage" Then
		
		ThisForm.ConstantsSet.FunctionalOptionTakingInventoryOnResponsibleStorage = CurrentValue;
		
	ElsIf  AttributePathToData = "ConstantsSet.FunctionalOptionUseOrderWarehouse" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseOrderWarehouse = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseOrderWarehouse" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseOrderWarehouse = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionInventoryReservation" Then
		
		ThisForm.ConstantsSet.FunctionalOptionInventoryReservation = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByCells" Then
		
		ThisForm.ConstantsSet.FunctionalOptionAccountingByCells = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseCharacteristics" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseCharacteristics = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseBatches" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseBatches = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionTransferRawMaterialsForProcessing" Then
		
		ThisForm.ConstantsSet.FunctionalOptionTransferRawMaterialsForProcessing = CurrentValue;
		
	EndIf;
	
EndProcedure // ReturnFormAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Checks whether it is possible to clear the UsePurchaseOrderStates option.
//
&AtServer
Function CancellationUncheckUsePurchaseOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	PurchaseOrder.Ref
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	(PurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR PurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT PurchaseOrder.Closed))";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en='There are Purchase order documents with the Open and/or Executed (not closed) status in the base!
		|Disabling the option is prohibited!
		|Note:
		|If there are documents in the state with
		|the status ""Open"", set them to state with the status ""In progress""
		|or ""Executed (closed)"" If there are documents in the state
		|with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".';ru='В базе есть документы ""Заказ поставщику"" в состоянии со статусом ""Открыт"" и/или ""Выполнен (не закрыт)""!
		|Снятие опции запрещено!
		|Примечание:
		|Если есть документы в
		|состоянии со статусом ""Открыт"", то установите для них состояние со
		|статусом ""В работе"" или ""Выполнен (закрыт)"" Если есть документы
		|в состоянии со статусом ""Выполнен (не закрыт)"", то установите для них состояние со статусом ""Выполнен (закрыт)"".'"
		);
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckUsePurchaseOrderStates()

// Checks whether it is possible to clear the AccountingBySeveralWarehouses option.
//
&AtServer
Function CancellationUncheckAccountingBySeveralWarehouses()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	StructuralUnits.Ref
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.StructuralUnitType = &StructuralUnitType
		|	AND StructuralUnits.Ref <> &MainWarehouse"
	);
	
	Query.SetParameter("StructuralUnitType", Enums.StructuralUnitsTypes.Warehouse);
	Query.SetParameter("MainWarehouse", Catalogs.StructuralUnits.MainWarehouse);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='Wharehouses different from the main warehouse are used in data base! Disabling the option is prohibited!';ru='В базе используются склады, отличные от основного! Снятие опции запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction  // CancellationUncheckAccountingBySeveralWarehouses()

//Checks whether it is possible to clear AccountingInVariousUOMs option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingInVariousUOM()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	Cancel = False;
	
	SelectionOfUOM = Catalogs.UOM.Select();
	While SelectionOfUOM.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionOfUOM.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en='Documents with users MOUs are entered in the application! Disabling the option is prohibited!';ru='В приложении введены документы в пользовательских единицах измерения! Снятие опции запрещено!'");
			Break;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionAccountingInVariousUOM()

// Checks whether it is possible to clear the TransferInventoryOnSafeCustody option.
//
&AtServer
Function CancellationUncheckFunctionalOptionTransferInventoryOnSafeCustody()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryTransferred.Company
		|FROM
		|	AccumulationRegister.InventoryTransferred AS InventoryTransferred
		|WHERE
		|	InventoryTransferred.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='Accumulation register ""Inventory transferred"" contains information about the transfer to safe custody. The flag removal is prohibited!';ru='Регистр накопления ""Запасы переданные"" содержит информацию о передаче на ответхранение! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionTransferInventoryOnSafeCustody()

// Checks whether it is possible to clear the ReceiveInventoryOnSafeCustody option.
//
&AtServer
Function CancellationUncheckFunctionalOptionTakingInventoryOnResponsibleStorage()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryReceived.Company
		|FROM
		|	AccumulationRegister.InventoryReceived AS InventoryReceived
		|WHERE
		|	InventoryReceived.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.SafeCustody)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='The Inventory received accumulation register contains information on the safe custody acceptance. The flag removal is prohibited!';ru='Регистр накопления ""Запасы принятые"" содержит информацию о приеме на ответхранение! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionTakingInventoryOnResponsibleStorage()

// Checks whether it is possible to clear the UseOrderWarehouse option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseOrderWarehouse()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	StructuralUnits.Ref
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.OrderWarehouse"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='There are order warehouses in the base! The flag removal is prohibited!';ru='В базе присутствуют ордерные склады! Снятие флага запрещено!'");
		
	EndIf;
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryForWarehouses.Company
		|FROM
		|	AccumulationRegister.InventoryForWarehouses AS InventoryForWarehouses"
	);
	
	QueryResultInventoryForWarehouses = Query.Execute();
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryFromWarehouses.Company
		|FROM
		|	AccumulationRegister.InventoryFromWarehouses AS InventoryFromWarehouses"
		);
		
	QueryResultInventoryFromWarehouses = Query.Execute();
	
	If Not QueryResultInventoryForWarehouses.IsEmpty()
		OR Not QueryResultInventoryFromWarehouses.IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are order warehouse movements in the base. The flag removal is prohibited!';ru='В базе присутствуют движения по ордерному складу! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseOrderWarehouse()

// Checks whether it is possible to clear the InventoryReservation option.
//
&AtServer
Function CancellationUncheckFunctionalOptionInventoryReservation()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	Inventory.CustomerOrder
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='There is an information about reserves in the base! The flag removal is prohibited!';ru='В базе содержится информация о резервах! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionInventoryReservation()

// Checks whether it is possible to clear the AccountingByCells option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingByCells()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryInWarehouses.Company
		|FROM
		|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
		|WHERE
		|	InventoryInWarehouses.Cell <> VALUE(Catalog.Cells.EmptyRef)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='There are cell movements in the base. The flag removal is prohibited!';ru='В базе содержатся движения по ячейкам! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionAccountingByCells()

// Checks whether it is possible to clear the UseCharachteristics option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseCharacteristics()
	
	ErrorText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("ProductRelease");
	ListOfRegisters.Add("InventoryTransferSchedule");
	ListOfRegisters.Add("WorkOrders");
	ListOfRegisters.Add("ProductionOrders");
	ListOfRegisters.Add("CustomerOrders");
	ListOfRegisters.Add("PurchaseOrders");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("InventoryByCCD");
	ListOfRegisters.Add("InventoryForWarehouses");
	ListOfRegisters.Add("InventoryFromWarehouses");
	ListOfRegisters.Add("InventoryInWarehouses");
	ListOfRegisters.Add("InventoryTransferred");
	ListOfRegisters.Add("InventoryReceived");
	ListOfRegisters.Add("SalesTargets");
	ListOfRegisters.Add("InventoryDemand");
	ListOfRegisters.Add("Sales");
	ListOfRegisters.Add("OrdersPlacement");
	ListOfRegisters.Add("JobSheets");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister in ListOfRegisters Do
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				" 
				|
				|UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Value + ".Characteristic
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Value + " AS AccumulationRegister" + AccumulationRegister.Value + "
				|WHERE
				|	AccumulationRegister" + AccumulationRegister.Value + ".Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
			
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Inventory.Characteristic
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en='There are charachteristic movements in the base. The flag removal is prohibited!';ru='В базе есть движения по характеристикам! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseCharacteristics()

// Checks whether it is possible to clear the UseBatches option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseBatches()
	
	ErrorText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("ProductRelease");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("InventoryByCCD");
	ListOfRegisters.Add("InventoryForWarehouses");
	ListOfRegisters.Add("InventoryFromWarehouses");
	ListOfRegisters.Add("InventoryInWarehouses");
	ListOfRegisters.Add("InventoryTransferred");
	ListOfRegisters.Add("InventoryReceived");
	ListOfRegisters.Add("Sales");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister in ListOfRegisters Do
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				" 
				|
				|UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Value + ".Batch
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Value + " AS AccumulationRegister" + AccumulationRegister.Value + "
				|WHERE
				|	AccumulationRegister" + AccumulationRegister.Value + ".Batch <> VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
			
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Inventory.Batch
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Batch <> VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en='There are batch movements in the base. The flag removal is prohibited!';ru='В базе есть движения по партиям! Снятие флага запрещено!'");
		
	EndIf;
	
	If GetFunctionalOption("ReceiveProductsOnCommission") Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en='Option ""Goods accepted on commission"" is enabled (Sales section)! The flag removal is prohibited!';ru='Включена опция ""Прием товаров на комиссию"" (раздел Продажи)! Снятие флага запрещено!'");
		
	EndIf;
	
	If GetFunctionalOption("Tolling") Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en='Option ""Tolling"" is enabled (Production section)! The flag removal is prohibited!';ru='Включена опция ""Переработка давальческого сырья"" (раздел Производство)! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseBatches()

// Checks whether it is possible to clear the TransferRawMaterialsForProcessing option.
//
&AtServer
Function CancellationUncheckFunctionalOptionTransferRawMaterialsForProcessing()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryTransferred.Company
		|FROM
		|	AccumulationRegister.InventoryTransferred AS InventoryTransferred
		|WHERE
		|	InventoryTransferred.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.TransferToProcessing)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='Accumulation register ""Inventory transferred"" contains information about the transfer to processing. The flag removal is prohibited!';ru='Регистр накопления ""Запасы переданные"" содержит информацию о передаче в переработку! Снятие флага запрещено!'");	
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionTransferRawMaterialsForProcessing()

// Initialization of checking the possibility to disable the CurrencyTransactionsAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are the Purchase order documents with the status other than Executed,then it is not allowed to remove the flag.
	If AttributePathToData = "ConstantsSet.UsePurchaseOrderStates" Then
		
		If Constants.UsePurchaseOrderStates.Get() <> ConstantsSet.UsePurchaseOrderStates
			AND (NOT ConstantsSet.UsePurchaseOrderStates) Then
			
			ErrorText = CancellationUncheckUsePurchaseOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the PurchaseOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.PurchaseOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UsePurchaseOrderStates
			AND Not ValueIsFilled(ConstantsSet.PurchaseOrdersInProgressStatus) Then
			
			ErrorText = NStr("en='""Use several purchase order statuses"" flag is removed, but the purchase order status ""In process"" parameter is not filled!';ru='Снят флаг ""Использовать несколько состояний заказов поставщикам"", но не заполнен параматр состояния заказа поставщику ""В работе""!'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.PurchaseOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the PurchaseOrdersCompletedStatus constant
	If AttributePathToData = "ConstantsSet.PurchaseOrdersCompletedStatus" Then
		
		If Not ConstantsSet.UsePurchaseOrderStates
			AND Not ValueIsFilled(ConstantsSet.PurchaseOrdersCompletedStatus) Then
			
			ErrorText = NStr("en='""Use several purchase order statuses"" flag is removed, but the purchase order status ""Executed"" parameter is not filled!';ru='Снят флаг ""Использовать несколько состояний заказов поставщикам"", но не заполнен параматр состояния заказа поставщику ""Выполнен""!'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.PurchaseOrdersCompletedStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are references to the warehouses not equal to the main warehouse, the removal of the FunctionalOptionAccountingByMultipleWarehouses flag is prohibited
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses" Then
		
		If Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() <> ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses
			AND (NOT ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses) Then
			
			ErrorText = CancellationUncheckAccountingBySeveralWarehouses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If the documents contain any references to UOM, it is not allowed to remove the FunctionalOptionAccountingInVariousUOM flag	
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingInVariousUOM" Then
			
		If Constants.FunctionalOptionAccountingInVariousUOM.Get() <> ConstantsSet.FunctionalOptionAccountingInVariousUOM 
			AND (NOT ConstantsSet.FunctionalOptionAccountingInVariousUOM) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingInVariousUOM();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any activities in register "Inventory transferred", it is not allowed to clear the FunctionalOptionTransferInventoryOnSafeCustody check box	
	If AttributePathToData = "ConstantsSet.FunctionalOptionTransferInventoryOnSafeCustody" Then
		
		If Constants.FunctionalOptionTransferInventoryOnSafeCustody.Get() <> ConstantsSet.FunctionalOptionTransferInventoryOnSafeCustody 
			AND (NOT ConstantsSet.FunctionalOptionTransferInventoryOnSafeCustody) Then
			
			ErrorText = CancellationUncheckFunctionalOptionTransferInventoryOnSafeCustody();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in register "Inventory received", it is not allowed to clear the FunctionalOptionTakingInventoryOnResponsibleStorage check box	
	If AttributePathToData = "ConstantsSet.FunctionalOptionTakingInventoryOnResponsibleStorage" Then
		
		If Constants.FunctionalOptionTakingInventoryOnResponsibleStorage.Get() <> ConstantsSet.FunctionalOptionTakingInventoryOnResponsibleStorage 
			AND (NOT ConstantsSet.FunctionalOptionTakingInventoryOnResponsibleStorage) Then
			
			ErrorText = CancellationUncheckFunctionalOptionTakingInventoryOnResponsibleStorage();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in registers "Inventory to receive" or "Inventory to transfer", the clearing of the FunctionalOptionUseOrderWarehouse check box is prohibited	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseOrderWarehouse" Then
		
		If Constants.FunctionalOptionUseOrderWarehouse.Get() <> ConstantsSet.FunctionalOptionUseOrderWarehouse 
			AND (NOT ConstantsSet.FunctionalOptionUseOrderWarehouse) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseOrderWarehouse();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in register "Inventory" for the non-empty customer order, the clearing of  the FunctionalOptionInventoryReservation check box is prohibited	
	If AttributePathToData = "ConstantsSet.FunctionalOptionInventoryReservation" Then
		
		If Constants.FunctionalOptionInventoryReservation.Get() <> ConstantsSet.FunctionalOptionInventoryReservation 
			AND (NOT ConstantsSet.FunctionalOptionInventoryReservation) Then
			
			ErrorText = CancellationUncheckFunctionalOptionInventoryReservation();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in register "Warehouse inventory" for a non-empty cell, the clearing of the FunctionalOptionAccountingByCells check box is prohibited
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByCells" Then
		
		If Constants.FunctionalOptionAccountingByCells.Get() <> ConstantsSet.FunctionalOptionAccountingByCells 
			AND (NOT ConstantsSet.FunctionalOptionAccountingByCells) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingByCells();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in the characteristic registers, the clearing of the FunctionalOptionUseCharacteristics check box is prohibited
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseCharacteristics" Then
		
		If Constants.FunctionalOptionUseCharacteristics.Get() <> ConstantsSet.FunctionalOptionUseCharacteristics
			AND (NOT ConstantsSet.FunctionalOptionUseCharacteristics) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseCharacteristics();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in registers containing batches, it is not allowed to clear the FunctionalOptionUseBatches check box
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseBatches" Then
		
		If Constants.FunctionalOptionUseBatches.Get() <> ConstantsSet.FunctionalOptionUseBatches
			AND (NOT ConstantsSet.FunctionalOptionUseBatches) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseBatches();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any activities in register "Inventory transferred", it is not allowed to clear the FunctionalOptionTransferRawMaterialsForProcessing check box	
	If AttributePathToData = "ConstantsSet.FunctionalOptionTransferRawMaterialsForProcessing" Then
		
		If Constants.FunctionalOptionTransferRawMaterialsForProcessing.Get() <> ConstantsSet.FunctionalOptionTransferRawMaterialsForProcessing
			AND (NOT ConstantsSet.FunctionalOptionTransferRawMaterialsForProcessing) Then
			
			ErrorText = CancellationUncheckFunctionalOptionTransferRawMaterialsForProcessing();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction // CheckAbilityToChangeAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure // UpdateSystemParameters()

// Procedure - handler of the PurchaseOrdersStatesCatalog command.
//
&AtClient
Procedure CatalogPurchaseOrderStates(Command)
	
	OpenForm("Catalog.PurchaseOrderStates.ListForm");
	
EndProcedure // PurchaseOrdersStatesCatalog()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose()
	
	RefreshApplicationInterface();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - handler of the OnChange event of the FunctionalOptionAccountingInVariousUOM field.
//
&AtClient
Procedure FunctionalOptionAccountingInVariousUOMOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingInVariousUOMOnChange()

// Procedure - handler of the OnChange event of the FunctionalOptionUseCharacteristics field.
//
&AtClient
Procedure FunctionalOptionUseCharacteristicsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseCharacteristicsOnChange()


// Procedure - handler of the  OnChange event of the FunctionalOptionUseBatches field.
//
&AtClient
Procedure FunctionalOptionUseBatchesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseBatches()

// Procedure - handler of the OnChange event of the FunctionalOptionAccountingByMultipleWarehouses field.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleWarehousesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingByMultipleWarehousesOnChange()

// Procedure - handler of the OnChange event of the FunctionalOptionUseOrderWarehouse field.
//
&AtClient
Procedure FunctionalOptionUseOrderWarehouseOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseOrderWarehouseOnChange()

// Procedure - handler of the CatalogStructuralUnitsWarehouses command.
//
&AtClient
Procedure CatalogStructuralUnitsWarehouses(Command)
	
	If ConstantsSet.FunctionalOptionAccountingByMultipleWarehouses Then
		
		FilterArray = New Array;
		FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Warehouse"));
		FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Retail"));
		FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.RetailAccrualAccounting"));
		
		FilterStructure = New Structure("StructuralUnitType", FilterArray);
		
		OpenForm("Catalog.StructuralUnits.ListForm", New Structure("Filter", FilterStructure));
		
	Else
		
		ParameterWarehouse = New Structure("Key", PredefinedValue("Catalog.StructuralUnits.MainWarehouse"));
		OpenForm("Catalog.StructuralUnits.ObjectForm", ParameterWarehouse);
		
	EndIf;
	
EndProcedure // CatalogStructuralUnitsWarehouses()

// Procedure - the OnChange event handler of the FunctionalOptionAccountingByCells field.
//
&AtClient
Procedure FunctionalOptionAccountingByCellsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingByCellsOnChange()

// Procedure - handler of the OnChange event of the FunctionalOptionInventoryReservation field.
//
&AtClient
Procedure FunctionalOptionInventoryReservationOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UsePurchaseOrderStates field.
//
&AtClient
Procedure UsePurchaseOrderStatesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // UsePurchaseOrderStatesOnChange()

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // InProcessStatusOnChange()

// Procedure - event handler OnChange of the CompletedStatus field.
// 
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // CompletedStatusOnChange()

// Procedure - handler of the OnChange event of the FunctionalOptionTakingInventoryOnResponsibleStorage field.
//
&AtClient
Procedure FunctionalOptionTakingInventoryOnResponsibleStorageOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
	If ConstantsSet.FunctionalOptionTakingInventoryOnResponsibleStorage
		AND Not ConstantsSet.FunctionalOptionUseBatches Then
		
		ConstantsSet.FunctionalOptionUseBatches = True;
		Attachable_OnAttributeChange(Items.FunctionalOptionUseBatches);
		
	EndIf;
	
EndProcedure // FunctionalOptionTakingInventoryOnResponsibleStorageOnChange()

// Procedure - handler of the OnChange event of the FunctionalOptionTakingInventoryOnResponsibleStorage field.
//
&AtClient
Procedure FunctionalOptionTransferInventoryOnSafeCustodyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionTransferInventoryOnSafeCustodyOnChange()

// Procedure - handler of the OnChange event of the FunctionalOptionTransferRawMaterialsForProcessing field.
//
&AtClient
Procedure FunctionalOptionTransferRawMaterialsForProcessingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionTransferRawMaterialsForProcessingOnChange()

// Procedure - handler of the OnChange event of the VendorPaymentDueDate field.
//
&AtClient
Procedure VendorPaymentDueDateOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // VendorPaymentDueDateOnChange()






























