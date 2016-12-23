
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
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseSubsystemProduction" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsProductionOrder",	"Enabled", ConstantsSet.FunctionalOptionUseSubsystemProduction);
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsOthers", 				"Enabled", ConstantsSet.FunctionalOptionUseSubsystemProduction);
		
		If ConstantsSet.FunctionalOptionUseSubsystemProduction Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingDefaultProductionOrdersByStatus","Enabled", Not ConstantsSet.UseProductionOrderStates);
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogProductionOrderStates", 			"Enabled", ConstantsSet.UseProductionOrderStates);
			
		Else
			
			Constants.FunctionalOptionTolling.Set(False);
			Constants.FunctionalOptionUseTechOperations.Set(False);
			
		EndIf;
		
	EndIf;
	
	If (RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData())
		AND ConstantsSet.FunctionalOptionUseSubsystemProduction Then
		
		If AttributePathToData = "ConstantsSet.UseProductionOrderStates" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingDefaultProductionOrdersByStatus","Enabled", Not ConstantsSet.UseProductionOrderStates);
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogProductionOrderStates", 			"Enabled", ConstantsSet.UseProductionOrderStates);
			
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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
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
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseSubsystemProduction" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseSubsystemProduction = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseProductionOrderStates" Then
		
		ThisForm.ConstantsSet.UseProductionOrderStates = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.ProductionOrdersInProgressStatus" Then
		
		ThisForm.ConstantsSet.ProductionOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.ProductionOrdersCompletedStatus" Then
		
		ThisForm.ConstantsSet.ProductionOrdersCompletedStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionTolling" Then
		
		ThisForm.ConstantsSet.FunctionalOptionTolling = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseTechOperations" Then
		
		ConstantsSet.FunctionalOptionUseTechOperations = CurrentValue;
		
	EndIf;
	
EndProcedure // ReturnFormAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// The removal control procedure of the Use production by registers option.
//
&AtServer
Function CheckRecordsByProductionSubsystemRegisters()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Inventory.Company
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	(Inventory.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR Inventory.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InventoryReceived.Company
	|FROM
	|	AccumulationRegister.InventoryReceived AS InventoryReceived
	|WHERE
	|	InventoryReceived.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing)";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Inventory Register.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en='There are activities on the register ""Inventory"" in the infobase ,where financial account has the Indirect costs type or Unfinished production type! Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют движения по регистру ""Запасы"", где счет учета имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 2. The Inventory received register.
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='The Inventory Received accumulation register contains information about receipt for processing! Removal of the flag ""Production"" is prohibited!';ru='Регистр накопления ""Запасы принятые"" содержит информацию о приеме в переработку! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CheckActivityOnProductionSubsystemRegisters()

