
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		
		Object.CashCurrency = NationalCurrency;
		
	EndIf;
	
	// Fill SWIFT and corr. bank account.
	FillBankDetails(SWIFTBank, CorrAccountBank, Object.Bank, Object.Owner);
	
	// Fill SWIFT and corr. account of bank of settlements.
	FillSWIFTAndCorrAccount(Object.AccountsBank, SWIFTBankForSettlements, CorrAccountBankForSettlements);
	
	FormItemsManagement();
	
	If Not ValueIsFilled(Object.AccountType) Then
		Object.AccountType = "Current";
	EndIf;
	
	FillInAccountViewListServer();
	
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End of StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogBankAccountsWrite");
	// StandardSubsystems.PerformanceEstimation
	
	// If bank of settlements is not used, clear the bank value.
	If Not BankForSettlementsIsUsed
		AND ValueIsFilled(Object.AccountsBank) Then
		
		Object.AccountsBank = Undefined;
		
	EndIf; 
	
	// Fill in the correspondent text.
	If EditCorrespondentText Then
		
		Object.CorrespondentText = CorrespondentText;
		
	Else
		
		Object.CorrespondentText = "";
		
	EndIf;
	
EndProcedure // BeforeWrite()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedBankAccounts" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure SWIFTBankOnChange(Item)
	
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure SWIFTBankStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenBankChoiceForm(True);
	
EndProcedure // SWIFTBankStartChoice()

&AtClient
Procedure SWIFTBankChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Object.Bank = ValueSelected;
	FillBankDetails(SWIFTBank, CorrAccountBank, Object.Bank, Object.Owner);
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
	If IsBlankString(SWIFTBank) Then
		
		ThisForm.CurrentItem = Items.SWIFTBank;
		
	EndIf;
	
	FillInAccountViewList();
	
EndProcedure // SWIFTBankChoiceProcessing()

