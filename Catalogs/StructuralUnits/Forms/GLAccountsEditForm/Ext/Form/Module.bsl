﻿
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	RetailAmountAccounting.Period,
	|	RetailAmountAccounting.Recorder,
	|	RetailAmountAccounting.LineNumber,
	|	RetailAmountAccounting.Active,
	|	RetailAmountAccounting.RecordType,
	|	RetailAmountAccounting.Company,
	|	RetailAmountAccounting.StructuralUnit,
	|	RetailAmountAccounting.Currency,
	|	RetailAmountAccounting.Amount,
	|	RetailAmountAccounting.AmountCur,
	|	RetailAmountAccounting.Cost,
	|	RetailAmountAccounting.ContentOfAccountingRecord,
	|	RetailAmountAccounting.SalesDocument
	|FROM
	|	AccumulationRegister.RetailAmountAccounting AS RetailAmountAccounting
	|WHERE
	|	RetailAmountAccounting.StructuralUnit = &StructuralUnit");
	
	Query.SetParameter("StructuralUnit", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // CancelGLAccountChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountInRetail = Parameters.GLAccountInRetail;
	MarkupGLAccount = Parameters.MarkupGLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'There are register records of this retail point in the base! You can not change the GL account!'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
	ThisIsRetailAccrualAccounting = Ref.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	GLAccountInRetail = PredefinedValue("ChartOfAccounts.Managerial.ProductsFinishedProducts");
	MarkupGLAccount = PredefinedValue("ChartOfAccounts.Managerial.TradeMarkup");
	NotifyAboutSettlementAccountChange();
	
EndProcedure // Default()

&AtClient
Procedure GLAccountInRetailOnChange(Item)
	
	If Not ValueIsFilled(GLAccountInRetail) Then
		GLAccountInRetail = PredefinedValue("ChartOfAccounts.Managerial.ProductsFinishedProducts");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure MarkupGLAccountOnChange(Item)
	
	If Not ValueIsFilled(MarkupGLAccount) Then
		MarkupGLAccount = PredefinedValue("ChartOfAccounts.Managerial.TradeMarkup");
	EndIf;
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccountInRetail, MarkupGLAccount",
		GLAccountInRetail, MarkupGLAccount
	);
	
	Notify("AccountsChangedStructuralUnits", ParameterStructure);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ThisIsRetailAccrualAccounting Then
		Cancel = True;
		ShowMessageBox(, NStr("en='GL accounts are edited only for retail with amount accounting!'"));
	EndIf;

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
