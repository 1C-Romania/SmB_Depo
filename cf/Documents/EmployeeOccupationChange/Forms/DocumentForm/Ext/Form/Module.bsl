#Region ServiceHandlers

&AtClient
// Procedure changes the current row of the Employees tabular section
//
Procedure ChangeCurrentEmployee()
	
	Items.Employees.CurrentRow = CurrentEmployee;
	
EndProcedure // ChangeCurrentEmployee()

&AtServer
// Function calls the object function FindEmployeeDeductionAccruals.
//
Function FindEmployeeAccrualsDeductionsServer(FilterStructure, Tax = False)	
	
	Document = FormAttributeToValue("Object");
	SearchResult = Document.FindEmployeeAccrualsDeductions(FilterStructure, Tax);
	ValueToFormAttribute(Document, "Object");
	
	Return SearchResult;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

&AtServer
// Fills the values of the Employees tabular section.
//
Procedure FillValues()
	
	If Object.Employees.Count() = 0 OR Object.OperationKind = Enums.OperationKindsEmployeeOccupationChange.PaymentFormChange Then
		Return;
	EndIf;
	
	For Each TSRow IN Object.Employees Do
		
		EmployeeStructure = New Structure;
		EmployeeStructure.Insert("Period", TSRow.Period - 1);
		EmployeeStructure.Insert("Employee", TSRow.Employee);
		EmployeeStructure.Insert("Company", Object.Company);
		
		GetEmployeeData(EmployeeStructure);
		
		TSRow.PreviousUnit = EmployeeStructure.StructuralUnit;
		TSRow.PreviousJobTitle = EmployeeStructure.Position;
		TSRow.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
		TSRow.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
		
	EndDo;
	
EndProcedure // 

&AtServer
// Fills the values of the Employees tabular section.
//
Procedure FillValuesAboutAllEmployees()	
	
	For Each TSRow IN Object.Employees Do
		
		If Not ValueIsFilled(TSRow.PreviousUnit)
				OR ValueIsFilled(TSRow.PreviousJobTitle) Then
		
			EmployeeStructure = New Structure;
			EmployeeStructure.Insert("Period", TSRow.Period - 1);
			EmployeeStructure.Insert("Employee", TSRow.Employee);
			EmployeeStructure.Insert("Company", Object.Company);
			
			GetEmployeeData(EmployeeStructure);
			
			TSRow.PreviousUnit = EmployeeStructure.StructuralUnit;
			TSRow.PreviousJobTitle = EmployeeStructure.Position;
			TSRow.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
			TSRow.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
		
		EndIf;
		
	EndDo;
	
EndProcedure // 

&AtServerNoContext
// Receives the server data set from the Employees tabular section.
//
Procedure GetEmployeeData(EmployeeStructure)
	
	Query = New Query(
	"SELECT
	|	EmployeesSliceLast.StructuralUnit,
	|	EmployeesSliceLast.Position,
	|	EmployeesSliceLast.OccupiedRates,
	|	EmployeesSliceLast.WorkSchedule
	|FROM
	|	InformationRegister.Employees.SliceLast(
	|			&Period,
	|			Employee = &Employee
	|				AND Company = &Company) AS EmployeesSliceLast");
	
	Query.SetParameter("Period", EmployeeStructure.Period);
	Query.SetParameter("Employee", EmployeeStructure.Employee);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(EmployeeStructure.Company));
	
	EmployeeStructure.Insert("StructuralUnit");
	EmployeeStructure.Insert("Position");
	EmployeeStructure.Insert("OccupiedRates", 1);
	EmployeeStructure.Insert("WorkSchedule");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		FillPropertyValues(EmployeeStructure, Selection);
	EndDo;
	
EndProcedure // GetDataDateOnChange()

&AtServer
// Procedure fills the selection list of the "Current employee" control field
//
Procedure FillCurrentEmployeesChoiceList()
	
	Items.CurrentEmployeeAccrualsDeductions.ChoiceList.Clear();
	Items.CurrentEmployeeTaxes.ChoiceList.Clear();
	For Each RowEmployee IN Object.Employees Do
		
		RowPresentation = String(RowEmployee.Employee) + NStr("en=', employee code: ';ru=', ТН: '") + String(RowEmployee.Employee.Code);
		Items.CurrentEmployeeAccrualsDeductions.ChoiceList.Add(RowEmployee.GetID(), RowPresentation);
		Items.CurrentEmployeeTaxes.ChoiceList.Add(RowEmployee.GetID(), RowPresentation);
		
	EndDo;
	
