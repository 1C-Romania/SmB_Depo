//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtServer
// Procedure - form event handler OnCreateAtServer
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				  = Settings.Get("Company");
	Counterparty				  = Settings.Get("Counterparty");
	BankAccountPettyCash		  = Settings.Get("BankAccountPettyCash");
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
		SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.PettyCashes") Then
		SmallBusinessClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		SmallBusinessClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	Else
		SmallBusinessClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
		SmallBusinessClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	EndIf;
	
EndProcedure // OnLoadDataFromSettingsAtServer()

// Procedure - event handler OnChange of attribute BankAccountPettyCash.
//
&AtClient
Procedure BankAccountPettyCashOnChange(Item)
	
	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.PettyCashes") Then
		SmallBusinessClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		SmallBusinessClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	Else
		SmallBusinessClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
		SmallBusinessClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of attribute Counterparty.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

// Procedure - event handler OnChange of the Company attribute.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	CurrentRow = Items.List.CurrentData;
	If CurrentRow <> Undefined Then
		Items.Information.Title = Format(CurrentRow.Date, "DLF=D");
	EndIf;
	
EndProcedure







