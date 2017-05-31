#Region DefaultSettingsGetters 

Function GetNationalCurrency() Export
	Return Constants.NationalCurrency.Get();
EndFunction

Function GetCurrentUser() Export
	Return SessionParameters.CurrentUser;
EndFunction	

Function GetDefaultCompany(Val User = Undefined) Export
	If NOT Constants.UseMultiCompanies.Get() Then 
		
		DefaultCompany	= CommonAtServerCached.DefaultCompany();
		
	Else
		
		DefaultCompany = CommonAtServer.GetUserSettingsValue("Company",User);
		
	EndIf;
	
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
	Return Catalogs.SalesPriceTypes.Base;	
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