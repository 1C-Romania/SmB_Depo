////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		SmallBusinessServer.GetCompany(Company)
	);
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

&AtServerNoContext
// Procedure receives the planning period data.
//
Function GetPlanningPeriodData(PlanningPeriod)
	
	StructureData = New Structure();
	
	StructureData.Insert("Periodicity", PlanningPeriod.Periodicity);
	StructureData.Insert("StartDate", PlanningPeriod.StartDate);
	StructureData.Insert("EndDate", PlanningPeriod.EndDate);
	
	Return StructureData;
	
EndFunction // ReceivePlanningPeriodData()

&AtClient
// Procedure adjusts the planning date to the planning period.
//
Procedure AlignPlanningDateByPlanningPeriod(PlanningDate)
	
	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		PlanningDate = BegOfWeek(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.TenDays") Then
		
		If Day(PlanningDate) < 11 Then
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 1);
			
		ElsIf Day(PlanningDate) < 21 Then	
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 11);
			
		Else
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 21);
			
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Month") Then
		
		PlanningDate = BegOfMonth(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Quarter") Then
		
		PlanningDate = BegOfQuarter(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.HalfYear") Then
		
		MonthOfStartDate = Month(PlanningDate);
		
		PlanningDate = BegOfYear(PlanningDate);
		
		If MonthOfStartDate > 6 Then
			
			PlanningDate = AddMonth(PlanningDate, 6);
			
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Year") Then
		
		PlanningDate = BegOfYear(PlanningDate);
		
	Else
		
		PlanningDate = '00010101';
		
	EndIf;
	
	If StartDate <> '00010101'
		AND (PlanningDate < StartDate
		OR PlanningDate > EndDate) Then
		
		PlanningDate = StartDate;
		
	EndIf;
	
EndProcedure // AlignPlanningDateByPlanningPeriod()

&AtServerNoContext
// Receives the data set from server for procedure AccountOnChange .
//
Function GetDataGLAccountType(StructureData)
	
	If StructureData.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherIncome
		OR StructureData.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses
		OR StructureData.Account.TypeOfAccount = Enums.GLAccountsTypes.CreditInterestRates Then
	
		StructureData.Insert("AccountTypeOther", True);
		
	Else
		
		StructureData.Insert("AccountTypeOther", False);
		
	EndIf;	
	
	Return StructureData;
	
EndFunction // ReceiveDataAccountType()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	StructureData = GetPlanningPeriodData(Object.PlanningPeriod);
	Periodicity = StructureData.Periodicity;
	StartDate = StructureData.StartDate;
	EndDate = StructureData.EndDate; 
	
	User = Users.CurrentUser();
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDivision");
	MainDivision = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDivision);
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

&AtClient
// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - handler of event OnChange of input field PlanningPeriod.
//
Procedure PlanningPeriodOnChange(Item)
	
	StructureData = GetPlanningPeriodData(Object.PlanningPeriod);	
	Periodicity = StructureData.Periodicity;
	StartDate = StructureData.StartDate;
	EndDate = StructureData.EndDate;
	
	For Each TabularSectionRow IN Object.DirectCost Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow IN Object.IndirectExpenses Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow IN Object.Incomings Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow IN Object.Expenses Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow IN Object.Receipts Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow IN Object.Disposal Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow IN Object.Operations Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
EndProcedure // PlanningPeriodOnChange()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS OF TABULAR SECTION DIRECT EXPENSES

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure DirectCostPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.DirectCost.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.DirectCost.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure // ReceiptsPlanningDateOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS OF THE INDIRECT EXPENSES TABULAR SECTION

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure IndirectExpensesPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.IndirectExpenses.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.IndirectExpenses.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure // IndirectExpensesPlanningDateOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS OF THE INCOME TABULAR SECTION

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure IncomePlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Incomings.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Incomings.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure // IncomePlanningDateOnChange()

&AtClient
// Procedure - handler of event OnChange of input field AccountOnChange.
// 
Procedure IncomeAccountOnChange(Item)
	
	TabularSectionRow = Items.Incomings.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Account", TabularSectionRow.Account);
	
	StructureData = GetDataGLAccountType(StructureData);
		
	If StructureData.AccountTypeOther Then
		TabularSectionRow.StructuralUnit = Undefined;
	ElsIf Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = MainDivision;
	EndIf;
			
EndProcedure // IncomingsAccountOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE COSTS TABULAR SECTION ATTRIBUTES

&AtClient
// Procedure - handler of event OnChange of input field PlanningDate.
// 
Procedure ExpensesPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Expenses.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Expenses.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure // ExpensesPlanningDateOnChange()

&AtClient
// Procedure - handler of event OnChange of input field ExpensesAccountOnChange.
//
Procedure ExpensesGLAccountOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Account", TabularSectionRow.Account);
	
	StructureData = GetDataGLAccountType(StructureData);
		
	If StructureData.AccountTypeOther Then
		TabularSectionRow.StructuralUnit = Undefined;
	ElsIf Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = MainDivision;
	EndIf;
	
EndProcedure // ExpensesGLAccountOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS OF THE RECEIPT TABULAR SECTION

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure ReceiptsPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Receipts.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Receipts.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure // ReceiptsPlanningDateOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS OF THE EXPENSE TABULAR SECTION

&AtClient
// Procedure - handler of event OnChange of input field PlanningDate.
// 
Procedure OutflowsPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Disposal.CurrentData.PlanningDate <> '00010101' Then
	   
		AlignPlanningDateByPlanningPeriod(Items.Disposal.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure // OutflowsPlanningDateOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS OF THE OPERATIONS TABULAR SECTION

&AtClient
// Procedure - handler of event OnChange of input field PlanningDate.
//
Procedure OperationsPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Operations.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Operations.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion













