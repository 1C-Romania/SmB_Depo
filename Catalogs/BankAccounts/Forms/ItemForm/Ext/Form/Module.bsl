////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// The procedure fills in the BIC and CorrAccount field values.
//
&AtServerNoContext
Procedure FillBIKAndCorrAccount(Bank, Bin, CorrAccount)
	
	If Not ValueIsFilled(Bank) Then
		
		Return;
		
	EndIf;
	
	Bin = Bank.Code;
	CorrAccount = Bank.CorrAccount;
	
EndProcedure // FillInBICAndCorrAccount()

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
Procedure OpenFormToSelectBank(IsBank, ListOfFoundBanks = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentRow", ?(IsBank, Object.Bank, Object.AccountsBank));
	FormParameters.Insert("ChoiceFoldersAndItemsParameter", FoldersAndItemsUse.Items);
	FormParameters.Insert("CloseOnChoice", True);
	FormParameters.Insert("Multiselect", False);
	
	If ListOfFoundBanks <> Undefined Then
		
		FormParameters.Insert("ListOfFoundBanks", ListOfFoundBanks);
		
	EndIf;
	
	OpenForm("Catalog.Banks.ChoiceForm", FormParameters, ?(IsBank, Items.BankBIC, Items.BankBICForSettlements));
	
EndProcedure // OpenBankSelectionForm()

&AtServerNoContext
Function BankDiscontinued(BIN)
	
	Result = False;
	
	QueryText = 
	"SELECT
	|	RFBankClassifier.ActivityDiscontinued
	|FROM
	|	Catalog.RFBankClassifier AS RFBankClassifier
	|WHERE
	|	RFBankClassifier.Code = &BIN";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("BIN", BIN);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.ActivityDiscontinued;
	EndIf;
	
	Return Result;
	
EndFunction

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
Function CheckCorrectnessOfAccountNumbers(Number, ForeignCurrencyAccount = False, ErrorText = "")

	Result = True;
	
	If IsBlankString(Number) Then
		Return Result;
	EndIf;
	
	ErrorText = "";
	If Not ForeignCurrencyAccount AND StrLen(Number) <> 20 Then
		
		ErrorText = NStr("en='Perhaps, account number is specified incompletely';ru='Возможно номер счета указан не полностью'");
		Result = False;
		
	ElsIf Not StringFunctionsClientServer.OnlyNumbersInString(Number) Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", " ") +
			NStr("en='The bank account number must contain only digits.
		|Perhaps, numer is specified incorrectly';ru='В номере банковского счета присутствуют не только цифры.
		|Возможно, номер указан неверно'");
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function ValidateCorrectnessOfBIN(BIN, ErrorText = "")
	
	If IsBlankString(BIN) Then
		
		Return True;
		
	EndIf;
	
	ErrorText = "";
	If StrLen(BIN) <> 9 Then
		
		ErrorText = NStr("en='No bank found for the specified BIC. Perhaps, BIN is specified incompletely.';ru='По указанному БИК банк не найден. Возможно БИК указан не полностью.'");
		
	ElsIf Not StringFunctionsClientServer.OnlyNumbersInString(BIN) Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", " ") +
			NStr("en='Bank BIN must inlude digits only';ru='В составе БИК банка должны быть только цифры'");
		
	ElsIf Not Left(BIN, 2) = "04" Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", " ") +
			NStr("en='Bank BIC must begin with ""04"".';ru='Первые 2 цифры БИК банка должны быть ""04""'");
		
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
	
	IsBank = (Field = "BankBIC") OR (Field = "BankCorrAccount");
	ClearValuesInAssociatedFieldsInForms(IsBank);
	
	If IsBlankString(TextForSearch) Then
		
		ClearMessages();
		
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The ""%1"" field value is invalid.';ru='Поле ""%1"" заполнено не корректно.'"), 
			?(Find(Field, "BIN") > 0, "BIN", "Corr. account")
			);
		
		CommonUseClientServer.MessageToUser(MessageText,, Field);
		
		Return Undefined;
		
	EndIf;
	
	If Find(Field, "BIN") = 1 Then
		
		SearchArea = "Code";
		
	ElsIf Find(Field, "CorrAccount") = 1 Then
		
		SearchArea = "CorrAccount";
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	ListOfFoundBanks = GetListOfBanksByAttributes(SearchArea, TextForSearch);
	If ListOfFoundBanks.Count() = 0 Then
		
		If SearchArea = "Code" Then
			
			If Not ValidateCorrectnessOfBIN(TextForSearch, ErrorText) Then
				
				ClearMessages();
				CommonUseClientServer.MessageToUser(ErrorText,, Field);
				Return Undefined;
				
			EndIf;
			
			QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='The bank with BIC ""%1"" was not found in the Banks catalog';ru='Банк с БИК ""%1"" не найден в справочнике банков'"), TextForSearch);
			
		ElsIf SearchArea = "CorrAccount" Then
			
			If Not CheckCorrectnessOfAccountNumbers(TextForSearch, Currency, ErrorText) Then
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
		
	ElsIf SearchArea = "Code" AND ListOfFoundBanks.Count() = 1 Then
		
		If Field = "BankBICForSettlements" Then
			
			BanksIndirectSettlementsStopped = BankDiscontinued(TextForSearch);
			
		Else
			
			BankDiscontinued = BankDiscontinued(TextForSearch);
			
		EndIf;
		
	EndIf;
	
	Return ListOfFoundBanks;
	
EndFunction // FindBanks()

// Procedure for managing form controls.
//
&AtServer
Procedure FormItemsManagement()
	
	// Set using the bank of settlements.
	SettlementBankUsed = ValueIsFilled(Object.AccountsBank);
	
	If SettlementBankUsed Then
		Items.FolderPagesIndirectCalculations.CurrentPage = Items.FolderAccountingBank;
	Else
		Items.FolderPagesIndirectCalculations.CurrentPage = Items.GroupLabelIndirectCalculations;
	EndIf;
	
	// Edit company name.
	EditCorrespondentText = ValueIsFilled(Object.CorrespondentText);
	Items.PayerText.Enabled = EditCorrespondentText;
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If EditCorrespondentText Then
		CorrespondentText = Object.CorrespondentText;
	Else
		FillCorrespondentText();
	EndIf;
	
	// Set the current tab.
	If TypeOf(Object.Owner) = Type("CatalogRef.Companies") Then
		Items.GroupPages.CurrentPage = Items.GroupAccountAttributesOfCompany;
	Else
		Items.GroupPages.CurrentPage = Items.GroupCounterpartyAccountAttributes;
	EndIf;
	
EndProcedure // ManageFormControls()

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
		BankBIC = "";
		BankCorrAccount = "";
		
	Else
		
		Object.AccountsBank = Undefined;
		BankBICForSettlements = "";
		BankCorrAccountForSettlements = "";
		
	EndIf;
	
EndProcedure // ClearRelatedFields()

// The procedure fills in the data on direct exchange with banks.
//
&AtServerNoContext
Procedure FillInDirectExchangeSettings(DirectExchangeWithBanksAgreement, DirectMessageExchange, Val Bank, Val AccountOwner)

	DirectMessageExchange = NStr("en = ''");
	
	If ValueIsFilled(Bank)
		AND TypeOf(AccountOwner)=Type("CatalogRef.Companies") Then
		
		Query = New Query();
		Query.Parameters.Insert("Bank", Bank);
		Query.Parameters.Insert("Company", AccountOwner);
		Query.Text =
		"SELECT
		|	EDUsageAgreements.Ref AS DirectExchangeWithBanksAgreement,
		|	EDUsageAgreements.Counterparty,
		|	EDUsageAgreements.AgreementStatus
		|FROM
		|	Catalog.EDUsageAgreements AS EDUsageAgreements
		|WHERE
		|	EDUsageAgreements.Counterparty = &Bank
		|	AND EDUsageAgreements.Company = &Company";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			DirectExchangeWithBanksAgreement = Selection.DirectExchangeWithBanksAgreement;
			DirectMessageExchange = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Direct exchange agreement %1';ru='Соглашение о прямом обмене %1'"), Lower(Selection.AgreementStatus));
		EndIf;
	EndIf;
	
EndProcedure // FillInDirectExchangeSettings()

// Fills in the bank details and direct exchange settings.
//
&AtServerNoContext
Procedure FillInBankDetails(BankBIC, BankCorrAccount, DirectExchangeWithBanksAgreement, DirectMessageExchange, Val Bank, Val AccountOwner)

	FillBIKAndCorrAccount(Bank, BankBIC, BankCorrAccount);
	FillInDirectExchangeSettings(DirectExchangeWithBanksAgreement, DirectMessageExchange, Bank, AccountOwner);

EndProcedure // FillInBankDetails()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer form event handler.
// The procedure sets visible and availability of
// form controls depending on the owner type.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		
		Object.CashCurrency = NationalCurrency;
		
	EndIf;
	
	// Fill in BIC and corr.bank account.
	FillInBankDetails(BankBIC, BankCorrAccount, DirectExchangeWithBanksAgreement, DirectMessageExchange, Object.Bank, Object.Owner);
	
	// Fill in BIC and corr.account of bank of settlements.
	FillBIKAndCorrAccount(Object.AccountsBank, BankBICForSettlements, BankCorrAccountForSettlements);
	
	FormItemsManagement();
	
	If Not ValueIsFilled(Object.AccountType) Then
		Object.AccountType = "Transactional";
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

// Procedure - event handler BeforeWrite form.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogBankAccountsWrite");
	// StandardSubsystems.PerformanceEstimation
	
	// If bank of settlements is not used, clear the bank value.
	If Not SettlementBankUsed
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

// Procedure - the OnChange event handler of the BankBIC field.
//
&AtClient
Procedure BankBICOnChange(Item)
	
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
	FillInAccountViewList();
	
EndProcedure

// Procedure - the BeginChoice event handler of the BankBIC field.
//
&AtClient
Procedure BankBICStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenFormToSelectBank(True);
	
EndProcedure // BankBICBeginChoice()

// Procedure - the ChoiceProcessing event handler of the BankBIC field.
//
&AtClient
Procedure BankBICChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Object.Bank = ValueSelected;
	FillInBankDetails(BankBIC, BankCorrAccount, DirectExchangeWithBanksAgreement, DirectMessageExchange, Object.Bank, Object.Owner);
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
	If IsBlankString(BankBIC) Then
		
		ThisForm.CurrentItem = Items.BankBIC;
		
	EndIf;
	
	FillInAccountViewList();
	
EndProcedure // BankBICChoiceProcessing()

// Procedure - the EndTextInput event handler of the BankBIC field.
//
&AtClient
Procedure BIKBankTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 9 Then
			Message = New UserMessage;
			Message.Text = NStr("en='Entered value exceeds the admissible length BIN 9 symbols!';ru='Введенное значение превышает допустимую длину БИК 9 символов!'");
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
			FillInBankDetails(BankBIC, BankCorrAccount, DirectExchangeWithBanksAgreement, DirectMessageExchange, Object.Bank, Object.Owner);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenFormToSelectBank(True, ListOfFoundBanks);
			
		Else
			
			OpenFormToSelectBank(True);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // BankBICEndTextInput()

// Procedure - the EndTextInput event handler of the BankCorrAccount field.
//
&AtClient
Procedure CorrespondentAccountOfBankTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ListOfFoundBanks = FindBanks(TrimAll(Text), Item.Name, Object.CashCurrency <> NationalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.Bank = ListOfFoundBanks[0].Value;
			FillInBankDetails(BankBIC, BankCorrAccount, DirectExchangeWithBanksAgreement, DirectMessageExchange, Object.Bank, Object.Owner);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenFormToSelectBank(True, ListOfFoundBanks);
			
		Else
			
			OpenFormToSelectBank(True);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // BankCorrAccountEndTextInput()

// Procedure - the ChoiceProcessing event handler of the SettlementsBankBIC field.
//
&AtClient
Procedure CorrespondentAccountOfBankChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Object.Bank = ValueSelected;
	FillInBankDetails(BankBIC, BankCorrAccount, DirectExchangeWithBanksAgreement, DirectMessageExchange, Object.Bank, Object.Owner);
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
EndProcedure // BankBICChoiceProcessing()

// Procedure - the BeginChoice event handler of the BankBIC field.
//
&AtClient
Procedure BankBICForSettlementsStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenFormToSelectBank(False);
	
EndProcedure // SettlementsBankBICBeginChoice()

// Procedure - the EndTextInput event handler of the SettlementsBankBIC field.
//
&AtClient
Procedure SettlementBankBICTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 9 Then
			Message = New UserMessage;
			Message.Text = NStr("en='Entered value exceeds the admissible length BIN 9 symbols!';ru='Введенное значение превышает допустимую длину БИК 9 символов!'");
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
			FillBIKAndCorrAccount(Object.AccountsBank,  BankBICForSettlements, BankCorrAccountForSettlements);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenFormToSelectBank(False, ListOfFoundBanks);
			
		Else
			
			OpenFormToSelectBank(False);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // SettlementsBankBICEndTextInput()

// Procedure - the BeginChoice event handler of the SettlementsBankBIC field.
//
&AtClient
Procedure SettlementsBankBICChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	FillBIKAndCorrAccount(ValueSelected, BankBICForSettlements, BankCorrAccountForSettlements);
	Object.AccountsBank = ValueSelected;
	
	If IsBlankString(BankBICForSettlements) Then
		
		ThisForm.CurrentItem = Items.BankBICForSettlements;
		
	EndIf;
	
EndProcedure // SettlementsBankBICChoiceProcessing()

// Procedure - the EndTextInput event handler of the SettlementsBankCorrAccount field.
//
&AtClient
Procedure CorrespondentAccountOfSettlementsBankTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ListOfFoundBanks = FindBanks(TrimAll(Text), Item.Name, Object.CashCurrency <> NationalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.AccountsBank = ListOfFoundBanks[0].Value;
			FillBIKAndCorrAccount(Object.AccountsBank,  BankBICForSettlements, BankCorrAccountForSettlements);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenFormToSelectBank(False, ListOfFoundBanks);
			
		Else
			
			OpenFormToSelectBank(False);
			
		EndIf;
		
	Else
		
		ThisForm.CurrentItem = Item;
		
	EndIf;
	
EndProcedure // SettlementsBankCorrAccountEndTextInput()

// Procedure - the ChoiceProcessing event handler of the SettlementsBankCorrAccount field.
//
&AtClient
Procedure CorrespondentAccountOfBankForSettlementsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	FillBIKAndCorrAccount(ValueSelected, BankBICForSettlements, BankCorrAccountForSettlements);
	Object.AccountsBank = ValueSelected;
	
EndProcedure // SettlementsBankCorrAccountChoiceProcessing()

// Procedure - The OnChange event handler of the SettlementsBankIsUsed check box.
//
&AtClient
Procedure BankIsUsedForSettlementsOnChange(Item)
	
	If SettlementBankUsed Then
		Items.FolderPagesIndirectCalculations.CurrentPage = Items.FolderAccountingBank;
	Else
		Items.FolderPagesIndirectCalculations.CurrentPage = Items.GroupLabelIndirectCalculations;
	EndIf;
	
EndProcedure // SettlementsBankIsUsedOnChange()

// Procedure - the OnChange event handler of the EditPayerText check box.
//
&AtClient
Procedure EditPayerTextOnChange(Item)
	
	Items.PayerText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

// Procedure - the OnChange event handler of the EditPayeeText check box
//
&AtClient
Procedure EditPayeeTextOnChange(Item)
	
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

// Procedure - the OnChange event handler of the AccountNumber field.
//
&AtClient
Procedure AccountNoOnChange(Item)
	
	Object.Description = Left(TrimAll(Object.AccountNo) + ?(ValueIsFilled(Object.Bank), ", in " + String(Object.Bank), ""), 100);
	
	FillInAccountViewList();
	
EndProcedure

// Procedure - the OnChange event handler of the CashAssetsCurrency field.
//
&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	FillInAccountViewList();
	
EndProcedure

// Procedure - the EndTextInput event handler of the AccountNumber field.
//
&AtClient
Procedure AccountNoTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 20 Then
			Message = New UserMessage;
			Message.Text = NStr("en='The entered value exceeds the permitted account number length of the 20 digits!';ru='Введенное значение превышает допустимую длину номера счета 20 символов!'");
			Message.Message();
			
			StandardProcessing = False;
		EndIf;
		
	#EndIf
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedBankAccounts" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure DirectExchangeMessageClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(DirectExchangeWithBanksAgreement) Then
		FormParameters = New Structure("Key, OpenWindowMode", DirectExchangeWithBanksAgreement, FormWindowOpeningMode.LockOwnerWindow);
		OpenForm("Catalog.EDUsageAgreements.ObjectForm", FormParameters, ThisObject);
	EndIf;
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineIfBankIsToBeSelectedFromCatalog(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = "Select" Then
		
		OpenFormToSelectBank(AdditionalParameters.IsBank);
		
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
