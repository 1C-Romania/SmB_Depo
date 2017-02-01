
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User = Users.CurrentUser();
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainCompany");
	If ValueIsFilled(SettingValue) Then
		MainCompany = SettingValue;
	Else
		MainCompany = SmallBusinessServer.GetPredefinedCompany();
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", Company, ValueIsFilled(Company));
	
EndProcedure // BeforeImportDataFromSettingsAtServer()

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", Company, ValueIsFilled(Company));
	
EndProcedure // CompanyOnChange()

&AtClient
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

#EndRegion
