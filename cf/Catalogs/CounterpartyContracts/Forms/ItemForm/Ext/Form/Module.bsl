////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// StandardSubsystems.AdditionalReportsAndDataProcessors

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
	
EndProcedure

// End StandardSubsystems.AdditionalReportsAndDataProcessors

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// The procedure fills in the counterparty price kind depending on the contract kind.
//
// ContractKind - EnumRef.ContractsKinds
// Counterparty - Catalog.Counterparties
//
&AtServer
Procedure FillCounterpartyPriceKind()
	
	SetPrivilegedMode(True);
	
	Query = New Query("Select Allowed * From Catalog.CounterpartyPriceKind AS CounterpartyPrices WHERE CounterpartyPrices.Owner = &Owner AND NOT CounterpartyPrices.DeletionMark");
	Query.SetParameter("Owner", Object.Owner);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then 
		
		Selection = QueryResult.Select();
		Selection.Next();
		Object.CounterpartyPriceKind = Selection.Ref;
		
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure // GetElementParametersByContractKind()

// The procedure fills in the counterparty price kind depending on the contract kind.
//
// ContractKind - EnumRef.ContractsKinds
// Counterparty - Catalog.Counterparties
//
&AtServer
Procedure FillKindPrices(IsNew = False)
	
	If IsNew Then
		
		PriceKindSales = SmallBusinessReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainPriceKindSales");
		
		If ValueIsFilled(PriceKindSales) Then
			
			Object.PriceKind = PriceKindSales;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillKindPrices()

&AtClientAtServerNoContext
// Procedure is the contract name of numbers and a date of the contract.
//
Function GenerateDescription(ContractNo, ContractDate, SettlementsCurrency)
	
	TextName = NStr("en='# %ContractNo% from %ContractDate% (%SettlementsCurrency%)';ru='№ %НомерДоговора% от %ДатаДоговора% (%ВалютаРасчетов%)'");
	TextName = StrReplace(TextName, "%ContractNo%", TrimAll(ContractNo));
	TextName = StrReplace(TextName, "%ContractDate%", ?(ValueIsFilled(ContractDate), TrimAll(String(Format(ContractDate, "DF=dd.MM.yyyy"))), ""));
	TextName = StrReplace(TextName, "%SettlementsCurrency%", TrimAll(String(SettlementsCurrency)));
	
	Return TextName;
	
EndFunction // GenerateDescription()

&AtClient
// Procedure sets availability of the form items.
//
Procedure SetItemsVisible()
	
	If Object.SettlementsCurrency = NationalCurrency Then
		Items.SettlementsInStandardUnits.Visible = False;
		Object.SettlementsInStandardUnits = False;
	Else
		Items.SettlementsInStandardUnits.Visible = True;
	EndIf;
	
EndProcedure // SetItemsAvailability()

&AtServer
// Procedure is forming mapping of contract kinds.
//
Procedure SetChoiceListOfContractKinds()
	
	If Constants.FunctionalOptionTransferGoodsOnCommission.Get() Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractKinds.WithAgent);
	EndIf;
	
	If Constants.FunctionalOptionReceiveGoodsOnCommission.Get() Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractKinds.FromPrincipal);
	EndIf;	
	