EndProcedure // FillCurrentEmployeesChoiceList()

&AtServer
// Procedure states availability of the form items on client.
//
// Parameters:
//  No.
//
Procedure SetVisibleAtServer()
	
	IsIsEmployeeOccupationChangeSalary = (Object.OperationKind = PredefinedValue("Enum.OperationKindsEmployeeOccupationChange.TransferAndPaymentFormChange"));
	
	Items.EmployeesFomerWorkSchedule.Visible 	= IsIsEmployeeOccupationChangeSalary;
	Items.EmployeesFomerPosition.Visible 		= IsIsEmployeeOccupationChangeSalary;
	Items.EmployeesFomerDepartment.Visible	= IsIsEmployeeOccupationChangeSalary;
	Items.EmployeesWorkSchedule.Visible 			= IsIsEmployeeOccupationChangeSalary;
	Items.EmployeesPosition.Visible 				= IsIsEmployeeOccupationChangeSalary;
	Items.EmployeesStructuralUnit.Visible 	= IsIsEmployeeOccupationChangeSalary;
	
	If IsIsEmployeeOccupationChangeSalary Then
		
		Items.EmployeesFomerQuantityRatesQty.Visible	= DoStaffSchedule;
		Items.EmployeesRatesQty.Visible					= DoStaffSchedule;
		
		Items.EmployeesStructuralUnit.AutoChoiceIncomplete 	= True;
		Items.EmployeesPosition.AutoChoiceIncomplete 			= True;
		Items.EmployeesRatesQty.AutoChoiceIncomplete 	= True;
		Items.EmployeesStructuralUnit.AutoMarkIncomplete = True;
		Items.EmployeesPosition.AutoMarkIncomplete 			= True;
		Items.EmployeesRatesQty.AutoMarkIncomplete 	= True;
		
	Else
		
		Items.EmployeesFomerQuantityRatesQty.Visible	= False;
		Items.EmployeesRatesQty.Visible					= False;
		
	EndIf;
	
EndProcedure // SetVisibleAtServer()

&AtServer
// Procedure initializes the control of visible and filling of calculated values on server
// 
Procedure ProcessEventAtServer(SetVisible = True, FillValues = True)
	
	If SetVisible Then
		
		SetVisibleAtServer();
		
	EndIf;
	
	If FillValues Then
		
		FillValues();
		
	EndIf;
	
EndProcedure //ProcessEventAtServer()

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);

	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	TabularSectionName = "Employees";
	CurrencyByDefault = Constants.NationalCurrency.Get();
	
	DoStaffSchedule = Constants.FunctionalOptionDoStaffSchedule.Get();
	
	ProcessEventAtServer();
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		
		If Items.Find("EmployeesEmployeeCode") <> Undefined Then
			
			Items.EmployeesEmployeeCode.Visible = False;
			
		EndIf;
		
	EndIf; 
	
	User = Users.CurrentUser();
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDepartment);
	
	If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get() Then
		Items.EmployeesFomerDepartment.Visible = False;
	EndIf;
	
	TaxAccounting = GetFunctionalOption("DoIncomeTaxAccounting");
	CommonUseClientServer.SetFormItemProperty(Items, "CurrentEmployeeTaxes", "Visible", TaxAccounting);
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

&AtServer
// Procedure - handler of the AfterWriteAtServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ProcessEventAtServer();
	
EndProcedure //AfterWriteOnServer()

#EndRegion

#Region HeaderAttributesHandlers

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
// Procedure - event handler OnChange of the OperationKind input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure OperationKindOnChange(Item)
	
	ProcessEventAtServer(,False);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsEmployeeOccupationChange.TransferAndPaymentFormChange") Then
	
		For Each TSRow IN Object.Employees Do
			
			If Not ValueIsFilled(TSRow.PreviousUnit)
				OR ValueIsFilled(TSRow.PreviousJobTitle) Then
				
				FillValuesAboutAllEmployees();
				Break;
			
			EndIf;
			
		EndDo;
	
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - event handler OnCurrentPageChange of field PagesMain
//
Procedure PagesMainOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.PageAccrualsDeductions
		OR CurrentPage = Items.PageTaxes Then
		
		FillCurrentEmployeesChoiceList();
		
		DataCurrentRows = Items.Employees.CurrentData;
		
		If DataCurrentRows <> Undefined Then
			
			CurrentEmployee = DataCurrentRows.GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure // PagesMainOnCurrentPageChange()

