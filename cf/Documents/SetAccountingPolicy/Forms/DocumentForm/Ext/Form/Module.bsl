
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	
	If Parameters.Key.IsEmpty() Then
		Items.GroupNumberPreview.CurrentPage = Items.PageNumberPreview;
		// Showing number presentation with prefixes.
		NumberPreview = DocumentsPostingAndNumbering.GetDocumentAutoNumberPresentation(FormAttributeToValue("Object"));
	EndIf;	
	
	DialogsAtServer.CheckAccountsExtDimensions(Object.Account_MaterialsConsumptionDuringProduction,"MaterialsConsumptionDuringProductionExtDimension",Object);
	DialogsAtServer.CheckAccountsExtDimensions(Object.Account_GoodsReceipt, "GoodsReceiptExtDimension", Object);
	DialogsAtServer.CheckAccountsExtDimensions(Object.Account_GoodsIssue,"GoodsIssueExtDimension",Object);
	DialogsAtServer.CheckAccountsExtDimensions(Object.Account_SalesPrepaymentInvoiceSettlement,"Account_SalesPrepaymentInvoiceSettlementExtDimension",Object);
	DialogsAtServer.CheckAccountsExtDimensions(Object.Account_PurchasePrepaymentInvoiceSettlement,"Account_PurchasePrepaymentInvoiceSettlementExtDimension",Object);
	DialogsAtServer.CheckAccountsExtDimensions(Object.Account_PurchaseCreditNotePositiveCostDifferences, "PurchaseCreditNotePositiveExtDimension", Object);
	DialogsAtServer.CheckAccountsExtDimensions(Object.Account_PurchaseCreditNoteNegativeCostDifferences, "PurchaseCreditNoteNegativeExtDimension", Object);
			
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	DocumentsFormAtClient.OnOpen(ThisForm, Cancel);
	
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_MaterialsConsumptionDuringProduction","MaterialsConsumptionDuringProductionExtDimension",Object,Items);
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_GoodsReceipt", "GoodsReceiptExtDimension",Object,Items);
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_GoodsIssue","GoodsIssueExtDimension",Object,Items);
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_SalesPrepaymentInvoiceSettlement","Account_SalesPrepaymentInvoiceSettlementExtDimension",Object,Items);
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_PurchasePrepaymentInvoiceSettlement","Account_PurchasePrepaymentInvoiceSettlementExtDimension",Object,Items);
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_PurchaseCreditNotePositiveCostDifferences", "PurchaseCreditNotePositiveExtDimension",Object,Items);
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_PurchaseCreditNoteNegativeCostDifferences", "PurchaseCreditNoteNegativeExtDimension",Object,Items);
	
	UpdateDialogAtClient();
	
EndProcedure

&AtServer
Procedure ChangeDocumentsHeaderAtServer(Recalculate = True) Export
	
	DocumentsFormAtServer.SetFormDocumentTitle(ThisForm);
	
EndProcedure

&AtClient
Procedure UpdateDialog() Export
	
	DocumentsFormAtClient.UpdateDialog(ThisForm);
	
EndProcedure

&AtClient
Procedure ChangeDocumentsHeader(MainParameters, AdditionalParameters) Export
	
	DocumentsFormAtClient.ChangeDocumentsHeader(ThisForm, MainParameters, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure PrefixOnChange(SelectedElement, AdditionalParameters) Export
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	If SelectedElement.Value = "NumberSettings" Then
		OpenForm("InformationRegister.DocumentsNumberingSettings.Form.RecordFormSetting", New Structure("DocumentType", Object.Ref), ThisForm);
		Return;
	EndIf;
	Object["ManualChangeNumber"] = False;
	Object["Prefix"] = SelectedElement.Value;
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm);
EndProcedure

&AtClient
Procedure EndTextNumberOnChange(QuestionAnswer, AdditionalParameters) Export
	If QuestionAnswer = DialogReturnCode.Yes Then
		Object.ManualChangeNumber = True;
	EndIf;
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Items[AdditionalParameters.ItemName]);
EndProcedure