EndProcedure // SetContractKindsChoiceList()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	If Object.Ref.IsEmpty() Then
		
		FillKindPrices(True);
		FillCounterpartyPriceKind();
		
		If Not ValueIsFilled(Object.Company) Then
			
			CompanyByDefault = SmallBusinessReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainCompany");
			If ValueIsFilled(CompanyByDefault) Then
				Object.Company = CompanyByDefault;
			Else
				Object.Company = Catalogs.Companies.MainCompany;
			EndIf;
			
		EndIf;
		
		Object.VendorPaymentDueDate = Constants.VendorPaymentDueDate.Get();
		Object.CustomerPaymentDueDate = Constants.CustomerPaymentDueDate.Get();
		
		If Not ValueIsFilled(Object.SettlementsCurrency) Then
			Object.SettlementsCurrency = NationalCurrency;
		EndIf;
		
		If Not IsBlankString(Parameters.FillingText) Then
			Object.ContractNo = Parameters.FillingText;
			Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
		EndIf;
		
	EndIf;
	
	If Object.SettlementsCurrency = NationalCurrency Then
		Items.SettlementsInStandardUnits.Visible = False;
		Object.SettlementsInStandardUnits = False;
	Else
		Items.SettlementsInStandardUnits.Visible = True;
	EndIf;
	
	UseDataExchange = True;
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded() Then
		
		Items.Company.Visible	= False;
		Items.ContractKind.Visible	= False;
		UseDataExchange 		= False;
		
	EndIf;
	
	SetChoiceListOfContractKinds();
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete = True;
		Items.PriceKind.AutoMarkIncomplete = True;
	Else
		Items.PriceKind.AutoChoiceIncomplete = False;
		Items.PriceKind.AutoMarkIncomplete = False;
	EndIf;
	
	If Parameters.Property("Document") Then 
		ThisForm.OpeningDocument = Parameters.Document;
	Else
		ThisForm.OpeningDocument = Undefined;
	EndIf;
	
	GetBlankParameters();
	ThisForm.ShowDocumentBeginning = True;
	ThisForm.DocumentCreated = False;
	GenerateAndShowContract();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
	If EventName = "PredefinedTemplateRestoration" Then 
		If Parameter = Object.ContractForm Then 
			FilterParameters = New Structure;
			FilterParameters.Insert("FormRefs", Object.ContractForm);
			ParameterArray = Object.EditableParameters.FindRows(FilterParameters);
			For Each String IN ParameterArray Do 
				String.Value = "";
			EndDo;
		EndIf;
	EndIf;
	
	If EventName = "ContractTemplateChangeAndRecordAtServer" Then 
		If Parameter = Object.ContractForm Then 
			ThisForm.DocumentCreated = False;
			GetBlankParameters();
			GenerateAndShowContract();
			ThisForm.Modified = True;
			ThisForm.ShowDocumentBeginning = True;
			ThisForm.CurrentParameterClicked = "";
		EndIf;
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure // BeforeWriteAtServer()

&AtClient
// Procedure - handler of event OnChange of Settlement currency input field.
//
Procedure SettlementsCurrencyOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	SetItemsVisible();
	
EndProcedure // SettlementsCurrencyOnChange()

&AtClient
// Procedure - handler of event OnChange of input field ContractNo.
//
Procedure ContractNoOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure // ContractNoOnChange()

&AtClient
// Procedure - handler of event OnChange of input field ContractDate.
//
Procedure ContractDateOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure // ContractDateOnChange()

&AtClient
// Procedure - handler of event OnChange of input field DiscountMarkupKind.
//
Procedure DiscountMarkupKindOnChange(Item)
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete = True;
		Items.PriceKind.AutoMarkIncomplete = True;	
	Else
		Items.PriceKind.AutoChoiceIncomplete = False;
		Items.PriceKind.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event Clearing input field DiscountMarkupKind.
//
Procedure DiscountMarkupKindClear(Item, StandardProcessing)
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete = True;
		Items.PriceKind.AutoMarkIncomplete = True;	
	Else
		Items.PriceKind.AutoChoiceIncomplete = False;
		Items.PriceKind.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnCurrentPageChange event handler. 
//
Procedure PagesGroupOnCurrentPageChange(Item, CurrentPage)
	Items.ContractForm.AutoMarkIncomplete = False;
	If ThisForm.Modified Then
		ThisForm.DocumentCreated = False;
	EndIf;
	
	If Items.GroupPages.CurrentPage = Items.GroupPrintContract
		AND Not ThisForm.DocumentCreated Then 
		
		GenerateAndShowContract();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event SelectionDataProcessor of input field ContractForm.
//
Procedure ContractFormChoiceDataProcessor(Item, ValueSelected, StandardProcessing)
	
	If ValueIsFilled(Object.ContractForm) Then
		ThisForm.ShowDocumentBeginning = True;
	Else
		ThisForm.ShowDocumentBeginning = False;
	EndIf;
	If Object.ContractForm = ValueSelected Then
		ThisForm.DocumentCreated = True;
		ThisForm.ShowDocumentBeginning = False;
		Return;
	EndIf;
	ThisForm.CurrentParameterClicked = "";
	Object.ContractForm = ValueSelected;
	GetBlankParameters();
	ThisForm.DocumentCreated = False;
	GenerateAndShowContract();
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field ContractForm.
//
Procedure ContractFormOnChange(Item)
	
	If Item.EditText = "" Then
		ThisForm.DocumentCreated = False;
		GenerateAndShowContract();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event OnActivateCell values table EditableParameters.
