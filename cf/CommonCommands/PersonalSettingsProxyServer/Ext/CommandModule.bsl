
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
#If WebClient Then
	ShowMessageBox(, NStr("en='In the web client the proxy server parameters must be specified in the browser settings.';ru='В веб-клиенте параметры прокси-сервера необходимо задавать в настройках браузера.'"));
	Return;
#EndIf
	
	OpenForm("CommonForm.ProxyServerParameters", New Structure("ProxySettingAtClient", True));
	
EndProcedure

#EndRegion