&AtClient
Procedure NewWriteProcessing(NewObject, Source, StandardProcessing)
	SwitchPreviewNumberToRealNumber();
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	SwitchPreviewNumberToRealNumber();
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	NumberPreview = DocumentsPostingAndNumbering.GetDocumentAutoNumberPresentation(Object.Ref);
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	NumberPreview = DocumentsPostingAndNumbering.GetDocumentAutoNumberPresentation(Object.Ref);
EndProcedure

&AtClient
Procedure GetAccountingPolicyAtClient(Command)
	GetAccountingPolicyAtServer();
EndProcedure

&AtServer
Procedure GetAccountingPolicyAtServer()
	
	If Parameters.Key.IsEmpty() Then
		
		If SessionParameters.IsBookkeepingAvailable Then
			
			AccountingPolicy = Accounting.GetAccountingPolicy(Object.Date,Object.Company);
			
			Object.Account_SalesPrepaymentInvoiceSettlement = AccountingPolicy.Account_SalesPrepaymentInvoiceSettlement;
			Object.Account_SalesPrepaymentInvoiceSettlementExtDimension1 = AccountingPolicy.Account_SalesPrepaymentInvoiceSettlementExtDimension1;
			Object.Account_SalesPrepaymentInvoiceSettlementExtDimension2 = AccountingPolicy.Account_SalesPrepaymentInvoiceSettlementExtDimension2;
			Object.Account_SalesPrepaymentInvoiceSettlementExtDimension3 = AccountingPolicy.Account_SalesPrepaymentInvoiceSettlementExtDimension3;
			
			Object.Account_PurchasePrepaymentInvoiceSettlement = AccountingPolicy.Account_PurchasePrepaymentInvoiceSettlement;
			Object.Account_PurchasePrepaymentInvoiceSettlementExtDimension1 = AccountingPolicy.Account_PurchasePrepaymentInvoiceSettlementExtDimension1;
			Object.Account_PurchasePrepaymentInvoiceSettlementExtDimension2 = AccountingPolicy.Account_PurchasePrepaymentInvoiceSettlementExtDimension2;
			Object.Account_PurchasePrepaymentInvoiceSettlementExtDimension3 = AccountingPolicy.Account_PurchasePrepaymentInvoiceSettlementExtDimension3;
			
			Object.Account_SalesCreditNoteVAT = AccountingPolicy.Account_SalesCreditNoteVAT;
			
			Object.Account_PrepaymentsToSuppliersSettlements = AccountingPolicy.Account_PrepaymentsToSuppliersSettlements;
			Object.Account_DeferredIncomesSettlements = AccountingPolicy.Account_DeferredIncomesSettlements;
			
			Object.Account_OtherSettlementsWithEmployees = AccountingPolicy.Account_OtherSettlementsWithEmployees;
			Object.Account_EmployeesSalariesSettlements = AccountingPolicy.Account_EmployeesSalariesSettlements;
			
			Object.ExchangeRateForCalculatingSalesAndPurchase = AccountingPolicy.ExchangeRateForCalculatingSalesAndPurchase;
			
			Object.Account_MaterialsConsumptionDuringProduction = AccountingPolicy.Account_MaterialsConsumptionDuringProduction;
			Object.MaterialsConsumptionDuringProductionExtDimension1 = AccountingPolicy.MaterialsConsumptionDuringProductionExtDimension1;
			Object.MaterialsConsumptionDuringProductionExtDimension2 = AccountingPolicy.MaterialsConsumptionDuringProductionExtDimension2;
			Object.MaterialsConsumptionDuringProductionExtDimension3 = AccountingPolicy.MaterialsConsumptionDuringProductionExtDimension3;
			
			Object.Account_PurchaseCreditNoteNegativeCostDifferences = AccountingPolicy.Account_PurchaseCreditNoteNegativeCostDifferences;
			Object.PurchaseCreditNoteNegativeExtDimension1 = AccountingPolicy.PurchaseCreditNoteNegativeExtDimension1;
			Object.PurchaseCreditNoteNegativeExtDimension2 = AccountingPolicy.PurchaseCreditNoteNegativeExtDimension2;
			Object.PurchaseCreditNoteNegativeExtDimension3 = AccountingPolicy.PurchaseCreditNoteNegativeExtDimension3;
			
			Object.Account_PurchaseCreditNotePositiveCostDifferences = AccountingPolicy.Account_PurchaseCreditNotePositiveCostDifferences;
			Object.PurchaseCreditNotePositiveExtDimension1 = AccountingPolicy.PurchaseCreditNotePositiveExtDimension1;
			Object.PurchaseCreditNotePositiveExtDimension2 = AccountingPolicy.PurchaseCreditNotePositiveExtDimension2;
			Object.PurchaseCreditNotePositiveExtDimension3 = AccountingPolicy.PurchaseCreditNotePositiveExtDimension3;
						
			GoodsInventoryAccountingPolicy = Accounting.GetGoodsInventoryAccountingPolicy(Object.Date,Object.Company);
			
			Object.Account_GoodsIssue = GoodsInventoryAccountingPolicy.Account_GoodsIssue;
			Object.GoodsIssueExtDimension1 = GoodsInventoryAccountingPolicy.GoodsIssueExtDimension1;
			Object.GoodsIssueExtDimension2 = GoodsInventoryAccountingPolicy.GoodsIssueExtDimension2;
			Object.GoodsIssueExtDimension3 = GoodsInventoryAccountingPolicy.GoodsIssueExtDimension3;
			
			Object.Account_GoodsReceipt = GoodsInventoryAccountingPolicy.Account_GoodsReceipt;
			Object.GoodsReceiptExtDimension1 = GoodsInventoryAccountingPolicy.GoodsReceiptExtDimension1;
			Object.GoodsReceiptExtDimension2 = GoodsInventoryAccountingPolicy.GoodsReceiptExtDimension2;
			Object.GoodsReceiptExtDimension3 = GoodsInventoryAccountingPolicy.GoodsReceiptExtDimension3;
			
		EndIf;
		
	EndIf;

