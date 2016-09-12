
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	Inventory.Period,
	|	Inventory.Recorder,
	|	Inventory.LineNumber,
	|	Inventory.Active,
	|	Inventory.RecordType,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.ProductsAndServices,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.CustomerOrder,
	|	Inventory.Quantity,
	|	Inventory.Amount,
	|	Inventory.StructuralUnitCorr,
	|	Inventory.CorrGLAccount,
	|	Inventory.ProductsAndServicesCorr,
	|	Inventory.CharacteristicCorr,
	|	Inventory.BatchCorr,
	|	Inventory.CustomerCorrOrder,
	|	Inventory.Specification,
	|	Inventory.SpecificationCorr,
	|	Inventory.OrderSales,
	|	Inventory.SalesDocument,
	|	Inventory.Division,
	|	Inventory.Responsible,
	|	Inventory.VATRate,
	|	Inventory.FixedCost,
	|	Inventory.ProductionExpenses,
	|	Inventory.Return,
	|	Inventory.ContentOfAccountingRecord,
	|	Inventory.RetailTransferAccrualAccounting
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.ProductsAndServices = &ProductsAndServices
	|	OR Inventory.ProductsAndServicesCorr = &ProductsAndServices");
	
	Query.SetParameter("ProductsAndServices", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // DenialChangeInventoryGLAccount()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InventoryGLAccount = Parameters.InventoryGLAccount;
	ExpensesGLAccount = Parameters.ExpensesGLAccount;
	Ref = Parameters.Ref;
	
	// FD Use Production subsystems.
	UseSubsystemProduction = Constants.FunctionalOptionUseSubsystemProduction.Get();
	
	Items.InventoryGLAccount.Visible = ?(
		(NOT ValueIsFilled(Parameters.ProductsAndServicesType))
		 OR Parameters.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem,
		True,
		False
	);
	
	Items.ExpensesGLAccount.Visible = ?(
		(NOT ValueIsFilled(Parameters.ProductsAndServicesType))
		 OR Parameters.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
		 //AND NOT UseSubsystemProduction)
		 OR Parameters.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work
		 OR Parameters.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Operation
		 OR Parameters.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service,
		True,
		False
	);
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en='There are register records in the base of this products and services! You can not change the GL account!';ru='В базе есть движения по этой номенклатуре! Изменение счета учета запрещено!'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()


// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	If Items.InventoryGLAccount.Visible Then
		InventoryGLAccount = PredefinedValue("ChartOfAccounts.Managerial.RawMaterialsAndMaterials");
	EndIf;
	
	If Items.ExpensesGLAccount.Visible Then
		If UseSubsystemProduction Then
			ExpensesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.UnfinishedProduction");
		Else
			ExpensesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.CommercialExpenses");
		EndIf;
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure // Default()

&AtClient
Procedure InventoryGLAccountOnChange(Item)
	
	If Not ValueIsFilled(InventoryGLAccount) Then
		InventoryGLAccount = PredefinedValue("ChartOfAccounts.Managerial.RawMaterialsAndMaterials");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure ExpensesGLAccountOnChange(Item)
	
	If Not ValueIsFilled(ExpensesGLAccount) Then
		If UseSubsystemProduction Then
			ExpensesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.UnfinishedProduction");
		Else
			ExpensesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.CommercialExpenses");
		EndIf;
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"InventoryGLAccount, ExpensesGLAccount",
		InventoryGLAccount, ExpensesGLAccount
	);
	
	Notify("ProductsAndServicesAccountsChanged", ParameterStructure);
	
EndProcedure



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
