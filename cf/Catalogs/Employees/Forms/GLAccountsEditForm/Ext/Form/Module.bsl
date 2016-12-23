
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks account change option.
//
&AtServer
Function CancelPersonnelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	PayrollPayments.Period,
	|	PayrollPayments.Recorder,
	|	PayrollPayments.LineNumber,
	|	PayrollPayments.Active,
	|	PayrollPayments.RecordType,
	|	PayrollPayments.Company,
	|	PayrollPayments.StructuralUnit,
	|	PayrollPayments.Employee,
	|	PayrollPayments.Currency,
	|	PayrollPayments.RegistrationPeriod,
	|	PayrollPayments.Amount,
	|	PayrollPayments.AmountCur,
	|	PayrollPayments.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.PayrollPayments AS PayrollPayments
	|WHERE
	|	PayrollPayments.Employee = &Employee");
	
	Query.SetParameter("Employee", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // CancelPersonnelGLAccountChange()

// Function checks account change option.
//
&AtServer
Function CancelAdvanceHoldersGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	AdvanceHolderPayments.Period,
	|	AdvanceHolderPayments.Recorder,
	|	AdvanceHolderPayments.LineNumber,
	|	AdvanceHolderPayments.Active,
	|	AdvanceHolderPayments.RecordType,
	|	AdvanceHolderPayments.Company,
	|	AdvanceHolderPayments.Employee,
	|	AdvanceHolderPayments.Currency,
	|	AdvanceHolderPayments.Document,
	|	AdvanceHolderPayments.Amount,
	|	AdvanceHolderPayments.AmountCur,
	|	AdvanceHolderPayments.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.AdvanceHolderPayments AS AdvanceHolderPayments
	|WHERE
	|	AdvanceHolderPayments.Employee = &Employee");
	
	Query.SetParameter("Employee", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // CancelAdvanceHoldersGLAccountChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SettlementsHumanResourcesGLAccount = Parameters.SettlementsHumanResourcesGLAccount;
	AdvanceHoldersGLAccount = Parameters.AdvanceHoldersGLAccount;
	OverrunGLAccount = Parameters.OverrunGLAccount;
	Ref = Parameters.Ref;
	
	If CancelPersonnelGLAccountChange(Ref) Then
		Items.WithStaff.ToolTip = NStr("en='There are records in the base for this employee! Change of settlement GL accounts with human resources is prohibited!';ru='В базе есть движения по этому сотруднику! Изменение счетов учета по расчетам с персоналом запрещено!'");
		Items.WithStaff.Enabled = False;
	EndIf;

	If CancelAdvanceHoldersGLAccountChange(Ref) Then
		Items.WithAdvanceHolder.ToolTip = NStr("en='There are records in the base for this advance holder! Change of settlement GL accounts with advance holders is prohibited!';ru='В базе есть движения по этому подотчетнику! Изменение счетов учета по расчетам с подотчетниками запрещено!'");
		Items.WithAdvanceHolder.Enabled = False;
	EndIf;
	
	If Not Items.WithStaff.Enabled
		AND Not Items.WithAdvanceHolder.Enabled Then
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	SettlementsHumanResourcesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.PayrollPaymentsOnPay");
	AdvanceHoldersGLAccount = PredefinedValue("ChartOfAccounts.Managerial.AdvanceHolderPayments");
	OverrunGLAccount = PredefinedValue("ChartOfAccounts.Managerial.OverrunOfAdvanceHolders");
	
EndProcedure // Default()

&AtClient
Procedure StaffGLAccountOnChange(Item)
	
	If Not ValueIsFilled(SettlementsHumanResourcesGLAccount) Then
		SettlementsHumanResourcesGLAccount = PredefinedValue("ChartOfAccounts.Managerial.PayrollPaymentsOnPay");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure AdvanceHoldersGLAccountOnChange(Item)
	
	If Not ValueIsFilled(AdvanceHoldersGLAccount) Then
		AdvanceHoldersGLAccount = PredefinedValue("ChartOfAccounts.Managerial.AdvanceHolderPayments");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure OverrunGLAccountOnChange(Item)
	
	If Not ValueIsFilled(OverrunGLAccount) Then
		OverrunGLAccount = PredefinedValue("ChartOfAccounts.Managerial.OverrunOfAdvanceHolders");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"SettlementsHumanResourcesGLAccount, AdvanceHoldersGLAccount, OverrunGLAccount",
		SettlementsHumanResourcesGLAccount, AdvanceHoldersGLAccount, OverrunGLAccount
	);
	
	Notify("AccountsChangedEmployees", ParameterStructure);
	
EndProcedure














