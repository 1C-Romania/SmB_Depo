
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF RECOVERY AND SETTINGS SAVING

&AtServer
// The procedure restores the custom settings.
//
Procedure RestoreSettings()
	
	Var SettingsValue;
	Var UserSettings;
	
	If PurchasesOnly Then
		SettingsValue = CommonSettingsStorage.Load("DataProcessor.DemandPlanning", "SettingsPurchases");
	Else
		SettingsValue = CommonSettingsStorage.Load("DataProcessor.DemandPlanning", "SettingsProduction");
	EndIf;
	
	ArrayWaysRefill = Items.FilterReplenishmentMethod.ChoiceList.UnloadValues();
	If TypeOf(SettingsValue) = Type("Structure") Then
		
		SettingsValue.Property("EndOfPeriod", EndOfPeriod);
		SettingsValue.Property("Counterparty", Counterparty);
		SettingsValue.Property("Company", Company);
		SettingsValue.Property("OnlyDeficit", OnlyDeficit);
		SettingsValue.Property("UserSettings", UserSettings);
		
		If ArrayWaysRefill.Count() = 1 Then
			
			FilterReplenishmentMethod = ArrayWaysRefill[0];
			
		Else
			
			SettingsValue.Property("FilterReplenishmentMethod", FilterReplenishmentMethod);
			
		EndIf;
		
	Else
		
		OnlyDeficit = True;
		UserSettings = New DataCompositionUserSettings;
		
	EndIf;
	
	UpdateChoiceListReplenishmentMethod();
	
	If EndOfPeriod <= CurrentDate() Then
		EndOfPeriod = CurrentDate() + 7 * 86400;
	EndIf;
	
	SettingsComposer.LoadUserSettings(UserSettings);
	
EndProcedure // RestoreSettings()

&AtServer
// The procedure saves custom settings.
//
Procedure SaveSettings()
	
	Var Settings;
	
	Settings = New Structure;
	Settings.Insert("EndOfPeriod", EndOfPeriod);
	Settings.Insert("Counterparty", Counterparty);
	Settings.Insert("Company", Company);
	Settings.Insert("OnlyDeficit", OnlyDeficit);
	Settings.Insert("FilterReplenishmentMethod", FilterReplenishmentMethod);
	Settings.Insert("UserSettings", SettingsComposer.UserSettings);
	
	If PurchasesOnly Then
		CommonSettingsStorage.Save("DataProcessor.DemandPlanning", "SettingsPurchases", Settings);
	Else
		CommonSettingsStorage.Save("DataProcessor.DemandPlanning", "SettingsProduction", Settings);
	EndIf;
	
EndProcedure // SaveSettings()

&AtServer
// The procedure updates the selections depending on the SF.
//
Procedure UpdateChoiceListReplenishmentMethod()
	
	PurchasesAvailable = IsInRole("FullRights") OR IsInRole("AddChangePurchasesSubsystem");
	AvailableProduction = (IsInRole("FullRights") OR IsInRole("AddChangeProductionSubsystem"))
		AND GetFunctionalOption("UseSubsystemProduction");
	
	If PurchasesAvailable Then
		If GetFunctionalOption("TransferRawMaterialsForProcessing") AND IsInRole("AddChangeProcessingSubsystem") Then
			Items.FilterReplenishmentMethod.ChoiceList.Add("Purchase and processing", "Purchase and processing");
		Else
			Items.FilterReplenishmentMethod.ChoiceList.Add("Purchase", "Purchase");
		EndIf;
	EndIf;
	
	If AvailableProduction Then
		Items.FilterReplenishmentMethod.ChoiceList.Add("Production", "Production");
		If PurchasesAvailable Then
			Items.FilterReplenishmentMethod.ChoiceList.Add("All", "All");
		EndIf;
	EndIf;
	
	Items.FilterReplenishmentMethod.Visible = PurchasesAvailable AND AvailableProduction;
	PurchasesOnly = PurchasesAvailable AND Not AvailableProduction;
	
	UpdateReplenishmentMethod();
	
	If FilterReplenishmentMethod = "Production" Then
		Items.Counterparty.Visible = False;
	Else
		Items.Counterparty.Visible = True;
	EndIf;
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Items.Company.ReadOnly = True;
		Company = Constants.SubsidiaryCompany.Get();
	ElsIf Not ValueIsFilled(Company) Then
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Company = SettingValue;
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
EndProcedure // UpdateChoiceListReplenishmentMethod()

&AtServer
// The procedure updates the selection: replenishment method.
//
Procedure UpdateReplenishmentMethod()
	
	If Items.FilterReplenishmentMethod.ChoiceList.FindByValue(FilterReplenishmentMethod) = Undefined Then
		
		If PurchasesOnly Then
			If GetFunctionalOption("TransferRawMaterialsForProcessing") AND IsInRole("AddChangeProcessingSubsystem") Then
				FilterReplenishmentMethod = "Purchase and processing";
			Else
				FilterReplenishmentMethod = "Purchase";
			EndIf;
		Else
			FilterReplenishmentMethod = "Production";
		EndIf;
		
	EndIf;
	
EndProcedure // UpdateReplenishmentMethod()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure of data processing and demand diagram output to the form.
//
Procedure UpdateAtServer()
	
	DataCompositionSchema = GetFromTempStorage(SchemaURLCompositionData);
	
	DataCompositionTemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = DataCompositionTemplateComposer.Execute(DataCompositionSchema, SettingsComposer.GetSettings());
	
	DataCompositionTemplate.ParameterValues.StartDate.Value = BegOfDay(CurrentDate());
	DataCompositionTemplate.ParameterValues.EndDate.Value = EndOfDay(?(EndOfPeriod < CurrentDate(), CurrentDate(), EndOfPeriod));
	
	Query = New Query(DataCompositionTemplate.DataSets.LineNeedsInventory.Query);

	QueryParametersDescription = Query.FindParameters();
	
	For Each QueryParameterDescription in QueryParametersDescription Do
		
		Query.SetParameter(QueryParameterDescription.Name, DataCompositionTemplate.ParameterValues[QueryParameterDescription.Name].Value);
		
	EndDo;
	
	Query.SetParameter("UseCharacteristics", Constants.FunctionalOptionUseCharacteristics.Get());
	Query.SetParameter("DateBalance", CurrentDate());
	Query.SetParameter("Company", Company);
	
	If ValueIsFilled(Counterparty) Then
		CounterpartyPriceKind = GetActualCounterpartyPriceKind();
		Query.SetParameter("CounterpartyPriceKind", CounterpartyPriceKind);
	Else
		Query.SetParameter("CounterpartyPriceKind", New ValueList());
	EndIf;
	
	Query.SetParameter("Counterparty", Counterparty);
	
	ReplenishmentMethod.Clear();
	If FilterReplenishmentMethod = "Purchase and processing" OR FilterReplenishmentMethod = "Purchase" Then
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Purchase);
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Processing);
	ElsIf FilterReplenishmentMethod = "Production" Then
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Production);
	Else
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Purchase);
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Processing);
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Production);
	EndIf;
	
	Query.SetParameter("ReplenishmentMethod", ReplenishmentMethod);
	
	RefreshColumns(Query.Parameters.StartDate, Query.Parameters.EndDate);
	RefreshData(Query.Execute(), Query.Parameters.StartDate, Query.Parameters.EndDate);
	
	AddressInventory = PutToTempStorage(FormAttributeToValue("Inventory"), UUID);
	CurrentEndOfPeriod = Query.Parameters.EndDate;
	
EndProcedure // UpdateOnServer()

&AtServer
// Procedure of form columns update.
//
Procedure RefreshColumns(StartDate, EndDate)
	
	// Deleting previously added items.
	For Each AddedItem in AddedElements Do
		
		Items.Delete(Items[AddedItem.Value]);
		
	EndDo;
	
	ArrayAddedAttributes = New Array;
	
	// Attributes "Period".
	CurrentPeriod = StartDate;
	
	While BegOfDay(CurrentPeriod) <= BegOfDay(EndDate) Do
		
		NewAttribute = New FormAttribute("Period" + Format(CurrentPeriod, "DF=yyyyMMdd"), New TypeDescription("Number", New NumberQualifiers(15, 3)), "Inventory", Format(CurrentPeriod, "DLF=D"));
		ArrayAddedAttributes.Add(NewAttribute);
		
		NewAttribute = New FormAttribute("VariantRegistrationPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"),  New TypeDescription(New NumberQualifiers(1, 0)), "Inventory");
		ArrayAddedAttributes.Add(NewAttribute);
		
		CurrentPeriod = CurrentPeriod + 86400;
		
	EndDo;
	
	// Deleting previously added attributes and adding new attributes.
	ChangeAttributes(ArrayAddedAttributes, AddedAttributes.UnloadValues());
	
	// Updating added attributes.
	AddedAttributes.Clear();
	
	For Each AddingAttribute in ArrayAddedAttributes Do
		
		AddedAttributes.Add(AddingAttribute.Path + "." + AddingAttribute.Name);
		
	EndDo;
	
	// Adding new items.
	AddedElements.Clear();
	
	For Each Attribute in ArrayAddedAttributes Do
		
		If IsBlankString(Attribute.Title) Then
			
			Continue;
			
		EndIf;
		
		Item = Items.Add(Attribute.Path + Attribute.Name, Type("FormField"), Items[Attribute.Path]);
		Item.Type = FormFieldType.InputField;
		Item.DataPath = Attribute.Path + "." + Attribute.Name;
		Item.Title = Attribute.Title;
		Item.ReadOnly = True;
		Item.Width = 10;
		
		AddedElements.Add(Attribute.Path + Attribute.Name);
		
	EndDo;
	
	// Setting the conditional appearance.
	SetConditionalAppearance(StartDate, EndDate);
	
