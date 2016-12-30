////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure fills tabular section Employees balance by charges.
//
Procedure FillByBalanceAtServer()	
	
	Document = FormAttributeToValue("Object");
	Document.FillByBalanceAtServer();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServer
// Procedure fills tabular section Employees by department.
//
Procedure FillByDepartmentAtServer()	
	
	Document = FormAttributeToValue("Object");
	Document.FillByDepartmentAtServer();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

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

&AtClient
// Procedure fills tabular section Employees balance by charges.
//
Procedure RecalculateAmountByCurrency(TabularSectionRow, ChangedAccrual, ChangedForExport, AdditionalParameters = Undefined)
	
	//
	// If both currencies are changed, calculation of payment amount is done by accrual amount
	//
	
	If ChangedAccrual Then
		
		If AdditionalParameters <> Undefined Then
			
			TabularSectionRow.SettlementsAmount = WorkWithCurrencyRatesClientServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.SettlementsAmount, AdditionalParameters.SettlementsCurrencyBeforeChange, Object.SettlementsCurrency, AdditionalParameters.ExchangeRateBeforeChange, Object.ExchangeRate, AdditionalParameters.MultiplicityBeforeChange, Object.Multiplicity);
			
		EndIf;
		
		TabularSectionRow.PaymentAmount = WorkWithCurrencyRatesClientServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.SettlementsAmount, Object.SettlementsCurrency, Object.DocumentCurrency, Object.ExchangeRate, RateDocumentCurrency, Object.Multiplicity, RepetitionDocumentCurrency);
		
	ElsIf ChangedForExport Then
		
		If AdditionalParameters <> Undefined Then
			
			TabularSectionRow.PaymentAmount = WorkWithCurrencyRatesClientServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.PaymentAmount, AdditionalParameters.DocumentCurrencyBeforeChange, Object.DocumentCurrency, AdditionalParameters.ExchangeRateDocumentCurrencyBeforeChange, RateDocumentCurrency, AdditionalParameters.MultiplicityDocumentCurrencyBeforeChange, RepetitionDocumentCurrency);
			
		EndIf;
		
		TabularSectionRow.SettlementsAmount = WorkWithCurrencyRatesClientServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.PaymentAmount, Object.DocumentCurrency, Object.SettlementsCurrency, RateDocumentCurrency, Object.ExchangeRate, RepetitionDocumentCurrency, Object.Multiplicity);
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills tabular section Employees balance by charges.
//
Procedure SetVisibleFromCurrency()
	
	SettlementsCurrencyDiffersFromDocumentCurrency = (Object.DocumentCurrency <> Object.SettlementsCurrency);
	
	CommonUseClientServer.SetFormItemProperty(Items, "EmployeesSettlementsAmount", "Visible", SettlementsCurrencyDiffersFromDocumentCurrency);
	CommonUseClientServer.SetFormItemProperty(Items, "EmployeesTotalAmountSettlements", "Visible", SettlementsCurrencyDiffersFromDocumentCurrency);
	CommonUseClientServer.SetFormItemProperty(Items, "EmployeesSettlementsCurrency", "Visible", SettlementsCurrencyDiffersFromDocumentCurrency);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

