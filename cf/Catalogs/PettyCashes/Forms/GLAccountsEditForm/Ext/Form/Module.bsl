
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	CashAssets.Period,
	|	CashAssets.Recorder,
	|	CashAssets.LineNumber,
	|	CashAssets.Active,
	|	CashAssets.RecordType,
	|	CashAssets.Company,
	|	CashAssets.CashAssetsType,
	|	CashAssets.BankAccountPettyCash,
	|	CashAssets.Currency,
	|	CashAssets.Amount,
	|	CashAssets.AmountCur,
	|	CashAssets.ContentOfAccountingRecord,
	|	CashAssets.Item
	|FROM
	|	AccumulationRegister.CashAssets AS CashAssets
	|WHERE
	|	CashAssets.BankAccountPettyCash = &BankAccountPettyCash");
	
	Query.SetParameter("BankAccountPettyCash", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // CancelGLAccountChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en='There are transactions in base by this petty cash! You can not change the GL account!';ru='В базе есть движения по этой кассе! Изменение счета учета запрещено!'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	GLAccount = PredefinedValue("ChartOfAccounts.Managerial.PettyCash");
	NotifyAccountChange();
	
EndProcedure // Default()

&AtClient
Procedure GLAccountOnChange(Item)
	
	If Not ValueIsFilled(GLAccount) Then
		GLAccount = PredefinedValue("ChartOfAccounts.Managerial.PettyCash");
	EndIf;
	NotifyAccountChange();
	
EndProcedure

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount
	);
	
	Notify("PettyCashAccountsChanged", ParameterStructure);
	
EndProcedure