EndProcedure // UpdateColumns()

&AtServer
// Data processing procedure.
//
Procedure RefreshData(QueryResult, StartDate, EndDate)
	
	// Generate a summary table of the demand diagram.
	TableQueryResult = QueryResult.Unload();
	CalculateInventoryTransferSchedule(TableQueryResult);
		
	// Order - decryption.
	TableLineNeeds = TableQueryResult.CopyColumns();
	AddDrillDownByOrder(TableQueryResult, TableLineNeeds);
		
	// Clearing the result before update.
	ProductsAndServicesItems = Inventory.GetItems();
	ProductsAndServicesItems.Clear();
			
	// Previous values of selection fields.
	PreviousRecord = New Structure("ProductsAndServices, Characteristic");
	
	// Tree item containing current products and services.
	ProductsAndServicesCurrent = Undefined;
	
	// Decryption.
	StructureDetails = Undefined;
	
	// The structure containing the data of current products and services and characteristic.
	StructureDetailing = Undefined;
	
	// Previous column for which the indicators were calculated.
	PreviousColumn = Undefined;
	
	// Selection bypass.
	RecNo = 0;
	RecCountInSample = TableLineNeeds.Count();
	For Each Selection IN TableLineNeeds Do
		
		RecNo = RecNo + 1;
		
		// First record in the selection or products and services and the characteristic have changed.
		If RecNo = 1 OR Selection.ProductsAndServices <> PreviousRecord.ProductsAndServices OR Selection.Characteristic <> PreviousRecord.Characteristic Then
			
			// Adding previous products and services.
			AddProductsAndServicesCharacteristic(ProductsAndServicesCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			// Deleting current products and services if they do not contain data.
			If ProductsAndServicesCurrent <> Undefined AND ProductsAndServicesCurrent.GetItems().Count() = 0 Then
				
				ProductsAndServicesItems.Delete(ProductsAndServicesCurrent);
				
			EndIf;
			
			// Adding Products And Services.
			ProductsAndServicesCurrent = ProductsAndServicesItems.Add();
			ProductsAndServicesCurrent.ProductsAndServices = Selection.ProductsAndServices;
			
			// Adding previous products and services.
			AddProductsAndServicesCharacteristic(ProductsAndServicesCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			ArrayOrders = New Array;
			StructureDetails = New Structure("Details", ArrayOrders);
			
			// Adding products and services and characteristics.
			StructureDetailing = New Structure("ProductsAndServices, Characteristic, MinInventory, MaxInventory, Deficit, Overdue", Selection.ProductsAndServices, Selection.Characteristic, Selection.MinInventory, Selection.MaxInventory);
			
			// Overdue.
			StructureDetailing.Overdue = New Structure("IndicatorValue, Overdue, Detailing", 0, False);
			StructureDetailing.Overdue.Detailing = New Structure("OpeningBalance, Receipt, Demand, MinInventory, MaxInventory, ClosingBalance", 0, 0, 0, 0, 0, 0);
			
			// Deficit.
			StructureDetailing.Deficit = New Structure("IndicatorValue, Overdue, Detailing", 0, False);
			StructureDetailing.Deficit.Detailing = New Structure("OpeningBalance, Receipt, Demand, MinInventory, MaxInventory, ClosingBalance", 0, 0, 0, 0, 0, 0);
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing.Overdue;
			
		EndIf;
					
		StructureDetails.Details.Add(Selection.OrderDetails);
						
		// Record with a period equal to the period start contains overdue items.
		If Selection.Period = StartDate Then
			
			// Setting the values of overdue indicators.
			StructureDetailing.Overdue.Detailing.Insert("OpeningBalance", Selection.AvailableBalance);
			StructureDetailing.Overdue.Detailing.Insert("Receipt", Selection.ReceiptOverdue);
			StructureDetailing.Overdue.Detailing.Insert("Demand", Selection.NeedOverdue);
			StructureDetailing.Overdue.Detailing.Insert("MinInventory", Selection.MinInventory);
			StructureDetailing.Overdue.Detailing.Insert("MaxInventory", ?(Selection.MaxInventory = 0, Selection.MinInventory, Selection.MaxInventory));
			StructureDetailing.Overdue.Detailing.Insert("ClosingBalance", StructureDetailing.Overdue.Detailing.OpeningBalance + StructureDetailing.Overdue.Detailing.Receipt - StructureDetailing.Overdue.Detailing.Demand);
			
			// Calculation of overdue deficit.
			IsOverdueDeficit = StructureDetailing.Overdue.Detailing.MinInventory >= StructureDetailing.Overdue.Detailing.ClosingBalance;
			
			If IsOverdueDeficit Then
				
				StructureDetailing.Overdue.IndicatorValue = StructureDetailing.Overdue.Detailing.MaxInventory - StructureDetailing.Overdue.Detailing.ClosingBalance;
				StructureDetailing.Overdue.Overdue = True;
				
			EndIf;
			
			// Setting the values of deficit indicators.
			FillPropertyValues(StructureDetailing.Deficit.Detailing, StructureDetailing.Overdue.Detailing);
			
			// Calculation of the general deficit.
			IsCommonDeficiency = StructureDetailing.Deficit.Detailing.MinInventory >= StructureDetailing.Deficit.Detailing.ClosingBalance;
			
			If IsCommonDeficiency Then
				
				StructureDetailing.Deficit.IndicatorValue = StructureDetailing.Deficit.Detailing.MaxInventory - StructureDetailing.Deficit.Detailing.ClosingBalance;
				
			EndIf;
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing.Overdue;
			
		EndIf;
			
		// Record of a scheduled period.
		If Selection.Period >= StartDate Then
			
			ColumnName = "Period" + Format(Selection.Period, "DF=yyyyMMdd");
			
			StructureDetailing.Insert(ColumnName, New Structure("IndicatorValue, Overdue, Detailing", 0, False));
			StructureDetailing[ColumnName].Detailing = New Structure("OpeningBalance, Receipt, Demand, MinInventory, MaxInventory, ClosingBalance", 0, 0, 0, 0, 0, 0);
			
			// Setting the values of indicators in the target period.
			StructureDetailing[ColumnName].Detailing.OpeningBalance = PreviousColumn.IndicatorValue + PreviousColumn.Detailing.ClosingBalance;
			StructureDetailing[ColumnName].Detailing.Receipt = Selection.Receipt;
			StructureDetailing[ColumnName].Detailing.Demand = Selection.Demand;
			StructureDetailing[ColumnName].Detailing.MinInventory = PreviousColumn.Detailing.MinInventory;
			StructureDetailing[ColumnName].Detailing.MaxInventory = ?(PreviousColumn.Detailing.MaxInventory = 0, PreviousColumn.Detailing.MinInventory, PreviousColumn.Detailing.MaxInventory);
			StructureDetailing[ColumnName].Detailing.ClosingBalance = StructureDetailing[ColumnName].Detailing.OpeningBalance + StructureDetailing[ColumnName].Detailing.Receipt - StructureDetailing[ColumnName].Detailing.Demand;
			
			// Setting the values of deficit indicators.
			StructureDetailing.Deficit.Detailing.Receipt = StructureDetailing.Deficit.Detailing.Receipt + StructureDetailing[ColumnName].Detailing.Receipt;
			StructureDetailing.Deficit.Detailing.Demand = StructureDetailing.Deficit.Detailing.Demand + StructureDetailing[ColumnName].Detailing.Demand;
			StructureDetailing.Deficit.Detailing.ClosingBalance = StructureDetailing.Deficit.Detailing.OpeningBalance + StructureDetailing.Deficit.Detailing.Receipt - StructureDetailing.Deficit.Detailing.Demand;
			
			// Calculation of the deficit for the period.
			IsShortageByPeriod = StructureDetailing[ColumnName].Detailing.MinInventory >= StructureDetailing[ColumnName].Detailing.ClosingBalance;
			
			If IsShortageByPeriod Then
			
				StructureDetailing[ColumnName].IndicatorValue = StructureDetailing[ColumnName].Detailing.MaxInventory - StructureDetailing[ColumnName].Detailing.ClosingBalance;
				StructureDetailing[ColumnName].Overdue = Selection.Overdue;
				
			Else
				
				StructureDetailing[ColumnName].IndicatorValue = 0;
				StructureDetailing[ColumnName].Overdue = Selection.Overdue;
				
			EndIf;
			
			// Calculation of the general deficit.
			IsCommonDeficiency = StructureDetailing.Deficit.Detailing.MinInventory >= StructureDetailing.Deficit.Detailing.ClosingBalance;
			
			If IsCommonDeficiency Then
				
				StructureDetailing.Deficit.IndicatorValue = StructureDetailing.Deficit.Detailing.MaxInventory - StructureDetailing.Deficit.Detailing.ClosingBalance;
				
			Else
				
				StructureDetailing.Deficit.IndicatorValue = 0;
				
			EndIf;
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing[ColumnName];
				
		EndIf;
							
		// Saving current values of selection fields.
		FillPropertyValues(PreviousRecord, Selection);
		
		// Last record in the selection.
		If RecNo = RecCountInSample Then
			
			// Adding current products and services.
			AddProductsAndServicesCharacteristic(ProductsAndServicesCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			// Deleting current products and services if they do not contain data.
			If ProductsAndServicesCurrent <> Undefined AND ProductsAndServicesCurrent.GetItems().Count() = 0 Then
				
				ProductsAndServicesItems.Delete(ProductsAndServicesCurrent);
				
			EndIf;
			
		EndIf;
				
	EndDo;	
		
EndProcedure // UpdateData()

&AtServer
// The procedure receives the actual kind of counterparty prices.
//
Function GetActualCounterpartyPriceKind()
	
	PriceKindsLis = New ValueList();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind AS CounterpartyPriceKind
	|FROM
	|	InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(&StartDate, CounterpartyPriceKind.Owner = &Counterparty) AS CounterpartyProductsAndServicesPricesSliceLast
	|WHERE
	|	CounterpartyProductsAndServicesPricesSliceLast.Actuality";
	
	Query.SetParameter("StartDate", BegOfDay(CurrentDate()));
	Query.SetParameter("Counterparty", Counterparty);
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		PriceKindsLis.Add(Selection.CounterpartyPriceKind);
	EndDo;
	
	Return PriceKindsLis;
	
EndFunction // GetActualCounterpartyPriceKind()

&AtServer
// The procedure adds products and services and the characteristic.
//
Procedure AddProductsAndServicesCharacteristic(ProductsAndServicesCurrent, StructureDetailing, StructureDetails, StartDate, EndDate)
	
	If StructureDetailing = Undefined Then
		Return;
	EndIf;
				
	If OnlyDeficit AND StructureDetailing.Deficit.IndicatorValue > 0 
		OR Not OnlyDeficit AND IndicatorsFilled(StructureDetailing) Then
		
		ProductsAndServicesItems = ProductsAndServicesCurrent.GetItems();
						
		// Adding the indicator values.
		OpeningBalance = ProductsAndServicesItems.Add();
		OpeningBalance.ProductsAndServices = NStr("en='Opening balance';ru='Начальные остатки по имуществу'");
		
		Receipt = ProductsAndServicesItems.Add();
		Receipt.ProductsAndServices = NStr("en='Receipt';ru='Приход'");
		
		Demand = ProductsAndServicesItems.Add();
		Demand.ProductsAndServices = NStr("en='Demand';ru='Срок годности токена'");
				
		If StructureDetailing.MinInventory = 0 AND StructureDetailing.MaxInventory = 0 Then
			
			RegulatoryInventory = Undefined;
			MaxInventory = Undefined;
			
		Else
			
			MinInventory = ProductsAndServicesItems.Add();
			MinInventory.ProductsAndServices = NStr("en='Minimum stock';ru='Минимальный запас'");
			
			MaxInventory = ProductsAndServicesItems.Add();
			MaxInventory.ProductsAndServices = NStr("en='Maximum stock';ru='Максимальный запас'");
			
		EndIf;	
		
		ClosingBalance = ProductsAndServicesItems.Add();
		ClosingBalance.ProductsAndServices = NStr("en='Closing balance';ru='Сальдо на конец периода составило'");
		
		ItemsReceipt = Receipt.GetItems();
		ItemsNeedFor = Demand.GetItems();
		
		OrdersArrayReceipt = New Array();
		OrdersArrayNeed = New Array();
		For Each RowDetails IN StructureDetails.Details Do
			For Each RowOrder IN RowDetails Do
				
				If (RowOrder.Value.Receipt <> 0 OR RowOrder.Value.ReceiptOverdue <> 0) AND OrdersArrayReceipt.Find(RowOrder.Key) = Undefined Then
					
					OrderDetails = ItemsReceipt.Add();
					OrderDetails.ProductsAndServices = RowOrder.Key;
					OrdersArrayReceipt.Add(RowOrder.Key);
					
				EndIf;	
				
				ItemsReceiptOverdue = Receipt.GetItems();
				For Each RowReceiptOutdated IN ItemsReceiptOverdue Do
						
					If RowReceiptOutdated.ProductsAndServices = RowOrder.Key Then
						
						If RowOrder.Value.ReceiptOverdue <> 0 Then
						
							RowReceiptOutdated.Overdue = RowReceiptOutdated.Overdue + RowOrder.Value.ReceiptOverdue;
							
						EndIf;	
						
						If RowOrder.Value.Receipt <> 0 Then
						
							RowReceiptOutdated[RowOrder.Value.Period] = RowReceiptOutdated[RowOrder.Value.Period] + RowOrder.Value.Receipt;
							
						EndIf;
					
						If StructureDetailing.Deficit.IndicatorValue <> 0 Then
								
							RowReceiptOutdated.Deficit = RowReceiptOutdated.Deficit + RowOrder.Value.ReceiptOverdue + RowOrder.Value.Receipt;
								
						EndIf;
						
					EndIf;	
					
				EndDo;
				
				If (RowOrder.Value.Demand <> 0 OR RowOrder.Value.NeedOverdue <> 0) AND OrdersArrayNeed.Find(RowOrder.Key) = Undefined Then
					
					OrderDetails = ItemsNeedFor.Add();
					OrderDetails.ProductsAndServices = RowOrder.Key;
					OrdersArrayNeed.Add(RowOrder.Key);
					
				EndIf;
				
				ItemsNeedForOverdue = Demand.GetItems();
				For Each StringNeedOverdue IN ItemsNeedForOverdue Do
						
					If StringNeedOverdue.ProductsAndServices = RowOrder.Key Then
						
						If RowOrder.Value.NeedOverdue <> 0 Then
						
							StringNeedOverdue.Overdue = StringNeedOverdue.Overdue + RowOrder.Value.NeedOverdue;
						
						EndIf;
						
						If RowOrder.Value.Demand <> 0 Then
						
							StringNeedOverdue[RowOrder.Value.Period] = StringNeedOverdue[RowOrder.Value.Period] + RowOrder.Value.Demand;
						    							
						EndIf;
						
						If StructureDetailing.Deficit.IndicatorValue <> 0 Then
							
							StringNeedOverdue.Deficit = StringNeedOverdue.Deficit + RowOrder.Value.NeedOverdue + RowOrder.Value.Demand;
							
						EndIf;	
						
					EndIf;	
												
				EndDo;
				
			EndDo;				
		EndDo;
		
		For Each Column in StructureDetailing Do
			
			If TypeOf(Column.Value) = Type("Structure") Then
				
				If Column.Key = "Overdue" Then
					
					OpeningBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0 OR Column.Value.Detailing.Receipt > 0 OR Column.Value.Detailing.Demand > 0, Column.Value.Detailing.OpeningBalance, 0);
					
					Receipt[Column.Key] = Column.Value.Detailing.Receipt;
					Demand[Column.Key] = Column.Value.Detailing.Demand;
					
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MinInventory, 0);
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MaxInventory, 0);
						
					EndIf;
										
					ClosingBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0 OR Column.Value.Detailing.Receipt > 0 OR Column.Value.Detailing.Demand > 0, Column.Value.Detailing.ClosingBalance, 0);
					
				ElsIf Column.Key = "Deficit" Then
					
					OpeningBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.OpeningBalance, 0);
					Receipt[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.Receipt, 0);
					Demand[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.Demand, 0);
										
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MinInventory, 0);
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MaxInventory, 0);
						
					EndIf;
									
					ClosingBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.ClosingBalance, 0);
					
				Else
					
					OpeningBalance[Column.Key] = Column.Value.Detailing.OpeningBalance;
					Receipt[Column.Key] = Column.Value.Detailing.Receipt;
					Demand[Column.Key] = Column.Value.Detailing.Demand;
					
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = Column.Value.Detailing.MinInventory;
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = Column.Value.Detailing.MaxInventory;
						
					EndIf;
										
					ClosingBalance[Column.Key] = Column.Value.Detailing.ClosingBalance;
					
				EndIf;
				
				ProductsAndServicesCurrent[Column.Key] = Column.Value.IndicatorValue;
												
				// Setting the formatting variant.
				ProductsAndServicesCurrent["VariantRegistration" + Column.Key] = ?(StructureDetailing[Column.Key].IndicatorValue > 0, ?(StructureDetailing[Column.Key].Overdue, 2, 1), 0);
				ProductsAndServicesCurrent.VariantProductsAndServicesDesignCharacteristic = Max(ProductsAndServicesCurrent.VariantProductsAndServicesDesignCharacteristic, ProductsAndServicesCurrent["VariantRegistration" + Column.Key]);
				
			Else
				
				ProductsAndServicesCurrent[Column.Key] = Column.Value;
				
			EndIf;
			
		EndDo;
				
	EndIf;
	
	StructureDetailing = Undefined;
	
