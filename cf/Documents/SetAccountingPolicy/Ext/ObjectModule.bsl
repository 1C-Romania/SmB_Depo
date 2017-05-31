Procedure Filling(FillingData, StandardProcessing)
	
	If FillingData = Undefined Then
		CommonAtServer.FillDocumentHeader(ThisObject);
	EndIf;	
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If CostingMethod <> Enums.GoodsCostingMethods.Average Then
		DocumentsPostingAndNumbering.DeleteFromCheckedAttributes(CheckedAttributes,"AdditionalCostOfGoodsPostingMethodWhenAverage");
		DocumentsPostingAndNumbering.DeleteFromCheckedAttributes(CheckedAttributes,"CostOfGoodsWriteOffDefaultDirection");
	Else	
		If AdditionalCostOfGoodsPostingMethodWhenAverage <> Enums.AdditionalCostOfGoodsPostingMethods.AccordingFinalBalance Then
			DocumentsPostingAndNumbering.DeleteFromCheckedAttributes(CheckedAttributes,"CostOfGoodsWriteOffDefaultDirection");
		EndIf;
	EndIf;
	If NOT UseBudgeting Then
		DocumentsPostingAndNumbering.DeleteFromCheckedAttributes(CheckedAttributes,"BudgetCurrency");
	EndIf;
	If NOT ControlPurchaseInvoiceInputtingWithBudget Then
		DocumentsPostingAndNumbering.DeleteFromCheckedAttributes(CheckedAttributes,"InvoiceAmountTypeForBudgetControl");
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	// WARNING!!! Calling of this function should be on begin of BeforeWrite function
	// Please, don't remove this call - it may cause damage in logic of configuration
	Common.GetObjectModificationFlag(ThisObject);
		
	Date = BegOfDay(Date);
	
	ReadPreviousCostinghMethod();
	
EndProcedure

Procedure ReadPreviousCostinghMethod()
	
	Query = New Query;
	Query.Text =  "SELECT
	|	AccountingPolicyGeneralSliceLast.CostingMethod
	|FROM
	|	InformationRegister.AccountingPolicyGeneral.SliceLast(&Period, Company = &Company) AS AccountingPolicyGeneralSliceLast";
	Query.SetParameter("Company",Company);
	If AdditionalProperties.WasNew Then
		If Date = '00010101000000' Then
			Query.SetParameter("Period",GetServerDate());
		Else
			Query.SetParameter("Period",Date);
		EndIf;	
	Else
		Query.SetParameter("Period",Ref.Date);
		AdditionalProperties.Insert("PrevCompany",Ref.Company);
	EndIf;	
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		AdditionalProperties.Insert("PrevCostingMethod",Selection.CostingMethod);
	Else
		AdditionalProperties.Insert("PrevCostingMethod",Undefined);
	EndIf;	
	
EndProcedure	

