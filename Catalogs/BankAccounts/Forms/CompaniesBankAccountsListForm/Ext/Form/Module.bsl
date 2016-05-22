
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User = Users.CurrentUser();
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainCompany");
	If ValueIsFilled(SettingValue) Then
		MainCompany = SettingValue;
	Else
		MainCompany = SmallBusinessServer.GetPredefinedCompany();
	EndIf;
	
	Items.AgreementOnDirectExchange.Visible = GetFunctionalOption("UseEDExchangeWithBanks");
	
EndProcedure // OnCreateAtServer()

// Procedure - form event handler BeforeImportDataFromSettingsAtServer.
//
&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", Company, ValueIsFilled(Company));
	
EndProcedure // BeforeImportDataFromSettingsAtServer()

&AtClient
// Procedure - event handler OnChange of the Company attribute.
//
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", Company, ValueIsFilled(Company));
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - list event handler BeforeAddStart.
//
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	ParametersStructure = New Structure();
	If ValueIsFilled(Company) Then
		ParametersStructure.Insert("Owner", Company);
	Else
		ParametersStructure.Insert("Owner", MainCompany);
	EndIf;
	
	OpenForm("Catalog.BankAccounts.Form.ItemForm", New Structure("FillingValues", ParametersStructure));
	
EndProcedure // ListBeforeAddRow()