EndProcedure // AddProductsAndServicesCharacteristic()	

&AtServer
// The function checks the completion of detailed data.
//
Function IndicatorsFilled(NewProductsAndServicesCharacteristic)
	
	IndicatorsFilled = False;
	
	For Each Column in NewProductsAndServicesCharacteristic Do
		
		If TypeOf(Column.Value) = Type("Structure") Then
			
			If Column.Value.Detailing.OpeningBalance <> 0
				OR Column.Value.Detailing.Receipt <> 0
				OR Column.Value.Detailing.Demand <> 0
				OR Column.Value.Detailing.MinInventory <> 0
				OR Column.Value.Detailing.MaxInventory <> 0
				OR Column.Value.Detailing.ClosingBalance <> 0 Then
				
				IndicatorsFilled = True;
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return IndicatorsFilled;
	
EndFunction // IndicatorsCompleted()

&AtServer
// The procedure calculates the inventory transfer schedule.
//
Procedure CalculateInventoryTransferSchedule(TableQueryResult)
	
	For Each RowResultQuery IN TableQueryResult Do
		
		If RowResultQuery.OrderBalance <= 0 Then
			Continue;
		EndIf;
		
		CountOrderBalance 			= RowResultQuery.OrderBalance;
		QuantityBalanceReceipt 	= RowResultQuery.OrderBalance;
		QuantityBalanceNeedFor 	= RowResultQuery.OrderBalance;
		
		SearchStructure = New Structure();
		SearchStructure.Insert("ProductsAndServices", RowResultQuery.ProductsAndServices);
		SearchStructure.Insert("Characteristic", RowResultQuery.Characteristic);
		SearchStructure.Insert("Order", RowResultQuery.Order);
		
		ResultOrders = TableQueryResult.FindRows(SearchStructure);
		For Each OrdersString IN ResultOrders Do
			
			// The supplies are overdue.
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Receipt Then
				
				QuantityBalanceReceipt = QuantityBalanceReceipt - OrdersString.Receipt;
				
			EndIf;
			
			If OrdersString.Receipt <> 0 Then
	
				// Receipt.
				Receipt = min(CountOrderBalance, OrdersString.Receipt);
				CountOrderBalance = CountOrderBalance - OrdersString.Receipt;
				OrdersString.Receipt = Receipt;
				
			EndIf;
			
			// The demand is overdue.
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Shipment Then
				
				QuantityBalanceNeedFor = QuantityBalanceNeedFor - OrdersString.Demand;
				
			EndIf;
			
			If OrdersString.Demand <> 0 Then
				
				// Demand.
				Demand = min(CountOrderBalance, OrdersString.Demand);
				CountOrderBalance = CountOrderBalance - OrdersString.Demand;
				OrdersString.Demand = Demand;
				
			EndIf;
			
			OrdersString.OrderBalance = 0;
			
		EndDo;
		
		For Each OrdersString IN ResultOrders Do
			
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Receipt Then
				
				If QuantityBalanceReceipt > 0 Then
					OrdersString.ReceiptOverdue = QuantityBalanceReceipt;
					QuantityBalanceReceipt = 0;
				EndIf;
				
			EndIf;
			
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Shipment Then
				
				If QuantityBalanceNeedFor > 0 Then
					OrdersString.NeedOverdue = QuantityBalanceNeedFor;
					QuantityBalanceNeedFor = 0;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure // CalculateInventoryTransferSchedule()