//
Procedure EditableParametersOnActivateCell(Item)
	
	If ValueIsFilled(Object.ContractForm) Then
		If Item.CurrentData <> Undefined Then
			If Not ThisForm.ShowDocumentBeginning Then
				SelectParameter(Item.CurrentData.ID);
			EndIf;
			ThisForm.ShowDocumentBeginning = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field EditableParametersParameterValue.
//
Procedure EditableParametersParameterValueOnChange(Item)
	
	ParameterValue = Item.EditText;
	SetAndWriteParameterValue(ParameterValue, True);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// StandardSubsystems.AdditionalReportsAndDataProcessors

&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

////////////////////////////////////////////////////////////////////////////////
// PROPERTY MECHANISM PROCEDURES

// Procedure - handler of event Run of command EditPropertiesContent.
//
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

// Procedure updates additional attributes items.
//
&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributesItems()

// Procedure-handler  of the AfterWriteOnServer event.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

// Procedure allows editing object attributes.
//
&AtClient
Procedure Attachable_AuthorizeObjectDetailsEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AuthorizeObjectDetailsEditing(ThisForm);
	
	//If ObjectsAttributesEditProhibitionClient.EnableObjectDetailsEditing(ThisForm)
	//	Then ObjectsAttributesEditProhibitionClient.SetEnableFormItems(ThisForm);
	//EndIf;
	
EndProcedure // Attachable_AllowObjectAttributeEditing()

////////////////////////////////////////////////////////////////////////////////
// CONTRACTS PRINT MECHANISM PROCEDURES

