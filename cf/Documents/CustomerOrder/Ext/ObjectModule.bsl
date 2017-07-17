#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	SmallBusinessManagementElectronicDocumentsServer.ClearIncomingDocumentDateNumber(ThisObject);
	
	FillOnCopy();
	Prepayment.Clear();

EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("OperationKind")
		And FillingData.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder
		And FillingData.Property("ProductsAndServices") Then
		
		ProductsAndServices = FillingData.ProductsAndServices;
		TabularSection = New ValueTable;
		TabularSection.Columns.Add("ProductsAndServices");
		NewRow = TabularSection.Add();
		NewRow.ProductsAndServices = ProductsAndServices;
		
		If ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
			NameTS = "Inventory";
		ElsIf ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
			Or ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work Then
			NameTS = "Works";
		Else
			NameTS = "";
		EndIf;
		
		FillingData = New Structure;
		If ValueIsFilled(NameTS) Then
			FillingData.Insert(NameTS, TabularSection);
		EndIf;
		If ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.WorkKind Then
			FillingData.Insert("WorkKind", ProductsAndServices);
		EndIf;
		FillingData.Insert("OperationKind", Enums.OperationKindsCustomerOrder.JobOrder);
		
	EndIf;

	If CommonUse.ReferenceTypeValue(FillingData) Then
		ObjectFillingSB.FillDocument(ThisObject, FillingData, "FillingHandler");
	Else
		ObjectFillingSB.FillDocument(ThisObject, FillingData);
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If ShipmentDatePosition = Enums.AttributePositionOnForm.InHeader Then
		For Each TabularSectionRow IN Inventory Do
			If TabularSectionRow.ShipmentDate <> ShipmentDate Then
				TabularSectionRow.ShipmentDate = ShipmentDate;
			EndIf;
		EndDo;
	EndIf;
	
	If ShipmentDatePosition = Enums.AttributePositionOnForm.InTabularSection Then
		If OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
			ShipmentDate = Finish;
		Else
			For Each Row In Inventory Do
				If Not ValueIsFilled(Row.ShipmentDate) Then
					Continue;
				EndIf;
				ShipmentDate = Row.ShipmentDate;
				Break;
			EndDo;
		EndIf;
	EndIf;
	
	If WorkKindPosition = Enums.AttributePositionOnForm.InHeader Then
		For Each TabularSectionRow IN Works Do
			TabularSectionRow.WorkKind = WorkKind;
		EndDo;
	EndIf;
	
	If OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		ResourcesList = "";
		For Each RowResource IN EnterpriseResources Do
			ResourcesList = ResourcesList + ?(ResourcesList = "","","; " + Chars.LF) + TrimAll(RowResource.EnterpriseResource);
		EndDo;
		
		ProductsAndServicesList = "";
		For Each StringProductsAndServices IN Works Do
			CharacteristicPresentation = "";
			If Constants.FunctionalOptionUseCharacteristics.Get() 
				AND ValueIsFilled(StringProductsAndServices.Characteristic) Then
				CharacteristicPresentation = " (" + TrimAll(StringProductsAndServices.Characteristic) + ")";
			EndIf;
			ProductsAndServicesQuantity = StringProductsAndServices.Quantity * StringProductsAndServices.Multiplicity * StringProductsAndServices.Factor;
			ProductsAndServicesList = ProductsAndServicesList + ?(ProductsAndServicesList = "","","; " + Chars.LF) + TrimAll(StringProductsAndServices.ProductsAndServices) + CharacteristicPresentation + ", " + ProductsAndServicesQuantity + " " + TrimAll(Catalogs.UOMClassifier.h);
		EndDo;
		
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total") + Works.Total("Total");
	
	ChangeDate = CurrentDate();
	