&AtServer
// The procedure adds the decryption for the order.
//
Procedure AddDrillDownByOrder(TableQueryResult, TableLineNeeds)
	
	TableLineNeeds.Columns.Add("OrderDetails");
	
	NewRow = Undefined;
	PreviousRecordPeriod = Undefined;
	ProductsAndServicesPreviousRecord = Undefined;
	PreviousRecordCharacteristic = Undefined;
	For Each RowQueryResult IN TableQueryResult Do
		
		If RowQueryResult.Period = PreviousRecordPeriod
			AND RowQueryResult.ProductsAndServices = ProductsAndServicesPreviousRecord 
			AND RowQueryResult.Characteristic = PreviousRecordCharacteristic Then
			
			IndicatorsStructure = New Structure;
			IndicatorsStructure.Insert("Period", "Period" + Format(RowQueryResult.Period, "DF=yyyyMMdd"));
			IndicatorsStructure.Insert("Receipt", RowQueryResult.Receipt);
			IndicatorsStructure.Insert("ReceiptOverdue", RowQueryResult.ReceiptOverdue);
			IndicatorsStructure.Insert("Demand", RowQueryResult.Demand);
			IndicatorsStructure.Insert("NeedOverdue", RowQueryResult.NeedOverdue);
			
			CorrespondenceNewRow = NewRow.OrderDetails;
			CorrespondenceNewRow.Insert(RowQueryResult.Order, IndicatorsStructure);
			NewRow.OrderDetails = CorrespondenceNewRow; 
			
			NewRow.Receipt = NewRow.Receipt + RowQueryResult.Receipt;
			NewRow.ReceiptOverdue = NewRow.ReceiptOverdue + RowQueryResult.ReceiptOverdue;
			
			NewRow.Demand = NewRow.Demand + RowQueryResult.Demand;
			NewRow.NeedOverdue = NewRow.NeedOverdue + RowQueryResult.NeedOverdue;
			
		Else
			
			NewRow = TableLineNeeds.Add();
			FillPropertyValues(NewRow, RowQueryResult);
			
			IndicatorsStructure = New Structure;
			IndicatorsStructure.Insert("Period", "Period" + Format(RowQueryResult.Period, "DF=yyyyMMdd"));
			IndicatorsStructure.Insert("Receipt", RowQueryResult.Receipt);
			IndicatorsStructure.Insert("ReceiptOverdue", RowQueryResult.ReceiptOverdue);
			IndicatorsStructure.Insert("Demand", RowQueryResult.Demand);
			IndicatorsStructure.Insert("NeedOverdue", RowQueryResult.NeedOverdue);
			
			OrderDetailsMap = New Map;
			OrderDetailsMap.Insert(RowQueryResult.Order, IndicatorsStructure); 
			
			NewRow.OrderDetails = OrderDetailsMap;
			
			PreviousRecordPeriod = RowQueryResult.Period;
			ProductsAndServicesPreviousRecord = RowQueryResult.ProductsAndServices;
			PreviousRecordCharacteristic = RowQueryResult.Characteristic;
			
		EndIf;
		
	EndDo;
	
	TableQueryResult = Undefined;
	
EndProcedure // AddDecryptionByOrder()