&AtClient
Procedure SWIFTBankTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 11 Then
			Message = New UserMessage;
			Message.Text = NStr("en='Entered value exceeds the admissible length SWIFT 11 symbols.';ru='Введенное значение превышает допустимую длину SWIFT 11 символов.'");
			Message.Message();
			
			StandardProcessing = False;
			
			Return;
			
		EndIf;
		
	#EndIf
	
	ListOfFoundBanks = FindBanks(Text, Item.Name, Object.CashCurrency <> NationalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.Bank = ListOfFoundBanks[0].Value;
			FillBankDetails(SWIFTBank, CorrAccountBank, Object.Bank, Object.Owner);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(True, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(True);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // SWIFTBankTextEditEnd()

&AtClient
Procedure CorrAccountBankTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ListOfFoundBanks = FindBanks(TrimAll(Text), Item.Name, Object.CashCurrency <> NationalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.Bank = ListOfFoundBanks[0].Value;
			FillBankDetails(SWIFTBank, CorrAccountBank, Object.Bank, Object.Owner);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(True, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(True);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // CorrAccountBankTextEditEnd()

&AtClient
Procedure CorrAccountBankChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Object.Bank = ValueSelected;
	FillBankDetails(SWIFTBank, CorrAccountBank, Object.Bank, Object.Owner);
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
EndProcedure // CorrAccountBankChoiceProcessing()

&AtClient
Procedure SWIFTBankForSettlementsStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenBankChoiceForm(False);
	
EndProcedure // SWIFTBankForSettlementsStartChoice()

&AtClient
Procedure SWIFTBankForSettlementsTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 11 Then
			Message = New UserMessage;
			Message.Text = NStr("en='Entered value exceeds the admissible length SWIFT 11 symbols!';ru='Введенное значение превышает допустимую длину SWIFT 11 символов!'");
			Message.Message();
			
			StandardProcessing = False;
			
			Return;
			
		EndIf;
		
	#EndIf
	
	ListOfFoundBanks = FindBanks(TrimAll(Text), Item.Name, Object.CashCurrency <> NationalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
		
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.AccountsBank = ListOfFoundBanks[0].Value;
			FillSWIFTAndCorrAccount(Object.AccountsBank,  SWIFTBankForSettlements, CorrAccountBankForSettlements);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(False, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(False);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // SWIFTBankForSettlementsTextEditEnd()

&AtClient
Procedure SWIFTBankForSettlementsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	FillSWIFTAndCorrAccount(ValueSelected, SWIFTBankForSettlements, CorrAccountBankForSettlements);
	Object.AccountsBank = ValueSelected;
	
	If IsBlankString(SWIFTBankForSettlements) Then
		
		ThisForm.CurrentItem = Items.SWIFTBankForSettlements;
		
	EndIf;
	
EndProcedure // SWIFTBankForSettlementsChoiceProcessing()

&AtClient
Procedure CorrAccountBankForSettlementsTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ListOfFoundBanks = FindBanks(TrimAll(Text), Item.Name, Object.CashCurrency <> NationalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.AccountsBank = ListOfFoundBanks[0].Value;
			FillSWIFTAndCorrAccount(Object.AccountsBank,  SWIFTBankForSettlements, CorrAccountBankForSettlements);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(False, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(False);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // CorrAccountBankForSettlementsTextEditEnd()

&AtClient
Procedure CorrAccountBankForSettlementsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	FillSWIFTAndCorrAccount(ValueSelected, SWIFTBankForSettlements, CorrAccountBankForSettlements);
	Object.AccountsBank = ValueSelected;
	
EndProcedure // CorrAccountBankForSettlementsChoiceProcessing()

&AtClient
Procedure BankForSettlementsIsUsedOnChange(Item)
	
	Items.SWIFTBankForSettlements.Visible		= BankForSettlementsIsUsed;
	Items.CorrAccountBankForSettlements.Visible	= BankForSettlementsIsUsed;
	Items.BankForSettlements.Visible			= BankForSettlementsIsUsed;
	Items.BankForSettlementsCity.Visible		= BankForSettlementsIsUsed;
	
EndProcedure // BankForSettlementsIsUsedOnChange()

&AtClient
Procedure EditPayerTextOnChange(Item)
	
	Items.PayerText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPayeeTextOnChange(Item)
	
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountNoOnChange(Item)
	
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	FillInAccountViewList();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// The procedure fills in the SWIFT and CorrAccount field values.
//
&AtServerNoContext
Procedure FillSWIFTAndCorrAccount(Bank, SWIFT, CorrAccount)
	
	If Not ValueIsFilled(Bank) Then
		
		Return;
		
	EndIf;
	
	SWIFT	= Bank.Code;
	CorrAccount = Bank.CorrAccount;
	
EndProcedure // FillSWIFTAndCorrAccount()

// The procedure fills in the CorrespondentText field value.
//
&AtServer
Procedure FillCorrespondentText()
	
	Query = New Query;
	Query.SetParameter("Ref", Object.Owner);
		
	If TypeOf(Object.Owner) = Type("CatalogRef.Companies") Then
		
		Query.Text =
		"SELECT
		|	Companies.DescriptionFull
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	Counterparties.DescriptionFull
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		CorrespondentText = TrimAll(Selection.DescriptionFull);
	EndIf;
	
EndProcedure // FillInCorrespondentText()

// The procedure opens a form with a list of banks for manual selection.
//
&AtClient
Procedure OpenBankChoiceForm(IsBank, ListOfFoundBanks = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentRow", ?(IsBank, Object.Bank, Object.AccountsBank));
	FormParameters.Insert("ChoiceFoldersAndItemsParameter", FoldersAndItemsUse.Items);
	FormParameters.Insert("CloseOnChoice", True);
	FormParameters.Insert("Multiselect", False);
	
	If ListOfFoundBanks <> Undefined Then
		
		FormParameters.Insert("ListOfFoundBanks", ListOfFoundBanks);
		
	EndIf;
	
	OpenForm("Catalog.Banks.ChoiceForm", FormParameters, ?(IsBank, Items.SWIFTBank, Items.SWIFTBankForSettlements));
	
EndProcedure // OpenBankChoiceForm()

&AtServerNoContext
Function GetListOfBanksByAttributes(Val Field, Val Value) Export

	BankList = New ValueList;
	
	If IsBlankString(Value) Then
	
		Return BankList;
		
	EndIf;
	
	BanksTable = Catalogs.Banks.GetBanksTableByAttributes(Field, Value);
	
	BankList.LoadValues(BanksTable.UnloadColumn("Ref"));
	
	Return BankList;
	
EndFunction

&AtClientAtServerNoContext
Function CheckCorrectnessOfAccountNumbers(Number, ErrorText = "")

	Result = True;
	
	If IsBlankString(Number) Then
		Return Result;
	EndIf;
	
	ErrorText = "";
	If Not StringFunctionsClientServer.OnlyNumbersInString(Number) Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", " ") +
			NStr("en='The bank account number must contain only digits.
		|Perhaps, numer is specified incorrectly';ru='В номере банковского счета присутствуют не только цифры.
		|Возможно, номер указан неверно'");
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function CheckCorrectnessOfSWIFT(SWIFT, ErrorText = "")
	
	If IsBlankString(SWIFT) Then
		
		Return True;
		
	EndIf;
	
	ErrorText = "";
	If StrLen(SWIFT) <> 8 AND StrLen(SWIFT) <> 11 Then
		
		ErrorText = NStr("en='No bank found for the specified SWIFT. Perhaps, SWIFT is specified incompletely.';ru='По указанному SWIFT банк не найден. Возможно SWIFT указан не полностью.'");
		
	EndIf;
	
	Return IsBlankString(ErrorText);
	
EndFunction

// The function returns a list of banks that satisfy the search condition
// 
// IN case of failure returns "Undefined" or empty value list.
//
&AtClient
Function FindBanks(TextForSearch, Field, Currency = False)
	
	Var ErrorText;
	
	IsBank = (Field = "SWIFTBank") OR (Field = "CorrAccountBank");
	ClearValuesInAssociatedFieldsInForms(IsBank);
	
	If IsBlankString(TextForSearch) Then
		
		ClearMessages();
		
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The ""%1"" field value is invalid.';ru='Поле ""%1"" заполнено не корректно.'"), 
			?(Find(Field, "SWIFT") > 0, "SWIFT", "Corr. account")
			);
		
		CommonUseClientServer.MessageToUser(MessageText,, Field);
		
		Return Undefined;
		
	EndIf;
	
	If Find(Field, "SWIFT") = 1 Then
		
		SearchArea = "Code";
		
	ElsIf Find(Field, "CorrAccount") = 1 Then
		
		SearchArea = "CorrAccount";
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	ListOfFoundBanks = GetListOfBanksByAttributes(SearchArea, TextForSearch);
	If ListOfFoundBanks.Count() = 0 Then
		
		If SearchArea = "Code" Then
			
			If Not CheckCorrectnessOfSWIFT(TextForSearch, ErrorText) Then
				
				ClearMessages();
				CommonUseClientServer.MessageToUser(ErrorText,, Field);
				Return Undefined;
				
			EndIf;
			
			QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='The bank with SWIFT ""%1"" was not found in the Banks catalog';ru='Банк с SWIFT ""%1"" не найден в справочнике банков'"), TextForSearch);
			
		ElsIf SearchArea = "CorrAccount" Then
			
			If Not CheckCorrectnessOfAccountNumbers(TextForSearch, ErrorText) Then
				ClearMessages();
				CommonUseClientServer.MessageToUser(ErrorText,, Field);
				Return Undefined;
			EndIf;
			
			QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Bank with corr. account ""%1"" was not found in the Banks catalog';ru='Банк с корр. счетом ""%1"" не найден в справочнике банков'"), TextForSearch);
			
		EndIf;
		
		// Generate variants
		Buttons	= New ValueList;
		Buttons.Add("Select",     NStr("en='Select from the catalog';ru='Выбрать из справочника'"));
		Buttons.Add("Cancel",   NStr("en='Cancel entering';ru='Отменить ввод'"));
		
		// Choice processor
		NotifyDescription = New NotifyDescription("DetermineIfBankIsToBeSelectedFromCatalog", ThisObject, New Structure("IsBank", IsBank));
		ShowQueryBox(NOTifyDescription, QuestionText, Buttons,, "Select", NStr("en='Bank not found';ru='Банк не найден'"));
		Return Undefined;
		
	EndIf;
	
	Return ListOfFoundBanks;
	
EndFunction // FindBanks()

// Procedure for managing form controls.
//
&AtServer
Procedure FormItemsManagement()
	
	// Set using the bank of settlements.
	BankForSettlementsIsUsed = ValueIsFilled(Object.AccountsBank);
	
	Items.SWIFTBankForSettlements.Visible		= BankForSettlementsIsUsed;
	Items.CorrAccountBankForSettlements.Visible	= BankForSettlementsIsUsed;
	Items.BankForSettlements.Visible			= BankForSettlementsIsUsed;
	Items.BankForSettlementsCity .Visible		= BankForSettlementsIsUsed;
	
	// Edit company name.
	EditCorrespondentText = ValueIsFilled(Object.CorrespondentText);
	Items.PayerText.Enabled = EditCorrespondentText;
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If EditCorrespondentText Then
		CorrespondentText = Object.CorrespondentText;
	Else
		FillCorrespondentText();
	EndIf;
	
	// Print settings
	Items.GroupCompanyAccountAttributes.Visible			= (TypeOf(Object.Owner) = Type("CatalogRef.Companies"));
	Items.GroupCounterpartyAccountAttributes.Visible	= Not (TypeOf(Object.Owner) = Type("CatalogRef.Companies"));
	
EndProcedure // FormItemsManagement()

// Function generates a bank account description.
//
&AtClient
Procedure FillInAccountViewList()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), "");
	DescriptionString = Left(DescriptionString, 100);
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	DescriptionString = ?(ValueIsFilled(Object.Bank), String(Object.Bank), "") + " (" + String(Object.CashCurrency) + ")";
	DescriptionString = Left(DescriptionString, 100);
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
EndProcedure // FillInAccountViewList()

// Function generates a bank account description.
//
&AtServer
Procedure FillInAccountViewListServer()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), "");
	DescriptionString = Left(DescriptionString, 100);
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	DescriptionString = ?(ValueIsFilled(Object.Bank), String(Object.Bank), "") + " (" + String(Object.CashCurrency) + ")";
	DescriptionString = Left(DescriptionString, 100);
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
EndProcedure // FillInAccountViewListServer()

// The procedure clears the related fields of the form
//
// It is useful if a user opens a selection form and refuses to select a value.
//
&AtClient
Procedure ClearValuesInAssociatedFieldsInForms(IsBank)
	
	If IsBank Then
		
		Object.Bank = Undefined;
		SWIFTBank = "";
		CorrAccountBank = "";
		
	Else
		
		Object.AccountsBank = Undefined;
		SWIFTBankForSettlements = "";
		CorrAccountBankForSettlements = "";
		
	EndIf;
	
EndProcedure // ClearRelatedFields()

// Fills in the bank details and direct exchange settings.
//
&AtServerNoContext
Procedure FillBankDetails(SWIFTBank, CorrAccountBank, Val Bank, Val AccountOwner)

	FillSWIFTAndCorrAccount(Bank, SWIFTBank, CorrAccountBank);

EndProcedure // FillBankDetails()

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineIfBankIsToBeSelectedFromCatalog(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = "Select" Then
		
		OpenBankChoiceForm(AdditionalParameters.IsBank);
		
	EndIf;
	
EndProcedure // DetermineBankPickNeedFromClassifier()

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
