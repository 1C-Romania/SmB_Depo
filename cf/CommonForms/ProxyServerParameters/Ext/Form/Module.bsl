
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ProxySettingAtClient = Parameters.ProxySettingAtClient;
	If Not Parameters.ProxySettingAtClient
		AND Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en='Insufficient access rights.
		|
		|Proxy server is configured by the administrator.';ru='Недостаточно прав доступа.
		|
		|Настройка прокси-сервера выполняется администратором.'");
	EndIf;
	
	If ProxySettingAtClient Then
		ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtClient();
	Else
		ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
	EndIf;
	
	UseProxy = True;
	UseSystemSettings = True;
	If TypeOf(ProxyServerSetting) = Type("Map") Then
		
		UseProxy = ProxyServerSetting.Get("UseProxy");
		UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
		
		If UseProxy AND Not UseSystemSettings Then
			
			// Fill form data with settings manually.
			Server       = ProxyServerSetting.Get("Server");
			User = ProxyServerSetting.Get("User");
			Password       = ProxyServerSetting.Get("Password");
			Port         = ProxyServerSetting.Get("Port");
			BypassProxyOnLocal = ProxyServerSetting.Get("BypassProxyOnLocal");
			
			AddressesExceptionsServersArray = ProxyServerSetting.Get("BypassProxyOnAddresses");
			If TypeOf(AddressesExceptionsServersArray) = Type("Array") Then
				ExceptionsServers.LoadValues(AddressesExceptionsServersArray);
			EndIf;
			
			AdditionalProxy = ProxyServerSetting.Get("ProxyAdditionalSettings");
			
			If TypeOf(AdditionalProxy) <> Type("Map") Then
				OneProxyForAllProtocols = True;
			Else
				
				// If the additional proxy servers
				// are assigned in the settings, read them from the settings.
				For Each ProtocolServer IN AdditionalProxy Do
					Protocol             = ProtocolServer.Key;
					ProtocolSettings = ProtocolServer.Value;
					ThisObject["Server" + Protocol] = ProtocolSettings.Address;
					ThisObject["Port"   + Protocol] = ProtocolSettings.Port;
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Variants of proxy server usage:
	// 0 - Do not use a proxy server (by default, corresponds to New InternetProxy(False)).
	// 1 - Use proxy server system settings (corresponds to New InternetProxy(True)).
	// 2 - Use own proxy server settings (corresponds to manual proxy server parameters setting).
	// For the last the manually change of proxy server parameters has become available.
	ProxyServerUseVariant = ?(UseProxy, ?(UseSystemSettings = True, 1, 2), 0);
	If ProxyServerUseVariant = 0 Then
		InitFormItems(ThisObject, EmptyProxyServerSettings());
	ElsIf ProxyServerUseVariant = 1 AND Not ProxySettingAtClient Then
		InitFormItems(ThisObject, SystemProxyServerSettings());
	EndIf;
	
	// Control the visible of the additional form items.
	FileModeWork = CommonUseReUse.ApplicationRunningMode().File;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ProxySettingAtClient Then
#If WebClient Then
		ShowMessageBox(, NStr("en='In the web client the proxy server parameters must be specified in the browser settings.';ru='В веб-клиенте параметры прокси-сервера необходимо задавать в настройках браузера.'"));
		Cancel = True;
		Return;