&AtServer
// Procedure of data processing and demand diagram output to the form.
//
Procedure UpdateRecommendationsAtServer()
	
	// Clearing the result before update.
	RecommendationsItems = Recommendations.GetItems();
	RecommendationsItems.Clear();
	
	TSInventory = GetFromTempStorage(AddressInventory);
	
	DataSource = New ValueTable;
	DataSource.Columns.Add("RowIndex", New TypeDescription("Number"));
	DataSource.Columns.Add("ProductsAndServices", New TypeDescription("CatalogRef.ProductsAndServices"));
	DataSource.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics"));
	DataSource.Columns.Add("Vendor", New TypeDescription("CatalogRef.Counterparties"));
	DataSource.Columns.Add("ReplenishmentMethod", New TypeDescription("EnumRef.InventoryReplenishmentMethods"));
	DataSource.Columns.Add("ReplenishmentDeadline", New TypeDescription("Number"));
	DataSource.Columns.Add("ReplenishmentMethodPrecision", New TypeDescription("Number"));
	DataSource.Columns.Add("Quantity", New TypeDescription("Number"));
	DataSource.Columns.Add("ReceiptDate", New TypeDescription("Date"));
	
	RowIndex = 0;
	
	For Each ProductsAndServices IN TSInventory.Rows Do
		
		If ProductsAndServices.Deficit > 0 Then
			
			CurrentPeriod = BegOfDay(CurrentDate());
		
			While BegOfDay(CurrentPeriod) <= BegOfDay(EndOfPeriod) Do
				
				ColumnName = "Period" + Format(CurrentPeriod, "DF=yyyyMMdd");
				
				If ProductsAndServices[ColumnName] > 0 OR ProductsAndServices.Overdue > 0 AND CurrentPeriod = BegOfDay(CurrentDate()) Then
					
					NewRow = DataSource.Add();
					NewRow.RowIndex = RowIndex;
					NewRow.ProductsAndServices = ProductsAndServices.ProductsAndServices;
					NewRow.Characteristic = ProductsAndServices.Characteristic;
					NewRow.Vendor = ProductsAndServices.ProductsAndServices.Vendor;
					NewRow.ReplenishmentMethod = ProductsAndServices.ProductsAndServices.ReplenishmentMethod;
					NewRow.ReplenishmentDeadline = ProductsAndServices.ProductsAndServices.ReplenishmentDeadline;
					NewRow.ReplenishmentMethodPrecision = 1;
					
					If CurrentPeriod = BegOfDay(CurrentDate()) Then
						
						NewRow.Quantity = ProductsAndServices[ColumnName] + ProductsAndServices.Overdue;
						
					Else
						
						NewRow.Quantity = ProductsAndServices[ColumnName];
						
					EndIf;
					
					NewRow.ReceiptDate = CurrentPeriod;
					
					If NewRow.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
						
						If Constants.FunctionalOptionUseSubsystemProduction.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
							
						EndIf;
						
						If Constants.FunctionalOptionTransferRawMaterialsForProcessing.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
							
						EndIf;
						
					ElsIf NewRow.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then	
						
						NewReplenishmentMethod = DataSource.Add();
						FillPropertyValues(NewReplenishmentMethod, NewRow);
						NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
						NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
						
						If Constants.FunctionalOptionTransferRawMaterialsForProcessing.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
							
						EndIf;
						
					Else
						
						NewReplenishmentMethod = DataSource.Add();
						FillPropertyValues(NewReplenishmentMethod, NewRow);
						NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
						NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
						
						If Constants.FunctionalOptionUseSubsystemProduction.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
							
						EndIf;
						
					EndIf;
					
					RowIndex = RowIndex + 1;
					
				EndIf;
				
				CurrentPeriod = CurrentPeriod + 86400;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If DataSource.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DataSource.RowIndex AS RowIndex,
	|	DataSource.ReplenishmentMethodPrecision AS ReplenishmentMethodPrecision,
	|	DataSource.ProductsAndServices AS ProductsAndServices,
	|	DataSource.Characteristic AS Characteristic,
	|	DataSource.Vendor AS Vendor,
	|	DataSource.ReplenishmentMethod AS ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline AS ReplenishmentDeadline,
	|	DataSource.Quantity AS Quantity,
	|	DataSource.ReceiptDate AS ReceiptDate
	|INTO DataSource
	|FROM
	|	&DataSource AS DataSource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TableCounterpartyPrices.ProductsAndServices AS ProductsAndServices,
	|	TableCounterpartyPrices.Characteristic AS Characteristic,
	|	CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind AS PriceKind,
	|	CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind.Owner AS Vendor,
	|	CounterpartyProductsAndServicesPricesSliceLast.CounterpartyPriceKind.PriceCurrency AS PriceCurrency,
	|	ISNULL(CounterpartyProductsAndServicesPricesSliceLast.Price / ISNULL(CounterpartyProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|INTO DataSourcePricesCounterparties
	|FROM
	|	DataSource AS TableCounterpartyPrices
	|		LEFT JOIN InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|				&ProcessingDate,
	|				(ProductsAndServices, Characteristic) In
	|					(SELECT
	|						DataSource.ProductsAndServices AS ProductsAndServices,
	|						DataSource.Characteristic AS Characteristic
	|					FROM
	|						DataSource AS DataSource)) AS CounterpartyProductsAndServicesPricesSliceLast
	|		ON TableCounterpartyPrices.ProductsAndServices = CounterpartyProductsAndServicesPricesSliceLast.ProductsAndServices
	|			AND TableCounterpartyPrices.Characteristic = CounterpartyProductsAndServicesPricesSliceLast.Characteristic
	|WHERE
	|	CounterpartyProductsAndServicesPricesSliceLast.Actuality
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DataSource.RowIndex AS RowIndex,
	|	DataSource.ReplenishmentMethodPrecision AS ReplenishmentMethodPrecision,
	|	DataSource.ProductsAndServices AS ProductsAndServices,
	|	DataSource.Characteristic AS Characteristic,
	|	DataSource.Vendor AS Vendor,
	|	DataSource.ReplenishmentMethod AS ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline AS ReplenishmentDeadline,
	|	DataSource.Quantity AS Quantity,
	|	DataSource.ReceiptDate AS ReceiptDate,
	|	DataSourcePricesCounterparties.PriceKind AS PriceKind,
	|	DataSourcePricesCounterparties.PriceCurrency AS PriceCurrency,
	|	ISNULL(DataSourcePricesCounterparties.Price, 0) AS Price
	|FROM
	|	DataSource AS DataSource
	|		LEFT JOIN DataSourcePricesCounterparties AS DataSourcePricesCounterparties
	|		ON DataSource.Vendor = DataSourcePricesCounterparties.Vendor
	|			AND DataSource.ProductsAndServices = DataSourcePricesCounterparties.ProductsAndServices
	|			AND DataSource.Characteristic = DataSourcePricesCounterparties.Characteristic
	|			AND (DataSource.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DataSource.RowIndex,
	|	DataSource.ReplenishmentMethodPrecision,
	|	DataSource.ProductsAndServices,
	|	DataSource.Characteristic,
	|	DataSourcePricesCounterparties.Vendor,
	|	DataSource.ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline,
	|	DataSource.Quantity,
	|	DataSource.ReceiptDate,
	|	DataSourcePricesCounterparties.PriceKind,
	|	DataSourcePricesCounterparties.PriceCurrency,
	|	ISNULL(DataSourcePricesCounterparties.Price, 0)
	|FROM
	|	DataSource AS DataSource
	|		LEFT JOIN DataSourcePricesCounterparties AS DataSourcePricesCounterparties
	|		ON DataSource.Vendor <> DataSourcePricesCounterparties.Vendor
	|			AND DataSource.ProductsAndServices = DataSourcePricesCounterparties.ProductsAndServices
	|			AND DataSource.Characteristic = DataSourcePricesCounterparties.Characteristic
	|			AND (DataSource.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase))
	|WHERE
	|	ISNULL(DataSourcePricesCounterparties.Price, 0) <> 0
	|
	|ORDER BY
	|	RowIndex,
	|	ReplenishmentMethodPrecision,
	|	Order,
	|	PriceKind");
	
	Query.SetParameter("DataSource", DataSource);
	Query.SetParameter("ProcessingDate", BegOfDay(CurrentDate()));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	ProductsAndServicesItems = Recommendations.GetItems();
	
	RowCurrentIndex = Undefined;
	While Selection.Next() Do

		// 1. Adding products and services.
		If RowCurrentIndex <> Selection.RowIndex Then
			
			RowCurrentIndex = Selection.RowIndex;
			
			NewProductsAndServices = ProductsAndServicesItems.Add();
			NewProductsAndServices.ProductsAndServices = Selection.ProductsAndServices;
			NewProductsAndServices.CharacteristicInventoryReplenishmentSource = Selection.Characteristic;
			NewProductsAndServices.Quantity = Selection.Quantity;
			NewProductsAndServices.ReceiptDate = Selection.ReceiptDate;
			NewProductsAndServices.ReceiptDateExpired = True;
			
			NewProductsAndServices.EditAllowed = False;
			
		EndIf;
		
		// 2. Adding replenishment method and prices.
		ReplenishmentMethodItems = NewProductsAndServices.GetItems();
		NewReplenishmentMethod = ReplenishmentMethodItems.Add();
		
		If Selection.ReplenishmentMethodPrecision = 1 Then
			NewReplenishmentMethod.ProductsAndServices = String(Selection.ReplenishmentMethod) + " " + "(Default)";
		Else
			NewReplenishmentMethod.ProductsAndServices = String(Selection.ReplenishmentMethod);
		EndIf;
		
		NewReplenishmentMethod.ReplenishmentMethod = Selection.ReplenishmentMethod;
		
		NewReplenishmentMethod.Quantity = Selection.Quantity;
		NewReplenishmentMethod.ReceiptDate =  Max(BegOfDay(CurrentDate()) + Selection.ReplenishmentDeadline * 86400, Selection.ReceiptDate);
		NewReplenishmentMethod.ReceiptDateExpired = NewReplenishmentMethod.ReceiptDate > Selection.ReceiptDate;
		NewReplenishmentMethod.EditAllowed = True;
		
		If Selection.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
			
			NewReplenishmentMethod.CharacteristicInventoryReplenishmentSource = Selection.Vendor;
			NewReplenishmentMethod.Price = Selection.Price;
			NewReplenishmentMethod.Amount = Selection.Price * Selection.Quantity;
			NewReplenishmentMethod.Currency = Selection.PriceCurrency;
			NewReplenishmentMethod.PriceKind = Selection.PriceKind;
			
		EndIf;
		
		// 3. Formatting parameters.
		If Not NewReplenishmentMethod.ReceiptDateExpired Then
			
			NewProductsAndServices.ReceiptDateExpired = False;
			NewProductsAndServices.DemandClosed = True;
			
			If Not NewProductsAndServices.Selected Then
				
				NewReplenishmentMethod.Selected = True;
				NewProductsAndServices.Selected = True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	DataSource = Undefined;
	
EndProcedure // UpdateRecommendationsOnServer()

&AtServer
// The procedure of data processing and orders generation.
//
Procedure GenerateOrdersAtServer()
	
	TableOrders = New ValueTable;
	TableOrders.Columns.Add("ReplenishmentMethod", New TypeDescription("EnumRef.InventoryReplenishmentMethods"));
	TableOrders.Columns.Add("Counterparty", New TypeDescription("CatalogRef.Counterparties"));
	TableOrders.Columns.Add("PriceKind", New TypeDescription("CatalogRef.CounterpartyPriceKind"));
	TableOrders.Columns.Add("Currency", New TypeDescription("CatalogRef.Currencies"));
	TableOrders.Columns.Add("ProductsAndServices", New TypeDescription("CatalogRef.ProductsAndServices"));
	TableOrders.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics"));
	TableOrders.Columns.Add("ReceiptDate", New TypeDescription("Date"));
	TableOrders.Columns.Add("Quantity", New TypeDescription("Number"));
	TableOrders.Columns.Add("Price", New TypeDescription("Number"));
	TableOrders.Columns.Add("Amount", New TypeDescription("Number"));
	TableOrders.Columns.Add("Order", New TypeDescription("DocumentObject.ProductionOrder, DocumentObject.PurchaseOrder"));
	
	RecommendationsProductsAndServices = Recommendations.GetItems();
	For Each RecommendationRow in RecommendationsProductsAndServices Do
		
		RecommendationsItems = RecommendationRow.GetItems();
		
		For Each StringProductsAndServices in RecommendationsItems Do
			
			If StringProductsAndServices.Selected Then
				
				NewRow = TableOrders.Add();
				NewRow.ReplenishmentMethod = StringProductsAndServices.ReplenishmentMethod;
				NewRow.Counterparty = StringProductsAndServices.CharacteristicInventoryReplenishmentSource;
				NewRow.PriceKind = StringProductsAndServices.PriceKind;
				NewRow.Currency = StringProductsAndServices.Currency;
				NewRow.ProductsAndServices = RecommendationRow.ProductsAndServices;
				NewRow.Characteristic = RecommendationRow.CharacteristicInventoryReplenishmentSource;
				NewRow.ReceiptDate = StringProductsAndServices.ReceiptDate;
				NewRow.Quantity = StringProductsAndServices.Quantity;
				NewRow.Price = StringProductsAndServices.Price;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	ReceiptDateInHead = SmallBusinessReUse.AttributeInHeader("ReceiptDatePositionInPurchaseOrder");
	
	DocumentCurrencyDefault = Constants.NationalCurrency.Get();
	DataCurrency = WorkWithCurrencyRates.FillRateDataForCurrencies(DocumentCurrencyDefault);
	ExchangeRateDocumentDefault = DataCurrency.ExchangeRate;
	RepetitionDocumentDefault = DataCurrency.Multiplicity;
	
	For Each OrderParameters in TableOrders Do
		
		// Create the purchase orders.
		If OrderParameters.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase
			OR OrderParameters.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing Then
			
			SearchStructure = New Structure("ReplenishmentMethod, Counterparty, Currency, Order", OrderParameters.ReplenishmentMethod, OrderParameters.Counterparty, OrderParameters.Currency, Undefined);
			
			If ReceiptDateInHead Then
				SearchStructure.Insert("ReceiptDate", OrderParameters.ReceiptDate);
			EndIf;
			
			SearchResult = TableOrders.FindRows(SearchStructure);
			
			If SearchResult.Count() = 0 Then
				Continue;
			EndIf;
			
			CurrentOrder = Documents.PurchaseOrder.CreateDocument();
			CurrentOrder.Date = CurrentDate();
			
			CurrentOrder.Fill(Undefined);
			
			If OrderParameters.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
				CurrentOrder.OperationKind = Enums.OperationKindsPurchaseOrder.OrderForPurchase;
			Else
				CurrentOrder.OperationKind = Enums.OperationKindsPurchaseOrder.OrderForProcessing;
			EndIf;
			
			SmallBusinessServer.FillDocumentHeader(CurrentOrder,,,, True, );
			
			CurrentOrder.Company = Company;
			CurrentOrder.DocumentCurrency = DocumentCurrencyDefault;
			CurrentOrder.ExchangeRate = ExchangeRateDocumentDefault;
			CurrentOrder.Multiplicity = RepetitionDocumentDefault;
			
			CurrentOrder.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
			CurrentOrder.AmountIncludesVAT = True;
			
			CurrentOrder.Counterparty = OrderParameters.Counterparty;
			ContractByDefault = CurrentOrder.Counterparty.ContractByDefault;
			
			If Not ValueIsFilled(OrderParameters.Currency) Then
				
				CurrentOrder.Contract = ContractByDefault;
				
			Else
				
				If OrderParameters.Currency = ContractByDefault.SettlementsCurrency Then
					
					CurrentOrder.Contract = ContractByDefault;
					
				Else
					
					CurrentOrder.Contract = Catalogs.CounterpartyContracts.EmptyRef();
					
					CurrentOrder.DocumentCurrency = OrderParameters.Currency;
					DataCurrency = WorkWithCurrencyRates.FillRateDataForCurrencies(CurrentOrder.DocumentCurrency);
					CurrentOrder.ExchangeRate = DataCurrency.ExchangeRate;
					CurrentOrder.Multiplicity = DataCurrency.Multiplicity;
					
				EndIf;
				
			EndIf;
			
			CurrentOrder.CounterpartyPriceKind = CurrentOrder.Contract.CounterpartyPriceKind;
			
			If ValueIsFilled(CurrentOrder.Contract) AND Not CurrentOrder.Contract.SettlementsCurrency = CurrentOrder.DocumentCurrency Then
				
				CurrentOrder.DocumentCurrency = CurrentOrder.Contract.SettlementsCurrency;
				DataCurrency = WorkWithCurrencyRates.FillRateDataForCurrencies(CurrentOrder.DocumentCurrency);
				CurrentOrder.ExchangeRate = DataCurrency.ExchangeRate;
				CurrentOrder.Multiplicity = DataCurrency.Multiplicity;
				
			EndIf;
			
			If ReceiptDateInHead Then
				CurrentOrder.ReceiptDate = OrderParameters.ReceiptDate;
			EndIf;
			
			For Each ResultRow in SearchResult Do
				
				NewRow = CurrentOrder.Inventory.Add();
				NewRow.ProductsAndServices = ResultRow.ProductsAndServices;
				NewRow.Characteristic = ResultRow.Characteristic;
				NewRow.Quantity = ResultRow.Quantity;
				NewRow.MeasurementUnit = NewRow.ProductsAndServices.MeasurementUnit;
				
				If ValueIsFilled(NewRow.ProductsAndServices.VATRate) Then
					NewRow.VATRate = NewRow.ProductsAndServices.VATRate;
				Else
					NewRow.VATRate = Company.DefaultVATRate;
				EndIf;
				
				If ValueIsFilled(OrderParameters.PriceKind) Then
					
					NewRow.Price = ResultRow.Price;
					
					VATRate = SmallBusinessReUse.GetVATRateValue(NewRow.VATRate);
					If Not ResultRow.PriceKind.PriceIncludesVAT Then
						NewRow.Price = (NewRow.Price * (100 + VATRate)) / 100;
					EndIf;
					
					NewRow.Amount = NewRow.Price * NewRow.Quantity;
					NewRow.VATAmount = NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100);
					NewRow.Total = NewRow.Amount;
					
				EndIf;
				
				NewRow.ReceiptDate = ResultRow.ReceiptDate;
				
				ResultRow.Order = CurrentOrder;
				
			EndDo;
			
		Else // We will create orders for production.
			
			SearchStructure = New Structure("ReplenishmentMethod, Order", OrderParameters.ReplenishmentMethod, Undefined);
			
			SearchResult = TableOrders.FindRows(SearchStructure);
			
			If SearchResult.Count() = 0 Then
				Continue;
			EndIf;
			
			CurrentOrder = Documents.ProductionOrder.CreateDocument();
			CurrentOrder.Date = CurrentDate();
			
			CurrentOrder.OperationKind = Enums.OperationKindsProductionOrder.Assembly;
			
			SmallBusinessServer.FillDocumentHeader(CurrentOrder,,,, True, );
			
			CurrentOrder.Company = Company;
			CurrentOrder.Start = OrderParameters.ReceiptDate - 86400 * OrderParameters.ProductsAndServices.ReplenishmentDeadline;
			CurrentOrder.Finish = OrderParameters.ReceiptDate;
			
			For Each ResultRow in SearchResult Do
				
				NewRow = CurrentOrder.Products.Add();
				NewRow.ProductsAndServices = ResultRow.ProductsAndServices;
				NewRow.Characteristic = ResultRow.Characteristic;
				NewRow.Quantity = ResultRow.Quantity;
				NewRow.MeasurementUnit = NewRow.ProductsAndServices.MeasurementUnit;
				NewRow.Specification = SmallBusinessServer.GetDefaultSpecification(NewRow.ProductsAndServices, NewRow.Characteristic);
				
				ResultRow.Order = CurrentOrder;
				
			EndDo;
			
			FillingData = New Structure("DemandPlanning", True);
			CurrentOrder.Fill(FillingData);
			
		EndIf;
		
		CurrentOrder.Comment = NStr("en='Automatically generated by ""Inventory demand planning"" service.';ru='Сформирован автоматически сервисом ""Расчет потребностей в запасах"".'");
		
		CurrentOrder.Write();
		GeneratedOrder = Orders.Add();
		GeneratedOrder.Order = CurrentOrder.Ref;
		GeneratedOrder.DefaultPicture = 0;
		
	EndDo;
	
