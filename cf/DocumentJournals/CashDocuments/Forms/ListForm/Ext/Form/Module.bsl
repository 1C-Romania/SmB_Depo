#Region HelperProceduresAndFunctions

&AtServerNoContext
Function GetDataByPettyCash(Period, PettyCash, Currency)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CashAssetsBalanceAndTurnovers.AmountCurOpeningBalance AS InformationAmountCurOpeningBalance,
	|	CashAssetsBalanceAndTurnovers.AmountCurReceipt AS InformationAmountCurReceipt,
	|	CashAssetsBalanceAndTurnovers.AmountCurExpense AS InformationAmountCurExpense,
	|	CashAssetsBalanceAndTurnovers.AmountCurClosingBalance AS InformationAmountCurClosingBalance
	|FROM
	|	AccumulationRegister.CashAssets.BalanceAndTurnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			Day,
	|			,
	|			BankAccountPettyCash = &PettyCash
	|				AND Currency = &Currency) AS CashAssetsBalanceAndTurnovers";
	
	Query.SetParameter("BeginOfPeriod", BegOfDay(Period));
	Query.SetParameter("EndOfPeriod", EndOfDay(Period));
	Query.SetParameter("PettyCash", PettyCash);
	Query.SetParameter("Currency", ?(ValueIsFilled(Currency), Currency, Constants.NationalCurrency.Get()));
	ResultSelection = Query.Execute().Select();
	
	If ResultSelection.Next() Then
		ReturnStructure = New Structure("InformationAmountCurOpeningBalance, InformationAmountCurClosingBalance, InformationAmountCurReceipt, InformationAmountCurExpense, CurrencyTransactionsAccounting");
		FillPropertyValues(ReturnStructure, ResultSelection);
		ReturnStructure.CurrencyTransactionsAccounting = GetFunctionalOption("CurrencyTransactionsAccounting");
		Return ReturnStructure;
	Else
		Return New Structure(
			"InformationAmountCurClosingBalance, InformationAmountCurOpeningBalance, InformationAmountCurReceipt, InformationAmountCurExpense, CurrencyTransactionsAccounting",
			0,0,0,0,False
		);
	EndIf;
	
EndFunction // GetDataByBankAccount()

&AtClient
Procedure Attachable_HandleListRowActivation()
	
	CurrentRow = Items.CashDocuments.CurrentData;
	If CurrentRow <> Undefined Then
		StructureData = GetDataByPettyCash(CurrentRow.Date, CurrentRow.PettyCash, CurrentRow.Currency);
		FillPropertyValues(ThisForm, StructureData);
		Date = Format(CurrentRow.Date, "DLF=D");
		If StructureData.CurrencyTransactionsAccounting Then
			Date = Date + " (" + CurrentRow.Currency + ")";
		EndIf;
	Else
		InformationAmountCurClosingBalance = 0;
		InformationAmountCurOpeningBalance = 0;
		InformationAmountCurReceipt = 0;
		InformationAmountCurExpense = 0;
		Date = "";
	EndIf;
	
EndProcedure // HandleListStringActivation()

#EndRegion

#Region EventsHandlers

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	Company	 = Settings.Get("Company");
	Counterparty	 = Settings.Get("Counterparty");
	PettyCash		 = Settings.Get("PettyCash");
	
	SmallBusinessClientServer.SetListFilterItem(CashDocuments, "CompanyForFiltering", Company, ValueIsFilled(Company));
	SmallBusinessClientServer.SetListFilterItem(CashDocuments, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	SmallBusinessClientServer.SetListFilterItem(CashDocuments, "PettyCash", PettyCash, ValueIsFilled(PettyCash));
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
Procedure PettyCashOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(CashDocuments, "PettyCash", PettyCash, ValueIsFilled(PettyCash));
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(CashDocuments, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(CashDocuments, "CompanyForFiltering", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure CashDocumentsOnActivateRow(Item)
	
	AttachIdleHandler("Attachable_HandleListRowActivation", 0.2, True);
	
EndProcedure // PettyCashDocumentsOnActivateRow()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutChangingDebt" Then
		Attachable_HandleListRowActivation();
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(CashDocuments);
	
EndProcedure

&AtClient
Procedure StatementGoTo(Command)
	
	OpenForm("Report.CashAssets.Form", New Structure("VariantKey", "Statement"));
	
EndProcedure // StatementGoTo()

#EndRegion