&AtClient
// Procedure - event handler OnChange of field CurrentEmployeeDeductionAccruals
//
Procedure CurrentEmployeeAccrualsDeductionsOnChange(Item)
	
	ChangeCurrentEmployee();
	
EndProcedure // CurrentEmployeeDeductionAccrualsOnChange()

&AtClient
// Procedure - event handler OnChange of field CurrentEmployeeTaxes
//
Procedure CurrentEmployeeTaxesOnChange(Item)
	
	ChangeCurrentEmployee();
	
EndProcedure // CurrentEmployeeTaxesOnChange()

#EndRegion

#Region TabularSectionsHandlers

&AtClient
Procedure FillAccrualsDeductions(Command)	
	
	TabularSectionRow = Items.Employees.CurrentData;
	
	If TabularSectionRow = Undefined Then
	
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Employees"" row is not selected in the tabular section.';ru='Не выбрана строка табличной части ""Сотрудники""!'");
		Message.Message();	
		Return;
		
	EndIf;  
	
	If Object.AccrualsDeductions.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey)).Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillDeductionAccrualsEnd", ThisObject, New Structure("TabularSectionRow", TabularSectionRow)), NStr("en='The ""Accruals and deductions"" tabular section will be cleared. Continue?';ru='Табличная часть ""Начисления и удержания"" будет очищена! Продолжить?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillDeductionAccrualsFragment(TabularSectionRow);
EndProcedure

&AtClient
Procedure FillDeductionAccrualsEnd(Result, AdditionalParameters) Export
    
    TabularSectionRow = AdditionalParameters.TabularSectionRow;
    
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillDeductionAccrualsFragment(TabularSectionRow);

EndProcedure

&AtClient
Procedure FillDeductionAccrualsFragment(Val TabularSectionRow)
    
    Var NewRow, SearchResult, SearchString, FilterStr, FilterStructure;
    
    SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "AccrualsDeductions");
    
    FilterStructure = New Structure;
    FilterStructure.Insert("Employee", 	TabularSectionRow.Employee);
    FilterStructure.Insert("Company", Object.Company);
    FilterStructure.Insert("Date", 		TabularSectionRow.Period);		
    SearchResult = FindEmployeeAccrualsDeductionsServer(FilterStructure);
    
    For Each SearchString IN SearchResult Do
        NewRow 						= Object.AccrualsDeductions.Add();
        NewRow.AccrualDeductionKind 	= SearchString.AccrualDeductionKind;		
        NewRow.Amount 					= SearchString.Amount;
        NewRow.Currency 					= SearchString.Currency;
        NewRow.GLExpenseAccount			 	= SearchString.GLExpenseAccount;
        NewRow.Actuality			= SearchString.Actuality;
        NewRow.ConnectionKey 				= TabularSectionRow.ConnectionKey;
    EndDo;	
    
    FilterStr = New FixedStructure("ConnectionKey", TabularSectionRow.ConnectionKey);
    Items.AccrualsDeductions.RowFilter 	= FilterStr;

EndProcedure

&AtClient
Procedure FillIncomeTaxes(Command)	
	
	TabularSectionRow = Items.Employees.CurrentData;
	
	If TabularSectionRow = Undefined Then
	
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Employees"" row is not selected in the tabular section.';ru='Не выбрана строка табличной части ""Сотрудники""!'");
		Message.Message();	
		Return;
		
	EndIf;  
	
	If Object.IncomeTaxes.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey)).Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillIncomeTaxesEnd", ThisObject, New Structure("TabularSectionRow", TabularSectionRow)), NStr("en='The ""Income taxes"" tabular section will be cleared. Continue?';ru='Табличная часть ""Налоги на доходы"" будет очищена! Продолжить?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillIncomeTaxFragment(TabularSectionRow);
EndProcedure

&AtClient
Procedure FillIncomeTaxesEnd(Result, AdditionalParameters) Export
    
    TabularSectionRow = AdditionalParameters.TabularSectionRow;
    
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillIncomeTaxFragment(TabularSectionRow);

EndProcedure

