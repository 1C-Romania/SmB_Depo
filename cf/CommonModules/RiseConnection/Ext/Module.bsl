
Function GetConnectionSettings() Export
	stSettings = New Structure;
	stSettings.Insert("ConnectionString", Constants.RiseTranslatorConnectionString.Get());
	stSettings.Insert("User", Constants.RiseTranslatorUser.Get());
	stSettings.Insert("Password", Constants.RiseTranslatorPassword.Get());
	Return stSettings;
EndFunction

Function GetProxy() Export
	stSettings = RiseConnection.GetConnectionSettings();
	
	Definitions = New WSDefinitions(stSettings.ConnectionString + "ws/translations.1cws?wsdl", stSettings.User, stSettings.Password);
	Proxy = New WSProxy(Definitions, "http://risecompany.ru/Translator/", "Translations", "TranslationsSoap");
	Proxy.User = stSettings.User;
	Proxy.Password = stSettings.Password;
	
	Return Proxy;
EndFunction