EndProcedure // GenerateOrdersOnServer()

&AtServerNoContext
// The function returns the result of posting.
//
Function OrdersPostAtServer(OrdersForPosting)
	
	PostingResults = New Array;
	
	For Each OrderForPosting in OrdersForPosting Do
	
		OrderObject = OrderForPosting.Ref.GetObject();
		
		If Not OrderObject.DeletionMark Then
			
			If OrderObject.CheckFilling() Then
			
				Try
					
					OrderObject.Write(DocumentWriteMode.Posting);
					PostingResults.Add(OrderForPosting.IndexOf);
					
				Except
				EndTry;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return PostingResults;
	
EndFunction // OrdersPostOnServer()

&AtServerNoContext
// The function returns the result of posting cancellation.
//
Function OrdersUndoPostingAtServer(OrdersForUndoPosting)
	
	UndoPostingResults = New Array;
	
	For Each OrderForUndoPosting in OrdersForUndoPosting Do
	
		OrderObject = OrderForUndoPosting.Ref.GetObject();
		
		If Not OrderObject.DeletionMark Then
			
			Try
				
				OrderObject.Write(DocumentWriteMode.UndoPosting);
				UndoPostingResults.Add(OrderForUndoPosting.IndexOf);
				
			Except
			EndTry;
			
		EndIf;
		
	EndDo;
	
	Return UndoPostingResults;
	
