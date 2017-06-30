#Region DefaultSettingsGetters 

Function GetNationalCurrency() Export
	Return Constants.NationalCurrency.Get();
EndFunction

Function GetCurrentUser() Export
	Return SessionParameters.CurrentUser;
EndFunction	

Function GetDefaultCompany(Val User = Undefined) Export
	DefaultCompany = CommonAtServer.GetUserSettingsValue("Company",User);
	Return DefaultCompany;
EndFunction

Function GetDefaultFinancialYear(Val User = Undefined) Export
	Return CommonAtServer.GetUserSettingsValue("DefaultFinancialYear",User);
EndFunction

Function GetDefaultWarehouse(Val User = Undefined) Export
	Return CommonAtServer.GetUserSettingsValue("Warehouse",User);
EndFunction

Function GetDefaultDepartment(Val User = Undefined) Export
	Return CommonAtServer.GetUserSettingsValue("Department",User);
EndFunction

Function GetDefaultPriceType(Val User = Undefined) Export	
    // Jack 29.06.2017	
	// to do
	Return Undefined;
	//Return Catalogs.SalesPriceTypes.Base;	
EndFunction	

Function GetDefaultIssuePlace(Val User = Undefined) Export	
	Return CommonAtServer.GetUserSettingsValue("DefaultIssuePlace",User);	
EndFunction	

#EndRegion

#Region ExchangeRates

Function GetExchangeRate(Val Currency, Val RateDate) Export 
	
	Return CommonAtServer.GetExchangeRate(Currency,RateDate);
	
EndFunction // GetExchangeRate()

#EndRegion