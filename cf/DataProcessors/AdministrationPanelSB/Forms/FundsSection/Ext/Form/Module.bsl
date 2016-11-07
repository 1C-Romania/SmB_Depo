
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
	
	If RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData() Then
		
		If AttributePathToData = "ConstantsSet.FunctionalCurrencyTransactionsAccounting" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "FunctionalCurrencyTransactionsAccountingSettings",	"Enabled", ConstantsSet.FunctionalCurrencyTransactionsAccounting);
			CommonUseClientServer.SetFormItemProperty(Items, "Group2", 										"Enabled", ConstantsSet.FunctionalCurrencyTransactionsAccounting);
			
			CommonUseClientServer.SetFormItemProperty(Items, "NationalCurrencyHelp",	"Visible", ConstantsSet.FunctionalCurrencyTransactionsAccounting);
			CommonUseClientServer.SetFormItemProperty(Items, "AccountingCurrencyHelp",			"Visible", ConstantsSet.FunctionalCurrencyTransactionsAccounting);
			CommonUseClientServer.SetFormItemProperty(Items, "ExchangeRateDifferencesCalculationFrequencyHelp", "Visible", ConstantsSet.FunctionalCurrencyTransactionsAccounting);
			
		EndIf;
		
	EndIf;
	
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
	
	If AttributePathToData = "ConstantsSet.FunctionalCurrencyTransactionsAccounting" Then
		
		ThisForm.ConstantsSet.FunctionalCurrencyTransactionsAccounting = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.AccountingCurrency" Then
		
		ThisForm.ConstantsSet.AccountingCurrency = CurrentValue;
		
	EndIf;
	
EndProcedure // ReturnFormAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Check on the possibility to disable the option CurrencyTransactionsAccounting.
//
&AtServer
Function CancellationUncheckFunctionalCurrencyTransactionsAccounting()
	
	MessageText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	Currencies.Ref
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.Ref <> &NationalCurrency"
	);
	
	Query.SetParameter("NationalCurrency", Constants.NationalCurrency.Get());
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		MessageText = NStr("en='Currencies that are different from the national are registered in the base! It is required to delete them. The flag removal is prohibited!';ru='В базе заведены валюты, отличные от национальной! Необходимо их удалить. Снятие флага запрещено!'");
		
	EndIf;
	
	Return MessageText;
	
EndFunction // CancellationUncheckFunctionalCurrencyTransactionsAccounting()

// Check on the possibility to change the established accounting currency.
//
&AtServer
Function CancellationToChangeAccountingCurrency()
	
	MessageText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("FixedAssets");
	ListOfRegisters.Add("CashAssets");
	ListOfRegisters.Add("IncomeAndExpenses");
	ListOfRegisters.Add("IncomeAndExpensesCashMethod");
	ListOfRegisters.Add("IncomeAndExpensesUndistributed");
	ListOfRegisters.Add("IncomeAndExpensesRetained");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("InventoryTransferred");
	ListOfRegisters.Add("InventoryReceived");
	ListOfRegisters.Add("AccrualsAndDeductions");
	ListOfRegisters.Add("SalesTargets");
	ListOfRegisters.Add("PaymentCalendar");
	ListOfRegisters.Add("Sales");
	ListOfRegisters.Add("TaxesSettlements");
	ListOfRegisters.Add("PayrollPayments");
	ListOfRegisters.Add("AdvanceHolderPayments");
	ListOfRegisters.Add("AccountsReceivable");
	ListOfRegisters.Add("AccountsPayable");
	ListOfRegisters.Add("FinancialResult");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister IN ListOfRegisters Do
		
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				" 
				|
				|UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Value + ".Company
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Value + " AS AccumulationRegister" + AccumulationRegister.Value;
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
		
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
			
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Inventory.Company
	|FROM
	|	AccumulationRegister.Inventory AS Inventory";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		MessageText = NStr("en='There are records in the base of the ""amount"" accumulation registers! You can not change the accounting currency!';ru='В базе есть движения по ""суммовым"" регистрам накопления! Изменение валюты учета запрещено!'");	
		
	EndIf;
	
	Return MessageText;
	
EndFunction // CancellationToChangeAccountingCurrency()

// Initialization of checking the possibility to disable the CurrencyTransactionsAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are catalog items "Currencies" except the predefined, it is not allowed to clear the FunctionalCurrencyTransactionsAccounting check box	
	If AttributePathToData = "ConstantsSet.FunctionalCurrencyTransactionsAccounting" Then
		
		If Constants.FunctionalCurrencyTransactionsAccounting.Get() <> ConstantsSet.FunctionalCurrencyTransactionsAccounting 
			AND (NOT ConstantsSet.FunctionalCurrencyTransactionsAccounting) Then
			
			ErrorText = CancellationUncheckFunctionalCurrencyTransactionsAccounting();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
	
	EndIf;
	
	If AttributePathToData = "ConstantsSet.AccountingCurrency" Then
		
		If Constants.AccountingCurrency.Get() <> ConstantsSet.AccountingCurrency Then
			
			ErrorText = CancellationToChangeAccountingCurrency();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	Constants.AccountingCurrency.Get());
				
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

// Procedure - command handler CatalogCurrencies.
//
&AtClient
Procedure CatalogCurrencies(Command)
	
	OpenForm("Catalog.Currencies.ListForm");
	
EndProcedure // CatalogCurrencies()

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

// Procedure - event handler OnChange of the FunctionalCurrencyTransactionsAccounting field.
//
&AtClient
Procedure FunctionalCurrencyTransactionsAccountingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalCurrencyTransactionsAccountingOnChange()

// Procedure - event handler OnChange of the NationalCurrency field.
//
&AtClient
Procedure NationalCurrencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // NationalCurrencyOnChange()

// Procedure - event handler OnChange of the AccountingCurrency field.
//
&AtClient
Procedure AccountingCurrencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // AccountingCurrencyOnChange()

// Procedure - click reference handler ExchangeRateDifferencesCalculationFrequency.
//
&AtClient
Procedure ExchangeRateDifferencesCalculationFrequencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // ExchangeRateDifferencesCalculationFrequency()

// Procedure - event handler OnChange of the OffsetAdvancesDebtsAutomatically field.
//
&AtClient
Procedure RegistrateDebtsAdvancesAutomaticallyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // RegistrateDebtsAdvancesAutomaticallyOnChange()

// Procedure - event handler OnChange of the FunctionalOptionPaymentCalendar field.
//
&AtClient
Procedure FunctionalOptionPaymentCalendarOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionPaymentCalendarOnChange()









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


//( elmi # 08.5
&AtClient
Procedure CurrencyQuotationTypeOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure
//) elmi