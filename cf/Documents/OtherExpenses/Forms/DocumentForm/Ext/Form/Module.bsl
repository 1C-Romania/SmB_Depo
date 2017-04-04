
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company = SmallBusinessServer.GetCompany(Object.Company);
	UpdateFormVisibilityAttributes();
	
	For Each CurrentRow In Object.Expenses Do
		CurrentRow.TypeOfAccount = CurrentRow.GLExpenseAccount.TypeOfAccount;
	EndDo;
	
	FormManagement(ThisForm);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Other settlements
	If EventName = "Write_ChartOfAccountManagerial" Then
		If ValueIsFilled(Parameter)
			And Object.Correspondence = Parameter Then
			
			UpdateFormVisibilityAttributes();
			FormManagement(ThisObject);
			
		EndIf;
	EndIf;
	// End Other settlements
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange	= DocumentDate;
	DocumentDate		= Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData	= GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number	= "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number	= "";
	StructureData	= GetDataCompanyOnChange(Object.Company);
	Company			= StructureData.Company;
	
EndProcedure // CompanyOnChange()

&AtClient
Procedure CorrespondenceOnChange(Item)
	
	UpdateFormVisibilityAttributes();
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	Object.Contract = StructureData.Contract;
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Тогда
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OtherSettlementsAccountingOnChange(Item)
	
	FormManagement(ThisObject);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersTableExpenses

&AtClient
Procedure ExpensesGLExpenseAccountOnChange(Item)
	
	AccountParameters		= GetGLExpenseAccountParametersOnChange(Items.Expenses.CurrentData.GLExpenseAccount);
	CurrentData				= Items.Expenses.CurrentData;
	CurrentData.TypeOfAccount	= AccountParameters.TypeOfAccount;
	
EndProcedure

&AtClient
Procedure ExpensesCounterpartyOnChange(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	CurrentData.Contract = GetContractByDefault(Object.Ref, CurrentData.Counterparty, Object.Company)
	
EndProcedure

&AtClient
Procedure ExpensesCounterpartyStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.Expenses.CurrentData;
	If CurrentData.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Creditors") And CurrentData.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Debitors") Then
		StandardProcessing = False;
		Message = New UserMessage;
		Message.Text = NStr("ru = 'Для данного типа счета не требуется указывать контрагента'; en = 'For this type of account, you do not need to specify a counterparty'");
		Message.Message();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	TablePartRow = Items.Expenses.CurrentData;
	If TablePartRow.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Creditors") And TablePartRow.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Debitors") Then
		
		StandardProcessing = False;
		Message = New UserMessage;
		Message.Text = NStr("ru = 'Для данного типа счета не требуется указывать договор'; en = 'For this type of account, you do not need to specify a contract'");
		Message.Message();
		
	ElsIf TablePartRow <> Undefined Then
		
		FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, TablePartRow.Counterparty, TablePartRow.Contract);
		If FormParameters.ControlContractChoice Then
			
			StandardProcessing = False;
			OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure FormManagement(Form)

	Object	= Form.Object;
	Items	= Form.Items;
	
	Items.Contract.Visible = Form.DoOperationsByContracts;
	
	Items.Counterparty.Visible	= False;
	Items.Contract.Visible		= False;
	
	Items.ExpensesContract.Visible		= Object.OtherSettlementsAccounting;
	Items.ExpensesCounterparty.Visible	= Object.OtherSettlementsAccounting;
	
	If Object.OtherSettlementsAccounting And (Form.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Debitors")
		Or Form.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Creditors")) Then
		Items.Counterparty.Visible = Истина;
		Items.Contract.Visible = Form.DoOperationsByContracts;
	EndIf;
	
	SetChoiceParametersByOtherSettlementsAccountingAtServer(Form);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	CatalogManager = Catalogs.CounterpartyContracts;
	
	ListContractKinds	= CatalogManager.GetContractKindsListForDocument(Document);
	ContractByDefault	= CatalogManager.GetDefaultContractByCompanyContractKind(Counterparty, Company, ListContractKinds);
	
	Return ContractByDefault;
	
EndFunction

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
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
// Gets data set from server.
//
Function GetDataCompanyOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetDataCompanyOnChange()

&НаСервере
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	DoOperationsByContracts = CommonUse.ObjectAttributeValue(Counterparty, "DoOperationsByContracts");
	SetVisibilitySettlementAttributes(ThisForm);
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

&AtServerNoContext
Function GetGLExpenseAccountParametersOnChange(Account)
	
	Parameters = New Structure("TypeOfAccount");
	
	Parameters.Insert("TypeOfAccount", Account.TypeOfAccount);
	
	Return Parameters;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetChoiceParametersByOtherSettlementsAccountingAtServer(Form)

	SetChoiceParametersByOtherSettlementsAccountingAtServerForItem(Form, Form.Items.Correspondence);
	SetChoiceParametersByOtherSettlementsAccountingAtServerForItem(Form, Form.Items.ExpensesGLExpenseAccount);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetChoiceParametersByOtherSettlementsAccountingAtServerForItem(Form, Item)

	Items = Form.Items;
	
	ItemChoiceParameters	= New Array;
	FilterByAccountType		= New Array;
	
	For Each Parameter In Item.ChoiceParameters Do
		If Parameter.Name = "Filter.TypeOfAccount" Then
			
			For Each TypeOfAccount In Parameter.Value Do
				If TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Creditors")
					And TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Debitors")
					And TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Capital") Then
					FilterByAccountType.Add(TypeOfAccount);
				EndIf;
			EndDo;
			
			If Form.Object.OtherSettlementsAccounting Then
				If FilterByAccountType.Find(PredefinedValue("Enum.GLAccountsTypes.Debitors")) = Undefined Then
					FilterByAccountType.Add(PredefinedValue("Enum.GLAccountsTypes.Debitors"));
				EndIf;
				If FilterByAccountType.Find(PredefinedValue("Enum.GLAccountsTypes.Creditors")) = Undefined Then
					FilterByAccountType.Add(PredefinedValue("Enum.GLAccountsTypes.Creditors"));
				EndIf;
				If Item = Items.Correspondence Then
					If FilterByAccountType.Find(PredefinedValue("Enum.GLAccountsTypes.Capital")) = Undefined Then
						FilterByAccountType.Add(PredefinedValue("Enum.GLAccountsTypes.Capital"));
					EndIf;
				EndIf;
			EndIf;
			
			ItemChoiceParameters.Add(New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(FilterByAccountType)));
		Else
			ItemChoiceParameters.Add(Parameter);
		EndIf;
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ItemChoiceParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetVisibilitySettlementAttributes(Form)
	
	FormManagement(Form);
	
EndProcedure // SetVisibilitySettlementAttributes()

&AtServer
Procedure UpdateFormVisibilityAttributes()
	
	AttributesRow		= "DoOperationsByContracts";
	AttributesValues	= CommonUse.ObjectAttributesValues(Object.Counterparty, AttributesRow);
	FillPropertyValues(ThisForm, AttributesValues, AttributesRow);
	
	AttributesRow		= "TypeOfAccount";
	AttributesValues	= CommonUse.ObjectAttributesValues(Object.Correspondence, AttributesRow);
	FillPropertyValues(ThisForm, AttributesValues, AttributesRow);
	
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