EndProcedure	

&AtClient
Procedure CostingMethodOnChange(Item)
	UpdateDialogAtClient();
EndProcedure

&AtClient
Procedure AdditionalCostOfGoodsPostingMethodWhenAverageOnChange(Item)
	
	If Object.AdditionalCostOfGoodsPostingMethodWhenAverage <> PredefinedValue("Enum.AdditionalCostOfGoodsPostingMethods.AccordingFinalBalance") Then
		Object.CostOfGoodsWriteOffDefaultDirection = Undefined;
	EndIf;
	
	UpdateDialogAtClient();
	
EndProcedure

&AtClient
Procedure UseBudgetingOnChange(Item)
	
	If Not Object.UseBudgeting Then
		Object.BudgetCurrency = Undefined;
		Object.ControlPurchaseInvoiceInputtingWithBudget = False;
		Object.InvoiceAmountTypeForBudgetControl = Undefined;
	EndIf;
	
	UpdateDialogAtClient();

EndProcedure

&AtClient
Procedure ControlPurchaseInvoiceInputtingWithBudgetOnChange(Item)
	
	If Not Object.ControlPurchaseInvoiceInputtingWithBudget Then
		Object.InvoiceAmountTypeForBudgetControl = Undefined;
	EndIf;
	
	UpdateDialogAtClient();

EndProcedure

&AtClient
Procedure Account_MaterialsConsumptionDuringProductionOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_MaterialsConsumptionDuringProduction","MaterialsConsumptionDuringProductionExtDimension",Object,Items);
	CheckAccountsExtDimensionsAtServer("Account_MaterialsConsumptionDuringProduction","MaterialsConsumptionDuringProductionExtDimension");
EndProcedure

&AtServer
Procedure CheckAccountsExtDimensionsAtServer(Val AccountName, Val ExtDimensionName)
	
	DialogsAtServer.CheckAccountsExtDimensions(Object[AccountName],"MaterialsConsumptionDuringProductionExtDimension",Object);
	
EndProcedure	

&AtClient
Procedure Account_GoodsReceiptOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_GoodsReceipt", "GoodsReceiptExtDimension",Object,Items);
	CheckAccountsExtDimensionsAtServer("Account_GoodsReceipt", "GoodsReceiptExtDimension");
EndProcedure

&AtClient
Procedure Account_GoodsIssueOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_GoodsIssue","GoodsIssueExtDimension",Object,Items);
	CheckAccountsExtDimensionsAtServer("Account_GoodsIssue","GoodsIssueExtDimension");
