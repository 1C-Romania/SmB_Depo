#Region EventsHandlers

// Function checks account change option.
//
&AtServer
Function CancelGLAccountWithCustomerChange(Ref)
	
	Query = New Query(
	"SELECT
	|	AccountsReceivable.Period,
	|	AccountsReceivable.Recorder,
	|	AccountsReceivable.LineNumber,
	|	AccountsReceivable.Active,
	|	AccountsReceivable.RecordType,
	|	AccountsReceivable.Company,
	|	AccountsReceivable.SettlementsType,
	|	AccountsReceivable.Counterparty,
	|	AccountsReceivable.Contract,
	|	AccountsReceivable.Document,
	|	AccountsReceivable.Order,
	|	AccountsReceivable.Amount,
	|	AccountsReceivable.AmountCur,
	|	AccountsReceivable.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Counterparty = &Counterparty");
	
	Query.SetParameter("Counterparty", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // DenialChangeGLAccountCustomerSettlements()

// Function checks account change option.
//
&AtServer
Function CancelGLAccountWithVendorChange(Ref)
	
	Query = New Query(
	"SELECT
	|	AccountsPayable.Period,
	|	AccountsPayable.Recorder,
	|	AccountsPayable.LineNumber,
	|	AccountsPayable.Active,
	|	AccountsPayable.RecordType,
	|	AccountsPayable.Company,
	|	AccountsPayable.SettlementsType,
	|	AccountsPayable.Counterparty,
	|	AccountsPayable.Contract,
	|	AccountsPayable.Document,
	|	AccountsPayable.Order,
	|	AccountsPayable.Amount,
	|	AccountsPayable.AmountCur,
	|	AccountsPayable.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Counterparty = &Counterparty");
	
	Query.SetParameter("Counterparty", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // DenialChangeGLAccountVendorSettlements()

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountCustomerSettlements = Parameters.GLAccountCustomerSettlements;
	CustomerAdvancesGLAccount = Parameters.CustomerAdvancesGLAccount;
	GLAccountVendorSettlements = Parameters.GLAccountVendorSettlements;
	VendorAdvancesGLAccount = Parameters.VendorAdvancesGLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountWithCustomerChange(Ref) Then
		Items.WithCustomer.ToolTip = NStr("en='There are transactions in base by this customer! Settlement GL account change with customer is prohibited!';ru='В базе есть движения по этому покупателю! Изменение счетов учета расчетов с покупателем запрещено!'");
		Items.WithCustomer.Enabled = False;
	EndIf;
		
	If CancelGLAccountWithVendorChange(Ref) Then
		Items.WithVendor.ToolTip = NStr("en='There are transactions in base by this supplier! Settlement GL account change with supplier is prohibited!';ru='В базе есть движения по этому поставщику! Изменение счетов учета расчетов с поставщиком запрещено!'");
		Items.WithVendor.Enabled = False;
	EndIf;
	
	If Not Items.WithCustomer.Enabled
		AND Not Items.WithVendor.Enabled Then
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure Default(Command)
	
	If Items.WithCustomer.Enabled Then
		GLAccountCustomerSettlements = PredefinedValue("ChartOfAccounts.Managerial.AccountsReceivable");
		CustomerAdvancesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.AccountsByAdvancesReceived");
	EndIf;
	
	If Items.WithVendor.Enabled Then
		GLAccountVendorSettlements = PredefinedValue("ChartOfAccounts.Managerial.AccountsPayable");
		VendorAdvancesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.SettlementsByAdvancesIssued");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure // Default()

&AtClient
Procedure GLAccountCustomerSettlementsOnChange(Item)
	
	If Not ValueIsFilled(GLAccountCustomerSettlements) Then
		GLAccountCustomerSettlements = PredefinedValue("ChartOfAccounts.Managerial.AccountsReceivable");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure CustomerAdvancesGLAccountOnChange(Item)
	
	If Not ValueIsFilled(CustomerAdvancesGLAccount) Then
		CustomerAdvancesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.AccountsByAdvancesReceived");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountVendorSettlementsOnChange(Item)
	
	If Not ValueIsFilled(GLAccountVendorSettlements) Then
		GLAccountVendorSettlements = PredefinedValue("ChartOfAccounts.Managerial.AccountsPayable");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure VendorAdvancesGLAccountOnChange(Item)
	
	If Not ValueIsFilled(VendorAdvancesGLAccount) Then
		VendorAdvancesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.SettlementsByAdvancesIssued");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccountCustomerSettlements, CustomerAdvanceGLAccount, GLAccountVendorSettlements, AdvanceGLAccountToSupplier",
		GLAccountCustomerSettlements, CustomerAdvancesGLAccount, GLAccountVendorSettlements, VendorAdvancesGLAccount
	);
	
	Notify("SettlementAccountsAreChanged", ParameterStructure);
	
EndProcedure

#EndRegion