EndFunction // OrdersUndoPostingOnServer()

&AtServerNoContext
// The function returns the result of deletion mark.
//
Function OrdersMarkToDeleteAtServer(OrdersForMarkToDelete)
	
	MarkToDeleteResults = New Array;
	
	For Each OrderForMarkToDelete in OrdersForMarkToDelete Do
	
		OrderObject = OrderForMarkToDelete.Ref.GetObject();
		
		Try
			
			OrderObject.SetDeletionMark(NOT OrderObject.DeletionMark);
			MarkToDeleteResults.Add(OrderForMarkToDelete.IndexOf);
			
		Except
		EndTry;
			
	EndDo;
	
	Return MarkToDeleteResults;
	
EndFunction // OrdersMarkToDeleteOnServer()

&AtServer
// Procedure sets conditional design.
//
Procedure SetConditionalAppearance(BeginOfPeriod, EndOfPeriod)
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem IN ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item IN ListOfItemsForDeletion Do
		ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	// Products and services and the characteristic are displayed in bold.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryProductsAndServices");
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryCharacteristic");
	
	FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsAndServicesCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 1;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsAndServicesCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 4;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Deficit is highlighted in bold.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryDeficit");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantDeficit");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 1;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Negative in the deficit is highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryDeficit");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Deficit");
	FilterItem.ComparisonType = DataCompositionComparisonType.Less;
	FilterItem.RightValue = 0;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	
	// Overdue items are highlighted in bold.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantOverdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 1;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Negative overdue is highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Overdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Less;
	FilterItem.RightValue = 0;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	
	// Products and services and the characteristic are displayed in bold and highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryProductsAndServices");
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryCharacteristic");
	
	FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsAndServicesCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 2;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsAndServicesCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 5;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Deficit is highlighted in bold and color.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryDeficit");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantDeficit");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 2;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Overdue items are highlighted in bold and color.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantOverdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 2;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Decryption overdue is displayed in the background color.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Overdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
	FilterItem.RightValue = 0;
	
	FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.ProductsAndServices");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = NStr("en='Receipt';ru='Приход'");
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.ProductsAndServices");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = NStr("en='Demand';ru='Срок годности токена'");
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.LightGray);
	
	CurrentPeriod = BeginOfPeriod;
	
	While BegOfDay(CurrentPeriod) <= BegOfDay(EndOfPeriod) Do
		
		// The period is bold.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 1;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 4;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
		
		// Negative in the period is highlighted.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Period" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Less;
		FilterItem.RightValue = 0;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
		
		// The period is highlighted in bold and color.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 2;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 5;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
		
		// Weekends are displayed in the background color.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
		FilterItem.RightValue = 2;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.CornSilk);
		
		// Decryption of the period is displayed in the background color.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Period" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
		FilterItem.RightValue = 0;
		
		FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.ProductsAndServices");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = NStr("en='Receipt';ru='Приход'");
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.ProductsAndServices");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = NStr("en='Demand';ru='Срок годности токена'");
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.LightGray);
		
		CurrentPeriod = CurrentPeriod + 86400;
		
	EndDo;
	
EndProcedure // SetConditionalAppearance()

// The procedure forms the period of demand generation.
//
&AtClient
Procedure GenerateDemandPeriod()
	
	CalendarDateBegin = BegOfDay(BegOfDay(CurrentDate()));
	CalendarDateEnd = EndOfDay(EndOfPeriod);
	
	If Month(CalendarDateBegin) = Month(CalendarDateEnd) Then
		
		DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
		WeekDayOfScheduleBegin = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
		DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
		WeekDayOfScheduleEnd = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
		
		MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
		YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
		
		PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfSchedule + ", " + YearOfSchedule;
		
	Else
		
		DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
		WeekDayOfScheduleBegin = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
		MonthOfScheduleBegin = Format(CalendarDateBegin, "DF=MMM");
		DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
		WeekDayOfScheduleEnd = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateEnd);
		MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
		
		If Year(CalendarDateBegin) = Year(CalendarDateEnd) Then
			YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
			PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
		Else
			YearOfScheduleBegin = Format(Year(CalendarDateBegin), "NG=0");
			YearOfScheduleEnd = Format(Year(CalendarDateEnd), "NG=0");
			PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
			
		EndIf;
		
	EndIf;
	
EndProcedure // GenerateDemandPeriod()

// The procedure updates the state of the orders (posted, recorded, marked for deletion) in TS Orders
//
&AtServer
Procedure UpdateStateOrdersAtServer()
	
	For Each OrderRow IN Orders Do
		
		CurrentOrder = OrderRow.Order;
		
		If CurrentOrder.Posted Then
			OrderRow.DefaultPicture = 1;
		ElsIf CurrentOrder.DeletionMark Then
			OrderRow.DefaultPicture = 2;
		Else
			OrderRow.DefaultPicture = 0;
		EndIf;
		
	EndDo
	
EndProcedure // UpdateOrdersStateOnServer()

/////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// The procedure is called when clicking "Update" on the command panel of the form.
//
Procedure Refresh(Command)
	
	If Not ValueIsFilled(Company) Then
		Message = New UserMessage();
		Message.Text = NStr("en='Company Is Not Selected!';ru='Не выбрана организация!'");
		Message.Field = "Company";
		Message.Message();
		Return;
	EndIf;
	
	UpdateAtServer();
	
EndProcedure // Refresh()

&AtClient
// The procedure is called when clicking "Setup" on the command panel of the form.
//
Procedure Setting(Command)
	
	FormParameters = New Structure();
	FormParameters.Insert("SchemaURLCompositionData", SchemaURLCompositionData);
	FormParameters.Insert("FilterSettingComposer", SettingsComposer);
	
	Notification = New NotifyDescription("SettingsEnd", ThisForm);
	OpenForm("DataProcessor.DemandPlanning.Form.FormSetting", FormParameters,,,,, Notification);
	
EndProcedure // Setting()

&AtClient
Procedure SettingsEnd(ReturnStructure, Parameters) Export
	
	If TypeOf(ReturnStructure) = Type("Structure") Then
		SettingsComposer.LoadSettings(ReturnStructure.SettingsComposer.Settings);
		SettingsComposer.LoadUserSettings(ReturnStructure.SettingsComposer.UserSettings);
		SettingsComposer.LoadFixedSettings(ReturnStructure.SettingsComposer.FixedSettings);
	EndIf;
	
EndProcedure // SettingsEnd()

&AtClient
// The procedure is called when clicking "GenerateOrders" on the command panel of the form.
//
Procedure GenerateOrders(Command)
	
	GenerateOrdersAtServer();
	
EndProcedure // GenerateOrders()

&AtClient
// The procedure is called when clicking "Post" on the command panel of the form.
//
Procedure OrdersPost(Command)
	
	OrdersArray = New Array;
	
	For Each SelectedRow in Items.Orders.SelectedRows Do
		
		OrdersArray.Add(New Structure("Index, Ref", SelectedRow, Orders.Get(SelectedRow).Order));
		
	EndDo;
	
	PostingResults = OrdersPostAtServer(OrdersArray);
	
	For Each PostingResult in PostingResults Do
		
		Orders.Get(PostingResult).DefaultPicture = 1;
		
	EndDo;
	
EndProcedure // OrdersPost()

&AtClient
// The procedure is called when clicking "UndoPost" on the command panel of the form.
//
Procedure OrdersUndoPosting(Command)
	
	OrdersArray = New Array;
	
	For Each SelectedRow in Items.Orders.SelectedRows Do
		
		OrdersArray.Add(New Structure("Index, Ref", SelectedRow, Orders.Get(SelectedRow).Order));
		
	EndDo;
	
	UndoPostingResults = OrdersUndoPostingAtServer(OrdersArray);
	
	For Each UndoPostingResult in UndoPostingResults Do
		
		Orders.Get(UndoPostingResult).DefaultPicture = 0;
		
	EndDo;
	
EndProcedure // OrdersUndoPosting()

&AtClient
// The procedure is called when clicking "MarkToDelete" on the command panel of the form.
//
Procedure OrdersMarkToDelete(Command)
	
	OrdersArray = New Array;
	
	For Each SelectedRow in Items.Orders.SelectedRows Do
		
		OrdersArray.Add(New Structure("Index, Ref", SelectedRow, Orders.Get(SelectedRow).Order));
		
	EndDo;
	
	MarkToDeleteResults = OrdersMarkToDeleteAtServer(OrdersArray);
	
	For Each MarkToDeleteResult in MarkToDeleteResults Do
		
		If Orders.Get(MarkToDeleteResult).DefaultPicture = 2 Then
			
			Orders.Get(MarkToDeleteResult).DefaultPicture = 0;
			
		Else
			
			Orders.Get(MarkToDeleteResult).DefaultPicture = 2;
			
		EndIf;
		
	EndDo;
	
EndProcedure // OrdersMarkToDelete()