#EndIf
		
		If ProxyServerUseVariant = 1 Then
			InitFormItems(ThisObject, SystemProxyServerSettings());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.ProxyServerAdditionalParameters") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		For Each KeyAndValue IN ValueSelected Do
			If KeyAndValue.Key <> "BypassProxyOnAddresses" Then
				ThisObject[KeyAndValue.Key] = KeyAndValue.Value;
			EndIf;
		EndDo;
		
		ExceptionsServers = ValueSelected.BypassProxyOnAddresses;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("ChooseAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ProxyServerUseVariantsOnChange(Item)
	
	UseProxy = (ProxyServerUseVariant > 0);
	UseSystemSettings = (ProxyServerUseVariant = 1);
	
	ProxySettings = Undefined;
	// Variants of proxy server settings:
	// 0 - Do not use a proxy server (by default, corresponds to New InternetProxy(False)).
	// 1 - Use proxy server system settings (corresponds to New InternetProxy(True)).
	// 2 - Use own proxy server settings (corresponds to manual proxy server parameters setting).
	// For the last the manually change of proxy server parameters has become available.
	If ProxyServerUseVariant = 0 Then
		ProxySettings = EmptyProxyServerSettings();
	ElsIf ProxyServerUseVariant = 1 Then
		ProxySettings = ?(ProxySettingAtClient,
							SystemProxyServerSettings(),
							ProxyServerSystemSettingsAtServer());
	EndIf;
	
	InitFormItems(ThisObject, ProxySettings);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ProxyServerAdditionalParameters(Command)
	
	// Generation of the parameters for additional settings.
	FormParameters = New Structure;
	FormParameters.Insert("OneProxyForAllProtocols", OneProxyForAllProtocols);
	
	FormParameters.Insert("Server"     , Server);
	FormParameters.Insert("Port"       , Port);
	FormParameters.Insert("HTTPServer" , HTTPServer);
	FormParameters.Insert("HTTPPort"   , HTTPPort);
	FormParameters.Insert("HTTPSServer", HTTPSServer);
	FormParameters.Insert("HTTPSPort"  , HTTPSPort);
	FormParameters.Insert("FTPServer"  , FTPServer);
	FormParameters.Insert("FTPPort"    , FTPPort);
	
	FormParameters.Insert("BypassProxyOnAddresses", ExceptionsServers);
	
	OpenForm("CommonForm.ProxyServerAdditionalParameters", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OKButton(Command)
	
	// Saves proxy server settings and closes the form, 
	// passing as return result the proxy parameters.
	SaveProxyServerSettings();
	
EndProcedure

&AtClient
Procedure ButtonCancel(Command)
	
	Modified = False;
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure InitFormItems(Form, ProxySettings)
	
	If ProxySettings <> Undefined Then
		
		Form.Server       = ProxySettings.Server;
		Form.Port         = ProxySettings.Port;
		Form.HTTPServer   = ProxySettings.HTTPServer;
		Form.HTTPPort     = ProxySettings.HTTPPort;
		Form.HTTPSServer  = ProxySettings.HTTPSServer;
		Form.HTTPSPort    = ProxySettings.HTTPSPort;
		Form.FTPServer    = ProxySettings.FTPServer;
		Form.FTPPort      = ProxySettings.FTPPort;
		Form.User = ProxySettings.User;
		Form.Password       = ProxySettings.Password;
		Form.BypassProxyOnLocal = ProxySettings.BypassProxyOnLocal;
		Form.ExceptionsServers.LoadValues(ProxySettings.BypassProxyOnAddresses);
		
		// If settings for all protocols match with the default proxy settings, 
		// then consider that one proxy is used for all protocols.
		Form.OneProxyForAllProtocols = (Form.Server = Form.HTTPServer
			AND Form.HTTPServer = Form.HTTPSServer
			AND Form.HTTPSServer = Form.FTPServer
			AND Form.Port = Form.HTTPPort
			AND Form.HTTPPort = Form.HTTPSPort
			AND Form.HTTPSPort = Form.FTPPort);
		
	EndIf;
	
	// Change the availability of the proxy parameters
	// editing group that depends on the proxy server usage variant.
	Form.Items.ProxyParameters.Enabled = (Form.ProxyServerUseVariant = 2);
	
EndProcedure

// Executes saving proxy server settings in the
// interactive mode as a result of the
// user actions with the displaying messages to the user after that closes the form with the return of proxy server settings.
//
&AtClient
Procedure SaveProxyServerSettings(CloseForm = True)
	
	ProxyServerSetting = New Map;
	
	ProxyServerSetting.Insert("UseProxy", UseProxy);
	ProxyServerSetting.Insert("User"      , User);
	ProxyServerSetting.Insert("Password"            , Password);
	ProxyServerSetting.Insert("Server"            , NormalizedProxyServerAddress(Server));
	ProxyServerSetting.Insert("Port"              , Port);
	ProxyServerSetting.Insert("BypassProxyOnLocal", BypassProxyOnLocal);
	ProxyServerSetting.Insert("BypassProxyOnAddresses", ExceptionsServers.UnloadValues());
	ProxyServerSetting.Insert("UseSystemSettings", UseSystemSettings);
	
	// Generation of the additional proxy server addresses.
	
	If Not OneProxyForAllProtocols Then
		
		AdditionalSettings = New Map;
		If Not IsBlankString(HTTPServer) Then
			AdditionalSettings.Insert("http",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPServer), HTTPPort));
		EndIf;
		
		If Not IsBlankString(HTTPSServer) Then
			AdditionalSettings.Insert("https",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPSServer), HTTPSPort));
		EndIf;
		
		If Not IsBlankString(FTPServer) Then
			AdditionalSettings.Insert("ftp",
				New Structure("Address,Port", NormalizedProxyServerAddress(FTPServer), FTPPort));
		EndIf;
		
		If AdditionalSettings.Count() > 0 Then
			ProxyServerSetting.Insert("ProxyAdditionalSettings", AdditionalSettings);
		EndIf;
		
	EndIf;
	
	WriteProxyServerSettingsInDatabase(ProxySettingAtClient, ProxyServerSetting);
	
	Modified = False;
	
	If CloseForm Then
		
		Close(ProxyServerSetting);
		
	EndIf;
	
