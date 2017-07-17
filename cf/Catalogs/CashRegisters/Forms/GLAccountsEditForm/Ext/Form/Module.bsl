
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
	|	CashInCashRegisters.Period,
	|	CashInCashRegisters.Recorder,
	|	CashInCashRegisters.LineNumber,
	|	CashInCashRegisters.Active,
	|	CashInCashRegisters.RecordType,
	|	CashInCashRegisters.Company,
	|	CashInCashRegisters.CashCR,
	|	CashInCashRegisters.Amount,
	|	CashInCashRegisters.AmountCur,
	|	CashInCashRegisters.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.CashInCashRegisters AS CashInCashRegisters
	|WHERE
	|	CashInCashRegisters.CashCR = &CashCR");
	
	Query.SetParameter("CashCR", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // CancelGLAccountChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en='Records are registered for this cash register in the infobase. Cannot change the GL account.';ru='В базе есть движения по этой кассе ККМ! Изменение счета учета запрещено!'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF THE FORM COMMAND PANELS

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
	
	Notify("CashRegisterAccountsChanged", ParameterStructure);
	
EndProcedure