EndProcedure // BeforeWrite()

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	PerformanceEstimationClientServer.StartTimeMeasurement("CustomerOrderDocumentPostingInitialization");
	
	Documents.CustomerOrder.InitializeDocumentData(Ref, AdditionalProperties, ThisObject);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	PerformanceEstimationClientServer.StartTimeMeasurement("CustomerOrderDocumentPostingActivitiesCreation");

	SmallBusinessServer.ReflectInventoryTransferSchedule(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectCustomerOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectOrdersPlacement(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccrualsAndDeductions(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPayrollPayments(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	SmallBusinessServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	SmallBusinessServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	// AutomaticDiscounts
	SmallBusinessServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);
	
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	PerformanceEstimationClientServer.StartTimeMeasurement("CustomerOrderDocumentPostingActivitiesRecord");
	
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	PerformanceEstimationClientServer.StartTimeMeasurement("CustomerOrderDocumentPostingControl");
	
	Documents.CustomerOrder.RunControl(ThisObject, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.CustomerOrder.RunControl(ThisObject, AdditionalProperties, Cancel, True);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ShipmentDate"));
		CheckedAttributes.Delete(CheckedAttributes.Find("ShipmentDate"));
		CheckedAttributes.Delete(CheckedAttributes.Find("ConsumerMaterials.ReceiptDate"));
		
		If OrderState.OrderStatus = Enums.OrderStatuses.InProcess
			OR OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
		
			CheckedAttributes.Add("Start");
			CheckedAttributes.Add("Finish");
		
		EndIf;
		
		If Materials.Count() > 0 OR Inventory.Count() > 0 Then
		
			CheckedAttributes.Add("StructuralUnitReserve");
		
		EndIf;
		
	Else
		
		If ShipmentDatePosition = Enums.AttributePositionOnForm.InTabularSection Then
			CheckedAttributes.Delete(CheckedAttributes.Find("ShipmentDate"));
		Else
			CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ShipmentDate"));
		EndIf;
		
	EndIf;
	
	If Inventory.Total("Reserve") > 0 Then
		
		For Each StringInventory IN Inventory Do
		
			If StringInventory.Reserve > 0
			AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en='Reserve warehouse is required.';ru='Не заполнен слад резерва'");
				SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If SchedulePayment
		AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
		
		CheckedAttributes.Delete(CheckedAttributes.Find("PettyCash"));
		
	ElsIf SchedulePayment
		AND CashAssetsType = Enums.CashAssetTypes.Cash Then
		
		CheckedAttributes.Delete(CheckedAttributes.Find("BankAccount"));
		
	Else
		
		CheckedAttributes.Delete(CheckedAttributes.Find("PettyCash"));
		CheckedAttributes.Delete(CheckedAttributes.Find("BankAccount"));
		
	EndIf;
	
	If SchedulePayment
		AND PaymentCalendar.Count() = 1
		AND Not ValueIsFilled(PaymentCalendar[0].PayDate) Then
		
		MessageText = NStr("en='The ""Payment date"" field is not filled in.';ru='Поле ""Дата оплаты"" не заполнено.'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "PayDate", Cancel);
		CheckedAttributes.Delete(CheckedAttributes.Find("PaymentCalendar.PaymentDate"));
		
	EndIf;
	
	If Constants.FunctionalOptionInventoryReservation.Get() Then
		
		If OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale Then
		
			For Each StringInventory IN Inventory Do
				
				If StringInventory.Reserve > StringInventory.Quantity Then
					
					MessageText = NStr("en='The number of reserved positions exceeds the total inventory quantity in row No. %Number% of the ""Goods, services"" tabular section.';ru='В строке №%Номер% табл. части ""Товары, услуги"" количество резервируемых позиций превышает общее количество запасов.'");
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
			
		ElsIf OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
			
			For Each StringInventory IN Inventory Do
				
				If OrderState.OrderStatus = Enums.OrderStatuses.Completed
					AND StringInventory.ReserveShipment > StringInventory.Quantity Then
					
					MessageText = NStr("en='The number of items written off from reserve exceeds the total inventory quantity in row No. %Number% of the Goods tabular section.';ru='В строке №%Номер% табл. части ""Товары"" количество списываемых позиций из резерва превышает общее количество запасов.'");
					MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Inventory",
						StringInventory.LineNumber,
						"ReserveShipment",
						Cancel
					);
					
				ElsIf StringInventory.Reserve > StringInventory.Quantity Then	
					
					MessageText = NStr("en='The number of reserved positions exceeds the total inventory quantity in row No. %Number% of the Goods tabular section.';ru='В строке №%Номер% табл. части ""Товары"" количество резервируемых позиций превышает общее количество запасов.'");
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
			
			For Each StringInventory IN Materials Do
				
				If OrderState.OrderStatus = Enums.OrderStatuses.Completed
					AND StringInventory.ReserveShipment > StringInventory.Quantity Then
					
					MessageText = NStr("en='Quantity of items written off from reserve exceeds the total inventory quantity in row No. %Number% of the ""Materials"" tabular section.';ru='В строке №%Номер% табл. части ""Материалы"" количество списываемых позиций из резерва превышает общее количество запасов.'");
					MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Materials",
						StringInventory.LineNumber,
						"ReserveShipment",
						Cancel
					);
					
				ElsIf StringInventory.Reserve > StringInventory.Quantity Then
					
					MessageText = NStr("en='The number of reserved positions exceeds the total inventory quantity in row No. %Number% of the ""Materials"" tabular section.';ru='В строке №%Номер% табл. части ""Материалы"" количество резервируемых позиций превышает общее количество запасов.'");
					MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Materials",
						StringInventory.LineNumber,
						"Reserve",
						Cancel
					);
					
				EndIf;
				
			EndDo;
			
			// Serial numbers
			WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, ThisObject);
			WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Materials, SerialNumbersMaterials, ThisObject, "ConnectionKeySerialNumbers");
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseCustomerOrderStates.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en='The ""Order state"" field is not filled. Specify state values in the accounting parameter settings.';ru='Поле ""Состояние заказа"" не заполнено. В настройках параметров учета необходимо установить значения состояний.'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseDiscountsMarkups");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups"); // AutomaticDiscounts
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringInventory IN Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			ManualDiscountCurAmount = ?(ThereAreManualDiscounts, ROUND(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount = ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts = ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				MessageText = NStr("en='The ""Amount"" column is not filled out in the %Number% row of the ""Goods, works, services"" list.';ru='Не заполнена колонка ""Сумма"" в строке %Номер% списка ""Товары, работы, услуги"".'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	If ThereAreManualDiscounts Then
		For Each WorkRow IN Works Do
			// AutomaticDiscounts
			CurAmount = WorkRow.Price * WorkRow.Quantity;
			ManualDiscountCurAmount = ?(ThereAreManualDiscounts, ROUND(CurAmount * WorkRow.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount = ?(ThereAreAutomaticDiscounts, WorkRow.AutomaticDiscountAmount, 0);
			CurAmountDiscounts = ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			If WorkRow.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(WorkRow.Amount) Then
				MessageText = NStr("en='The ""Amount"" column is not filled out in the %Number% row of the ""Works"" list.';ru='Не заполнена колонка ""Сумма"" в строке %Номер% списка ""Работы"".'");
				MessageText = StrReplace(MessageText, "%Number%", WorkRow.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Works",
					WorkRow.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
	//Also check filling of the employees accruals
	Documents.CustomerOrder.ArePerformersWithEmptyAccrualSum(Performers);
	
EndProcedure // FillCheckProcessing()

#EndRegion

#Region DocumentFillingProcedures

Procedure FillingHandler(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(TabularSectionName(FillingData)) Then
		Return;
	EndIf;
	
	QueryResult = QueryDataForFilling(FillingData).Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	SelectionHeader = QueryResult.Select();
	SelectionHeader.Next();
	
	FillPropertyValues(ThisObject, SelectionHeader);
	
	If DocumentCurrency <> Constants.NationalCurrency.Get() Then
		CurrencyStructure = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = CurrencyStructure.ExchangeRate;
		Multiplicity = CurrencyStructure.Multiplicity;
	EndIf;
	
	ThisObject.Inventory.Clear();
	TabularSectionSelection = SelectionHeader[TabularSectionName(FillingData)].Select();
	While TabularSectionSelection.Next() Do
		NewRow	= ThisObject.Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionSelection);
		NewRow.ProductsAndServicesTypeInventory = (TabularSectionSelection.ProductsAndServicesProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem);
	EndDo;
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		SelectionDiscountsMarkups = SelectionHeader.DiscountsMarkups.Select();
		While SelectionDiscountsMarkups.Next() Do
			FillPropertyValues(ThisObject.DiscountsMarkups.Add(), SelectionDiscountsMarkups);
		EndDo;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
EndProcedure

Function QueryDataForFilling(FillingData)
	
	Wizard = New QuerySchema;
	Batch = Wizard.QueryBatch[0];
	Batch.SelectAllowed = True;
	Operator0 = Batch.Operators[0];
	Operator0.Sources.Add(FillingData.Metadata().FullName());
	For Each HeaderFieldDescription In HeaderFieldsDescription(FillingData) Do
		Operator0.SelectedFields.Add(HeaderFieldDescription.Key);
		If ValueIsFilled(HeaderFieldDescription.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = HeaderFieldDescription.Value;
		EndIf;
	EndDo;
	
	For Each CurFieldDescriptionTabularSectionInventory In FieldsDescriptionTabularSectionInventory(FillingData) Do
		Operator0.SelectedFields.Add(
		StringFunctionsClientServer.SubstituteParametersInString(
		"%1.%2",
		TabularSectionName(FillingData),
		CurFieldDescriptionTabularSectionInventory.Key));
		If ValueIsFilled(CurFieldDescriptionTabularSectionInventory.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = CurFieldDescriptionTabularSectionInventory.Value;
		EndIf;
	EndDo;
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		Operator0.SelectedFields.Add("DiscountsMarkups.ConnectionKey");
		Operator0.SelectedFields.Add("DiscountsMarkups.DiscountMarkup");
		Operator0.SelectedFields.Add("DiscountsMarkups.Amount");
	EndIf;
	
	Operator0.Filter.Add("Ref = &Parameter");
	
	Result = New Query(Wizard.GetQueryText());
	Result.SetParameter("Parameter", FillingData);
	
	Return Result;
	
EndFunction

Function TabularSectionName(FillingData)
	
	TabularSectionNames = New Map;
	TabularSectionNames[Type("DocumentRef.InvoiceForPayment")] = "Inventory";
	
	Return TabularSectionNames[TypeOf(FillingData)];
	
EndFunction

Function HeaderFieldsDescription(FillingData)
	
	Result = New Map;
	
	FillingDataMetadata = FillingData.Metadata();
	
	Result.Insert("Ref", "BasisDocument");
	Result.Insert("Company");
	Result.Insert("Company.BankAccountByDefault", "BankAccount");
	
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountPercentByDiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "ExchangeRate");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Multiplicity");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "AmountIncludesVAT");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "VATTaxation");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Contract");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Counterparty");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DocumentCurrency");
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		Result.Insert("DiscountsAreCalculated");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddAttributeIfItIsInDocument(ResultMap, FillingDataMetadata, AttributeName)
	
	If CommonUse.IsObjectAttribute(AttributeName, FillingDataMetadata) Then
		ResultMap.Insert(AttributeName);
	EndIf;
	
EndProcedure

Function FieldsDescriptionTabularSectionInventory(FillingData)
	
	Result = New Map;
	Result.Insert("ProductsAndServices");
	Result.Insert("ProductsAndServices.ProductsAndServicesType");
	Result.Insert("Characteristic");
	Result.Insert("Content");
	Result.Insert("MeasurementUnit");
	Result.Insert("Quantity");
	Result.Insert("Price");
	Result.Insert("DiscountMarkupPercent");
	Result.Insert("Amount");
	Result.Insert("VATRate");
	Result.Insert("VATAmount");
	Result.Insert("Total");
	If TabularSectionName(FillingData) <> "WorksAndServices" Then
		Result.Insert("Batch");
	EndIf;
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		Result.Insert("ConnectionKey");
		Result.Insert("AutomaticDiscountAmount");
		Result.Insert("AutomaticDiscountsPercent");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillTabularSectionPerformersByResources(PerformersConnectionKey) Export
	
	EmployeeArray	= New Array();
	ArrayOfTeams 		= New Array();
	For Each TSRow IN EnterpriseResources Do
		
		If ValueIsFilled(TSRow.EnterpriseResource) Then
			
			ResourceValue = TSRow.EnterpriseResource.ResourceValue;
			If TypeOf(ResourceValue) = Type("CatalogRef.Employees") Then
				
				EmployeeArray.Add(ResourceValue);
				
			ElsIf TypeOf(ResourceValue) = Type("CatalogRef.Teams") Then
				
				ArrayOfTeams.Add(ResourceValue);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EmployeesTable.Employee AS Employee,
	|	EmployeesTable.Description AS Description,
	|	AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind AS AccrualDeductionKind
	|INTO TemporaryTableEmployeesAndAccrualDeductionSorts
	|FROM
	|	(SELECT
	|		Employees.Ref AS Employee,
	|		Employees.Description AS Description
	|	FROM
	|		Catalog.Employees AS Employees
	|	WHERE
	|		Employees.Ref IN(&EmployeeArray)
	|	
	|	GROUP BY
	|		Employees.Ref,
	|		Employees.Description
	|	
	|	UNION
	|	
	|	SELECT
	|		WorkgroupsContent.Employee,
	|		WorkgroupsContent.Employee.Description
	|	FROM
	|		Catalog.Teams.Content AS WorkgroupsContent
	|	WHERE
	|		WorkgroupsContent.Ref IN(&ArrayOfTeams)) AS EmployeesTable
	|		LEFT JOIN InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality
	|					AND AccrualDeductionKind IN (VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment), VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent), VALUE(Catalog.AccrualAndDeductionKinds.FixedAmount))) AS AccrualsAndDeductionsPlanSliceLast
	|		ON EmployeesTable.Employee = AccrualsAndDeductionsPlanSliceLast.Employee
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.Employee AS Employee,
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.Description AS Description,
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.AccrualDeductionKind AS AccrualDeductionKind,
	|	1 AS LPF,
	|	AccrualsAndDeductionsPlanSliceLast.Amount * AccrualCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccrualCurrencyRate.Multiplicity) AS AmountAccrualDeduction
	|FROM
	|	TemporaryTableEmployeesAndAccrualDeductionSorts AS TemporaryTableEmployeesAndAccrualDeductionSorts
	|		LEFT JOIN InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality) AS AccrualsAndDeductionsPlanSliceLast
	|		ON TemporaryTableEmployeesAndAccrualDeductionSorts.Employee = AccrualsAndDeductionsPlanSliceLast.Employee
	|			AND TemporaryTableEmployeesAndAccrualDeductionSorts.AccrualDeductionKind = AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ToDate, ) AS AccrualCurrencyRate
	|		ON (AccrualsAndDeductionsPlanSliceLast.Currency = AccrualCurrencyRate.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ToDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|
	|ORDER BY
	|	Description";
	
	Query.SetParameter("ToDate", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ArrayOfTeams", ArrayOfTeams);
	Query.SetParameter("EmployeeArray", EmployeeArray);
	
	ResultsArray = Query.ExecuteBatch();
	EmployeesTable = ResultsArray[1].Unload();
	
	If PerformersConnectionKey = Undefined Then
		
		For Each TabularSectionRow IN Works Do
			
			If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work Then
				
				For Each TSRow IN EmployeesTable Do
					
					NewRow = Performers.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.ConnectionKey = TabularSectionRow.ConnectionKey;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TSRow IN EmployeesTable Do
			
			NewRow = Performers.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.ConnectionKey = PerformersConnectionKey;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillPerformersTabularSectionByResources()

Procedure FillTabularSectionPerformersByTeams(ArrayOfTeams, PerformersConnectionKey) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkgroupsContent.Employee AS Employee,
	|	WorkgroupsContent.Employee.Description AS Description,
	|	AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind AS AccrualDeductionKind
	|INTO TemporaryTableEmployeesAndAccrualDeductionSorts
	|FROM
	|	Catalog.Teams.Content AS WorkgroupsContent
	|		LEFT JOIN InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality
	|					AND AccrualDeductionKind IN (VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePayment), VALUE(Catalog.AccrualAndDeductionKinds.PieceRatePaymentPercent), VALUE(Catalog.AccrualAndDeductionKinds.FixedAmount))) AS AccrualsAndDeductionsPlanSliceLast
	|		ON WorkgroupsContent.Employee = AccrualsAndDeductionsPlanSliceLast.Employee
	|WHERE
	|	WorkgroupsContent.Ref IN(&ArrayOfTeams)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.Employee AS Employee,
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.Description AS Description,
	|	TemporaryTableEmployeesAndAccrualDeductionSorts.AccrualDeductionKind AS AccrualDeductionKind,
	|	1 AS LPF,
	|	AccrualsAndDeductionsPlanSliceLast.Amount * AccrualCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccrualCurrencyRate.Multiplicity) AS AmountAccrualDeduction
	|FROM
	|	TemporaryTableEmployeesAndAccrualDeductionSorts AS TemporaryTableEmployeesAndAccrualDeductionSorts
	|		LEFT JOIN InformationRegister.AccrualsAndDeductionsPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality) AS AccrualsAndDeductionsPlanSliceLast
	|		ON TemporaryTableEmployeesAndAccrualDeductionSorts.Employee = AccrualsAndDeductionsPlanSliceLast.Employee
	|			AND TemporaryTableEmployeesAndAccrualDeductionSorts.AccrualDeductionKind = AccrualsAndDeductionsPlanSliceLast.AccrualDeductionKind
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ToDate, ) AS AccrualCurrencyRate
	|		ON (AccrualsAndDeductionsPlanSliceLast.Currency = AccrualCurrencyRate.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ToDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|
	|ORDER BY
	|	Description";
	
	Query.SetParameter("ToDate", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ArrayOfTeams", ArrayOfTeams);
	
	ResultsArray = Query.ExecuteBatch();
	EmployeesTable = ResultsArray[1].Unload();
	
	If PerformersConnectionKey = Undefined Then
		
		For Each TabularSectionRow IN Works Do
			
			If TabularSectionRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work Then
				
				For Each TSRow IN EmployeesTable Do
					
					NewRow = Performers.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.ConnectionKey = TabularSectionRow.ConnectionKey;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TSRow IN EmployeesTable Do
			
			NewRow = Performers.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.ConnectionKey = PerformersConnectionKey;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillPerformersTabularSectionByTeams()

Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsAndServicesTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ProductsAndServices.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.ShipmentDate = StringInventory.ShipmentDate;
			NewRow.StringInventory = StringInventory;
		EndDo;
		
		TotalBalance = Selection.QuantityBalance;
		TableOfPeriods.Sort("ShipmentDate");
		For Each TableOfPeriodsRow IN TableOfPeriods Do
			StringInventory = TableOfPeriodsRow.StringInventory;
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
		TableOfPeriods.Clear();
		
	EndDo;
	
EndProcedure // FillColumnReserveByBalances()

Procedure GoodsFillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	Inventory.LoadColumn(New Array(Inventory.Count()), "ReserveShipment");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsAndServicesTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ProductsAndServices.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				StringInventory.ReserveShipment = StringInventory.Reserve;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				StringInventory.ReserveShipment = StringInventory.Reserve;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure // GoodsFillReserveColumnByBalances()

Procedure GoodsFillColumnReserveByReserves() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "ReserveShipment");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS CustomerOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsAndServicesTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("Order", Ref);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ProductsAndServices.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.CustomerOrder,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				
				StringInventory.ReserveShipment = TotalBalance;
				TotalBalance = 0;
				
			Else
				
				StringInventory.ReserveShipment = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	For Each TabularSectionRow IN Inventory Do
		If TabularSectionRow.ReserveShipment < TabularSectionRow.Reserve Then
			TabularSectionRow.Reserve = TabularSectionRow.ReserveShipment;
		EndIf;
	EndDo;
	
EndProcedure // GoodsFillReserveColumnByReserves()

Procedure MaterialsFillColumnReserveByBalances(MaterialsConnectionKey) Export
	
	If MaterialsConnectionKey = Undefined Then
		Materials.LoadColumn(New Array(Materials.Count()), "Reserve");
		Materials.LoadColumn(New Array(Materials.Count()), "ReserveShipment");
	Else
		SearchResult = Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
		For Each TabularSectionRow IN SearchResult Do
			TabularSectionRow.Reserve = 0;
			TabularSectionRow.ReserveShipment = 0;
		EndDo;
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
		Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	CASE
	|			WHEN &SelectionByKeyLinks
	|				THEN TableInventory.ConnectionKey = &ConnectionKey
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.SetParameter("SelectionByKeyLinks", ?(MaterialsConnectionKey = Undefined, False, True));
	Query.SetParameter("ConnectionKey", MaterialsConnectionKey);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ProductsAndServices.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If MaterialsConnectionKey <> Undefined Then
			StructureForSearch.Insert("ConnectionKey", MaterialsConnectionKey);
		EndIf;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				StringInventory.ReserveShipment = StringInventory.Reserve;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				StringInventory.ReserveShipment = StringInventory.Reserve;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure // MaterialsFillReserveColumnByBalances()

Procedure MaterialsFillColumnReserveByReserves(MaterialsConnectionKey) Export
	
	If MaterialsConnectionKey = Undefined Then
		Materials.LoadColumn(New Array(Materials.Count()), "ReserveShipment");
	Else
		SearchResult = Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
		For Each TabularSectionRow IN SearchResult Do
			TabularSectionRow.ReserveShipment = 0;
		EndDo;
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS CustomerOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	CASE
	|			WHEN &SelectionByKeyLinks
	|				THEN TableInventory.ConnectionKey = &ConnectionKey
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.SetParameter("SelectionByKeyLinks", ?(MaterialsConnectionKey = Undefined, False, True));
	Query.SetParameter("ConnectionKey", MaterialsConnectionKey);
	Query.SetParameter("Order", Ref);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ProductsAndServices.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.CustomerOrder,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If MaterialsConnectionKey <> Undefined Then
			StructureForSearch.Insert("ConnectionKey", MaterialsConnectionKey);
		EndIf;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				
				StringInventory.ReserveShipment = TotalBalance;
				TotalBalance = 0;
				
			Else
				
				StringInventory.ReserveShipment = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If MaterialsConnectionKey = Undefined Then
		For Each TabularSectionRow IN Materials Do
			If TabularSectionRow.ReserveShipment < TabularSectionRow.Reserve Then
				TabularSectionRow.Reserve = TabularSectionRow.ReserveShipment;
			EndIf;
		EndDo;
	Else
		For Each TabularSectionRow IN SearchResult Do
			If TabularSectionRow.ReserveShipment < TabularSectionRow.Reserve Then
				TabularSectionRow.Reserve = TabularSectionRow.ReserveShipment;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure // MaterialsFillReserveColumnByReserves()

Procedure FillOnCopy()
	
	If Constants.UseCustomerOrderStates.Get() Then
		User = Users.CurrentUser();
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "StatusOfNewCustomerOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.CustomerOrderStates.Open;
		EndIf;
	Else
		OrderState = Constants.CustomerOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
EndProcedure

Procedure FillByDefault()

	If Constants.UseCustomerOrderStates.Get() Then
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "StatusOfNewCustomerOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.CustomerOrderStates.Open;
		EndIf;
	Else
		OrderState = Constants.CustomerOrdersInProgressStatus.Get();
	EndIf;

EndProcedure

#EndRegion

#EndIf
