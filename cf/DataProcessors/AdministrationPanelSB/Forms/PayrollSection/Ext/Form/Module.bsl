
&AtClient
Var RefreshInterface;

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonUseClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure // VisibleManagement()

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseSubsystemPayroll" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "UsageSettings",	"Enabled", ConstantsSet.FunctionalOptionUseSubsystemPayroll);
		CommonUseClientServer.SetFormItemProperty(Items, "PayrollSectionCatalogs","Enabled", ConstantsSet.FunctionalOptionUseSubsystemPayroll);
		
		If Not ConstantsSet.FunctionalOptionUseSubsystemPayroll Then
			
			Constants.FunctionalOptionUseJobSharing.Set(False);
			Constants.FunctionalOptionDoStaffSchedule.Set(False);
			Constants.FunctionalOptionAccountingDoIncomeTax.Set(False);
			
		EndIf;
			
	EndIf;
	
	// there aren't dependent options requiring accessibility management in section
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseSubsystemPayroll" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseSubsystemPayroll = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseJobSharing" Then
		
		ConstantsSet.FunctionalOptionUseJobSharing = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionAccountingDoIncomeTax" Then
		
		ConstantsSet.FunctionalOptionAccountingDoIncomeTax = CurrentValue;
		
	EndIf;
	
EndProcedure // ReturnFormAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure to control the disabling of the "Use payroll by registers" option.
//
&AtServer
Function CheckRecordsByPayrollSubsystemRegisters()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	AccrualsAndDeductions.Company
	|FROM
	|	AccumulationRegister.AccrualsAndDeductions AS AccrualsAndDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	PayrollPayments.Company
	|FROM
	|	AccumulationRegister.PayrollPayments AS PayrollPayments";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Register Accruals and deductions.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en='There are transactions in infobase by the register ""Accruals And Deductions""! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют движения по регистру ""Начисления и удержания""! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	// 2. Register Payroll payments.
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='Infobase contains transactions by register ""Payroll payments""! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют движения по регистру ""Расчеты с персоналом""! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CheckRecordsBySubsystemRegistersPayroll()