EndProcedure

&AtClient
Procedure CostOfGoodsMovementsDirectionsOnStartEdit(Item, NewRow, Clone)
	If Item.CurrentRow <> Undefined Then
		AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","CostOfGoodsMovementsDirectionsExtDimension",Item.CurrentData,Item.ChildItems);
		TableWithExtDimensionsOnChangeAtServer("Account","ExtDimension","CostOfGoodsMovementsDirections",Item.CurrentRow);
	EndIf;	
EndProcedure

&AtClient
Procedure CostOfGoodsMovementsDirectionsAccountOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","CostOfGoodsMovementsDirectionsExtDimension",Items.CostOfGoodsMovementsDirections.CurrentData,Items.CostOfGoodsMovementsDirections.ChildItems);
	TableWithExtDimensionsOnChangeAtServer("Account","ExtDimension","CostOfGoodsMovementsDirections",Items.CostOfGoodsMovementsDirections.CurrentRow);
EndProcedure

&AtClient
Procedure Account_SalesPrepaymentInvoiceSettlementOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_SalesPrepaymentInvoiceSettlement","Account_SalesPrepaymentInvoiceSettlementExtDimension",Object,Items);
	CheckAccountsExtDimensionsAtServer("Account_SalesPrepaymentInvoiceSettlement","Account_SalesPrepaymentInvoiceSettlementExtDimension");
EndProcedure

&AtClient
Procedure Account_PurchasePrepaymentInvoiceSettlementOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_PurchasePrepaymentInvoiceSettlement","Account_PurchasePrepaymentInvoiceSettlementExtDimension",Object,Items);
	CheckAccountsExtDimensionsAtServer("Account_PurchasePrepaymentInvoiceSettlement","Account_PurchasePrepaymentInvoiceSettlementExtDimension");
EndProcedure

&AtClient
Procedure ExchangeRateDifferenceAccountsOnStartEdit(Item, NewRow, Clone)	
	If Item.CurrentRow <> Undefined Then
		AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","ExchangeRateDifferenceAccountsExtDimension",Item.CurrentData,Item.ChildItems);
		TableWithExtDimensionsOnChangeAtServer("Account","ExtDimension","ExchangeRateDifferenceAccounts",Item.CurrentRow);
	EndIf;	
EndProcedure

&AtClient
Procedure ExchangeRateDifferenceAccountsAccountOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","ExchangeRateDifferenceAccountsExtDimension",Items.ExchangeRateDifferenceAccounts.CurrentData,Items.ExchangeRateDifferenceAccounts.ChildItems);
	TableWithExtDimensionsOnChangeAtServer("Account","ExtDimension","ExchangeRateDifferenceAccounts",Items.ExchangeRateDifferenceAccounts.CurrentRow);
EndProcedure

&AtClient
Procedure GeneralRoundingAccountsOnStartEdit(Item, NewRow, Clone)
	If Item.CurrentRow <> Undefined Then
		AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","GeneralRoundingAccountsExtDimension",Item.CurrentData,Item.ChildItems);
		TableWithExtDimensionsOnChangeAtServer("Account","ExtDimension","GeneralRoundingAccounts",Item.CurrentRow);
	EndIf;	
EndProcedure

&AtClient
Procedure GeneralRoundingAccountsAccountOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","GeneralRoundingAccountsExtDimension",Items.GeneralRoundingAccounts.CurrentData,Items.GeneralRoundingAccounts.ChildItems);
	TableWithExtDimensionsOnChangeAtServer("Account","ExtDimension","GeneralRoundingAccounts",Items.GeneralRoundingAccounts.CurrentRow);
EndProcedure

&AtClient
Procedure Account_PurchaseCreditNotePositiveCostDifferencesOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_PurchaseCreditNotePositiveCostDifferences", "PurchaseCreditNotePositiveExtDimension",Object,Items);
	CheckAccountsExtDimensionsAtServer("Account_PurchaseCreditNotePositiveCostDifferences", "PurchaseCreditNotePositiveExtDimension");
EndProcedure