EndProcedure

// Performs direct saving of the proxy server settings.
&AtServerNoContext
Procedure WriteProxyServerSettingsInDatabase(ProxySettingAtClient, ProxyServerSetting)
	
	If ProxySettingAtClient
		OR CommonUseReUse.ApplicationRunningMode().File Then
		
		CommonUse.CommonSettingsStorageSave("ProxyServerSetting", , ProxyServerSetting);
		RefreshReusableValues();
	Else
		GetFilesFromInternetService.SaveProxySettingsAt1CEnterpriseServer(ProxyServerSetting);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function EmptyProxyServerSettings()
	
	Result = New Structure;
	Result.Insert("Server"      , "");
	Result.Insert("Port"        , 0);
	Result.Insert("HTTPServer"  , "");
	Result.Insert("HTTPPort"    , 0);
	Result.Insert("HTTPSServer" , "");
	Result.Insert("HTTPSPort"   , 0);
	Result.Insert("FTPServer"   , "");
	Result.Insert("FTPPort"     , 0);
	Result.Insert("User", "");
	Result.Insert("Password"      , "");
	
	Result.Insert("BypassProxyOnLocal", False);
	Result.Insert("BypassProxyOnAddresses", New Array);
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function SystemProxyServerSettings()
	
	Proxy = New InternetProxy(True);
	
	Result = New Structure;
	Result.Insert("Server", Proxy.Server());
	Result.Insert("Port"  , Proxy.Port());
	
	Result.Insert("HTTPServer" , Proxy.Server("http"));
	Result.Insert("HTTPPort"   , Proxy.Port("http"));
	Result.Insert("HTTPSServer", Proxy.Server("https"));
	Result.Insert("HTTPSPort"  , Proxy.Port("https"));
	Result.Insert("FTPServer"  , Proxy.Server("ftp"));
	Result.Insert("FTPPort"    , Proxy.Port("ftp"));
	
	Result.Insert("User", Proxy.User);
	Result.Insert("Password"      , Proxy.Password);
	
	Result.Insert("BypassProxyOnLocal",
		Proxy.BypassProxyOnLocal);
	
	BypassProxyOnAddresses = New Array;
	For Each ServerAddress IN Proxy.BypassProxyOnAddresses Do
		BypassProxyOnAddresses.Add(ServerAddress);
	EndDo;
	Result.Insert("BypassProxyOnAddresses", BypassProxyOnAddresses);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function ProxyServerSystemSettingsAtServer()
	
	Return SystemProxyServerSettings();
	
EndFunction

// Returns the normalized proxy server address - without spaces.
// If there are spaces between meaningful characters,
// then the address is truncated at the first space.
//
// Parameters:
// ProxyServerAddress (String) - normalized proxy server address.
//
// Return value: String - normalized proxy server address.
//
&AtClientAtServerNoContext
Function NormalizedProxyServerAddress(Val AddressOfProxyServer)
	
	AddressOfProxyServer = TrimAll(AddressOfProxyServer);
	SpacePosition = Find(AddressOfProxyServer, " ");
	If SpacePosition > 0 Then
		// If there are spaces in the server address, 
		// then the part of the address before the first space is taken.
		AddressOfProxyServer = Left(AddressOfProxyServer, SpacePosition - 1);
	EndIf;
	
	Return AddressOfProxyServer;
	
EndFunction

&AtClient
Procedure ChooseAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	SaveProxyServerSettings();
	
EndProcedure

#EndRegion