&AtClient
// The procedure is called when clicking "Reread" on the command panel of the form.
//
Procedure Reread(Command)
	
	If ThisForm.Modified Then
		
		QuestionStr = NStr("en='Data was changed. Reread data?';ru='Данные изменены. Перечитать данные?'");
		Notification = New NotifyDescription("RereadCompletion",ThisForm);
		ShowQueryBox(Notification,QuestionStr,QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	UpdateRecommendationsAtServer();
	
EndProcedure // Reread()

&AtClient
Procedure RereadCompletion(Result,Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		UpdateRecommendationsAtServer();
	EndIf;
	
EndProcedure

&AtClient
// The procedure is called when clicking "OpenProductsAndServices" on the command panel Inventory.
//
Procedure InventoryOpenProductsAndServices(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TabularSectionRow <> Undefined Then
		
		While True Do
			
			If TypeOf(TabularSectionRow.ProductsAndServices) = Type("CatalogRef.ProductsAndServices") Then
				OpenForm("Catalog.ProductsAndServices.Form.ItemForm", New Structure("Key", TabularSectionRow.ProductsAndServices));
				Break;
			Else
				TabularSectionRow = TabularSectionRow.GetParent();
				If TabularSectionRow = Undefined Then
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
		
	EndIf;
	
EndProcedure // InventoryOpenProductsAndServices()

&AtClient
// The procedure is called when clicking "OpenProductsAndServices" on the command panel Recommendations.
//
Procedure RecommendationsOpenProductsAndServices(Command)
	
	TabularSectionRow = Items.Recommendations.CurrentData;
	If TabularSectionRow <> Undefined Then
		
		While True Do
			
			If TypeOf(TabularSectionRow.ProductsAndServices) = Type("CatalogRef.ProductsAndServices") Then
				OpenForm("Catalog.ProductsAndServices.Form.ItemForm", New Structure("Key", TabularSectionRow.ProductsAndServices));
				Break;
			Else
				TabularSectionRow = TabularSectionRow.GetParent();
				If TabularSectionRow = Undefined Then
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
		
	EndIf;
	
EndProcedure // RecommendationsOpenProductsAndServices()

// Procedure - handler of Calendar command.
//
&AtClient
Procedure PeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", EndOfPeriod);
	Notification = New NotifyDescription("PeriodPresentationStartChoiceEnd",ThisForm);
	OpenForm("CommonForm.CalendarForm", ParametersStructure,,,,,Notification);
	
EndProcedure // PeriodPresentationStartChoice()

&AtClient
Procedure PeriodPresentationStartChoiceEnd(CalendarDateEnd,Parameters) Export
	
	If ValueIsFilled(CalendarDateEnd) Then
		
		EndOfPeriod = EndOfDay(CalendarDateEnd);
		If BegOfDay(CurrentDate()) > BegOfDay(EndOfPeriod) Then
			EndOfPeriod = EndOfDay(CurrentDate());
		EndIf;
		
		GenerateDemandPeriod();
		
	EndIf;
	
EndProcedure

// Procedure - handler of ShortenPeriod command.
//
&AtClient
Procedure ShortenPeriod(Command)
	
	EndOfPeriod = EndOfDay(EndOfPeriod - 60 * 60 * 24);
	If BegOfDay(CurrentDate()) > BegOfDay(EndOfPeriod) Then
		EndOfPeriod = EndOfDay(CurrentDate());
	EndIf;
	
	GenerateDemandPeriod();
	
EndProcedure // ShortenPeriod()

// Procedure - handler of ExtendPeriod command.
//
&AtClient
Procedure ExtendPeriod(Command)
	
	EndOfPeriod = EndOfDay(EndOfPeriod + 60 * 60 * 24);
	GenerateDemandPeriod();
	
EndProcedure // ExtendPeriod()

// Procedure - handler of UpdateOrders command.
//
&AtClient
Procedure RefreshOrders(Command)
	
	UpdateStateOrdersAtServer();
	
EndProcedure // UpdateOrders()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("PurchasesOnly") Then
		PurchasesOnly = Parameters.PurchasesOnly;
	EndIf;
	
	EndOfPeriod = CurrentDate() + 7 * 86400;
	
	DataProcessor = FormAttributeToValue("Object");
	DataCompositionSchema = DataProcessor.GetTemplate("DataCompositionSchema");
	
	SchemaURLCompositionData = PutToTempStorage(DataCompositionSchema, New UUID);
	SettingsSource = New DataCompositionAvailableSettingsSource(SchemaURLCompositionData);
	
	SettingsComposer.Initialize(SettingsSource);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	RestoreSettings();
	
	If Not ValueIsFilled(EndOfPeriod) Then
		EndOfPeriod = CurrentDate() + 7 * 86400;
	EndIf;
	
	AddressInventory = PutToTempStorage(FormAttributeToValue("Inventory"), UUID);
	
EndProcedure // OnCreateAtServer()

&AtClient
// Event handler procedure OnOpen.
// Performs initial attributes forms filling.
//
Procedure OnOpen(Cancel)
	
	GenerateDemandPeriod();
	
EndProcedure // OnOpen()

&AtClient
// Procedure-handler of OnClose event.
//
Procedure OnClose()
	
	SaveSettings();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of input field FilterReplenishmentMethod.
//
Procedure FilterReplenishmentMethodOnChange(Item)
	
	If FilterReplenishmentMethod = "Production" Then
		Items.Counterparty.Visible = False;
		Counterparty = Undefined;
	Else
		Items.Counterparty.Visible = True;
	EndIf;
	
EndProcedure // FilterReplenishmentMethodOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABLE FIELD

&AtClient
// Procedure-the Choice event handler of the Inventory tabular section.
//
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Item.CurrentData <> Undefined Then
		
		If TypeOf(Item.CurrentData.ProductsAndServices) = Type("DocumentRef.CustomerOrder") Then
			OpenForm("Document.CustomerOrder.ObjectForm", New Structure("Key", Item.CurrentData.ProductsAndServices));
		ElsIf TypeOf(Item.CurrentData.ProductsAndServices) = Type("DocumentRef.PurchaseOrder") Then
			OpenForm("Document.PurchaseOrder.ObjectForm", New Structure("Key", Item.CurrentData.ProductsAndServices));
		ElsIf TypeOf(Item.CurrentData.ProductsAndServices) = Type("DocumentRef.ProductionOrder") Then
			OpenForm("Document.ProductionOrder.ObjectForm", New Structure("Key", Item.CurrentData.ProductsAndServices));
		EndIf;
		
	EndIf;
	
EndProcedure // InventorySelection()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR SECTION RECOMMENDATIONS

&AtClient
// Procedure - event handler BeforeStartChanging of tabular section Recommendations.
//
Procedure RecommendationsBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData = Undefined 
		OR Not Item.CurrentData.EditAllowed 
		AND Not (Item.CurrentItem <> Undefined AND Item.CurrentItem.Name = "RecommendationsSelected")Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
EndProcedure // RecommendationsBeforeChangeStart()

&AtClient
// Procedure - event handler BeforeAddStart of tabular section Recommendations.
//
Procedure RecommendationsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure // RecommendationsBeforeStartAdding()

&AtClient
// Procedure - event handler BeforeDelete of tabular section Recommendations.
//
Procedure RecommendationsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure // RecommendationsBeforeDeletion()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION EVENT HANDLERS ORDERS

&AtClient
// Procedure - event handler of Tabular section selection Orders.
//
Procedure OrdersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(Undefined,Item.RowData(SelectedRow).Order);
	
EndProcedure // OrdersSelection()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF ATTRIBUTES OF TABULAR SECTION RECOMMENDATIONS

&AtClient
// Procedure - event handler OnChange of the Selected input field.
//
Procedure RecommendationsSelectedOnChange(Item)
	
	SecuredQuantity = 0;
	Selected = False;
	
	CurrentDataParent = Items.Recommendations.CurrentData.GetParent();
	
	If CurrentDataParent = Undefined Then
		
		ParentCurrentData = Items.Recommendations.CurrentData.GetItems();
		SelectedParent = Items.Recommendations.CurrentData.Selected;
		Default = True;
		For Each TreeRow IN ParentCurrentData Do
			
			If SelectedParent Then
				TreeRow.Selected = Default;
			Else
				TreeRow.Selected = False;
			EndIf;
			
			Default = False;
			
			If TreeRow.Selected Then
			
				Selected = True;
				SecuredQuantity = SecuredQuantity + TreeRow.Quantity;
			
			EndIf;
			
		EndDo;
		
		Items.Recommendations.CurrentData.Selected = Selected;
		Items.Recommendations.CurrentData.DemandClosed = (SecuredQuantity >= Items.Recommendations.CurrentData.Quantity);
		
	Else	
		
		For Each TreeRow in CurrentDataParent.GetItems() Do
		
			If TreeRow.Selected Then
				
				Selected = True;
				SecuredQuantity = SecuredQuantity + TreeRow.Quantity;
				
			EndIf;
			
		EndDo;
		
		CurrentDataParent.Selected = Selected;
		CurrentDataParent.DemandClosed = (SecuredQuantity >= CurrentDataParent.Quantity);
		
	EndIf;
	
EndProcedure // RecommendationsSelectedOnChange()

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure RecommendationsQuantityOnChange(Item)
	
	Item.Parent.CurrentData.Selected = True;
	Item.Parent.CurrentData.Amount = Item.Parent.CurrentData.Quantity * Item.Parent.CurrentData.Price;
	
	RecommendationsSelectedOnChange(Item);
	
EndProcedure // RecommendationsQuantityOnChange()