&AtClient
// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False)
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	ParametersStructure.Insert("RateDocumentCurrency",		RateDocumentCurrency);
	ParametersStructure.Insert("RepetitionDocumentCurrency",RepetitionDocumentCurrency);
	
	ParametersStructure.Insert("SettlementsCurrency",			Object.SettlementsCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",				Object.Multiplicity);
	
	ParametersStructure.Insert("Company",				SubsidiaryCompany);
	ParametersStructure.Insert("DocumentDate",			Object.Date);
	ParametersStructure.Insert("RecalculatePricesByCurrency",	False);
	ParametersStructure.Insert("WereMadeChanges",	False);
	
	StructurePricesAndCurrency = Undefined;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("SettlementsCurrencyBeforeChange", Object.SettlementsCurrency);
	AdditionalParameters.Insert("ExchangeRateBeforeChange" ,Object.ExchangeRate);
	AdditionalParameters.Insert("MultiplicityBeforeChange" ,Object.Multiplicity);
	
	AdditionalParameters.Insert("DocumentCurrencyBeforeChange", Object.DocumentCurrency);
	AdditionalParameters.Insert("ExchangeRateDocumentCurrencyBeforeChange" ,RateDocumentCurrency);
	AdditionalParameters.Insert("MultiplicityDocumentCurrencyBeforeChange" ,RepetitionDocumentCurrency);
	
	OpenForm("Document.PayrollSheet.Form.CurrencyForm", ParametersStructure,,,,, New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, AdditionalParameters), FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(Result, AdditionalParameters) Export
	
	StructurePricesAndCurrency = Result;
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.DocumentCurrency		= StructurePricesAndCurrency.DocumentCurrency;
		RateDocumentCurrency			= StructurePricesAndCurrency.RateDocumentCurrency;
		RepetitionDocumentCurrency	= StructurePricesAndCurrency.RepetitionDocumentCurrency;
		
		Object.SettlementsCurrency 	= StructurePricesAndCurrency.SettlementsCurrency;
		Object.ExchangeRate 			= StructurePricesAndCurrency.ExchangeRate;
		Object.Multiplicity 		= StructurePricesAndCurrency.Multiplicity;
		
		// Recalculate prices by currency.
		If StructurePricesAndCurrency.RecalculatePricesByCurrency Then
			
			For Each TabularSectionRow IN Object.Employees Do
				
				RecalculateAmountByCurrency(TabularSectionRow, StructurePricesAndCurrency.ChangedCurrencySettlements, StructurePricesAndCurrency.ChangedDocumentCurrency, AdditionalParameters);
				
			EndDo; 
			
		ElsIf StructurePricesAndCurrency.SettlementsCurrency <> AdditionalParameters.SettlementsCurrencyBeforeChange 
			AND StructurePricesAndCurrency.DocumentCurrency <> AdditionalParameters.DocumentCurrencyBeforeChange Then
			
			// Skip
			
		ElsIf StructurePricesAndCurrency.SettlementsCurrency <> AdditionalParameters.SettlementsCurrencyBeforeChange 
			OR StructurePricesAndCurrency.DocumentCurrency <> AdditionalParameters.DocumentCurrencyBeforeChange Then
			
			For Each TabularSectionRow IN Object.Employees Do
				
				RecalculateAmountByCurrency(TabularSectionRow, False, True, AdditionalParameters);
				
			EndDo; 
			
		EndIf;
		
		SetVisibleFromCurrency();
		
	EndIf;
	
	// Fill in form data.
	PricesAndCurrency = NStr("en='Doc %1 • Beg. %2';ru='Док %1 • Нач. %2'");
	PricesAndCurrency = StringFunctionsClientServer.PlaceParametersIntoString(PricesAndCurrency, TrimAll(String(Object.DocumentCurrency)), TrimAll(String(Object.SettlementsCurrency)));
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initialization of form parameters,
// - setting of the form functional options parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not (Parameters.FillingValues.Property("RegistrationPeriod") AND ValueIsFilled(Parameters.FillingValues.RegistrationPeriod)) Then
		
		Object.RegistrationPeriod 	= BegOfMonth(CurrentDate());
		
	EndIf;
	
	RegistrationPeriodPresentation = Format(ThisForm.Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	If Object.SettlementsCurrency = Object.DocumentCurrency Then
		
		RateDocumentCurrency = Object.ExchangeRate;
		RepetitionDocumentCurrency = Object.Multiplicity;
		
	Else
		
		DocumentCurrencyRate = WorkWithCurrencyRates.GetCurrencyRate(Object.DocumentCurrency, Object.Date);
		RateDocumentCurrency = DocumentCurrencyRate.ExchangeRate;
		RepetitionDocumentCurrency = DocumentCurrencyRate.Multiplicity;
		
	EndIf;
	
	// Fill in form data.
	PricesAndCurrency = NStr("en='Doc. %1 • Beg. %2';ru='Док. %1 • Нач. %2'");
	PricesAndCurrency = StringFunctionsClientServer.PlaceParametersIntoString(PricesAndCurrency, TrimAll(String(Object.DocumentCurrency)), TrimAll(String(Object.SettlementsCurrency)));
	
	SetVisibleFromCurrency();
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("EmployeesEmployeeCode") <> Undefined Then
			Items.EmployeesEmployeeCode.Visible = False;
		EndIf; 
	EndIf;
	
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

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "CalendarForm") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - FillInAndCalculateExecute event handler of the form.
//
Procedure FillByBalance(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en='The department is not filled!';ru='Не заполнено подразделение!'");
		Message.Field = "Object.StructuralUnit";
 		Message.Message();
		
		Return;
		
	EndIf;
	
	FillByBalanceAtServer();		
	
EndProcedure

&AtClient
Procedure FillByDepartment(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en='The department is not filled!';ru='Не заполнено подразделение!'");
		Message.Field = "Object.StructuralUnit";
 		Message.Message();
		
		Return;
		
	EndIf;
	
	FillByDepartmentAtServer();
	
EndProcedure

&AtClient
// Procedure - Management event handler of RegistrationPeriod attribute
//
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	SmallBusinessClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure

&AtClient
// Procedure - StartChoice event handler of RegistrationPeriod attribute
//
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, SmallBusinessReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.CalendarForm", SmallBusinessClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

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
// Procedure - handler of the OnChange event of the SettlementsAmount input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure SettlementsAmountOnChange(Item)
	
	RecalculateAmountByCurrency(Items.Employees.CurrentData, True, False);
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the SettlementsAmount input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure EmployeesPaymentAmountOnChange(Item)
	
	RecalculateAmountByCurrency(Items.Employees.CurrentData, False, True);
	
EndProcedure

&AtClient
// Procedure - Click event handler of PricesAndCurrency field.
//
Procedure PricesAndCurrencyClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	
EndProcedure // PricesAndCurrencyClick()

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