&AtClient
Procedure Account_PurchaseCreditNoteNegativeCostDifferencesOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_PurchaseCreditNoteNegativeCostDifferences", "PurchaseCreditNoteNegativeExtDimension",Object,Items);
	CheckAccountsExtDimensionsAtServer("Account_PurchaseCreditNoteNegativeCostDifferences", "PurchaseCreditNoteNegativeExtDimension");
EndProcedure

&AtServer
Procedure TableWithExtDimensionsOnChangeAtServer(Val AccountName, Val ExtDimensionName,Val TableName,Val RowId)
	
	RowData = Object[TableName].FindById(RowId);
	DialogsAtServer.CheckAccountsExtDimensions(RowData[AccountName],ExtDimensionName,RowData);
	
EndProcedure	

&AtClient
Procedure UpdateDialogAtClient()
	
	//IsAverage = (Object.CostingMethod = PredefinedValue("Enum.GoodsCostingMethods.Average"));
	IsAverage = (Object.CostingMethod = PredefinedValue("Enum.InventoryValuationMethods.byAverage"));
	ControlsProcessingAtClientAtServer.SetControlMarkIncompleteAndEnable(Items.AdditionalCostOfGoodsPostingMethodWhenAverage,Object.AdditionalCostOfGoodsPostingMethodWhenAverage,IsAverage);
	
	Items.CostOfGoodsWriteOffDefaultDirection.Enabled      = (Object.AdditionalCostOfGoodsPostingMethodWhenAverage = PredefinedValue("Enum.AdditionalCostOfGoodsPostingMethods.AccordingFinalBalance"));
	
	MarkIncomplete = (Object.CostOfGoodsWriteOffDefaultDirection.IsEmpty() And Items.CostOfGoodsWriteOffDefaultDirection.Enabled);
	Items.CostOfGoodsWriteOffDefaultDirection.AutoMarkIncomplete = MarkIncomplete;
	Items.CostOfGoodsWriteOffDefaultDirection.MarkIncomplete     = MarkIncomplete;
	
	Items.BudgetCurrency.Enabled = Object.UseBudgeting;
	Items.ControlPurchaseInvoiceInputtingWithBudget.Enabled = Object.UseBudgeting;
	
	MarkIncomplete = (Object.BudgetCurrency.IsEmpty() And Items.BudgetCurrency.Enabled);
	Items.BudgetCurrency.AutoMarkIncomplete = MarkIncomplete;
	Items.BudgetCurrency.MarkIncomplete     = MarkIncomplete;
	
	Items.InvoiceAmountTypeForBudgetControl.Enabled = Object.ControlPurchaseInvoiceInputtingWithBudget;
	
	MarkIncomplete = (Object.InvoiceAmountTypeForBudgetControl.IsEmpty() And Items.InvoiceAmountTypeForBudgetControl.Enabled);
	Items.InvoiceAmountTypeForBudgetControl.AutoMarkIncomplete = MarkIncomplete;
	Items.InvoiceAmountTypeForBudgetControl.MarkIncomplete     = MarkIncomplete;

EndProcedure	

&AtClient
Procedure SwitchPreviewNumberToRealNumber()
	
	If Items.GroupNumberPreview.CurrentPage = Items.PageNumberPreview Then
		Items.GroupNumberPreview.CurrentPage = Items.PageNumber;
	EndIf;	
	
EndProcedure	

&AtClient
Procedure NumberPreviewOnChange(Item)
	If Object.ManualChangeNumber Then
		DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Item);
	Else
		EndTextNumberOnChange = New NotifyDescription("EndTextNumberOnChange", ThisForm, New Structure("ItemName", Item.Name));
		ShowQueryBox(EndTextNumberOnChange, NStr("pl='UWAGA! Po zmianie numeru numeracja automatyczna tego dokumentu zostanie wyłączona! Włączyć moźliwość zmiany numeru?';en='ATTENTION! After changing the number automatic numbering for this document will be disabled! Enable number editing?'"), QuestionDialogMode.YesNo);
	EndIf;
EndProcedure

&AtClient
Procedure NumberPreviewStartChoice(Item, ChoiceData, StandardProcessing)
	ShowChooseFromList(New NotifyDescription("PrefixOnChange", ThisForm), ThisForm["PrefixList"], Item);
EndProcedure