Procedure PostingBookkeeping() Export

	//Bookkeeping
	Record = RegisterRecords.BookkeepingAccountingPolicyGeneral.Add();
	
	Record.Period = Date;
	Record.Company = Company;
	
	//Record.ExchangeRateForCalculatingSalesAndPurchase = ExchangeRateForCalculatingSalesAndPurchase;
	
	Record.Account_PrepaymentsToSuppliersSettlements = Account_PrepaymentsToSuppliersSettlements;
	Record.Account_DeferredIncomesSettlements = Account_DeferredIncomesSettlements;
	
	Record.Account_CostSettlement = Account_CostSettlement;
	
	Record.Account_SalesCreditNoteVAT = Account_SalesCreditNoteVAT;
	
	Record.Account_FixedAssetsUnderContstruction = Account_FixedAssetsUnderContstruction;
	
	Record.Account_MaterialsConsumptionDuringProduction = Account_MaterialsConsumptionDuringProduction;
	Record.MaterialsConsumptionDuringProductionExtDimension1 = MaterialsConsumptionDuringProductionExtDimension1;
	Record.MaterialsConsumptionDuringProductionExtDimension2 = MaterialsConsumptionDuringProductionExtDimension2;
	Record.MaterialsConsumptionDuringProductionExtDimension3 = MaterialsConsumptionDuringProductionExtDimension3;
	
	Record.Account_PurchaseCreditNoteNegativeCostDifferences = Account_PurchaseCreditNoteNegativeCostDifferences;
	Record.PurchaseCreditNoteNegativeExtDimension1 = PurchaseCreditNoteNegativeExtDimension1;
	Record.PurchaseCreditNoteNegativeExtDimension2 = PurchaseCreditNoteNegativeExtDimension2;
	Record.PurchaseCreditNoteNegativeExtDimension3 = PurchaseCreditNoteNegativeExtDimension3;
	
	Record.Account_PurchaseCreditNotePositiveCostDifferences = Account_PurchaseCreditNotePositiveCostDifferences;
	Record.PurchaseCreditNotePositiveExtDimension1 = PurchaseCreditNotePositiveExtDimension1;
	Record.PurchaseCreditNotePositiveExtDimension2 = PurchaseCreditNotePositiveExtDimension2;
	Record.PurchaseCreditNotePositiveExtDimension3 = PurchaseCreditNotePositiveExtDimension3;
	
	Record.Account_OtherSettlementsWithEmployees = Account_OtherSettlementsWithEmployees;
	Record.Account_EmployeesSalariesSettlements = Account_EmployeesSalariesSettlements;
	Record.Account_AccountsWithOtherPersons = Account_AccountsWithOtherPersons;
	
	Record.Payroll_IllnessToBonus = Payroll_IllnessToBonus;
	Record.Payroll_Account_PublicSettlements = Payroll_Account_PublicSettlements;
	Record.Payroll_CostArticle_EmployeesBenefits = Payroll_CostArticle_EmployeesBenefits;
	Record.Payroll_CostArticle_Salaries = Payroll_CostArticle_Salaries;
	Record.Payroll_Settlements_HealthIns = Payroll_Settlements_HealthIns;
	Record.Payroll_Settlements_IncomeTax = Payroll_Settlements_IncomeTax;
	Record.Payroll_Settlements_SocialIns = Payroll_Settlements_SocialIns;
	Record.Payroll_Settlements_ZUSFPFGSP = Payroll_Settlements_ZUSFPFGSP;
	
	Record.Account_SalesPrepaymentInvoiceSettlement = Account_SalesPrepaymentInvoiceSettlement;
	Record.Account_SalesPrepaymentInvoiceSettlementExtDimension1 = Account_SalesPrepaymentInvoiceSettlementExtDimension1;
	Record.Account_SalesPrepaymentInvoiceSettlementExtDimension2 = Account_SalesPrepaymentInvoiceSettlementExtDimension2;
	Record.Account_SalesPrepaymentInvoiceSettlementExtDimension3 = Account_SalesPrepaymentInvoiceSettlementExtDimension3;
	
	Record.Account_PurchasePrepaymentInvoiceSettlement = Account_PurchasePrepaymentInvoiceSettlement;
	Record.Account_PurchasePrepaymentInvoiceSettlementExtDimension1 = Account_PurchasePrepaymentInvoiceSettlementExtDimension1;
	Record.Account_PurchasePrepaymentInvoiceSettlementExtDimension2 = Account_PurchasePrepaymentInvoiceSettlementExtDimension2;
	Record.Account_PurchasePrepaymentInvoiceSettlementExtDimension3 = Account_PurchasePrepaymentInvoiceSettlementExtDimension3;
	
	//Record.VATCalculationMethod = VATCalculationMethod;
	
	// DefaultAccountGoodsInventoryMovements
	Record = RegisterRecords.BookkeepingDefaultAccountGoodsInventoryMovements.Add();
	
	Record.Period = Date;
	Record.Company = Company;
	
	Record.Account_GoodsReceipt = Account_GoodsReceipt;
	Record.GoodsReceiptExtDimension1 = GoodsReceiptExtDimension1;
	Record.GoodsReceiptExtDimension2 = GoodsReceiptExtDimension2;
	Record.GoodsReceiptExtDimension3 = GoodsReceiptExtDimension3;
	
	Record.Account_GoodsIssue = Account_GoodsIssue;
	Record.GoodsIssueExtDimension1 = GoodsIssueExtDimension1;
	Record.GoodsIssueExtDimension2 = GoodsIssueExtDimension2;
	Record.GoodsIssueExtDimension3 = GoodsIssueExtDimension3;
	
	// CostOfGoodsMovementsDirections
	For Each Item In CostOfGoodsMovementsDirections Do
		Record = RegisterRecords.BookkeepingAccountingPolicyCostOfGoodsDirections.Add();
		Record.Period = Date;
		Record.Company = Company;

		Record.ItemAccountingGroup = Item.ItemAccountingGroup;		
		Record.Direction = Item.Direction;
		Record.Account = Item.Account;
		Record.ExtDimension1 = Item.ExtDimension1;
		Record.ExtDimension2 = Item.ExtDimension2;
		Record.ExtDimension3 = Item.ExtDimension3;
	EndDo;
	
	// valuation of amount dues
	For Each Item In ValuationOfAmountDues Do
		Record = RegisterRecords.BookkeepingAccountingPolicyValuationOfAmountDues.Add();
		Record.Period = Date;
		Record.Company = Company;
		
		Record.Account_AmountDue = Item.Account_AmountDue;
		Record.Account_Valuation = Item.Account_Valuation;
		Record.UseAccount = Item.UseAccount;
	EndDo;
	
	// accounts for exchange rate differences
	For Each Item In ExchangeRateDifferenceAccounts Do
		Record = RegisterRecords.BookkeepingAccountingPolicyExchangeRateDifference.Add();
		Record.Period = Date;
		Record.Company = Company;
		
		Record.CarriedOut = Item.CarriedOut;
		Record.Sign = Item.Sign;
		Record.GroupKind = Item.GroupKind;
		
		Record.Account = Item.Account;
		Record.ExtDimension1 = Item.ExtDimension1;
		Record.ExtDimension2 = Item.ExtDimension2;
		Record.ExtDimension3 = Item.ExtDimension3;
	EndDo;
	
	// accounts for exchange rate differences
	For Each Item In GeneralRoundingAccounts Do
		Record = RegisterRecords.BookkeepingAccountingPolicyGeneralRounding.Add();
		Record.Period = Date;
		Record.Company = Company;
		
		Record.Sign = Item.Sign;
		
		Record.Account = Item.Account;
		Record.ExtDimension1 = Item.ExtDimension1;
		Record.ExtDimension2 = Item.ExtDimension2;
		Record.ExtDimension3 = Item.ExtDimension3;
	EndDo;


	
