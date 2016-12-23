
#Region ServiceProceduresAndFunctions

// Procedure for creating the owner form notification about the change of account
//
&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure("GLExpenseAccount", GLExpenseAccount);
	Notify("AccountsChangedAccrualAndDeductionKinds", ParameterStructure);
	
EndProcedure // NotifyAccountChange()

// Function checks GL account change option.
//
&AtServer
Function CancelGLExpenseAccountChange(AccrualDeductionKind)
	
	Query = New Query(
	"SELECT
	|	AccrualsAndDeductions.Period,
	|	AccrualsAndDeductions.Recorder,
	|	AccrualsAndDeductions.LineNumber,
	|	AccrualsAndDeductions.Active,
	|	AccrualsAndDeductions.Company,
	|	AccrualsAndDeductions.StructuralUnit,
	|	AccrualsAndDeductions.Employee,
	|	AccrualsAndDeductions.RegistrationPeriod,
	|	AccrualsAndDeductions.Currency,
	|	AccrualsAndDeductions.AccrualDeductionKind,
	|	AccrualsAndDeductions.Amount,
	|	AccrualsAndDeductions.AmountCur,
	|	AccrualsAndDeductions.StartDate,
	|	AccrualsAndDeductions.EndDate,
	|	AccrualsAndDeductions.DaysWorked,
	|	AccrualsAndDeductions.HoursWorked,
	|	AccrualsAndDeductions.Size
	|FROM
	|	AccumulationRegister.AccrualsAndDeductions AS AccrualsAndDeductions
	|WHERE
	|	AccrualsAndDeductions.AccrualDeductionKind = &AccrualDeductionKind");
	
	Query.SetParameter("AccrualDeductionKind", ?(ValueIsFilled(AccrualDeductionKind), AccrualDeductionKind, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction // CancelGLExpenseAccountChange()

// Procedure fills the data structure for the GL account selection.
//
&AtServer
Procedure ReceiveDataForSelectAccountsSettlements(DataStructure)
	
	GLAccountsAvailableTypes = New Array;
	AccrualDeductionKind = DataStructure.AccrualDeductionKind;
	If Not ValueIsFilled(AccrualDeductionKind) Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.UnfinishedProduction);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	ElsIf AccrualDeductionKind.Type = Enums.AccrualAndDeductionTypes.Accrual Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.UnfinishedProduction);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		
	ElsIf AccrualDeductionKind.Type = Enums.AccrualAndDeductionTypes.Deduction Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	EndIf;
	
	DataStructure.Insert("GLAccountsAvailableTypes", GLAccountsAvailableTypes);
	
EndProcedure // ReceiveDataForSelectAccountsSettlements()

// Procedure sets the link of selection parameters for the "GL expense account" attribute
//
&AtServer
Procedure SetConnectionSelectAtServerParameters()
	
	DataStructure = New Structure;
	DataStructure.Insert("AccrualDeductionKind", AccrualDeductionKind);
		
	ReceiveDataForSelectAccountsSettlements(DataStructure);
	
	NewArray = New Array;
	NewParameter = New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(DataStructure.GLAccountsAvailableTypes));
	NewArray.Add(NewParameter);
	ChoiceParameters = New FixedArray(NewArray);
	Items.GLExpenseAccount.ChoiceParameters = ChoiceParameters
	
EndProcedure // SetConnectionSelectAtServerParameters()

#EndRegion

#Region FormEventsHandlers

// Procedure - event handler of the OnCreateAtServer form
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLExpenseAccount				= Parameters.GLExpenseAccount;
	AccrualDeductionKind	= Parameters.Ref;
	IsTax				= (AccrualDeductionKind.Type = Enums.AccrualAndDeductionTypes.Tax);
	
	SetConnectionSelectAtServerParameters();
	
	If CancelGLExpenseAccountChange(AccrualDeductionKind) Then
		
		Items.GLAccountsGroup.ToolTip	= NStr("en='There are records of this kind of accrual (deduction) in the base! You can not change the GL account!';ru='В базе есть движения по этому виду начисления (удержания)! Изменение счета учета запрещено!'");
		Items.GLAccountsGroup.Enabled	= False;
		Items.Default.Visible			= False;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler of the OnCreateAtServer form
//
&AtClient
Procedure OnOpen(Cancel)
	
	If IsTax Then
		
		ShowMessageBox(, NStr("en='You can not edit the GL accounts for the Tax accrual kind!';ru='Для типа вида начисления Налог счета учета не редактируются!'"));
		Cancel = True;
		
	EndIf;
	
EndProcedure // OnOpen()

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler by default.
//
&AtClient
Procedure Default(Command)
	
	GLExpenseAccount = PredefinedValue("ChartOfAccounts.Managerial.AdministrativeExpenses");
	NotifyAccountChange();
	
EndProcedure // Default()

#EndRegion

#Region FormAttributesEventsHandlers

// Event handler OnChange of the GLExpenseAccount attribute
//
&AtClient
Procedure GLExpenseAccountOnChange(Item)
	
	If Not ValueIsFilled(GLExpenseAccount) Then
		
		GLExpenseAccount = PredefinedValue("ChartOfAccounts.Managerial.AdministrativeExpenses");
		
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure // GLExpenseAccountOnChange()

#EndRegion