&AtClient
Procedure FillIncomeTaxFragment(Val TabularSectionRow)
    
    Var NewRow, SearchResult, SearchString, FilterStr, FilterStructure;
    
    SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "IncomeTaxes");
    
    FilterStructure = New Structure;
    FilterStructure.Insert("Employee", 	TabularSectionRow.Employee);
    FilterStructure.Insert("Company", Object.Company);
    FilterStructure.Insert("Date", 		TabularSectionRow.Period);		
    SearchResult = FindEmployeeAccrualsDeductionsServer(FilterStructure, True);
    
    For Each SearchString IN SearchResult Do
        NewRow 						= Object.IncomeTaxes.Add();
        NewRow.AccrualDeductionKind 	= SearchString.AccrualDeductionKind;		
        NewRow.Currency 					= SearchString.Currency;
        NewRow.Actuality			= SearchString.Actuality;
        NewRow.ConnectionKey 				= TabularSectionRow.ConnectionKey;
    EndDo;	
    
    FilterStr = New FixedStructure("ConnectionKey", TabularSectionRow.ConnectionKey);
    Items.IncomeTaxes.RowFilter 	= FilterStr;

EndProcedure

&AtClient
// Procedure - event handler OnActivate of the Employees tabular section row.
//
Procedure EmployeesOnActivateRow(Item)
		
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "AccrualsDeductions");
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "IncomeTaxes");
	
EndProcedure

&AtClient
// Procedure - handler of event OnStartEdit of tabular section Employees.
//
Procedure EmployeesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then

		SmallBusinessClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "AccrualsDeductions");
		SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "IncomeTaxes");
		
		TabularSectionRow = Items.Employees.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeDelete of tabular section Employees.
//
Procedure EmployeesBeforeDelete(Item, Cancel)

	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "AccrualsDeductions");
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "IncomeTaxes");

EndProcedure

&AtClient
// Procedure - event handler OnChange of the Employee of the Employees tabular section.
//
Procedure EmployeesEmployeeOnChange(Item)
	
	CurrentData = Items.Employees.CurrentData;
	CurrentData.Period = CurrentDate();
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationKindsEmployeeOccupationChange.TransferAndPaymentFormChange") Then
		Return;
	EndIf;
	
	EmployeeStructure = New Structure();
	EmployeeStructure.Insert("Employee", CurrentData.Employee);
	EmployeeStructure.Insert("Period", CurrentData.Period);
	EmployeeStructure.Insert("Company", Object.Company);
	
	GetEmployeeData(EmployeeStructure);
	
	FillPropertyValues(CurrentData, EmployeeStructure);
		
	CurrentData.PreviousUnit = EmployeeStructure.StructuralUnit;
	CurrentData.PreviousJobTitle = EmployeeStructure.Position;
	CurrentData.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
	CurrentData.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
	
	If Not ValueIsFilled(CurrentData.StructuralUnit) Then
		CurrentData.StructuralUnit = MainDepartment;
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Period of the Employees tabular section.
//
Procedure EmployeesPeriodOnChange(Item)
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationKindsEmployeeOccupationChange.TransferAndPaymentFormChange") Then
		Return;
	EndIf;
	
	CurrentData = Items.Employees.CurrentData;
	
	EmployeeStructure = New Structure();
	EmployeeStructure.Insert("Employee", CurrentData.Employee);
	EmployeeStructure.Insert("Period", CurrentData.Period);
	EmployeeStructure.Insert("Company", Object.Company);
	
	GetEmployeeData(EmployeeStructure);
	
	CurrentData.PreviousUnit = EmployeeStructure.StructuralUnit;
	CurrentData.PreviousJobTitle = EmployeeStructure.Position;
	CurrentData.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
	CurrentData.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
	
	If Not ValueIsFilled(CurrentData.StructuralUnit) AND Not ValueIsFilled(CurrentData.Position) AND Not ValueIsFilled(CurrentData.WorkSchedule) Then	
		FillPropertyValues(CurrentData, EmployeeStructure);	
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section DeductionAccruals.
//
Procedure AccrualsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.AccrualsDeductions.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		TabularSectionRow.Actuality = True;
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeAdditionStart of tabular section DeductionAccruals.
//
Procedure AccrualsDeductionsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange DeductionAccrualKind of tabular section DeductionAccruals.
//
Procedure AccrualsDeductionsAccrualDeductionKindOnChange(Item)
	
	SmallBusinessClient.PutExpensesGLAccountByDefault(ThisForm);
	
EndProcedure // DeductionAccrualsDeductionAccrualKindOnChange()

&AtClient
// Procedure - event handler OnStartEdit of tabular section IncomeTaxes.
//
Procedure IncomeTaxesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.IncomeTaxes.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		TabularSectionRow.Actuality = True;
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeAdditionStart of tabular section IncomeTaxes.
//
Procedure IncomeTaxesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

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

#EndRegion

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