// The removal control procedure of the Use production option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseSubsystemProduction()
	
	ErrorText = "";
	
	Cancel = False;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ProductionOrder.Ref
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InventoryAssembly.Ref
	|FROM
	|	Document.InventoryAssembly AS InventoryAssembly
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	DockCostAllocation.Ref
	|FROM
	|	Document.CostAllocation AS DockCostAllocation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CustomerOrder.Ref
	|FROM
	|	Document.CustomerOrder AS CustomerOrder
	|WHERE
	|	CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForProcessing)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	JobSheet.Ref
	|FROM
	|	Document.JobSheet AS JobSheet
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TransferBetweenCells.Ref
	|FROM
	|	Document.TransferBetweenCells AS TransferBetweenCells
	|WHERE
	|	TransferBetweenCells.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InventoryTransfer.Ref
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	((InventoryTransfer.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|				OR InventoryTransfer.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division))
	|				AND InventoryTransfer.OperationKind = VALUE(Enum.OperationKindsInventoryTransfer.Move)
	|			OR InventoryTransfer.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EnterOpeningBalanceFixedAssets.Ref
	|FROM
	|	Document.EnterOpeningBalance.FixedAssets AS EnterOpeningBalanceFixedAssets
	|WHERE
	|	(EnterOpeningBalanceFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR EnterOpeningBalanceFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	EnterOpeningBalanceInventory.Ref
	|FROM
	|	Document.EnterOpeningBalance.Inventory AS EnterOpeningBalanceInventory
	|WHERE
	|	EnterOpeningBalanceInventory.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	EnteringOpeningBalancesDirectCost.Ref
	|FROM
	|	Document.EnterOpeningBalance.DirectCost AS EnteringOpeningBalancesDirectCost
	|WHERE
	|	EnteringOpeningBalancesDirectCost.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	FixedAssetsEnterFixedAssets.Ref
	|FROM
	|	Document.FixedAssetsEnter.FixedAssets AS FixedAssetsEnterFixedAssets
	|WHERE
	|	(FixedAssetsEnterFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR FixedAssetsEnterFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InventoryReceipt.Ref
	|FROM
	|	Document.InventoryReceipt AS InventoryReceipt
	|WHERE
	|	InventoryReceipt.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	BudgetBalance.Ref
	|FROM
	|	Document.Budget.Balance AS BudgetBalance
	|WHERE
	|	(BudgetBalance.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetBalance.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	BudgetIndirectExpenses.Ref
	|FROM
	|	Document.Budget.IndirectExpenses AS BudgetIndirectExpenses
	|WHERE
	|	(BudgetIndirectExpenses.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetIndirectExpenses.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR BudgetIndirectExpenses.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetIndirectExpenses.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	BudgetDirectCost.Ref
	|FROM
	|	Document.Budget.DirectCost AS BudgetDirectCost
	|WHERE
	|	(BudgetDirectCost.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetDirectCost.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR BudgetDirectCost.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetDirectCost.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	BudgetOperations.Ref
	|FROM
	|	Document.Budget.Operations AS BudgetOperations
	|WHERE
	|	(BudgetOperations.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetOperations.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR BudgetOperations.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetOperations.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	ChangingParametersFAFixedAssets.Ref
	|FROM
	|	Document.FixedAssetsModernization.FixedAssets AS ChangingParametersFAFixedAssets
	|WHERE
	|	(ChangingParametersFAFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR ChangingParametersFAFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	PayrollAccrualRetention.Ref
	|FROM
	|	Document.Payroll.AccrualsDeductions AS PayrollAccrualRetention
	|WHERE
	|	(PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR PayrollAccrualRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TaxAccrualTaxes.Ref
	|FROM
	|	Document.TaxAccrual.Taxes AS TaxAccrualTaxes
	|WHERE
	|	(TaxAccrualTaxes.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR TaxAccrualTaxes.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TransactionAccountingRecords.Ref
	|FROM
	|	Document.Operation.AccountingRecords AS TransactionAccountingRecords
	|WHERE
	|	(TransactionAccountingRecords.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR TransactionAccountingRecords.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR TransactionAccountingRecords.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR TransactionAccountingRecords.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	OtherExpensesCosts.Ref
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	(OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	ProductsAndServices.Ref
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServices
	|WHERE
	|	(ProductsAndServices.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR ProductsAndServices.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.UnfinishedProduction)
	|			OR ProductsAndServices.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	StructuralUnits.Ref
	|FROM
	|	Catalog.StructuralUnits AS StructuralUnits
	|WHERE
	|	(StructuralUnits.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			OR StructuralUnits.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			OR StructuralUnits.RecipientOfWastes.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division))";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Order for production Document.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en='The infobase contains the Production order documents! Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Заказ на производство""! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 2. Production Document.
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='The infobase contains the Production documents! Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Производство""! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 3. The Cost allocation document.
	If Not ResultsArray[2].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='The infobase contains documents ""Cost allocation"". Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Распределение затрат""! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 4. Customer order (Order for processing) document.
	If Not ResultsArray[3].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='The infobase contains the documents ""Customer order"" with the  operation kind ""Order for processing""! Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Заказ покупателя"" с видом операции ""Заказ на переработку""! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 5. The Job sheet document
	If Not ResultsArray[4].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='The infobase contains the Job sheet documents! Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Сдельный наряд""! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 6. Transfer between cells document (transfer - division).
	If Not ResultsArray[5].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='The infobase contains documents ""Transfer between cells"", where company structural unit has the Division type. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Перемещение по ячейкам"", где структурная единица компании имеет тип Подразделение! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 7. The Inventory transfer document (division, indirect costs).
	If Not ResultsArray[6].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Inventory Transfer"" documents in the infobase, where structural unit of company having Division type and/or the account of expenses having type Indirect costs! Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Перемещение запасов"", где структурная единица компании имеет тип Подразделение и/или счет затрат имеет тип Косвенные затраты! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 8. Enter opening balance document (division, indirect costs).
	If Not ResultsArray[7].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Enter opening balance"" documents in the infobase, where structural unit of the company has the Division type and/or the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Ввод начальных остатков"", где структурная единица компании имеет тип Подразделение и/или счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 9. Fixed assets enter document (unfinished production, indirect costs).
	If Not ResultsArray[8].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Fixed assets enter"" documents in the infobase, where the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Принятие к учету имущества"", где счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 10. Document Inventory receipt (division).
	If Not ResultsArray[9].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Inventory receipt"" documents in the infobase, where structural company unit has the Division type. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Оприходование запасов"", где структурная единица компании имеет тип Подразделение! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 11. The Budget document (unfinished production, indirect costs).
	If Not ResultsArray[10].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Budget"" documents in the infobase, where the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Бюджет"", где счета затрат имеют тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 12. The Fixed asserts modernization document (unfinished production, indirect costs).
	If Not ResultsArray[11].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Fixed assets modernization"" documents in the infobase, where the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Изменение параметров имущества"", где счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 13. Payroll document (unfinished production, indirect costs).
	If Not ResultsArray[12].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Payroll"" documents in the infobase, where the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Начисление зарплаты"", где счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 14. Tax accrual document (unfinished production, indirect costs).
	If Not ResultsArray[13].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Tax accrual"" documents in the infobase, where the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Начисление налогов"", где счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 15. The Operation document (unfinished production, indirect costs).
	If Not ResultsArray[14].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Operation"" documents in the infobase, where the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Операция"", где счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 16. The Other expenses document (unfinished production,indirect costs).
	If Not ResultsArray[15].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Other expenses"" documents in the infobase, where the account of expenses has type Indirect costs or Unfinished production. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют документы ""Прочие затраты (расходы)"", где счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 17. Catalog ProductsAndServices (unfinished production, indirect costs).
	If Not ResultsArray[16].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are ""Products and services"" catalog items in the infobase, where the account of expenses has type Indirect costs, Unfinished production or the ""Production"" method of inventory receipt. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют элементы справочника ""Номенклатура"", где счет учета затрат имеет тип Косвенные затраты, Незавершенное производство или способ пополнения запаса Производство! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	// 18. Catalog Structural units (division).
	If Not ResultsArray[17].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are items of catalog ""Structural unit"" in the infobase, where the autoshift parameter (shift, batching) has the Division type. Removal of the flag ""Production"" is prohibited!';ru='В информационной базе присутствуют элементы справочника ""Структурная единица"", где параметр автоперемещения (перемещение, комплектация) имеет тип Подразделение! Снятие флага ""Производство"" запрещено!'");
		
	EndIf;
	
	If IsBlankString(ErrorText) Then
		
		ErrorText = CheckRecordsByProductionSubsystemRegisters();
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseSubsystemProduction()

// Uncheck test of the UseProductionOrderStates option.
//
&AtServer
Function CancellationUncheckUseProductionOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ProductionOrder.Ref,
	|	ProductionOrder.OrderState.OrderStatus AS OrderStatus
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	(ProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR ProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT ProductionOrder.Closed))";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en='The base contains the documents ""Production order""  with the ""Opened"" and/or ""Executed (not closed)"" status!
		|Disabling the option is prohibited!
		|Note:
		|If there are documents in the state with
		|the status ""Open"", set them to state with the status ""In progress""
		|or ""Executed (closed)"" If there are documents in the state
		|with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".';ru='В базе есть документы ""Заказ на производство"" в состоянии со статусом ""Открыт"" и/или ""Выполнен (не закрыт)""!
		|Снятие опции запрещено!
		|Примечание:
		|Если есть документы в состоянии со статусом ""Открыт"", 
		|то установите для них состояние со статусом ""В работе"" или ""Выполнен (закрыт)""
		|Если есть документы в состоянии со статусом ""Выполнен (не закрыт)"",
		|то установите для них состояние со статусом ""Выполнен (закрыт)"".'"
		);
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckUseProductionOrderStates()

// uncheck test of the Tolling option.
//
&AtServer
Function CancellationUncheckFunctionalOptionTolling()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryReceived.Company
		|FROM
		|	AccumulationRegister.InventoryReceived AS InventoryReceived
		|WHERE
		|	InventoryReceived.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.ReceiptToProcessing)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='The Inventory Received accumulation register contains information about receipt for processing! The flag removal is prohibited!';ru='Регистр накопления ""Запасы принятые"" содержит информацию о приеме в переработку! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionTolling()

// Uncheck test of the UseTechoperations option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseTechOperations()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	JobSheets.Operation
		|FROM
		|	AccumulationRegister.JobSheets AS JobSheets"
	);
	
	QueryResult = Query.Execute();
		
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='The base contains information about the work centers import or the documents of the type ""Job sheet""! The flag removal is prohibited!';ru='В базе присутствует информация о загрузке рабочих центров или документы вида ""Сдельный наряд""! Снятие флага запрещено!'");
		
	EndIf;
	
	Query.Text = "Select First 1 * From Catalog.ProductsAndServices AS CtlProductsAndServices Where CtlProductsAndServices.ProductsAndServicesType = Value(Enum.ProductsAndServices.Operation)";
	
	QueryResult = Query.Execute();
		
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en='The base contains ProductsAndServices with the type ""Operation""! The flag removal is prohibited!';ru='В базе присутствует номенклатура с типом ""Операция""! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseTechOperations()

// Initialization of checking the possibility to disable the CurrencyTransactionsAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Include/remove Production section
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseSubsystemProduction" Then
		
		If Constants.FunctionalOptionUseSubsystemProduction.Get() <> ConstantsSet.FunctionalOptionUseSubsystemProduction
			AND (NOT ConstantsSet.FunctionalOptionUseSubsystemProduction) Then
		
			ErrorText = CancellationUncheckFunctionalOptionUseSubsystemProduction();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are the Production Order documents with the status different from Executed, the flag removal is prohibited.
	If AttributePathToData = "ConstantsSet.UseProductionOrderStates" Then
		
		If Constants.UseProductionOrderStates.Get() <> ConstantsSet.UseProductionOrderStates
			AND (NOT ConstantsSet.UseProductionOrderStates) Then
			
			ErrorText = CancellationUncheckUseProductionOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	//If InProcessStatus for the Production order documents are used,the field is required to be filled in.
	If AttributePathToData = "ConstantsSet.ProductionOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseProductionOrderStates
			AND Not ValueIsFilled(ConstantsSet.ProductionOrdersInProgressStatus) Then
			
			ErrorText = NStr("en='""Use several production order statuses"" flag is removed but ""In progress"" parameter of the production order status is not filled!';ru='Снят флаг ""Использовать несколько состояний заказов на производство"", но не заполнен параматр состояния заказа на производство ""В работе""!'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.ProductionOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	//If StatusExecuted for the ProductionOrders documents are used,the field is required to be filled in.
	If AttributePathToData = "ConstantsSet.ProductionOrdersCompletedStatus" Then
		
		If Not ConstantsSet.UseProductionOrderStates
			AND Not ValueIsFilled(ConstantsSet.ProductionOrdersCompletedStatus) Then
			
			ErrorText = NStr("en='""Use several production order statuses"" flag is removed, but ""Executed"" parameter of the production order status  is not filled!';ru='Снят флаг ""Использовать несколько состояний заказов на производство"", но не заполнен параматр состояния заказа на производство ""Выполнен""!'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.ProductionOrdersCompletedStatus.Get());
			
		EndIf; 
		
	EndIf;
	
	
	// If there are any activities on the register "Inventory received", the removal of the FunctionalOptionTolling flag is prohibited
	If AttributePathToData = "ConstantsSet.FunctionalOptionTolling" Then
		
		If Constants.FunctionalOptionTolling.Get() <> ConstantsSet.FunctionalOptionTolling 
			AND (NOT ConstantsSet.FunctionalOptionTolling) Then
			
			ErrorText = CancellationUncheckFunctionalOptionTolling();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any activities on the registers "Work centers loading", on the register "Job sheet" or the products and services with the Operation type, the removal of the FunctionalOptionUseTechOperations flag is prohibited
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseTechOperations" Then
		
		If Constants.FunctionalOptionUseTechOperations.Get() <> ConstantsSet.FunctionalOptionUseTechOperations 
			AND (NOT ConstantsSet.FunctionalOptionUseTechOperations) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseTechOperations();
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

// Procedure - handler of the ProductionOrderStatusesCatalog command.
//
&AtClient
Procedure CatalogProductionOrderStates(Command)
	
	OpenForm("Catalog.ProductionOrderStates.ListForm");
	
EndProcedure // ProductionOrdersStatesCatalog()

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
	
	// Additionally
	CommonUseClientServer.SetFormItemProperty(Items, "SettingsProcessingOfTollingFO", "Enabled", ConstantsSet.FunctionalOptionUseBatches);
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure // OnOpen()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then
		
		If Source = "FunctionalOptionUseBatches" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "Group4", "Enabled", Parameter.Value);
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose()
	
	RefreshApplicationInterface();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - handler of the OnChange event of the UseProductionOrderStates field
//
&AtClient
Procedure FunctionalOptionUseSubsystemProductionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseSubsystemProductionOnChange()

// Procedure - handler of the OnChange event of the UseProductionOrderStates field
//
&AtClient
Procedure UseStatusesProductionOrderOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // UseProductionOrderStatesOnChange()

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

// Procedure - the OnChange event handler of the FunctionalOptionUseTechOperations field.
//
&AtClient
Procedure FunctionalOptionUseTechOperationsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseTechOperationsOnChange()

// Procedure - the OnChange event handler of the FunctionalOptionUseTechOperations field.
//
&AtClient
Procedure FunctionalOptionTollingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionTollingOnChange()
// 














