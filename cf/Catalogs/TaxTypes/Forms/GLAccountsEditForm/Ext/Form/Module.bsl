
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	TaxesSettlements.Period,
	|	TaxesSettlements.Recorder,
	|	TaxesSettlements.LineNumber,
	|	TaxesSettlements.Active,
	|	TaxesSettlements.RecordType,
	|	TaxesSettlements.Company,
	|	TaxesSettlements.TaxKind,
	|	TaxesSettlements.Amount,
	|	TaxesSettlements.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.TaxesSettlements AS TaxesSettlements
	|WHERE
	|	TaxesSettlements.TaxKind = &TaxKind");
	
	Query.SetParameter("TaxKind", ?(ValueIsFilled(Ref), Ref, Undefined));
	
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
	GLAccountForReimbursement = Parameters.GLAccountForReimbursement;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en='There are transactions in base by this tax kind! You can not change the GL account!';ru='В базе есть движения по этому виду налога! Изменение счета учета запрещено!'");
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
	
	GLAccount = PredefinedValue("ChartOfAccounts.Managerial.Taxes");
	GLAccountForReimbursement = PredefinedValue("ChartOfAccounts.Managerial.TaxesToRefund");
	NotifyAccountChange();
	
EndProcedure // Default()

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount, GLAccountForReimbursement",
		GLAccount, GLAccountForReimbursement
	);
	
	Notify("AccountsTaxTypesChanged", ParameterStructure);
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If Not ValueIsFilled(GLAccount) Then
		GLAccount = PredefinedValue("ChartOfAccounts.Managerial.Taxes");
	EndIf;
	NotifyAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountForReimbursementOnChange(Item)
	
	If Not ValueIsFilled(GLAccountForReimbursement) Then
		GLAccount = PredefinedValue("ChartOfAccounts.Managerial.TaxesToRefund");
	EndIf;
	NotifyAccountChange();
	
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
