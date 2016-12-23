
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(MessageText)
	
	Query = New Query(
	"SELECT
	|	FixedAssets.Period,
	|	FixedAssets.Recorder,
	|	FixedAssets.LineNumber,
	|	FixedAssets.Active,
	|	FixedAssets.RecordType,
	|	FixedAssets.Company,
	|	FixedAssets.FixedAsset,
	|	FixedAssets.Cost,
	|	FixedAssets.Depreciation,
	|	FixedAssets.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.FixedAsset = &FixedAsset");
	
	Query.SetParameter("FixedAsset", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // CancelGLAccountChange()

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure("GLAccount, DepreciationAccount", GLAccount, DepreciationAccount);
	Notify("AccountsChangedFixedAssets", ParameterStructure);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	DepreciationAccount = Parameters.DepreciationAccount;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en='There are transactions in base by this fixed asset! GL account change is prohibited!';ru='В базе есть движения по этому внеоборотному активу! Изменение счетов учета запрещено!'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
Procedure GLAccountOnChange(Item)
	
	If Not ValueIsFilled(GLAccount) Then
		GLAccount = PredefinedValue("ChartOfAccounts.Managerial.FixedAssets");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure DepreciationAccountOnChange(Item)
	
	If Not ValueIsFilled(DepreciationAccount) Then
		DepreciationAccount = PredefinedValue("ChartOfAccounts.Managerial.DepreciationFixedAssets");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	GLAccount = PredefinedValue("ChartOfAccounts.Managerial.FixedAssets");
	DepreciationAccount = PredefinedValue("ChartOfAccounts.Managerial.DepreciationFixedAssets");
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure // Default()














