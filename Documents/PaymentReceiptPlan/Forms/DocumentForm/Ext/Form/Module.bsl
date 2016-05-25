////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Checks compliance of bank account cash assets currency and
// document currency in case of inconsistency, a default bank account (petty cash) is defined.
//
// Parameters:
// Company - CatalogRef.Companies - Document company
// Currency - CatalogRef.Currencies - Document company 
// BankAccount - CatalogRef.BankAccounts - Bank document account
// Petty cash - CatalogRef.PettyCashes - Document petty cash
//
&AtServerNoContext
Function GetBankAccount(Company, Currency)
	
	Query = New Query(
	"SELECT
	|	CASE
	|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
	|			THEN Companies.BankAccountByDefault
	|		WHEN (NOT BankAccounts.BankAccount IS NULL )
	|			THEN BankAccounts.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccount
	|FROM
	|	Catalog.Companies AS Companies
	|		LEFT JOIN (SELECT
	|			BankAccounts.Ref AS BankAccount
	|		FROM
	|			Catalog.BankAccounts AS BankAccounts
	|		WHERE
	|			BankAccounts.CashCurrency = &CashCurrency
	|			AND BankAccounts.Owner = &Company) AS BankAccounts
	|		ON (TRUE)
	|WHERE
	|	Companies.Ref = &Company");
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashCurrency", Currency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	StructureData = New Structure();
	If Selection.Next() Then
		Return Selection.BankAccount;
	Else
		Return Undefined;
	EndIf;
	
EndFunction // GetBankAccount()

// Checks data with server for procedure CompanyOnChange.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company, Currency, BankAccount)
	
	StructureData = New Structure();
	
	StructureData.Insert("BankAccount", GetBankAccount(Company, Currency));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Checks data with server for procedure DocumentCurrencyOnChange.
//
&AtServerNoContext
Function GetDataDocumentCurrencyOnChange(Company, Currency, BankAccount, NewCurrency, DocumentAmount, Date)
	
	StructureData = New Structure();
	StructureData.Insert("BankAccount", GetBankAccount(Company, NewCurrency));
	
	Query = New Query(
	"SELECT
	|	CASE
	|		WHEN CurrencyRates.Multiplicity <> 0
	|				AND (NOT CurrencyRates.Multiplicity IS NULL )
	|				AND NewCurrencyRates.ExchangeRate <> 0
	|				AND (NOT NewCurrencyRates.ExchangeRate IS NULL )
	|			THEN &DocumentAmount * (CurrencyRates.ExchangeRate * NewCurrencyRates.Multiplicity) / (CurrencyRates.Multiplicity * NewCurrencyRates.ExchangeRate)
	|		ELSE 0
	|	END AS Amount
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&Date, Currency = &Currency) AS CurrencyRates
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Date, Currency = &NewCurrency) AS NewCurrencyRates
	|		ON (TRUE)");
	
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("NewCurrency", NewCurrency);
	Query.SetParameter("DocumentAmount", DocumentAmount);
	Query.SetParameter("Date", Date);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		StructureData.Insert("Amount", Selection.Amount);
	Else
		StructureData.Insert("Amount", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataDocumentCurrencyOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
		
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		Counterparty.ContractByDefault
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return PettyCash.CurrencyByDefault;
	
EndFunction // GetPettyCashDefaultCurrencyOnServer()

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
	
EndProcedure // SetContractVisible()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Sets the current page for document operation kind.
//
// Parameters:
//  BusinessOperation - EnumRef.EconomicOperations - Economic operations
//
&AtServer
Procedure SetCurrentPage()
	
	If Object.CashAssetsType = Enums.CashAssetTypes.Noncash Then
		Items.BankAccount.Enabled = True;
		Items.BankAccount.Visible 	= True;
		Items.PettyCash.Visible 			= False;
	ElsIf Object.CashAssetsType = Enums.CashAssetTypes.Cash Then
		Items.PettyCash.Enabled 			= True;
		Items.BankAccount.Visible 	= False;
		Items.PettyCash.Visible 			= True;
	Else
		Items.BankAccount.Enabled = False;
		Items.BankAccount.Visible	= False;
		Items.PettyCash.Enabled 			= False;
		Items.PettyCash.Visible 			= False;
	EndIf;
	
EndProcedure // SetCurrentPage()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		Query = New Query(
		"SELECT
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.DocumentCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			Object.BankAccount = Selection.BankAccount;
		EndIf;
		Object.PettyCash = Catalogs.PettyCashes.GetPettyCashByDefault(Object.Company);
	EndIf;
	
	Currency = Object.DocumentCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	SetCurrentPage();
	
	// Setting contract visible.
	SetContractVisible();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
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

// Procedure - "AfterWrite" event handler of the forms.
//
&AtClient
Procedure AfterWrite()
	
	Notify();
	
EndProcedure // AfterWrite()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter)
		   AND Object.Counterparty = Parameter Then
			SetContractVisible();
		EndIf;
	EndIf;
	
EndProcedure // NotificationProcessing

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Company input field.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(
		Object.Company,
		Object.DocumentCurrency,
		Object.BankAccount
	);
	Object.BankAccount = StructureData.BankAccount;
	
EndProcedure // CompanyOnChange()

// Procedure - handler of event OnChange of input field DocumentCurrency.
//
&AtClient
Procedure DocumentCurrencyOnChange(Item)
	
	If Currency <> Object.DocumentCurrency Then
		
		StructureData = GetDataDocumentCurrencyOnChange(
			Object.Company,
			Currency,
			Object.BankAccount,
			Object.DocumentCurrency,
			Object.DocumentAmount,
			Object.Date);
		
		Object.BankAccount = StructureData.BankAccount;
		
		If Object.DocumentAmount <> 0 Then
			Mode = QuestionDialogMode.YesNo;
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("DocumentCurrencyOnChangeEnd", ThisObject, New Structure("StructureData", StructureData)), NStr("en = 'Document currency is changed. Recalculate document amount?'"), Mode);
            Return;
		EndIf;
		DocumentCurrencyOnChangeFragment();

		
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeEnd(Result, AdditionalParameters) Export
    
    StructureData = AdditionalParameters.StructureData;
    
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.DocumentAmount = StructureData.Amount;
    EndIf;
    
    DocumentCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeFragment()
    
    Currency = Object.DocumentCurrency;

EndProcedure // DocumentCurrencyOnChange()

// Procedure - event handler OnChange input field CashAssetsType.
//
&AtClient
Procedure CashAssetsTypeOnChange(Item)
	
	SetCurrentPage();
	
EndProcedure // CashAssetsTypeOnChange()

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
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

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
	Object.Contract = StructureData.Contract;
	
EndProcedure

// Procedure - OnChange event handler of the PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	Object.DocumentCurrency = ?(
		ValueIsFilled(Object.DocumentCurrency),
		Object.DocumentCurrency,
		GetPettyCashAccountingCurrencyAtServer(Object.PettyCash)
	);
	
EndProcedure // PettyCashOnChange()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	Currency = Object.DocumentCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	SetCurrentPage();
	SetContractVisible();
	
EndProcedure // FillByDocument()

// Procedure - command handler FillByBasis.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en='Basis document is not selected!'"));
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Document will be completely refilled by ""Basis""! Continue?'"), QuestionDialogMode.YesNo, 0);

EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        FillByDocument(Object.BasisDocument);
        
    EndIf;

EndProcedure // FillByBasis()

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