EndProcedure

Procedure Posting(Cancel, PostingMode)
		
	Record = RegisterRecords.AccountingPolicyGeneral.Add();
	
	Record.Period  = Date;
	Record.Company = Company;
	
	Record.ExchangeRateForCalculatingSalesAndPurchase = ExchangeRateForCalculatingSalesAndPurchase;
	
	Record.AdditionalCostOfGoodsPostingMethodWhenAverage = AdditionalCostOfGoodsPostingMethodWhenAverage;
	Record.CostOfGoodsWriteOffDefaultDirection           = CostOfGoodsWriteOffDefaultDirection;
	
	Record.UseBudgeting                              = UseBudgeting;
	Record.BudgetCurrency                            = BudgetCurrency;
	Record.ControlPurchaseInvoiceInputtingWithBudget = ControlPurchaseInvoiceInputtingWithBudget;
	Record.InvoiceAmountTypeForBudgetControl         = InvoiceAmountTypeForBudgetControl;
	Record.VATCalculationMethod                      = VATCalculationMethod;
	Record.Payroll_AccidentInsuranceCompany			 = Payroll_AccidentInsuranceCompany;
	Record.Payroll_IllnessToBonus					 = Payroll_IllnessToBonus;
	Record.CostingMethod = CostingMethod;
	Record.CostingCurrencyMethod = CostingCurrencyMethod;
	
	AccountingGroupsMap = New Map;
		
	SourcePointInTime = New PointInTime(Date, Ref);
	
	If AdditionalProperties.PrevCostingMethod <> CostingMethod Then
		// need to reset COGS sequence by all pairs item+company
		
		CompaniesArray = New Array;
		CompaniesArray.Add(Company);
		If AdditionalProperties.Property("PrevCompany") Then
			CompaniesArray.Add(AdditionalProperties.PrevCompany);
		EndIf;	
		COGSBoundaryQuery = New Query;
		COGSBoundaryQuery.Text = "SELECT DISTINCT
								 |	CostOfGoodsBoundaries.Item,
								 |	CostOfGoodsBoundaries.Company,
								 |	CostOfGoodsBoundaries.PointInTime
								 |FROM
								 |	Sequence.CostOfGoods.Boundaries AS CostOfGoodsBoundaries
								 |WHERE
								 |	CostOfGoodsBoundaries.Company IN(&CompaniesArray)
								 |	AND CostOfGoodsBoundaries.PointInTime > &PointInTime";
		COGSBoundaryQuery.SetParameter("CompaniesArray",CompaniesArray);
		COGSBoundaryQuery.SetParameter("PointInTime",SourcePointInTime);
		QueryResult = COGSBoundaryQuery.Execute();
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			SequenceFilter = New Structure("Company, Item",Selection.Company,Selection.Item);
			
			If Sequences.CostOfGoods.Validate(SourcePointInTime, SequenceFilter)
				AND Sequences.CostOfGoods.GetBound(SequenceFilter).Date>=SourcePointInTime.Date Then
				Sequences.CostOfGoods.SetBound(SourcePointInTime, SequenceFilter);
			EndIf;
			
		EndDo;	
		
	EndIf;	
	
	If SessionParameters.IsBookkeepingAvailable Then
		PostingBookkeeping();
	EndIf;	
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////