// Procedure requeries and sets HTML text of
// generated contract text and writes in the values table edited parameters.
//
&AtServer
Procedure GenerateAndShowContract()
	
	If Not ThisForm.DocumentCreated Then
		
		ThisForm.EditableParameters.Clear();
		FilterParameters = New Structure("FormRefs", Object.ContractForm);
		ArrayInfobaseParameters = Object.InfobaseParameters.FindRows(FilterParameters);
		For Each Parameter IN ArrayInfobaseParameters Do
			NewRow = ThisForm.EditableParameters.Add();
			NewRow.Presentation = Parameter.Presentation;
			NewRow.Value = Parameter.Value;
			NewRow.ID = Parameter.ID;
			NewRow.Parameter = Parameter.Parameter;
			NewRow.LineNumber = Parameter.LineNumber;
		EndDo;
		
		ArrayEditedParameters = Object.EditableParameters.FindRows(FilterParameters);
		For Each Parameter IN ArrayEditedParameters Do
			NewRow = ThisForm.EditableParameters.Add();
			NewRow.Presentation = Parameter.Presentation;
			NewRow.Value = Parameter.Value;
			NewRow.ID = Parameter.ID;
			NewRow.LineNumber = Parameter.LineNumber;
		EndDo;
		
		GeneratedDocument = SmallBusinessCreationOfPrintedFormsOfContract.GetGeneratedContractHTML(Object, ThisForm.OpeningDocument, ThisForm.EditableParameters);
		If ThisForm.ContractHTMLDocument = GeneratedDocument Then
			ThisForm.DocumentCreated = True;
		EndIf;
		ThisForm.ContractHTMLDocument = GeneratedDocument;
		
		FilterParameters = New Structure("Parameter", PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Facsimile"));
		Rows = ThisForm.EditableParameters.FindRows(FilterParameters);
		For Each String IN Rows Do
			ID = String.GetID();
			ThisForm.EditableParameters.Delete(EditableParameters.FindByID(ID));
		EndDo;
		
		FilterParameters.Parameter = PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Logo");
		Rows = ThisForm.EditableParameters.FindRows(FilterParameters);
		For Each String IN Rows Do
			ID = String.GetID();
			ThisForm.EditableParameters.Delete(EditableParameters.FindByID(ID))
		EndDo;
		
		For Each String IN ThisForm.EditableParameters Do
			If ValueIsFilled(String.Value) Then
				String.ValueIsFilled = True;
			Else
				String.ValueIsFilled = False;
			EndIf;
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure GetBlankParameters()
	
	FilterParameters = New Structure("FormRefs", Object.ContractForm);
	ObjectEditedParameters = Object.EditableParameters.FindRows(FilterParameters);
	ObjectInfobaseParameters = Object.InfobaseParameters.FindRows(FilterParameters);
	
	For Each Parameter IN ObjectEditedParameters Do
		FilterParameters = New Structure("ID", Parameter.ID);
		If Object.ContractForm.EditableParameters.FindRows(FilterParameters).Count() <> 0 Then
			Continue;
		EndIf;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		Rows = Object.EditableParameters.FindRows(FilterParameters);
		If Rows.Count() > 0 Then 
			Object.EditableParameters.Delete(Rows[0]);
		EndIf;
	EndDo;
	
	For Each Parameter IN Object.ContractForm.EditableParameters Do
		FilterParameters = New Structure("FormRefs, ID", Object.ContractForm, Parameter.ID);
		If Object.EditableParameters.FindRows(FilterParameters).Count() > 0 Then 
			Continue;
		EndIf;
		NewRow = Object.EditableParameters.Add();
		NewRow.FormRefs = Object.ContractForm;
		NewRow.Presentation = Parameter.Presentation;
		NewRow.ID = Parameter.ID;
	EndDo;
	
	For Each Parameter IN ObjectInfobaseParameters Do
		FilterParameters = New Structure("ID", Parameter.ID);
		Rows = Object.ContractForm.InfobaseParameters.FindRows(FilterParameters);
		If Rows.Count() <> 0 Then
			Parameter.Presentation = Rows[0].Presentation;
			Continue;
		EndIf;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		Rows = Object.InfobaseParameters.FindRows(FilterParameters);
		If Rows.Count() > 0 Then 
			Object.InfobaseParameters.Delete(Rows[0]);
		EndIf;
	EndDo;
	
	For Each Parameter IN Object.ContractForm.InfobaseParameters Do 
		FilterParameters = New Structure("FormRefs, ID", Object.ContractForm, Parameter.ID);
		If Object.InfobaseParameters.FindRows(FilterParameters).Count() > 0 Then
			Continue;
		EndIf;
		NewRow = Object.InfobaseParameters.Add();
		NewRow.FormRefs = Object.ContractForm;
		NewRow.Presentation = Parameter.Presentation;
		NewRow.ID = Parameter.ID;
		NewRow.Parameter = Parameter.Parameter;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectParameter(Parameter)
	
	If Not ThisForm.DocumentCreated Then
		Return;
	EndIf;
	
	document = Items.ContractHTMLDocument.Document;
	
	If ValueIsFilled(ThisForm.CurrentParameterClicked) Then
		lastParameter = document.getElementById(ThisForm.CurrentParameterClicked);
		If lastParameter.className = "Filled" Then 
			lastParameter.style.backgroundColor = "#FFFFFF";
		ElsIf lastParameter.className = "Empty" Then 
			lastParameter.style.backgroundColor = "#DCDCDC";
		EndIf;
	EndIf;
	
	chosenParameter = document.getElementById(Parameter);
	If chosenParameter <> Undefined Then
		chosenParameter.style.backgroundColor = "#CCFFCC";
		chosenParameter.scrollIntoView();
		
		ThisForm.CurrentParameterClicked = Parameter;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractHTMLDocumentDocumentCreated(Item)
	
	document = Items.ContractHTMLDocument.Document;
	EditedParametersOnPage = document.getElementsByName("parameter");
	
	Iterator = 0;
	For Each Parameter in EditedParametersOnPage Do 
		FilterParameters = New Structure("ID", Parameter.id);
		String = EditableParameters.FindRows(FilterParameters);
		If String.Count() > 0 Then 
			RowIndex = EditableParameters.IndexOf(String[0]);
			Shift = Iterator - RowIndex;
			If Shift <> 0 Then 
				EditableParameters.Move(RowIndex, Shift);
			EndIf;
		EndIf;
		Iterator = Iterator + 1;
	EndDo;
	
	ThisForm.DocumentCreated = True;
	
EndProcedure

&AtServer
Function ThisIsInfobaseParameter(Parameter)
	
	Return ?(TypeOf(Parameter) = Type("EnumRef.ContractsWithCounterpartiesTemplatesParameters"), True, False);
	
EndFunction

&AtServer
Function ThisIsAdditionalAttribute(Parameter)
	
	Return ?(TypeOf(Parameter) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"), True, False);
	
EndFunction

&AtServer
Function GetParameterValue(Parameter, Presentation, ID)
	
	If ThisIsInfobaseParameter(Parameter) Then
		Return SmallBusinessCreationOfPrintedFormsOfContract.GetParameterValue(Object, , Parameter, Presentation);
	ElsIf ThisIsAdditionalAttribute(Parameter) Then
		Return SmallBusinessCreationOfPrintedFormsOfContract.GetAdditionalAttributeValue(Object, OpeningDocument, Parameter);
	Else
		Return SmallBusinessCreationOfPrintedFormsOfContract.GetFilledFieldValueOnGeneratingPrintedForm(Object, ID);
	EndIf;
	
EndFunction

&AtClient
Procedure EditableParametersOnStartEdit(Item, NewRow, Copy)
	
	If Not ValueIsFilled(ThisForm.CurrentParameterClicked) Then
		SelectParameter(Item.CurrentData.ID);
	EndIf;
	
	Rows = EditableParameters.FindRows(New Structure("ID", ThisForm.CurrentParameterClicked));
	If Rows.Count() > 0 Then
		Rows[0].ValueIsFilled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersOnEditEnd(Item, NewRow, CancelEdit)
	
	Rows = EditableParameters.FindRows(New Structure("ID", ThisForm.CurrentParameterClicked));
	If Rows.Count() > 0 Then
		If ValueIsFilled(Rows[0].Value) Then
			Rows[0].ValueIsFilled = True;
		Else
			Rows[0].ValueIsFilled = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersParameterValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Parameter = Items.EditableParameters.CurrentData;
	ParameterValue = GetParameterValue(Parameter.Parameter, Parameter.Presentation, Parameter.ID);
	Items.EditableParameters.CurrentData.Value = ParameterValue;
	
	SetAndWriteParameterValue(ParameterValue, False);
	
EndProcedure

&AtClient
Procedure SetAndWriteParameterValue(ParameterValue, WriteValue)
	
	document = Items.ContractHTMLDocument.Document;
	chosenParameter = document.getElementById(ThisForm.CurrentParameterClicked);
	
	If ValueIsFilled(ParameterValue) Then
		chosenParameter.innerText = ParameterValue;
		chosenParameter.className = "Filled";
		Items.EditableParameters.CurrentData.ValueIsFilled = True;
	Else
		chosenParameter.innerText = "__________";
		chosenParameter.className = "Empty";
		Items.EditableParameters.CurrentData.ValueIsFilled = False;
	EndIf;
	
	WorkingTable = Undefined;
	Parameter = Items.EditableParameters.CurrentData;
	If ThisIsInfobaseParameter(Parameter.Parameter) OR ThisIsAdditionalAttribute(Parameter.Parameter) Then
		WorkingTable = Object.InfobaseParameters;
		If WriteValue Then
			ParameterValueInInfobase = GetParameterValue(Parameter.Parameter, Parameter.Presentation, Parameter.ID);
			If ParameterValue = ParameterValueInInfobase Then
				WriteValue = False;
			EndIf;
		EndIf;
	Else
		WorkingTable = Object.EditableParameters;
	EndIf;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ID", ThisForm.CurrentParameterClicked);
	Rows = ThisForm.EditableParameters.FindRows(FilterParameters);
	If Rows.Count() > 0 Then 
		ParameterIndex = Rows[0].LineNumber - 1;
	Else
		ParameterIndex = Undefined;
	EndIf;
	
	If ParameterIndex = Undefined Then
		Return;
	EndIf;
	
	If WriteValue Then
		WorkingTable[ParameterIndex].Value = ParameterValue;
	Else
		WorkingTable[ParameterIndex].Value = "";
	EndIf;
	
	ThisForm.Modified = True;
	
EndProcedure









