#Region ServiceHandlers

&AtClient
// Procedure changes the current row of the Employees tabular section
//
Procedure ChangeCurrentEmployee()
	
	Items.Employees.CurrentRow = CurrentEmployee;
	
EndProcedure // ChangeCurrentEmployee()

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
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("EmployeesEmployeeCode") <> Undefined Then
			Items.EmployeesEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	User = Users.CurrentUser();
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDepartment);
	
	TaxAccounting = GetFunctionalOption("DoIncomeTaxAccounting");
	CommonUseClientServer.SetFormItemProperty(Items, "CurrentEmployeeTaxes", "Visible", TaxAccounting);
	If Not TaxAccounting Then
		
		Items.Employees.ExtendedTooltip.Title = 
			NStr("en='Accruals and deductions are specified on the corresponding page for each employee individually.';ru='Начисления и удержания указываются на соответствующей странице для каждого сотрудника в отдельности.'");
			
	EndIf;
		
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
		If Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
			
			TabularSectionRow.StructuralUnit = MainDepartment;
			
		EndIf;
		
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
	
	Items.Employees.CurrentData.OccupiedRates = 1;
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section DeductionAccruals.
//
Procedure AccrualsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.AccrualsDeductions.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
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