Function GetAttributesStructureForTabularPartsValidation(PostingMode) Export
	
	//TabularPartsStructure = New Structure();
	//
	//If SessionParameters.IsBookkeepingAvailable Then
	//	//Bookkeeping
	//	
	//	// CostOfGoodsMovementsDirections
	//	AttributesStructure = New Structure("Direction, Account");
	//	
	//	CostOfGoodsMovementsDirectionsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	//	CostOfGoodsMovementsDirectionsValueTable = Alerts.AddAttributesValueTableRow(CostOfGoodsMovementsDirectionsValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Warning);
	//	CostOfGoodsMovementsDirectionsValueTable = Alerts.AddAttributesValueTableRow(CostOfGoodsMovementsDirectionsValueTable,"ItemAccountingGroup, Direction",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
	//	
	//	TabularPartsStructure.Insert("CostOfGoodsMovementsDirections",CostOfGoodsMovementsDirectionsValueTable);
	//	
	//	
	//	// ValuationOfAmountDues
	//	If ValuationOfAmountDues.Count() > 0 Then
	//		AttributesStructure = New Structure("Account_AmountDue");
	//		
	//		ValuationOfAmountDuesValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	//		ValuationOfAmountDuesValueTable = Alerts.AddAttributesValueTableRow(ValuationOfAmountDuesValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Warning);
	//		ValuationOfAmountDuesValueTable = Alerts.AddAttributesValueTableRow(ValuationOfAmountDuesValueTable,"Account_AmountDue",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
	//		
	//		TabularPartsStructure.Insert("ValuationOfAmountDues",ValuationOfAmountDuesValueTable);
	//	EndIf;
	//	
	//	// ExchangeRateDifferenceAccounts
	//	If ExchangeRateDifferenceAccounts.Count() > 0 Then
	//		AttributesStructure = New Structure("CarriedOut, Sign, GroupKind, Account" );
	//		
	//		ExchangeRateDifferenceAccountsValueTable = Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
	//		ExchangeRateDifferenceAccountsValueTable = Alerts.AddAttributesValueTableRow(ExchangeRateDifferenceAccountsValueTable,"CheckNotEmpty",,Enums.AlertsAttributesPropertyType.Property,Enums.AlertType.Warning);
	//		ExchangeRateDifferenceAccountsValueTable = Alerts.AddAttributesValueTableRow(ExchangeRateDifferenceAccountsValueTable,"CarriedOut, Sign, GroupKind",,Enums.AlertsAttributesPropertyType.UniqueAttributes,Enums.AlertType.Error);
	//		
	//		TabularPartsStructure.Insert("ExchangeRateDifferenceAccounts",ExchangeRateDifferenceAccountsValueTable);
	//	EndIf;
	//	
	//	//Bookkeeping
	//EndIf;
	//
	//Return TabularPartsStructure;
	
EndFunction