// Procedure to control the disabling of the "Use salary by documents and catalogs" option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUsePayrollSubsystem()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Payroll.Ref
	|FROM
	|	Document.Payroll AS Payroll
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	AccrualsAndDeductions.Company,
	|	JobSheet.Ref
	|FROM
	|	AccumulationRegister.AccrualsAndDeductions AS AccrualsAndDeductions
	|		LEFT JOIN Document.JobSheet AS JobSheet
	|		ON AccrualsAndDeductions.Recorder = JobSheet.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CustomerOrderPerformers.Employee
	|FROM
	|	Document.CustomerOrder.Performers AS CustomerOrderPerformers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EnterOpeningBalance.Ref
	|FROM
	|	Document.EnterOpeningBalance AS EnterOpeningBalance
	|WHERE
	|	EnterOpeningBalance.AccountingSection = &AccountingSection
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CashPayment.Ref
	|FROM
	|	Document.CashPayment AS CashPayment
	|WHERE
	|	(CashPayment.OperationKind = VALUE(Enum.OperationKindsCashPayment.Salary)
	|			OR CashPayment.OperationKind = VALUE(Enum.OperationKindsCashPayment.SalaryForEmployee))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	PaymentExpense.Ref
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.OperationKind = VALUE(Enum.OperationKindsPaymentExpense.Salary)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Employees.Ref
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.OccupationType = VALUE(Enum.OccupationTypes.Jobsharing)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	AccrualAndDeductionKinds.Ref
	|FROM
	|	Catalog.AccrualAndDeductionKinds AS AccrualAndDeductionKinds
	|WHERE
	|	AccrualAndDeductionKinds.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax)";
	
	Query.SetParameter("AccountingSection", "Personnel settlements");
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Document Payroll.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en='Infobase contains documents ""Payroll""! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют документы ""Начисление зарплаты""! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	// 2. The Job sheet document
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='Infobase contains documents ""Job sheet"" which are used to accrue salary to employees! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют документы ""Сдельный наряд"", которые начисляют зарплату сотрудникам! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	// 3. Document Order - order.
	If Not ResultsArray[2].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='Infobase contains documents ""Purchase order"" which are payroll to employees! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют документы ""Заказ - наряд"", которые начисляют зарплату сотрудникам! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	// 4. Document Enter opening balance.
	If Not ResultsArray[3].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) +  NStr("en='Infobase contains documents ""Entry initial balance"" by accounting section ""Payroll payments""! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют документы ""Ввод начальных остатвков"", по разделу учета ""Расчеты с персоналом""! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	// 5. Document Cash payment.
	If Not ResultsArray[4].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='Infobase contains documents ""Cash payment"" with operation kind ""Salary by statements"" and/or ""Employee salary""! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют документы ""Расход из кассы"", с видом операции ""Зарплата по ведомости"" и/или ""Зарплата сотруднику""! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	// 6. Document Payment expense.
	If Not ResultsArray[5].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are documents ""Payment expense"" with operation kind ""Salary"" in infobase! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют документы ""Расод со счета"", с видом операции ""Зарплата""! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	// 7. Catalog Employees.
	If Not ResultsArray[6].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are users with employment type ""Jobsharing"" in the infobase! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе есть сотрудники с типом занятости ""Совместительство""! Снятие флага ""Зарплата"" запрещено!'");	
		
	EndIf;
	
	// 8. Catalog Accrual and deduction kinds.
	If Not ResultsArray[7].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en='There are catalog items ""Accrual and deduction kinds"" with type ""Tax"" in infobase! It is prohibited to clear the ""Payroll"" check box!';ru='В информационной базе присутствуют элементы справочника ""Виды начислений и удержаний"" с типом ""Налог""! Снятие флага ""Зарплата"" запрещено!'");
		
	EndIf;
	
	If IsBlankString(ErrorText) Then
		
		ErrorText = CheckRecordsByPayrollSubsystemRegisters();
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancelDisableFunctionalOptionUseSubsystemPayroll()

// Check on the possibility of option disable UseJobsharing.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseJobsharing()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Employees.Ref
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.OccupationType = VALUE(Enum.OccupationTypes.Jobsharing)";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='There are employees with occupation type ""Jobsharing"" in base! The flag removal is prohibited!';ru='В базе есть сотрудники с типом занятости ""Совместительство""! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancelDisableFunctionalOptionUseJobsharing()

// Check on the possibility of option disable DoIncomeTaxAccounting.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingDoIncomeTax()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	AccrualAndDeductionKinds.Ref
		|FROM
		|	Catalog.AccrualAndDeductionKinds AS AccrualAndDeductionKinds
		|WHERE
		|	AccrualAndDeductionKinds.Type = VALUE(Enum.AccrualAndDeductionTypes.Tax)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='There are catalog items ""Accrual and deduction kinds"" with type ""Tax"" in base! The flag removal is prohibited!';ru='В базе присутствуют элементы справочника ""Виды начислений и удержаний"" с типом ""Налог""! Снятие флага запрещено!'");	
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancelDisableFunctionalOptionAccountingDoIncomeTax()

// Initialization of checking the possibility to disable the CurrencyTransactionsAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Enable/disable  Payroll section
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseSubsystemPayroll" Then
	
		If Constants.FunctionalOptionUseSubsystemPayroll.Get() <> ConstantsSet.FunctionalOptionUseSubsystemPayroll
			AND (NOT ConstantsSet.FunctionalOptionUseSubsystemPayroll) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUsePayrollSubsystem();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If the catalog Employees there are part-time workers then it is not allowed to delete flag FunctionalOptionUseJobSharing
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseJobSharing" Then
		
		If Constants.FunctionalOptionUseJobSharing.Get() <> ConstantsSet.FunctionalOptionUseJobSharing
			AND (NOT ConstantsSet.FunctionalOptionUseJobSharing) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseJobsharing();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are catalog items "Accrual and deduction kinds" with type "Tax" then it is not allowed to delete flag FunctionalOptionAccountingDoIncomeTax
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingDoIncomeTax" Then
		
		If Constants.FunctionalOptionAccountingDoIncomeTax.Get() <> ConstantsSet.FunctionalOptionAccountingDoIncomeTax
			AND (NOT ConstantsSet.FunctionalOptionAccountingDoIncomeTax) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingDoIncomeTax();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction // CheckAbilityToChangeAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure // UpdateSystemParameters()

// Procedure - command handler CatalogIndividualDocumentKinds.
//
&AtClient
Procedure CatalogIndividualsDocumentsKinds(Command)
	
	OpenForm("Catalog.IndividualsDocumentsKinds.ListForm");
	
EndProcedure // CatalogIndividualDocumentKinds()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose()
	
	RefreshApplicationInterface();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange field FunctionalOptionUseSubsystemPayroll.
&AtClient
Procedure FunctionalOptionUseSubsystemPayrollOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseSubsystemPayrollOnChange()

// Procedure - ref click handler FunctionalOptionDoStaffScheduleHelp.
//
&AtClient
Procedure FunctionalOptionDoStaffScheduleOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionDoStaffScheduleOnChange()

// Procedure - event handler OnChange field FunctionalOptionUseJobsharing.
//
&AtClient
Procedure FunctionalOptionUseJobSharingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseJobsharingOnChange()

// Procedure - event handler OnChange field FunctionalOptionReflectIncomeTaxes.
&AtClient
Procedure FunctionalOptionToReflectIncomeTaxesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionReflectIncomeTaxesOnChange()
// 














